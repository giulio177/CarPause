#!/usr/bin/env bash
# =============================================================================
# start_infotainment.sh - High-Performance Automotive Infotainment Launcher
# Launches PyQt6 + QML 1024x600 HMI
#
# Runtime modes:
#   - Kiosk (Pi boot): linuxfb direct framebuffer (1024x600, FKMS)
#   - Desktop dev:     WAYLAND_DISPLAY or DISPLAY already set by DE
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

# PyQt6 pip bundle: tell Qt and the linker where its plugins and libs live
VENV_QT6=$(find "$SCRIPT_DIR/venv/lib" -maxdepth 3 -type d -name "Qt6" -path "*/PyQt6/*" 2>/dev/null | head -1)
if [ -n "$VENV_QT6" ]; then
    export QT_PLUGIN_PATH="$VENV_QT6/plugins"
    export LD_LIBRARY_PATH="$VENV_QT6/lib:${LD_LIBRARY_PATH:-}"
    export QML2_IMPORT_PATH="$VENV_QT6/qml:${QML2_IMPORT_PATH:-}"
fi

# -----------------------------------------------------------------------------
# 2. GRAPHICS RUNTIME CONFIGURATION
# -----------------------------------------------------------------------------
export QSG_RENDER_LOOP="threaded"
export QT_QUICK_CONTROLS_STYLE="Basic"

if [ -n "${WAYLAND_DISPLAY:-}" ]; then
    # Wayland desktop development
    export QT_QPA_PLATFORM="wayland"
elif [ -n "${DISPLAY:-}" ]; then
    # X11 desktop development
    export QT_QPA_PLATFORM="xcb"
else
    # Headless kiosk: direct Linux framebuffer (works with FKMS + hdmi_cvt)
    export QT_QPA_PLATFORM="linuxfb:fb=/dev/fb0:size=1024x600"
    export QT_QPA_GENERIC_PLUGINS="evdevtouch:/dev/input/event0"
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
