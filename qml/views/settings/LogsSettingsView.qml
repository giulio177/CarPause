import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../components"

Rectangle {
    id: logsViewRoot
    Layout.fillWidth: true
    Layout.fillHeight: true
    radius: theme.radiusLarge
    color: theme.surfaceDark
    border.color: theme.surfaceBorder
    clip: true

    property string levelFilter: "ALL" // "ALL", "INFO", "WARNING", "ERROR"
    property bool autoScroll: true

    // Filtered logs list
    readonly property var filteredLogs: {
        var all = backend.appLogs || [];
        if (levelFilter === "ALL") return all;
        return all.filter(function(entry) {
            if (levelFilter === "WARNING") return entry.level === "WARNING";
            if (levelFilter === "ERROR") return entry.level === "ERROR" || entry.level === "CRITICAL";
            if (levelFilter === "INFO") return entry.level === "INFO";
            return true;
        });
    }

    Component.onCompleted: {
        Qt.callLater(function() {
            if (logListView.count > 0) {
                logListView.positionViewAtEnd();
            }
        });
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        // ====================================================================
        // 1. HEADER RIGA 1: TITOLO, FILE ATTIVO, CONTEGGIO E AZIONI
        // ====================================================================
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            // Titolo Sezione
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
                    text: "LOG APPLICAZIONE"
                    color: theme.textPrimary
                    font.pixelSize: 14
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // Badge File di Sessione (logs/session_*.log)
            Rectangle {
                implicitWidth: Math.min(sessionFileRow.implicitWidth + 12, 220)
                implicitHeight: 24
                radius: 12
                color: theme.surfaceElevated
                border.color: Qt.rgba(0.0, 0.898, 1.0, 0.25)
                Layout.alignment: Qt.AlignVCenter

                Row {
                    id: sessionFileRow
                    anchors.centerIn: parent
                    spacing: 4

                    MaterialIcon {
                        name: "description"
                        size: 13
                        iconColor: theme.accentCyan
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: backend.currentLogFilename || "session.log"
                        color: theme.accentCyan
                        font.pixelSize: 10
                        font.bold: true
                        elide: Text.ElideMiddle
                        width: Math.min(implicitWidth, 190)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            // Badge conteggio voci
            Rectangle {
                implicitWidth: countText.contentWidth + 12
                implicitHeight: 22
                radius: 11
                color: theme.surfaceElevated
                border.color: theme.surfaceBorder
                Layout.alignment: Qt.AlignVCenter

                Text {
                    id: countText
                    anchors.centerIn: parent
                    text: logsViewRoot.filteredLogs.length + " eventi"
                    color: theme.textSecondary
                    font.pixelSize: 10
                    font.bold: true
                }
            }

            Item { Layout.fillWidth: true } // Spacer

            // Pulsante Ricarica da File
            Rectangle {
                implicitWidth: reloadRow.implicitWidth + 12
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
                    onClicked: backend.refreshLogs()
                }
            }

            // Pulsante Auto-Scroll / In Fondo
            Rectangle {
                implicitWidth: scrollRow.implicitWidth + 12
                implicitHeight: 28
                radius: 14
                color: logsViewRoot.autoScroll ? Qt.rgba(0.0, 0.898, 1.0, 0.14) : theme.surfaceElevated
                border.color: logsViewRoot.autoScroll ? theme.accentCyan : theme.surfaceBorder
                Layout.alignment: Qt.AlignVCenter

                Row {
                    id: scrollRow
                    anchors.centerIn: parent
                    spacing: 4

                    MaterialIcon {
                        name: "arrow_downward"
                        size: 14
                        iconColor: logsViewRoot.autoScroll ? theme.accentCyan : theme.textMuted
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "In Fondo"
                        color: logsViewRoot.autoScroll ? theme.accentCyan : theme.textMuted
                        font.pixelSize: 11
                        font.bold: logsViewRoot.autoScroll
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        logsViewRoot.autoScroll = !logsViewRoot.autoScroll;
                        if (logsViewRoot.autoScroll && logListView.count > 0) {
                            logListView.positionViewAtEnd();
                        }
                    }
                }
            }

            // Pulsante Svuota Log
            Rectangle {
                implicitWidth: clearRow.implicitWidth + 12
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
                    onClicked: backend.clearLogs()
                }
            }
        }

        // ====================================================================
        // 2. HEADER RIGA 2: FILTRI PER LIVELLO E INFO STATUS
        // ====================================================================
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            // Filtri per Livello
            Row {
                spacing: 6
                Layout.alignment: Qt.AlignVCenter

                component FilterBtn: Rectangle {
                    property string targetFilter: ""
                    property string label: ""
                    property color activeColor: theme.accentCyan
                    property bool isCurrent: logsViewRoot.levelFilter === targetFilter

                    implicitWidth: filterBtnText.contentWidth + 16
                    implicitHeight: 26
                    radius: 13
                    color: isCurrent ? Qt.rgba(activeColor.r, activeColor.g, activeColor.b, 0.16) : theme.surfaceElevated
                    border.color: isCurrent ? activeColor : theme.surfaceBorder
                    border.width: isCurrent ? 1.5 : 1

                    Text {
                        id: filterBtnText
                        anchors.centerIn: parent
                        text: label
                        color: isCurrent ? theme.textPrimary : theme.textMuted
                        font.pixelSize: 11
                        font.bold: isCurrent
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: logsViewRoot.levelFilter = targetFilter
                    }
                }

                FilterBtn { targetFilter: "ALL"; label: "TUTTI"; activeColor: theme.accentCyan }
                FilterBtn { targetFilter: "INFO"; label: "INFO"; activeColor: theme.accentCyan }
                FilterBtn { targetFilter: "WARNING"; label: "WARN"; activeColor: theme.accentYellow }
                FilterBtn { targetFilter: "ERROR"; label: "ERR"; activeColor: theme.accentRed }
            }

            Item { Layout.fillWidth: true } // Spacer

            // Info percorso cartella
            Row {
                spacing: 4
                Layout.alignment: Qt.AlignVCenter

                MaterialIcon {
                    name: "folder"
                    size: 13
                    iconColor: theme.textMuted
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: "logs/"
                    color: theme.textMuted
                    font.pixelSize: 10
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        // Linea divisoria
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: theme.surfaceBorder
        }

        // ====================================================================
        // 3. LISTA SCORRIBILE DEI LOG (ListView con larghezza controllata)
        // ====================================================================
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ListView {
                id: logListView
                anchors.fill: parent
                clip: true
                spacing: 6
                boundsBehavior: Flickable.StopAtBounds
                model: logsViewRoot.filteredLogs

                onCountChanged: {
                    if (logsViewRoot.autoScroll && !logListView.moving && !logListView.dragging && !logListView.flicking && count > 0) {
                        Qt.callLater(logListView.positionViewAtEnd);
                    }
                }

                onMovementEnded: {
                    var distFromBottom = (contentHeight - height) - contentY;
                    if (distFromBottom > 40) {
                        logsViewRoot.autoScroll = false;
                    } else {
                        logsViewRoot.autoScroll = true;
                    }
                }

                // Barra di scorrimento verticale personalizzata
                ScrollBar.vertical: ScrollBar {
                    id: vScrollBar
                    active: true
                    policy: ScrollBar.AlwaysOn
                    width: 6

                    contentItem: Rectangle {
                        implicitWidth: 6
                        radius: 3
                        color: vScrollBar.pressed ? theme.accentCyan : Qt.rgba(1.0, 1.0, 1.0, 0.20)
                    }
                }

                delegate: Rectangle {
                    // Larghezza esatta calcolata per non superare mai i bordi della card
                    width: logListView.width - 12
                    anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
                    implicitHeight: logRowCol.implicitHeight + 14
                    radius: 8
                    color: {
                        if (modelData.level === "ERROR" || modelData.level === "CRITICAL") return "#251218";
                        if (modelData.level === "WARNING") return "#221A10";
                        return theme.surfaceElevated;
                    }
                    border.color: {
                        if (modelData.level === "ERROR" || modelData.level === "CRITICAL") return Qt.rgba(1.0, 0.2, 0.4, 0.45);
                        if (modelData.level === "WARNING") return Qt.rgba(1.0, 0.7, 0.0, 0.40);
                        return theme.surfaceBorder;
                    }
                    border.width: 1

                    ColumnLayout {
                        id: logRowCol
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 4

                        // Intestazione log: [LIVELLO] [ORARIO] [SERVIZIO/COMPONENTE]
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            // Badge livello
                            Rectangle {
                                implicitWidth: lvlText.contentWidth + 10
                                implicitHeight: 18
                                radius: 4
                                color: {
                                    if (modelData.level === "ERROR" || modelData.level === "CRITICAL") return Qt.rgba(1.0, 0.2, 0.4, 0.16);
                                    if (modelData.level === "WARNING") return Qt.rgba(1.0, 0.7, 0.0, 0.16);
                                    return Qt.rgba(0.0, 0.898, 1.0, 0.15);
                                }
                                border.color: {
                                    if (modelData.level === "ERROR" || modelData.level === "CRITICAL") return theme.accentRed;
                                    if (modelData.level === "WARNING") return theme.accentYellow;
                                    return theme.accentCyan;
                                }

                                Text {
                                    id: lvlText
                                    anchors.centerIn: parent
                                    text: {
                                        if (modelData.level === "WARNING") return "WARN";
                                        if (modelData.level === "CRITICAL") return "CRIT";
                                        return modelData.level || "INFO";
                                    }
                                    color: {
                                        if (modelData.level === "ERROR" || modelData.level === "CRITICAL") return theme.accentRed;
                                        if (modelData.level === "WARNING") return theme.accentYellow;
                                        return theme.accentCyan;
                                    }
                                    font.pixelSize: 9
                                    font.bold: true
                                }
                            }

                            // Orario
                            Text {
                                text: modelData.time || ""
                                color: theme.textSecondary
                                font.pixelSize: 11
                                font.bold: true
                            }

                            // Nome del Logger / Servizio
                            Text {
                                text: modelData.name ? "[" + modelData.name + "]" : ""
                                color: theme.accentCyan
                                font.pixelSize: 11
                                font.bold: true
                            }

                            Item { Layout.fillWidth: true }
                        }

                        // Messaggio del log
                        Text {
                            text: modelData.message || ""
                            color: theme.textPrimary
                            font.pixelSize: 12
                            wrapMode: Text.WrapAnywhere
                            Layout.fillWidth: true
                        }
                    }
                }

                // Stato vuoto
                Item {
                    anchors.centerIn: parent
                    width: parent.width
                    height: 160
                    visible: logListView.count === 0

                    Column {
                        anchors.centerIn: parent
                        spacing: 10

                        MaterialIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            name: "description"
                            size: 40
                            iconColor: theme.textMuted
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Nessun evento registrato nel file di sessione"
                            color: theme.textMuted
                            font.pixelSize: 13
                            font.bold: true
                        }
                    }
                }
            }
        }
    }
}
