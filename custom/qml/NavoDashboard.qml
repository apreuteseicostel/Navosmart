import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtPositioning

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlyView
import QGroundControl.FlightMap
import QGroundControl.PlanView

Item {
    id: root
    implicitWidth: 1280
    implicitHeight: 720

    property var vehicle: QGroundControl.multiVehicleManager.activeVehicle
    property var battery: vehicle && vehicle.batteries.count > 0 ? vehicle.batteries.get(0) : null
    property var waypointNames: ({})
    property real depthM: NaN
    property real waterTempC: NaN
    property bool sonarConnected: false
    property string lastNavigationStatus: ""

    readonly property bool vehicleConnected: vehicle !== null
    readonly property real batteryPercent: battery && !isNaN(battery.percentRemaining.rawValue) ? battery.percentRemaining.rawValue : NaN
    readonly property real batteryVoltage: battery && !isNaN(battery.voltage.rawValue) ? battery.voltage.rawValue : NaN
    readonly property real speedMps: vehicle && !isNaN(vehicle.groundSpeed.rawValue) ? vehicle.groundSpeed.rawValue : NaN
    readonly property real distanceHomeM: vehicle && !isNaN(vehicle.distanceToHome.rawValue) ? vehicle.distanceToHome.rawValue : NaN
    readonly property int satellites: vehicle && vehicle.gps ? vehicle.gps.count.rawValue : -1
    readonly property real headingDeg: vehicle && !isNaN(vehicle.heading.rawValue) ? vehicle.heading.rawValue : NaN
    readonly property string flightMode: vehicle ? vehicle.flightMode : "NECONECTAT"
    readonly property int gpsFix: vehicle && vehicle.gps ? vehicle.gps.lock.rawValue : 0
    readonly property bool gpsRtk: gpsFix >= 5
    readonly property real hdop: vehicle && vehicle.gps && !isNaN(vehicle.gps.hdop.rawValue) ? vehicle.gps.hdop.rawValue : NaN

    readonly property color bg: "#06111f"
    readonly property color panel: "#0b1c2e"
    readonly property color panel2: "#10273d"
    readonly property color line: "#1c4262"
    readonly property color cyan: "#21b7ff"
    readonly property color green: "#31d67b"
    readonly property color textMain: "#f2f7fb"
    readonly property color textDim: "#9db2c5"
    readonly property color danger: "#ff3e55"

    function num(v, decimals, suffix) { return isNaN(v) ? "--" : Number(v).toFixed(decimals) + suffix }

    Rectangle { anchors.fill: parent; color: root.bg }

    Rectangle {
        id: header
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        height: 72; color: "#071827"; border.color: root.line
        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 20; anchors.rightMargin: 20; spacing: 14
            ColumnLayout { spacing: 0
                Label { text: "NAVO SMART"; color: root.cyan; font.pixelSize: 25; font.bold: true }
                Label { text: "Pescarul lu peste"; color: root.textDim; font.pixelSize: 12 }
            }
            Item { Layout.fillWidth: true }
            StatusPill { label: root.gpsRtk ? "GPS RTK" : "GPS"; value: root.satellites >= 0 ? root.satellites + " sat" : "--"; ok: root.gpsFix >= 3 }
            StatusPill { label: "BATERIE"; value: root.num(root.batteryPercent,0,"%") + "  " + root.num(root.batteryVoltage,1,"V"); ok: !isNaN(root.batteryPercent) && root.batteryPercent > 25 }
            StatusPill { label: "VITEZĂ"; value: root.num(root.speedMps,1," m/s"); ok: root.vehicleConnected }
            StatusPill { label: "DIRECȚIE"; value: root.num(root.headingDeg,0,"°"); ok: root.vehicleConnected }
            StatusPill { label: "MOD"; value: root.flightMode; ok: root.vehicleConnected }
        }
    }

    Rectangle {
        id: sidebar
        anchors.left: parent.left; anchors.top: header.bottom; anchors.bottom: footer.top
        width: 190; color: "#071522"; border.color: root.line
        ColumnLayout { anchors.fill: parent; anchors.margins: 12; spacing: 8
            NavButton { text: "Hartă"; active: true }
            NavButton { text: "Sonar" }
            NavButton { text: "Puncte" }
            NavButton { text: "Trasee" }
            NavButton { text: "Setări" }
            Item { Layout.fillHeight: true }
            Label { text: root.vehicle ? root.vehicle.vehicleTypeString : "ArduPilot Rover"; color: root.textDim; font.pixelSize: 11 }
            Label { text: "Matek H743-WING V3"; color: root.textDim; font.pixelSize: 10 }
        }
    }

    Rectangle {
        id: mapPanel
        anchors.left: sidebar.right; anchors.right: rightPanel.left
        anchors.top: header.bottom; anchors.bottom: footer.top
        anchors.margins: 10; radius: 10; color: root.panel; border.color: root.line; clip: true

        FlyViewMap {
            id: liveMap
            anchors.fill: parent
            planMasterController: planController
            rightPanelWidth: 0
            toolInsets: QtObject {
                readonly property real leftEdgeTopInset: 0; readonly property real leftEdgeCenterInset: 0; readonly property real leftEdgeBottomInset: 0
                readonly property real rightEdgeTopInset: 0; readonly property real rightEdgeCenterInset: 0; readonly property real rightEdgeBottomInset: 0
                readonly property real topEdgeLeftInset: 0; readonly property real topEdgeCenterInset: 0; readonly property real topEdgeRightInset: 0
                readonly property real bottomEdgeLeftInset: 0; readonly property real bottomEdgeCenterInset: 48; readonly property real bottomEdgeRightInset: 0
            }
        }

        PlanMasterController {
            id: planController
            Component.onCompleted: { start(); if (root.vehicleConnected) loadFromVehicle() }
        }

        // NAVO SMART interactive layer: tap a waypoint -> live details -> explicit confirmation -> Guided GoTo.
        NavoWaypointMapOverlay {
            id: waypointLayer
            anchors.fill: liveMap
            map: liveMap
            missionController: planController.missionController
            vehicle: root.vehicle
            waypointNames: root.waypointNames
            savedDepthM: root.sonarConnected ? root.depthM : NaN
            savedWaterTempC: root.sonarConnected ? root.waterTempC : NaN
            z: 1000
            onNavigationCommandSent: function(wp, accepted) {
                root.lastNavigationStatus = accepted
                    ? "Navigare trimisă către " + friendlyName(wp)
                    : "Comanda de navigare a fost refuzată"
            }
        }

        Connections {
            target: QGroundControl.multiVehicleManager
            function onActiveVehicleChanged(activeVehicle) {
                waypointLayer.selectedWaypoint = null
                if (activeVehicle) { planController.loadFromVehicle(); liveMap.center = activeVehicle.coordinate }
            }
        }

        Rectangle {
            anchors.left: parent.left; anchors.top: parent.top; anchors.margins: 12
            width: mapTitle.implicitWidth + 22; height: 32; radius: 6; color: "#071827dd"
            Label { id: mapTitle; anchors.centerIn: parent; text: "HARTĂ LIVE • MAVLink"; color: root.textMain; font.bold: true }
        }

        RowLayout {
            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 12; spacing: 8
            Button { text: "Centrează barca"; enabled: root.vehicleConnected; onClicked: if (root.vehicle) liveMap.center = root.vehicle.coordinate }
            Button { text: "HOME"; enabled: root.vehicleConnected && root.vehicle.homePosition.isValid; onClicked: if (root.vehicle && root.vehicle.homePosition.isValid) liveMap.center = root.vehicle.homePosition }
            Button { text: "Potrivește traseul"; enabled: root.vehicleConnected; onClicked: liveMap.mapFitFunctions.fitMapViewportToMissionItems() }
            Item { Layout.fillWidth: true }
            Rectangle { width: 154; height: 34; radius: 6; color: "#071827dd"; Label { anchors.centerIn: parent; text: "Acasă: " + root.num(root.distanceHomeM,0," m"); color: root.textMain; font.bold: true } }
        }
    }

    Rectangle {
        id: rightPanel
        anchors.right: parent.right; anchors.top: header.bottom; anchors.bottom: footer.top
        anchors.topMargin: 10; anchors.bottomMargin: 10; anchors.rightMargin: 10
        width: 310; color: root.panel; radius: 10; border.color: root.line
        ColumnLayout { anchors.fill: parent; anchors.margins: 14; spacing: 10
            Label { text: "TELEMETRIE MAVLINK"; color: root.textMain; font.bold: true; font.pixelSize: 15 }
            DataLine { name: "Distanță acasă"; value: root.num(root.distanceHomeM,0," m") }
            DataLine { name: "GPS HDOP"; value: root.num(root.hdop,1,"") }
            DataLine { name: "GPS fix"; value: root.gpsFix >= 6 ? "RTK FIXED" : (root.gpsFix === 5 ? "RTK FLOAT" : (root.gpsFix >= 3 ? "3D" : "Fără fix")) }
            DataLine { name: "Sateliți"; value: root.satellites >= 0 ? root.satellites.toString() : "--" }
            RowLayout { Layout.fillWidth: true; spacing: 7
                ModeButton { text: "MANUAL"; selected: root.flightMode.toUpperCase() === "MANUAL"; enabled: root.vehicleConnected; onClicked: if (root.vehicle) root.vehicle.flightMode = "Manual" }
                ModeButton { text: "AUTO"; selected: root.flightMode.toUpperCase() === "AUTO"; enabled: root.vehicleConnected; onClicked: if (root.vehicle) root.vehicle.flightMode = "Auto" }
                ModeButton { text: "RTL"; selected: root.flightMode.toUpperCase().indexOf("RTL") >= 0; enabled: root.vehicleConnected; onClicked: if (root.vehicle) root.vehicle.guidedModeRTL(false) }
            }
            Button { Layout.fillWidth: true; text: "Reîncarcă misiunea"; enabled: root.vehicleConnected; onClicked: planController.loadFromVehicle() }
            Rectangle { Layout.fillWidth: true; height: 1; color: root.line }
            RowLayout { Layout.fillWidth: true; Label { text: "SONAR 2D"; color: root.textMain; font.bold: true }; Item { Layout.fillWidth: true }; Label { text: root.sonarConnected ? "● Conectat" : "● Neconectat"; color: root.sonarConnected ? root.green : root.textDim } }
            Rectangle { Layout.fillWidth: true; Layout.fillHeight: true; Layout.minimumHeight: 150; radius: 7; color: "#06131e"; border.color: root.line
                Column { anchors.centerIn: parent; spacing: 5
                    Label { anchors.horizontalCenter: parent.horizontalCenter; text: root.sonarConnected ? root.num(root.depthM,1," m") : "-- m"; color: root.textMain; font.pixelSize: 28; font.bold: true }
                    Label { anchors.horizontalCenter: parent.horizontalCenter; text: root.sonarConnected ? root.num(root.waterTempC,1," °C") : "Kogger neconectat"; color: root.textDim }
                }
            }
            Label { text: "Kogger Sonar 2D Basic"; color: root.textDim; font.pixelSize: 11 }
        }
    }

    Rectangle {
        id: footer
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        height: 38; color: "#071522"; border.color: root.line
        RowLayout { anchors.fill: parent; anchors.leftMargin: 18; anchors.rightMargin: 18
            Label { text: root.lastNavigationStatus.length ? root.lastNavigationStatus : (root.vehicleConnected ? "●  MAVLink conectat • " + root.flightMode : "●  Aștept conexiunea ArduPilot"); color: root.vehicleConnected ? root.green : root.danger }
            Item { Layout.fillWidth: true }
            Label { text: "NAVO SMART • Pescarul lu peste • V0.3 WAYPOINT LIVE"; color: root.textDim; font.pixelSize: 11 }
        }
    }

    component StatusPill: Rectangle {
        property string label: ""; property string value: ""; property bool ok: false
        Layout.preferredWidth: 120; Layout.preferredHeight: 48; radius: 7; color: root.panel2; border.color: ok ? root.green : root.line
        Column { anchors.centerIn: parent; spacing: 1; Label { anchors.horizontalCenter: parent.horizontalCenter; text: label; color: root.textDim; font.pixelSize: 9 }; Label { anchors.horizontalCenter: parent.horizontalCenter; text: value; color: ok ? root.green : root.textMain; font.pixelSize: 13; font.bold: true } }
    }
    component NavButton: Button {
        property bool active: false; Layout.fillWidth: true; Layout.preferredHeight: 44
        background: Rectangle { radius: 7; color: parent.active ? "#123d58" : "transparent"; border.color: parent.active ? root.cyan : "transparent" }
        contentItem: Label { text: parent.text; color: parent.active ? root.cyan : root.textMain; verticalAlignment: Text.AlignVCenter; leftPadding: 10; font.bold: parent.active }
    }
    component ModeButton: Button {
        property bool selected: false; Layout.fillWidth: true
        background: Rectangle { radius: 6; color: parent.selected ? "#0e7048" : root.panel2; border.color: parent.selected ? root.green : root.line }
        contentItem: Label { text: parent.text; color: parent.selected ? "white" : root.textDim; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.bold: true; font.pixelSize: 11 }
    }
    component DataLine: RowLayout {
        property string name: ""; property string value: "--"; Layout.fillWidth: true
        Label { text: parent.name; color: root.textDim }; Item { Layout.fillWidth: true }; Label { text: parent.value; color: root.textMain; font.bold: true }
    }
}
