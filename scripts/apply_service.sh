#!/usr/bin/env bash
# =============================================================================
# apply_service.sh - Quick fix: write correct systemd service files
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

echo ">>> Scrittura infotainment.service (Cage Wayland Kiosk)..."

cat >/etc/systemd/system/infotainment.service <<SVCEOF
[Unit]
Description=Mito Automotive Infotainment (PyQt6 + QML via Cage Wayland Kiosk)
After=systemd-user-sessions.service network.target bluetooth.service sound.target avahi-daemon.service
Wants=bluetooth.service avahi-daemon.service

[Service]
Type=simple
User=$REAL_USER

PAMName=login
TTYPath=/dev/tty7
StandardInput=tty-force
UtmpIdentifier=tty7
UtmpMode=user

WorkingDirectory=$PROJECT_DIR

Environment=PYTHONUNBUFFERED=1
Environment=XDG_RUNTIME_DIR=/run/user/$REAL_UID
Environment=DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$REAL_UID/bus
Environment=HOME=$REAL_HOME

ExecStartPre=/bin/sleep 2
ExecStart=/usr/bin/cage -s -- $START_SCRIPT

Restart=always
RestartSec=3
TimeoutStopSec=10

StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SVCEOF

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

echo ">>> Abilitazione linger utente $REAL_USER..."
loginctl enable-linger "$REAL_USER" || true

echo ">>> Reload e abilitazione servizi..."
systemctl daemon-reload
systemctl enable infotainment.service
systemctl enable bt-auto-pair.service

echo ""
echo "=========================================="
echo "  Servizi configurati con successo!"
echo "=========================================="
echo "  infotainment.service -> cage + wayland"
echo "  bt-auto-pair.service -> timeout 3s"
echo ""
echo "  Esegui: sudo reboot"
echo "=========================================="
