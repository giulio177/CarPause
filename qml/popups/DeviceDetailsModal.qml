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

    property string name: ""
    property string mac: ""
    property bool connected: false
    property bool paired: false

    function openForDevice(dev) {
        if (!dev) return;
        modalRoot.name = dev.name || dev.mac || "Dispositivo";
        modalRoot.mac = dev.mac || "";
        modalRoot.connected = Boolean(dev.connected);
        modalRoot.paired = Boolean(dev.paired);
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
        height: 320
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
                    name: "bluetooth"
                    size: 24
                    iconColor: modalRoot.connected ? theme.accentGreen : theme.accentCyan
                }

                Column {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        text: modalRoot.name
                        color: theme.textPrimary
                        font.pixelSize: 18
                        font.bold: true
                        elide: Text.ElideRight
                        width: parent.width
                    }
                    Text {
                        text: modalRoot.mac
                        color: theme.textMuted
                        font.pixelSize: 12
                    }
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
                Layout.preferredHeight: 80
                radius: theme.radiusMedium
                color: theme.surfaceElevated
                border.color: theme.surfaceBorder

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Stato associazione"; color: theme.textSecondary; font.pixelSize: 13 }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: modalRoot.connected ? "Connesso" : (modalRoot.paired ? "Associato" : "Disponibile nelle vicinanze")
                            color: modalRoot.connected ? theme.accentGreen : (modalRoot.paired ? theme.accentCyan : theme.textMuted)
                            font.pixelSize: 13
                            font.bold: true
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Indirizzo hardware MAC"; color: theme.textSecondary; font.pixelSize: 13 }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: modalRoot.mac
                            color: theme.textPrimary
                            font.pixelSize: 12
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
                    color: modalRoot.connected ? "#331620" : "#172A3C"
                    border.color: modalRoot.connected ? theme.accentRed : theme.accentCyan
                    border.width: 1

                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        MaterialIcon {
                            name: modalRoot.connected ? "bluetooth_disabled" : "bluetooth_connected"
                            size: 16
                            iconColor: modalRoot.connected ? theme.accentRed : theme.accentCyan
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: modalRoot.connected ? "Disconnetti" : "Connetti"
                            color: modalRoot.connected ? theme.accentRed : theme.accentCyan
                            font.pixelSize: 13
                            font.bold: true
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            modalRoot.closeModal();
                            if (modalRoot.connected) {
                                backend.disconnectBluetoothDevice(modalRoot.mac);
                            } else {
                                backend.connectBluetoothDevice(modalRoot.mac);
                            }
                        }
                    }
                }

                // Forget / Unpair Device Button
                Rectangle {
                    visible: modalRoot.paired
                    Layout.fillWidth: true
                    implicitHeight: 44
                    radius: theme.radiusMedium
                    color: forgetBtArea.pressed ? theme.surfaceBorder : theme.surfaceElevated
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
                            text: "Dimentica dispositivo"
                            color: theme.accentYellow
                            font.pixelSize: 13
                            font.bold: true
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: forgetBtArea
                        anchors.fill: parent
                        onClicked: {
                            modalRoot.closeModal();
                            backend.forgetBluetoothDevice(modalRoot.mac);
                        }
                    }
                }
            }
        }
    }
}
