import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
const c=vm.createContext({});
vm.runInContext(fs.readFileSync('custom/qml/NavoVisualPosition.js','utf8').replace('.pragma library',''),c);
let count=0;
function test(name,f){f();console.log('PASS '+name);count++}
const metre=1/111195;
test('Stationary jitter attenuates without locking a real raw point',()=>{
 let s=c.update(c.reset(),52,-1,0,2,1000), raw=0,filtered=0;
 for(let i=1;i<100;i++){const delta=(i%2?1:-1)*metre;s=c.update(s,52+delta,-1,0,2,1000+i*200);raw+=Math.abs(delta);filtered+=Math.abs(s.lat-52)}
 assert(filtered<raw*.5);assert.notEqual(s.lat,52);
});
test('Consistent slow movement releases smoothing without requiring speed',()=>{
 let s=c.update(c.reset(),52,-1,NaN,2,1000);
 for(let i=1;i<=30;i++)s=c.update(s,52+i*.1*metre,-1,NaN,2,1000+i*200);
 assert(Math.abs(s.lat-(52+3*metre))/metre<.05);
});
test('Fast readings require consecutive evidence; no long trail in motion',()=>{
 let s=c.update(c.reset(),52,-1,0,2,1000);
 s=c.update(s,52+metre,-1,2,2,1200);assert.equal(s.fast,1);
 s=c.update(s,52+2*metre,-1,2,2,1400);assert.equal(s.fast,2);
 assert(Math.abs(s.lat-(52+2*metre))/metre<.3);
});
test('Turning, missing accuracy, duplicate coordinates and invalid inputs stay finite',()=>{
 let s=c.update(c.reset(),52,-1,NaN,NaN,1000);
 for(let i=1;i<=30;i++)s=c.update(s,52+Math.sin(i/3)*metre,-1+Math.cos(i/3)*metre,.5,NaN,1000+i*200);
 assert(Number.isFinite(s.lat));assert(Number.isFinite(s.lon));
 const before=s;s=c.update(s,NaN,0,0,2,8000);assert.equal(s,before);
 s=c.update(s,s.rawLat,s.rawLon,0,NaN,s.at+200);assert(Number.isFinite(s.lat));
});
test('Long gaps/reconnect reset rather than replaying the old movement',()=>{
 let s=c.update(c.reset(),52,-1,0,2,1000);s=c.update(s,53,-2,0,2,5001);
 assert.equal(s.lat,53);assert.equal(s.lon,-2);assert.equal(s.coherent,0);
});
test('Antimeridian uses shortest geographic delta',()=>{
 let s=c.update(c.reset(),0,179.999999,0,2,1000);s=c.update(s,0,-179.999999,0,2,1200);
 assert(Math.abs(s.lon)>179.99);
});
test('Raw input unchanged and visual binding isolated from controllers',()=>{
 const raw={lat:52,lon:-1};c.update(c.reset(),raw.lat,raw.lon,0,2,1000);assert.deepEqual(raw,{lat:52,lon:-1});
 const map=fs.readFileSync('custom/qml/NavoMap.qml','utf8');
 assert.match(map,/id: navoBoatMarker[\s\S]*?coordinate: root.displayCoordinate/);
 assert.match(map,/boatCoordinate:root.vehicle \? root.vehicle.coordinate : null/);
 assert.match(map,/center: visible \? root.vehicle.coordinate : QtPositioning.coordinate\(\)/);
 assert.match(map,/text: "GPS vechi"/);
});
console.log(`${count} map visual stability scenarios passed`);
