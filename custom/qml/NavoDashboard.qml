import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtPositioning

import QGroundControl
import QGroundControl.Controllers
import QGroundControl.Controls
import QGroundControl.FlightDisplay
import QGroundControl.FlightMap
import NavoSmart 1.0
import NavoSmart.Backend 1.0

Item {
    id: root
    implicitWidth: 1280
    implicitHeight: 720

    // Compatibility with QGroundControl v5.0.7 MainWindow, which binds this
    // property on the FlyView root. NAVO does not currently use UTM/SP.
    property bool utmspSendActTrigger: false

    property var vehicle: QGroundControl.multiVehicleManager.activeVehicle
    property var planController: _planController

    PlanMasterController {
        id: _planController
        flyView: true
        Component.onCompleted: start()
    }

    NavoPersistence { id: persistence }
    NavoFishingSpots { id: fishingSpots }
    NavoFishDetections { id: fishStore }
    NavoAreaScan { id: areaScanController }
    NavoBaitingController {
        id: baitingController
        vehicle: root.vehicle
        onGotoRequested: function(coordinate, reason) { if(root.vehicle && root.vehicle.guidedModeGotoLocation) root.vehicle.guidedModeGotoLocation(coordinate) }
        onSpeedRequested: function(metersPerSecond) {
            if(root.vehicle && root.vehicle.guidedModeChangeGroundSpeedMetersSecond)
                root.vehicle.guidedModeChangeGroundSpeedMetersSecond(metersPerSecond)
        }
        onStopRequested: function(reason) { root.holdMission(); root.lastNavigationStatus="Nădire: "+reason }
        onHopperReleaseRequested: function(hopper) {
            if(!hopperBridge.release(hopper))
                baitingController.abortCycle("Cuva nu a putut fi comandată")
        }
        onRtlRequested: root.rtlMission()
        onStateChangedDetailed: function(state, text) { root.lastNavigationStatus="Nădire: "+text }
        onCycleFinished: function(success, message) { root.lastNavigationStatus=message }
    }
    NavoDigitalAnchor {
        id: digitalAnchor
        vehicle: root.vehicle
        onStatus: function(text) { root.lastNavigationStatus=text }
    }
    NavoEnergyGuard { id: energyGuard }
    NavoFailsafeController {
        id: failsafeController
        vehicle: root.vehicle
        onHoldRequested: function(reason) { root.lastNavigationStatus="FAILSAFE HOLD: "+reason; root.holdMission() }
        onRtlRequested: function(reason) { root.lastNavigationStatus="FAILSAFE RTL: "+reason; root.rtlMission() }
        onRecovered: function(subsystem, action) { root.lastNavigationStatus=subsystem+": "+action }
    }
    NavoSonarMapping {
        id: sonarMapping
        visible: false
        vehicle: root.vehicle
        depthM: root.depthM
        waterTempC: root.waterTempC
        sonarConnected: root.sonarConnected
        externalSampleIngestion: true
        onCheckpointRequested: function(state) { scanCoordinator.checkpoint("sonar-mapping") }
    }
    NavoScanCoordinator {
        id: scanCoordinator
        areaScan: areaScanController
        persistence: persistence
        fishingSpots: fishingSpots
        sonarMapping: sonarMapping
        vehicle: root.vehicle
        onMissionPrepared: function(points) {
            if (!missionUploader.prepare(points))
                root.lastNavigationStatus = "Pregătire misiune eșuată: " + missionUploader.lastError
        }
        onStatus: function(message) { root.lastNavigationStatus = message }
    }
    Connections {
        target: root.planController ? root.planController.missionController : null
        function onCurrentMissionIndexChanged(currentMissionIndex) {
            scanCoordinator.missionIndexChanged(currentMissionIndex)
        }
    }
    Connections {
        target: root.vehicle
        function onFlightModeChanged() {
            if (!root.vehicle) return
            var expected = String(root.vehicle.missionFlightMode || "").toUpperCase()
            var actual = String(root.vehicle.flightMode || "").toUpperCase()
            if (expected.length && actual === expected)
                root.lastNavigationStatus = "H743 confirmă " + root.vehicle.flightMode + " • misiune activă"
        }
    }

    NavoMissionUploader {
        id: missionUploader
        planController: root.planController
        vehicle: root.vehicle
        onStatus: function(message) { root.lastNavigationStatus = message }
        onUploadFinished: function(success, message) {
            root.lastNavigationStatus = message
            // Upload confirmation is not permission to start motors. Require a second press.
        }
    }
    property var battery: vehicle && vehicle.batteries.count > 0 ? vehicle.batteries.get(0) : null
    property var waypointNames: persistence.waypointNames
    readonly property real depthM: sonar.depthM
    readonly property real waterTempC: sonar.waterTempC
    readonly property bool sonarConnected: sonar.connected && sonar.dataAlive
    property alias fishDetections: fishStore.detections
    property string cameraStreamUrl: ""
    property string cameraProtocol: "auto"
    property string lastNavigationStatus: ""
    property bool silentModeActive: false
    property bool cameraConnected: false
    property bool cameraFullscreen: false
    property string flightMode: vehicle ? vehicle.flightMode : ""
    property real distanceToHome: vehicle && vehicle.distanceToHome ? vehicle.distanceToHome.rawValue : 0
    property real distanceToTarget: vehicle && vehicle.distanceToGoal ? vehicle.distanceToGoal.rawValue : 0
    property string boatId: "NAV0001"
    property int activePage: 0
    property bool hopperStatusExpanded: false
    property bool mapFullscreen: false
    property var mapController: null
    property string selectedHopper: "none"
    property int manualHopperHoldMs: 1500
    readonly property bool manualMode: root.flightMode.toUpperCase() === "MANUAL"
    readonly property bool nearBaitingPoint: root.distanceToTarget > 0 && root.distanceToTarget <= 8
    readonly property bool hopperControlsEnabled: root.manualMode || root.nearBaitingPoint
    property color bg: "#0b1016"
    property color panel: "#121a24"
    property color line: "#273342"
    property color text: "#eaf2f8"
    property color muted: "#91a3b5"
    property color accent: "#26c6da"
    property color ok: "#47d16c"
    property color warn: "#ffc857"
    property color danger: "#ff5c5c"

    NavoSonarEthernet {
        id: sonar
        vehicle: root.vehicle
        onGeoSample: function(sample) {
            persistence.addSonarSample(sample)
            sonarMapping.ingestSample(sample)
        }
    }
    NavoFishDetector {
        id: fishDetector
        onTargetDetected: function(targetDepthM, strength) {
            if (!root.vehicle || !root.vehicle.coordinate || !root.vehicle.coordinate.isValid) return
            fishStore.addDetection(root.vehicle.coordinate, targetDepthM, sonar.depthM, strength, Date.now())
            // NavoFishDetections owns bounded history and hotspot rebuilding.
        }
    }
    Connections {
        target: sonar.decoder
        function onEchoSamplesChanged() { fishDetector.analyze(sonar.echoSamples, sonar.depthM) }
    }

    NavoNanoTelemetry {
        id: nanoTelemetry
        vehicle: root.vehicle
    }
    NavoHopperBridge {
        id: hopperBridge
        vehicle: root.vehicle
        calibrated: nanoTelemetry.connected && nanoTelemetry.hopperLeftUs > 0 && nanoTelemetry.hopperRightUs > 0
        onCommandSent: function(message) { root.lastNavigationStatus = message }
        onCommandRejected: function(reason) { root.lastNavigationStatus = "Cuve: " + reason }
    }
    NavoSafetyManager {
        id: safetyManager
        vehicle: root.vehicle
        waterDetected: nanoTelemetry.waterDetected
        batteryTempC: nanoTelemetry.batteryTempC
        onWarning: function(reason) { root.lastNavigationStatus = "AVERTISMENT: " + reason }
        onHoldRequested: function(reason) {
            root.lastNavigationStatus = "SIGURANTA HOLD: " + reason
            root.holdMission()
        }
        onRtlRequested: function(reason) {
            root.lastNavigationStatus = "SIGURANTA RTL: " + reason
            root.rtlMission()
        }
    }

    function modeColor() {
        var m = root.flightMode.toUpperCase()
        if (m === "AUTO" || m === "GUIDED") return root.ok
        if (m === "RTL" || m === "HOLD") return root.warn
        return root.accent
    }
    function openHopper(side) {
        if (!root.hopperControlsEnabled) {
            root.lastNavigationStatus = "Cuve blocate: mergi aproape de punct sau treci pe MANUAL"
            return
        }
        var hopper = side === "stanga" ? 1 : side === "dreapta" ? 2 : 3
        if (!hopperBridge.release(hopper)) return
        root.selectedHopper = side
    }
    function closeHoppers() {
        root.selectedHopper = "none"
    }
    function startMission() {
        if (!root.vehicle) {
            root.lastNavigationStatus = "START blocat: H743 neconectat"
            return false
        }
        if (missionUploader.uploadInProgress) {
            root.lastNavigationStatus = "Upload misiune deja în curs"
            return false
        }
        if (missionUploader.uploadVerified) return root.startUploadedMission()
        if (missionUploader.preparedCount < 1) {
            root.lastNavigationStatus = "START blocat: nu există misiune pregătită"
            return false
        }
        return missionUploader.uploadPrepared()
    }
    function startUploadedMission() {
        if (!root.vehicle) {
            root.lastNavigationStatus = "Upload confirmat, dar H743 nu mai este conectat"
            return false
        }
        // QGC Vehicle::startMission() is the normal MAVLink mission-start path.
        // Never report AUTO before the vehicle reports the resulting mode.
        if (root.vehicle.startMission) {
            root.vehicle.startMission()
            root.lastNavigationStatus = "Upload confirmat • comandă START trimisă H743"
            return true
        }
        root.lastNavigationStatus = "Upload confirmat • START indisponibil în Vehicle API"
        return false
    }
    function holdMission() {
        if (vehicle && vehicle.pauseVehicle) vehicle.pauseVehicle()
        root.lastNavigationStatus = "HOLD activ"
    }
    function rtlMission() {
        if (vehicle && vehicle.guidedModeRTL) vehicle.guidedModeRTL(false)
        root.lastNavigationStatus = "RTL activ"
    }
    function stopMission() {
        if (vehicle && vehicle.pauseVehicle) vehicle.pauseVehicle()
        root.lastNavigationStatus = "Misiune oprita"
    }
    function navigateToCoordinate(c) {
        if (!vehicle || !c || !c.isValid) {
            root.lastNavigationStatus = "Navigatie indisponibila"
            return
        }
        if (vehicle.guidedModeGotoLocation) vehicle.guidedModeGotoLocation(c)
        root.lastNavigationStatus = "Navighez la punct"
    }


    Rectangle { anchors.fill: parent; color: root.bg }

    Rectangle {
        id: header
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        height: 64; color: "#101822"; border.color: root.line
        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16; spacing: 12
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Label { text: "NAVO SMART"; color: root.text; font.pixelSize: 22; font.bold: true }
                Label { text: "Pescarul lu Peste"; color: root.muted; font.pixelSize: 11 }
            }
            StatusPill { title: "GPS"; value: vehicle && vehicle.gps ? String(vehicle.gps.count.rawValue) + " sat" : "--"; good: vehicle && vehicle.gps }
            StatusPill { title: "BATERIE"; value: battery ? Number(battery.percentRemaining.rawValue).toFixed(0) + "%" : "--"; good: battery && battery.percentRemaining.rawValue > 20 }
            StatusPill { title: "MOD"; value: root.flightMode.length ? root.flightMode : "OFFLINE"; good: vehicle !== null }
        }
    }

    Rectangle {
        id: sidebar
        anchors.left: parent.left; anchors.top: header.bottom; anchors.bottom: footer.top
        width: 190; color: root.panel; border.color: root.line
        ColumnLayout {
            anchors.fill: parent; anchors.margins: 10; spacing: 8
            Label { text: "NAVIGATIE"; color: root.muted; font.bold: true }
            NavButton { text: "HARTA"; active: root.activePage === 0; onClicked: root.activePage = 0 }
            NavButton { text: "SONAR"; active: root.activePage === 1; onClicked: root.activePage = 1 }
            NavButton { text: "AREA SCAN"; active: root.activePage === 2; onClicked: root.activePage = 2 }
            NavButton { text: "PUNCTE PESCUIT"; active: root.activePage === 3; onClicked: root.activePage = 3 }
            NavButton { text: "BALȚILE MELE"; active: root.activePage === 4; onClicked: root.activePage = 4 }
            NavButton { text: "CAMERA"; active: root.activePage === 5; onClicked: root.activePage = 5 }
            NavButton { text: "3D"; active: root.activePage === 7; onClicked: root.activePage = 7 }
            NavButton { text: "NĂDIRE"; active: root.activePage === 8; onClicked: root.activePage = 8 }
            NavButton { text: "SETARI"; active: root.activePage === 6; onClicked: root.activePage = 6 }
            Item { Layout.fillHeight: true }
            Label { text: "BARCA " + root.boatId; color: root.muted; font.pixelSize: 11 }
        }
    }

    Rectangle {
        id: content
        anchors.left: sidebar.right; anchors.right: rightPanel.left; anchors.top: header.bottom; anchors.bottom: footer.top
        color: root.bg
        Loader {
            anchors.fill: parent; anchors.margins: 10
            sourceComponent: root.activePage === 0 ? mapPage :
                             root.activePage === 1 ? sonarPage :
                             root.activePage === 2 ? areaPage :
                             root.activePage === 3 ? fishingPage :
                             root.activePage === 4 ? lakesPage :
                             root.activePage === 5 ? cameraPage :
                             root.activePage === 7 ? bathymetryPage :
                             root.activePage === 8 ? baitingPage : settingsPage
        }
    }

    Rectangle {
        id: rightPanel
        anchors.right: parent.right; anchors.top: header.bottom; anchors.bottom: footer.top
        width: 260; color: root.panel; border.color: root.line
        ColumnLayout {
            anchors.fill: parent; anchors.margins: 12; spacing: 10
            Label { text: "STATUS BARCA"; color: root.text; font.bold: true }
            NavoEthernetIndicator {
                Layout.fillWidth: true
                sonarConnected: sonar.connected
                sonarAlive: sonar.dataAlive
                cameraConnected: root.cameraStreamUrl.length > 0
                cameraAlive: root.cameraStreamUrl.length > 0
                sonarStatus: sonar.status
                cameraStatus: root.cameraStreamUrl.length ? "URL configurat" : "OFFLINE"
            }
            DataLine { name: "Conexiune"; value: vehicle ? "ONLINE" : "OFFLINE"; valueColor: vehicle ? root.ok : root.danger }
            DataLine { name: "Mod"; value: root.flightMode.length ? root.flightMode : "--"; valueColor: root.modeColor() }
            DataLine { name: "Acasa"; value: Number(root.distanceToHome).toFixed(0) + " m" }
            DataLine { name: "Tinta"; value: root.distanceToTarget > 0 ? Number(root.distanceToTarget).toFixed(0) + " m" : "--" }
            DataLine { name: "Nano"; value: nanoTelemetry.connected ? "ONLINE" : "OFFLINE"; valueColor: nanoTelemetry.connected ? root.ok : root.warn }
            DataLine { name: "Temp baterie"; value: nanoTelemetry.connected && !isNaN(nanoTelemetry.batteryTempC) ? Number(nanoTelemetry.batteryTempC).toFixed(1) + " °C" : "--"; valueColor: safetyManager.state === "CRITICAL" ? root.danger : safetyManager.state === "WARNING" ? root.warn : root.text }
            DataLine { name: "Apa"; value: nanoTelemetry.connected ? (nanoTelemetry.waterDetected ? "DETECTATA" : "OK") : "--"; valueColor: nanoTelemetry.waterDetected ? root.danger : root.text }
            NavoBoatStatus {
                Layout.fillWidth: true
                Layout.preferredHeight: 150
                compact: true
                waterDetected: nanoTelemetry.waterDetected
                batteryTempC: nanoTelemetry.batteryTempC
                headlightOn: nanoTelemetry.headlightOn
                positionLightsOn: nanoTelemetry.positionLightsOn
                rudderNormalized: nanoTelemetry.rudderUs > 0 ? Math.max(-1,Math.min(1,(nanoTelemetry.rudderUs-1500)/500.0)) : 0
                leftHopperCommandOpen: hopperBridge.commandPending && (hopperBridge.pendingHopper===1||hopperBridge.pendingHopper===3)
                rightHopperCommandOpen: hopperBridge.commandPending && (hopperBridge.pendingHopper===2||hopperBridge.pendingHopper===3)
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: root.line }
            NavoFailsafePanel { Layout.fillWidth: true; controller: failsafeController }
            Label { text: "CONTROL MISIUNE"; color: root.muted; font.bold: true }
            RowLayout {
                Layout.fillWidth: true
                Button { Layout.fillWidth: true; text: missionUploader.uploadVerified ? "START H743" : "UPLOAD"; onClicked: root.startMission() }
                Button { Layout.fillWidth: true; text: "HOLD"; onClicked: root.holdMission() }
            }
            RowLayout {
                Layout.fillWidth: true
                Button { Layout.fillWidth: true; text: "RTL"; onClicked: root.rtlMission() }
                Button { Layout.fillWidth: true; text: "STOP"; onClicked: root.stopMission() }
            }
            RowLayout {
                Layout.fillWidth: true
                Button { Layout.fillWidth: true; text: digitalAnchor.active ? "ANCORĂ ON" : "ANCORĂ GPS"; onClicked: digitalAnchor.active ? digitalAnchor.release() : digitalAnchor.engage() }
                Label { text: energyGuard.message(root.distanceToHome, battery ? Number(battery.percentRemaining.rawValue) : NaN); color: battery && energyGuard.canStart(root.distanceToHome, Number(battery.percentRemaining.rawValue)) ? root.ok : root.warn; font.pixelSize: 9 }
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: root.line }
            Label { text: "CUVE"; color: root.muted; font.bold: true }
            Label {
                Layout.fillWidth: true; wrapMode: Text.WordWrap
                text: root.hopperControlsEnabled ? "Control disponibil" : "Blocate pana aproape de punct"
                color: root.hopperControlsEnabled ? root.ok : root.warn; font.pixelSize: 11
            }
            RowLayout {
                Layout.fillWidth: true
                Button { Layout.fillWidth: true; text: "STANGA"; enabled: root.hopperControlsEnabled; onClicked: root.openHopper("stanga") }
                Button { Layout.fillWidth: true; text: "DREAPTA"; enabled: root.hopperControlsEnabled; onClicked: root.openHopper("dreapta") }
            }
            Button { Layout.fillWidth: true; text: "AMBELE"; enabled: root.hopperControlsEnabled; onClicked: root.openHopper("ambele") }
            Item { Layout.fillHeight: true }
            Label { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: root.lastNavigationStatus; color: root.muted; font.pixelSize: 11 }
        }
    }

    Component {
        id: mapPage
        Item {
            Rectangle { anchors.fill: parent; radius: 8; color: root.panel; border.color: root.line }
            NavoMap {
                id: navoMap
                anchors.fill: parent; anchors.margins: 8
                Component.onCompleted: root.mapController = navoMap
                Component.onDestruction: if(root.mapController===navoMap) root.mapController=null
                vehicle: root.vehicle
                waypointNames: root.waypointNames
                fishModel: fishStore
                fishingSpotsModel: fishingSpots
                bathymetryCells: scanCoordinator.bathymetryCells
                baitingController: baitingController
                areaScanController: areaScanController
                savedDepthM: root.depthM
                savedWaterTempC: root.waterTempC
                onNavigateRequested: function(coordinate) { root.navigateToCoordinate(coordinate) }
                onBaitingWaypointSelected: function(waypoint) { root.activePage=8; root.lastNavigationStatus="Punct selectat pentru nădire automată" }
                onAreaRectangleRequested: function(cornerA, cornerB) {
                    var pts=scanCoordinator.prepareRectangle(cornerA,cornerB)
                    root.lastNavigationStatus="Area Scan dreptunghi • "+pts.length+" WP generate"
                    root.activePage=2
                }
                onAreaPolygonRequested: function(polygon) {
                    var boat=root.vehicle&&root.vehicle.coordinate&&root.vehicle.coordinate.isValid?root.vehicle.coordinate:null
                    var pts=areaScanController.generatePolygon(polygon)
                    scanCoordinator.areaPoints=pts
                    scanCoordinator.checkpoint("area-polygon")
                    root.lastNavigationStatus="Area Scan poligon • "+pts.length+" WP generate"
                    root.activePage=2
                }
                onSavePointRequested: function(coordinate) {
                    var spot = fishingSpots.saveSpot(coordinate, root.depthM, root.waterTempC, "", "", null)
                    if (spot) {
                        scanCoordinator.checkpoint("fishing-spot")
                        root.lastNavigationStatus = "Punct salvat: " + spot.name
                    } else root.lastNavigationStatus = "Punct invalid: nu a fost salvat"
                }
            }
        }
    }

    Component {
        id: sonarPage
        Item {
            Rectangle { anchors.fill: parent; radius: 8; color: root.panel; border.color: root.line }
            ColumnLayout {
                anchors.fill: parent; anchors.margins: 12; spacing: 8
                Label { text: "KOGGER SONAR"; color: root.text; font.pixelSize: 18; font.bold: true }
                NavoSonarCard {
                    Layout.fillWidth: true; Layout.preferredHeight: 150
                    connected: root.sonarConnected; depthM: root.depthM; waterTempC: root.waterTempC
                }
                NavoSonarFullScreen {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    connected: root.sonarConnected; depthM: root.depthM; waterTempC: root.waterTempC
                    echoSamples: sonar.echoSamples
                    transport: sonar
                    fishHotspots: root.fishDetections
                    latitude: root.vehicle && root.vehicle.coordinate && root.vehicle.coordinate.isValid ? root.vehicle.coordinate.latitude : NaN
                    longitude: root.vehicle && root.vehicle.coordinate && root.vehicle.coordinate.isValid ? root.vehicle.coordinate.longitude : NaN
                    onSaveWaypointRequested: function(latitude, longitude, depth, temp) {
                        var spot=fishingSpots.saveSpot(QtPositioning.coordinate(latitude,longitude),depth,temp,"","",null)
                        if(spot){scanCoordinator.checkpoint("sonar-fishing-spot");root.lastNavigationStatus="Punct sonar salvat: "+spot.name}
                    }
                }
            }
        }
    }

    Component {
        id: areaPage
        Item {
            Rectangle { anchors.fill: parent; radius: 8; color: root.panel; border.color: root.line }
            ColumnLayout {
                anchors.fill: parent; anchors.margins: 14; spacing: 10
                RowLayout {
                    Layout.fillWidth: true
                    Label { text: "AREA SCAN"; color: root.text; font.pixelSize: 20; font.bold: true }
                    Item { Layout.fillWidth: true }
                    Label { text: areaScanController.progressPercent() + "%"; color: root.accent; font.bold: true }
                }
                ProgressBar {
                    Layout.fillWidth: true
                    from: 0; to: 100
                    value: areaScanController.progressPercent()
                }
                Label {
                    Layout.fillWidth: true
                    text: areaScanController.laneCount() ?
                          (areaScanController.completedLanes.length + " / " + areaScanController.laneCount() + " culoare • WP H743 " + scanCoordinator.missionCurrentIndex) :
                          "Definește zona de scanare pe hartă."
                    color: root.muted
                }
                RowLayout {
                    Layout.fillWidth: true
                    Button {
                        text: "DREPTUNGHI PE HARTĂ"
                        onClicked: {
                            root.activePage=0
                            Qt.callLater(function(){ if(root.mapController)root.mapController.beginAreaRectangle() })
                        }
                    }
                    Button {
                        text: "POLIGON PE HARTĂ"
                        onClicked: {
                            root.activePage=0
                            Qt.callLater(function(){ if(root.mapController)root.mapController.beginAreaPolygon() })
                        }
                    }
                    Button {
                        text: "PREGĂTEȘTE MISIUNEA"
                        enabled: areaScanController.generatedPoints.length > 0 && !missionUploader.uploadInProgress
                        onClicked: scanCoordinator.prepareMission(false)
                    }
                    Button {
                        text: "START"
                        enabled: missionUploader.preparedCount > 0 && !missionUploader.uploadInProgress
                        onClicked: {
                            if (scanCoordinator.start()) root.startMission()
                        }
                    }
                    Button {
                        text: "RESUME"
                        enabled: areaScanController.generatedPoints.length > 0 && areaScanController.completedLanes.length < areaScanController.laneCount()
                        onClicked: {
                            var mission = scanCoordinator.resume()
                            if (mission.length) root.startMission()
                        }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Button { text: "HOLD"; onClicked: { scanCoordinator.pause("HOLD utilizator"); root.holdMission() } }
                    Button { text: "RTL"; onClicked: { scanCoordinator.rtl("RTL utilizator"); root.rtlMission() } }
                    Button { text: "STOP"; onClicked: { scanCoordinator.pause("STOP utilizator"); root.stopMission() } }
                    Item { Layout.fillWidth: true }
                    Label { text: scanCoordinator.state; color: root.modeColor(); font.bold: true }
                }
                Rectangle {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    radius: 8; color: root.bg; border.color: root.line
                    Column {
                        anchors.centerIn: parent; spacing: 8
                        Label { anchors.horizontalCenter: parent.horizontalCenter; text: "Traseu Area Scan"; color: root.text; font.pixelSize: 18; font.bold: true }
                        Label { anchors.horizontalCenter: parent.horizontalCenter; text: areaScanController.generatedPoints.length + " waypoint-uri"; color: root.muted }
                        Label { anchors.horizontalCenter: parent.horizontalCenter; text: "Culoar activ: " + (areaScanController.activeLaneIndex >= 0 ? (areaScanController.activeLaneIndex + 1) : "--"); color: root.muted }
                        Label { anchors.horizontalCenter: parent.horizontalCenter; text: "Zona se definește din hartă; aici se controlează misiunea H743."; color: root.muted }
                    }
                }
            }
        }
    }

    Component {
        id: fishingPage
        Item {
            Rectangle { anchors.fill: parent; radius: 8; color: root.panel; border.color: root.line }
            ColumnLayout {
                anchors.fill: parent; anchors.margins: 16; spacing: 8
                Label { text: "PUNCTE DE PESCUIT"; color: root.text; font.pixelSize: 20; font.bold: true }
                Label { text: fishingSpots.fishingSpots.length + " puncte salvate"; color: root.muted }
                ListView {
                    Layout.fillWidth: true; Layout.fillHeight: true; clip: true
                    model: fishingSpots.fishingSpots
                    delegate: Rectangle {
                        required property var modelData
                        width: ListView.view.width; height: 76; radius: 7; color: root.bg; border.color: root.line
                        Column {
                            anchors.left: parent.left; anchors.leftMargin: 10; anchors.verticalCenter: parent.verticalCenter
                            Label { text: modelData.name || "Loc pescuit"; color: root.text; font.bold: true }
                            Label { text: Number(modelData.lat).toFixed(5) + ", " + Number(modelData.lon).toFixed(5); color: root.muted; font.pixelSize: 11 }
                            Label { text: (modelData.depth === null ? "--" : Number(modelData.depth).toFixed(1) + " m") + " • " + (modelData.temp === null ? "--" : Number(modelData.temp).toFixed(1) + " °C"); color: root.muted; font.pixelSize: 11 }
                        }
                        Button { anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter; text: "ȘTERGE"; onClicked: { fishingSpots.removeSpot(modelData.id); scanCoordinator.checkpoint("fishing-spot-delete") } }
                    }
                }
            }
        }
    }

    Component {
        id: waypointEditorPage
        NavoWaypointEditor {
            anchors.fill: parent
            planController: root.planController
            vehicle: root.vehicle
            waypointNames: root.waypointNames
            onWaypointNameChanged: function(sequence, friendlyName) { persistence.setWaypointName(sequence, friendlyName) }
        }
    }

    Component {
        id: lakesPage
        Item {
            Rectangle { anchors.fill: parent; radius: 8; color: root.panel; border.color: root.line }
            ColumnLayout {
                anchors.fill: parent; anchors.margins: 16; spacing: 10
                Label { text: "BALȚILE MELE"; color: root.text; font.pixelSize: 20; font.bold: true }
                Label { text: persistence.lakes.length + " bălți salvate • sonar + puncte + Area Scan + Resume"; color: root.muted }
                Button { text: "DESCHIDE BĂLȚILE MELE"; onClicked: myLakesPopup.open() }
                Item { Layout.fillHeight: true }
            }
            NavoMyLakes {
                id: myLakesPopup
                persistence: persistence
                scanCoordinator: scanCoordinator
                onLakeRestored: function(lakeId) {
                    root.activePage = 2
                    root.lastNavigationStatus = "Balta restaurată • pregătită pentru Resume"
                }
            }
        }
    }

    Component {
        id: baitingPage
        Item {
            NavoBaitingPanel {
                anchors.centerIn: parent
                controller: baitingController
                waypoint: baitingController.targetWaypoint
                onStartConfirmed: function(waypoint, name, hopper) { baitingController.startCycle(waypoint,name,hopper) }
                onAbortRequested: baitingController.abortCycle("Oprit de utilizator")
            }
        }
    }

    Component {
        id: bathymetryPage
        Item {
            NavoBathymetry3D {
                anchors.fill: parent
                samples: persistence.sonarSamples
                boatTrack: sonarMapping.trackCoordinates
                fishingSpots: fishingSpots.fishingSpots
                fishDetections: root.fishDetections
            }
        }
    }

    Component {
        id: cameraPage
        Item {
            Rectangle { anchors.fill: parent; radius: 8; color: "#05080c"; border.color: root.line }
            ColumnLayout {
                anchors.fill: parent; anchors.margins: 12
                Label { text: "CAMERA ETHERNET"; color: root.text; font.pixelSize: 18; font.bold: true }
                NavoCameraPip {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    connected: root.cameraStreamUrl.length > 0
                    streamUrl: root.cameraStreamUrl
                    protocol: root.cameraProtocol
                    onFullscreenRequested: root.cameraFullscreen = true
                }
            }
        }
    }

    Component {
        id: settingsPage
        Item {
            Rectangle { anchors.fill: parent; radius: 8; color: root.panel; border.color: root.line }
            NavoEthernetSettings {
                id: ethernetSettings
                anchors.fill: parent; anchors.margins: 12
                sonar: sonar
                onCameraStreamUrlChanged: root.cameraStreamUrl = cameraStreamUrl
                onCameraProtocolChanged: root.cameraProtocol = cameraProtocol
                onStatus: function(text) { root.lastNavigationStatus=text }
            }
        }
    }

    Loader {
        anchors.fill: parent
        z: 1000
        active: root.cameraFullscreen
        sourceComponent: Component {
            NavoCameraFullScreen {
                streamUrl: root.cameraStreamUrl
                protocol: root.cameraProtocol
                onClosed: root.cameraFullscreen = false
            }
        }
    }

    Rectangle {
        id: footer
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        height: 34; color: "#0d141d"; border.color: root.line
        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
            Label { text: vehicle ? "MAVLink conectat" : "Astept conexiunea ArduPilot"; color: vehicle ? root.ok : root.warn }
            Item { Layout.fillWidth: true }
            Label { text: "NAVO SMART"; color: root.muted }
        }
    }

    component StatusPill: Rectangle {
        property string title: ""
        property string value: "--"
        property bool good: false
        Layout.preferredWidth: 100; Layout.preferredHeight: 42; radius: 7
        color: root.panel; border.color: good ? root.ok : root.line
        Column {
            anchors.centerIn: parent; spacing: 0
            Label { anchors.horizontalCenter: parent.horizontalCenter; text: title; color: root.muted; font.pixelSize: 9 }
            Label { anchors.horizontalCenter: parent.horizontalCenter; text: value; color: good ? root.ok : root.text; font.pixelSize: 12; font.bold: true }
        }
    }

    component NavButton: Button {
        property bool active: false
        Layout.fillWidth: true; Layout.preferredHeight: 40
        background: Rectangle { radius: 6; color: parent.active ? "#183248" : "transparent"; border.color: parent.active ? root.accent : "transparent" }
        contentItem: Label { text: parent.text; color: parent.active ? root.accent : root.text; verticalAlignment: Text.AlignVCenter; leftPadding: 8; font.bold: parent.active }
    }

    component DataLine: RowLayout {
        property string name: ""
        property string value: "--"
        property color valueColor: root.text
        Layout.fillWidth: true
        Label { text: parent.name; color: root.muted }
        Item { Layout.fillWidth: true }
        Label { text: parent.value; color: parent.valueColor; font.bold: true }
    }
}
