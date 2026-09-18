import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"
import "settings"

Item {
    id: settingsRoot

    property string currentSubTab: "general"
    signal requestWifiConnect(string ssid)

    RowLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 16

        // ====================================================================
        // LEFT SUB-NAVIGATION SIDEBAR FOR SETTINGS
        // ====================================================================
        Rectangle {
            Layout.preferredWidth: 170
            Layout.fillHeight: true
            radius: theme.radiusLarge
            color: theme.surfaceDark
            border.color: theme.surfaceBorder

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10

                Text {
                    text: "SETTINGS"
                    color: theme.textMuted
                    font.pixelSize: 11
                    font.bold: true
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 4
                    Layout.bottomMargin: 4
                }

                component SettingsNavBtn: Rectangle {
                    property string tabId: ""
                    property string iconName: ""
                    property string label: ""
                    readonly property bool isSelected: settingsRoot.currentSubTab === tabId

                    Layout.fillWidth: true
                    Layout.preferredHeight: 56
                    radius: theme.radiusMedium
                    color: isSelected ? theme.surfaceElevated : (subTabTap.pressed ? Qt.rgba(255, 255, 255, 0.06) : "transparent")
                    border.color: isSelected ? theme.accentCyan : "transparent"
                    border.width: 1.5

                    Behavior on color { ColorAnimation { duration: 120 } }

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10
                        scale: subTabTap.pressed ? 0.95 : 1.0
                        Behavior on scale { NumberAnimation { duration: 80 } }

                        MaterialIcon {
                            name: iconName
                            size: 22
                            iconColor: isSelected ? theme.accentCyan : theme.textSecondary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: label
                            color: isSelected ? theme.textPrimary : theme.textMuted
                            font.pixelSize: 13
                            font.bold: isSelected
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    TapHandler {
                        id: subTabTap
                        margin: 6
                        onTapped: settingsRoot.currentSubTab = tabId
                    }
                }

                SettingsNavBtn {
                    tabId: "general"
                    iconName: "info"
                    label: "Generale"
                }

                SettingsNavBtn {
                    tabId: "wifi"
                    iconName: "wifi"
                    label: "Wi-Fi"
                }

                SettingsNavBtn {
                    tabId: "bt"
                    iconName: "bluetooth"
                    label: "Bluetooth"
                }

                SettingsNavBtn {
                    tabId: "logs"
                    iconName: "description"
                    label: "Log App"
                }

                SettingsNavBtn {
                    tabId: "terminal"
                    iconName: "terminal"
                    label: "Terminale"
                }

                Item { Layout.fillHeight: true } // Spacer
            }
        }

        // ====================================================================
        // RIGHT SUB-PAGE CONTAINER (StackLayout)
        // ====================================================================
        StackLayout {
            id: settingsStack
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: {
                if (settingsRoot.currentSubTab === "wifi") return 1;
                if (settingsRoot.currentSubTab === "bt") return 2;
                if (settingsRoot.currentSubTab === "logs") return 3;
                if (settingsRoot.currentSubTab === "terminal") return 4;
                return 0; // "general"
            }

            GeneralSettingsView {
                id: generalView
            }

            WifiSettingsView {
                id: wifiView
                onRequestWifiConnect: (ssid) => {
                    settingsRoot.requestWifiConnect(ssid);
                }
            }

            BluetoothSettingsView {
                id: btView
            }

            LogsSettingsView {
                id: logsView
            }

            TerminalSettingsView {
                id: terminalView
            }
        }
    }
}
