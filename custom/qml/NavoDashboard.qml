import QtQuick
// NAVO build validation trigger after QML syntax repairs
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
    readonly property string activePageName: ["HARTA","SONAR","MISIUNI","PUNCTE PESCUIT","BALȚILE MELE","CAMERA","SETARI","3D","NĂDIRE","SIGURANȚĂ","SONAR PRO"][activePage] || "HARTA"
    implicitWidth: 1280
    implicitHeight: 720

    // Compatibility with QGroundControl v5.0.7 MainWindow, which binds this
    // property on the FlyView root. NAVO does not currently use UTM/SP.
    property bool utmspSendActTrigger: false
    property bool mapMaximized: false
    readonly property bool compactUi: width < 1180 || height < 700
    readonly property int responsiveMargin: compactUi ? 7 : 12
    readonly property int responsiveGap: compactUi ? 5 : 8

    property var proBoatTrack: []
    Connections {
        target: root.vehicle
        function onCoordinateChanged() {
            if(!root.vehicle || !root.vehicle.coordinate || !root.vehicle.coordinate.isValid) return
            var c=root.vehicle.coordinate, points=root.proBoatTrack
            if(!points.length || points[points.length-1].distanceTo(c)>=1) {
                points=points.slice(-3999); points.push(c); root.proBoatTrack=points
            }
        }
    }
    property var vehicle: QGroundControl.multiVehicleManager.activeVehicle
    property var planController: _planController
    readonly property var mapBaitingController: baitingController
    readonly property var mapAreaScanController: areaScanController

    PlanMasterController {
        id: _planController
        flyView: true
        Component.onCompleted: start()
    }

    NavoPersistence { id: persistence }
    property alias lakePersistence: persistence
    property alias fishingSpotsController: fishingSpots
    property alias fishStoreController: fishStore
    property alias sonarMappingController: sonarMapping
    property alias hopperBridgeController: hopperBridge
    property alias sonarController: sonar
    property alias replayMappingController: replayMapping
    function saveRecordedReplayLake(name) {
        replayBathymetryModel.rebuild(replayMapping.rawSamples)
        var id=persistence.saveReplayLake(name,replayMapping.rawSamples,replayBathymetryModel.cells,sonar.nativeSurfaceMesh)
        root.replaySaveStatus=id ? "Salvat în Bălțile mele: "+name : "Salvarea a eșuat; sunt necesare probe GPS și fund valid."
        return id
    }
    Loader {
        active: typeof navoAcceptance!=="undefined" && navoAcceptance!==null && navoAcceptance.active
        sourceComponent: Component { NavoAndroidAcceptance { dashboard:root; backend:navoAcceptance } }
    }
    Connections {
        target: sonar.nativeBridge
        function onNativeSurfaceChanged() {
            var mesh=sonar.nativeSurfaceMesh
            if(!sonar.replayMode && scanCoordinator.lakeId.length && mesh && mesh.indices && mesh.indices.length)
                scanCoordinator.nativeSurfaceMesh=mesh
        }
    }
    NavoFishingSpots { id: fishingSpots; onSpotSaved: scanCoordinator.checkpoint("spot-save"); onSpotRemoved: scanCoordinator.checkpoint("spot-delete"); onSpotUpdated: scanCoordinator.checkpoint("spot-update") }
    NavoFishDetections { id: fishStore }
    NavoBathymetryModel { id: bathymetryModel }
    property string replaySaveStatus: ""
    NavoBathymetryModel { id: replayBathymetryModel }
    NavoSonarMapping { id: replayMapping; visible:false; externalSampleIngestion:true; sonarConnected:true; scanning:true }
    readonly property var displayNativeSurfaceMesh: sonar.replayMode ? sonar.nativeSurfaceMesh : scanCoordinator.nativeSurfaceMesh
    readonly property var displayBathymetryCells: sonar.replayMode ? replayBathymetryModel.cells : scanCoordinator.bathymetryCells
    Timer {
        interval:2000; repeat:true; running:sonar.replayMode
        onTriggered: if(replayMapping.rawSamples.length>=3)replayBathymetryModel.rebuild(replayMapping.rawSamples)
    }
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
        property bool connectOnStartup: true
        property string cameraStreamUrl: ""
        property string cameraProtocol: "auto"
    }
    Settings {
        id: lightSettings
        category: "NavoLights"
        property string positionMode: "AUTO"
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
        if(endpointSettings.connectOnStartup && sonar.host.length && sonar.port>0) sonar.connectSonar()
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
        onCycleFinished: function(success, message) {
            root.lastNavigationStatus=message
            if(routePlan.active) routePlan.stepFinished(success,message)
        }
    }
    readonly property var routePlanController:routePlan
    property bool routePreviousRtl: true
    property real routeLegDistanceM: 0
    property bool missionScanSelected: true
    property real scanEstimateSpeedMps: 1.5
    readonly property bool missionBusy: routePlan.active || baitingController.enabled || scanCoordinator.state==="SCANNING" || root.awaitingMissionStart || missionUploader.uploadInProgress
    readonly property var scanEstimate: {
        var points=areaScanController.generatedPoints
        var origin=root.vehicle ? root.vehicle.coordinate : null
        var home=root.vehicle ? root.vehicle.homePosition : null
        if(!points.length || !origin || !origin.isValid || !home || !home.isValid || !isFinite(root.scanEstimateSpeedMps) || root.scanEstimateSpeedMps<=0)return {valid:false}
        var d=0,prev=origin
        for(var i=0;i<points.length;i++){d+=prev.distanceTo(points[i]);prev=points[i]}
        if(root.areaScanFinishAction==="RTL")d+=prev.distanceTo(home)
        return {valid:isFinite(d),distanceM:d,durationSeconds:d/root.scanEstimateSpeedMps}
    }
    function missionStateLabel(state) {
        var labels={DRAFT:"Schiță",RUNNING:"În curs",DISPATCHED:"Acțiuni comandate",STOPPED:"Oprit",IDLE:"Pregătit",READY:"Pregătit pentru START",RESUME_READY:"Reluare pregătită",SCANNING:"În curs",PAUSED:"Pauză",RTL:"Întoarcere HOME comandată",COMPLETE:"Încheiată"}
        return labels[state] || state
    }
    function selectMission(index) {
        if(root.missionBusy || sonar.replayMode || !Number.isInteger(index) || index<0 || index>2)return false
        if(index!==2 && !routePlan.selectKind(index===0 ? "point" : "route"))return false
        root.missionScanSelected=index===2
        root.pendingBaitPointPick=false
        root.pendingAreaDrawMode="none"
        return true
    }
    NavoRoutePlan {
        id:routePlan
        readOnly:root.sonarController.replayMode
        onActiveChanged:if(!active) baitingController.rtlAfterDrop=root.routePreviousRtl
        onChanged:if(!root.sonarController.replayMode)scanCoordinator.checkpoint("route-edit")
        onStatus:function(text){root.lastNavigationStatus=text}
        onStepRequested:function(stop){
            if(!root.startRouteStop(stop)) routePlan.cancel(root.lastNavigationStatus)
        }
        onFinishRequested:function(action){root.finishRoute(action)}
    }
    readonly property var routeEstimate: routePlan.estimate(root.vehicle ? root.vehicle.coordinate : null,
                                                           root.vehicle ? root.vehicle.homePosition : null, baitingController)
    readonly property string routeEnergyText: root.routeEstimate.valid
        ? energyGuard.message(root.routeEstimate.energyDistanceM,root.battery && root.battery.percentRemaining ? Number(root.battery.percentRemaining.rawValue) : NaN) : ""
    NavoSteeringAssist {
        id:steeringAssist
        vehicle:root.vehicle
        readOnly:sonar.replayMode
        operationsBusy:root.missionBusy || digitalAnchor.active
        preLaunchReady:preLaunchCheck.navigationReady
        onStatus:function(text){root.lastNavigationStatus=text}
    }
    readonly property bool steeringModeBusy:steeringAssist.busy
    NavoDigitalAnchor {
        id: digitalAnchor
        vehicle: root.vehicle
        onStatus: function(text) { root.lastNavigationStatus=text }
    }
    NavoEnergyGuard { id: energyGuard }
    NavoPreLaunchCheck {
        id: preLaunchCheck
        vehicleConnected: root.linkAlive
        gpsReady: !!root.vehicle && !!root.vehicle.gps && Number(root.vehicle.gps.lock.rawValue) >= 3 && !!root.vehicle.coordinate && root.vehicle.coordinate.isValid
        homeReady: !!root.vehicle && !!root.vehicle.homePosition && root.vehicle.homePosition.isValid
        batteryReady: !!root.battery && !!root.battery.percentRemaining && isFinite(Number(root.battery.percentRemaining.rawValue)) && Number(root.battery.percentRemaining.rawValue) > 20
        nanoReady: nanoTelemetry.connected
        sonarReady: root.sonarConnected
        cameraReady: root.cameraConnected
        hoppersReady: hopperSettings.confirmed && hopperSettings.leftOutput !== hopperSettings.rightOutput
    }
    Settings {
        id: energySettings
        category:"NavoEnergy"
        property bool confirmed:false
        property real reservePercent:25
        property real consumptionPercentPerKm:12
    }
    Binding { target:energyGuard;property:"calibrated";value:energySettings.confirmed }
    Binding { target:energyGuard;property:"reservePercent";value:energySettings.reservePercent }
    Binding { target:energyGuard;property:"consumptionPercentPerKm";value:energySettings.consumptionPercentPerKm }
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
        bottomHardness: root.bottomHardnessPercent
        bottomEchoStrength: root.bottomEchoStrength
        onCheckpointRequested: function(state) { scanCoordinator.checkpoint("sonar-mapping") }
    }
    NavoScanCoordinator {
        id: scanCoordinator
        readOnlyReplay: root.sonarController.replayMode
        routePlan: root.routePlanController
        areaScan: areaScanController
        persistence: root.lakePersistence
        fishingSpots: root.fishingSpotsController
        fishStore: root.fishStoreController
        bathymetry: bathymetryModel
        sonarMapping: root.sonarMappingController
        vehicle: root.vehicle
        onMissionPrepared: function(points) {
            if (!missionUploader.prepare(points)) {
                scanCoordinator.state = "ERROR"
                root.lastNavigationStatus = "Pregătire misiune eșuată: " + missionUploader.lastError
            }
        }
        onStatus: function(message) { root.lastNavigationStatus = message }
        onLakeActivated: function(id) { sessionSettings.activeLakeId=id; missionUploader.invalidate(); baitingController.targetWaypoint=null; if(!sonar.replayMode)sonar.nativeBridge.clear() }
        onScanFinished: function(bathymetrySaved, sampleCount) {
            missionUploader.invalidate()
            root.awaitingMissionStart=false
            if(root.areaScanFinishAction==="RTL") {
                root.lastNavigationStatus="Area Scan 100% • "+sampleCount+" măsurători • RTL"
                if(root.vehicle && root.vehicle.guidedModeRTL) root.vehicle.guidedModeRTL(false)
            } else {
                root.lastNavigationStatus="Area Scan 100% • "+sampleCount+" măsurători • HOLD"
                if(root.vehicle && root.vehicle.pauseVehicle) root.vehicle.pauseVehicle()
            }
        }
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
    readonly property real depthM: isFinite(sonar.depthM) ? sonar.depthM : ((sonar.echoFresh || sonar.replayMode) ? sonar.processedBottomDepthM : NaN)
    readonly property real waterTempC: sonar.waterTempC
    readonly property bool sonarConnected: sonar.connected && sonar.dataAlive
    readonly property real bottomEchoStrength: sonar.bottomEchoStrength
    readonly property real bottomHardnessPercent: isNaN(root.bottomEchoStrength) ? NaN : Math.max(0, Math.min(100, root.bottomEchoStrength * 100))
    property alias fishDetections: fishStore.detections
    property string cameraStreamUrl: ""
    property string cameraProtocol: "auto"
    property string lastNavigationStatus: ""
    property bool silentModeActive: false
    property bool cameraConnected: false
    property bool cameraFullscreen: false
    property bool cameraPipEnabled: true
    readonly property bool boatActive: !!vehicle && ((vehicle.groundSpeed && Number(vehicle.groundSpeed.rawValue)>0.25) || scanCoordinator.state==="SCANNING" || baitingController.enabled || root.awaitingMissionStart)
    property bool lastAutoPositionState: false
    onBoatActiveChanged: {
        if(lightSettings.positionMode==="AUTO" && lastAutoPositionState!==boatActive) {
            lastAutoPositionState=boatActive
            commandNanoLight(2,boatActive?1:0,"Poziții AUTO")
        }
    }
    function setPositionLightMode(mode) {
        lightSettings.positionMode=mode
        if(mode==="AUTO") { lastAutoPositionState=boatActive; commandNanoLight(2,boatActive?1:0,"Poziții AUTO") }
        else commandNanoLight(2,mode==="ON"?1:0,"Poziții")
    }
    property bool awaitingMissionStart: false
    property string areaScanFinishAction: "HOLD"
    onVehicleChanged: { if(routePlan && routePlan.active) routePlan.cancel("Autopilot schimbat"); nanoMissingSinceMs=0; nanoHopperFallback=false; proBoatTrack=[]; awaitingMissionStart=false; if(baitingController && baitingController.enabled) baitingController.abortCycle("Autopilot schimbat"); if(scanCoordinator && scanCoordinator.state==="SCANNING") scanCoordinator.pause("Autopilot schimbat") }
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
    property bool headingOverlayOpen: false
    property var mapController: null
    property string pendingAreaDrawMode: "none"
    property bool pendingBaitPointPick: false
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
    readonly property real headingDeg: vehicle && vehicle.heading && isFinite(Number(vehicle.heading.rawValue)) ? Number(vehicle.heading.rawValue) : NaN
    readonly property real rollDeg: vehicle && vehicle.roll && isFinite(Number(vehicle.roll.rawValue)) ? Number(vehicle.roll.rawValue) : NaN
    readonly property real pitchDeg: vehicle && vehicle.pitch && isFinite(Number(vehicle.pitch.rawValue)) ? Number(vehicle.pitch.rawValue) : NaN
    readonly property real waypointBearingDeg: {
        if (vehicle && vehicle.headingToNextWP && isFinite(Number(vehicle.headingToNextWP.rawValue)))
            return Number(vehicle.headingToNextWP.rawValue)
        if (vehicle && vehicle.coordinate && vehicle.coordinate.isValid &&
                baitingController.targetWaypoint && baitingController.targetWaypoint.coordinate &&
                baitingController.targetWaypoint.coordinate.isValid)
            return vehicle.coordinate.azimuthTo(baitingController.targetWaypoint.coordinate)
        return NaN
    }


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
        onReplayModeChanged: {
            if(sonar.replayMode && routePlan.active) root.stopMission()
            root.pendingAreaDrawMode="none"; root.pendingBaitPointPick=false
            root.replaySaveStatus=""
            replayMapping.rawSamples=[]; replayMapping.trackCoordinates=[]
            replayBathymetryModel.rebuild([])
        }
        onGeoSample: function(sample) {
            if(sample.replay) { replayMapping.ingestSample(sample); return }
            if(sonar.replayMode)return
            // Preserve the echo metric captured with this georeferenced CHART column.
            var echo = (sample.bottomEcho !== undefined && isFinite(Number(sample.bottomEcho)))
                       ? Number(sample.bottomEcho) : NaN
            var enriched = {time:sample.time, sequence:sample.sequence, source:sample.source, lat:sample.lat, lon:sample.lon,
                            heading:sample.heading, depth:sample.depth, temp:sample.temp,
                            bottomEcho:echo,
                            chartResolution:sample.chartResolution,
                            chartAbsoluteOffset:sample.chartAbsoluteOffset,
                            chartVersion:sample.chartVersion,
                            chartResolutionMeters:sample.chartResolutionMeters,
                            chartOffsetMeters:sample.chartOffsetMeters,
                            chartRangeMeters:sample.chartRangeMeters,
                            hardness:isNaN(echo)?NaN:Math.max(0,Math.min(100,echo*100))}
            persistence.addSonarSample(enriched)
            sonarMapping.ingestSample(enriched)
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

    function recordLiveFishDetection(targetDepthM, strength) {
        if (sonar.replayMode || !root.linkAlive || !root.vehicle || !root.vehicle.gps || root.vehicle.gps.lock.rawValue<3 ||
            !root.vehicle || !root.vehicle.coordinate || !root.vehicle.coordinate.isValid) return false
        var detection = fishStore.addDetection(root.vehicle.coordinate, targetDepthM, sonar.depthM, strength, Date.now())
        if (!detection) return false
        scanCoordinator.checkpoint("fish-detection")
        return true
    }
    NavoFishDetector {
        id: fishDetector
        onTargetDetected: function(targetDepthM, strength) {
            root.recordLiveFishDetection(targetDepthM, strength)
            // NavoFishDetections owns bounded history and hotspot rebuilding.
        }
    }
    Connections {
        target: sonar.decoder
        function onEchoSamplesChanged() { if (!sonar.replayMode) fishDetector.analyze(sonar.echoSamples, root.depthM, sonar.chartOffsetMeters, sonar.chartRangeMeters) }
    }

    NavoNanoTelemetry {
        id: nanoTelemetry
        vehicle: root.vehicle
    }
    // A missing Nano never removes H743 control: wait once, then permit
    // calibrated servo commands. This does not issue a release automatically.
    property double nanoMissingSinceMs: 0
    property bool nanoHopperFallback: false
    function updateNanoHopperAvailability(nowMs) {
        if (!root.vehicle || !root.linkAlive) {
            nanoMissingSinceMs = 0
            nanoHopperFallback = false
            return
        }
        if (nanoTelemetry.lastUpdateMs > 0) nanoMissingSinceMs = nanoTelemetry.lastUpdateMs
        else if (!nanoMissingSinceMs) nanoMissingSinceMs = nowMs
        nanoHopperFallback = nowMs - nanoMissingSinceMs >= 2000
    }
    Timer {
        interval: 100; repeat: true; running: true
        onTriggered: root.updateNanoHopperAvailability(Date.now())
    }
    Connections {
        target: nanoTelemetry
        function onTelemetryChanged() { root.updateNanoHopperAvailability(Date.now()) }
    }
    NavoHopperBridge {
        id: hopperBridge
        vehicle: root.vehicle
        calibrated: hopperSettings.confirmed && hopperSettings.leftOutput!==hopperSettings.rightOutput && root.linkAlive
        releaseAllowed: nanoTelemetry.connected || root.nanoHopperFallback
        leftServoOutput: hopperSettings.leftOutput
        rightServoOutput: hopperSettings.rightOutput
        leftClosedPwm: hopperSettings.leftClosed
        leftOpenPwm: hopperSettings.leftOpen
        rightClosedPwm: hopperSettings.rightClosed
        rightOpenPwm: hopperSettings.rightOpen
        onCommandSent: function(message) { root.lastNavigationStatus = message }
        onCommandRejected: function(reason) { root.lastNavigationStatus = "Cuve: " + reason }
        onServoCommandFailed:function(reason){
            if(routePlan.active)root.stopMission()
            else if(baitingController.enabled)baitingController.abortCycle(reason)
            root.lastNavigationStatus=reason
        }
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

    NavoG20Controller {
        id: g20Controller
        vehicle: root.vehicle
        inputAllowed: root.linkAlive && !root.sonarController.replayMode
        onActionRequested: function(control, action) { root.dispatchG20Action(control, action) }
    }

    function dispatchG20Action(control, action) {
        if(action==="NONE") return
        if(action==="CUVA_STANGA") { openHopper("stanga"); return }
        if(action==="CUVA_DREAPTA") { openHopper("dreapta"); return }
        if(action==="CUVE_AMBELE") { openHopper("ambele"); return }
        if(action==="SONAR") { activePage=1; lastNavigationStatus="G20 "+control+" • SONAR"; return }
        if(action==="CAMERA") { activePage=5; cameraFullscreen=!cameraFullscreen; lastNavigationStatus="G20 "+control+" • CAMERA FAȚĂ"; return }
        if(action==="HOLD") { holdMission(); lastNavigationStatus="G20 "+control+" • HOLD"; return }
        if(action==="RTL") { homeRtlConfirm.open(); lastNavigationStatus="G20 "+control+" • confirmă RTL / ACASĂ"; return }
        if(action==="MANUAL") {
            if(vehicle) { vehicle.flightMode="Manual"; pendingMode="Manual"; pendingModeLabel="MANUAL"; lastNavigationStatus="G20 • MANUAL solicitat" }
            return
        }
        if(action==="AUTO") {
            lastNavigationStatus="G20 • AUTO selectat • folosește START pentru pornirea misiunii"
            return
        }
        if(action==="FAR") { commandNanoLight(1,2,"Far"); return }
        if(action==="POZITII") { commandNanoLight(2,2,"Poziții"); return }
    }

    function commandNanoLight(target, mode, label) {
        // MAV_CMD_WAYPOINT_USER_1 (31000), consumed only by navo_nano_bridge.lua.
        // param1: 1=headlight, 2=position; param2: 0=OFF, 1=ON, 2=TOGGLE.
        if(!vehicle || !vehicle.sendCommand) { lastNavigationStatus=label+" indisponibil: H743 deconectat"; return false }
        vehicle.sendCommand(1,31000,true,target,mode,0,0,0,0,0)
        lastNavigationStatus=label+" • comandă trimisă • aștept confirmarea Nano"
        return true
    }

    function modeColor() {
        var m = root.flightMode.toUpperCase()
        if (m === "AUTO" || m === "GUIDED") return root.ok
        if (m === "RTL" || m === "HOLD") return root.warn
        return root.accent
    }
    function openHopper(side) {
        if(routePlan.active) {root.lastNavigationStatus="Oprește traseul înainte de eliberarea manuală";return}
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
    function allowLiveAction() {
        if(root.sonarController.replayMode) {
            root.lastNavigationStatus="Replay activ: oprește redarea pentru editare sau navigare live"
            return false
        }
        return true
    }
    function toggleDigitalAnchor(){
        if(root.steeringModeBusy){root.lastNavigationStatus="Oprește asistența cârmei înainte de navigare/misiune";return false}
        if(digitalAnchor.active){root.holdMission();return true}
        if(!root.allowLiveAction())return false
        if(!root.linkAlive || scanCoordinator.state==="SCANNING" || root.awaitingMissionStart || (baitingController.enabled || (routePlan && routePlan.active))){root.lastNavigationStatus="Ancora indisponibilă: verifică legătura și oprește misiunea/nădirea";return false}
        return digitalAnchor.engage()
    }
    function routeDistanceWithReturn(points){
        if(!vehicle || !vehicle.coordinate || !vehicle.coordinate.isValid || !vehicle.homePosition || !vehicle.homePosition.isValid || !points || !points.length)return NaN
        var distance=0,previous=vehicle.coordinate
        for(var i=0;i<points.length;i++){
            var p=points[i]
            if(!p || !p.isValid)return NaN
            var segment=previous.distanceTo(p)
            if(!isFinite(segment)||segment<0)return NaN
            distance+=segment;previous=p
        }
        var homeDistance=previous.distanceTo(vehicle.homePosition)
        return isFinite(homeDistance)&&homeDistance>=0 ? distance+homeDistance : NaN
    }
    function checkEnergyForRoute(points){
        if(!energyGuard.calibrated)return true
        var distance=routeDistanceWithReturn(points)
        var percent=battery && battery.percentRemaining ? Number(battery.percentRemaining.rawValue) : NaN
        if(!energyGuard.canStart(distance,percent)){root.lastNavigationStatus=energyGuard.message(distance,percent);return false}
        return true
    }
    function startRouteStop(stop) {
        if(!root.allowLiveAction() || !root.linkAlive || !root.vehicle || !root.vehicle.guidedModeGotoLocation ||
           !root.vehicle.guidedModeChangeGroundSpeedMetersSecond || !root.vehicle.pauseVehicle ||
           scanCoordinator.state==="SCANNING" || root.awaitingMissionStart ||
           (stop.hopper!==0 && !hopperBridge.calibrated)) {
            root.lastNavigationStatus="Traseu blocat: verifică legătura, comenzile H743 și calibrarea cuvelor"; return false
        }
        var leg=root.vehicle.coordinate && root.vehicle.coordinate.isValid ? root.vehicle.coordinate.distanceTo(routePlan.coordinate(stop)) : NaN
        root.routeLegDistanceM=isFinite(leg) ? leg : 0
        digitalAnchor.release()
        baitingController.rtlAfterDrop=false
        return baitingController.startCycle({coordinate:routePlan.coordinate(stop)},stop.name,stop.hopper)
    }
    function startRoute(loadConfirmed) {
        if(root.steeringModeBusy){root.lastNavigationStatus="Oprește asistența cârmei înainte de navigare/misiune";return false}
        if(!root.requireActiveLakeForPointSave())return false
        if(!preLaunchCheck.navigationReady) {root.lastNavigationStatus=preLaunchCheck.blockingMessage;return false}
        if(!root.allowLiveAction() || !root.linkAlive || baitingController.enabled || routePlan.active ||
           scanCoordinator.state==="SCANNING" || root.awaitingMissionStart || missionUploader.uploadInProgress) {
            root.lastNavigationStatus="Oprește operația activă înainte de START traseu"; return false
        }
        var estimate=root.routeEstimate
        if(!estimate.valid) {root.lastNavigationStatus="Traseu blocat: verifică GPS, HOME și vitezele";return false}
        var percent=battery && battery.percentRemaining ? Number(battery.percentRemaining.rawValue) : NaN
        if(!energyGuard.canStart(estimate.energyDistanceM,percent)) {
            root.lastNavigationStatus=energyGuard.message(estimate.energyDistanceM,percent);return false
        }
        if(routePlan.finishAction==="RTL" && !root.vehicle.guidedModeRTL) {root.lastNavigationStatus="RTL indisponibil";return false}
        if(!scanCoordinator.checkpoint("route-before-start"))return false
        root.routePreviousRtl=baitingController.rtlAfterDrop
        root.missionScanSelected=false
        return routePlan.start(loadConfirmed)
    }
    function finishRoute(action) {
        // Dispatch only: neither ACK nor elapsed time proves HOME/anchor arrival.
        if(!root.allowLiveAction() || !root.linkAlive) {routePlan.state="STOPPED";return false}
        var ok=action==="RTL" ? root.rtlMission() : action==="ANCHOR" ? digitalAnchor.engage() : root.holdMission()
        if(!ok) {routePlan.state="STOPPED";root.lastNavigationStatus="Acțiunea finală a eșuat"}
        scanCoordinator.checkpoint("route-dispatched")
        return ok
    }
    function startBaiting(waypoint,name,hopper){
        if(root.steeringModeBusy){root.lastNavigationStatus="Oprește asistența cârmei înainte de navigare/misiune";return false}
        if(routePlan && routePlan.active) {root.lastNavigationStatus="Oprește traseul înainte de altă nădire";return false}
        if(!root.allowLiveAction())return false
        if(!root.linkAlive || scanCoordinator.state==="SCANNING" || root.awaitingMissionStart || (hopper!==0 && !hopperBridge.calibrated)){root.lastNavigationStatus="Nădire blocată: verifică legătura, misiunea activă și calibrarea cuvelor";return false}
        if(!waypoint || !root.checkEnergyForRoute([waypoint.coordinate]))return false
        digitalAnchor.release()
        return baitingController.startCycle(waypoint,name,hopper)
    }
    function startMission() {
        if(root.steeringModeBusy){root.lastNavigationStatus="Oprește asistența cârmei înainte de navigare/misiune";return false}
        if((routePlan && routePlan.active) || (baitingController && baitingController.enabled)) {root.lastNavigationStatus="Oprește traseul/nădirea înainte de Area Scan";return false}
        if(!root.allowLiveAction()) return false
        if (!preLaunchCheck.navigationReady) { root.lastNavigationStatus = preLaunchCheck.blockingMessage; return false }
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
        if(root.steeringModeBusy){root.lastNavigationStatus="Oprește asistența cârmei înainte de navigare/misiune";return false}
        if((routePlan && routePlan.active) || (baitingController && baitingController.enabled)) {root.lastNavigationStatus="Oprește traseul/nădirea înainte de START Area Scan";return false}
        if(!root.allowLiveAction()) return false
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
        var route=scanCoordinator.state==="RESUME_READY" ? areaScanController.resumeRoute(root.vehicle.coordinate) : areaScanController.generatedPoints
        if(!root.checkEnergyForRoute(route))return false
        // QGC Vehicle::startMission() is the normal MAVLink mission-start path.
        // Never report AUTO before the vehicle reports the resulting mode.
        if (root.vehicle.startMission) {
            digitalAnchor.release()
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
        if(!keepBaiting && routePlan.active) routePlan.cancel("HOLD utilizator")
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
        if(routePlan.active) routePlan.cancel("RTL solicitat")
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
        if(routePlan.active) routePlan.cancel("STOP utilizator")
        root.awaitingMissionStart = false
        if(baitingController.enabled) baitingController.abortCycle("STOP utilizator")
        digitalAnchor.release()
        if(scanCoordinator.state==="SCANNING") scanCoordinator.pause("STOP utilizator")
        else if(scanCoordinator.state==="READY" || scanCoordinator.state==="RESUME_READY") {
            areaScanController.hold("STOP înainte de START", root.vehicle && root.vehicle.coordinate ? root.vehicle.coordinate : null)
            scanCoordinator.state="PAUSED"
            scanCoordinator.checkpoint("stop-before-start")
        }
        missionUploader.invalidate()
        if (!vehicle || !vehicle.pauseVehicle) { root.lastNavigationStatus = "STOP indisponibil: autopilot deconectat"; return false }
        vehicle.pauseVehicle()
        root.pendingMode=vehicle.pauseFlightMode; root.pendingModeLabel="STOP (HOLD)"
        root.lastNavigationStatus = "Comandă STOP/HOLD trimisă • aștept confirmarea autopilotului"
        return true
    }
    function requireActiveLakeForPointSave() {
        if (sonar.replayMode) {
            root.lastNavigationStatus = "Salvează replay-ul într-o baltă separată înainte de a adăuga puncte"
            return false
        }
        if (scanCoordinator.lakeId.length) return true
        root.lastNavigationStatus = "Selectează sau creează o baltă pentru a păstra acest punct"
        noActiveLakeDialog.open()
        return false
    }
    function navigateToCoordinate(c) {
        if(root.steeringModeBusy){root.lastNavigationStatus="Oprește asistența cârmei înainte de navigare/misiune";return false}
        if(!root.allowLiveAction()) return false
        if (!root.linkAlive || !vehicle || !c || !c.isValid) {
            root.lastNavigationStatus = "Navigatie indisponibila"
            return false
        }
        if(scanCoordinator.state==="SCANNING" || root.awaitingMissionStart || (baitingController.enabled || (routePlan && routePlan.active))){root.lastNavigationStatus="Oprește misiunea/nădirea înainte de navigarea către alt punct";return false}
        if (!vehicle.guidedModeGotoLocation) {
            root.lastNavigationStatus = "Navigație indisponibilă: comanda GUIDED nu este expusă de autopilot"
            return false
        }
        if(!root.checkEnergyForRoute([c]))return false
        digitalAnchor.release()
        vehicle.guidedModeGotoLocation(c)
        root.lastNavigationStatus = "Comandă GUIDED trimisă către punct"
        return true
    }


    Dialog { id:homeRtlConfirm; parent:Overlay.overlay; anchors.centerIn:parent; modal:true; width:Math.min(360,root.width-24); title:"Întoarcere la HOME?"; standardButtons:Dialog.Yes | Dialog.No; closePolicy:Popup.NoAutoClose
        Label { width:Math.min(320,root.width-56); wrapMode:Text.WordWrap; text:"Comanzi RTL către H743/ArduPilot. Barca se va întoarce la HOME salvat de autopilot." }
        onAccepted: root.rtlMission()
    }

    Dialog { id:noActiveLakeDialog; parent:Overlay.overlay; anchors.centerIn:parent; modal:true; title:"Baltă necesară"; standardButtons:Dialog.Cancel
        ColumnLayout { width:Math.min(340,root.width-40); spacing:10
            Label { Layout.fillWidth:true; wrapMode:Text.WordWrap; text:"Selectează sau creează o baltă pentru a păstra acest punct. Punctele, sonar-ul și Area Scan vor rămâne grupate în aceeași baltă." }
            Button { Layout.fillWidth:true; text:"DESCHIDE BĂLȚILE MELE"; onClicked:{noActiveLakeDialog.close();root.activePage=4} }
        }
    }

    Rectangle { anchors.fill: parent; color: root.bg }

    Rectangle {
        id: header
        visible: root.activePage !== 10
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        height: 64; color: "#101822"; border.color: root.line; z: 2000
        Flickable {
            anchors.fill: parent
            clip: false
            contentWidth: Math.max(width, headerItems.implicitWidth + 32)
            contentHeight: height
            boundsBehavior: Flickable.StopAtBounds
        RowLayout {
            id: headerItems
            x: 16; height: parent.height; spacing: 8
            Item {
                Layout.preferredWidth: 150
                Layout.preferredHeight: titleLabels.implicitHeight
                ColumnLayout {
                    id: titleLabels
                    anchors.fill: parent
                    spacing: 0
                    Label { text: "NAVO SMART"; color: root.text; font.pixelSize: 22; font.bold: true }
                    Label { text: "Pescarul lu Peste"; color: root.muted; font.pixelSize: 11 }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.mapMaximized=false; root.activePage=0 } }
            }
            StatusPill { iconSource:"qrc:/qml/NavoSmart/icons/satellite.svg"; title: "SATELIȚI"; value: vehicle && vehicle.gps ? String(vehicle.gps.count.rawValue) : "--"; good: vehicle && vehicle.gps }
            StatusPill { iconSource:"qrc:/qml/NavoSmart/icons/home.svg"; title: "HOME"; value: Number(root.distanceToHome).toFixed(0) + " m"; good: !!vehicle; interactive:true
                onClicked: { root.activePage=0; Qt.callLater(function(){ if(root.mapController && root.mapController.centerHome && !root.mapController.centerHome()) root.lastNavigationStatus="HOME indisponibil" }) }
                onPressAndHold: { if(!root.vehicle || !root.vehicle.homePosition || !root.vehicle.homePosition.isValid || !root.vehicle.coordinate || !root.vehicle.coordinate.isValid || !root.vehicle.gps || root.vehicle.gps.lock.rawValue<3) root.lastNavigationStatus="RTL blocat: HOME/GPS invalid"; else homeRtlConfirm.open() }
            }
            StatusPill { iconSource:"qrc:/qml/NavoSmart/icons/speed.svg"; title: "VITEZĂ"; value: vehicle && vehicle.groundSpeed ? Number(vehicle.groundSpeed.rawValue * 3.6).toFixed(1) + " km/h" : "--"; good: !!vehicle }
            StatusPill { iconSource:"qrc:/qml/NavoSmart/icons/target.svg"; title: "ȚINTĂ"; value: root.distanceToTarget > 0 ? Number(root.distanceToTarget).toFixed(0) + " m" : "--"; good: root.distanceToTarget > 0 }
            StatusPill { iconSource:"qrc:/qml/NavoSmart/icons/battery.svg"; title: "BATERIE"; value: battery ? Number(battery.percentRemaining.rawValue).toFixed(0) + "%" : "--"; good: battery && battery.percentRemaining.rawValue > 20 }
            StatusPill { iconSource:"qrc:/qml/NavoSmart/icons/temp.svg"; title: "TEMP"; value: nanoTelemetry.connected && !isNaN(nanoTelemetry.batteryTempC) ? Number(nanoTelemetry.batteryTempC).toFixed(1) + "°" : "--"; good: nanoTelemetry.connected && safetyManager.state !== "CRITICAL" }
            StatusPill { pillWidth: 58; iconSource:"qrc:/qml/NavoSmart/icons/mode.svg"; title: "MOD"; value: root.flightMode.length ? root.flightMode : "OFF"; good: vehicle !== null }
            NavoHeadingCompass {
                id: headingCompass
                Layout.preferredWidth: 54
                Layout.preferredHeight: 54
                headingDeg: root.headingDeg
                waypointBearingDeg: root.waypointBearingDeg
                rollDeg: root.rollDeg
                pitchDeg: root.pitchDeg
                expanded: false
                onToggleRequested: root.headingOverlayOpen = !root.headingOverlayOpen
            }
        }
        }
    }

    NavoHeadingCompass { id:headingCompassOverlay; visible:root.headingOverlayOpen && root.activePage !== 10; expanded:true; width:260; height:260; anchors.top:header.bottom; anchors.right:parent.right; anchors.topMargin:12; anchors.rightMargin:88; z:6000; headingDeg:root.headingDeg; waypointBearingDeg:root.waypointBearingDeg; rollDeg:root.rollDeg; pitchDeg:root.pitchDeg; onToggleRequested:root.headingOverlayOpen=false }

    Rectangle {
        id: sidebar
        anchors.left: parent.left; anchors.top: header.bottom; anchors.bottom: parent.bottom
        visible: !root.mapMaximized && root.activePage !== 10
        width: root.width < 1100 ? 64 : 72; color: root.panel; border.color: root.line
        Flickable {
            anchors.fill: parent
            anchors.margins: 8
            clip: true
            contentWidth: width
            contentHeight: navColumn.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AlwaysOff }
            ColumnLayout {
                id: navColumn
                width: parent.width
                spacing: Math.max(3, Math.min(8, (sidebar.height - 44 - 10 * 36) / 11))
                NavButton { text: "HARTA"; iconSource: "qrc:/qml/NavoSmart/icons/map.svg"; active: root.activePage === 0; onClicked: root.activePage = 0 }
                NavButton { text: "SONAR"; iconSource: "qrc:/qml/NavoSmart/icons/sonar.svg"; active: root.activePage === 1; onClicked: root.activePage = 1 }
                NavButton { text: "SONAR PRO"; proBadge: true; iconSource: "qrc:/qml/NavoSmart/icons/sonar.svg"; active: root.activePage === 10; onClicked: root.activePage = 10 }
                NavButton { text: "MISIUNI"; iconSource: "qrc:/qml/NavoSmart/icons/scan.svg"; active: root.activePage === 2; onClicked: root.activePage = 2 }
                NavButton { text: "PUNCTE PESCUIT"; iconSource: "qrc:/qml/NavoSmart/icons/fish.svg"; active: root.activePage === 3; onClicked: root.activePage = 3 }
                NavButton { text: "BALȚILE MELE"; iconSource: "qrc:/qml/NavoSmart/icons/lake.svg"; active: root.activePage === 4; onClicked: root.activePage = 4 }
                NavButton { text: "CAMERA"; iconSource: "qrc:/qml/NavoSmart/icons/camera.svg"; active: root.activePage === 5; onClicked: root.activePage = 5 }
                NavButton { text: "3D"; iconSource: "qrc:/qml/NavoSmart/icons/cube.svg"; active: root.activePage === 7; onClicked: root.activePage = 7 }
                NavButton { text: "NĂDIRE"; iconSource: "qrc:/qml/NavoSmart/icons/bait.svg"; active: root.activePage === 8; onClicked: root.activePage = 8 }
                NavButton { text: "SIGURANȚĂ"; iconSource: "qrc:/qml/NavoSmart/icons/shield.svg"; active: root.activePage === 9; onClicked: root.activePage = 9 }
                NavButton { text: "SETARI"; iconSource: "qrc:/qml/NavoSmart/icons/settings.svg"; active: root.activePage === 6; onClicked: root.activePage = 6 }
                Label { Layout.alignment:Qt.AlignHCenter; text:"●"; color:root.ok; font.pixelSize:10; ToolTip.visible:mouseBoat.containsMouse; ToolTip.text:"BARCA "+root.boatId; MouseArea{id:mouseBoat;anchors.fill:parent;hoverEnabled:true} }
            }
        }
    }

    NavoMissionStatus {
        id:missionStrip
        visible:root.missionBusy || root.activePage===2
        anchors.left:root.mapMaximized || root.activePage===10 ? parent.left : sidebar.right
        anchors.right:parent.right
        anchors.top:root.activePage===10 ? parent.top : header.bottom
        height:visible ? implicitHeight : 0
        z:6001
        active:root.missionBusy
        connected:root.linkAlive
        homeAvailable:!sonar.replayMode && !!root.vehicle && !!root.vehicle.guidedModeRTL && !!root.vehicle.homePosition && root.vehicle.homePosition.isValid
        progress:routePlan.active ? 100*(routePlan.currentIndex+Math.min(0.95,Math.max(0,root.routeLegDistanceM>0 && isFinite(baitingController.distanceToTarget()) ? 1-baitingController.distanceToTarget()/root.routeLegDistanceM : 0)))/Math.max(1,routePlan.runningStops.length) : root.missionScanSelected ? areaScanController.progressPercent() : routePlan.state==="DISPATCHED" ? 100 : 0
        statusText:routePlan.active ? (routePlan.missionKind==="point" ? "Mergi la punct" : "Traseu cu opriri")+" • oprire "+(routePlan.currentIndex+1)+"/"+routePlan.runningStops.length+" • "+baitingController.stateText(baitingController.state) : root.missionScanSelected ? "Scanare • "+root.missionStateLabel(scanCoordinator.state) : "Misiune • "+root.missionStateLabel(routePlan.state)
        onPauseRequested:root.holdMission()
        onHomeRequested:homeRtlConfirm.open()
    }
    Rectangle {
        id: content
        anchors.left: root.mapMaximized || root.activePage === 10 ? parent.left : sidebar.right; anchors.right: parent.right; anchors.top: missionStrip.bottom; anchors.bottom: parent.bottom
        // Fullscreen sonar controls must render above the Dashboard header (z: 2000).
        z: root.activePage === 10 ? 3000 : 0
        color: root.bg
        Loader {
            Accessible.role: Accessible.Pane
            Accessible.name: status === Loader.Ready ? "Pagina " + root.activePageName : "Se încarcă pagina"
            anchors.fill: parent; anchors.margins: root.activePage === 10 ? 0 : 10
            sourceComponent: root.activePage === 0 ? mapPage :
                             root.activePage === 1 ? sonarPage :
                             root.activePage === 10 ? sonarProPage :
                             root.activePage === 2 ? areaPage :
                             root.activePage === 3 ? fishingPage :
                             root.activePage === 4 ? lakesPage :
                             root.activePage === 5 ? cameraPage :
                             root.activePage === 7 ? bathymetryPage :
                             root.activePage === 8 ? baitingPage :
                             root.activePage === 9 ? failsafePage : settingsPage
        }
    }

    NavoCameraPip {
        id: persistentCameraPip
        parent: root
        z: 900
        visible: root.cameraPipEnabled && root.cameraStreamUrl.length>0 && !root.cameraFullscreen && root.activePage!==5 && root.activePage!==10
        anchors.right: parent.right
        anchors.top: header.bottom
        anchors.rightMargin: root.activePage===0 ? 88 : 16
        anchors.topMargin: root.activePage===0 ? 20 : 12
        width: root.activePage===0 ? Math.max(170,Math.min(210,root.width*0.15)) : Math.max(190,Math.min(260,root.width*0.19))
        height: Math.round(width*0.58)
        connected: root.cameraStreamUrl.length>0
        streamUrl: root.cameraStreamUrl
        protocol: root.cameraProtocol
        onLiveChanged: root.cameraConnected=live
        onFullscreenRequested: root.cameraFullscreen=true
    }


    Component {
        id: mapPage
        Item {
            id: fishingPageRoot
            Rectangle { anchors.fill: parent; radius: 8; color: root.panel; border.color: root.line }
            NavoMap {
                routeActive:routePlan.active
                routeStops:routePlan.active ? routePlan.runningStops : routePlan.stops
                routeReturnsHome:(routePlan.active ? routePlan.runningFinishAction : routePlan.finishAction)==="RTL"
                recordedReplay: sonar.replayMode
                id: navoMap
                anchors.fill: parent
                anchors.leftMargin: 8; anchors.topMargin: 8; anchors.bottomMargin: 8; anchors.rightMargin: 72
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
                nativeSurfaceMesh: root.displayNativeSurfaceMesh
                nativeSurfaceBridge: sonar.nativeBridge
                bathymetryCells: root.displayBathymetryCells
                        replayPreview: sonar.replayMode || (!root.vehicle && sonarMapping.trackCoordinates.length>0)
                        replayTrack: sonar.replayMode ? replayMapping.trackCoordinates : sonarMapping.trackCoordinates
                baitingController: root.mapBaitingController
                areaScanController: root.mapAreaScanController
                savedDepthM: root.depthM
                savedWaterTempC: root.waterTempC
                maximized: root.mapMaximized
                onMaximizeRequested: root.mapMaximized = !root.mapMaximized
                onNavigateRequested: function(coordinate) { root.navigateToCoordinate(coordinate) }
                onBaitingWaypointSelected: function(waypoint) {
                    root.lastNavigationStatus="Punct selectat: " + (waypoint.sequenceNumber !== undefined ? "WP" + waypoint.sequenceNumber : "waypoint") + " • poți deschide NĂDIRE când dorești"
                }
                onAreaRectangleRequested: function(cornerA, cornerB) {
                            if(!root.allowLiveAction()) return;
                    missionUploader.invalidate()
                    var pts=scanCoordinator.prepareRectangle(cornerA,cornerB)
                    root.lastNavigationStatus=pts.length ? "Area Scan dreptunghi pregătit • "+areaScanController.laneCount()+" culoare • "+pts.length+" WP • apasă PREGĂTEȘTE MISIUNEA" : "Dreptunghi respins: "+areaScanController.lastError
                    root.pendingAreaDrawMode="none"
                    root.missionScanSelected=true
                    root.activePage=2
                }
                onAreaPolygonRequested: function(polygon) {
                            if(!root.allowLiveAction()) return;
                    missionUploader.invalidate()
                    var pts=scanCoordinator.preparePolygon(polygon)
                    root.lastNavigationStatus=pts.length ? "Area Scan poligon • "+areaScanController.laneCount()+" culoare • "+pts.length+" WP generate" : areaScanController.lastError
                    root.pendingAreaDrawMode="none"
                    root.missionScanSelected=true
                    root.activePage=2
                }
                onSaveNamedPointRequested: function(coordinate,name,markerColor) {
                    if(!root.requireActiveLakeForPointSave()) return
                    var spot=fishingSpots.saveSpot(coordinate,NaN,NaN,name,"Punct ales pe hartă",null,markerColor)
                    if(spot){scanCoordinator.checkpoint("fishing-spot-map");root.lastNavigationStatus="Punct salvat: "+spot.name}
                }
                onSavePointRequested: function(coordinate) {
                    if(!root.requireActiveLakeForPointSave()) return
                    var spot = fishingSpots.saveSpot(coordinate, root.depthM, root.waterTempC, "", "", null)
                    if (spot) {
                        scanCoordinator.checkpoint("fishing-spot")
                        root.lastNavigationStatus = "Punct salvat: " + spot.name
                    } else root.lastNavigationStatus = "Punct invalid: nu a fost salvat"
                }
            }
            Column {
                anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom
                anchors.topMargin: 8; anchors.rightMargin: 8; anchors.bottomMargin: 8
                width: 54; spacing: 4
                component MiniStatus: Rectangle {
                    property string title:""; property string value:""; property bool good:false; property url iconSource:""
                    property bool clickable:false
                    property string toolTipText:""
                    signal clicked()
                    width:54; height:52; radius:7; color:mouse.containsMouse&&clickable?"#183149":"#101822"; border.color:good?root.ok:(mouse.containsMouse&&clickable?"#21b7ff":root.line)
                    Column { anchors.centerIn:parent; spacing:0
                        Image { anchors.horizontalCenter:parent.horizontalCenter;width:22;height:22;source:iconSource;fillMode:Image.PreserveAspectFit }
                        Label { anchors.horizontalCenter:parent.horizontalCenter; text:title; color:"#c9d4df"; font.pixelSize:7; font.bold:true }
                        Label { anchors.horizontalCenter:parent.horizontalCenter; text:value; color:good?root.ok:"#ff6575"; font.pixelSize:9; font.bold:true }
                    }
                    MouseArea { id:mouse; anchors.fill:parent; enabled:parent.clickable; hoverEnabled:true; cursorShape:enabled?Qt.PointingHandCursor:Qt.ArrowCursor; onClicked:parent.clicked() }
                    ToolTip.visible: mouse.containsMouse && clickable
                    ToolTip.text: toolTipText
                }
                MiniStatus { iconSource:"qrc:/qml/NavoSmart/icons/autopilot.svg"; title:"AP"; value:vehicle?"ON":"OFF"; good:!!vehicle }
                MiniStatus { iconSource:"qrc:/qml/NavoSmart/icons/lan.svg"; title:"LAN"; value:sonar.transport&&sonar.transport.connected?"ON":"OFF"; good:sonar.transport&&sonar.transport.connected }
                MiniStatus { iconSource:"qrc:/qml/NavoSmart/icons/sonar.svg"; title:"SONAR"; value:root.sonarConnected?"ON":"OFF"; good:root.sonarConnected }
                MiniStatus { iconSource:"qrc:/qml/NavoSmart/icons/nano.svg"; title:"NANO"; value:nanoTelemetry.connected?"ON":"OFF"; good:nanoTelemetry.connected }
                MiniStatus { iconSource:"qrc:/qml/NavoSmart/icons/navigate.svg";title:"ANCORĂ";value:digitalAnchor.active?"CERUTĂ":"OFF";good:digitalAnchor.guidedConfirmed;clickable:true;toolTipText:digitalAnchor.active?"Dezactivează ancora GPS și solicită HOLD":"Menține poziția GPS curentă";onClicked:root.toggleDigitalAnchor() }
                MiniStatus {
                    iconSource:"qrc:/qml/NavoSmart/icons/camera.svg"; title:"CAM"; value:root.cameraConnected?"ON":"OFF"; good:root.cameraConnected
                    clickable:true
                    toolTipText: root.cameraStreamUrl.length>0 ? (root.cameraPipEnabled ? "Ascunde Camera față PiP" : "Afișează Camera față PiP") : "Configurează Camera față"
                    onClicked: {
                        if (root.cameraStreamUrl.length > 0) {
                            root.cameraPipEnabled = !root.cameraPipEnabled
                            root.cameraFullscreen = false
                            root.lastNavigationStatus = root.cameraPipEnabled ? "Camera față PiP activată" : "Camera față PiP ascunsă"
                        } else {
                            root.activePage = 5
                            root.lastNavigationStatus = "Camera față: configurează stream-ul Ethernet"
                        }
                    }
                }
            }
        }
    }

    Component {
        id: sonarProPage
        NavoSonarPro {
            chartSource: sonar
            vehicle: root.vehicle
            planController: root.planController
            boatTrack: sonar.replayMode ? replayMapping.trackCoordinates : root.proBoatTrack
            plannedTrack: areaScanController.generatedPoints
            replaySaveStatus: root.replaySaveStatus
            replaySampleCount: replayMapping.rawSamples.length
            onSaveReplayRequested: function(name) {
                root.saveRecordedReplayLake(name)
            }
            onClosed: root.activePage = 0
            connected: sonar.connected || sonar.replayMode
            depthM: root.depthM
            waterTempC: root.waterTempC
            samples: sonar.echoSamples
            chartResolution: sonar.chartResolution
            chartAbsoluteOffset: sonar.chartAbsoluteOffset
            chartVersion: sonar.chartVersion
            chartResolutionMeters: sonar.chartResolutionMeters
            chartOffsetMeters: sonar.chartOffsetMeters
            chartRangeMeters: sonar.chartRangeMeters
            chartRawByteCount: sonar.chartRawByteCount
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
                    text: root.sonarConnected ? "Sonar conectat • apasă MĂREȘTE pentru ecogramă" : "Kogger offline • apasă MĂREȘTE pentru ecogramă și conexiune"
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
                        if(!root.requireActiveLakeForPointSave()) return
                        var spot=fishingSpots.saveSpot(QtPositioning.coordinate(latitude,longitude),depth,temp,"","",null)
                        if(spot){scanCoordinator.checkpoint("sonar-fishing-spot");root.lastNavigationStatus="Punct sonar salvat: "+spot.name}
                    }
                    onRecordingRequested: function(start) {
                        if(start) {
                            if(!scanCoordinator.lakeId.length) {
                                fullSonar.recording=false
                                root.lastNavigationStatus="Înregistrare sonar blocată: selectează o baltă"
                                return
                            }
                            if(scanCoordinator.state==="SCANNING") {
                                fullSonar.recording=false
                                root.lastNavigationStatus="Area Scan înregistrează deja datele sonar"
                                return
                            }
                            sonarMapping.startScan()
                            if(!sonarMapping.scanning) fullSonar.recording=false
                            else {
                                scanCoordinator.state="MANUAL_SONAR"
                                scanCoordinator.checkpoint("manual-sonar-start")
                                root.lastNavigationStatus="Înregistrare sonar pornită • GPS + adâncime + temperatură"
                            }
                        } else {
                            if(scanCoordinator.state==="MANUAL_SONAR" && sonarMapping.scanning) {
                                sonarMapping.finishAndBuild()
                                var manualBathyOk=false
                                if(sonarMapping.rawSamples.length>=3 && bathymetryModel && bathymetryModel.rebuild) {
                                    var manualCells=bathymetryModel.rebuild(sonarMapping.rawSamples)
                                    if(manualCells!==undefined && manualCells!==null) {
                                        scanCoordinator.bathymetryCells=manualCells
                                        manualBathyOk=true
                                    }
                                }
                                sonarMapping.markBathymetrySaved(manualBathyOk)
                                scanCoordinator.state="IDLE"
                                var manualSaved=scanCoordinator.checkpoint("manual-sonar-stop")
                                root.lastNavigationStatus=manualSaved
                                        ? ("Înregistrare sonar oprită • "+sonarMapping.rawSamples.length+" măsurători salvate"+(manualBathyOk?" • batimetrie generată":" • batimetrie indisponibilă"))
                                        : "Înregistrare sonar oprită • EROARE la salvarea sesiunii"
                            }
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
                anchors.fill: parent; anchors.margins: root.responsiveMargin; spacing: root.responsiveGap
                Flow {
                    Layout.fillWidth:true
                    spacing:6
                    Repeater {
                        model:["Mergi la punct","Traseu cu opriri","Scanează zona"]
                        delegate:Button {
                            required property string modelData
                            required property int index
                            text:modelData
                            highlighted:root.missionScanSelected ? index===2 : index===(routePlan.missionKind==="point" ? 0 : 1)
                            enabled:!root.missionBusy && !sonar.replayMode
                            onClicked:root.selectMission(index)
                        }
                    }
                }
                Label {
                    Layout.fillWidth:true; wrapMode:Text.WordWrap; color:root.muted
                    visible:!root.missionScanSelected && routePlan.state==="STOPPED"
                    text:"HOLD oprește ciclul de nădire. Verifică cuvele și folosește un nou START; nu se reia automat o eliberare."
                }
                GridLayout {
                    columns:2
                    visible:root.missionScanSelected
                    Layout.fillWidth:true
                    Label {Layout.fillWidth:true;wrapMode:Text.WordWrap;text:"Viteză estimare (m/s)";color:"white"}
                    SpinBox {
                        from:1;to:30;value:Math.round(root.scanEstimateSpeedMps*10)
                        enabled:!root.missionBusy && !sonar.replayMode
                        textFromValue:function(v,locale){return Number(v/10).toLocaleString(locale,'f',1)}
                        onValueModified:root.scanEstimateSpeedMps=value/10
                    }
                    Label {text:"La final";color:"white"}
                    ComboBox { enabled:!root.missionBusy && !sonar.replayMode; model:["HOLD","RTL"]; currentIndex:root.areaScanFinishAction==="RTL"?1:0; onActivated:root.areaScanFinishAction=currentIndex===1?"RTL":"HOLD" }
                }
                Label {
                    visible:root.missionScanSelected
                    Layout.fillWidth:true;wrapMode:Text.WordWrap;color:root.muted
                    text:"Cuve: fără eliberare • AUTO folosește viteza configurată în H743.\n"+
                        (root.scanEstimate.valid ? "~"+Math.ceil(root.scanEstimate.distanceM)+" m • ~"+Math.ceil(root.scanEstimate.durationSeconds/60)+" min (estimare fără viraje)" : "Definește zona; GPS și HOME sunt necesare pentru estimare.")
                }
                GridLayout {
                    columns:root.missionScanSelected || width>=700 ? 2 : 1
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    rowSpacing:8;columnSpacing:8
                    Rectangle {
                        Layout.fillWidth: true; Layout.fillHeight: true; Layout.minimumHeight:120
                        radius: 8; color: root.bg; border.color: root.line; clip: true
                        NavoMap {
                routeActive:routePlan.active
                routeStops:routePlan.active ? routePlan.runningStops : routePlan.stops
                routeReturnsHome:(routePlan.active ? routePlan.runningFinishAction : routePlan.finishAction)==="RTL"
                recordedReplay: sonar.replayMode
                            id: areaScanMap
                            anchors.fill: parent; anchors.margins: 2
                            vehicle: root.vehicle
                            planController: root.planController
                            waypointNames: root.waypointNames
                            fishModel: fishStore
                            fishingSpotsModel: fishingSpots
                            nativeSurfaceMesh: root.displayNativeSurfaceMesh
                            nativeSurfaceBridge: sonar.nativeBridge
                bathymetryCells: root.displayBathymetryCells
                        replayPreview: sonar.replayMode || (!root.vehicle && sonarMapping.trackCoordinates.length>0)
                        replayTrack: sonar.replayMode ? replayMapping.trackCoordinates : sonarMapping.trackCoordinates
                            baitingController: root.mapBaitingController
                            areaScanController: root.mapAreaScanController
                            savedDepthM: root.depthM
                            savedWaterTempC: root.waterTempC
                            maximized: root.mapMaximized
                            baitPointPickMode: root.pendingBaitPointPick
                            onNavigateRequested:function(coordinate){if(!root.missionBusy){baitingController.targetWaypoint={coordinate:coordinate,name:"Punct hartă",sequenceNumber:0};root.lastNavigationStatus="Punct selectat pentru misiune"}}
                            onBaitPointPicked: function(coordinate) { root.pendingBaitPointPick=false; baitingController.targetWaypoint={coordinate:coordinate,name:"Punct hartă",sequenceNumber:0}; root.lastNavigationStatus="Punct selectat • aplică destinația sau adaugă oprirea" }
                            onMaximizeRequested: root.mapMaximized = !root.mapMaximized
                            onAreaRectangleRequested: function(cornerA, cornerB) {
                            if(!root.allowLiveAction()) return; missionUploader.invalidate(); var pts=scanCoordinator.prepareRectangle(cornerA,cornerB); root.lastNavigationStatus=pts.length ? "Area Scan dreptunghi pregătit • "+areaScanController.laneCount()+" culoare • "+pts.length+" WP • apasă PREGĂTEȘTE MISIUNEA" : "Dreptunghi respins: "+areaScanController.lastError; root.pendingAreaDrawMode="none" }
                            onAreaPolygonRequested: function(polygon) {
                            if(!root.allowLiveAction()) return; missionUploader.invalidate(); var pts=scanCoordinator.preparePolygon(polygon); root.lastNavigationStatus=pts.length ? "Area Scan poligon pregătit • "+areaScanController.laneCount()+" culoare • "+pts.length+" WP • apasă PREGĂTEȘTE MISIUNEA" : "Poligon respins: "+areaScanController.lastError; root.pendingAreaDrawMode="none" }
                            onSavePointRequested: function(coordinate) { if(!root.requireActiveLakeForPointSave()) return; var spot=fishingSpots.saveSpot(coordinate,root.depthM,root.waterTempC,"","",null); if(spot) scanCoordinator.checkpoint("fishing-spot") }
                        }
                    }
                    ScrollView {
                        visible:!root.missionScanSelected
                        Layout.fillWidth:parent.columns===1
                        Layout.preferredWidth:parent.columns===1 ? parent.width : 300
                        Layout.minimumHeight:130
                        Layout.fillHeight:true
                        clip:true
                        contentWidth:availableWidth
                        NavoRoutePanel {
                            width:parent.width
                            implicitHeight:650
                            routePlan:root.routePlanController
                            waypoint:baitingController.targetWaypoint
                            availableSpots:fishingSpots.fishingSpots
                            estimate:root.routeEstimate
                            energyText:root.routeEnergyText
                            speedMps:baitingController.silentMode ? baitingController.silentSpeedMps : baitingController.normalSpeedMps
                            speedEditable:!root.missionBusy
                            onSpeedRequested:function(speed){if(!root.missionBusy && root.allowLiveAction()){if(baitingController.silentMode)baitingController.silentSpeedMps=speed;else baitingController.normalSpeedMps=speed}}
                            onSpotChosen:function(spot){baitingController.targetWaypoint={coordinate:QtPositioning.coordinate(spot.lat,spot.lon),name:spot.name,sequenceNumber:0}}
                            onChooseOnMapRequested:{root.pendingBaitPointPick=true;root.lastNavigationStatus="Atinge destinația pe hartă"}
                            onStartRequested:function(loadConfirmed){root.startRoute(loadConfirmed)}
                            onStopRequested:root.stopMission()
                        }
                    }
                    ScrollView {
                        visible:root.missionScanSelected
                        Layout.preferredWidth: root.compactUi ? 112 : 126
                        Layout.minimumWidth: 106; Layout.maximumWidth: 132
                        Layout.fillHeight: true
                        clip:true;contentWidth:availableWidth
                        Flow {
                        width:parent.width
                        spacing: 6
                        component ScanIconButton: Button {
                            width: 52; height: 46; padding: 0
                            property string hint: ""
                            ToolTip.visible: hovered
                            ToolTip.text: hint
                            background: Rectangle { radius: 8; color: parent.down ? "#18354a" : "#101b25"; border.color: parent.enabled ? "#31506a" : "#26313a" }
                        }
                        ScanIconButton {
                            hint: "Desenează dreptunghi"
                            enabled: !root.missionBusy && !sonar.replayMode
                            contentItem: Canvas { anchors.fill: parent; onPaint:{var p=getContext("2d");p.reset();p.strokeStyle="#f2f7fb";p.lineWidth=2;p.strokeRect(12,11,28,24)} }
                            onClicked: { root.pendingAreaDrawMode="rectangle"; Qt.callLater(function(){if(areaScanMap){areaScanMap.beginAreaRectangle();root.pendingAreaDrawMode="none"}}); root.lastNavigationStatus="Atinge două colțuri pe hartă pentru dreptunghi" }
                        }
                        ScanIconButton {
                            hint: "Desenează poligon"
                            enabled: !root.missionBusy && !sonar.replayMode
                            contentItem: Canvas { anchors.fill: parent; onPaint:{var p=getContext("2d");p.reset();p.strokeStyle="#f2f7fb";p.lineWidth=2;p.beginPath();p.moveTo(12,31);p.lineTo(17,12);p.lineTo(38,9);p.lineTo(42,30);p.lineTo(27,37);p.closePath();p.stroke()} }
                            onClicked: { root.pendingAreaDrawMode="polygon"; Qt.callLater(function(){if(areaScanMap){areaScanMap.beginAreaPolygon();root.pendingAreaDrawMode="none"}}); root.lastNavigationStatus="Atinge cel puțin trei puncte și apoi TERMINĂ" }
                        }
                        ScanIconButton {
                            hint: "Pregătește misiunea"
                            enabled: areaScanController.generatedPoints.length>0 && scanCoordinator.state!=="SCANNING" && !missionUploader.uploadInProgress
                            contentItem: Canvas { anchors.fill: parent; onPaint:{var p=getContext("2d");p.reset();p.strokeStyle="#21b7ff";p.fillStyle="#21b7ff";p.lineWidth=2;p.beginPath();p.moveTo(11,34);p.lineTo(22,22);p.lineTo(31,29);p.lineTo(41,13);p.stroke();for(var i=0;i<4;i++){var a=[[11,34],[22,22],[31,29],[41,13]][i];p.beginPath();p.arc(a[0],a[1],2.5,0,Math.PI*2);p.fill()}} }
                            onClicked: { if(!root.allowLiveAction()) return; missionUploader.invalidate(); var prepared=scanCoordinator.prepareMission(false); if(prepared&&prepared.length)root.lastNavigationStatus="Misiune pregătită • "+prepared.length+" WP • următorul pas: UPLOAD"; else if(!root.lastNavigationStatus.length)root.lastNavigationStatus="Pregătirea misiunii a eșuat" }
                        }
                        ScanIconButton {
                            hint: missionUploader.uploadVerified ? "Start autopilot" : "Upload misiune"
                            enabled: missionUploader.preparedCount>0 && !missionUploader.uploadInProgress
                            contentItem: Canvas { anchors.fill: parent; onPaint:{var p=getContext("2d");p.reset();p.strokeStyle="#31d67b";p.fillStyle="#31d67b";p.lineWidth=2;if(missionUploader.uploadVerified){p.beginPath();p.moveTo(17,11);p.lineTo(38,23);p.lineTo(17,35);p.closePath();p.fill()}else{p.beginPath();p.moveTo(26,35);p.lineTo(26,12);p.moveTo(17,21);p.lineTo(26,12);p.lineTo(35,21);p.stroke()}} }
                            onClicked: root.startMission()
                        }
                        ScanIconButton {
                            hint: "Continuă scanarea"
                            enabled: (scanCoordinator.state==="PAUSED"||scanCoordinator.state==="RTL") && !missionUploader.uploadInProgress && areaScanController.generatedPoints.length>0 && areaScanController.completedLanes.length<areaScanController.laneCount()
                            contentItem: Canvas { anchors.fill: parent; onPaint:{var p=getContext("2d");p.reset();p.strokeStyle="#f2f7fb";p.lineWidth=2;p.beginPath();p.arc(26,23,12,.45,5.3);p.stroke();p.beginPath();p.moveTo(34,10);p.lineTo(39,17);p.lineTo(31,18);p.stroke()} }
                            onClicked:{var mission=scanCoordinator.resume();if(mission.length)root.lastNavigationStatus="Resume pregătit • apasă UPLOAD și apoi START AUTOPILOT"}
                        }
                        ScanIconButton { hint:"HOLD"; enabled:scanCoordinator.state==="SCANNING"||root.awaitingMissionStart; contentItem:Canvas{anchors.fill:parent;onPaint:{var p=getContext("2d");p.reset();p.fillStyle="#ffc857";p.fillRect(15,12,7,23);p.fillRect(30,12,7,23)}} onClicked:root.holdMission() }
                        ScanIconButton { hint:"RTL / întoarcere acasă"; enabled:scanCoordinator.state==="SCANNING"||scanCoordinator.state==="PAUSED"||scanCoordinator.state==="RESUME_READY"; contentItem:Canvas{anchors.fill:parent;onPaint:{var p=getContext("2d");p.reset();p.strokeStyle="#21b7ff";p.lineWidth=2;p.beginPath();p.moveTo(10,25);p.lineTo(26,11);p.lineTo(42,25);p.moveTo(16,22);p.lineTo(16,37);p.lineTo(36,37);p.lineTo(36,22);p.stroke()}} onClicked:root.rtlMission() }
                        ScanIconButton { hint:"STOP"; enabled:scanCoordinator.state==="SCANNING"||scanCoordinator.state==="PAUSED"||scanCoordinator.state==="READY"||scanCoordinator.state==="RESUME_READY"||root.awaitingMissionStart; contentItem:Canvas{anchors.fill:parent;onPaint:{var p=getContext("2d");p.reset();p.fillStyle="#ff5c5c";p.fillRect(15,12,23,23)}} onClicked:root.stopMission() }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: fishingPage
        Item {
            id: fishingPageRoot
            property string spotEditId: ""
            property string spotEditColor: "#31d67b"
            property bool mapExpanded: false
            Rectangle { anchors.fill:parent; radius:8; color:root.panel; border.color:root.line }
            RowLayout {
                anchors.fill:parent; anchors.margins:8; spacing:fishingPageRoot.mapExpanded?0:8
                Rectangle {
                    Layout.fillWidth:true; Layout.fillHeight:true
                    Layout.minimumWidth: 320
                    radius:8; color:root.bg; border.color:root.line; clip:true
                    NavoMap {
                routeActive:routePlan.active
                routeStops:routePlan.active ? routePlan.runningStops : routePlan.stops
                routeReturnsHome:(routePlan.active ? routePlan.runningFinishAction : routePlan.finishAction)==="RTL"
                recordedReplay: sonar.replayMode
                        id:fishingMap
                        anchors.fill:parent
                        property real targetAspect: 16/9
                        property real availableAspect: width / Math.max(1,height)
                        vehicle:root.vehicle; planController:root.planController; waypointNames:root.waypointNames
                        fishModel:fishStore; fishingSpotsModel:fishingSpots; nativeSurfaceMesh:root.displayNativeSurfaceMesh; nativeSurfaceBridge:sonar.nativeBridge; bathymetryCells:root.displayBathymetryCells
                        replayPreview: sonar.replayMode || (!root.vehicle && sonarMapping.trackCoordinates.length>0)
                        replayTrack: sonar.replayMode ? replayMapping.trackCoordinates : sonarMapping.trackCoordinates
                        baitingController: root.mapBaitingController; areaScanController: root.mapAreaScanController
                        savedDepthM:root.depthM; savedWaterTempC:root.waterTempC; showStatusHint:false
                        maximized:fishingPageRoot.mapExpanded
                        onMaximizeRequested:fishingPageRoot.mapExpanded=!fishingPageRoot.mapExpanded
                        onFishingSpotsRequested:function(spot){fishingPageRoot.mapExpanded=false;root.lastNavigationStatus="Punct selectat: "+(spot&&spot.name?spot.name:"--")}
                        onNavigateRequested:function(c){root.navigateToCoordinate(c)}
                        onFishingSpotRenameRequested:function(spot){fishingPageRoot.openEdit(spot)}
                        onBaitingWaypointSelected:function(wp){baitingController.targetWaypoint=wp;root.lastNavigationStatus="Punct de nădire ales: "+wp.name}
                        onSaveNamedPointRequested:function(c,name,markerColor){
                            if(!root.requireActiveLakeForPointSave()) return
                            var s=fishingSpots.saveSpot(c,NaN,NaN,name,"Punct ales pe hartă",null,markerColor)
                            if(s){scanCoordinator.checkpoint("fishing-spot-map");root.lastNavigationStatus="Punct salvat: "+s.name}
                        }
                        onSavePointRequested:function(c){
                            if(!root.requireActiveLakeForPointSave()) return
                            var s=fishingSpots.saveSpot(c,root.depthM,root.waterTempC,"","Poziția bărcii",null,"#31d67b")
                            if(s){scanCoordinator.checkpoint("fishing-spot-boat");root.lastNavigationStatus="Poziția bărcii salvată: "+s.name}
                        }
                    }
                    Rectangle {
                        anchors.left:parent.left; anchors.top:parent.top; anchors.leftMargin:76; anchors.topMargin:10
                        width:hint.implicitWidth+20; height:30; radius:7; color:"#071827ee"; border.color:root.line
                        Label { id:hint; anchors.centerIn:parent; text:"ȚINE APĂSAT PE HARTĂ PENTRU PUNCT NOU"; color:root.text; font.pixelSize:10; font.bold:true }
                    }
                }
                Rectangle {
                    visible:!fishingPageRoot.mapExpanded; Layout.preferredWidth: visible ? (root.width < 1150 ? 270 : Math.min(330, parent.width*0.25)) : 0; Layout.minimumWidth:visible?240:0; Layout.maximumWidth:visible?330:0; Layout.fillHeight:true
                    radius:8; color:root.panel; border.color:root.line
                    ColumnLayout {
                        anchors.fill:parent; anchors.margins:8; spacing:7
                        RowLayout {
                            Layout.fillWidth:true
                            Label { text:"PUNCTE PESCUIT"; color:root.text; font.bold:true; font.pixelSize:15 }
                            Item { Layout.fillWidth:true }
                            Label { text:fishingSpots.fishingSpots.length+" salvate"; color:root.muted; font.pixelSize:10 }
                        }
                        Label { Layout.fillWidth:true; text:scanCoordinator.lakeName.length ? "Balta: "+scanCoordinator.lakeName : "Selectează o baltă pentru salvare persistentă"; color:scanCoordinator.lakeId.length?root.ok:root.warn; font.pixelSize:10; wrapMode:Text.WordWrap }
                        ListView {
                            Layout.fillWidth:true; Layout.fillHeight:true; clip:true; spacing:5
                            model:fishingSpots.fishingSpots
                            delegate:Rectangle {
                                required property var modelData
                                width:ListView.view.width; height:76; radius:7; color:root.bg; border.color:root.line
                                Rectangle { width:16;height:16;radius:8;anchors.left:parent.left;anchors.leftMargin:8;anchors.top:parent.top;anchors.topMargin:10;color:modelData.color||"#31d67b";border.color:"white" }
                                Column {
                                    anchors.left:parent.left; anchors.leftMargin:31; anchors.right:parent.right; anchors.rightMargin:6; anchors.top:parent.top; anchors.topMargin:7
                                    Label { width:parent.width; text:modelData.name||"Loc pescuit"; color:root.text; font.bold:true; elide:Text.ElideRight }
                                    Label { width:parent.width; text:Number(modelData.lat).toFixed(5)+", "+Number(modelData.lon).toFixed(5); color:root.muted; font.pixelSize:9; elide:Text.ElideRight }
                                }
                                Row {
                                    anchors.left:parent.left;anchors.leftMargin:8;anchors.bottom:parent.bottom;anchors.bottomMargin:5;spacing:4
                                    Button { height:34; width:36; padding:2; ToolTip.visible:hovered; ToolTip.text:"Navighează"; contentItem:Image{anchors.centerIn:parent;width:20;height:20;source:"qrc:/qml/NavoSmart/icons/navigate.svg"} onClicked:root.navigateToCoordinate(QtPositioning.coordinate(Number(modelData.lat),Number(modelData.lon))) }
                                    Button { height:34; width:36; padding:2; ToolTip.visible:hovered; ToolTip.text:"Editează"; contentItem:Image{anchors.centerIn:parent;width:20;height:20;source:"qrc:/qml/NavoSmart/icons/edit.svg"} onClicked:fishingPageRoot.openEdit(modelData) }
                                    Button { height:34; width:36; padding:2; ToolTip.visible:hovered; ToolTip.text:"Nădire aici"; contentItem:Image{anchors.centerIn:parent;width:20;height:20;source:"qrc:/qml/NavoSmart/icons/bait.svg"} onClicked:{baitingController.targetWaypoint={coordinate:QtPositioning.coordinate(Number(modelData.lat),Number(modelData.lon)),name:modelData.name,sequenceNumber:0};root.activePage=8;root.lastNavigationStatus="Punct de nădire ales: "+modelData.name} }
                                    Button { height:34; width:36; padding:2; ToolTip.visible:hovered; ToolTip.text:"Șterge punct"; contentItem:Image{anchors.centerIn:parent;width:20;height:20;source:"qrc:/qml/NavoSmart/icons/delete.svg"} onClicked:{fishingSpots.removeSpot(modelData.id);scanCoordinator.checkpoint("fishing-spot-delete")} }
                                }
                            }
                        }
                    }
                }
            }
            function openEdit(spot) {
                spotEditId=spot.id; spotName.text=spot.name||""; spotEditColor=spot.color||"#31d67b"; spotEditDialog.open()
            }
            Dialog {
                id:spotEditDialog; parent:Overlay.overlay; anchors.centerIn:parent; modal:true
                title:"Editează punct"; standardButtons:Dialog.Save|Dialog.Cancel
                Column {
                    spacing:8
                    TextField { palette.text:"#0b1118"; palette.base:"#ffffff"; palette.placeholderText:"#5f6b76"; palette.highlight:"#21b7ff"; palette.highlightedText:"#ffffff"; id:spotName; width:280; placeholderText:"Lanseta verde" }
                    Label { text:"Culoare marker" }
                    Row {
                        spacing:8
                        Repeater {
                            model:["#31d67b","#ef4444","#3b82f6","#facc15","#a855f7","#f97316"]
                            delegate:Rectangle {
                                required property var modelData
                                width:30;height:30;radius:15;color:modelData
                                border.color:fishingPageRoot.spotEditColor===modelData?"white":"#607080"
                                border.width:fishingPageRoot.spotEditColor===modelData?3:1
                                MouseArea { anchors.fill:parent; onClicked:fishingPageRoot.spotEditColor=modelData }
                            }
                        }
                    }
                }
                onAccepted:{
                    if(fishingSpots.renameSpot(fishingPageRoot.spotEditId,spotName.text))
                        fishingSpots.setSpotColor(fishingPageRoot.spotEditId,fishingPageRoot.spotEditColor)
                    scanCoordinator.checkpoint("fishing-spot-edit")
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
            onWaypointNameChanged: function(sequence, friendlyName) { persistence.setWaypointName(sequence, friendlyName); scanCoordinator.checkpoint("waypoint-name") }
        }
    }

    Component {
        id: lakesPage
        Item {
            Rectangle { anchors.fill: parent; radius: 8; color: root.panel; border.color: root.line }
            ColumnLayout {
                anchors.fill: parent; anchors.margins: root.compactUi ? 8 : 16; spacing: root.responsiveGap
                Label { text: "BALȚILE MELE"; color: root.text; font.pixelSize: root.compactUi ? 16 : 20; font.bold: true }
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
                    TextField {
                        id: inlineLakeName
                        Layout.fillWidth: true
                        placeholderText: "Nume baltă nouă"
                        color: "#0b1118"
                        placeholderTextColor: "#5f6b76"
                        selectionColor: "#21b7ff"
                        selectedTextColor: "#ffffff"
                        palette.text: "#0b1118"
                        palette.base: "#ffffff"
                        palette.placeholderText: "#5f6b76"
                        palette.highlight: "#21b7ff"
                        palette.highlightedText: "#ffffff"
                        background: Rectangle {
                            color: "#ffffff"
                            border.color: inlineLakeName.activeFocus ? "#21b7ff" : "#c7d0d8"
                            border.width: inlineLakeName.activeFocus ? 2 : 1
                            radius: 2
                        }
                        onAccepted: {
                            addLakeButton.clicked()
                            focus = false
                        }
                    }
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
                    Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: 5
                    model: persistence.lakes
                    delegate: Rectangle {
                        required property var modelData
                        width: ListView.view.width; height: 48; radius: 7
                        color: root.bg; border.color: root.line
                        RowLayout {
                            anchors.fill: parent; anchors.margins: 4; spacing: 4
                            Button {
                                Layout.fillWidth: true
                                text: modelData.name || "Baltă"
                                flat: true
                                contentItem: Label {
                                    text: parent.text
                                    color: root.text
                                    font.bold: true
                                    verticalAlignment: Text.AlignVCenter
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                }
                                background: Rectangle {
                                    radius: 6
                                    color: parent.hovered ? "#183248" : "transparent"
                                    border.color: parent.hovered ? root.accent : "transparent"
                                }
                                onClicked: {
                                    myLakesPopup.selectLake(modelData)
                                    myLakesPopup.open()
                                }
                            }
                            Button {
                                text: "NUME"
                                onClicked: {
                                    myLakesPopup.open()
                                    myLakesPopup.beginRename(modelData)
                                }
                            }
                            Button {
                                text: "ȘTERGE"
                                onClicked: {
                                    myLakesPopup.open()
                                    myLakesPopup.beginDelete(modelData)
                                }
                            }
                        }
                    }
                }
                Button {
                    Layout.alignment: Qt.AlignLeft
                    Layout.preferredWidth: 172
                    Layout.preferredHeight: 36
                    flat: true
                    ToolTip.visible: hovered
                    ToolTip.text: "Deschide managerul Bălțile mele"
                    background: Rectangle {
                        radius: 8
                        color: parent.hovered ? "#153047" : "#0b1a27"
                        border.color: parent.hovered ? root.accent : root.line
                    }
                    contentItem: Row {
                        spacing: 8
                        anchors.centerIn: parent
                        Image { width:22; height:22; source:"qrc:/qml/NavoSmart/icons/lake.svg"; fillMode:Image.PreserveAspectFit }
                        Label { text:"Deschide Bălțile mele"; color:root.accent; font.pixelSize:11; font.bold:true; anchors.verticalCenter:parent.verticalCenter }
                    }
                    onClicked: myLakesPopup.open()
                }
            }
            NavoMyLakes {
                id: myLakesPopup
                persistence: root.lakePersistence
                scanCoordinator: root.areaCoordinator
                onLakeRestored: function(lakeId) {
                    missionUploader.invalidate()
                    root.lastNavigationStatus = "Balta restaurată • datele salvate sunt active"
                }
                onOpenLakeMap: function(lakeId) {
                    root.activePage = 0
                    root.lastNavigationStatus = "Balta încărcată • hartă, sonar, puncte și Area Scan restaurate"
                }
                onOpenLakeBathymetry: function(lakeId) {
                    root.activePage = 7
                    root.lastNavigationStatus = "Balta încărcată • hartă batimetrică restaurată"
                }
                onOpenLakeFishingSpots: function(lakeId) {
                    root.activePage = 3
                    root.lastNavigationStatus = "Balta încărcată • punctele de pescuit restaurate"
                }
                onResumeLakeScan: function(lakeId) {
                    root.activePage = 2
                    var mission=scanCoordinator.resume()
                    if(mission && mission.length) root.lastNavigationStatus = "Resume pregătit • "+mission.length+" WP • verifică și încarcă misiunea"
                    else root.lastNavigationStatus = "Resume indisponibil • "+areaScanController.lastError
                }
            }
        }
    }

    Component {
        id: baitingPage
        Item {
            RowLayout {
                anchors.fill: parent
                spacing: 8
                Rectangle {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    radius: 8; color: root.panel; border.color: root.line; clip: true
                    NavoMap {
                routeActive:routePlan.active
                routeStops:routePlan.active ? routePlan.runningStops : routePlan.stops
                routeReturnsHome:(routePlan.active ? routePlan.runningFinishAction : routePlan.finishAction)==="RTL"
                recordedReplay: sonar.replayMode
                        anchors.fill: parent; anchors.margins: 2
                        vehicle: root.vehicle
                        planController: root.planController
                        waypointNames: root.waypointNames
                        fishModel: fishStore
                        fishingSpotsModel: fishingSpots
                        nativeSurfaceMesh: root.displayNativeSurfaceMesh
                        nativeSurfaceBridge: sonar.nativeBridge
                bathymetryCells: root.displayBathymetryCells
                        replayPreview: sonar.replayMode || (!root.vehicle && sonarMapping.trackCoordinates.length>0)
                        replayTrack: sonar.replayMode ? replayMapping.trackCoordinates : sonarMapping.trackCoordinates
                        baitingController: root.mapBaitingController
                        areaScanController: root.mapAreaScanController
                        savedDepthM: root.depthM
                        savedWaterTempC: root.waterTempC
                        maximized: root.mapMaximized
                        baitPointPickMode: root.pendingBaitPointPick
                        onBaitPointPicked: function(coordinate) {
                            root.pendingBaitPointPick=false
                            baitingController.targetWaypoint={coordinate:coordinate,name:"Punct hartă",sequenceNumber:0}
                            root.lastNavigationStatus="Punct de nădire selectat pe hartă"
                        }
                        onBaitingWaypointSelected: function(wp) {
                            baitingController.targetWaypoint=wp
                            root.lastNavigationStatus="Punct de nădire selectat: "+(wp.name||"Punct")
                        }
                        onSaveNamedPointRequested: function(coordinate,name,markerColor) {
                            if(!root.requireActiveLakeForPointSave()) return
                            fishingSpots.saveSpot(coordinate,NaN,NaN,name,"Punct ales pe hartă",null,markerColor)
                        }
                        onFishingSpotRenameRequested: function(spot) { root.lastNavigationStatus="Redenumirea punctului este disponibilă în PUNCTE PESCUIT" }
                        onNavigateRequested: function(c) { root.navigateToCoordinate(c) }
                        onMaximizeRequested: root.mapMaximized=!root.mapMaximized
                    }
                }
                Rectangle {
                    Layout.preferredWidth: root.compactUi ? 245 : Math.min(340,parent.width*0.27)
                    Layout.minimumWidth: 230; Layout.maximumWidth: 340
                    Layout.fillHeight: true
                    radius: 8; color: root.panel; border.color: root.line
                    NavoBaitingPanel {
                        anchors.fill: parent
                        anchors.margins: 8
                        controller: baitingController
                        routePlan:root.routePlanController; routeEstimate:root.routeEstimate; routeEnergyText:root.routeEnergyText
                        onRouteStartRequested:function(loaded){root.startRoute(loaded)}
                        onRouteStopRequested:root.stopMission()
                        hopperBridge: root.hopperBridgeController
                        waypoint: baitingController.targetWaypoint
                        availableSpots: sonar.replayMode ? [] : fishingSpots.fishingSpots
                        onChooseOnMapRequested: {
                            if(!root.allowLiveAction()) return;
                            root.pendingBaitPointPick=true
                            root.lastNavigationStatus="Atinge harta din stânga pentru punctul de nădire"
                        }
                        onSpotChosen: function(spot) {
                            if(!root.allowLiveAction()) return;
                            var coordinate=QtPositioning.coordinate(Number(spot.lat),Number(spot.lon))
                            if(!coordinate.isValid){root.lastNavigationStatus="Locul salvat nu are coordonate valide";return}
                            baitingController.targetWaypoint={coordinate:coordinate,name:spot.name,sequenceNumber:0}
                            root.lastNavigationStatus="Punct de nădire ales: "+spot.name
                        }
                        onStartConfirmed: function(waypoint,name,hopper) {
                            root.startBaiting(waypoint,name,hopper)
                        }
                        onAbortRequested:root.stopMission()
                    }
                }
            }
        }
    }

    Component {
        id: failsafePage
        Item {
            Rectangle { anchors.fill:parent; radius:8; color:root.panel; border.color:root.line }
            RowLayout {
                anchors.fill:parent; anchors.margins:root.responsiveMargin; spacing:root.responsiveGap
                ColumnLayout {
                    Layout.fillWidth:true; Layout.fillHeight:true; Layout.preferredWidth:1
                    NavoFailsafePanel {
                        Layout.fillWidth:true
                        Layout.alignment:Qt.AlignTop
                        controller:failsafeController
                    }
                    Label {
                        Layout.fillWidth:true; wrapMode:Text.WordWrap; color:root.muted; font.pixelSize:11
                        text:"Link G20: HOLD după timpul configurat. GPS: așteaptă recuperarea; HOME/RTL este cerut numai după revenirea unei poziții GPS valide."
                    }
                    Item { Layout.fillHeight:true }
                }
                Rectangle {
                    Layout.fillWidth:true; Layout.fillHeight:true; Layout.preferredWidth:1
                    radius:8; color:root.bg; border.color:root.line
                    ColumnLayout {
                        anchors.fill:parent; anchors.margins:root.compactUi ? 7 : 9; spacing:root.compactUi ? 4 : 6
                        Label { text:"CUVE & SIGURANȚĂ HARDWARE"; color:"#f4f7fb"; font.pixelSize:15; font.bold:true }
                        GridLayout {
                            columns:3; Layout.fillWidth:true; columnSpacing:root.compactUi ? 5 : 7; rowSpacing:root.compactUi ? 3 : 5
                            Label { text:"Cuva"; color:root.text } Label { text:"Stânga"; color:root.text } Label { text:"Dreapta"; color:root.text }
                            Label { text:"Ieșire"; color:"#dbe5ee"; font.bold:true }
                            SpinBox { Layout.fillWidth:true; Layout.minimumWidth:86; from:1;to:16;value:hopperSettings.leftOutput;onValueModified:{hopperSettings.confirmed=false;hopperSettings.leftOutput=value} }
                            SpinBox { Layout.fillWidth:true; Layout.minimumWidth:86; from:1;to:16;value:hopperSettings.rightOutput;onValueModified:{hopperSettings.confirmed=false;hopperSettings.rightOutput=value} }
                            Label { text:"Închis µs"; color:"#dbe5ee"; font.bold:true }
                            SpinBox { Layout.fillWidth:true; Layout.minimumWidth:86; from:900;to:2100;value:hopperSettings.leftClosed;onValueModified:{hopperSettings.confirmed=false;hopperSettings.leftClosed=value} }
                            SpinBox { Layout.fillWidth:true; Layout.minimumWidth:86; from:900;to:2100;value:hopperSettings.rightClosed;onValueModified:{hopperSettings.confirmed=false;hopperSettings.rightClosed=value} }
                            Label { text:"Deschis µs"; color:"#dbe5ee"; font.bold:true }
                            SpinBox { Layout.fillWidth:true; Layout.minimumWidth:86; from:900;to:2100;value:hopperSettings.leftOpen;onValueModified:{hopperSettings.confirmed=false;hopperSettings.leftOpen=value} }
                            SpinBox { Layout.fillWidth:true; Layout.minimumWidth:86; from:900;to:2100;value:hopperSettings.rightOpen;onValueModified:{hopperSettings.confirmed=false;hopperSettings.rightOpen=value} }
                        }
                        CheckBox {
                            Layout.fillWidth:true
                            text:"Am verificat mecanic calibrarea cuvelor"
                            palette.text:"#f4f7fb"
                            contentItem: Label {
                                leftPadding: parent.indicator.width + parent.spacing
                                text: parent.text
                                color: "#f4f7fb"
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                            }
                            checked:hopperSettings.confirmed
                            enabled: true
                            ToolTip.visible: hovered
                            ToolTip.text: "Confirmarea mecanică este disponibilă și cu Nano offline"
                            onToggled:hopperSettings.confirmed=checked
                        }
                        Rectangle {
                            Layout.fillWidth:true; Layout.preferredHeight:root.compactUi ? 58 : 64; radius:7
                            color:root.panel; border.color:safetyManager.state==="CRITICAL"?root.danger:root.line
                            RowLayout {
                                anchors.fill:parent; anchors.margins:9
                                ColumnLayout {
                                    Label { text:"SENZORI"; color:root.muted; font.pixelSize:10 }
                                    Label { text:nanoTelemetry.connected?"Nano ONLINE":"Nano OFFLINE"; color:nanoTelemetry.connected?root.ok:root.warn; font.bold:true }
                                }
                                Item { Layout.fillWidth:true }
                                ColumnLayout {
                                    Label { text:"TEMP BATERIE"; color:root.muted; font.pixelSize:10 }
                                    Label { text:nanoTelemetry.connected&&!isNaN(nanoTelemetry.batteryTempC)?Number(nanoTelemetry.batteryTempC).toFixed(1)+" °C":"--"; color:root.text; font.bold:true }
                                }
                                ColumnLayout {
                                    Label { text:"APĂ"; color:root.muted; font.pixelSize:10 }
                                    Label { text:nanoTelemetry.waterDetected?"DETECTATĂ":"OK"; color:nanoTelemetry.waterDetected?root.danger:(nanoTelemetry.connected?root.ok:root.muted); font.bold:true }
                                }
                            }
                        }
                        Item { Layout.fillHeight:true }
                    }
                }
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
                samples: sonar.replayMode ? replayMapping.rawSamples : sonarMapping.rawSamples
                boatTrack: sonar.replayMode ? replayMapping.trackCoordinates : (sonarMapping.trackCoordinates.length ? sonarMapping.trackCoordinates : root.coordinatesFromSonarSamples(sonarMapping.rawSamples))
                fishingSpots: sonar.replayMode ? [] : root.fishingSpotsController.fishingSpots
                fishDetections: sonar.replayMode ? [] : root.fishDetections
                onOpenSonarRequested: root.activePage = 1
            }
        }
    }

    Component {
        id: cameraPage
        Item {
            Rectangle { anchors.fill: parent; radius: 8; color: "#05080c"; border.color: root.line }
            ColumnLayout {
                anchors.fill: parent; anchors.margins: root.responsiveMargin
                RowLayout { Layout.fillWidth: true
                    Label { text: "CAMERA FAȚĂ • LAN"; color: root.text; font.pixelSize: 18; font.bold: true }
                    Item { Layout.fillWidth: true }
                    Label { text: cameraEthernet.connected ? (cameraEthernet.dataAlive ? "LAN LIVE" : "LAN CONECTAT") : "LAN OFFLINE"; color: cameraEthernet.dataAlive ? root.ok : (cameraEthernet.connected ? root.warn : root.muted); font.bold: true; font.pixelSize: 10 }
                }
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
            ScrollView {
                id: settingsScroll
                contentWidth: availableWidth
                anchors.fill: parent
                anchors.margins: root.responsiveMargin
                clip: true
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ScrollBar.vertical.policy: contentHeight > availableHeight ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff

                ColumnLayout {
                    width: settingsScroll.availableWidth
                    spacing: root.responsiveGap
                    Button {
                        Layout.maximumWidth: 230
                        text: g20Advanced.visible ? "Închide Avansat • G20" : "Avansat • integrare G20"
                        onClicked: g20Advanced.visible = !g20Advanced.visible
                    }
                    NavoG20Settings {
                        id: g20Advanced
                        visible: false
                        Layout.fillWidth: true
                        Layout.preferredHeight: implicitHeight
                        controller: g20Controller
                    }
                    NavoSteeringPanel {
                        Layout.fillWidth:true
                        controller:steeringAssist
                        onEnableRequested:steeringAssist.enable()
                    }
                    NavoEthernetSettings {
                        id: ethernetSettings
                        Layout.fillWidth: true
                        Layout.preferredHeight: implicitHeight
                        sonar: root.sonarController
                        camera: cameraEthernet
                        onCameraStreamUrlChanged: root.cameraStreamUrl = cameraStreamUrl
                        onCameraProtocolChanged: root.cameraProtocol = cameraProtocol
                        onStatus: function(text) { root.lastNavigationStatus=text }
                        onUnitsRequested: { if (typeof mainWindow !== "undefined" && mainWindow.showSettingsTool) mainWindow.showSettingsTool() }
                    }
                    GroupBox {
                        title:"Rezervă energie • traseu + întoarcere HOME"
                        Layout.fillWidth:true
                        ColumnLayout {
                            anchors.fill:parent
                            Label { Layout.fillWidth:true;wrapMode:Text.WordWrap;color:root.muted;text:"Activează verificarea numai după măsurarea consumului pe barcă. Estimarea verifică navigarea, nădirea și START Area Scan; nu comandă automat RTL." }
                            GridLayout {
                                columns:2;Layout.fillWidth:true
                                Label { text:"Rezervă %";color:root.text }
                                SpinBox { Layout.fillWidth:true;from:5;to:80;value:energySettings.reservePercent;onValueModified:{energySettings.confirmed=false;energySettings.reservePercent=value} }
                                Label { text:"Consum %/km";color:root.text }
                                SpinBox { Layout.fillWidth:true;from:1;to:100;value:energySettings.consumptionPercentPerKm;onValueModified:{energySettings.confirmed=false;energySettings.consumptionPercentPerKm=value} }
                            }
                            CheckBox { text:"Consum verificat • activează verificarea înainte de plecare";checked:energySettings.confirmed;onToggled:energySettings.confirmed=checked }
                        }
                    }
                }
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


    component StatusPill: Rectangle {
        property url iconSource: ""
        property string title: ""
        property string value: "--"
        property bool good: false
        property bool interactive: false
        signal clicked()
        signal pressAndHold()
        property real pillWidth: 72
        Layout.preferredWidth: pillWidth; Layout.preferredHeight: 36; radius: 7
        color: root.panel; border.color: good ? root.ok : root.line
        MouseArea { id:pillMouse; anchors.fill:parent; enabled:parent.interactive; hoverEnabled:true; cursorShape:parent.interactive?Qt.PointingHandCursor:Qt.ArrowCursor; pressAndHoldInterval:1600; onClicked:parent.clicked(); onPressAndHold:parent.pressAndHold() }
        Row { anchors.centerIn:parent; spacing:5
            Image { width:20;height:20;anchors.verticalCenter:parent.verticalCenter;source:iconSource;fillMode:Image.PreserveAspectFit }
            Column { anchors.verticalCenter:parent.verticalCenter; spacing:0
                Label { anchors.horizontalCenter:parent.horizontalCenter;text:title;color:root.muted;font.pixelSize:7 }
                Label { anchors.horizontalCenter:parent.horizontalCenter;text:value;color:good?root.ok:root.text;font.pixelSize:10;font.bold:true }
            }
        }
    }

    component NavButton: Button {
        Accessible.name: text
        property bool active: false
        property bool proBadge: false
        property url iconSource: ""
        ToolTip.visible: hovered
        ToolTip.text: text
        Layout.fillWidth: true
        Layout.preferredHeight: Math.max(38, Math.min(46, (sidebar.height - 58) / 9))
        background: Rectangle { radius: 6; color: parent.active ? "#183248" : "transparent"; border.color: parent.active ? root.accent : "transparent" }
        contentItem: Item {
            Image {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: parent.parent.proBadge ? -5 : 0
                width: parent.parent.proBadge ? 27 : 32
                height: parent.parent.proBadge ? 27 : 32
                source: parent.parent.iconSource
                fillMode: Image.PreserveAspectFit
            }
            Rectangle {
                visible: parent.parent.proBadge
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 1
                width: 31; height: 13; radius: 3
                color: parent.parent.active ? "#21b7ff" : "#103c51"
                border.color: "#21b7ff"
                Label {
                    anchors.centerIn: parent
                    text: "PRO"; font.pixelSize: 9; font.bold: true
                    color: parent.parent.active ? "#061824" : "#e1faff"
                }
            }
        }
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
