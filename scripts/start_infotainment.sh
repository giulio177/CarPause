#!/usr/bin/env bash
# =============================================================================
# start_infotainment.sh - High-Performance Automotive Infotainment Launcher
# Launches PyQt6 + QML 1024x600 HMI with GPU acceleration (EGLFS/Wayland)
# =============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"

USER_ID=$(id -u)
export XDG_RUNTIME_DIR="/run/user/$USER_ID"

# -----------------------------------------------------------------------------
# 1. GRAPHICS RUNTIME CONFIGURATION (Raspberry Pi 4B GPU Acceleration)
# -----------------------------------------------------------------------------
export QSG_RENDER_LOOP="threaded"
export QT_QUICK_CONTROLS_STYLE="Basic"

if [ -n "$WAYLAND_DISPLAY" ]; then
    export QT_QPA_PLATFORM="wayland"
elif [ -n "$DISPLAY" ]; then
    export QT_QPA_PLATFORM="xcb"
else
    # Running standalone directly from console / KMS without desktop environment
    export QT_QPA_PLATFORM="eglfs"
    export QT_QPA_EGLFS_ALWAYS_SET_MODE=1
    export QT_QPA_EGLFS_WIDTH=1024
    export QT_QPA_EGLFS_HEIGHT=600
    export QT_QPA_EGLFS_PHYSICAL_WIDTH=154
    export QT_QPA_EGLFS_PHYSICAL_HEIGHT=86
fi

# -----------------------------------------------------------------------------
# 2. AUDIO STACK CONFIGURATION (PipeWire / PulseAudio)
# -----------------------------------------------------------------------------
export PULSE_SERVER="unix:$XDG_RUNTIME_DIR/pulse/native"
export SDL_AUDIODRIVER="pulseaudio"

# -----------------------------------------------------------------------------
# 3. PYTHON ENVIRONMENT & EXECUTION
# -----------------------------------------------------------------------------
if [ -f "$SCRIPT_DIR/venv/bin/activate" ]; then
    source "$SCRIPT_DIR/venv/bin/activate"
fi

exec python3 "$SCRIPT_DIR/main.py"
