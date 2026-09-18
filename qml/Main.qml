import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import "components"
import "bars"
import "views"
import "popups"

ApplicationWindow {
    id: rootWindow
    visible: true
    width: 1024
    height: 600
    title: "RPi Automotive Infotainment"
    color: theme.bgDark

    // Automotive Touch Constraints (Fixed 1024x600 for 7" RPi Display)
    minimumWidth: 1024
    minimumHeight: 600
    maximumWidth: 1024
    maximumHeight: 600

    // FontLoader ensures font is always registered in QML runtime
    FontLoader {
        id: materialFontLoader
        source: "../Material_Symbols_Rounded/MaterialSymbolsRounded-VariableFont_FILL,GRAD,opsz,wght.ttf"
    }

    // Design Tokens and Theme Colors
    QtObject {
        id: theme
        readonly property color bgDark: "#0B0F17"
        readonly property color surfaceDark: "#141A24"
        readonly property color surfaceElevated: "#1E2638"
        readonly property color surfaceBorder: "#2A354D"
        readonly property color accentCyan: "#00E5FF"
        readonly property color accentBlue: "#0072FF"
        readonly property color accentRed: "#FF3366"
        readonly property color accentYellow: "#FFB300"
        readonly property color accentGreen: "#00E676"
        readonly property color textPrimary: "#FFFFFF"
        readonly property color textSecondary: "#9AA5B8"
        readonly property color textMuted: "#5D6A82"
        readonly property int touchMinSize: 56
        readonly property int radiusMedium: 14
        readonly property int radiusLarge: 20
    }

    // ========================================================================
    // MAIN APPLICATION LAYOUT (TopBar, Full-Width Central Views, BottomBar)
    // ========================================================================
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // 1. TOP STATUS BAR (No border, seamless dark background)
        TopBar {
            id: topBar
            visible: !backend.airplayStreaming
            onRequestOpenSettings: (subTab) => {
                backend.changeView("settings");
                settingsView.currentSubTab = subTab;
            }
        }

        // 2. CENTRAL WORKSPACE (Full 1024px width, no sidebar clutter)
        StackLayout {
            id: contentStack
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: {
                if (backend.currentView === "media") return 1;
                if (backend.currentView === "airplay") return 2;
                if (backend.currentView === "settings") return 3;
                return 0; // dashboard
            }

            DashboardView {
                id: dashboardView
            }

            MediaView {
                id: mediaView
            }

            AirPlayView {
                id: airPlayView
                onRequestOpenWifiSettings: {
                    backend.changeView("settings");
                    settingsView.currentSubTab = "wifi";
                }
            }

            SettingsView {
                id: settingsView
                onRequestWifiConnect: (ssid) => {
                    wifiPasswordModal.openForSsid(ssid);
                }
            }
        }

        // 3. UNIFIED BOTTOM BAR (Mini-Media, Navigation Tabs, Volume Slider)
        BottomBar {
            id: bottomBar
            visible: !backend.airplayStreaming
            onRequestRebootModal: {
                confirmationModal.openModal({
                    title: "Riavvio Raspberry Pi",
                    subtitle: "Conferma riavvio del sistema operativo",
                    message: "Sei sicuro di voler riavviare l'intero sistema Raspberry Pi?\nTutti i processi in esecuzione, l'audio e le connessioni verranno interrotti.",
                    iconName: "restart_alt",
                    iconColor: theme.accentYellow,
                    borderColor: theme.accentYellow,
                    confirmText: "Riavvia Sistema",
                    cancelText: "Annulla"
                });
            }
        }
    }

    // ========================================================================
    // AIRPLAY STREAMING OVERLAYS (Touch interceptor & floating exit button)
    // ========================================================================
    MouseArea {
        id: airplayTouchCatcher
        anchors.fill: parent
        z: 9998
        visible: backend.airplayStreaming
        onClicked: (mouse) => {
            backend.stopAirPlayStream();
        }
    }

    AirPlayExitOverlay {
        id: airPlayExitOverlay
    }

    // ========================================================================
    // POPUPS & MODAL DIALOGS
    // ========================================================================
    WifiPasswordModal {
        id: wifiPasswordModal
    }

    ConfirmationModal {
        id: confirmationModal
        onConfirmed: {
            backend.rebootSystem();
        }
    }
}
