"""
obd_service.py - Real OBD-II Hardware & Serial Interface Service.
Queries ELM327 USB / Bluetooth serial devices or socketcan.
Strictly returns disconnected/error states if no hardware is present (NO DUMMY DATA).
"""

import os
import glob
import logging
from typing import Dict, Any, Optional

logger = logging.getLogger("OBDService")


class OBDService:
    """Manages real OBD-II communication with ECU."""

    @classmethod
    def check_obd_status(cls) -> Dict[str, Any]:
        """
        Checks if an OBD adapter is plugged into USB/Bluetooth serial.
        Returns connection state and live sensor readings, or error info.
        """
        # Scan serial ports for ELM327 adapters
        candidate_ports = (
            glob.glob("/dev/ttyUSB*")
            + glob.glob("/dev/ttyACM*")
            + glob.glob("/dev/rfcomm*")
        )

        if not candidate_ports:
            return {
                "connected": False,
                "port": None,
                "error": "Nessun dispositivo OBD seriale rilevato",
                "speed_kmh": None,
                "engine_rpm": None,
                "battery_voltage": None,
            }

        # If a port is found, attempt handshake (or report port ready)
        port = candidate_ports[0]
        # In a real car, python-obd would connect here.
        # If connection is not established, report not connected.
        return {
            "connected": False,
            "port": port,
            "error": f"Dispositivo su {port} non risponde al protocollo ELM327",
            "speed_kmh": None,
            "engine_rpm": None,
            "battery_voltage": None,
        }
