"""
map_service.py - OpenStreetMap (OSM) service and local tile caching proxy.
Provides:
- Local multi-threaded HTTP tile proxy (127.0.0.1:8585) serving cached tiles to QML.
- Offline disk caching in ~/.cache/mito_maps/ with sub-second retrieval.
- Geocoding and POI search via OpenStreetMap Nominatim API.
- Slippy map projection calculations (lat/lon <-> tile coordinates).
- Persistent favorites/bookmarks management.
"""

import os
import math
import json
import shutil
import logging
import urllib.request
import urllib.parse
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler
import threading
from pathlib import Path
from typing import List, Dict, Any, Tuple, Optional

logger = logging.getLogger("MapService")

# Tile Server Providers
TILE_PROVIDERS: Dict[str, str] = {
    "dark": "https://basemaps.cartocdn.com/rastertiles/dark_all/{z}/{x}/{y}.png",
    "dark_clean": "https://basemaps.cartocdn.com/rastertiles/dark_nolabels/{z}/{x}/{y}.png",
    "osm": "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
    "voyager": "https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png",
}

# 256x256 1-pixel dark fallback PNG
FALLBACK_DARK_PNG = bytes([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
    0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
    0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x18, 0x18, 0x18, 0x00,
    0x00, 0x00, 0x42, 0x00, 0x01, 0x2A, 0x2A, 0x7E, 0x7D, 0x00, 0x00, 0x00,
    0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82
])


class TileProxyHandler(BaseHTTPRequestHandler):
    """Serves map tiles from local disk cache, fetching and caching on demand."""

    cache_dir: Path = Path.home() / ".cache" / "mito_maps"
    carto_api_key: str = ""

    def do_GET(self) -> None:
        # Expected path format: /tiles/{theme}/{z}/{x}/{y}.png
        path = self.path.lstrip("/").split("?")[0]
        parts = path.split("/")

        if len(parts) != 5 or parts[0] != "tiles":
            self.send_error(404, "Invalid tile path")
            return

        _, theme, z_str, x_str, y_filename = parts
        y_str = y_filename.replace(".png", "")

        try:
            z = int(z_str)
            x = int(x_str)
            y = int(y_str)
        except ValueError:
            self.send_error(400, "Invalid tile coordinates")
            return

        tile_bytes = self._get_tile(theme, z, x, y)
        if tile_bytes:
            self.send_response(200)
            self.send_header("Content-Type", "image/png")
            self.send_header("Content-Length", str(len(tile_bytes)))
            self.send_header("Cache-Control", "public, max-age=604800")
            self.end_headers()
            try:
                self.wfile.write(tile_bytes)
            except (BrokenPipeError, ConnectionResetError):
                pass
        else:
            # Send dark fallback tile
            self.send_response(200)
            self.send_header("Content-Type", "image/png")
            self.send_header("Content-Length", str(len(FALLBACK_DARK_PNG)))
            self.end_headers()
            try:
                self.wfile.write(FALLBACK_DARK_PNG)
            except Exception:
                pass

    def _get_tile(self, theme: str, z: int, x: int, y: int) -> Optional[bytes]:
        tile_file = self.cache_dir / theme / str(z) / str(x) / f"{y}.png"
        if tile_file.exists() and tile_file.stat().st_size > 0:
            try:
                return tile_file.read_bytes()
            except Exception:
                pass

        # Not in cache, fetch from upstream provider
        tmpl = TILE_PROVIDERS.get(theme, TILE_PROVIDERS["dark"])
        url = tmpl.format(z=z, x=x, y=y)
        if "cartocdn.com" in url and self.carto_api_key:
            url += f"?key={self.carto_api_key}"

        try:
            req = urllib.request.Request(
                url,
                headers={
                    "User-Agent": "MitoInfotainment/1.0 (RaspberryPi; Automotive Dashboard)",
                    "Accept": "image/png,image/*",
                },
            )
            with urllib.request.urlopen(req, timeout=3.5) as response:
                if response.status == 200:
                    data = response.read()
                    # Save to local disk cache asynchronously
                    try:
                        tile_file.parent.mkdir(parents=True, exist_ok=True)
                        tile_file.write_bytes(data)
                    except Exception as save_err:
                        logger.debug("Failed to write tile cache for %s: %s", tile_file, save_err)
                    return data
        except Exception as exc:
            logger.debug("Tile fetch failed for %s/%d/%d/%d: %s", theme, z, x, y, exc)

        return None

    def log_message(self, format: str, *args: Any) -> None:
        # Suppress HTTP server stdout/stderr console logging to keep terminal clean
        pass


