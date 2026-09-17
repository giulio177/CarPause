"""
media_history_service.py - Automotive Media Playback History Logger
Saves playback sessions (one file per application startup, named with startup timestamp).
Tracks listened tracks, playback duration, active listened time, progress, and completion status.
ZERO DUMMY DATA: only logs actual played tracks from real media sources (BlueZ AVRCP / MPRIS).
"""

import os
import time
import json
import logging
from datetime import datetime
from typing import Optional, Dict, Any, List

logger = logging.getLogger("MediaHistoryService")


def format_duration(seconds: float) -> str:
    """Formats seconds into MM:SS or HH:MM:SS string."""
    s = max(0, int(seconds))
    m, s = divmod(s, 60)
    h, m = divmod(m, 60)
    if h > 0:
        return f"{h:02d}:{m:02d}:{s:02d}"
    return f"{m:02d}:{s:02d}"


class MediaHistoryService:
    """
    Session-based audio playback logger.
    Creates a new JSON file on startup inside 'media_history/' directory.
    Accurately tracks how long each track was listened to and whether it completed.
    """

    IGNORABLE_TITLES = {
        "", "traccia bluetooth", "audio bluetooth connesso",
        "pronto per la riproduzione", "senza titolo", "dispositivo connesso"
    }

    def __init__(self, base_dir: Optional[str] = None):
        if base_dir is None:
            # Default to project root: Mito/media_history
            base_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "media_history"))

        self._base_dir = base_dir
        os.makedirs(self._base_dir, exist_ok=True)

        # Clean up any empty session files from previous runs
        self._cleanup_empty_history_files()

        self._session_start = datetime.now()
        self._session_time_str = self._session_start.strftime("%Y-%m-%d %H:%M:%S")
        file_timestamp = self._session_start.strftime("%Y-%m-%d_%H-%M-%S")
        self._file_name = f"session_{file_timestamp}.json"
        self._file_path = os.path.join(self._base_dir, self._file_name)

        # Track tracking state
        self._active_track: Optional[Dict[str, Any]] = None
        self._tracks: List[Dict[str, Any]] = []
        self._last_tick_time: float = time.time()
        self._last_flush_time: float = 0.0

        # Create initial session file
        self._flush_session_file()
        logger.info("MediaHistoryService initialized session log: %s", self._file_path)

    def _cleanup_empty_history_files(self) -> int:
        """
        Scans media_history directory on app startup for empty session files
        (files with only header and no tracks) and deletes them.
        """
        removed_count = 0
        if not os.path.exists(self._base_dir):
            return 0

        for entry in os.listdir(self._base_dir):
            if not entry.startswith("session_") or not entry.endswith(".json"):
                continue
            file_path = os.path.join(self._base_dir, entry)
            # Skip current session file if already assigned
            if hasattr(self, "_file_path") and file_path == self._file_path:
                continue
            try:
                if os.path.isfile(file_path):
                    with open(file_path, "r", encoding="utf-8") as f:
                        data = json.load(f)
                    tracks = data.get("tracks", [])
                    total = data.get("total_tracks", 0)
                    if len(tracks) == 0 or total == 0:
                        os.remove(file_path)
                        removed_count += 1
                        logger.info("Removed empty media history session file: %s", entry)
            except Exception as exc:
                logger.debug("Skipping file %s during cleanup: %s", entry, exc)

        if removed_count > 0:
            logger.info("Cleaned up %d empty session file(s) from %s", removed_count, self._base_dir)
        return removed_count

    @property
    def session_file_path(self) -> str:
        return self._file_path

    def update_playback(
        self,
        title: str,
        artist: str,
        album: str,
        is_playing: bool,
        duration_ms: int = 0,
        position_ms: int = 0
    ) -> None:
        """
        Main update method called periodically or on media changes.
        Accumulates listening seconds while is_playing is True.
        Detects track transitions and finalizes track completion stats.
        """
        now = time.time()
        dt = max(0.0, now - self._last_tick_time)
        self._last_tick_time = now

        clean_title = (title or "").strip()
        clean_artist = (artist or "").strip()
        clean_album = (album or "").strip()

        # Check if valid real media track (not placeholder/empty)
        is_real_track = clean_title.lower() not in self.IGNORABLE_TITLES and bool(clean_title)

        # 1. No track currently active
        if self._active_track is None:
            if is_real_track and is_playing:
                self._start_new_track(clean_title, clean_artist, clean_album, duration_ms, position_ms)
            return

        # 2. Check if the active track changed (new song started)
        current_title = self._active_track.get("title", "")
        current_artist = self._active_track.get("artist", "")

        is_same_track = (
            clean_title.lower() == current_title.lower() and
            clean_artist.lower() == current_artist.lower()
        )

        if not is_same_track:
            # Finalize previous track
            self._finalize_active_track()

            # If new track is playing, start tracking it
            if is_real_track and is_playing:
                self._start_new_track(clean_title, clean_artist, clean_album, duration_ms, position_ms)
            else:
                self._active_track = None
            self._flush_session_file()
            return

        # 3. Same track continuing
        track = self._active_track

        # Update duration if newly reported
        if duration_ms > 0:
            dur_sec = duration_ms / 1000.0
            if dur_sec > track["duration_seconds"]:
                track["duration_seconds"] = round(dur_sec, 1)
                track["duration"] = format_duration(dur_sec)

        # Update position
        if position_ms > 0:
            pos_sec = position_ms / 1000.0
            if pos_sec > track["max_position_seconds"]:
                track["max_position_seconds"] = round(pos_sec, 1)

        # If playing, accumulate listened seconds
        # Clamp dt to 3.0s max to prevent jumps if app was suspended/sleeping
        if is_playing:
            effective_dt = min(dt, 3.0)
            track["listened_seconds"] = round(track["listened_seconds"] + effective_dt, 1)
            track["listened_time"] = format_duration(track["listened_seconds"])

        # Calculate progress and completion
        dur = track["duration_seconds"]
        if dur > 0:
            best_progress = max(track["listened_seconds"], track["max_position_seconds"])
            pct = min(100.0, round((best_progress / dur) * 100.0, 1))
            track["progress_percent"] = pct

            # Considered completed if listened >= 88% of duration or reached near end
            if pct >= 88.0 or (dur - track["max_position_seconds"] <= 8.0 and dur > 30.0):
                track["completed"] = True
                track["status"] = "Completata"
            elif is_playing:
                track["status"] = f"In riproduzione ({pct:.0f}%)"
            else:
                track["status"] = f"In pausa ({pct:.0f}%)"
        else:
            track["progress_percent"] = None
            if is_playing:
                track["status"] = f"In riproduzione ({track['listened_time']})"
            else:
                track["status"] = f"In pausa ({track['listened_time']})"

        # Flush periodically (every 5 seconds) while playing
        if now - self._last_flush_time > 5.0:
            self._flush_session_file()

    def _start_new_track(
        self,
        title: str,
        artist: str,
        album: str,
        duration_ms: int,
        position_ms: int
    ) -> None:
        """Starts tracking a new audio track entry."""
        now_dt = datetime.now()
        dur_sec = round(duration_ms / 1000.0, 1) if duration_ms > 0 else 0.0
        pos_sec = round(position_ms / 1000.0, 1) if position_ms > 0 else 0.0

        self._active_track = {
            "title": title,
            "artist": artist or "Sconosciuto",
            "album": album or "",
            "started_at": now_dt.strftime("%H:%M:%S"),
            "ended_at": None,
            "duration": format_duration(dur_sec) if dur_sec > 0 else "Sconosciuta",
            "duration_seconds": dur_sec,
            "listened_time": "00:00",
            "listened_seconds": 0.0,
            "max_position_seconds": pos_sec,
            "progress_percent": 0.0 if dur_sec > 0 else None,
            "completed": False,
            "status": "In riproduzione",
        }
        self._tracks.append(self._active_track)
        self._flush_session_file()
        logger.info("Media history: started tracking '%s' by '%s'", title, artist)

    def _finalize_active_track(self) -> None:
        """Finalizes the active track stats when song changes or session terminates."""
        if not self._active_track:
            return

        track = self._active_track
        track["ended_at"] = datetime.now().strftime("%H:%M:%S")

        dur = track.get("duration_seconds", 0.0)
        listened = track.get("listened_seconds", 0.0)
        max_pos = track.get("max_position_seconds", 0.0)

        if dur > 0:
            best_progress = max(listened, max_pos)
            pct = min(100.0, round((best_progress / dur) * 100.0, 1))
            track["progress_percent"] = pct

            if pct >= 88.0 or (dur - max_pos <= 8.0 and dur > 30.0):
                track["completed"] = True
                track["status"] = "Completata"
            elif listened < 10.0 and pct < 15.0:
                track["completed"] = False
                track["status"] = f"Saltata ({int(listened)}s)"
            else:
                track["completed"] = False
                track["status"] = f"Parziale ({pct:.0f}%)"
        else:
            track["completed"] = False
            track["progress_percent"] = None
            if listened < 10.0:
                track["status"] = f"Saltata ({int(listened)}s)"
            else:
                track["status"] = f"Ascoltata ({track['listened_time']})"

        logger.info(
            "Media history: finalized track '%s' - Listened: %s, Completed: %s, Status: %s",
            track.get("title"), track.get("listened_time"), track.get("completed"), track.get("status")
        )

    def close_session(self) -> None:
        """Finalizes any active track and flushes session or deletes file if empty."""
        if self._active_track:
            self._finalize_active_track()
            self._active_track = None

        if len(self._tracks) == 0:
            if os.path.exists(self._file_path):
                try:
                    os.remove(self._file_path)
                    logger.info("Removed empty current session file on close: %s", self._file_path)
                except Exception as exc:
                    logger.debug("Error removing empty session file: %s", exc)
        else:
            self._flush_session_file()
            logger.info("MediaHistoryService closed session file: %s", self._file_path)

    def _flush_session_file(self) -> None:
        """Atomically writes session data to JSON file on disk."""
        os.makedirs(self._base_dir, exist_ok=True)
        data = {
            "session_started": self._session_time_str,
            "session_file": self._file_name,
            "last_updated": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            "total_tracks": len(self._tracks),
            "tracks": self._tracks,
        }

        tmp_path = f"{self._file_path}.tmp"
        try:
            with open(tmp_path, "w", encoding="utf-8") as f:
                json.dump(data, f, indent=2, ensure_ascii=False)
            os.replace(tmp_path, self._file_path)
            self._last_flush_time = time.time()
        except Exception as exc:
            logger.error("Failed writing media history session file: %s", exc)

    def get_all_history_tracks(self) -> List[Dict[str, Any]]:
        """
        Aggregates all listened tracks from all session files (and the current active session)
        into a single flat chronological list, sorted newest first.
        ZERO DUMMY DATA: only reads actual persisted and active listening records.
        """
        all_entries: List[Dict[str, Any]] = []
        seen_keys: Dict[str, Dict[str, Any]] = {}

        # Month names for Italian automotive date formatting
        months = ["Gen", "Feb", "Mar", "Apr", "Mag", "Giu", "Lug", "Ago", "Set", "Ott", "Nov", "Dic"]

        def parse_datetime(date_str: str, time_str: str):
            try:
                full_str = f"{date_str} {time_str}"
                return datetime.strptime(full_str, "%Y-%m-%d %H:%M:%S")
            except Exception:
                try:
                    return datetime.strptime(date_str, "%Y-%m-%d")
                except Exception:
                    return datetime.now()

        # 1. Read past and saved session files
        if os.path.exists(self._base_dir):
            for entry in sorted(os.listdir(self._base_dir)):
                if not entry.startswith("session_") or not entry.endswith(".json"):
                    continue
                file_path = os.path.join(self._base_dir, entry)
                # If it's current session, we prefer in-memory self._tracks
                if hasattr(self, "_file_path") and file_path == self._file_path and len(self._tracks) > 0:
                    continue

                try:
                    with open(file_path, "r", encoding="utf-8") as f:
                        session_data = json.load(f)
                    session_started = session_data.get("session_started", "")
                    session_date = session_started.split(" ")[0] if " " in session_started else "2026-09-17"
                    tracks = session_data.get("tracks", [])

                    for tr in tracks:
                        self._process_history_item(tr, session_date, seen_keys, months)
                except Exception as exc:
                    logger.debug("Error reading history session %s: %s", entry, exc)

        # 2. Include in-memory tracks from current session
        current_date = self._session_start.strftime("%Y-%m-%d")
        for tr in self._tracks:
            self._process_history_item(tr, current_date, seen_keys, months)

        all_entries = list(seen_keys.values())

        # Sort descending by timestamp (newest first)
        all_entries.sort(key=lambda x: x.get("timestamp_sort", 0), reverse=True)
        return all_entries

    def _process_history_item(
        self,
        tr: Dict[str, Any],
        date_str: str,
        seen_keys: Dict[str, Dict[str, Any]],
        months: List[str]
    ) -> None:
        title = (tr.get("title") or "").strip()
        artist = (tr.get("artist") or "").strip()
        if not title or title.lower() in self.IGNORABLE_TITLES:
            return

        started_at = tr.get("started_at") or "00:00:00"
        try:
            dt = datetime.strptime(f"{date_str} {started_at}", "%Y-%m-%d %H:%M:%S")
        except Exception:
            try:
                dt = datetime.strptime(date_str, "%Y-%m-%d")
            except Exception:
                dt = datetime.now()

        m_idx = dt.month - 1
        m_name = months[m_idx] if 0 <= m_idx < len(months) else f"{dt.month:02d}"
        formatted_date = f"{dt.day:02d} {m_name}"
        time_hm = dt.strftime("%H:%M")

        # Dedup key: same title, artist, and started_at
        dedup_key = f"{date_str}_{started_at}_{title.lower()}_{artist.lower()}"

        item = {
            "title": title,
            "artist": artist or "Sconosciuto",
            "album": tr.get("album", ""),
            "duration": tr.get("duration") or "00:00",
            "duration_seconds": tr.get("duration_seconds", 0.0),
            "listened_time": tr.get("listened_time") or "00:00",
            "listened_seconds": tr.get("listened_seconds", 0.0),
            "progress_percent": tr.get("progress_percent") if tr.get("progress_percent") is not None else 0.0,
            "completed": bool(tr.get("completed", False)),
            "status": tr.get("status") or ("Completata" if tr.get("completed") else "Ascoltata"),
            "timestamp_sort": dt.timestamp(),
            "date_str": formatted_date,
            "time_str": time_hm,
            "started_at": started_at,
        }

        if dedup_key in seen_keys:
            existing = seen_keys[dedup_key]
            # Keep the version with highest listened seconds or progress
            if item["listened_seconds"] >= existing["listened_seconds"]:
                seen_keys[dedup_key] = item
        else:
            seen_keys[dedup_key] = item

