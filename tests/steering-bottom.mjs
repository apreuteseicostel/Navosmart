import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
const read=name=>fs.readFileSync(new URL('../custom/qml/'+name,import.meta.url),'utf8');
function functions(source,c) {
 const re=/\bfunction\s+([A-Za-z_][A-Za-z_0-9]*)\s*\(/g;let m;
 while((m=re.exec(source))) {
  let fn;for(let end=source.indexOf('}',m.index);end>=0;end=source.indexOf('}',end+1)) {
   const candidate=source.slice(m.index,end+1);try{new vm.Script('('+candidate+')');fn=candidate;break}catch{}
  }
  assert(fn);vm.runInContext(fn,c);re.lastIndex=m.index+fn.length;
 }
}
function controller() {
 const source=read('NavoSteeringAssist.qml'), commands=[];let mode='Manual',now=10000;
 const vehicle={rover:true,flightModes:['Manual','Steering','Hold'],coordinate:{isValid:true},gps:{lock:{rawValue:3}},heading:{rawValue:359},vehicleLinkManager:{communicationLost:false},pauseVehicle(){commands.push('HOLD')}};
 Object.defineProperty(vehicle,'flightMode',{get:()=>mode,set:value=>commands.push(value)});
 const c=vm.createContext({vehicle,readOnly:false,operationsBusy:false,preLaunchReady:true,state:'IDLE',message:'',requestedAt:0,previousMode:'',Date:{now:()=>now},status(){}});c.root=c;
 functions(source,c);
 for(const name of ['busy','steeringMode','canEnable']) {
  const line=source.split('\n').find(x=>x.includes('readonly property') && x.includes(' '+name+':'));
  const expr=line.slice(line.indexOf(':')+1);
  Object.defineProperty(c,name,{get:()=>vm.runInContext(expr,c)});
 }
 return {c,commands,setMode:value=>mode=value,setNow:value=>now=value};
}
let passed=0;function test(name,fn){fn();passed++;console.log('PASS '+name)}
test('Dashboard navigation, baiting, scans and anchor refuse active STEERING before issuing commands',()=>{
 const c=vm.createContext({steeringModeBusy:true,lastNavigationStatus:''});c.root=c;functions(read('NavoDashboard.qml'),c);
 for(const name of ['startRoute','startBaiting','startMission','startUploadedMission','navigateToCoordinate','toggleDigitalAnchor'])assert.equal(c[name](),false,name);
});
test('STEERING only uses a reported Rover mode and valid prelaunch, link, GPS and heading',()=>{
 const {c,commands}=controller();
 for(const [key,value] of [['readOnly',true],['operationsBusy',true],['preLaunchReady',false]]) {
  const prior=c[key];c[key]=value;assert(!c.enable());c[key]=prior;
 }
 c.vehicle.heading.rawValue=NaN;assert(!c.enable());c.vehicle.heading.rawValue=1;
 c.vehicle.gps.lock.rawValue=2;assert(!c.enable());c.vehicle.gps.lock.rawValue=3;
 c.vehicle.vehicleLinkManager.communicationLost=true;assert(!c.enable());c.vehicle.vehicleLinkManager.communicationLost=false;
 c.vehicle.flightModes=['Manual','Auto'];assert(!c.enable());assert.deepEqual(commands,[]);
});
test('Mode request is pending until telemetry; timeout never claims activation or rewrites pilot mode',()=>{
 const {c,commands,setNow}=controller();assert(c.enable());assert.equal(c.state,'REQUESTED');assert(!c.enable());
 setNow(16000);c.observe();assert.equal(c.state,'IDLE');assert.deepEqual(commands,['Steering']);
});
test('Reported STEERING activates; pilot MANUAL cancels without HOLD or servo commands',()=>{
 const {c,commands,setMode}=controller();c.enable();setMode('Steering');c.observe();assert.equal(c.state,'ACTIVE');
 setMode('Manual');c.observe();assert.equal(c.state,'IDLE');assert.deepEqual(commands,['Steering']);
});
test('GPS/link loss cancels ownership and recovery cannot re-enable automatically',()=>{
 for(const failure of ['gps','link']) {
  const {c,commands,setMode}=controller();c.enable();setMode('Steering');c.observe();
  if(failure==='gps')c.vehicle.gps.lock.rawValue=2;else c.vehicle.vehicleLinkManager.communicationLost=true;
  c.observe();assert.equal(c.state,'IDLE');c.vehicle.gps.lock.rawValue=3;c.vehicle.vehicleLinkManager.communicationLost=false;
  c.observe();assert.equal(c.state,'IDLE');assert.deepEqual(commands,['Steering']);
 }
});
test('Stop uses HOLD and waits for confirmation; stop after pilot takeover cannot override MANUAL',()=>{
 const {c,commands,setMode}=controller();c.enable();setMode('Steering');c.observe();assert(c.stop());assert.equal(c.state,'STOP_REQUESTED');
 setMode('Hold');c.observe();assert.equal(c.state,'IDLE');assert.deepEqual(commands,['Steering','HOLD']);
 const other=controller();other.c.enable();other.setMode('Steering');other.c.observe();other.setMode('Manual');assert(!other.c.stop());assert.deepEqual(other.commands,['Steering']);
});
const analysis=vm.createContext({});vm.runInContext(read('NavoBottomAnalysis.js').replace(/^\.pragma library\s*/,''),analysis);
function raw(){const r=Array(200).fill(.05);r[98]=.4;r[99]=.8;r[100]=.8;r[101]=.4;return r}
test('Raw physical-scale metrics identify a known peak, width and independent water-column echo',()=>{
 const r=raw();r[40]=r[41]=r[42]=.6;
 const a=analysis.column(r,0,4,2);assert(a.valid);assert.equal(a.peak,.8);assert.equal(a.widthM,.08);assert.equal(a.stepM,.02);assert.equal(a.aboveEchoes,1);assert(Math.abs(a.aboveHeightM-1.2)<1e-9);assert.equal(a.material,'NECLASIFICAT');
});
test('Missing scale/depth, null data, clipped windows and corrupt amplitudes cannot yield a material',()=>{
 for(const values of [[raw(),0,NaN,2],[raw(),0,4,null],[raw(),0,4,5],[raw(),0,4,.02],[Array(8).fill(.5),0,4,2]])assert(!analysis.column(...values).valid);
 const r=raw();r[99]=null;assert(!analysis.column(r,0,4,2).valid);r[99]=1.1;assert(!analysis.column(r,0,4,2).valid);
});
test('Broad returns are labelled as truncated widths; zero return is zero echo, never hard bottom',()=>{
 const broad=analysis.column(Array(200).fill(.6),0,4,2);assert(broad.valid && broad.widthLimited);
 const zero=analysis.column(Array(200).fill(0),0,4,2);assert(zero.valid);assert.equal(zero.widthM,0);assert.equal(zero.material,'NECLASIFICAT');
});
test('Profile uses only bounded recent physical depths, without slope or substrate inference',()=>{
 const h=Array.from({length:100},(_,i)=>({bottom:i<60?200:2+(i%3)*.1,offset:0,range:4}));const p=analysis.profile(h);
 assert(p.valid);assert.equal(p.count,40);assert(Math.abs(p.variationM-.2)<1e-9);assert(!analysis.profile([{bottom:null}]).valid);assert(!analysis.profile(Array(5).fill({bottom:8,offset:0,range:4})).valid);
});
console.log(`${passed} steering/bottom scenarios passed`);
