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
    property var planController
    signal waypointNameChanged(int sequence, string name)
    property var waypointNames: ({})
    property var fishModel
    property var fishingSpotsModel
    property var bathymetryCells: []
    property bool bathymetryHDEnabled: false
    property var baitingController
    property var areaScanController
    property real savedDepthM: NaN
    property real savedWaterTempC: NaN
    property bool maximized: false
    property int lakeZoomLevel: 17
    property bool initialCenterApplied: false

    signal navigateRequested(var coordinate)
    signal savePointRequested(var coordinate)
    signal saveNamedPointRequested(var coordinate, string name)
    property var pendingFishingCoordinate: null
    signal areaRectangleRequested(var cornerA, var cornerB)
    signal areaPolygonRequested(var polygon)
    signal baitingWaypointSelected(var waypoint)
    signal maximizeRequested()
    signal fishingSpotRenameRequested(var spot)

    property string areaDrawMode: "none"
    property var areaDraftPoints: []

    function beginAreaRectangle() {
        areaDraftPoints=[]
        areaDrawMode="rectangle"
        if(vehicle && vehicle.coordinate && vehicle.coordinate.isValid) liveMap.center=vehicle.coordinate
    }
    function beginAreaPolygon() {
        areaDraftPoints=[]
        areaDrawMode="polygon"
        if(vehicle && vehicle.coordinate && vehicle.coordinate.isValid) liveMap.center=vehicle.coordinate
    }
    function cancelAreaDrawing() { areaDraftPoints=[]; areaDrawMode="none" }
    function finishAreaDrawing() {
        if(areaDrawMode==="rectangle" && areaDraftPoints.length===2)
            areaRectangleRequested(areaDraftPoints[0],areaDraftPoints[1])
        else if(areaDrawMode==="polygon" && areaDraftPoints.length>=3)
            areaPolygonRequested(areaDraftPoints.slice(0))
        else return false
        areaDrawMode="none"
        areaDraftPoints=[]
        return true
    }

    FlyViewMap {
        id: liveMap
        anchors.fill: parent
        planMasterController: root.planController
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

    NavoActualTrack { id: actualTrack; map: liveMap; vehicle: root.vehicle; taskActive: !!root.vehicle }
    NavoAreaScanOverlay { map: liveMap; areaScan: root.areaScanController }
    NavoFishOverlay { map: liveMap; fishModel: root.fishModel }
    NavoBathymetryHDOverlay {
        map: liveMap
        cells: root.bathymetryCells
        enabled: root.bathymetryHDEnabled
        resolution: root.maximized ? 34 : 28
    }
    NavoBathymetryOverlay {
        map: liveMap
        bathymetryCells: root.bathymetryCells
        showBathymetryCells: !root.bathymetryHDEnabled
        fishingSpotsModel: root.fishingSpotsModel
        onNavigateSpotRequested: function(spot) { root.navigateRequested(QtPositioning.coordinate(Number(spot.lat),Number(spot.lon))) }
        onBaitSpotRequested: function(spot) {
            var c=QtPositioning.coordinate(Number(spot.lat),Number(spot.lon))
            var wp={coordinate:c,name:spot.name,sequenceNumber:0}
            if(root.baitingController) root.baitingController.targetWaypoint=wp
            root.baitingWaypointSelected(wp)
        }
        onRenameSpotRequested: function(spot) { root.fishingSpotRenameRequested(spot) }
    }

    NavoWaypointMapOverlay {
        map: liveMap
        missionController: root.planController ? root.planController.missionController : null
        vehicle: root.vehicle
        waypointNames: root.waypointNames
        savedDepthM: root.savedDepthM
        savedWaterTempC: root.savedWaterTempC
        onNavigationCommandSent: function(wp, accepted) {
            if (accepted && root.baitingController) root.baitingController.targetWaypoint = wp
        }
        onWaypointSelected: function(wp) {
            if(root.baitingController) root.baitingController.targetWaypoint=wp
            root.baitingWaypointSelected(wp)
        }
        onEditRequested: function(wp) {
            renameDialog.sequence=wp.sequenceNumber
            waypointName.text=root.waypointNames[String(wp.sequenceNumber)] || "WP"+wp.sequenceNumber
            renameDialog.open()
        }
    }
    Dialog {
        id: renameDialog; parent: Overlay.overlay; anchors.centerIn: parent; modal: true
        property int sequence: -1
        title: "Nume waypoint"; standardButtons: Dialog.Save | Dialog.Cancel
        TextField { id: waypointName; width: Math.min(300, root.width); placeholderText: "Lanseta verde" }
        onAccepted: if(sequence>0 && waypointName.text.trim().length) root.waypointNameChanged(sequence,waypointName.text.trim())
    }

    MapPolyline {
        id: areaDraftOutline
        parent: liveMap
        line.width: 3
        line.color: "#21b7ff"
        path: {
            var pts = root.areaDraftPoints ? root.areaDraftPoints.slice(0) : []
            if (root.areaDrawMode === "rectangle" && pts.length === 2) {
                var a=pts[0], b=pts[1]
                return [a, QtPositioning.coordinate(a.latitude,b.longitude), b, QtPositioning.coordinate(b.latitude,a.longitude), a]
            }
            if (root.areaDrawMode === "polygon" && pts.length > 1) {
                if (pts.length >= 3) pts.push(pts[0])
                return pts
            }
            return pts
        }
        Component.onCompleted: liveMap.addMapItem(this)
        Component.onDestruction: liveMap.removeMapItem(this)
    }

    Repeater {
        model: root.areaDraftPoints
        delegate: MapQuickItem {
            required property var modelData
            Component.onCompleted: { parent = liveMap; liveMap.addMapItem(this) }
            Component.onDestruction: liveMap.removeMapItem(this)
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
    MouseArea {
        anchors.fill: parent
        enabled: root.areaDrawMode === "none"
        acceptedButtons: Qt.LeftButton
        onPressAndHold: function(mouse) {
            var c=liveMap.toCoordinate(Qt.point(mouse.x,mouse.y),false)
            if(!c || !c.isValid)return
            root.pendingFishingCoordinate=c
            fishingName.text=""
            fishingSaveDialog.open()
        }
    }
    Dialog {
        id: fishingSaveDialog; parent: Overlay.overlay; anchors.centerIn: parent; modal: true
        title: "Salvează punct de pescuit"; standardButtons: Dialog.Save | Dialog.Cancel
        Column {
            spacing: 8
            Label { text: "Nume punct (opțional)" }
            TextField { id: fishingName; width: Math.min(300, root.width-40); placeholderText: "ex. Lanseta verde" }
            Label { text: root.pendingFishingCoordinate && root.pendingFishingCoordinate.isValid ? Number(root.pendingFishingCoordinate.latitude).toFixed(5)+", "+Number(root.pendingFishingCoordinate.longitude).toFixed(5) : ""; font.pixelSize: 11 }
        }
        onAccepted: if(root.pendingFishingCoordinate && root.pendingFishingCoordinate.isValid) root.saveNamedPointRequested(root.pendingFishingCoordinate,fishingName.text.trim())
    }

    Row {
        anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.margins: 10; spacing: 6
        visible: root.areaDrawMode!=="none"
        Button { width: 72; height: 32; padding: 2; text: root.areaDrawMode==="rectangle" ? "▭ "+root.areaDraftPoints.length+"/2" : "⬡ "+root.areaDraftPoints.length; enabled:false }
        Button { visible: root.areaDrawMode==="polygon"; width:72; height:32; padding:2; text:"✓ GATA"; enabled:root.areaDraftPoints.length>=3; onClicked:root.finishAreaDrawing() }
        Button { width:42; height:32; padding:2; text:"×"; ToolTip.visible:hovered; ToolTip.text:"Anulează"; onClicked:root.cancelAreaDrawing() }
    }
    Column {
        id: mapControls
        // Keep controls inside the map on phones/tablets and above any bottom overlays.
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: Math.max(8, Math.round(root.width * 0.008))
        anchors.topMargin: 8
        spacing: 4
        z: 50
        property int controlSize: Math.max(38, Math.min(46, Math.round(root.width * 0.042)))
        property int iconSize: Math.max(18, Math.round(controlSize * 0.48))
        Button {
            text: "HD"; width: parent.controlSize; height: parent.controlSize; padding: 2; font.pixelSize: Math.max(14,mapControls.iconSize-2)
            checkable: true; checked: root.bathymetryHDEnabled
            ToolTip.visible: hovered; ToolTip.text: "Strat Batimetrie HD"
            onToggled: root.bathymetryHDEnabled = checked
        }
        Button { text: "+"; width: parent.controlSize; height: parent.controlSize; padding: 2; font.pixelSize: mapControls.iconSize; onClicked: liveMap.zoomLevel = liveMap.zoomLevel + 1 }
        Button { text: "−"; width: parent.controlSize; height: parent.controlSize; padding: 2; font.pixelSize: mapControls.iconSize; onClicked: liveMap.zoomLevel = liveMap.zoomLevel - 1 }
        Button {
            text: "⌖"; width: parent.controlSize; height: parent.controlSize; padding: 2; font.pixelSize: mapControls.iconSize
            ToolTip.visible: hovered; ToolTip.text: "Centrează pe barcă"
            enabled: !!root.vehicle && !!root.vehicle.coordinate && root.vehicle.coordinate.isValid
            onClicked: liveMap.center = root.vehicle.coordinate
        }
        Button {
            text: "⌂"; width: parent.controlSize; height: parent.controlSize; padding: 2; font.pixelSize: mapControls.iconSize
            ToolTip.visible: hovered; ToolTip.text: "Acasă"
            enabled: !!root.vehicle && !!root.vehicle.homePosition && root.vehicle.homePosition.isValid
            onClicked: liveMap.center = root.vehicle.homePosition
        }
        Button {
            text: root.maximized ? "↙" : "⛶"; width: parent.controlSize; height: parent.controlSize; padding: 2; font.pixelSize: mapControls.iconSize
            ToolTip.visible: hovered; ToolTip.text: root.maximized ? "Micșorează harta" : "Maximizează harta"
            onClicked: root.maximizeRequested()
        }
        Button {
            text: "＋"; width: parent.controlSize; height: parent.controlSize; padding: 2; font.pixelSize: mapControls.iconSize
            ToolTip.visible: hovered; ToolTip.text: "Salvează punct"
            enabled: !!root.vehicle && !!root.vehicle.coordinate && root.vehicle.coordinate.isValid
            onClicked: root.savePointRequested(root.vehicle.coordinate)
        }
    }
    Rectangle {
        anchors.left: parent.left; anchors.top: parent.top; anchors.margins: 10
        width: Math.max(110, Math.min(parent.width - 180, mapHint.implicitWidth + 20))
        height: mapHint.implicitHeight + 14; radius: 7; color: "#d9101c29"
        Label {
            id: mapHint; anchors.centerIn: parent
            text: root.areaDrawMode === "rectangle" ? "Atinge două colțuri pe hartă" :
                  root.areaDrawMode === "polygon" ? "Atinge punctele, apoi TERMINĂ" :
                  (root.vehicle && root.vehicle.coordinate && root.vehicle.coordinate.isValid ?
                   "Traseu: " + actualTrack.trackCoordinates.length + " poziții • " +
                   (root.areaScanController ? root.areaScanController.laneCount() : 0) + " culoare scanate" :
                   "Harta este disponibilă • aștept poziția bărcii")
            color: "white"; font.pixelSize: 12; elide: Text.ElideRight
            width: parent.width - 16
        }
    }

    function centerOnBoatOnce() {
        if(initialCenterApplied)return
        if(vehicle && vehicle.coordinate && vehicle.coordinate.isValid) {
            liveMap.center=vehicle.coordinate
            liveMap.zoomLevel=Math.max(liveMap.zoomLevel,lakeZoomLevel)
            initialCenterApplied=true
        }
    }
    Component.onCompleted: centerOnBoatOnce()
    onVehicleChanged: { initialCenterApplied=false; centerOnBoatOnce() }

    Connections {
        target: root.vehicle
        function onCoordinateChanged() { root.centerOnBoatOnce() }
    }
    Connections {
        target: QGroundControl.multiVehicleManager
        function onActiveVehicleChanged(activeVehicle) {
            if (activeVehicle) {
                if (activeVehicle.coordinate && activeVehicle.coordinate.isValid) {
                    liveMap.center = activeVehicle.coordinate
                    liveMap.zoomLevel = Math.max(liveMap.zoomLevel, root.lakeZoomLevel)
                    root.initialCenterApplied = true
                }
            }
        }
    }
}
