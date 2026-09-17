"""
log_service.py - Automotive Session Log File Manager & Reader
Creates a new log file on each startup inside 'logs/' directory (named with timestamp, similar to media_history).
Writes all application logs into the session file and provides structured log reading for the UI.
"""

import os
import re
import sys
import logging
from datetime import datetime
from typing import Optional, Dict, Any, List, Callable


LOG_FORMAT = "%(asctime)s [%(levelname)s] [%(name)s]: %(message)s"
LOG_DATEFMT = "%Y-%m-%d %H:%M:%S"
LOG_REGEX = re.compile(r"^(\d{4}-\d{2}-\d{2}\s+(\d{2}:\d{2}:\d{2}))\s+\[([A-Z]+)\]\s+\[(.*?)\]:\s*(.*)$")


class SessionFileHandler(logging.FileHandler):
    """FileHandler that flushes immediately to disk and triggers an optional callback."""
    def __init__(self, filename: str, on_new_record: Optional[Callable[[], None]] = None):
        os.makedirs(os.path.dirname(os.path.abspath(filename)), exist_ok=True)
        super().__init__(filename, mode="a", encoding="utf-8")
        self._on_new_record = on_new_record

    def emit(self, record: logging.LogRecord) -> None:
        super().emit(record)
        self.flush()
        if self._on_new_record:
            try:
                self._on_new_record()
            except Exception:
                pass


class LogService:
    """
    Manages session log files in 'logs/'.
    Similar to MediaHistoryService:
    - Creates a new session file per application startup (session_YYYY-MM-DD_HH-MM-SS.log).
    - Cleans up empty 0-byte log files from prior sessions.
    - Exposes structured reading of the current or selected log file.
    """
    _instance: Optional["LogService"] = None

    def __init__(self, base_dir: Optional[str] = None, on_new_record: Optional[Callable[[], None]] = None):
        if base_dir is None:
            # Default to project root: Mito/logs
            base_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "logs"))

        self._base_dir = base_dir
        os.makedirs(self._base_dir, exist_ok=True)
        self._on_new_record = on_new_record

        # Clean up empty files from previous runs
        self._cleanup_empty_log_files()

        # Session timestamp
        self._session_start = datetime.now()
        file_timestamp = self._session_start.strftime("%Y-%m-%d_%H-%M-%S")
        self._current_filename = f"session_{file_timestamp}.log"
        self._current_file_path = os.path.join(self._base_dir, self._current_filename)

        # Create file handler
        self._file_handler = SessionFileHandler(self._current_file_path, on_new_record=self._on_record_emitted)
        formatter = logging.Formatter(LOG_FORMAT, datefmt=LOG_DATEFMT)
        self._file_handler.setFormatter(formatter)
        self._file_handler.setLevel(logging.INFO)

        # Attach to root logger
        root_logger = logging.getLogger()
        if root_logger.level > logging.INFO or root_logger.level == logging.NOTSET:
            root_logger.setLevel(logging.INFO)
        root_logger.addHandler(self._file_handler)

        logging.getLogger("LogService").info("Session log initialized: %s", self._current_file_path)

    @classmethod
    def get_instance(cls, base_dir: Optional[str] = None, on_new_record: Optional[Callable[[], None]] = None) -> "LogService":
        if cls._instance is None:
            cls._instance = LogService(base_dir=base_dir, on_new_record=on_new_record)
        elif on_new_record and cls._instance._on_new_record is None:
            cls._instance._on_new_record = on_new_record
            cls._instance._file_handler._on_new_record = cls._instance._on_record_emitted
        return cls._instance

    @classmethod
    def get_handler(cls) -> "LogService":
        """Returns the singleton LogService instance."""
        return cls.get_instance()

    def get_logs(self) -> List[Dict[str, Any]]:
        """Alias for read_logs() reading current session file from disk."""
        return self.read_logs()

    def _on_record_emitted(self) -> None:
        if self._on_new_record:
            self._on_new_record()

    @property
    def current_filename(self) -> str:
        return self._current_filename

    @property
    def current_file_path(self) -> str:
        return self._current_file_path

    def _cleanup_empty_log_files(self) -> int:
        """Deletes 0-byte log files from prior sessions."""
        count = 0
        if not os.path.exists(self._base_dir):
            return 0
        for entry in os.listdir(self._base_dir):
            if entry.startswith("session_") and entry.endswith(".log"):
                fp = os.path.join(self._base_dir, entry)
                try:
                    if os.path.isfile(fp) and os.path.getsize(fp) == 0:
                        os.remove(fp)
                        count += 1
                except Exception:
                    pass
        return count

    def read_logs(self, filename: Optional[str] = None) -> List[Dict[str, Any]]:
        """
        Reads and parses the specified log file (or current session file) from disk.
        Returns a list of structured log dictionaries.
        """
        target_path = self._current_file_path
        if filename:
            target_path = os.path.join(self._base_dir, filename)

        if not os.path.exists(target_path):
            return []

        entries: List[Dict[str, Any]] = []
        try:
            with open(target_path, "r", encoding="utf-8", errors="replace") as f:
                for line in f:
                    line_clean = line.rstrip("\r\n")
                    if not line_clean:
                        continue
                    m = LOG_REGEX.match(line_clean)
                    if m:
                        entries.append({
                            "datetime": m.group(1),
                            "time": m.group(2),
                            "level": m.group(3),
                            "name": m.group(4),
                            "message": m.group(5),
                            "raw": line_clean,
                        })
                    else:
                        if entries:
                            entries[-1]["message"] += "\n" + line_clean
                            entries[-1]["raw"] += "\n" + line_clean
                        else:
                            entries.append({
                                "datetime": "",
                                "time": "",
                                "level": "INFO",
                                "name": "System",
                                "message": line_clean,
                                "raw": line_clean,
                            })
        except Exception as exc:
            logging.getLogger("LogService").error("Failed to read log file: %s", exc)

        return entries

    def clear_current_log(self) -> None:
        """Clears the contents of the current session log file."""
        try:
            os.makedirs(self._base_dir, exist_ok=True)
            with open(self._current_file_path, "w", encoding="utf-8") as f:
                f.truncate(0)
            if self._on_new_record:
                self._on_new_record()
        except Exception as exc:
            logging.getLogger("LogService").error("Failed to truncate log file: %s", exc)

    def get_log_files(self) -> List[str]:
        """Returns all session log files in logs/ sorted descending by timestamp."""
        if not os.path.exists(self._base_dir):
            return []
        files = [
            f for f in os.listdir(self._base_dir)
            if f.startswith("session_") and f.endswith(".log")
        ]
        files.sort(reverse=True)
        return files
