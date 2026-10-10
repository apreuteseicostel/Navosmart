import QtQuick
import QtPositioning

// CI-only driver of the actual Dashboard and its real controllers. Hardware
// actions are tested only for refusal while no vehicle is connected.
Item {
    id: test
    required property var dashboard
    required property var backend
    visible:false
    property string stage:"start"
    property double started:Date.now()
    property double entered:Date.now()
    property string liveId:""
    property string replayId:""
    property string liveBefore:""
    property int samples:0
    property var evidence:({})
    property bool stepping:false
    property double reported:0
    property string progressSignature:""
    property double progressed:Date.now()
    function fail(message){evidence.failedStage=stage;evidence.error=message;stage="failed";backend.report(reportState("failed"));clock.stop()}
    function require(ok,message){if(!ok)throw new Error(message)}
    function advance(next){stage=next;entered=Date.now();evidence.sceneReady=false;publish("running")}
    function reportState(status){
        var state={status:status,phase:backend.configuration.phase,stage:stage,liveId:liveId,replayId:replayId,samples:samples}
        var sonar=dashboard.sonarController
        state.replayPosition=sonar.replayPosition;state.replaySize=sonar.replaySize
        state.replayActive=sonar.replayActive;state.replayPaused=sonar.replayPaused
        state.processedColumns=sonar.processedColumns;state.nativeCapacityFull=sonar.nativeCapacityFull
        state.nativeChartRecords=sonar.nativeChartRecords;state.nativeChartRejected=sonar.nativeChartRejected
        state.bathymetryTileCount=sonar.bathymetryTileCount
        state.replayMappingSamples=dashboard.replayMappingController.rawSamples.length
        state.restoredLakeSamples=dashboard.sonarMappingController.rawSamples.length
        state.activePage=dashboard.activePage
        state.nativeSurfaceIndices=sonar.nativeSurfaceMesh.indices ? sonar.nativeSurfaceMesh.indices.length : 0
        for(var key in evidence)state[key]=evidence[key]
        var metrics=backend.inspect(dashboard)
        for(var metric in metrics)state[metric]=metrics[metric]
        return state
    }
    function publish(status){
        require(backend.report(reportState(status)),"Cannot persist acceptance report")
        reported=Date.now()
    }
    function saveReplaySnapshot(){
        // EOF closes the byte reader, not the asynchronous native processor.
        // Samples may arrive while the sonar/map evidence is being captured.
        // Compare restart with the exact snapshot saved here, not the EOF count.
        samples=dashboard.replayMappingController.rawSamples.length
        require(samples>14000,"Recorded snapshot missed processed recording samples")
        replayId=dashboard.saveRecordedReplayLake("CI original Kogger")
        require(replayId && replayId!==liveId,"Replay did not create a separate lake")
        var saved=dashboard.lakePersistence.lakeState(replayId)
        evidence.savedSamples=saved.sonarSamples ? saved.sonarSamples.length : 0
        require(evidence.savedSamples===samples,"Saved sonar sample count differs: expected "+samples+", saved "+evidence.savedSamples)
        dashboard.sonarController.stopReplay()
        require(dashboard.areaCoordinator.activateLake(replayId,"CI original Kogger"),"Cannot activate saved recording")
        evidence.activatedSamples=dashboard.sonarMappingController.rawSamples.length
        require(evidence.activatedSamples===samples,"Activated sonar sample count differs: expected "+samples+", activated "+evidence.activatedSamples)
    }
    function step(){
        require(!dashboard.vehicle,"Acceptance requires a disposable emulator with no vehicle")
        require(Date.now()-started<720000,"Acceptance timed out at "+stage)
        var sonar=dashboard.sonarController,persistence=dashboard.lakePersistence,coordinator=dashboard.areaCoordinator
        var area=dashboard.mapAreaScanController
        if(stage==="start") {
            if(backend.configuration.phase==="restore") {
                liveId=backend.configuration.liveId;replayId=backend.configuration.replayId;samples=backend.configuration.samples
                require(coordinator.lakeId===replayId,"Selected lake not restored automatically after process restart")
                var saved=persistence.lakeState(replayId)
                evidence.savedSamples=saved.sonarSamples ? saved.sonarSamples.length : 0
                evidence.restoredSamples=dashboard.sonarMappingController.rawSamples.length
                require(evidence.savedSamples===samples,"Persisted sonar sample count differs: expected "+samples+", persisted "+evidence.savedSamples)
                require(evidence.restoredSamples===samples,"Restored sonar sample count differs: expected "+samples+", restored "+evidence.restoredSamples)
                require(coordinator.nativeSurfaceMesh.indices.length>=3,"Saved native mesh missing after restart")
                require(!sonar.replayMode,"Restart unexpectedly started replay")
                dashboard.activePage=0;advance("restored-map");return
            }
            require(backend.verifiedFixture(),"Original Kogger fixture hash mismatch")
            liveId=persistence.saveLake({name:"CI live isolation"})
            require(liveId && coordinator.activateLake(liveId,"CI live isolation"),"Cannot create live lake")
            var route=coordinator.prepareRectangle(QtPositioning.coordinate(40.1610,44.4740),QtPositioning.coordinate(40.1615,44.4745))
            require(route.length>4,"Real Area Scan rectangle did not generate corridors")
            area.completedLanes=[0];area.activeLaneIndex=1;coordinator.state="PAUSED"
            require(coordinator.checkpoint("acceptance-area-paused"),"Cannot save paused Area Scan")
            evidence.areaCorridors=area.laneCount()
            require(!dashboard.hopperBridgeController.release(1),"Hopper release allowed without H743")
            require(!dashboard.hopperBridgeController.physicalPositionConfirmed,"Invented physical hopper confirmation")
            evidence.disconnectedHopperBlocked=true
            liveBefore=JSON.stringify(persistence.lakeState(liveId))
            dashboard.activePage=10
            sonar.setReplaySpeed(5)
            require(sonar.startReplay("file://"+backend.directory+"/00028_DownView.klf"),"Installed replay did not open original fixture")
            advance("replay");return
        }
        if(stage==="replay") {
            require(!sonar.dataAlive,"Replay claims live telemetry")
            if(sonar.replayError.length)throw new Error(sonar.replayError)
            var signature=[sonar.replayPosition,sonar.processedColumns,dashboard.replayMappingController.rawSamples.length,sonar.nativeSurfaceMesh.indices ? sonar.nativeSurfaceMesh.indices.length : 0].join(":")
            if(signature!==progressSignature){progressSignature=signature;progressed=Date.now()}
            require(Date.now()-progressed<60000,"Replay stalled: "+signature)
            if(Date.now()-reported>5000)publish("running")
            if(sonar.replayActive || sonar.processedColumns<14000 || !sonar.nativeSurfaceMesh.indices || sonar.nativeSurfaceMesh.indices.length<3)return
            require(sonar.replayPosition===sonar.replaySize,"Replay ended before EOF")
            samples=dashboard.replayMappingController.rawSamples.length
            evidence.samplesAtEof=samples
            require(samples>14000,"Installed mapping missed processed recording samples")
            require(backend.inspect(dashboard).sonarHistoryColumns>100,"Installed Sonar PRO has no populated ecogram history")
            require(liveBefore===JSON.stringify(persistence.lakeState(liveId)),"Replay modified the active live lake")
            evidence.processedColumns=sonar.processedColumns;evidence.replayBytes=sonar.replaySize
            advance("sonar-evidence");return
        }
        if(stage==="sonar-evidence" && Date.now()-entered>4000) {
            dashboard.activePage=0;advance("native-map");return
        }
        if(stage==="native-map" || stage==="restored-map") {
            backend.enableNativeMap(dashboard)
            if(backend.inspect(dashboard).nativePaintedTriangles<=0)return
            if(!evidence.sceneReady){evidence.sceneReady=true;evidence.nativeMapPaintedTriangles=backend.inspect(dashboard).nativePaintedTriangles;entered=Date.now();publish("running")}
            if(Date.now()-entered<4000)return
            require(coordinator.nativeSurfaceMesh.indices || stage==="native-map","Restored native geometry absent")
            if(stage==="native-map") {
                saveReplaySnapshot()
            }
            dashboard.activePage=7;advance("3d");return
        }
        if(stage==="3d") {
            var mesh=backend.inspect(dashboard)
            require(dashboard.activePage===7,"3D page is not selected")
            // Wait for the visible Quick3D page to settle before screenshot readiness.
            if(Date.now()-entered<4000 || !mesh.mesh3dVisible || mesh.mesh3dVertices<3 || mesh.mesh3dTriangles<1)return
            if(!evidence.sceneReady){evidence.sceneReady=true;entered=Date.now();publish("running")}
            if(Date.now()-entered<4000)return
            evidence.verifiedMesh3dVertices=mesh.mesh3dVertices;evidence.verifiedMesh3dTriangles=mesh.mesh3dTriangles
            if(backend.configuration.phase==="restore") {
                require(coordinator.activateLake(liveId,"CI live isolation"),"Cannot restore original Area Scan lake")
                require(area.completedLanes.length===1 && area.completedLanes[0]===0,"Area Scan completed corridor lost after restart")
                require(coordinator.state==="PAUSED" && area.resumeRoute(null).length===area.generatedPoints.length-2,"Area Scan resume route includes completed corridor")
                evidence.areaResumeConfirmed=true
                require(coordinator.activateLake(replayId,"CI original Kogger"),"Cannot return to saved recording")
            }
            publish("passed");clock.stop()
        }
    }
    Timer {
        id:clock;interval:250;repeat:true;running:true
        onTriggered:{
            if(test.stepping || !backend.claim(dashboard))return
            test.stepping=true
            try{test.step()}catch(error){test.fail(String(error))}
            finally{test.stepping=false}
        }
    }
}
