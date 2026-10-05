import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import QtPositioning
import QtLocation
import QGroundControl.FlightMap

Rectangle {
    id: root
    objectName:"navoSonarPro"
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
    readonly property bool replayMode: chartSource ? chartSource.replayMode : false
    readonly property bool replayActive: chartSource ? chartSource.replayActive : false
    FileDialog { id: replayPicker; title: 'Încarcă înregistrare Kogger'; nameFilters: ['Kogger (*.klf)', 'Toate fișierele (*)']; onAccepted: { if(root.chartSource) {root.history=[];root.chartSource.startReplay(selectedFile)} } }
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
    // Cache only display pixels; retain all original samples for processing/save.
    // Bounded cache also works with QVariant-backed QML arrays.
    property var rasterCache: []
    function displayRaster(entry, pixelHeight) {
        var rows = Math.max(1, Math.ceil(pixelHeight))
        var col = entry.samples
        var geometryKey = [rows, scaleStart, scaleRange, entry.offset, entry.range,
                           noiseFilterEnabled].join(":")
        var key = [geometryKey, gain, noiseFloor].join(":")
        var cache = rasterCache, slot = -1, cached = null
        for (var c = 0; c < cache.length; ++c)
            if (cache[c].samples === col) { slot = c; cached = cache[c]; break }
        if (cached && cached.key === key) return cached
        var peaks = cached && cached.geometryKey === geometryKey ? cached.peaks : null
        if (!peaks) {
            peaks = new Float32Array(rows)
            peaks.fill(-Infinity)
            if (scaleRange > 0 && entry.range > 0 && col.length) {
                var step = entry.range / col.length / scaleRange * rows
                var top = (entry.offset - scaleStart) / scaleRange * rows
                var filter = noiseFilterEnabled
                for (var i = 0; i < col.length; ++i) {
                    var first = Math.max(0, Math.floor(top + i * step))
                    var end = Math.min(rows, Math.ceil(top + (i + 1) * step))
                    if (first >= end) continue
                    var value = Number(col[i])
                    if (!isFinite(value)) continue
                    if (filter && i > 0 && i < col.length - 1) {
                        var left = Number(col[i - 1]), right = Number(col[i + 1])
                        if (isFinite(left) && isFinite(right))
                            value = Math.max(Math.min(left, value), Math.min(Math.max(left, value), right))
                    }
                    for (var y = first; y < end; ++y)
                        if (value > peaks[y]) peaks[y] = value
                }
            }
        }
        // Gain/floor are monotonic: apply them to row peaks without rescanning raw data.
        var strengths = new Float32Array(rows), bins = new Uint8Array(rows)
        var displayGain = gain, floor = noiseFloor
        for (var y = 0; y < rows; ++y) {
            var v = isFinite(peaks[y]) ? Math.max(0, Math.min(1, (peaks[y] - floor) * displayGain)) : 0
            if (!isFinite(v)) v = 0
            strengths[y] = v
            bins[y] = v <= 0 ? 0 : v > .72 ? 4 : v > .48 ? 3 : v > .24 ? 2 : 1
        }
        cached = {samples:col, key:key, geometryKey:geometryKey, peaks:peaks, strengths:strengths, bins:bins}
        if (slot >= 0) cache[slot] = cached
        else {
            cache.push(cached)
            if (cache.length > Math.max(1, historyColumns)) cache.shift()
        }
        return cached
    }
    // Georeferenced input queue for the native KoggerApp Dataset adapter.
    // Retain raw CHART bytes and their metadata; never feed display-filtered pixels
    // to bottom tracking, mosaic, surface or isobath processing.
    property var geoChartRecords: []
    property int maxGeoChartRecords: 3000
    property int unlocatedChartCount: 0
    function captureGeoChart() {
        if (!chartSource || chartSource.replayMode || !chartSource.chartRawBytes || !chartSource.chartRawByteCount) return
        var coordinate = vehicle && vehicle.coordinate ? vehicle.coordinate : null
        var fixValid = vehicle && vehicle.gps && vehicle.gps.lock.rawValue >= 3 &&
                       vehicle.vehicleLinkManager && !vehicle.vehicleLinkManager.communicationLost
        if (!fixValid || !coordinate || !coordinate.isValid) { unlocatedChartCount++; return }
        var record = { latitude: coordinate.latitude, longitude: coordinate.longitude,
                       timestampMs: Date.now(), sequence:chartSource.chartSequence,
                       depthM: chartSource.nativeChannelReady ? NaN : depthM,
                       resolution: chartSource.chartResolution,
                       absoluteOffset: chartSource.chartAbsoluteOffset,
                       version: chartSource.chartVersion,
                       rawBytes: chartSource.chartRawBytes }
        var next = geoChartRecords.slice(0); next.push(record)
        if (next.length > maxGeoChartRecords) next.splice(0,next.length-maxGeoChartRecords)
        geoChartRecords = next
    }
    property int historyColumns: 240
    property int replaySampleCount: 0
    property string replaySaveStatus: ""
    signal saveReplayRequested(string name)
    signal closed()
    Dialog {
        id: replaySaveDialog
        parent: Overlay.overlay
        anchors.centerIn: parent
        modal: true
        title: "Salvează înregistrarea ca baltă separată"
        standardButtons: Dialog.Save | Dialog.Cancel
        TextField {
            id: replayLakeName
            width: Math.min(300,root.width-40)
            placeholderText: "Numele bălții"
            text: "Înregistrare DownView"
        }
        onAccepted: root.saveReplayRequested(replayLakeName.text.trim())
    }
    property real gain: 1.0
    property real noiseFloor: 0.10
    property bool noiseFilterEnabled: false
    property bool dayPalette: false
    property bool koggerCompensation: false
    // Native bottom results update their matching completed CHART column.
    property bool showBottomTrack: true
    readonly property var displayedColumn: history.length ? history[history.length - 1] : null
    readonly property int buttonSize: width < 640 ? 36 : 40
    readonly property color selectedMenuColor: "#176b86"
    readonly property color selectedMenuBorder: "#45d5f5"
    readonly property int echoWidth: width < 640 ? 44 : 58
    color: "#03101a"
    clip: true
    function pushHistory() {
        var column = chartSource ? (koggerCompensation ? chartSource.compensatedSamples : chartSource.echoSamples) : samples
        var offset = chartSource ? chartSource.chartOffsetMeters : chartOffsetMeters
        var range = chartSource ? chartSource.chartRangeMeters : chartRangeMeters
        var available = chartSource ? (chartSource.connected || root.replayMode) : connected
        if (paused || !available || !column || !column.length ||
                !isFinite(offset) || !isFinite(range) || range <= 0) return
        var h = history.slice(0)
        h.push({samples: column.slice(0), offset: offset, range: range, sequence: chartSource ? chartSource.chartSequence : 0,
                bottom: chartSource && chartSource.nativeChannelReady ? NaN : (isFinite(root.depthM) && root.depthM >= 0 ? root.depthM : NaN)})
        if (h.length > historyColumns) h.splice(0, h.length - historyColumns)
        history = h
    }
    function updateHistoryBottom(sequence, depth) {
        if (!isFinite(depth) || depth <= 0) return
        var next = history.slice(0), changed = false
        for (var i=0; i<next.length; ++i) {
            if (next[i].sequence !== sequence) continue
            var entry = Object.assign({},next[i]); entry.bottom = depth; next[i] = entry; changed = true
        }
        if (changed) { history = next; repaint() }
        var geoNext=geoChartRecords.slice(0), geoChanged=false
        for(var g=0;g<geoNext.length;++g){
            if(geoNext[g].sequence!==sequence)continue
            var record=Object.assign({},geoNext[g]);record.depthM=depth;geoNext[g]=record;geoChanged=true
        }
        if(geoChanged)geoChartRecords=geoNext
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
        function onBottomColumnReady(sequence,depth) { root.updateHistoryBottom(sequence,depth) }
    }
    onSamplesChanged: if (!chartSource) Qt.callLater(pushHistory)
    Component.onCompleted: Qt.callLater(pushHistory)
    onHistoryChanged: { if (!history.length) rasterCache = []; repaint() }
    onGainChanged: repaint()
    onNoiseFloorChanged: repaint()
    onNoiseFilterEnabledChanged: repaint()
    onDayPaletteChanged: repaint()
    onReplayActiveChanged: { history=[]; root.menuOpen=false }
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
        background: Rectangle { radius: 8; color: control.checked ? root.selectedMenuColor : "#cc0b1c2e"; opacity: control.enabled ? 1 : .4; border.color: control.checked ? root.selectedMenuBorder : "#31536c"; border.width: control.checked ? 2 : 1 }
        contentItem: Image { source: "qrc:/qml/NavoSmart/icons/" + control.glyph + ".svg"; fillMode: Image.PreserveAspectFit }
    }
    Row {
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        // Keep the scale and echo key below the status/close controls.
        anchors.top: telemetryBar.bottom; anchors.topMargin: 8
        spacing: root.mapEnabled ? 2 : 0
        Item {
            id: echoPanel
            width: root.mapEnabled ? Math.floor((parent.width - 2) * 0.55) : parent.width
            height: parent.height
            clip: true
            Canvas {
                id: echogram
                objectName: "sonarProEchogram"
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
                        var bins = root.displayRaster(entry, height).bins
                        var palette = root.dayPalette
                            ? ["", "#b7d8e8", "#136d9b", "#e97820", "#a52026"]
                            : ["", "#105caa", "#1ccde1", "#f6da46", "#f44b2e"]
                        for (var y=0; y<bins.length;) {
                            var shade=bins[y], end=y+1
                            while (end<bins.length && bins[end]===shade) ++end
                            if (shade) {
                                ctx.fillStyle=palette[shade]
                                ctx.fillRect(px,y,Math.max(1,cw+.5),end-y)
                            }
                            y=end
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
                        {
                            var depthLabel=root.scaleRange > 0 ? (root.scaleStart+n*root.scaleRange/4).toFixed(1)+" m" : "— m"
                            var labelY=Math.max(14,Math.min(height-6,gy+(n===4?-5:14)))
                            var labelWidth=ctx.measureText(depthLabel).width+10
                            var labelX=n===0 ? menuButton.x+menuButton.width+8 : 8
                            ctx.fillStyle=root.dayPalette?"#e5edf2":"#102b3b"
                            ctx.fillRect(labelX-5,labelY-12,labelWidth,16)
                            ctx.fillStyle=root.dayPalette?"#18364a":"#d9edf7"
                            ctx.fillText(depthLabel,labelX,labelY)
                        }
                    }
                }
            }
            Label {
                anchors.centerIn: parent
                visible: !root.history.length
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
                    anchors.fill: parent; anchors.margins: 2; anchors.rightMargin: 20; anchors.bottomMargin: 22
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.reset()
                        if (!root.displayedColumn || !root.scaleRange) return
                        var raster = root.displayRaster(root.displayedColumn, height)
                        for (var i = 0; i < raster.strengths.length; ++i) {
                            var v = raster.strengths[i]
                            if (v <= 0) continue
                            ctx.fillStyle = root.echoColor(v)
                            ctx.fillRect(0, i, v * width, 1)
                        }
                    }
                }
                // Strength key remains visible when the live return is empty.
                Rectangle {
                    objectName: "sonarProEchoStrengthLegend"
                    anchors.right: parent.right; anchors.rightMargin: 3
                    anchors.top: parent.top; anchors.topMargin: 30
                    anchors.bottom: parent.bottom; anchors.bottomMargin: 30
                    width: 10
                    gradient: Gradient {
                        GradientStop { position: 0; color: root.echoColor(1) }
                        GradientStop { position: .3; color: root.echoColor(.6) }
                        GradientStop { position: .65; color: root.echoColor(.3) }
                        GradientStop { position: 1; color: root.echoColor(0) }
                    }
                }
                Label {
                    anchors.right: parent.right; anchors.rightMargin: 2
                    anchors.top: parent.top; anchors.topMargin: 8
                    text: "100%"; font.pixelSize: 10
                    color: root.dayPalette ? "#18364a" : "#d9edf7"
                }
                Label {
                    anchors.right: parent.right; anchors.rightMargin: 2
                    anchors.bottom: parent.bottom; anchors.bottomMargin: 19
                    text: "0%"; font.pixelSize: 10
                    color: root.dayPalette ? "#18364a" : "#d9edf7"
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
                    FlightMap {
                        id: liveMap
                        anchors.fill: parent
                        zoomLevel: 17
                        function followBoat() {
                            if(root.replayMode) {
                                if(root.boatTrack.length) center=root.boatTrack[root.boatTrack.length-1]
                                return
                            }
                            if(root.vehicle && root.vehicle.coordinate && root.vehicle.coordinate.isValid)
                                center=root.vehicle.coordinate
                        }
                        Component.onCompleted: followBoat()
                        Connections { target: root; function onBoatTrackChanged() { if(root.replayMode) liveMap.followBoat() } }
                        Connections { target: root.vehicle; function onCoordinateChanged() { liveMap.followBoat() } }
                    }
                    MapPolyline {
                        parent: liveMap
                        objectName: "sonarProPlannedTrack"
                        line.width: 2; line.color: "#f6da46"
                        path: root.replayMode ? [] : root.plannedTrack
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
                        objectName: "sonarProBoatMarker"
                        parent: liveMap
                        coordinate: root.replayMode ? (root.boatTrack.length ? root.boatTrack[root.boatTrack.length-1] : QtPositioning.coordinate()) : (root.vehicle ? root.vehicle.coordinate : QtPositioning.coordinate())
                        visible: coordinate.isValid
                        anchorPoint.x: 18; anchorPoint.y: 18
                        sourceItem: Image {
                            width: 36; height: 36
                            source: "qrc:/qml/NavoSmart/icons/boat.svg"
                            rotation: !root.replayMode && root.vehicle && root.vehicle.heading ? root.vehicle.heading.rawValue-liveMap.bearing : 0
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
            id: telemetry; objectName: "sonarProTelemetry"; font.pixelSize: 14; anchors.fill: parent; anchors.margins: 8; elide: Text.ElideRight
            color: root.connected ? "#21b7ff" : "#9db2c5"
            text: "PRO  •  " + (root.connected ? (root.replayActive ? "TEST REPLAY" : (root.paused ? "PAUZĂ" : "LIVE")) : "OFFLINE") + "   " + (isFinite(root.depthM)?root.depthM.toFixed(1)+" m":"— m") + "   " + (isFinite(root.waterTempC)?root.waterTempC.toFixed(1)+" °C":"— °C")
        }
    }
    IconButton {
        id: menuButton
        objectName: "sonarProMenuButton"
        anchors.left: parent.left; anchors.top: telemetryBar.bottom; anchors.leftMargin: 10; anchors.topMargin: 18
        implicitWidth: 34; implicitHeight: 34; padding: 6
        z: 100; visible: true; enabled: true
        glyph: "settings"; hint: "Deschide / închide meniul Sonar PRO"
        checkable: true; checked: root.menuOpen
        onClicked: { root.settingsVisible = false; root.menuOpen = !root.menuOpen }
    }
    IconButton {
        id: closeButton
        objectName: "sonarProCloseButton"
        anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 6
        z: 102; glyph: "close"; hint: "Ieșire din Sonar PRO"
        onClicked: root.closed()
    }
    Rectangle {
        id: menuPanel
        visible: root.menuOpen
        z: 103
        anchors.left: parent.left; anchors.top: menuButton.bottom; anchors.topMargin: 4; anchors.leftMargin: 6
        width: Math.min(222,parent.width*.48)
        height: Math.min(menuColumn.implicitHeight+16,Math.max(0,parent.height-menuButton.height-55))
        radius: 8; color: "#ee0b1c2e"; border.color: "#31536c"
        ScrollView {
            anchors.fill: parent; anchors.margins: 8; clip: true
            contentWidth: availableWidth
            ColumnLayout {
                id: menuColumn; width: menuPanel.width-16; spacing: 3
                component MenuAction: Button {
                    id: action
                    property bool selected: false
                    Layout.fillWidth: true
                    implicitHeight: 32
                    font.pixelSize: 12
                    padding: 5
                    palette.buttonText: selected ? "#ffffff" : "#d7e7f1"
                    background: Rectangle { radius: 5; color: action.selected ? root.selectedMenuColor : (action.hovered ? "#183c51" : "#102435"); border.color: action.selected ? root.selectedMenuBorder : "#31536c"; border.width: action.selected ? 2 : 1 }
                }
                MenuAction { text: 'Deschide KLF (TEST)'; onClicked: {root.menuOpen=false; replayPicker.open()} }
                MenuAction { visible:root.replayActive; selected:root.chartSource && root.chartSource.replayPaused; text:root.chartSource && root.chartSource.replayPaused ? 'Continuă replay' : 'Pauză replay'; onClicked:root.chartSource.pauseReplay(!root.chartSource.replayPaused) }
                MenuAction { visible:root.replayActive; selected:root.replayActive; text:'Viteză replay: '+(root.chartSource ? root.chartSource.replaySpeed : 1)+'×'; onClicked:root.chartSource.setReplaySpeed(root.chartSource.replaySpeed>=5 ? 0.5 : root.chartSource.replaySpeed*2) }
                MenuAction { visible:root.replayMode; enabled:root.replaySampleCount>=3; text:"Salvează replay în Bălțile mele"; onClicked:{root.menuOpen=false;replaySaveDialog.open()} }
                Label { visible:root.replaySaveStatus.length>0; Layout.fillWidth:true; wrapMode:Text.WordWrap; text:root.replaySaveStatus; color:"#d7e7f1"; font.pixelSize:11 }
                MenuAction { visible:root.replayActive; text:'Oprește replay'; onClicked:root.chartSource.stopReplay() }
                MenuAction { selected:root.mapEnabled; text: root.mapEnabled ? "Ascunde harta" : "Activează harta"; onClicked: {root.mapEnabled=!root.mapEnabled;root.menuOpen=false} }
                MenuAction { selected:root.paused; text: root.paused ? "Continuă ecograma" : "Pauză ecogramă"; onClicked: root.paused=!root.paused }
                MenuAction { selected:root.dayPalette; text: root.dayPalette ? "Paletă NAVO" : "Paletă de zi"; onClicked: root.dayPalette=!root.dayPalette }
                MenuAction { selected:root.settingsVisible; text: "Sensibilitate și filtre"; onClicked: {root.settingsVisible=!root.settingsVisible;root.menuOpen=false} }
                MenuAction { selected:root.koggerCompensation; text: root.koggerCompensation ? "Ecou brut" : "Compensare Kogger"; onClicked: root.koggerCompensation=!root.koggerCompensation }
                MenuAction { selected:root.showBottomTrack; text: root.showBottomTrack ? "Ascunde linia fundului" : "Arată linia fundului"; onClicked: root.showBottomTrack=!root.showBottomTrack }
                MenuAction { text: "Reset reglaje"; onClicked: root.resetDisplaySettings() }
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
