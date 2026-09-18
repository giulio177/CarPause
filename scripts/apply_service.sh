#!/usr/bin/env bash
# =============================================================================
# apply_service.sh - Write correct systemd service files + fix display config
# Run with: sudo ./scripts/apply_service.sh
# =============================================================================
set -euo pipefail

if [[ "$EUID" -ne 0 ]]; then
    echo "ERRORE: Eseguire con sudo: sudo ./scripts/apply_service.sh"
    exit 1
fi

REAL_USER="${SUDO_USER:-$(logname 2>/dev/null || echo "pi")}"
REAL_UID="$(id -u "$REAL_USER")"
REAL_HOME="$(getent passwd "$REAL_USER" | cut -d: -f6)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
START_SCRIPT="$PROJECT_DIR/scripts/start_infotainment.sh"

chmod +x "$START_SCRIPT"
chown "$REAL_USER:$REAL_USER" "$START_SCRIPT"

# Individua boot partition
if [[ -f /boot/firmware/config.txt ]]; then
    BOOT_DIR="/boot/firmware"
else
    BOOT_DIR="/boot"
fi
CONFIG_FILE="$BOOT_DIR/config.txt"
CMDLINE_FILE="$BOOT_DIR/cmdline.txt"

# =========================================================================
# 1. Fix Display: FKMS + hdmi_cvt 1024x600 (funzionante, testato su legacy)
# =========================================================================
echo ">>> Fix display: passaggio a FKMS + risoluzione 1024x600..."

# Cambia Full KMS -> FKMS
if grep -q "dtoverlay=vc4-kms-v3d" "$CONFIG_FILE"; then
    sed -i 's/dtoverlay=vc4-kms-v3d/dtoverlay=vc4-fkms-v3d/' "$CONFIG_FILE"
    echo "  Cambiato vc4-kms-v3d -> vc4-fkms-v3d"
fi

# Aggiungi FKMS se manca
if ! grep -q "dtoverlay=vc4-fkms-v3d" "$CONFIG_FILE"; then
    echo "dtoverlay=vc4-fkms-v3d" >> "$CONFIG_FILE"
    echo "  Aggiunto dtoverlay=vc4-fkms-v3d"
fi

# Aggiungi blocco HDMI 1024x600 se manca
if ! grep -q "hdmi_cvt=1024 600 60 6 0 0 0" "$CONFIG_FILE"; then
    cat >> "$CONFIG_FILE" << 'HDMIEOF'

# --- RPi Automotive Display Configuration (1024x600 @ 60Hz) ---
hdmi_force_hotplug=1
hdmi_group=2
hdmi_mode=87
hdmi_cvt=1024 600 60 6 0 0 0
HDMIEOF
    echo "  Aggiunto blocco HDMI 1024x600"
fi

# Rimuovi video= forzato da cmdline (non serve con FKMS)
if [[ -f "$CMDLINE_FILE" ]]; then
    sed -i 's| video=HDMI-A-1:[^ ]*||g' "$CMDLINE_FILE"
    echo "  Rimosso video= override da cmdline.txt"
fi

# =========================================================================
# 2. Servizio infotainment (linuxfb diretto, senza cage)
# =========================================================================
echo ">>> Scrittura infotainment.service (linuxfb framebuffer)..."

cat >/etc/systemd/system/infotainment.service <<SVCEOF
[Unit]
Description=Mito Automotive Infotainment (PyQt6 + QML Framebuffer)
After=network.target bluetooth.service sound.target avahi-daemon.service
Wants=bluetooth.service avahi-daemon.service

[Service]
Type=simple
User=$REAL_USER
Group=$REAL_USER
WorkingDirectory=$PROJECT_DIR

Environment=PYTHONUNBUFFERED=1
Environment=XDG_RUNTIME_DIR=/run/user/$REAL_UID
Environment=DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$REAL_UID/bus
Environment=HOME=$REAL_HOME
Environment=PULSE_SERVER=unix:/run/user/$REAL_UID/pulse/native

ExecStartPre=/bin/sleep 3
ExecStart=$START_SCRIPT

Restart=always
RestartSec=3
TimeoutStopSec=10

StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SVCEOF

# =========================================================================
# 3. Servizio bt-auto-pair (timeout 3s)
# =========================================================================
echo ">>> Scrittura bt-auto-pair.service..."

cat >/etc/systemd/system/bt-auto-pair.service <<BTEOF
[Unit]
Description=Bluetooth Auto-Accept Agent (No PIN, Auto-Pairing)
After=bluetooth.service
Requires=bluetooth.service

[Service]
Type=simple
ExecStart=/usr/bin/bt-agent -c NoInputNoOutput
Restart=always
RestartSec=2
TimeoutStopSec=3
KillMode=process

[Install]
WantedBy=multi-user.target
BTEOF

# =========================================================================
# 4. Linger + reload + enable
# =========================================================================
loginctl enable-linger "$REAL_USER" || true
systemctl daemon-reload
systemctl enable infotainment.service
systemctl enable bt-auto-pair.service

echo ""
echo "=========================================="
echo "  Configurazione completata!"
echo "=========================================="
echo "  Display:      FKMS + 1024x600 hdmi_cvt"
echo "  Infotainment: linuxfb:/dev/fb0"
echo "  BT Agent:     timeout 3s"
echo ""
echo "  Esegui: sudo reboot"
echo "=========================================="
