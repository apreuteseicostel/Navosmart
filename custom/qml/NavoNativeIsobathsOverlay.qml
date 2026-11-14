import QtQuick
import QtQuick.Controls
import QtPositioning
import "NavoMapProjection.js" as MapPan

// Live Kogger native isobaths overlay. Never creates navigation commands.
// Geometry is a capped list of GPS line endpoints from IsobathsProcessor.
Item {
    id: root
    objectName: "navoNativeIsobathsOverlay"
    property var map: null
    property var geometry: ({})
    property bool active: false
    readonly property bool ready: !!geometry && geometry.version === 1 &&
        !!geometry.segments && geometry.segments.length > 0 &&
        geometry.segments.length <= 4000
    property var projected: []
    property var projectedView: ({})
    property int renderedSegments: 0
    anchors.fill: parent
    visible: active && ready
    z: 30

    function currentView() {
        return {center: QtPositioning.coordinate(map.center.latitude, map.center.longitude),
                zoomLevel: map.zoomLevel, bearing: map.bearing, tilt: map.tilt,
                width: map.width, height: map.height}
    }
    function requestRepaint(onlyPan) {
        if (!onlyPan) { projected = []; projectedView = ({}) }
        if (!repaintTimer.running) repaintTimer.start()
    }
    onGeometryChanged: requestRepaint(false)
    onActiveChanged: requestRepaint(false)
    Timer { id: repaintTimer; interval: 50; onTriggered: contourCanvas.requestPaint() }
    Connections {
        target: root.map
        ignoreUnknownSignals: true
        function onCenterChanged() { root.requestRepaint(true) }
        function onZoomLevelChanged() { root.requestRepaint(false) }
        function onBearingChanged() { root.requestRepaint(false) }
        function onTiltChanged() { root.requestRepaint(false) }
        function onWidthChanged() { root.requestRepaint(false) }
        function onHeightChanged() { root.requestRepaint(false) }
    }
    Canvas {
        id: contourCanvas
        objectName: "nativeIsobathsCanvas"
        anchors.fill: parent
        onWidthChanged: root.requestRepaint(false)
        onHeightChanged: root.requestRepaint(false)
        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            root.renderedSegments = 0
            if (!root.active || !root.ready || !root.map || !root.map.mapReady) return
            var lines = root.geometry.segments
            if (root.projected.length) {
                var offset = MapPan.panOffset(root.map, root.projectedView)
                if (!offset) root.projected = []
                else if (offset.x !== 0 || offset.y !== 0) {
                    MapPan.translateProjected(root.projected, offset)
                    root.projectedView = root.currentView()
                }
            }
            if (!root.projected.length) {
                var points = []
                for (var i = 0; i < lines.length; ++i) {
                    var line = lines[i]
                    if (!line || line.length !== 5 ||
                        !isFinite(line[0]) || !isFinite(line[1]) ||
                        !isFinite(line[2]) || !isFinite(line[3]) ||
                        !isFinite(line[4]) || line[4] <= 0 ||
                        Math.abs(line[0]) > 90 || Math.abs(line[2]) > 90 ||
                        Math.abs(line[1]) > 180 || Math.abs(line[3]) > 180) {
                        points.push(null, null)
                        continue
                    }
                    var pa = root.map.fromCoordinate(QtPositioning.coordinate(line[0],line[1]),false)
                    var pb = root.map.fromCoordinate(QtPositioning.coordinate(line[2],line[3]),false)
                    points.push(pa && isFinite(pa.x) && isFinite(pa.y) ? {x:pa.x,y:pa.y} : null)
                    points.push(pb && isFinite(pb.x) && isFinite(pb.y) ? {x:pb.x,y:pb.y} : null)
                }
                root.projected = points
                root.projectedView = root.currentView()
            }
            ctx.strokeStyle = "#fff0bc"
            ctx.lineWidth = 1.5
            ctx.globalAlpha = 0.9
            ctx.beginPath()
            var labels = 0
            for (var j = 0; j < lines.length; ++j) {
                var a = root.projected[j*2], b = root.projected[j*2+1]
                if (!a || !b ||
                    Math.max(a.x,b.x)<0 || Math.min(a.x,b.x)>width ||
                    Math.max(a.y,b.y)<0 || Math.min(a.y,b.y)>height) continue
                ctx.moveTo(a.x,a.y)
                ctx.lineTo(b.x,b.y)
                root.renderedSegments++
            }
            ctx.stroke()
            ctx.globalAlpha = 1
            ctx.font = "11px sans-serif"
            for (var k = 0; k < lines.length && labels < 16; k += 24) {
                var a2 = root.projected[k*2], b2 = root.projected[k*2+1]
                if (!a2 || !b2) continue
                var x = (a2.x+b2.x)/2, y = (a2.y+b2.y)/2
                if (x < 24 || y < 20 || x > width - 70 || y > height - 16) continue
                var depth = Number(lines[k][4])
                var name = depth.toFixed(root.geometry.stepMeters < 1 ? 1 : 0) + " m"
                var w = ctx.measureText(name).width + 10
                ctx.fillStyle = "#d9081b2b"
                ctx.fillRect(x-4, y-13, w, 17)
                ctx.fillStyle = "#fff0bc"
                ctx.fillText(name,x+1,y)
                labels++
            }
        }
    }
    Rectangle {
        objectName: "nativeIsobathsLegend"
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 12
        anchors.bottomMargin: 10
        width: legend.implicitWidth + 18
        height: 28
        radius: 6
        color: "#df071827"
        border.color: "#ad9563"
        Label {
            id: legend
            anchors.centerIn: parent
            color: "#fff0bc"
            font.pixelSize: 11
            text: "ISOBATE " + Number(root.geometry.stepMeters || 1).toFixed(root.geometry.stepMeters < 1 ? 1 : 0) +
                  " m" + (root.geometry.truncated ? " • LIMITAT" : "")
        }
    }
}
