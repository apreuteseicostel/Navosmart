import QtQuick
import QtQuick.Controls
import QtLocation
import QtPositioning

import QGroundControl
import QGroundControl.Controls

Item {
    id: root
    required property var map
    required property var missionController
    required property var vehicle
    property var selectedWaypoint: null
    property point selectedScreenPoint: Qt.point(0, 0)
    property var waypointNames: ({})
    property real savedDepthM: NaN
    property real savedWaterTempC: NaN
    property string waypointNote: ""

    signal editRequested(var waypoint)
    signal deleteRequested(var waypoint)
    signal navigationCommandSent(var waypoint, bool accepted)

    anchors.fill: parent

    function friendlyName(wp) {
        if (!wp) return "Waypoint"
        var key = wp.sequenceNumber.toString()
        return waypointNames[key] && waypointNames[key].length ? waypointNames[key] : "WP" + wp.sequenceNumber
    }

    function selectWaypoint(wp) {
        selectedWaypoint = wp
        selectedScreenPoint = map.fromCoordinate(wp.coordinate, false)
    }

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
                width: Math.max(46, markerLabel.implicitWidth + 20)
                height: 36
                radius: 18
                color: root.selectedWaypoint === object ? "#21b7ff" : "#0b1c2eee"
                border.color: "#21b7ff"
                border.width: 2
                Label {
                    id: markerLabel
                    anchors.centerIn: parent
                    text: root.friendlyName(object)
                    color: "white"
                    font.bold: true
                    font.pixelSize: 11
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.selectWaypoint(object)
                }
            }
        }
    }

    NavoWaypointDetails {
        id: detailsCard
        visible: root.selectedWaypoint !== null
        waypoint: root.selectedWaypoint
        vehicle: root.vehicle
        friendlyName: root.friendlyName(root.selectedWaypoint)
        savedDepthM: root.savedDepthM
        savedWaterTempC: root.savedWaterTempC
        note: root.waypointNote
        z: QGroundControl.zOrderTopMost + 10
        x: Math.max(8, Math.min(root.width - width - 8, root.selectedScreenPoint.x + 20))
        y: Math.max(8, Math.min(root.height - height - 8, root.selectedScreenPoint.y - height / 2))
        onNavigateRequested: function(wp) {
            if (wp && root.vehicle && wp.coordinate && wp.coordinate.isValid) {
                navigateConfirm.open()
            }
        }
        onEditRequested: function(wp) { root.editRequested(wp) }
        onDeleteRequested: function(wp) { root.deleteRequested(wp) }
    }

    Dialog {
        id: navigateConfirm
        modal: true
        anchors.centerIn: parent
        title: "Confirmă navigarea autonomă"
        standardButtons: Dialog.Yes | Dialog.No
        closePolicy: Popup.NoAutoClose

        Column {
            spacing: 8
            width: 360
            Label {
                width: parent.width
                wrapMode: Text.WordWrap
                text: root.selectedWaypoint
                      ? "Trimiți barca la «" + root.friendlyName(root.selectedWaypoint) + "»?\n\nDistanță: " +
                        (root.vehicle && root.vehicle.coordinate && root.vehicle.coordinate.isValid
                         ? root.vehicle.coordinate.distanceTo(root.selectedWaypoint.coordinate).toFixed(0) + " m"
                         : "--") +
                        "\nVerifică apa și traseul înainte de confirmare."
                      : "Nu este selectat niciun waypoint."
            }
        }

        onAccepted: {
            if (!root.selectedWaypoint || !root.vehicle || !root.selectedWaypoint.coordinate.isValid) return
            // QGroundControl Vehicle API performs the firmware-specific Guided/GoTo command.
            // No command is sent before this explicit confirmation.
            var accepted = root.vehicle.guidedModeGotoLocation(root.selectedWaypoint.coordinate)
            root.navigationCommandSent(root.selectedWaypoint, accepted)
            if (accepted) root.selectedWaypoint = null
        }
    }

    MouseArea {
        // Small explicit close target for the selected card; does not intercept map gestures.
        visible: root.selectedWaypoint !== null
        z: QGroundControl.zOrderTopMost + 11
        width: 30; height: 30
        x: detailsCard.x + detailsCard.width - width - 4
        y: detailsCard.y + 4
        onClicked: root.selectedWaypoint = null
        Rectangle { anchors.fill: parent; radius: 15; color: "#14283a"; border.color: "#41617b" }
        Label { anchors.centerIn: parent; text: "×"; color: "white"; font.pixelSize: 18 }
    }
}
