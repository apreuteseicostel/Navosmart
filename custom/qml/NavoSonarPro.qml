import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtPositioning
import QtLocation
import QGroundControl.FlightDisplay

Rectangle {
    id: root
    property int chartResolution: 0
    property int chartAbsoluteOffset: 0
    property int chartVersion: 0
    property int chartRawByteCount: 0
    property real chartResolutionMeters: NaN
    property real chartOffsetMeters: NaN
    property real chartRangeMeters: NaN
    property var chartSource: null
    property var samples: []
    property bool connected: false
    property real depthM: NaN
    property real waterTempC: NaN
    property var vehicle: null
    property var planController: null
    property var boatTrack: []
    property var plannedTrack: []
    property bool mapEnabled: false
    property bool settingsVisible: false
    property bool menuOpen: false
    property bool paused: false
    property var history: []
    // Georeferenced input queue for the native KoggerApp Dataset adapter.
    // Retain raw CHART bytes and their metadata; never feed display-filtered pixels
    // to bottom tracking, mosaic, surface or isobath processing.
    property var geoChartRecords: []
    property int maxGeoChartRecords: 3000
    property int unlocatedChartCount: 0
    function captureGeoChart() {
        if (!chartSource || !chartSource.chartRawBytes || !chartSource.chartRawByteCount) return
        var coordinate = vehicle && vehicle.coordinate ? vehicle.coordinate : null
        if (!coordinate || !coordinate.isValid) { unlocatedChartCount++; return }
        var record = { latitude: coordinate.latitude, longitude: coordinate.longitude,
                       timestampMs: Date.now(), depthM: depthM,
                       resolution: chartSource.chartResolution,
                       absoluteOffset: chartSource.chartAbsoluteOffset,
                       version: chartSource.chartVersion,
                       rawBytes: chartSource.chartRawBytes }
        var next = geoChartRecords.slice(0); next.push(record)
        if (next.length > maxGeoChartRecords) next.splice(0,next.length-maxGeoChartRecords)
        geoChartRecords = next
    }
    property int historyColumns: 240
    signal closed()
    property real gain: 1.0
    property real noiseFloor: 0.10
    property bool noiseFilterEnabled: false
    property bool dayPalette: false
    property bool koggerCompensation: false
    // Live bottom overlay uses the decoded Kogger depth telemetry, not the
    // offline KoggerApp BottomTrackProcessor (which needs a Dataset adapter).
    property bool showBottomTrack: true
    readonly property var displayedColumn: history.length ? history[history.length - 1] : null
    readonly property int buttonSize: width < 640 ? 36 : 40
    readonly property int echoWidth: width < 640 ? 44 : 58
    color: "#03101a"
    clip: true
    function pushHistory() {
        var column = chartSource ? (koggerCompensation ? chartSource.compensatedSamples : chartSource.echoSamples) : samples
        var offset = chartSource ? chartSource.chartOffsetMeters : chartOffsetMeters
        var range = chartSource ? chartSource.chartRangeMeters : chartRangeMeters
        var available = chartSource ? chartSource.connected : connected
        if (paused || !available || !column || !column.length ||
                !isFinite(offset) || !isFinite(range) || range <= 0) return
        var h = history.slice(0)
        h.push({samples: column.slice(0), offset: offset, range: range, bottom: isFinite(root.depthM) && root.depthM >= 0 ? root.depthM : NaN})
        if (h.length > historyColumns) h.splice(0, h.length - historyColumns)
        history = h
    }
    function sampleStrength(column, index) {
        var value = Number(column[index])
        if (!isFinite(value)) return 0
        if (noiseFilterEnabled && index > 0 && index < column.length - 1) {
            var left = Number(column[index - 1]), right = Number(column[index + 1])
            if (isFinite(left) && isFinite(right))
                value = Math.max(Math.min(left, value), Math.min(Math.max(left, value), right))
        }
        return Math.max(0, Math.min(1, (value - noiseFloor) * gain))
    }
    function echoColor(value) {
        if (dayPalette)
            return value > .72 ? "#a52026" : value > .48 ? "#e97820" : value > .24 ? "#136d9b" : "#b7d8e8"
        return value > .72 ? "#f44b2e" : value > .48 ? "#f6da46" : value > .24 ? "#1ccde1" : "#105caa"
    }
    function resetDisplaySettings() {
        gain = 1.0
        noiseFloor = .10
        noiseFilterEnabled = false
        dayPalette = false
    }
    function repaint() { echogram.requestPaint(); liveEcho.requestPaint() }
    // Read the source getters synchronously: all metadata is published before
    // this signal. Capture every column even when one TCP chunk holds several.
    Connections {
        target: root.chartSource
        function onEchoSamplesChanged() { root.captureGeoChart(); root.pushHistory() }
    }
    onSamplesChanged: if (!chartSource) Qt.callLater(pushHistory)
    Component.onCompleted: Qt.callLater(pushHistory)
    onHistoryChanged: repaint()
    onGainChanged: repaint()
    onNoiseFloorChanged: repaint()
    onNoiseFilterEnabledChanged: repaint()
    onDayPaletteChanged: repaint()
    onKoggerCompensationChanged: { history = []; pushHistory(); repaint() }
    onShowBottomTrackChanged: repaint()
    // Freeze scale together with the displayed history while paused.
    readonly property real scaleStart: displayedColumn ? displayedColumn.offset : (isFinite(chartOffsetMeters) ? chartOffsetMeters : 0)
    readonly property real scaleRange: displayedColumn ? displayedColumn.range : (isFinite(chartRangeMeters) && chartRangeMeters > 0 ? chartRangeMeters : 0)
    onScaleStartChanged: repaint()
    onScaleRangeChanged: repaint()

    component IconButton: Button {
        id: control
        property string glyph
        property string hint
        implicitWidth: root.buttonSize; implicitHeight: root.buttonSize; padding: 8
        Accessible.name: hint
        ToolTip.visible: hovered || pressed
        ToolTip.text: hint
        background: Rectangle { radius: 8; color: control.checked ? "#18536a" : "#cc0b1c2e"; opacity: control.enabled ? 1 : .4; border.color: "#31536c" }
        contentItem: Image { source: "qrc:/qml/NavoSmart/icons/" + control.glyph + ".svg"; fillMode: Image.PreserveAspectFit }
    }
    Row {
        anchors.fill: parent
        spacing: root.mapEnabled ? 2 : 0
        Item {
            id: echoPanel
            width: root.mapEnabled ? Math.floor((parent.width - 2) * 0.55) : parent.width
            height: parent.height
            clip: true
            Canvas {
                id: echogram
                anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                anchors.right: echoColumn.left
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.reset(); ctx.fillStyle = root.dayPalette ? "#f1f5f7" : "#03101a"; ctx.fillRect(0,0,width,height)
                    var cw = width / root.historyColumns
                    for (var x=0; x<root.history.length; x++) {
                        var entry=root.history[x], col=entry.samples
                        if (!root.scaleRange || !isFinite(entry.range) || entry.range<=0) continue
                        var px=width-(root.history.length-x)*cw
                        for (var y=0; y<col.length; y++) {
                            var v=root.sampleStrength(col, y)
                            if (!isFinite(v) || v<=0) continue
                            var py=(entry.offset+y*entry.range/col.length-root.scaleStart)/root.scaleRange*height
                            var ph=entry.range/col.length/root.scaleRange*height
                            ctx.fillStyle=root.echoColor(v)
                            ctx.fillRect(px,py,Math.max(1,cw+.5),Math.max(1,ph+.5))
                        }
                    }
                    if(root.showBottomTrack && root.scaleRange>0) {
                        ctx.beginPath(); ctx.strokeStyle="#f6da46"; ctx.lineWidth=2
                        var started=false
                        for(var bx=0;bx<root.history.length;bx++) {
                            var bottomEntry=root.history[bx]
                            if(!isFinite(bottomEntry.bottom)){started=false;continue}
                            var bottomY=(bottomEntry.bottom-root.scaleStart)/root.scaleRange*height
                            var bottomX=width-(root.history.length-bx-.5)*cw
                            if(!started){ctx.moveTo(bottomX,bottomY);started=true}else ctx.lineTo(bottomX,bottomY)
                        }
                        ctx.stroke();ctx.lineWidth=1
                    }
                    ctx.strokeStyle=root.dayPalette?"#bccbd4":"#40536a"; ctx.fillStyle=root.dayPalette?"#18364a":"#d9edf7"; ctx.font="12px sans-serif"
                    for (var n=0;n<=4;n++) {
                        var gy=n*height/4
                        ctx.beginPath();ctx.moveTo(0,gy);ctx.lineTo(width,gy);ctx.stroke()
                        if(root.scaleRange > 0) {
                            var depthLabel=(root.scaleStart+n*root.scaleRange/4).toFixed(1)+" m"
                            var labelY=Math.max(14,Math.min(height-6,gy+(n===4?-5:14)))
                            var labelWidth=ctx.measureText(depthLabel).width+10
                            ctx.fillStyle=root.dayPalette?"#e5edf2":"#102b3b"
                            ctx.fillRect(3,labelY-12,labelWidth,16)
                            ctx.fillStyle=root.dayPalette?"#18364a":"#d9edf7"
                            ctx.fillText(depthLabel,8,labelY)
                        }
                    }
                }
            }
            Label {
                anchors.centerIn: parent
                visible: !root.connected || !root.history.length
                text: root.connected ? "Aștept coloane CHART" : "Aștept date Kogger"
                color: "#9db2c5"
            }
            Rectangle {
                id: echoColumn
                anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom
                width: root.echoWidth
                color: root.dayPalette ? "#e1eaf0" : "#081b2b"
                border.color: "#31536c"
                Canvas {
                    id: liveEcho
                    anchors.fill: parent; anchors.margins: 2
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.reset()
                        if (!root.displayedColumn || !root.scaleRange) return
                        var col = root.displayedColumn.samples
                        for (var i = 0; i < col.length; ++i) {
                            var v = root.sampleStrength(col, i)
                            if (v <= 0) continue
                            ctx.fillStyle = root.echoColor(v)
                            ctx.fillRect(0, i * height / col.length, v * width, Math.max(1, height / col.length))
                        }
                    }
                }
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom; anchors.bottomMargin: 5
                    text: "ECOU"; font.pixelSize: 9; font.bold: true
                    color: root.dayPalette ? "#18364a" : "#d9edf7"
                }
            }
        }
        Loader {
            id: mapLoader
            width: root.mapEnabled ? parent.width-echoPanel.width-2 : 0
            height: parent.height
            active: root.mapEnabled
            visible: active
            sourceComponent: Component {
                Item {
                    clip: true
                    FlyViewMap {
                        id: liveMap
                        anchors.fill: parent
                        planMasterController: root.planController
                        rightPanelWidth: 0
                        zoomLevel: 17
                        toolInsets: QtObject {
                            readonly property real leftEdgeTopInset: 0
                            readonly property real leftEdgeCenterInset: 0
                            readonly property real leftEdgeBottomInset: 0
                            readonly property real rightEdgeTopInset: 0
                            readonly property real rightEdgeCenterInset: 0
                            readonly property real rightEdgeBottomInset: 0
                            readonly property real topEdgeLeftInset: 0
                            readonly property real topEdgeCenterInset: 0
                            readonly property real topEdgeRightInset: 0
                            readonly property real bottomEdgeLeftInset: 0
                            readonly property real bottomEdgeCenterInset: 0
                            readonly property real bottomEdgeRightInset: 0
                        }
                        function followBoat() {
                            if(root.vehicle && root.vehicle.coordinate && root.vehicle.coordinate.isValid)
                                center=root.vehicle.coordinate
                        }
                        Component.onCompleted: followBoat()
                        Connections { target: root.vehicle; function onCoordinateChanged() { liveMap.followBoat() } }
                    }
                    MapPolyline {
                        parent: liveMap
                        line.width: 2; line.color: "#f6da46"
                        path: root.plannedTrack
                        Component.onCompleted: liveMap.addMapItem(this)
                        Component.onDestruction: liveMap.removeMapItem(this)
                    }
                    MapPolyline {
                        parent: liveMap
                        line.width: 3; line.color: "#21b7ff"
                        path: root.boatTrack
                        Component.onCompleted: liveMap.addMapItem(this)
                        Component.onDestruction: liveMap.removeMapItem(this)
                    }
                    MapQuickItem {
                        parent: liveMap
                        coordinate: root.vehicle ? root.vehicle.coordinate : QtPositioning.coordinate()
                        visible: coordinate.isValid
                        anchorPoint.x: 18; anchorPoint.y: 18
                        sourceItem: Image {
                            width: 36; height: 36
                            source: "qrc:/qml/NavoSmart/icons/boat.svg"
                            rotation: root.vehicle && root.vehicle.heading ? root.vehicle.heading.rawValue-liveMap.bearing : 0
                        }
                        Component.onCompleted: liveMap.addMapItem(this)
                        Component.onDestruction: liveMap.removeMapItem(this)
                    }
                    Row {
                        anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 8; spacing: 4
                        IconButton { glyph: "zoom-out"; hint: "Micșorează harta"; onClicked: liveMap.zoomLevel-- }
                        IconButton { glyph: "zoom-in"; hint: "Mărește harta"; onClicked: liveMap.zoomLevel++ }
                    }
                }
            }
        }
    }
    Rectangle {
        id: telemetryBar
        anchors.left: parent.left; anchors.top: parent.top; anchors.margins: 6
        width: Math.max(0, Math.min(parent.width-root.buttonSize-18, telemetry.implicitWidth+16)); height: root.buttonSize; radius: 7; color: "#cc0b1c2e"
        z: 101
        Label {
            id: telemetry; anchors.fill: parent; anchors.margins: 8; elide: Text.ElideRight
            color: root.connected ? "#21b7ff" : "#9db2c5"
            text: "PRO  •  " + (root.connected ? (root.paused ? "PAUZĂ" : "LIVE") : "OFFLINE") + "   " + (isFinite(root.depthM)?root.depthM.toFixed(1)+" m":"— m") + "   " + (isFinite(root.waterTempC)?root.waterTempC.toFixed(1)+" °C":"— °C")
        }
    }
    IconButton {
        id: menuButton
        anchors.left: parent.left; anchors.top: telemetryBar.bottom; anchors.margins: 6
        z: 100; visible: true; enabled: true
        glyph: "settings"; hint: "Deschide / închide meniul Sonar PRO"
        checkable: true; checked: root.menuOpen
        onClicked: { root.settingsVisible = false; root.menuOpen = !root.menuOpen }
    }
    IconButton {
        id: closeButton
        anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 6
        z: 102; glyph: "close"; hint: "Ieșire din Sonar PRO"
        onClicked: root.closed()
    }
    Rectangle {
        id: menuPanel
        visible: root.menuOpen
        z: 103
        anchors.left: parent.left; anchors.top: menuButton.bottom; anchors.topMargin: 4; anchors.leftMargin: 6
        width: Math.min(260,parent.width*.48)
        height: Math.min(menuColumn.implicitHeight+16,Math.max(0,parent.height-menuButton.height-55))
        radius: 8; color: "#ee0b1c2e"; border.color: "#31536c"
        ScrollView {
            anchors.fill: parent; anchors.margins: 8; clip: true
            contentWidth: availableWidth
            ColumnLayout {
                id: menuColumn; width: menuPanel.width-16; spacing: 5
                Button { Layout.fillWidth: true; text: root.mapEnabled ? "Ascunde harta" : "Activează harta"; onClicked: {root.mapEnabled=!root.mapEnabled;root.menuOpen=false} }
                Button { Layout.fillWidth: true; text: root.paused ? "Continuă ecograma" : "Pauză ecogramă"; onClicked: root.paused=!root.paused }
                Button { Layout.fillWidth: true; text: root.dayPalette ? "Paletă NAVO" : "Paletă de zi"; onClicked: root.dayPalette=!root.dayPalette }
                Button { Layout.fillWidth: true; text: "Sensibilitate și filtre"; onClicked: {root.settingsVisible=!root.settingsVisible;root.menuOpen=false} }
                Button { Layout.fillWidth: true; text: root.koggerCompensation ? "Ecou brut" : "Compensare Kogger"; onClicked: root.koggerCompensation=!root.koggerCompensation }
                Button { Layout.fillWidth: true; text: root.showBottomTrack ? "Ascunde linia fundului" : "Arată linia fundului"; onClicked: root.showBottomTrack=!root.showBottomTrack }
                Button { Layout.fillWidth: true; text: "Reset reglaje"; onClicked: root.resetDisplaySettings() }
            }
        }
    }
    Rectangle {
        visible: root.settingsVisible
        z: 21
        anchors.left: parent.left; anchors.top: menuButton.bottom; anchors.topMargin: 4; anchors.leftMargin: 6
        width: Math.min(360,parent.width-16)
        height: Math.min(settingsContent.implicitHeight+16, Math.max(0, parent.height-menuButton.height-55))
        radius: 8; color: "#ed0b1c2e"; border.color: "#31536c"
        ScrollView {
            anchors.fill: parent; anchors.margins: 8; clip: true
            id: settingsScroll
            contentWidth: availableWidth
            ColumnLayout {
                id: settingsContent
                width: settingsScroll.availableWidth; spacing: 6
                RowLayout {
                    Layout.fillWidth: true
                    Image { source: "qrc:/qml/NavoSmart/icons/gain.svg"; Layout.preferredWidth: 22; Layout.preferredHeight: 22 }
                    Slider {
                        Layout.fillWidth: true; from: .5; to: 3; stepSize: .05
                        value: root.gain; onMoved: root.gain=value
                        Accessible.name: "Sensibilitate ecogramă"
                        ToolTip.visible: hovered || pressed; ToolTip.text: "Sensibilitate " + value.toFixed(2) + "×"
                    }
                    Label { text: root.gain.toFixed(2)+"×"; color: "#d9edf7"; Layout.preferredWidth: 46 }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Image { source: "qrc:/qml/NavoSmart/icons/filter.svg"; Layout.preferredWidth: 22; Layout.preferredHeight: 22 }
                    Slider {
                        Layout.fillWidth: true; from: 0; to: .5; stepSize: .01
                        value: root.noiseFloor; onMoved: root.noiseFloor=value
                        Accessible.name: "Prag zgomot ecogramă"
                        ToolTip.visible: hovered || pressed; ToolTip.text: "Prag zgomot " + Math.round(value*100) + "%"
                    }
                    Label { text: Math.round(root.noiseFloor*100)+"%"; color: "#d9edf7"; Layout.preferredWidth: 46 }
                }
                RowLayout {
                    Layout.fillWidth: true
                    IconButton { glyph: "filter"; hint: root.noiseFilterEnabled ? "Dezactivează filtrul de impulsuri" : "Activează filtrul de impulsuri"; checkable: true; checked: root.noiseFilterEnabled; onClicked: root.noiseFilterEnabled=!root.noiseFilterEnabled }
                    Label { Layout.fillWidth: true; text: "Filtru impulsuri"; color: "#d9edf7" }
                    IconButton { glyph: "undo"; hint: "Restabilește reglajele implicite"; onClicked: root.resetDisplaySettings() }
                }
            }
        }
    }
}
