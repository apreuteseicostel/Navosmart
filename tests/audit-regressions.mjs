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
  const c=vm.createContext({...values}); c.root=c;
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
  const c=context('NavoBaitingController.qml',{enabled:true,state:4,settleState:4,releaseState:5,arrivalRadiusM:1,releaseMaxSpeedMps:.12,hopper:1,postDropTimer:{restart(){c.postStarted=true}},hopperReleaseRequested(){c.released=true},stopRequested:noop,restart:noop});
  c.vehicleCoordinateValid=()=>true;c.validTarget=()=>true;c.distanceToTarget=()=>distance;c.groundSpeed=()=>speed;c.setState=s=>c.state=s;c.abortCycle=()=>{c.enabled=false;c.aborted=true};
  return c;
}
test('Bait release refuses unknown speed and drift outside waypoint radius',()=>{
  for(const c of [bait(NaN),bait(Infinity),bait(.01,2)]) {timerHandler('NavoBaitingController.qml','settleTimer',c)();assert(c.aborted);assert(!c.released);assert(!c.postStarted);}
});
test('Valid stationary bait release dispatches; synchronous rejection prevents exit timer',()=>{
  let c=bait(.01);timerHandler('NavoBaitingController.qml','settleTimer',c)();assert(c.released && c.postStarted);
  c=bait(.01);c.hopperReleaseRequested=()=>c.abortCycle();timerHandler('NavoBaitingController.qml','settleTimer',c)();assert(!c.postStarted);
});
test('Failsafe grace uses full epoch milliseconds and correct QGC link property',()=>{
  let now=1790240400000,rtl=0;
  const c=context('NavoFailsafeController.qml',{Date:{now:()=>now},enabled:true,vehicle:{vehicleLinkManager:{communicationLost:true},gps:{lock:{rawValue:3}},coordinate:coord(52,0)},minGpsFix:3,linkLost:false,gpsLost:false,linkGraceSeconds:30,gpsRecoverySeconds:60,gpsReturnHomeSeconds:120,rtlRequested:()=>rtl++,holdRequested:noop,recovered:noop});
  c.tick();now+=29000;c.tick();assert.equal(rtl,0);now+=1000;c.tick();assert.equal(rtl,1);c.tick();assert.equal(rtl,1);
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
  for(const token of ['property bool mapMaximized: false','id: areaScanMap','id:fishingMap','FINAL: HOLD','onMaximizeRequested: root.mapMaximized = !root.mapMaximized'])
    assert(dash.includes(token),token);
  assert(!dash.includes('id: statusStrip'),'legacy bottom status strip must stay removed');
  assert(area.includes('▶ "+(root.areaScan.activeLaneIndex+1)+"/"+root.areaScan.laneCount()'));
  assert(uploader.includes('property int verifiedCount: 0'));
});
test('NAVO starts as ArduPilot Rover Boat without vehicle-selection prompt',()=>{
  const srcDir=path.resolve(import.meta.dirname,'../custom/src');
  const h=fs.readFileSync(path.join(srcDir,'CustomPlugin.h'),'utf8');
  const cc=fs.readFileSync(path.join(srcDir,'CustomPlugin.cc'),'utf8');
  assert(h.includes('firstRunPromptStdIds() final { return QList<int>({ kUnitsFirstRunPromptId }); }'));
  assert(cc.includes('QGCMAVLink::FirmwareClassArduPilot'));
  assert(cc.includes('QGCMAVLink::VehicleClassRoverBoat'));
});
test('Saved lakes expose persistent rename and confirmed delete controls',()=>{
  const ui=fs.readFileSync(path.join(dir,'NavoMyLakes.qml'),'utf8');
  const dash=fs.readFileSync(path.join(dir,'NavoDashboard.qml'),'utf8');
  const coordinator=fs.readFileSync(path.join(dir,'NavoScanCoordinator.qml'),'utf8');
  for(const token of ['beginRename','beginDelete','renameCurrentLake','deleteCurrentLake','🗑 ȘTERGE'])
    assert(ui.includes(token),token);
  assert(dash.includes('✏ NUME'));
  assert(dash.includes('🗑 ȘTERGE'));
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
console.log(`${passed} regression scenarios passed`);
