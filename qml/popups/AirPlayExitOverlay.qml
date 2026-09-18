import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Item {
    id: exitOverlayRoot
    width: 220
    height: 52
    anchors.top: parent.top
    anchors.topMargin: 16
    anchors.right: parent.right
    anchors.rightMargin: 16
    z: 9999

    visible: backend.airplayStreaming && backend.airplayShowExitPopup
    opacity: visible ? 1.0 : 0.0

    Behavior on opacity {
        NumberAnimation { duration: 250; easing.type: Easing.OutQuad }
    }

    Rectangle {
        id: pillBg
        anchors.fill: parent
        radius: 26
        color: touchArea.pressed ? "#4A121A" : "#D91C1F2B"
        border.color: theme.accentRed
        border.width: 1.5

        // Shadow / Glow effect
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.color: theme.accentRed
            border.width: 1
            opacity: 0.3
            scale: 1.04
            z: -1
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 18
            spacing: 10

            Rectangle {
                width: 32
                height: 32
                radius: 16
                color: theme.accentRed
                Layout.alignment: Qt.AlignVCenter

                MaterialIcon {
                    name: "close"
                    size: 20
                    iconColor: theme.textPrimary
                    anchors.centerIn: parent
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 1

                Text {
                    text: "Chiudi AirPlay"
                    color: theme.textPrimary
                    font.pixelSize: 14
                    font.bold: true
                }

                Text {
                    text: "Tocca per terminare"
                    color: theme.accentRed
                    font.pixelSize: 11
                }
            }
        }

        MouseArea {
            id: touchArea
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onClicked: {
                backend.stopAirPlayStream();
            }
        }
    }
}
