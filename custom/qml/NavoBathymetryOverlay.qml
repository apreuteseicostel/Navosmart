import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtLocation
import QtPositioning

Item {
    id: root
    required property var map
    property var bathymetryCells: []
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
        model: root.bathymetryCells
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
            sourceItem: Rectangle {
                id: pin
                width: Math.max(72,pinText.implicitWidth+18); height:34; radius:17
                color:"#071827ee"; border.color:"#31d67b"; border.width:2
                Label { id:pinText; anchors.centerIn:parent; text:"🎣 "+modelData.name; color:"white"; font.bold:true; font.pixelSize:10 }
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
