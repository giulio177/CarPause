import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: keyboardRoot
    width: parent ? parent.width : 1024
    height: 250
    color: "#0F141E"
    border.color: "#253043"
    border.width: 1

    property var targetInput: null
    property bool isShifted: false
    property bool isSymbols: false

    signal enterPressed()
    signal closed()

    // Key Button Component
    component KeyButton: Rectangle {
        property string charNormal: ""
        property string charShift: ""
        property string charSymbol: ""
        property int customWidth: 0
        property color btnColor: "#18202F"
        property color textColor: "#FFFFFF"
        property int fontSize: 18

        readonly property string displayChar: {
            if (keyboardRoot.isSymbols) return charSymbol || charNormal;
            if (keyboardRoot.isShifted) return (charShift || charNormal).toUpperCase();
            return (charNormal).toLowerCase();
        }

        Layout.preferredWidth: customWidth > 0 ? customWidth : 74
        Layout.preferredHeight: 50
        radius: 10
        color: keyMouseArea.pressed ? "#00E5FF" : btnColor
        border.color: keyMouseArea.pressed ? "#00E5FF" : "#28354A"
        border.width: 1

        Behavior on color { ColorAnimation { duration: 80 } }

        Text {
            anchors.centerIn: parent
            text: displayChar
            color: keyMouseArea.pressed ? "#0B0F17" : textColor
            font.pixelSize: fontSize
            font.bold: true
        }

        MouseArea {
            id: keyMouseArea
            anchors.fill: parent
            onClicked: {
                if (targetInput) {
                    targetInput.text += displayChar;
                }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 8

        // ====================================================================
        // ROW 1: Numbers or QWERTY Top Row
        // ====================================================================
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 8

            KeyButton { charNormal: "1"; charSymbol: "1"; visible: keyboardRoot.isSymbols }
            KeyButton { charNormal: "2"; charSymbol: "2"; visible: keyboardRoot.isSymbols }
            KeyButton { charNormal: "3"; charSymbol: "3"; visible: keyboardRoot.isSymbols }
            KeyButton { charNormal: "4"; charSymbol: "4"; visible: keyboardRoot.isSymbols }
            KeyButton { charNormal: "5"; charSymbol: "5"; visible: keyboardRoot.isSymbols }
            KeyButton { charNormal: "6"; charSymbol: "6"; visible: keyboardRoot.isSymbols }
            KeyButton { charNormal: "7"; charSymbol: "7"; visible: keyboardRoot.isSymbols }
            KeyButton { charNormal: "8"; charSymbol: "8"; visible: keyboardRoot.isSymbols }
            KeyButton { charNormal: "9"; charSymbol: "9"; visible: keyboardRoot.isSymbols }
            KeyButton { charNormal: "0"; charSymbol: "0"; visible: keyboardRoot.isSymbols }

            KeyButton { charNormal: "q"; charShift: "Q"; visible: !keyboardRoot.isSymbols }
            KeyButton { charNormal: "w"; charShift: "W"; visible: !keyboardRoot.isSymbols }
            KeyButton { charNormal: "e"; charShift: "E"; visible: !keyboardRoot.isSymbols }
            KeyButton { charNormal: "r"; charShift: "R"; visible: !keyboardRoot.isSymbols }
            KeyButton { charNormal: "t"; charShift: "T"; visible: !keyboardRoot.isSymbols }
            KeyButton { charNormal: "y"; charShift: "Y"; visible: !keyboardRoot.isSymbols }
            KeyButton { charNormal: "u"; charShift: "U"; visible: !keyboardRoot.isSymbols }
            KeyButton { charNormal: "i"; charShift: "I"; visible: !keyboardRoot.isSymbols }
            KeyButton { charNormal: "o"; charShift: "O"; visible: !keyboardRoot.isSymbols }
            KeyButton { charNormal: "p"; charShift: "P"; visible: !keyboardRoot.isSymbols }
        }

        // ====================================================================
        // ROW 2: Middle Row (A S D F G H J K L) or Symbols
        // ====================================================================
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 8

            KeyButton { charNormal: "a"; charShift: "A"; charSymbol: "@" }
            KeyButton { charNormal: "s"; charShift: "S"; charSymbol: "#" }
            KeyButton { charNormal: "d"; charShift: "D"; charSymbol: "$" }
            KeyButton { charNormal: "f"; charShift: "F"; charSymbol: "%" }
            KeyButton { charNormal: "g"; charShift: "G"; charSymbol: "&" }
            KeyButton { charNormal: "h"; charShift: "H"; charSymbol: "*" }
            KeyButton { charNormal: "j"; charShift: "J"; charSymbol: "-" }
            KeyButton { charNormal: "k"; charShift: "K"; charSymbol: "+" }
            KeyButton { charNormal: "l"; charShift: "L"; charSymbol: "=" }
        }

        // ====================================================================
        // ROW 3: Shift / Z X C V B N M / Backspace
        // ====================================================================
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 8

            // SHIFT / CAPS BUTTON
            Rectangle {
                Layout.preferredWidth: 100
                Layout.preferredHeight: 50
                radius: 10
                color: keyboardRoot.isShifted ? "#00E5FF" : "#242E40"
                border.color: "#35455E"
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: keyboardRoot.isSymbols ? "SYM" : "⇧"
                    color: keyboardRoot.isShifted ? "#0B0F17" : "#FFFFFF"
                    font.pixelSize: 18
                    font.bold: true
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: keyboardRoot.isShifted = !keyboardRoot.isShifted
                }
            }

            KeyButton { charNormal: "z"; charShift: "Z"; charSymbol: "!" }
            KeyButton { charNormal: "x"; charShift: "X"; charSymbol: "?" }
            KeyButton { charNormal: "c"; charShift: "C"; charSymbol: "/" }
            KeyButton { charNormal: "v"; charShift: "V"; charSymbol: "\\" }
            KeyButton { charNormal: "b"; charShift: "B"; charSymbol: "_" }
            KeyButton { charNormal: "n"; charShift: "N"; charSymbol: ":" }
            KeyButton { charNormal: "m"; charShift: "M"; charSymbol: ";" }

            // BACKSPACE BUTTON
            Rectangle {
                Layout.preferredWidth: 100
                Layout.preferredHeight: 50
                radius: 10
                color: bspMouseArea.pressed ? "#FF3366" : "#242E40"
                border.color: "#35455E"
                border.width: 1

                MaterialIcon {
                    anchors.centerIn: parent
                    name: "backspace"
                    size: 22
                    iconColor: "#FFFFFF"
                }

                MouseArea {
                    id: bspMouseArea
                    anchors.fill: parent
                    onClicked: {
                        if (targetInput && targetInput.text.length > 0) {
                            targetInput.text = targetInput.text.substring(0, targetInput.text.length - 1);
                        }
                    }
                }
            }
        }

        // ====================================================================
        // ROW 4: ?123 Mode / Spacebar / Special Chars / Enter
        // ====================================================================
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 8

            // ?123 TOGGLE
            Rectangle {
                Layout.preferredWidth: 90
                Layout.preferredHeight: 50
                radius: 10
                color: keyboardRoot.isSymbols ? "#00E5FF" : "#242E40"
                border.color: "#35455E"
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: keyboardRoot.isSymbols ? "ABC" : "?123"
                    color: keyboardRoot.isSymbols ? "#0B0F17" : "#FFFFFF"
                    font.pixelSize: 15
                    font.bold: true
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: keyboardRoot.isSymbols = !keyboardRoot.isSymbols
                }
            }

            KeyButton { charNormal: "."; charSymbol: "." }
            KeyButton { charNormal: ","; charSymbol: "'" }

            // SPACEBAR
            Rectangle {
                Layout.preferredWidth: 360
                Layout.preferredHeight: 50
                radius: 10
                color: spaceMouseArea.pressed ? "#00E5FF" : "#18202F"
                border.color: "#28354A"
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "SPAZIO"
                    color: spaceMouseArea.pressed ? "#0B0F17" : "#8A97AC"
                    font.pixelSize: 13
                    font.bold: true
                }

                MouseArea {
                    id: spaceMouseArea
                    anchors.fill: parent
                    onClicked: {
                        if (targetInput) targetInput.text += " ";
                    }
                }
            }

            KeyButton { charNormal: "-"; charSymbol: "(" }
            KeyButton { charNormal: "_"; charSymbol: ")" }

            // ENTER / DONE BUTTON
            Rectangle {
                Layout.preferredWidth: 120
                Layout.preferredHeight: 50
                radius: 10
                color: enterMouseArea.pressed ? "#00C853" : "#00E676"
                border.color: "#00E676"
                border.width: 1

                Row {
                    anchors.centerIn: parent
                    spacing: 4
                    Text {
                        text: "CONFERMA"
                        color: "#0B0F17"
                        font.pixelSize: 13
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    MaterialIcon {
                        name: "check"
                        size: 16
                        iconColor: "#0B0F17"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: enterMouseArea
                    anchors.fill: parent
                    onClicked: keyboardRoot.enterPressed()
                }
            }
        }
    }
}
