import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import QtPositioning
import QtLocation
import QGroundControl.FlightMap
import "NavoBottomAnalysis.js" as BottomAnalysis

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
    function sourceStatusText() {
        if(chartSource && chartSource.replayMode)return replayActive ? "REPLAY" : "REPLAY • FINAL"
        return connected ? (chartSource && chartSource.recording ? "REC ●" : (paused ? "PAUZĂ" : "LIVE")) : "OFFLINE"
    }
    FileDialog { id: replayPicker; title: 'Încarcă înregistrare sonar'; nameFilters: ['Sonar NAVO / Kogger (*.navosonar *.klf)', 'Toate fișierele (*)']; onAccepted: { if(root.chartSource) {root.history=[];root.chartSource.startReplay(selectedFile)} } }
    readonly property var bottomAnalysis: bottomAnalysisDialog.visible && displayedColumn
        ? BottomAnalysis.column(displayedColumn.rawSamples,displayedColumn.offset,displayedColumn.range,displayedColumn.bottom) : ({valid:false})
    readonly property var bottomProfile: bottomAnalysisDialog.visible ? BottomAnalysis.profile(history) : ({valid:false})
    Dialog {
        id:bottomAnalysisDialog;objectName:"sonarBottomAnalysisDialog"
        title:"Fund & ecouri • analiză relativă";modal:true
        width:Math.min(440,root.width-16);height:Math.min(420,root.height-16);anchors.centerIn:parent
        footer:DialogButtonBox {Button{text:"Închide";DialogButtonBox.buttonRole:DialogButtonBox.RejectRole}}
        contentItem:ScrollView {
            clip:true;contentWidth:availableWidth
            ColumnLayout {
                width:parent.width;spacing:10
                Label {Layout.fillWidth:true;wrapMode:Text.WordWrap;text:"Sursă: "+root.sourceStatusText()+" • ultima coloană afișată"}
                Label {Layout.fillWidth:true;wrapMode:Text.WordWrap;text:"Material: NECLASIFICAT. Mâl, pietriș și vegetație necesită măsurători de referință. Aceasta este analiza CHART 2D, nu un mod DownScan."}
                Label {Layout.fillWidth:true;wrapMode:Text.WordWrap;text:root.bottomAnalysis.valid ?
                    "Fund: "+root.bottomAnalysis.bottomM.toFixed(2)+" m\nEcou brut maxim: "+Math.round(root.bottomAnalysis.peak*100)+"% din scala amplitudinii\nEcou mediu în fereastră: "+Math.round(root.bottomAnalysis.mean*100)+"%\nLățime la jumătatea maximului: "+(root.bottomAnalysis.widthLimited ? "≥ " : "")+root.bottomAnalysis.widthM.toFixed(2)+" m\nRezoluție verticală: "+root.bottomAnalysis.stepM.toFixed(3)+" m" : root.bottomAnalysis.reason || "Aștept fundul procesat al coloanei CHART curente."}
                Label {Layout.fillWidth:true;wrapMode:Text.WordWrap;text:root.bottomAnalysis.valid && root.bottomAnalysis.aboveEchoes!==null ?
                    "Grupuri de ecouri deasupra fundului: "+root.bottomAnalysis.aboveEchoes+(isFinite(root.bottomAnalysis.aboveHeightM) ? "\nÎnălțime maximă relativă: "+root.bottomAnalysis.aboveHeightM.toFixed(2)+" m" : "")+"\nPot proveni din pești, vegetație, obiecte sau zgomot; nu sunt identificări confirmate." : "Coloană de apă insuficientă pentru analiza ecourilor de deasupra fundului."}
                Label {Layout.fillWidth:true;wrapMode:Text.WordWrap;text:root.bottomProfile.valid ?
                    "Profil recent ("+root.bottomProfile.count+" coloane): "+root.bottomProfile.minM.toFixed(2)+"–"+root.bottomProfile.maxM.toFixed(2)+" m\nVariație verticală: "+root.bottomProfile.variationM.toFixed(2)+" m. Nu indică panta fără distanță GPS validată." : "Profil recent: sunt necesare cel puțin 3 coloane cu fund valid."}
                Label {Layout.fillWidth:true;wrapMode:Text.WordWrap;text:"Valorile provin din ecoul brut, înainte de paletă, sensibilitate și filtrele afișării. Intensitatea ecoului nu este duritatea fizică a fundului."}
            }
        }
    }
    Dialog {
        id: recordingDialog
        objectName: "sonarRecordingDialog"
        title: "Înregistrare sonar"
        modal: true
        width: Math.min(360, root.width-16)
        anchors.centerIn: parent
        footer: DialogButtonBox {
            Button { text:"Pornește"; DialogButtonBox.buttonRole:DialogButtonBox.AcceptRole }
            Button { text:"Renunță"; DialogButtonBox.buttonRole:DialogButtonBox.RejectRole }
        }
        contentItem: ColumnLayout {
            TextField { id: recordingName; objectName:"sonarRecordingName"; Layout.fillWidth:true; placeholderText:"Nume baltă / sesiune"; maximumLength:120 }
            Label { Layout.fillWidth:true; wrapMode:Text.WordWrap; text:"Salvează ecourile brute și poziția GPS la recepție. Oprește înregistrarea pentru a o păstra offline." }
        }
        onAccepted: { if(root.chartSource)root.chartSource.startRecording(recordingName.text) }
    }
    Dialog {
        id: recordingsDialog
        objectName: "sonarRecordingsDialog"
        title: "Sesiuni sonar offline"
        modal:true
        width:Math.min(440,root.width-16)
        height:Math.min(420,root.height-16)
        anchors.centerIn:parent
        footer:DialogButtonBox { Button {text:"Închide"; DialogButtonBox.buttonRole:DialogButtonBox.RejectRole} }
        onOpened: { if(root.chartSource)root.chartSource.refreshRecordings() }
        contentItem: ColumnLayout {
            Label { Layout.fillWidth:true; wrapMode:Text.WordWrap; text:"Redeschide o sesiune salvată pe acest dispozitiv. Replay-ul nu comandă barca." }
            Label { visible:!root.chartSource || !root.chartSource.recordings || root.chartSource.recordings.length===0; text:"Nu ai sesiuni salvate încă." }
            ListView {
                id: recordingsList
                objectName:"sonarRecordingsList"
                Layout.fillWidth:true; Layout.fillHeight:true
                clip:true; spacing:5
                model:root.chartSource && root.chartSource.recordings ? root.chartSource.recordings : []
                delegate: Button {
                    required property var modelData
                    width:recordingsList.width
                    text:modelData.name + " · " + (modelData.size/1048576).toFixed(1) + " MiB\n" + modelData.createdUtc
                    onClicked: {root.history=[];root.chartSource.startReplay(modelData.url);recordingsDialog.close()}
                }
                ScrollBar.vertical:ScrollBar {}
            }
        }
    }
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
    property string activeLakeId: ""
    property string pointSaveStatus: ""
    property bool pointPicking: false
    property bool pointPreviousPaused: false
    property var selectedSonarPoint: null
    signal sonarPointRequested(var entry, string name, string note, bool prepareMission)
    function beginPointPick() {
        if(replayMode || !activeLakeId.length || !history.length)return false
        pointPreviousPaused=paused;paused=true;pointPicking=true;pointSaveStatus=""
        return true
    }
    function endPointPick() {
        if(pointPicking)paused=pointPreviousPaused
        pointPicking=false
    }
    function closePointDialog() { sonarPointDialog.close();endPointPick() }
    function selectSonarPoint(x, chartWidth) {
        if(!pointPicking || !(chartWidth>0) || x<0 || x>=chartWidth)return false
        var index=Math.floor(x/chartWidth*historyColumns)-(historyColumns-history.length)
        if(index<0 || index>=history.length)return false
        var e=history[index]
        selectedSonarPoint={latitude:e.latitude,longitude:e.longitude,time:e.time,
            temp:e.temp,bottom:e.bottom,sequence:e.sequence,offset:e.offset,range:e.range,
            lakeId:e.lakeId,replay:e.replay}
        sonarPointName.text="";sonarPointNote.text="";pointSaveStatus=""
        sonarPointDialog.open();return true
    }
    function sonarPointValid(e) {
        return e && !e.replay && !replayMode && e.lakeId===activeLakeId && activeLakeId.length>0 &&
            typeof e.latitude==="number" && isFinite(e.latitude) && Math.abs(e.latitude)<=90 &&
            typeof e.longitude==="number" && isFinite(e.longitude) && Math.abs(e.longitude)<=180
    }
    Dialog {
        id:sonarPointDialog;objectName:"sonarPointDialog";title:"Punct din ecogramă"
        parent:Overlay.overlay;anchors.centerIn:parent;modal:true
        width:Math.min(420,root.width-16);height:Math.min(390,root.height-16)
        onClosed:root.endPointPick()
        contentItem:ScrollView {
            clip:true;contentWidth:availableWidth
            ColumnLayout {
                width:parent.width;spacing:8
                Label { Layout.fillWidth:true;wrapMode:Text.WordWrap
                    text:root.sonarPointValid(root.selectedSonarPoint) ? "GPS-ul coloanei selectate • "+new Date(root.selectedSonarPoint.time).toLocaleTimeString()+"\nFund: "+(isFinite(root.selectedSonarPoint.bottom) ? root.selectedSonarPoint.bottom.toFixed(2)+" m" : "indisponibil") : "Această coloană nu are GPS valid în balta activă. Nu poate fi salvată pe hartă." }
                TextField { id:sonarPointName;objectName:"sonarPointName";Layout.fillWidth:true;maximumLength:80;placeholderText:"Nume (opțional)" }
                TextField { id:sonarPointNote;Layout.fillWidth:true;maximumLength:300;placeholderText:"Notă (opțional)" }
                Label { Layout.fillWidth:true;wrapMode:Text.WordWrap;text:root.pointSaveStatus }
                Button { objectName:"saveSonarPoint";Layout.fillWidth:true;text:"SALVEAZĂ PUNCT";enabled:root.sonarPointValid(root.selectedSonarPoint)
                    onClicked:root.sonarPointRequested(root.selectedSonarPoint,sonarPointName.text.trim(),sonarPointNote.text.trim(),false) }
                Button { objectName:"prepareSonarPoint";Layout.fillWidth:true;text:"SALVEAZĂ ȘI PREGĂTEȘTE MISIUNEA";enabled:root.sonarPointValid(root.selectedSonarPoint)
                    onClicked:root.sonarPointRequested(root.selectedSonarPoint,sonarPointName.text.trim(),sonarPointNote.text.trim(),true) }
                Label { Layout.fillWidth:true;wrapMode:Text.WordWrap;text:"Pregătirea deschide Mergi la punct. Alegi cuvele și confirmi START separat." }
                Button { Layout.fillWidth:true;text:"ÎNCHIDE";onClicked:sonarPointDialog.close() }
            }
        }
    }
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
        var raw=chartSource ? chartSource.echoSamples.slice(0) : column.slice(0)
        var h = history.slice(0)
        var v=root.vehicle
        var fix=!root.replayMode && v && v.gps && v.gps.lock.rawValue>=3 &&
            v.vehicleLinkManager && !v.vehicleLinkManager.communicationLost
        var c=fix && v.coordinate && v.coordinate.isValid ? v.coordinate : null
        h.push({rawSamples:raw,samples:chartSource && koggerCompensation ? column.slice(0) : raw, offset: offset, range: range, sequence: chartSource ? chartSource.chartSequence : 0,
                latitude:c ? c.latitude : NaN,longitude:c ? c.longitude : NaN,time:Date.now(),
                temp:root.waterTempC,lakeId:root.activeLakeId,replay:root.replayMode,
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
        target: root.chartSource || null
        function onEchoSamplesChanged() { root.captureGeoChart(); root.pushHistory() }
        function onBottomColumnReady(sequence,depth) { root.updateHistoryBottom(sequence,depth) }
    }
    onSamplesChanged: if (!chartSource) Qt.callLater(pushHistory)
    Component.onCompleted: Qt.callLater(pushHistory)
    onHistoryChanged: { if (!history.length) rasterCache = []; repaint() }
    onActiveLakeIdChanged: { endPointPick();sonarPointDialog.close();history=[] }
    onReplayModeChanged: { endPointPick();sonarPointDialog.close();history=[] }
    onGainChanged: repaint()
    onNoiseFloorChanged: repaint()
    onNoiseFilterEnabledChanged: repaint()
    onDayPaletteChanged: repaint()
    onReplayActiveChanged: { if(replayActive)history=[]; root.menuOpen=false }
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
                MouseArea {
                    anchors.fill:parent;enabled:root.pointPicking;cursorShape:Qt.CrossCursor
                    onClicked:function(mouse){root.selectSonarPoint(mouse.x,width)}
                }
            }
            Label {
                anchors.horizontalCenter:echogram.horizontalCenter;anchors.bottom:parent.bottom
                visible:root.pointPicking;z:2;text:"Atinge coloana sonar • PAUZĂ";color:"#ffffff"
                background:Rectangle { color:"#176b86";radius:4 }
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
            text: "PRO  •  " + root.sourceStatusText() + "   " + (isFinite(root.depthM)?root.depthM.toFixed(1)+" m":"— m") + "   " + (isFinite(root.waterTempC)?root.waterTempC.toFixed(1)+" °C":"— °C")
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
                MenuAction { visible:!!(root.chartSource && !root.replayMode); enabled:!!(root.chartSource && (root.chartSource.recording || root.chartSource.dataAlive)); selected:!!(root.chartSource && root.chartSource.recording); text:root.chartSource && root.chartSource.recording ? 'Oprește și salvează REC' : 'Înregistrează sesiunea'; onClicked: {root.menuOpen=false;if(root.chartSource.recording)root.chartSource.stopRecording();else recordingDialog.open()} }
                MenuAction { text:'Analiză fund și ecouri'; enabled:root.history.length>0; onClicked:{root.menuOpen=false;bottomAnalysisDialog.open()} }
                MenuAction { text:root.pointPicking ? 'Anulează alegerea punctului' : 'Salvează punct din ecogramă'; selected:root.pointPicking
                    enabled:root.pointPicking || (!root.replayMode && root.activeLakeId.length>0 && root.history.length>0)
                    onClicked:{root.menuOpen=false;if(root.pointPicking)root.endPointPick();else root.beginPointPick()} }
                MenuAction { text:'Sesiuni offline'; onClicked:{root.menuOpen=false;recordingsDialog.open()} }
                Label { visible:!!(root.chartSource && root.chartSource.recording); Layout.fillWidth:true; wrapMode:Text.WordWrap; text:root.chartSource ? 'REC · '+(root.chartSource.recordingBytes/1048576).toFixed(1)+' MiB' : ''; color:'#ffbd69'; font.pixelSize:11 }
                Label { visible:!!(root.chartSource && root.chartSource.recordingError && root.chartSource.recordingError.length>0); Layout.fillWidth:true; wrapMode:Text.WordWrap; text:root.chartSource ? root.chartSource.recordingError || '' : ''; color:'#ffbd69'; font.pixelSize:11 }
                Label { visible:!!(root.chartSource && !root.chartSource.recording && root.chartSource.recordingSavedName && root.chartSource.recordingSavedName.length>0); Layout.fillWidth:true; wrapMode:Text.WordWrap; text:root.chartSource ? 'Salvat: '+(root.chartSource.recordingSavedName || '') : ''; color:'#d7e7f1'; font.pixelSize:11 }
                Label { visible:!!(root.chartSource && root.chartSource.replayError && root.chartSource.replayError.length>0); Layout.fillWidth:true; wrapMode:Text.WordWrap; text:root.chartSource ? root.chartSource.replayError || '' : ''; color:'#ffbd69'; font.pixelSize:11 }
                MenuAction { text: 'Deschide fișier sonar'; onClicked: {root.menuOpen=false; replayPicker.open()} }
                MenuAction { visible:root.replayActive; selected:!!(root.chartSource && root.chartSource.replayPaused); text:root.chartSource && root.chartSource.replayPaused ? 'Continuă replay' : 'Pauză replay'; onClicked:root.chartSource.pauseReplay(!root.chartSource.replayPaused) }
                MenuAction { visible:root.replayActive; selected:root.replayActive; text:'Viteză replay: '+(root.chartSource ? root.chartSource.replaySpeed : 1)+'×'; onClicked:root.chartSource.setReplaySpeed(root.chartSource.replaySpeed>=5 ? 0.5 : root.chartSource.replaySpeed*2) }
                MenuAction { visible:root.replayMode; enabled:root.replaySampleCount>=3; text:"Salvează replay în Bălțile mele"; onClicked:{root.menuOpen=false;replaySaveDialog.open()} }
                Label { visible:root.replaySaveStatus.length>0; Layout.fillWidth:true; wrapMode:Text.WordWrap; text:root.replaySaveStatus; color:"#d7e7f1"; font.pixelSize:11 }
                MenuAction { visible:root.replayMode; text:'Închide replay'; onClicked:root.chartSource.stopReplay() }
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
