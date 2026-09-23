import QtQuick
import QtPositioning

import QGroundControl
import QGroundControl.Controllers
import QGroundControl.FlightDisplay

Item {
    id: root

    property var vehicle: QGroundControl.multiVehicleManager.activeVehicle
    property var waypointNames: ({})

    signal navigateRequested(var coordinate)
    signal savePointRequested(var coordinate)

    PlanMasterController {
        id: planController
        Component.onCompleted: {
            start()
            if (root.vehicle) {
                loadFromVehicle()
            }
        }
    }

    FlyViewMap {
        id: liveMap
        anchors.fill: parent
        planMasterController: planController
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
    }

    Connections {
        target: QGroundControl.multiVehicleManager
        function onActiveVehicleChanged(activeVehicle) {
            if (activeVehicle) {
                planController.loadFromVehicle()
                if (activeVehicle.coordinate && activeVehicle.coordinate.isValid) {
                    liveMap.center = activeVehicle.coordinate
                }
            }
        }
    }
}
