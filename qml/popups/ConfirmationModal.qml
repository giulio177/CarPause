import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Rectangle {
    id: modalRoot
    anchors.fill: parent
    color: Qt.rgba(0, 0, 0, 0.85)
    visible: false
    z: 1000

    property string title: "Attenzione"
    property string subtitle: "Richiesta conferma operazione"
    property string message: ""
    property string iconName: "warning"
    property color iconColor: theme.accentYellow
    property color borderColor: theme.accentYellow
    property string confirmText: "Conferma"
    property string cancelText: "Annulla"

    signal confirmed()
    signal cancelled()

    function openModal(options) {
        if (options) {
            if (options.title !== undefined) modalRoot.title = options.title;
            if (options.subtitle !== undefined) modalRoot.subtitle = options.subtitle;
            if (options.message !== undefined) modalRoot.message = options.message;
            if (options.iconName !== undefined) modalRoot.iconName = options.iconName;
            if (options.iconColor !== undefined) modalRoot.iconColor = options.iconColor;
            if (options.borderColor !== undefined) modalRoot.borderColor = options.borderColor;
            if (options.confirmText !== undefined) modalRoot.confirmText = options.confirmText;
            if (options.cancelText !== undefined) modalRoot.cancelText = options.cancelText;
        }
        modalRoot.visible = true;
    }

    function closeModal() {
        modalRoot.visible = false;
        modalRoot.cancelled();
    }

    // Intercept background clicks
    MouseArea {
        anchors.fill: parent
    }

    Rectangle {
        anchors.centerIn: parent
        width: 520
        height: 260
        radius: theme.radiusLarge
        color: theme.surfaceDark
        border.color: modalRoot.borderColor
        border.width: 1.5

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 16

            RowLayout {
                spacing: 14
                MaterialIcon {
                    name: modalRoot.iconName
                    size: 32
                    iconColor: modalRoot.iconColor
                }
                Column {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        text: modalRoot.title
                        color: theme.textPrimary
                        font.pixelSize: 18
                        font.bold: true
                    }
                    Text {
                        text: modalRoot.subtitle
                        color: theme.textMuted
                        font.pixelSize: 12
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: modalRoot.message
                color: theme.textSecondary
                font.pixelSize: 14
                lineHeight: 1.2
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                Layout.fillWidth: true
                spacing: 14

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 46
                    radius: theme.radiusMedium
                    color: cancelArea.pressed ? theme.surfaceBorder : theme.surfaceElevated
                    border.color: theme.surfaceBorder

                    Text {
                        anchors.centerIn: parent
                        text: modalRoot.cancelText
                        color: theme.textPrimary
                        font.pixelSize: 14
                        font.bold: true
                    }

                    MouseArea {
                        id: cancelArea
                        anchors.fill: parent
                        onClicked: {
                            modalRoot.visible = false;
                            modalRoot.cancelled();
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 46
                    radius: theme.radiusMedium
                    color: confirmArea.pressed ? theme.surfaceBorder : "#36161C"
                    border.color: modalRoot.borderColor
                    border.width: 1.5

                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        MaterialIcon {
                            name: modalRoot.iconName
                            size: 18
                            iconColor: modalRoot.iconColor
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: modalRoot.confirmText
                            color: modalRoot.iconColor
                            font.pixelSize: 14
                            font.bold: true
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: confirmArea
                        anchors.fill: parent
                        onClicked: {
                            modalRoot.visible = false;
                            modalRoot.confirmed();
                        }
                    }
                }
            }
        }
    }
}
