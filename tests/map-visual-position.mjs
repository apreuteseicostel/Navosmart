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

// Keep native mesh geometry reusable when only map.center moves. Zoom,
// rotation, tilt, large jumps and a not-ready map must reproject accurately.
const mapPan=vm.createContext({});
vm.runInContext(fs.readFileSync('custom/qml/NavoMapProjection.js','utf8').replace('.pragma library',''),mapPan);
function mockMap(center) {
 return {mapReady:true,width:400,height:300,center,zoomLevel:17,bearing:0,tilt:0,
   fromCoordinate(p){return {x:200+(p.longitude-this.center.longitude)*10000,
                              y:150-(p.latitude-this.center.latitude)*10000};}};
}
function snapshot(map) {
 return {center:{...map.center},width:map.width,height:map.height,zoomLevel:map.zoomLevel,bearing:map.bearing,tilt:map.tilt};
}
test('Native surface pan reuses projected vertices with the same screen coordinates',()=>{
 const old={latitude:52,longitude:-1,isValid:true}, map=mockMap(old), view=snapshot(map);
 const points=[{latitude:52.001,longitude:-1.002},{latitude:52.002,longitude:-1.001}];
 const projected=points.map(p=>map.fromCoordinate(p));
 map.center={latitude:52.001,longitude:-1.01,isValid:true};
 const expected=points.map(p=>map.fromCoordinate(p));
 const offset=mapPan.panOffset(map,view);
 assert(offset); assert.equal(offset.x,100); assert.equal(offset.y,10);
 const result=mapPan.translateProjected(projected,offset);
 for(let i=0;i<points.length;i++){
   assert(Math.abs(result[i].x-expected[i].x)<1e-8);
   assert(Math.abs(result[i].y-expected[i].y)<1e-8);
 }
});
test('Native surface pan preserves invalid vertices and zero movement',()=>{
 const map=mockMap({latitude:52,longitude:-1,isValid:true}),view=snapshot(map);
 assert.equal(mapPan.panOffset(map,view).x,0);
 const points=[null,{x:2,y:3}];
 assert.equal(mapPan.translateProjected(points,{x:4,y:-1}),points);
 assert.equal(points[0],null);assert.equal(points[1].x,6);assert.equal(points[1].y,2);
});
test('Native pan cache safely falls back on zoom, rotation, tilt, resize, large jumps and invalid map',()=>{
 const original={latitude:52,longitude:-1,isValid:true},map=mockMap(original),view=snapshot(map);
 for(const [field,value] of [['zoomLevel',18],['bearing',10],['tilt',10],['width',500],['height',200],['mapReady',false]]){
   const other={...map,[field]:value};assert.equal(mapPan.panOffset(other,view),null,field);
 }
 assert.equal(mapPan.panOffset({...map,center:{latitude:52,longitude:1,isValid:true}},view),null);
 assert.equal(mapPan.panOffset({...map,center:{latitude:52,longitude:0,isValid:false}},view),null);
});
test('Map source uses pan reuse and actual track incremental Qt path updates',()=>{
 const source=fs.readFileSync('custom/qml/NavoNativeBathymetryOverlay.qml','utf8');
 const track=fs.readFileSync('custom/qml/NavoActualTrack.qml','utf8');
 const cmake=fs.readFileSync('custom/CMakeLists.txt','utf8');
 assert.match(source,/import "NavoMapProjection\\.js" as MapPan/);
 assert.match(source,/onCenterChanged\\(\\)\\{root\\.invalidateProjection\\(true,true\\)\\}/);
 assert.match(source,/MapPan\\.translateProjected\\(root\\.projected,offset\\)/);
 assert.match(source,/root\\.projectedView=root\\.currentMapView\\(\\)/);
 assert.match(track,/actualTrack\\.addCoordinate\\(c\\)/);
 assert.match(track,/function appendTrackCoordinate\\(c\\)/);
 assert.match(track,/trackCoordinates\\s*=\\s*trackCoordinates\\.concat\\(\\[c\\]\\)/);
 assert.doesNotMatch(track,/path:\\s*root\\.trackCoordinates/);
 assert.match(cmake,/qml\\/NavoMapProjection\\.js/);
});
console.log(`${count} map visual stability scenarios passed`);
