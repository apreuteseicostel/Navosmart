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
    function fail(message){stage="failed";backend.report({status:"failed",error:message,phase:backend.configuration.phase});clock.stop()}
    function require(ok,message){if(!ok)throw new Error(message)}
    function advance(next){stage=next;entered=Date.now();evidence.sceneReady=false;publish("running")}
    function publish(status){
        var state={status:status,phase:backend.configuration.phase,stage:stage,liveId:liveId,replayId:replayId,samples:samples}
        for(var key in evidence)state[key]=evidence[key]
        var metrics=backend.inspect(dashboard)
        for(var metric in metrics)state[metric]=metrics[metric]
        require(backend.report(state),"Cannot persist acceptance report")
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
                require(dashboard.sonarMappingController.rawSamples.length===samples,"Restored sonar sample count differs")
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
            if(sonar.replayActive || sonar.processedColumns<14000 || !sonar.nativeSurfaceMesh.indices || sonar.nativeSurfaceMesh.indices.length<3)return
            require(sonar.replayPosition===sonar.replaySize,"Replay ended before EOF")
            samples=dashboard.replayMappingController.rawSamples.length
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
                replayId=dashboard.saveRecordedReplayLake("CI original Kogger")
                require(replayId && replayId!==liveId,"Replay did not create a separate lake")
                sonar.stopReplay()
                require(coordinator.activateLake(replayId,"CI original Kogger"),"Cannot activate saved recording")
            }
            dashboard.activePage=7;advance("3d");return
        }
        if(stage==="3d") {
            var mesh=backend.inspect(dashboard)
            if(mesh.mesh3dVertices<3 || mesh.mesh3dTriangles<1)return
            if(!evidence.sceneReady){evidence.sceneReady=true;entered=Date.now();publish("running")}
            if(Date.now()-entered<4000)return
            evidence.mesh3dVertices=mesh.mesh3dVertices;evidence.mesh3dTriangles=mesh.mesh3dTriangles
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
    Timer {id:clock;interval:250;repeat:true;running:true;onTriggered:{try{test.step()}catch(error){test.fail(String(error))}}}
}
