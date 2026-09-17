import QtQuick

Rectangle {
    id: switchRoot
    width: 50
    height: 28
    radius: 14
    color: checked ? theme.accentCyan : theme.surfaceBorder

    property bool checked: false
    signal toggled(bool isChecked)

    Behavior on color { ColorAnimation { duration: 200 } }

    Rectangle {
        id: thumb
        width: 22
        height: 22
        radius: 11
        anchors.verticalCenter: parent.verticalCenter
        x: switchRoot.checked ? (switchRoot.width - width - 3) : 3
        color: "#FFFFFF"

        Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.InOutQuad } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            switchRoot.toggled(!switchRoot.checked);
        }
    }
}
