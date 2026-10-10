// Execute production QML functions. Coordinates/vehicle/Qt scheduling are explicit doubles.
import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
function context(file, values) {
 const source=fs.readFileSync(new URL('../custom/qml/'+file,import.meta.url),'utf8');
 const c=vm.createContext(values);c.root=c;
 const re=/\bfunction\s+([A-Za-z_][A-Za-z_0-9]*)\s*\(/g;let m;
 while((m=re.exec(source))) {
  let fn;for(let end=source.indexOf('}',m.index);end>=0;end=source.indexOf('}',end+1)){
   const candidate=source.slice(m.index,end+1);try{new vm.Script('('+candidate+')');fn=candidate;break}catch{}
  }
  assert(fn);vm.runInContext(fn,c);re.lastIndex=m.index+fn.length;
 }return c;
}
function coord(lat,lon) {return {latitude:lat,longitude:lon,isValid:Number.isFinite(lat)&&Number.isFinite(lon)&&Math.abs(lat)<=90&&Math.abs(lon)<=180,
 distanceTo(p){return Math.hypot((p.latitude-lat)*111320,(p.longitude-lon)*111320)},azimuthTo(p){return Math.atan2(p.longitude-lon,p.latitude-lat)*180/Math.PI},
 atDistanceAndAzimuth(d,b){return coord(lat+d*Math.cos(b*Math.PI/180)/111320,lon+d*Math.sin(b*Math.PI/180)/111320)}}}
function plan(){const queued=[],dispatched=[],finished=[];
 const c=context('NavoRoutePlan.qml',{stops:[],missionKind:'route',otherDraft:[],otherFinishAction:'RTL',finishAction:'RTL',readOnly:false,active:false,currentIndex:-1,runningStops:[],runningFinishAction:'RTL',state:'DRAFT',generation:0,lastError:'',history:[],startedAtMs:0,Date,
 QtPositioning:{coordinate:coord},Qt:{callLater:f=>queued.push(f)},changed(){},status(){},stepRequested:s=>dispatched.push(s),finishRequested:a=>finished.push(a)});
 return {c,queued,dispatched,finished};}
const wp=(lat,lon)=>({coordinate:coord(lat,lon)});let passed=0;
function test(name,fn){fn();passed++;console.log('PASS '+name)}
test('Mission selector refuses replay, active operations and invalid modes without replacing a draft',()=>{
 const {c:route}=plan();route.addStop(wp(52,0),'route',0);
 const c=context('NavoDashboard.qml',{routePlan:route,missionBusy:true,sonar:{replayMode:false},missionScanSelected:true});
 assert(!c.selectMission(0));c.missionBusy=false;c.sonar.replayMode=true;assert(!c.selectMission(0));
 c.sonar.replayMode=false;for(const bad of [-1,3,NaN,'0'])assert(!c.selectMission(bad));
 assert(c.selectMission(0));assert.equal(route.missionKind,'point');assert(c.selectMission(2));assert.equal(c.missionScanSelected,true);
 assert(c.selectMission(1));assert.equal(route.stops[0].name,'route');
});
test('Point and route editors preserve separate drafts and final actions across lake restore',()=>{
 const {c}=plan();c.addStop(wp(52,0),'route A',1);c.addStop(wp(52,.001),'route B',2);c.finishAction='ANCHOR';
 assert(c.selectKind('point'));assert.equal(c.stops.length,0);assert(c.setPoint(wp(52,.003),'point',0));c.finishAction='HOLD';
 assert(!c.addStop(wp(52,.004),'extra',0));const saved=c.snapshot();saved.otherDraft[0].name='snapshot copy';assert.equal(c.otherDraft[0].name,'route A');
 const restored=plan().c;assert(restored.restore(c.snapshot()));assert.equal(restored.missionKind,'point');assert.equal(restored.stops.length,1);
 assert(restored.selectKind('route'));assert.equal(restored.stops.length,2);assert.equal(restored.finishAction,'ANCHOR');
 assert(restored.selectKind('point'));assert.equal(restored.stops[0].name,'point');assert.equal(restored.finishAction,'HOLD');
 assert(restored.start(false));assert(!restored.selectKind('route'));assert(!restored.setPoint(wp(52,.002),'changed',3));
 restored.cancel('HOLD');restored.readOnly=true;assert(!restored.selectKind('route'));assert(!restored.setPoint(wp(52,.002),'changed',3));
});
test('Invalid coordinates/actions, bounded route and duplicate physical loads are refused',()=>{
 const {c}=plan();assert(!c.addStop(wp(NaN,0),'bad',1));assert(!c.addStop(wp(52,0),'bad',4));
 assert(c.addStop(wp(52,0),'left',1));assert(!c.addStop(wp(52,.001),'left again',1));assert(c.addStop(wp(52,.001),'right',2));
 assert(c.validate(c.stops,'UNKNOWN'));assert(c.validate(Array(51).fill(c.stops[0]),'RTL'));
});
test('Replay blocks route edits and START',()=>{
 const {c}=plan();c.addStop(wp(52,0),'A',1);c.readOnly=true;assert(!c.addStop(wp(52,.1),'B',0));assert(!c.removeStop(0));assert(!c.moveStop(0,1));assert(!c.start(true));
});
test('Start/repeat requires load confirmation and freezes the running route',()=>{
 const {c,dispatched}=plan();c.addStop(wp(52,0),'A',3);assert(!c.start(false));assert(c.start(true));
 assert.equal(dispatched.length,1);assert(!c.removeStop(0));assert(!c.addStop(wp(52,.1),'B',0));
 c.stops[0].name='edited externally';assert.equal(c.runningStops[0].name,'A');c.stepFinished(true,'ok');assert.equal(c.state,'DISPATCHED');assert.equal(c.history.length,1);assert.equal(c.history[0].result,'DISPATCHED');
 assert(!c.start(false));assert(c.start(true));
});
test('Sequential dispatch has no premature final action',()=>{
 const {c,queued,dispatched,finished}=plan();c.addStop(wp(52,0),'A',1);c.addStop(wp(52,.001),'B',2);c.finishAction='ANCHOR';
 assert(c.start(true));c.stepFinished(true,'A');assert.equal(dispatched.length,1);assert.equal(finished.length,0);queued.shift()();
 assert.equal(dispatched[1].name,'B');c.stepFinished(true,'B');assert.equal(c.active,false);assert.deepEqual(finished,['ANCHOR']);
 c.stepFinished(true,'duplicate');assert.equal(finished.length,1);
});
test('STOP cancels queued next stop; restart cannot receive an old callback',()=>{
 const {c,queued,dispatched}=plan();c.addStop(wp(52,0),'A',0);c.addStop(wp(52,.001),'B',0);c.start(false);c.stepFinished(true,'A');
 c.cancel('STOP');assert(c.start(false));const before=dispatched.length;queued.shift()();assert.equal(dispatched.length,before);
});
test('Failure ends the route without another drop or final navigation',()=>{
 const {c,dispatched,finished}=plan();c.addStop(wp(52,0),'A',1);c.start(true);c.stepFinished(false,'link lost');
 assert.equal(c.state,'STOPPED');assert.equal(c.active,false);assert.equal(dispatched.length,1);assert.equal(finished.length,0);
});
test('Saved route restores as a draft, never as a running mission',()=>{
 const {c}=plan();c.addStop(wp(52,0),'A',1);const saved=c.snapshot();c.start(true);assert(!c.restore(saved));c.cancel('stop');assert(c.restore(saved));
 assert.equal(c.active,false);assert.equal(c.currentIndex,-1);assert.equal(c.state,'DRAFT');
 assert(!c.restore({version:1,stops:[{latitude:null,longitude:0,hopper:1}],finishAction:'RTL'}));assert.equal(c.stops.length,0);
});
test('Estimated travel includes slow approach, dwell, exit and HOME reserve for every final action',()=>{
 const {c}=plan();c.addStop(wp(0,.001),'A',1);
 const cfg={silentMode:false,normalSpeedMps:2,silentSpeedMps:1,finalSpeedMps:.5,silentRadiusM:10,finalRadiusM:3,settleMs:2000,postDropMs:2000,exitDistanceM:4,exitSide:1};
 const home=coord(0,0),rtl=c.estimate(home,home,cfg);assert(rtl.valid);assert(rtl.distanceM>222);assert(rtl.durationSeconds>rtl.distanceM/2);
 c.finishAction='HOLD';const hold=c.estimate(home,home,cfg);assert(hold.valid);assert.equal(hold.energyDistanceM,rtl.energyDistanceM);assert(hold.distanceM<rtl.distanceM);
 assert(!c.estimate(home,null,cfg).valid);assert(!c.estimate(home,home,{...cfg,finalSpeedMps:0}).valid);
});
test('Navigation-only stop does not add a lateral bait-zone exit',()=>{
 const {c}=plan();c.addStop(wp(0,.001),'A',0);c.finishAction='HOLD';
 const cfg={normalSpeedMps:2,silentSpeedMps:1,finalSpeedMps:.5,silentRadiusM:10,finalRadiusM:3,settleMs:2000,postDropMs:2000,exitDistanceM:4,exitSide:1};
 assert(Math.abs(c.estimate(coord(0,0),coord(0,0),cfg).distanceM-111.32)<.001);
});
test('Pilot mode changes cancel navigation without overriding MANUAL with HOLD',()=>{
 let stopped=0,finished=0;const timer={stop(){}};
 const c=context('NavoBaitingController.qml',{vehicle:{flightMode:'MANUAL'},enabled:true,guidedConfirmed:true,guidedRequestedAtMs:0,Date,
 monitorTimer:timer,settleTimer:timer,postDropTimer:timer,rampTimer:timer,idleState:0,navigateState:1,approachState:2,finalApproachState:3,settleState:4,releaseState:5,exitState:6,returnHomeState:7,completeState:8,abortedState:9,state:1,stateChangedDetailed(){},stopRequested(){stopped++},cycleFinished(){finished++}});
 assert.equal(c.navigationModeValid(),false);assert.equal(c.enabled,false);assert.equal(stopped,0);assert.equal(finished,1);
});
test('Dashboard pre-launch, energy and failed save gates issue no route start',()=>{
 let starts=0, saved=0;
 const c=context('NavoDashboard.qml',{routePlan:{active:false,finishAction:'RTL',start(){starts++;return true}},baitingController:{enabled:false,rtlAfterDrop:true},
 scanCoordinator:{state:'IDLE',checkpoint(){saved++;return false}},sonarController:{replayMode:false},linkAlive:true,awaitingMissionStart:false,
 missionUploader:{uploadInProgress:false},vehicle:{guidedModeRTL(){}},preLaunchCheck:{navigationReady:false,blockingMessage:'battery missing'},routeEstimate:{valid:true,energyDistanceM:400},
 energyGuard:{canStart(){return false},message(){return 'energy failed'}},battery:{percentRemaining:{rawValue:80}}});
 c.requireActiveLakeForPointSave=()=>true;
 assert.equal(c.startRoute(true),false);assert.equal(starts,0);assert.equal(saved,0);
 c.preLaunchCheck.navigationReady=true;assert.equal(c.startRoute(true),false);assert.equal(starts,0);assert.equal(saved,0);
 c.energyGuard.canStart=()=>true;assert.equal(c.startRoute(true),false);assert.equal(starts,0);assert.equal(saved,1);
 c.scanCoordinator.checkpoint=()=>true;assert(c.startRoute(true));assert.equal(starts,1);
});
test('Per-lake snapshots include route and history; active route prevents lake changes',()=>{
 const {c:route}=plan();route.addStop(wp(52,0),'A',1);route.start(true);route.stepFinished(true,'ok');
 let payload;const c=context('NavoScanCoordinator.qml',{routePlan:route,lakeId:'lake',lakeName:'Lake',state:'IDLE',areaPoints:[],bathymetryCells:[],nativeSurfaceMesh:{},
 persistence:{waypointNames:{},saveLakeState(id,p){payload=p;return true}},sonarMapping:{rawSamples:[]},areaScan:{activeLaneIndex:-1,completedLanes:[],laneCount(){return 0}},
 fishingSpots:null,fishStore:null,status(){},missionCurrentIndex:-1,lastCompletedLaneFromMission:-1,lastCompletedRouteLaneFromMission:-1,missionLanes:[],missionWaypointCount:0});
 assert(c.checkpoint('route'));assert.equal(payload.routePlan.stops.length,1);assert.equal(payload.routePlan.history.length,1);
 route.start(true);assert.equal(c.activateLake('another','Other'),false);assert.equal(c.deleteLake('lake'),false);assert.equal(c.clearActiveLake(),false);
});
test('Foreign servo results are ignored; rejected/timeout commands emit failure instead of success',()=>{
 const failures=[];const c=context('NavoHopperBridge.qml',{vehicle:{id:42},mavCompAutopilot1:1,mavCmdDoSetServo:183,Date,servoCommandFailed:r=>failures.push(r)});
 assert.equal(c.receiveServoResult(99,1,183,2,0),false);assert.equal(failures.length,0);
 c.receiveServoResult(42,1,183,0,0);c.receiveServoResult(42,1,183,5,0);assert.equal(failures.length,0);
 c.receiveServoResult(42,1,183,2,0);c.receiveServoResult(42,1,183,0,1);assert.equal(failures.length,2);
});
console.log(`${passed} route scenarios passed`);
