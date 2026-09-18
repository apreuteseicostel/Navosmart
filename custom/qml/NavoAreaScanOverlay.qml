import QtQuick
import QtLocation
import QtPositioning

Item {
    id: root
    required property var map
    property var areaScan
    property int lineWidth: 4
    property color pendingColor: "#9db2c5"
    property color activeColor: "#ffcc33"
    property color completedColor: "#31d67b"
    anchors.fill: parent

    MapItemView {
        model: root.areaScan ? root.areaScan.laneCount() : 0
        delegate: MapPolyline {
            required property int index
            line.width: root.lineWidth
            line.color: root.areaScan && root.areaScan.completedLanes.indexOf(index)>=0
                        ? root.completedColor
                        : (root.areaScan && root.areaScan.activeLaneIndex===index ? root.activeColor : root.pendingColor)
            path: root.areaScan && root.areaScan.generatedPoints.length >= (index+1)*2
                  ? [root.areaScan.generatedPoints[index*2],root.areaScan.generatedPoints[index*2+1]] : []
        }
    }

    MapItemView {
        model: root.areaScan && root.areaScan.activeLaneIndex>=0 ? 1 : 0
        delegate: MapQuickItem {
            coordinate: root.areaScan.generatedPoints[root.areaScan.activeLaneIndex*2]
            anchorPoint.x: badge.width/2; anchorPoint.y: badge.height/2
            sourceItem: Rectangle {
                id: badge; width: 54; height: 28; radius: 14
                color:"#071827ee"; border.color:root.activeColor; border.width:2
                Text { anchors.centerIn:parent; color:"white"; font.bold:true; text:"SCAN "+(root.areaScan.activeLaneIndex+1) }
            }
        }
    }
}
