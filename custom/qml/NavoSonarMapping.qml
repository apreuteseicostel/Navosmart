import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    property var vehicle
    property real depthM: NaN
    property real waterTempC: NaN
    property bool sonarConnected: false
    property bool scanning: false
    property bool paused: false
    property bool bathymetryComplete: false
    property var rawSamples: []
    property var trackCoordinates: []
    property var depthPoints: []
    property real minDepthM: NaN
    property real maxDepthM: NaN
    signal status(string text)
    signal bathymetryRequested(var samples)

    color: "#0b1c2e"
    border.color: "#1c4262"
    radius: 10

    function validPosition() { return vehicle && vehicle.coordinate && vehicle.coordinate.isValid }
    function startScan() {
        if (!validPosition() || !sonarConnected) { status("Scanare blocată: GPS și Kogger trebuie conectate"); return }
        rawSamples=[]; trackCoordinates=[]; depthPoints=[]; minDepthM=NaN; maxDepthM=NaN; bathymetryComplete=false; scanning=true; paused=false
        status("Mapare sonar pornită")
    }
    function pauseScan() { if(scanning){paused=true; status("Mapare sonar în pauză • datele sunt păstrate")} }
    function resumeScan() { if(scanning){paused=false; status("Mapare sonar continuată")} }
    function addGeoSample(sample) {
        if(!scanning || paused || !sample || isNaN(sample.lat) || isNaN(sample.lon) || isNaN(sample.depth)) return
        var s=rawSamples.slice(0); s.push(sample); rawSamples=s
        var d=depthPoints.slice(0); d.push({latitude:sample.lat,longitude:sample.lon,depth:sample.depth,heading:sample.heading,time:sample.time}); depthPoints=d
        minDepthM=isNaN(minDepthM)?sample.depth:Math.min(minDepthM,sample.depth); maxDepthM=isNaN(maxDepthM)?sample.depth:Math.max(maxDepthM,sample.depth)
    }
    function addCurrentSample() {
        if(!scanning || paused || !validPosition() || !sonarConnected || isNaN(depthM)) return
        var c=vehicle.coordinate
        var s=rawSamples.slice(0)
        s.push({lat:c.latitude, lon:c.longitude, depth:depthM, temp:waterTempC, heading:vehicle.heading?vehicle.heading.rawValue:NaN, time:Date.now()})
        rawSamples=s
        var d=depthPoints.slice(0); d.push({latitude:c.latitude,longitude:c.longitude,depth:depthM,heading:vehicle.heading?vehicle.heading.rawValue:NaN,time:Date.now()}); depthPoints=d
        minDepthM=isNaN(minDepthM)?depthM:Math.min(minDepthM,depthM); maxDepthM=isNaN(maxDepthM)?depthM:Math.max(maxDepthM,depthM)
        var t=trackCoordinates.slice(0)
        if(t.length===0 || t[t.length-1].distanceTo(c)>=1.0){t.push(c); trackCoordinates=t}
    }
    function finishAndBuild() {
        if(!scanning) return
        scanning=false; paused=false
        if(rawSamples.length<3){status("Mapare incompletă: prea puține măsurători valide"); return}
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
        rawSamples=[]; trackCoordinates=[]; depthPoints=[]; minDepthM=NaN; maxDepthM=NaN
        status("Datele brute GPS + sonar au fost șterse")
    }

    Connections {
        target: root.vehicle
        function onCoordinateChanged(){
            if(!root.scanning || root.paused || !root.validPosition()) return
            var c=root.vehicle.coordinate, t=root.trackCoordinates.slice(0)
            if(t.length===0 || t[t.length-1].distanceTo(c)>=1.0){t.push(c); root.trackCoordinates=t}
        }
    }

    ColumnLayout {
        anchors.fill: parent; anchors.margins: 12; spacing: 8
        Label { text:"MAPARE SONAR / BATIMETRIE"; color:"#21b7ff"; font.bold:true }
        Label { text: root.scanning ? (root.paused ? "PAUZĂ" : "SCANARE ACTIVĂ") : (root.bathymetryComplete ? "HARTĂ SALVATĂ" : "PREGĂTIT"); color:"#f2f7fb"; font.bold:true }
        Label { text: "Puncte: "+root.rawSamples.length+" • Adâncime: "+(isNaN(root.minDepthM)?"--":root.minDepthM.toFixed(1))+"–"+(isNaN(root.maxDepthM)?"--":root.maxDepthM.toFixed(1))+" m"; color:"#9db2c5" }
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
