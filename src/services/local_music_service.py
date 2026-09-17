"""
local_music_service.py - Raspberry Pi Local Music Library Scanner and Metadata Parser
Scans the local project 'music/' directory for audio files and their sidecar metadata:
- Audio tracks: .mp3, .wav, .ogg, .flac, .m4a, .aac
- Metadata: <filename>.json or directory metadata.json
- Cover artwork: <filename>.png, <filename>.jpg, cover.png, cover.jpg
- Lyrics: <filename>.lrc, <filename>.txt, or embedded in metadata JSON
ZERO DUMMY DATA: strictly scans and returns actual files present on the filesystem.
"""

import os
import json
import logging
import subprocess
from typing import List, Dict, Any, Optional

logger = logging.getLogger("LocalMusicService")


def format_duration(seconds: float) -> str:
    """Formats seconds into MM:SS string."""
    s = max(0, int(seconds))
    m, s = divmod(s, 60)
    h, m = divmod(m, 60)
    if h > 0:
        return f"{h:02d}:{m:02d}:{s:02d}"
    return f"{m:02d}:{s:02d}"


class LocalMusicService:
    SUPPORTED_EXTENSIONS = {".mp3", ".wav", ".ogg", ".flac", ".m4a", ".aac"}
    COVER_EXTENSIONS = {".png", ".jpg", ".jpeg", ".webp"}
    LYRICS_EXTENSIONS = {".lrc", ".txt"}

    def __init__(self, music_dir: Optional[str] = None):
        if music_dir is None:
            music_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "music"))
        self._music_dir = music_dir
        os.makedirs(self._music_dir, exist_ok=True)

    @property
    def music_dir(self) -> str:
        return self._music_dir

    def scan_tracks(self) -> List[Dict[str, Any]]:
        """
        Scans the music directory for audio tracks and associates sidecar metadata.
        Returns a sorted list of track dictionaries.
        """
        if not os.path.exists(self._music_dir):
            return []

        tracks: List[Dict[str, Any]] = []

        try:
            for root, _, files in os.walk(self._music_dir):
                for file in files:
                    ext = os.path.splitext(file)[1].lower()
                    if ext not in self.SUPPORTED_EXTENSIONS:
                        continue

                    file_path = os.path.join(root, file)
                    track_info = self._parse_track(file_path)
                    if track_info:
                        tracks.append(track_info)
        except Exception as exc:
            logger.error("Error scanning music directory %s: %s", self._music_dir, exc)

        # Sort alphabetically by title
        tracks.sort(key=lambda t: t.get("title", "").lower())
        logger.info("LocalMusicService found %d tracks in %s", len(tracks), self._music_dir)
        return tracks

    def _parse_track(self, file_path: str) -> Optional[Dict[str, Any]]:
        """Parses an audio file and its accompanying metadata, cover art, and lyrics."""
        try:
            file_dir = os.path.dirname(file_path)
            file_name = os.path.basename(file_path)
            stem, ext = os.path.splitext(file_name)

            # 1. Look for sidecar JSON metadata
            meta: Dict[str, Any] = {}
            json_candidates = [
                os.path.join(file_dir, f"{stem}.json"),
                os.path.join(file_dir, "metadata.json")
            ]
            for jpath in json_candidates:
                if os.path.isfile(jpath):
                    try:
                        with open(jpath, "r", encoding="utf-8") as f:
                            data = json.load(f)
                            if isinstance(data, dict):
                                meta = data
                                break
                    except Exception as jexc:
                        logger.debug("Failed reading JSON metadata %s: %s", jpath, jexc)

            # 2. Track Title, Artist, Album with filename fallback
            title = meta.get("title")
            artist = meta.get("artist")
            album = meta.get("album", "")

            if not title:
                # If filename format is "Artist - Title"
                if " - " in stem:
                    parts = stem.split(" - ", 1)
                    artist = artist or parts[0].strip()
                    title = parts[1].strip()
                else:
                    title = stem.replace("_", " ").replace("-", " ").strip()

            if not artist:
                artist = "Libreria Raspberry"

            # 3. Look for cover artwork
            cover_url = ""
            if meta.get("cover"):
                cover_candidate = os.path.join(file_dir, meta["cover"])
                if os.path.isfile(cover_candidate):
                    cover_url = "file://" + os.path.abspath(cover_candidate)

            if not cover_url:
                for c_ext in self.COVER_EXTENSIONS:
                    candidate = os.path.join(file_dir, f"{stem}{c_ext}")
                    if os.path.isfile(candidate):
                        cover_url = "file://" + os.path.abspath(candidate)
                        break

            if not cover_url:
                for default_cover in ["cover.png", "cover.jpg", "album.png", "album.jpg"]:
                    candidate = os.path.join(file_dir, default_cover)
                    if os.path.isfile(candidate):
                        cover_url = "file://" + os.path.abspath(candidate)
                        break

            # 4. Look for lyrics (.lrc or .txt or json)
            lyrics = meta.get("lyrics", "")
            if not lyrics and meta.get("lyrics_file"):
                l_path = os.path.join(file_dir, meta["lyrics_file"])
                if os.path.isfile(l_path):
                    try:
                        with open(l_path, "r", encoding="utf-8") as lf:
                            lyrics = lf.read().strip()
                    except Exception:
                        pass

            if not lyrics:
                for l_ext in self.LYRICS_EXTENSIONS:
                    candidate = os.path.join(file_dir, f"{stem}{l_ext}")
                    if os.path.isfile(candidate):
                        try:
                            with open(candidate, "r", encoding="utf-8") as lf:
                                lyrics = lf.read().strip()
                                break
                        except Exception:
                            pass

            # 5. Determine duration
            duration_sec = float(meta.get("duration", 0.0))
            if duration_sec <= 0:
                duration_sec = self._probe_audio_duration(file_path)

            return {
                "id": stem,
                "file_path": os.path.abspath(file_path),
                "title": title,
                "artist": artist,
                "album": album,
                "duration_seconds": round(duration_sec, 1),
                "duration": format_duration(duration_sec),
                "cover_url": cover_url,
                "has_cover": bool(cover_url),
                "lyrics": lyrics,
                "has_lyrics": bool(lyrics),
                "year": meta.get("year", ""),
                "genre": meta.get("genre", ""),
            }

        except Exception as exc:
            logger.warning("Error parsing audio file %s: %s", file_path, exc)
            return None

    def _probe_audio_duration(self, file_path: str) -> float:
        """Tries to probe audio duration via ffprobe or file size estimation."""
        try:
            cmd = [
                "ffprobe", "-v", "error", "-show_entries", "format=duration",
                "-of", "default=noprint_wrappers=1:nokey=1", file_path
            ]
            res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, timeout=1.0)
            if res.returncode == 0 and res.stdout.strip():
                return float(res.stdout.strip())
        except Exception:
            pass
        return 0.0
