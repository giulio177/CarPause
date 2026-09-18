#!/usr/bin/env bash
# =============================================================================
# apply_service.sh - Write correct systemd service files + fix display & BT audio
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
# 2. Fix Bluetooth Audio & Stack (libspa-0.2-bluetooth, main.conf, btmgmt)
# =========================================================================
echo ">>> Configurazione Bluetooth A2DP & PipeWire..."

# Sblocco RFKill
rfkill unblock bluetooth 2>/dev/null || true

# Installa modulo Bluetooth per PipeWire se mancante
if ! dpkg -l | grep -q "libspa-0.2-bluetooth"; then
    echo "  Installazione libspa-0.2-bluetooth per audio smartphone..."
    apt-get update -qq && apt-get install -y libspa-0.2-bluetooth
fi

# Configurazione /etc/bluetooth/main.conf
BT_CONF="/etc/bluetooth/main.conf"
if [[ ! -f "$BT_CONF" ]]; then
    echo "[General]" > "$BT_CONF"
elif ! grep -q '^\[General\]' "$BT_CONF"; then
    sed -i '1i[General]' "$BT_CONF"
fi

set_bt_key() {
    local k="$1"
    local v="$2"
    if grep -q "^$k" "$BT_CONF"; then
        sed -i "s/^$k.*/$k = $v/" "$BT_CONF"
    else
        sed -i "/^\[General\]/a $k = $v" "$BT_CONF"
    fi
}

set_bt_key "Class" "0x200420"             # Car Audio CoD
set_bt_key "DiscoverableTimeout" "0"      # Sempre visibile quando richiesto
set_bt_key "PairableTimeout" "0"          # Sempre accoppiabile
set_bt_key "JustWorksRepairing" "always"  # No PIN pairing automatico
set_bt_key "AutoEnable" "true"            # Acceso al boot
set_bt_key "ControllerMode" "dual"        # Supporta sia Classic (A2DP) che BLE
set_bt_key "MultiProfile" "multiple"      # Consente connessione profili multipli
set_bt_key "Name" "Mito-Infotainment"

# =========================================================================
# 3. Servizio bt-auto-pair (No PIN)
# =========================================================================
echo ">>> Scrittura bt-auto-pair.service..."
killall -9 btmgmt bt-agent 2>/dev/null || true

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
# 4. Servizio infotainment (linuxfb diretto, senza cage)
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
# 5. Linger, PipeWire user services, reload + enable
# =========================================================================
echo ">>> Abilitazione servizi utente PipeWire e WirePlumber..."
loginctl enable-linger "$REAL_USER" || true

sudo -u "$REAL_USER" XDG_RUNTIME_DIR="/run/user/$REAL_UID" systemctl --user daemon-reload 2>/dev/null || true
sudo -u "$REAL_USER" XDG_RUNTIME_DIR="/run/user/$REAL_UID" systemctl --user enable --now pipewire pipewire-pulse wireplumber 2>/dev/null || true

systemctl daemon-reload
systemctl enable infotainment.service
systemctl enable bt-auto-pair.service

# Riavvia Bluetooth e agent
systemctl restart bluetooth
systemctl restart bt-auto-pair.service
sudo -u "$REAL_USER" XDG_RUNTIME_DIR="/run/user/$REAL_UID" systemctl --user restart pipewire pipewire-pulse wireplumber 2>/dev/null || true

echo ""
echo "=========================================="
echo "  Configurazione completata!"
echo "=========================================="
echo "  Display:      FKMS + 1024x600 hdmi_cvt"
echo "  Infotainment: linuxfb:/dev/fb0"
echo "  Bluetooth:    Car Audio (0x200420) + Dual Mode + libspa-0.2-bluetooth"
echo "  BT Agent:     NoInputNoOutput + btmgmt io-cap 3"
echo "  Wi-Fi:        Rescan attivo supportato"
echo "=========================================="
