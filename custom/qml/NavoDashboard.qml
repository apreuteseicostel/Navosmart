import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtPositioning
import QtCore

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
    property alias lakePersistence: persistence
    NavoFishingSpots { id: fishingSpots; onSpotSaved: scanCoordinator.checkpoint("spot-save"); onSpotRemoved: scanCoordinator.checkpoint("spot-delete") }
    NavoFishDetections { id: fishStore }
    NavoBathymetryModel { id: bathymetryModel }
    Settings {
        id: sessionSettings
        category: "NavoSession"
        property string activeLakeId: ""
    }
    Settings {
        id: endpointSettings
        category: "NavoEthernet"
        property string sonarHost: ""
        property int sonarPort: 0
        property bool sonarUdp: false
        property string cameraStreamUrl: ""
        property string cameraProtocol: "auto"
    }
    Settings {
        id: hopperSettings
        category: "NavoHopperCalibration"
        property bool confirmed: false
        property int leftOutput: 9
        property int rightOutput: 10
        property int leftClosed: 1500
        property int leftOpen: 1900
        property int rightClosed: 1500
        property int rightOpen: 1900
    }
    Component.onCompleted: {
        sonar.host=endpointSettings.sonarHost; sonar.port=endpointSettings.sonarPort; sonar.udp=endpointSettings.sonarUdp
        root.cameraStreamUrl=endpointSettings.cameraStreamUrl; root.cameraProtocol=endpointSettings.cameraProtocol
        for(var i=0;i<persistence.lakes.length;i++) {
            var lake=persistence.lakes[i]
            if(lake.id===sessionSettings.activeLakeId) { scanCoordinator.activateLake(lake.id,lake.name); break }
        }
    }
    NavoAreaScan { id: areaScanController }
    NavoBaitingController {
        id: baitingController
        vehicle: root.vehicle
        onGotoRequested: function(coordinate, reason) { if(root.vehicle && root.vehicle.guidedModeGotoLocation) root.vehicle.guidedModeGotoLocation(coordinate) }
        onSpeedRequested: function(metersPerSecond) {
            if(root.vehicle && root.vehicle.guidedModeChangeGroundSpeedMetersSecond)
                root.vehicle.guidedModeChangeGroundSpeedMetersSecond(metersPerSecond)
        }
        onStopRequested: function(reason) { root.holdMission(true); root.lastNavigationStatus="Nădire: "+reason }
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
        onHoldRequested: function(reason) {
            root.lastNavigationStatus="FAILSAFE HOLD: "+reason
            if (scanCoordinator.state === "SCANNING") scanCoordinator.pause(reason)
            root.holdMission()
        }
        onRtlRequested: function(reason) {
            root.lastNavigationStatus="FAILSAFE RTL: "+reason
            if (scanCoordinator.state === "SCANNING" || scanCoordinator.state === "PAUSED" || scanCoordinator.state === "RESUME_READY") scanCoordinator.rtl(reason)
            root.rtlMission()
        }
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
        fishStore: fishStore
        bathymetry: bathymetryModel
        sonarMapping: sonarMapping
        vehicle: root.vehicle
        onMissionPrepared: function(points) {
            if (!missionUploader.prepare(points)) {
                scanCoordinator.state = "ERROR"
                root.lastNavigationStatus = "Pregătire misiune eșuată: " + missionUploader.lastError
            }
        }
        onStatus: function(message) { root.lastNavigationStatus = message }
        onLakeActivated: function(id) { sessionSettings.activeLakeId=id; missionUploader.invalidate(); baitingController.targetWaypoint=null }
    }
    property alias areaCoordinator: scanCoordinator
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
                root.lastNavigationStatus = "Autopilot confirmă " + root.vehicle.flightMode + " • misiune activă"
            if (root.awaitingMissionStart && expected.length && actual === expected && scanCoordinator.state === "READY")
                scanCoordinator.start()
            else if (root.awaitingMissionStart && expected.length && actual === expected && scanCoordinator.state === "RESUME_READY")
                scanCoordinator.activateResume()
            if (root.awaitingMissionStart && expected.length && actual === expected)
                root.awaitingMissionStart = false
        }
    }

    NavoMissionUploader {
        id: missionUploader
        planController: root.planController
        vehicle: root.vehicle
        onStatus: function(message) { root.lastNavigationStatus = message }
        onMissionItemReached: function(sequence) {
            scanCoordinator.missionItemReached(sequence)
        }
        onUploadFinished: function(success, message) {
            root.lastNavigationStatus = message
            if (!success) root.awaitingMissionStart = false
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
    property bool awaitingMissionStart: false
    onVehicleChanged: { awaitingMissionStart=false; if(baitingController && baitingController.enabled) baitingController.abortCycle("Autopilot schimbat"); if(scanCoordinator && scanCoordinator.state==="SCANNING") scanCoordinator.pause("Autopilot schimbat") }
    property string pendingMode: ""
    property string pendingModeLabel: ""
    Timer {
        interval: 10000; running: root.pendingMode.length>0; repeat: false
        onTriggered: { root.lastNavigationStatus=root.pendingModeLabel+" fără confirmare autopilot"; root.pendingMode="" }
    }
    onFlightModeChanged: {
        if(pendingMode.length && flightMode.toUpperCase()===pendingMode.toUpperCase()) {
            lastNavigationStatus="Autopilot confirmă "+pendingModeLabel; pendingMode=""
        }
        if(scanCoordinator.state==="SCANNING" && vehicle && flightMode!==vehicle.missionFlightMode) scanCoordinator.pause("Autopilotul a părăsit AUTO")
    }
    readonly property bool linkAlive: !!vehicle && !!vehicle.vehicleLinkManager && !vehicle.vehicleLinkManager.communicationLost
    Timer {
        interval: 10000
        running: root.awaitingMissionStart
        repeat: false
        onTriggered: {
            root.awaitingMissionStart = false
            root.lastNavigationStatus = "START AUTOPILOT trimis, dar modul AUTO nu a fost confirmat de autopilot"
        }
    }
    property string flightMode: vehicle ? vehicle.flightMode : ""
    property real distanceToHome: vehicle && vehicle.distanceToHome ? vehicle.distanceToHome.rawValue : 0
    property real distanceToTarget: vehicle && vehicle.distanceToGoal ? vehicle.distanceToGoal.rawValue : 0
    property string boatId: "NAV0001"
    property int activePage: 0
    property bool hopperStatusExpanded: false
    property bool mapFullscreen: false
    property var mapController: null
    property string pendingAreaDrawMode: "none"
    property string lakeSaveStatus: ""
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

    function coordinatesFromSonarSamples(samples) {
        var out=[]
        if(!samples) return out
        for(var i=0;i<samples.length;i++) {
            var s=samples[i]
            if(s && s.lat!==undefined && s.lon!==undefined)
                out.push(QtPositioning.coordinate(Number(s.lat), Number(s.lon)))
        }
        return out
    }


    NavoCameraEthernet {
        id: cameraEthernet
    }

    NavoSonarEthernet {
        id: sonar
        vehicle: root.vehicle
        onGeoSample: function(sample) {
            persistence.addSonarSample(sample)
            sonarMapping.ingestSample(sample)
        }
    }
    property bool sonarLossHandled: false
    Timer {
        id: sonarSafetyTimer
        interval: 1000
        repeat: true
        running: scanCoordinator.state === "SCANNING"
        onTriggered: {
            if (root.sonarConnected) {
                root.sonarLossHandled = false
                return
            }
            if (root.sonarLossHandled) return
            root.sonarLossHandled = true
            scanCoordinator.pause("Sonar Kogger fără date live")
            root.holdMission()
            root.lastNavigationStatus = "SONAR PIERDUT • Area Scan salvat • HOLD"
        }
    }
    Connections {
        target: scanCoordinator
        function onStateChanged() {
            if (scanCoordinator.state !== "SCANNING") root.sonarLossHandled = false
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
        calibrated: hopperSettings.confirmed && hopperSettings.leftOutput!==hopperSettings.rightOutput && root.linkAlive && nanoTelemetry.connected
        leftServoOutput: hopperSettings.leftOutput
        rightServoOutput: hopperSettings.rightOutput
        leftClosedPwm: hopperSettings.leftClosed
        leftOpenPwm: hopperSettings.leftOpen
        rightClosedPwm: hopperSettings.rightClosed
        rightOpenPwm: hopperSettings.rightOpen
        onCommandSent: function(message) { root.lastNavigationStatus = message }
        onCommandRejected: function(reason) { root.lastNavigationStatus = "Cuve: " + reason }
    }
    NavoSafetyManager {
        id: safetyManager
        vehicle: root.vehicle
        telemetryLive: nanoTelemetry.connected
        waterSensorFault: nanoTelemetry.waterSensorFault
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
            root.lastNavigationStatus = "START blocat: autopilot neconectat"
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
        if (!root.linkAlive || !root.vehicle.rover) {
            root.lastNavigationStatus = "Upload confirmat, dar autopilotul nu mai este conectat"
            return false
        }
        if (root.awaitingMissionStart) return false
        if(root.vehicle.flightMode===root.vehicle.missionFlightMode) {root.lastNavigationStatus="Treci în HOLD înainte de pornirea unei misiuni noi";return false}
        if(!missionUploader.uploadVerified || (scanCoordinator.state!=="READY" && scanCoordinator.state!=="RESUME_READY")) { root.lastNavigationStatus="Pregătește și încarcă misiunea înainte de START"; return false }
        if(!scanCoordinator.lakeId.length) { root.lastNavigationStatus="Selectează o baltă pentru salvarea scanării"; return false }
        if (!root.vehicle.coordinate || !root.vehicle.coordinate.isValid || !root.vehicle.gps || root.vehicle.gps.lock.rawValue<3) {
            root.lastNavigationStatus = "START blocat: GPS autopilot indisponibil"
            return false
        }
        if ((scanCoordinator.state === "READY" || scanCoordinator.state === "RESUME_READY") && !root.sonarConnected) {
            root.lastNavigationStatus = "START Area Scan blocat: sonar fără date live"
            return false
        }
        // QGC Vehicle::startMission() is the normal MAVLink mission-start path.
        // Never report AUTO before the vehicle reports the resulting mode.
        if (root.vehicle.startMission) {
            root.awaitingMissionStart = true
            root.vehicle.startMission()
            root.lastNavigationStatus = "Upload confirmat • comandă START AUTOPILOT trimisă"
            return true
        }
        root.lastNavigationStatus = "Upload confirmat • START indisponibil în Vehicle API"
        return false
    }
    function holdMission(keepBaiting) {
        root.awaitingMissionStart = false
        if(!keepBaiting && baitingController.enabled) baitingController.abortCycle("HOLD utilizator")
        digitalAnchor.release()
        if(scanCoordinator.state==="SCANNING") scanCoordinator.pause("HOLD utilizator")
        if (!vehicle || !vehicle.pauseVehicle) { root.lastNavigationStatus = "HOLD indisponibil: autopilot deconectat"; return false }
        vehicle.pauseVehicle()
        root.pendingMode=vehicle.pauseFlightMode; root.pendingModeLabel="HOLD"
        root.lastNavigationStatus = "Comandă HOLD trimisă • aștept confirmarea autopilotului"
        return true
    }
    function rtlMission() {
        root.awaitingMissionStart = false
        digitalAnchor.release()
        if(baitingController.enabled) baitingController.abortCycle("RTL solicitat")
        if(scanCoordinator.state==="SCANNING" || scanCoordinator.state==="PAUSED") scanCoordinator.rtl("RTL utilizator")
        if (!vehicle || !vehicle.guidedModeRTL) { root.lastNavigationStatus = "RTL indisponibil: autopilot deconectat"; return false }
        vehicle.guidedModeRTL(false)
        root.pendingMode=vehicle.rtlFlightMode; root.pendingModeLabel="RTL"
        root.lastNavigationStatus = "Comandă RTL trimisă • aștept confirmarea autopilotului"
        return true
    }
    function stopMission() {
        root.awaitingMissionStart = false
        if(baitingController.enabled) baitingController.abortCycle("STOP utilizator")
        digitalAnchor.release()
        if(scanCoordinator.state==="SCANNING") scanCoordinator.pause("STOP utilizator")
        missionUploader.invalidate()
        if (!vehicle || !vehicle.pauseVehicle) { root.lastNavigationStatus = "STOP indisponibil: autopilot deconectat"; return false }
        vehicle.pauseVehicle()
        root.pendingMode=vehicle.pauseFlightMode; root.pendingModeLabel="STOP (HOLD)"
        root.lastNavigationStatus = "Comandă STOP/HOLD trimisă • aștept confirmarea autopilotului"
        return true
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
        Flickable {
            anchors.fill: parent
            clip: true
            contentWidth: Math.max(width, headerItems.implicitWidth + 32)
            contentHeight: height
            boundsBehavior: Flickable.StopAtBounds
        RowLayout {
            id: headerItems
            x: 16; height: parent.height; spacing: 12
            ColumnLayout {
                Layout.preferredWidth: 150
                spacing: 0
                Label { text: "NAVO SMART"; color: root.text; font.pixelSize: 22; font.bold: true }
                Label { text: "Pescarul lu Peste"; color: root.muted; font.pixelSize: 11 }
            }
            StatusPill { title: "SATELIȚI"; value: vehicle && vehicle.gps ? String(vehicle.gps.count.rawValue) : "--"; good: vehicle && vehicle.gps }
            StatusPill { title: "VITEZĂ"; value: vehicle && vehicle.groundSpeed ? Number(vehicle.groundSpeed.rawValue * 3.6).toFixed(1) + " km/h" : "--"; good: !!vehicle }
            StatusPill { title: "BATERIE"; value: battery ? Number(battery.percentRemaining.rawValue).toFixed(0) + "%" : "--"; good: battery && battery.percentRemaining.rawValue > 20 }
            StatusPill { title: "MOD"; value: root.flightMode.length ? root.flightMode : "OFFLINE"; good: vehicle !== null }
            StatusPill { title: "SONAR"; value: root.sonarConnected ? "LIVE" : "OFFLINE"; good: root.sonarConnected }
            StatusPill { title: "NANO"; value: nanoTelemetry.connected ? "ONLINE" : "OFFLINE"; good: nanoTelemetry.connected }
        }
        }
    }

    Rectangle {
        id: sidebar
        anchors.left: parent.left; anchors.top: header.bottom; anchors.bottom: footer.top
        width: root.width < 1100 ? 150 : 190; color: root.panel; border.color: root.line
        Flickable {
            anchors.fill: parent
            anchors.margins: 8
            clip: true
            contentWidth: width
            contentHeight: navColumn.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: navColumn.implicitHeight > sidebar.height - 16 ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff }
            ColumnLayout {
                id: navColumn
                width: parent.width
                spacing: Math.max(3, Math.min(8, (sidebar.height - 44 - 10 * 36) / 11))
                Label { text: navColumn.implicitHeight > sidebar.height - 16 ? "NAVIGAȚIE ↓" : "NAVIGAȚIE"; color: root.muted; font.bold: true; font.pixelSize: 13 }
                NavButton { text: "HARTA"; active: root.activePage === 0; onClicked: root.activePage = 0 }
                NavButton { text: "SONAR"; active: root.activePage === 1; onClicked: root.activePage = 1 }
                NavButton { text: "AREA SCAN"; active: root.activePage === 2; onClicked: root.activePage = 2 }
                NavButton { text: "PUNCTE PESCUIT"; active: root.activePage === 3; onClicked: root.activePage = 3 }
                NavButton { text: "BALȚILE MELE"; active: root.activePage === 4; onClicked: root.activePage = 4 }
                NavButton { text: "CAMERA"; active: root.activePage === 5; onClicked: root.activePage = 5 }
                NavButton { text: "3D"; active: root.activePage === 7; onClicked: root.activePage = 7 }
                NavButton { text: "NĂDIRE"; active: root.activePage === 8; onClicked: root.activePage = 8 }
                NavButton { text: "SIGURANȚĂ"; active: root.activePage === 9; onClicked: root.activePage = 9 }
                NavButton { text: "SETARI"; active: root.activePage === 6; onClicked: root.activePage = 6 }
                Label { text: "BARCA " + root.boatId; color: root.muted; font.pixelSize: 10; Layout.topMargin: 2 }
            }
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
                             root.activePage === 8 ? baitingPage :
                             root.activePage === 9 ? failsafePage : settingsPage
        }
    }

    Rectangle {
        id: rightPanel
        anchors.right: parent.right; anchors.top: header.bottom; anchors.bottom: footer.top
        width: root.width < 1100 ? 220 : 260; color: root.panel; border.color: root.line
        Flickable {
            anchors.fill: parent
            clip: true
            contentWidth: width
            contentHeight: statusColumn.implicitHeight + 24
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        ColumnLayout {
            id: statusColumn
            x: 12; y: 12; width: parent.width - 24; spacing: 10
            Label { text: "STATUS BARCA"; color: root.text; font.bold: true }
            NavoEthernetIndicator {
                Layout.fillWidth: true
                sonarConnected: sonar.connected
                sonarAlive: sonar.dataAlive
                cameraConnected: root.cameraConnected
                cameraAlive: root.cameraConnected
                sonarStatus: sonar.status
                cameraStatus: root.cameraConnected ? "Flux video LIVE" : (root.cameraStreamUrl.length ? "URL configurat; flux inactiv" : "OFFLINE")
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
                Layout.preferredHeight: 170
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
            Label { text: "CONTROL MISIUNE"; color: root.muted; font.bold: true }
            RowLayout {
                Layout.fillWidth: true
                Button { Layout.fillWidth: true; text: missionUploader.uploadVerified ? "START AUTOPILOT" : "UPLOAD"; onClicked: root.startMission() }
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
    }

    Component {
        id: mapPage
        Item {
            Rectangle { anchors.fill: parent; radius: 8; color: root.panel; border.color: root.line }
            NavoMap {
                id: navoMap
                anchors.fill: parent; anchors.margins: 8
                Component.onCompleted: {
                    root.mapController = navoMap
                    if (root.pendingAreaDrawMode === "rectangle") navoMap.beginAreaRectangle()
                    else if (root.pendingAreaDrawMode === "polygon") navoMap.beginAreaPolygon()
                    root.pendingAreaDrawMode = "none"
                }
                Component.onDestruction: if(root.mapController===navoMap) root.mapController=null
                vehicle: root.vehicle
                planController: root.planController
                onWaypointNameChanged: function(sequence,name) { persistence.setWaypointName(sequence,name) }
                waypointNames: root.waypointNames
                fishModel: fishStore
                fishingSpotsModel: fishingSpots
                bathymetryCells: scanCoordinator.bathymetryCells
                baitingController: baitingController
                areaScanController: areaScanController
                savedDepthM: root.depthM
                savedWaterTempC: root.waterTempC
                onNavigateRequested: function(coordinate) { root.navigateToCoordinate(coordinate) }
                onBaitingWaypointSelected: function(waypoint) {
                    root.lastNavigationStatus="Punct selectat: " + (waypoint.sequenceNumber !== undefined ? "WP" + waypoint.sequenceNumber : "waypoint") + " • poți deschide NĂDIRE când dorești"
                }
                onAreaRectangleRequested: function(cornerA, cornerB) {
                    missionUploader.invalidate()
                    var pts=scanCoordinator.prepareRectangle(cornerA,cornerB)
                    root.lastNavigationStatus=pts.length ? "Area Scan dreptunghi • "+areaScanController.laneCount()+" culoare • "+pts.length+" WP generate" : areaScanController.lastError
                    root.pendingAreaDrawMode="none"
                    root.activePage=2
                }
                onAreaPolygonRequested: function(polygon) {
                    missionUploader.invalidate()
                    var pts=scanCoordinator.preparePolygon(polygon)
                    root.lastNavigationStatus=pts.length ? "Area Scan poligon • "+areaScanController.laneCount()+" culoare • "+pts.length+" WP generate" : areaScanController.lastError
                    root.pendingAreaDrawMode="none"
                    root.activePage=2
                }
                onSavePointRequested: function(coordinate) {
                    if(!scanCoordinator.lakeId.length) {root.lastNavigationStatus="Selectează o baltă înainte de salvare";return}
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
                    echoSamples: sonar.echoSamples
                    onOpenFullSonar: fullSonar.open()
                }
                Label {
                    Layout.fillWidth: true
                    text: root.sonarConnected ? "Sonar conectat • atinge ⛶ pentru ecogramă" : "Kogger offline • atinge ⛶ pentru ecogramă și conexiune"
                    color: root.muted
                    wrapMode: Text.WordWrap
                }
                Item { Layout.fillHeight: true }
            }
            NavoSonarFullScreen {
                    id: fullSonar
                    parent: Overlay.overlay
                    connected: root.sonarConnected; depthM: root.depthM; waterTempC: root.waterTempC
                    echoSamples: sonar.echoSamples
                    transport: sonar
                    fishHotspots: fishStore.hotspots
                    speedMps: root.vehicle && root.vehicle.groundSpeed ? root.vehicle.groundSpeed.rawValue : NaN
                    latitude: root.vehicle && root.vehicle.coordinate && root.vehicle.coordinate.isValid ? root.vehicle.coordinate.latitude : NaN
                    longitude: root.vehicle && root.vehicle.coordinate && root.vehicle.coordinate.isValid ? root.vehicle.coordinate.longitude : NaN
                    onSaveWaypointRequested: function(latitude, longitude, depth, temp) {
                        if(!scanCoordinator.lakeId.length) {root.lastNavigationStatus="Selectează o baltă înainte de salvare";return}
                        var spot=fishingSpots.saveSpot(QtPositioning.coordinate(latitude,longitude),depth,temp,"","",null)
                        if(spot){scanCoordinator.checkpoint("sonar-fishing-spot");root.lastNavigationStatus="Punct sonar salvat: "+spot.name}
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
                          (areaScanController.completedLanes.length + " / " + areaScanController.laneCount() + " culoare • WP autopilot " + scanCoordinator.missionCurrentIndex) :
                          "Definește zona de scanare pe hartă."
                    color: root.muted
                }
                Flow {
                    Layout.fillWidth: true
                    spacing: 6
                    Button {
                        text: "DREPTUNGHI PE HARTĂ"
                        enabled: scanCoordinator.state!=="SCANNING" && !missionUploader.uploadInProgress
                        onClicked: {
                            root.pendingAreaDrawMode="rectangle"
                            root.activePage=0
                            root.lastNavigationStatus="Atinge două colțuri pe hartă pentru dreptunghi"
                        }
                    }
                    Button {
                        text: "POLIGON PE HARTĂ"
                        enabled: scanCoordinator.state!=="SCANNING" && !missionUploader.uploadInProgress
                        onClicked: {
                            root.pendingAreaDrawMode="polygon"
                            root.activePage=0
                            root.lastNavigationStatus="Atinge cel puțin trei puncte și apoi TERMINĂ"
                        }
                    }
                    Button {
                        text: "PREGĂTEȘTE MISIUNEA"
                        enabled: areaScanController.generatedPoints.length > 0 && scanCoordinator.state!=="SCANNING" && !missionUploader.uploadInProgress
                        onClicked: {
                            missionUploader.invalidate()
                            var prepared=scanCoordinator.prepareMission(false)
                            if(prepared && prepared.length)
                                root.lastNavigationStatus="Misiune pregătită • "+prepared.length+" WP • următorul pas: UPLOAD"
                            else if(!root.lastNavigationStatus.length)
                                root.lastNavigationStatus="Pregătirea misiunii a eșuat"
                        }
                    }
                    Button {
                        text: missionUploader.uploadInProgress ? "UPLOAD…" : (missionUploader.uploadVerified ? "START AUTOPILOT" : "UPLOAD")
                        enabled: missionUploader.preparedCount > 0 && !missionUploader.uploadInProgress
                        onClicked: root.startMission()
                    }
                    Button {
                        text: "RESUME"
                        enabled: scanCoordinator.state==="PAUSED" && !missionUploader.uploadInProgress && areaScanController.generatedPoints.length > 0 && areaScanController.completedLanes.length < areaScanController.laneCount()
                        onClicked: {
                            var mission = scanCoordinator.resume()
                            if (mission.length) root.lastNavigationStatus = "Resume pregătit • apasă UPLOAD și apoi START AUTOPILOT"
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
                        Label { anchors.horizontalCenter: parent.horizontalCenter; text: "Zona se definește din hartă; aici se controlează misiunea autopilotului."; color: root.muted }
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
                Label {
                    Layout.fillWidth: true
                    text: persistence.lakes.length + " bălți salvate • sonar + puncte + Area Scan + Resume"
                    color: root.muted
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
                RowLayout {
                    Layout.fillWidth: true
                    TextField { id: inlineLakeName; Layout.fillWidth: true; placeholderText: "Nume baltă nouă"; onAccepted: addLakeButton.clicked() }
                    Button {
                        id: addLakeButton
                        text: "+ ADAUGĂ"
                        enabled: inlineLakeName.text.trim().length > 0
                        onClicked: {
                            var name=inlineLakeName.text.trim()
                            var id=persistence.saveLake({name:name})
                            var found=false
                            for (var i=0;i<persistence.lakes.length;i++)
                                if (persistence.lakes[i].id===id) { found=true; break }
                            if (found) {
                                inlineLakeName.clear()
                                root.lakeSaveStatus="Salvată: "+name
                                // Make the new lake the active session immediately so
                                // subsequent sonar/spots/Area Scan checkpoints belong to it.
                                for (var j=0;j<persistence.lakes.length;j++) {
                                    if (persistence.lakes[j].id===id) {
                                        myLakesPopup.selectLake(persistence.lakes[j])
                                        break
                                    }
                                }
                                scanCoordinator.checkpoint("lake-created")
                            } else root.lakeSaveStatus="Salvarea a eșuat • încearcă din nou"
                        }
                    }
                }
                Label { Layout.fillWidth: true; visible: root.lakeSaveStatus.length>0; text: root.lakeSaveStatus; color: root.accent }
                ListView {
                    Layout.fillWidth: true; Layout.fillHeight: true; clip: true
                    model: persistence.lakes
                    delegate: Button {
                        required property var modelData
                        width: ListView.view.width
                        text: modelData.name || "Baltă"
                        onClicked: {
                            myLakesPopup.selectLake(modelData)
                            myLakesPopup.open()
                        }
                    }
                }
                Button { text: "DESCHIDE BĂLȚILE MELE"; onClicked: myLakesPopup.open() }
            }
            NavoMyLakes {
                id: myLakesPopup
                persistence: root.lakePersistence
                scanCoordinator: root.areaCoordinator
                onLakeRestored: function(lakeId) {
                    missionUploader.invalidate()
                    root.activePage = 2
                    root.lastNavigationStatus = "Balta restaurată • pregătită pentru Resume"
                }
            }
        }
    }

    Component {
        id: baitingPage
        Item {
            Rectangle { anchors.fill: parent; radius: 8; color: root.panel; border.color: root.line }
            NavoBaitingPanel {
                anchors.centerIn: parent
                controller: baitingController
                waypoint: baitingController.targetWaypoint
                availableSpots: fishingSpots.fishingSpots
                onChooseOnMapRequested: {
                    root.activePage = 0
                    root.lastNavigationStatus = "Selectează un waypoint pe hartă sau salvează un loc de pescuit, apoi revino la NĂDIRE"
                }
                onSpotChosen: function(spot) {
                    var coordinate = QtPositioning.coordinate(Number(spot.lat), Number(spot.lon))
                    if (!coordinate.isValid) {
                        root.lastNavigationStatus = "Locul salvat nu are coordonate valide"
                        return
                    }
                    baitingController.targetWaypoint = {coordinate: coordinate, name: spot.name, sequenceNumber: 0}
                    root.lastNavigationStatus = "Punct de nădire ales: " + spot.name
                }
                onStartConfirmed: function(waypoint, name, hopper) {
                    if(!root.linkAlive || scanCoordinator.state==="SCANNING" || root.awaitingMissionStart || (hopper!==0 && !hopperBridge.calibrated)) { root.lastNavigationStatus="Nădire blocată: verifică legătura, misiunea activă și calibrarea cuvelor"; return }
                    digitalAnchor.release(); baitingController.startCycle(waypoint,name,hopper)
                }
                onAbortRequested: baitingController.abortCycle("Oprit de utilizator")
            }
        }
    }

    Component {
        id: failsafePage
        Item {
            Rectangle { anchors.fill: parent; radius: 8; color: root.panel; border.color: root.line }
            ColumnLayout {
                anchors.fill: parent; anchors.margins: 16; spacing: 12
                Label { text: "SIGURANȚĂ & FAILSAFE"; color: root.text; font.pixelSize: 20; font.bold: true }
                NavoFailsafePanel { Layout.fillWidth: true; controller: failsafeController }
                Label { Layout.fillWidth:true; wrapMode:Text.WordWrap; color:root.warn; text:"Cuve: confirmă ieșirile și PWM-urile pe banc înainte de activare. Telemetria PWM nu confirmă calibrarea mecanică." }
                GridLayout {
                    columns:3; Layout.fillWidth:true
                    Label { text:"Cuva"; color:root.text } Label { text:"Stânga"; color:root.text } Label { text:"Dreapta"; color:root.text }
                    Label { text:"Ieșire"; color:root.text }
                    SpinBox { from:1; to:16; value:hopperSettings.leftOutput; onValueModified:{hopperSettings.confirmed=false;hopperSettings.leftOutput=value} }
                    SpinBox { from:1; to:16; value:hopperSettings.rightOutput; onValueModified:{hopperSettings.confirmed=false;hopperSettings.rightOutput=value} }
                    Label { text:"Închis µs"; color:root.text }
                    SpinBox { from:900; to:2100; value:hopperSettings.leftClosed; onValueModified:{hopperSettings.confirmed=false;hopperSettings.leftClosed=value} }
                    SpinBox { from:900; to:2100; value:hopperSettings.rightClosed; onValueModified:{hopperSettings.confirmed=false;hopperSettings.rightClosed=value} }
                    Label { text:"Deschis µs"; color:root.text }
                    SpinBox { from:900; to:2100; value:hopperSettings.leftOpen; onValueModified:{hopperSettings.confirmed=false;hopperSettings.leftOpen=value} }
                    SpinBox { from:900; to:2100; value:hopperSettings.rightOpen; onValueModified:{hopperSettings.confirmed=false;hopperSettings.rightOpen=value} }
                }
                CheckBox { text:"Am verificat mecanic calibrarea cuvelor"; checked:hopperSettings.confirmed; enabled:!baitingController.enabled && !hopperBridge.commandPending; onToggled:hopperSettings.confirmed=checked }
                Item { Layout.fillHeight: true }
            }
        }
    }

    Component {
        id: bathymetryPage
        Item {
            NavoBathymetry3D {
                anchors.fill: parent
                // Use the active/restored lake session, not the global sonar history.
                // restoreLake() repopulates rawSamples from the selected lake checkpoint.
                samples: sonarMapping.rawSamples
                boatTrack: sonarMapping.trackCoordinates.length ? sonarMapping.trackCoordinates : root.coordinatesFromSonarSamples(sonarMapping.rawSamples)
                fishingSpots: fishingSpots.fishingSpots
                fishDetections: root.fishDetections
                onOpenSonarRequested: root.activePage = 1
            }
        }
    }

    Component {
        id: cameraPage
        Item {
            Rectangle { anchors.fill: parent; radius: 8; color: "#05080c"; border.color: root.line }
            ColumnLayout {
                anchors.fill: parent; anchors.margins: 12
                Label { text: "CAMERA FAȚĂ"; color: root.text; font.pixelSize: 18; font.bold: true }
                NavoCameraPip {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    connected: root.cameraStreamUrl.length > 0
                    streamUrl: root.cameraStreamUrl
                    protocol: root.cameraProtocol
                    onLiveChanged: root.cameraConnected = live
                    Component.onDestruction: root.cameraConnected = false
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
                camera: cameraEthernet
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
        Layout.fillWidth: true
        Layout.preferredHeight: Math.max(32, Math.min(40, (sidebar.height - 70) / 9))
        background: Rectangle { radius: 6; color: parent.active ? "#183248" : "transparent"; border.color: parent.active ? root.accent : "transparent" }
        contentItem: Label { text: parent.text; color: parent.active ? root.accent : root.text; verticalAlignment: Text.AlignVCenter; leftPadding: 8; font.pixelSize: Math.max(11, Math.min(14, parent.height * 0.36)); font.bold: parent.active; elide: Text.ElideRight }
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
