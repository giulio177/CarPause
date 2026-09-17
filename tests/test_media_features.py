"""
Unit and integration tests for local music library and listening history aggregation.
"""

import os
import unittest
from PyQt6.QtCore import QCoreApplication
from src.services.local_music_service import LocalMusicService
from src.services.media_history_service import MediaHistoryService
from backend import InfotainmentBackend

app = QCoreApplication.instance() or QCoreApplication([])


class TestMediaFeatures(unittest.TestCase):
    def setUp(self):
        self.project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
        self.music_dir = os.path.join(self.project_root, "music")
        self.history_dir = os.path.join(self.project_root, "media_history")

    def test_local_music_scanner(self):
        svc = LocalMusicService(self.music_dir)
        tracks = svc.scan_tracks()
        self.assertGreater(len(tracks), 0, "Should find at least 1 music track in music/")
        
        first = tracks[0]
        self.assertIn("title", first)
        self.assertIn("artist", first)
        self.assertIn("duration", first)
        self.assertIn("cover_url", first)
        self.assertIn("lyrics", first)
        self.assertTrue(first["has_lyrics"], "Track should have lyrics")
        self.assertTrue(first["has_cover"], "Track should have cover art")

    def test_unified_media_history(self):
        svc = MediaHistoryService(self.history_dir)
        history = svc.get_all_history_tracks()
        self.assertIsInstance(history, list)
        self.assertGreater(len(history), 0, "Should aggregate tracks across all session files")

        # Verify not grouped by file, and descending chronological order
        for i in range(len(history) - 1):
            t_curr = history[i].get("timestamp_sort", 0)
            t_next = history[i + 1].get("timestamp_sort", 0)
            self.assertGreaterEqual(t_curr, t_next, "History must be sorted in descending chronological order")

        # Verify required display fields
        first = history[0]
        self.assertIn("title", first)
        self.assertIn("artist", first)
        self.assertIn("status", first)
        self.assertIn("listened_time", first)
        self.assertIn("date_str", first)
        self.assertIn("time_str", first)

    def test_backend_integration(self):
        backend = InfotainmentBackend()
        self.assertEqual(backend.mediaSubView, "player")

        backend.setMediaSubView("library")
        self.assertEqual(backend.mediaSubView, "library")

        backend.setMediaSubView("history")
        self.assertEqual(backend.mediaSubView, "history")

        backend.setMediaSubView("player")
        self.assertEqual(backend.mediaSubView, "player")

        tracks = backend.localMusicTracks
        self.assertIsInstance(tracks, list)

    def test_playback_progress_and_seeking(self):
        backend = InfotainmentBackend()
        self.assertEqual(backend.trackPositionFormatted, "00:00")
        self.assertEqual(backend.trackDurationFormatted, "00:00")

        # Simulate track duration set
        backend._track_duration_ms = 185000  # 3m 05s
        self.assertEqual(backend.trackDurationFormatted, "03:05")

        # Test seeking to 50%
        backend.seekProgress(0.5)
        self.assertAlmostEqual(backend.trackProgress, 0.5)
        self.assertEqual(backend.trackPositionMs, 92500)
        self.assertEqual(backend.trackPositionFormatted, "01:32")

    def test_playback_ticker_frequency(self):
        backend = InfotainmentBackend()
        # Verify timer is configured for 500ms
        self.assertEqual(backend._playback_ticker.interval(), 500)
        self.assertTrue(backend._playback_ticker.isActive())

        # Test tick advancement when playing remote media
        backend._is_playing = True
        backend._has_media = True
        backend._media_source = "remote"
        backend._track_duration_ms = 60000
        backend._track_position_ms = 1000

        backend._on_playback_tick()
        self.assertEqual(backend.trackPositionMs, 1500)
        self.assertEqual(backend.trackPositionFormatted, "00:01")

    def test_shuffle_and_repeat(self):
        backend = InfotainmentBackend()
        # Initial states
        self.assertFalse(backend.shuffleEnabled)
        self.assertEqual(backend.repeatMode, "off")

        # Toggle shuffle
        backend.toggleShuffle()
        self.assertTrue(backend.shuffleEnabled)
        backend.toggleShuffle()
        self.assertFalse(backend.shuffleEnabled)

        # Toggle repeat cycles: off -> all -> one -> off
        backend.toggleRepeat()
        self.assertEqual(backend.repeatMode, "all")
        backend.toggleRepeat()
        self.assertEqual(backend.repeatMode, "one")
        backend.toggleRepeat()
        self.assertEqual(backend.repeatMode, "off")

    def test_media_service_shuffle_repeat(self):
        from src.services.media_service import MediaService
        # Verify function signatures and execution without throwing exceptions
        res_shuf = MediaService.set_player_shuffle(True)
        self.assertIsInstance(res_shuf, bool)
        res_rep = MediaService.set_player_repeat("all")
        self.assertIsInstance(res_rep, bool)
        res_rep_one = MediaService.set_player_repeat("one")
        self.assertIsInstance(res_rep_one, bool)
        res_rep_off = MediaService.set_player_repeat("off")
        self.assertIsInstance(res_rep_off, bool)


    def test_toggle_media_source(self):
        backend = InfotainmentBackend()
        self.assertEqual(backend.mediaSource, "remote")

        # Mock remote media info
        backend._remote_has_media = True
        backend._remote_title = "Remote BT Song"
        backend._remote_artist = "BT Artist"
        backend._remote_album = "BT Album"
        backend._has_media = True
        backend._track_title = "Remote BT Song"
        backend._track_artist = "BT Artist"
        backend._track_album = "BT Album"

        # Mock local tracks
        backend._local_tracks = [
            {
                "id": "local_1",
                "file_path": "/fake/path/song1.mp3",
                "title": "Local RPi Song",
                "artist": "RPi Artist",
                "album": "RPi Album",
                "duration_seconds": 120,
                "cover_url": "image://localmusic/cover/song1.png",
                "lyrics": "Local lyrics",
                "has_lyrics": True,
            }
        ]

        # Toggle to local
        backend.toggleMediaSource()
        self.assertEqual(backend.mediaSource, "local")
        self.assertEqual(backend._track_title, "Local RPi Song")
        self.assertEqual(backend._track_artist, "RPi Artist")
        self.assertEqual(backend.currentTrackCover, "image://localmusic/cover/song1.png")
        self.assertTrue(backend.hasLyrics)

        # Toggle shuffle on local
        backend.toggleShuffle()
        self.assertTrue(backend.shuffleEnabled)

        # Toggle back to remote
        backend.toggleMediaSource()
        self.assertEqual(backend.mediaSource, "remote")
        self.assertEqual(backend._track_title, "Remote BT Song")
        self.assertEqual(backend._track_artist, "BT Artist")
        # Remote shuffle should still be false
        self.assertFalse(backend.shuffleEnabled)

        # Toggle back to local, verify local shuffle was preserved
        backend.toggleMediaSource()
        self.assertEqual(backend.mediaSource, "local")
        self.assertTrue(backend.shuffleEnabled)

    def test_log_service_and_backend_logs(self):
        import logging
        import os
        from src.services.log_service import LogService
        
        service = LogService.get_instance()
        self.assertIsNotNone(service)
        self.assertTrue(service.current_filename.startswith("session_"))
        self.assertTrue(service.current_filename.endswith(".log"))
        self.assertTrue(os.path.exists(service.current_file_path))

        test_logger = logging.getLogger("TestLogger")
        test_msg = "Automotive test log message 12345"
        test_logger.info(test_msg)

        logs = service.read_logs()
        self.assertGreater(len(logs), 0)
        found = any(test_msg in l["message"] for l in logs)
        self.assertTrue(found)

        backend = InfotainmentBackend()
        self.assertEqual(backend.currentLogFilename, service.current_filename)
        backend.refreshLogs()
        b_logs = backend.appLogs
        self.assertIsInstance(b_logs, list)
        self.assertGreater(len(b_logs), 0)

        # Clear logs test
        backend.clearLogs()
        self.assertEqual(len(backend.appLogs), 0)
        # Check that file on disk is also empty
        self.assertEqual(os.path.getsize(service.current_file_path), 0)

    def test_max_volume_configuration(self):
        backend = InfotainmentBackend()
        # Set max volume to 150% (Linux desktop volume boost)
        backend.setMaxVolume(150)
        self.assertEqual(backend.maxVolume, 150)

        # Set volume to 150%
        backend.setVolume(150)
        self.assertEqual(backend.volume, 150)

        # Attempt to set volume above 150% -> clamped to 150%
        backend.setVolume(170)
        self.assertEqual(backend.volume, 150)

        # Lower max volume to 125% -> current volume should automatically clamp to 125%
        backend.setMaxVolume(125)
        self.assertEqual(backend.maxVolume, 125)
        self.assertEqual(backend.volume, 125)


if __name__ == "__main__":
    unittest.main()
