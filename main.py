#!/usr/bin/env python3
"""
main.py - Entrypoint for Modern Raspberry Pi Automotive Infotainment
Initializes QGuiApplication, QQmlApplicationEngine, and binds the Python backend bridge.
Optimized for 1024x600 capacitive touchscreen on Raspberry Pi 4B.
"""

import os
import sys
import signal
import logging
from pathlib import Path

from PyQt6.QtGui import QGuiApplication, QIcon, QFontDatabase
from PyQt6.QtQml import QQmlApplicationEngine
from PyQt6.QtCore import Qt, QTimer, QUrl

from backend import InfotainmentBackend

# Setup structured logging
base_logs_dir = Path(__file__).resolve().parent / "logs"
base_logs_dir.mkdir(parents=True, exist_ok=True)
terminal_log_file = base_logs_dir / "terminal.log"

log_handlers: list = [logging.FileHandler(str(terminal_log_file), mode="a", encoding="utf-8")]
if os.environ.get("DISPLAY") or os.environ.get("WAYLAND_DISPLAY"):
    log_handlers.append(logging.StreamHandler(sys.stdout))

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] (%(name)s) %(message)s",
    handlers=log_handlers,
)
logger = logging.getLogger("InfotainmentApp")


def configure_rpi_environment() -> None:
    """
    Optimizes Qt Quick runtime and platform plugin for Raspberry Pi 4B.
    Enables GPU hardware acceleration via OpenGL ES 2 / EGLFS when running standalone.
    """
    # Force Qt Quick Scenegraph hardware rendering
    if "QSG_RENDER_LOOP" not in os.environ:
        os.environ["QSG_RENDER_LOOP"] = "threaded"

    # Default platform plugin detection
    if "QT_QPA_PLATFORM" not in os.environ:
        if os.environ.get("WAYLAND_DISPLAY"):
            os.environ["QT_QPA_PLATFORM"] = "wayland"
        elif os.environ.get("DISPLAY"):
            os.environ["QT_QPA_PLATFORM"] = "xcb"
        elif sys.platform.startswith("linux"):
            # Standalone KMS/DRM or EGLFS directly on Pi framebuffer
            os.environ["QT_QPA_PLATFORM"] = "eglfs"

    # Set modern controls style
    os.environ["QT_QUICK_CONTROLS_STYLE"] = "Basic"
    logger.info("Platform target configured: QT_QPA_PLATFORM=%s", os.environ.get("QT_QPA_PLATFORM"))


def main() -> int:
    configure_rpi_environment()

    # Create lightweight QGuiApplication (no QtWidgets raster bloat)
    app = QGuiApplication(sys.argv)
    app.setApplicationName("RPi Car Infotainment")
    app.setOrganizationName("Automotive")

    base_dir = Path(__file__).resolve().parent

    # Register Material Symbols Rounded font
    font_path = base_dir / "Material_Symbols_Rounded" / "MaterialSymbolsRounded-VariableFont_FILL,GRAD,opsz,wght.ttf"
    if font_path.exists():
        font_id = QFontDatabase.addApplicationFont(str(font_path))
        if font_id != -1:
            logger.info("Loaded application font: %s", QFontDatabase.applicationFontFamilies(font_id))
        else:
            logger.warning("Failed to register font: %s", font_path)

    # Connect OS SIGINT (Ctrl+C) cleanly into Qt event loop
    signal.signal(signal.SIGINT, lambda *args: app.quit())
    sigint_timer = QTimer()
    sigint_timer.start(500)
    sigint_timer.timeout.connect(lambda: None)

    # Initialize non-blocking Python backend bridge
    backend = InfotainmentBackend()
    backend.setParent(app)

    # Initialize QML engine
    engine = QQmlApplicationEngine()

    # Expose Python backend controller to QML context
    is_desktop = bool(os.environ.get("DISPLAY") or os.environ.get("WAYLAND_DISPLAY"))
    engine.rootContext().setContextProperty("backend", backend)
    engine.rootContext().setContextProperty("isDesktopDev", is_desktop)

    # Path to main QML file
    base_dir = Path(__file__).resolve().parent
    qml_file = base_dir / "qml" / "Main.qml"

    if not qml_file.exists():
        logger.critical("QML entrypoint file not found: %s", qml_file)
        return 1

    # Catch QML loading errors gracefully
    def on_object_created(obj, url):
        if obj is None and url == QUrl.fromLocalFile(str(qml_file)):
            logger.critical("Failed to load QML root component: %s", url)
            sys.exit(-1)

    engine.objectCreated.connect(on_object_created)

    logger.info("Loading QML root interface: %s", qml_file)
    engine.load(QUrl.fromLocalFile(str(qml_file)))

    logger.info("Infotainment HMI active at 60 FPS (1024x600 target).")
    return app.exec()


if __name__ == "__main__":
    sys.exit(main())
