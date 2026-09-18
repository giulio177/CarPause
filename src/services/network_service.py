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

    _cached_networks: List[Dict[str, Any]] = []

    @classmethod
    def get_status_and_networks(cls, rescan: bool = False) -> Dict[str, Any]:
        """
        Scans for nearby networks and checks active Wi-Fi connection.
        If rescan is True, forces NetworkManager to perform an active wireless probe scan (--rescan yes).
        Returns real status dict with no fake/dummy data.
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
            "networks": list(cls._cached_networks),
            "error": "",
        }

        if not status["powered"]:
            status["networks"] = []
            return status

        try:
            # Query saved Wi-Fi connection profiles and last-connected timestamps from NetworkManager
            saved_wifi_timestamps: Dict[str, int] = {}
            try:
                con_proc = cls._run_nmcli_command(
                    ["nmcli", "-t", "-f", "NAME,TYPE,TIMESTAMP", "con", "show"],
                    timeout=5.0
                )
                if con_proc.returncode == 0:
                    for con_line in con_proc.stdout.strip().splitlines():
                        con_parts = re.split(r'(?<!\\):', con_line)
                        if len(con_parts) >= 3 and con_parts[1].strip() == "802-11-wireless":
                            prof_name = con_parts[0].replace(r"\:", ":").strip()
                            try:
                                saved_wifi_timestamps[prof_name] = int(con_parts[2].strip())
                            except ValueError:
                                saved_wifi_timestamps[prof_name] = 0
            except Exception as e:
                logger.debug("Failed to query saved connections: %s", e)

            # If rescan is True, ask NetworkManager for an active radio probe scan (--rescan yes)
            # which synchronously waits for channel probing (takes ~3-8 seconds)
            out = ""
            if rescan:
                try:
                    cmd_rescan = ["nmcli", "-t", "-f", "ACTIVE,SSID,SIGNAL,SECURITY", "dev", "wifi", "list", "--rescan", "yes"]
                    out = subprocess.check_output(cmd_rescan, text=True, stderr=subprocess.DEVNULL, timeout=15.0)
                except Exception as e:
                    logger.warning("Active Wi-Fi probe scan (--rescan yes) failed or timed out: %s. Falling back to cached list", e)

            # Fallback to cached query if not rescan or if active rescan failed
            if not out:
                cmd_cached = ["nmcli", "-t", "-f", "ACTIVE,SSID,SIGNAL,SECURITY", "dev", "wifi", "list", "--rescan", "no"]
                out = subprocess.check_output(cmd_cached, text=True, stderr=subprocess.DEVNULL, timeout=5.0)

            networks_by_ssid: Dict[str, Dict[str, Any]] = {}
            for line in out.strip().splitlines():
                parts = re.split(r'(?<!\\):', line)
                if len(parts) >= 3:
                    is_active = (parts[0].strip().lower() == "yes")
                    ssid = parts[1].replace(r"\:", ":").strip()
                    try:
                        signal_lvl = int(parts[2].strip())
                    except ValueError:
                        signal_lvl = 0
                    sec = parts[3].replace(r"\:", ":").strip() if len(parts) > 3 else ""

                    if not ssid or ssid.startswith("--"):
                        continue

                    if is_active:
                        status["connected"] = True
                        status["ssid"] = ssid
                        status["signal"] = signal_lvl

                    is_saved = (ssid in saved_wifi_timestamps)
                    last_connected_ts = saved_wifi_timestamps.get(ssid, 0)

                    if ssid not in networks_by_ssid:
                        networks_by_ssid[ssid] = {
                            "ssid": ssid,
                            "signal": signal_lvl,
                            "security": sec,
                            "active": is_active,
                            "inUse": is_active,
                            "saved": is_saved,
                            "timestamp": last_connected_ts,
                        }
                    else:
                        existing = networks_by_ssid[ssid]
                        if is_active:
                            existing["active"] = True
                            existing["inUse"] = True
                        if signal_lvl > existing["signal"]:
                            existing["signal"] = signal_lvl
                        if is_saved:
                            existing["saved"] = True
                            existing["timestamp"] = max(existing.get("timestamp", 0), last_connected_ts)

            parsed_networks = list(networks_by_ssid.values())
            # Strict Sorting:
            # 1. Active connection ALWAYS on top
            # 2. Saved networks ordered by last time connected (highest timestamp first)
            # 3. Unsaved networks ordered by signal strength
            parsed_networks.sort(
                key=lambda n: (
                    0 if n["active"] else 1,
                    -n.get("timestamp", 0),
                    -n.get("signal", 0)
                )
            )

            status["networks"] = parsed_networks
            cls._cached_networks = parsed_networks

            if status["connected"]:
                status["ip"] = cls.get_active_ip()

        except subprocess.TimeoutExpired:
            status["error"] = "Timeout scansione Wi-Fi"
            logger.warning("Wi-Fi scan timed out, preserving %d cached networks", len(cls._cached_networks))
            status["networks"] = list(cls._cached_networks)
        except Exception as exc:
            status["error"] = str(exc)
            logger.warning("Wi-Fi scan error: %s, preserving %d cached networks", exc, len(cls._cached_networks))
            status["networks"] = list(cls._cached_networks)

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
    def _run_nmcli_command(cls, cmd: List[str], timeout: float = 25.0) -> subprocess.CompletedProcess:
        """
        Executes an nmcli command. If it fails due to Polkit permissions
        ('Not authorized' or 'insufficient privileges'), automatically attempts
        passwordless 'sudo -n' fallback.
        """
        proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=timeout)
        if proc.returncode != 0:
            combined_err = (proc.stderr or "") + " " + (proc.stdout or "")
            if "not authorized" in combined_err.lower() or "insufficient privileges" in combined_err.lower():
                sudo_bin = shutil.which("sudo")
                if sudo_bin:
                    try:
                        sudo_cmd = [sudo_bin, "-n"] + cmd
                        proc_sudo = subprocess.run(sudo_cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=timeout)
                        return proc_sudo
                    except Exception as e:
                        logger.warning("sudo -n nmcli fallback failed: %s", e)
        return proc

    @classmethod
    def connect_saved_network(cls, ssid: str) -> Tuple[bool, str]:
        """Connects to a pre-saved Wi-Fi connection profile without passing passwords."""
        if not shutil.which("nmcli"):
            return False, "Comando nmcli non disponibile"

        try:
            cmd = ["nmcli", "con", "up", "id", ssid]
            proc = cls._run_nmcli_command(cmd, timeout=25.0)
            if proc.returncode == 0:
                return True, "Connessione riuscita"
            # Fallback to dev wifi connect if connection profile name differs
            cmd_fallback = ["nmcli", "dev", "wifi", "connect", ssid]
            proc_fb = cls._run_nmcli_command(cmd_fallback, timeout=25.0)
            if proc_fb.returncode == 0:
                return True, "Connessione riuscita"
            err = proc.stderr.strip() or proc_fb.stderr.strip() or "Errore di connessione"
            if err.startswith("Error:"):
                err = err.replace("Error:", "").strip()
            return False, err
        except subprocess.TimeoutExpired:
            return False, "Timeout di connessione (25 secondi)"
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
            proc = cls._run_nmcli_command(cmd, timeout=25.0)
            if proc.returncode == 0:
                return True, "Connessione riuscita"

            raw_err = (proc.stderr or "") + " " + (proc.stdout or "")
            error_msg = proc.stderr.strip() or proc.stdout.strip() or "Errore di connessione"
            logger.warning("First Wi-Fi connect attempt failed for '%s': %s", ssid, error_msg)

            # Fallback if NetworkManager complains about key-mgmt or missing properties
            if password and ("key-mgmt" in raw_err.lower() or "property is missing" in raw_err.lower() or "secrets" in raw_err.lower() or "failed to add/activate" in raw_err.lower()):
                logger.info("Attempting explicit profile creation for '%s' with wpa-psk...", ssid)
                # 1. Clean up any corrupted existing connection profile for this SSID
                cls._run_nmcli_command(["nmcli", "con", "delete", "id", ssid], timeout=5.0)
                # 2. Add explicit WPA-PSK connection profile
                add_cmd = [
                    "nmcli", "con", "add",
                    "type", "wifi",
                    "con-name", ssid,
                    "ssid", ssid,
                    "802-11-wireless-security.key-mgmt", "wpa-psk",
                    "802-11-wireless-security.psk", password
                ]
                add_proc = cls._run_nmcli_command(add_cmd, timeout=10.0)
                if add_proc.returncode == 0:
                    up_proc = cls._run_nmcli_command(["nmcli", "con", "up", "id", ssid], timeout=25.0)
                    if up_proc.returncode == 0:
                        return True, "Connessione riuscita"
                    up_err = up_proc.stderr.strip() or up_proc.stdout.strip()
                    logger.warning("wpa-psk connection up failed: %s, trying SAE (WPA3)...", up_err)
                    # If WPA-PSK fails, try WPA3-SAE
                    cls._run_nmcli_command(["nmcli", "con", "modify", ssid, "802-11-wireless-security.key-mgmt", "sae"], timeout=5.0)
                    sae_proc = cls._run_nmcli_command(["nmcli", "con", "up", "id", ssid], timeout=25.0)
                    if sae_proc.returncode == 0:
                        return True, "Connessione riuscita"
                    error_msg = sae_proc.stderr.strip() or up_err or error_msg

            # Pulizia prefisso standard nmcli
            if error_msg.startswith("Error:"):
                error_msg = error_msg.replace("Error:", "").strip()
            return False, error_msg
        except subprocess.TimeoutExpired:
            return False, "Timeout di connessione (la rete non ha risposto in 25 secondi)"
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
            cls._run_nmcli_command(["nmcli", "radio", "wifi", val], timeout=4.0)
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
                proc = cls._run_nmcli_command(["nmcli", "con", "down", "id", ssid], timeout=5.0)
                if proc.returncode == 0:
                    return True, f"Disconnesso da {ssid}"
            # Fallback: disconnect all active wireless connections
            con_out = subprocess.check_output(["nmcli", "-t", "-f", "NAME,TYPE,STATE", "con", "show", "--active"], text=True, stderr=subprocess.DEVNULL, timeout=2.0)
            for line in con_out.strip().splitlines():
                parts = re.split(r'(?<!\\):', line)
                if len(parts) >= 2 and parts[1].strip() == "802-11-wireless":
                    prof = parts[0].replace(r"\:", ":").strip()
                    cls._run_nmcli_command(["nmcli", "con", "down", "id", prof], timeout=4.0)
            return True, "Wi-Fi disconnesso"
        except Exception as exc:
            return False, str(exc)

    @classmethod
    def forget_network(cls, ssid: str) -> Tuple[bool, str]:
        """Deletes a saved Wi-Fi connection profile from NetworkManager."""
        if not shutil.which("nmcli"):
            return False, "Comando nmcli non disponibile"
        try:
            proc = cls._run_nmcli_command(["nmcli", "con", "delete", "id", ssid], timeout=5.0)
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
        """Connects to a Bluetooth device, automatically trusting, pairing, and falling back to A2DP profile if needed."""
        if not shutil.which("bluetoothctl"):
            return False, "bluetoothctl non trovato"
        try:
            logger.info("Initiating Bluetooth connection to device [%s]...", mac)

            # Trust device for automatic future connection
            subprocess.run(["bluetoothctl", "trust", mac], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=2.0)
            
            # Check pairing status
            info_proc = subprocess.run(["bluetoothctl", "info", mac], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, timeout=2.0)
            if "Paired: yes" not in info_proc.stdout:
                logger.info("Device [%s] is not yet paired. Attempting pairing...", mac)
                pair_proc = subprocess.run(["bluetoothctl", "pair", mac], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=8.0)
                logger.info("bluetoothctl pair [%s]: code=%s, out=%s, err=%s", mac, pair_proc.returncode, pair_proc.stdout.strip(), pair_proc.stderr.strip())
                
            # Attempt whole-device connect via bluetoothctl
            proc = subprocess.run(["bluetoothctl", "connect", mac], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=12.0)
            logger.info("bluetoothctl connect [%s]: code=%s, out=%s, err=%s", mac, proc.returncode, proc.stdout.strip(), proc.stderr.strip())

            # Verify real connection state directly via info
            verify_proc = subprocess.run(["bluetoothctl", "info", mac], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, timeout=2.0)
            is_connected = "Connected: yes" in verify_proc.stdout

            # Fallback: Many smartphones (especially iPhones) reject broad device Connect() from sink devices
            # but accept specific A2DP Source / Audio profile ConnectProfile()
            if not is_connected:
                logger.info("Whole-device connect did not report connected. Attempting D-Bus A2DP profile connection to [%s]...", mac)
                try:
                    dbus_mac = "dev_" + mac.replace(":", "_").upper()
                    dev_path = f"/org/bluez/hci0/{dbus_mac}"
                    cmd_dbus = [
                        "dbus-send", "--system", "--type=method_call",
                        "--dest=org.bluez", dev_path,
                        "org.bluez.Device1.ConnectProfile",
                        "string:0000110a-0000-1000-8000-00805f9b34fb"
                    ]
                    dbus_proc = subprocess.run(cmd_dbus, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=6.0)
                    logger.info("D-Bus A2DP ConnectProfile [%s]: code=%s, err=%s", mac, dbus_proc.returncode, dbus_proc.stderr.strip())

                    # Also try AVRCP Control profile
                    cmd_dbus_avrcp = [
                        "dbus-send", "--system", "--type=method_call",
                        "--dest=org.bluez", dev_path,
                        "org.bluez.Device1.ConnectProfile",
                        "string:0000110e-0000-1000-8000-00805f9b34fb"
                    ]
                    subprocess.run(cmd_dbus_avrcp, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=4.0)

                    time.sleep(0.5)
                    verify_proc2 = subprocess.run(["bluetoothctl", "info", mac], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, timeout=2.0)
                    is_connected = "Connected: yes" in verify_proc2.stdout
                except Exception as dbus_err:
                    logger.warning("D-Bus ConnectProfile fallback error for [%s]: %s", mac, dbus_err)

            if is_connected or proc.returncode == 0 or "Connection successful" in proc.stdout:
                history = _load_bt_history()
                history[mac] = int(time.time())
                _save_bt_history(history)
                logger.info("Successfully connected to Bluetooth device [%s]", mac)
                return True, "Connessione Bluetooth riuscita"

            err = proc.stderr.strip() or proc.stdout.strip() or "Errore connessione Bluetooth"
            logger.warning("Bluetooth connection to [%s] failed: %s", mac, err)
            return False, err
        except Exception as exc:
            logger.error("Exception while connecting to Bluetooth [%s]: %s", mac, exc)
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
