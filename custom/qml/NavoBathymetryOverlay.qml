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
                    onClicked:{root.selectedSpot=modelData;root.selectedCell=null}
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

    Dialog {
        id:spotDetails;objectName:"savedSpotDetails";parent:Overlay.overlay
        modal:true;anchors.centerIn:parent
        width:Math.min(420,parent.width-24);height:Math.min(540,parent.height-24)
        title:root.currentSpot ? root.currentSpot.name : "Punct pescuit"
        standardButtons:Dialog.Close
        contentItem:ScrollView {
            clip:true;contentWidth:availableWidth
            ColumnLayout {
                width:spotDetails.availableWidth;spacing:8
                Label { Layout.fillWidth:true;wrapMode:Text.WordWrap;text:root.currentSpot && typeof root.currentSpot.depth==="number" && isFinite(root.currentSpot.depth) ? "Adâncime salvată: "+root.currentSpot.depth.toFixed(2)+" m" : "Adâncime: --" }
                Label { Layout.fillWidth:true;wrapMode:Text.WordWrap;text:root.currentSpot && typeof root.currentSpot.temp==="number" && isFinite(root.currentSpot.temp) ? "Temperatură salvată: "+root.currentSpot.temp.toFixed(1)+" °C" : "Temperatură apă: --" }
                Label { Layout.fillWidth:true;wrapMode:Text.WordWrap;text:root.spotCoordinateValid ? "GPS: "+root.currentSpot.lat.toFixed(6)+", "+root.currentSpot.lon.toFixed(6) : "Coordonate indisponibile" }
                Label { Layout.fillWidth:true;wrapMode:Text.WordWrap;text:root.spotCoordinateValid && root.boatCoordinate && root.boatCoordinate.isValid ? "Distanță de la barcă: "+Math.round(root.boatCoordinate.distanceTo(QtPositioning.coordinate(root.currentSpot.lat,root.currentSpot.lon)))+" m" : "Distanță de la barcă: --" }
                Label { Layout.fillWidth:true;wrapMode:Text.WordWrap;text:root.currentSpot && root.currentSpot.createdAt ? "Salvat: "+new Date(root.currentSpot.createdAt).toLocaleString() : "" }
                Label { Layout.fillWidth:true;wrapMode:Text.WordWrap;text:root.currentSpot ? root.currentSpot.note||"" : "" }
                Label { Layout.fillWidth:true;wrapMode:Text.WordWrap;text:"Pregătești misiunea la coordonatele salvate. Pornirea se confirmă separat prin START.";color:"#91a3b5" }
                Button { objectName:"savedSpotNavigate";Layout.fillWidth:true;text:"NAVIGHEAZĂ LA PUNCT";enabled:root.actionsAllowed && root.spotCoordinateValid
                    onClicked:{var spot=root.currentSpot;spotDetails.close();root.spotActionRequested(spot,"navigate",0,0)} }
                ComboBox { id:spotHopper;objectName:"savedSpotHopper";Layout.fillWidth:true;model:["Cuva stângă","Cuva dreaptă","Ambele cuve"];enabled:root.actionsAllowed }
                Button { objectName:"savedSpotBait";Layout.fillWidth:true;text:"NĂDIRE LA PUNCT";enabled:root.actionsAllowed && root.spotCoordinateValid
                    onClicked:{var spot=root.currentSpot,h=spotHopper.currentIndex+1;spotDetails.close();root.spotActionRequested(spot,"bait",h,0)} }
                RowLayout {
                    Layout.fillWidth:true
                    Label { Layout.fillWidth:true;text:"Latura zonei (m)";wrapMode:Text.WordWrap }
                    SpinBox { id:spotScanSize;objectName:"savedSpotScanSize";from:10;to:100;stepSize:5;value:20;enabled:root.actionsAllowed;implicitWidth:120 }
                }
                Button { objectName:"savedSpotScan";Layout.fillWidth:true;text:"SCANARE ÎN JURUL PUNCTULUI";enabled:root.actionsAllowed && root.spotCoordinateValid
                    onClicked:{var spot=root.currentSpot,size=spotScanSize.value;spotDetails.close();root.spotActionRequested(spot,"scan",0,size)} }
                Label { Layout.fillWidth:true;wrapMode:Text.WordWrap;text:"Scanare: pătrat centrat pe punct; verifică limitele bălții înainte de pregătire/upload și START.";color:"#91a3b5" }
                Button { Layout.fillWidth:true;text:"EDITARE PUNCT";enabled:root.actionsAllowed && !!root.currentSpot;onClicked:{var spot=root.currentSpot;spotDetails.close();root.renameSpotRequested(spot)} }
                Button { Layout.fillWidth:true;text:"LISTA PUNCTELOR";onClicked:{var spot=root.currentSpot;spotDetails.close();root.openFishingSpotsRequested(spot)} }
            }
        }
    }
}
