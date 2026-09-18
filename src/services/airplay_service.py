"""
airplay_service.py - AirPlay Screen Mirroring Service utilizing UxPlay.
Manages the UxPlay daemon, monitors connection state and streaming status,
and provides touch monitoring during active video mirroring.
Adheres strictly to the DOX contract and zero dummy data policy.
"""

import os
import re
import time
import signal
import shutil
import logging
import threading
import subprocess
from typing import Optional, Callable, List

logger = logging.getLogger("AirPlayService")


class TouchMonitorThread(threading.Thread):
    """
    Background worker monitoring input devices (/dev/input/event*)
    to detect touch or mouse tap events during active video mirroring.
    """

    def __init__(self, on_touch_callback: Callable[[], None]):
        super().__init__(daemon=True)
        self._on_touch = on_touch_callback
        self._stop_event = threading.Event()
        self._devices = []
        self._last_touch_time = 0.0

    def stop(self) -> None:
        self._stop_event.set()

    def run(self) -> None:
        try:
            import evdev
            from select import select
        except ImportError:
            logger.info("evdev not available for touch interception, relying on UI overlay")
            return

        try:
            device_paths = evdev.list_devices()
            for path in device_paths:
                try:
                    dev = evdev.InputDevice(path)
                    caps = dev.capabilities()
                    # Check for touch (EV_ABS or BTN_TOUCH) or mouse (EV_REL / BTN_LEFT)
                    is_touch = (
                        evdev.ecodes.EV_ABS in caps
                        or (evdev.ecodes.EV_KEY in caps and (
                            evdev.ecodes.BTN_TOUCH in caps[evdev.ecodes.EV_KEY]
                            or evdev.ecodes.BTN_LEFT in caps[evdev.ecodes.EV_KEY]
                        ))
                    )
                    if is_touch:
                        self._devices.append(dev)
                except Exception:
                    continue
        except Exception as exc:
            logger.debug("Failed listing evdev devices: %s", exc)
            return

        if not self._devices:
            logger.debug("No touch or pointer evdev devices identified")
            return

        logger.info("Monitoring %d input device(s) for touch wake/exit events", len(self._devices))

        while not self._stop_event.is_set():
            try:
                r, _, _ = select(self._devices, [], [], 0.5)
                if not r:
                    continue
                for dev in r:
                    for event in dev.read():
                        is_tap = False
                        # Detect touch down or mouse click
                        if event.type == evdev.ecodes.EV_KEY:
                            if event.code in (evdev.ecodes.BTN_TOUCH, evdev.ecodes.BTN_LEFT) and event.value == 1:
                                is_tap = True
                        elif event.type == evdev.ecodes.EV_ABS:
                            # Touchscreen position update/press
                            if event.code in (evdev.ecodes.ABS_PRESSURE, evdev.ecodes.ABS_MT_PRESSURE) and event.value > 0:
                                is_tap = True
                            elif event.code in (evdev.ecodes.ABS_X, evdev.ecodes.ABS_Y, evdev.ecodes.ABS_MT_POSITION_X):
                                is_tap = True

                        if is_tap:
                            now = time.time()
                            # Debounce touch events by 1.2s to avoid spam
                            if now - self._last_touch_time > 1.2:
                                self._last_touch_time = now
                                if self._on_touch:
                                    self._on_touch()
            except Exception as exc:
                if not self._stop_event.is_set():
                    logger.debug("Error in evdev reader: %s", exc)
                break


