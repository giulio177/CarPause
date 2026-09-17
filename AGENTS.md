# DOX framework

- DOX is highly performant AGENTS.md hierarchy installed here
- Agent must follow DOX instructions across any edits

## Core Contract

- AGENTS.md files are binding work contracts for their subtrees
- Work products, source materials, instructions, records, assets, and durable docs must stay understandable from the nearest applicable AGENTS.md plus every parent AGENTS.md above it

## Read Before Editing

1. Read the root AGENTS.md
2. Identify every file or folder you expect to touch
3. Walk from the repository root to each target path
4. Read every AGENTS.md found along each route
5. If a parent AGENTS.md lists a child AGENTS.md whose scope contains the path, read that child and continue from there
6. Use the nearest AGENTS.md as the local contract and parent docs for repo-wide rules
7. If docs conflict, the closer doc controls local work details, but no child doc may weaken DOX

Do not rely on memory. Re-read the applicable DOX chain in the current session before editing.

## Update After Editing

Every meaningful change requires a DOX pass before the task is done.

Update the closest owning AGENTS.md when a change affects:

- purpose, scope, ownership, or responsibilities
- durable structure, contracts, workflows, or operating rules
- required inputs, outputs, permissions, constraints, side effects, or artifacts
- user preferences about behavior, communication, process, organization, or quality
- AGENTS.md creation, deletion, move, rename, or index contents

Update parent docs when parent-level structure, ownership, workflow, or child index changes. Update child docs when parent changes alter local rules. Remove stale or contradictory text immediately. Small edits that do not change behavior or contracts may leave docs unchanged, but the DOX pass still must happen.

## Hierarchy

- Root AGENTS.md is the DOX rail: project-wide instructions, global preferences, durable workflow rules, and the top-level Child DOX Index
- Child AGENTS.md files own domain-specific instructions and their own Child DOX Index
- Each parent explains what its direct children cover and what stays owned by the parent
- The closer a doc is to the work, the more specific and practical it must be

## Child Doc Shape

- Create a child AGENTS.md when a folder becomes a durable boundary with its own purpose, rules, responsibilities, workflow, materials, or quality standards
- Work Guidance must reflect the current standards of the project or user instructions; if there are no specific standards or instructions yet, leave it empty
- Verification must reflect an existing check; if no verification framework exists yet, leave it empty and update it when one exists

Default section order:
- Purpose
- Ownership
- Local Contracts
- Work Guidance
- Verification
- Child DOX Index

## Style

- Keep docs concise, current, and operational
- Document stable contracts, not diary entries
- Put broad rules in parent docs and concrete details in child docs
- Prefer direct bullets with explicit names
- Do not duplicate rules across many files unless each scope needs a local version
- Delete stale notes instead of explaining history
- Trim obvious statements, repeated rules, misplaced detail, and warnings for risks that no longer exist

## Closeout

1. Re-check changed paths against the DOX chain
2. Update nearest owning docs and any affected parents or children
3. Refresh every affected Child DOX Index
4. Remove stale or contradictory text
5. Run existing verification when relevant
6. Report any docs intentionally left unchanged and why

## User Preferences

- The root directory (`Mito/`) is the primary home of the modern Raspberry Pi 4B infotainment system (PyQt6 + QML).
- `legacy_repo/` is archived for reference and excluded from git.
- **Zero Dummy Data Contract:** Never fabricate numbers, fake tracks, or simulated sensor data. If a hardware interface (OBD-II, Bluetooth, Media player, Wi-Fi) is disconnected or unavailable, the UI must strictly reflect the actual disconnected/error state.

## Project Architecture & Ownership

