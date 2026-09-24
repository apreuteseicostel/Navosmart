import QtQuick
import QtLocation
import QtPositioning

Item {
    id: root
    required property var map
    property var areaScan
    property int lineWidth: 4
    property color pendingColor: "#21d4ff"
    property color activeColor: "#ffd24a"
    property color completedColor: "#31d67b"
    anchors.fill: parent

    Repeater {
        model: root.areaScan ? root.areaScan.laneCount() : 0
        delegate: MapPolyline {
            required property int index
            Component.onCompleted: { parent = root.map; root.map.addMapItem(this) }
            Component.onDestruction: root.map.removeMapItem(this)
            line.width: root.areaScan && root.areaScan.activeLaneIndex===index ? root.lineWidth+2 : root.lineWidth
            line.color: root.areaScan && root.areaScan.completedLanes.indexOf(index)>=0
                        ? root.completedColor
                        : (root.areaScan && root.areaScan.activeLaneIndex===index ? root.activeColor : root.pendingColor)
            path: root.areaScan && root.areaScan.generatedPoints.length >= (index+1)*2
                  ? [root.areaScan.generatedPoints[index*2],root.areaScan.generatedPoints[index*2+1]] : []
        }
    }


    Repeater {
        model: root.areaScan ? root.areaScan.laneCount() : 0
        delegate: MapQuickItem {
            required property int index
            Component.onCompleted: { parent = root.map; root.map.addMapItem(this) }
            Component.onDestruction: root.map.removeMapItem(this)
            coordinate: root.areaScan.generatedPoints[index*2]
            anchorPoint.x: laneBadge.width/2
            anchorPoint.y: laneBadge.height/2
            sourceItem: Rectangle {
                id: laneBadge
                width: 24; height: 20; radius: 5
                color: "#071827ee"
                border.color: root.areaScan && root.areaScan.completedLanes.indexOf(index)>=0 ? root.completedColor : root.pendingColor
                Text { anchors.centerIn: parent; text: String(index+1); color: "white"; font.pixelSize: 10; font.bold: true }
            }
        }
    }

    Repeater {
        model: root.areaScan && root.areaScan.activeLaneIndex>=0 ? 1 : 0
        delegate: MapQuickItem {
            Component.onCompleted: { parent = root.map; root.map.addMapItem(this) }
            Component.onDestruction: root.map.removeMapItem(this)
            coordinate: root.areaScan.generatedPoints[root.areaScan.activeLaneIndex*2]
            anchorPoint.x: badge.width/2; anchorPoint.y: badge.height/2
            sourceItem: Rectangle {
                id: badge; width: 54; height: 28; radius: 14
                color:"#071827ee"; border.color:root.activeColor; border.width:2
                Text { anchors.centerIn:parent; color:"white"; font.bold:true; text:"ACTIV "+(root.areaScan.activeLaneIndex+1)+"/"+root.areaScan.laneCount() }
            }
        }
    }
}
