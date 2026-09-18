import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../components"
import "../../popups"

Rectangle {
    id: btSettingsRoot
    Layout.fillWidth: true
    Layout.fillHeight: true
    radius: theme.radiusLarge
    color: theme.surfaceDark
    border.color: theme.surfaceBorder

    // Reactive partitions: Paired/Connected vs Other nearby devices
    readonly property var allDevices: backend.availableBluetoothDevices || []
    readonly property var myDevices: allDevices.filter(function(d) {
        return d && (d.connected || d.paired);
    })
    readonly property var otherDevices: allDevices.filter(function(d) {
        return d && !d.connected && !d.paired;
    })

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 12

        // ====================================================================
        // TOP HEADER: TITLE, RENDI VISIBILE BUTTON & APPLE-STYLE POWER SWITCH
        // ====================================================================
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            spacing: 12

            Row {
                spacing: 10
                MaterialIcon {
                    name: "bluetooth"
                    size: 24
                    iconColor: backend.bluetoothPowered ? theme.accentCyan : theme.textMuted
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: "Bluetooth"
                    color: theme.textPrimary
                    font.pixelSize: 18
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Item { Layout.fillWidth: true } // Spacer

            // Discoverable / Pairing mode button (Minimal, modern squircle capsule)
            Rectangle {
                id: discBtn
                visible: backend.bluetoothPowered
                implicitWidth: discRow.implicitWidth + 24
                implicitHeight: 32
                radius: height / 2

                color: backend.bluetoothDiscoverable 
                    ? Qt.rgba(0.0, 0.9, 0.46, 0.12) 
                    : (discTap.pressed ? "#252F43" : theme.surfaceElevated)
                border.color: theme.surfaceBorder
                border.width: 1

                Behavior on color { ColorAnimation { duration: 180 } }

                Row {
                    id: discRow
                    anchors.centerIn: parent
                    spacing: 7
                    scale: discTap.pressed ? 0.95 : 1.0
                    Behavior on scale { NumberAnimation { duration: 80 } }

                    // Subtle abstract status dot
                    Rectangle {
                        width: 7
                        height: 7
                        radius: 3.5
                        color: backend.bluetoothDiscoverable ? theme.accentGreen : theme.textMuted
                        anchors.verticalCenter: parent.verticalCenter

                        SequentialAnimation on opacity {
                            running: backend.bluetoothDiscoverable
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.35; duration: 800; easing.type: Easing.InOutQuad }
                            NumberAnimation { to: 1.0; duration: 800; easing.type: Easing.InOutQuad }
                        }
                    }

                    MaterialIcon {
                        name: "sensors"
                        size: 14
                        iconColor: backend.bluetoothDiscoverable ? theme.accentGreen : theme.textSecondary
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: backend.bluetoothDiscoverable ? "Visibile" : "Rendi visibile"
                        color: backend.bluetoothDiscoverable ? theme.textPrimary : theme.textSecondary
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                TapHandler {
                    id: discTap
                    margin: 8
                    onTapped: backend.toggleBluetoothDiscoverable()
                }
            }

            Text {
                text: backend.bluetoothPowered ? "Attivo" : "Disattivato"
                color: theme.textSecondary
                font.pixelSize: 13
                Layout.alignment: Qt.AlignVCenter
            }

            AppleSwitch {
                checked: backend.bluetoothPowered
                onToggled: function(val) {
                    backend.setBluetoothPowered(val);
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: theme.surfaceBorder
        }

        // ====================================================================
        // BLUETOOTH OFF STATE
        // ====================================================================
        Item {
            visible: !backend.bluetoothPowered
            Layout.fillWidth: true
            Layout.fillHeight: true

            Column {
                anchors.centerIn: parent
                spacing: 12

                MaterialIcon {
                    name: "bluetooth_disabled"
                    size: 48
                    iconColor: theme.textMuted
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: "Il Bluetooth è disattivato"
                    color: theme.textSecondary
                    font.pixelSize: 16
                    font.bold: true
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: "Attiva lo switch in alto per connettere smartphone e cuffie."
                    color: theme.textMuted
                    font.pixelSize: 13
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }

        // ====================================================================
        // BLUETOOTH ON: FULL-WIDTH SCROLLABLE LIST
        // ====================================================================
        Flickable {
            id: btFlickable
            visible: backend.bluetoothPowered
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: btListColumn.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            pressDelay: 120

            Column {
                id: btListColumn
                width: btFlickable.width
                spacing: 14

                // ------------------------------------------------------------
                // 1. SECTION: "MIEI DISPOSITIVI" (Paired / Connected Devices)
                // ------------------------------------------------------------
                Column {
                    width: parent.width
                    spacing: 8
                    visible: btSettingsRoot.myDevices.length > 0

                    Text {
                        text: "MIEI DISPOSITIVI"
                        color: theme.textMuted
                        font.pixelSize: 11
                        font.bold: true
                        leftPadding: 4
                    }

                    Column {
                        width: parent.width
                        spacing: 8

                        Repeater {
                            model: btSettingsRoot.myDevices

                            delegate: Rectangle {
                                width: btListColumn.width
                                height: 54
                                radius: theme.radiusMedium
                                color: isConnected ? "#102820" : (rowDevArea.pressed ? theme.surfaceBorder : theme.surfaceElevated)
                                border.color: isConnected ? theme.accentGreen : theme.surfaceBorder
                                border.width: isConnected ? 1.5 : 1

                                readonly property bool isConnected: Boolean(modelData && modelData.connected)
                                readonly property string devIconName: {
                                    if (!modelData || !modelData.name) return "bluetooth";
                                    var n = modelData.name.toLowerCase();
                                    if (n.indexOf("phone") !== -1 || n.indexOf("iphone") !== -1 || n.indexOf("galaxy") !== -1 || n.indexOf("pixel") !== -1) {
                                        return "smartphone";
                                    }
                                    if (n.indexOf("headset") !== -1 || n.indexOf("headphone") !== -1 || n.indexOf("airpod") !== -1 || n.indexOf("buds") !== -1 || n.indexOf("audio") !== -1) {
                                        return "headphones";
                                    }
                                    return "bluetooth";
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 16
                                    anchors.rightMargin: 12
                                    spacing: 12

                                    // Device Icon (Green/Cyan if connected, White otherwise)
                                    MaterialIcon {
                                        name: devIconName
                                        size: 22
                                        iconColor: isConnected ? theme.accentCyan : "#FFFFFF"
                                    }

                                    // Device Name (Full width)
                                    Text {
                                        text: (modelData && (modelData.name || modelData.mac)) ? (modelData.name || modelData.mac) : "Dispositivo"
                                        color: isConnected ? theme.accentGreen : theme.textPrimary
                                        font.pixelSize: 14
                                        font.bold: isConnected
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    // Status text (Apple-style)
                                    Text {
                                        text: isConnected ? "Connesso" : "Non connesso"
                                        color: isConnected ? theme.accentGreen : theme.textMuted
                                        font.pixelSize: 13
                                        font.bold: isConnected
                                    }

                                    // Blue Info Circle Button
                                    Rectangle {
                                        width: 38
                                        height: 38
                                        radius: 19
                                        color: devInfoArea.pressed ? theme.surfaceDark : "transparent"

                                        MaterialIcon {
                                            anchors.centerIn: parent
                                            name: "info"
                                            size: 22
                                            iconColor: theme.accentCyan
                                        }

                                        MouseArea {
                                            id: devInfoArea
                                            anchors.fill: parent
                                            preventStealing: true
                                            onClicked: {
                                                deviceDetailsModal.openForDevice(modelData);
                                            }
                                        }
                                    }
                                }

                                // Entire row tap to connect or disconnect
                                MouseArea {
                                    id: rowDevArea
                                    anchors.fill: parent
                                    anchors.rightMargin: 46 // Don't block info button
                                    preventStealing: true
                                    onClicked: {
                                        if (!modelData || !modelData.mac) return;
                                        if (isConnected) {
                                            backend.disconnectBluetoothDevice(modelData.mac);
                                        } else {
                                            backend.connectBluetoothDevice(modelData.mac);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ------------------------------------------------------------
                // 2. SECTION: "ALTRI DISPOSITIVI" (Nearby Scanned Devices)
                // ------------------------------------------------------------
                Column {
                    width: parent.width
                    spacing: 8

                    RowLayout {
                        width: parent.width
                        Text {
                            text: "ALTRI DISPOSITIVI"
                            color: theme.textMuted
                            font.pixelSize: 11
                            font.bold: true
                            leftPadding: 4
                        }

                        Item { Layout.fillWidth: true }

                        // Scan button/indicator
                        Rectangle {
                            implicitWidth: 120
                            implicitHeight: 28
                            radius: 6
                            color: backend.bluetoothScanning ? theme.surfaceElevated : (otherScanArea.pressed ? theme.surfaceBorder : "transparent")

                            Row {
                                anchors.centerIn: parent
                                spacing: 4
                                MaterialIcon {
                                    name: backend.bluetoothScanning ? "sync" : "search"
                                    size: 14
                                    iconColor: theme.accentCyan
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: backend.bluetoothScanning ? "Scansione..." : "Cerca altri"
                                    color: theme.accentCyan
                                    font.pixelSize: 11
                                    font.bold: true
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: otherScanArea
                                anchors.fill: parent
                                preventStealing: true
                                enabled: !backend.bluetoothScanning
                                onClicked: backend.scanBluetooth()
                            }
                        }
                    }

                    // Placeholder if no other devices currently in cache
                    Rectangle {
                        visible: btSettingsRoot.otherDevices.length === 0
                        width: btListColumn.width
                        height: 52
                        radius: theme.radiusMedium
                        color: theme.surfaceElevated
                        border.color: theme.surfaceBorder

                        Text {
                            anchors.centerIn: parent
                            text: backend.bluetoothScanning ? "Ricerca dispositivi in corso..." : "Nessun altro dispositivo nelle vicinanze"
                            color: theme.textMuted
                            font.pixelSize: 13
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: 8
                        visible: btSettingsRoot.otherDevices.length > 0

                        Repeater {
                            model: btSettingsRoot.otherDevices

                            delegate: Rectangle {
                                width: btListColumn.width
                                height: 54
                                radius: theme.radiusMedium
                                color: otherDevRowArea.pressed ? theme.surfaceBorder : theme.surfaceElevated
                                border.color: theme.surfaceBorder
                                border.width: 1

                                readonly property string devIconName: {
                                    if (!modelData || !modelData.name) return "bluetooth";
                                    var n = modelData.name.toLowerCase();
                                    if (n.indexOf("phone") !== -1 || n.indexOf("iphone") !== -1 || n.indexOf("galaxy") !== -1 || n.indexOf("pixel") !== -1) {
                                        return "smartphone";
                                    }
                                    if (n.indexOf("headset") !== -1 || n.indexOf("headphone") !== -1 || n.indexOf("airpod") !== -1 || n.indexOf("buds") !== -1 || n.indexOf("audio") !== -1) {
                                        return "headphones";
                                    }
                                    return "bluetooth";
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 16
                                    anchors.rightMargin: 12
                                    spacing: 12

                                    // Device Icon (White for other devices)
                                    MaterialIcon {
                                        name: devIconName
                                        size: 22
                                        iconColor: "#FFFFFF"
                                    }

                                    // Device Name (Full width)
                                    Text {
                                        text: (modelData && (modelData.name || modelData.mac)) ? (modelData.name || modelData.mac) : "Dispositivo"
                                        color: theme.textPrimary
                                        font.pixelSize: 14
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    // Blue Info Button
                                    Rectangle {
                                        width: 38
                                        height: 38
                                        radius: 19
                                        color: otherDevInfoArea.pressed ? theme.surfaceDark : "transparent"

                                        MaterialIcon {
                                            anchors.centerIn: parent
                                            name: "info"
                                            size: 22
                                            iconColor: theme.accentCyan
                                        }

                                        MouseArea {
                                            id: otherDevInfoArea
                                            anchors.fill: parent
                                            preventStealing: true
                                            onClicked: {
                                                deviceDetailsModal.openForDevice(modelData);
                                            }
                                        }
                                    }
                                }

                                // Entire row tap to connect/pair
                                MouseArea {
                                    id: otherDevRowArea
                                    anchors.fill: parent
                                    anchors.rightMargin: 46 // Don't block info button
                                    preventStealing: true
                                    onClicked: {
                                        if (modelData && modelData.mac) {
                                            backend.connectBluetoothDevice(modelData.mac);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ========================================================================
    // APPLE-STYLE BLUETOOTH DEVICE DETAILS MODAL
    // ========================================================================
    DeviceDetailsModal {
        id: deviceDetailsModal
    }
}