- `main.py`: Application entrypoint configuring platform plugins (EGLFS on Pi, Wayland/XCB on desktop) and initializing `QGuiApplication` + `QQmlApplicationEngine`.
- `music/`: Local Raspberry Pi music storage directory containing audio files (`.mp3`, `.wav`, etc.), cover artwork (`.png`, `.jpg`), sidecar metadata (`.json`), and lyrics (`.lrc`, `.txt`).
- `logs/`: Application session logging directory containing per-boot log files (`session_YYYY-MM-DD_HH-MM-SS.log`).
- `backend.py`: High-performance QObject bridge exposing reactive `Q_PROPERTY` attributes and non-blocking `@pyqtSlot` handlers to QML.
  - Real-time event-driven D-Bus listeners (`PropertiesChanged` on System & Session buses) for instantaneous (<10ms) BlueZ AVRCP and MPRIS metadata and play/pause state synchronization.
  - Local music playback engine (`QMediaPlayer` + `QAudioOutput`) integrating local audio files from `music/` with automatic playlist progression, shuffle mode (`shuffleEnabled`, `toggleShuffle`), 3-state repeat mode (`repeatMode` cycling `off` -> `all` -> `one` -> `off`, `toggleRepeat`), lyrics exposure, album cover art binding, and high-frequency 500ms playback position polling ticker (`_playback_ticker`).
  - Dual-source media switching (`mediaSource` property, `toggleMediaSource` slot): enables instant display swapping between Bluetooth audio (`"remote"`) and internal music library (`"local"`), preserving independent playback, track metadata, shuffle, and repeat states even when both are paused or in standby.
  - Zero-latency optimistic UI updates on media playback controls (`togglePlay`) with anti-bounce target locking to prevent AVRCP transit flicker, combined with staggered burst syncs (`nextTrack`, `previousTrack`).
  - Audio management with configurable maximum volume limit (`maxVolume`, `setMaxVolume` up to 200% for software amplification), non-zero volume memory, and automatic unmute recovery across PipeWire and ALSA.
  - Quick tap app-only restart (`restartApp` via `os.execv`) and protected 3-second hold modal reboot (`rebootSystem` via `systemctl reboot`).
  - Bluetooth device list property (`availableBluetoothDevices`), pairing/connect/disconnect slots, active discovery scan (`scanBluetooth`), and discoverable/pairable mode toggle (`toggleBluetoothDiscoverable`).
  - AirPlay screen mirroring management (`airplayAvailable`, `airplayRunning`, `airplayStreaming`, `airplayServerName`, `airplayClientInfo`, `airplayStatusMessage`, `airplayShowExitPopup`, `wifiIp`), start/stop/toggle slots, touch-to-exit trigger, and auto-activation on navigation.
  - Unified listening history aggregator property (`mediaHistoryList`) and local music library property (`localMusicTracks`).
  - Real-time application log stream property (`appLogs`), active session log file property (`currentLogFilename`), session file clearing slot (`clearLogs`), and log file re-reading slot (`refreshLogs`).
- `qml/`: Pure declarative UI, modular automotive architecture fixed at 1024x600 resolution:
  - `Main.qml`: Central coordinator linking top bar, central workspace stack, bottom bar, fullscreen streaming overlays, and parameterized modal overlays.
  - `Theme.qml` & `qmldir`: Global design token singleton (dark mode, automotive touch sizes, curated palette).
  - `bars/`: `TopBar.qml` (borderless status bar seamlessly blending into background with dynamic Material Symbols for weather conditions, clock, CPU, battery, and tappable Wi-Fi / Bluetooth status pills opening their respective settings subpages), `BottomBar.qml` (compact mini-media player, screen navigation tabs with centered icon and small text underneath: DASH, MEDIA, AIRPLAY, SETTING; app restart / 3-second hold reboot button, and volume slider dynamically bounded by `maxVolume` with amber boost indicator for volumes > 100%).
  - `views/`: Dedicated modular screens (`DashboardView.qml`, `MediaView.qml`, `AirPlayView.qml`, `SettingsView.qml` acting as a sub-navigator with a dedicated left sidebar).
    - `MediaView.qml`: Automotive media hub with 3 sub-views: "In Riproduzione" (supports seamless toggling between Classic Player with photo on left, title/texts & controls on right, full-width sliding progress bar and bottom buttons, and Split Screen with full lyrics on the right and compact controls/cover/seek bar on the left; both views include an interactive source badge that swaps display and control between Bluetooth and internal music library on tap), "Libreria Raspberry" (touch list of local tracks in `music/` with cover thumbnails, lyrics badge direct launcher, and automatic transition to player), and "Cronologia Ascolti" (continuous, flat chronological list of all tracks listened to across all sessions, with status badges, listened duration vs total, and filters).
    - `AirPlayView.qml`: Dedicated AirPlay screen mirroring guide replacing the legacy climate screen. Features real-time Wi-Fi & Hotspot connection status (SSID, local IP, direct link to Wi-Fi settings if disconnected), 3 interactive automotive guide cards (Personal Hotspot on iPhone, Wi-Fi pairing, Control Center screen mirroring with device target name badge), UxPlay daemon power toggle switch, touch-exit hint, and missing binary installation instructions.
    - `views/settings/`: Apple-style settings subpages: `GeneralSettingsView.qml` (diagnostics & system status, and audio configuration for bottom bar max volume limit with 100%, 125%, 150%, 200% presets and stepper), `WifiSettingsView.qml` (Apple-style Wi-Fi manager with radio power toggle, signal-based icons, known networks separation, full-row connection tap, and info popup), `BluetoothSettingsView.qml` (Apple-style Bluetooth manager with adapter power switch, discoverability toggle, paired vs nearby device separation, and device info popup), `LogsSettingsView.qml` (touch-scrollable dark-mode log console reading directly from disk session log file in `logs/`, featuring active file badge, event count pill, level filters, manual disk reload button, auto-scroll toggle, and file clearing).
  - `popups/`: Dedicated parameterized modals (`ConfirmationModal.qml` for system alerts/reboots, `WifiPasswordModal.qml` with integrated touch keyboard, `NetworkDetailsModal.qml` for Wi-Fi info/forget, `DeviceDetailsModal.qml` for Bluetooth device info/unpair, `LyricsModal.qml` for displaying song lyrics, `AirPlayExitOverlay.qml` for floating top-right touch exit during video streaming).
  - `components/`: Core touch components (`MaterialIcon.qml` utilizing Google Material Symbols Rounded font, `AppleSwitch.qml` for iOS-like toggles, `VirtualKeyboard.qml` for automotive text input).