class MapService:
    """Singleton service for OpenStreetMap management."""

    _instance: Optional["MapService"] = None

    def __init__(self, port: int = 8585):
        self._port = port
        self._carto_api_key: str = ""
        self._cache_dir = Path.home() / ".cache" / "mito_maps"
        self._cache_dir.mkdir(parents=True, exist_ok=True)
        TileProxyHandler.cache_dir = self._cache_dir
        TileProxyHandler.carto_api_key = self._carto_api_key

        self._server: Optional[ThreadingHTTPServer] = None
        self._server_thread: Optional[threading.Thread] = None

        self._bookmarks_file = Path(__file__).resolve().parent.parent.parent / "maps_bookmarks.json"
        self._bookmarks: List[Dict[str, Any]] = self._load_bookmarks()

        self.start_tile_proxy()

    @classmethod
    def get_instance(cls, port: int = 8585) -> "MapService":
        if cls._instance is None:
            cls._instance = MapService(port=port)
        return cls._instance

    @property
    def proxy_url(self) -> str:
        return f"http://127.0.0.1:{self._port}"

    def start_tile_proxy(self) -> None:
        """Starts the local tile cache proxy server."""
        if self._server is not None:
            return

        try:
            self._server = ThreadingHTTPServer(("127.0.0.1", self._port), TileProxyHandler)
            self._server_thread = threading.Thread(target=self._server.serve_forever, daemon=True)
            self._server_thread.start()
            logger.info("Map tile proxy running at %s (cache: %s)", self.proxy_url, self._cache_dir)
        except Exception as exc:
            logger.error("Failed to start map tile proxy on port %d: %s", self._port, exc)

    def stop_tile_proxy(self) -> None:
        """Stops the tile cache proxy server."""
        if self._server:
            try:
                self._server.shutdown()
                self._server.server_close()
            except Exception:
                pass
            self._server = None

    def set_carto_api_key(self, api_key: str) -> None:
        """Configures the CARTO API key for upstream raster tile requests."""
        self._carto_api_key = api_key.strip()
        TileProxyHandler.carto_api_key = self._carto_api_key
        logger.info("CARTO API key updated: %s", (self._carto_api_key[:6] + "...") if self._carto_api_key else "None")

    def clear_tile_cache(self) -> None:
        """Purges local disk cache so newly requested tiles fetch cleanly from upstream."""
        try:
            if self._cache_dir.exists():
                for item in self._cache_dir.iterdir():
                    if item.is_dir():
                        shutil.rmtree(item)
                    else:
                        item.unlink()
                logger.info("Map tile disk cache purged successfully.")
        except Exception as exc:
            logger.warning("Error purging tile disk cache: %s", exc)

    # -------------------------------------------------------------------------
    # Slippy Map Coordinate Mathematics
    # -------------------------------------------------------------------------

    @staticmethod
    def lat_lon_to_tile(lat: float, lon: float, zoom: int) -> Tuple[float, float]:
        """Converts latitude and longitude to fractional tile coordinates (x, y)."""
        lat_rad = math.radians(lat)
        n = 2.0 ** zoom
        x = (lon + 180.0) / 360.0 * n
        # Bound latitude to avoid singularity at poles
        lat_clamped = max(min(lat_rad, math.radians(85.0511)), math.radians(-85.0511))
        y = (1.0 - math.log(math.tan(lat_clamped) + 1.0 / math.cos(lat_clamped)) / math.pi) / 2.0 * n
        return x, y

    @staticmethod
    def tile_to_lat_lon(x: float, y: float, zoom: int) -> Tuple[float, float]:
        """Converts fractional tile coordinates back to latitude and longitude."""
        n = 2.0 ** zoom
        lon = x / n * 360.0 - 180.0
        lat_rad = math.atan(math.sinh(math.pi * (1.0 - 2.0 * y / n)))
        lat = math.degrees(lat_rad)
        return lat, lon

    # -------------------------------------------------------------------------
    # Nominatim Geocoding & POI Search
    # -------------------------------------------------------------------------

    def search_places(self, query: str, limit: int = 6) -> List[Dict[str, Any]]:
        """
        Searches places, cities, and addresses using OpenStreetMap Nominatim.
        Returns a list of structured results.
        """
        query_clean = query.strip()
        if not query_clean:
            return []

        params = urllib.parse.urlencode({
            "q": query_clean,
            "format": "json",
            "addressdetails": "1",
            "limit": str(limit),
            "accept-language": "it,en",
        })
        url = f"https://nominatim.openstreetmap.org/search?{params}"

        try:
            req = urllib.request.Request(
                url,
                headers={"User-Agent": "MitoInfotainment/1.0 (RaspberryPi; Automotive Dashboard)"}
            )
            with urllib.request.urlopen(req, timeout=5.0) as resp:
                data = json.loads(resp.read().decode("utf-8"))
                results: List[Dict[str, Any]] = []
                for item in data:
                    addr = item.get("address", {})
                    # Build readable short address
                    title = item.get("name") or addr.get("road") or addr.get("city") or addr.get("town") or item.get("display_name", "").split(",")[0]
                    subtitle = item.get("display_name", "")
                    category = item.get("type", "location")

                    results.append({
                        "name": title,
                        "display_name": subtitle,
                        "lat": float(item["lat"]),
                        "lon": float(item["lon"]),
                        "type": category,
                    })
                return results
        except Exception as exc:
            logger.warning("Nominatim place search error for '%s': %s", query_clean, exc)
            return []

    # -------------------------------------------------------------------------
    # Geolocation / Automatic Positioning
    # -------------------------------------------------------------------------

    @staticmethod
    def get_ip_location() -> Optional[Dict[str, Any]]:
        """
        Determines current geographic position via IP Geolocation when connected
        to the smartphone's Wi-Fi hotspot or local network.
        Returns coordinates and locality name without fabricating data.
        """
        try:
            req = urllib.request.Request(
                "http://ip-api.com/json/",
                headers={"User-Agent": "MitoInfotainment/1.0 (RaspberryPi; Automotive)"}
            )
            with urllib.request.urlopen(req, timeout=3.5) as resp:
                data = json.loads(resp.read().decode("utf-8"))
                if data.get("status") == "success":
                    city = data.get("city", "Posizione Rilevata")
                    region = data.get("regionName", "")
                    label = f"{city}, {region}" if region else city
                    logger.info("IP Geolocation successful: %s (%f, %f)", label, data["lat"], data["lon"])
                    return {
                        "name": label,
                        "lat": float(data["lat"]),
                        "lon": float(data["lon"]),
                    }
        except Exception as exc:
            logger.debug("IP Geolocation lookup not available: %s", exc)
        return None

    # -------------------------------------------------------------------------
    # Bookmarks / Favorites Storage
    # -------------------------------------------------------------------------

    def _load_bookmarks(self) -> List[Dict[str, Any]]:
        if self._bookmarks_file.exists():
            try:
                with open(self._bookmarks_file, "r", encoding="utf-8") as f:
                    return json.load(f)
            except Exception:
                pass
        # Default presets for Italy / driving
        return [
            {"name": "Roma Centro", "lat": 41.8933, "lon": 12.4829, "icon": "location_city"},
            {"name": "Milano Duomo", "lat": 45.4642, "lon": 9.1916, "icon": "location_city"},
            {"name": "Napoli Centro", "lat": 40.8518, "lon": 14.2681, "icon": "location_city"},
            {"name": "Torino", "lat": 45.0703, "lon": 7.6869, "icon": "location_city"},
        ]

    def get_bookmarks(self) -> List[Dict[str, Any]]:
        return list(self._bookmarks)

    def add_bookmark(self, name: str, lat: float, lon: float, icon: str = "place") -> None:
        for b in self._bookmarks:
            if b.get("name") == name:
                b["lat"] = lat
                b["lon"] = lon
                self._save_bookmarks()
                return
        self._bookmarks.append({"name": name, "lat": lat, "lon": lon, "icon": icon})
        self._save_bookmarks()

    def remove_bookmark(self, name: str) -> None:
        self._bookmarks = [b for b in self._bookmarks if b.get("name") != name]
        self._save_bookmarks()

    def _save_bookmarks(self) -> None:
        try:
            with open(self._bookmarks_file, "w", encoding="utf-8") as f:
                json.dump(self._bookmarks, f, indent=2, ensure_ascii=False)
        except Exception as exc:
            logger.warning("Failed to save map bookmarks: %s", exc)
