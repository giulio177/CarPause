import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Rectangle {
    id: lyricsModalRoot
    anchors.fill: parent
    color: Qt.rgba(0, 0, 0, 0.85)
    visible: false
    z: 1000

    property string title: "Testo del Brano"
    property string artist: ""
    property string lyrics: ""

    function openForTrack(trackTitle, trackArtist, trackLyrics) {
        title = trackTitle || "Testo del Brano";
        artist = trackArtist || "";
        lyrics = trackLyrics || "Nessun testo disponibile per questa traccia.";
        lyricsModalRoot.visible = true;
    }

    function closeModal() {
        lyricsModalRoot.visible = false;
    }

    // Intercept clicks
    MouseArea {
        anchors.fill: parent
        onClicked: lyricsModalRoot.closeModal()
    }

    Rectangle {
        anchors.centerIn: parent
        width: 620
        height: 480
        radius: theme.radiusLarge
        color: theme.surfaceDark
        border.color: theme.accentCyan
        border.width: 1.5

        MouseArea {
            anchors.fill: parent
            // Prevent closing when tapping inside modal content
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 16

            // Header
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Rectangle {
                    width: 44
                    height: 44
                    radius: 22
                    color: Qt.rgba(0, 0.898, 1, 0.12)
                    border.color: theme.accentCyan

                    MaterialIcon {
                        anchors.centerIn: parent
                        name: "lyrics"
                        size: 24
                        iconColor: theme.accentCyan
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: lyricsModalRoot.title
                        color: theme.textPrimary
                        font.pixelSize: 18
                        font.bold: true
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Text {
                        text: lyricsModalRoot.artist
                        color: theme.textSecondary
                        font.pixelSize: 13
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                // Close Button
                Rectangle {
                    width: 44
                    height: 44
                    radius: 22
                    color: closeArea.pressed ? theme.surfaceBorder : theme.surfaceElevated
                    border.color: theme.surfaceBorder

                    MaterialIcon {
                        anchors.centerIn: parent
                        name: "close"
                        size: 22
                        iconColor: theme.textSecondary
                    }

                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        onClicked: lyricsModalRoot.closeModal()
                    }
                }
            }

            // Separator
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: theme.surfaceBorder
            }

            // Scrollable Lyrics Body
            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: width
                contentHeight: lyricsText.height + 40
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ScrollBar.vertical: ScrollBar {
                    active: true
                    policy: ScrollBar.AsNeeded
                }

                Text {
                    id: lyricsText
                    width: parent.width
                    text: lyricsModalRoot.lyrics
                    color: theme.textPrimary
                    font.pixelSize: 16
                    font.letterSpacing: 0.5
                    lineHeight: 1.5
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }
            }
        }
    }
}