- `src/services/`: Linux OS and hardware services (zero Qt dependency):
  - `airplay_service.py`: Subprocess lifecycle manager for UxPlay AirPlay mirroring daemon (supports Wayland/GStreamer hardware acceleration, real-time stdout status parsing for client connections and mirroring events, and background `evdev` touch event monitoring on `/dev/input/event*` during active video streaming).
  - `local_music_service.py`: Scans `music/` for audio files (`.mp3`, `.wav`, `.ogg`, `.flac`, `.m4a`), parses sidecar JSON metadata, cover artwork, and lyrics files (`.lrc`, `.txt`).
  - `log_service.py`: Session-based file logging manager creating per-boot log files in `logs/` (`session_YYYY-MM-DD_HH-MM-SS.log`), automatically cleaning up 0-byte stale sessions, immediately flushing log records to disk, and parsing log lines into structured dictionaries for the UI.
  - `system_service.py`: WirePlumber/PipeWire (`wpctl`), PulseAudio multi-sink and stream muting (`pactl`), ALSA Master fallback (`amixer`), CPU thermal sensors, Open-Meteo weather client.
  - `network_service.py`: Real NetworkManager (`nmcli`) Wi-Fi scanner with active IP address detection and BlueZ (`bluetoothctl`) tracking with discoverable broadcast and active device scanning.
  - `media_service.py`: Real BlueZ Bluetooth AVRCP (`org.bluez.MediaPlayer1` / `MediaControl1` on System D-Bus) and MPRIS media player tracking (`org.mpris.MediaPlayer2` on Session D-Bus). Supports live metadata queries, playback control dispatch, and remote Shuffle / Repeat setting requests (`set_player_shuffle`, `set_player_repeat`) translating to AVRCP SetPlayerApplicationSettingValue PDUs for connected smartphones.
  - `media_history_service.py`: Session-based audio playback history logger creating date-stamped JSON files in `media_history/` (tracks played songs, active listened duration, progress %, and completed/skipped status; automatically purges empty session files with 0 tracks on startup and graceful exit). Exposes `get_all_history_tracks()` for unified cross-session chronological retrieval.
  - `obd_service.py`: Real ELM327 serial port scanning and vehicle telemetry connection.
- `src/core/`: Thread pool async runner (`QThreadPool`) ensuring zero main GUI thread blocking with safe thread teardown.
- `scripts/`: Deployment, installation, and hardware startup scripts:
  - `install_rpi_infotainment.sh`: Idempotent system-wide installer for Raspberry Pi OS (configures Full KMS `vc4-kms-v3d`, 1024x600 HDMI timings, PipeWire/ALSA, BlueZ auto-pairing, UxPlay AirPlay mirror receiver with GStreamer acceleration, user permissions, and systemd autostart).
  - `start_infotainment.sh`: Automotive kiosk launcher optimizing Qt Quick scenegraph (`QSG_RENDER_LOOP=threaded`), platform plugins (EGLFS/Wayland), audio routing, and executing `main.py`.
  - `update_infotainment.sh`: One-click remote updater pulling latest git commits from GitHub, installing dependency updates, and restarting the application.

## Child DOX Index

- [legacy_repo](file:///home/giulio/Desktop/Mito/legacy_repo/AGENTS.md): Legacy car infotainment system based on QtWidgets and embedded WebEngine (archived for reference during migration).