import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Rectangle {
    id: bottomBarRoot
    Layout.fillWidth: true
    Layout.preferredHeight: 68
    color: theme.surfaceDark
    border.color: theme.surfaceBorder
    border.width: 1

    signal requestRebootModal()

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        spacing: 12

        // ====================================================================
        // 1. COMPACT MINI MEDIA PLAYER (Left Section)
        // ====================================================================
        RowLayout {
            Layout.preferredWidth: 220
            Layout.alignment: Qt.AlignVCenter
            spacing: 10

            Rectangle {
                width: 40
                height: 40
                radius: 20
                color: theme.surfaceElevated
                border.color: backend.hasMedia ? theme.accentCyan : theme.surfaceBorder
                border.width: 1
                opacity: backend.hasMedia ? 1.0 : 0.45

                MaterialIcon {
                    anchors.centerIn: parent
                    name: backend.isPlaying ? "pause" : "play_arrow"
                    size: 20
                    iconColor: backend.hasMedia ? theme.accentCyan : theme.textMuted
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: backend.hasMedia
                    onClicked: backend.togglePlay()
                }
            }

            Column {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: backend.hasMedia ? backend.trackTitle : "Nessuna traccia"
                    color: backend.hasMedia ? theme.textPrimary : theme.textMuted
                    font.pixelSize: 13
                    font.bold: backend.hasMedia
                    elide: Text.ElideRight
                    width: 165
                }
                Text {
                    text: backend.hasMedia ? backend.trackArtist : "Audio Standby"
                    color: theme.textMuted
                    font.pixelSize: 11
                    elide: Text.ElideRight
                    width: 165
                }
            }
        }

        Item { Layout.fillWidth: true } // Spacer

        // ====================================================================
        // 2. CENTRAL NAVIGATION TABS + RESTART/POWER
        // ====================================================================
        Row {
            Layout.alignment: Qt.AlignVCenter
            spacing: 8

            component NavTab: Rectangle {
                property string viewId: ""
                property string iconName: ""
                property string label: ""
                property bool isActive: backend.currentView === viewId

                width: 90
                height: 54
                radius: theme.radiusMedium
                color: isActive ? Qt.rgba(0, 0.898, 1, 0.12) : (navTabMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.05) : "transparent")
                border.color: isActive ? theme.accentCyan : "transparent"
                border.width: 1.5

                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on scale { NumberAnimation { duration: 100 } }

                Column {
                    anchors.centerIn: parent
                    spacing: 3

                    MaterialIcon {
                        name: iconName
                        size: 22
                        iconColor: isActive ? theme.accentCyan : theme.textSecondary
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Text {
                        text: label
                        color: isActive ? theme.textPrimary : theme.textMuted
                        font.pixelSize: 10
                        font.bold: isActive
                        font.letterSpacing: 0.5
                        horizontalAlignment: Text.AlignHCenter
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }

                MouseArea {
                    id: navTabMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPressed: parent.scale = 0.94
                    onReleased: parent.scale = 1.0
                    onCanceled: parent.scale = 1.0
                    onClicked: backend.changeView(viewId)
                }
            }

            NavTab { viewId: "dashboard"; iconName: "speed";       label: "DASH" }
            NavTab { viewId: "media";     iconName: "music_note";  label: "MEDIA" }
            NavTab { viewId: "airplay";   iconName: "airplay";     label: "AIRPLAY" }
            NavTab { viewId: "settings";  iconName: "settings";    label: "SETTING" }

        }

        Item { Layout.fillWidth: true } // Spacer

        // ====================================================================
        // 3. MASTER VOLUME SLIDER + MUTE CONTROL (Right Section)
        // ====================================================================
        RowLayout {
            Layout.alignment: Qt.AlignVCenter
            spacing: 8

            Rectangle {
                id: muteBtn
                width: 42
                height: 42
                radius: 21
                color: backend.isMuted ? "#381520" : (muteMouseArea.pressed ? "#232F42" : theme.surfaceElevated)
                border.color: backend.isMuted ? theme.accentRed : (muteMouseArea.containsMouse ? theme.accentCyan : theme.surfaceBorder)
                border.width: backend.isMuted ? 2 : 1
                scale: muteMouseArea.pressed ? 0.92 : 1.0

                Behavior on scale { NumberAnimation { duration: 100 } }
                Behavior on color { ColorAnimation { duration: 150 } }

                MaterialIcon {
                    anchors.centerIn: parent
                    name: backend.isMuted ? "volume_off" : (backend.volume === 0 ? "volume_mute" : "volume_up")
                    size: 20
                    iconColor: backend.isMuted ? theme.accentRed : theme.textPrimary
                }

                MouseArea {
                    id: muteMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: backend.toggleMute()
                }
            }

            Slider {
                id: volumeSlider
                Layout.preferredWidth: 130
                from: 0
                to: backend.maxVolume
                stepSize: 1
                value: backend.volume

                onMoved: {
                    backend.setVolume(Math.round(value))
                }

                background: Rectangle {
                    x: volumeSlider.leftPadding
                    y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                    width: volumeSlider.availableWidth
                    height: 8
                    radius: 4
                    color: theme.surfaceElevated

                    Rectangle {
                        width: volumeSlider.visualPosition * parent.width
                        height: parent.height
                        color: backend.isMuted ? theme.textMuted : (backend.volume > 100 ? theme.accentYellow : theme.accentCyan)
                        radius: 4
                    }
                }

                handle: Rectangle {
                    x: volumeSlider.leftPadding + volumeSlider.visualPosition * (volumeSlider.availableWidth - width)
                    y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                    width: 24
                    height: 24
                    radius: 12
                    color: theme.textPrimary
                    border.color: backend.volume > 100 ? theme.accentYellow : theme.accentCyan
                    border.width: 2
                }
            }

            Text {
                text: backend.volume + "%"
                color: backend.volume > 100 ? theme.accentYellow : theme.textSecondary
                font.pixelSize: 13
                font.bold: true
                Layout.preferredWidth: 44
            }
        }
        
        // App Restart & System Reboot (3-second hold)
        Rectangle {
            id: restartBtn
            width: 50
            height: 50
            radius: 25
            Layout.alignment: Qt.AlignVCenter
            color: restartMouseArea.pressed ? "#1E2B3E" : "#141D2B"
            border.color: restartBtn.holdProgress > 0 ? theme.accentYellow : (restartMouseArea.pressed ? theme.accentCyan : theme.surfaceBorder)
            border.width: restartBtn.holdProgress > 0 ? 2.5 : 1

            property real holdProgress: 0.0

            NumberAnimation on holdProgress {
                id: holdAnim
                from: 0.0
                to: 1.0
                duration: 3000
                running: false
            }

            // Fill indicator for 3-second hold
            Rectangle {
                anchors.fill: parent
                radius: 25
                color: "transparent"
                border.color: theme.accentYellow
                border.width: restartBtn.holdProgress > 0 ? 3 : 0
                opacity: restartBtn.holdProgress
            }

            MaterialIcon {
                anchors.centerIn: parent
                name: "restart_alt"
                size: 22
                iconColor: restartBtn.holdProgress > 0 ? theme.accentYellow : theme.accentCyan
            }

            MouseArea {
                id: restartMouseArea
                anchors.fill: parent
                pressAndHoldInterval: 3000
                property bool holdTriggered: false

                onPressed: {
                    holdTriggered = false;
                    restartBtn.holdProgress = 0.0;
                    holdAnim.start();
                }

                onReleased: {
                    holdAnim.stop();
                    restartBtn.holdProgress = 0.0;
                }

                onCanceled: {
                    holdAnim.stop();
                    restartBtn.holdProgress = 0.0;
                }

                onPressAndHold: {
                    holdTriggered = true;
                    holdAnim.stop();
                    restartBtn.holdProgress = 0.0;
                    bottomBarRoot.requestRebootModal();
                }

                onClicked: {
                    if (!holdTriggered) {
                        backend.restartApp();
                    }
                }
            }
        }
    }
}
