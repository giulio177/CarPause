import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Item {
    id: mediaViewRoot

    // Filter state for history subview: "all", "completed", "partial"
    property string historyFilter: "all"

    // Toggle for displaying lyrics mode (false = classic centered player, true = split lyrics player)
    property bool showLyrics: false

    StackLayout {
        anchors.fill: parent
        anchors.margins: 20
        currentIndex: {
            if (backend.mediaSubView === "library") return 1;
            if (backend.mediaSubView === "history") return 2;
            return 0; // player
        }

        // ====================================================================
        // 1. SUB-VIEW: NOW PLAYING (In Riproduzione)
        // Two switchable layouts:
        // - Classic Centered Player (!mediaViewRoot.showLyrics)
        // - Split Screen with Lyrics on Right (mediaViewRoot.showLyrics)
        // ====================================================================
        Item {
            id: playerSubView

            // ----------------------------------------------------------------
            // ----------------------------------------------------------------
            // MODALITÀ A: PLAYER CON LYRICS NASCOSTA
            // Foto a sinistra, titolo/testo e comandi a destra.
            // Sotto a entrambe le colonne: sliding bar di avanzamento traccia.
            // Sotto alla sliding bar: i vari pulsanti (Libreria, Testo, Cronologia).
            // ----------------------------------------------------------------
            Item {
                id: centeredClassicPlayer
                anchors.fill: parent
                visible: !mediaViewRoot.showLyrics

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 12

                    // 1. SEZIONE SUPERIORE: FOTO A SINISTRA, TESTI E COMANDI A DESTRA
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 24

                        // Colonna Sinistra: FOTO (Cover Art / Vinile)
                        Rectangle {
                            Layout.preferredWidth: 300
                            Layout.preferredHeight: 300
                            Layout.alignment: Qt.AlignVCenter
                            radius: theme.radiusLarge
                            color: theme.surfaceElevated
                            border.color: backend.isPlaying ? theme.accentCyan : theme.surfaceBorder
                            border.width: backend.isPlaying ? 2 : 1
                            clip: true

                            Image {
                                anchors.fill: parent
                                anchors.margins: 2
                                source: backend.currentTrackCover
                                fillMode: Image.PreserveAspectCrop
                                visible: backend.currentTrackCover !== ""
                            }

                            MaterialIcon {
                                anchors.centerIn: parent
                                visible: backend.currentTrackCover === ""
                                name: backend.hasMedia ? (backend.isPlaying ? "graphic_eq" : "music_note") : "music_off"
                                size: 76
                                iconColor: backend.hasMedia ? theme.accentCyan : theme.textMuted
                                opacity: backend.hasMedia ? 1.0 : 0.35
                            }

                            // Playing indicator badge
                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.right: parent.right
                                anchors.margins: 10
                                width: 30
                                height: 30
                                radius: 15
                                color: Qt.rgba(0, 0, 0, 0.8)
                                border.color: theme.accentCyan
                                visible: backend.hasMedia && backend.isPlaying

                                MaterialIcon {
                                    anchors.centerIn: parent
                                    name: "play_arrow"
                                    size: 18
                                    iconColor: theme.accentCyan
                                }
                            }
                        }

                        // Colonna Destra: Titolo, Testo Vario, e sotto i Controlli (Centrati nello spazio rimanente)
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 6

                            // Titolo brano
                            Text {
                                text: backend.hasMedia ? backend.trackTitle : "Nessun flusso audio attivo"
                                color: theme.textPrimary
                                font.pixelSize: 24
                                font.bold: true
                                elide: Text.ElideRight
                                horizontalAlignment: Text.AlignHCenter
                                Layout.fillWidth: true
                            }

                            // Artista
                            Text {
                                text: backend.hasMedia ? backend.trackArtist : backend.bluetoothDeviceName
                                color: theme.accentCyan
                                font.pixelSize: 16
                                font.bold: true
                                elide: Text.ElideRight
                                horizontalAlignment: Text.AlignHCenter
                                Layout.fillWidth: true
                            }

                            // Testo Vario (Album + Badge Sorgente)
                            RowLayout {
                                Layout.alignment: Qt.AlignHCenter
                                spacing: 10

                                Text {
                                    text: backend.hasMedia ? backend.trackAlbum : "Libreria Raspberry Pi"
                                    color: theme.textMuted
                                    font.pixelSize: 13
                                    elide: Text.ElideRight
                                    visible: text !== ""
                                }

                                Rectangle {
                                    id: classicSrcBadge
                                    implicitWidth: classicSrcBadgeRow.implicitWidth + 18
                                    implicitHeight: 24
                                    radius: 12
                                    color: classicSrcBadgeMouse.pressed ? Qt.rgba(255, 255, 255, 0.14) : (classicSrcBadgeMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.09) : Qt.rgba(255, 255, 255, 0.06))
                                    border.color: classicSrcBadgeMouse.containsMouse ? theme.accentCyan : theme.surfaceBorder

                                    Row {
                                        id: classicSrcBadgeRow
                                        anchors.centerIn: parent
                                        spacing: 5

                                        MaterialIcon {
                                            anchors.verticalCenter: parent.verticalCenter
                                            name: backend.mediaSource === "local" ? "library_music" : "bluetooth"
                                            size: 13
                                            iconColor: backend.hasMedia ? theme.accentCyan : theme.accentRed
                                        }

                                        Text {
                                            id: classicSrcBadgeText
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: backend.hasMedia ? (backend.mediaSource === "local" ? "LIBRERIA LOCALE" : "BLUETOOTH AUDIO") : (backend.mediaSource === "local" ? "LIBRERIA (PAUSA)" : "BLUETOOTH (STANDBY)")
                                            color: backend.hasMedia ? theme.textSecondary : theme.accentRed
                                            font.pixelSize: 10
                                            font.bold: true
                                        }

                                        MaterialIcon {
                                            anchors.verticalCenter: parent.verticalCenter
                                            name: "swap_horiz"
                                            size: 14
                                            iconColor: classicSrcBadgeMouse.containsMouse ? theme.accentCyan : theme.textMuted
                                        }
                                    }

                                    MouseArea {
                                        id: classicSrcBadgeMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            backend.toggleMediaSource()
                                        }
                                    }
                                }
                            }

                            Item { Layout.preferredHeight: 12 }

                            // Sotto questo testo: i controlli centrati
                            Row {
                                Layout.alignment: Qt.AlignHCenter
                                spacing: 20
                                opacity: backend.hasMedia ? 1.0 : 0.4

                                Rectangle {
                                    width: 52
                                    height: 52
                                    radius: 26
                                    color: theme.surfaceDark
                                    border.color: theme.surfaceBorder
                                    anchors.verticalCenter: parent.verticalCenter

                                    MaterialIcon {
                                        anchors.centerIn: parent
                                        name: "skip_previous"
                                        size: 24
                                        iconColor: theme.textPrimary
                                    }
                                     MouseArea {
                                        anchors.fill: parent
                                        preventStealing: true
                                        enabled: backend.hasMedia
                                        onClicked: backend.previousTrack()
                                    }
                                }

                                Rectangle {
                                    width: 66
                                    height: 66
                                    radius: 33
                                    color: backend.hasMedia ? theme.accentCyan : theme.surfaceElevated
                                    anchors.verticalCenter: parent.verticalCenter

                                    MaterialIcon {
                                        anchors.centerIn: parent
                                        name: backend.isPlaying ? "pause" : "play_arrow"
                                        size: 34
                                        iconColor: backend.hasMedia ? theme.bgDark : theme.textMuted
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        preventStealing: true
                                        enabled: backend.hasMedia
                                        onClicked: backend.togglePlay()
                                    }
                                }

                                Rectangle {
                                    width: 52
                                    height: 52
                                    radius: 26
                                    color: theme.surfaceDark
                                    border.color: theme.surfaceBorder
                                    anchors.verticalCenter: parent.verticalCenter

                                    MaterialIcon {
                                        anchors.centerIn: parent
                                        name: "skip_next"
                                        size: 24
                                        iconColor: theme.textPrimary
                                    }

                                    MouseArea {
                                        id: nextMouseArea
                                        anchors.fill: parent
                                        preventStealing: true
                                        enabled: backend.hasMedia
                                        onClicked: backend.nextTrack()
                                    }
                                }
                            }

                            Item { Layout.preferredHeight: 6 }

                            // Sotto ai comandi: Pulsanti circolari Shuffle e Repeat
                            Row {
                                Layout.alignment: Qt.AlignHCenter
                                spacing: 20
                                opacity: backend.hasMedia ? 1.0 : 0.4

                                // Pulsante Circolare Shuffle
                                Rectangle {
                                    width: 44
                                    height: 44
                                    radius: 22
                                    color: backend.shuffleEnabled ? Qt.rgba(0, 0.898, 1, 0.15) : (shuffleBtnArea.pressed ? theme.surfaceBorder : theme.surfaceDark)
                                    border.color: backend.shuffleEnabled ? theme.accentCyan : theme.surfaceBorder
                                    border.width: backend.shuffleEnabled ? 2 : 1

                                    MaterialIcon {
                                        anchors.centerIn: parent
                                        name: "shuffle"
                                        size: 20
                                        iconColor: backend.shuffleEnabled ? theme.accentCyan : theme.textSecondary
                                    }

                                    MouseArea {
                                        id: shuffleBtnArea
                                        anchors.fill: parent
                                        preventStealing: true
                                        enabled: backend.hasMedia
                                        onClicked: backend.toggleShuffle()
                                    }
                                }

                                // Pulsante Circolare Repeat (off -> all -> one -> off)
                                Rectangle {
                                    width: 44
                                    height: 44
                                    radius: 22
                                    color: backend.repeatMode !== "off" ? Qt.rgba(0, 0.898, 1, 0.15) : (repeatBtnArea.pressed ? theme.surfaceBorder : theme.surfaceDark)
                                    border.color: backend.repeatMode !== "off" ? theme.accentCyan : theme.surfaceBorder
                                    border.width: backend.repeatMode !== "off" ? 2 : 1

                                    MaterialIcon {
                                        anchors.centerIn: parent
                                        name: backend.repeatMode === "one" ? "repeat_one" : "repeat"
                                        size: 20
                                        iconColor: backend.repeatMode !== "off" ? theme.accentCyan : theme.textSecondary
                                    }

                                    MouseArea {
                                        id: repeatBtnArea
                                        anchors.fill: parent
                                        preventStealing: true
                                        enabled: backend.hasMedia
                                        onClicked: backend.toggleRepeat()
                                    }
                                }
                            }
                        }
                    }

                    // 2. SOTTO A ENTRAMBE LE COLONNE: SLIDING BAR DI AVANZAMENTO TRACCIA
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        // Tempo trascorso
                        Text {
                            text: backend.hasMedia ? backend.trackPositionFormatted : "00:00"
                            color: theme.textSecondary
                            font.pixelSize: 13
                            font.bold: true
                            Layout.minimumWidth: 42
                            horizontalAlignment: Text.AlignRight
                        }

                        // Sliding Bar
                        Slider {
                            id: trackProgressSlider
                            Layout.fillWidth: true
                            from: 0.0
                            to: 1.0
                            value: pressed ? value : backend.trackProgress
                            enabled: backend.hasMedia

                            onMoved: {
                                backend.seekProgress(value)
                            }

                            background: Rectangle {
                                x: trackProgressSlider.leftPadding
                                y: trackProgressSlider.topPadding + trackProgressSlider.availableHeight / 2 - height / 2
                                implicitWidth: 200
                                implicitHeight: 6
                                width: trackProgressSlider.availableWidth
                                height: implicitHeight
                                radius: 3
                                color: theme.surfaceElevated
                                border.color: theme.surfaceBorder

                                Rectangle {
                                    width: trackProgressSlider.visualPosition * parent.width
                                    height: parent.height
                                    color: theme.accentCyan
                                    radius: 3
                                }
                            }

                            handle: Rectangle {
                                x: trackProgressSlider.leftPadding + trackProgressSlider.visualPosition * (trackProgressSlider.availableWidth - width)
                                y: trackProgressSlider.topPadding + trackProgressSlider.availableHeight / 2 - height / 2
                                implicitWidth: 18
                                implicitHeight: 18
                                radius: 9
                                color: trackProgressSlider.pressed ? theme.accentCyan : theme.textPrimary
                                border.color: theme.accentCyan
                                border.width: 2
                            }
                        }

                        // Tempo totale
                        Text {
                            text: backend.hasMedia ? backend.trackDurationFormatted : "00:00"
                            color: theme.textMuted
                            font.pixelSize: 13
                            font.bold: true
                            Layout.minimumWidth: 42
                        }
                    }

                    // 3. SOTTO ALLA SLIDING BAR: I VARI PULSANTI
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        // Libreria
                        Rectangle {
                            Layout.fillWidth: true
                            height: 44
                            radius: theme.radiusMedium
                            color: libClassicArea.pressed ? theme.surfaceBorder : theme.surfaceElevated
                            border.color: theme.surfaceBorder

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 6
                                MaterialIcon {
                                    name: "library_music"
                                    size: 18
                                    iconColor: theme.accentCyan
                                }
                                Text {
                                    text: "Libreria (" + backend.localMusicTracks.length + ")"
                                    color: theme.textPrimary
                                    font.pixelSize: 13
                                    font.bold: true
                                }
                            }

                            MouseArea {
                                id: libClassicArea
                                anchors.fill: parent
                                preventStealing: true
                                onClicked: backend.setMediaSubView("library")
                            }
                        }

                        // Mostra Testo (Lyrics)
                        Rectangle {
                            Layout.fillWidth: true
                            height: 44
                            radius: theme.radiusMedium
                            color: lyricsClassicArea.pressed ? theme.surfaceBorder : (backend.hasLyrics ? Qt.rgba(0, 0.898, 1, 0.15) : theme.surfaceElevated)
                            border.color: backend.hasLyrics ? theme.accentCyan : theme.surfaceBorder

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 6
                                MaterialIcon {
                                    name: "lyrics"
                                    size: 18
                                    iconColor: backend.hasLyrics ? theme.accentCyan : theme.textMuted
                                }
                                Text {
                                    text: backend.hasLyrics ? "Mostra Testo" : "Testo (N/D)"
                                    color: backend.hasLyrics ? theme.accentCyan : theme.textMuted
                                    font.pixelSize: 13
                                    font.bold: true
                                }
                            }

                            MouseArea {
                                id: lyricsClassicArea
                                anchors.fill: parent
                                preventStealing: true
                                onClicked: {
                                    mediaViewRoot.showLyrics = true;
                                }
                            }
                        }

                        // Cronologia
                        Rectangle {
                            Layout.fillWidth: true
                            height: 44
                            radius: theme.radiusMedium
                            color: histClassicArea.pressed ? theme.surfaceBorder : theme.surfaceElevated
                            border.color: theme.surfaceBorder

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 6
                                MaterialIcon {
                                    name: "history"
                                    size: 18
                                    iconColor: theme.accentCyan
                                }
                                Text {
                                    text: "Cronologia (" + backend.mediaHistoryList.length + ")"
                                    color: theme.textPrimary
                                    font.pixelSize: 13
                                    font.bold: true
                                }
                            }

                            MouseArea {
                                id: histClassicArea
                                anchors.fill: parent
                                preventStealing: true
                                onClicked: backend.setMediaSubView("history")
                            }
                        }
                    }
                }
            }

            // ----------------------------------------------------------------
            // MODALITÀ B: PLAYER AFFIANCATO CON LYRICS (Testo attivato)
            // ----------------------------------------------------------------
            Item {
                id: splitLyricsPlayer
                anchors.fill: parent
                visible: mediaViewRoot.showLyrics

                // LATO SINISTRO (Larghezza fissa 320px): Copertina, Scritte, Comandi e Scorciatoie
                Item {
                    id: leftPlayerColumn
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 320

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 8

                        // 1. Immagine compatta (140x140)
                        Rectangle {
                            Layout.preferredWidth: 140
                            Layout.preferredHeight: 140
                            Layout.alignment: Qt.AlignHCenter
                            radius: theme.radiusLarge
                            color: theme.surfaceElevated
                            border.color: backend.isPlaying ? theme.accentCyan : theme.surfaceBorder
                            border.width: backend.isPlaying ? 2 : 1
                            clip: true

                            Image {
                                anchors.fill: parent
                                anchors.margins: 2
                                source: backend.currentTrackCover
                                fillMode: Image.PreserveAspectCrop
                                visible: backend.currentTrackCover !== ""
                            }

                            MaterialIcon {
                                anchors.centerIn: parent
                                visible: backend.currentTrackCover === ""
                                name: backend.hasMedia ? (backend.isPlaying ? "graphic_eq" : "music_note") : "music_off"
                                size: 54
                                iconColor: backend.hasMedia ? theme.accentCyan : theme.textMuted
                                opacity: backend.hasMedia ? 1.0 : 0.35
                            }

                            // Playing indicator badge
                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.right: parent.right
                                anchors.margins: 6
                                width: 24
                                height: 24
                                radius: 12
                                color: Qt.rgba(0, 0, 0, 0.75)
                                border.color: theme.accentCyan
                                visible: backend.hasMedia && backend.isPlaying

                                MaterialIcon {
                                    anchors.centerIn: parent
                                    name: "play_arrow"
                                    size: 14
                                    iconColor: theme.accentCyan
                                }
                            }
                        }

                        // 2. Scritte
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 2

                            Text {
                                text: backend.hasMedia ? backend.trackTitle : "Nessun flusso audio attivo"
                                color: backend.hasMedia ? theme.textPrimary : theme.textSecondary
                                font.pixelSize: 16
                                font.bold: true
                                elide: Text.ElideRight
                                horizontalAlignment: Text.AlignHCenter
                                Layout.fillWidth: true
                            }

                            Text {
                                text: backend.hasMedia ? backend.trackArtist : backend.bluetoothDeviceName
                                color: theme.accentCyan
                                font.pixelSize: 13
                                font.bold: true
                                elide: Text.ElideRight
                                horizontalAlignment: Text.AlignHCenter
                                Layout.fillWidth: true
                            }

                            RowLayout {
                                Layout.alignment: Qt.AlignHCenter
                                spacing: 8

                                Text {
                                    text: backend.hasMedia ? backend.trackAlbum : "Libreria Raspberry Pi"
                                    color: theme.textMuted
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                    visible: text !== ""
                                }

                                Rectangle {
                                    id: splitSrcBadge
                                    implicitWidth: splitSrcBadgeRow.implicitWidth + 14
                                    implicitHeight: 20
                                    radius: 10
                                    color: splitSrcBadgeMouse.pressed ? Qt.rgba(255, 255, 255, 0.14) : (splitSrcBadgeMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.09) : Qt.rgba(255, 255, 255, 0.06))
                                    border.color: splitSrcBadgeMouse.containsMouse ? theme.accentCyan : theme.surfaceBorder

                                    Row {
                                        id: splitSrcBadgeRow
                                        anchors.centerIn: parent
                                        spacing: 4

                                        MaterialIcon {
                                            anchors.verticalCenter: parent.verticalCenter
                                            name: backend.mediaSource === "local" ? "library_music" : "bluetooth"
                                            size: 11
                                            iconColor: backend.hasMedia ? theme.accentCyan : theme.accentRed
                                        }

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: backend.hasMedia ? (backend.mediaSource === "local" ? "LIBRERIA LOCALE" : "BLUETOOTH AUDIO") : (backend.mediaSource === "local" ? "LIBRERIA" : "BLUETOOTH")
                                            color: backend.hasMedia ? theme.textSecondary : theme.accentRed
                                            font.pixelSize: 9
                                            font.bold: true
                                        }

                                        MaterialIcon {
                                            anchors.verticalCenter: parent.verticalCenter
                                            name: "swap_horiz"
                                            size: 12
                                            iconColor: splitSrcBadgeMouse.containsMouse ? theme.accentCyan : theme.textMuted
                                        }
                                    }

                                    MouseArea {
                                        id: splitSrcBadgeMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            backend.toggleMediaSource()
                                        }
                                    }
                                }
                            }
                        }

                        Item { Layout.fillHeight: true }

                        // 3. Comandi di Trasporto Compatti
                        Row {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 16
                            opacity: backend.hasMedia ? 1.0 : 0.4

                            Rectangle {
                                width: 48
                                height: 48
                                radius: 24
                                color: theme.surfaceDark
                                border.color: theme.surfaceBorder

                                MaterialIcon {
                                    anchors.centerIn: parent
                                    name: "skip_previous"
                                    size: 20
                                    iconColor: theme.textPrimary
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    preventStealing: true
                                    enabled: backend.hasMedia
                                    onClicked: backend.previousTrack()
                                }
                            }

                            Rectangle {
                                width: 60
                                height: 60
                                radius: 30
                                color: backend.hasMedia ? theme.accentCyan : theme.surfaceElevated

                                MaterialIcon {
                                    anchors.centerIn: parent
                                    name: backend.isPlaying ? "pause" : "play_arrow"
                                    size: 28
                                    iconColor: backend.hasMedia ? theme.bgDark : theme.textMuted
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    preventStealing: true
                                    enabled: backend.hasMedia
                                    onClicked: backend.togglePlay()
                                }
                            }

                            Rectangle {
                                width: 48
                                height: 48
                                radius: 24
                                color: theme.surfaceDark
                                border.color: theme.surfaceBorder

                                MaterialIcon {
                                    anchors.centerIn: parent
                                    name: "skip_next"
                                    size: 20
                                    iconColor: theme.textPrimary
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    preventStealing: true
                                    enabled: backend.hasMedia
                                    onClicked: backend.nextTrack()
                                }
                            }
                        }

                        // Piccola barra di avanzamento traccia sotto i controlli
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: backend.hasMedia ? backend.trackPositionFormatted : "00:00"
                                color: theme.textSecondary
                                font.pixelSize: 11
                                font.bold: true
                                Layout.minimumWidth: 32
                                horizontalAlignment: Text.AlignRight
                            }

                            Slider {
                                id: splitTrackProgressSlider
                                Layout.fillWidth: true
                                from: 0.0
                                to: 1.0
                                value: pressed ? value : backend.trackProgress
                                enabled: backend.hasMedia

                                onMoved: {
                                    backend.seekProgress(value)
                                }

                                background: Rectangle {
                                    x: splitTrackProgressSlider.leftPadding
                                    y: splitTrackProgressSlider.topPadding + splitTrackProgressSlider.availableHeight / 2 - height / 2
                                    implicitWidth: 100
                                    implicitHeight: 4
                                    width: splitTrackProgressSlider.availableWidth
                                    height: implicitHeight
                                    radius: 2
                                    color: theme.surfaceElevated
                                    border.color: theme.surfaceBorder

                                    Rectangle {
                                        width: splitTrackProgressSlider.visualPosition * parent.width
                                        height: parent.height
                                        color: theme.accentCyan
                                        radius: 2
                                    }
                                }

                                handle: Rectangle {
                                    x: splitTrackProgressSlider.leftPadding + splitTrackProgressSlider.visualPosition * (splitTrackProgressSlider.availableWidth - width)
                                    y: splitTrackProgressSlider.topPadding + splitTrackProgressSlider.availableHeight / 2 - height / 2
                                    implicitWidth: 14
                                    implicitHeight: 14
                                    radius: 7
                                    color: splitTrackProgressSlider.pressed ? theme.accentCyan : theme.textPrimary
                                    border.color: theme.accentCyan
                                    border.width: 1.5
                                }
                            }

                            Text {
                                text: backend.hasMedia ? backend.trackDurationFormatted : "00:00"
                                color: theme.textMuted
                                font.pixelSize: 11
                                font.bold: true
                                Layout.minimumWidth: 32
                            }
                        }

                        Item { Layout.fillHeight: true }

                        // 4. Pulsanti Rapidi (Libreria, Cronologia, Nascondi Testo)
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Rectangle {
                                Layout.fillWidth: true
                                height: 42
                                radius: theme.radiusMedium
                                color: libSplitArea.pressed ? theme.surfaceBorder : theme.surfaceElevated
                                border.color: theme.surfaceBorder

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 4
                                    MaterialIcon {
                                        name: "library_music"
                                        size: 16
                                        iconColor: theme.accentCyan
                                    }
                                    Text {
                                        text: "Libreria (" + backend.localMusicTracks.length + ")"
                                        color: theme.textPrimary
                                        font.pixelSize: 11
                                        font.bold: true
                                    }
                                }

                                MouseArea {
                                    id: libSplitArea
                                    anchors.fill: parent
                                    onClicked: backend.setMediaSubView("library")
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 42
                                radius: theme.radiusMedium
                                color: histSplitArea.pressed ? theme.surfaceBorder : theme.surfaceElevated
                                border.color: theme.surfaceBorder

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 4
                                    MaterialIcon {
                                        name: "history"
                                        size: 16
                                        iconColor: theme.accentCyan
                                    }
                                    Text {
                                        text: "Cronologia (" + backend.mediaHistoryList.length + ")"
                                        color: theme.textPrimary
                                        font.pixelSize: 11
                                        font.bold: true
                                    }
                                }

                                MouseArea {
                                    id: histSplitArea
                                    anchors.fill: parent
                                    onClicked: backend.setMediaSubView("history")
                                }
                            }

                            // Pulsante disattiva testo
                            Rectangle {
                                width: 42
                                height: 42
                                radius: theme.radiusMedium
                                color: hideLyricsArea.pressed ? theme.surfaceBorder : Qt.rgba(0, 0.898, 1, 0.12)
                                border.color: theme.accentCyan

                                MaterialIcon {
                                    anchors.centerIn: parent
                                    name: "close"
                                    size: 18
                                    iconColor: theme.accentCyan
                                }

                                MouseArea {
                                    id: hideLyricsArea
                                    anchors.fill: parent
                                    onClicked: mediaViewRoot.showLyrics = false
                                }
                            }
                        }
                    }
                }

                // LATO DESTRO: La Lyrics (occupa tutto lo spazio rimanente)
                Rectangle {
                    id: rightLyricsPanel
                    anchors.left: leftPlayerColumn.right
                    anchors.leftMargin: 16
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    radius: theme.radiusLarge
                    color: theme.surfaceDark
                    border.color: backend.hasLyrics ? Qt.rgba(0, 0.898, 1, 0.25) : theme.surfaceBorder
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 10

                        // Header Barra Lyrics
                        RowLayout {
                            Layout.fillWidth: true

                            Row {
                                spacing: 8
                                MaterialIcon {
                                    name: "lyrics"
                                    size: 20
                                    iconColor: backend.hasLyrics ? theme.accentCyan : theme.textMuted
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: "TESTO DELLA CANZONE"
                                    color: backend.hasLyrics ? theme.accentCyan : theme.textMuted
                                    font.pixelSize: 13
                                    font.bold: true
                                    font.letterSpacing: 1
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            Item { Layout.fillWidth: true }

                            // Badge sorgente
                            Rectangle {
                                implicitWidth: srcPillText.contentWidth + 14
                                implicitHeight: 26
                                radius: 13
                                color: Qt.rgba(255, 255, 255, 0.06)
                                border.color: theme.surfaceBorder

                                Text {
                                    id: srcPillText
                                    anchors.centerIn: parent
                                    text: backend.hasMedia ? (backend.mediaSource === "local" ? "LIBRERIA LOCALE" : "BLUETOOTH AUDIO") : "DISCONNESSO"
                                    color: backend.hasMedia ? theme.textSecondary : theme.accentRed
                                    font.pixelSize: 11
                                    font.bold: true
                                }
                            }

                            // Pulsante Chiudi Testo nell'header
                            Rectangle {
                                implicitWidth: closeHeaderRow.width + 16
                                implicitHeight: 28
                                radius: 14
                                color: closeHeaderArea.pressed ? theme.accentCyan : Qt.rgba(255, 255, 255, 0.08)
                                border.color: theme.surfaceBorder

                                Row {
                                    id: closeHeaderRow
                                    anchors.centerIn: parent
                                    spacing: 5
                                    MaterialIcon {
                                        name: "close"
                                        size: 16
                                        iconColor: theme.textPrimary
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Text {
                                        text: "Chiudi"
                                        color: theme.textPrimary
                                        font.pixelSize: 11
                                        font.bold: true
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                MouseArea {
                                    id: closeHeaderArea
                                    anchors.fill: parent
                                    onClicked: mediaViewRoot.showLyrics = false
                                }
                            }
                        }

                        // Separatore
                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: theme.surfaceBorder
                        }

                        // Contenuto Lyrics Scorrevole o Stato Vuoto
                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            // Testo Presente
                            Flickable {
                                id: lyricsFlickable
                                anchors.fill: parent
                                contentWidth: width
                                contentHeight: lyricsTextDisplay.height + 30
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds
                                visible: backend.hasLyrics && backend.currentTrackLyrics !== ""

                                ScrollBar.vertical: ScrollBar {
                                    active: true
                                    policy: ScrollBar.AsNeeded
                                }

                                Text {
                                    id: lyricsTextDisplay
                                    width: parent.width - 24
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: backend.currentTrackLyrics
                                    color: theme.textPrimary
                                    font.pixelSize: 16
                                    font.letterSpacing: 0.4
                                    lineHeight: 1.65
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.WordWrap
                                }
                            }

                            // Stato Vuoto (Senza Testo)
                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 10
                                visible: !backend.hasLyrics || backend.currentTrackLyrics === ""

                                MaterialIcon {
                                    Layout.alignment: Qt.AlignHCenter
                                    name: "lyrics"
                                    size: 44
                                    iconColor: theme.textMuted
                                    opacity: 0.3
                                }

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: backend.hasMedia ? "Nessun testo disponibile per questa traccia" : "Nessun flusso audio in riproduzione"
                                    color: theme.textSecondary
                                    font.pixelSize: 15
                                    font.bold: true
                                }

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: backend.hasMedia ? "I testi possono essere inseriti nella cartella music/ come file .lrc o nel file .json del brano." : "Seleziona una canzone dalla Libreria Raspberry o connetti un dispositivo Bluetooth."
                                    color: theme.textMuted
                                    font.pixelSize: 12
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }
                    }
                }
            }
        }

        // ====================================================================
        // 2. SUB-VIEW: LOCAL MUSIC LIBRARY (Libreria Raspberry)
        // ====================================================================
        Item {
            id: librarySubView

            ColumnLayout {
                anchors.fill: parent
                spacing: 12

                // Header Bar with Back Button
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14

                    // Back to Player
                    Rectangle {
                        implicitWidth: backLibRow.width + 22
                        implicitHeight: 42
                        radius: theme.radiusMedium
                        color: backLibArea.pressed ? theme.surfaceBorder : theme.surfaceElevated
                        border.color: theme.surfaceBorder

                        Row {
                            id: backLibRow
                            anchors.centerIn: parent
                            spacing: 8
                            MaterialIcon {
                                name: "arrow_back"
                                size: 20
                                iconColor: theme.accentCyan
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: "Torna al Player"
                                color: theme.textPrimary
                                font.pixelSize: 13
                                font.bold: true
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: backLibArea
                            anchors.fill: parent
                            onClicked: backend.setMediaSubView("player")
                        }
                    }

                    Text {
                        text: "Libreria Locale Raspberry Pi (" + backend.localMusicTracks.length + " brani in music/)"
                        color: theme.textSecondary
                        font.pixelSize: 14
                        Layout.fillWidth: true
                    }

                    // Rescan Button
                    Rectangle {
                        implicitWidth: rescanRow.width + 20
                        implicitHeight: 42
                        radius: theme.radiusMedium
                        color: rescanArea.pressed ? theme.surfaceBorder : theme.surfaceElevated
                        border.color: theme.surfaceBorder

                        Row {
                            id: rescanRow
                            anchors.centerIn: parent
                            spacing: 6
                            MaterialIcon {
                                name: "refresh"
                                size: 18
                                iconColor: theme.textPrimary
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: "Ricarica"
                                color: theme.textPrimary
                                font.pixelSize: 13
                                font.bold: true
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: rescanArea
                            anchors.fill: parent
                            onClicked: backend.scanLocalMusic()
                        }
                    }
                }

                // Empty State (Zero Dummy Data)
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: theme.radiusMedium
                    color: theme.surfaceDark
                    border.color: theme.surfaceBorder
                    visible: backend.localMusicTracks.length === 0

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 12

                        MaterialIcon {
                            Layout.alignment: Qt.AlignHCenter
                            name: "folder_open"
                            size: 54
                            iconColor: theme.textMuted
                        }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "Nessun brano trovato nella cartella music/"
                            color: theme.textPrimary
                            font.pixelSize: 16
                            font.bold: true
                        }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "Copia file audio (.mp3, .wav, .flac) con eventuali copertine e testi nella cartella music/ del Raspberry."
                            color: theme.textMuted
                            font.pixelSize: 13
                        }
                    }
                }

                // Local Music Tracks ListView
                ListView {
                    id: libraryListView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    visible: backend.localMusicTracks.length > 0
                    model: backend.localMusicTracks
                    spacing: 8
                    boundsBehavior: Flickable.StopAtBounds

                    ScrollBar.vertical: ScrollBar {
                        active: true
                        policy: ScrollBar.AsNeeded
                    }

                    delegate: Rectangle {
                        width: libraryListView.width
                        height: 66
                        radius: theme.radiusMedium
                        color: {
                            var isCurrent = (backend.hasMedia && backend.trackTitle === modelData.title);
                            if (isCurrent) return Qt.rgba(0, 0.898, 1, 0.12);
                            return itemMouseArea.pressed ? theme.surfaceBorder : theme.surfaceElevated;
                        }
                        border.color: {
                            var isCurrent = (backend.hasMedia && backend.trackTitle === modelData.title);
                            return isCurrent ? theme.accentCyan : theme.surfaceBorder;
                        }
                        border.width: (backend.hasMedia && backend.trackTitle === modelData.title) ? 1.5 : 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 14

                            // Cover Thumbnail
                            Rectangle {
                                width: 44
                                height: 44
                                radius: 8
                                color: theme.surfaceDark
                                border.color: theme.surfaceBorder
                                clip: true

                                Image {
                                    anchors.fill: parent
                                    source: modelData.cover_url || ""
                                    fillMode: Image.PreserveAspectCrop
                                    visible: Boolean(modelData.has_cover)
                                }

                                MaterialIcon {
                                    anchors.centerIn: parent
                                    visible: !modelData.has_cover
                                    name: "music_note"
                                    size: 24
                                    iconColor: theme.accentCyan
                                }
                            }

                            // Title & Artist
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                RowLayout {
                                    spacing: 8
                                    Text {
                                        text: modelData.title
                                        color: (backend.hasMedia && backend.trackTitle === modelData.title) ? theme.accentCyan : theme.textPrimary
                                        font.pixelSize: 15
                                        font.bold: true
                                        elide: Text.ElideRight
                                    }

                                    // Currently Playing animated indicator
                                    Rectangle {
                                        visible: backend.hasMedia && backend.trackTitle === modelData.title && backend.isPlaying
                                        implicitWidth: nowPlayingBadge.width + 12
                                        implicitHeight: 20
                                        radius: 10
                                        color: theme.accentCyan

                                        Row {
                                            id: nowPlayingBadge
                                            anchors.centerIn: parent
                                            spacing: 4
                                            MaterialIcon {
                                                name: "graphic_eq"
                                                size: 14
                                                iconColor: theme.bgDark
                                            }
                                            Text {
                                                text: "IN RIPRODUZIONE"
                                                color: theme.bgDark
                                                font.pixelSize: 9
                                                font.bold: true
                                            }
                                        }
                                    }
                                }

                                Text {
                                    text: modelData.artist + (modelData.album ? " • " + modelData.album : "")
                                    color: theme.textSecondary
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            // Lyrics badge button
                            Rectangle {
                                visible: Boolean(modelData.has_lyrics)
                                implicitWidth: 32
                                implicitHeight: 32
                                radius: 16
                                color: lyricsBadgeArea.pressed ? theme.accentCyan : Qt.rgba(0, 0.898, 1, 0.15)
                                border.color: theme.accentCyan
                                z: 2

                                MaterialIcon {
                                    anchors.centerIn: parent
                                    name: "lyrics"
                                    size: 18
                                    iconColor: lyricsBadgeArea.pressed ? theme.bgDark : theme.accentCyan
                                }

                                MouseArea {
                                    id: lyricsBadgeArea
                                    anchors.fill: parent
                                    onClicked: {
                                        backend.playLocalTrack(modelData.file_path);
                                        mediaViewRoot.showLyrics = true;
                                        backend.setMediaSubView("player");
                                    }
                                }
                            }

                            // Duration
                            Text {
                                text: modelData.duration || "00:00"
                                color: theme.textMuted
                                font.pixelSize: 13
                            }

                            // Play icon button
                            Rectangle {
                                width: 36
                                height: 36
                                radius: 18
                                color: (backend.hasMedia && backend.trackTitle === modelData.title) ? theme.accentCyan : theme.surfaceDark
                                border.color: theme.surfaceBorder

                                MaterialIcon {
                                    anchors.centerIn: parent
                                    name: (backend.hasMedia && backend.trackTitle === modelData.title && backend.isPlaying) ? "pause" : "play_arrow"
                                    size: 20
                                    iconColor: (backend.hasMedia && backend.trackTitle === modelData.title) ? theme.bgDark : theme.textPrimary
                                }
                            }
                        }

                        MouseArea {
                            id: itemMouseArea
                            anchors.fill: parent
                            onClicked: {
                                if (backend.hasMedia && backend.trackTitle === modelData.title) {
                                    backend.togglePlay();
                                } else {
                                    backend.playLocalTrack(modelData.file_path);
                                }
                                backend.setMediaSubView("player");
                            }
                        }
                    }
                }
            }
        }

        // ====================================================================
        // 3. SUB-VIEW: COMPLETE LISTENING HISTORY (Cronologia Ascolti)
        // ====================================================================
        Item {
            id: historySubView

            ColumnLayout {
                anchors.fill: parent
                spacing: 12

                // Header Bar with Back Button & Filters
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14

                    // Back to Player
                    Rectangle {
                        implicitWidth: backHistRow.width + 22
                        implicitHeight: 42
                        radius: theme.radiusMedium
                        color: backHistArea.pressed ? theme.surfaceBorder : theme.surfaceElevated
                        border.color: theme.surfaceBorder

                        Row {
                            id: backHistRow
                            anchors.centerIn: parent
                            spacing: 8
                            MaterialIcon {
                                name: "arrow_back"
                                size: 20
                                iconColor: theme.accentCyan
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: "Torna al Player"
                                color: theme.textPrimary
                                font.pixelSize: 13
                                font.bold: true
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: backHistArea
                            anchors.fill: parent
                            onClicked: backend.setMediaSubView("player")
                        }
                    }

                    // Filter Pills: Tutte / Completate / Parziali
                    Row {
                        spacing: 8

                        Rectangle {
                            width: filterAllText.contentWidth + 18
                            height: 34
                            radius: 17
                            color: mediaViewRoot.historyFilter === "all" ? theme.accentCyan : theme.surfaceElevated
                            border.color: mediaViewRoot.historyFilter === "all" ? theme.accentCyan : theme.surfaceBorder

                            Text {
                                id: filterAllText
                                anchors.centerIn: parent
                                text: "Tutte (" + backend.mediaHistoryList.length + ")"
                                color: mediaViewRoot.historyFilter === "all" ? theme.bgDark : theme.textSecondary
                                font.pixelSize: 12
                                font.bold: true
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: mediaViewRoot.historyFilter = "all"
                            }
                        }

                        Rectangle {
                            width: filterCompText.contentWidth + 18
                            height: 34
                            radius: 17
                            color: mediaViewRoot.historyFilter === "completed" ? theme.accentGreen : theme.surfaceElevated
                            border.color: mediaViewRoot.historyFilter === "completed" ? theme.accentGreen : theme.surfaceBorder

                            Text {
                                id: filterCompText
                                anchors.centerIn: parent
                                text: "Completate"
                                color: mediaViewRoot.historyFilter === "completed" ? theme.bgDark : theme.textSecondary
                                font.pixelSize: 12
                                font.bold: true
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: mediaViewRoot.historyFilter = "completed"
                            }
                        }

                        Rectangle {
                            width: filterPartText.contentWidth + 18
                            height: 34
                            radius: 17
                            color: mediaViewRoot.historyFilter === "partial" ? theme.accentYellow : theme.surfaceElevated
                            border.color: mediaViewRoot.historyFilter === "partial" ? theme.accentYellow : theme.surfaceBorder

                            Text {
                                id: filterPartText
                                anchors.centerIn: parent
                                text: "Saltate / Parziali"
                                color: mediaViewRoot.historyFilter === "partial" ? theme.bgDark : theme.textSecondary
                                font.pixelSize: 12
                                font.bold: true
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: mediaViewRoot.historyFilter = "partial"
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Refresh History Button
                    Rectangle {
                        implicitWidth: refHistRow.width + 20
                        implicitHeight: 42
                        radius: theme.radiusMedium
                        color: refHistArea.pressed ? theme.surfaceBorder : theme.surfaceElevated
                        border.color: theme.surfaceBorder

                        Row {
                            id: refHistRow
                            anchors.centerIn: parent
                            spacing: 6
                            MaterialIcon {
                                name: "refresh"
                                size: 18
                                iconColor: theme.textPrimary
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: "Aggiorna"
                                color: theme.textPrimary
                                font.pixelSize: 13
                                font.bold: true
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: refHistArea
                            anchors.fill: parent
                            onClicked: backend.refreshMediaHistory()
                        }
                    }
                }

                // Empty History State
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: theme.radiusMedium
                    color: theme.surfaceDark
                    border.color: theme.surfaceBorder
                    visible: backend.mediaHistoryList.length === 0

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 12

                        MaterialIcon {
                            Layout.alignment: Qt.AlignHCenter
                            name: "history_toggle_off"
                            size: 54
                            iconColor: theme.textMuted
                        }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "Nessun ascolto registrato"
                            color: theme.textPrimary
                            font.pixelSize: 16
                            font.bold: true
                        }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "Riproduci brani da Bluetooth o dalla Libreria Raspberry per iniziare a popolare la cronologia."
                            color: theme.textMuted
                            font.pixelSize: 13
                        }
                    }
                }

                // Unified Continuous History ListView (Non suddiviso per file)
                ListView {
                    id: historyListView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    visible: backend.mediaHistoryList.length > 0
                    spacing: 8
                    boundsBehavior: Flickable.StopAtBounds

                    model: {
                        var list = backend.mediaHistoryList;
                        if (mediaViewRoot.historyFilter === "completed") {
                            return list.filter(function(item) { return item.completed === true; });
                        }
                        if (mediaViewRoot.historyFilter === "partial") {
                            return list.filter(function(item) { return item.completed !== true; });
                        }
                        return list;
                    }

                    ScrollBar.vertical: ScrollBar {
                        active: true
                        policy: ScrollBar.AsNeeded
                    }

                    delegate: Rectangle {
                        width: historyListView.width
                        height: 68
                        radius: theme.radiusMedium
                        color: theme.surfaceElevated
                        border.color: theme.surfaceBorder
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 14

                            // Date & Time Badge
                            Rectangle {
                                width: 72
                                height: 46
                                radius: 10
                                color: theme.surfaceDark
                                border.color: theme.surfaceBorder

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 1

                                    Text {
                                        text: modelData.date_str || "Oggi"
                                        color: theme.textPrimary
                                        font.pixelSize: 11
                                        font.bold: true
                                        horizontalAlignment: Text.AlignHCenter
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }
                                    Text {
                                        text: modelData.time_str || "00:00"
                                        color: theme.textMuted
                                        font.pixelSize: 10
                                        horizontalAlignment: Text.AlignHCenter
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }
                                }
                            }

                            // Title & Artist
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4

                                Text {
                                    text: modelData.title
                                    color: theme.textPrimary
                                    font.pixelSize: 14
                                    font.bold: true
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                RowLayout {
                                    spacing: 12

                                    Text {
                                        text: modelData.artist + (modelData.album ? " • " + modelData.album : "")
                                        color: theme.textSecondary
                                        font.pixelSize: 11
                                        elide: Text.ElideRight
                                    }

                                    // Duration details: listened vs total
                                    Text {
                                        text: "Ascoltato: " + modelData.listened_time + " / " + modelData.duration
                                        color: theme.textMuted
                                        font.pixelSize: 11
                                    }
                                }

                                // Progress bar
                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 3
                                    radius: 1.5
                                    color: theme.surfaceDark

                                    Rectangle {
                                        width: parent.width * Math.min(1.0, Math.max(0.0, (modelData.progress_percent || 0.0) / 100.0))
                                        height: parent.height
                                        radius: 1.5
                                        color: {
                                            if (modelData.completed) return theme.accentGreen;
                                            if (modelData.status && modelData.status.indexOf("In riproduzione") !== -1) return theme.accentCyan;
                                            return theme.accentYellow;
                                        }
                                    }
                                }
                            }

                            // Status Pill
                            Rectangle {
                                implicitWidth: statusText.contentWidth + 16
                                implicitHeight: 28
                                radius: 14
                                color: {
                                    if (modelData.completed) return Qt.rgba(0, 0.9, 0.46, 0.12);
                                    if (modelData.status && modelData.status.indexOf("In riproduzione") !== -1) return Qt.rgba(0, 0.898, 1, 0.12);
                                    if (modelData.status && modelData.status.indexOf("In pausa") !== -1) return Qt.rgba(1, 0.7, 0, 0.12);
                                    return Qt.rgba(1, 1, 1, 0.05);
                                }
                                border.color: {
                                    if (modelData.completed) return theme.accentGreen;
                                    if (modelData.status && modelData.status.indexOf("In riproduzione") !== -1) return theme.accentCyan;
                                    if (modelData.status && modelData.status.indexOf("In pausa") !== -1) return theme.accentYellow;
                                    return theme.surfaceBorder;
                                }

                                Text {
                                    id: statusText
                                    anchors.centerIn: parent
                                    text: modelData.status || (modelData.completed ? "Completata" : "Ascoltata")
                                    color: {
                                        if (modelData.completed) return theme.accentGreen;
                                        if (modelData.status && modelData.status.indexOf("In riproduzione") !== -1) return theme.accentCyan;
                                        if (modelData.status && modelData.status.indexOf("In pausa") !== -1) return theme.accentYellow;
                                        return theme.textMuted;
                                    }
                                    font.pixelSize: 11
                                    font.bold: true
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
