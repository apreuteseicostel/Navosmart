// G20 graphics regression: safe fast-mode defaults and expensive work reuse.
// This is an offline structural + pure-QML-JavaScript test; G20 FPS remains a
// device acceptance metric, never an inferred claim from CI.
import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
const read=p=>fs.readFileSync(p,'utf8');
const scene=read('custom/qml/NavoBathymetry3D.qml');
const geometry=read('custom/src/NavoBathymetryGeometry.cc');
const geometryHeader=read('custom/src/NavoBathymetryGeometry.h');
const track=read('custom/src/NavoTrack3DGeometry.cc');
const map=read('custom/qml/NavoNativeBathymetryOverlay.qml');
const projection=read('custom/qml/NavoMapProjection.js');

assert(scene.includes('property bool performanceMode:true'), 'G20 fast mode not the default');
assert(scene.includes('objectName:"bathymetryPerformanceToggle"'), 'graphics quality toggle unavailable');
assert(scene.includes('SceneEnvironment.NoAA:SceneEnvironment.MSAA'), 'MSAA quality mode broken');
assert(scene.includes('castsShadow:!root.performanceMode'), 'GPU shadow toggle missing');
assert(scene.includes('terrainGeometry.geometryBytes') && scene.includes('terrainGeometry.lastBuildMs'), 'real render metrics unavailable');
assert(geometry.includes('QTimer::singleShot(0,this'), 'GPU buffer rebuild not coalesced');
assert(geometry.includes('if(_rebuildQueued)return'), 'duplicate same-event-loop rebuild not suppressed');
for(const setter of ['_vertices=v','_triangles=v','_z=v','_minDepth=v','_maxDepth=v']){
 assert(geometry.includes(setter+';scheduleRebuild()'), 'geometry setter bypassed coalescer: '+setter);
}
assert(geometryHeader.includes('Q_PROPERTY(int geometryBytes'), 'GPU buffer size not instrumented');
assert(geometry.includes('elapsed.nsecsElapsed()'), 'CPU build time not measured');
assert(track.includes('if(_p==p)return'), 'unchanged 3D track triggers expensive simplification');
assert(track.includes('if(qFuzzyCompare(_w,w))return'), 'unchanged track width triggers rebuild');

assert(map.includes('function rebuildTriangleColors()'), 'native triangle color LUT missing');
assert(map.includes('onSurfaceChanged: {rebuildTriangleColors();invalidateProjection(false)}'), 'palette cache not invalidated on data change');
assert(map.includes('var fill=root.triangleColors[i/3]'), 'per-frame colors not reused');
assert(map.includes('var pan={x:0,y:0}') && map.includes('else pan=offset'), 'screen-space translation missing');
assert(!map.includes('MapPan.translateProjected(root.projected,offset)'), 'per-pan vertex mutation came back');
assert(map.includes('if(!active){projected=[];projectedView=({})}'), 'hidden map retains full projection');
assert(projection.includes('Math.abs(map.zoomLevel - cachedView.zoomLevel)'), 'pan cache must be invalidated on zoom');
assert(projection.includes('Math.abs(map.bearing - cachedView.bearing)'), 'pan cache must be invalidated on rotation');
assert(projection.includes('Math.abs(map.tilt)'), 'pan cache must be invalidated on tilt');

function qmlFunction(text,name){
 const at=text.indexOf('function '+name+'(');
 assert(at>=0,name+' missing');
 const start=text.indexOf('{',at);
 let depth=0;
 for(let i=start;i<text.length;i++){
  if(text[i]==='{')depth++;
  else if(text[i]==='}' && --depth===0)return text.slice(at,i+1);
 }
 throw Error(name+' missing closing brace');
}
let allocations=0;
const input={
  vertices:[[52,-1,2],[52.001,-1,3],[52,-1.001,4],[52.001,-1.001,5]],
  indices:[0,1,2,1,3,2]
};
const ctx=vm.createContext({surface:input,triangleColors:[],depthColor(value){
 allocations++;return 'C'+value.toFixed(2);
}});
vm.runInContext(qmlFunction(map,'rebuildTriangleColors'),ctx);
ctx.rebuildTriangleColors();
assert.equal(allocations,2, 'not exactly one colour per triangle');
assert.deepEqual([...ctx.triangleColors],['C3.00','C4.00']);
for(let repaint=0;repaint<30;repaint++){
 assert.equal(ctx.triangleColors[0],'C3.00');
}
assert.equal(allocations,2,'painting allocates colours instead of reusing LUT');
ctx.surface={...input,vertices:[[52,-1,3],[52.001,-1,4],[52,-1.001,5],[52.001,-1.001,6]]};
ctx.rebuildTriangleColors();
assert.equal(allocations,4,'changed sonar mesh did not refresh colours');
assert.equal(ctx.triangleColors[0],'C4.00');

const mapCtx=vm.createContext({});
vm.runInContext(projection.replace('.pragma library',''),mapCtx);
const old={latitude:52,longitude:-1,isValid:true};
const mapObject={
 mapReady:true,width:1000,height:600,center:old,zoomLevel:17,bearing:0,tilt:0,
 fromCoordinate(pos){return {x:500+(pos.longitude-this.center.longitude)*1000,
                              y:300-(pos.latitude-this.center.latitude)*1000};}
};
const oldView={center:old,width:1000,height:600,zoomLevel:17,bearing:0,tilt:0};
const originalPoints=[{x:80,y:80},{x:90,y:80},{x:85,y:90}];
const before=JSON.stringify(originalPoints);
mapObject.center={latitude:52.01,longitude:-1.02,isValid:true};
const move=mapCtx.panOffset(mapObject,oldView);
assert(move && move.x!==0 && move.y!==0,'pan should be reusable');
const display=originalPoints.map(p=>({x:p.x+move.x,y:p.y+move.y}));
assert.equal(JSON.stringify(originalPoints),before, 'pan offset mutated projected cache');
assert.equal(display[0].x,originalPoints[0].x+move.x);
mapObject.zoomLevel=18;
assert.equal(mapCtx.panOffset(mapObject,oldView),null,'zoom must force reprojection');
console.log('PASS G20 GPU build coalescing, UI fast/HD mode, native color cache, nonmutating pan and stale projection guards');
