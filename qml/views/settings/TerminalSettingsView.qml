import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../components"

Rectangle {
    id: terminalViewRoot
    Layout.fillWidth: true
    Layout.fillHeight: true
    radius: theme.radiusLarge
    color: theme.surfaceDark
    border.color: theme.surfaceBorder
    clip: true

    property bool autoScroll: true
    readonly property var allTerminalLines: backend.terminalLogs || []
    property real savedContentY: 0

    onAllTerminalLinesChanged: {
        if (!autoScroll) {
            savedContentY = terminalListView.contentY;
            Qt.callLater(function() {
                terminalListView.contentY = Math.min(savedContentY, Math.max(0, terminalListView.contentHeight - terminalListView.height));
            });
        }
    }

    Component.onCompleted: {
        Qt.callLater(function() {
            if (terminalListView.count > 0) {
                terminalListView.positionViewAtEnd();
            }
        });
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        // ====================================================================
        // 1. TOP HEADER: TITLE, BADGE, COUNTER & ACTIONS
        // ====================================================================
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            // Section Title
            Row {
                spacing: 8
                Layout.alignment: Qt.AlignVCenter

                MaterialIcon {
                    name: "terminal"
                    size: 20
                    iconColor: theme.accentCyan
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: "TERMINALE DI SISTEMA"
                    color: theme.textPrimary
                    font.pixelSize: 14
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // Badge File Name
            Rectangle {
                implicitWidth: Math.min(terminalFileRow.implicitWidth + 14, 200)
                implicitHeight: 24
                radius: 12
                color: theme.surfaceElevated
                border.color: Qt.rgba(0.0, 0.898, 1.0, 0.25)
                Layout.alignment: Qt.AlignVCenter

                Row {
                    id: terminalFileRow
                    anchors.centerIn: parent
                    spacing: 4

                    MaterialIcon {
                        name: "description"
                        size: 13
                        iconColor: theme.accentCyan
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: backend.currentTerminalLogFilename || "terminal.log"
                        color: theme.accentCyan
                        font.pixelSize: 10
                        font.bold: true
                        elide: Text.ElideMiddle
                        width: Math.min(implicitWidth, 170)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            // Line count badge
            Rectangle {
                implicitWidth: countText.contentWidth + 14
                implicitHeight: 22
                radius: 11
                color: theme.surfaceElevated
                border.color: theme.surfaceBorder
                Layout.alignment: Qt.AlignVCenter

                Text {
                    id: countText
                    anchors.centerIn: parent
                    text: terminalViewRoot.allTerminalLines.length + " righe"
                    color: theme.textSecondary
                    font.pixelSize: 10
                    font.bold: true
                }
            }

            Item { Layout.fillWidth: true } // Spacer

            // Reload Button
            Rectangle {
                implicitWidth: reloadRow.implicitWidth + 14
                implicitHeight: 28
                radius: 14
                color: reloadMouse.pressed ? theme.surfaceBorder : theme.surfaceElevated
                border.color: reloadMouse.containsMouse ? theme.accentCyan : theme.surfaceBorder
                Layout.alignment: Qt.AlignVCenter

                Row {
                    id: reloadRow
                    anchors.centerIn: parent
                    spacing: 4

                    MaterialIcon {
                        name: "refresh"
                        size: 14
                        iconColor: reloadMouse.containsMouse ? theme.accentCyan : theme.textSecondary
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "Ricarica"
                        color: reloadMouse.containsMouse ? theme.accentCyan : theme.textSecondary
                        font.pixelSize: 11
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: reloadMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: backend.refreshTerminalLogs()
                }
            }

            // Auto-scroll Button
            Rectangle {
                implicitWidth: scrollRow.implicitWidth + 14
                implicitHeight: 28
                radius: 14
                color: terminalViewRoot.autoScroll ? Qt.rgba(0.0, 0.898, 1.0, 0.14) : theme.surfaceElevated
                border.color: terminalViewRoot.autoScroll ? theme.accentCyan : theme.surfaceBorder
                Layout.alignment: Qt.AlignVCenter

                Row {
                    id: scrollRow
                    anchors.centerIn: parent
                    spacing: 4

                    MaterialIcon {
                        name: "arrow_downward"
                        size: 14
                        iconColor: terminalViewRoot.autoScroll ? theme.accentCyan : theme.textMuted
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "In Fondo"
                        color: terminalViewRoot.autoScroll ? theme.accentCyan : theme.textMuted
                        font.pixelSize: 11
                        font.bold: terminalViewRoot.autoScroll
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        terminalViewRoot.autoScroll = !terminalViewRoot.autoScroll;
                        if (terminalViewRoot.autoScroll && terminalListView.count > 0) {
                            terminalListView.positionViewAtEnd();
                        }
                    }
                }
            }

            // Clear Log Button
            Rectangle {
                implicitWidth: clearRow.implicitWidth + 14
                implicitHeight: 28
                radius: 14
                color: clearMouse.pressed ? Qt.rgba(1.0, 0.2, 0.4, 0.25) : theme.surfaceElevated
                border.color: clearMouse.containsMouse ? theme.accentRed : theme.surfaceBorder
                Layout.alignment: Qt.AlignVCenter

                Row {
                    id: clearRow
                    anchors.centerIn: parent
                    spacing: 4

                    MaterialIcon {
                        name: "delete_outline"
                        size: 14
                        iconColor: clearMouse.containsMouse ? theme.accentRed : theme.textMuted
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "Svuota"
                        color: clearMouse.containsMouse ? theme.accentRed : theme.textMuted
                        font.pixelSize: 11
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: clearMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: backend.clearTerminalLogs()
                }
            }
        }

        // ====================================================================
        // 2. CONSOLE DISPLAY CONTAINER
        // ====================================================================
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: theme.radiusMedium
            color: "#080B10" // Dark high-contrast console background
            border.color: Qt.rgba(0.0, 0.898, 1.0, 0.18)
            border.width: 1
            clip: true

            // Empty State
            Item {
                anchors.centerIn: parent
                visible: terminalViewRoot.allTerminalLines.length === 0
                width: parent.width - 40
                height: 120

                Column {
                    anchors.centerIn: parent
                    spacing: 8

                    MaterialIcon {
                        name: "terminal"
                        size: 38
                        iconColor: theme.textMuted
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    Text {
                        text: "Nessun output registrato nel terminale"
                        color: theme.textMuted
                        font.pixelSize: 13
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    Text {
                        text: "Tutti i messaggi di console, print e comandi di sistema appariranno qui."
                        color: Qt.rgba(1, 1, 1, 0.3)
                        font.pixelSize: 11
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
            }

            // Monospace Terminal Line ListView
            ListView {
                id: terminalListView
                anchors.fill: parent
                anchors.margins: 8
                model: terminalViewRoot.allTerminalLines
                clip: true
                spacing: 2
                boundsBehavior: Flickable.StopAtBounds

                onCountChanged: {
                    if (terminalViewRoot.autoScroll && count > 0) {
                        Qt.callLater(terminalListView.positionViewAtEnd);
                    }
                }

                ScrollBar.vertical: ScrollBar {
                    id: terminalScrollBar
                    policy: ScrollBar.AsNeeded
                    active: terminalListView.moving || terminalScrollBar.pressed
                    contentItem: Rectangle {
                        implicitWidth: 5
                        radius: 3
                        color: terminalScrollBar.pressed ? theme.accentCyan : Qt.rgba(0.0, 0.898, 1.0, 0.4)
                    }
                }

                delegate: Rectangle {
                    width: terminalListView.width
                    height: Math.max(22, lineContentRow.implicitHeight + 4)
                    color: index % 2 === 0 ? "transparent" : "#0D131A"
                    radius: 3

                    readonly property string lineLevel: modelData && modelData.level ? modelData.level : "INFO"
                    readonly property string lineText: modelData && modelData.text !== undefined ? String(modelData.text) : ""
                    readonly property int lineNum: modelData && modelData.line !== undefined ? modelData.line : (index + 1)

                    RowLayout {
                        id: lineContentRow
                        anchors.fill: parent
                        anchors.leftMargin: 6
                        anchors.rightMargin: 6
                        spacing: 8

                        // Line Number Column
                        Text {
                            text: lineNum
                            color: Qt.rgba(1, 1, 1, 0.28)
                            font.pixelSize: 10
                            font.family: "Monospace"
                            Layout.preferredWidth: 36
                            horizontalAlignment: Text.AlignRight
                            Layout.alignment: Qt.AlignTop
                            Layout.topMargin: 2
                        }

                        // Status Color Bar Indicator
                        Rectangle {
                            width: 2.5
                            height: 14
                            radius: 1
                            Layout.alignment: Qt.AlignTop
                            Layout.topMargin: 3
                            color: {
                                if (lineLevel === "ERROR") return theme.accentRed;
                                if (lineLevel === "WARNING") return theme.accentYellow;
                                return Qt.rgba(0.0, 0.898, 1.0, 0.35);
                            }
                        }

                        // Terminal Text (Monospace, selectable color)
                        Text {
                            text: lineText
                            color: {
                                if (lineLevel === "ERROR") return theme.accentRed;
                                if (lineLevel === "WARNING") return theme.accentYellow;
                                return "#D8E2EC";
                            }
                            font.pixelSize: 11
                            font.family: "Monospace"
                            wrapMode: Text.WrapAnywhere
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }
                }
            }
        }
    }
}
