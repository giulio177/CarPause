#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# install_rpi_infotainment.sh - Raspberry Pi 4B Modern Infotainment Installer
# Target OS: Raspberry Pi OS (Bookworm / Bullseye 64-bit / Lite or Desktop)
# Stack: PyQt6 + QML 1024x600 (GPU KMS/Wayland), PipeWire/PulseAudio, BlueZ,
#        UxPlay AirPlay Screen Mirroring, NetworkManager
###############################################################################

# 1. Verifica permessi di root
if [[ "$EUID" -ne 0 ]]; then
    echo "ERRORE: Questo script deve essere eseguito con sudo o come root."
    echo "Uso: sudo ./scripts/install_rpi_infotainment.sh"
    exit 1
fi

# 2. Identificazione utente reale e percorso progetto
REAL_USER="${SUDO_USER:-$(logname 2>/dev/null || echo "pi")}"
if ! id "$REAL_USER" >/dev/null 2>&1; then
    echo "ERRORE: Impossibile determinare l'utente non-root."
    exit 1
fi

REAL_UID="$(id -u "$REAL_USER")"
REAL_HOME="$(getent passwd "$REAL_USER" | cut -d: -f6)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "========================================================================="
echo "  RPi Automotive Infotainment Installer (PyQt6 + QML + UxPlay AirPlay)  "
echo "========================================================================="
echo "Utente di sistema:   $REAL_USER (UID: $REAL_UID)"
echo "Home utente:         $REAL_HOME"
echo "Cartella progetto:   $PROJECT_DIR"
echo

# 3. Individuazione partizione di boot (/boot/firmware su Bookworm, /boot su legacy)
if [[ -f /boot/firmware/cmdline.txt ]]; then
    BOOT_DIR="/boot/firmware"
elif [[ -f /boot/cmdline.txt ]]; then
    BOOT_DIR="/boot"
else
    echo "ATTENZIONE: cmdline.txt non trovato in /boot/firmware né /boot."
    BOOT_DIR="/boot"
fi

CMDLINE_FILE="$BOOT_DIR/cmdline.txt"
CONFIG_FILE="$BOOT_DIR/config.txt"
echo "Partizione boot rilevata: $BOOT_DIR"
echo

###############################################################################
# 4. Aggiornamento sistema e installazione pacchetti APT
###############################################################################
echo ">>> [1/8] Aggiornamento repository ed installazione dipendenze di sistema..."
apt update

# Pacchetti essenziali, build tools, D-Bus, rete, audio, Bluetooth
apt install -y \
    git python3-venv python3-pip python3-dev build-essential pkg-config cmake \
    python3-dbus python3-gi gir1.2-glib-2.0 dbus-user-session libglib2.0-dev libdbus-1-dev \
    network-manager \
    pipewire pipewire-pulse wireplumber alsa-utils libasound2-dev \
    bluez bluez-tools pi-bluetooth bluez-firmware \
    ffmpeg libavcodec-extra rfkill \
    avahi-daemon avahi-utils libavahi-compat-libdnssd-dev libssl-dev libplist-dev \
    gstreamer1.0-tools gstreamer1.0-plugins-base gstreamer1.0-plugins-good \
    gstreamer1.0-plugins-bad gstreamer1.0-libav gstreamer1.0-gl \
    gstreamer1.0-alsa gstreamer1.0-pulseaudio \
    python3-evdev

# Pacchetti PyQt6 e QtQuick nativi Debian/Raspberry Pi OS (se disponibili nei repository apt)
apt install -y \
    python3-pyqt6 python3-pyqt6.qtquick python3-pyqt6.qtmultimedia python3-pyqt6.qtdbus \
    qml6-module-qtquick qml6-module-qtquick-controls qml6-module-qtquick-layouts \
    qml6-module-qtquick-window qml6-module-qtmultimedia 2>/dev/null || {
    echo "Nota: Alcuni moduli Qt6 QML saranno gestiti direttamente dal virtualenv Python."
}

# Tentativo installazione pacchetto uxplay via apt
if ! command -v uxplay &>/dev/null; then
    if apt-cache show uxplay &>/dev/null; then
        echo ">>> Installazione di UxPlay tramite APT..."
        apt install -y uxplay
    else
        echo ">>> UxPlay non presente nei repo APT di questa release. Compilazione da sorgente..."
        BUILD_DIR="/tmp/uxplay_build"
        rm -rf "$BUILD_DIR"
        mkdir -p "$BUILD_DIR"
        git clone https://github.com/FDH2/UxPlay.git "$BUILD_DIR"
        cd "$BUILD_DIR"
        mkdir build && cd build
        cmake ..
        make -j"$(nproc)"
        make install
        cd "$PROJECT_DIR"
        rm -rf "$BUILD_DIR"
        echo ">>> UxPlay compilato ed installato con successo in /usr/local/bin/uxplay."
    fi
