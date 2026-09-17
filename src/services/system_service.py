"""
Hardware and Operating System Services (Pure Python).
Designed to be called exclusively from worker threads or async workers.
"""

import os
import re
import shutil
import subprocess
import urllib.request
import json
import logging
from typing import Optional, Dict, Any, Tuple

logger = logging.getLogger("SystemService")


class AudioService:
    """Controls Linux audio across WirePlumber/PipeWire (wpctl), PulseAudio (pactl), and ALSA (amixer)."""

    MIXER_CONTROL = "Master"

    @classmethod
    def get_volume_and_mute(cls) -> Tuple[int, bool]:
        """Reads current volume (0-100) and mute status (True/False)."""
        # 1. WirePlumber (PipeWire native standard on modern Linux & Pi OS Bookworm)
        if shutil.which("wpctl"):
            try:
                out = subprocess.check_output(
                    ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"],
                    stderr=subprocess.DEVNULL, text=True, timeout=0.8
                )
                m = re.search(r"Volume:\s+([0-9.]+)", out)
                if m:
                    vol = int(round(float(m.group(1)) * 100))
                    is_muted = "[MUTED]" in out
                    return max(0, min(200, vol)), is_muted
            except Exception as exc:
                logger.debug("wpctl query failed: %s", exc)

        # 2. pactl (PulseAudio / PipeWire-Pulse fallback)
        if shutil.which("pactl"):
            try:
                vol_out = subprocess.check_output(
                    ["pactl", "get-sink-volume", "@DEFAULT_SINK@"],
                    stderr=subprocess.DEVNULL, text=True, timeout=1.0
                )
                mute_out = subprocess.check_output(
                    ["pactl", "get-sink-mute", "@DEFAULT_SINK@"],
                    stderr=subprocess.DEVNULL, text=True, timeout=1.0
                )
                vol_match = re.search(r"/ +(\d+)% +/", vol_out)
                is_muted = "yes" in mute_out.lower()
                vol = int(vol_match.group(1)) if vol_match else 50
                return max(0, min(200, vol)), is_muted
            except Exception as exc:
                logger.debug("pactl query failed: %s, falling back to amixer", exc)

        # 3. amixer (ALSA fallback)
        if shutil.which("amixer"):
            try:
                cmd = ["amixer", "sget", cls.MIXER_CONTROL]
                output = subprocess.check_output(cmd, stderr=subprocess.DEVNULL, text=True, timeout=1.5)
                vol_match = re.search(r"\[(\d+)%\]", output)
                mute_match = re.search(r"\[(on|off)\]", output)
                vol = int(vol_match.group(1)) if vol_match else 50
                is_muted = (mute_match.group(1) == "off") if mute_match else False
                return min(100, max(0, vol)), is_muted
            except Exception as exc:
                logger.warning("Error querying amixer: %s", exc)

        return 50, False

    @classmethod
    def set_volume(cls, percent: int, max_limit: int = 200) -> bool:
        """Sets volume percentage across all available audio subsystems (supports boost beyond 100%)."""
        clamped = max(0, min(max_limit, int(percent)))
        success = False

        # 1. WirePlumber / PipeWire
        if shutil.which("wpctl"):
            try:
                vol_float = clamped / 100.0
                limit_float = max(1.0, max_limit / 100.0)
                subprocess.run(
                    ["wpctl", "set-volume", "-l", f"{limit_float:.2f}", "@DEFAULT_AUDIO_SINK@", f"{vol_float:.2f}"],
                    stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=0.8
                )
                success = True
            except Exception as exc:
                logger.debug("wpctl set-volume failed: %s", exc)

        # 2. pactl
        if shutil.which("pactl"):
            try:
                subprocess.run(
                    ["pactl", "set-sink-volume", "@DEFAULT_SINK@", f"{clamped}%"],
                    stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=1.0
                )
                success = True
            except Exception as exc:
                logger.debug("pactl set-sink-volume failed: %s", exc)

        # 3. amixer
        if shutil.which("amixer"):
            try:
                hw_vol = min(100, clamped)
                cmd = ["amixer", "sset", cls.MIXER_CONTROL, f"{hw_vol}%"]
                subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=1.0)
                success = True
            except Exception as exc:
                logger.debug("amixer set-volume failed: %s", exc)

        return success

    @classmethod
    def set_mute(cls, muted: bool) -> bool:
        """Sets mute state across WirePlumber, PulseAudio/PipeWire sinks, streams, and ALSA."""
        val_str = "1" if muted else "0"
        success = False

        # 1. WirePlumber (PipeWire native)
        if shutil.which("wpctl"):
            try:
                subprocess.run(
                    ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", val_str],
                    stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=0.8
                )
                success = True
            except Exception as exc:
                logger.debug("wpctl set-mute failed: %s", exc)

        # 2. PulseAudio / PipeWire Pulse (pactl)
        if shutil.which("pactl"):
            try:
                # Mute default sink
                subprocess.run(
                    ["pactl", "set-sink-mute", "@DEFAULT_SINK@", val_str],
                    stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=0.8
                )
                success = True

                # Also mute all individual sinks
                try:
                    sinks_out = subprocess.check_output(
                        ["pactl", "list", "sinks", "short"],
                        stderr=subprocess.DEVNULL, text=True, timeout=0.8
                    )
                    for s_line in sinks_out.strip().splitlines():
                        parts = s_line.split()
                        if parts:
                            subprocess.run(
                                ["pactl", "set-sink-mute", parts[0], val_str],
                                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=0.4
                            )
                except Exception:
                    pass

                # Also mute all active playback streams (sink-inputs)
                try:
                    inputs_out = subprocess.check_output(
                        ["pactl", "list", "sink-inputs", "short"],
                        stderr=subprocess.DEVNULL, text=True, timeout=0.8
                    )
                    for i_line in inputs_out.strip().splitlines():
                        parts = i_line.split()
                        if parts:
                            subprocess.run(
                                ["pactl", "set-sink-input-mute", parts[0], val_str],
                                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=0.4
                            )
                except Exception:
                    pass

            except Exception as exc:
                logger.debug("pactl set-sink-mute failed: %s", exc)

        # 3. ALSA mixer via amixer
        if shutil.which("amixer"):
            try:
                state = "mute" if muted else "unmute"
                subprocess.run(
                    ["amixer", "set", cls.MIXER_CONTROL, state],
                    stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=1.0
                )
                success = True
            except Exception as exc:
                logger.debug("amixer set mute state failed: %s", exc)

        return success


