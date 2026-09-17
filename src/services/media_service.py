"""
media_service.py - Real Media Player integration for Linux & Automotive systems.
Supports:
1. Native BlueZ Bluetooth AVRCP on System D-Bus (org.bluez.MediaPlayer1 / MediaControl1).
2. Desktop MPRIS media players on Session D-Bus (org.mpris.MediaPlayer2.*).
Extracts live track metadata (Title, Artist, Album, Status) and sends playback controls.
ZERO DUMMY DATA: returns None if no media stream or connected player exists.
"""

import logging
import shutil
import subprocess
from typing import Optional, Dict, Any

from PyQt6.QtDBus import QDBusConnection, QDBusInterface, QDBusMessage, QDBusVariant, QDBus

logger = logging.getLogger("MediaService")


class MediaService:
    """Interacts with BlueZ Bluetooth AVRCP (System Bus) and MPRIS (Session Bus)."""

    _mpris_proxy_started = False

    @classmethod
    def _ensure_mpris_proxy(cls) -> None:
        """Starts mpris-proxy daemon if available so desktop MPRIS listeners stay synced with BlueZ."""
        if cls._mpris_proxy_started:
            return
        cls._mpris_proxy_started = True

        if shutil.which("systemctl"):
            try:
                subprocess.run(
                    ["systemctl", "--user", "start", "mpris-proxy.service"],
                    stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=1.0
                )
                return
            except Exception:
                pass

        if shutil.which("mpris-proxy"):
            try:
                # Check if running
                proc = subprocess.run(["pgrep", "-x", "mpris-proxy"], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
                if proc.returncode != 0:
                    subprocess.Popen(["mpris-proxy"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            except Exception:
                pass

    @classmethod
    def get_current_media(cls) -> Optional[Dict[str, Any]]:
        """
        Queries both BlueZ on System Bus and MPRIS players on Session Bus.
        Returns track metadata dictionary or None if no media source is active.
        """
        cls._ensure_mpris_proxy()

        # ---------------------------------------------------------------------
        # 1. Native BlueZ Bluetooth AVRCP Query (System Bus)
        # ---------------------------------------------------------------------
        bus_system = QDBusConnection.systemBus()
        if bus_system.isConnected():
            try:
                mgr = QDBusInterface("org.bluez", "/", "org.freedesktop.DBus.ObjectManager", bus_system)
                msg: QDBusMessage = mgr.call("GetManagedObjects")
                if msg.type() == QDBusMessage.MessageType.ReplyMessage and len(msg.arguments()) > 0:
                    managed = msg.arguments()[0]

                    # A. Active org.bluez.MediaPlayer1
                    for path, ifaces in managed.items():
                        if "org.bluez.MediaPlayer1" in ifaces:
                            mp = ifaces["org.bluez.MediaPlayer1"]
                            status = str(mp.get("Status", "stopped"))
                            track = mp.get("Track", {})
                            title = str(track.get("Title", "")).strip()
                            artist = str(track.get("Artist", "")).strip()
                            album = str(track.get("Album", "")).strip()
                            duration_ms = track.get("Duration", 0)
                            position_ms = mp.get("Position", 0)
                            progress = (position_ms / duration_ms) if duration_ms > 0 else 0.0

                            # Retrieve device name for display
                            device_name = "Bluetooth Audio"
                            for dev_path, dev_ifaces in managed.items():
                                if path.startswith(dev_path) and dev_path != path:
                                    d_props = dev_ifaces.get("org.bluez.Device1", {})
                                    device_name = d_props.get("Alias") or d_props.get("Name") or device_name

                            # Extract BlueZ AVRCP Shuffle and Repeat modes
                            shuf_raw = str(mp.get("Shuffle", "off")).lower()
                            shuffle_val = (shuf_raw in ["alltracks", "group"])

                            rep_raw = str(mp.get("Repeat", "off")).lower()
                            if rep_raw == "singletrack":
                                repeat_val = "one"
                            elif rep_raw in ["alltracks", "group"]:
                                repeat_val = "all"
                            else:
                                repeat_val = "off"

                            return {
                                "source": "bluez",
                                "object_path": path,
                                "interface": "org.bluez.MediaPlayer1",
                                "player": str(mp.get("Name") or "Bluetooth"),
                                "title": title or "Traccia Bluetooth",
                                "artist": artist or device_name,
                                "album": album or "",
                                "is_playing": (status.lower() == "playing"),
                                "status": status.capitalize(),
                                "progress": progress,
                                "duration_ms": duration_ms,
                                "position_ms": position_ms,
                                "shuffle": shuffle_val,
                                "repeat": repeat_val,
                            }

                    # B. Device connected with MediaControl1 (fallback if track info not yet emitted)
                    for path, ifaces in managed.items():
                        if "org.bluez.MediaControl1" in ifaces:
                            mc = ifaces["org.bluez.MediaControl1"]
                            dev_props = ifaces.get("org.bluez.Device1", {})
                            is_connected = dev_props.get("Connected", False) or mc.get("Connected", False)
                            if is_connected:
                                dev_name = dev_props.get("Alias") or dev_props.get("Name") or "Dispositivo Bluetooth"
                                return {
                                    "source": "bluez_control",
                                    "object_path": path,
                                    "interface": "org.bluez.MediaControl1",
                                    "player": "Bluetooth",
                                    "title": "Audio Bluetooth Connesso",
                                    "artist": dev_name,
                                    "album": "Pronto per la riproduzione",
                                    "is_playing": False,
                                    "status": "Stopped",
                                    "progress": 0.0,
                                }
            except Exception as exc:
                logger.debug("BlueZ system bus media query error: %s", exc)

        # ---------------------------------------------------------------------
        # 2. Local MPRIS Media Players Query (Session Bus)
        # ---------------------------------------------------------------------
        bus_session = QDBusConnection.sessionBus()
        if bus_session.isConnected():
            try:
                dbus_iface = QDBusInterface(
                    "org.freedesktop.DBus",
                    "/org/freedesktop/DBus",
                    "org.freedesktop.DBus",
                    bus_session
                )
                reply: QDBusMessage = dbus_iface.call("ListNames")
                if reply.type() == QDBusMessage.MessageType.ReplyMessage and len(reply.arguments()) > 0:
                    names = reply.arguments()[0]
                    player_names = [n for n in names if n.startswith("org.mpris.MediaPlayer2.")]

                    for player_service in player_names:
                        player_iface = QDBusInterface(
                            player_service,
                            "/org/mpris/MediaPlayer2",
                            "org.freedesktop.DBus.Properties",
                            bus_session
                        )
                        if not player_iface.isValid():
                            continue

                        status_reply: QDBusMessage = player_iface.call("Get", "org.mpris.MediaPlayer2.Player", "PlaybackStatus")
                        status = "Stopped"
                        if status_reply.type() == QDBusMessage.MessageType.ReplyMessage and len(status_reply.arguments()) > 0:
                            status = str(status_reply.arguments()[0])

                        meta_reply: QDBusMessage = player_iface.call("Get", "org.mpris.MediaPlayer2.Player", "Metadata")
                        if meta_reply.type() != QDBusMessage.MessageType.ReplyMessage or len(meta_reply.arguments()) == 0:
                            continue

                        raw_meta = meta_reply.arguments()[0]
                        if not isinstance(raw_meta, dict):
                            continue

                        title = ""
                        artist = ""
                        album = ""

                        if "xesam:title" in raw_meta:
                            title = str(raw_meta["xesam:title"])
                        if "xesam:artist" in raw_meta:
                            art = raw_meta["xesam:artist"]
                            artist = ", ".join(art) if isinstance(art, list) else str(art)
                        if "xesam:album" in raw_meta:
                            album = str(raw_meta["xesam:album"])

                        if title or artist:
                            length_us = raw_meta.get("mpris:length", 0)
                            dur_ms = int(length_us / 1000) if length_us else 0
                            pos_reply = player_iface.call("Get", "org.mpris.MediaPlayer2.Player", "Position")
                            pos_us = pos_reply.arguments()[0] if (pos_reply.type() == QDBusMessage.MessageType.ReplyMessage and len(pos_reply.arguments()) > 0) else 0
                            p_ms = int(pos_us / 1000) if pos_us else 0
                            prog = (p_ms / dur_ms) if dur_ms > 0 else 0.0

                            # Extract MPRIS Shuffle and LoopStatus
                            shuf_reply = player_iface.call("Get", "org.mpris.MediaPlayer2.Player", "Shuffle")
                            shuf_val = bool(shuf_reply.arguments()[0]) if (shuf_reply.type() == QDBusMessage.MessageType.ReplyMessage and len(shuf_reply.arguments()) > 0) else False

                            loop_reply = player_iface.call("Get", "org.mpris.MediaPlayer2.Player", "LoopStatus")
                            loop_raw = str(loop_reply.arguments()[0]).lower() if (loop_reply.type() == QDBusMessage.MessageType.ReplyMessage and len(loop_reply.arguments()) > 0) else "none"
                            if loop_raw == "track":
                                repeat_val = "one"
                            elif loop_raw == "playlist":
                                repeat_val = "all"
                            else:
                                repeat_val = "off"

                            return {
                                "source": "mpris",
                                "object_path": "/org/mpris/MediaPlayer2",
                                "interface": "org.mpris.MediaPlayer2.Player",
                                "player": player_service.replace("org.mpris.MediaPlayer2.", ""),
                                "title": title or "Senza Titolo",
                                "artist": artist or "Artista Sconosciuto",
                                "album": album or "",
                                "is_playing": (status.lower() == "playing"),
                                "status": status,
                                "progress": prog,
                                "duration_ms": dur_ms,
                                "position_ms": p_ms,
                                "shuffle": shuf_val,
                                "repeat": repeat_val,
                            }
            except Exception as exc:
                logger.debug("Session bus MPRIS query error: %s", exc)

        return None

    @classmethod
    def send_player_command(cls, action: str) -> bool:
        """
        Dispatches Play, Pause, PlayPause, Next, Previous to the active player.
        Prioritizes BlueZ Bluetooth device first, then session MPRIS players.
        """
        # 1. Check BlueZ on System Bus
        bus_system = QDBusConnection.systemBus()
        if bus_system.isConnected():
            try:
                mgr = QDBusInterface("org.bluez", "/", "org.freedesktop.DBus.ObjectManager", bus_system)
                msg: QDBusMessage = mgr.call("GetManagedObjects")
                if msg.type() == QDBusMessage.MessageType.ReplyMessage and len(msg.arguments()) > 0:
                    managed = msg.arguments()[0]

                    # Target org.bluez.MediaPlayer1
                    for path, ifaces in managed.items():
                        if "org.bluez.MediaPlayer1" in ifaces:
                            player = QDBusInterface("org.bluez", path, "org.bluez.MediaPlayer1", bus_system)
                            if player.isValid():
                                if action == "PlayPause":
                                    status = str(ifaces["org.bluez.MediaPlayer1"].get("Status", "")).lower()
                                    cmd = "Pause" if status == "playing" else "Play"
                                    player.call(cmd)
                                else:
                                    player.call(action)
                                logger.info("Dispatched '%s' to BlueZ MediaPlayer1 at %s", action, path)
                                return True

                    # Target org.bluez.MediaControl1
                    for path, ifaces in managed.items():
                        if "org.bluez.MediaControl1" in ifaces:
                            dev = ifaces.get("org.bluez.Device1", {})
                            if dev.get("Connected", False) or ifaces["org.bluez.MediaControl1"].get("Connected", False):
                                mc = QDBusInterface("org.bluez", path, "org.bluez.MediaControl1", bus_system)
                                if mc.isValid():
                                    cmd = "Play" if action == "PlayPause" else action
                                    mc.call(cmd)
                                    logger.info("Dispatched '%s' to BlueZ MediaControl1 at %s", action, path)
                                    return True
            except Exception as exc:
                logger.warning("Error dispatching BlueZ player command: %s", exc)

        # 2. Check Session Bus MPRIS
        bus_session = QDBusConnection.sessionBus()
        if bus_session.isConnected():
            try:
                dbus_iface = QDBusInterface("org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus", bus_session)
                reply: QDBusMessage = dbus_iface.call("ListNames")
                if reply.type() == QDBusMessage.MessageType.ReplyMessage and len(reply.arguments()) > 0:
                    names = reply.arguments()[0]
                    player_names = [n for n in names if n.startswith("org.mpris.MediaPlayer2.")]
                    if player_names:
                        target = player_names[0]
                        player = QDBusInterface(target, "/org/mpris/MediaPlayer2", "org.mpris.MediaPlayer2.Player", bus_session)
                        if player.isValid():
                            player.call(action)
                            logger.info("Dispatched '%s' to MPRIS player %s", action, target)
                            return True
            except Exception as exc:
                logger.warning("Error dispatching session MPRIS command: %s", exc)

        return False

    @classmethod
    def set_player_shuffle(cls, enabled: bool) -> bool:
        """
        Sends shuffle setting request to active BlueZ Bluetooth player or MPRIS player.
        - For BlueZ (AVRCP): sets 'Shuffle' property to 'alltracks' or 'off'.
          BlueZ converts this into an AVRCP SetPlayerApplicationSettingValue PDU to the smartphone.
        - For MPRIS (Session bus): sets 'Shuffle' property to boolean True or False.
        """
        cls._ensure_mpris_proxy()
        success = False

        # 1. BlueZ Bluetooth on System Bus
        bus_system = QDBusConnection.systemBus()
        if bus_system.isConnected():
            try:
                mgr = QDBusInterface("org.bluez", "/", "org.freedesktop.DBus.ObjectManager", bus_system)
                msg: QDBusMessage = mgr.call("GetManagedObjects")
                if msg.type() == QDBusMessage.MessageType.ReplyMessage and len(msg.arguments()) > 0:
                    managed = msg.arguments()[0]
                    bluez_val = "alltracks" if enabled else "off"

                    for path, ifaces in managed.items():
                        if "org.bluez.MediaPlayer1" in ifaces:
                            prop_iface = QDBusInterface("org.bluez", path, "org.freedesktop.DBus.Properties", bus_system)
                            if prop_iface.isValid():
                                prop_iface.call(QDBus.CallMode.NoBlock, "Set", "org.bluez.MediaPlayer1", "Shuffle", QDBusVariant(bluez_val))
                                logger.info("Dispatched Bluetooth AVRCP Shuffle='%s' to %s", bluez_val, path)
                                success = True
            except Exception as exc:
                logger.debug("Error setting BlueZ shuffle: %s", exc)

        # 2. MPRIS on Session Bus
        bus_session = QDBusConnection.sessionBus()
        if bus_session.isConnected():
            try:
                dbus_iface = QDBusInterface("org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus", bus_session)
                reply: QDBusMessage = dbus_iface.call("ListNames")
                if reply.type() == QDBusMessage.MessageType.ReplyMessage and len(reply.arguments()) > 0:
                    names = reply.arguments()[0]
                    player_names = [n for n in names if n.startswith("org.mpris.MediaPlayer2.")]
                    for target in player_names:
                        prop_iface = QDBusInterface(target, "/org/mpris/MediaPlayer2", "org.freedesktop.DBus.Properties", bus_session)
                        if prop_iface.isValid():
                            prop_iface.call(QDBus.CallMode.NoBlock, "Set", "org.mpris.MediaPlayer2.Player", "Shuffle", QDBusVariant(enabled))
                            logger.info("Dispatched MPRIS Shuffle=%s to %s", enabled, target)
                            success = True
            except Exception as exc:
                logger.debug("Error setting MPRIS shuffle: %s", exc)

        return success

    @classmethod
    def set_player_repeat(cls, mode: str) -> bool:
        """
        Sends repeat mode setting request to active BlueZ Bluetooth player or MPRIS player.
        Modes: 'off', 'all' (entire playlist), 'one' (single track).
        - For BlueZ (AVRCP): sets 'Repeat' property to 'off', 'alltracks', or 'singletrack'.
          BlueZ converts this into an AVRCP SetPlayerApplicationSettingValue PDU to the smartphone.
        - For MPRIS (Session bus): sets 'LoopStatus' property to 'None', 'Playlist', or 'Track'.
        """
        cls._ensure_mpris_proxy()
        success = False

        bluez_val = "alltracks" if mode == "all" else ("singletrack" if mode == "one" else "off")
        mpris_val = "Playlist" if mode == "all" else ("Track" if mode == "one" else "None")

        # 1. BlueZ Bluetooth on System Bus
        bus_system = QDBusConnection.systemBus()
        if bus_system.isConnected():
            try:
                mgr = QDBusInterface("org.bluez", "/", "org.freedesktop.DBus.ObjectManager", bus_system)
                msg: QDBusMessage = mgr.call("GetManagedObjects")
                if msg.type() == QDBusMessage.MessageType.ReplyMessage and len(msg.arguments()) > 0:
                    managed = msg.arguments()[0]
                    for path, ifaces in managed.items():
                        if "org.bluez.MediaPlayer1" in ifaces:
                            prop_iface = QDBusInterface("org.bluez", path, "org.freedesktop.DBus.Properties", bus_system)
                            if prop_iface.isValid():
                                prop_iface.call(QDBus.CallMode.NoBlock, "Set", "org.bluez.MediaPlayer1", "Repeat", QDBusVariant(bluez_val))
                                logger.info("Dispatched Bluetooth AVRCP Repeat='%s' to %s", bluez_val, path)
                                success = True
            except Exception as exc:
                logger.debug("Error setting BlueZ repeat: %s", exc)

        # 2. MPRIS on Session Bus
        bus_session = QDBusConnection.sessionBus()
        if bus_session.isConnected():
            try:
                dbus_iface = QDBusInterface("org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus", bus_session)
                reply: QDBusMessage = dbus_iface.call("ListNames")
                if reply.type() == QDBusMessage.MessageType.ReplyMessage and len(reply.arguments()) > 0:
                    names = reply.arguments()[0]
                    player_names = [n for n in names if n.startswith("org.mpris.MediaPlayer2.")]
                    for target in player_names:
                        prop_iface = QDBusInterface(target, "/org/mpris/MediaPlayer2", "org.freedesktop.DBus.Properties", bus_session)
                        if prop_iface.isValid():
                            prop_iface.call(QDBus.CallMode.NoBlock, "Set", "org.mpris.MediaPlayer2.Player", "LoopStatus", QDBusVariant(mpris_val))
                            logger.info("Dispatched MPRIS LoopStatus='%s' to %s", mpris_val, target)
                            success = True
            except Exception as exc:
                logger.warning("Error setting MPRIS repeat: %s", exc)

        return success