else
    echo ">>> UxPlay è già installato: $(command -v uxplay)"
fi
echo

###############################################################################
# 5. Configurazione Boot (cmdline.txt e config.txt)
###############################################################################
echo ">>> [2/8] Configurazione parametri di boot ($CMDLINE_FILE e $CONFIG_FILE)..."

# 5.1 cmdline.txt: Avvio silenzioso stile automotive senza log di console
if [[ -f "$CMDLINE_FILE" ]]; then
    EXTRA_CMDLINE="logo.nologo quiet loglevel=3 vt.global_cursor_default=0"
    if ! grep -q "logo.nologo" "$CMDLINE_FILE"; then
        sed -i "1s|\$| ${EXTRA_CMDLINE}|" "$CMDLINE_FILE"
        echo "Aggiunte opzioni quiet/automotive a $CMDLINE_FILE."
    fi
fi

# 5.2 config.txt: Driver KMS 3D, Audio e Display 1024x600
if [[ -f "$CONFIG_FILE" ]]; then
    # Assicurati che vc4-kms-v3d (Full KMS) sia attivo per l'accelerazione GPU
    if ! grep -q "dtoverlay=vc4-kms-v3d" "$CONFIG_FILE"; then
        if grep -q "dtoverlay=vc4-fkms-v3d" "$CONFIG_FILE"; then
            sed -i 's/dtoverlay=vc4-fkms-v3d/dtoverlay=vc4-kms-v3d/' "$CONFIG_FILE"
            echo "Aggiornato driver da fkms a Full KMS (vc4-kms-v3d)."
        else
            echo "dtoverlay=vc4-kms-v3d" >> "$CONFIG_FILE"
        fi
    fi

    # Rimuovi eventuale disable-bt
    sed -i '/dtoverlay=disable-bt/d' "$CONFIG_FILE"

    # Abilita UART e Audio
    grep -q "^enable_uart=1" "$CONFIG_FILE" || echo "enable_uart=1" >> "$CONFIG_FILE"
    if grep -q '^dtparam=audio=' "$CONFIG_FILE"; then
        sed -i 's/^dtparam=audio=.*/dtparam=audio=on/' "$CONFIG_FILE"
    else
        echo 'dtparam=audio=on' >> "$CONFIG_FILE"
    fi

    # Display HDMI 1024x600 a 60Hz
    if ! grep -q "hdmi_cvt=1024 600 60 6 0 0 0" "$CONFIG_FILE"; then
        cat >> "$CONFIG_FILE" << 'EOF'

# --- RPi Automotive Display Configuration (1024x600 @ 60Hz) ---
hdmi_force_hotplug=1
hdmi_group=2
hdmi_mode=87
hdmi_cvt=1024 600 60 6 0 0 0
EOF
        echo "Configurata risoluzione HDMI 1024x600 in $CONFIG_FILE."
    fi

    # Automotive Boot Speed & Poweroff GPIO 17
    grep -q "^disable_splash=1" "$CONFIG_FILE" || echo "disable_splash=1" >> "$CONFIG_FILE"
    grep -q "^boot_delay=0" "$CONFIG_FILE" || echo "boot_delay=0" >> "$CONFIG_FILE"
    grep -q "^gpio=17=op,dh" "$CONFIG_FILE" || echo "gpio=17=op,dh" >> "$CONFIG_FILE"
    grep -q "dtoverlay=gpio-poweroff,gpiopin=17,active_low=1" "$CONFIG_FILE" || echo "dtoverlay=gpio-poweroff,gpiopin=17,active_low=1" >> "$CONFIG_FILE"
fi
echo

###############################################################################
# 6. Configurazione Bluetooth (BlueZ e Agente Auto-Pairing)
###############################################################################
echo ">>> [3/8] Configurazione Bluetooth & Agente Auto-Pairing..."

# Sblocco RFKill e avvio driver hciuart
rfkill unblock bluetooth 2>/dev/null || true
systemctl enable hciuart 2>/dev/null || true
systemctl restart hciuart 2>/dev/null || true

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
set_bt_key "DiscoverableTimeout" "30"     # 30s timeout
set_bt_key "PairableTimeout" "0"          # Sempre accoppiabile quando visibile
set_bt_key "JustWorksRepairing" "always"  # No PIN pairing
set_bt_key "AutoEnable" "true"            # Acceso al boot
set_bt_key "ControllerMode" "bredr"       # Standard A2DP
set_bt_key "Name" "Mito-Infotainment"

