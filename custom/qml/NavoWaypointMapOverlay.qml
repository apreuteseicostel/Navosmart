import QtQuick
import QtLocation
import QtPositioning

import QGroundControl
import QGroundControl.Controls

Item {
    id: root
    required property var map
    required property var missionController
    property var selectedWaypoint: null
    signal waypointTapped(var waypoint, point screenPoint)

    anchors.fill: parent

    MapItemView {
        model: root.missionController ? root.missionController.visualItems : null

        delegate: MapQuickItem {
            id: marker
            required property var object
            coordinate: object.coordinate
            visible: object && object.coordinate && object.coordinate.isValid && object.sequenceNumber > 0
            z: QGroundControl.zOrderTopMost
            anchorPoint.x: markerBody.width / 2
            anchorPoint.y: markerBody.height / 2

            sourceItem: Rectangle {
                id: markerBody
                width: Math.max(42, markerLabel.implicitWidth + 18)
                height: 34
                radius: 17
                color: root.selectedWaypoint === object ? "#21b7ff" : "#0b1c2eee"
                border.color: "#21b7ff"
                border.width: 2

                Label {
                    id: markerLabel
                    anchors.centerIn: parent
                    text: "WP" + object.sequenceNumber
                    color: "white"
                    font.bold: true
                    font.pixelSize: 12
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        root.selectedWaypoint = object
                        var p = root.map.fromCoordinate(object.coordinate, false)
                        root.waypointTapped(object, p)
                    }
                }
            }
        }
    }
}
