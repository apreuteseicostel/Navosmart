import QtQuick
import QtQuick.Controls
import QtPositioning
import QtQuick.Layouts

Rectangle {
    id: root
    property var vehicle
    property real depthM: NaN
    property real waterTempC: NaN
    property bool sonarConnected: false
    property bool externalSampleIngestion: false
    property real bottomHardness: NaN
    property real bottomEchoStrength: NaN
    property bool scanning: false
    property bool paused: false
    // Passive Kogger mapping works in MANUAL/GUIDED, independently of Area Scan.
    // Never uses route, autopilot or hopper commands.
    property bool liveMappingActive: false
    property bool liveMappingPaused: false
    property bool liveMappingCapacityReached: false
    property bool liveGpsReady: false
    property bool replayMode: false
    property int maxLiveSamples: 25000
    property bool bathymetryComplete: false
    property var rawSamples: []
    property var trackCoordinates: []
    property string lakeId: ""
    property int currentLane: 0
    property int completedLanes: 0
    property int totalLanes: 0
    property var resumeState: ({})
    signal status(string text)
    signal bathymetryRequested(var samples)
    signal checkpointRequested(var state)

    color: "#0b1c2e"
    border.color: "#1c4262"
    radius: 10

    function validPosition() { return vehicle && vehicle.coordinate && vehicle.coordinate.isValid }
    onLakeIdChanged: { liveMappingActive=false;liveMappingPaused=false;liveMappingCapacityReached=false }
    onReplayModeChanged: {
        if(replayMode && liveMappingActive) {
            liveMappingActive=false;liveMappingPaused=false
            status("Replay activ: maparea live a fost oprită")
        }
    }
    onLiveGpsReadyChanged: {
        if(liveMappingActive && !liveMappingPaused && !liveGpsReady) {
            liveMappingPaused=true
            status("Mapare live în pauză: GPS H743 invalid sau MAVLink pierdut")
        }
    }
    onSonarConnectedChanged: {
        if(liveMappingActive && !liveMappingPaused && !sonarConnected) {
            liveMappingPaused=true
            status("Mapare live în pauză: Kogger nu mai transmite")
        }
    }
    function startLiveMapping() {
        if(replayMode || scanning || liveMappingActive || !lakeId.length ||
           !sonarConnected || !liveGpsReady || !validPosition()) return false
        if(rawSamples.length>=maxLiveSamples) {
            liveMappingCapacityReached=true
            status("Limită de măsurători atinsă: salvează harta înainte de altă scanare")
            return false
        }
        liveMappingCapacityReached=false
        liveMappingActive=true;liveMappingPaused=false;bathymetryComplete=false
        status("BATIMETRIE LIVE: înregistrare GPS + Kogger pornită • fără autopilot")
        return true
    }
    function pauseLiveMapping() {
        if(!liveMappingActive || liveMappingPaused) return false
        liveMappingPaused=true;status("Batimetrie live în pauză • datele sunt păstrate")
        return true
    }
    function resumeLiveMapping() {
        if(!liveMappingActive || !liveMappingPaused || replayMode ||
           !sonarConnected || !liveGpsReady || !validPosition() ||
           rawSamples.length>=maxLiveSamples) return false
        liveMappingPaused=false;status("Batimetrie live reluată")
        return true
    }
    function stopLiveMapping() {
        if(!liveMappingActive) return false
        liveMappingActive=false;liveMappingPaused=false
        status("Batimetrie live oprită • măsurătorile se păstrează pentru salvare")
        return true
    }
    function startScan() {
        if (typeof liveMappingActive!=="undefined" && liveMappingActive) { status("Oprește maparea manuală înainte de Area Scan"); return }
        if (!validPosition() || !sonarConnected) { status("Scanare blocată: GPS și Kogger trebuie conectate"); return }
        rawSamples=[]; trackCoordinates=[]; bathymetryComplete=false; scanning=true; paused=false
        addCurrentSample(); status("Mapare sonar pornită")
    }
    function pauseScan() { if(scanning){paused=true; saveCheckpoint("pause"); status("Mapare sonar în pauză • datele sunt păstrate")} }
    function setLaneProgress(laneIndex, completed, total){ currentLane=laneIndex; completedLanes=completed; totalLanes=total; saveCheckpoint("lane") }
    function saveCheckpoint(reason){ resumeState={lakeId:lakeId,currentLane:currentLane,completedLanes:completedLanes,totalLanes:totalLanes,sampleCount:rawSamples.length,lastCoordinate:trackCoordinates.length?trackCoordinates[trackCoordinates.length-1]:null,reason:reason,time:Date.now()}; checkpointRequested(resumeState) }
    function restoreCheckpoint(state){ if(!state)return false; resumeState=state; lakeId=state.lakeId||""; currentLane=state.currentLane||0; completedLanes=state.completedLanes||0; totalLanes=state.totalLanes||0; paused=true; scanning=true; status("Scanare restaurată • continuă de la culoarul "+(currentLane+1)); return true }
    function resumeScan() {
        if(!scanning) { status("Resume sonar indisponibil: nu există scanare restaurată"); return false }
        if(!validPosition()) { paused=true; status("Resume blocat: GPS indisponibil"); return false }
        if(!sonarConnected) { paused=true; status("Resume blocat: Kogger fără date live"); return false }
        paused=false; saveCheckpoint("resume"); status("Mapare sonar continuată"); return true
    }
    function ingestSample(sample) {
        var manual=(typeof liveMappingActive!=="undefined" && liveMappingActive) && !scanning
        if((!scanning && !manual) || (scanning && paused) ||
           (manual && (liveMappingPaused || !liveGpsReady || replayMode)) ||
           !sonarConnected || !sample) return
        // Do not discard old data when the manual recording reaches capacity.
        if(manual && rawSamples.length>=maxLiveSamples) {
            if(!liveMappingCapacityReached) status("Limită 25.000 măsurători • salvează harta")
            liveMappingCapacityReached=true;liveMappingPaused=true
            return
        }
        // Never coerce missing/null GPS into (0,0), or strings/booleans into a
        // valid bathymetry point. 0,0 remains valid when actually numeric.
        if(typeof sample.lat!=="number" || typeof sample.lon!=="number" ||
           typeof sample.depth!=="number") return
        var lat=sample.lat, lon=sample.lon, depth=sample.depth
        if(!isFinite(lat)||!isFinite(lon)||Math.abs(lat)>90||Math.abs(lon)>180 ||
           !isFinite(depth)||depth<=0) return
        var s=rawSamples.slice(0)
        s.push({sequence:sample.sequence,source:sample.source,lat:lat,lon:lon,depth:depth,temp:sample.temp,hardness:(sample.hardness===undefined||!isFinite(Number(sample.hardness)))?bottomHardness:Number(sample.hardness),bottomEcho:(sample.bottomEcho===undefined||!isFinite(Number(sample.bottomEcho)))?bottomEchoStrength:Number(sample.bottomEcho),chartResolution:sample.chartResolution,chartAbsoluteOffset:sample.chartAbsoluteOffset,chartVersion:sample.chartVersion,chartResolutionMeters:sample.chartResolutionMeters,chartOffsetMeters:sample.chartOffsetMeters,chartRangeMeters:sample.chartRangeMeters,time:sample.time||Date.now()})
        rawSamples=s
        var c=QtPositioning.coordinate(lat,lon),t=trackCoordinates.slice(0)
        if(t.length===0 || t[t.length-1].distanceTo(c)>=1.0){t.push(c);trackCoordinates=t}
    }
    function addCurrentSample() {
        if(externalSampleIngestion || !scanning || paused || !validPosition() || !sonarConnected || isNaN(depthM)) return
        ingestSample({lat:vehicle.coordinate.latitude,lon:vehicle.coordinate.longitude,depth:depthM,temp:waterTempC,hardness:bottomHardness,bottomEcho:bottomEchoStrength,time:Date.now()})
    }
    function finishAndBuild() {
        if(!scanning) return
        addCurrentSample(); scanning=false; paused=false
        if(rawSamples.length<3){status("Mapare incompletă: prea puține măsurători valide"); return}
        saveCheckpoint("finish")
        bathymetryRequested(rawSamples)
        status("Date scanare pregătite pentru generarea hărții batimetrice")
    }
    function markBathymetrySaved(success) {
        if(!success){bathymetryComplete=false; status("Harta batimetrică nu a fost salvată • urma GPS este păstrată"); return}
        bathymetryComplete=true
        trackCoordinates=[]
        status("Hartă batimetrică salvată • urma GPS temporară a fost eliminată")
    }
    function deleteRawData() {
        if(scanning) return
        rawSamples=[]; trackCoordinates=[]
        status("Datele brute GPS + sonar au fost șterse")
    }

    Connections {
        target: root.vehicle || null
        function onCoordinateChanged(){ root.addCurrentSample() }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        Label {
            text: "MAPARE SONAR / BATIMETRIE"
            color: "#21b7ff"
            font.bold: true
        }
        Label {
            text: root.scanning ? (root.paused ? "PAUZĂ" : "SCANARE ACTIVĂ") : (root.bathymetryComplete ? "HARTĂ SALVATĂ" : "PREGĂTIT")
            color: "#f2f7fb"
            font.bold: true
        }
        Label {
            text: "Puncte valide: " + root.rawSamples.length + " • Urmă GPS: " + root.trackCoordinates.length
            color: "#9db2c5"
        }
        RowLayout {
            Layout.fillWidth: true
            Button {
                text: "START SCAN"
                enabled: !root.scanning
                onClicked: root.startScan()
            }
            Button {
                text: root.paused ? "CONTINUĂ" : "PAUZĂ"
                enabled: root.scanning
                onClicked: root.paused ? root.resumeScan() : root.pauseScan()
            }
            Button {
                text: "FINALIZEAZĂ"
                enabled: root.scanning
                onClicked: root.finishAndBuild()
            }
        }
        Button {
            Layout.fillWidth: true
            text: "ȘTERGE DATELE BRUTE"
            enabled: !root.scanning && root.rawSamples.length > 0
            onClicked: root.deleteRawData()
        }
        Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: "#9db2c5"
            text: "Urma GPS este temporară. Se elimină automat numai după confirmarea că harta batimetrică a fost generată și salvată. Datele brute GPS + sonar se păstrează până la ștergerea explicită."
        }
    }
}
