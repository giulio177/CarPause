import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Item {
    id: airPlayRoot

    signal requestOpenWifiSettings()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 14

        // ====================================================================
        // 1. TOP HEADER: Title, Subtitle, and AirPlay Receiver Toggle
        // ====================================================================
        RowLayout {
            Layout.fillWidth: true
            spacing: 16

            Rectangle {
                width: 48
                height: 48
                radius: 24
                color: backend.airplayRunning ? "#163442" : theme.surfaceElevated
                border.color: backend.airplayRunning ? theme.accentCyan : theme.surfaceBorder
                border.width: 1.5

                MaterialIcon {
                    name: "airplay"
                    size: 26
                    iconColor: backend.airplayRunning ? theme.accentCyan : theme.textSecondary
                    anchors.centerIn: parent
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                RowLayout {
                    spacing: 10

                    Text {
                        text: "AIRPLAY MIRRORING"
                        color: theme.textPrimary
                        font.pixelSize: 20
                        font.bold: true
                        font.letterSpacing: 0.5
                    }

                    // Status Pill
                    Rectangle {
                        height: 22
                        radius: 11
                        color: {
                            if (backend.airplayStreaming) return "#1A4526";
                            if (backend.airplayRunning) return "#133748";
                            return "#2B1A22";
                        }
                        border.color: {
                            if (backend.airplayStreaming) return theme.accentGreen;
                            if (backend.airplayRunning) return theme.accentCyan;
                            return theme.accentRed;
                        }
                        border.width: 1
                        implicitWidth: statusText.implicitWidth + 18

                        Row {
                            anchors.centerIn: parent
                            spacing: 6

                            Rectangle {
                                width: 7
                                height: 7
                                radius: 3.5
                                color: {
                                    if (backend.airplayStreaming) return theme.accentGreen;
                                    if (backend.airplayRunning) return theme.accentCyan;
                                    return theme.accentRed;
                                }
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                id: statusText
                                text: {
                                    if (backend.airplayStreaming) return "STREAMING IN CORSO";
                                    if (backend.airplayRunning) return "IN ASCOLTO";
                                    return "RICEVITORE DISATTIVO";
                                }
                                color: {
                                    if (backend.airplayStreaming) return theme.accentGreen;
                                    if (backend.airplayRunning) return theme.accentCyan;
                                    return theme.textSecondary;
                                }
                                font.pixelSize: 10
                                font.bold: true
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }

                Text {
                    text: "Duplica lo schermo e l'audio del tuo iPhone in tempo reale"
                    color: theme.textSecondary
                    font.pixelSize: 12
                }
            }

            // Receiver Power Switch
            RowLayout {
                spacing: 10
                Layout.alignment: Qt.AlignVCenter

                Text {
                    text: backend.airplayRunning ? "Ricevitore Attivo" : "Ricevitore Spento"
                    color: backend.airplayRunning ? theme.accentCyan : theme.textMuted
                    font.pixelSize: 13
                    font.bold: true
                }

                AppleSwitch {
                    checked: backend.airplayRunning
                    onToggled: (isChecked) => {
                        backend.toggleAirPlay();
                    }
                }
            }
        }

        // ====================================================================
        // 2. REAL-TIME HOTSPOT & WI-FI CONNECTION BANNER
        // ====================================================================
        Rectangle {
            Layout.fillWidth: true
            height: 48
            radius: theme.radiusMedium
            color: backend.wifiConnected ? "#10231D" : "#281D14"
            border.color: backend.wifiConnected ? "#1F5941" : "#593D1F"
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 12

                MaterialIcon {
                    name: backend.wifiConnected ? "wifi" : "wifi_off"
                    size: 22
                    iconColor: backend.wifiConnected ? theme.accentGreen : theme.accentYellow
                }

                Text {
                    text: backend.wifiConnected
                          ? ("Connesso alla rete Wi-Fi: " + backend.wifiSsid)
                          : "Raspberry non connesso ad alcuna rete Wi-Fi / Hotspot"
                    color: theme.textPrimary
                    font.pixelSize: 13
                    font.bold: true
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }

                // IP Address Badge if connected
                Rectangle {
                    visible: backend.wifiConnected && (backend.wifiIp.length > 0)
                    height: 26
                    radius: 13
                    color: "#163328"
                    border.color: theme.accentGreen
                    border.width: 1
                    implicitWidth: ipText.implicitWidth + 20

                    Text {
                        id: ipText
                        anchors.centerIn: parent
                        text: "IP: " + backend.wifiIp
                        color: theme.accentGreen
                        font.pixelSize: 11
                        font.bold: true
                    }
                }

                // Quick Action to open Wi-Fi settings if not connected
                Rectangle {
                    id: wifiActionBtn
                    visible: !backend.wifiConnected
                    height: 32
                    radius: 16
                    color: wifiActionMouse.pressed ? theme.accentYellow : "#382914"
                    border.color: theme.accentYellow
                    border.width: 1
                    implicitWidth: wifiActionText.implicitWidth + 24

                    Row {
                        anchors.centerIn: parent
                        spacing: 6

                        MaterialIcon {
                            name: "settings"
                            size: 16
                            iconColor: wifiActionMouse.pressed ? theme.bgDark : theme.accentYellow
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            id: wifiActionText
                            text: "Configura Wi-Fi"
                            color: wifiActionMouse.pressed ? theme.bgDark : theme.accentYellow
                            font.pixelSize: 12
                            font.bold: true
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: wifiActionMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            airPlayRoot.requestOpenWifiSettings();
                        }
                    }
                }
            }
        }

        // ====================================================================
        // 3. STEP-BY-STEP AUTOMOTIVE GUIDE CARDS
        // ====================================================================
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 16

            // STEP 1 CARD: Personal Hotspot
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: theme.radiusLarge
                color: theme.surfaceDark
                border.color: theme.surfaceBorder
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 12

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Rectangle {
                            width: 30
                            height: 30
                            radius: 15
                            color: "#382810"
                            border.color: theme.accentYellow
                            border.width: 1

                            Text {
                                text: "1"
                                anchors.centerIn: parent
                                color: theme.accentYellow
                                font.pixelSize: 14
                                font.bold: true
                            }
                        }

                        Text {
                            text: "Hotspot Telefono"
                            color: theme.textPrimary
                            font.pixelSize: 16
                            font.bold: true
                            Layout.fillWidth: true
                        }

                        MaterialIcon {
                            name: "wifi_tethering"
                            size: 24
                            iconColor: theme.accentYellow
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: theme.surfaceBorder
                    }

                    Text {
                        text: "Accendi l'Hotspot Personale nelle impostazioni del tuo iPhone.\n\nAssicurati che sia spuntata l'opzione 'Consenti ad altri di accedere'."
                        color: theme.textSecondary
                        font.pixelSize: 13
                        lineHeight: 1.3
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 28
                        radius: 8
                        color: theme.surfaceElevated

                        Row {
                            anchors.centerIn: parent
                            spacing: 6
                            MaterialIcon {
                                name: "info"
                                size: 14
                                iconColor: theme.textMuted
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: "Richiede Wi-Fi e Bluetooth attivi su iOS"
                                color: theme.textMuted
                                font.pixelSize: 10
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }
            }

            // STEP 2 CARD: Connect Raspberry
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: theme.radiusLarge
                color: theme.surfaceDark
                border.color: backend.wifiConnected ? theme.accentCyan : theme.surfaceBorder
                border.width: backend.wifiConnected ? 1.5 : 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 12

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Rectangle {
                            width: 30
                            height: 30
                            radius: 15
                            color: "#133644"
                            border.color: theme.accentCyan
                            border.width: 1

                            Text {
                                text: "2"
                                anchors.centerIn: parent
                                color: theme.accentCyan
                                font.pixelSize: 14
                                font.bold: true
                            }
                        }

                        Text {
                            text: "Collega Raspberry"
                            color: theme.textPrimary
                            font.pixelSize: 16
                            font.bold: true
                            Layout.fillWidth: true
                        }

                        MaterialIcon {
                            name: "phonelink"
                            size: 24
                            iconColor: theme.accentCyan
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: theme.surfaceBorder
                    }

                    Text {
                        text: "Connetti il Raspberry Pi alla rete Wi-Fi dell'iPhone.\n\nI due dispositivi devono essere sulla stessa rete locale per comunicare via mDNS."
                        color: theme.textSecondary
                        font.pixelSize: 13
                        lineHeight: 1.3
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                    }

                    // Quick Connection Indicator
                    Rectangle {
                        Layout.fillWidth: true
                        height: 28
                        radius: 8
                        color: backend.wifiConnected ? "#143026" : "#2E2419"

                        Row {
                            anchors.centerIn: parent
                            spacing: 6
                            MaterialIcon {
                                name: backend.wifiConnected ? "check_circle" : "pending"
                                size: 14
                                iconColor: backend.wifiConnected ? theme.accentGreen : theme.accentYellow
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: backend.wifiConnected ? ("Connesso: " + backend.wifiSsid) : "In attesa di connessione..."
                                color: backend.wifiConnected ? theme.accentGreen : theme.accentYellow
                                font.pixelSize: 10
                                font.bold: true
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }
            }

            // STEP 3 CARD: Screen Mirroring AirPlay
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: theme.radiusLarge
                color: theme.surfaceDark
                border.color: backend.airplayStreaming ? theme.accentGreen : theme.surfaceBorder
                border.width: backend.airplayStreaming ? 1.5 : 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 12

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Rectangle {
                            width: 30
                            height: 30
                            radius: 15
                            color: "#183824"
                            border.color: theme.accentGreen
                            border.width: 1

                            Text {
                                text: "3"
                                anchors.centerIn: parent
                                color: theme.accentGreen
                                font.pixelSize: 14
                                font.bold: true
                            }
                        }

                        Text {
                            text: "Duplica Schermo"
                            color: theme.textPrimary
                            font.pixelSize: 16
                            font.bold: true
                            Layout.fillWidth: true
                        }

                        MaterialIcon {
                            name: "cast"
                            size: 24
                            iconColor: theme.accentGreen
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: theme.surfaceBorder
                    }

                    Text {
                        text: "Apri il Centro di Controllo scorrendo dall'alto a destra dell'iPhone, tocca 'Duplica Schermo' e seleziona:"
                        color: theme.textSecondary
                        font.pixelSize: 13
                        lineHeight: 1.3
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    // AirPlay Target Name Badge
                    Rectangle {
                        Layout.fillWidth: true
                        height: 42
                        radius: 10
                        color: "#172236"
                        border.color: theme.accentCyan
                        border.width: 1.5

                        Row {
                            anchors.centerIn: parent
                            spacing: 8

                            MaterialIcon {
                                name: "airplay"
                                size: 18
                                iconColor: theme.accentCyan
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: backend.airplayServerName
                                color: theme.accentCyan
                                font.pixelSize: 15
                                font.bold: true
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }
                }
            }
        }

        // ====================================================================
        // 4. FOOTER NOTE / TOUCH HINT & DECODER MODE
        // ====================================================================
        Rectangle {
            Layout.fillWidth: true
            height: 40
            radius: theme.radiusMedium
            color: theme.surfaceDark
            border.color: theme.surfaceBorder
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 10

                MaterialIcon {
                    name: "touch_app"
                    size: 18
                    iconColor: theme.accentCyan
                }

                Text {
                    text: "Durante la duplicazione schermo, tocca lo schermo o tieni premuto per 5 secondi per forzare l'uscita immediata."
                    color: theme.textSecondary
                    font.pixelSize: 12
                    Layout.fillWidth: true
                }

                // Decoder Mode Indicator / Quick Toggle
                Rectangle {
                    height: 24
                    radius: 12
                    color: backend.airplayDecoder === "software" ? "#143026" : "#2E2419"
                    border.color: backend.airplayDecoder === "software" ? theme.accentGreen : theme.accentYellow
                    border.width: 1
                    implicitWidth: decoderLabel.implicitWidth + 20

                    Row {
                        anchors.centerIn: parent
                        spacing: 5

                        MaterialIcon {
                            name: backend.airplayDecoder === "software" ? "palette" : "speed"
                            size: 13
                            iconColor: backend.airplayDecoder === "software" ? theme.accentGreen : theme.accentYellow
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            id: decoderLabel
                            text: backend.airplayDecoder === "software" ? "Colori Fedeli (avdec)" : "Hardware (v4l2)"
                            color: backend.airplayDecoder === "software" ? theme.accentGreen : theme.accentYellow
                            font.pixelSize: 10
                            font.bold: true
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var nextMode = backend.airplayDecoder === "software" ? "hardware" : "software";
                            backend.setAirPlayDecoder(nextMode);
                        }
                    }
                }
            }
        }
    }

    // ========================================================================
    // 5. MISSING UXPLAY WARNING OVERLAY (If binary is not installed)
    // ========================================================================
    Rectangle {
        anchors.fill: parent
        color: "#E60B0F17"
        visible: !backend.airplayAvailable
        z: 100

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 16
            width: parent.width * 0.7

            Rectangle {
                width: 60
                height: 60
                radius: 30
                color: "#3D2A12"
                border.color: theme.accentYellow
                border.width: 2
                Layout.alignment: Qt.AlignHCenter

                MaterialIcon {
                    name: "warning"
                    size: 32
                    iconColor: theme.accentYellow
                    anchors.centerIn: parent
                }
            }

            Text {
                text: "Pacchetto UxPlay non installato"
                color: theme.textPrimary
                font.pixelSize: 20
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                text: "Per abilitare il mirroring dello schermo AirPlay dall'iPhone, è necessario installare UxPlay sul Raspberry Pi con il comando:\n\nsudo apt install uxplay\n\n(oppure 'sudo dnf install uxplay' su distribuzioni basate su Fedora)."
                color: theme.textSecondary
                font.pixelSize: 13
                lineHeight: 1.4
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }
    }
}
