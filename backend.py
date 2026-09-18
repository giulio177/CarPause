"""
backend.py - Automotive Infotainment Core Bridge (Pure Real-Data Engine)
Strictly connects to real Linux system services (PipeWire/PulseAudio, NetworkManager, BlueZ, MPRIS, OBD-II).
ZERO DUMMY DATA: if an interface or sensor is disconnected, real error states are exposed.
"""

import os
import sys
import random
import atexit
import subprocess
import logging
from datetime import datetime
from typing import Optional, List, Dict, Any

from PyQt6.QtCore import QObject, pyqtProperty, pyqtSignal, pyqtSlot, QTimer, QCoreApplication, QUrl, QMetaObject, Qt, QSettings
from PyQt6.QtDBus import QDBusConnection, QDBusMessage
from PyQt6.QtMultimedia import QMediaPlayer, QAudioOutput

from src.core.async_runner import AsyncRunner
from src.services.system_service import AudioService, HardwareMonitorService, WeatherService
from src.services.network_service import WiFiService, BluetoothService
from src.services.media_service import MediaService
from src.services.media_history_service import MediaHistoryService
from src.services.local_music_service import LocalMusicService
from src.services.obd_service import OBDService
from src.services.log_service import LogService
from src.services.airplay_service import AirPlayService

logger = logging.getLogger("InfotainmentBackend")


