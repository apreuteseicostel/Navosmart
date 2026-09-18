import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtLocation
import QtPositioning

Item {
    id: root
    required property var map
    property var vehicle
    property var planner
    property var missionController
    property var planController
    property bool missionPrepared: false
    property bool missionUploaded: false
    property bool uploadPending: false
    property bool uploadFailed: false
    property bool missionRunning: false
    property int missionPointCount: 0
    readonly property int currentMissionIndex: vehicle && vehicle.missionItemIndex ? Number(vehicle.missionItemIndex.rawValue) : -1
    readonly property int progressPercent: missionPointCount > 0 && currentMissionIndex >= 0 ? Math.max(0,Math.min(100,Math.round(currentMissionIndex*100/missionPointCount))) : 0
    property bool editing: false
    property var cornerA: QtPositioning.coordinate()
    property var cornerB: QtPositioning.coordinate()
    property real scanSpeedMps: 1.0
    property bool planReady: planner && planner.generatedPoints && planner.generatedPoints.length >= 4
    signal status(string text)
    signal startRequested(var points)
    signal uploadRequested(var points)

    function valid(c) { return c && c.isValid }
    function formatTime(seconds) {
        if (!isFinite(seconds) || seconds <= 0) return "--"
        var m=Math.ceil(seconds/60); return m<60 ? m+" min" : Math.floor(m/60)+" h "+(m%60)+" min"
    }
    function regenerate() {
        if(!planner || !valid(cornerA) || !valid(cornerB)) return
        planner.generateRectangle(cornerA,cornerB)
        if(vehicle && valid(vehicle.coordinate)) planner.reverseForNearestStart(vehicle.coordinate)
        status("Area Scan pregătit • "+planner.laneCount+" culoare • "+Math.round(planner.estimatedDistanceM)+" m")
    }
    function prepareMission() {
        if(!planReady || !missionController) { status("Area Scan: plan invalid"); return false }
        missionController.removeAll()
        for(var i=0;i<planner.generatedPoints.length;i++)
            missionController.insertSimpleMissionItem(planner.generatedPoints[i], i+1, false)
        missionPointCount=planner.generatedPoints.length
        missionPrepared=true; missionUploaded=false; missionRunning=false
        status("Area Scan: misiune pregătită • "+missionPointCount+" waypoint-uri")
        return true
    }
    function uploadMission() {
        if(!vehicle || !missionController || !planController) { status("Area Scan: H743/MAVLink indisponibil"); return }
        if(!missionPrepared && !prepareMission()) return
        missionUploaded=false; uploadFailed=false; uploadPending=true
        planController.sendToVehicle()
        status("Area Scan: se încarcă misiunea în H743…")
    }
    function startMission() {
        if(!vehicle || !missionUploaded) { status("Area Scan: încarcă misiunea înainte de START"); return }
        vehicle.setCurrentMissionSequence(1)
        vehicle.startMission()
        missionRunning=true
        status("Area Scan: START misiune solicitat")
    }
    function holdMission() {
        if(!vehicle) return
        vehicle.pauseVehicle(); missionRunning=false
        status("Area Scan: HOLD/STOP solicitat")
    }
    function rtlMission() {
        if(!vehicle) return
        vehicle.guidedModeRTL(false); missionRunning=false
        status("Area Scan: RTL solicitat")
    }
    function clearPlan() {
        cornerA=QtPositioning.coordinate(); cornerB=QtPositioning.coordinate()
        if(planner) planner.clear()
        editing=false; missionPrepared=false; missionUploaded=false; uploadPending=false; uploadFailed=false; missionRunning=false; missionPointCount=0; status("Area Scan șters")
    }

    Connections {
        target: root.planController
        function onSyncInProgressChanged() {
            if(!root.uploadPending || !root.planController || root.planController.syncInProgress) return
            root.uploadPending=false
            if(root.planController.dirtyForUpload) {
                root.missionUploaded=false; root.uploadFailed=true
                root.status("Area Scan: upload H743 nereușit • START blocat")
            } else {
                root.missionUploaded=true; root.uploadFailed=false
                root.status("Area Scan: misiune confirmată pe H743 • gata de START")
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.editing
        z: 1450
        onClicked: function(mouse) {
            var c=root.map.toCoordinate(Qt.point(mouse.x,mouse.y),false)
            if(!root.valid(root.cornerA) || root.valid(root.cornerB)) {
                root.cornerA=c; root.cornerB=QtPositioning.coordinate()
                if(root.planner) root.planner.clear()
                root.status("Area Scan: selectează colțul opus")
            } else {
                root.cornerB=c; root.editing=false; root.regenerate()
            }
        }
    }

    MapPolygon {
        id: boundaryItem
        path: root.planner ? root.planner.boundary : []
        color: "#2131d67b"; border.color: "#31d67b"; border.width: 2
        visible: root.planReady; z: 800
        Component.onCompleted: root.map.addMapItem(this)
        Component.onDestruction: root.map.removeMapItem(this)
    }
    MapPolyline {
        id: routeItem
        path: root.planner ? root.planner.generatedPoints : []
        line.width: 3; line.color: "#21b7ff"
        visible: root.planReady; z: 810
        Component.onCompleted: root.map.addMapItem(this)
        Component.onDestruction: root.map.removeMapItem(this)
    }

    Rectangle {
        anchors.left: parent.left; anchors.top: parent.top
        anchors.leftMargin: 12; anchors.topMargin: 52
        width: 320; height: root.planReady ? 302 : 118
        radius: 10; color: "#071827ee"; border.color: "#21b7ff"; z: 1500
        ColumnLayout {
            anchors.fill: parent; anchors.margins: 10; spacing: 6
            RowLayout {
                Layout.fillWidth: true
                Label { text:"AREA SCAN"; color:"#21b7ff"; font.bold:true; font.pixelSize:15 }
                Item { Layout.fillWidth:true }
                Button { text:root.editing?"ANULEAZĂ":"ALEGE ZONA"; onClicked:{root.editing=!root.editing;if(root.editing){root.cornerA=QtPositioning.coordinate();root.cornerB=QtPositioning.coordinate();if(root.planner)root.planner.clear();root.status("Area Scan: selectează primul colț")}} }
            }
            Label { visible:!root.planReady; Layout.fillWidth:true; wrapMode:Text.WordWrap; text:root.editing?"Atinge două colțuri opuse ale zonei de scanat.":"Alege zona pentru a genera traseul sonar tip șarpe."; color:"#9db2c5"; font.pixelSize:11 }
            GridLayout {
                visible:root.planReady; columns:2; Layout.fillWidth:true
                Label{text:"Suprafață";color:"#9db2c5"};Label{text:Math.round(root.planner?root.planner.estimatedAreaM2:0)+" m²";color:"white";font.bold:true}
                Label{text:"Traseu";color:"#9db2c5"};Label{text:Math.round(root.planner?root.planner.estimatedDistanceM:0)+" m";color:"white";font.bold:true}
                Label{text:"Culoare";color:"#9db2c5"};Label{text:(root.planner?root.planner.laneCount:0)+" • "+(root.planner?root.planner.orientation:"");color:"white";font.bold:true}
                Label{text:"ETA";color:"#9db2c5"};Label{text:root.formatTime((root.planner?root.planner.estimatedDistanceM:0)/Math.max(.2,root.scanSpeedMps));color:"#31d67b";font.bold:true}
            }
            RowLayout {
                visible:root.planReady; Layout.fillWidth:true
                Label { text:"Spațiere"; color:"#9db2c5" }
                SpinBox { from:1; to:20; value:root.planner?Math.round(root.planner.laneSpacingM):5; editable:true; onValueModified:{if(root.planner){root.planner.laneSpacingM=value;root.regenerate()}} }
                Label { text:"m"; color:"#9db2c5" }
                Item { Layout.fillWidth:true }
            }
            RowLayout {
                visible:root.planReady; Layout.fillWidth:true
                Button { text:"PREGĂTEȘTE"; enabled:root.planReady; onClicked:root.prepareMission() }
                Button { text:root.uploadPending?"SE ÎNCARCĂ…":"UPLOAD H743"; enabled:root.missionPrepared && root.vehicle && !root.uploadPending && !root.missionRunning; onClicked:root.uploadMission() }
                Button { text:"START"; enabled:root.missionUploaded && root.vehicle && !root.uploadPending && !root.missionRunning; onClicked:root.startMission() }
            }
            ProgressBar { visible:root.planReady; Layout.fillWidth:true; from:0; to:100; value:root.progressPercent }
            Label { visible:root.planReady; text:root.missionRunning ? "SCANARE "+root.progressPercent+"% • WP "+root.currentMissionIndex+"/"+root.missionPointCount : (root.missionUploaded?"Misiune încărcată • gata de START":(root.uploadPending?"Se așteaptă confirmarea H743…":(root.uploadFailed?"UPLOAD EȘUAT • START BLOCAT":(root.missionPrepared?"Misiune pregătită local":"Preview")))); color:root.missionRunning?"#31d67b":"#9db2c5"; font.bold:root.missionRunning }
            RowLayout {
                visible:root.planReady; Layout.fillWidth:true
                Button { text:"HOLD / STOP"; enabled:root.vehicle; onClicked:root.holdMission() }
                Button { text:"RTL"; enabled:root.vehicle; onClicked:root.rtlMission() }
                Item { Layout.fillWidth:true }
                Button { text:"ȘTERGE"; enabled:!root.missionRunning; onClicked:root.clearPlan() }
            }
        }
    }
}