"""
network_service.py - Real Linux WiFi & Bluetooth management.
Uses nmcli (NetworkManager) and bluetoothctl (BlueZ).
Strictly queries real hardware states with NO dummy/fake data.
"""

import logging
import re
import shutil
import subprocess
from typing import Dict, Any, List, Optional, Tuple

logger = logging.getLogger("NetworkService")


class WiFiService:
    """Manages Wi-Fi connections via NetworkManager (nmcli)."""

    @classmethod
    def get_status_and_networks(cls, rescan: bool = False) -> Dict[str, Any]:
        """
        Scans for nearby networks and checks active Wi-Fi connection.
        If rescan is True, forces NetworkManager to perform an active wireless probe scan.
        Returns real status dict.
        """
        if not shutil.which("nmcli"):
            return {
                "available": False,
                "connected": False,
                "ssid": "",
                "signal": 0,
                "networks": [],
                "error": "nmcli non trovato",
            }

        status: Dict[str, Any] = {
            "available": True,
            "powered": cls.get_wifi_power(),
            "connected": False,
            "ssid": "",
            "signal": 0,
            "ip": "",
            "networks": [],
            "error": "",
        }

        try:
            if rescan:
                try:
                    subprocess.run(
                        ["nmcli", "dev", "wifi", "rescan"],
                        stdout=subprocess.DEVNULL,
                        stderr=subprocess.DEVNULL,
                        timeout=6.0
                    )
                except Exception:
                    pass

            # Query saved Wi-Fi connection profiles and last-connected timestamps from NetworkManager
            saved_wifi_timestamps: Dict[str, int] = {}
            try:
                con_out = subprocess.check_output(
                    ["nmcli", "-t", "-f", "NAME,TYPE,TIMESTAMP", "con", "show"],
                    text=True, stderr=subprocess.DEVNULL, timeout=2.0
                )
                for con_line in con_out.strip().splitlines():
                    con_parts = con_line.split(":")
                    if len(con_parts) >= 3 and con_parts[1] == "802-11-wireless":
                        try:
                            saved_wifi_timestamps[con_parts[0].strip()] = int(con_parts[2].strip())
                        except ValueError:
                            saved_wifi_timestamps[con_parts[0].strip()] = 0
            except Exception:
                pass

            # Query networks with SSID, Signal strength, security
            cmd = ["nmcli", "-t", "-f", "ACTIVE,SSID,SIGNAL,SECURITY", "dev", "wifi"]
            out = subprocess.check_output(cmd, text=True, stderr=subprocess.DEVNULL, timeout=4.0)

            seen_ssids = set()
            for line in out.strip().splitlines():
                parts = line.split(":")
                if len(parts) >= 3:
                    is_active = (parts[0].strip() == "yes")
                    ssid = parts[1].strip()
                    try:
                        signal_lvl = int(parts[2].strip())
                    except ValueError:
                        signal_lvl = 0
                    sec = parts[3].strip() if len(parts) > 3 else ""

                    if not ssid or ssid.startswith("--"):
                        continue

                    if is_active:
                        status["connected"] = True
                        status["ssid"] = ssid
                        status["signal"] = signal_lvl

                    is_saved = (ssid in saved_wifi_timestamps)
                    last_connected_ts = saved_wifi_timestamps.get(ssid, 0)

                    if ssid not in seen_ssids:
                        seen_ssids.add(ssid)
                        status["networks"].append({
                            "ssid": ssid,
                            "signal": signal_lvl,
                            "security": sec,
                            "active": is_active,
                            "inUse": is_active,
                            "saved": is_saved,
                            "timestamp": last_connected_ts,
                        })

            # Strict Sorting:
            # 1. Active connection ALWAYS on top
            # 2. Saved networks ordered by last time connected (highest timestamp first)
            # 3. Unsaved networks ordered by signal strength
            status["networks"].sort(
                key=lambda n: (
                    0 if n["active"] else 1,
                    -n.get("timestamp", 0),
                    -n.get("signal", 0)
                )
            )

            if status["connected"]:
                status["ip"] = cls.get_active_ip()

        except subprocess.TimeoutExpired:
            status["error"] = "Timeout scansione Wi-Fi"
        except Exception as exc:
            status["error"] = str(exc)

        return status

    @classmethod
    def get_active_ip(cls) -> str:
        """Returns the IPv4 address of the active Wi-Fi or primary network interface."""
        try:
            out = subprocess.check_output(
                ["ip", "-o", "-4", "addr", "show"],
                text=True,
                stderr=subprocess.DEVNULL,
                timeout=2.0
            )
            wifi_ip = ""
            fallback_ip = ""
            for line in out.strip().splitlines():
                parts = line.split()
                if len(parts) >= 4:
                    iface = parts[1]
                    cidr = parts[3]
                    ip = cidr.split("/")[0]
                    if ip.startswith("127."):
                        continue
                    if iface.startswith("wl"):
                        wifi_ip = ip
                        break
                    elif not fallback_ip:
                        fallback_ip = ip
            return wifi_ip or fallback_ip
        except Exception:
            return ""

    @classmethod
    def connect_saved_network(cls, ssid: str) -> Tuple[bool, str]:
        """Connects to a pre-saved Wi-Fi connection profile without passing passwords."""
        if not shutil.which("nmcli"):
            return False, "Comando nmcli non disponibile"

        try:
            cmd = ["nmcli", "con", "up", "id", ssid]
            proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=20.0)
            if proc.returncode == 0:
                return True, "Connessione riuscita"
            # Fallback to dev wifi connect if connection profile name differs
            cmd_fallback = ["nmcli", "dev", "wifi", "connect", ssid]
            proc_fb = subprocess.run(cmd_fallback, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=20.0)
            if proc_fb.returncode == 0:
                return True, "Connessione riuscita"
            err = proc.stderr.strip() or proc_fb.stderr.strip() or "Errore di connessione"
            if err.startswith("Error:"):
                err = err.replace("Error:", "").strip()
            return False, err
        except subprocess.TimeoutExpired:
            return False, "Timeout di connessione (20 secondi)"
        except Exception as exc:
            return False, str(exc)

    @classmethod
    def connect_to_network(cls, ssid: str, password: Optional[str] = None) -> Tuple[bool, str]:
        """Connects to a specific Wi-Fi SSID via nmcli and returns (success, message)."""
        if not shutil.which("nmcli"):
            return False, "Comando nmcli non disponibile"

        try:
            cmd = ["nmcli", "dev", "wifi", "connect", ssid]
            if password:
                cmd.extend(["password", password])
            proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=20.0)
            if proc.returncode == 0:
                return True, "Connessione riuscita"
            error_msg = proc.stderr.strip() or proc.stdout.strip() or "Errore di connessione"
            # Pulizia prefisso standard nmcli
            if error_msg.startswith("Error:"):
                error_msg = error_msg.replace("Error:", "").strip()
            return False, error_msg
        except subprocess.TimeoutExpired:
            return False, "Timeout di connessione (la rete non ha risposto in 20 secondi)"
        except Exception as exc:
            logger.warning("Failed to connect to Wi-Fi %s: %s", ssid, exc)
            return False, str(exc)

    @classmethod
    def get_wifi_power(cls) -> bool:
        """Checks if Wi-Fi radio is enabled via nmcli."""
        if not shutil.which("nmcli"):
            return False
        try:
            out = subprocess.check_output(["nmcli", "radio", "wifi"], text=True, stderr=subprocess.DEVNULL, timeout=2.0)
            return "enabled" in out.lower()
        except Exception:
            return True

    @classmethod
    def set_wifi_power(cls, enable: bool) -> Tuple[bool, str]:
        """Enables or disables Wi-Fi radio."""
        if not shutil.which("nmcli"):
            return False, "Comando nmcli non disponibile"
        try:
            val = "on" if enable else "off"
            subprocess.run(["nmcli", "radio", "wifi", val], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=4.0)
            return True, f"Wi-Fi: {val}"
        except Exception as exc:
            return False, str(exc)

    @classmethod
    def disconnect_network(cls, ssid: Optional[str] = None) -> Tuple[bool, str]:
        """Disconnects current Wi-Fi connection or a specific SSID."""
        if not shutil.which("nmcli"):
            return False, "Comando nmcli non disponibile"
        try:
            if ssid:
                proc = subprocess.run(["nmcli", "con", "down", "id", ssid], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=5.0)
                if proc.returncode == 0:
                    return True, f"Disconnesso da {ssid}"
            # Fallback: disconnect all active wireless connections
            con_out = subprocess.check_output(["nmcli", "-t", "-f", "NAME,TYPE,STATE", "con", "show", "--active"], text=True, stderr=subprocess.DEVNULL, timeout=2.0)
            for line in con_out.strip().splitlines():
                parts = line.split(":")
                if len(parts) >= 2 and parts[1] == "802-11-wireless":
                    subprocess.run(["nmcli", "con", "down", "id", parts[0]], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=4.0)
            return True, "Wi-Fi disconnesso"
        except Exception as exc:
            return False, str(exc)

    @classmethod
    def forget_network(cls, ssid: str) -> Tuple[bool, str]:
        """Deletes a saved Wi-Fi connection profile from NetworkManager."""
        if not shutil.which("nmcli"):
            return False, "Comando nmcli non disponibile"
        try:
            proc = subprocess.run(["nmcli", "con", "delete", "id", ssid], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=5.0)
            if proc.returncode == 0:
                return True, f"Rete '{ssid}' dimenticata"
            err = proc.stderr.strip() or "Errore durante la cancellazione"
            return False, err
        except Exception as exc:
            return False, str(exc)


