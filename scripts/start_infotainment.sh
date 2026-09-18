#!/usr/bin/env bash
# =============================================================================
# start_infotainment.sh - High-Performance Automotive Infotainment Launcher
# Launches PyQt6 + QML 1024x600 HMI with GPU acceleration
#
# Runtime modes:
#   - Kiosk (Pi boot): cage compositor sets WAYLAND_DISPLAY -> wayland platform
#   - Desktop dev:     WAYLAND_DISPLAY or DISPLAY already set by DE
#   - Fallback:        linuxfb (no GPU accel, last resort)
# =============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"

USER_ID=$(id -u)
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$USER_ID}"

# -----------------------------------------------------------------------------
# 1. PYTHON ENVIRONMENT (must be first to resolve Qt6 library paths)
# -----------------------------------------------------------------------------
if [ -f "$SCRIPT_DIR/venv/bin/activate" ]; then
    source "$SCRIPT_DIR/venv/bin/activate"
fi

# PyQt6 pip bundle: tell Qt where its plugins and libs live
QT6_DIR="$SCRIPT_DIR/venv/lib/python3.13/site-packages/PyQt6/Qt6"
if [ -d "$QT6_DIR" ]; then
    # Auto-detect python version if path doesn't exist
    if [ ! -d "$QT6_DIR" ]; then
        QT6_DIR=$(find "$SCRIPT_DIR/venv/lib" -maxdepth 3 -type d -name "Qt6" -path "*/PyQt6/*" 2>/dev/null | head -1)
    fi
    export QT_PLUGIN_PATH="$QT6_DIR/plugins"
    export LD_LIBRARY_PATH="$QT6_DIR/lib:${LD_LIBRARY_PATH:-}"
    export QML2_IMPORT_PATH="$QT6_DIR/qml:${QML2_IMPORT_PATH:-}"
fi

# -----------------------------------------------------------------------------
# 2. GRAPHICS RUNTIME CONFIGURATION
# -----------------------------------------------------------------------------
export QSG_RENDER_LOOP="threaded"
export QT_QUICK_CONTROLS_STYLE="Basic"

if [ -n "$WAYLAND_DISPLAY" ]; then
    # Inside cage compositor (kiosk boot) or Wayland desktop
    export QT_QPA_PLATFORM="wayland"
elif [ -n "$DISPLAY" ]; then
    # X11 desktop development
    export QT_QPA_PLATFORM="xcb"
else
    # No display server at all — last resort framebuffer
    export QT_QPA_PLATFORM="linuxfb"
    export QT_QPA_FB_DRM=1
fi

# -----------------------------------------------------------------------------
# 3. AUDIO STACK CONFIGURATION (PipeWire / PulseAudio)
# -----------------------------------------------------------------------------
export PULSE_SERVER="unix:$XDG_RUNTIME_DIR/pulse/native"
export SDL_AUDIODRIVER="pulseaudio"

# -----------------------------------------------------------------------------
# 4. EXECUTION
# -----------------------------------------------------------------------------
exec python3 "$SCRIPT_DIR/main.py"
