import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Item {
    id: exitOverlayRoot
    width: 60
    height: 60
    anchors.top: parent.top
    anchors.topMargin: 18
    anchors.right: parent.right
    anchors.rightMargin: 18
    z: 10000

    visible: backend.airplayStreaming && backend.airplayShowExitPopup
    opacity: (backend.airplayStreaming && backend.airplayShowExitPopup) ? 1.0 : 0.0

    Behavior on opacity {
        NumberAnimation { duration: 220; easing.type: Easing.OutQuad }
    }

    Rectangle {
        id: buttonCircle
        anchors.centerIn: parent
        width: 54
        height: 54
        radius: 27
        color: exitMouseArea.pressed ? "#DC2626" : "#E6141724"
        border.color: "#EF4444"
        border.width: 2

        scale: exitMouseArea.pressed ? 0.90 : 1.0
        Behavior on scale {
            NumberAnimation { duration: 100 }
        }

        // Ambient outer red glow
        Rectangle {
            anchors.centerIn: parent
            width: parent.width + 10
            height: parent.height + 10
            radius: width / 2
            color: "transparent"
            border.color: "#EF4444"
            border.width: 1.5
            opacity: 0.35
            z: -1
        }

        // Inner subtle red tint circle for contrast
        Rectangle {
            anchors.centerIn: parent
            width: 42
            height: 42
            radius: 21
            color: exitMouseArea.pressed ? "transparent" : "#33EF4444"
            z: 0
        }

        // 'X' Close icon
        MaterialIcon {
            name: "close"
            size: 30
            iconColor: "#FFFFFF"
            anchors.centerIn: parent
            z: 1
        }
    }

    MouseArea {
        id: exitMouseArea
        anchors.fill: parent
        anchors.margins: -12  // Generous 84x84 touch target for automotive comfort
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        preventStealing: true
        onClicked: {
            backend.stopAirPlayStream();
        }
    }
}
