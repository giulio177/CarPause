import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Item {
    id: dashboardRoot

    RowLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 18

        // ====================================================================
        // LEFT CARD: SPEEDOMETER & REAL OBD TELEMETRY
        // ====================================================================
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 350
            radius: theme.radiusLarge
            color: theme.surfaceDark
            border.color: backend.obdConnected ? theme.surfaceBorder : "#4A2026"

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 14

                // Status Banner
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    radius: 8
                    color: backend.obdConnected ? "#143026" : "#36161C"
                    border.color: backend.obdConnected ? theme.accentGreen : theme.accentRed

                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        MaterialIcon {
                            name: backend.obdConnected ? "check_circle" : "warning"
                            size: 16
                            iconColor: backend.obdConnected ? theme.accentGreen : theme.accentRed
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: backend.obdConnected ? "OBD COLLEGATO" : "OBD DISCONNESSO"
                            color: backend.obdConnected ? theme.accentGreen : theme.accentRed
                            font.pixelSize: 11
                            font.bold: true
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                Text {
                    text: "VELOCITÀ ISTANTANEA"
                    color: theme.textSecondary
                    font.pixelSize: 12
                    font.bold: true
                    Layout.alignment: Qt.AlignHCenter
                }

                // Digital Speed Reading
                Row {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 6
                    Text {
                        text: backend.speedText
                        color: backend.obdConnected ? theme.textPrimary : theme.textMuted
                        font.pixelSize: 68
                        font.bold: true
                    }
                    Text {
                        text: "km/h"
                        color: backend.obdConnected ? theme.accentCyan : theme.textMuted
                        font.pixelSize: 16
                        font.bold: true
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 12
                    }
                }

                // Engine RPM Bar
                Column {
                    Layout.fillWidth: true
                    spacing: 6
                    RowLayout {
                        width: parent.width
                        Text { text: "GIRI MOTORE"; color: theme.textMuted; font.pixelSize: 11 }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: backend.rpmText + (backend.obdConnected ? " RPM" : "")
                            color: backend.obdConnected ? theme.accentCyan : theme.textMuted
                            font.pixelSize: 12
                            font.bold: true
                        }
                    }

                    ProgressBar {
                        width: parent.width
                        from: 0
                        to: 6000
                        value: backend.obdConnected ? parseInt(backend.rpmText) : 0
                        background: Rectangle {
                            implicitHeight: 8
                            radius: 4
                            color: theme.surfaceElevated
                        }
                        contentItem: Item {
                            implicitHeight: 8
                            Rectangle {
                                width: parent.parent.visualPosition * parent.parent.width
                                height: parent.height
                                radius: 4
                                color: backend.obdConnected ? theme.accentCyan : theme.textMuted
                            }
                        }
                    }
                }

                // Real OBD Port info or error
                Text {
                    text: backend.obdConnected ? "Centralina ECU attiva" : backend.obdError
                    color: backend.obdConnected ? theme.textSecondary : theme.accentRed
                    font.pixelSize: 11
                    Layout.alignment: Qt.AlignHCenter
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                }

                Item { Layout.fillHeight: true }
            }
        }

        // ====================================================================
        // RIGHT COLUMN: NOW PLAYING CARD & CONNECTIVITY OVERVIEW
        // ====================================================================
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 18

            // Now Playing Widget Card
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: theme.radiusLarge
                color: theme.surfaceDark
                border.color: theme.surfaceBorder

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 20

                    Rectangle {
                        Layout.preferredWidth: 110
                        Layout.preferredHeight: 110
                        radius: theme.radiusMedium
                        color: theme.surfaceElevated
                        border.color: theme.surfaceBorder

                        MaterialIcon {
                            anchors.centerIn: parent
                            name: backend.hasMedia ? "headphones" : "music_off"
                            size: 48
                            iconColor: backend.hasMedia ? theme.accentCyan : theme.textMuted
                            opacity: backend.hasMedia ? 1.0 : 0.4
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: backend.hasMedia ? "IN RIPRODUZIONE (MPRIS / BT)" : "SORGENTE MULTIMEDIALE"
                            color: backend.hasMedia ? theme.accentCyan : theme.textMuted
                            font.pixelSize: 11
                            font.bold: true
                        }

                        Text {
                            text: backend.hasMedia ? backend.trackTitle : "Nessun dispositivo connesso"
                            color: backend.hasMedia ? theme.textPrimary : theme.textSecondary
                            font.pixelSize: 20
                            font.bold: true
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            text: backend.hasMedia
                                  ? (backend.trackArtist + (backend.trackAlbum ? " — " + backend.trackAlbum : ""))
                                  : "Collega uno smartphone via Bluetooth per riprodurre audio"
                            color: theme.textMuted
                            font.pixelSize: 13
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        // Mini Media Controls
                        Row {
                            spacing: 14
                            Layout.topMargin: 4
                            opacity: backend.hasMedia ? 1.0 : 0.4

                            Rectangle {
                                width: 44
                                height: 44
                                radius: 22
                                color: theme.surfaceElevated
                                border.color: theme.surfaceBorder
                                MaterialIcon {
                                    anchors.centerIn: parent
                                    name: "skip_previous"
                                    size: 20
                                    iconColor: theme.textPrimary
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    enabled: backend.hasMedia
                                    onClicked: backend.previousTrack()
                                }
                            }

                            Rectangle {
                                width: 44
                                height: 44
                                radius: 22
                                color: backend.hasMedia ? theme.accentCyan : theme.surfaceElevated
                                MaterialIcon {
                                    anchors.centerIn: parent
                                    name: backend.isPlaying ? "pause" : "play_arrow"
                                    size: 22
                                    iconColor: backend.hasMedia ? theme.bgDark : theme.textMuted
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    enabled: backend.hasMedia
                                    onClicked: backend.togglePlay()
                                }
                            }

                            Rectangle {
                                width: 44
                                height: 44
                                radius: 22
                                color: theme.surfaceElevated
                                border.color: theme.surfaceBorder
                                MaterialIcon {
                                    anchors.centerIn: parent
                                    name: "skip_next"
                                    size: 20
                                    iconColor: theme.textPrimary
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    enabled: backend.hasMedia
                                    onClicked: backend.nextTrack()
                                }
                            }
                        }
                    }
                }
            }

            // Quick Connectivity Status Card
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 96
                radius: theme.radiusLarge
                color: theme.surfaceDark
                border.color: theme.surfaceBorder

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 16

                    MaterialIcon {
                        name: "sensors"
                        size: 32
                        iconColor: theme.accentCyan
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 3
                        Text { text: "Stato Rete & Connettività"; color: theme.textSecondary; font.pixelSize: 11 }
                        Text {
                            text: backend.wifiConnected ? ("Wi-Fi: " + backend.wifiSsid) : "Wi-Fi Disconnesso"
                            color: backend.wifiConnected ? theme.accentGreen : theme.accentRed
                            font.pixelSize: 15
                            font.bold: true
                        }
                        Text {
                            text: backend.bluetoothConnected ? ("Bluetooth: connesso a " + backend.bluetoothDeviceName) : ("Bluetooth: " + backend.bluetoothDeviceName)
                            color: theme.textMuted
                            font.pixelSize: 12
                        }
                    }
                }
            }
        }
    }
}
