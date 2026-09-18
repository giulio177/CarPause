import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../components"
import "../../popups"

Rectangle {
    id: wifiSettingsRoot
    Layout.fillWidth: true
    Layout.fillHeight: true
    radius: theme.radiusLarge
    color: theme.surfaceDark
    border.color: theme.surfaceBorder

    signal requestWifiConnect(string ssid)

    // Reactive partitions: Known/Saved/Active vs Other nearby networks
    property var allNetworks: []
    property var myNetworks: []
    property var otherNetworks: []

    function updateNetworkLists() {
        var list = backend.availableWifiNetworks || [];
        var myNets = [];
        var othNets = [];
        for (var i = 0; i < list.length; i++) {
            var item = list[i];
            if (!item) continue;
            if (item.saved || item.inUse || item.active) {
                myNets.push(item);
            } else {
                othNets.push(item);
            }
        }
        allNetworks = list;
        myNetworks = myNets;
        otherNetworks = othNets;
    }

    Component.onCompleted: updateNetworkLists()

    Connections {
        target: backend
        function onWifiNetworksChanged() {
            wifiSettingsRoot.updateNetworkLists();
        }
        function onWifiChanged() {
            wifiSettingsRoot.updateNetworkLists();
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 12

        // ====================================================================
        // TOP HEADER: TITLE & APPLE-STYLE POWER SWITCH
        // ====================================================================
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            spacing: 12

            Row {
                spacing: 10
                MaterialIcon {
                    name: "wifi"
                    size: 24
                    iconColor: backend.wifiPowered ? theme.accentCyan : theme.textMuted
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: "Wi-Fi"
                    color: theme.textPrimary
                    font.pixelSize: 18
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Item { Layout.fillWidth: true } // Spacer

            Text {
                text: backend.wifiPowered ? "Attivo" : "Disattivato"
                color: theme.textSecondary
                font.pixelSize: 13
                Layout.alignment: Qt.AlignVCenter
            }

            AppleSwitch {
                checked: backend.wifiPowered
                onToggled: function(val) {
                    backend.setWifiPowered(val);
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: theme.surfaceBorder
        }

        // ====================================================================
        // WI-FI OFF STATE
        // ====================================================================
        Item {
            visible: !backend.wifiPowered
            Layout.fillWidth: true
            Layout.fillHeight: true

            Column {
                anchors.centerIn: parent
                spacing: 12

                MaterialIcon {
                    name: "wifi_off"
                    size: 48
                    iconColor: theme.textMuted
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: "Il Wi-Fi è disattivato"
                    color: theme.textSecondary
                    font.pixelSize: 16
                    font.bold: true
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: "Attiva lo switch in alto per connetterti alle reti disponibili."
                    color: theme.textMuted
                    font.pixelSize: 13
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }

        // ====================================================================
        // WI-FI ON: FULL-WIDTH SCROLLABLE LIST
        // ====================================================================
        Flickable {
            id: wifiFlickable
            visible: backend.wifiPowered
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: wifiListColumn.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: wifiListColumn
                width: wifiFlickable.width
                spacing: 14

                // ------------------------------------------------------------
                // 1. SECTION: "MIE RETI" (Known / Saved / Active Networks)
                // ------------------------------------------------------------
                Column {
                    width: parent.width
                    spacing: 8
                    visible: wifiSettingsRoot.myNetworks.length > 0

                    Text {
                        text: "MIE RETI"
                        color: theme.textMuted
                        font.pixelSize: 11
                        font.bold: true
                        leftPadding: 4
                    }

                    Column {
                        width: parent.width
                        spacing: 8

                        Repeater {
                            model: wifiSettingsRoot.myNetworks

                            delegate: Rectangle {
                                width: wifiListColumn.width
                                height: 52
                                radius: theme.radiusMedium
                                color: isConnected ? "#102820" : (rowArea.pressed ? theme.surfaceBorder : theme.surfaceElevated)
                                border.color: isConnected ? theme.accentGreen : theme.surfaceBorder
                                border.width: isConnected ? 1.5 : 1

                                readonly property bool isConnected: Boolean(modelData && (modelData.inUse || modelData.active))
                                readonly property int sigLevel: modelData && modelData.signal ? modelData.signal : 0
                                readonly property string wifiIconName: {
                                    if (sigLevel < 35) return "wifi_1_bar";
                                    if (sigLevel < 70) return "wifi_2_bar";
                                    return "wifi";
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 16
                                    anchors.rightMargin: 12
                                    spacing: 12

                                    // Signal icon (Cyan if connected, White otherwise)
                                    MaterialIcon {
                                        name: wifiIconName
                                        size: 22
                                        iconColor: isConnected ? theme.accentCyan : "#FFFFFF"
                                    }

                                    // SSID text (Full width)
                                    Text {
                                        text: modelData && modelData.ssid ? modelData.ssid : "Rete"
                                        color: isConnected ? theme.accentGreen : theme.textPrimary
                                        font.pixelSize: 14
                                        font.bold: isConnected
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    // Lock icon if protected
                                    MaterialIcon {
                                        visible: Boolean(modelData && modelData.security && modelData.security !== "--")
                                        name: "lock"
                                        size: 16
                                        iconColor: theme.textMuted
                                    }

                                    // Connected Checkmark
                                    MaterialIcon {
                                        visible: isConnected
                                        name: "check"
                                        size: 18
                                        iconColor: theme.accentGreen
                                    }

                                    // Blue Info Button
                                    Rectangle {
                                        width: 38
                                        height: 38
                                        radius: 19
                                        color: infoBtnArea.pressed ? theme.surfaceDark : "transparent"

                                        MaterialIcon {
                                            anchors.centerIn: parent
                                            name: "info"
                                            size: 22
                                            iconColor: theme.accentCyan
                                        }

                                        MouseArea {
                                            id: infoBtnArea
                                            anchors.fill: parent
                                            onClicked: {
                                                networkDetailsModal.openForNetwork(modelData);
                                            }
                                        }
                                    }
                                }

                                // Entire row tap to connect
                                MouseArea {
                                    id: rowArea
                                    anchors.fill: parent
                                    anchors.rightMargin: 46 // Don't block info button
                                    onClicked: {
                                        if (isConnected) return;
                                        if (modelData.saved) {
                                            backend.connectSavedWifi(modelData.ssid);
                                        } else {
                                            wifiSettingsRoot.requestWifiConnect(modelData.ssid);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ------------------------------------------------------------
                // 2. SECTION: "ALTRE RETI" (Nearby Scanned Networks)
                // ------------------------------------------------------------
                Column {
                    width: parent.width
                    spacing: 8

                    RowLayout {
                        width: parent.width
                        Text {
                            text: "ALTRE RETI"
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
                            color: backend.wifiScanning ? theme.surfaceElevated : (otherWifiScanArea.pressed ? theme.surfaceBorder : "transparent")

                            Row {
                                anchors.centerIn: parent
                                spacing: 4
                                MaterialIcon {
                                    name: backend.wifiScanning ? "sync" : "search"
                                    size: 14
                                    iconColor: theme.accentCyan
                                    anchors.verticalCenter: parent.verticalCenter
                                    RotationAnimation on rotation {
                                        running: backend.wifiScanning
                                        loops: Animation.Infinite
                                        from: 0
                                        to: 360
                                        duration: 1000
                                    }
                                }
                                Text {
                                    text: backend.wifiScanning ? "Scansione..." : "Cerca altre"
                                    color: theme.accentCyan
                                    font.pixelSize: 11
                                    font.bold: true
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: otherWifiScanArea
                                anchors.fill: parent
                                enabled: !backend.wifiScanning
                                onClicked: backend.rescanWifi()
                            }
                        }
                    }

                    // Placeholder if no other networks currently in cache
                    Rectangle {
                        visible: wifiSettingsRoot.otherNetworks.length === 0
                        width: wifiListColumn.width
                        height: 52
                        radius: theme.radiusMedium
                        color: theme.surfaceElevated
                        border.color: theme.surfaceBorder

                        Text {
                            anchors.centerIn: parent
                            text: backend.wifiScanning ? "Ricerca reti in corso..." : "Nessun'altra rete nelle vicinanze"
                            color: theme.textMuted
                            font.pixelSize: 13
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: 8
                        visible: wifiSettingsRoot.otherNetworks.length > 0

                        Repeater {
                            model: wifiSettingsRoot.otherNetworks

                            delegate: Rectangle {
                                width: wifiListColumn.width
                                height: 52
                                radius: theme.radiusMedium
                                color: otherRowArea.pressed ? theme.surfaceBorder : theme.surfaceElevated
                                border.color: theme.surfaceBorder
                                border.width: 1

                                readonly property int sigLevel: modelData && modelData.signal ? modelData.signal : 0
                                readonly property string wifiIconName: {
                                    if (sigLevel < 35) return "wifi_1_bar";
                                    if (sigLevel < 70) return "wifi_2_bar";
                                    return "wifi";
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 16
                                    anchors.rightMargin: 12
                                    spacing: 12

                                    // Signal icon (White for other networks)
                                    MaterialIcon {
                                        name: wifiIconName
                                        size: 22
                                        iconColor: "#FFFFFF"
                                    }

                                    // SSID text (Full width)
                                    Text {
                                        text: modelData && modelData.ssid ? modelData.ssid : "Rete"
                                        color: theme.textPrimary
                                        font.pixelSize: 14
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    // Lock icon if protected
                                    MaterialIcon {
                                        visible: Boolean(modelData && modelData.security && modelData.security !== "--")
                                        name: "lock"
                                        size: 16
                                        iconColor: theme.textMuted
                                    }

                                    // Blue Info Button
                                    Rectangle {
                                        width: 38
                                        height: 38
                                        radius: 19
                                        color: otherInfoBtnArea.pressed ? theme.surfaceDark : "transparent"

                                        MaterialIcon {
                                            anchors.centerIn: parent
                                            name: "info"
                                            size: 22
                                            iconColor: theme.accentCyan
                                        }

                                        MouseArea {
                                            id: otherInfoBtnArea
                                            anchors.fill: parent
                                            onClicked: {
                                                networkDetailsModal.openForNetwork(modelData);
                                            }
                                        }
                                    }
                                }

                                // Entire row tap to connect
                                MouseArea {
                                    id: otherRowArea
                                    anchors.fill: parent
                                    anchors.rightMargin: 46 // Don't block info button
                                    onClicked: {
                                        if (modelData && modelData.ssid) {
                                            wifiSettingsRoot.requestWifiConnect(modelData.ssid);
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
    // APPLE-STYLE NETWORK DETAILS MODAL
    // ========================================================================
    NetworkDetailsModal {
        id: networkDetailsModal
        onRequestPassword: function(ssid) {
            wifiSettingsRoot.requestWifiConnect(ssid);
        }
    }
}
