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
    signal status(string text)
    signal navigateSpotRequested(var spot)
    signal baitSpotRequested(var spot)
    signal renameSpotRequested(var spot)

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
                MouseArea { anchors.fill:parent; onClicked:{root.selectedSpot=modelData;root.selectedCell=null;spotDetails.open()} }
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
        id: spotDetails
        modal:true; anchors.centerIn:parent
        title: root.selectedSpot ? root.selectedSpot.name : "Punct pescuit"
        standardButtons: Dialog.Close
        ColumnLayout {
            width:340
            Label { text: root.selectedSpot && root.selectedSpot.depth!==null ? "Adâncime salvată: "+Number(root.selectedSpot.depth).toFixed(2)+" m" : "Adâncime: --"; font.bold:true }
            Label { Layout.fillWidth:true; wrapMode:Text.WordWrap; text:root.selectedSpot ? root.selectedSpot.note : "" }
            RowLayout {
                Layout.fillWidth:true
                Button { text:"NAVIGHEAZĂ"; onClicked:{root.navigateSpotRequested(root.selectedSpot);spotDetails.close()} }
                Button { text:"NĂDIRE"; onClicked:{root.baitSpotRequested(root.selectedSpot);spotDetails.close()} }
                Button { text:"NUME"; onClicked:{root.renameSpotRequested(root.selectedSpot);spotDetails.close()} }
            }
            Button { text:"ȘTERGE PUNCTUL"; enabled:root.selectedSpot!==null; onClicked:{if(root.fishingSpotsModel&&root.selectedSpot){root.fishingSpotsModel.removeSpot(root.selectedSpot.id);root.status("Punct șters");root.selectedSpot=null;spotDetails.close()}} }
        }
    }
}
