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
# 4. EMERGENCY TOUCH WATCHDOG (5-second screen hold force-kills uxplay)
# -----------------------------------------------------------------------------
pkill -f "touch_killer.py" 2>/dev/null || true
mkdir -p "$SCRIPT_DIR/logs"

if [ -f "$SCRIPT_DIR/scripts/touch_killer.py" ]; then
    chmod +x "$SCRIPT_DIR/scripts/touch_killer.py" 2>/dev/null || true
    python3 "$SCRIPT_DIR/scripts/touch_killer.py" >> "$SCRIPT_DIR/logs/touch_killer.log" 2>&1 &
fi

# -----------------------------------------------------------------------------
# 5. CONSOLE SILENCING & EXECUTION
# Prevents any terminal text, cursor or dmesg prints from drawing on framebuffer
# -----------------------------------------------------------------------------
mkdir -p "$SCRIPT_DIR/logs"
TERMINAL_LOG="$SCRIPT_DIR/logs/terminal.log"

# Disable kernel printk messages from showing on the virtual console
dmesg -D 2>/dev/null || true

# Turn off virtual console blinking cursor and clear screen
setterm -cursor off > /dev/tty1 2>/dev/null || true
setterm -blank 0 > /dev/tty1 2>/dev/null || true
setterm -clear all > /dev/tty1 2>/dev/null || true

# Redirect all stdout & stderr to terminal.log so nothing bleeds over the UI
echo "=== Infotainment session started: $(date) ===" >> "$TERMINAL_LOG"
exec python3 "$SCRIPT_DIR/main.py" >> "$TERMINAL_LOG" 2>&1
