import QtQuick
import QtQuick.Controls
import QtLocation
import QtPositioning

Item {
    id: root
    required property var map
    property var fishModel
    property var selectedHotspot: null
    anchors.fill: parent

    MapItemView {
        model: fishModel ? fishModel.hotspots : []
        delegate: MapQuickItem {
            required property var modelData
            coordinate: QtPositioning.coordinate(modelData.lat,modelData.lon)
            anchorPoint.x: marker.width/2; anchorPoint.y: marker.height/2
            sourceItem: Rectangle {
                id:marker;width:modelData.count>3?46:38;height:width;radius:width/2
                color:"#071827e8";border.color:"#21b7ff";border.width:2
                Label{anchors.centerIn:parent;text:"🐟"+(modelData.count>1?modelData.count:"");color:"white";font.bold:true}
                MouseArea{anchors.fill:parent;onClicked:{root.selectedHotspot=modelData;details.open()}}
            }
        }
    }
    Dialog {
        id:details;modal:true;anchors.centerIn:parent
        title:"Activitate sonar 🐟";standardButtons:Dialog.Close
        Column {
            width:330;spacing:7
            Label{text:selectedHotspot?selectedHotspot.count+" detecții sonar":"--";font.bold:true}
            Label{text:selectedHotspot?"Ținte la "+Number(selectedHotspot.minTargetDepth).toFixed(1)+"–"+Number(selectedHotspot.maxTargetDepth).toFixed(1)+" m":""}
            Label{width:parent.width;wrapMode:Text.WordWrap;text:"Markerul reprezintă zona în care barca a detectat țintele, nu poziția GPS exactă a peștilor."}
        }
    }
}
