import QtQuick
import QtQuick.Layouts
import "../components"

Rectangle {
    id: topBarRoot
    Layout.fillWidth: true
    Layout.preferredHeight: 44
    color: "transparent" // Seamlessly blends into rootWindow background
    border.width: 0     // No visual divider line cutting across the screen

    signal requestOpenSettings(string subTab)

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        spacing: 14

        // Real Clock & Date
        Row {
            spacing: 8
            Layout.alignment: Qt.AlignVCenter

            Text {
                text: backend.currentTime || "--:--"
                color: theme.textPrimary
                font.pixelSize: 20
                font.bold: true
            }

            Text {
                text: "• " + (backend.currentDate || "")
                color: theme.textSecondary
                font.pixelSize: 13
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Item { Layout.fillWidth: true } // Spacer

        // Real Weather Status (Dynamic icon based on real WMO code, temperature only)
        Row {
            spacing: 6
            Layout.alignment: Qt.AlignVCenter

            MaterialIcon {
                name: backend.weatherAvailable ? backend.weatherIcon : "cloud_off"
                size: 19
                iconColor: backend.weatherAvailable ? theme.accentCyan : theme.textMuted
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: backend.weatherAvailable ? backend.weatherTemperatureText : "--°C"
                color: backend.weatherAvailable ? theme.textPrimary : theme.textMuted
                font.pixelSize: 13
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Rectangle { width: 1; height: 16; color: theme.surfaceBorder }

        // Real Hardware Telemetry
        Row {
            spacing: 14
            Layout.alignment: Qt.AlignVCenter

            // CPU Temperature
            Row {
                spacing: 4
                MaterialIcon {
                    name: "bolt"
                    size: 14
                    iconColor: theme.accentCyan
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: backend.cpuTemperatureText
                    color: theme.textSecondary
                    font.pixelSize: 12
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // Car Battery Voltage (OBD)
            Row {
                spacing: 4
                MaterialIcon {
                    name: "battery_charging_full"
                    size: 15
                    iconColor: backend.obdConnected ? theme.accentGreen : theme.textMuted
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: backend.batteryVoltageText
                    color: backend.obdConnected ? theme.textSecondary : theme.textMuted
                    font.pixelSize: 12
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // Real Wi-Fi Status (Tappable -> Opens Wi-Fi Settings)
            Rectangle {
                id: wifiTopBarBtn
                height: 30
                width: wifiRow.width + 12
                radius: 8
                color: wifiMouseArea.pressed ? theme.surfaceElevated : "transparent"
                Layout.alignment: Qt.AlignVCenter

                Behavior on color { ColorAnimation { duration: 120 } }

                Row {
                    id: wifiRow
                    anchors.centerIn: parent
                    spacing: 4

                    MaterialIcon {
                        name: backend.wifiConnected ? "wifi" : "wifi_off"
                        size: 15
                        iconColor: backend.wifiConnected ? theme.accentCyan : theme.accentRed
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: backend.wifiConnected ? backend.wifiSsid : "Wi-Fi Off"
                        color: backend.wifiConnected ? theme.textSecondary : theme.accentRed
                        font.pixelSize: 12
                        font.bold: true
                        elide: Text.ElideRight
                        width: Math.min(130, implicitWidth)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: wifiMouseArea
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: topBarRoot.requestOpenSettings("wifi")
                }
            }

            // Real Bluetooth Status (Tappable -> Opens Bluetooth Settings)
            Rectangle {
                id: btTopBarBtn
                height: 30
                width: btRow.width + 12
                radius: 8
                color: btMouseArea.pressed ? theme.surfaceElevated : "transparent"
                Layout.alignment: Qt.AlignVCenter

                Behavior on color { ColorAnimation { duration: 120 } }

                Row {
                    id: btRow
                    anchors.centerIn: parent
                    spacing: 4

                    MaterialIcon {
                        name: backend.bluetoothConnected ? "bluetooth_connected" : (backend.bluetoothPowered ? "bluetooth" : "bluetooth_disabled")
                        size: 16
                        iconColor: backend.bluetoothConnected
                                   ? theme.accentCyan
                                   : (backend.bluetoothPowered ? theme.textMuted : theme.accentRed)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: backend.bluetoothConnected ? backend.bluetoothDeviceName : (backend.bluetoothPowered ? "BT Standby" : "BT Off")
                        color: backend.bluetoothConnected ? theme.textSecondary : theme.textMuted
                        font.pixelSize: 12
                        font.bold: true
                        elide: Text.ElideRight
                        width: Math.min(110, implicitWidth)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: btMouseArea
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: topBarRoot.requestOpenSettings("bt")
                }
            }
        }
    }
}