import json
import time
from pathlib import Path

BT_HISTORY_FILE = Path.home() / ".config" / "mito_infotainment" / "bt_history.json"


def _load_bt_history() -> Dict[str, int]:
    try:
        if BT_HISTORY_FILE.exists():
            with open(BT_HISTORY_FILE, "r", encoding="utf-8") as f:
                return json.load(f)
    except Exception:
        pass
    return {}


def _save_bt_history(history: Dict[str, int]) -> None:
    try:
        BT_HISTORY_FILE.parent.mkdir(parents=True, exist_ok=True)
        with open(BT_HISTORY_FILE, "w", encoding="utf-8") as f:
            json.dump(history, f)
    except Exception:
        pass


class BluetoothService:
    """Manages Bluetooth adapter and paired devices via BlueZ (bluetoothctl)."""

    @classmethod
    def get_bluetooth_status(cls) -> Dict[str, Any]:
        """
        Queries adapter power and connected/paired devices.
        Strictly sorts:
        1. Connected devices at the very top.
        2. Devices ordered by last-connected timestamp (most recent first).
        3. Never-connected devices alphabetically.
        """
        if not shutil.which("bluetoothctl"):
            return {
                "available": False,
                "powered": False,
                "connected": False,
                "connected_device": "",
                "devices": [],
                "error": "bluetoothctl non trovato",
            }

        res: Dict[str, Any] = {
            "available": True,
            "powered": False,
            "connected": False,
            "connected_device": "",
            "discoverable": False,
            "adapter_name": "Raspberry Pi",
            "devices": [],
            "error": "",
        }

        try:
            # Check controller power and discoverable state
            show = subprocess.check_output(["bluetoothctl", "show"], text=True, stderr=subprocess.DEVNULL, timeout=2.0)
            if "Powered: yes" in show:
                res["powered"] = True
            if "Discoverable: yes" in show:
                res["discoverable"] = True

            alias_match = re.search(r"Alias:\s+(.+)", show)
            name_match = re.search(r"Name:\s+(.+)", show)
            if alias_match:
                res["adapter_name"] = alias_match.group(1).strip()
            elif name_match:
                res["adapter_name"] = name_match.group(1).strip()

            # Query connected devices
            conn = subprocess.check_output(
                ["bluetoothctl", "devices", "Connected"],
                text=True,
                stderr=subprocess.DEVNULL,
                timeout=2.0
            )
            connected_macs = set(re.findall(r"Device\s+([0-9A-Fa-f:]{17})", conn))
            match = re.search(r"Device\s+([0-9A-Fa-f:]{17})\s+(.+)", conn)
            if match:
                res["connected"] = True
                res["connected_device"] = match.group(2).strip()

            # Load persistent connection history
            history = _load_bt_history()
            history_updated = False
            now_ts = int(time.time())

            for cmac in connected_macs:
                history[cmac] = now_ts
                history_updated = True

            if history_updated:
                _save_bt_history(history)

            # Query paired devices set
            paired_macs = set()
            try:
                paired_out = subprocess.check_output(
                    ["bluetoothctl", "devices", "Paired"],
                    text=True,
                    stderr=subprocess.DEVNULL,
                    timeout=2.0
                )
                paired_macs = set(re.findall(r"Device\s+([0-9A-Fa-f:]{17})", paired_out))
            except Exception:
                pass

            # Query ALL available devices (both paired and nearby scanned in BlueZ cache)
            all_devices_out = subprocess.check_output(
                ["bluetoothctl", "devices"],
                text=True,
                stderr=subprocess.DEVNULL,
                timeout=2.0
            )

            seen_macs = set()
            for line in all_devices_out.strip().splitlines():
                m = re.match(r"Device\s+([0-9A-Fa-f:]{17})\s+(.+)", line)
                if m:
                    mac = m.group(1)
                    name = m.group(2).strip()
                    if mac in seen_macs:
                        continue
                    seen_macs.add(mac)

                    is_dev_connected = (mac in connected_macs)
                    is_dev_paired = (mac in paired_macs)
                    dev_ts = history.get(mac, 0)

                    res["devices"].append({
                        "mac": mac,
                        "name": name,
                        "connected": is_dev_connected,
                        "paired": is_dev_paired,
                        "timestamp": dev_ts,
                    })

            # Strict Sorting:
            # 1. Connected devices at the very top (0)
            # 2. Paired/previously connected devices (1), sorted by last connected timestamp descending (-timestamp)
            # 3. Available/scanned devices (2)
            # 4. Alphabetical by name
            res["devices"].sort(
                key=lambda d: (
                    0 if d["connected"] else (1 if d["paired"] else 2),
                    -d.get("timestamp", 0),
                    d["name"].lower()
                )
            )

        except Exception as exc:
            res["error"] = str(exc)

        return res

    @classmethod
    def set_discoverable(cls, enable: bool) -> Tuple[bool, str]:
        """Toggles Bluetooth discoverable/pairable mode so smartphones and tablets can find the Pi."""
        if not shutil.which("bluetoothctl"):
            return False, "bluetoothctl non trovato"
        val = "on" if enable else "off"
        try:
            subprocess.run(["bluetoothctl", "discoverable", val], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=2.0)
            if enable:
                subprocess.run(["bluetoothctl", "pairable", "on"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=2.0)
            return True, f"Visibilità Bluetooth: {val}"
        except Exception as exc:
            return False, str(exc)

    @classmethod
    def scan_devices(cls, timeout_sec: int = 5) -> Tuple[bool, str]:
        """Triggers an active Bluetooth scan to discover nearby devices."""
        if not shutil.which("bluetoothctl"):
            return False, "bluetoothctl non trovato"
        try:
            subprocess.run(
                ["bluetoothctl", "--timeout", str(timeout_sec), "scan", "on"],
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=timeout_sec + 2.0
            )
            return True, "Scansione Bluetooth completata"
        except Exception as exc:
            return False, str(exc)

    @classmethod
    def connect_device(cls, mac: str) -> Tuple[bool, str]:
        """Connects to a Bluetooth device, automatically trusting and pairing if needed."""
        if not shutil.which("bluetoothctl"):
            return False, "bluetoothctl non trovato"
        try:
            # Trust device for automatic future connection
            subprocess.run(["bluetoothctl", "trust", mac], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=2.0)
            # Attempt pair (succeeds or proceeds if already paired)
            subprocess.run(["bluetoothctl", "pair", mac], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=8.0)
            # Connect
            proc = subprocess.run(["bluetoothctl", "connect", mac], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=12.0)
            if proc.returncode == 0:
                history = _load_bt_history()
                history[mac] = int(time.time())
                _save_bt_history(history)
                return True, "Connessione Bluetooth riuscita"
            return False, proc.stderr.strip() or proc.stdout.strip() or "Errore connessione Bluetooth"
        except Exception as exc:
            return False, str(exc)

    @classmethod
    def disconnect_device(cls, mac: str) -> Tuple[bool, str]:
        """Disconnects a Bluetooth device."""
        if not shutil.which("bluetoothctl"):
            return False, "bluetoothctl non trovato"
        try:
            proc = subprocess.run(["bluetoothctl", "disconnect", mac], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=8.0)
            return proc.returncode == 0, "Disconnesso"
        except Exception as exc:
            return False, str(exc)

    @classmethod
    def set_power(cls, enable: bool) -> Tuple[bool, str]:
        """Enables or disables Bluetooth adapter power."""
        if not shutil.which("bluetoothctl"):
            return False, "bluetoothctl non trovato"
        try:
            val = "on" if enable else "off"
            subprocess.run(["bluetoothctl", "power", val], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=4.0)
            return True, f"Bluetooth: {val}"
        except Exception as exc:
            return False, str(exc)

    @classmethod
    def remove_device(cls, mac: str) -> Tuple[bool, str]:
        """Unpairs and removes a Bluetooth device from BlueZ cache."""
        if not shutil.which("bluetoothctl"):
            return False, "bluetoothctl non trovato"
        try:
            proc = subprocess.run(["bluetoothctl", "remove", mac], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=6.0)
            history = _load_bt_history()
            if mac in history:
                del history[mac]
                _save_bt_history(history)
            return proc.returncode == 0, "Dispositivo rimosso"
        except Exception as exc:
            return False, str(exc)