class AirPlayService:
    """
    Subprocess lifecycle manager for UxPlay AirPlay mirroring server.
    """

    def __init__(self, server_name: str = "Mito-AirPlay", decoder_mode: str = "software"):
        self._server_name = server_name
        self._decoder_mode = decoder_mode  # "software" (avdec) or "hardware" (bt709)
        self._lock = threading.Lock()
        self._process: Optional[subprocess.Popen] = None
        self._reader_thread: Optional[threading.Thread] = None
        self._touch_thread: Optional[TouchMonitorThread] = None
        self._is_running: bool = False
        self._is_streaming: bool = False
        self._client_info: str = ""
        self._status_message: str = "Inattivo"

        # Callbacks
        self._on_streaming_start: Optional[Callable[[str], None]] = None
        self._on_streaming_stop: Optional[Callable[[], None]] = None
        self._on_touch: Optional[Callable[[], None]] = None
        self._on_status: Optional[Callable[[bool, bool, str], None]] = None

    @staticmethod
    def is_available() -> bool:
        """Returns True if the 'uxplay' executable is installed in PATH."""
        return shutil.which("uxplay") is not None

    @property
    def is_running(self) -> bool:
        return self._is_running and self._process is not None and self._process.poll() is None

    @property
    def is_streaming(self) -> bool:
        return self._is_streaming

    @property
    def server_name(self) -> str:
        return self._server_name

    @property
    def decoder_mode(self) -> str:
        return self._decoder_mode

    @decoder_mode.setter
    def decoder_mode(self, mode: str) -> None:
        if mode in ("software", "hardware") and mode != self._decoder_mode:
            self._decoder_mode = mode
            logger.info("AirPlay decoder mode set to: %s", mode)
            if self.is_running:
                threading.Thread(target=self.stop_current_stream, daemon=True).start()

    @property
    def client_info(self) -> str:
        return self._client_info

    @property
    def status_message(self) -> str:
        return self._status_message

    def start_server(
        self,
        on_streaming_start: Optional[Callable[[str], None]] = None,
        on_streaming_stop: Optional[Callable[[], None]] = None,
        on_touch: Optional[Callable[[], None]] = None,
        on_status: Optional[Callable[[bool, bool, str], None]] = None,
    ) -> bool:
        """
        Starts the UxPlay daemon in the background with hardware-appropriate parameters.
        """
        if not self.is_available():
            self._status_message = "UxPlay non installato nel sistema"
            logger.warning("Cannot start AirPlay: 'uxplay' executable not found in PATH")
            if on_status:
                on_status(False, False, self._status_message)
            return False

        with self._lock:
            if self.is_running:
                logger.info("UxPlay daemon already running")
                return True

            self._on_streaming_start = on_streaming_start
            self._on_streaming_stop = on_streaming_stop
            self._on_touch = on_touch
            self._on_status = on_status

            # Build command arguments
            cmd = [
                "uxplay",
                "-n", self._server_name,
                "-nh",           # Do not append @hostname
                "-s", "1024x600", # Native screen resolution
                "-fs",           # Fullscreen mode
                "-p",            # Support AirPlay PIN / standard port discovery
            ]

            # Decoder selection:
            # - Software (-avdec): Uses FFmpeg libav avdec_h264 with NEON SIMD.
            #   Completely fixes the severe Raspberry Pi 4 V4L2 color distortion / solarization
            #   bug (BT.709 full range misinterpretation) and prevents GStreamer pipeline freezes.
            # - Hardware (-bt709): Broadcom GPU V4L2 decoder requiring explicit BT.709 colorimetry fix.
            if self._decoder_mode == "software":
                cmd.append("-avdec")
            else:
                cmd.append("-bt709")

            # Optimize video sink based on graphics platform
            if os.environ.get("WAYLAND_DISPLAY"):
                cmd.extend(["-vs", "waylandsink"])
            else:
                cmd.extend(["-vs", "autovideosink"])

            # Optimize audio sink
            cmd.extend(["-as", "pulsesink"])

            logger.info("Starting UxPlay (decoder: %s) with command: %s", self._decoder_mode, " ".join(cmd))
            try:
                self._process = subprocess.Popen(
                    cmd,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT,
                    stdin=subprocess.PIPE,
                    text=True,
                    bufsize=1,
                )
                self._is_running = True
                self._is_streaming = False
                self._status_message = "In ascolto (In attesa di connessione)"
                self._notify_status()

                # Start background reader for stdout/stderr
                self._reader_thread = threading.Thread(target=self._stdout_reader, daemon=True)
                self._reader_thread.start()
                return True
            except Exception as exc:
                logger.error("Failed to launch uxplay: %s", exc)
                self._is_running = False
                self._status_message = f"Errore avvio: {exc}"
                self._notify_status()
                return False

    def stop_server(self) -> None:
        """
        Stops UxPlay completely and guarantees release of the DRM/KMS framebuffer
        so the Qt Quick infotainment interface is restored immediately.
        """
        self._stop_touch_monitor()

        if self._process is not None:
            logger.info("Stopping UxPlay daemon...")
            try:
                if self._process.stdin and not self._process.stdin.closed:
                    try:
                        self._process.stdin.write("q\n")
                        self._process.stdin.flush()
                    except Exception:
                        pass
                self._process.send_signal(signal.SIGINT)
                self._process.wait(timeout=0.6)
            except (subprocess.TimeoutExpired, Exception):
                try:
                    self._process.kill()
                    self._process.wait(timeout=0.4)
                except Exception:
                    pass
            self._process = None

        # Clean up any lingering uxplay helper or orphaned processes to ensure display plane is cleared
        try:
            subprocess.run(["pkill", "-9", "-f", "uxplay"], timeout=0.8, capture_output=True)
        except Exception:
            pass

        self._is_running = False
        was_streaming = self._is_streaming
        self._is_streaming = False
        self._client_info = ""
        self._status_message = "Inattivo"

        if was_streaming and self._on_streaming_stop:
            try:
                self._on_streaming_stop()
            except Exception as exc:
                logger.error("Error in on_streaming_stop callback: %s", exc)

        self._notify_status()

    def stop_current_stream(self) -> None:
        """
        Interrupts the active mirroring stream while keeping the server ready
        for subsequent connections. Destroys the video window to instantly restore
        the infotainment UI, then quietly restarts listening.
        """
        logger.info("Terminating current AirPlay stream and restoring listening state...")
        self.stop_server()
        # Brief pause to ensure DRM/KMS framebuffer is completely relinquished to Qt
        time.sleep(0.3)
        self.start_server(
            on_streaming_start=self._on_streaming_start,
            on_streaming_stop=self._on_streaming_stop,
            on_touch=self._on_touch,
            on_status=self._on_status,
        )

    def _start_touch_monitor(self) -> None:
        self._stop_touch_monitor()
        # Wire touch monitor to handle physical touchscreen taps during stream
        self._touch_thread = TouchMonitorThread(self._handle_touch_during_stream)
        self._touch_thread.start()

    def _stop_touch_monitor(self) -> None:
        if self._touch_thread is not None:
            self._touch_thread.stop()
            self._touch_thread = None

    def _handle_touch_during_stream(self) -> None:
        """
        Called when the car physical touchscreen is tapped while AirPlay mirroring is active.
        Since iOS AirPlay mirroring does not support reverse touch control, tapping anywhere
        on the screen indicates the driver/passenger wants to exit AirPlay and return
        to the infotainment dashboard.
        """
        if self._is_streaming:
            logger.info("Touch event detected on car screen during AirPlay stream -> Exiting stream and restoring UI")
            threading.Thread(target=self.stop_current_stream, daemon=True).start()

        if self._on_touch:
            try:
                self._on_touch()
            except Exception as exc:
                logger.error("Error in on_touch callback: %s", exc)

    def _stdout_reader(self) -> None:
        """Reads stdout line by line from UxPlay to track real connection state."""
        proc = self._process
        if not proc or not proc.stdout:
            return

        client_regex = re.compile(r"connection from\s+([0-9a-zA-Z\.\:\_\-]+)", re.IGNORECASE)

        for raw_line in iter(proc.stdout.readline, ""):
            line = raw_line.strip()
            if not line:
                continue

            logger.debug("[UxPlay] %s", line)

            # Check client address / connection
            match = client_regex.search(line)
            if match:
                self._client_info = match.group(1)

            # Detect mirroring start
            if any(k in line.lower() for k in ["starting mirroring", "raop_rtp_mirror", "video stream started"]):
                if not self._is_streaming:
                    self._is_streaming = True
                    self._status_message = f"Streaming attivo ({self._client_info or 'iPhone'})"
                    logger.info("AirPlay video mirroring stream STARTED from %s", self._client_info)
                    self._start_touch_monitor()
                    if self._on_streaming_start:
                        try:
                            self._on_streaming_start(self._client_info)
                        except Exception as exc:
                            logger.error("Error in on_streaming_start callback: %s", exc)
                    self._notify_status()

            # Detect mirroring stop / teardown
            elif any(k in line.lower() for k in [
                "stopping mirroring", "connection closed", "teardown",
                "reset by peer", "raop_rtp_mirror stopping", "end of stream", "broken pipe"
            ]):
                if self._is_streaming:
                    self._is_streaming = False
                    self._status_message = "In ascolto (Dispositivo disconnesso)"
                    logger.info("AirPlay video mirroring stream STOPPED -> Resetting UxPlay to clear frozen frame")
                    self._stop_touch_monitor()
                    if self._on_streaming_stop:
                        try:
                            self._on_streaming_stop()
                        except Exception as exc:
                            logger.error("Error in on_streaming_stop callback: %s", exc)
                    self._notify_status()

                    # Immediately reset UxPlay process so the GStreamer video window disappears
                    # and the Mito UI is restored without freezing on the last frame
                    threading.Thread(target=self.stop_current_stream, daemon=True).start()

        # Process exited
        self._is_running = False
        was_streaming = self._is_streaming
        self._is_streaming = False
        self._stop_touch_monitor()
        self._status_message = "Inattivo"
        if was_streaming and self._on_streaming_stop:
            try:
                self._on_streaming_stop()
            except Exception:
                pass
        self._notify_status()

    def _notify_status(self) -> None:
        if self._on_status:
            try:
                self._on_status(self._is_running, self._is_streaming, self._status_message)
            except Exception as exc:
                logger.error("Error in on_status callback: %s", exc)
