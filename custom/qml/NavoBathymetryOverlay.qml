import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtLocation
import QtPositioning

Item {
    id: root
    required property var map
    property var bathymetryCells: []
    property bool showBathymetryCells: true
    property var fishingSpotsModel
    property var selectedCell: null
    property var selectedSpot: null
    property bool actionsAllowed: true
    property var boatCoordinate:null
    readonly property var currentSpot: {
        if(!selectedSpot || !fishingSpotsModel)return null
        var spots=fishingSpotsModel.fishingSpots
        for(var i=0;i<spots.length;i++)if(spots[i].id===selectedSpot.id)return spots[i]
        return null
    }
    readonly property bool spotCoordinateValid: !!currentSpot && typeof currentSpot.lat==="number" && typeof currentSpot.lon==="number" && isFinite(currentSpot.lat) && isFinite(currentSpot.lon) && Math.abs(currentSpot.lat)<=90 && Math.abs(currentSpot.lon)<=180
    onCurrentSpotChanged:if(!currentSpot)spotDetails.close()
    function openSpotAtPosition(x,y) {
        for(var i=0;i<spotMarkers.count;i++) {
            var marker=spotMarkers.itemAt(i)
            if(!marker || !marker.sourceItem || !marker.visible)continue
            var pin=marker.sourceItem,p=pin.mapFromItem(root.map,x,y)
            if(p.x>=0 && p.x<=pin.width && p.y>=0 && p.y<=pin.height) {
                openSpotDetails(marker.modelData);return true
            }
        }
        return false
    }
    function openSpotDetails(spot){selectedSpot=spot;selectedCell=null;spotDetails.open()}
    signal spotActionRequested(var spot, string action, int hopper, real scanSizeM)
    signal status(string text)
    signal navigateSpotRequested(var spot)
    signal baitSpotRequested(var spot)
    signal renameSpotRequested(var spot)
    signal openFishingSpotsRequested(var spot)

    anchors.fill: parent

    function selectCell(cell) {
        selectedCell=cell
        selectedSpot=null
        spotName.text=fishingSpotsModel ? fishingSpotsModel.suggestedName("Groapă cu pește") : "Groapă cu pește 1"
        cellPopup.open()
    }

    Repeater {
        model: root.showBathymetryCells ? root.bathymetryCells : []
        delegate: MapQuickItem {
            required property var modelData
            Component.onCompleted: { parent = root.map; root.map.addMapItem(this) }
            Component.onDestruction: root.map.removeMapItem(this)
            coordinate: QtPositioning.coordinate(modelData.lat,modelData.lon)
            anchorPoint.x: body.width/2
            anchorPoint.y: body.height/2
            sourceItem: Rectangle {
                id: body
                width: 34; height: 26; radius: 6
                color: "#0b1c2ecc"; border.color: "#21b7ff"
                Label { anchors.centerIn: parent; text: Number(modelData.depth).toFixed(1)+"m"; color:"white"; font.pixelSize:10; font.bold:true }
                MouseArea { anchors.fill: parent; onClicked: root.selectCell(modelData) }
            }
        }
    }

    Repeater {
        id:spotMarkers
        model: root.fishingSpotsModel ? root.fishingSpotsModel.fishingSpots : []
        delegate: MapQuickItem {
            required property var modelData
            Component.onCompleted: { parent = root.map; root.map.addMapItem(this) }
            Component.onDestruction: root.map.removeMapItem(this)
            coordinate: QtPositioning.coordinate(modelData.lat,modelData.lon)
            anchorPoint.x: pin.width/2; anchorPoint.y: pin.height
            sourceItem: Item {
                id: pin
                width: Math.max(88,pinText.implicitWidth+32); height:36
                Rectangle {
                    width:18; height:18; radius:9; anchors.left:parent.left; anchors.verticalCenter:parent.verticalCenter
                    color:modelData.color||"#31d67b"; border.color:"white"; border.width:2
                }
                Rectangle { anchors.left:parent.left; anchors.leftMargin:22; anchors.verticalCenter:parent.verticalCenter; width:pinText.implicitWidth+12; height:24; radius:6; color:"#071827d9"; border.color:"#20384a"
                    Label { id:pinText; anchors.centerIn:parent; text:modelData.name; color:"white"; font.bold:true; font.pixelSize:11 }
                }
                MouseArea {
                    objectName:"savedSpotPin";anchors.fill:parent;pressAndHoldInterval:600
                    onClicked:root.openSpotDetails(modelData)
                    onPressAndHold:root.openSpotDetails(modelData)
                    onDoubleClicked:root.openSpotDetails(modelData)
                }
            }
        }
    }

    Dialog {
        id: cellPopup
        modal:true; anchors.centerIn:parent
        title:"Punct batimetric"
        standardButtons: Dialog.Save | Dialog.Cancel
        ColumnLayout {
            width:360; spacing:8
            Label { text: root.selectedCell ? "Adâncime: "+Number(root.selectedCell.depth).toFixed(2)+" m" : "--"; font.bold:true }
            Label { text: root.selectedCell ? "Min/Max în celulă: "+Number(root.selectedCell.minDepth).toFixed(2)+" / "+Number(root.selectedCell.maxDepth).toFixed(2)+" m • "+root.selectedCell.samples+" măsurători" : ""; wrapMode:Text.WordWrap; Layout.fillWidth:true }
            TextField { id:spotName; Layout.fillWidth:true; placeholderText:"Ex: Groapă cu pește 1" }
            TextArea { id:spotNote; Layout.fillWidth:true; Layout.preferredHeight:70; placeholderText:"Notă: pește observat, prag, substrat..." }
        }
        onAccepted:{
            if(!root.selectedCell || !root.fishingSpotsModel)return
            var s=root.fishingSpotsModel.saveFromBathymetry(root.selectedCell,spotName.text,spotNote.text)
            if(s) root.status("Punct salvat: "+s.name+" • "+Number(s.depth).toFixed(1)+" m")
        }
    }

    component SpotActionButton: Button {
        implicitHeight:34; font.pixelSize:12
        contentItem:Text { text:parent.text;color:parent.enabled ? "#e8f4fa" : "#617887";font:parent.font;horizontalAlignment:Text.AlignHCenter;verticalAlignment:Text.AlignVCenter;elide:Text.ElideRight }
        background:Rectangle { radius:7;color:parent.down ? "#254b60" : parent.hovered ? "#203d50" : "#142c3c";border.color:parent.enabled ? "#316078" : "#243846" }
    }

    Dialog {
        id:spotDetails;objectName:"savedSpotDetails";parent:Overlay.overlay
        property bool expanded:false
        modal:false;dim:false
        width:Math.min(320,parent.width-24)
        height:Math.min(expanded ? 330 : 250,parent.height*0.48)
        x:Math.max(12,parent.width-width-12);y:Math.max(12,parent.height-height-12)
        padding:10;topPadding:6
        closePolicy:Popup.CloseOnEscape | Popup.CloseOnPressOutside
        onOpened:expanded=false
        background:Rectangle { color:"#f210202c";radius:12;border.width:1;border.color:"#387183" }
        header:RowLayout {
            spacing:6
            Label { Layout.leftMargin:12;Layout.fillWidth:true;text:root.currentSpot ? root.currentSpot.name : "Punct pescuit";color:"#e8f4fa";font.pixelSize:14;font.bold:true;elide:Text.ElideRight }
            ToolButton { objectName:"savedSpotClose";text:"×";implicitWidth:34;implicitHeight:34;onClicked:spotDetails.close();contentItem:Text{text:parent.text;font.pixelSize:22;color:"#67dfdc";horizontalAlignment:Text.AlignHCenter;verticalAlignment:Text.AlignVCenter} Accessible.name:"Închide detaliile punctului" }
        }
        footer:null
        contentItem:ScrollView {
            clip:true;contentWidth:availableWidth
            ColumnLayout {
                width:spotDetails.availableWidth;spacing:5
                Label { Layout.fillWidth:true;wrapMode:Text.WordWrap;color:"#67dfdc";font.pixelSize:11
                    text:(root.currentSpot && typeof root.currentSpot.depth==="number" && isFinite(root.currentSpot.depth) ? root.currentSpot.depth.toFixed(2)+" m" : "Adâncime --")+"  •  "+(root.currentSpot && typeof root.currentSpot.temp==="number" && isFinite(root.currentSpot.temp) ? root.currentSpot.temp.toFixed(1)+" °C" : "Apă --")+"  •  "+(root.spotCoordinateValid && root.boatCoordinate && root.boatCoordinate.isValid ? "Barcă "+Math.round(root.boatCoordinate.distanceTo(QtPositioning.coordinate(root.currentSpot.lat,root.currentSpot.lon)))+" m" : "Barcă --") }
                Label { Layout.fillWidth:true;visible:spotDetails.expanded;wrapMode:Text.WordWrap;font.pixelSize:11;color:"#a8becd";text:root.spotCoordinateValid ? "GPS: "+root.currentSpot.lat.toFixed(6)+", "+root.currentSpot.lon.toFixed(6) : "Coordonate indisponibile" }
                Label { Layout.fillWidth:true;visible:spotDetails.expanded;wrapMode:Text.WordWrap;font.pixelSize:11;color:"#a8becd";text:root.currentSpot && root.currentSpot.createdAt ? "Salvat: "+new Date(root.currentSpot.createdAt).toLocaleString() : "" }
                Label { Layout.fillWidth:true;visible:spotDetails.expanded;wrapMode:Text.WordWrap;font.pixelSize:11;color:"#a8becd";text:root.currentSpot ? root.currentSpot.note||"" : "" }
                SpotActionButton { objectName:"savedSpotNavigate";Layout.fillWidth:true;text:"↗  Navigare";Accessible.name:"Navighează la punct";enabled:root.actionsAllowed && root.spotCoordinateValid
                    onClicked:{var spot=root.currentSpot;spotDetails.close();root.spotActionRequested(spot,"navigate",0,0)} }
                RowLayout {
                    Layout.fillWidth:true;spacing:5
                    ComboBox { id:spotHopper;objectName:"savedSpotHopper";Layout.fillWidth:true;Layout.minimumWidth:0;implicitHeight:34;font.pixelSize:11;model:["Cuva stângă","Cuva dreaptă","Ambele cuve"];enabled:root.actionsAllowed
                        contentItem:Text { text:spotHopper.displayText;color:spotHopper.enabled ? "#e8f4fa" : "#617887";font:spotHopper.font;leftPadding:8;rightPadding:22;verticalAlignment:Text.AlignVCenter;elide:Text.ElideRight }
                        background:Rectangle { radius:7;color:"#142c3c";border.color:"#316078" }
                        indicator:Text { x:spotHopper.width-18;y:8;text:"▾";color:"#67dfdc" }
                        delegate:ItemDelegate { width:spotHopper.width;text:modelData;font.pixelSize:11;contentItem:Text {text:parent.text;color:"#e8f4fa";font:parent.font;verticalAlignment:Text.AlignVCenter} background:Rectangle{color:parent.highlighted ? "#254b60" : "#142c3c"} highlighted:spotHopper.highlightedIndex===index }
                        popup.background:Rectangle {color:"#142c3c";radius:7;border.color:"#316078"}
                    }
                    SpotActionButton { objectName:"savedSpotBait";Layout.preferredWidth:88;text:"Nădire";Accessible.name:"Nădire la punct";enabled:root.actionsAllowed && root.spotCoordinateValid
                        onClicked:{var spot=root.currentSpot,h=spotHopper.currentIndex+1;spotDetails.close();root.spotActionRequested(spot,"bait",h,0)} }
                }
                RowLayout {
                    Layout.fillWidth:true;spacing:5
                    SpinBox { id:spotScanSize;objectName:"savedSpotScanSize";from:10;to:100;stepSize:5;value:20;enabled:root.actionsAllowed;Layout.fillWidth:true;Layout.minimumWidth:0;implicitHeight:34;font.pixelSize:11;Accessible.name:"Latura zonei de scanare în metri"
                        contentItem:Text {text:spotScanSize.value+" m";font:spotScanSize.font;color:spotScanSize.enabled ? "#e8f4fa" : "#617887";horizontalAlignment:Text.AlignHCenter;verticalAlignment:Text.AlignVCenter}
                        background:Rectangle {radius:7;color:"#142c3c";border.color:"#316078"}
                        up.indicator:Rectangle {x:spotScanSize.width-width;implicitWidth:30;implicitHeight:34;radius:7;color:spotScanSize.up.pressed ? "#254b60" : "#142c3c";Text{anchors.centerIn:parent;text:"+";color:"#67dfdc";font.pixelSize:18}}
                        down.indicator:Rectangle {implicitWidth:30;implicitHeight:34;radius:7;color:spotScanSize.down.pressed ? "#254b60" : "#142c3c";Text{anchors.centerIn:parent;text:"−";color:"#67dfdc";font.pixelSize:18}}
                    }
                    SpotActionButton { objectName:"savedSpotScan";Layout.preferredWidth:88;text:"Scanare";Accessible.name:"Scanare în jurul punctului";enabled:root.actionsAllowed && root.spotCoordinateValid
                        onClicked:{var spot=root.currentSpot,size=spotScanSize.value;spotDetails.close();root.spotActionRequested(spot,"scan",0,size)} }
                }
                Label { Layout.fillWidth:true;wrapMode:Text.WordWrap;text:"Zonă: latura în metri. Pornire separată prin START.";font.pixelSize:10;color:"#91a3b5" }
                RowLayout {
                    Layout.fillWidth:true;spacing:5
                    SpotActionButton { objectName:"savedSpotMore";Layout.fillWidth:true;text:spotDetails.expanded ? "Mai puțin" : "Detalii";onClicked:spotDetails.expanded=!spotDetails.expanded }
                    SpotActionButton { Layout.fillWidth:true;text:"Editare";enabled:root.actionsAllowed && !!root.currentSpot;onClicked:{var spot=root.currentSpot;spotDetails.close();root.renameSpotRequested(spot)} }
                    SpotActionButton { Layout.fillWidth:true;text:"Listă";onClicked:{var spot=root.currentSpot;spotDetails.close();root.openFishingSpotsRequested(spot)} }
                }
            }
        }
    }
}
