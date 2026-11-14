// Stage 3: keep native Kogger 3D opt-in, unmodified raw lake samples and safe fallback.
import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';

const scene=fs.readFileSync('custom/qml/NavoBathymetry3D.qml','utf8');
const dashboard=fs.readFileSync('custom/qml/NavoDashboard.qml','utf8');
const cpp=fs.readFileSync('custom/src/NavoBathymetryMesh.cc','utf8');
const header=fs.readFileSync('custom/src/NavoBathymetryMesh.h','utf8');
function extractFunction(name){
 const start=scene.indexOf('function '+name+'(');
 assert(start>=0, 'missing function: '+name);
 const begin=scene.indexOf('{',start);
 let depth=0,end=-1;
 for(let i=begin;i<scene.length;i++){
   if(scene[i]==='{')depth++;
   else if(scene[i]==='}' && --depth===0){end=i+1;break}
 }
 assert(end>begin,name+' not closed');
 return scene.slice(start,end);
}
assert(scene.includes('property bool nativeModeRequested:false'), 'new 3D mode must default OFF');
assert(scene.includes('objectName:"nativeKogger3dToggle"'), 'K3D toggle missing');
assert(scene.includes('nativeSurfaceMesh.source==="kogger-native-surface"'), 'native input must have Kogger provenance');
assert(scene.includes('meshEngine.loadNativeSurface(nativeSurfaceMesh)'), 'native terrain data never loaded');
assert(scene.includes('onNativeSurfaceMeshChanged:if(nativeModeRequested)nativeDebounce.restart()'), 'native mesh updates not debounced');
assert(scene.includes('Rectangle{visible:meshEngine.vertices.length===0'), 'native-only lake wrongly shows empty state');
assert(scene.includes('!root.nativeMeshLoaded&&samples.length'), 'native mesh must not rebuild at every camera LOD change');
assert(dashboard.includes('nativeSurfaceMesh: root.displayNativeSurfaceMesh'), 'selected/replay lake not passed into the 3D page');
assert(header.includes('Q_INVOKABLE bool loadNativeSurface(const QVariantMap& surface)'), 'native C++ converter missing');
assert(cpp.includes('mark<1||mark>3') && cpp.includes('depth<=0') && cpp.includes('std::abs(twiceArea)<0.00001'), 'invalid triangles/depth not guarded');
assert(cpp.includes('{"measured",false}'), 'triangulated Kogger vertices must not be described as measured');

const source={version:1,source:'kogger-native-surface',vertices:[[40.16,44.47,3,3],[40.17,44.47,4,3],[40.16,44.48,5,1]],indices:[0,1,2]};
const calls=[];
const c={
  nativeModeRequested:false,nativeSurfaceAvailable:true,nativeSurfaceMesh:source,
  samples:[{lat:40.16,lon:44.47,depth:3}],
  lodLevel:0,gridSizeM:2,maxGapM:6,
  cachedSampleCount:0,cachedSampleSignature:'',selectedPoint:{old:true},selectedObject:null,
  cameraFramed:false,
  meshEngine:{
     vertices:[],
     loadNativeSurface(map){calls.push(['native',map]);this.vertices=[{x:0,y:0,depth:3}];return true},
     buildCached(arr){calls.push(['samples',arr.length]);this.vertices=[{x:0,y:0,depth:4}];return true},
     clear(){calls.push(['clear']);this.vertices=[]}
  },
  sampleSignature(){return 'test'},fitCamera(){this.cameraFramed=true}
};
const ctx=vm.createContext(c);
for(const name of ['rebuild','refreshForSamples'])vm.runInContext(extractFunction(name),ctx);
c.rebuild();assert.deepEqual(calls.map(x=>x[0]),['samples']);assert.equal(c.nativeMeshLoaded,false);
calls.length=0;c.nativeModeRequested=true;c.cameraFramed=false;c.rebuild();
assert.deepEqual(calls.map(x=>x[0]),['native']);assert.equal(c.nativeMeshLoaded,true);assert.equal(c.selectedPoint,null);
c.refreshForSamples();assert.equal(calls.length,1,'raw history triggered native rebuild');
calls.length=0;c.nativeSurfaceAvailable=false;c.rebuild();
assert.deepEqual(calls.map(x=>x[0]),['samples']);assert.equal(c.nativeMeshLoaded,false,'invalid native input retained');
console.log('PASS native Kogger 3D opt-in, provenance, switch/fallback and read-only geometry policy');
