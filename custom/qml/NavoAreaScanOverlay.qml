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
    property bool editing: false
    property var cornerA: QtPositioning.coordinate()
    property var cornerB: QtPositioning.coordinate()
    property real scanSpeedMps: 1.0
    property bool planReady: planner && planner.generatedPoints && planner.generatedPoints.length >= 4
    signal status(string text)
    signal startRequested(var points)

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
    function clearPlan() {
        cornerA=QtPositioning.coordinate(); cornerB=QtPositioning.coordinate()
        if(planner) planner.clear()
        editing=false; status("Area Scan șters")
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
        width: 300; height: root.planReady ? 226 : 118
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
                Button { text:"ȘTERGE"; onClicked:root.clearPlan() }
                Item { Layout.fillWidth:true }
                Button {
                    text:"PORNEȘTE SCANAREA"
                    enabled:root.planReady && root.vehicle && root.vehicle.coordinate && root.vehicle.coordinate.isValid
                    onClicked:{root.startRequested(root.planner.generatedPoints);root.status("Area Scan confirmat • pregătit pentru misiune ArduPilot")}
                }
            }
        }
    }
}