# Servizio Systemd per l'agente auto-accept "Just Works" (No PIN)
cat >/etc/systemd/system/bt-auto-pair.service <<EOF
[Unit]
Description=Bluetooth Auto-Accept Agent (No PIN, Auto-Pairing)
After=bluetooth.service
Requires=bluetooth.service

[Service]
Type=simple
ExecStart=/usr/bin/bt-agent -c NoInputNoOutput
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now bt-auto-pair.service
systemctl restart bluetooth
echo "Bluetooth e agente auto-pairing configurati."
echo

###############################################################################
# 7. Configurazione Avahi / mDNS per AirPlay (UxPlay)
###############################################################################
echo ">>> [4/8] Configurazione servizio mDNS (Avahi Daemon per AirPlay)..."
systemctl enable --now avahi-daemon
echo "Avahi daemon attivo per rilevamento AirPlay su iOS."
echo

###############################################################################
# 8. Permessi Gruppi Utente
###############################################################################
echo ">>> [5/8] Assegnazione permessi gruppi utente per audio, input e grafica..."
usermod -aG video,input,render,audio,dialout,netdev "$REAL_USER"

# Regola udev per accesso a /dev/uinput senza privilegi di root
cat >/etc/udev/rules.d/99-uinput-infotainment.rules <<EOF
KERNEL=="uinput", MODE="0660", GROUP="input"
EOF
udevadm control --reload-rules && udevadm trigger || true
echo "Gruppi e permessi udev aggiornati."
echo

###############################################################################
# 9. Configurazione Virtualenv Python
###############################################################################
echo ">>> [6/8] Configurazione Virtualenv Python..."

sudo -u "$REAL_USER" bash -lc "
  set -e
  cd '$PROJECT_DIR'
  if [ ! -d venv ]; then
      python3 -m venv --system-site-packages venv
  fi
  source venv/bin/activate
  pip install --upgrade pip
  pip install -r requirements.txt
"
echo "Virtualenv configurato con successo."
echo

###############################################################################
# 10. Script di avvio ed abilitazione Servizio Systemd Infotainment
###############################################################################
echo ">>> [7/8] Creazione ed abilitazione servizio infotainment.service..."

START_SCRIPT="$PROJECT_DIR/scripts/start_infotainment.sh"
chmod +x "$START_SCRIPT"
chown "$REAL_USER:$REAL_USER" "$START_SCRIPT"

# Abilita linger per permettere l'istanza user di PipeWire/D-Bus
loginctl enable-linger "$REAL_USER" || true

cat >/etc/systemd/system/infotainment.service <<EOF
[Unit]
Description=Mito Automotive Infotainment (PyQt6 + QML)
After=network.target bluetooth.service sound.target avahi-daemon.service
Wants=bluetooth.service avahi-daemon.service

[Service]
Type=simple
User=$REAL_USER
Group=$REAL_USER
WorkingDirectory=$PROJECT_DIR

Environment=PYTHONUNBUFFERED=1
Environment=XDG_RUNTIME_DIR=/run/user/$REAL_UID

# Avvio tramite launcher ottimizzato
ExecStart=$START_SCRIPT

Restart=always
RestartSec=3

StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable infotainment.service
echo "Servizio infotainment.service abilitato per l'avvio automatico al boot."
echo

###############################################################################
# 11. Ottimizzazione Audio & Volume
###############################################################################
echo ">>> [8/8] Reset e sblocco volumi hardware ALSA..."
amixer set Master 100% unmute 2>/dev/null || true
amixer -c 1 set PCM 100% unmute 2>/dev/null || true
amixer -c 0 set Headphone 100% unmute 2>/dev/null || true
echo

###############################################################################
# 12. Completamento
###############################################################################
echo "========================================================================="
echo "                  INSTALLAZIONE COMPLETATA CON SUCCESSO!                 "
echo "========================================================================="
echo "Il sistema Raspberry Pi è ora configurato:"
echo "  1. Risoluzione forzata a 1024x600 @ 60Hz con accelerazione GPU Full KMS"
echo "  2. Bluetooth A2DP Car Audio con accoppiamento automatico 'Just Works'"
echo "  3. AirPlay screen mirroring & audio ricevitore via UxPlay con mDNS"
echo "  4. Gestione Wi-Fi ed hotspot con NetworkManager"
echo "  5. Avvio automatico al boot via systemd (infotainment.service)"
echo
echo "Per applicare tutti i driver e i parametri del kernel, esegui:"
echo "  sudo reboot"
echo "========================================================================="
