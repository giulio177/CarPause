import QtQuick

Text {
    id: rootIcon
    property string name: ""
    property int size: 24
    property color iconColor: "#FFFFFF"

    text: name
    font.family: "Material Symbols Rounded"
    font.pixelSize: size
    color: iconColor
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
}
