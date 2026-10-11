// Execute the actual installed-acceptance state machine with explicit UI doubles.
// Android still supplies the real controls, touch events and persistence.
import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
const source=fs.readFileSync(new URL('../custom/qml/NavoAndroidAcceptance.qml',import.meta.url),'utf8');
const now=Date.now();let load={checked:true},popup={visible:false},scanSize={value:20},hopper={currentIndex:0},report;
const spot={id:'green',lat:40.1612,lon:44.4742};
const plan={active:false,stops:[],missionKind:'point'};
const area={generatedPoints:[]};
const dashboard={vehicle:null,activePage:0,mapMaximized:false,missionScanSelected:false,routePlanController:plan,mapAreaScanController:area,
 fishingSpotsController:{saveSpot(){return spot}},sonarController:{},lakePersistence:{},startRoute:()=>false,
 areaCoordinator:{activateLake:()=>true,checkpoint:()=>true,state:'PAUSED'}};
const backend={configuration:{phase:'spots',liveId:'live'},focusSavedSpot:()=>true,control(d,name){return ({savedSpotDetails:popup,savedSpotHopper:hopper,savedSpotScanSize:scanSize,routeLoadCheck:load})[name]}};
const c=vm.createContext({dashboard,backend,stage:'start',started:now,entered:now,evidence:{},QtPositioning:{coordinate:(lat,lon)=>({latitude:lat,longitude:lon})},clock:{stop(){c.stopped=true}},Date});
c.test=c;
for(const name of ['require','step']) {
 const begin=source.indexOf('function '+name+'(');let fn;
 for(let end=source.indexOf('}',begin);end>=0;end=source.indexOf('}',end+1)) {
  const candidate=source.slice(begin,end+1);try{new vm.Script('('+candidate+')');fn=candidate;break}catch{}
 }
 assert(fn);vm.runInContext('this.'+name+'='+fn,c);
}
c.advance=stage=>{c.stage=stage;c.entered=now;c.evidence.sceneReady=false};c.publish=status=>{report=status};
c.step();assert.equal(c.stage,'spots-pin-navigation');
for(const action of ['navigation','bait','scan']) {
 c.entered=now-2000;popup.visible=true;dashboard.activePage=0;c.step();assert.equal(c.stage,'spots-action-'+action);
 if(action==='bait')assert.equal(hopper.currentIndex,2);
 if(action==='scan')assert.equal(scanSize.value,40);
 popup.visible=false;dashboard.activePage=2;
 if(action!=='scan') {
  plan.stops=[{latitude:spot.lat,longitude:spot.lon,hopper:action==='bait'?3:0}];load.checked=false;
 } else {
  dashboard.missionScanSelected=true;dashboard.areaCoordinator.state='AREA_DEFINED';
  area.completedLanes=[];area.generatedPoints=Array.from({length:8},(_,i)=>({latitude:spot.lat+(i<4?.0001:-.0001),longitude:spot.lon+(i%2?.0001:-.0001)}));
 }
 c.step();
}
assert.equal(report,'passed');assert(c.stopped);
for(const flag of ['savedSpotNavigationVerified','savedSpotBaitVerified','savedSpotScanVerified','savedSpotDisconnectedStartBlocked'])assert(c.evidence[flag]);
// A faulty command path must fail the acceptance, rather than report success.
c.stage='spots-action-navigation';c.entered=now;dashboard.activePage=2;plan.stops=[{latitude:spot.lat,longitude:spot.lon,hopper:0}];dashboard.startRoute=()=>true;
assert.throws(()=>c.step(),/Disconnected START was allowed/);
console.log('PASS installed saved-point acceptance stages and rejection of an unsafe START');
