# Mito - Raspberry Pi Automotive Infotainment 🚗💨

Un sistema di infotainment automobilistico moderno, fluido e touch-friendly sviluppato per **Raspberry Pi 4B** (ottimizzato per display touchscreen capacitivo **1024x600** su Alfa Romeo MiTo).

L'interfaccia è costruita nativamente in **PyQt6 + QML (Qt Quick)** con accelerazione hardware GPU (Full KMS / Wayland) a **60 FPS**, collegata a servizi Linux reali (PipeWire, NetworkManager, BlueZ, GStreamer, OBD-II).

> **Zero Dummy Data Contract:** L'infotainment visualizza e gestisce esclusivamente dati e periferiche hardware reali. Nessun dato fittizio, sensore simulato o finta traccia audio.

---

## 🌟 Caratteristiche Principali

### 1. Dashboard Telemetria & Monitoraggio
* **Telemetria Veicolo OBD-II:** Lettura in tempo reale di velocità (km/h), regime motore (RPM) e voltaggio batteria (V) tramite adattatore ELM327 USB/Bluetooth.
* **Diagnostica Hardware:** Temperatura CPU Broadcom in tempo reale e stato connessioni.
* **Meteo Live:** Condizioni meteo e temperatura esterna via API Open-Meteo.
* **Mini-Player Integrato:** Controlli multimediali rapidi e titolo traccia sempre a portata di tocco.

### 2. Hub Multimediale (Dual-Source Media Player)
* **Doppia Sorgente Multimediale:** Tasto interattivo per scambiare istantaneamente visualizzazione e controllo tra **Bluetooth Smartphone** (BlueZ AVRCP/MPRIS) e **Libreria Interna Raspberry Pi** (`music/`).
* **Visualizzazione Flessibile:** Supporta sia il **Player Classico** (cover grande a sinistra, controlli e slider a destra), sia il **Player Split-Screen con Testi (Lyrics)** a tutto schermo sulla destra per file `.lrc` o `.txt`.
* **Cronologia Ascolti Completa:** Storico unificato dei brani riprodotti tra tutte le sessioni, con indicazione del tempo effettivo di ascolto, percentuale di completamento e badge (*Completata*, *Parziale*, *Saltata*).
* **Controlli Avanzati:** Riproduzione casuale (Shuffle), modalità ripetizione a 3 stati (*Off* -> *Tutti* -> *Brano Singolo* -> *Off*).

### 3. Screen Mirroring Video AirPlay (UxPlay)
* **Duplicazione Schermo iPhone / iPad:** Streaming video fluido H.264 e audio wireless tramite server **UxPlay** integrato e accelerazione hardware GStreamer.
* **Guida Connessione Hotspot:** Schermata interattiva con visualizzazione dello stato Wi-Fi in tempo reale (SSID, IP locale assegnato) e guida passo-passo per collegarsi all'hotspot dell'iPhone e avviare la duplicazione dal Centro di Controllo.
* **Modalità Fullscreen & Popup di Uscita al Tocco:** Durante la duplicazione video, la barra superiore e inferiore si nascondono automaticamente a schermo intero (1024x600). Toccando lo schermo in qualsiasi punto, compare in alto a destra un popup compatto (*"Chiudi AirPlay"*) con timer di auto-occultamento a 4 secondi.

### 4. Impostazioni Stile Apple
* **Gestione Wi-Fi:** Scansione reale delle reti Wi-Fi (`nmcli`), indicatore del livello di segnale, separazione reti salvate vs disponibili, connessione con tastiera touch virtuale su schermo e dettaglio IP.
* **Gestione Bluetooth:** Switch alimentazione controller, modalità visibilità/scoperta, elenco dispositivi associati e ricerca dispositivi nelle vicinanze.
* **Agente Auto-Pairing "Just Works":** Consente l'accoppiamento Bluetooth istantaneo da qualsiasi telefono senza richiesta di PIN.
* **Configurazione Audio Avanzata:** Regolazione volume master con slider dinamico ed amplificazione software fino al **200%**.
* **Console Log di Sistema:** Visualizzatore in tempo reale dei log applicativi da disco (`logs/session_*.log`) con filtri di livello e auto-scroll.
* **Aggiornamento Software con 1 Click:** Pulsante in *Impostazioni Generali* per verificare, scaricare e installare automaticamente l'ultima versione disponibile da GitHub con riavvio a caldo dell'applicazione.

---

## 🛠️ Requisiti Hardware & Sistema Operativo

* **Board:** Raspberry Pi 4B (2GB, 4GB o 8GB RAM).
* **Sistema Operativo:** **Raspberry Pi OS (Bookworm 64-bit)** (Lite o Desktop).
* **Display:** Schermo touch capacitivo 7" con risoluzione nativa **1024x600** (HDMI + USB touch controller).
* **Audio:** Uscita analogica jack 3.5 mm o DAC audio I2S/USB configurato con PipeWire/ALSA.
* **Interfaccia Veicolo (Opzionale):** Cavo USB OBD-II ELM327 FTDI/CH340 collegato alla presa diagnosi OBD dell'auto.

---

## 🚀 Installazione Rapida su Raspberry Pi

Collega il Raspberry Pi a internet (via cavo Ethernet, Wi-Fi o Hotspot dello smartphone) ed esegui i seguenti passaggi:

```bash
# 1. Installa git (non presente di default su Pi OS Lite)
sudo apt update && sudo apt install -y git

# 2. Clona il repository nella tua home
cd ~
git clone https://github.com/giulio177/CarPause.git Mito
cd Mito

# 3. Esegui lo script di installazione automatica con permessi di root
sudo ./scripts/install_rpi_infotainment.sh

# 4. Riavvia il Raspberry Pi per applicare driver e configurazioni
sudo reboot
```

### Cosa fa lo script di installazione:
1. Installa tutte le dipendenze di sistema (PyQt6, QtQuick, GStreamer con codec hardware, UxPlay, NetworkManager, PipeWire, BlueZ).
2. Configura `/boot/firmware/config.txt` con il driver **Full KMS** (`vc4-kms-v3d`), risoluzione forzata **1024x600 @ 60Hz** e fix UART per il Bluetooth.
3. Configura l'avvio silenzioso automotive (`quiet`, `logo.nologo`, boot delay a zero).
4. Abilita il demone Bluetooth con agente auto-pairing *NoInputNoOutput* ("Just Works").
5. Configura il servizio mDNS Avahi per il rilevamento di AirPlay da iOS.
6. Assegna i permessi utente (`video`, `input`, `render`, `audio`, `dialout`, `netdev`) e crea le regole udev per il touchscreen.
7. Crea il virtualenv Python con `--system-site-packages` e installa le dipendenze.
8. Configura e abilita il servizio systemd `infotainment.service` per l'avvio automatico al boot in modalità kiosk.

---

## 🔄 Aggiornamento del Software

Puoi aggiornare l'infotainment all'ultima versione disponibile su GitHub in due modi:

### Metodo 1: Dall'interfaccia Touch (Consigliato)
1. Vai nella scheda **SETTING** (Impostazioni) in basso a destra.
2. Nella sezione *Generali*, scorri fino alla card **AGGIORNAMENTO SOFTWARE (GITHUB)**.
3. Tocca **"Verifica e Aggiorna"**. Il sistema scaricherà l'ultima versione, aggiornerà le dipendenze e si riavvierà da solo in 2 secondi.

### Metodo 2: Da Terminale / SSH
```bash
cd ~/Mito
./scripts/update_infotainment.sh
```

---

## 💻 Modalità Sviluppo su PC Desktop (Linux)

Il progetto può essere testato ed eseguito direttamente su un computer desktop Linux (con X11 o Wayland) a scopo di sviluppo:

```bash
cd Mito
./run_desktop.sh
```
Lo script configurerà automaticamente un virtualenv locale e avvierà l'interfaccia a 1024x600 in finestra con i moduli audio e grafici desktop.

---

## 📂 Struttura del Progetto

```
Mito/
├── main.py                     # Entrypoint applicazione (QGuiApplication + QML Engine)
├── backend.py                  # Controller ponte Python-QML (D-Bus, PipeWire, BlueZ, UxPlay)
├── requirements.txt            # Dipendenze Python (PyQt6, psutil, evdev)
├── AGENTS.md                   # Contratto architetturale e documentazione DOX
├── qml/                        # Interfaccia grafica dichiarativa Qt Quick (1024x600)
│   ├── Main.qml                # Coordinatore centrale e gestione layer fullscreen
│   ├── Theme.qml               # Design tokens, palette colori e misure touch
│   ├── bars/                   # TopBar (status bar trasparente) e BottomBar (navigazione e volume)
│   ├── views/                  # Schermate (DashboardView, MediaView, AirPlayView, SettingsView)
│   │   └── settings/           # Sotto-pagine impostazioni (Generali, Wi-Fi, Bluetooth, Log)
│   ├── popups/                 # Modali e overlay (AirPlayExitOverlay, WifiPasswordModal, ecc.)
│   └── components/             # Componenti touch riutilizzabili (AppleSwitch, VirtualKeyboard)
├── src/
│   ├── core/async_runner.py    # Esecutore task asincroni non bloccanti (QThreadPool)
│   └── services/               # Servizi di sistema OS e hardware reali (zero mock)
│       ├── airplay_service.py  # Gestione demone UxPlay e monitoraggio touch evdev
│       ├── network_service.py  # NetworkManager (nmcli) e BlueZ (bluetoothctl)
│       ├── media_service.py    # Ricezione D-Bus AVRCP/MPRIS Bluetooth
│       ├── media_history_service.py # Registrazione cronologia riproduzione su disco
│       ├── local_music_service.py   # Scanner libreria musicale locale e testi
│       ├── system_service.py   # Gestione volume PipeWire/ALSA e meteo
│       ├── obd_service.py      # Telemetria veicolo ELM327
│       └── log_service.py      # Gestione log di sessione su file
├── scripts/
│   ├── install_rpi_infotainment.sh # Installer di sistema completo per Raspberry Pi OS
│   ├── start_infotainment.sh       # Launcher kiosk con GPU acceleration (EGLFS/Wayland)
│   └── update_infotainment.sh      # Script di aggiornamento rapido da GitHub
└── music/                      # Directory locale per file audio (.mp3, .wav), cover e testi (.lrc)
```

---

## 📜 Licenza

Questo progetto è distribuito sotto licenza MIT.
