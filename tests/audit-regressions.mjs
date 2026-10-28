// Execute actual QML JavaScript functions with explicit hardware/Qt mocks.
// These regression tests do not substitute for Qt loading, Android or HIL.
import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import path from 'node:path';
const dir = path.resolve(import.meta.dirname, '../custom/qml');
function callable(source, start) {
  for(let end=source.indexOf('}',start);end>=0;end=source.indexOf('}',end+1)) {
    const candidate=source.slice(start,end+1);
    try { new vm.Script('('+candidate+')'); return candidate; } catch {}
  }
  throw Error('Unparseable function');
}
function context(file, values={}) {
  const source=fs.readFileSync(path.join(dir,file),'utf8');
  const c=vm.createContext({routePlan:null,baitingController:null,onboardTiming:false,servoCommandFailed:()=>{},...values}); c.root=c;
  const re=/\bfunction\s+([A-Za-z_][A-Za-z_0-9]*)\s*\(/g;
  let m;
  while((m=re.exec(source))) {
    const fn=callable(source,m.index);
    vm.runInContext(fn,c); re.lastIndex=m.index+fn.length;
  }
  return c;
}
function timerHandler(file, timer, c) {
  const s=fs.readFileSync(path.join(dir,file),'utf8');
  const start=s.indexOf('onTriggered:',s.indexOf('property Timer '+timer));
  assert(start>=0);
  const body=s.slice(s.indexOf('{',start));
  return vm.runInContext('('+callable('function(){'+body.slice(1),0)+')',c);
}
function coord(lat,lon) {
  return {latitude:lat,longitude:lon,isValid:Number.isFinite(lat)&&Number.isFinite(lon)&&Math.abs(lat)<=90&&Math.abs(lon)<=180,
    distanceTo(c){return Math.hypot((c.latitude-lat)*111320,(c.longitude-lon)*111320*Math.cos(lat*Math.PI/180));}};
}
let passed=0;
function test(name, f){f();passed++;console.log('PASS '+name);}
const noop=()=>{};
function area(){return context('NavoAreaScan.qml',{QtPositioning:{coordinate:coord},lastBoatCoordinate:null,laneSpacingM:5,maxMissionPoints:500,generatedPoints:[],completedLanes:[],scanReady:noop,progressChanged:noop});}
test('Rectangle spacing, even lane endpoints and bounded mission size',()=>{
  const a=area(),p=a.generateRectangle(coord(52,0),coord(52.001,.001));
  assert(p.length>2 && p.length%2===0);
  for(let i=2;i<p.length;i+=2)assert(Math.abs(p[i].latitude-p[i-2].latitude)*111320<=5.01);
  assert.equal(a.generateRectangle(coord(0,0),coord(1,1)).length,0);
  assert.equal(a.generatedPoints.length,0);
});
test('Degenerate, self-intersecting and concave polygons are rejected',()=>{
  const a=area();
  for(const ps of [ [[0,0],[0,0],[0,.001]], [[0,0],[.001,.001],[0,.001],[.001,0]], [[0,0],[0,.002],[.001,.001],[.002,.002],[.002,0]] ])
    assert.equal(a.generatePolygon(ps.map(x=>coord(...x))).length,0);
  assert(a.generatePolygon([[0,0],[0,.001],[.001,.001],[.001,0]].map(x=>coord(...x))).length>0);
});
test('Resume retains only incomplete lanes, including non-contiguous gaps',()=>{
  const a=area(); a.generatedPoints=[0,1,2,3,4,5,6,7].map(x=>coord(52,x/10000));a.completedLanes=[0,2];
  const out=a.resumeRoute(null);assert.equal(out.length,4);assert.equal(out[0].longitude,.0002);assert.equal(out[2].longitude,.0006);
});
test('Preparing Area Scan resume preserves HOLD until activation',()=>{
  const a=area();
  a.generatedPoints=[0,1,2,3].map(x=>coord(52,x/10000));
  a.completedLanes=[0];a.paused=true;a.activeLaneIndex=-1;
  const route=a.resumeRoute(null);
  assert.equal(route.length,2);
  assert.equal(a.paused,true);
  assert.equal(a.activeLaneIndex,1);
});
test('Restoring Area Scan after restart leaves scan in HOLD',()=>{
  const a=area(),c=context('NavoScanCoordinator.qml',{
    state:'IDLE',lakeId:'',sonarMapping:{rawSamples:[],restoreCheckpoint:noop,trackCoordinates:[]},
    areaScan:a,persistence:{lakeState:()=>({state:'SCANNING',areaPoints:[{latitude:52,longitude:0},{latitude:52,longitude:.001}],completedLanes:[],missionLanes:[],totalLanes:1}),lakes:[]},
    status:noop,lakeActivated:noop,QtPositioning:{coordinate:coord},fishingSpots:null,fishStore:null,bathymetry:null,routePlan:null
  });
  c.checkpoint=()=>true;
  assert.equal(c.restoreLake('lake'),true);
  assert.equal(c.state,'PAUSED');
  assert.equal(a.paused,true);
});
test('Area Scan resume clears HOLD only after sonar confirms live scanning',()=>{
  const a=area();a.paused=true;
  const sonar={scanning:false,paused:true,resumeScan(){this.scanning=true;this.paused=false;return true}};
  const c=context('NavoScanCoordinator.qml',{state:'RESUME_READY',readOnlyReplay:false,areaScan:a,sonarMapping:sonar,status:noop});
  c.checkpoint=()=>true;
  assert.equal(c.activateResume(),true);
  assert.equal(c.state,'SCANNING');
  assert.equal(a.paused,false);
  a.paused=true;c.state='RESUME_READY';sonar.resumeScan=()=>false;
  assert.equal(c.activateResume(),false);
  assert.equal(a.paused,true);
});
test('Replay and absent controllers cannot activate Area Scan resume',()=>{
  const c=context('NavoScanCoordinator.qml',{state:'RESUME_READY',readOnlyReplay:true,areaScan:{paused:true},sonarMapping:{resumeScan(){throw Error('must not resume sonar')}},status:noop});
  assert.equal(c.activateResume(),false);
  assert.equal(c.areaScan.paused,true);
  c.readOnlyReplay=false;c.areaScan=null;
  assert.equal(c.activateResume(),false);
  c.areaScan={paused:true};c.sonarMapping=null;
  assert.equal(c.activateResume(),false);
});
test('Reached-item evidence ignores odd, duplicate, out-of-range and paused events',()=>{
  const reached=[]; const c=context('NavoScanCoordinator.qml',{areaScan:{},state:'SCANNING',missionWaypointCount:6,missionLanes:[1,3,4],lastCompletedRouteLaneFromMission:-1,lastCompletedLaneFromMission:-1});
  c.laneCompleted=x=>reached.push(x);
  assert.equal(c.missionItemReached(1),false);assert.equal(c.missionItemReached(8),false);
  c.missionItemReached(2);assert.equal(c.missionItemReached(2),false);c.missionItemReached(6);assert.deepEqual(reached,[1,4]);
  c.state='PAUSED';assert.equal(c.missionItemReached(4),false);
});
test('Switching lakes saves old session before clearing all per-lake collections',()=>{
  const saves=[];const c=context('NavoScanCoordinator.qml',{state:'PAUSED',lakeId:'old',lakeName:'Old',persistence:{lakeState:()=>({})},sonarMapping:{rawSamples:[1],trackCoordinates:[1]},areaScan:{generatedPoints:[1],completedLanes:[0]},fishingSpots:{fishingSpots:[1]},fishStore:{clear(){this.detections=[]},detections:[1]},lakeActivated:noop,status:noop});
  c.checkpoint=()=>{saves.push(c.lakeId);return true};
  assert.equal(c.activateLake('new','New'),true);assert.deepEqual(saves,['old','new']);
  assert.equal(c.sonarMapping.rawSamples.length,0);assert.equal(c.fishingSpots.fishingSpots.length,0);assert.equal(c.areaScan.generatedPoints.length,0);
  c.state='SCANNING';assert.equal(c.activateLake('third','Third'),false);assert.equal(c.lakeId,'new');
});
test('Failed checkpoint blocks lake switch',()=>{
  const c=context('NavoScanCoordinator.qml',{state:'PAUSED',lakeId:'old',persistence:{},sonarMapping:{},areaScan:{}});
  c.checkpoint=()=>false;assert.equal(c.activateLake('new','New'),false);assert.equal(c.lakeId,'old');
});
function bait(speed, distance=0.2) {
  const c=context('NavoBaitingController.qml',{vehicle:{flightMode:'HOLD'},enabled:true,state:4,settleState:4,releaseState:5,arrivalRadiusM:1,releaseMaxSpeedMps:.12,hopper:1,postDropTimer:{restart(){c.postStarted=true}},hopperReleaseRequested(){c.released=true},stopRequested:noop,restart:noop});
  c.vehicleCoordinateValid=()=>true;c.validTarget=()=>true;c.distanceToTarget=()=>distance;c.groundSpeed=()=>speed;c.setState=s=>c.state=s;c.abortCycle=()=>{c.enabled=false;c.aborted=true};
  return c;
}
test('Bait release refuses unknown speed and drift outside waypoint radius',()=>{
  for(const c of [bait(NaN),bait(Infinity),bait(.01,2)]) {timerHandler('NavoBaitingController.qml','settleTimer',c)();assert(c.aborted);assert(!c.released);assert(!c.postStarted);}
});
test('Pilot MANUAL blocks the drop even if the settle timer fires before the position monitor',()=>{
 const c=bait(.01);c.vehicle.flightMode='MANUAL';timerHandler('NavoBaitingController.qml','settleTimer',c)();assert(c.aborted);assert(!c.released);
});
test('Valid stationary bait release dispatches; synchronous rejection prevents exit timer',()=>{
  let c=bait(.01);timerHandler('NavoBaitingController.qml','settleTimer',c)();assert(c.released && c.postStarted);
  c=bait(.01);c.hopperReleaseRequested=()=>c.abortCycle();timerHandler('NavoBaitingController.qml','settleTimer',c)();assert(!c.postStarted);
});
test('Failsafe grace never claims RTL delivery after MAVLink communication loss',()=>{
  let now=1790240400000,rtl=0;
  const c=context('NavoFailsafeController.qml',{Date:{now:()=>now},enabled:true,vehicle:{vehicleLinkManager:{communicationLost:true},gps:{lock:{rawValue:3}},coordinate:coord(52,0)},minGpsFix:3,linkLost:false,gpsLost:false,linkGraceSeconds:30,gpsRecoverySeconds:60,gpsReturnHomeSeconds:120,rtlRequested:()=>rtl++,holdRequested:noop,recovered:noop});
  c.tick();now+=29000;c.tick();assert.equal(rtl,0);now+=1000;c.tick();assert.equal(rtl,0);assert(c.status.includes('RTL neconfirmat'));c.tick();assert.equal(rtl,0);
});
test('Disconnected H743 suppresses GPS HOLD requests even during simultaneous GPS loss',()=>{
  let now=1790240400000,holds=0,rtls=0;
  const c=context('NavoFailsafeController.qml',{Date:{now:()=>now},enabled:true,vehicle:{vehicleLinkManager:{communicationLost:true},gps:{lock:{rawValue:0}},coordinate:{isValid:false}},minGpsFix:3,linkLost:false,gpsLost:false,linkGraceSeconds:30,gpsRecoverySeconds:60,gpsReturnHomeSeconds:120,rtlRequested:()=>rtls++,holdRequested:()=>holds++,recovered:noop});
  c.tick();now+=121000;c.tick();assert.equal(holds,0);assert.equal(rtls,0);
  assert.equal(c.gpsLost,true);assert.equal(c.linkLost,true);
});
test('H743 reconnection cannot replay a stale GPS timeout as automatic RTL',()=>{
  let now=1790240400000,rtls=0,holds=0;
  const vehicle={vehicleLinkManager:{communicationLost:true},gps:{lock:{rawValue:0}},coordinate:{isValid:false}};
  const c=context('NavoFailsafeController.qml',{Date:{now:()=>now},enabled:true,vehicle,minGpsFix:3,linkLost:false,gpsLost:false,linkGraceSeconds:30,gpsRecoverySeconds:60,gpsReturnHomeSeconds:120,rtlRequested:()=>rtls++,holdRequested:()=>holds++,recovered:noop});
  c.tick();now+=130000;c.tick();
  vehicle.vehicleLinkManager.communicationLost=false;vehicle.gps.lock.rawValue=3;vehicle.coordinate.isValid=true;
  c.tick();assert.equal(rtls,0);assert.equal(holds,0);assert.equal(c.gpsLost,false);assert.equal(c.gpsRtlPending,false);
});
test('Energy RTL only latches after command dispatch returns success',()=>{
  const dash=fs.readFileSync(path.join(dir,'NavoDashboard.qml'),'utf8');
  assert(dash.includes('if(root.rtlMission())root.energyRtlIssued=true'));
  assert(!dash.includes('root.energyRtlIssued=true\n                if(!root.rtlMission())'));
});
test('App energy RTL respects MANUAL and ACRO pilot modes',()=>{
  const dash=fs.readFileSync(path.join(dir,'NavoDashboard.qml'),'utf8');
  assert(dash.includes('root.flightMode==="MANUAL" || root.flightMode==="ACRO"'));
});
test('Failsafe treats missing GPS lock and invalid fixes as unhealthy without throwing',()=>{
  const c=context('NavoFailsafeController.qml',{vehicle:{gps:{},coordinate:{isValid:true}},minGpsFix:3});
  assert.equal(c.gpsHealthy(),false);
  c.vehicle.gps.lock={rawValue:NaN};assert.equal(c.gpsHealthy(),false);
  c.vehicle.gps.lock.rawValue=3;assert.equal(c.gpsHealthy(),true);
});
test('Malformed sonar samples cannot enter the active lake',()=>{
  const c=context('NavoSonarMapping.qml',{bottomHardness:NaN,bottomEchoStrength:NaN,scanning:true,paused:false,sonarConnected:true,rawSamples:[],trackCoordinates:[],QtPositioning:{coordinate:coord}});
  for(const s of [{lat:52,lon:0,depth:null},{lat:52,lon:0,depth:-1},{lat:Infinity,lon:0,depth:2},{lat:52,lon:181,depth:2}])c.ingestSample(s);
  assert.equal(c.rawSamples.length,0);c.ingestSample({lat:52,lon:0,depth:2});assert.equal(c.rawSamples.length,1);
});
test('Recovered NAVO mobile UI remains reachable from the dashboard',()=>{
  const dash=fs.readFileSync(path.join(dir,'NavoDashboard.qml'),'utf8');
  const area=fs.readFileSync(path.join(dir,'NavoAreaScanOverlay.qml'),'utf8');
  const uploader=fs.readFileSync(path.join(dir,'NavoMissionUploader.qml'),'utf8');
  for(const token of ['property bool mapMaximized: false','id: areaScanMap','id:fishingMap','model:["HOLD","RTL"]','onMaximizeRequested: root.mapMaximized = !root.mapMaximized'])
    assert(dash.includes(token),token);
  assert(!dash.includes('id: statusStrip'),'legacy bottom status strip must stay removed');
  assert(area.includes('ACTIV "+(root.areaScan.activeLaneIndex+1)+"/"+root.areaScan.laneCount()'));
  assert(uploader.includes('property int verifiedCount: 0'));
});
test('NAVO starts as ArduPilot Rover Boat without vehicle-selection prompt',()=>{
  const srcDir=path.resolve(import.meta.dirname,'../custom/src');
  const h=fs.readFileSync(path.join(srcDir,'CustomPlugin.h'),'utf8');
  const cc=fs.readFileSync(path.join(srcDir,'CustomPlugin.cc'),'utf8');
  assert(h.includes('firstRunPromptStdIds() final { return {}; }'));
  assert(cc.includes('if(!units.contains(it.key()))units.setValue(it.key(),it.value())'));
  assert(cc.includes('QGCMAVLink::FirmwareClassArduPilot'));
  assert(cc.includes('QGCMAVLink::VehicleClassRoverBoat'));
});
test('Saved lakes expose persistent rename and confirmed delete controls',()=>{
  const ui=fs.readFileSync(path.join(dir,'NavoMyLakes.qml'),'utf8');
  const dash=fs.readFileSync(path.join(dir,'NavoDashboard.qml'),'utf8');
  const coordinator=fs.readFileSync(path.join(dir,'NavoScanCoordinator.qml'),'utf8');
  for(const token of ['beginRename','beginDelete','renameCurrentLake','deleteCurrentLake','ToolTip.text: "Șterge"'])
    assert(ui.includes(token),token);
  // Rename/delete controls live in NavoMyLakes; dashboard only opens/selects the persistent lake UI.
  assert(dash.includes('id: myLakesPopup'));
  assert(dash.includes('myLakesPopup.beginRename(modelData)'));
  assert(dash.includes('myLakesPopup.beginDelete(modelData)'));
  assert(coordinator.includes('function renameLake(id, name)'));
  assert(coordinator.includes('function deleteLake(id)'));
  assert(coordinator.includes('function clearActiveLake()'));
});
test('Deleting the active lake clears restored session state instead of leaving stale data',()=>{
  let deleted='';
  const c=context('NavoScanCoordinator.qml',{
    state:'PAUSED',lakeId:'lake-a',lakeName:'A',areaPoints:[1],bathymetryCells:[1],
    persistence:{deleteLake(id){deleted=id;return true},replaceWaypointNames:noop},
    sonarMapping:{scanning:false,paused:true,lakeId:'lake-a',rawSamples:[1],trackCoordinates:[1],currentLane:2,completedLanes:1,totalLanes:3},
    areaScan:{generatedPoints:[1],completedLanes:[0],activeLaneIndex:1,paused:true,lastBoatCoordinate:{}},
    fishingSpots:{fishingSpots:[1]},fishStore:{clear(){this.cleared=true}},
    lakeActivated:noop,status:noop
  });
  assert.equal(c.deleteLake('lake-a'),true);
  assert.equal(deleted,'lake-a');assert.equal(c.lakeId,'');assert.equal(c.state,'IDLE');
  assert.equal(c.areaScan.generatedPoints.length,0);assert.equal(c.sonarMapping.rawSamples.length,0);assert.equal(c.fishingSpots.fishingSpots.length,0);
});
test('Baiting animation is bound to live hopper command state',()=>{
  const panel=fs.readFileSync(path.join(dir,'NavoBaitingPanel.qml'),'utf8');
  const bridge=fs.readFileSync(path.join(dir,'NavoHopperBridge.qml'),'utf8');
  assert(panel.includes('property var hopperBridge'));
  assert(panel.includes('root.hopperLeftOpen ? -52 : 0'));
  assert(panel.includes('root.hopperRightOpen ? 52 : 0'));
  assert(bridge.includes('if(hopper===1||hopper===3)leftOpen=true'));
  assert(bridge.includes('if(hopper===2||hopper===3)rightOpen=true'));
});
test('Android workflow cancels superseded PR builds so UI fixes are tested in batches',()=>{
  const workflow=fs.readFileSync(path.resolve(import.meta.dirname,'../.github/workflows/android.yml'),'utf8');
  assert(workflow.includes('concurrency:'));
  assert(workflow.includes('cancel-in-progress: true'));
});
test('PRO history copies complete CHART columns, preserves scale and stays bounded',()=>{
  const c=context('NavoSonarPro.qml',{paused:false,connected:true,chartSource:null,samples:[.1,.8],history:[],historyColumns:2,chartOffsetMeters:1,chartRangeMeters:4});
  c.pushHistory();c.samples[0]=.9;
  assert.equal(c.history[0].samples[0],.1);
  assert.equal(c.history[0].offset,1);assert.equal(c.history[0].range,4);
  c.chartOffsetMeters=2;c.pushHistory();c.pushHistory();assert.equal(c.history.length,2);
  assert.equal(c.history[0].offset,2);
  c.paused=true;c.samples=[.5];c.pushHistory();assert.equal(c.history[1].samples.length,2);
  c.paused=false;c.connected=false;c.pushHistory();assert.equal(c.history[1].samples.length,2);
});
test('PRO rejects columns without physical range or offset',()=>{
  const c=context('NavoSonarPro.qml',{paused:false,connected:true,chartSource:null,samples:[.2,.7],history:[],historyColumns:240,chartOffsetMeters:0,chartRangeMeters:NaN});
  for(const range of [NaN,0,-1,Infinity]){c.chartRangeMeters=range;c.pushHistory();}
  c.chartRangeMeters=10;c.chartOffsetMeters=NaN;c.pushHistory();
  assert.equal(c.history.length,0);
  c.chartOffsetMeters=2;c.pushHistory();assert.equal(c.history.length,1);
});
test('PRO captures every source column with its own metadata during a burst',()=>{
  const source={connected:true,echoSamples:[.2,.8],chartOffsetMeters:1,chartRangeMeters:5};
  const c=context('NavoSonarPro.qml',{chartSource:source,koggerCompensation:false,paused:false,connected:false,samples:[],history:[],historyColumns:240});
  c.pushHistory();source.echoSamples=[.3,.9];source.chartOffsetMeters=2;source.chartRangeMeters=8;c.pushHistory();
  assert.equal(c.history.length,2);assert.equal(c.history[0].range,5);assert.equal(c.history[1].range,8);
  assert.equal(c.history[0].samples[1],.8);assert.equal(c.history[1].offset,2);
  c.paused=true;source.chartRangeMeters=20;c.pushHistory();assert.equal(c.history.length,2);
});
test('PRO impulse filter removes an isolated spike and preserves sustained returns',()=>{
  const c=context('NavoSonarPro.qml',{noiseFilterEnabled:false,noiseFloor:.1,gain:1});
  assert.equal(c.sampleStrength([.1,.9,.1],1),.8);
  c.noiseFilterEnabled=true;assert.equal(c.sampleStrength([.1,.9,.1],1),0);
  assert.equal(c.sampleStrength([.8,.9,.8],1),.7000000000000001);
  assert.equal(c.sampleStrength([.8,NaN,.8],1),0);
  c.gain=3;assert.equal(c.sampleStrength([.8,.9,.8],1),1);
});
test('V3 hopper control does not depend on legacy Nano timeout',()=>{
  const q=fs.readFileSync(path.join(dir,'NavoDashboard.qml'),'utf8');
  assert.ok(!q.includes('updateNanoHopperAvailability('));
  assert.ok(!q.includes('nanoHopperFallback'));
  assert.ok(q.includes('releaseAllowed: root.linkAlive && hopperSettings.confirmed'));
});
test('Replay cannot create live fish detections or checkpoints, including delayed detection events',()=>{
  let added=0,saved=0;const c=context('NavoDashboard.qml',{sonar:{replayMode:true,depthM:5},linkAlive:true,vehicle:{coordinate:coord(52,0),gps:{lock:{rawValue:3}}},fishStore:{addDetection(){added++;return {}}},scanCoordinator:{checkpoint(){saved++}}});
  assert.equal(c.recordLiveFishDetection(2,.7),false);assert.equal(added,0);assert.equal(saved,0);
  c.sonar.replayMode=false;assert.equal(c.recordLiveFishDetection(2,.7),true);assert.equal(added,1);assert.equal(saved,1);
  c.linkAlive=false;assert.equal(c.recordLiveFishDetection(2,.7),false);assert.equal(added,1);
});
test('PRO replay never captures the connected live vehicle GPS as recording metadata',()=>{
  const c=context('NavoSonarPro.qml',{chartSource:{replayMode:true,chartRawBytes:[1],chartRawByteCount:1},vehicle:{coordinate:coord(52,0),gps:{lock:{rawValue:3}},vehicleLinkManager:{communicationLost:false}},geoChartRecords:[],unlocatedChartCount:0});
  c.captureGeoChart();assert.equal(c.geoChartRecords.length,0);
});
test('Selecting G20 AUTO does not switch an armed vehicle into mission mode',()=>{
  const c=context('NavoDashboard.qml',{vehicle:{armed:true,flightMode:'Hold',missionFlightMode:'Auto'}});
  c.dispatchG20Action('MODE3','AUTO');assert.equal(c.vehicle.flightMode,'Hold');
});
test('Nano fallback does not bypass missing H743 link or invalid PWM',()=>{
  let sent=0;const c=context('NavoHopperBridge.qml',{vehicle:{vehicleLinkManager:{communicationLost:true},sendCommand(){sent++}},calibrated:true,commandRejected:noop,mavCompAutopilot1:1,mavCmdDoSetServo:183});
  assert.equal(c.setServo(9,1900),false);assert.equal(sent,0);
  c.vehicle.vehicleLinkManager.communicationLost=false;assert.equal(c.setServo(9,3000),false);assert.equal(sent,0);
  assert.equal(c.setServo(9,1900),true);assert.equal(sent,1);
});
test('Fish depth uses physical CHART range and offset, excluding echoes beyond the bottom',()=>{
  const found=[];const c=context('NavoFishDetector.qml',{surfaceIgnoreM:.35,bottomGuardM:.45,lastDetectionTime:0,cooldownMs:900,sensitivity:.72,minimumRunBins:2,targetDetected:(depth)=>found.push(depth)});
  const samples=Array(500).fill(0);samples[25]=.9;samples[26]=.9;samples[100]=.9;samples[101]=.9;
  c.analyze(samples,6,2,50);assert.equal(found.length,1);assert.equal(found[0],4.550000000000001);
  c.lastDetectionTime=0;c.analyze(samples,6,2,NaN);assert.equal(found.length,1);
});
test('Both hopper outputs are validated before any opening command',()=>{
 let sent=0;const c=context('NavoHopperBridge.qml',{vehicle:{vehicleLinkManager:{communicationLost:false},sendCommand(){sent++}},calibrated:true,releaseAllowed:true,commandPending:false,leftServoOutput:9,rightServoOutput:10,leftOpenPwm:1900,leftClosedPwm:1500,rightOpenPwm:3000,rightClosedPwm:1500,commandRejected:noop,mavCompAutopilot1:1,mavCmdDoSetServo:183});
 assert.equal(c.release(3),false);assert.equal(sent,0);
 c.rightOpenPwm=1900;c.releaseAllowed=false;assert.equal(c.release(3),false);assert.equal(sent,0);
});
test('Nano loss cannot block closing; H743 loss preserves open state and retries',()=>{
 let sent=0,retried=0;const c=context('NavoHopperBridge.qml',{vehicle:{vehicleLinkManager:{communicationLost:true},sendCommand(){sent++}},calibrated:true,releaseAllowed:false,commandPending:true,pendingHopper:3,leftOpen:true,rightOpen:true,leftServoOutput:9,rightServoOutput:10,leftClosedPwm:1500,rightClosedPwm:1500,closeTimer:{restart(){retried++}},commandRejected:noop,commandSent:noop,mavCompAutopilot1:1,mavCmdDoSetServo:183});
 assert.equal(c.closePending(),false);assert.equal(sent,0);assert.equal(c.leftOpen,true);assert.equal(c.commandPending,true);assert.equal(retried,1);
 c.vehicle.vehicleLinkManager.communicationLost=false;assert.equal(c.closePending(),true);assert.equal(sent,2);assert.equal(c.leftOpen,false);assert.equal(c.rightOpen,false);assert.equal(c.commandPending,false);
});
test('Replay point saves cannot write into the currently active live lake',()=>{
 const c=context('NavoDashboard.qml',{sonar:{replayMode:true},scanCoordinator:{lakeId:'live-lake'}});
 assert.equal(c.requireActiveLakeForPointSave(),false);c.sonar.replayMode=false;assert.equal(c.requireActiveLakeForPointSave(),true);
});
test('Recorded replay refuses live geometry changes and new navigation or mission starts',()=>{
 const writes=[];const c=context('NavoScanCoordinator.qml',{readOnlyReplay:true,status:noop,areaScan:{generatedPoints:[1]},sonarMapping:{rawSamples:[1]},state:'IDLE'});
 c.checkpoint=()=>{writes.push(1);return true};
 assert.equal(c.prepareRectangle(coord(52,0),coord(52.001,.001)).length,0);
 assert.equal(c.preparePolygon([coord(52,0),coord(52.001,0),coord(52.001,.001)]).length,0);
 assert.equal(c.prepareMission(false).length,0);c.state="PAUSED";assert.equal(c.resume().length,0);assert.equal(c.state,"PAUSED");
 assert.deepEqual(c.areaScan.generatedPoints,[1]);assert.equal(writes.length,0);
 let commands=0;const d=context('NavoDashboard.qml',{sonarController:{replayMode:true},vehicle:{guidedModeGotoLocation(){commands++}},lastNavigationStatus:''});
 assert.equal(d.navigateToCoordinate(coord(52,0)),false);assert.equal(d.startMission(),false);assert.equal(d.startUploadedMission(),false);assert.equal(commands,0);
 d.sonarController.replayMode=false;assert.equal(d.allowLiveAction(),true);
});
test('Recorded replay Map refuses area drawing and its deferred commit',()=>{
 const c=context('NavoMap.qml',{recordedReplay:true,areaDrawMode:'polygon',areaDraftPoints:[1,2,3],areaPolygonRequested(){throw Error('Replay geometry reached live session')}});
 assert.equal(c.beginAreaRectangle(),false);assert.equal(c.beginAreaPolygon(),false);assert.equal(c.finishAreaDrawing(),false);
 assert.equal(c.areaDrawMode,'polygon');assert.deepEqual(c.areaDraftPoints,[1,2,3]);
});
test('Servo replies are filtered by vehicle, component and command',()=>{
 const c=context('NavoHopperBridge.qml',{vehicle:{id:42},mavCompAutopilot1:1,mavCmdDoSetServo:183,servoResponse:'original',servoResponseAtMs:0});
 for(const args of [[43,1,183,0,0],[42,2,183,0,0],[42,1,184,0,0]])assert.equal(c.receiveServoResult(...args),false);
 assert.equal(c.servoResponse,'original');assert.equal(c.servoResponseAtMs,0);
});
test('Accepted servo ACK does not alter requested hopper position',()=>{
 const c=context('NavoHopperBridge.qml',{vehicle:{id:42},mavCompAutopilot1:1,mavCmdDoSetServo:183,leftOpen:false,rightOpen:true,commandPending:true});
 assert.equal(c.receiveServoResult(42,1,183,0,0),true);
 assert.match(c.servoResponse,/acceptat/);assert(c.servoResponseAtMs>0);
 assert.equal(c.leftOpen,false);assert.equal(c.rightOpen,true);assert.equal(c.commandPending,true);
});
test('Servo timeout, duplicate and rejected replies remain failures',()=>{
 const c=context('NavoHopperBridge.qml',{vehicle:{id:42},mavCompAutopilot1:1,mavCmdDoSetServo:183});
 c.receiveServoResult(42,1,183,0,1);assert.match(c.servoResponse,/timeout/);
 c.receiveServoResult(42,1,183,0,2);assert.match(c.servoResponse,/netrimisă/);
 c.receiveServoResult(42,1,183,2,0);assert.match(c.servoResponse,/respins/);
 c.receiveServoResult(42,1,183,5,0);assert.match(c.servoResponse,/în curs/);
});
test('Changing the vehicle removes stale servo feedback',()=>{
 const c=context('NavoHopperBridge.qml',{servoResponse:'acceptat',servoResponseAtMs:100});
 c.resetServoFeedback();assert.equal(c.servoResponseAtMs,0);assert.match(c.servoResponse,/Niciun/);
 const panel=fs.readFileSync(path.join(dir,'NavoBaitingPanel.qml'),'utf8');
 assert(panel.includes('physicalPositionStatus'));assert(!panel.includes('CUVE BASCULEAZĂ'));
});
test('Sonar PRO preserves recorded ecogram at EOF and starts a clean new replay',()=>{
 const source=fs.readFileSync(path.join(dir,'NavoSonarPro.qml'),'utf8');
 const handler=source.match(/onReplayActiveChanged:\s*(\{[^\n]*\})/)[1];
 const c=vm.createContext({history:[{sequence:1},{sequence:2}],replayActive:false,menuOpen:true});c.root=c;
 vm.runInContext(handler,c);assert.equal(c.history.length,2);assert.equal(c.menuOpen,false);
 c.replayActive=true;vm.runInContext(handler,c);assert.equal(c.history.length,0);
});
test('Sonar PRO displays the Dashboard native bottom-depth fallback',()=>{
 const dashboard=fs.readFileSync(path.join(dir,'NavoDashboard.qml'),'utf8');
 const pro=dashboard.slice(dashboard.indexOf('id: sonarProPage'),dashboard.indexOf('id: sonarProPage')+1800);
 assert.match(pro,/depthM:\s*root\.depthM/);
 assert.match(dashboard,/processedBottomDepthM/);
});
test('Sonar PRO labels the finished recording as replay rather than live input',()=>{
 const c=context('NavoSonarPro.qml',{chartSource:{replayMode:true},replayActive:false,connected:true,paused:false});
 assert.equal(c.sourceStatusText(),'REPLAY • FINAL');
 c.replayActive=true;assert.equal(c.sourceStatusText(),'REPLAY');
 c.chartSource.replayMode=false;assert.equal(c.sourceStatusText(),'LIVE');
 c.connected=false;assert.equal(c.sourceStatusText(),'OFFLINE');
});
test('Installed acceptance compares restart with the saved snapshot including late native samples',()=>{
 const late=Array(14486).fill({depth:3}),saved={};let stopped=false;
 const dashboard={replayMappingController:{rawSamples:late},sonarMappingController:{rawSamples:[]},
   saveRecordedReplayLake(){saved.sonarSamples=late.slice();return 'replay'},
   lakePersistence:{lakeState(){return saved}},sonarController:{stopReplay(){stopped=true}},
   areaCoordinator:{activateLake(){dashboard.sonarMappingController.rawSamples=saved.sonarSamples.slice();return true}}};
 const c=context('NavoAndroidAcceptance.qml',{dashboard,samples:14460,liveId:'live',replayId:'',evidence:{samplesAtEof:14460}});
 c.saveReplaySnapshot();assert.equal(c.samples,14486);assert.equal(c.evidence.samplesAtEof,14460);
 assert.equal(c.evidence.savedSamples,14486);assert.equal(c.evidence.activatedSamples,14486);assert(stopped);
});
test('Installed acceptance refuses sample loss at save or immediate activation',()=>{
 let stopped=false;const source=Array(14486).fill({depth:3}),saved={sonarSamples:source.slice(1)};
 const dashboard={replayMappingController:{rawSamples:source},sonarMappingController:{rawSamples:[]},
   saveRecordedReplayLake(){return 'replay'},lakePersistence:{lakeState(){return saved}},
   sonarController:{stopReplay(){stopped=true}},areaCoordinator:{activateLake(){return true}}};
 const c=context('NavoAndroidAcceptance.qml',{dashboard,samples:14460,liveId:'live',replayId:'',evidence:{}});
 assert.throws(()=>c.saveReplaySnapshot(),/Saved sonar sample count differs/);assert.equal(stopped,false);
 saved.sonarSamples=source.slice();assert.throws(()=>c.saveReplaySnapshot(),/Activated sonar sample count differs/);
});
test('Installed acceptance keeps exact persisted and restored counts after restart',()=>{
 const source=Array(14486).fill({depth:3}),saved={sonarSamples:source};
 const dashboard={vehicle:null,sonarController:{},lakePersistence:{lakeState(){return saved}},
   sonarMappingController:{rawSamples:source.slice(1)},areaCoordinator:{lakeId:'replay'},mapAreaScanController:{}};
 const c=context('NavoAndroidAcceptance.qml',{dashboard,backend:{configuration:{phase:'restore',liveId:'live',replayId:'replay',samples:14486}},
   started:Date.now(),stage:'start',liveId:'',replayId:'',samples:0,evidence:{}});
 assert.throws(()=>c.step(),/Restored sonar sample count differs: expected 14486, restored 14485/);
 assert.equal(c.evidence.savedSamples,14486);assert.equal(c.evidence.restoredSamples,14485);
 saved.sonarSamples=source.slice(1);assert.throws(()=>c.step(),/Persisted sonar sample count differs/);
});
test('Installed 3D evidence waits for visible page and rendering settlement',()=>{
 const c=context('NavoAndroidAcceptance.qml',{stage:'3d',entered:Date.now(),started:Date.now(),evidence:{sceneReady:false},
  backend:{inspect:()=>({mesh3dVisible:true,mesh3dVertices:799,mesh3dTriangles:802})},
  dashboard:{vehicle:null,activePage:7},publish:noop});
 c.publish=noop;c.step();assert.equal(c.evidence.sceneReady,false);
 c.entered=Date.now()-5000;c.step();assert.equal(c.evidence.sceneReady,true);
 c.dashboard.activePage=0;assert.throws(()=>c.step(),/3D page is not selected/);
});
test('3D camera centres the terrain and GPS track and fits portrait and landscape',()=>{
 const c=context('NavoBathymetry3D.qml',{meshEngine:{vertices:[{x:0,y:0,depth:1},{x:100,y:200,depth:10}]},boatTrack:[],verticalExaggeration:2,
   width:960,height:540,Qt:{point:(x,y)=>({x,y})}});
 c.sceneBounds=c.boundsForScene();assert.equal(c.sceneBounds.centerX,50);assert.equal(c.sceneBounds.centerY,-11);assert.equal(c.sceneBounds.centerZ,-100);
 c.fitCamera();const wide=c.cameraDistance;assert(wide>c.sceneBounds.radius);assert(c.cameraFramed);
 c.width=540;c.height=960;c.fitCamera();assert(c.cameraDistance>wide);
 c.localPoint=()=>({x:400,y:0,z:300});c.boatTrack=[{lat:1,lon:2}];c.sceneBounds=c.boundsForScene();assert.equal(c.sceneBounds.centerX,200);assert.equal(c.sceneBounds.centerZ,50);
 const source=fs.readFileSync(path.join(dir,'NavoBathymetry3D.qml'),'utf8');assert.match(source,/Node\{id:cameraPivot/);assert.match(source,/position:Qt\.vector3d\(0,0,root.cameraDistance\)/);
});
test('Energy guard is opt-in and rejects invalid route/battery and inadequate return reserve',()=>{
 const c=context('NavoEnergyGuard.qml',{calibrated:false,reservePercent:25,consumptionPercentPerKm:12});
 assert(c.canStart(NaN,NaN));c.calibrated=true;
 for(const value of [NaN,Infinity,-1])assert.equal(c.canStart(value,100),false);
 for(const value of [NaN,Infinity,-1,101])assert.equal(c.canStart(1000,value),false);
 assert.equal(c.requiredPercent(2000),49);assert.equal(c.canStart(2000,48),false);assert(c.canStart(2000,49));
 c.consumptionPercentPerKm=0;assert.equal(c.canStart(0,100),false);
});
test('Route energy includes approach, every corridor and return HOME',()=>{
 const c=context('NavoDashboard.qml',{vehicle:{coordinate:coord(0,0),homePosition:coord(0,0)}});
 const distance=c.routeDistanceWithReturn([coord(0,.001),coord(0,.002)]);assert(Math.abs(distance-445.28)<.001);
 c.vehicle.homePosition={isValid:false};assert(Number.isNaN(c.routeDistanceWithReturn([coord(0,.001)])));
});
test('GPS anchor refuses unsupported commands and never overrides pilot mode changes',()=>{
 const commands=[];const vehicle={coordinate:coord(52,0),vehicleLinkManager:{communicationLost:false},gps:{lock:{rawValue:3}},flightMode:'Guided',
   guidedModeGotoLocation(c){commands.push(c)},pauseVehicle(){throw Error('Anchor should retain GUIDED rather than switch to HOLD')}};
 const c=context('NavoDigitalAnchor.qml',{vehicle,QtPositioning:{coordinate:coord},active:false,correctionActive:false,driftRadiusM:1.5,status:noop});
 assert(c.engage());assert.equal(commands.length,1);c.maintain();assert(c.guidedConfirmed);
 vehicle.coordinate=coord(52,.0001);c.maintain();assert.equal(commands.length,2);c.maintain();assert.equal(commands.length,2);
 vehicle.coordinate=coord(52,0);c.maintain();assert.equal(c.correctionActive,false);
 vehicle.flightMode='Manual';c.maintain();assert.equal(c.active,false);assert.equal(commands.length,2);
 vehicle.guidedModeGotoLocation=null;assert.equal(c.engage(),false);
});
test('GPS anchor cancels on invalid coordinates and link loss',()=>{
 const vehicle={coordinate:coord(52,0),vehicleLinkManager:{communicationLost:false},gps:{lock:{rawValue:3}},flightMode:'Guided',guidedModeGotoLocation:noop,pauseVehicle:noop};
 const c=context('NavoDigitalAnchor.qml',{vehicle,QtPositioning:{coordinate:coord},active:false,correctionActive:false,driftRadiusM:1.5,status:noop});
 assert(c.engage());vehicle.coordinate={isValid:false};c.maintain();assert.equal(c.active,false);
 vehicle.coordinate=coord(52,0);assert(c.engage());vehicle.vehicleLinkManager.communicationLost=true;c.maintain();assert.equal(c.active,false);
 vehicle.vehicleLinkManager.communicationLost=false;
 for(const invalid of [undefined,NaN,2]){vehicle.gps.lock.rawValue=invalid;assert.equal(c.engage(),false)}
 vehicle.gps.lock=null;assert.equal(c.engage(),false);
 vehicle.gps.lock={rawValue:3};assert(c.engage());vehicle.gps.lock.rawValue=NaN;c.maintain();assert.equal(c.active,false);
});
test('Dashboard anchor is reachable but blocked during replay and active operations',()=>{
 let engaged=0,held=0;const c=context('NavoDashboard.qml',{digitalAnchor:{active:false,engage(){engaged++;return true}},linkAlive:true,
   sonarController:{replayMode:true},scanCoordinator:{state:'IDLE'},awaitingMissionStart:false,baitingController:{enabled:false}});
 assert.equal(c.toggleDigitalAnchor(),false);assert.equal(engaged,0);c.sonarController.replayMode=false;
 c.scanCoordinator.state='SCANNING';assert.equal(c.toggleDigitalAnchor(),false);c.scanCoordinator.state='IDLE';assert(c.toggleDigitalAnchor());
 c.digitalAnchor.active=true;c.holdMission=()=>{held++};assert(c.toggleDigitalAnchor());assert.equal(held,1);
});
test('Navigation and baiting refuse calibrated energy failure before releasing anchor or commanding H743',()=>{
 let commands=0;const c=context('NavoDashboard.qml',{linkAlive:true,vehicle:{guidedModeGotoLocation(){commands++}},sonarController:{replayMode:false},
   scanCoordinator:{state:'IDLE'},awaitingMissionStart:false,baitingController:{enabled:false,startCycle(){commands++}},hopperBridge:{calibrated:true},
   digitalAnchor:{release(){commands++}},energyGuard:{calibrated:true,canStart(){return false},message(){return 'insufficient'}},battery:null});
 c.routeDistanceWithReturn=()=>1000;
 assert.equal(c.navigateToCoordinate(coord(52,0)),false);assert.equal(c.startBaiting({coordinate:coord(52,0)},'spot',1),false);assert.equal(commands,0);
 c.linkAlive=false;assert.equal(c.navigateToCoordinate(coord(52,0)),false);
});
test('Area Scan checks energy before START and uses only remaining corridors on Resume',()=>{
 let started=0,released=0,checked=[];const coordinate=coord(52,0),route=[coord(52,.001)];
 const c=context('NavoDashboard.qml',{sonarController:{replayMode:false},linkAlive:true,vehicle:{rover:true,coordinate,gps:{lock:{rawValue:3}},flightMode:'Hold',missionFlightMode:'Auto',startMission(){started++}},
   awaitingMissionStart:false,missionUploader:{uploadVerified:true},scanCoordinator:{state:'RESUME_READY',lakeId:'lake'},sonarConnected:true,
   areaScanController:{resumeRoute(){return route},generatedPoints:[coordinate,...route]},digitalAnchor:{release(){released++}}});
 c.checkEnergyForRoute=(points)=>{checked=points;return false};assert.equal(c.startUploadedMission(),false);assert.equal(started,0);assert.equal(released,0);assert.equal(checked,route);
 c.checkEnergyForRoute=()=>true;assert(c.startUploadedMission());assert.equal(started,1);assert.equal(released,1);
});
test('Pilot takeover discards pending GPS recovery without app HOLD or RTL',()=>{
 let now=1790240400000,hold=0,rtl=0;
 const vehicle={flightMode:'Auto',vehicleLinkManager:{communicationLost:false},gps:{lock:{rawValue:2}},coordinate:coord(52,0)};
 const c=context('NavoFailsafeController.qml',{Date:{now:()=>now},enabled:true,vehicle,minGpsFix:3,linkLost:false,gpsLost:false,linkGraceSeconds:30,gpsRecoverySeconds:60,gpsReturnHomeSeconds:120,rtlRequested:()=>rtl++,holdRequested:()=>hold++,recovered:noop});
 c.tick();assert.equal(hold,1);now+=125000;c.tick();assert(c.gpsRtlPending);
 for(const mode of ['Manual',' Acro ']){vehicle.flightMode=mode;c.tick();assert.equal(c.gpsRtlPending,false);vehicle.gps.lock.rawValue=3;c.tick();assert.equal(rtl,0)}
 vehicle.flightMode='Auto';c.tick();assert.equal(rtl,0);
});
test('V3 release cannot leave the drop while onboard completion is pending',()=>{
 let exited=0,restarted=0;
 const c=context('NavoBaitingController.qml',{enabled:true,state:4,releaseState:4,hopper:1,releaseComplete:false,vehicleCoordinateValid:()=>true,restart:()=>restarted++,finishExit:()=>exited++,makeExitCoordinate:()=>null});
 c.vehicleCoordinateValid=()=>true;c.finishExit=()=>exited++;c.makeExitCoordinate=()=>null;
 const timeout=timerHandler('NavoBaitingController.qml','postDropTimer',c);
 timeout();assert.equal(restarted,1);assert.equal(exited,0);
 c.releaseComplete=true;timeout();assert.equal(exited,1);
});
test('V3 request sequence persists, follows onboard acknowledgement and refuses exhaustion',()=>{
 const settings={requestSequence:5};const telemetry={lastRequest:8};
 const c=context('NavoDashboard.qml',{hopperSettings:settings,h743Telemetry:telemetry});
 assert.equal(c.nextHardwareRequest(),9);assert.equal(settings.requestSequence,9);
 assert.equal(c.nextHardwareRequest(),10);telemetry.lastRequest=16777215;assert.equal(c.nextHardwareRequest(),0);
});
test('V3 lights require live capability and use explicit state with shared request IDs',()=>{
 const sent=[];const telemetry={connected:false,capabilities:1,lightsValid:true,headlightOn:true,positionLightsOn:false,lastRequest:0};
 const c=context('NavoDashboard.qml',{linkAlive:true,vehicle:{sendCommand:(...args)=>sent.push(args)},sonarController:{replayMode:false},hopperBridge:{commandPending:false},h743Telemetry:telemetry,hopperSettings:{requestSequence:0}});
 assert.equal(c.commandH743Light(1,2,'Far'),false);assert.equal(sent.length,0);
 telemetry.connected=true;assert(c.commandH743Light(1,2,'Far'));assert.deepEqual(sent[0].slice(0,6),[1,31001,true,1,0,1]);
 assert(c.commandH743Light(2,2,'Poziții'));assert.deepEqual(sent[1].slice(3,6),[2,1,2]);
 c.sonarController.replayMode=true;assert.equal(c.commandH743Light(1,1,'Far'),false);assert.equal(sent.length,2);
 c.sonarController.replayMode=false;telemetry.capabilities=0;assert.equal(c.commandH743Light(1,1,'Far'),false);
});
test('V3 close can supersede a pending release but cannot bypass stale telemetry',()=>{
 const sent=[];const c=context('NavoHopperBridge.qml',{vehicle:{vehicleLinkManager:{communicationLost:false},sendCommand:(...a)=>sent.push(a)},hardwareTelemetry:{connected:true,capabilities:8,hopperStateValid:true,hopperMask:3},commandPending:true,nextRequest:()=>2,onboardWatchdog:{restart:noop},mavCompAutopilot1:1,leftServoOutput:9,rightServoOutput:10,leftClosedPwm:1500,leftOpenPwm:1900,rightClosedPwm:1500,rightOpenPwm:1900,releaseHoldMs:900,commandSent:noop,commandRejected:noop});
 assert.equal(c.sendOnboard(3,1),false);assert(c.closeOnboard());assert.equal(sent[0][3],4);
 c.hardwareTelemetry.connected=false;assert.equal(c.closeOnboard(),false);assert.equal(sent.length,1);
});
test('Dashboard redesign preserves all three read-only diagnostics and explicit home credits',()=>{
  const dash=fs.readFileSync(path.join(dir,'NavoDashboard.qml'),'utf8');
  const panel=fs.readFileSync(path.join(dir,'NavoStatusDetails.qml'),'utf8');
  const g20=fs.readFileSync(path.join(dir,'NavoG20Controller.qml'),'utf8');
  assert.match(dash,/Pescaru' lu' Pește/);
  assert.match(dash,/build and design by Costel Apreutesei/);
  for(const section of ['battery','temperature','mode'])
    assert(dash.includes('dashboardDetails.showSection("'+section+'")'));
  assert.match(dash,/NavoStatusDetails\s*\{/);
  assert.match(panel,/temperatureSamples/);
  assert.match(panel,/date/i); // Date.now-based genuine time series, not demo points.
  assert.match(panel,/FĂRĂ TELEMETRIE/);
  assert.match(panel,/BMS \/ echilibrare celule/);
  assert.match(panel,/Mod confirmat de H743/);
  assert.match(g20,/dashboardModeChannel: 5/);
  assert.match(g20,/dashboardModePosition/);
  assert.doesNotMatch(panel,/\bsendCommand\s*\(|\bflightMode\s*=/);
});
test('Tabbed NAVO settings expose real camera, sonar, audio, energy and QGC controls',()=>{
  const page=fs.readFileSync(path.join(dir,'NavoSettingsV3.qml'),'utf8');
  const ethernet=fs.readFileSync(path.join(dir,'NavoEthernetSettings.qml'),'utf8');
  const alerts=fs.readFileSync(path.join(dir,'NavoAlertSettings.qml'),'utf8');
  const steering=fs.readFileSync(path.join(dir,'NavoSteeringPanel.qml'),'utf8');
  const dashboard=fs.readFileSync(path.join(dir,'NavoDashboard.qml'),'utf8');
  const cmake=fs.readFileSync(path.resolve(dir,'../CMakeLists.txt'),'utf8');
  for(const name of ['General','Avansat','Integrare','QGroundControl'])
    assert(page.includes('"'+name+'"'),name+' tab absent');
  assert(!page.includes('text: "Unități"'));
  assert.equal((page.match(/root\.settingsToolRequested\(\)/g)||[]).length,1);
  assert.match(dashboard,/id: settingsPage\s*NavoSettingsV3\s*\{/);
  assert.match(cmake,/qml\/NavoSettingsV3\.qml/);
  assert.match(page,/anchors\.bottom: saveFooter\.visible \? saveFooter\.top : parent\.bottom/);
  assert.match(page,/ethernetSettings\.saveEndpoints\(\)/);
  assert.match(dashboard,/onSettingsToolRequested:/);
  assert.match(ethernet,/function saveEndpoints\(\)/);
  assert.match(ethernet,/videoTest\.start\(\)/);
  assert.match(ethernet,/videoTest\.stop\(\)/);
  assert.match(ethernet,/root\.sonar\.connectSonar\(\)/);
  assert.match(ethernet,/root\.sonar\.disconnectSonar\(\)/);
  assert.match(ethernet,/lanDiscovery\.scan\(\)/);
  assert.match(alerts,/controller\.configure\(sound\.checked, voice\.checked, volume\.value\)/);
  assert.match(alerts,/root\.controller\.test\(\)/);
  assert.match(alerts,/root\.audio\.stop\(\)/);
  assert.match(steering,/objectName: "steeringConfirmation"/);
  assert.match(steering,/objectName: "steeringEnable"/);
  assert.match(steering,/objectName: "steeringStop"/);
  assert.match(page,/confirmed = false; root\.energy\.reservePercent = value/);
  assert.match(page,/confirmed = false; root\.energy\.consumptionPercentPerKm = value/);
  assert.doesNotMatch(page,/\bvehicle\.flightMode\s*=/);
  assert.doesNotMatch(ethernet,/\bvehicle\.flightMode\s*=/);
});
test('NAVO journal tabs preserve trip persistence, frozen entry context and accessible editors',()=>{
  const journal=fs.readFileSync(path.join(dir,'NavoFishingJournal.qml'),'utf8');
  for(const label of ['Partide','Însemnări','Statistici','Capturi • Nădiri • Observații'])
    assert(journal.includes('"'+label+'"'),label);
  for(const marker of ['journalTrips','journalSummary','journalEntryFilter','journalEntries','journalEntryEditor','journalEntrySave','journalSpecies','journalWeight','journalBait','journalEntryText'])
    assert(journal.includes('"'+marker+'"'),marker);
  assert.match(journal,/function beginEntry\(entry\)/);
  assert.match(journal,/function saveEntry\(\)/);
  assert.match(journal,/persistence\.saveFishingEntry\(selectedId,data\)/);
  assert.match(journal,/pendingEntryId=modelData\.id/);
  assert.match(journal,/startFishingTrip\(root\.lakeId,tripTitle\.text\)/);
  assert.match(journal,/finishFishingTrip\(root\.selectedId\)/);
  assert.match(journal,/deleteFishingTrip\(root\.pendingDeleteId\)/);
  assert.match(journal,/replayMode \|\| selected\.endedAt/);
  assert.match(journal,/background: Rectangle \{ color: "#071e30"; radius: 12; border.color: "#20d9ed" \}/);
});
test('NAVO lake library preserves saved partitions, session replay and confirmed delete',()=>{
  const lakes=fs.readFileSync(path.join(dir,'NavoMyLakes.qml'),'utf8');
  const dashboard=fs.readFileSync(path.join(dir,'NavoDashboard.qml'),'utf8');
  for(const tab of ['Prezentare','Sesiuni sonar','Acțiuni','Bălți salvate','Baltă activă','Administrare'])
    assert((lakes+dashboard).includes('"'+tab+'"'),tab);
  for(const action of ['selectLake(lake)','beginRename(lake)','beginDelete(lake)','renameCurrentLake()','deleteCurrentLake()','restoreAndOpen(destination)','sessionsForLake(id)'])
    assert(lakes.includes(action),action);
  for(const event of ['lakeRestored(selectedLakeId)','openLakeMap(selectedLakeId)','openLakeBathymetry(selectedLakeId)','openLakeFishingSpots(selectedLakeId)','resumeLakeScan(selectedLakeId)','root.openSession(modelData)'])
    assert(lakes.includes(event),event);
  assert.match(lakes,/scanCoordinator\.deleteLake\(id\)/);
  assert.match(lakes,/scanCoordinator\.renameLake\(editLake\.id,name\)/);
  assert.match(lakes,/scanCoordinator\.restoreLake\(selectedLakeId\)/);
  assert.match(dashboard,/myLakesPopup\.selectLake\(modelData\)/);
  assert.match(dashboard,/myLakesPopup\.beginRename\(modelData\)/);
  assert.match(dashboard,/myLakesPopup\.beginDelete\(modelData\)/);
});
test('NAVO offline tabs keep quota, async downloads, pause/resume and delete safeguards',()=>{
  const offline=fs.readFileSync(path.join(dir,'NavoOfflineMaps.qml'),'utf8');
  for(const tab of ['Descarcă','Zone salvate','Informații'])
    assert(offline.includes('"'+tab+'"'),tab);
  for(const marker of ['offlineSetName','offlineMapType','offlineMinZoom','offlineMaxZoom'])
    assert(offline.includes('"'+marker+'"'),marker);
  assert.match(offline,/Math\.min\(5000,tileLimit\)/);
  assert.match(offline,/manager\.startDownload\(name,typeChoice\.currentText\)/);
  assert.match(offline,/manager\.findName\(name\)/);
  assert.match(offline,/tileSet\.cancelDownloadTask\(\)/);
  assert.match(offline,/tileSet\.resumeDownloadTask\(\)/);
  assert.match(offline,/root\.showRegionRequested\(/);
  assert.match(offline,/root\.manager\.deleteTileSet\(root\.pendingDelete\)/);
  assert.match(offline,/!root\.pendingDelete\.defaultSet && !root\.pendingDelete\.downloading/);
  assert.match(offline,/root\.validRegion/);
});
test('NAVO compact journal and offline layouts wrap narrow-screen actions',()=>{
  const journal=fs.readFileSync(path.join(dir,'NavoFishingJournal.qml'),'utf8');
  const offline=fs.readFileSync(path.join(dir,'NavoOfflineMaps.qml'),'utf8');
  const dashboard=fs.readFileSync(path.join(dir,'NavoDashboard.qml'),'utf8');
  assert.match(journal,/columns:\s*root\.width < 385 \? 2 : 3/);
  assert.match(journal,/Flow\s*\{\s*Layout\.fillWidth:\s*true[\s\S]*?text: "Deschide însemnările"/);
  assert.match(journal,/onClicked: root\.journalTab = 1/);
  assert.match(offline,/columns:\s*root\.width < 370 \? 2 : 3/);
  assert.match(offline,/columns:\s*root\.width < 460 \? 2 : 5/);
  assert.match(offline,/columns:\s*root\.width < 440 \? 1 : 2/);
  assert.match(offline,/id:\s*minZoom;\s*objectName:\s*"offlineMinZoom"/);
  assert.match(offline,/id:\s*maxZoom;\s*objectName:\s*"offlineMaxZoom"/);
  assert.match(dashboard,/id:\s*lakesPage/);
  assert.match(dashboard,/id:\s*myLakesPopup/);
  // No UI button can silently delete a tile set or a lake without its confirmation dialog.
  assert.match(offline,/root\.pendingDelete=tileSet;\s*deleteDialog\.open\(\)/);
  assert.match(dashboard,/myLakesPopup\.beginDelete\(modelData\)/);
});

test('GNSS moving-baseline yaw has explicit GPS1/GPS2 priority and H743 fallback',()=>{
  const dirSrc=path.resolve(dir,'../src');
  const header=fs.readFileSync(path.join(dirSrc,'NavoGnssHeading.h'),'utf8');
  const cpp=fs.readFileSync(path.join(dirSrc,'NavoGnssHeading.cc'),'utf8');
  const dash=fs.readFileSync(path.join(dir,'NavoDashboard.qml'),'utf8');
  const map=fs.readFileSync(path.join(dir,'NavoMap.qml'),'utf8');
  const compass=fs.readFileSync(path.join(dir,'NavoHeadingCompass.qml'),'utf8');
  const plugin=fs.readFileSync(path.join(dirSrc,'CustomPlugin.cc'),'utf8');
  const cmake=fs.readFileSync(path.resolve(dir,'../CMakeLists.txt'),'utf8');
  assert.match(plugin,/qmlRegisterType<NavoGnssHeading>/);
  assert.match(cmake,/src\/NavoGnssHeading\.cc/);
  assert.match(header,/Q_PROPERTY\(double selectedHeadingDeg/);
  assert.match(header,/Q_PROPERTY\(QString headingSource/);
  assert.match(cpp,/MAVLINK_MSG_ID_GPS_RAW_INT/);
  assert.match(cpp,/MAVLINK_MSG_ID_GPS2_RAW/);
  assert.match(cpp,/_observe\(_gps1, gps\.fix_type, gps\.satellites_visible, gps\.yaw\)/);
  assert.match(cpp,/_observe\(_gps2, gps\.fix_type, gps\.satellites_visible, gps\.yaw\)/);
  assert.doesNotMatch(cpp,/gps\.cog|gps\.hdg/); // COG is travel direction, not antenna yaw.
  assert.match(cpp,/rawYaw >= 1 && rawYaw <= 36000/);
  assert.match(cpp,/rawYaw == 36000 \? 0\.0/); // True north, NOT invalid.
  assert.match(cpp,/fix >= 3 && receiver\.sats >= 4/);
  assert.match(cpp,/lastYawMs = -1/); // Explicit invalidity revokes old heading.
  assert.match(header,/kYawTimeoutMs = 3000/);
  assert.match(cpp,/if \(_available\(_gps1\)\) return &_gps1/);
  assert.match(cpp,/if \(_available\(_gps2\)\) return &_gps2/);
  assert.match(cpp,/return _autopilotHeadingDeg;\s*\/\/ Only display fallback/);
  assert.match(cpp,/if \(!alive\) \{/);
  assert.match(cpp,/if \(next == _vehicle\) return/);
  assert.match(dash,/id: gnssHeading/);
  assert.match(dash,/headingDeg: gnssHeading\.selectedHeadingDeg/);
  assert.equal((dash.match(/headingOverrideEnabled: true/g)||[]).length,4);
  assert.equal((dash.match(/headingOverrideDeg: root\.headingDeg/g)||[]).length,4);
  assert.match(map,/headingOverrideEnabled \? headingOverrideDeg/);
  assert.match(map,/root\.boatHeadingDeg - liveMap\.bearing/);
  assert.match(compass,/headingSource/);
  assert.match(dash,/Heading GNSS dual-antenă/);
  assert.match(dash,/Heading H743 \(rezervă\)/);
  assert.doesNotMatch(cpp,/setFlightMode|sendCommand|armVehicle|disarmVehicle/);
});
function cancellable(options={}) {
 const events=[];
 const bait=context('NavoBaitingController.qml',{enabled:true,state:2,idleState:0,navigateState:1,approachState:2,
   finalApproachState:3,settleState:4,releaseState:5,exitState:6,returnHomeState:7,completeState:8,abortedState:9,
   targetSpeedMps:1,commandedSpeedMps:1,monitorTimer:{stop(){events.push('monitor-stop')}},
   settleTimer:{stop(){events.push('settle-stop')}},postDropTimer:{stop(){events.push('drop-stop')}},
   rampTimer:{running:true,stop(){this.running=false;events.push('ramp-stop')}},
   stopRequested(){events.push('extra-hold')},stateChangedDetailed:noop,cycleFinished:noop});
 const route=context('NavoRoutePlan.qml',{active:true,startedAtMs:0,generation:5,state:'RUNNING',changed:noop,status:noop});
 const uploader=context('NavoMissionUploader.qml',{uploadTimeout:{stop(){events.push('upload-timer-stop')}},uploadInProgress:true,uploadVerified:true,preparedCount:8,verifiedCount:8});
 const c=context('NavoDashboard.qml',{sonarController:{replayMode:false},linkAlive:true,awaitingMissionStart:true,directGotoActive:true,
   areaDrawingGeneration:0,pendingAreaDrawMode:'rectangle',pendingBaitPointPick:true,pendingMode:'RTL',pendingModeLabel:'RTL',
   routePlan:route,baitingController:bait,missionUploader:uploader,
   digitalAnchor:{release(){events.push('anchor-release')}},scanCoordinator:{cancel(){events.push('scan-cancel')}},
   hopperBridge:{commandPending:false,leftOpen:false,rightOpen:false,closePending(){events.push('close')}},
   vehicle:{flightMode:'RTL',pauseFlightMode:'HOLD',pauseVehicle(){events.push('hold')}},...options});
 return {c,bait,route,uploader,events};
}
test('Cancel stops bait timers, route generation and pending upload/START before one HOLD',()=>{
 const {c,bait,route,uploader,events}=cancellable();assert(c.cancelCurrentAction());
 assert.equal(route.active,false);assert.equal(route.generation,6);assert.equal(bait.enabled,false);
 for(const e of ['monitor-stop','settle-stop','drop-stop','ramp-stop','scan-cancel','upload-timer-stop'])assert(events.includes(e));
 assert.equal(events.filter(e=>e==='hold').length,1);assert(!events.includes('extra-hold'));
 assert.equal(c.awaitingMissionStart,false);assert.equal(c.directGotoActive,false);assert.equal(c.pendingBaitPointPick,false);
 assert.equal(uploader.uploadInProgress,false);assert.equal(uploader.uploadVerified,false);assert.equal(uploader.preparedCount,0);
 assert.equal(c.pendingMode,'HOLD');assert.match(c.lastNavigationStatus,/aștept confirmarea/);
});
test('Cancel RTL stops a leftover speed ramp even after bait cycle reports finished',()=>{
 const {c,bait,events}=cancellable();bait.enabled=false;bait.state=7;
 assert(c.cancelCurrentAction());assert(events.includes('ramp-stop'));assert.equal(bait.state,9);
});
test('Link loss cancels local actions without sending HOLD or hopper commands',()=>{
 const {c,bait,uploader,events}=cancellable({linkAlive:false});c.hopperBridge.commandPending=true;
 assert.equal(c.cancelCurrentAction(),false);assert.equal(bait.enabled,false);assert.equal(uploader.preparedCount,0);
 assert(!events.includes('hold'));assert(!events.includes('close'));assert.match(c.lastNavigationStatus,/nu este confirmată/);
});
test('Cancellation during release requests closure and never opens another hopper',()=>{
 const {c,events}=cancellable();c.hopperBridge.commandPending=true;
 assert(c.cancelCurrentAction());assert.equal(events.filter(e=>e==='close').length,1);
});
test('Replay suspends local continuation without sending live HOLD or hopper commands',()=>{
 const {c,bait,events}=cancellable({sonarController:{replayMode:true}});
 assert.equal(c.cancelCurrentAction(),false);assert.equal(bait.enabled,false);assert(!events.includes('hold'));assert(!events.includes('close'));
});
test('Late upload completion cannot revalidate or auto-start a cancelled mission',()=>{
 const {c,uploader}=cancellable();c.cancelCurrentAction();
 const source=fs.readFileSync(path.join(dir,'NavoMissionUploader.qml'),'utf8');
 const start=source.indexOf('function(success)',source.indexOf('onUploadCompleted:'));
 vm.runInContext('('+callable(source,start)+')(true)',uploader);
 assert.equal(uploader.uploadVerified,false);assert.equal(uploader.preparedCount,0);assert.equal(c.awaitingMissionStart,false);
});
function clearable() {
 const a=area();a.generatedPoints=[coord(52,0),coord(52,.001)];a.completedLanes=[0];a.activeLaneIndex=0;a.paused=true;
 const sonar={scanning:true,paused:true,currentLane:1,completedLanes:1,totalLanes:2,rawSamples:[{depth:3}],trackCoordinates:[coord(52,0)]};
 const c=context('NavoScanCoordinator.qml',{vehicle:null,areaScan:a,sonarMapping:sonar,readOnlyReplay:false,routePlan:{active:false},
  state:'PAUSED',lakeId:'lake-A',areaPoints:a.generatedPoints,missionLanes:[0],missionWaypointCount:2,missionCurrentIndex:2,
  lastCompletedLaneFromMission:0,lastCompletedRouteLaneFromMission:0,bathymetryCells:[{depth:3}],nativeSurfaceMesh:{indices:[0,1,2]},status:noop});
 c.checkpoint=()=>true;return {c,a,sonar};
}
test('Cancel Area Scan preserves geometry, completed lanes and samples for explicit Resume',()=>{
 const {c,a,sonar}=clearable();c.state='SCANNING';sonar.paused=false;
 a.safetyActionRequested=noop;sonar.pauseScan=()=>{sonar.paused=true};
 assert(c.cancel('User cancel'));assert.equal(c.state,'PAUSED');assert.equal(a.generatedPoints.length,2);
 assert.equal(a.completedLanes.length,1);assert.equal(sonar.rawSamples.length,1);assert.equal(sonar.paused,true);
});
test('Clear old Area Scan removes only geometry/progress and saves an empty checkpoint',()=>{
 const {c,a,sonar}=clearable();let saved=false;
 c.checkpoint=reason=>{assert.equal(reason,'area-cleared');assert.equal(c.areaPoints.length,0);assert.equal(c.missionWaypointCount,0);saved=true;return true};
 assert(c.clearArea());assert(saved);assert.equal(c.state,'IDLE');assert.equal(a.generatedPoints.length,0);
 assert.equal(a.completedLanes.length,0);assert.equal(a.activeLaneIndex,-1);assert.equal(sonar.scanning,false);
 assert.equal(sonar.rawSamples.length,1);assert.equal(sonar.trackCoordinates.length,1);assert.equal(c.bathymetryCells.length,1);assert.equal(c.nativeSurfaceMesh.indices.length,3);
});
test('Replay transition pauses live scan locally without changing its saved lake',()=>{
 const {c,a,sonar}=clearable();c.readOnlyReplay=true;c.state='SCANNING';sonar.paused=false;
 c.checkpoint=()=>{throw Error('Replay must not write the live lake')};
 assert(c.cancel('Replay'));assert.equal(c.state,'PAUSED');assert.equal(a.paused,true);assert.equal(sonar.paused,true);
 assert.equal(sonar.rawSamples.length,1);assert.equal(a.generatedPoints.length,2);
});
test('Failed geometry save restores area, resume progress and sonar state',()=>{
 const {c,a,sonar}=clearable();c.checkpoint=()=>false;
 assert.equal(c.clearArea(),false);assert.equal(c.state,'PAUSED');assert.equal(c.areaPoints.length,2);
 assert.equal(a.generatedPoints.length,2);assert.equal(a.completedLanes.length,1);assert.equal(a.activeLaneIndex,0);
 assert.equal(sonar.scanning,true);assert.equal(sonar.paused,true);assert.equal(c.missionWaypointCount,2);
});
test('Clear is blocked during active scan, pending start, RTL, active route and replay',()=>{
 for(const state of ['SCANNING','READY','RESUME_READY','RTL']){
  const {c,a}=clearable();c.state=state;assert.equal(c.clearArea(),false);assert.equal(a.generatedPoints.length,2);
 }
 for(const flag of ['readOnlyReplay','route']){
  const {c,a}=clearable();if(flag==='route')c.routePlan.active=true;else c.readOnlyReplay=true;
  assert.equal(c.clearArea(),false);assert.equal(a.generatedPoints.length,2);
 }
});
test('Dashboard deletion rechecks the guard and resets every map only after persisted success',()=>{
 let saved=false,invalidated=0;
 const c=context('NavoDashboard.qml',{canClearArea:false,areaDrawingGeneration:4,pendingAreaDrawMode:'rectangle',
 scanCoordinator:{clearArea:()=>saved},missionUploader:{invalidate(){invalidated++}}});
 assert.equal(c.clearAreaScan(),false);c.canClearArea=true;assert.equal(c.clearAreaScan(),false);assert.equal(invalidated,0);
 saved=true;assert(c.clearAreaScan());assert.equal(c.areaDrawingGeneration,5);assert.equal(c.pendingAreaDrawMode,'none');assert.equal(invalidated,1);
 const dash=fs.readFileSync(path.join(dir,'NavoDashboard.qml'),'utf8');assert.equal((dash.match(/areaDrawingGeneration: root\.areaDrawingGeneration/g)||[]).length,4);
 const map=context('NavoMap.qml',{areaDraftPoints:[1,2],lastAreaOutline:[1,2,3],areaDrawMode:'rectangle',rectangleDragCorner:1});
 map.clearAreaDrawing();assert.equal(map.lastAreaOutline.length,0);assert.equal(map.areaDraftPoints.length,0);assert.equal(map.areaDrawMode,'none');
});
test('RTL cancellation remains reachable and Area Scan controls explain hover and touch',()=>{
 const dash=fs.readFileSync(path.join(dir,'NavoDashboard.qml'),'utf8'),map=fs.readFileSync(path.join(dir,'NavoMap.qml'),'utf8'),strip=fs.readFileSync(path.join(dir,'NavoMissionStatus.qml'),'utf8');
 assert.match(dash,/visible:root\.actionActive \|\| root\.activePage===2/);assert.match(dash,/cancelText:root\.rtlActive \? "ANULEAZĂ RTL"/);
 assert.match(strip,/onClicked:root\.cancelRequested\(\)/);assert.match(strip,/enabled:root\.cancelAvailable/);
 assert.match(dash,/onPressed:helpTimer\.restart\(\)/);assert.match(dash,/scanHover\.hovered \|\| scanButton\.down \|\| helpTimer\.running/);
 assert.match(map,/onPressed: root\.showToolHelp\(ToolTip\.text\)/);assert.match(map,/interval:4000/);
 assert.match(dash,/if\(areaScanMap && root\.pendingAreaDrawMode==="rectangle"\)/);
});
function editableSpot() {
 const original={id:'s',name:'Old',lat:52,lon:-1,depth:null,temp:null,note:'old',color:'#31d67b',createdAt:123,sonarEvidence:{samples:9}};
 let updates=0;
 const model=context('NavoFishingSpots.qml',{fishingSpots:[original],spotUpdated:()=>updates++});
 const fields={name:' New ',lat:53.1,lon:-2.1,depth:4.2,temp:12.5,note:'mud',color:'#ef4444'};
 return {model,original,fields,updates:()=>updates};
}
test('Complete spot edit updates GPS and metadata together, preserving identity and sonar',()=>{
 const {model,original,fields,updates}=editableSpot();assert(model.updateSpot('s',fields));
 const s=model.fishingSpots[0];assert.equal(s.name,'New');assert.equal(s.lat,53.1);assert.equal(s.lon,-2.1);
 assert.equal(s.depth,4.2);assert.equal(s.temp,12.5);assert.equal(s.note,'mud');assert.equal(s.color,'#ef4444');
 assert.equal(s.createdAt,123);assert.equal(s.id,'s');assert.equal(s.sonarEvidence,original.sonarEvidence);
 assert.equal(original.name,'Old');assert.equal(updates(),1);
});
test('Invalid spot fields and missing IDs leave the entire original record untouched',()=>{
 for(const patch of [{name:''},{lat:91},{lat:NaN},{lat:'52'},{lon:-181},{lon:Infinity},{depth:-1},{depth:''},{temp:NaN},{color:'red'},{note:null}]){
  const {model,original,fields,updates}=editableSpot();assert.equal(model.updateSpot('s',{...fields,...patch}),false);
  assert.equal(model.fishingSpots[0],original);assert.equal(updates(),0);
 }
 const {model,fields,updates}=editableSpot();assert.equal(model.updateSpot('deleted',fields),false);assert.equal(updates(),0);
});
test('Unknown depth/temperature remain null, while measured zero is preserved',()=>{
 const {model,fields}=editableSpot();assert(model.updateSpot('s',{...fields,depth:null,temp:null}));assert.equal(model.fishingSpots[0].depth,null);
 assert(model.updateSpot('s',{...fields,depth:0,temp:0}));assert.equal(model.fishingSpots[0].depth,0);assert.equal(model.fishingSpots[0].temp,0);
});
function spotEditPage(save=true){
 const {model,original}=editableSpot();let closed=false,writes=0;
 const page=context('NavoDashboard.qml',{actionActive:false,missionBusy:false,steeringModeBusy:false,sonar:{replayMode:false},
  spotEditLakeId:'lake',spotEditId:'s',spotEditColor:'#ef4444',fishingSpots:model,
  scanCoordinator:{lakeId:'lake',checkpoint(){writes++;return save}},
  spotName:{text:'New'},spotLatitude:{text:'53,25'},spotLongitude:{text:'-2.5'},spotDepth:{text:''},spotTemperature:{text:'0'},spotNote:{text:'note'},
  spotEditDialog:{errorText:'',close(){closed=true}}});
 return {page,model,original,closed:()=>closed,writes:()=>writes};
}
test('Editor parses comma decimals and refuses blank GPS or trailing garbage',()=>{
 const {page}=spotEditPage();assert.equal(page.spotNumber('53,25'),53.25);assert.equal(page.spotNumber(' -2.5 '),-2.5);
 for(const value of ['', ' ', '12junk', '0x10','1,2,3','Infinity'])assert(Number.isNaN(page.spotNumber(value)));
});
test('Editor persists all fields once and closes only on checkpoint success',()=>{
 const {page,model,closed,writes}=spotEditPage();assert(page.saveSpotEdit());assert(closed());assert.equal(writes(),1);
 assert.equal(model.fishingSpots[0].lat,53.25);assert.equal(model.fishingSpots[0].depth,null);assert.equal(model.fishingSpots[0].temp,0);
});
test('Disk failure rolls back the spot and keeps editor input for retry',()=>{
 const {page,model,original,closed}=spotEditPage(false);assert.equal(page.saveSpotEdit(),false);
 assert.equal(model.fishingSpots[0],original);assert.equal(closed(),false);assert.equal(page.spotName.text,'New');assert.match(page.spotEditDialog.errorText,/eșuat/);
});
test('Lake changes, replay and actions begun during editing block save',()=>{
 for(const flag of ['lake','replay','actionActive','missionBusy','steeringModeBusy']){
  const {page,model,original,writes}=spotEditPage();
  if(flag==='lake')page.scanCoordinator.lakeId='other';else if(flag==='replay')page.sonar.replayMode=true;else page[flag]=true;
  assert.equal(page.saveSpotEdit(),false);assert.equal(model.fishingSpots[0],original);assert.equal(writes(),0);
 }
});
test('QML-creatable backend classes permit the Qt QQmlElement wrapper to derive',()=>{
 const src=path.join(dir,'../src');
 const plugin=fs.readFileSync(path.join(src,'CustomPlugin.cc'),'utf8');
 const headers=fs.readdirSync(src).filter(n=>n.endsWith('.h')).map(n=>fs.readFileSync(path.join(src,n),'utf8')).join('\n');
 for(const match of plugin.matchAll(/qmlRegisterType<([A-Za-z_][A-Za-z_0-9]*)>/g)) {
  const name=match[1];
  assert(!new RegExp('class\\s+'+name+'\\s+final\\b').test(headers), name+' cannot be final when registered with qmlRegisterType');
 }
});
console.log(`${passed} regression scenarios passed`);

