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
    property bool silentModeActive: false
    property bool cameraConnected: false
    property string cameraStreamUrl: ""
    property bool waterAlarm: false
    property real escTempC: NaN
    property real batteryCurrentA: NaN
    property string boatId: "NAV0001"
    property int activePage: 0
    property bool hopperStatusExpanded: false
    property string selectedHopper: "none"
    property int manualHopperHoldMs: 1500
    readonly property bool manualMode: root.flightMode.toUpperCase() === "MANUAL"
    readonly property bool autoMode: root.flightMode.toUpperCase() === "AUTO"
    readonly property bool autoHopperWindow: root.autoMode && baitingController.enabled && baitingController.distanceToTarget() <= baitingController.finalRadiusM
    readonly property bool hopperReleaseSafe: root.manualMode || (root.autoHopperWindow && !isNaN(root.speedMps) && root.speedMps <= baitingController.releaseMaxSpeedMps)

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
    function setMode(mode) { if (!root.vehicle) return; if (baitingController.enabled && mode.toUpperCase() === "MANUAL") baitingController.abortCycle("AUTO întrerupt: control manual"); root.vehicle.flightMode = mode; root.lastNavigationStatus = "Mod solicitat: " + mode }
    function holdBoat() { if (!root.vehicle) return; if (baitingController.enabled) baitingController.abortCycle("HOLD manual"); else root.vehicle.pauseVehicle(); root.lastNavigationStatus = "HOLD/STOP solicitat" }
    function rtlBoat() { if (!root.vehicle) return; if (baitingController.enabled) baitingController.abortCycle("RTL manual"); root.vehicle.guidedModeRTL(false); root.lastNavigationStatus = "RTL solicitat" }

    NavoDigitalAnchor { id: digitalAnchor; vehicle: root.vehicle; onStatus: function(text) { root.lastNavigationStatus = text } }
    NavoActionSequence { id: actionSequence; vehicle: root.vehicle; hopperBridge: hopperBridge; onStatus: function(text) { root.lastNavigationStatus = text } }

    NavoFailsafeController {
        id: failsafeController
        vehicle: root.vehicle
        linkGraceSeconds: 30
        gpsRecoverySeconds: 60
        gpsReturnHomeSeconds: 120
        onHoldRequested: function(reason) {
            if (baitingController.enabled) baitingController.abortCycle(reason)
            else if (root.vehicle) root.vehicle.pauseVehicle()
            root.lastNavigationStatus = "FAILSAFE HOLD: " + reason
        }
        onRtlRequested: function(reason) {
            if (root.vehicle) root.vehicle.guidedModeRTL(false)
            root.lastNavigationStatus = "FAILSAFE RTL: " + reason
        }
        onRecovered: function(subsystem, action) {
            root.lastNavigationStatus = subsystem + " RESTABILIT: " + action
        }
    }

    NavoHopperBridge {
        id: hopperBridge
        vehicle: root.vehicle
        // Intentionally false until the real H743 output numbers and PWM end-points
        // are measured on the assembled boat.
        calibrated: false
        onCommandSent: function(text) { root.lastNavigationStatus = text }
    }

    NavoBaitingController {
        id: baitingController
        vehicle: root.vehicle
        silentMode: root.silentModeActive

        onGotoRequested: function(coordinate, reason) {
            if (!root.vehicle || !coordinate || !coordinate.isValid) {
                abortCycle("Coordonată de navigare invalidă")
                return
            }
            var accepted = root.vehicle.guidedModeGotoLocation(coordinate)
            if (!accepted) abortCycle("ArduPilot a refuzat comanda Guided GoTo")
        }

        // QGC exposes this Vehicle API and routes it through the firmware plugin.
        // Actual low-speed behaviour still requires Rover/H743 bench + water validation.
        onSpeedRequested: function(metersPerSecond) {
            if (!root.vehicle || metersPerSecond <= 0.05) return
            root.vehicle.guidedModeChangeGroundSpeedMetersSecond(metersPerSecond)
        }

        onStopRequested: function(reason) {
            if (!root.vehicle) return
            root.vehicle.pauseVehicle()
            root.lastNavigationStatus = "STOP/HOLD: " + reason
        }

        onSilentModeChangedDetailed: function(active) {
            root.silentModeActive = active
            root.lastNavigationStatus = active ? "🔇 Mod SILENȚIOS activ" : "Mod silențios dezactivat"
        }

        onHopperReleaseRequested: function(hopper) {
            root.hopperStatusExpanded = true
            root.selectedHopper = hopper
            if (!hopperBridge.release(hopper))
                root.lastNavigationStatus = "Eliberare blocată: calibrează ieșirile H743 și PWM-urile cuvelor"
        }

        onRtlRequested: function() {
            if (root.vehicle) root.vehicle.guidedModeRTL(false)
        }

        onStateChangedDetailed: function(state, text) {
            root.lastNavigationStatus = "Nădire: " + text
            if (state === baitingController.finalApproachState) root.hopperStatusExpanded = true
        }

        onCycleFinished: function(success, message) {
            root.lastNavigationStatus = message
            hopperPopupClose.restart()
        }
    }

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
            Button {
                text: root.silentModeActive ? "🔇 SILENȚIOS" : "🔊 NORMAL"
                checkable: true
                checked: root.silentModeActive
                enabled: root.vehicleConnected
                onClicked: baitingController.toggleSilentMode()
                background: Rectangle { radius: 7; color: parent.checked ? "#0e7048" : root.panel2; border.color: parent.checked ? root.green : root.line }
                contentItem: Label { text: parent.text; color: parent.checked ? "white" : root.textMain; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.bold: true }
            }
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
            NavButton { text: "Sonar"; onClicked: sonarFull.open() }
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

        PlanMasterController { id: planController; Component.onCompleted: { start(); if (root.vehicleConnected) loadFromVehicle() } }

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
                root.lastNavigationStatus = accepted ? "Navigare trimisă către " + waypointLayer.friendlyName(wp) : "Comanda de navigare a fost refuzată"
            }
        }

        NavoBaitingPanel {
            id: baitingPanel
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            z: 1100
            visible: waypointLayer.selectedWaypoint !== null || baitingController.enabled
            controller: baitingController
            waypoint: waypointLayer.selectedWaypoint ? waypointLayer.selectedWaypoint : baitingController.targetWaypoint
            waypointName: waypointLayer.selectedWaypoint ? waypointLayer.friendlyName(waypointLayer.selectedWaypoint) : baitingController.targetName
            onStartConfirmed: function(wp, name, hopper) {
                if (!root.vehicleConnected || root.gpsFix < 3) {
                    root.lastNavigationStatus = "Nădire blocată: este necesar GPS 3D/RTK și conexiune MAVLink"
                    return
                }
                if (baitingController.startCycle(wp, name, hopper)) waypointLayer.selectedWaypoint = null
            }
            onAbortRequested: baitingController.abortCycle("Oprit manual din NAVO SMART")
        }

        Connections {
            target: QGroundControl.multiVehicleManager
            function onActiveVehicleChanged(activeVehicle) {
                if (baitingController.enabled) baitingController.abortCycle("Vehiculul activ s-a schimbat")
                waypointLayer.selectedWaypoint = null
                if (activeVehicle) { planController.loadFromVehicle(); liveMap.center = activeVehicle.coordinate }
            }
        }

        NavoCameraPip {
            id: cameraPip
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.leftMargin: 12
            anchors.topMargin: 52
            z: 1050
            connected: root.cameraConnected
            streamUrl: root.cameraStreamUrl
            onFullscreenRequested: root.lastNavigationStatus = "Camera GR01: fullscreen va fi activat când conectăm fluxul real G20"
        }


        NavoBoatStatus {
            id: boatStatusMini
            compact: true
            width: 150; height: 105
            anchors.right: parent.right; anchors.bottom: parent.bottom
            anchors.rightMargin: 12; anchors.bottomMargin: 54
            z: 1200
            leftHopperCommandOpen: hopperBridge.leftOpen
            rightHopperCommandOpen: hopperBridge.rightOpen
            waterDetected: root.waterAlarm
            batteryTempC: NaN
            visible: !root.hopperStatusExpanded
            MouseArea { anchors.fill: parent; onClicked: root.hopperStatusExpanded = true }
        }

        Popup {
            id: hopperStatusPopup
            visible: root.hopperStatusExpanded
            modal: false
            focus: false
            closePolicy: Popup.NoAutoClose
            x: (mapPanel.width-width)/2; y: (mapPanel.height-height)/2
            width: 430; height: 320
            background: Rectangle { radius: 16; color: "#071827f2"; border.color: root.cyan; border.width: 2 }
            contentItem: ColumnLayout {
                anchors.fill: parent; anchors.margins: 14
                Label { text: "DESCĂRCARE / STATUS BARCĂ"; color: root.cyan; font.bold: true; font.pixelSize: 18; Layout.alignment: Qt.AlignHCenter }
                NavoBoatStatus {
                    Layout.alignment: Qt.AlignHCenter; Layout.preferredWidth: 360; Layout.preferredHeight: 235
                    compact: false
                    leftHopperCommandOpen: hopperBridge.leftOpen
                    rightHopperCommandOpen: hopperBridge.rightOpen
                    waterDetected: root.waterAlarm
                    batteryTempC: NaN
                }
                RowLayout {
                    Layout.fillWidth: true
                    HoldHopperButton { Layout.fillWidth: true; text: "ȚINE C1"; hopperId: 1 }
                    HoldHopperButton { Layout.fillWidth: true; text: "ȚINE AMBELE"; hopperId: 3 }
                    HoldHopperButton { Layout.fillWidth: true; text: "ȚINE C2"; hopperId: 2 }
                }
                Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.autoMode && !root.autoHopperWindow ? "Cuve blocate până la apropierea finală" :
                          (root.autoMode && !root.hopperReleaseSafe ? "Aștept STOP pentru descărcare" : "Ține apăsat 1,5 s pentru deschidere")
                    color: root.textDim; font.pixelSize: 11
                }
                Button { text: "Închide"; Layout.alignment: Qt.AlignHCenter; onClicked: root.hopperStatusExpanded=false }
            }
        }

        Timer { id: hopperPopupClose; interval: 5000; repeat:false; onTriggered: root.hopperStatusExpanded=false }

        Rectangle { anchors.left: parent.left; anchors.top: parent.top; anchors.margins: 12; width: mapTitle.implicitWidth + 22; height: 32; radius: 6; color: "#071827dd"; Label { id: mapTitle; anchors.centerIn: parent; text: "HARTĂ LIVE • MAVLink"; color: root.textMain; font.bold: true } }
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
            Label { text: "KOGGER 2D SONAR"; color: root.cyan; font.bold: true; font.pixelSize: 15 }
            DataLine { name: "Distanță acasă"; value: root.num(root.distanceHomeM,0," m") }
            DataLine { name: "GPS HDOP"; value: root.num(root.hdop,1,"") }
            DataLine { name: "GPS fix"; value: root.gpsFix >= 6 ? "RTK FIXED" : (root.gpsFix === 5 ? "RTK FLOAT" : (root.gpsFix >= 3 ? "3D" : "Fără fix")) }
            DataLine { name: "Sateliți"; value: root.satellites >= 0 ? root.satellites.toString() : "--" }
            DataLine { name: "Nădire"; value: baitingController.stateText(baitingController.state) }
            DataLine { name: "Silențios"; value: root.silentModeActive ? "ACTIV" : "Normal" }
            DataLine { name: "Țintă viteză"; value: root.num(baitingController.targetSpeedMps,1," m/s") }
            RowLayout { Layout.fillWidth: true; spacing: 7
                ModeButton { text: "MANUAL"; selected: root.manualMode; enabled: root.vehicleConnected; onClicked: root.setMode("Manual") }
                ModeButton { text: "AUTO"; selected: root.autoMode; enabled: root.vehicleConnected; onClicked: root.setMode("Auto") }
                ModeButton { text: "HOLD"; selected: root.flightMode.toUpperCase().indexOf("HOLD") >= 0; enabled: root.vehicleConnected; onClicked: root.holdBoat() }
                ModeButton { text: "RTL"; selected: root.flightMode.toUpperCase().indexOf("RTL") >= 0; enabled: root.vehicleConnected; onClicked: root.rtlBoat() }
            }
            Button { Layout.fillWidth: true; text: "Reîncarcă misiunea"; enabled: root.vehicleConnected; onClicked: { planController.loadFromVehicle(); root.lastNavigationStatus="Misiune reîncărcată din H743" } }
            Button { Layout.fillWidth: true; text: digitalAnchor.active ? "Eliberează ancora GPS" : "Ancoră GPS"; enabled: root.vehicleConnected && root.gpsFix >= 3; onClicked: { if (digitalAnchor.active) digitalAnchor.release(); else digitalAnchor.engage() } }
            Label { text: "CAMERĂ BARCĂ"; color: root.cyan; font.bold: true }
            NavoCameraPip {
                Layout.fillWidth: true; Layout.preferredHeight: 125
                connected: root.cameraConnected; streamUrl: root.cameraStreamUrl
                onFullscreenRequested: root.lastNavigationStatus = "Cameră: fullscreen solicitat"
            }
            Label { text: "NĂDIRE SILENȚIOASĂ"; color: root.cyan; font.bold: true }
            RowLayout {
                Layout.fillWidth: true
                Button { Layout.fillWidth: true; text: "STÂNGA"; enabled: root.vehicleConnected; onClicked: root.lastNavigationStatus = "Cuva stângă selectată" }
                Button { Layout.fillWidth: true; text: "AMBELE"; enabled: root.vehicleConnected; onClicked: root.lastNavigationStatus = "Ambele cuve selectate" }
                Button { Layout.fillWidth: true; text: "DREAPTA"; enabled: root.vehicleConnected; onClicked: root.lastNavigationStatus = "Cuva dreaptă selectată" }
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: root.line }
            NavoSonarCard {
                Layout.fillWidth: true
                Layout.preferredHeight: 190
                connected: root.sonarConnected
                depthM: root.depthM
                waterTempC: root.waterTempC
                onOpenFullSonar: sonarFull.open()
            }
            NavoSafetyCard {
                Layout.fillWidth: true
                waterAlarm: root.waterAlarm
            }
            NavoFailsafePanel {
                Layout.fillWidth: true
                controller: failsafeController
            }
        }
    }

    NavoSonarFullScreen {
        id: sonarFull
        parent: Overlay.overlay
        x: 0
        y: 0
        width: Overlay.overlay ? Overlay.overlay.width : root.width
        height: Overlay.overlay ? Overlay.overlay.height : root.height
        connected: root.sonarConnected
        depthM: root.depthM
        waterTempC: root.waterTempC
        speedMps: root.speedMps
        latitude: root.vehicle && root.vehicle.coordinate && root.vehicle.coordinate.isValid ? root.vehicle.coordinate.latitude : NaN
        longitude: root.vehicle && root.vehicle.coordinate && root.vehicle.coordinate.isValid ? root.vehicle.coordinate.longitude : NaN
        onSaveWaypointRequested: function(latitude, longitude, depth, temperature) {
            root.lastNavigationStatus = "Punct sonar pregătit: " + depth.toFixed(1) + " m • " + latitude.toFixed(6) + ", " + longitude.toFixed(6)
        }
    }

    Rectangle {
        id: footer
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        height: 38; color: "#071522"; border.color: root.line
        RowLayout { anchors.fill: parent; anchors.leftMargin: 18; anchors.rightMargin: 18
            Label { text: root.lastNavigationStatus.length ? root.lastNavigationStatus : (root.vehicleConnected ? "● MAVLink conectat • " + root.flightMode : "● Aștept conexiunea ArduPilot"); color: root.vehicleConnected ? root.green : root.danger }
            Item { Layout.fillWidth: true }
            Label { text: "NAVO SMART • Pescarul lu peste • V0.9 FAILSAFE RECOVERY"; color: root.textDim; font.pixelSize: 11 }
        }
    }

    component StatusPill: Rectangle {
        property string label: ""
        property string value: ""
        property bool ok: false
        Layout.preferredWidth: 120
        Layout.preferredHeight: 48
        radius: 7
        color: root.panel2
        border.color: ok ? root.green : root.line
        Column {
            anchors.centerIn: parent
            spacing: 1
            Label { anchors.horizontalCenter: parent.horizontalCenter; text: label; color: root.textDim; font.pixelSize: 9 }
            Label { anchors.horizontalCenter: parent.horizontalCenter; text: value; color: ok ? root.green : root.textMain; font.pixelSize: 13; font.bold: true }
        }
    }
    component NavButton: Button {
        property bool active: false
        Layout.fillWidth: true
        Layout.preferredHeight: 44
        background: Rectangle { radius: 7; color: parent.active ? "#123d58" : "transparent"; border.color: parent.active ? root.cyan : "transparent" }
        contentItem: Label { text: parent.text; color: parent.active ? root.cyan : root.textMain; verticalAlignment: Text.AlignVCenter; leftPadding: 10; font.bold: parent.active }
    }
    component ModeButton: Button {
        property bool selected: false
        Layout.fillWidth: true
        background: Rectangle { radius: 6; color: parent.selected ? "#0e7048" : root.panel2; border.color: parent.selected ? root.green : root.line }
        contentItem: Label { text: parent.text; color: parent.selected ? "white" : root.textDim; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.bold: true; font.pixelSize: 11 }
    }
    component HoldHopperButton: Button {
        property int hopperId: 0
        property real holdProgress: 0
        enabled: root.vehicleConnected && (root.manualMode || root.autoHopperWindow)
        onPressed: { holdProgress = 0; hopperHoldTimer.restart() }
        onReleased: { if (hopperHoldTimer.running) hopperHoldTimer.stop(); holdProgress = 0 }
        onCanceled: { hopperHoldTimer.stop(); holdProgress = 0 }
        Timer {
            id: hopperHoldTimer
            interval: 50
            repeat: true
            onTriggered: {
                parent.holdProgress += interval / root.manualHopperHoldMs
                if (parent.holdProgress >= 1) {
                    stop()
                    parent.holdProgress = 0
                    if (!root.hopperReleaseSafe) {
                        root.lastNavigationStatus = root.autoMode ? "Cuva blocată: aștept oprirea bărcii" : "Cuva blocată"
                        return
                    }
                    root.hopperStatusExpanded = true
                    root.selectedHopper = parent.hopperId
                    if (!hopperBridge.release(parent.hopperId))
                        root.lastNavigationStatus = "Deschidere blocată: cuvele trebuie calibrate pe H743"
                }
            }
        }
        background: Rectangle {
            radius: 6
            color: !parent.enabled ? "#26313a" : (parent.pressed ? "#0e7048" : root.panel2)
            border.color: parent.enabled ? root.cyan : "#46515a"
            Rectangle {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                height: 4
                width: parent.width * parent.parent.holdProgress
                color: root.green
                radius: 2
            }
        }
        contentItem: Label { text: parent.text; color: parent.enabled ? root.textMain : "#78838c"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.bold: true }
    }
    component DataLine: RowLayout {
        property string name: ""
        property string value: "--"
        Layout.fillWidth: true
        Label { text: parent.name; color: root.textDim }
        Item { Layout.fillWidth: true }
        Label { text: parent.value; color: root.textMain; font.bold: true }
    }
}
