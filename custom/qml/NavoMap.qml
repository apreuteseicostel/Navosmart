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
    property bool headingUp: false
    property bool rulerMode: false
    property bool mapLayerMenuOpen: false
    property bool showStatusHint: true
    property var rulerPoints: []
    readonly property real boatHeadingDeg: vehicle && vehicle.heading && isFinite(Number(vehicle.heading.rawValue)) ? Number(vehicle.heading.rawValue) : NaN

    signal navigateRequested(var coordinate)
    signal savePointRequested(var coordinate)
    signal saveNamedPointRequested(var coordinate, string name, string markerColor)
    property var pendingFishingCoordinate: null
    property string pendingFishingColor: "#31d67b"
    signal areaRectangleRequested(var cornerA, var cornerB)
    signal areaPolygonRequested(var polygon)
    signal baitingWaypointSelected(var waypoint)
    signal baitPointPicked(var coordinate)
    signal maximizeRequested()
    signal fishingSpotRenameRequested(var spot)

    property string areaDrawMode: "none"
    property bool baitPointPickMode: false
    property var areaDraftPoints: []
    property var lastAreaOutline: []

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
    function undoAreaPoint() { if(areaDraftPoints.length===0)return; var pts=areaDraftPoints.slice(0); pts.pop(); areaDraftPoints=pts }
    function clearAreaDrawing() { areaDraftPoints=[]; lastAreaOutline=[]; areaDrawMode="none" }
    function cancelAreaDrawing() { clearAreaDrawing() }
    function resetView() {
        if(vehicle && vehicle.coordinate && vehicle.coordinate.isValid) liveMap.center=vehicle.coordinate
        liveMap.zoomLevel=Math.max(liveMap.zoomLevel,lakeZoomLevel)
        headingUp=false
        rulerMode=false; rulerPoints=[]
    }
    function toggleRuler() { rulerMode=!rulerMode; rulerPoints=[]; mapLayerMenuOpen=false }
    function toggleMapLayer() { bathymetryHDEnabled=!bathymetryHDEnabled; mapLayerMenuOpen=false }
    function rulerDistanceText() {
        if(rulerPoints.length<2) return "Atinge două puncte"
        var d=rulerPoints[0].distanceTo(rulerPoints[1])
        return d>=1000 ? (d/1000).toFixed(2)+" km" : Math.round(d)+" m"
    }
    function finishAreaDrawing() {
        if(areaDrawMode==="rectangle" && areaDraftPoints.length===2)
            areaRectangleRequested(areaDraftPoints[0],areaDraftPoints[1])
        else if(areaDrawMode==="polygon" && areaDraftPoints.length>=3)
            areaPolygonRequested(areaDraftPoints.slice(0))
        else return false
        // Preserve the selected boundary as a preview after drawing ends.
        // Generated scan lanes are rendered by NavoAreaScanOverlay.
        var outline=areaDraftPoints.slice(0)
        if(areaDrawMode==="rectangle" && outline.length===2) {
            var a=outline[0], b=outline[1]
            lastAreaOutline=[a,QtPositioning.coordinate(a.latitude,b.longitude),b,QtPositioning.coordinate(b.latitude,a.longitude),a]
        } else if(areaDrawMode==="polygon" && outline.length>=3) {
            lastAreaOutline=outline
            lastAreaOutline.push(outline[0])
        }
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
        bearing: root.headingUp && isFinite(root.boatHeadingDeg) ? root.boatHeadingDeg : 0
        Behavior on bearing { NumberAnimation { duration: 250 } }
    }


    MapQuickItem {
        id: navoBoatMarker
        parent: liveMap
        visible: !!root.vehicle && !!root.vehicle.coordinate && root.vehicle.coordinate.isValid
        coordinate: visible ? root.vehicle.coordinate : QtPositioning.coordinate()
        anchorPoint.x: 24; anchorPoint.y: 42
        z: 35
        sourceItem: Item {
            width:48; height:84
            rotation: isFinite(root.boatHeadingDeg) ? root.boatHeadingDeg - liveMap.bearing : 0
            Behavior on rotation { RotationAnimation { duration:240; direction:RotationAnimation.Shortest } }
            Canvas {
                anchors.fill:parent
                onPaint:{var p=getContext("2d");p.reset();p.fillStyle="#d9ff19";p.strokeStyle="#07131d";p.lineWidth=2;p.beginPath();p.moveTo(width/2,1);p.quadraticCurveTo(width-2,15,width-3,52);p.lineTo(width-8,height-3);p.lineTo(8,height-3);p.lineTo(3,52);p.quadraticCurveTo(2,15,width/2,1);p.closePath();p.fill();p.stroke();p.fillStyle="#101820";p.fillRect(7,34,9,22);p.fillRect(width-16,34,9,22);p.fillStyle="#18232d";p.fillRect(11,15,width-22,16)}
            }
        }
        Component.onCompleted: liveMap.addMapItem(this)
        Component.onDestruction: liveMap.removeMapItem(this)
    }

    MapPolyline {
        id:rulerLine; parent:liveMap; visible:root.rulerPoints.length>1; path:root.rulerPoints; line.width:3; line.color:"#ffc857"
        Component.onCompleted:liveMap.addMapItem(this); Component.onDestruction:liveMap.removeMapItem(this)
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
        TextField { palette.text:"#0b1118"; palette.base:"#ffffff"; palette.placeholderText:"#5f6b76"; palette.highlight:"#21b7ff"; palette.highlightedText:"#ffffff"; id: waypointName; width: Math.min(300, root.width); placeholderText: "Lanseta verde" }
        onAccepted: if(sequence>0 && waypointName.text.trim().length) root.waypointNameChanged(sequence,waypointName.text.trim())
    }

    MapPolyline {
        id: areaCommittedOutline
        parent: liveMap
        line.width: 3
        line.color: "#21d4ff"
        path: root.lastAreaOutline
        visible: root.lastAreaOutline.length > 1
        Component.onCompleted: liveMap.addMapItem(this)
        Component.onDestruction: liveMap.removeMapItem(this)
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
        enabled: root.areaDrawMode === "none" && !root.baitPointPickMode && !root.rulerMode
        acceptedButtons: Qt.LeftButton
        onPressAndHold: function(mouse) {
            var c=liveMap.toCoordinate(Qt.point(mouse.x,mouse.y),false)
            if(!c || !c.isValid)return
            root.pendingFishingCoordinate=c
            fishingName.text=""
            root.pendingFishingColor="#31d67b"
            fishingSaveDialog.open()
        }
    }
    MouseArea {
        anchors.fill:parent; z:20; enabled:root.rulerMode && root.areaDrawMode==="none" && !root.baitPointPickMode
        onClicked:function(mouse){var c=liveMap.toCoordinate(Qt.point(mouse.x,mouse.y),false);if(!c||!c.isValid)return;var p=root.rulerPoints.slice(0);if(p.length>=2)p=[];p.push(c);root.rulerPoints=p}
    }
    MouseArea {
        anchors.fill: parent
        z: 40
        enabled: root.baitPointPickMode && root.areaDrawMode === "none"
        acceptedButtons: Qt.LeftButton
        onClicked: function(mouse) {
            var c=liveMap.toCoordinate(Qt.point(mouse.x,mouse.y),false)
            if(!c || !c.isValid)return
            root.baitPointPickMode=false
            root.baitPointPicked(c)
        }
    }
    Rectangle {
        visible: root.baitPointPickMode
        z: 45
        anchors.left: parent.left; anchors.top: parent.top; anchors.margins: 10
        width: pickLabel.implicitWidth+22; height: 36; radius: 7
        color: "#071827dd"; border.color: "#26c6da"
        Label { id:pickLabel; anchors.centerIn:parent; text:"ATINGE HARTA PENTRU PUNCTUL DE NĂDIRE"; color:"white"; font.bold:true; font.pixelSize:11 }
    }
    Dialog {
        id: fishingSaveDialog; parent: Overlay.overlay; anchors.centerIn: parent; modal: true
        title: "Salvează punct de pescuit"; standardButtons: Dialog.Save | Dialog.Cancel
        Column {
            spacing: 8
            Label { text: "Nume punct (opțional)" }
            TextField { palette.text:"#0b1118"; palette.base:"#ffffff"; palette.placeholderText:"#5f6b76"; palette.highlight:"#21b7ff"; palette.highlightedText:"#ffffff"; id: fishingName; width: Math.min(300, root.width-40); placeholderText: "ex. Lanseta verde" }
            Label { text: "Culoare marker"; font.pixelSize: 11 }
            Row {
                spacing: 8
                Repeater {
                    model: ["#31d67b","#ef4444","#3b82f6","#facc15","#a855f7","#f97316"]
                    delegate: Rectangle {
                        required property var modelData
                        width:30; height:30; radius:15; color:modelData
                        border.color: root.pendingFishingColor===modelData ? "white" : "#607080"
                        border.width: root.pendingFishingColor===modelData ? 3 : 1
                        MouseArea { anchors.fill:parent; onClicked:root.pendingFishingColor=modelData }
                    }
                }
            }
            Label { text: root.pendingFishingCoordinate && root.pendingFishingCoordinate.isValid ? Number(root.pendingFishingCoordinate.latitude).toFixed(5)+", "+Number(root.pendingFishingCoordinate.longitude).toFixed(5) : ""; font.pixelSize: 11 }
        }
        onAccepted: if(root.pendingFishingCoordinate && root.pendingFishingCoordinate.isValid) root.saveNamedPointRequested(root.pendingFishingCoordinate,fishingName.text.trim(),root.pendingFishingColor)
    }

    Row {
        anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.margins: 10; spacing: 6
        visible: root.areaDrawMode!=="none"
        Button { width:72; height:32; padding:2; text:(root.areaDrawMode==="rectangle" ? "DREPT. " : "POLIG. ")+root.areaDraftPoints.length+(root.areaDrawMode==="rectangle"?"/2":""); enabled:false }
        Button { visible:root.areaDrawMode==="polygon"; width:72; height:32; padding:2; text:"GATA"; enabled:root.areaDraftPoints.length>=3; onClicked:root.finishAreaDrawing() }
        Button { width:42; height:32; padding:2; text:"↶"; enabled:root.areaDraftPoints.length>0; ToolTip.visible:hovered; ToolTip.text:"Șterge ultimul punct / segment"; onClicked:root.undoAreaPoint() }
        Button { width:42; height:32; padding:2; text:"DEL"; ToolTip.visible:hovered; ToolTip.text:"Șterge desenul Area Scan"; onClicked:root.clearAreaDrawing() }
    }
    Column {
        id: mapControls
        anchors.left:parent.left; anchors.top:parent.top; anchors.margins:10
        spacing:5; z:200
        property int controlSize:56
        component MapTool: Button {
            width:56;height:56;padding:0
            font.pixelSize:26;font.bold:true
            background:Rectangle { radius:8;color:"#0d1722";border.color:"#27394b";border.width:1 }
            contentItem:Label { text:parent.text;color:"#f4f7fb";font.pixelSize:parent.font.pixelSize;font.bold:true;horizontalAlignment:Text.AlignHCenter;verticalAlignment:Text.AlignVCenter }
        }
        MapTool { text:"BOAT"; font.pixelSize:9; ToolTip.visible:hovered;ToolTip.text:"Centrează pe poziția actuală a bărcii";enabled:!!root.vehicle&&!!root.vehicle.coordinate&&root.vehicle.coordinate.isValid;onClicked:liveMap.center=root.vehicle.coordinate }
        MapTool { text:"+";ToolTip.visible:hovered;ToolTip.text:"Mărește harta";onClicked:liveMap.zoomLevel=liveMap.zoomLevel+1 }
        MapTool { text:"-";ToolTip.visible:hovered;ToolTip.text:"Micșorează harta";onClicked:liveMap.zoomLevel=liveMap.zoomLevel-1 }
        MapTool { text:"CTR";font.pixelSize:10;ToolTip.visible:hovered;ToolTip.text:"Reîncadrează harta și revine la orientarea Nord sus";onClicked:root.resetView() }
    }
    Column {
        anchors.right:parent.right;anchors.top:parent.top;anchors.margins:10;spacing:5;z:200
        property int controlSize:56
        component RightTool: Button {
            width:56;height:56;padding:0;font.pixelSize:22;font.bold:true
            background:Rectangle { radius:8;color:"#0d1722";border.color:"#27394b" }
            contentItem:Label { text:parent.text;color:"#f4f7fb";font.pixelSize:parent.font.pixelSize;font.bold:true;horizontalAlignment:Text.AlignHCenter;verticalAlignment:Text.AlignVCenter }
        }
        RightTool { text:"MAP";font.pixelSize:11;checkable:true;checked:root.bathymetryHDEnabled;ToolTip.visible:hovered;ToolTip.text:root.bathymetryHDEnabled?"Ascunde batimetria HD":"Afișează batimetria HD";onClicked:root.toggleMapLayer() }
        RightTool { text:"HD";font.pixelSize:14;checkable:true;checked:root.headingUp;ToolTip.visible:hovered;ToolTip.text:root.headingUp?"Heading Up activ • apasă pentru Nord sus":"Heading Up • rotește după barcă";onClicked:root.headingUp=!root.headingUp }
        RightTool { text:"RUL";font.pixelSize:11;checkable:true;checked:root.rulerMode;ToolTip.visible:hovered;ToolTip.text:root.rulerMode?root.rulerDistanceText():"Măsoară distanța între două puncte";onClicked:root.toggleRuler() }
        RightTool { text:root.maximized?"MIN":"MAX";font.pixelSize:10;ToolTip.visible:hovered;ToolTip.text:root.maximized?"Revino la dashboard":"Hartă pe tot ecranul";onClicked:root.maximizeRequested() }
    }
    Rectangle {
        visible: root.showStatusHint
        anchors.left: mapControls.right; anchors.top: parent.top
        anchors.leftMargin: 8; anchors.topMargin: 10
        width: Math.max(70, Math.min(parent.width - mapControls.width - 180, mapHint.implicitWidth + 18))
        height: 30; radius: 7; color: "#d9101c29"
        Label {
            id: mapHint; anchors.centerIn: parent
            text: root.areaDrawMode === "rectangle" ? "Atinge două colțuri pe hartă" :
                  root.areaDrawMode === "polygon" ? "Atinge punctele, apoi TERMINĂ" :
                  (root.rulerMode ? "RUL • "+root.rulerDistanceText() :
                   (root.vehicle && root.vehicle.coordinate && root.vehicle.coordinate.isValid ?
                    "Traseu: " + actualTrack.trackCoordinates.length + " • " +
                    (root.areaScanController ? root.areaScanController.laneCount() : 0) + " culoare" :
                    "GPS: AȘTEPTARE"))
            color: "white"; font.pixelSize: 11; elide: Text.ElideRight
            width: parent.width - 14
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