class InfotainmentBackend(QObject):
    """
    Main Controller Bridge between Python OS/Hardware layer and QML Frontend.
    Provides reactive properties with ZERO mock/dummy fallback data.
    """

    # Signals for Reactive Q_PROPERTY bindings
    volumeChanged = pyqtSignal(int)
    maxVolumeChanged = pyqtSignal(int)
    muteChanged = pyqtSignal(bool)
    timeChanged = pyqtSignal(str)
    dateChanged = pyqtSignal(str)
    cpuTemperatureChanged = pyqtSignal()
    weatherChanged = pyqtSignal()
    mediaChanged = pyqtSignal()
    localMusicChanged = pyqtSignal()
    mediaHistoryChanged = pyqtSignal()
    mediaSubViewChanged = pyqtSignal(str)
    trackLyricsChanged = pyqtSignal()
    shuffleChanged = pyqtSignal()
    repeatModeChanged = pyqtSignal()
    currentViewChanged = pyqtSignal(str)
    obdChanged = pyqtSignal()
    wifiChanged = pyqtSignal()
    wifiPoweredChanged = pyqtSignal(bool)
    wifiConnectingChanged = pyqtSignal(bool)
    wifiStatusMessageChanged = pyqtSignal(str)
    wifiConnectedSuccessfully = pyqtSignal(str)
    wifiScanningChanged = pyqtSignal(bool)
    bluetoothChanged = pyqtSignal()
    bluetoothDevicesChanged = pyqtSignal()
    bluetoothScanningChanged = pyqtSignal(bool)
    appLogsChanged = pyqtSignal()
    airplayChanged = pyqtSignal()
    airplayStreamingChanged = pyqtSignal(bool)
    airplayExitPopupChanged = pyqtSignal(bool)
    updateStateChanged = pyqtSignal()

    def __init__(self, parent: Optional[QObject] = None):
        super().__init__(parent)

        self._async_runner = AsyncRunner(max_threads=4)

        # 1. Audio State
        self._settings = QSettings("Automotive", "RPi Car Infotainment")
        try:
            saved_max = int(self._settings.value("audio/maxVolume", 100))
            self._max_volume: int = max(100, min(200, saved_max))
        except Exception:
            self._max_volume: int = 100
        self._volume: int = 50
        self._is_muted: bool = False
        self._last_nonzero_volume: int = 50
        self._audio_sync_suppressed: bool = False

        # 2. Clock
        self._current_time: str = ""
        self._current_date: str = ""

        # 3. Hardware Monitoring (Real CPU temp, None if unavailable)
        self._cpu_temp: Optional[float] = None

        # 4. Weather State (Real Open-Meteo, None if offline)
        self._weather_temp: Optional[float] = None
        self._weather_condition: str = "Aggiornamento..."
        self._weather_icon: str = "weather_offline"
        self._weather_available: bool = False

        # 5. Media State (Real MPRIS/Bluetooth/Local, empty if no player active)
        self._has_media: bool = False
        self._track_title: str = ""
        self._track_artist: str = ""
        self._track_album: str = ""
        self._track_duration_ms: int = 0
        self._track_position_ms: int = 0
        self._is_playing: bool = False
        self._track_progress: float = 0.0

        # Local Music & Media SubView State
        self._local_music_service = LocalMusicService()
        self._local_tracks: List[Dict[str, Any]] = []
        self._media_history_list: List[Dict[str, Any]] = []
        self._media_sub_view: str = "player"  # "player", "library", "history"
        self._media_source: str = "remote"    # "remote" (Bluetooth) or "local" (Raspberry Pi)
        self._current_track_cover: str = ""
        self._current_track_lyrics: str = ""
        self._has_lyrics: bool = False
        self._current_local_track_idx: int = -1
        self._shuffle_enabled: bool = False
        self._repeat_mode: str = "off"  # "off", "all", "one"

        # Dual-source cache (preserves state when toggling between Bluetooth and Local)
        self._remote_has_media: bool = False
        self._remote_title: str = ""
        self._remote_artist: str = ""
        self._remote_album: str = ""
        self._remote_duration_ms: int = 0
        self._remote_position_ms: int = 0
        self._remote_progress: float = 0.0
        self._remote_is_playing: bool = False
        self._remote_shuffle: bool = False
        self._remote_repeat: str = "off"

        self._local_has_media: bool = False
        self._local_title: str = ""
        self._local_artist: str = ""
        self._local_album: str = ""
        self._local_duration_ms: int = 0
        self._local_position_ms: int = 0
        self._local_progress: float = 0.0
        self._local_is_playing: bool = False
        self._local_cover: str = ""
        self._local_lyrics: str = ""
        self._local_has_lyrics: bool = False
        self._local_shuffle: bool = False
        self._local_repeat: str = "off"

        # Local QMediaPlayer for Raspberry Pi music files
        self._local_player = QMediaPlayer(self)
        self._audio_output = QAudioOutput(self)
        self._local_player.setAudioOutput(self._audio_output)
        self._local_player.positionChanged.connect(self._on_local_player_position_changed)
        self._local_player.durationChanged.connect(self._on_local_player_duration_changed)
        self._local_player.playbackStateChanged.connect(self._on_local_player_state_changed)
        self._local_player.mediaStatusChanged.connect(self._on_local_player_media_status_changed)

        # 6. OBD-II / Vehicle Telemetry (Real OBD, None if disconnected)
        self._obd_connected: bool = False
        self._obd_error: str = "OBD Non Rilevato"
        self._speed_kmh: Optional[int] = None
        self._battery_voltage: Optional[float] = None
        self._engine_rpm: Optional[int] = None

        # 7. Network: Wi-Fi State (Real nmcli)
        self._wifi_powered: bool = True
        self._wifi_connected: bool = False
        self._wifi_ssid: str = ""
        self._wifi_signal: int = 0
        self._wifi_ip: str = ""
        self._wifi_networks: List[Dict[str, Any]] = []
        self._wifi_connecting: bool = False
        self._wifi_scanning: bool = False
        self._wifi_status_message: str = ""

        # 8. Network: Bluetooth State (Real BlueZ)
        self._bt_powered: bool = False
        self._bt_connected: bool = False
        self._bt_device_name: str = ""
        self._bt_discoverable: bool = False
        self._bt_adapter_name: str = "Raspberry Pi"
        self._bt_scanning: bool = False
        self._bt_devices: List[Dict[str, Any]] = []

        # 9. AirPlay State (UxPlay screen mirroring)
        self._airplay_decoder: str = str(self._settings.value("airplay/decoder", "software"))
        self._airplay_service = AirPlayService(server_name="Mito-AirPlay", decoder_mode=self._airplay_decoder)
        self._airplay_available: bool = AirPlayService.is_available()
        self._airplay_running: bool = False
        self._airplay_streaming: bool = False
        self._airplay_client_info: str = ""
        self._airplay_status_message: str = "Pronto per l'avvio" if self._airplay_available else "UxPlay non installato"
        self._airplay_show_exit_popup: bool = False
        self._airplay_popup_timer = QTimer(self)
        self._airplay_popup_timer.setInterval(4000)
        self._airplay_popup_timer.setSingleShot(True)
        self._airplay_popup_timer.timeout.connect(self._on_airplay_popup_timeout)
        atexit.register(self._airplay_service.stop_server)

        # 10. Software Update State (Git pull via scripts/update_infotainment.sh)
        self._update_running: bool = False
        self._update_status_message: str = ""
        self._update_success: bool = False

        # 11. UI Navigation View
        self._current_view: str = "dashboard"

        # Debounce timer for volume slider interaction
        self._pending_volume: Optional[int] = None
        self._volume_debounce_timer = QTimer(self)
        self._volume_debounce_timer.setSingleShot(True)
        self._volume_debounce_timer.setInterval(50)
        self._volume_debounce_timer.timeout.connect(self._flush_volume_to_hardware)

        # Anti-bounce optimistic play/pause lock
        self._optimistic_play_target: Optional[bool] = None
        self._optimistic_play_timer = QTimer(self)
        self._optimistic_play_timer.setSingleShot(True)
        self._optimistic_play_timer.setInterval(1500)
        self._optimistic_play_timer.timeout.connect(self._clear_optimistic_play_target)

        # Media Playback History Logger (Session log per app startup in media_history/)
        self._media_history = MediaHistoryService()
        atexit.register(self._media_history.close_session)
        app_inst = QCoreApplication.instance()
        if app_inst:
            app_inst.aboutToQuit.connect(self._media_history.close_session)
            app_inst.aboutToQuit.connect(self._airplay_service.stop_server)

        # Session File Log Service (writes and reads session files in logs/ like media_history/)
        self._log_service = LogService.get_instance(on_new_record=self._on_log_recorded_callback)
        self._current_log_file: str = self._log_service.current_filename
        self._app_logs: List[Dict[str, Any]] = self._log_service.read_logs()
        self._log_refresh_timer = QTimer(self)
        self._log_refresh_timer.setInterval(250)
        self._log_refresh_timer.setSingleShot(True)
        self._log_refresh_timer.timeout.connect(self._sync_logs_to_qml)

        # Setup background polling timers
        self._setup_timers()

        # Real-time event-driven D-Bus listeners
        self._setup_dbus_listeners()

        # Initial background queries
        self._initialize_all_services()

    def _on_log_recorded_callback(self) -> None:
        """Invoked from logging thread whenever a new log entry is written to file."""
        try:
            QMetaObject.invokeMethod(self._log_refresh_timer, "start", Qt.ConnectionType.QueuedConnection)
        except Exception:
            pass

    def _sync_logs_to_qml(self) -> None:
        """Reads session log file from disk and updates QML frontend."""
        self._app_logs = self._log_service.read_logs(self._current_log_file)
        self.appLogsChanged.emit()

    # -------------------------------------------------------------------------
    # Initializers & Polling Timers
    # -------------------------------------------------------------------------

    def _setup_timers(self) -> None:
        # Clock timer (1s)
        self._clock_timer = QTimer(self)
        self._clock_timer.setInterval(1000)
        self._clock_timer.timeout.connect(self._on_clock_tick)
        self._clock_timer.start()
        self._on_clock_tick()

        # Media & Bluetooth polling timer (1s fallback)
        self._media_timer = QTimer(self)
        self._media_timer.setInterval(1000)
        self._media_timer.timeout.connect(self._query_media_and_bt_async)
        self._media_timer.start()

        # High-frequency playback position ticker (500ms = mezzo secondo)
        self._playback_ticker = QTimer(self)
        self._playback_ticker.setInterval(500)
        self._playback_ticker.timeout.connect(self._on_playback_tick)
        self._playback_ticker.start()

        # Telemetry & OBD timer (3s)
        self._telemetry_timer = QTimer(self)
        self._telemetry_timer.setInterval(3000)
        self._telemetry_timer.timeout.connect(self._query_system_and_obd_async)
        self._telemetry_timer.start()

        # Wi-Fi polling timer (10s)
        self._wifi_timer = QTimer(self)
        self._wifi_timer.setInterval(10000)
        self._wifi_timer.timeout.connect(self.scanWifi)
        self._wifi_timer.start()

        # Audio sync timer (3s) - keeps volume and mute state in sync with hardware
        self._audio_timer = QTimer(self)
        self._audio_timer.setInterval(3000)
        self._audio_timer.timeout.connect(self._sync_audio_async)
        self._audio_timer.start()

        # Weather timer (15min)
        self._weather_timer = QTimer(self)
        self._weather_timer.setInterval(15 * 60 * 1000)
        self._weather_timer.timeout.connect(self.refreshWeather)
        self._weather_timer.start()

    def _initialize_all_services(self) -> None:
        """Asynchronously triggers initial queries for all real services."""
        # Audio
        self._async_runner.run_async(
            AudioService.get_volume_and_mute,
            on_result=self._on_initial_audio_loaded,
        )
        # Media & BT
        self._query_media_and_bt_async()
        # Telemetry & OBD
        self._query_system_and_obd_async()
        # Wi-Fi
        self.scanWifi()
        # Weather
        self.refreshWeather()
        # Local Music & History
        self.scanLocalMusic()
        self.refreshMediaHistory()

    def _on_initial_audio_loaded(self, result: tuple) -> None:
        if self._audio_sync_suppressed:
            return
        vol, muted = result
        vol = max(0, min(self._max_volume, vol))
        self._volume = vol
        self._is_muted = muted
        if vol > 0:
            self._last_nonzero_volume = vol
        self.volumeChanged.emit(self._volume)
        self.muteChanged.emit(self._is_muted)
        logger.info("Real Audio active: Volume=%d%% (Max=%d%%), Muted=%s", vol, self._max_volume, muted)

    def _sync_audio_async(self) -> None:
        """Polls hardware audio state if user isn't currently moving the slider."""
        if self._pending_volume is None and not self._audio_sync_suppressed:
            self._async_runner.run_async(
                AudioService.get_volume_and_mute,
                on_result=self._on_audio_polled
            )

    def _on_audio_polled(self, result: tuple) -> None:
        if self._pending_volume is not None or self._audio_sync_suppressed:
            return
        vol, muted = result
        vol = max(0, min(self._max_volume, vol))
        if vol > 0:
            self._last_nonzero_volume = vol
        if vol != self._volume:
            self._volume = vol
            self.volumeChanged.emit(self._volume)
        if muted != self._is_muted:
            self._is_muted = muted
            self.muteChanged.emit(self._is_muted)

    # -------------------------------------------------------------------------
    # Asynchronous System Dispatchers (Zero GUI Lag)
    # -------------------------------------------------------------------------

    def _on_clock_tick(self) -> None:
        now = datetime.now()
        t_str = now.strftime("%H:%M")
        d_str = now.strftime("%A, %d %B").capitalize()
        if t_str != self._current_time:
            self._current_time = t_str
            self.timeChanged.emit(self._current_time)
        if d_str != self._current_date:
            self._current_date = d_str
            self.dateChanged.emit(self._current_date)

        # Update media playback session history
        self._media_history.update_playback(
            self._track_title,
            self._track_artist,
            self._track_album,
            self._is_playing,
            duration_ms=self._track_duration_ms,
            position_ms=self._track_position_ms,
        )

    def _setup_dbus_listeners(self) -> None:
        """
        Connects real-time event-driven D-Bus signal listeners for BlueZ and MPRIS.
        Ensures instantaneous (<10ms) UI updates when playback state or metadata changes.
        """
        try:
            QDBusConnection.systemBus().connect(
                "", "", "org.freedesktop.DBus.Properties", "PropertiesChanged",
                self._on_dbus_properties_changed
            )
        except Exception as exc:
            logger.warning("Failed to connect system D-Bus media listener: %s", exc)

        try:
            QDBusConnection.sessionBus().connect(
                "", "", "org.freedesktop.DBus.Properties", "PropertiesChanged",
                self._on_dbus_properties_changed
            )
        except Exception as exc:
            logger.warning("Failed to connect session D-Bus media listener: %s", exc)

    def _clear_optimistic_play_target(self) -> None:
        """Grace window elapsed without hardware confirmation: sync actual state."""
        self._optimistic_play_target = None
        self._query_media_and_bt_async()

    @pyqtSlot(QDBusMessage)
    def _on_dbus_properties_changed(self, msg: QDBusMessage) -> None:
        """
        Sub-frame event-driven reactive handler for BlueZ and MPRIS D-Bus signals.
        Instantaneously updates track metadata and play/pause state (<10ms).
        """
        try:
            args = msg.arguments()
            if len(args) < 2:
                return
            interface_name = str(args[0])
            changed_props = args[1]
            if not isinstance(changed_props, dict):
                return

            updated = False

            if interface_name == "org.bluez.MediaPlayer1":
                if "Status" in changed_props:
                    st = str(changed_props["Status"]).lower()
                    hw_playing = (st == "playing")
                    self._remote_is_playing = hw_playing
                    self._remote_has_media = True
                    if self._media_source == "remote":
                        if self._optimistic_play_target is not None:
                            if hw_playing == self._optimistic_play_target:
                                # Hardware confirmed desired state: release lock
                                self._optimistic_play_target = None
                                self._optimistic_play_timer.stop()
                                if self._is_playing != hw_playing:
                                    self._is_playing = hw_playing
                                    updated = True
                            # If different, ignore stale pre-transit event to prevent flicker
                        else:
                            if self._is_playing != hw_playing:
                                self._is_playing = hw_playing
                                self._has_media = True
                                updated = True
                    elif self._media_source == "local" and hw_playing:
                        # Remote phone explicitly started playing: pause local and yield to remote
                        self._local_player.pause()
                        self._local_is_playing = False
                        self._media_source = "remote"
                        self._is_playing = True
                        self._has_media = True
                        self._track_title = self._remote_title
                        self._track_artist = self._remote_artist
                        self._track_album = self._remote_album
                        self._track_duration_ms = self._remote_duration_ms
                        self._track_position_ms = self._remote_position_ms
                        self._track_progress = self._remote_progress
                        self._current_track_cover = ""
                        self._current_track_lyrics = ""
                        self._has_lyrics = False
                        self._shuffle_enabled = self._remote_shuffle
                        self._repeat_mode = self._remote_repeat
                        updated = True
                        self.trackLyricsChanged.emit()
                        self.shuffleChanged.emit()
                        self.repeatModeChanged.emit()

                if "Track" in changed_props:
                    track = changed_props["Track"]
                    if isinstance(track, dict):
                        t = str(track.get("Title", "")).strip()
                        a = str(track.get("Artist", "")).strip()
                        alb = str(track.get("Album", "")).strip()
                        dur = track.get("Duration", 0)
                        pos = changed_props.get("Position")
                        self._remote_has_media = True
                        if t:
                            self._remote_title = t
                        if a:
                            self._remote_artist = a
                        if alb:
                            self._remote_album = alb
                        if dur > 0:
                            self._remote_duration_ms = dur
                        if pos is not None:
                            self._remote_position_ms = pos
                        if dur and pos is not None:
                            self._remote_progress = pos / dur

                        if self._media_source == "remote":
                            if t:
                                self._track_title = t
                            if a:
                                self._track_artist = a
                            if alb:
                                self._track_album = alb
                            if dur > 0:
                                self._track_duration_ms = dur
                            if pos is not None:
                                self._track_position_ms = pos
                            if dur and pos is not None:
                                self._track_progress = pos / dur
                            self._has_media = True
                            updated = True

                if "Position" in changed_props and "Track" not in changed_props:
                    pos = changed_props.get("Position")
                    if pos is not None:
                        self._remote_position_ms = pos
                        if self._media_source == "remote":
                            self._track_position_ms = pos
                            if self._track_duration_ms > 0:
                                self._track_progress = pos / float(self._track_duration_ms)
                            updated = True

                if "Shuffle" in changed_props:
                    shuf_val = str(changed_props["Shuffle"]).lower()
                    new_shuf = (shuf_val in ["alltracks", "group"])
                    self._remote_shuffle = new_shuf
                    if self._media_source == "remote":
                        if self._shuffle_enabled != new_shuf:
                            self._shuffle_enabled = new_shuf
                            self.shuffleChanged.emit()
                            updated = True

                if "Repeat" in changed_props:
                    rep_val = str(changed_props["Repeat"]).lower()
                    if rep_val == "singletrack":
                        new_rep = "one"
                    elif rep_val in ["alltracks", "group"]:
                        new_rep = "all"
                    else:
                        new_rep = "off"
                    self._remote_repeat = new_rep
                    if self._media_source == "remote":
                        if self._repeat_mode != new_rep:
                            self._repeat_mode = new_rep
                            self.repeatModeChanged.emit()
                            updated = True

            elif interface_name == "org.mpris.MediaPlayer2.Player":
                if "PlaybackStatus" in changed_props:
                    st = str(changed_props["PlaybackStatus"]).lower()
                    hw_playing = (st == "playing")
                    self._remote_is_playing = hw_playing
                    self._remote_has_media = True
                    if self._media_source == "remote":
                        if self._optimistic_play_target is not None:
                            if hw_playing == self._optimistic_play_target:
                                self._optimistic_play_target = None
                                self._optimistic_play_timer.stop()
                                if self._is_playing != hw_playing:
                                    self._is_playing = hw_playing
                                    updated = True
                        else:
                            if self._is_playing != hw_playing:
                                self._is_playing = hw_playing
                                self._has_media = True
                                updated = True
                    elif self._media_source == "local" and hw_playing:
                        self._local_player.pause()
                        self._local_is_playing = False
                        self._media_source = "remote"
                        self._is_playing = True
                        self._has_media = True
                        self._track_title = self._remote_title
                        self._track_artist = self._remote_artist
                        self._track_album = self._remote_album
                        self._track_duration_ms = self._remote_duration_ms
                        self._track_position_ms = self._remote_position_ms
                        self._track_progress = self._remote_progress
                        self._current_track_cover = ""
                        self._current_track_lyrics = ""
                        self._has_lyrics = False
                        self._shuffle_enabled = self._remote_shuffle
                        self._repeat_mode = self._remote_repeat
                        updated = True
                        self.trackLyricsChanged.emit()
                        self.shuffleChanged.emit()
                        self.repeatModeChanged.emit()

                if "Metadata" in changed_props:
                    meta = changed_props["Metadata"]
                    if isinstance(meta, dict):
                        t = str(meta.get("xesam:title", "")).strip()
                        artists = meta.get("xesam:artist", [])
                        a = ", ".join(artists) if isinstance(artists, list) else str(artists).strip()
                        alb = str(meta.get("xesam:album", "")).strip()
                        len_us = meta.get("mpris:length", 0)
                        dur = int(len_us / 1000) if len_us else 0
                        self._remote_has_media = True
                        if t:
                            self._remote_title = t
                        if a:
                            self._remote_artist = a
                        if alb:
                            self._remote_album = alb
                        if dur > 0:
                            self._remote_duration_ms = dur

                        if self._media_source == "remote":
                            if t:
                                self._track_title = t
                            if a:
                                self._track_artist = a
                            if alb:
                                self._track_album = alb
                            if dur > 0:
                                self._track_duration_ms = dur
                            self._has_media = True
                            updated = True

                if "Shuffle" in changed_props:
                    new_shuf = bool(changed_props["Shuffle"])
                    self._remote_shuffle = new_shuf
                    if self._media_source == "remote":
                        if self._shuffle_enabled != new_shuf:
                            self._shuffle_enabled = new_shuf
                            self.shuffleChanged.emit()
                            updated = True

                if "LoopStatus" in changed_props:
                    loop_val = str(changed_props["LoopStatus"]).lower()
                    if loop_val == "track":
                        new_rep = "one"
                    elif loop_val == "playlist":
                        new_rep = "all"
                    else:
                        new_rep = "off"
                    self._remote_repeat = new_rep
                    if self._media_source == "remote":
                        if self._repeat_mode != new_rep:
                            self._repeat_mode = new_rep
                            self.repeatModeChanged.emit()
                            updated = True

            elif interface_name == "org.bluez.Device1":
                if "Connected" in changed_props:
                    is_conn = bool(changed_props["Connected"])
                    if not is_conn:
                        self._remote_has_media = False
                        self._remote_title = ""
                        self._remote_artist = ""
                        self._remote_album = ""
                        self._remote_duration_ms = 0
                        self._remote_position_ms = 0
                        self._remote_is_playing = False
                        self._remote_progress = 0.0
                        self._remote_shuffle = False
                        self._remote_repeat = "off"
                        self._bt_connected = False
                        self._bt_device_name = ""
                        if self._media_source == "remote":
                            self._has_media = False
                            self._track_title = ""
                            self._track_artist = ""
                            self._track_album = ""
                            self._track_duration_ms = 0
                            self._track_position_ms = 0
                            self._is_playing = False
                            self._track_progress = 0.0
                            self._optimistic_play_target = None
                            self._optimistic_play_timer.stop()
                            self._media_history.update_playback("", "", "", False, 0, 0)
                            self.mediaChanged.emit()
                        self.bluetoothChanged.emit()
                    self._query_media_and_bt_async()

            if updated:
                self._media_history.update_playback(
                    self._track_title,
                    self._track_artist,
                    self._track_album,
                    self._is_playing,
                    duration_ms=self._track_duration_ms,
                    position_ms=self._track_position_ms,
                )
                self.mediaChanged.emit()

        except Exception as exc:
            logger.debug("Error handling D-Bus properties changed: %s", exc)

    def _on_playback_tick(self) -> None:
        """
        High-frequency (500ms = mezzo secondo) playback ticker for smooth time and slider updates.
        Directly queries real-time position from local media player or smoothly advances remote media.
        """
        if not self._is_playing:
            return

        if self._media_source == "local":
            pos = self._local_player.position()
            if pos >= 0 and pos != self._track_position_ms:
                self._track_position_ms = pos
                if self._track_duration_ms > 0:
                    self._track_progress = min(1.0, max(0.0, pos / float(self._track_duration_ms)))
                self._media_history.update_playback(
                    self._track_title,
                    self._track_artist,
                    self._track_album,
                    self._is_playing,
                    duration_ms=self._track_duration_ms,
                    position_ms=self._track_position_ms,
                )
                self.mediaChanged.emit()
        elif self._has_media:
            # Advance remote track smoothly between Bluetooth AVRCP / MPRIS sync events
            if self._track_duration_ms > 0 and self._track_position_ms < self._track_duration_ms:
                new_pos = min(self._track_duration_ms, self._track_position_ms + 500)
                if new_pos != self._track_position_ms:
                    self._track_position_ms = new_pos
                    self._track_progress = min(1.0, max(0.0, new_pos / float(self._track_duration_ms)))
                    self.mediaChanged.emit()

    def _on_local_player_position_changed(self, pos_ms: int) -> None:
        if self._media_source != "local":
            return
        self._track_position_ms = pos_ms
        if self._track_duration_ms > 0:
            self._track_progress = min(1.0, max(0.0, pos_ms / float(self._track_duration_ms)))
        self._media_history.update_playback(
            self._track_title,
            self._track_artist,
            self._track_album,
            self._is_playing,
            duration_ms=self._track_duration_ms,
            position_ms=self._track_position_ms,
        )
        self.mediaChanged.emit()

    def _on_local_player_duration_changed(self, dur_ms: int) -> None:
        if self._media_source != "local":
            return
        if dur_ms > 0:
            self._track_duration_ms = dur_ms
            if self._track_position_ms > 0:
                self._track_progress = min(1.0, max(0.0, self._track_position_ms / float(dur_ms)))
            self.mediaChanged.emit()

    def _on_local_player_state_changed(self, state: QMediaPlayer.PlaybackState) -> None:
        if self._media_source != "local":
            return
        self._is_playing = (state == QMediaPlayer.PlaybackState.PlayingState)
        self._media_history.update_playback(
            self._track_title,
            self._track_artist,
            self._track_album,
            self._is_playing,
            duration_ms=self._track_duration_ms,
            position_ms=self._track_position_ms,
        )
        self.mediaChanged.emit()

    def _on_local_player_media_status_changed(self, status: QMediaPlayer.MediaStatus) -> None:
        if self._media_source != "local":
            return
        if status == QMediaPlayer.MediaStatus.EndOfMedia:
            if self._repeat_mode == "one":
                self._local_player.setPosition(0)
                self._local_player.play()
                self._is_playing = True
                self.mediaChanged.emit()
            elif self._repeat_mode == "all":
                self.nextTrack()
            else:  # "off"
                if self._shuffle_enabled:
                    self.nextTrack()
                elif self._current_local_track_idx + 1 < len(self._local_tracks):
                    self.nextTrack()
                else:
                    self._local_player.stop()
                    self._is_playing = False
                    self._track_position_ms = 0
                    self._track_progress = 0.0
                    self.mediaChanged.emit()

    def _query_media_and_bt_async(self) -> None:
        self._async_runner.run_async(MediaService.get_current_media, on_result=self._on_media_received)
        self._async_runner.run_async(BluetoothService.get_bluetooth_status, on_result=self._on_bt_received)

    def _on_media_received(self, media_info: Optional[dict]) -> None:
        if media_info:
            self._remote_has_media = True
            self._remote_title = media_info.get("title", "")
            self._remote_artist = media_info.get("artist", "")
            self._remote_album = media_info.get("album", "")
            if media_info.get("duration_ms"):
                self._remote_duration_ms = media_info.get("duration_ms", 0)
            if media_info.get("position_ms") is not None:
                self._remote_position_ms = media_info.get("position_ms", 0)
            self._remote_is_playing = media_info.get("is_playing", False)
            self._remote_progress = media_info.get("progress", 0.0)
            if "shuffle" in media_info:
                self._remote_shuffle = bool(media_info["shuffle"])
            if "repeat" in media_info:
                self._remote_repeat = str(media_info["repeat"])

        if self._media_source == "local":
            if media_info and media_info.get("is_playing", False):
                # Remote media started playing: pause local player and yield to remote
                self._local_player.pause()
                self._local_is_playing = False
                self._media_source = "remote"
                self._current_track_cover = ""
                self._current_track_lyrics = ""
                self._has_lyrics = False
                self.trackLyricsChanged.emit()
            else:
                # Keep playing local media
                return

        if media_info:
            self._has_media = True
            self._track_title = media_info.get("title", "")
            self._track_artist = media_info.get("artist", "")
            self._track_album = media_info.get("album", "")
            if media_info.get("duration_ms"):
                self._track_duration_ms = media_info.get("duration_ms", 0)
            if media_info.get("position_ms") is not None:
                self._track_position_ms = media_info.get("position_ms", 0)

            hw_playing = media_info.get("is_playing", False)
            if self._optimistic_play_target is not None:
                if hw_playing == self._optimistic_play_target:
                    # Hardware reached target: release lock
                    self._optimistic_play_target = None
                    self._optimistic_play_timer.stop()
                    self._is_playing = hw_playing
                # Else: keep self._is_playing locked to target until confirmed or timed out
            else:
                self._is_playing = hw_playing

            self._track_progress = media_info.get("progress", 0.0)

            # Sync remote Bluetooth/MPRIS shuffle and repeat states
            if "shuffle" in media_info and self._media_source != "local":
                new_shuf = bool(media_info["shuffle"])
                if self._shuffle_enabled != new_shuf:
                    self._shuffle_enabled = new_shuf
                    self.shuffleChanged.emit()

            if "repeat" in media_info and self._media_source != "local":
                new_rep = str(media_info["repeat"])
                if self._repeat_mode != new_rep:
                    self._repeat_mode = new_rep
                    self.repeatModeChanged.emit()

            self._media_history.update_playback(
                self._track_title,
                self._track_artist,
                self._track_album,
                self._is_playing,
                duration_ms=self._track_duration_ms,
                position_ms=self._track_position_ms,
            )
        elif self._bt_connected:
            self._has_media = True
            if not self._track_title:
                self._track_title = "Traccia Bluetooth"
                self._track_artist = self._bt_device_name or "Dispositivo Connesso"
                self._track_album = "Pronto per la riproduzione"
            if self._optimistic_play_target is None:
                self._is_playing = False
            self._track_progress = 0.0
        else:
            self._has_media = False
            self._track_title = ""
            self._track_artist = ""
            self._track_album = ""
            self._track_duration_ms = 0
            self._track_position_ms = 0
            self._is_playing = False
            self._track_progress = 0.0
            self._optimistic_play_target = None
            self._optimistic_play_timer.stop()
            self._media_history.update_playback("", "", "", False, 0, 0)
        self.mediaChanged.emit()

    def _on_bt_received(self, bt_info: dict) -> None:
        self._bt_powered = bt_info.get("powered", False)
        self._bt_connected = bt_info.get("connected", False)
        self._bt_device_name = bt_info.get("connected_device", "")
        self._bt_discoverable = bt_info.get("discoverable", False)
        self._bt_adapter_name = bt_info.get("adapter_name", "Raspberry Pi")
        self._bt_devices = bt_info.get("devices", [])
        self.bluetoothChanged.emit()
        self.bluetoothDevicesChanged.emit()

        if self._bt_connected and not self._has_media:
            self._has_media = True
            if not self._track_title:
                self._track_title = "Traccia Bluetooth"
                self._track_artist = self._bt_device_name or "Dispositivo Connesso"
                self._track_album = "Pronto per la riproduzione"
            self.mediaChanged.emit()

    def _query_system_and_obd_async(self) -> None:
        self._async_runner.run_async(HardwareMonitorService.get_cpu_temperature, on_result=self._on_cpu_temp_received)
        self._async_runner.run_async(OBDService.check_obd_status, on_result=self._on_obd_received)

    def _on_cpu_temp_received(self, temp: Optional[float]) -> None:
        if temp != self._cpu_temp:
            self._cpu_temp = temp
            self.cpuTemperatureChanged.emit()

    def _on_obd_received(self, obd_info: dict) -> None:
        self._obd_connected = obd_info.get("connected", False)
        self._obd_error = obd_info.get("error", "Disconnesso")
        self._speed_kmh = obd_info.get("speed_kmh")
        self._engine_rpm = obd_info.get("engine_rpm")
        self._battery_voltage = obd_info.get("battery_voltage")
        self.obdChanged.emit()

    @pyqtSlot()
    def scanWifi(self) -> None:
        """Triggers asynchronous Wi-Fi scan via nmcli."""
        self._async_runner.run_async(WiFiService.get_status_and_networks, on_result=self._on_wifi_received)

    @pyqtSlot()
    def rescanWifi(self) -> None:
        """Triggers active Wi-Fi rescan for nearby networks."""
        if self._wifi_scanning:
            return
        self._wifi_scanning = True
        self.wifiScanningChanged.emit(True)
        logger.info("Starting active Wi-Fi rescan...")

        def _scan_worker() -> dict:
            return WiFiService.get_status_and_networks(rescan=True)

        def _on_done(wifi_info: dict) -> None:
            self._wifi_scanning = False
            self.wifiScanningChanged.emit(False)
            logger.info("Active Wi-Fi rescan finished")
            self._on_wifi_received(wifi_info)

        self._async_runner.run_async(
            _scan_worker,
            on_result=_on_done,
            on_error=lambda err: _on_done({"error": str(err)})
        )

    def _on_wifi_received(self, wifi_info: dict) -> None:
        self._wifi_powered = wifi_info.get("powered", True)
        self._wifi_connected = wifi_info.get("connected", False)
        self._wifi_ssid = wifi_info.get("ssid", "")
        self._wifi_signal = wifi_info.get("signal", 0)
        self._wifi_ip = wifi_info.get("ip", "")
        self._wifi_networks = wifi_info.get("networks", [])
        self.wifiChanged.emit()
        self.wifiPoweredChanged.emit(self._wifi_powered)

    def _on_airplay_streaming_start(self, client_info: str) -> None:
        logger.info("AirPlay mirroring started from: %s", client_info)
        self._airplay_streaming = True
        self._airplay_client_info = client_info
        # Pause any local audio to prevent overlapping playback
        if self._is_playing:
            self.togglePlay()
        self.airplayStreamingChanged.emit(True)
        self.airplayChanged.emit()
        self.triggerAirPlayTouch()

    def _on_airplay_streaming_stop(self) -> None:
        logger.info("AirPlay mirroring ended")
        self._airplay_streaming = False
        self._airplay_show_exit_popup = False
        self._airplay_popup_timer.stop()
        self.airplayStreamingChanged.emit(False)
        self.airplayExitPopupChanged.emit(False)
        self.airplayChanged.emit()

    def _on_airplay_touch(self) -> None:
        if self._airplay_streaming:
            self.triggerAirPlayTouch()

    def _on_airplay_status(self, running: bool, streaming: bool, msg: str) -> None:
        self._airplay_running = running
        self._airplay_streaming = streaming
        self._airplay_status_message = msg
        self.airplayChanged.emit()
        self.airplayStreamingChanged.emit(streaming)

    def _on_airplay_popup_timeout(self) -> None:
        self._airplay_show_exit_popup = False
        self.airplayExitPopupChanged.emit(False)

    @pyqtSlot()
    def refreshWeather(self) -> None:
        """Triggers asynchronous weather fetch without dummy fallback."""
        self._async_runner.run_async(WeatherService.fetch_weather, on_result=self._on_weather_received)

    def _on_weather_received(self, data: dict) -> None:
        self._weather_available = data.get("success", False)
        self._weather_temp = data.get("temperature")
        self._weather_condition = data.get("condition", "Non disponibile")
        self._weather_icon = data.get("icon", "weather_offline")
        self.weatherChanged.emit()

    # -------------------------------------------------------------------------
    # Q_PROPERTY Getters (Strictly Real Data)
    # -------------------------------------------------------------------------

    # Audio
    @pyqtProperty(int, notify=volumeChanged)
    def volume(self) -> int:
        return self._volume

    @pyqtProperty(bool, notify=muteChanged)
    def isMuted(self) -> bool:
        return self._is_muted

    @pyqtProperty(int, notify=maxVolumeChanged)
    def maxVolume(self) -> int:
        return self._max_volume

    # Clock
    @pyqtProperty(str, notify=timeChanged)
    def currentTime(self) -> str:
        return self._current_time

    @pyqtProperty(str, notify=dateChanged)
    def currentDate(self) -> str:
        return self._current_date

    # CPU Temperature (Real sensor or null/error)
    @pyqtProperty(str, notify=cpuTemperatureChanged)
    def cpuTemperatureText(self) -> str:
        return f"{self._cpu_temp:.0f}°C" if self._cpu_temp is not None else "--°C"

    # Weather
    @pyqtProperty(bool, notify=weatherChanged)
    def weatherAvailable(self) -> bool:
        return self._weather_available

    @pyqtProperty(str, notify=weatherChanged)
    def weatherTemperatureText(self) -> str:
        return f"{self._weather_temp:.1f}°C" if self._weather_temp is not None else "--°C"

    @pyqtProperty(str, notify=weatherChanged)
    def weatherCondition(self) -> str:
        return self._weather_condition

    @pyqtProperty(str, notify=weatherChanged)
    def weatherIcon(self) -> str:
        return self._weather_icon if self._weather_available else "cloud_off"

    # Media (MPRIS / Bluetooth)
    @pyqtProperty(bool, notify=mediaChanged)
    def hasMedia(self) -> bool:
        return self._has_media

    @pyqtProperty(str, notify=mediaChanged)
    def trackTitle(self) -> str:
        return self._track_title

    @pyqtProperty(str, notify=mediaChanged)
    def trackArtist(self) -> str:
        return self._track_artist

    @pyqtProperty(str, notify=mediaChanged)
    def trackAlbum(self) -> str:
        return self._track_album

    @pyqtProperty(bool, notify=mediaChanged)
    def isPlaying(self) -> bool:
        return self._is_playing

    @pyqtProperty(float, notify=mediaChanged)
    def trackProgress(self) -> float:
        return self._track_progress

    @pyqtProperty(str, notify=mediaChanged)
    def trackPositionFormatted(self) -> str:
        sec = max(0, self._track_position_ms // 1000)
        return f"{sec // 60:02d}:{sec % 60:02d}"

    @pyqtProperty(str, notify=mediaChanged)
    def trackDurationFormatted(self) -> str:
        sec = max(0, self._track_duration_ms // 1000)
        return f"{sec // 60:02d}:{sec % 60:02d}"

    @pyqtProperty(int, notify=mediaChanged)
    def trackPositionMs(self) -> int:
        return self._track_position_ms

    @pyqtProperty(int, notify=mediaChanged)
    def trackDurationMs(self) -> int:
        return self._track_duration_ms

    @pyqtProperty(str, notify=mediaChanged)
    def currentTrackCover(self) -> str:
        return self._current_track_cover

    @pyqtProperty(str, notify=trackLyricsChanged)
    def currentTrackLyrics(self) -> str:
        return self._current_track_lyrics

    @pyqtProperty(bool, notify=trackLyricsChanged)
    def hasLyrics(self) -> bool:
        return self._has_lyrics

    @pyqtProperty(bool, notify=shuffleChanged)
    def shuffleEnabled(self) -> bool:
        return self._shuffle_enabled

    @pyqtProperty(str, notify=repeatModeChanged)
    def repeatMode(self) -> str:
        return self._repeat_mode

    @pyqtProperty(str, notify=mediaSubViewChanged)
    def mediaSubView(self) -> str:
        return self._media_sub_view

    @pyqtProperty(str, notify=mediaChanged)
    def mediaSource(self) -> str:
        return self._media_source

    @pyqtProperty("QVariantList", notify=localMusicChanged)
    def localMusicTracks(self) -> list:
        return self._local_tracks

    @pyqtProperty("QVariantList", notify=mediaHistoryChanged)
    def mediaHistoryList(self) -> list:
        return self._media_history_list

    # OBD-II Vehicle Telemetry
    @pyqtProperty(bool, notify=obdChanged)
    def obdConnected(self) -> bool:
        return self._obd_connected

    @pyqtProperty(str, notify=obdChanged)
    def obdError(self) -> str:
        return self._obd_error

    @pyqtProperty(str, notify=obdChanged)
    def speedText(self) -> str:
        return str(self._speed_kmh) if self._speed_kmh is not None else "--"

    @pyqtProperty(str, notify=obdChanged)
    def rpmText(self) -> str:
        return str(self._engine_rpm) if self._engine_rpm is not None else "--"

    @pyqtProperty(str, notify=obdChanged)
    def batteryVoltageText(self) -> str:
        return f"{self._battery_voltage:.1f}V" if self._battery_voltage is not None else "--V"

    # Wi-Fi (nmcli)
    @pyqtProperty(bool, notify=wifiPoweredChanged)
    def wifiPowered(self) -> bool:
        return self._wifi_powered

    @pyqtProperty(bool, notify=wifiChanged)
    def wifiConnected(self) -> bool:
        return self._wifi_connected

    @pyqtProperty(str, notify=wifiChanged)
    def wifiSsid(self) -> str:
        return self._wifi_ssid if self._wifi_connected else "Wi-Fi: Disconnesso"

    @pyqtProperty(int, notify=wifiChanged)
    def wifiSignal(self) -> int:
        return self._wifi_signal

    @pyqtProperty("QVariantList", notify=wifiChanged)
    def availableWifiNetworks(self) -> list:
        return self._wifi_networks

    @pyqtProperty(bool, notify=wifiConnectingChanged)
    def wifiConnecting(self) -> bool:
        return self._wifi_connecting

    @pyqtProperty(bool, notify=wifiScanningChanged)
    def wifiScanning(self) -> bool:
        return self._wifi_scanning

    @pyqtProperty(str, notify=wifiStatusMessageChanged)
    def wifiStatusMessage(self) -> str:
        return self._wifi_status_message

    @pyqtProperty(str, notify=wifiChanged)
    def wifiIp(self) -> str:
        return self._wifi_ip

    # AirPlay Properties (UxPlay)
    @pyqtProperty(bool, notify=airplayChanged)
    def airplayAvailable(self) -> bool:
        return self._airplay_available

    @pyqtProperty(bool, notify=airplayChanged)
    def airplayRunning(self) -> bool:
        return self._airplay_running

    @pyqtProperty(bool, notify=airplayStreamingChanged)
    def airplayStreaming(self) -> bool:
        return self._airplay_streaming

    @pyqtProperty(str, notify=airplayChanged)
    def airplayServerName(self) -> str:
        return self._airplay_service.server_name

    @pyqtProperty(str, notify=airplayChanged)
    def airplayClientInfo(self) -> str:
        return self._airplay_client_info

    @pyqtProperty(str, notify=airplayChanged)
    def airplayStatusMessage(self) -> str:
        return self._airplay_status_message

    @pyqtProperty(str, notify=airplayChanged)
    def airplayDecoder(self) -> str:
        return self._airplay_decoder

    @pyqtProperty(bool, notify=airplayExitPopupChanged)
    def airplayShowExitPopup(self) -> bool:
        return self._airplay_show_exit_popup

    # Software Update Properties
    @pyqtProperty(bool, notify=updateStateChanged)
    def updateRunning(self) -> bool:
        return self._update_running

    @pyqtProperty(str, notify=updateStateChanged)
    def updateStatusMessage(self) -> str:
        return self._update_status_message

    @pyqtProperty(bool, notify=updateStateChanged)
    def updateSuccess(self) -> bool:
        return self._update_success

    # Bluetooth (BlueZ)
    @pyqtProperty(bool, notify=bluetoothChanged)
    def bluetoothPowered(self) -> bool:
        return self._bt_powered

    @pyqtProperty(bool, notify=bluetoothChanged)
    def bluetoothConnected(self) -> bool:
        return self._bt_connected

    @pyqtProperty(str, notify=bluetoothChanged)
    def bluetoothDeviceName(self) -> str:
        if not self._bt_powered:
            return "Bluetooth: Disattivato"
        return self._bt_device_name if self._bt_connected else "Bluetooth: Non Connesso"

    @pyqtProperty(bool, notify=bluetoothChanged)
    def bluetoothDiscoverable(self) -> bool:
        return self._bt_discoverable

    @pyqtProperty(str, notify=bluetoothChanged)
    def bluetoothAdapterName(self) -> str:
        return self._bt_adapter_name

    @pyqtProperty(bool, notify=bluetoothScanningChanged)
    def bluetoothScanning(self) -> bool:
        return self._bt_scanning

    @pyqtProperty("QVariantList", notify=bluetoothDevicesChanged)
    def availableBluetoothDevices(self) -> list:
        return self._bt_devices

    # Application Session File Logs
    @pyqtProperty(str, notify=appLogsChanged)
    def currentLogFilename(self) -> str:
        return self._current_log_file

    @pyqtProperty("QVariantList", notify=appLogsChanged)
    def appLogs(self) -> list:
        return self._app_logs

    # UI Navigation
    @pyqtProperty(str, notify=currentViewChanged)
    def currentView(self) -> str:
        return self._current_view

    # -------------------------------------------------------------------------
    # QML Slots
    # -------------------------------------------------------------------------

    @pyqtSlot()
    def clearLogs(self) -> None:
        """Clears the contents of the current session log file on disk."""
        self._log_service.clear_current_log()
        self._app_logs = []
        self.appLogsChanged.emit()

    @pyqtSlot()
    def refreshLogs(self) -> None:
        """Refreshes and re-reads the log file from disk."""
        self._sync_logs_to_qml()

    @pyqtSlot(int)
    def setMaxVolume(self, level: int) -> None:
        """Sets the maximum volume limit (100% to 200%) and persists in settings."""
        clamped = max(100, min(200, int(level)))
        if clamped != self._max_volume:
            self._max_volume = clamped
            try:
                self._settings.setValue("audio/maxVolume", self._max_volume)
            except Exception as exc:
                logger.warning("Failed saving maxVolume setting: %s", exc)
            self.maxVolumeChanged.emit(self._max_volume)
            logger.info("Maximum volume limit set to %d%%", self._max_volume)
            if self._volume > self._max_volume:
                self.setVolume(self._max_volume)

    @pyqtSlot(int)
    def setVolume(self, level: int) -> None:
        clamped = max(0, min(self._max_volume, int(level)))
        if clamped > 0:
            self._last_nonzero_volume = clamped

        # If user increases volume while muted, automatically unmute
        if self._is_muted and clamped > 0:
            self._is_muted = False
            self.muteChanged.emit(self._is_muted)
            self._async_runner.run_async(AudioService.set_mute, False)

        if hasattr(self, "_audio_output"):
            self._audio_output.setVolume(min(1.0, clamped / 100.0))

        if clamped != self._volume:
            self._volume = clamped
            self.volumeChanged.emit(self._volume)
            self._pending_volume = clamped
            self._volume_debounce_timer.start()

    def _flush_volume_to_hardware(self) -> None:
        if self._pending_volume is not None:
            target = self._pending_volume
            self._pending_volume = None
            self._async_runner.run_async(AudioService.set_volume, target, self._max_volume)

    def _unsuppress_audio_sync(self) -> None:
        self._audio_sync_suppressed = False

    @pyqtSlot()
    def toggleMute(self) -> None:
        self._audio_sync_suppressed = True
        QTimer.singleShot(2000, self._unsuppress_audio_sync)

        self._is_muted = not self._is_muted

        # When unmuting, if volume was 0%, restore the last non-zero volume
        if not self._is_muted and self._volume <= 0:
            self._volume = self._last_nonzero_volume if self._last_nonzero_volume > 0 else 50
            self.volumeChanged.emit(self._volume)
            self._async_runner.run_async(AudioService.set_volume, self._volume)

        if hasattr(self, "_audio_output"):
            self._audio_output.setMuted(self._is_muted)

        self.muteChanged.emit(self._is_muted)
        self._async_runner.run_async(AudioService.set_mute, self._is_muted)

    @pyqtSlot(str)
    def changeView(self, view_name: str) -> None:
        if view_name != self._current_view:
            self._current_view = view_name
            self.currentViewChanged.emit(self._current_view)
            if view_name == "airplay" and self._airplay_available and not self._airplay_running:
                self.startAirPlay()

    @pyqtSlot()
    def toggleMediaSource(self) -> None:
        """
        Swaps the active media player display between Bluetooth ('remote') and
        the internal Raspberry Pi music library ('local'), allowing inspection
        and control of either source even when both are paused or in standby.
        """
        if self._media_source == "local":
            # Cache active local display state
            self._local_has_media = self._has_media
            self._local_title = self._track_title
            self._local_artist = self._track_artist
            self._local_album = self._track_album
            self._local_duration_ms = self._track_duration_ms
            self._local_position_ms = self._track_position_ms
            self._local_progress = self._track_progress
            self._local_is_playing = self._is_playing
            self._local_cover = self._current_track_cover
            self._local_lyrics = self._current_track_lyrics
            self._local_has_lyrics = self._has_lyrics
            self._local_shuffle = self._shuffle_enabled
            self._local_repeat = self._repeat_mode

            # Switch active view to remote
            self._media_source = "remote"
            self._has_media = self._remote_has_media
            self._track_title = self._remote_title
            self._track_artist = self._remote_artist
            self._track_album = self._remote_album
            self._track_duration_ms = self._remote_duration_ms
            self._track_position_ms = self._remote_position_ms
            self._track_progress = self._remote_progress
            self._is_playing = self._remote_is_playing
            self._current_track_cover = ""
            self._current_track_lyrics = ""
            self._has_lyrics = False
            self._shuffle_enabled = self._remote_shuffle
            self._repeat_mode = self._remote_repeat

            logger.info("Swapped media display to Bluetooth audio (remote)")
            self.mediaChanged.emit()
            self.trackLyricsChanged.emit()
            self.shuffleChanged.emit()
            self.repeatModeChanged.emit()

            # Refresh remote state in background
            self._query_media_and_bt_async()
        else:
            # Cache active remote display state
            self._remote_has_media = self._has_media
            self._remote_title = self._track_title
            self._remote_artist = self._track_artist
            self._remote_album = self._track_album
            self._remote_duration_ms = self._track_duration_ms
            self._remote_position_ms = self._track_position_ms
            self._remote_progress = self._track_progress
            self._remote_is_playing = self._is_playing
            self._remote_shuffle = self._shuffle_enabled
            self._remote_repeat = self._repeat_mode

            # Switch active view to local
            self._media_source = "local"
            if not self._local_title and self._local_tracks:
                idx = max(0, self._current_local_track_idx)
                tr = self._local_tracks[idx]
                self._current_local_track_idx = idx
                self._local_has_media = True
                self._local_title = tr.get("title", "")
                self._local_artist = tr.get("artist", "")
                self._local_album = tr.get("album", "")
                self._local_cover = tr.get("cover_url", "")
                self._local_lyrics = tr.get("lyrics", "")
                self._local_has_lyrics = tr.get("has_lyrics", False)
                self._local_duration_ms = int(tr.get("duration_seconds", 0) * 1000)
                self._local_position_ms = 0
                self._local_progress = 0.0
                self._local_is_playing = (self._local_player.playbackState() == QMediaPlayer.PlaybackState.PlayingState)

            self._has_media = self._local_has_media
            self._track_title = self._local_title
            self._track_artist = self._local_artist
            self._track_album = self._local_album
            self._track_duration_ms = self._local_duration_ms
            self._track_position_ms = self._local_position_ms
            self._track_progress = self._local_progress
            self._is_playing = self._local_is_playing
            self._current_track_cover = self._local_cover
            self._current_track_lyrics = self._local_lyrics
            self._has_lyrics = self._local_has_lyrics
            self._shuffle_enabled = self._local_shuffle
            self._repeat_mode = self._local_repeat

            logger.info("Swapped media display to Raspberry Pi local library (local)")
            self.mediaChanged.emit()
            self.trackLyricsChanged.emit()
            self.shuffleChanged.emit()
            self.repeatModeChanged.emit()

    @pyqtSlot()
    def togglePlay(self) -> None:
        """
        Toggles playback for local music player or remote Bluetooth/MPRIS player.
        """
        if self._media_source == "local":
            if self._local_player.playbackState() == QMediaPlayer.PlaybackState.PlayingState:
                self._local_player.pause()
                self._is_playing = False
                self._local_is_playing = False
            else:
                if self._local_player.source().isEmpty() and self._local_tracks:
                    idx = max(0, self._current_local_track_idx)
                    self.playLocalTrack(self._local_tracks[idx]["file_path"])
                    return
                self._local_player.play()
                self._is_playing = True
                self._local_is_playing = True
            self.mediaChanged.emit()
            return

        if not self._has_media:
            return

        # Flip to desired target state and lock against AVRCP transit bounce
        target_state = not self._is_playing
        self._is_playing = target_state
        self._remote_is_playing = target_state
        self._optimistic_play_target = target_state
        self._optimistic_play_timer.start()
        self.mediaChanged.emit()

        # Send hardware command asynchronously
        self._async_runner.run_async(lambda: MediaService.send_player_command("PlayPause"))

    @pyqtSlot()
    def toggleShuffle(self) -> None:
        """Toggles shuffle mode on/off for both local player and remote Bluetooth/MPRIS player."""
        self._shuffle_enabled = not self._shuffle_enabled
        if self._media_source == "local":
            self._local_shuffle = self._shuffle_enabled
        else:
            self._remote_shuffle = self._shuffle_enabled
        logger.info("Shuffle toggled (%s): %s", self._media_source, self._shuffle_enabled)
        self.shuffleChanged.emit()
        self.mediaChanged.emit()

        # Dispatches request to Bluetooth (AVRCP SetPlayerApplicationSettingValue) and MPRIS
        if self._media_source != "local":
            self._async_runner.run_async(lambda: MediaService.set_player_shuffle(self._shuffle_enabled))

    @pyqtSlot()
    def toggleRepeat(self) -> None:
        """
        Cycles repeat mode: 'off' -> 'all' (entire playlist) -> 'one' (current track) -> 'off'.
        Dispatches request to Bluetooth (AVRCP SetPlayerApplicationSettingValue) and MPRIS.
        """
        if self._repeat_mode == "off":
            self._repeat_mode = "all"
        elif self._repeat_mode == "all":
            self._repeat_mode = "one"
        else:
            self._repeat_mode = "off"
        if self._media_source == "local":
            self._local_repeat = self._repeat_mode
        else:
            self._remote_repeat = self._repeat_mode
        logger.info("Repeat mode cycled (%s) to: %s", self._media_source, self._repeat_mode)
        self.repeatModeChanged.emit()
        self.mediaChanged.emit()

        # Dispatches request to Bluetooth (AVRCP SetPlayerApplicationSettingValue) and MPRIS
        if self._media_source != "local":
            self._async_runner.run_async(lambda: MediaService.set_player_repeat(self._repeat_mode))

    @pyqtSlot()
    def nextTrack(self) -> None:
        """Dispatches Next track command for local or remote player."""
        if self._media_source == "local" and self._local_tracks:
            if self._shuffle_enabled and len(self._local_tracks) > 1:
                candidates = [i for i in range(len(self._local_tracks)) if i != self._current_local_track_idx]
                next_idx = random.choice(candidates)
            else:
                next_idx = (self._current_local_track_idx + 1) % len(self._local_tracks)
            next_path = self._local_tracks[next_idx]["file_path"]
            self.playLocalTrack(next_path)
            return

        if not self._has_media:
            return

        self._async_runner.run_async(lambda: MediaService.send_player_command("Next"))

        # Burst queries: phone AVRCP track change typically takes 150-400ms
        QTimer.singleShot(100, self._query_media_and_bt_async)
        QTimer.singleShot(250, self._query_media_and_bt_async)
        QTimer.singleShot(500, self._query_media_and_bt_async)
        QTimer.singleShot(1000, self._query_media_and_bt_async)

    @pyqtSlot()
    def previousTrack(self) -> None:
        """Dispatches Previous track command for local or remote player."""
        if self._media_source == "local" and self._local_tracks:
            # If past 3 seconds, previous track restarts the current song
            if self._track_position_ms > 3000:
                self.seekProgress(0.0)
                return
            if self._shuffle_enabled and len(self._local_tracks) > 1:
                candidates = [i for i in range(len(self._local_tracks)) if i != self._current_local_track_idx]
                prev_idx = random.choice(candidates)
            else:
                prev_idx = (self._current_local_track_idx - 1) % len(self._local_tracks)
            prev_path = self._local_tracks[prev_idx]["file_path"]
            self.playLocalTrack(prev_path)
            return

        if not self._has_media:
            return

        self._async_runner.run_async(lambda: MediaService.send_player_command("Previous"))

        # Burst queries
        QTimer.singleShot(100, self._query_media_and_bt_async)
        QTimer.singleShot(250, self._query_media_and_bt_async)
        QTimer.singleShot(500, self._query_media_and_bt_async)
        QTimer.singleShot(1000, self._query_media_and_bt_async)

    @pyqtSlot(str)
    def playLocalTrack(self, file_path: str) -> None:
        """Plays an audio track from the Raspberry Pi local music library."""
        target_track = None
        target_idx = -1
        for idx, tr in enumerate(self._local_tracks):
            if tr.get("file_path") == file_path or tr.get("id") == file_path:
                target_track = tr
                target_idx = idx
                break

        if not target_track:
            logger.warning("Local track not found: %s", file_path)
            return

        self._media_source = "local"
        self._current_local_track_idx = target_idx
        self._has_media = True
        self._track_title = target_track.get("title", "")
        self._track_artist = target_track.get("artist", "")
        self._track_album = target_track.get("album", "")
        self._current_track_cover = target_track.get("cover_url", "")
        self._current_track_lyrics = target_track.get("lyrics", "")
        self._has_lyrics = target_track.get("has_lyrics", False)
        self._track_duration_ms = int(target_track.get("duration_seconds", 0) * 1000)
        self._track_position_ms = 0
        self._track_progress = 0.0

        # Update local cache
        self._local_has_media = True
        self._local_title = self._track_title
        self._local_artist = self._track_artist
        self._local_album = self._track_album
        self._local_cover = self._current_track_cover
        self._local_lyrics = self._current_track_lyrics
        self._local_has_lyrics = self._has_lyrics
        self._local_duration_ms = self._track_duration_ms
        self._local_position_ms = 0
        self._local_progress = 0.0
        self._local_is_playing = True

        # Load into QMediaPlayer
        self._local_player.setSource(QUrl.fromLocalFile(target_track["file_path"]))
        self._local_player.play()
        self._is_playing = True

        self._media_history.update_playback(
            self._track_title,
            self._track_artist,
            self._track_album,
            True,
            duration_ms=self._track_duration_ms,
            position_ms=0,
        )
        self.mediaChanged.emit()
        self.trackLyricsChanged.emit()
        logger.info("Started local playback of '%s' by '%s'", self._track_title, self._track_artist)

    @pyqtSlot()
    def scanLocalMusic(self) -> None:
        """Scans the music/ directory asynchronously and updates localMusicTracks."""
        self._async_runner.run_async(self._local_music_service.scan_tracks, on_result=self._on_local_music_scanned)

    def _on_local_music_scanned(self, tracks: list) -> None:
        self._local_tracks = tracks or []
        if self._local_tracks and not self._local_title:
            tr = self._local_tracks[0]
            self._current_local_track_idx = 0
            self._local_has_media = True
            self._local_title = tr.get("title", "")
            self._local_artist = tr.get("artist", "")
            self._local_album = tr.get("album", "")
            self._local_cover = tr.get("cover_url", "")
            self._local_lyrics = tr.get("lyrics", "")
            self._local_has_lyrics = tr.get("has_lyrics", False)
            self._local_duration_ms = int(tr.get("duration_seconds", 0) * 1000)
            self._local_position_ms = 0
            self._local_progress = 0.0
            if self._media_source == "local":
                self._has_media = True
                self._track_title = self._local_title
                self._track_artist = self._local_artist
                self._track_album = self._local_album
                self._current_track_cover = self._local_cover
                self._current_track_lyrics = self._local_lyrics
                self._has_lyrics = self._local_has_lyrics
                self._track_duration_ms = self._local_duration_ms
                self._track_position_ms = self._local_position_ms
                self._track_progress = self._local_progress
                self.mediaChanged.emit()
                self.trackLyricsChanged.emit()
        self.localMusicChanged.emit()

    @pyqtSlot()
    def refreshMediaHistory(self) -> None:
        """Aggregates all history tracks asynchronously across all sessions."""
        self._async_runner.run_async(self._media_history.get_all_history_tracks, on_result=self._on_history_received)

    def _on_history_received(self, history: list) -> None:
        self._media_history_list = history or []
        self.mediaHistoryChanged.emit()

    @pyqtSlot(str)
    def setMediaSubView(self, sub_view: str) -> None:
        """Switches media screen sub-view: 'player', 'library', 'history'."""
        if sub_view != self._media_sub_view:
            self._media_sub_view = sub_view
            if sub_view == "library":
                self.scanLocalMusic()
            elif sub_view == "history":
                self.refreshMediaHistory()
            self.mediaSubViewChanged.emit(self._media_sub_view)

    @pyqtSlot(float)
    def seekProgress(self, progress: float) -> None:
        """
        Seeks playback position using a normalized progress float (0.0 to 1.0).
        Works with local tracks and updates history & UI reactively.
        """
        clamped = max(0.0, min(1.0, float(progress)))
        self._track_progress = clamped
        if self._track_duration_ms > 0:
            target_ms = int(clamped * self._track_duration_ms)
            self._track_position_ms = target_ms
            if self._media_source == "local":
                self._local_player.setPosition(target_ms)
                self._media_history.update_playback(
                    self._track_title,
                    self._track_artist,
                    self._track_album,
                    self._is_playing,
                    duration_ms=self._track_duration_ms,
                    position_ms=self._track_position_ms,
                )
        self.mediaChanged.emit()

    @pyqtSlot(str, str)
    def connectWifi(self, ssid: str, password: str) -> None:
        """Asynchronously initiates connection to a Wi-Fi network with live UI status."""
        self._wifi_connecting = True
        self._wifi_status_message = f"Connessione a '{ssid}' in corso..."
        self.wifiConnectingChanged.emit(True)
        self.wifiStatusMessageChanged.emit(self._wifi_status_message)
        logger.info("Connecting to Wi-Fi: %s", ssid)

        def _on_result(res: tuple) -> None:
            success, msg = res
            self._wifi_connecting = False
            self._wifi_status_message = msg
            self.wifiConnectingChanged.emit(False)
            self.wifiStatusMessageChanged.emit(self._wifi_status_message)
            if success:
                self.wifiConnectedSuccessfully.emit(ssid)
            logger.info("Wi-Fi connection result: %s - %s", success, msg)
            self.scanWifi()

        self._async_runner.run_async(
            WiFiService.connect_to_network,
            ssid,
            password,
            on_result=_on_result,
            on_error=lambda err: _on_result((False, str(err)))
        )

    @pyqtSlot(str)
    def connectSavedWifi(self, ssid: str) -> None:
        """Asynchronously connects to a pre-saved network profile without requiring a password."""
        self._wifi_connecting = True
        self._wifi_status_message = f"Connessione a '{ssid}' (profilo salvato)..."
        self.wifiConnectingChanged.emit(True)
        self.wifiStatusMessageChanged.emit(self._wifi_status_message)
        logger.info("Connecting to saved Wi-Fi: %s", ssid)

        def _on_result(res: tuple) -> None:
            success, msg = res
            self._wifi_connecting = False
            self._wifi_status_message = msg
            self.wifiConnectingChanged.emit(False)
            self.wifiStatusMessageChanged.emit(self._wifi_status_message)
            if success:
                self.wifiConnectedSuccessfully.emit(ssid)
            logger.info("Saved Wi-Fi connection result: %s - %s", success, msg)
            self.scanWifi()

        self._async_runner.run_async(
            WiFiService.connect_saved_network,
            ssid,
            on_result=_on_result,
            on_error=lambda err: _on_result((False, str(err)))
        )

    @pyqtSlot(bool)
    def setWifiPowered(self, enabled: bool) -> None:
        """Enables or disables the Wi-Fi radio."""
        logger.info("Setting Wi-Fi radio power to %s", enabled)
        self._wifi_powered = enabled
        self.wifiPoweredChanged.emit(enabled)

        def _on_done(res: tuple) -> None:
            self.scanWifi()

        self._async_runner.run_async(
            WiFiService.set_wifi_power,
            enabled,
            on_result=_on_done
        )

    @pyqtSlot()
    def toggleWifiPower(self) -> None:
        """Toggles Wi-Fi radio power on or off."""
        self.setWifiPowered(not self._wifi_powered)

    @pyqtSlot()
    def disconnectWifi(self) -> None:
        """Disconnects the currently active Wi-Fi connection."""
        logger.info("Disconnecting from Wi-Fi...")

        def _on_done(res: tuple) -> None:
            self.scanWifi()

        self._async_runner.run_async(
            WiFiService.disconnect_network,
            None,
            on_result=_on_done
        )

    @pyqtSlot(str)
    def disconnectWifiNetwork(self, ssid: str) -> None:
        """Disconnects from a specific Wi-Fi SSID."""
        logger.info("Disconnecting from Wi-Fi network: %s", ssid)

        def _on_done(res: tuple) -> None:
            self.scanWifi()

        self._async_runner.run_async(
            WiFiService.disconnect_network,
            ssid,
            on_result=_on_done
        )

    @pyqtSlot(str)
    def forgetWifi(self, ssid: str) -> None:
        """Removes a saved Wi-Fi connection profile from NetworkManager."""
        logger.info("Forgetting Wi-Fi network: %s", ssid)

        def _on_done(res: tuple) -> None:
            self.scanWifi()

        self._async_runner.run_async(
            WiFiService.forget_network,
            ssid,
            on_result=_on_done
        )

    @pyqtSlot(bool)
    def setBluetoothPowered(self, enabled: bool) -> None:
        """Turns the Bluetooth adapter power on or off."""
        logger.info("Setting Bluetooth adapter power to %s", enabled)
        self._bt_powered = enabled
        self.bluetoothChanged.emit()

        def _on_done(res: tuple) -> None:
            self._query_media_and_bt_async()

        self._async_runner.run_async(
            BluetoothService.set_power,
            enabled,
            on_result=_on_done
        )

    @pyqtSlot()
    def toggleBluetoothPower(self) -> None:
        """Toggles Bluetooth adapter power on or off."""
        self.setBluetoothPowered(not self._bt_powered)

    @pyqtSlot(str)
    def forgetBluetoothDevice(self, mac: str) -> None:
        """Removes and unpairs a Bluetooth device from BlueZ cache."""
        logger.info("Forgetting Bluetooth device: %s", mac)

        def _on_done(res: tuple) -> None:
            self._query_media_and_bt_async()

        self._async_runner.run_async(
            BluetoothService.remove_device,
            mac,
            on_result=_on_done
        )

    @pyqtSlot()
    def toggleBluetoothDiscoverable(self) -> None:
        """Toggles Bluetooth visibility so smartphones can discover and pair with the infotainment system."""
        target_state = not self._bt_discoverable
        logger.info("Setting Bluetooth discoverable to %s", target_state)

        def _on_done(res: tuple) -> None:
            self._query_media_and_bt_async()

        self._async_runner.run_async(
            BluetoothService.set_discoverable,
            target_state,
            on_result=_on_done
        )

    @pyqtSlot()
    def scanBluetooth(self) -> None:
        """Triggers active Bluetooth discovery scan for nearby devices."""
        if self._bt_scanning:
            return
        self._bt_scanning = True
        self.bluetoothScanningChanged.emit(True)
        logger.info("Starting active Bluetooth scan (6s)...")

        def _on_scan_finished(res: tuple) -> None:
            self._bt_scanning = False
            self.bluetoothScanningChanged.emit(False)
            logger.info("Bluetooth scan finished: %s", res)
            self._query_media_and_bt_async()

        self._async_runner.run_async(
            BluetoothService.scan_devices,
            6,
            on_result=_on_scan_finished,
            on_error=lambda err: _on_scan_finished((False, str(err)))
        )

    @pyqtSlot(str)
    def connectBluetoothDevice(self, mac: str) -> None:
        """Asynchronously connects to a paired or discovered Bluetooth device."""
        logger.info("Connecting to Bluetooth device: %s", mac)
        self._async_runner.run_async(
            BluetoothService.connect_device,
            mac,
            on_result=lambda res: self._query_media_and_bt_async()
        )

    @pyqtSlot(str)
    def disconnectBluetoothDevice(self, mac: str) -> None:
        """Asynchronously disconnects a Bluetooth device."""
        logger.info("Disconnecting Bluetooth device: %s", mac)
        self._async_runner.run_async(
            BluetoothService.disconnect_device,
            mac,
            on_result=lambda res: self._query_media_and_bt_async()
        )

    @pyqtSlot()
    def restartApp(self) -> None:
        """
        Re-launches the current infotainment application process (frontend + backend) in place.
        Does NOT reboot or affect the Linux operating system.
        """
        logger.warning("Application restart requested by user.")
        try:
            self._airplay_service.stop_server()
            os.execv(sys.executable, [sys.executable] + sys.argv)
        except Exception as exc:
            logger.error("Failed to restart application: %s", exc)

    @pyqtSlot()
    def rebootSystem(self) -> None:
        """
        Reboots the host operating system (Raspberry Pi).
        Only triggered after explicit user confirmation in UI.
        """
        logger.warning("Host system reboot confirmed and initiated.")
        try:
            self._airplay_service.stop_server()
            subprocess.run(["systemctl", "reboot"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except Exception as exc:
            logger.error("Failed to execute systemctl reboot: %s", exc)

    @pyqtSlot()
    def shutdownSystem(self) -> None:
        """Legacy alias: calls restartApp() safely instead of muting audio."""
        self.restartApp()

    # AirPlay Slots
    @pyqtSlot()
    def startAirPlay(self) -> None:
        """Starts the UxPlay AirPlay mirroring server."""
        self._airplay_service.start_server(
            on_streaming_start=self._on_airplay_streaming_start,
            on_streaming_stop=self._on_airplay_streaming_stop,
            on_touch=self._on_airplay_touch,
            on_status=self._on_airplay_status,
        )
        self._airplay_running = self._airplay_service.is_running
        self._airplay_status_message = self._airplay_service.status_message
        self.airplayChanged.emit()

    @pyqtSlot()
    def stopAirPlay(self) -> None:
        """Stops the active AirPlay stream or server."""
        self._airplay_service.stop_server()
        self._airplay_running = False
        self._airplay_streaming = False
        self._airplay_show_exit_popup = False
        self._airplay_popup_timer.stop()
        self.airplayStreamingChanged.emit(False)
        self.airplayExitPopupChanged.emit(False)
        self.airplayChanged.emit()

    @pyqtSlot()
    def stopAirPlayStream(self) -> None:
        """Stops the active AirPlay video stream and returns to listening mode."""
        self._airplay_service.stop_current_stream()
        self._airplay_streaming = False
        self._airplay_show_exit_popup = False
        self._airplay_popup_timer.stop()
        self.airplayStreamingChanged.emit(False)
        self.airplayExitPopupChanged.emit(False)
        self.airplayChanged.emit()

    @pyqtSlot(str)
    def setAirPlayDecoder(self, mode: str) -> None:
        """Sets AirPlay decoder mode: 'software' (-avdec, faithful colors) or 'hardware' (-bt709)."""
        if mode in ("software", "hardware") and mode != self._airplay_decoder:
            self._airplay_decoder = mode
            self._settings.setValue("airplay/decoder", mode)
            self._airplay_service.decoder_mode = mode
            self.airplayChanged.emit()

    @pyqtSlot()
    def toggleAirPlay(self) -> None:
        """Toggles the AirPlay receiver on/off."""
        if self._airplay_running:
            self.stopAirPlay()
        else:
            self.startAirPlay()

    @pyqtSlot()
    def triggerAirPlayTouch(self) -> None:
        """Displays the top-right exit popup during streaming with a 4s auto-hide countdown."""
        self._airplay_show_exit_popup = True
        self.airplayExitPopupChanged.emit(True)
        self._airplay_popup_timer.start()

    @pyqtSlot()
    def hideAirPlayExitPopup(self) -> None:
        """Hides the top-right exit popup."""
        self._airplay_popup_timer.stop()
        self._airplay_show_exit_popup = False
        self.airplayExitPopupChanged.emit(False)

    # Software Update Slots
    @pyqtSlot()
    def checkAndUpdateApp(self) -> None:
        """Pulls latest software update from GitHub via scripts/update_infotainment.sh."""
        if self._update_running:
            return

        self._update_running = True
        self._update_status_message = "Verifica e download aggiornamenti da GitHub in corso..."
        self._update_success = False
        self.updateStateChanged.emit()

        script_path = os.path.abspath(os.path.join(os.path.dirname(__file__), "scripts", "update_infotainment.sh"))

        def _update_task() -> Tuple[bool, str]:
            if not os.path.isfile(script_path):
                return False, "Script 'scripts/update_infotainment.sh' non trovato."
            try:
                proc = subprocess.run(
                    ["bash", script_path],
                    stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT,
                    text=True,
                    timeout=90.0,
                )
                output = proc.stdout.strip()
                lines = [l for l in output.splitlines() if l.strip()]
                msg = lines[-1] if lines else ""
                return (proc.returncode == 0), msg
            except subprocess.TimeoutExpired:
                return False, "Timeout connessione durante il download da GitHub."
            except Exception as exc:
                return False, f"Errore durante l'aggiornamento: {exc}"

        def _on_finish(result: Tuple[bool, str]) -> None:
            success, msg = result
            self._update_running = False
            self._update_success = success
            self._update_status_message = msg
            self.updateStateChanged.emit()

            if success and ("Aggiornato" in msg or "Nuova versione" in msg or "completato" in msg.lower()):
                logger.info("Software updated from Git! Scheduling application restart in 2 seconds...")
                QTimer.singleShot(2000, self.restartApp)

        self._async_runner.run_async(_update_task, on_result=_on_finish)
