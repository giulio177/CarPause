import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Rectangle {
    id: wifiModalRoot
    anchors.fill: parent
    color: Qt.rgba(0, 0, 0, 0.85)
    visible: false
    z: 999

    property string selectedSsid: ""

    signal closed()

    function openForSsid(ssid) {
        selectedSsid = ssid;
        wifiPasswordInput.text = "";
        wifiModalRoot.visible = true;
    }

    function close() {
        wifiModalRoot.visible = false;
        wifiModalRoot.closed();
    }

    // Auto-close timer triggered on successful connection
    Timer {
        id: modalAutoCloseTimer
        interval: 1200
        repeat: false
        onTriggered: {
            wifiModalRoot.close();
        }
    }

    // Listener for real connection success from NetworkManager
    Connections {
        target: typeof backend !== "undefined" ? backend : null
        function onWifiConnectedSuccessfully(ssid) {
            modalAutoCloseTimer.start();
        }
    }

    // Block taps underneath
    MouseArea {
        anchors.fill: parent
    }

    // Top Dialog Box
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 20
        width: 640
        height: 270
        radius: theme.radiusLarge
        color: theme.surfaceDark
        border.color: theme.accentCyan
        border.width: 1.5

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                MaterialIcon {
                    name: "lock"
                    size: 20
                    iconColor: theme.accentCyan
                }

                Text {
                    text: "Connessione Wi-Fi Protetta"
                    color: theme.textPrimary
                    font.pixelSize: 18
                    font.bold: true
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    width: 32
                    height: 32
                    radius: 16
                    color: "transparent"

                    MaterialIcon {
                        anchors.centerIn: parent
                        name: "close"
                        size: 20
                        iconColor: closeArea.pressed ? theme.textPrimary : theme.textMuted
                    }

                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        onClicked: wifiModalRoot.close()
                    }
                }
            }

            Row {
                spacing: 8
                Text { text: "Rete selezionata:"; color: theme.textMuted; font.pixelSize: 14 }
                Text { text: wifiModalRoot.selectedSsid; color: theme.accentCyan; font.pixelSize: 15; font.bold: true }
            }

            TextField {
                id: wifiPasswordInput
                Layout.fillWidth: true
                implicitHeight: 46
                placeholderText: "Tocca qui e digita la password sulla tastiera sottostante..."
                echoMode: showPasswordToggle.checked ? TextInput.Normal : TextInput.Password
                color: theme.textPrimary
                font.pixelSize: 15
                background: Rectangle {
                    radius: 8
                    color: theme.surfaceElevated
                    border.color: wifiPasswordInput.activeFocus ? theme.accentCyan : theme.surfaceBorder
                    border.width: wifiPasswordInput.activeFocus ? 1.5 : 1
                }
            }

            RowLayout {
                Layout.fillWidth: true
                CheckBox {
                    id: showPasswordToggle
                    text: "Mostra password"
                }
                Item { Layout.fillWidth: true }
                Text {
                    visible: backend.wifiStatusMessage !== ""
                    text: backend.wifiStatusMessage
                    color: backend.wifiConnected ? theme.accentGreen : (backend.wifiConnecting ? theme.accentCyan : theme.accentYellow)
                    font.pixelSize: 12
                    font.bold: true
                }
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                Layout.fillWidth: true
                spacing: 14

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 44
                    radius: theme.radiusMedium
                    color: cancelBtnArea.pressed ? theme.surfaceBorder : theme.surfaceElevated
                    border.color: theme.surfaceBorder
                    opacity: backend.wifiConnecting ? 0.5 : 1.0

                    Text {
                        anchors.centerIn: parent
                        text: "Annulla"
                        color: theme.textPrimary
                        font.pixelSize: 13
                        font.bold: true
                    }

                    MouseArea {
                        id: cancelBtnArea
                        anchors.fill: parent
                        enabled: !backend.wifiConnecting
                        onClicked: wifiModalRoot.close()
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 44
                    radius: theme.radiusMedium
                    color: connectBtnArea.pressed ? theme.surfaceBorder : "#172A3C"
                    border.color: theme.accentCyan
                    border.width: 1
                    opacity: backend.wifiConnecting ? 0.5 : 1.0

                    Row {
                        anchors.centerIn: parent
                        spacing: 6

                        MaterialIcon {
                            name: backend.wifiConnecting ? "sync" : "lock_open"
                            size: 16
                            iconColor: theme.accentCyan
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: backend.wifiConnecting ? "Connessione in corso..." : "Connetti e Salva"
                            color: theme.accentCyan
                            font.pixelSize: 13
                            font.bold: true
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: connectBtnArea
                        anchors.fill: parent
                        enabled: !backend.wifiConnecting
                        onClicked: {
                            backend.connectWifi(wifiModalRoot.selectedSsid, wifiPasswordInput.text)
                        }
                    }
                }
            }
        }
    }

    // Integrated On-Screen Touch Virtual Keyboard for 1024x600 Automotive Display
    VirtualKeyboard {
        id: onScreenKeyboard
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 270
        targetInput: wifiPasswordInput

        onEnterPressed: {
            if (!backend.wifiConnecting) {
                backend.connectWifi(wifiModalRoot.selectedSsid, wifiPasswordInput.text);
            }
        }
    }
}
