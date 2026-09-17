import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Rectangle {
    id: modalRoot
    anchors.fill: parent
    color: Qt.rgba(0, 0, 0, 0.85)
    visible: false
    z: 1000

    property string ssid: ""
    property int signal: 0
    property string security: ""
    property bool inUse: false
    property bool saved: false

    signal requestPassword(string ssid)

    function openForNetwork(net) {
        if (!net) return;
        modalRoot.ssid = net.ssid || "";
        modalRoot.signal = net.signal || 0;
        modalRoot.security = net.security || "Aperta";
        modalRoot.inUse = Boolean(net.inUse || net.active);
        modalRoot.saved = Boolean(net.saved);
        modalRoot.visible = true;
    }

    function closeModal() {
        modalRoot.visible = false;
    }

    // Intercept clicks
    MouseArea {
        anchors.fill: parent
    }

    Rectangle {
        anchors.centerIn: parent
        width: 500
        height: 340
        radius: theme.radiusLarge
        color: theme.surfaceDark
        border.color: theme.surfaceBorder
        border.width: 1.5

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 22
            spacing: 14

            // Header
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                MaterialIcon {
                    name: "info"
                    size: 24
                    iconColor: theme.accentCyan
                }

                Text {
                    text: modalRoot.ssid
                    color: theme.textPrimary
                    font.pixelSize: 18
                    font.bold: true
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Rectangle {
                    width: 32
                    height: 32
                    radius: 16
                    color: "transparent"

                    MaterialIcon {
                        anchors.centerIn: parent
                        name: "close"
                        size: 20
                        iconColor: theme.textMuted
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: modalRoot.closeModal()
                    }
                }
            }

            // Info Card
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 110
                radius: theme.radiusMedium
                color: theme.surfaceElevated
                border.color: theme.surfaceBorder

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Stato connessione"; color: theme.textSecondary; font.pixelSize: 13 }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: modalRoot.inUse ? "Connessa" : (modalRoot.saved ? "Rete salvata" : "Disponibile")
                            color: modalRoot.inUse ? theme.accentGreen : (modalRoot.saved ? theme.accentCyan : theme.textMuted)
                            font.pixelSize: 13
                            font.bold: true
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Intensità segnale"; color: theme.textSecondary; font.pixelSize: 13 }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: modalRoot.signal + "%"
                            color: theme.textPrimary
                            font.pixelSize: 13
                            font.bold: true
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Tipo di sicurezza"; color: theme.textSecondary; font.pixelSize: 13 }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: modalRoot.security || "Aperta (Nessuna)"
                            color: theme.textPrimary
                            font.pixelSize: 13
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }

            // Action Buttons
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                // Connect / Disconnect button
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 44
                    radius: theme.radiusMedium
                    color: modalRoot.inUse ? "#331620" : "#172A3C"
                    border.color: modalRoot.inUse ? theme.accentRed : theme.accentCyan
                    border.width: 1

                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        MaterialIcon {
                            name: modalRoot.inUse ? "wifi_off" : "wifi"
                            size: 16
                            iconColor: modalRoot.inUse ? theme.accentRed : theme.accentCyan
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: modalRoot.inUse ? "Disconnetti" : "Connetti"
                            color: modalRoot.inUse ? theme.accentRed : theme.accentCyan
                            font.pixelSize: 13
                            font.bold: true
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            modalRoot.closeModal();
                            if (modalRoot.inUse) {
                                backend.disconnectWifiNetwork(modalRoot.ssid);
                            } else {
                                if (modalRoot.saved) {
                                    backend.connectSavedWifi(modalRoot.ssid);
                                } else {
                                    modalRoot.requestPassword(modalRoot.ssid);
                                }
                            }
                        }
                    }
                }

                // Forget Network Button (Only if saved)
                Rectangle {
                    visible: modalRoot.saved
                    Layout.fillWidth: true
                    implicitHeight: 44
                    radius: theme.radiusMedium
                    color: forgetArea.pressed ? theme.surfaceBorder : theme.surfaceElevated
                    border.color: theme.accentYellow
                    border.width: 1

                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        MaterialIcon {
                            name: "delete_outline"
                            size: 16
                            iconColor: theme.accentYellow
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: "Dimentica rete"
                            color: theme.accentYellow
                            font.pixelSize: 13
                            font.bold: true
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: forgetArea
                        anchors.fill: parent
                        onClicked: {
                            modalRoot.closeModal();
                            backend.forgetWifi(modalRoot.ssid);
                        }
                    }
                }
            }
        }
    }
}
