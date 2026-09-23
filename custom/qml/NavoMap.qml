import QtQuick
import QtPositioning
import QtLocation
import QtQuick.Controls

import QGroundControl
import QGroundControl.Controllers
import QGroundControl.FlightDisplay

Item {
    id: root

    property var vehicle: QGroundControl.multiVehicleManager.activeVehicle
    property var waypointNames: ({})
    property var fishModel
    property var fishingSpotsModel
    property var bathymetryCells: []
    property var baitingController
    property real savedDepthM: NaN
    property real savedWaterTempC: NaN

    signal navigateRequested(var coordinate)
    signal savePointRequested(var coordinate)
    signal areaRectangleRequested(var cornerA, var cornerB)
    signal areaPolygonRequested(var polygon)
    signal baitingWaypointSelected(var waypoint)

    property string areaDrawMode: "none"
    property var areaDraftPoints: []

    function beginAreaRectangle() { areaDraftPoints=[]; areaDrawMode="rectangle" }
    function beginAreaPolygon() { areaDraftPoints=[]; areaDrawMode="polygon" }
    function cancelAreaDrawing() { areaDraftPoints=[]; areaDrawMode="none" }
    function finishAreaDrawing() {
        if(areaDrawMode==="rectangle" && areaDraftPoints.length===2)
            areaRectangleRequested(areaDraftPoints[0],areaDraftPoints[1])
        else if(areaDrawMode==="polygon" && areaDraftPoints.length>=3)
            areaPolygonRequested(areaDraftPoints.slice(0))
        else return false
        areaDrawMode="none"
        return true
    }

    PlanMasterController {
        id: planController
        Component.onCompleted: {
            start()
            if (root.vehicle) {
                loadFromVehicle()
            }
        }
    }

    FlyViewMap {
        id: liveMap
        anchors.fill: parent
        planMasterController: planController
        rightPanelWidth: 0
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
    }

    NavoActualTrack { map: liveMap; vehicle: root.vehicle; taskActive: !!root.vehicle }
    NavoAreaScanOverlay { map: liveMap; areaScan: root.baitingController ? root.baitingController.areaScanController : null }
    NavoFishOverlay { map: liveMap; fishModel: root.fishModel }
    NavoBathymetryOverlay { map: liveMap; bathymetryCells: root.bathymetryCells; fishingSpotsModel: root.fishingSpotsModel }

    NavoWaypointMapOverlay {
        map: liveMap
        missionController: planController.missionController
        vehicle: root.vehicle
        waypointNames: root.waypointNames
        savedDepthM: root.savedDepthM
        savedWaterTempC: root.savedWaterTempC
        onNavigationCommandSent: function(wp, accepted) {
            if (accepted && root.baitingController) root.baitingController.targetWaypoint = wp
        }
        onEditRequested: function(wp) {
            if(root.baitingController){root.baitingController.targetWaypoint=wp;root.baitingWaypointSelected(wp)}
        }
    }

    MapItemView {
        model: root.areaDraftPoints
        delegate: MapQuickItem {
            required property var modelData
            coordinate: modelData
            anchorPoint.x: 6; anchorPoint.y: 6
            sourceItem: Rectangle { width: 12; height: 12; radius: 6; color: "#26c6da"; border.color: "white" }
        }
    }
    MouseArea {
        anchors.fill: parent
        enabled: root.areaDrawMode !== "none"
        onClicked: function(mouse) {
            var c=liveMap.toCoordinate(Qt.point(mouse.x,mouse.y),false)
            if(!c || !c.isValid)return
            var pts=root.areaDraftPoints.slice(0)
            if(root.areaDrawMode==="rectangle") {
                if(pts.length>=2)pts=[]
                pts.push(c)
                root.areaDraftPoints=pts
                if(pts.length===2)root.finishAreaDrawing()
            } else {
                pts.push(c);root.areaDraftPoints=pts
            }
        }
    }
    Row {
        anchors.left: parent.left; anchors.top: parent.top; anchors.margins: 10; spacing: 6
        visible: root.areaDrawMode!=="none"
        Button { text: root.areaDrawMode==="rectangle" ? "DREPTUNGHI: 2 COLȚURI" : "POLIGON: "+root.areaDraftPoints.length+" PUNCTE"; enabled:false }
        Button { visible: root.areaDrawMode==="polygon"; text:"TERMINĂ"; enabled:root.areaDraftPoints.length>=3; onClicked:root.finishAreaDrawing() }
        Button { text:"ANULEAZĂ"; onClicked:root.cancelAreaDrawing() }
    }

    Connections {
        target: QGroundControl.multiVehicleManager
        function onActiveVehicleChanged(activeVehicle) {
            if (activeVehicle) {
                planController.loadFromVehicle()
                if (activeVehicle.coordinate && activeVehicle.coordinate.isValid) {
                    liveMap.center = activeVehicle.coordinate
                }
            }
        }
    }
}
