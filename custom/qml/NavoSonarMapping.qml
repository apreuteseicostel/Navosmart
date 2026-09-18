import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    property var vehicle
    property real depthM: NaN
    property real waterTempC: NaN
    property bool sonarConnected: false\n    property real bottomHardness: NaN\n    property real bottomEchoStrength: NaN
    property bool scanning: false
    property bool paused: false
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
    function startScan() {
        if (!validPosition() || !sonarConnected) { status("Scanare blocată: GPS și Kogger trebuie conectate"); return }
        rawSamples=[]; trackCoordinates=[]; bathymetryComplete=false; scanning=true; paused=false
        addCurrentSample(); status("Mapare sonar pornită")
    }
    function pauseScan() { if(scanning){paused=true; saveCheckpoint("pause"); status("Mapare sonar în pauză • datele sunt păstrate")} }
    function setLaneProgress(laneIndex, completed, total){ currentLane=laneIndex; completedLanes=completed; totalLanes=total; saveCheckpoint("lane") }
    function saveCheckpoint(reason){ resumeState={lakeId:lakeId,currentLane:currentLane,completedLanes:completedLanes,totalLanes:totalLanes,sampleCount:rawSamples.length,lastCoordinate:trackCoordinates.length?trackCoordinates[trackCoordinates.length-1]:null,reason:reason,time:Date.now()}; checkpointRequested(resumeState) }
    function restoreCheckpoint(state){ if(!state)return false; resumeState=state; lakeId=state.lakeId||""; currentLane=state.currentLane||0; completedLanes=state.completedLanes||0; totalLanes=state.totalLanes||0; paused=true; scanning=true; status("Scanare restaurată • continuă de la culoarul "+(currentLane+1)); return true }
    function resumeScan() { if(scanning){paused=false; status("Mapare sonar continuată")} }
    function addCurrentSample() {
        if(!scanning || paused || !validPosition() || !sonarConnected || isNaN(depthM)) return
        var c=vehicle.coordinate
        var s=rawSamples.slice(0)
        s.push({lat:c.latitude, lon:c.longitude, depth:depthM, temp:waterTempC, hardness:bottomHardness, bottomEcho:bottomEchoStrength, time:Date.now()})
        rawSamples=s
        var t=trackCoordinates.slice(0)
        if(t.length===0 || t[t.length-1].distanceTo(c)>=1.0){t.push(c); trackCoordinates=t}
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
        target: root.vehicle
        function onCoordinateChanged(){ root.addCurrentSample() }
    }

    ColumnLayout {
        anchors.fill: parent; anchors.margins: 12; spacing: 8
        Label { text:"MAPARE SONAR / BATIMETRIE"; color:"#21b7ff"; font.bold:true }
        Label { text: root.scanning ? (root.paused ? "PAUZĂ" : "SCANARE ACTIVĂ") : (root.bathymetryComplete ? "HARTĂ SALVATĂ" : "PREGĂTIT"); color:"#f2f7fb"; font.bold:true }
        Label { text: "Puncte valide: "+root.rawSamples.length+" • Urmă GPS: "+root.trackCoordinates.length; color:"#9db2c5" }
        RowLayout {
            Layout.fillWidth:true
            Button { text:"START SCAN"; enabled:!root.scanning; onClicked:root.startScan() }
            Button { text:root.paused?"CONTINUĂ":"PAUZĂ"; enabled:root.scanning; onClicked:root.paused?root.resumeScan():root.pauseScan() }
            Button { text:"FINALIZEAZĂ"; enabled:root.scanning; onClicked:root.finishAndBuild() }
        }
        Button { Layout.fillWidth:true; text:"ȘTERGE DATELE BRUTE"; enabled:!root.scanning && root.rawSamples.length>0; onClicked:root.deleteRawData() }
        Label { Layout.fillWidth:true; wrapMode:Text.WordWrap; color:"#9db2c5"; text:"Urma GPS este temporară. Se elimină automat numai după confirmarea că harta batimetrică a fost generată și salvată. Datele brute GPS + sonar se păstrează până la ștergerea explicită." }
    }
}
