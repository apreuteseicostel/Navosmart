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
    property bool paused: false
    property var history: []
    property int historyColumns: 240
    signal closed()
    property real gain: 1.0
    property real noiseFloor: 0.10
    property bool bottomTrackEnabled: true
    // Experimental bottom peak tracker; calibrated physical hardness is NOT inferred.
    readonly property var bottomResult: {
        if (!bottomTrackEnabled || !samples || samples.length < 8)
            return ({ index: -1, strength: NaN, confidence: 0 })
        var n = samples.length
        var start = Math.max(1, Math.floor(n * 0.25))
        var end = n - 2
        var best = -1
        var bestScore = 0
        var second = 0
        for (var i = start; i <= end; ++i) {
            var left = Number(samples[i - 1])
            var center = Number(samples[i])
            var right = Number(samples[i + 1])
            if (!isFinite(left) || !isFinite(center) || !isFinite(right)) continue
            var score = Math.max(0, (left + 2 * center + right) / 4 - noiseFloor)
            if (score > bestScore) { second = bestScore; bestScore = score; best = i }
            else if (score > second) second = score
        }
        if (best < 0 || bestScore <= 0)
            return ({ index: -1, strength: NaN, confidence: 0 })
        return ({ index: best, strength: Math.min(1, bestScore * gain),
                  confidence: Math.max(0, Math.min(1, (bestScore - second) / Math.max(bestScore, 0.001))) })
    }
    readonly property real bottomEcho: bottomResult.strength
    readonly property real bottomDepthEstimate: bottomResult.index >= 0 && isFinite(depthM)
        ? chartOffsetMeters + chartResolutionMeters * bottomResult.index : NaN
    color: "#03101a"
    clip: true
    function pushHistory() {
        if (paused || !connected || !samples || !samples.length) return
        var h = history.slice(0)
        h.push({samples: samples.slice(0), offset: chartOffsetMeters, range: chartRangeMeters})
        if (h.length > historyColumns) h.shift()
        history = h
    }
    onSamplesChanged: pushHistory()
    onHistoryChanged: echogram.requestPaint()
    onGainChanged: echogram.requestPaint()
    onNoiseFloorChanged: echogram.requestPaint()
    readonly property real scaleStart: isFinite(chartOffsetMeters) ? chartOffsetMeters : 0
    readonly property real scaleRange: isFinite(chartRangeMeters) && chartRangeMeters > 0 ? chartRangeMeters : 0
    onScaleStartChanged: echogram.requestPaint()
    onScaleRangeChanged: echogram.requestPaint()

    component IconButton: Button {
        id: control
        property string glyph
        property string hint
        implicitWidth: 40; implicitHeight: 40; padding: 8
        Accessible.name: hint
        ToolTip.visible: hovered || pressed
        ToolTip.text: hint
        background: Rectangle { radius: 8; color: control.checked ? "#18536a" : "#cc0b1c2e"; border.color: "#31536c" }
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
                anchors.fill: parent
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.reset(); ctx.fillStyle = "#03101a"; ctx.fillRect(0,0,width,height)
                    var cw = width / root.historyColumns
                    for (var x=0; x<root.history.length; x++) {
                        var entry=root.history[x], col=entry.samples
                        if (!root.scaleRange || !isFinite(entry.range) || entry.range<=0) continue
                        var px=width-(root.history.length-x)*cw
                        for (var y=0; y<col.length; y++) {
                            var v=Math.max(0,Math.min(1,(Number(col[y])-root.noiseFloor)*root.gain))
                            if (!isFinite(v) || v<=0) continue
                            var py=(entry.offset+y*entry.range/col.length-root.scaleStart)/root.scaleRange*height
                            var ph=entry.range/col.length/root.scaleRange*height
                            ctx.fillStyle=v>.72?"#f44b2e":v>.48?"#f6da46":v>.24?"#1ccde1":"#105caa"
                            ctx.fillRect(px,py,Math.max(1,cw+.5),Math.max(1,ph+.5))
                        }
                    }
                    ctx.strokeStyle="#40536a"; ctx.fillStyle="#d9edf7"; ctx.font="12px sans-serif"
                    for (var n=0;n<=4;n++) {
                        var gy=n*height/4
                        ctx.beginPath();ctx.moveTo(0,gy);ctx.lineTo(width,gy);ctx.stroke()
                        if(root.scaleRange) ctx.fillText((root.scaleStart+n*root.scaleRange/4).toFixed(1)+" m",6,Math.max(62,Math.min(height-8,gy+15)))
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
                anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom
                width: 8
                gradient: Gradient {
                    GradientStop { position: 0; color: "#f44b2e" }
                    GradientStop { position: .3; color: "#f6da46" }
                    GradientStop { position: .65; color: "#1ccde1" }
                    GradientStop { position: 1; color: "#105caa" }
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
        anchors.left: parent.left; anchors.top: parent.top; anchors.margins: 6
        width: Math.min(parent.width-150, telemetry.implicitWidth+16); height: 38; radius: 7; color: "#cc0b1c2e"
        Label {
            id: telemetry; anchors.fill: parent; anchors.margins: 8; elide: Text.ElideRight
            color: root.connected ? "#21b7ff" : "#9db2c5"
            text: "PRO  •  " + (root.connected ? "LIVE" : "OFFLINE") + "   " + (isFinite(root.depthM)?root.depthM.toFixed(1)+" m":"— m") + "   " + (isFinite(root.waterTempC)?root.waterTempC.toFixed(1)+" °C":"— °C")
        }
    }
    Row {
        anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 6; spacing: 4
        IconButton { glyph: "map"; hint: root.mapEnabled ? "Ascunde harta" : "Arată harta"; checkable: true; checked: root.mapEnabled; onClicked: root.mapEnabled=!root.mapEnabled }
        IconButton { glyph: "settings"; hint: "Reglaje sonar"; checkable: true; checked: root.settingsVisible; onClicked: root.settingsVisible=!root.settingsVisible }
        IconButton { glyph: "close"; hint: "Închide Sonar PRO"; onClicked: root.closed() }
    }
    Rectangle {
        visible: root.settingsVisible
        anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.margins: 8
        width: Math.min(360,parent.width-16); height: 138; radius: 8; color: "#ed0b1c2e"; border.color: "#31536c"
        ColumnLayout {
            anchors.fill: parent; anchors.margins: 8
            RowLayout {
                Label { text: "Sensibilitate"; color: "#d9edf7" }
                Slider { Layout.fillWidth: true; from: .5; to: 3; value: root.gain; onMoved: root.gain=value }
            }
            RowLayout {
                Label { text: "Zgomot"; color: "#d9edf7" }
                Slider { Layout.fillWidth: true; from: 0; to: .5; value: root.noiseFloor; onMoved: root.noiseFloor=value }
            }
            RowLayout {
                IconButton { glyph: root.paused?"play":"stop"; hint: root.paused?"Continuă ecograma":"Pauză ecogramă"; onClicked: root.paused=!root.paused }
                Label { text: "CHART v"+root.chartVersion+" • "+root.chartRawByteCount+" B"; color: "#9db2c5" }
            }
        }
    }
}
