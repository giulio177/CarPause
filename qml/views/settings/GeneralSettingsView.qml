import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../components"

Rectangle {
    id: generalSettingsRoot
    Layout.fillWidth: true
    Layout.fillHeight: true
    radius: theme.radiusLarge
    color: theme.surfaceDark
    border.color: theme.surfaceBorder
    clip: true

    Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: contentCol.implicitHeight + 40
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        ColumnLayout {
            id: contentCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 20
            spacing: 16

            // ================================================================
            // 1. INFORMAZIONI E STATO SISTEMA
            // ================================================================
            Row {
                spacing: 10
                MaterialIcon {
                    name: "info"
                    size: 22
                    iconColor: theme.accentCyan
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: "INFORMAZIONI E STATO SISTEMA"
                    color: theme.textPrimary
                    font.pixelSize: 15
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: theme.surfaceBorder
            }

            // Diagnostics Rows
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "Piattaforma Operativa"; color: theme.textSecondary; font.pixelSize: 13 }
                    Item { Layout.fillWidth: true }
                    Text { text: "Linux Embedded (Raspberry Pi 4B)"; color: theme.textPrimary; font.pixelSize: 13; font.bold: true }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "Risoluzione Display Touch"; color: theme.textSecondary; font.pixelSize: 13 }
                    Item { Layout.fillWidth: true }
                    Text { text: "1024x600 @ 60 FPS"; color: theme.textPrimary; font.pixelSize: 13; font.bold: true }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "Temperatura CPU Broadcom"; color: theme.textSecondary; font.pixelSize: 13 }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: backend.cpuTemperatureText
                        color: theme.accentCyan
                        font.pixelSize: 13
                        font.bold: true
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "Interfaccia Telemetria OBD-II"; color: theme.textSecondary; font.pixelSize: 13 }
                    Item { Layout.fillWidth: true }
                    Row {
                        spacing: 6
                        MaterialIcon {
                            name: backend.obdConnected ? "check_circle" : "cancel"
                            size: 15
                            iconColor: backend.obdConnected ? theme.accentGreen : theme.accentRed
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: backend.obdConnected ? "Connesso (ECU Online)" : "Disconnesso"
                            color: backend.obdConnected ? theme.accentGreen : theme.accentRed
                            font.pixelSize: 13
                            font.bold: true
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "Flusso Audio / Bluetooth Attivo"; color: theme.textSecondary; font.pixelSize: 13 }
                    Item { Layout.fillWidth: true }
                    Row {
                        spacing: 6
                        MaterialIcon {
                            name: backend.bluetoothConnected ? "bluetooth_connected" : "bluetooth"
                            size: 15
                            iconColor: backend.bluetoothConnected ? theme.accentCyan : theme.textMuted
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: backend.bluetoothDeviceName
                            color: backend.bluetoothConnected ? theme.accentCyan : theme.textSecondary
                            font.pixelSize: 13
                            font.bold: backend.bluetoothConnected
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }

            // ================================================================
            // 2. CONFIGURAZIONE AUDIO & CONTROLLI
            // ================================================================
            Item { Layout.preferredHeight: 4 } // Spaziatore

            Row {
                spacing: 10
                MaterialIcon {
                    name: "volume_up"
                    size: 22
                    iconColor: theme.accentCyan
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: "CONFIGURAZIONE AUDIO & CONTROLLI"
                    color: theme.textPrimary
                    font.pixelSize: 15
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: theme.surfaceBorder
            }

            // Riquadro impostazione Volume Massimo Slider
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: maxVolCol.implicitHeight + 28
                radius: theme.radiusMedium
                color: theme.surfaceElevated
                border.color: theme.surfaceBorder

                ColumnLayout {
                    id: maxVolCol
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 12

                    // Riga 1: Titolo e pulsanti preset (solo percentuali senza nomi)
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        ColumnLayout {
                            spacing: 2
                            Layout.alignment: Qt.AlignVCenter

                            Text {
                                text: "Volume Massimo Slider Barra Inferiore"
                                color: theme.textPrimary
                                font.pixelSize: 13
                                font.bold: true
                            }
                            Text {
                                text: "Consente l'amplificazione software oltre il 100%"
                                color: theme.textSecondary
                                font.pixelSize: 11
                            }
                        }

                        Item { Layout.fillWidth: true } // Spacer

                        // Presets rapidi: solo percentuali
                        Row {
                            spacing: 6
                            Layout.alignment: Qt.AlignVCenter

                            component VolPresetBtn: Rectangle {
                                property int targetVol: 100
                                property bool isCurrent: backend ? (backend.maxVolume === targetVol) : false
                                property bool isBoost: targetVol > 100

                                implicitWidth: volPresetText.contentWidth + 14
                                implicitHeight: 28
                                radius: 14
                                color: isCurrent 
                                    ? (isBoost ? Qt.rgba(1.0, 0.7, 0.0, 0.18) : Qt.rgba(0.0, 0.898, 1.0, 0.18))
                                    : theme.surfaceDark
                                border.color: isCurrent
                                    ? (isBoost ? theme.accentYellow : theme.accentCyan)
                                    : theme.surfaceBorder
                                border.width: isCurrent ? 1.5 : 1

                                Text {
                                    id: volPresetText
                                    anchors.centerIn: parent
                                    text: targetVol + "%"
                                    color: isCurrent 
                                        ? (isBoost ? theme.accentYellow : theme.accentCyan)
                                        : theme.textSecondary
                                    font.pixelSize: 11
                                    font.bold: isCurrent
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (backend) backend.setMaxVolume(targetVol);
                                    }
                                }
                            }

                            VolPresetBtn { targetVol: 100 }
                            VolPresetBtn { targetVol: 125 }
                            VolPresetBtn { targetVol: 150 }
                            VolPresetBtn { targetVol: 200 }
                        }
                    }

                    // Riga 2: Slider con [-] e [+] alle estremità
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        // Tasto [-] estremità sinistra
                        Rectangle {
                            width: 34
                            height: 34
                            radius: 17
                            color: minusMouse.pressed ? theme.surfaceBorder : theme.surfaceDark
                            border.color: theme.surfaceBorder
                            Layout.alignment: Qt.AlignVCenter

                            MaterialIcon {
                                name: "remove"
                                size: 16
                                iconColor: (backend && backend.maxVolume > 100) ? theme.textPrimary : theme.textMuted
                                anchors.centerIn: parent
                            }

                            MouseArea {
                                id: minusMouse
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                enabled: Boolean(backend && backend.maxVolume > 100)
                                onClicked: {
                                    if (backend) backend.setMaxVolume(Math.max(100, backend.maxVolume - 5));
                                }
                            }
                        }

                        // Slider al centro
                        Slider {
                            id: maxVolSlider
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            from: 100
                            to: 200
                            stepSize: 5
                            value: backend ? backend.maxVolume : 100

                            onMoved: {
                                if (backend) backend.setMaxVolume(Math.round(value));
                            }

                            background: Rectangle {
                                x: maxVolSlider.leftPadding
                                y: maxVolSlider.topPadding + maxVolSlider.availableHeight / 2 - height / 2
                                width: maxVolSlider.availableWidth
                                height: 8
                                radius: 4
                                color: theme.surfaceDark

                                Rectangle {
                                    width: maxVolSlider.visualPosition * parent.width
                                    height: parent.height
                                    color: (backend && backend.maxVolume > 100) ? theme.accentYellow : theme.accentCyan
                                    radius: 4
                                }
                            }

                            handle: Rectangle {
                                x: maxVolSlider.leftPadding + maxVolSlider.visualPosition * (maxVolSlider.availableWidth - width)
                                y: maxVolSlider.topPadding + maxVolSlider.availableHeight / 2 - height / 2
                                width: 24
                                height: 24
                                radius: 12
                                color: theme.textPrimary
                                border.color: (backend && backend.maxVolume > 100) ? theme.accentYellow : theme.accentCyan
                                border.width: 2
                            }
                        }

                        // Tasto [+] estremità destra
                        Rectangle {
                            width: 34
                            height: 34
                            radius: 17
                            color: plusMouse.pressed ? theme.surfaceBorder : theme.surfaceDark
                            border.color: theme.surfaceBorder
                            Layout.alignment: Qt.AlignVCenter

                            MaterialIcon {
                                name: "add"
                                size: 16
                                iconColor: (backend && backend.maxVolume < 200) ? theme.textPrimary : theme.textMuted
                                anchors.centerIn: parent
                            }

                            MouseArea {
                                id: plusMouse
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                enabled: Boolean(backend && backend.maxVolume < 200)
                                onClicked: {
                                    if (backend) backend.setMaxVolume(Math.min(200, backend.maxVolume + 5));
                                }
                            }
                        }

                        // Badge percentuale
                        Rectangle {
                            implicitWidth: maxVolDispText.contentWidth + 16
                            implicitHeight: 32
                            radius: 16
                            color: (backend && backend.maxVolume > 100) ? Qt.rgba(1.0, 0.7, 0.0, 0.16) : Qt.rgba(0.0, 0.898, 1.0, 0.16)
                            border.color: (backend && backend.maxVolume > 100) ? theme.accentYellow : theme.accentCyan
                            border.width: 1
                            Layout.alignment: Qt.AlignVCenter

                            Text {
                                id: maxVolDispText
                                anchors.centerIn: parent
                                text: (backend ? backend.maxVolume : 100) + "%"
                                color: (backend && backend.maxVolume > 100) ? theme.accentYellow : theme.accentCyan
                                font.pixelSize: 12
                                font.bold: true
                            }
                        }
                    }
                }
            }

            // ================================================================
            // 3. AGGIORNAMENTO SOFTWARE DA GITHUB
            // ================================================================
            Item { Layout.preferredHeight: 4 } // Spaziatore

            Row {
                spacing: 10
                MaterialIcon {
                    name: "system_update"
                    size: 22
                    iconColor: theme.accentCyan
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: "AGGIORNAMENTO SOFTWARE (GITHUB)"
                    color: theme.textPrimary
                    font.pixelSize: 15
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: theme.surfaceBorder
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: updateCardCol.implicitHeight + 28
                radius: theme.radiusMedium
                color: theme.surfaceElevated
                border.color: theme.surfaceBorder

                ColumnLayout {
                    id: updateCardCol
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 12

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 14

                        Rectangle {
                            width: 40
                            height: 40
                            radius: 20
                            color: backend.updateRunning ? "#12303D" : theme.surfaceDark
                            border.color: backend.updateRunning ? theme.accentCyan : theme.surfaceBorder
                            Layout.alignment: Qt.AlignVCenter

                            MaterialIcon {
                                name: "cloud_sync"
                                size: 22
                                iconColor: backend.updateRunning ? theme.accentCyan : theme.textPrimary
                                anchors.centerIn: parent
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Layout.alignment: Qt.AlignVCenter

                            Text {
                                text: "Sincronizzazione Software Remota"
                                color: theme.textPrimary
                                font.pixelSize: 13
                                font.bold: true
                            }
                            Text {
                                text: "Esegue git pull dal repository ufficiale e aggiorna le dipendenze"
                                color: theme.textSecondary
                                font.pixelSize: 11
                            }
                        }

                        // Pulsante di aggiornamento
                        Rectangle {
                            id: updateBtn
                            implicitWidth: updateBtnText.contentWidth + 30
                            height: 38
                            radius: 19
                            color: backend.updateRunning ? "#253342" : (updateMouse.pressed ? theme.accentCyan : theme.surfaceDark)
                            border.color: backend.updateRunning ? theme.textMuted : theme.accentCyan
                            border.width: 1.5
                            Layout.alignment: Qt.AlignVCenter

                            Row {
                                anchors.centerIn: parent
                                spacing: 8

                                MaterialIcon {
                                    name: backend.updateRunning ? "hourglass_top" : "download"
                                    size: 16
                                    iconColor: backend.updateRunning ? theme.textMuted : (updateMouse.pressed ? theme.bgDark : theme.accentCyan)
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    id: updateBtnText
                                    text: backend.updateRunning ? "Aggiornamento..." : "Verifica e Aggiorna"
                                    color: backend.updateRunning ? theme.textMuted : (updateMouse.pressed ? theme.bgDark : theme.accentCyan)
                                    font.pixelSize: 12
                                    font.bold: true
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: updateMouse
                                anchors.fill: parent
                                cursorShape: backend.updateRunning ? Qt.ArrowCursor : Qt.PointingHandCursor
                                enabled: !backend.updateRunning
                                onClicked: {
                                    backend.checkAndUpdateApp();
                                }
                            }
                        }
                    }

                    // Banner di stato dell'aggiornamento (se presente)
                    Rectangle {
                        visible: backend.updateStatusMessage.length > 0 || backend.updateRunning
                        Layout.fillWidth: true
                        height: 32
                        radius: 8
                        color: {
                            if (backend.updateRunning) return "#142F3B";
                            if (backend.updateSuccess) return "#153625";
                            return "#361D22";
                        }
                        border.color: {
                            if (backend.updateRunning) return theme.accentCyan;
                            if (backend.updateSuccess) return theme.accentGreen;
                            return theme.accentRed;
                        }
                        border.width: 1

                        Row {
                            anchors.centerIn: parent
                            spacing: 8

                            MaterialIcon {
                                name: {
                                    if (backend.updateRunning) return "sync";
                                    if (backend.updateSuccess) return "check_circle";
                                    return "error";
                                }
                                size: 14
                                iconColor: {
                                    if (backend.updateRunning) return theme.accentCyan;
                                    if (backend.updateSuccess) return theme.accentGreen;
                                    return theme.accentRed;
                                }
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: backend.updateStatusMessage
                                color: {
                                    if (backend.updateRunning) return theme.accentCyan;
                                    if (backend.updateSuccess) return theme.accentGreen;
                                    return theme.accentRed;
                                }
                                font.pixelSize: 11
                                font.bold: true
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }
            }

            // ================================================================
            // 4. AZIONI RAPIDE
            // ================================================================
            Item { Layout.preferredHeight: 4 } // Spaziatore

            RowLayout {
                Layout.fillWidth: true
                spacing: 14

                Rectangle {
                    Layout.preferredWidth: 180
                    Layout.preferredHeight: 42
                    radius: theme.radiusMedium
                    color: refreshArea.pressed ? theme.surfaceBorder : theme.surfaceElevated
                    border.color: theme.surfaceBorder

                    Row {
                        anchors.centerIn: parent
                        spacing: 8
                        MaterialIcon {
                            name: "refresh"
                            size: 16
                            iconColor: theme.textPrimary
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: "Ricarica Meteo"
                            color: theme.textPrimary
                            font.pixelSize: 12
                            font.bold: true
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: refreshArea
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: backend.refreshWeather()
                    }
                }
            }
        }
    }
}
