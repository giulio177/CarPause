import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Rectangle {
    id: mapRoot
    Layout.fillWidth: true
    Layout.fillHeight: true
    color: "#080C14"
    clip: true

    // ========================================================================
    // MAP PROJECTION & COORDINATE LOGIC (Slippy Map Tile System)
    // ========================================================================
    readonly property real viewWidth: width > 0 ? width : 1024
    readonly property real viewHeight: height > 0 ? height : 516
    readonly property real centerX: viewWidth / 2.0
    readonly property real centerY: viewHeight / 2.0

    readonly property real currentLat: backend.mapCenterLat
    readonly property real currentLon: backend.mapCenterLon
    readonly property int currentZoom: backend.mapZoom
    readonly property string currentTheme: backend.mapTheme

    // Interactive Touch Pan Offsets
    property real dragOffsetX: 0.0
    property real dragOffsetY: 0.0
    property real dragStartX: 0.0
    property real dragStartY: 0.0
    property bool isDragging: false

    // Search Drawer UI State
    property bool searchOpen: false
    property string destinationName: ""
    property real destinationLat: 0.0
    property real destinationLon: 0.0
    property bool hasDestination: false

    // Mathematical conversions
    function latToY(lat, zoom) {
        var latRad = lat * Math.PI / 180.0;
        latRad = Math.max(Math.min(latRad, 1.4844), -1.4844);
        var n = Math.pow(2, zoom);
        return (1.0 - Math.log(Math.tan(latRad) + 1.0 / Math.cos(latRad)) / Math.PI) / 2.0 * n;
    }

    function lonToX(lon, zoom) {
        var n = Math.pow(2, zoom);
        return (lon + 180.0) / 360.0 * n;
    }

    function xToLon(x, zoom) {
        var n = Math.pow(2, zoom);
        return x / n * 360.0 - 180.0;
    }

    function yToLat(y, zoom) {
        var n = Math.pow(2, zoom);
        var latRad = Math.atan(Math.sinh(Math.PI * (1.0 - 2.0 * y / n)));
        return latRad * 180.0 / Math.PI;
    }

    // Dynamic fractional tile coordinates
    readonly property real liveCenterTileX: lonToX(currentLon, currentZoom) - (dragOffsetX / 256.0)
    readonly property real liveCenterTileY: latToY(currentLat, currentZoom) - (dragOffsetY / 256.0)

    // Base whole tile coordinates
    readonly property int maxTiles: Math.pow(2, currentZoom)
    readonly property int baseTileX: Math.floor(liveCenterTileX) - 2
    readonly property int baseTileY: Math.floor(liveCenterTileY) - 1

    // ========================================================================
    // 1. TILE GRID LAYER (24 tiles = 6 columns x 4 rows, covering 1024x516)
    // ========================================================================
    Item {
        id: tileCanvas
        anchors.fill: parent

        Repeater {
            model: 24 // 6 columns x 4 rows

            delegate: Item {
                readonly property int col: index % 6
                readonly property int row: Math.floor(index / 6)

                readonly property int rawX: mapRoot.baseTileX + col
                readonly property int rawY: mapRoot.baseTileY + row

                // Wrap longitude tile index around the world
                readonly property int tileX: ((rawX % mapRoot.maxTiles) + mapRoot.maxTiles) % mapRoot.maxTiles
                readonly property int tileY: rawY
                readonly property bool isValidTile: tileY >= 0 && tileY < mapRoot.maxTiles

                width: 256
                height: 256
                x: Math.round(mapRoot.centerX + (rawX - mapRoot.liveCenterTileX) * 256.0)
                y: Math.round(mapRoot.centerY + (rawY - mapRoot.liveCenterTileY) * 256.0)

                // Background tile placeholder (dark grid styling)
                Rectangle {
                    anchors.fill: parent
                    color: index % 2 === 0 ? "#0C111A" : "#0E1420"
                    border.color: Qt.rgba(1, 1, 1, 0.03)
                    border.width: 1
                }

                // Tile Image fetched from local proxy
                Image {
                    anchors.fill: parent
                    visible: isValidTile
                    asynchronous: true
                    cache: true
                    fillMode: Image.Stretch
                    source: isValidTile ? (backend.mapTileBaseUrl + "/" + mapRoot.currentTheme + "/" + mapRoot.currentZoom + "/" + tileX + "/" + tileY + ".png") : ""
                }
            }
        }
    }

    // ========================================================================
    // 2. MARKERS LAYER (Destination Pin & Vehicle Location)
    // ========================================================================
    Item {
        id: markersLayer
        anchors.fill: parent

        // Destination Marker
        Item {
            visible: mapRoot.hasDestination
            readonly property real destTileX: mapRoot.lonToX(mapRoot.destinationLon, mapRoot.currentZoom)
            readonly property real destTileY: mapRoot.latToY(mapRoot.destinationLat, mapRoot.currentZoom)

            x: Math.round(mapRoot.centerX + (destTileX - mapRoot.liveCenterTileX) * 256.0)
            y: Math.round(mapRoot.centerY + (destTileY - mapRoot.liveCenterTileY) * 256.0)

            Column {
                anchors.bottom: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 2

                Rectangle {
                    height: 26
                    width: destText.contentWidth + 18
                    radius: 13
                    color: "#D91438"
                    border.color: "#FFFFFF"
                    border.width: 1.5
                    anchors.horizontalCenter: parent.horizontalCenter

                    Text {
                        id: destText
                        anchors.centerIn: parent
                        text: mapRoot.destinationName || "Destinazione"
                        color: "#FFFFFF"
                        font.pixelSize: 12
                        font.bold: true
                    }
                }

                MaterialIcon {
                    name: "location_on"
                    size: 34
                    iconColor: "#FF2A55"
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }

        // Center Vehicle Navigation Marker (Fixed at screen center)
        Item {
            anchors.centerIn: parent
            width: 48
            height: 48

            // Outer Pulse Halo
            Rectangle {
                anchors.centerIn: parent
                width: 40
                height: 40
                radius: 20
                color: Qt.rgba(0.0, 0.898, 1.0, 0.22)
                border.color: theme.accentCyan
                border.width: 1.5

                SequentialAnimation on scale {
                    running: true
                    loops: Animation.Infinite
                    PropertyAnimation { from: 0.85; to: 1.25; duration: 1200; easing.type: Easing.InOutQuad }
                    PropertyAnimation { from: 1.25; to: 0.85; duration: 1200; easing.type: Easing.InOutQuad }
                }
            }

            // Inner Core Dot
            Rectangle {
                anchors.centerIn: parent
                width: 16
                height: 16
                radius: 8
                color: theme.accentCyan
                border.color: "#FFFFFF"
                border.width: 2.5
            }

            // Direction Arrow
            MaterialIcon {
                anchors.centerIn: parent
                name: "navigation"
                size: 20
                iconColor: "#080C14"
            }
        }
    }

    // ========================================================================
    // 3. MAP GESTURE TOUCH INTERACTION (Pan, Double Tap Zoom)
    // ========================================================================
    MouseArea {
        id: mapGestureArea
        anchors.fill: parent
        preventStealing: true
        enabled: !mapRoot.searchOpen

        onPressed: (mouse) => {
            mapRoot.dragStartX = mouse.x;
            mapRoot.dragStartY = mouse.y;
            mapRoot.isDragging = true;
        }

        onPositionChanged: (mouse) => {
            if (mapRoot.isDragging) {
                mapRoot.dragOffsetX = mouse.x - mapRoot.dragStartX;
                mapRoot.dragOffsetY = mouse.y - mapRoot.dragStartY;
            }
        }

        onReleased: {
            if (mapRoot.isDragging) {
                mapRoot.isDragging = false;
                if (Math.abs(mapRoot.dragOffsetX) > 2 || Math.abs(mapRoot.dragOffsetY) > 2) {
                    var newLon = mapRoot.xToLon(mapRoot.liveCenterTileX, mapRoot.currentZoom);
                    var newLat = mapRoot.yToLat(mapRoot.liveCenterTileY, mapRoot.currentZoom);
                    mapRoot.dragOffsetX = 0.0;
                    mapRoot.dragOffsetY = 0.0;
                    backend.setMapCenter(newLat, newLon);
                } else {
                    mapRoot.dragOffsetX = 0.0;
                    mapRoot.dragOffsetY = 0.0;
                }
            }
        }

        onDoubleClicked: {
            backend.zoomIn();
        }
    }

    // ========================================================================
    // 4. TOP FLOATING BAR: SEARCH BAR & QUICK PRESET CHIPS
    // ========================================================================
    Column {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 14
        spacing: 8
        z: 100

        // Search Bar Capsule
        Rectangle {
            id: searchCapsule
            width: Math.min(520, parent.width - 28)
            height: 44
            radius: 22
            color: Qt.rgba(14, 20, 32, 0.88)
            border.color: mapRoot.searchOpen ? theme.accentCyan : theme.surfaceBorder
            border.width: 1.5

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 12
                spacing: 10

                MaterialIcon {
                    name: "search"
                    size: 22
                    iconColor: mapRoot.searchOpen ? theme.accentCyan : theme.textSecondary
                }

                Text {
                    text: mapRoot.hasDestination ? mapRoot.destinationName : "Cerca destinazione o città..."
                    color: mapRoot.hasDestination ? theme.textPrimary : theme.textMuted
                    font.pixelSize: 14
                    font.bold: mapRoot.hasDestination
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                // Clear / Cancel button
                Rectangle {
                    visible: mapRoot.hasDestination
                    width: 28
                    height: 28
                    radius: 14
                    color: Qt.rgba(255, 255, 255, 0.1)

                    MaterialIcon {
                        anchors.centerIn: parent
                        name: "close"
                        size: 16
                        iconColor: theme.textSecondary
                    }

                    TapHandler {
                        onTapped: {
                            mapRoot.hasDestination = false;
                            mapRoot.destinationName = "";
                        }
                    }
                }
            }

            TapHandler {
                onTapped: {
                    mapRoot.searchOpen = !mapRoot.searchOpen;
                    if (mapRoot.searchOpen) {
                        searchField.forceActiveFocus();
                    }
                }
            }
        }

        // Quick Preset Chips (Rome, Milan, Naples, Turin)
        Row {
            spacing: 8
            visible: !mapRoot.searchOpen

            Repeater {
                model: backend.mapBookmarks

                delegate: Rectangle {
                    height: 30
                    width: chipRow.implicitWidth + 20
                    radius: 15
                    color: Qt.rgba(15, 22, 35, 0.82)
                    border.color: theme.surfaceBorder
                    border.width: 1

                    Row {
                        id: chipRow
                        anchors.centerIn: parent
                        spacing: 5

                        MaterialIcon {
                            name: modelData.icon || "place"
                            size: 14
                            iconColor: theme.accentCyan
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: modelData.name
                            color: theme.textPrimary
                            font.pixelSize: 12
                            font.bold: true
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    TapHandler {
                        margin: 6
                        onTapped: {
                            backend.setMapCenter(modelData.lat, modelData.lon);
                            mapRoot.destinationName = modelData.name;
                            mapRoot.destinationLat = modelData.lat;
                            mapRoot.destinationLon = modelData.lon;
                            mapRoot.hasDestination = true;
                        }
                    }
                }
            }
        }
    }

    // ========================================================================
    // 5. RIGHT FLOATING CONTROLS: ZOOM IN / OUT, THEME, RECENTER
    // ========================================================================
    Column {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: 14
        anchors.rightMargin: 14
        spacing: 10
        z: 100

        // Zoom In (+)
        Rectangle {
            width: 48
            height: 48
            radius: 24
            color: zoomInTap.pressed ? "#253248" : Qt.rgba(15, 22, 35, 0.90)
            border.color: theme.surfaceBorder
            border.width: 1.5

            MaterialIcon {
                anchors.centerIn: parent
                name: "add"
                size: 24
                iconColor: theme.textPrimary
            }

            TapHandler {
                id: zoomInTap
                margin: 8
                onTapped: backend.zoomIn()
            }
        }

        // Zoom Level Indicator Pill
        Rectangle {
            width: 48
            height: 26
            radius: 13
            color: Qt.rgba(10, 15, 24, 0.90)
            border.color: theme.surfaceBorder
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: backend.mapZoom + "x"
                color: theme.accentCyan
                font.pixelSize: 11
                font.bold: true
            }
        }

        // Zoom Out (-)
        Rectangle {
            width: 48
            height: 48
            radius: 24
            color: zoomOutTap.pressed ? "#253248" : Qt.rgba(15, 22, 35, 0.90)
            border.color: theme.surfaceBorder
            border.width: 1.5

            MaterialIcon {
                anchors.centerIn: parent
                name: "remove"
                size: 24
                iconColor: theme.textPrimary
            }

            TapHandler {
                id: zoomOutTap
                margin: 8
                onTapped: backend.zoomOut()
            }
        }

        // Map Style / Theme Switcher (Dark -> OSM -> Voyager)
        Rectangle {
            width: 48
            height: 48
            radius: 24
            color: themeTap.pressed ? "#253248" : Qt.rgba(15, 22, 35, 0.90)
            border.color: theme.surfaceBorder
            border.width: 1.5

            MaterialIcon {
                anchors.centerIn: parent
                name: "layers"
                size: 22
                iconColor: theme.accentGreen
            }

            TapHandler {
                id: themeTap
                margin: 8
                onTapped: backend.cycleMapTheme()
            }
        }

        // Recenter Button
        Rectangle {
            width: 48
            height: 48
            radius: 24
            color: recenterTap.pressed ? "#253248" : Qt.rgba(15, 22, 35, 0.90)
            border.color: theme.accentCyan
            border.width: 1.5

            MaterialIcon {
                anchors.centerIn: parent
                name: "my_location"
                size: 22
                iconColor: theme.accentCyan
            }

            TapHandler {
                id: recenterTap
                margin: 8
                onTapped: {
                    // Recenter on vehicle / default home position
                    backend.setMapCenter(41.8933, 12.4829);
                }
            }
        }
    }

    // ========================================================================
    // 6. BOTTOM-LEFT HUD: SPEEDOMETER & MAP ATTRIBUTION
    // ========================================================================
    Row {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.margins: 14
        spacing: 10
        z: 100

        // Real Vehicle Speed Pill (OBD-II Telemetry)
        Rectangle {
            height: 38
            width: speedCol.implicitWidth + 24
            radius: 19
            color: Qt.rgba(10, 15, 25, 0.88)
            border.color: backend.obdConnected ? theme.accentGreen : theme.surfaceBorder
            border.width: 1.5

            Row {
                id: speedCol
                anchors.centerIn: parent
                spacing: 6

                MaterialIcon {
                    name: "speed"
                    size: 18
                    iconColor: backend.obdConnected ? theme.accentGreen : theme.textMuted
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: backend.obdConnected ? backend.speedText : "-- km/h"
                    color: backend.obdConnected ? theme.textPrimary : theme.textMuted
                    font.pixelSize: 14
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        // Theme Badge & OSM attribution
        Rectangle {
            height: 28
            width: attrRow.implicitWidth + 16
            radius: 14
            color: Qt.rgba(10, 15, 25, 0.70)
            anchors.verticalCenter: parent.verticalCenter

            Row {
                id: attrRow
                anchors.centerIn: parent
                spacing: 5

                Text {
                    text: {
                        if (mapRoot.currentTheme === "dark") return "CARTO Dark (OSM)";
                        if (mapRoot.currentTheme === "voyager") return "CARTO Voyager";
                        return "OpenStreetMap";
                    }
                    color: Qt.rgba(1, 1, 1, 0.45)
                    font.pixelSize: 10
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    // ========================================================================
    // 7. SEARCH DRAWER OVERLAY (With Nominatim Results & Virtual Keyboard)
    // ========================================================================
    Rectangle {
        id: searchDrawer
        anchors.fill: parent
        color: Qt.rgba(8, 12, 20, 0.95)
        visible: mapRoot.searchOpen
        z: 200

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            // Top Bar: Search Input Field & Close Button
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    Layout.fillWidth: true
                    height: 48
                    radius: theme.radiusMedium
                    color: theme.surfaceElevated
                    border.color: theme.accentCyan
                    border.width: 1.5

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 8

                        MaterialIcon {
                            name: "search"
                            size: 22
                            iconColor: theme.accentCyan
                        }

                        TextInput {
                            id: searchField
                            Layout.fillWidth: true
                            color: theme.textPrimary
                            font.pixelSize: 16
                            font.bold: true
                            verticalAlignment: TextInput.AlignVCenter
                            clip: true

                            Text {
                                text: "Inserisci città, via o punto di interesse..."
                                color: theme.textMuted
                                font.pixelSize: 15
                                visible: !searchField.text
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            onAccepted: {
                                if (searchField.text.trim().length > 0) {
                                    backend.searchMap(searchField.text.trim());
                                }
                            }
                        }

                        // Search Action Button
                        Rectangle {
                            width: 34
                            height: 34
                            radius: 17
                            color: theme.accentCyan

                            MaterialIcon {
                                anchors.centerIn: parent
                                name: backend.mapSearching ? "sync" : "arrow_forward"
                                size: 18
                                iconColor: "#000000"
                                RotationAnimation on rotation {
                                    running: backend.mapSearching
                                    loops: Animation.Infinite
                                    from: 0; to: 360; duration: 1000
                                }
                            }

                            TapHandler {
                                onTapped: {
                                    if (searchField.text.trim().length > 0) {
                                        backend.searchMap(searchField.text.trim());
                                    }
                                }
                            }
                        }
                    }
                }

                // Close Drawer Button
                Rectangle {
                    width: 48
                    height: 48
                    radius: theme.radiusMedium
                    color: theme.surfaceElevated
                    border.color: theme.surfaceBorder
                    border.width: 1

                    MaterialIcon {
                        anchors.centerIn: parent
                        name: "close"
                        size: 24
                        iconColor: theme.textPrimary
                    }

                    TapHandler {
                        onTapped: {
                            mapRoot.searchOpen = false;
                            backend.clearMapSearch();
                        }
                    }
                }
            }

            // Results List
            ListView {
                id: resultsList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 6
                model: backend.mapSearchResults

                delegate: Rectangle {
                    width: resultsList.width
                    height: 52
                    radius: theme.radiusMedium
                    color: resultTap.pressed ? theme.surfaceBorder : theme.surfaceElevated
                    border.color: theme.surfaceBorder
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 12

                        MaterialIcon {
                            name: "place"
                            size: 22
                            iconColor: theme.accentCyan
                        }

                        Column {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                text: modelData.name || "Luogo"
                                color: theme.textPrimary
                                font.pixelSize: 14
                                font.bold: true
                                elide: Text.ElideRight
                                width: parent.width
                            }

                            Text {
                                text: modelData.display_name || ""
                                color: theme.textMuted
                                font.pixelSize: 11
                                elide: Text.ElideRight
                                width: parent.width
                            }
                        }
                    }

                    TapHandler {
                        id: resultTap
                        onTapped: {
                            backend.setMapCenter(modelData.lat, modelData.lon);
                            backend.setMapZoom(15);
                            mapRoot.destinationName = modelData.name;
                            mapRoot.destinationLat = modelData.lat;
                            mapRoot.destinationLon = modelData.lon;
                            mapRoot.hasDestination = true;
                            mapRoot.searchOpen = false;
                            backend.clearMapSearch();
                        }
                    }
                }
            }

            // Virtual Keyboard for Automotive Touch Input
            VirtualKeyboard {
                id: mapKeyboard
                Layout.fillWidth: true
                Layout.preferredHeight: 215
                targetInput: searchField

                onEnterPressed: {
                    if (searchField.text.trim().length > 0) {
                        backend.searchMap(searchField.text.trim());
                    }
                }

                onClosed: {
                    mapRoot.searchOpen = false;
                }
            }
        }
    }
}
