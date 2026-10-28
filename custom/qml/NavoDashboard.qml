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
    readonly property string activePageName: ["HARTA","SONAR","MISIUNI","PUNCTE PESCUIT","BALȚILE MELE","CAMERA","SETARI","3D","NĂDIRE","SIGURANȚĂ","SONAR PRO","JURNAL","HĂRȚI OFFLINE"][activePage] || "HARTA"
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
    readonly property var settingsAlertsController: alerts
    readonly property var mapBaitingController: baitingController
    readonly property var mapAreaScanController: areaScanController

    PlanMasterController {
        id: _planController
        flyView: true
        Component.onCompleted: start()
    }

    NavoPersistence { id: persistence }
    NavoAlertAudio { id:alertAudio;volume:alerts.volume }
    NavoAlerts {
        id:alerts;output:alertAudio;vehicle:root.vehicle;replayMode:sonar.replayMode
        telemetryConnected:h743Telemetry.connected
        waterValid:h743Telemetry.waterValid
        temperatureValid:h743Telemetry.temperatureValid
        waterConfirmed:safetyManager.waterConfirmed
        batteryTempC:h743Telemetry.batteryTempC
        batteryPercent:root.battery && root.battery.percentRemaining ? Number(root.battery.percentRemaining.rawValue) : NaN
        gpsHealthy:failsafeController.gpsHealthy()
        linkHealthy:failsafeController.linkHealthy()
    }
    Connections {
        target:baitingController
        function onCycleFinished(success,message){if(success)alerts.notify("bait-cycle","Ciclul de nădire s-a încheiat",false)}
    }
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
        property int requestSequence: 0
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
        if(persistence) root.pendingBaitJournalEvents=persistence.pendingBaitJournalEvents()
        if(endpointSettings.connectOnStartup && sonar.host.length && sonar.port>0) sonar.connectSonar()
        for(var i=0;i<persistence.lakes.length;i++) {
            var lake=persistence.lakes[i]
            if(lake.id===sessionSettings.activeLakeId) { scanCoordinator.activateLake(lake.id,lake.name); break }
        }
    }
    NavoAreaScan { id: areaScanController }
    // Snapshot each accepted release command immediately. Do not overwrite events while
    // the user is deciding whether to start a fishing trip.
    property var pendingBaitJournalEvents: []
    property int baitJournalSequence: 0
    property bool baitJournalFlushBusy: false
    readonly property int pendingBaitJournalCount: pendingBaitJournalEvents.length
    function persistPendingBaitJournal(events) {
        if(!persistence || !persistence.storePendingBaitJournalEvents(events))return false
        root.pendingBaitJournalEvents=events
        return true
    }
    Dialog {
        id: baitJournalTripDialog
        parent: Overlay.overlay
        anchors.centerIn: parent
        modal: true
        title: "Jurnal nădire automată"
        standardButtons: Dialog.Yes | Dialog.No
        Label {
            width: Math.min(340, root.width-60)
            wrapMode: Text.WordWrap
            text: "Ai "+root.pendingBaitJournalEvents.length+" comenzi de nădire neînregistrate. Creezi o partidă pentru balta selectată și le salvezi? Nu se repetă eliberarea nadei."
        }
        onAccepted: root.flushPendingBaitJournal(true)
        onRejected: {
            // Declining to create a trip must not erase accepted hopper commands.
            // Keep the durable queue for recovery from the Journal page.
            root.lastNavigationStatus="Jurnal: nădirile sunt păstrate; le poți recupera ulterior"
        }
    }
    function retryPendingBaitJournal() {
        if(!root.pendingBaitJournalEvents.length)return true
        var success=root.flushPendingBaitJournal(false)
        if(root.pendingBaitJournalEvents.length && !baitJournalTripDialog.visible)baitJournalTripDialog.open()
        return success
    }
    function activeBaitJournalTrip(lakeId) {
        var trips=persistence ? (persistence.fishingTrips || []) : []
        for(var i=0;i<trips.length;i++) if(!trips[i].endedAt && trips[i].lakeId===lakeId)return trips[i]
        return null
    }
    function flushPendingBaitJournal(allowCreate) {
        if(root.baitJournalFlushBusy || !persistence)return false
        var queue=root.pendingBaitJournalEvents.slice()
        if(!queue.length)return true
        root.baitJournalFlushBusy=true
        var remaining=[], failed=false, tripCache=({})
        for(var i=0;i<queue.length;i++) {
            var event=queue[i]
            var trip=tripCache[event.lakeId] || root.activeBaitJournalTrip(event.lakeId)
            if(!trip && allowCreate && event.lakeId===scanCoordinator.lakeId) {
                var tripId=persistence.startFishingTrip(event.lakeId,event.lakeName || "Partidă de pescuit")
                if(tripId)trip={id:tripId,lakeId:event.lakeId}
            }
            if(trip)tripCache[event.lakeId]=trip
            if(!trip || !persistence.saveFishingEntry(trip.id,event.entry)) {
                remaining.push(event);failed=true
            }
        }
        if(!root.persistPendingBaitJournal(remaining.concat(root.pendingBaitJournalEvents.slice(queue.length))))failed=true
        root.baitJournalFlushBusy=false
        if(failed)root.lastNavigationStatus="Jurnal: "+remaining.length+" nădiri nesalvate; păstrate în sesiune pentru reîncercare"
        return !failed
    }
    function recordAutomaticBaiting(hopper, outcome) {
        if(sonar.replayMode || !scanCoordinator.lakeId || !persistence)return false
        var lakeId=scanCoordinator.lakeId
        var hopperName=hopper===1 ? "stânga" : hopper===2 ? "dreapta" : hopper===3 ? "ambele" : "fără cuvă"
        var message="Nădire automată • "+(baitingController.targetName||"punct fără nume")+" • cuva "+hopperName+" • "+outcome+" • Nadă folosită: de completat"
        var entry={type:"bait",text:message}
        if(root.vehicle && root.vehicle.coordinate && root.vehicle.coordinate.isValid && root.linkAlive && root.vehicle.gps && Number(root.vehicle.gps.lock.rawValue)>=3) {
            entry.positionValid=true;entry.lat=root.vehicle.coordinate.latitude;entry.lon=root.vehicle.coordinate.longitude
        }
        if(isFinite(root.depthM) && root.depthM>0)entry.depth=root.depthM
        if(isFinite(root.waterTempC))entry.temperature=root.waterTempC
        entry.clientEventId="bait-"+Date.now().toString(36)+"-"+(++root.baitJournalSequence).toString(36)+"-"+Math.random().toString(36).slice(2)
        var event={sequence:root.baitJournalSequence,lakeId:lakeId,lakeName:scanCoordinator.lakeName,entry:entry}
        if(!root.persistPendingBaitJournal(root.pendingBaitJournalEvents.concat([event])))return false
        if(root.activeBaitJournalTrip(lakeId))return root.flushPendingBaitJournal(false)
        if(!baitJournalTripDialog.visible)baitJournalTripDialog.open()
        return false
    }
    NavoBaitingController {
        id: baitingController
        vehicle: root.vehicle
        releaseComplete: hopperBridge.onboardCycleComplete && h743Telemetry.hopperStateValid && h743Telemetry.hopperMask===0
        onGotoRequested: function(coordinate, reason) { if(root.vehicle && root.vehicle.guidedModeGotoLocation) root.vehicle.guidedModeGotoLocation(coordinate) }
        onSpeedRequested: function(metersPerSecond) {
            if(root.vehicle && root.vehicle.guidedModeChangeGroundSpeedMetersSecond)
                root.vehicle.guidedModeChangeGroundSpeedMetersSecond(metersPerSecond)
        }
        onStopRequested: function(reason) { root.holdMission(true); root.lastNavigationStatus="Nădire: "+reason }
        onHopperReleaseRequested: function(hopper) {
            if(!hopperBridge.release(hopper))
                baitingController.abortCycle("Cuva nu a putut fi comandată")
            else root.recordAutomaticBaiting(hopper, "comandă de eliberare trimisă; confirmarea fizică nu este disponibilă")
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
    property bool directGotoActive: false
    property int areaDrawingGeneration: 0
    readonly property bool rtlActive: root.pendingModeLabel==="RTL" && root.pendingMode.length>0 ||
        ["RTL","SMARTRTL","SMART_RTL"].indexOf(String(root.flightMode).toUpperCase())>=0 ||
        (!!root.vehicle && !!root.vehicle.rtlFlightMode && String(root.flightMode).toUpperCase()===String(root.vehicle.rtlFlightMode).toUpperCase())
    readonly property bool actionActive: root.missionBusy || root.directGotoActive || root.rtlActive ||
        root.pendingMode.length>0 || ["AUTO","GUIDED"].indexOf(String(root.flightMode).toUpperCase())>=0
    readonly property bool canClearArea: !sonar.replayMode && !root.actionActive &&
        ["READY","RESUME_READY","RTL"].indexOf(scanCoordinator.state)<0 &&
        (!sonarMapping.scanning || sonarMapping.paused) && !root.awaitingMissionStart && !missionUploader.uploadInProgress &&
        !(root.planController && (root.planController.syncInProgress ||
          (root.planController.missionController && root.planController.missionController.syncInProgress)))
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
        libraryAvailable:scanCoordinator.lakeId.length>0 && !root.sonarController.replayMode && !baitingController.enabled && scanCoordinator.state!=="SCANNING" && !root.awaitingMissionStart
        persistLibrary:function(){return scanCoordinator.checkpoint("mission-library")}
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
    property bool preLaunchBatteryOverride: false
    NavoPreLaunchCheck {
        id: preLaunchCheck
        nanoReady: h743Telemetry.connected
        sensorLabel: "H743 / V3"
        vehicleConnected: root.linkAlive
        gpsReady: !!root.vehicle && !!root.vehicle.gps && Number(root.vehicle.gps.lock.rawValue) >= 3 && !!root.vehicle.coordinate && root.vehicle.coordinate.isValid
        homeReady: !!root.vehicle && !!root.vehicle.homePosition && root.vehicle.homePosition.isValid
        batteryReady: root.preLaunchBatteryOverride || (!!root.battery && !!root.battery.percentRemaining && isFinite(Number(root.battery.percentRemaining.rawValue)) && Number(root.battery.percentRemaining.rawValue) > 20)
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
    // App-side energy warning/RTL only with valid live telemetry and calibrated model.
    property bool energyRtlIssued: false
    property var energyRtlVehicle: null
    Timer {
        interval: 3000
        repeat: true
        running: energyGuard.calibrated && root.linkAlive
        onTriggered: {
            if(root.energyRtlVehicle!==root.vehicle){root.energyRtlVehicle=root.vehicle;root.energyRtlIssued=false}
            // Do not override a pilot-selected manual mode with an app-side energy RTL.
            if(!root.missionBusy || root.flightMode==="MANUAL" || root.flightMode==="ACRO" ||
               root.pendingModeLabel==="RTL" ||
               (root.vehicle && root.vehicle.rtlFlightMode && root.flightMode===root.vehicle.rtlFlightMode))return
            if(!root.vehicle || !root.vehicle.homePosition || !root.vehicle.homePosition.isValid ||
               !root.vehicle.coordinate || !root.vehicle.coordinate.isValid ||
               !root.vehicle.gps || Number(root.vehicle.gps.lock.rawValue)<3 ||
               !root.battery || !root.battery.percentRemaining)return
            var percent=Number(root.battery.percentRemaining.rawValue)
            var distance=root.vehicle.coordinate.distanceTo(root.vehicle.homePosition)
            if(!isFinite(percent) || percent<0 || percent>100 || !isFinite(distance) || distance<0)return
            var required=energyGuard.requiredPercent(distance)
            if(!isFinite(required))return
            if(percent<=required && !root.energyRtlIssued) {
                if(root.rtlMission())root.energyRtlIssued=true
                else root.lastNavigationStatus="ENERGIE CRITICĂ • RTL indisponibil; verifică H743"
            }
        }
    }
    NavoFailsafeController {
        id: failsafeController
        vehicle: root.vehicle
        onHoldRequested: function(reason) {
            if (root.manualControlActive()) {
                root.lastNavigationStatus="MANUAL/ACRO • GPS HOLD aplicație ignorat • verifică H743: "+reason
                return
            }
            root.lastNavigationStatus="FAILSAFE HOLD: "+reason
            if (scanCoordinator.state === "SCANNING") scanCoordinator.pause(reason)
            root.holdMission()
        }
        onRtlRequested: function(reason) {
            if (root.manualControlActive()) {
                root.lastNavigationStatus="MANUAL/ACRO • GPS RTL aplicație ignorat • verifică H743: "+reason
                return
            }
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
            commandH743Light(2,boatActive?1:0,"Poziții AUTO")
        }
    }
    function setPositionLightMode(mode) {
        lightSettings.positionMode=mode
        if(mode==="AUTO") { lastAutoPositionState=boatActive; commandH743Light(2,boatActive?1:0,"Poziții AUTO") }
        else commandH743Light(2,mode==="ON"?1:0,"Poziții")
    }
    property bool awaitingMissionStart: false
    property string areaScanFinishAction: "HOLD"
    onVehicleChanged: { directGotoActive=false; if(routePlan && routePlan.active) routePlan.cancel("Autopilot schimbat"); proBoatTrack=[]; awaitingMissionStart=false; if(baitingController && baitingController.enabled) baitingController.abortCycle("Autopilot schimbat"); if(scanCoordinator && scanCoordinator.state==="SCANNING") scanCoordinator.pause("Autopilot schimbat") }
    property string pendingMode: ""
    property string pendingModeLabel: ""
    Timer {
        interval: 10000; running: root.pendingMode.length>0; repeat: false
        onTriggered: { root.lastNavigationStatus=root.pendingModeLabel+" fără confirmare autopilot"; root.pendingMode="" }
    }
    onFlightModeChanged: {
        if(String(flightMode).toUpperCase()!=="GUIDED") directGotoActive=false
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
    function manualControlActive(){
        var mode=String(root.flightMode || "").trim().toUpperCase()
        return mode==="MANUAL" || mode==="ACRO"
    }
    property real distanceToHome: vehicle && vehicle.distanceToHome ? vehicle.distanceToHome.rawValue : 0
    property real distanceToTarget: vehicle && vehicle.distanceToGoal ? vehicle.distanceToGoal.rawValue : 0
    property string boatId: "NAV0001"
    property int activePage: 0
    property bool showHomeCredit: false
    property bool hopperStatusExpanded: false
    property bool mapFullscreen: false
    property bool headingOverlayOpen: false
    property var offlineRegion: ({})
    property var offlineViewRequest: null
    function openOfflineMaps(region) { offlineRegion=region;mapMaximized=false;activePage=12 }
    function showOfflineRegion(region,mapType) {
        var providers=QGroundControl.mapEngineManager.mapProviderList
        for(var i=0;i<providers.length;i++)if(mapType.indexOf(providers[i]+" ")===0){
            QGroundControl.settingsManager.flightMapSettings.mapProvider.rawValue=providers[i]
            QGroundControl.settingsManager.flightMapSettings.mapType.rawValue=mapType.slice(providers[i].length+1)
            break
        }
        offlineViewRequest=region;activePage=0
        Qt.callLater(function(){if(root.mapController){root.mapController.showOfflineRegion(region);root.offlineViewRequest=null}})
    }
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
    readonly property real headingDeg: gnssHeading.selectedHeadingDeg
    readonly property string headingSource: gnssHeading.headingSource
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

    NavoH743Telemetry {
        id: h743Telemetry
        vehicle: root.vehicle
        v3Profile: true // NAVO V3 receives only NV3* messages from H743
    }
    // Display-only priority: GPS_RAW_INT / GPS2_RAW yaw when valid and fresh;
    // otherwise the H743's normal vehicle.heading. EKF/mode/failsafes untouched.
    NavoGnssHeading {
        id: gnssHeading
        vehicle: root.vehicle
        linkAlive: root.linkAlive
        autopilotHeadingDeg: root.vehicle && root.vehicle.heading &&
            isFinite(Number(root.vehicle.heading.rawValue))
                ? Number(root.vehicle.heading.rawValue) : NaN
    }
    NavoHopperBridge {
        id: hopperBridge
        onboardTiming: h743Telemetry.v3Profile
        hardwareTelemetry: h743Telemetry
        nextRequest: root.nextHardwareRequest
        vehicle: root.vehicle
        calibrated: hopperSettings.confirmed && hopperSettings.leftOutput!==hopperSettings.rightOutput && root.linkAlive
        releaseAllowed: root.linkAlive && hopperSettings.confirmed
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
        telemetryLive: h743Telemetry.connected
        temperatureValid: h743Telemetry.temperatureValid
        waterValid: h743Telemetry.waterValid
        waterSensorFault: h743Telemetry.waterSensorFault
        waterDetected: h743Telemetry.waterDetected
        batteryTempC: h743Telemetry.batteryTempC
        onWarning: function(reason) { root.lastNavigationStatus = "AVERTISMENT: " + reason }
        onHoldRequested: function(reason) {
            if(root.manualControlActive()) {root.lastNavigationStatus="MANUAL/ACRO • alertă senzori: "+reason;return}
            root.lastNavigationStatus = "SIGURANTA HOLD: " + reason
            root.holdMission()
        }
        onRtlRequested: function(reason) {
            if(root.manualControlActive()) {root.lastNavigationStatus="MANUAL/ACRO • alertă senzori: "+reason;return}
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
        if(action==="FAR") { commandH743Light(1,2,"Far"); return }
        if(action==="POZITII") { commandH743Light(2,2,"Poziții"); return }
    }

    function nextHardwareRequest() {
        var current=Math.max(hopperSettings.requestSequence,h743Telemetry.lastRequest)
        if(!Number.isInteger(current) || current<0 || current>=16777215)return 0
        hopperSettings.requestSequence=current+1
        return hopperSettings.requestSequence
    }
    function commandH743Light(target, mode, label) {
        if(!root.linkAlive || !vehicle || !vehicle.sendCommand || root.sonarController.replayMode) {
            root.lastNavigationStatus=label+" indisponibil: H743 deconectat sau replay"
            return false
        }
        if(hopperBridge.commandPending || !h743Telemetry.connected || !(h743Telemetry.capabilities & 1) || !h743Telemetry.lightsValid) {
            root.lastNavigationStatus=label+" indisponibil: serviciul H743/V3 nu este pregătit"
            return false
        }
        if(target!==1 && target!==2)return false
        var desired=mode===2 ? ((target===1 ? h743Telemetry.headlightOn : h743Telemetry.positionLightsOn) ? 0 : 1) : mode
        if(desired!==0 && desired!==1)return false
        var request=root.nextHardwareRequest()
        if(!request)return false
        vehicle.sendCommand(1,31001,true,target,desired,request,0,0,0,0)
        root.lastNavigationStatus=label+" • solicitat H743; fără confirmare fizică"
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
        if(!hopperBridge.closeOnboard())return
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
        if (!preLaunchCheck.navigationReady) { root.lastNavigationStatus = preLaunchCheck.blockingMessage; preLaunchSkipDialog.open(); return false }
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
        return root.cancelCurrentAction()
    }
    function cancelCurrentAction() {
        var liveAllowed=root.allowLiveAction()
        // Stop local producers before callbacks can queue another leg/drop/START.
        root.awaitingMissionStart = false
        root.directGotoActive = false
        root.pendingBaitPointPick = false
        root.pendingAreaDrawMode = "none"
        root.areaDrawingGeneration++
        if(routePlan.active) routePlan.cancel("Acțiune anulată de utilizator")
        if(baitingController.enabled || baitingController.state===baitingController.returnHomeState || baitingController.rampTimer.running)
            baitingController.abortCycle("Nădire anulată de utilizator", true)
        digitalAnchor.release()
        scanCoordinator.cancel("Area Scan anulat de utilizator")
        missionUploader.invalidate()
        root.pendingMode=""; root.pendingModeLabel=""
        if(!liveAllowed) {
            root.lastNavigationStatus="Continuarea locală anulată • replay activ; HOLD netrimis, verifică H743"
            return false
        }
        // Close an already requested release; cancellation cannot undo bait released.
        if(root.linkAlive && (hopperBridge.commandPending || hopperBridge.leftOpen || hopperBridge.rightOpen))
            hopperBridge.closePending()
        if (!root.linkAlive || !vehicle || !vehicle.pauseVehicle) {
            root.lastNavigationStatus = "Acțiunea locală anulată • HOLD netrimis: H743 indisponibil; oprirea bărcii nu este confirmată"
            return false
        }
        vehicle.pauseVehicle()
        root.pendingMode=vehicle.pauseFlightMode; root.pendingModeLabel="ANULARE (HOLD)"
        root.lastNavigationStatus = "Acțiune anulată în aplicație • HOLD trimis; aștept confirmarea H743"
        if(String(vehicle.flightMode).toUpperCase()===String(vehicle.pauseFlightMode).toUpperCase()) {
            root.pendingMode=""
            root.lastNavigationStatus="Acțiune anulată • H743 raportează HOLD"
        }
        return true
    }
    function clearAreaScan() {
        if(!root.canClearArea) { root.lastNavigationStatus="Anulează acțiunea și așteaptă HOLD înainte de ștergerea zonei"; return false }
        if(!scanCoordinator.clearArea()) return false
        missionUploader.invalidate()
        root.pendingAreaDrawMode="none"
        root.areaDrawingGeneration++
        root.lastNavigationStatus="Zona și culoarele Area Scan șterse • măsurătorile sonar păstrate"
        return true
    }
    Dialog {
        id:clearAreaConfirm;objectName:"scanClearConfirm"
        parent:Overlay.overlay;anchors.centerIn:parent;modal:true
        width:Math.min(360,parent.width-24);height:Math.min(226,parent.height-24)
        padding:12;closePolicy:Popup.CloseOnEscape
        title:"Ștergi zona Area Scan?"
        onOpened:clearAreaCancel.forceActiveFocus()
        background:Rectangle { radius:12;color:"#071e30";border.color:"#27cddd" }
        header:Label {
            text:clearAreaConfirm.title;color:"#eff9ff";font.bold:true;font.pixelSize:16
            leftPadding:12;rightPadding:12;topPadding:12;bottomPadding:8
            background:Rectangle { color:"#071e30";radius:12 }
        }
        contentItem:ScrollView {
            id:clearAreaText;clip:true;contentWidth:availableWidth
            ScrollBar.horizontal.policy:ScrollBar.AlwaysOff
            Label {
                width:clearAreaText.availableWidth;wrapMode:Text.WordWrap;color:"#c1d7e6";font.pixelSize:12
                text:"Se șterg chenarul, culoarele și progresul scanării.\n\nMăsurătorile sonar, batimetria și punctele salvate se păstrează."
            }
        }
        footer:Item {
            implicitHeight:54
            RowLayout {
                anchors.fill:parent;anchors.margins:10;spacing:8
                Button {
                    id:clearAreaCancel;objectName:"scanClearCancel";text:"Renunță";Layout.fillWidth:true;implicitHeight:36
                    contentItem:Label { text:parent.text;color:"#eff9ff";horizontalAlignment:Text.AlignHCenter;verticalAlignment:Text.AlignVCenter }
                    background:Rectangle { radius:7;color:parent.down ? "#254b60" : "#142c3c";border.color:parent.activeFocus ? "#67dfdc" : "#316078" }
                    onClicked:clearAreaConfirm.reject()
                }
                Button {
                    objectName:"scanClearAccept";text:"Șterge zona";Layout.fillWidth:true;implicitHeight:36;enabled:root.canClearArea
                    contentItem:Label { text:parent.text;color:parent.enabled ? "#ffffff" : "#9aaebd";horizontalAlignment:Text.AlignHCenter;verticalAlignment:Text.AlignVCenter }
                    background:Rectangle { radius:7;color:parent.down ? "#a72d37" : "#72212b";border.color:"#ff8793";opacity:parent.enabled ? 1 : .45 }
                    onClicked:clearAreaConfirm.accept()
                }
            }
        }
        onAccepted:root.clearAreaScan()
    }
    function saveSonarPoint(pro, entry, name, note, prepare) {
        if(!pro.sonarPointValid(entry) || entry.lakeId!==scanCoordinator.lakeId || !root.requireActiveLakeForPointSave()) {
            pro.pointSaveStatus="Punct indisponibil: GPS/balta sursă trebuie să fie valide";return false
        }
        if(prepare && (routePlan.active || baitingController.enabled || scanCoordinator.state==="SCANNING" || root.awaitingMissionStart || root.steeringModeBusy)) {
            pro.pointSaveStatus="Oprește misiunea activă înainte de pregătirea altui punct";return false
        }
        var previous=fishingSpots.fishingSpots
        var c=QtPositioning.coordinate(entry.latitude,entry.longitude)
        var spot=fishingSpots.saveSpot(c,entry.bottom,entry.temp,name,note,
            {source:"CHART",sequence:entry.sequence,observedAt:entry.time,offset:entry.offset,range:entry.range})
        if(!spot || !scanCoordinator.checkpoint("sonar-point")) {
            fishingSpots.fishingSpots=previous
            pro.pointSaveStatus="Salvarea a eșuat. Punctul nu este confirmat pe disc.";return false
        }
        pro.pointSaveStatus="Punct salvat: "+spot.name
        root.lastNavigationStatus=pro.pointSaveStatus
        pro.closePointDialog()
        if(prepare) {
            if(!routePlan.selectKind("point") || !routePlan.setPoint({coordinate:c},spot.name,0)) {
                pro.pointSaveStatus="Punct salvat; pregătirea misiunii a eșuat";return false
            }
            root.missionScanSelected=false;root.activePage=2
            baitingController.targetWaypoint={coordinate:c,name:spot.name}
        }
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
    property string pendingSpotEditId:""
    signal savedSpotEditRequested()
    signal savedSpotPrepared()
    function prepareFishingSpotAction(spot,action,hopper,scanSizeM) {
        if(!spot || !root.requireActiveLakeForPointSave() || !root.allowLiveAction())return false
        if(root.missionBusy || baitingController.enabled || root.steeringModeBusy) {
            root.lastNavigationStatus="Oprește operația activă înainte de a pregăti alt punct";return false
        }
        // Resolve by ID in the current lake: never use stale popup coordinates.
        var current=null
        for(var i=0;i<fishingSpots.fishingSpots.length;i++)if(fishingSpots.fishingSpots[i].id===spot.id){current=fishingSpots.fishingSpots[i];break}
        if(!current || typeof current.lat!=="number" || typeof current.lon!=="number" || !isFinite(current.lat) || !isFinite(current.lon) || Math.abs(current.lat)>90 || Math.abs(current.lon)>180)return false
        if(action==="edit") {
            root.pendingSpotEditId=current.id;root.mapMaximized=false;root.activePage=3
            root.savedSpotEditRequested();return true
        }
        var c=QtPositioning.coordinate(current.lat,current.lon)
        if(action==="scan") {
            if(typeof scanSizeM!=="number" || !isFinite(scanSizeM) || scanSizeM<10 || scanSizeM>100 || Math.abs(c.latitude)>85)return false
            var north=c.atDistanceAndAzimuth(scanSizeM/2,0),south=c.atDistanceAndAzimuth(scanSizeM/2,180)
            var west=c.atDistanceAndAzimuth(scanSizeM/2,270),east=c.atDistanceAndAzimuth(scanSizeM/2,90)
            var a=QtPositioning.coordinate(north.latitude,west.longitude),b=QtPositioning.coordinate(south.latitude,east.longitude)
            // The rectangle generator does not support date-line crossing.
            if(Math.abs(a.longitude-b.longitude)>180)return false
            missionUploader.invalidate()
            var points=scanCoordinator.prepareRectangle(a,b)
            if(!points.length){root.lastNavigationStatus="Zona respinsă: "+areaScanController.lastError;return false}
            root.missionScanSelected=true
            root.lastNavigationStatus="Zona din jurul punctului "+current.name+" pregătită • verifică limitele și apasă PREGĂTEȘTE MISIUNEA"
        } else {
            if(action!=="navigate" && action!=="bait")return false
            if(action==="bait" && (!Number.isInteger(hopper) || hopper<1 || hopper>3))return false
            if(!routePlan.selectKind("point") || !routePlan.setPoint({coordinate:c},current.name,action==="bait" ? hopper : 0))return false
            root.missionScanSelected=false
            baitingController.targetWaypoint={coordinate:c,name:current.name,sequenceNumber:0}
            root.lastNavigationStatus="Destinație: "+current.name+" • verifică misiunea și confirmă START"
        }
        root.pendingBaitPointPick=false;root.pendingAreaDrawMode="none";root.mapMaximized=false
        root.activePage=2
        root.savedSpotPrepared()
        return true
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
        root.directGotoActive = true
        root.lastNavigationStatus = "Comandă GUIDED trimisă către punct"
        return true
    }


    Dialog {
        id: preLaunchSkipDialog
        parent: Overlay.overlay
        anchors.centerIn: parent
        modal: true
        title: "Pre-Launch • verificare"
        standardButtons: Dialog.Cancel
        ColumnLayout {
            width: Math.min(350, root.width-50)
            spacing: 10
            Label { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: preLaunchCheck.blockingMessage }
            Label { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: "SKIP poate ignora doar citirea bateriei din pre-check, în această sesiune. Nu dezactivează GPS, HOME, legătura H743, failsafe-ul autopilotului sau Energy Guard." }
            Button {
                Layout.fillWidth: true
                text: "SKIP CITIRE BATERIE • CONFIRM"
                enabled: root.linkAlive && preLaunchCheck.gpsReady && preLaunchCheck.homeReady && !preLaunchCheck.batteryReady
                onClicked: {
                    root.preLaunchBatteryOverride = true
                    root.lastNavigationStatus = "Pre-Launch: citire baterie ignorată manual; verifică tensiunea fizic înainte de plecare"
                    preLaunchSkipDialog.close()
                }
            }
        }
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

    // Credits appear only after the user presses the NAVO SMART home branding.
    Rectangle {
        visible: root.showHomeCredit && root.activePage === 0 && !root.mapMaximized
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 3
        width: Math.min(root.width - 30, homeCredit.implicitWidth + 30)
        height: 23
        radius: 8
        color: "#071926"
        border.color: "#13617a"
        z: 1900
        Label {
            id: homeCredit
            anchors.centerIn: parent
            text: "build and design by Costel Apreutesei"
            color: "#7edff2"
            font.pixelSize: 11
        }
    }

    Rectangle {
        id: header
        // Reserve the final compass before sizing telemetry, so it remains on screen.
        readonly property real sideMargin: root.width < 1000 ? 8 : 12
        readonly property real itemGap: root.width < 1000 ? 5 : 8
        readonly property real brandWidth: root.width < 1000 ? 136 : 164
        readonly property real compassWidth: root.activePage===2 ? 40 : 46
        readonly property real telemetryScale: Math.max(0.76, Math.min(1,
            (width - 2*sideMargin - brandWidth - compassWidth - 8*itemGap - 8) / 551))
        visible: root.activePage !== 10 && !(root.activePage===2 && root.mapMaximized)
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        height: root.activePage===2 ? (root.mapMaximized ? 0 : 48) : 64
        color: "#071926"; border.color: "#13617a"; z: 2000
        Flickable {
            anchors.fill: parent
            clip: true
            contentWidth: Math.max(width, headerItems.implicitWidth + 2*header.sideMargin)
            contentHeight: height
            boundsBehavior: Flickable.StopAtBounds
        RowLayout {
            id: headerItems
            x: header.sideMargin; height: parent.height; spacing: header.itemGap
            Item {
                Layout.preferredWidth: header.brandWidth
                Layout.minimumWidth: header.brandWidth
                Layout.maximumWidth: header.brandWidth
                Layout.preferredHeight: 48
                RowLayout {
                    anchors.fill: parent
                    spacing: 5
                    Image {
                        source: "qrc:/qml/NavoSmart/icons/navo-brand.svg"
                        Layout.preferredWidth: root.activePage===2 ? 26 : 28
                        Layout.preferredHeight: root.activePage===2 ? 26 : 28
                        fillMode: Image.PreserveAspectFit
                    }
                    ColumnLayout {
                        id: titleLabels
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        spacing: 1
                        Label { Layout.fillWidth:true; text: "NAVO SMART"; color: root.text; font.pixelSize: root.width < 1000 ? 14 : 16; font.bold: true }
                        Label { visible:root.activePage!==2; text: "Pescaru' lu' Pește"; color: "#7edff2"; font.pixelSize: 10 }
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { root.mapMaximized=false; root.activePage=0; root.showHomeCredit=true }
                }
            }
            StatusPill { iconSource:"qrc:/qml/NavoSmart/icons/satellite.svg"; title: "SATELIȚI"; value: vehicle && vehicle.gps ? String(vehicle.gps.count.rawValue) : "--"; good: root.linkAlive && vehicle.gps && Number(vehicle.gps.lock.rawValue)>=3 && isFinite(Number(vehicle.gps.count.rawValue)) && Number(vehicle.gps.count.rawValue)>=0 && Number(vehicle.gps.count.rawValue)<255; interactive:true; onClicked:gnssDiagnostic.open() }
            StatusPill { iconSource:"qrc:/qml/NavoSmart/icons/home.svg"; title: "HOME"; value: Number(root.distanceToHome).toFixed(0) + " m"; good: root.linkAlive && vehicle.homePosition && vehicle.homePosition.isValid && vehicle.coordinate && vehicle.coordinate.isValid && vehicle.distanceToHome && isFinite(Number(vehicle.distanceToHome.rawValue)); interactive:true
                onClicked: { root.activePage=0; Qt.callLater(function(){ if(root.mapController && root.mapController.centerHome && !root.mapController.centerHome()) root.lastNavigationStatus="HOME indisponibil" }) }
                onPressAndHold: { if(!root.vehicle || !root.vehicle.homePosition || !root.vehicle.homePosition.isValid || !root.vehicle.coordinate || !root.vehicle.coordinate.isValid || !root.vehicle.gps || root.vehicle.gps.lock.rawValue<3) root.lastNavigationStatus="RTL blocat: HOME/GPS invalid"; else homeRtlConfirm.open() }
            }
            StatusPill { iconSource:"qrc:/qml/NavoSmart/icons/speed.svg"; title: "VITEZĂ"; value: vehicle && vehicle.groundSpeed ? Number(vehicle.groundSpeed.rawValue * 3.6).toFixed(1) + " km/h" : "--"; good: root.linkAlive && vehicle.groundSpeed && isFinite(Number(vehicle.groundSpeed.rawValue)) }
            StatusPill { iconSource:"qrc:/qml/NavoSmart/icons/target.svg"; title: "ȚINTĂ"; value: root.distanceToTarget > 0 ? Number(root.distanceToTarget).toFixed(0) + " m" : "--"; good: root.linkAlive && isFinite(root.distanceToTarget) && root.distanceToTarget > 0 }
            StatusPill { pillWidth:82; iconSource:"qrc:/qml/NavoSmart/icons/battery.svg"; title: "BATERIE"; value: root.linkAlive && battery && battery.percentRemaining && isFinite(Number(battery.percentRemaining.rawValue)) && Number(battery.percentRemaining.rawValue)>=0 ? Number(battery.percentRemaining.rawValue).toFixed(0) + "%" : "--"; good: root.linkAlive && battery && battery.percentRemaining && Number(battery.percentRemaining.rawValue)>20; interactive:true; onClicked:dashboardDetails.showSection("battery") }
            StatusPill { pillWidth:77; iconSource:"qrc:/qml/NavoSmart/icons/temp.svg"; title: "TEMP"; value: h743Telemetry.connected && h743Telemetry.temperatureValid && isFinite(h743Telemetry.batteryTempC) ? Number(h743Telemetry.batteryTempC).toFixed(1) + "°" : "--"; good: h743Telemetry.connected && h743Telemetry.temperatureValid && safetyManager.state !== "CRITICAL"; interactive:true; onClicked:dashboardDetails.showSection("temperature") }
            StatusPill { pillWidth:88; iconSource:"qrc:/qml/NavoSmart/icons/mode.svg"; title: "MOD"; value: root.linkAlive && root.flightMode.length ? root.flightMode.toUpperCase() : "--"; good: root.linkAlive; interactive:false }
            NavoHeadingCompass {
                id: headingCompass
                Layout.preferredWidth: header.compassWidth
                Layout.preferredHeight: header.compassWidth
                headingDeg: root.headingDeg
                headingSource: root.headingSource
                waypointBearingDeg: root.waypointBearingDeg
                rollDeg: root.rollDeg
                pitchDeg: root.pitchDeg
                expanded: false
                onToggleRequested: root.headingOverlayOpen = !root.headingOverlayOpen
            }
        }
        }
    }

    Popup {
        id: gnssDiagnostic
        modal: false
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        x: Math.max(8, Math.min(165, root.width - width - 8))
        y: 66
        width: Math.min(420, root.width - 18)
        padding: 14
        z: 6800
        background: Rectangle { radius: 14; color: "#071926"; border.color: "#20d9ed"; border.width: 1.5 }
        property string checkResult: ""
        function factValue(fact) {
            if (!fact || fact.rawValue === undefined || fact.rawValue === null) return "--"
            var n = Number(fact.rawValue)
            return isFinite(n) ? n.toFixed(2) : "--"
        }
        ColumnLayout {
            width: parent.width
            spacing: 9
            RowLayout {
                Layout.fillWidth: true
                Image { source: "qrc:/qml/NavoSmart/icons/satellite.svg"; Layout.preferredWidth: 25; Layout.preferredHeight: 25 }
                Label { text: "GNSS / UM982 • Diagnostic"; color: "#edf8ff"; font.bold: true; font.pixelSize: 17; Layout.fillWidth: true }
                Button {
                    text: "✕"; Accessible.name: "Închide diagnosticul GPS"
                    implicitWidth: 34; implicitHeight: 31
                    onClicked: gnssDiagnostic.close()
                    background: Rectangle { radius: 9; color: "#103044"; border.color: "#174e68" }
                    contentItem: Label { text: parent.text; color: "#20d9ed"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                }
            }
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 34
                radius: 9; color: "#0d2a39"; border.color: "#174e68"
                Label {
                    anchors.centerIn: parent
                    text: !root.vehicle ? "H743 deconectat" : !root.vehicle.gps ? "Fără date GPS" : Number(root.vehicle.gps.lock.rawValue) >= 3 ? "● Poziție GPS validă" : "● GPS fără fix 3D"
                    color: root.vehicle && root.vehicle.gps && Number(root.vehicle.gps.lock.rawValue) >= 3 ? "#31d6a5" : "#ffd166"
                    font.pixelSize: 12; font.bold: true
                }
            }
            DataLine { name: "Sursă orientare"; value: gnssHeading.headingSource }
            Rectangle { Layout.fillWidth: true; height: 1; color: "#174e68" }
            DataLine { name: "Heading GNSS dual-antenă"; value: gnssHeading.gpsYawValid ? Number(gnssHeading.gpsYawDeg).toFixed(2) + "°" : "--" }
            DataLine { name: "Heading H743 (rezervă)"; value: root.vehicle && root.vehicle.heading && root.linkAlive && isFinite(Number(root.vehicle.heading.rawValue)) ? Number(root.vehicle.heading.rawValue).toFixed(2) + "°" : "--" }
            DataLine { name: "Vechime orientare GNSS"; value: gnssHeading.gpsYawValid ? String(gnssHeading.gpsYawAgeMs) + " ms" : "--" }
            Label { Layout.fillWidth: true; text: gnssHeading.headingDetail; color: gnssHeading.gpsYawValid ? "#31d6a5" : "#ffd166"; wrapMode: Text.WordWrap; font.pixelSize: 11 }
            Rectangle { Layout.fillWidth: true; height: 1; color: "#174e68" }
            DataLine { name: "Sateliți"; value: root.vehicle && root.vehicle.gps ? String(root.vehicle.gps.count.rawValue) : "--" }
            Rectangle { Layout.fillWidth: true; height: 1; color: "#174e68" }
            DataLine { name: "Fix GPS / MAVLink"; value: root.vehicle && root.vehicle.gps ? String(root.vehicle.gps.lock.rawValue) : "--" }
            Rectangle { Layout.fillWidth: true; height: 1; color: "#174e68" }
            DataLine { name: "Latitudine"; value: root.vehicle && root.vehicle.coordinate && root.vehicle.coordinate.isValid ? Number(root.vehicle.coordinate.latitude).toFixed(7) + "°" : "--" }
            Rectangle { Layout.fillWidth: true; height: 1; color: "#174e68" }
            DataLine { name: "Longitudine"; value: root.vehicle && root.vehicle.coordinate && root.vehicle.coordinate.isValid ? Number(root.vehicle.coordinate.longitude).toFixed(7) + "°" : "--" }
            Rectangle { Layout.fillWidth: true; height: 1; color: "#174e68" }
            DataLine { name: "Altitudine GPS"; value: root.vehicle && root.vehicle.coordinate && root.vehicle.coordinate.isValid ? Number(root.vehicle.coordinate.altitude).toFixed(1) + " m" : "--" }
            Rectangle { Layout.fillWidth: true; height: 1; color: "#174e68" }
            DataLine { name: "HDOP"; value: root.vehicle && root.vehicle.gps ? gnssDiagnostic.factValue(root.vehicle.gps.hdop) : "--" }
            DataLine { name: "VDOP"; value: root.vehicle && root.vehicle.gps ? gnssDiagnostic.factValue(root.vehicle.gps.vdop) : "--" }
            Label {
                Layout.fillWidth: true
                text: "3 = 3D • 4 = DGPS • 5/6 = RTK. Identitatea UM982 și antenele duale nu pot fi confirmate prin fixul MAVLink."
                color: "#9cc4d7"; wrapMode: Text.WordWrap; font.pixelSize: 11
            }
            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                Button {
                    text: "Verifică GPS"
                    implicitHeight: 34
                    onClicked: {
                        if (!root.vehicle) gnssDiagnostic.checkResult = "H743 nu este conectat. Verifică MAVLink."
                        else if (!root.vehicle.gps) gnssDiagnostic.checkResult = "H743 conectat, dar nu raportează GPS. Verifică UART, alimentarea UM982 și SERIALx_PROTOCOL."
                        else if (Number(root.vehicle.gps.lock.rawValue) < 3) gnssDiagnostic.checkResult = "GPS raportat, fără fix 3D. Verifică antenele și vizibilitatea cerului."
                        else if (!gnssHeading.gpsYawValid) gnssDiagnostic.checkResult = "GPS are fix, dar nu există GPS yaw valid de la antenele duale. Momentan orientarea bărcii folosește H743 ca rezervă. Verifică GPS1_TYPE=25, EK3_SRC1_YAW și antenele."
                        else gnssDiagnostic.checkResult = "Orientare GNSS validă (" + gnssHeading.headingSource + "): " + Number(gnssHeading.gpsYawDeg).toFixed(2) + "°. Identitatea fizică UM982 se validează separat."
                    }
                    background: Rectangle { radius: 9; color: "#103044"; border.color: "#20d9ed" }
                    contentItem: Label { text: parent.text; color: "#20d9ed"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                }
            }
            Label { Layout.fillWidth: true; visible: gnssDiagnostic.checkResult.length>0; text: gnssDiagnostic.checkResult; color: "#20d9ed"; wrapMode: Text.WordWrap; font.pixelSize: 11 }
        }
        onOpened: checkResult = ""
    }

    NavoStatusDetails {
        id: dashboardDetails
        viewportWidth: root.width
        viewportHeight: root.height
        vehicle: root.vehicle
        battery: root.battery
        linkAlive: root.linkAlive
        temperatureFresh: h743Telemetry.connected && h743Telemetry.temperatureValid && isFinite(h743Telemetry.batteryTempC)
        temperatureC: h743Telemetry.batteryTempC
        temperatureSource: "Temperatură NTC baterie / H743"
    }

    NavoHeadingCompass { id:headingCompassOverlay; visible:root.headingOverlayOpen && root.activePage !== 10; expanded:true; width:260; height:260; anchors.top:header.bottom; anchors.right:parent.right; anchors.topMargin:12; anchors.rightMargin:88; z:6000; headingDeg:root.headingDeg; headingSource:root.headingSource; waypointBearingDeg:root.waypointBearingDeg; rollDeg:root.rollDeg; pitchDeg:root.pitchDeg; onToggleRequested:root.headingOverlayOpen=false }

    Rectangle {
        id: sidebar
        anchors.left: parent.left; anchors.top: header.bottom; anchors.bottom: parent.bottom
        visible: !root.mapMaximized && root.activePage !== 10
        width: root.width < 1100 ? 64 : 72; color: "#071926"; border.color: "#174e68"
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
                NavButton { text:"HĂRȚI OFFLINE";iconSource:"qrc:/qml/NavoSmart/icons/save.svg";active:root.activePage===12;onClicked:{if(root.mapController)root.offlineRegion=root.mapController.offlineRegion();root.activePage=12} }
                NavButton { text:"JURNAL"; iconSource:"qrc:/qml/NavoSmart/icons/edit.svg"; active:root.activePage===11; onClicked:root.activePage=11 }
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
        visible:root.actionActive || root.activePage===2
        anchors.left:root.mapMaximized || root.activePage===10 ? parent.left : sidebar.right
        anchors.right:parent.right
        anchors.top:root.activePage===10 ? parent.top : header.bottom
        height:visible ? implicitHeight : 0
        z:6001
        active:root.actionActive
        cancelAvailable:!sonar.replayMode && (root.actionActive || scanCoordinator.state==="READY" || scanCoordinator.state==="RESUME_READY" || scanCoordinator.state==="PAUSED")
        cancelText:root.rtlActive ? "ANULEAZĂ RTL" : "ANULEAZĂ"
        onCancelRequested:root.cancelCurrentAction()
        connected:root.linkAlive
        homeAvailable:!sonar.replayMode && !!root.vehicle && !!root.vehicle.guidedModeRTL && !!root.vehicle.homePosition && root.vehicle.homePosition.isValid
        progress:routePlan.active ? 100*(routePlan.currentIndex+Math.min(0.95,Math.max(0,root.routeLegDistanceM>0 && isFinite(baitingController.distanceToTarget()) ? 1-baitingController.distanceToTarget()/root.routeLegDistanceM : 0)))/Math.max(1,routePlan.runningStops.length) : root.missionScanSelected ? areaScanController.progressPercent() : routePlan.state==="DISPATCHED" ? 100 : 0
        statusText:root.pendingMode.length ? root.lastNavigationStatus : root.rtlActive ? "Întoarcere HOME • RTL activ" : root.directGotoActive ? "Mergi la punct • comandă GUIDED trimisă" : routePlan.active ? (routePlan.missionKind==="point" ? "Mergi la punct" : "Traseu cu opriri")+" • oprire "+(routePlan.currentIndex+1)+"/"+routePlan.runningStops.length+" • "+baitingController.stateText(baitingController.state) : root.missionScanSelected ? "Scanare • "+root.missionStateLabel(scanCoordinator.state) : "Misiune • "+root.missionStateLabel(routePlan.state)
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
            sourceComponent: root.activePage === 12 ? offlineMapsPage :
                             root.activePage === 11 ? journalPage :
                             root.activePage === 0 ? mapPage :
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
                headingOverrideEnabled: true
                areaDrawingGeneration: root.areaDrawingGeneration
                headingOverrideDeg: root.headingDeg
                spotActionsAllowed:!root.missionBusy && !sonar.replayMode && !root.steeringModeBusy
                onFishingSpotActionRequested:function(spot,action,hopper,size){root.prepareFishingSpotAction(spot,action,hopper,size)}
                onFishingSpotRenameRequested:function(spot){root.prepareFishingSpotAction(spot,"edit",0,0)}
                onOfflineMapsRequested:function(region){root.openOfflineMaps(region)}
                onFishingSpotsRequested:function(spot){root.mapMaximized=false;root.activePage=3}
                routeActive:routePlan.active
                routeStops:routePlan.active ? routePlan.runningStops : routePlan.stops
                routeReturnsHome:(routePlan.active ? routePlan.runningFinishAction : routePlan.finishAction)==="RTL"
                recordedReplay: sonar.replayMode
                id: navoMap
                anchors.fill: parent
                anchors.leftMargin: 8; anchors.topMargin: 8; anchors.bottomMargin: 8; anchors.rightMargin: 72
                Component.onCompleted: {
                    root.mapController = navoMap
                    if(root.offlineViewRequest){navoMap.showOfflineRegion(root.offlineViewRequest);root.offlineViewRequest=null}
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
            id:sonarProView
            activeLakeId:scanCoordinator.lakeId
            onSonarPointRequested:function(entry,name,note,prepareMission){root.saveSonarPoint(sonarProView,entry,name,note,prepareMission)}
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
                RowLayout {
                    Layout.fillWidth:true
                    Button {
                        objectName:"missionConfigure"
                        implicitWidth:36;implicitHeight:34;padding:7
                        text:"Configurare misiune"
                        ToolTip.visible:hovered;ToolTip.text:text
                        background:Rectangle { radius:6;color:missionOptions.opened ? "#176b86" : "#102b3b";border.color:missionOptions.opened ? "#45d5f5" : "#31506a" }
                        contentItem:Image { source:"qrc:/qml/NavoSmart/icons/settings.svg";fillMode:Image.PreserveAspectFit }
                        Accessible.name:"Configurare misiune"
                        onClicked:{routeEditor.close();missionOptions.opened ? missionOptions.close() : missionOptions.open()}
                    }
                    Button {
                        objectName:"missionDetails"
                        visible:!root.missionScanSelected
                        implicitHeight:34
                        text:routePlan.active ? "Detalii" : "Opriri"
                        Accessible.name:"Arată sau ascunde opririle misiunii"
                        background:Rectangle { radius:6;color:routeEditor.opened ? "#176b86" : "#102b3b";border.color:"#31506a" }
                        contentItem:Label { text:parent.text;color:"#e3f4ff";horizontalAlignment:Text.AlignHCenter;verticalAlignment:Text.AlignVCenter }
                        onClicked:{missionOptions.close();routeEditor.opened ? routeEditor.close() : routeEditor.open()}
                    }
                    Label {
                        Layout.fillWidth:true; color:root.muted; elide:Text.ElideRight
                        text:root.missionScanSelected ? "Scanează zona" : (routePlan.missionKind==="point" ? "Mergi la punct" : "Traseu cu opriri")
                    }
                    Button {
                        objectName:"missionFitRoute"
                        implicitWidth:36;implicitHeight:34;padding:7
                        enabled:areaScanMap.canFitMission
                        Accessible.name:"Încadrează traseul pe hartă"
                        ToolTip.visible:hovered;ToolTip.text:Accessible.name
                        background:Rectangle { radius:6;color:"#102b3b";border.color:parent.enabled ? "#38badb" : "#31506a" }
                        contentItem:Image { source:"qrc:/qml/NavoSmart/icons/route.svg";fillMode:Image.PreserveAspectFit;opacity:parent.enabled ? 1 : .4 }
                        onClicked:{routeEditor.close();Qt.callLater(areaScanMap.fitMission)}
                    }
                    Button {
                        objectName:"missionExpand"
                        implicitWidth:36;implicitHeight:34;padding:7
                        text:root.mapMaximized ? "Revino la configurare" : "Mărește harta"
                        Accessible.name:text;ToolTip.visible:hovered;ToolTip.text:text
                        background:Rectangle { radius:6;color:root.mapMaximized ? "#176b86" : "#102b3b";border.color:"#38badb" }
                        contentItem:Image { source:"qrc:/qml/NavoSmart/icons/fullscreen.svg";fillMode:Image.PreserveAspectFit }
                        onClicked:{missionOptions.close();routeEditor.close();root.mapMaximized=!root.mapMaximized}
                    }
                }
                Popup {
                    id:missionOptions
                    parent:Overlay.overlay
                    x:Math.max(12,(parent.width-width)/2)
                    y:Math.max(12,Math.min(110,parent.height-height-12))
                    width:Math.min(760,parent.width-24)
                    height:Math.min(310,parent.height-24)
                    modal:false; focus:true; closePolicy:Popup.CloseOnEscape|Popup.CloseOnPressOutside
                    padding:12
                    background:Rectangle { color:"#101b25";radius:10;border.color:"#21b7ff";border.width:2 }
                    contentItem:ScrollView {
                        clip:true;contentWidth:availableWidth
                        ColumnLayout {
                            width:missionOptions.availableWidth
                            spacing:8
                            Flow {
                                Layout.fillWidth:true
                                spacing:6
                                Repeater {
                                    model:["Mergi la punct","Traseu cu opriri","Scanează zona"]
                                    delegate:Button {
                                        implicitHeight:36
                                        leftPadding:9;rightPadding:9;topPadding:4;bottomPadding:4
                                        font.pixelSize:12
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
                                    implicitWidth:132; implicitHeight:38
                                    from:1;to:30;value:Math.round(root.scanEstimateSpeedMps*10)
                                    enabled:!root.missionBusy && !sonar.replayMode
                                    textFromValue:function(v,locale){return Number(v/10).toLocaleString(locale,'f',1)}
                                    onValueModified:root.scanEstimateSpeedMps=value/10
                                }
                                Label {text:"La final";color:"white"}
                                ComboBox { implicitWidth:132; implicitHeight:38; enabled:!root.missionBusy && !sonar.replayMode; model:["HOLD","RTL"]; currentIndex:root.areaScanFinishAction==="RTL"?1:0; onActivated:root.areaScanFinishAction=currentIndex===1?"RTL":"HOLD" }
                            }
                            Label {
                                visible:root.missionScanSelected
                                Layout.fillWidth:true;wrapMode:Text.WordWrap;color:root.muted
                                text:"Cuve: fără eliberare • AUTO folosește viteza configurată în H743.\n"+
                                    (root.scanEstimate.valid ? "~"+Math.ceil(root.scanEstimate.distanceM)+" m • ~"+Math.ceil(root.scanEstimate.durationSeconds/60)+" min (estimare fără viraje)" : "Definește zona; GPS și HOME sunt necesare pentru estimare.")
                            }
            
                            Button { text:"Închide";Layout.alignment:Qt.AlignRight;onClicked:missionOptions.close() }
                        }
                    }
                }
                Popup {
                    id:routeEditor;objectName:"missionRouteEditor"
                    Component.onCompleted:if(!root.missionScanSelected && routePlan.stops.length && !routePlan.active && !root.mapMaximized)Qt.callLater(routeEditor.open)
                    parent:Overlay.overlay
                    width:Math.min(380,parent.width-24)
                    y:missionStrip.y+missionStrip.height+48
                    height:Math.max(100,parent.height-y-12)
                    x:parent.width-width-12
                    modal:false;focus:true;padding:10
                    closePolicy:Popup.CloseOnEscape
                    background:Rectangle { color:"#0b1c2e";radius:8;border.color:"#38badb" }
                    onClosed:root.pendingBaitPointPick=false
                    Connections {
                        target:root.routePlanController
                        function onActiveChanged(){if(root.routePlanController.active){routeEditor.close();root.mapMaximized=true}}
                    }
                    Connections {
                        target:root
                        function onMissionScanSelectedChanged(){if(root.missionScanSelected)routeEditor.close()}
                        function onSavedSpotPrepared(){if(!root.missionScanSelected)routeEditor.open();else routeEditor.close()}
                    }
                    contentItem:ColumnLayout {
                        spacing:6
                        RowLayout {
                            Layout.fillWidth:true
                            Label { Layout.fillWidth:true;text:routePlan.active ? "Misiune activă" : "Configurare opriri";elide:Text.ElideRight;color:"white";font.bold:true }
                            Button { objectName:"missionHideDetails";text:"Ascunde";implicitHeight:34;onClicked:routeEditor.close() }
                        }
                        ScrollView {
                            id:routeEditorScroll;objectName:"missionRouteScroll"
                            Layout.fillWidth:true;Layout.fillHeight:true
                            clip:true;contentWidth:availableWidth
                            ScrollBar.vertical.policy:ScrollBar.AlwaysOn
                            NavoRoutePanel {
                                width:routeEditorScroll.availableWidth
                                routePlan:root.routePlanController
                                waypoint:baitingController.targetWaypoint
                                availableSpots:fishingSpots.fishingSpots
                                estimate:root.routeEstimate
                                energyText:root.routeEnergyText
                                speedMps:baitingController.silentMode ? baitingController.silentSpeedMps : baitingController.normalSpeedMps
                                speedEditable:!root.missionBusy
                                onSpeedRequested:function(speed){if(!root.missionBusy && root.allowLiveAction()){if(baitingController.silentMode)baitingController.silentSpeedMps=speed;else baitingController.normalSpeedMps=speed}}
                                onSpotChosen:function(spot){baitingController.targetWaypoint={coordinate:QtPositioning.coordinate(spot.lat,spot.lon),name:spot.name,sequenceNumber:0}}
                                onChooseOnMapRequested:{routeEditor.close();root.pendingBaitPointPick=true;root.lastNavigationStatus="Atinge destinația pe hartă"}
                                onStartRequested:function(loadConfirmed){root.startRoute(loadConfirmed)}
                                onStopRequested:root.stopMission()
                            }
                        }
                    }
                }
                GridLayout {
                    columns:root.missionScanSelected && !root.mapMaximized ? 2 : 1
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    rowSpacing:8;columnSpacing:8
                    Rectangle {
                        Layout.fillWidth: true; Layout.fillHeight: true; Layout.minimumHeight:120
                        Layout.rightMargin:routeEditor.opened && !root.missionScanSelected && parent.width>=700 ? routeEditor.width+8 : 0
                        radius: 8; color: root.bg; border.color: root.line; clip: true
                        NavoMap {
                headingOverrideEnabled: true
                areaDrawingGeneration: root.areaDrawingGeneration
                headingOverrideDeg: root.headingDeg
                spotActionsAllowed:!root.missionBusy && !sonar.replayMode && !root.steeringModeBusy
                onFishingSpotActionRequested:function(spot,action,hopper,size){root.prepareFishingSpotAction(spot,action,hopper,size)}
                onFishingSpotRenameRequested:function(spot){root.prepareFishingSpotAction(spot,"edit",0,0)}
                onOfflineMapsRequested:function(region){root.openOfflineMaps(region)}
                onFishingSpotsRequested:function(spot){root.mapMaximized=false;root.activePage=3}
                routeActive:routePlan.active
                routeStops:root.missionScanSelected ? [] : routePlan.active ? routePlan.runningStops : routePlan.stops
                routeReturnsHome:root.missionScanSelected ? root.areaScanFinishAction==="RTL" : (routePlan.active ? routePlan.runningFinishAction : routePlan.finishAction)==="RTL"
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
                        visible:root.missionScanSelected && !root.mapMaximized
                        id:scanToolsScroll
                        objectName:"scanToolsScroll"
                        Layout.preferredWidth:112
                        Layout.minimumWidth:112;Layout.maximumWidth:112
                        Layout.fillHeight: true
                        clip:true;contentWidth:availableWidth
                        ScrollBar.horizontal.policy:ScrollBar.AlwaysOff
                        Flow {
                        width:scanToolsScroll.availableWidth
                        spacing: 6
                        component ScanIconButton: Button {
                            id: scanButton
                            width:52;height:46;padding:0;hoverEnabled:true
                            property string hint: ""
                            property string caption: hint
                            Accessible.name: caption
                            Accessible.description: hint
                            HoverHandler { id:scanHover;acceptedDevices:PointerDevice.Mouse | PointerDevice.TouchPad }
                            Timer { id:helpTimer;interval:4000;repeat:false }
                            onPressed:helpTimer.restart()
                            ToolTip {
                                id:scanHelpTip;objectName:"scanToolTip"
                                visible:(scanHover.hovered || scanButton.down || helpTimer.running) && !clearAreaConfirm.opened
                                delay:scanHover.hovered && !helpTimer.running ? 300 : 0
                                timeout:-1
                                width:Math.min(280,root.width-24);padding:8;margins:8
                                x:(scanButton.width-width)/2;y:-height-6
                                text:scanButton.caption===scanButton.hint ? scanButton.hint : scanButton.caption+" • "+scanButton.hint
                                contentItem:Label { text:scanHelpTip.text;color:"#eff9ff";font.pixelSize:12;wrapMode:Text.WordWrap }
                                background:Rectangle { radius:7;color:"#102536";border.color:"#38badb" }
                            }
                            background: Rectangle { radius: 8; color: parent.down ? "#18354a" : "#101b25"; border.color: parent.enabled ? "#31506a" : "#26313a" }
                        }
                        ScanIconButton {
                            hint: "Desenează dreptunghi"
                            enabled: !root.missionBusy && !sonar.replayMode
                            contentItem: Canvas { anchors.top:parent.top;anchors.horizontalCenter:parent.horizontalCenter;width:52;height:46; onPaint:{var p=getContext("2d");p.reset();p.strokeStyle="#f2f7fb";p.lineWidth=2;p.strokeRect(12,11,28,24)} }
                            onClicked: { root.pendingAreaDrawMode="rectangle"; Qt.callLater(function(){if(areaScanMap && root.pendingAreaDrawMode==="rectangle"){areaScanMap.beginAreaRectangle();root.pendingAreaDrawMode="none"}}); root.lastNavigationStatus="Atinge două colțuri pe hartă pentru dreptunghi" }
                        }
                        ScanIconButton {
                            hint: "Desenează poligon"
                            enabled: !root.missionBusy && !sonar.replayMode
                            contentItem: Canvas { anchors.top:parent.top;anchors.horizontalCenter:parent.horizontalCenter;width:52;height:46; onPaint:{var p=getContext("2d");p.reset();p.strokeStyle="#f2f7fb";p.lineWidth=2;p.beginPath();p.moveTo(12,31);p.lineTo(17,12);p.lineTo(38,9);p.lineTo(42,30);p.lineTo(27,37);p.closePath();p.stroke()} }
                            onClicked: { root.pendingAreaDrawMode="polygon"; Qt.callLater(function(){if(areaScanMap && root.pendingAreaDrawMode==="polygon"){areaScanMap.beginAreaPolygon();root.pendingAreaDrawMode="none"}}); root.lastNavigationStatus="Atinge cel puțin trei puncte și apoi TERMINĂ" }
                        }
                        ScanIconButton {
                            hint: "Pregătește misiunea"
                            enabled: areaScanController.generatedPoints.length>0 && scanCoordinator.state!=="SCANNING" && !missionUploader.uploadInProgress
                            contentItem: Canvas { anchors.top:parent.top;anchors.horizontalCenter:parent.horizontalCenter;width:52;height:46; onPaint:{var p=getContext("2d");p.reset();p.strokeStyle="#21b7ff";p.fillStyle="#21b7ff";p.lineWidth=2;p.beginPath();p.moveTo(11,34);p.lineTo(22,22);p.lineTo(31,29);p.lineTo(41,13);p.stroke();for(var i=0;i<4;i++){var a=[[11,34],[22,22],[31,29],[41,13]][i];p.beginPath();p.arc(a[0],a[1],2.5,0,Math.PI*2);p.fill()}} }
                            onClicked: { if(!root.allowLiveAction()) return; missionUploader.invalidate(); var prepared=scanCoordinator.prepareMission(false); if(prepared&&prepared.length)root.lastNavigationStatus="Misiune pregătită • "+prepared.length+" WP • următorul pas: UPLOAD"; else if(!root.lastNavigationStatus.length)root.lastNavigationStatus="Pregătirea misiunii a eșuat" }
                        }
                        ScanIconButton {
                            hint: missionUploader.uploadVerified ? "Start autopilot" : "Upload misiune"
                            enabled: missionUploader.preparedCount>0 && !missionUploader.uploadInProgress
                            contentItem: Canvas { anchors.top:parent.top;anchors.horizontalCenter:parent.horizontalCenter;width:52;height:46; onPaint:{var p=getContext("2d");p.reset();p.strokeStyle="#31d67b";p.fillStyle="#31d67b";p.lineWidth=2;if(missionUploader.uploadVerified){p.beginPath();p.moveTo(17,11);p.lineTo(38,23);p.lineTo(17,35);p.closePath();p.fill()}else{p.beginPath();p.moveTo(26,35);p.lineTo(26,12);p.moveTo(17,21);p.lineTo(26,12);p.lineTo(35,21);p.stroke()}} }
                            onClicked: root.startMission()
                        }
                        ScanIconButton {
                            caption: "Continuă scanarea"
                            hint: "Pregătește culoarele rămase; apoi apasă Upload și Start autopilot"
                            enabled: (scanCoordinator.state==="PAUSED"||scanCoordinator.state==="RTL") && !missionUploader.uploadInProgress && areaScanController.generatedPoints.length>0 && areaScanController.completedLanes.length<areaScanController.laneCount()
                            contentItem: Canvas { anchors.top:parent.top;anchors.horizontalCenter:parent.horizontalCenter;width:52;height:46; onPaint:{var p=getContext("2d");p.reset();p.strokeStyle="#f2f7fb";p.lineWidth=2;p.beginPath();p.arc(26,23,12,.45,5.3);p.stroke();p.beginPath();p.moveTo(34,10);p.lineTo(39,17);p.lineTo(31,18);p.stroke()} }
                            onClicked:{var mission=scanCoordinator.resume();if(mission.length)root.lastNavigationStatus="Resume pregătit • apasă UPLOAD și apoi START AUTOPILOT"}
                        }
                        ScanIconButton { caption:"Pauză / HOLD"; hint:"Pune scanarea în pauză și solicită HOLD"; enabled:scanCoordinator.state==="SCANNING"||root.awaitingMissionStart; contentItem:Canvas{anchors.top:parent.top;anchors.horizontalCenter:parent.horizontalCenter;width:52;height:46;onPaint:{var p=getContext("2d");p.reset();p.fillStyle="#ffc857";p.fillRect(15,12,7,23);p.fillRect(30,12,7,23)}} onClicked:root.holdMission() }
                        ScanIconButton { hint:"RTL / întoarcere acasă"; enabled:scanCoordinator.state==="SCANNING"||scanCoordinator.state==="PAUSED"||scanCoordinator.state==="RESUME_READY"; contentItem:Canvas{anchors.top:parent.top;anchors.horizontalCenter:parent.horizontalCenter;width:52;height:46;onPaint:{var p=getContext("2d");p.reset();p.strokeStyle="#21b7ff";p.lineWidth=2;p.beginPath();p.moveTo(10,25);p.lineTo(26,11);p.lineTo(42,25);p.moveTo(16,22);p.lineTo(16,37);p.lineTo(36,37);p.lineTo(36,22);p.stroke()}} onClicked:root.rtlMission() }
                        ScanIconButton { objectName:"scanCancel"; caption:root.rtlActive ? "Anulează RTL" : "Anulează acțiunea"; hint:"Anulează scanarea, navigarea sau RTL și solicită HOLD"; enabled:!sonar.replayMode && (root.actionActive || scanCoordinator.state==="PAUSED" || scanCoordinator.state==="READY" || scanCoordinator.state==="RESUME_READY"); contentItem:Canvas{anchors.top:parent.top;anchors.horizontalCenter:parent.horizontalCenter;width:52;height:46;onPaint:{var p=getContext("2d");p.reset();p.fillStyle="#ff5c5c";p.fillRect(15,12,23,23)}} onClicked:root.stopMission() }
                        ScanIconButton {
                            objectName:"scanClearArea"; caption:"Șterge zona"
                            hint:"Șterge chenarul și culoarele Area Scan; păstrează măsurătorile sonar"
                            enabled:root.canClearArea
                            contentItem:Canvas { anchors.top:parent.top;anchors.horizontalCenter:parent.horizontalCenter;width:52;height:46;onPaint:{var p=getContext("2d");p.reset();p.strokeStyle="#ff8b93";p.lineWidth=2;p.strokeRect(17,15,20,23);p.beginPath();p.moveTo(13,12);p.lineTo(41,12);p.moveTo(22,8);p.lineTo(32,8);p.stroke()} }
                            onClicked:clearAreaConfirm.open()
                        }
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
            function openPendingSpotEdit(){
                if(!root.pendingSpotEditId)return
                for(var i=0;i<fishingSpots.fishingSpots.length;i++)if(fishingSpots.fishingSpots[i].id===root.pendingSpotEditId){openEdit(fishingSpots.fishingSpots[i]);break}
                root.pendingSpotEditId=""
            }
            Component.onCompleted:Qt.callLater(openPendingSpotEdit)
            Connections { target:root;function onSavedSpotEditRequested(){fishingPageRoot.openPendingSpotEdit()} }
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
                headingOverrideEnabled: true
                areaDrawingGeneration: root.areaDrawingGeneration
                headingOverrideDeg: root.headingDeg
                spotActionsAllowed:!root.missionBusy && !sonar.replayMode && !root.steeringModeBusy
                onFishingSpotActionRequested:function(spot,action,hopper,size){root.prepareFishingSpotAction(spot,action,hopper,size)}
                onFishingSpotRenameRequested:function(spot){root.prepareFishingSpotAction(spot,"edit",0,0)}
                onOfflineMapsRequested:function(region){root.openOfflineMaps(region)}
                onFishingSpotsRequested:function(spot){fishingPageRoot.mapExpanded=false;root.mapMaximized=false;root.activePage=3}
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
                        onNavigateRequested:function(c){root.navigateToCoordinate(c)}
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
                        width:Math.min(parent.width-90,hint.implicitWidth+20); height:30; radius:7; color:"#071827ee"; border.color:root.line
                        Label { id:hint; anchors.fill:parent;anchors.margins:6;elide:Text.ElideRight;verticalAlignment:Text.AlignVCenter;text:"ȚINE APĂSAT: PUNCT SALVAT = ACȚIUNI • HARTĂ = PUNCT NOU"; color:root.text; font.pixelSize:10; font.bold:true }
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
            property string spotEditLakeId: ""
            function openEdit(spot) {
                if(root.missionBusy || root.actionActive || sonar.replayMode || root.steeringModeBusy || !scanCoordinator.lakeId.length)return
                spotEditId=spot.id;spotEditLakeId=scanCoordinator.lakeId
                spotName.text=spot.name||"";spotEditColor=spot.color||"#31d67b"
                spotLatitude.text=String(spot.lat);spotLongitude.text=String(spot.lon)
                spotDepth.text=typeof spot.depth==="number" && isFinite(spot.depth) ? String(spot.depth) : ""
                spotTemperature.text=typeof spot.temp==="number" && isFinite(spot.temp) ? String(spot.temp) : ""
                spotNote.text=spot.note||"";spotEditDialog.errorText="";spotEditDialog.open()
            }
            function spotNumber(text) {
                var clean=text.trim().replace(",", ".")
                return /^[+-]?(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)$/.test(clean) ? Number(clean) : NaN
            }
            function saveSpotEdit() {
                if(root.actionActive || root.missionBusy || sonar.replayMode || root.steeringModeBusy ||
                   !spotEditLakeId.length || spotEditLakeId!==scanCoordinator.lakeId){
                    spotEditDialog.errorText="Editare blocată: operație activă, replay sau baltă schimbată.";return false
                }
                var before=fishingSpots.fishingSpots.slice(0)
                var fields={name:spotName.text,lat:spotNumber(spotLatitude.text),lon:spotNumber(spotLongitude.text),
                    depth:spotDepth.text.trim().length ? spotNumber(spotDepth.text) : null,
                    temp:spotTemperature.text.trim().length ? spotNumber(spotTemperature.text) : null,
                    note:spotNote.text,color:spotEditColor}
                if(!fishingSpots.updateSpot(spotEditId,fields)){
                    spotEditDialog.errorText="Verifică numele, GPS (-90…90 / -180…180), adâncimea ≥ 0 și temperatura. Punctul trebuie să existe.";return false
                }
                if(!scanCoordinator.checkpoint("fishing-spot-edit")){
                    fishingSpots.fishingSpots=before
                    spotEditDialog.errorText="Salvarea a eșuat. Datele vechi au fost păstrate; poți reîncerca.";return false
                }
                root.lastNavigationStatus="Punct salvat: "+fields.name.trim()
                spotEditDialog.close();return true
            }
            Dialog {
                id:spotEditDialog;objectName:"savedSpotEditor"
                parent:Overlay.overlay;anchors.centerIn:parent;modal:true
                width:Math.min(560,parent.width-24);height:Math.min(620,parent.height-24)
                padding:14
                title:"Editează punct"
                header:Label {
                    text:spotEditDialog.title;color:root.text;font.bold:true;font.pixelSize:18
                    leftPadding:14;rightPadding:14;topPadding:10;bottomPadding:8
                    background:Rectangle { color:root.panel;radius:12 }
                }
                property string errorText:""
                palette.windowText:root.text;palette.text:root.text;palette.buttonText:root.text
                background:Rectangle { color:root.panel;radius:12;border.color:root.cyan }
                component EditorButton: Button {
                    Layout.fillWidth:true;implicitHeight:40
                    contentItem:Label { text:parent.text;color:root.text;font.bold:true;horizontalAlignment:Text.AlignHCenter;verticalAlignment:Text.AlignVCenter }
                    background:Rectangle { radius:6;color:parent.down ? "#254b60" : "#142c3c";border.color:root.cyan }
                }
                component SpotField: TextField {
                    Layout.fillWidth:true;selectByMouse:true
                    color:root.text;placeholderTextColor:root.muted
                    background:Rectangle { radius:6;color:root.bg;border.color:root.line }
                }
                contentItem:ScrollView {
                    id:spotEditScroll;clip:true;contentWidth:availableWidth
                    ScrollBar.horizontal.policy:ScrollBar.AlwaysOff
                    ColumnLayout {
                        width:spotEditScroll.availableWidth;spacing:7
                        Label { text:"Nume";color:root.text }
                        SpotField { id:spotName;objectName:"spotEditName";placeholderText:"Lanseta verde" }
                        Label { text:"Latitudine GPS (grade zecimale)";color:root.text }
                        SpotField { id:spotLatitude;objectName:"spotEditLatitude";inputMethodHints:Qt.ImhFormattedNumbersOnly }
                        Label { text:"Longitudine GPS (grade zecimale)";color:root.text }
                        SpotField { id:spotLongitude;objectName:"spotEditLongitude";inputMethodHints:Qt.ImhFormattedNumbersOnly }
                        Label { text:"Adâncime (m) • gol = necunoscută";color:root.text }
                        SpotField { id:spotDepth;objectName:"spotEditDepth";inputMethodHints:Qt.ImhFormattedNumbersOnly }
                        Label { text:"Temperatura apei (°C) • gol = necunoscută";color:root.text }
                        SpotField { id:spotTemperature;objectName:"spotEditTemperature";inputMethodHints:Qt.ImhFormattedNumbersOnly }
                        Label { text:"Notițe";color:root.text }
                        TextArea {
                            id:spotNote;objectName:"spotEditNote";Layout.fillWidth:true;Layout.minimumHeight:70
                            wrapMode:TextEdit.Wrap;selectByMouse:true;color:root.text
                            background:Rectangle { radius:6;color:root.bg;border.color:root.line }
                        }
                        Label { text:"Culoare marker (cod HEX)";color:root.text }
                        SpotField { objectName:"spotEditColor";text:fishingPageRoot.spotEditColor;onTextEdited:fishingPageRoot.spotEditColor=text }
                        Flow {
                            Layout.fillWidth:true;spacing:8
                            Repeater {
                                model:["#31d67b","#ef4444","#3b82f6","#facc15","#a855f7","#f97316"]
                                delegate:Button {
                                    required property var modelData
                                    width:38;height:38
                                    Accessible.name:"Culoare "+modelData
                                    background:Rectangle { radius:19;color:parent.modelData;border.color:fishingPageRoot.spotEditColor===parent.modelData ? "white" : "#607080";border.width:3 }
                                    onClicked:fishingPageRoot.spotEditColor=modelData
                                }
                            }
                        }
                        Label { Layout.fillWidth:true;text:"Datele sonar originale și data creării rămân asociate punctului.";color:root.muted;wrapMode:Text.WordWrap;font.pixelSize:11 }
                    }
                }
                footer:ColumnLayout {
                    spacing:6
                    Label { Layout.fillWidth:true;Layout.margins:10;visible:text.length>0;text:spotEditDialog.errorText;color:root.warn;wrapMode:Text.WordWrap }
                    RowLayout {
                        Layout.fillWidth:true;Layout.margins:10
                        EditorButton { text:"Anulează";onClicked:spotEditDialog.reject() }
                        EditorButton { objectName:"spotEditSave";text:"Salvează";onClicked:fishingPageRoot.saveSpotEdit() }
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
            onWaypointNameChanged: function(sequence, friendlyName) { persistence.setWaypointName(sequence, friendlyName); scanCoordinator.checkpoint("waypoint-name") }
        }
    }

    Component {
        id: lakesPage
        Item {
            id: lakesHome
            property int selectedTab: 0
            Rectangle { anchors.fill: parent; color: "#051521"; radius: 10; border.color: "#174c68" }
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: root.compactUi ? 8 : 11
                spacing: 9
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    color: "#071e30"; radius: 10; border.color: "#20d9ed"
                    RowLayout {
                        anchors.fill: parent; anchors.margins: 4
                        Image { source: "qrc:/qml/NavoSmart/icons/lake.svg"; Layout.preferredWidth: 18; Layout.preferredHeight: 18 }
                        Label { text: "Bălțile mele"; color: "#eff9ff"; font.pixelSize: 12; font.bold: true; Layout.fillWidth: true }
                        Button {
                            text: "Manager"
                            Accessible.name: "Deschide managerul Bălțile mele"
                            implicitWidth: 92; implicitHeight: 35
                            onClicked: myLakesPopup.open()
                            background: Rectangle { radius: 8; color: "#0a293e"; border.color: "#20d9ed" }
                            contentItem: Label { text: parent.text; color: "#eff9ff"; font.pixelSize: 12; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        }
                    }
                }
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 47
                    color: "#071e30"; radius: 9; border.color: "#19546b"
                    Flickable {
                        anchors.fill: parent; anchors.margins: 5
                        contentWidth: lakesHomeTabs.implicitWidth; contentHeight: height
                        clip: true; boundsBehavior: Flickable.StopAtBounds
                        Row {
                            id: lakesHomeTabs; height: parent.height; spacing: 7
                            Repeater {
                                model: ["Bălți salvate", "Baltă activă", "Administrare"]
                                delegate: Button {
                                    required property string modelData
                                    required property int index
                                    implicitWidth: index === 0 ? 145 : 125
                                    implicitHeight: 36
                                    onClicked: lakesHome.selectedTab = index
                                    background: Rectangle {
                                        radius: 8
                                        color: lakesHome.selectedTab===index ? "#10394d" : "#071e30"
                                        border.color: lakesHome.selectedTab===index ? "#20d9ed" : "#26718b"
                                        border.width: lakesHome.selectedTab===index ? 2 : 1
                                    }
                                    contentItem: Label {
                                        text: modelData; color: "#eff9ff"; font.pixelSize: 12
                                        font.bold: lakesHome.selectedTab===index
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }
                            }
                        }
                    }
                }
                Rectangle {
                    visible: lakesHome.selectedTab===0
                    Layout.fillWidth: true
                    implicitHeight: 56
                    color: "#061827"; border.color: "#20d9ed"; radius: 10
                    RowLayout {
                        anchors.fill: parent; anchors.margins: 9; spacing: 8
                        TextField {
                            id: inlineLakeName
                            Layout.fillWidth: true
                            implicitHeight: 37
                            placeholderText: "Nume baltă nouă"
                            color: "#eff9ff"; placeholderTextColor: "#a7c1d3"
                            selectByMouse: true
                            background: Rectangle { color: "#092439"; border.color: inlineLakeName.activeFocus ? "#20d9ed" : "#54869d"; radius: 8 }
                            onAccepted: { addLakeButton.clicked(); focus = false }
                        }
                        Button {
                            id: addLakeButton
                            text: "+ Salvează"
                            enabled: inlineLakeName.text.trim().length > 0
                            implicitHeight: 36
                            implicitWidth: 105
                            onClicked: {
                                var name=inlineLakeName.text.trim()
                                var id=persistence.saveLake({name:name})
                                var found=false
                                for(var i=0;i<persistence.lakes.length;i++)
                                    if(persistence.lakes[i].id===id){found=true;break}
                                if(found){
                                    inlineLakeName.clear()
                                    root.lakeSaveStatus="Salvată: "+name
                                    // Existing NAVO checkpoint preserves the sonar/spots/mission lake partition.
                                    for(var j=0;j<persistence.lakes.length;j++)
                                        if(persistence.lakes[j].id===id){myLakesPopup.selectLake(persistence.lakes[j]);break}
                                    scanCoordinator.checkpoint("lake-created")
                                } else root.lakeSaveStatus="Salvarea a eșuat • încearcă din nou"
                            }
                            background: Rectangle { radius: 8; color: "#0b3546"; border.color: parent.enabled ? "#37e9a2" : "#506778" }
                            contentItem: Label { text: parent.text; color: parent.enabled ? "#eff9ff" : "#b7c3cf"; font.pixelSize: 12; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        }
                    }
                }
                Label {
                    visible: root.lakeSaveStatus.length>0
                    Layout.fillWidth: true
                    text: root.lakeSaveStatus; color: "#9be9e2"
                    font.pixelSize: 11; wrapMode: Text.WordWrap
                }
                Rectangle {
                    visible: lakesHome.selectedTab===0
                    Layout.fillWidth: true; Layout.fillHeight: true
                    color: "#061827"; border.color: "#20d9ed"; radius: 10
                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 9; spacing: 6
                        RowLayout {
                            Layout.fillWidth: true
                            Label { text: "Bibliotecă bălți"; color: "#eff9ff"; font.bold: true; font.pixelSize: 15; Layout.fillWidth: true }
                            Label { text: persistence.lakes.length+" salvate"; color: "#79eff0"; font.pixelSize: 11 }
                        }
                        Rectangle { Layout.fillWidth: true; height: 1; color: "#19546b" }
                        ListView {
                            Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: 6
                            model: persistence.lakes
                            delegate: Rectangle {
                                required property var modelData
                                width: ListView.view.width; height: 52; radius: 8
                                color: "#092334"; border.color: "#2a7892"
                                RowLayout {
                                    anchors.fill: parent; anchors.margins: 5; spacing: 7
                                    Button {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        text: modelData.name || "Baltă"
                                        flat: true
                                        contentItem: Label {
                                            text: parent.text; color: "#eff9ff"; font.pixelSize: 13; font.bold: true
                                            verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight
                                        }
                                        onClicked: { myLakesPopup.selectLake(modelData); myLakesPopup.open() }
                                    }
                                    Button {
                                        text: "Redenumește";implicitWidth:42;implicitHeight:40;padding:8
                                        ToolTip.visible: hovered; ToolTip.text: "Redenumește"
                                        onClicked: { myLakesPopup.open(); myLakesPopup.beginRename(modelData) }
                                        background: Rectangle { radius: 7; color: "#0b3546"; border.color: "#20d9ed" }
                                        contentItem:Image { source:"qrc:/qml/NavoSmart/icons/edit.svg";fillMode:Image.PreserveAspectFit }
                                    }
                                    Button {
                                        text: "Șterge";implicitWidth:42;implicitHeight:40;padding:8
                                        ToolTip.visible: hovered; ToolTip.text: "Șterge"
                                        onClicked: { myLakesPopup.open(); myLakesPopup.beginDelete(modelData) }
                                        background: Rectangle { radius: 7; color: "#291e30"; border.color: "#ff8793" }
                                        contentItem:Image { source:"qrc:/qml/NavoSmart/icons/delete.svg";fillMode:Image.PreserveAspectFit }
                                    }
                                }
                            }
                            Label { visible: parent.count===0; anchors.centerIn: parent; text: "Nu există încă bălți salvate"; color: "#c1d7e6" }
                        }
                    }
                }
                Rectangle {
                    visible: lakesHome.selectedTab===1
                    Layout.fillWidth: true; Layout.fillHeight: true
                    color: "#061827"; border.color: "#20d9ed"; radius: 10
                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 13; spacing: 10
                        Label { text: "Baltă activă"; color: "#eff9ff"; font.bold: true; font.pixelSize: 17 }
                        Rectangle { Layout.fillWidth: true; height: 1; color: "#19546b" }
                        Label { text: scanCoordinator.lakeName.length ? scanCoordinator.lakeName : "Nicio baltă activă"; color: "#79eff0"; font.pixelSize: 16 }
                        Label {
                            Layout.fillWidth: true; wrapMode: Text.WordWrap; font.pixelSize: 12; color: "#c1d7e6"
                            text: "Datele Sonar PRO, punctele de pescuit, batimetria și progresul Area Scan se salvează separat pentru fiecare baltă."
                        }
                        Button {
                            text: "Deschide managerul bălții"
                            enabled: persistence.lakes.length>0
                            onClicked: myLakesPopup.open()
                            background: Rectangle { color: "#0b3546"; border.color: "#20d9ed"; radius: 8 }
                            contentItem: Label { text: parent.text; color: "#eff9ff"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        }
                        Item { Layout.fillHeight: true }
                    }
                }
                Rectangle {
                    visible: lakesHome.selectedTab===2
                    Layout.fillWidth: true; Layout.fillHeight: true
                    color: "#061827"; border.color: "#20d9ed"; radius: 10
                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 13; spacing: 10
                        Label { text: "Administrare și restaurare"; color: "#eff9ff"; font.bold: true; font.pixelSize: 17 }
                        Rectangle { Layout.fillWidth: true; height: 1; color: "#19546b" }
                        Label {
                            Layout.fillWidth: true; wrapMode: Text.WordWrap; color: "#c1d7e6"; font.pixelSize: 12
                            text: "Selectează o baltă pentru a încărca sesiunile sonar, pentru a deschide harta sau pentru a continua o scanare. Redenumirea și ștergerea sunt protejate de dialoguri."
                        }
                        Button {
                            text: "Deschide Bălțile mele"
                            onClicked: myLakesPopup.open()
                            background: Rectangle { radius: 8; color: "#0b3546"; border.color: "#20d9ed" }
                            contentItem: Label { text: parent.text; color: "#eff9ff"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        }
                        Item { Layout.fillHeight: true }
                    }
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
        id:offlineMapsPage
        NavoOfflineMaps {
            manager:QGroundControl.mapEngineManager
            region:root.offlineRegion
            lakeName:scanCoordinator.lakeName
            tileLimit:Number(QGroundControl.settingsManager.offlineMapsSettings.maxTilesForDownload.rawValue)
            onChooseRegionRequested:{root.activePage=0;Qt.callLater(function(){if(root.mapController){root.mapController.beginOfflinePick()}})}
            onShowRegionRequested:function(region,mapType){root.showOfflineRegion(region,mapType)}
        }
    }

    Component {
        id:journalPage
        ColumnLayout {
            anchors.fill: parent
            spacing: 6
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                radius: 9
                color: "#102a39"
                border.color: "#ffd166"
                visible: root.pendingBaitJournalCount>0
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 7
                    spacing: 8
                    Label { Layout.fillWidth: true; color: "#ffe09a"; font.pixelSize: 12; wrapMode: Text.WordWrap; text: root.pendingBaitJournalCount+" nădiri așteaptă salvarea" }
                    Button {
                        text: "Recuperează"
                        implicitHeight: 33
                        onClicked: root.retryPendingBaitJournal()
                        background: Rectangle { radius: 8; color: "#0b3546"; border.color: "#20d9ed" }
                        contentItem: Label { text: parent.text; color: "#eff9ff"; font.pixelSize: 12; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    }
                }
            }
            NavoFishingJournal {
            Layout.fillWidth: true
            Layout.fillHeight: true
            persistence:root.lakePersistence
            lakeId:scanCoordinator.lakeId
            lakeName:scanCoordinator.lakeName
            vehicle:root.vehicle
            replayMode:sonar.replayMode
            depthM:sonar.replayMode ? NaN : root.depthM
            waterTempC:sonar.replayMode ? NaN : root.waterTempC
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
                headingOverrideEnabled: true
                areaDrawingGeneration: root.areaDrawingGeneration
                headingOverrideDeg: root.headingDeg
                spotActionsAllowed:!root.missionBusy && !sonar.replayMode && !root.steeringModeBusy
                onFishingSpotActionRequested:function(spot,action,hopper,size){root.prepareFishingSpotAction(spot,action,hopper,size)}
                onFishingSpotRenameRequested:function(spot){root.prepareFishingSpotAction(spot,"edit",0,0)}
                onOfflineMapsRequested:function(region){root.openOfflineMaps(region)}
                onFishingSpotsRequested:function(spot){root.mapMaximized=false;root.activePage=3}
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
                            ToolTip.text: "Confirmarea mecanică nu necesită telemetrie, dar comenzile V3 cer serviciul H743 validat"
                            onToggled:hopperSettings.confirmed=checked
                        }
                        Rectangle {
                            Layout.fillWidth:true; Layout.preferredHeight:root.compactUi ? 58 : 64; radius:7
                            color:root.panel; border.color:safetyManager.state==="CRITICAL"?root.danger:root.line
                            RowLayout {
                                anchors.fill:parent; anchors.margins:9
                                ColumnLayout {
                                    Label { text:"SENZORI"; color:root.muted; font.pixelSize:10 }
                                    Label { text:h743Telemetry.connected?"H743 ONLINE":"H743 OFFLINE"; color:h743Telemetry.connected?root.ok:root.warn; font.bold:true }
                                }
                                Item { Layout.fillWidth:true }
                                ColumnLayout {
                                    Label { text:"TEMP BATERIE"; color:root.muted; font.pixelSize:10 }
                                    Label { text:h743Telemetry.connected&&!isNaN(h743Telemetry.batteryTempC)?Number(h743Telemetry.batteryTempC).toFixed(1)+" °C":"--"; color:root.text; font.bold:true }
                                }
                                ColumnLayout {
                                    Label { text:"APĂ"; color:root.muted; font.pixelSize:10 }
                                    Label { text:h743Telemetry.waterDetected?"DETECTATĂ":"OK"; color:h743Telemetry.waterDetected?root.danger:(h743Telemetry.connected?root.ok:root.muted); font.bold:true }
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
        NavoSettingsV3 {
            anchors.fill: parent
            sonar: root.sonarController
            camera: cameraEthernet
            alerts: root.settingsAlertsController
            audio: alertAudio
            steering: steeringAssist
            g20: g20Controller
            energy: energySettings
            onCameraStreamUrlChanged: root.cameraStreamUrl = cameraStreamUrl
            onCameraProtocolChanged: root.cameraProtocol = cameraProtocol
            onStatus: function(message) { root.lastNavigationStatus = message }
            onEnableSteeringRequested: steeringAssist.enable()
            onSettingsToolRequested: {
                if (typeof mainWindow !== "undefined" && mainWindow.showSettingsTool)
                    mainWindow.showSettingsTool()
                else root.lastNavigationStatus = "Setările native QGroundControl nu sunt disponibile în acest context."
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
        readonly property bool healthy: good && root.linkAlive && value.length>0 && value!=="--"
        property bool interactive: false
        signal clicked()
        signal pressAndHold()
        property real pillWidth: 76
        Layout.preferredWidth: pillWidth * header.telemetryScale; Layout.preferredHeight: root.compactUi ? 36 : 42; radius: 9
        color: pillMouse.containsMouse && interactive ? "#143747" : "#0a2332"
        border.color: healthy ? root.ok : (pillMouse.containsMouse && interactive ? "#20d9ed" : (interactive ? "#167a93" : root.line))
        border.width: healthy ? 2 : 1
        ToolTip.visible: pillMouse.containsMouse && interactive
        ToolTip.text: "Deschide " + title.toLowerCase()
        ToolTip.delay: 500
        MouseArea { id:pillMouse; anchors.fill:parent; enabled:parent.interactive; hoverEnabled:true; cursorShape:parent.interactive?Qt.PointingHandCursor:Qt.ArrowCursor; pressAndHoldInterval:1600; onClicked:parent.clicked(); onPressAndHold:parent.pressAndHold() }
        Row { width:parent.width-6; anchors.centerIn:parent; spacing:header.telemetryScale<1 ? 3 : 5
            Image { id:pillIcon;width:header.telemetryScale<1 ? 16 : 20;height:width;anchors.verticalCenter:parent.verticalCenter;source:iconSource;fillMode:Image.PreserveAspectFit }
            Column { width:parent.width-pillIcon.width-parent.spacing;anchors.verticalCenter:parent.verticalCenter;spacing:0
                Label { width:parent.width;horizontalAlignment:Text.AlignHCenter;elide:Text.ElideRight;text:title;color:"#9cc4d7";font.pixelSize:8 }
                Label { width:parent.width;horizontalAlignment:Text.AlignHCenter;elide:Text.ElideRight;text:value;color:healthy?root.ok:root.text;font.pixelSize:header.telemetryScale<1 ? 10 : 11;font.bold:true }
            }
        }
    }

    component NavButton: Button {
        Accessible.name: text
        property bool active: false
        property bool proBadge: false
        property url iconSource: ""
        // Mouse hover on desktop, sustained touch on Android/G20.
        property bool longPressHint: false
        ToolTip.visible: hovered || longPressHint
        ToolTip.text: text
        ToolTip.delay: hovered ? 450 : 0
        ToolTip.timeout: longPressHint ? 2200 : -1
        onPressAndHold: longPressHint = true
        onReleased: longPressHint = false
        onCanceled: longPressHint = false
        Layout.fillWidth: true
        Layout.preferredHeight: Math.max(38, Math.min(46, (sidebar.height - 58) / 9))
        background: Rectangle {
            radius: 9
            color: parent.active ? "#103b4d" : (parent.hovered ? "#0d2a38" : "transparent")
            border.color: parent.active ? "#20d9ed" : (parent.hovered ? "#167a93" : "transparent")
            border.width: 1
        }
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

