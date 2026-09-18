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

# Load local environment variables (.env) if present
if [ -f "$SCRIPT_DIR/.env" ]; then
    set -a
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR/.env"
    set +a
fi

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
# 5. CONSOLE SILENCING & FRAMEBUFFER UNBINDING
# Completely detaches Linux text console (fbcon) from /dev/fb0 so no kernel
# messages, getty prompts, or terminal text can ever draw over the UI.
# -----------------------------------------------------------------------------
mkdir -p "$SCRIPT_DIR/logs"
TERMINAL_LOG="$SCRIPT_DIR/logs/terminal.log"

# Silence kernel printk console messages (only emergency messages to console)
sudo -n dmesg -n 1 2>/dev/null || dmesg -D 2>/dev/null || true

# Unbind VT console from framebuffer device
# This completely detaches fbcon from /dev/fb0, making it impossible for the
# kernel or console to draw characters or cursor onto the display.
if [ -d /sys/class/vtconsole ]; then
    for v in /sys/class/vtconsole/vtcon*/name; do
        if [ -f "$v" ] && grep -q "frame buffer" "$v" 2>/dev/null; then
            bind_file="${v%name}bind"
            if [ -w "$bind_file" ]; then
                echo 0 > "$bind_file" 2>/dev/null || true
            else
                sudo -n sh -c "echo 0 > '$bind_file'" 2>/dev/null || true
            fi
        fi
    done
fi

# Turn off virtual console blinking cursor and clear screen
setterm -cursor off > /dev/tty1 2>/dev/null || sudo -n setterm -cursor off > /dev/tty1 2>/dev/null || true
setterm -blank 0 > /dev/tty1 2>/dev/null || sudo -n setterm -blank 0 > /dev/tty1 2>/dev/null || true
setterm -clear all > /dev/tty1 2>/dev/null || sudo -n setterm -clear all > /dev/tty1 2>/dev/null || true

# Clear framebuffer so any residual console text is removed before Qt draws
if [ -w /dev/fb0 ]; then
    dd if=/dev/zero of=/dev/fb0 bs=1024 count=2400 2>/dev/null || true
else
    sudo -n dd if=/dev/zero of=/dev/fb0 bs=1024 count=2400 2>/dev/null || true
fi

# Redirect all stdout & stderr to terminal.log so nothing bleeds over the UI
echo "=== Infotainment session started: $(date) ===" >> "$TERMINAL_LOG"
exec python3 "$SCRIPT_DIR/main.py" >> "$TERMINAL_LOG" 2>&1