class HardwareMonitorService:
    """Reads system telemetry such as CPU temperature across Linux (Raspberry Pi & Desktop)."""

    @classmethod
    def get_cpu_temperature(cls) -> Optional[float]:
        """Reads CPU temperature in Celsius from thermal zones or vcgencmd."""
        # Check standard Linux thermal zones (zone0, zone1, etc.)
        for zone in ["thermal_zone0", "thermal_zone1", "thermal_zone2"]:
            thermal_path = f"/sys/class/thermal/{zone}/temp"
            if os.path.exists(thermal_path):
                try:
                    with open(thermal_path, "r", encoding="utf-8") as f:
                        millidegrees = int(f.read().strip())
                        val = round(millidegrees / 1000.0, 1)
                        if val > 0:
                            return val
                except Exception:
                    pass

        # Fallback to vcgencmd on Raspberry Pi
        if shutil.which("vcgencmd"):
            try:
                output = subprocess.check_output(["vcgencmd", "measure_temp"], text=True, timeout=1.0)
                match = re.search(r"temp=([\d\.]+)", output)
                if match:
                    return float(match.group(1))
            except Exception:
                pass

        # No dummy value: return None if sensor unavailable
        return None


class WeatherService:
    """Fetches non-blocking meteorological data using Open-Meteo."""

    @classmethod
    def fetch_weather(cls, latitude: float = 45.5467, longitude: float = 11.5475) -> Dict[str, Any]:
        """
        Fetches current weather for given coordinates (default: Vicenza).
        Returns dict with temperature, condition, icon name or error state (NO DUMMY DATA).
        """
        url = (
            f"https://api.open-meteo.com/v1/forecast?"
            f"latitude={latitude}&longitude={longitude}&current_weather=true"
        )
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "RPi-Car-Infotainment/2.0"})
            with urllib.request.urlopen(req, timeout=3.0) as resp:
                data = json.loads(resp.read().decode("utf-8"))
                current = data.get("current_weather", {})
                temp = round(current.get("temperature"), 1) if "temperature" in current else None
                code = current.get("weathercode", 0)
                condition, icon = cls._map_weather_code(code)
                return {
                    "temperature": temp,
                    "condition": condition,
                    "icon": icon,
                    "success": True,
                }
        except Exception as exc:
            logger.debug("Weather fetch error (offline or unreachable): %s", exc)
            return {
                "temperature": None,
                "condition": "Offline / Dati non disponibili",
                "icon": "cloud_off",
                "success": False,
            }

    @staticmethod
    def _map_weather_code(code: int) -> Tuple[str, str]:
        # WMO Weather interpretation codes mapped to Material Symbols ligatures
        if code == 0:
            return "Sereno", "wb_sunny"
        if code in (1, 2):
            return "Poco Nuvoloso", "partly_cloudy_day"
        if code == 3:
            return "Nuvoloso", "cloud"
        if code in (45, 48):
            return "Nebbia", "foggy"
        if code in (51, 53, 55, 61, 63, 65, 80, 81, 82):
            return "Pioggia", "rainy"
        if code in (71, 73, 75, 85, 86):
            return "Neve", "ac_unit"
        if code in (95, 96, 99):
            return "Temporale", "thunderstorm"
        return "Variabile", "partly_cloudy_day"
