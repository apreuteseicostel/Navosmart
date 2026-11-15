import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

const from = path => fs.readFileSync(path,'utf8');
function context(filename){
 const sandbox=vm.createContext({});
 vm.runInContext(from(filename).replace('.pragma library',''),sandbox);
 return sandbox;
}
const scale=context('custom/qml/NavoSonarDepthScale.js');
const depths=Array.from({length:50},(_,i)=>({bottom:2.8+0.4*Math.sin(i/6)}));
const r=scale.targetRange(depths,3,0,50);
assert(r>=3.5&&r<=5, '3 m seabed should fill about 75–85% of the echogram rather than 0–50 m');
assert.equal(scale.targetRange([],3,0,50),4,'plausible instrument 3m should permit 4m display scale');
assert.equal(scale.targetRange([],0.3,0,50),0,'near-surface interference cannot trigger a false 0–1m crop');
assert.equal(scale.targetRange([{bottom:NaN},{bottom:-2},{bottom:150}],NaN,0,50),0);
assert.equal(scale.targetRange(depths,3,0,3),3,'auto zoom cannot exceed the recorded physical range');
assert.equal(scale.targetRange([],10,8,12),5,'offset CHART records preserve physical source start');
assert.equal(scale.targetRange([],NaN,0,50),0,'no valid depth keeps the original range');
const withSpike=depths.concat([{bottom:49}]);
assert(scale.targetRange(withSpike,3,0,50)<8,'a single deep spike must not expand the chart to 50m');
assert.equal(scale.smoothRange(4,8,50),8,'new deep relief must expand immediately');
assert(scale.smoothRange(50,4,50)<50,'shallow relief must converge away from original 50m range');
assert.equal(scale.smoothRange(0,4,50),4,'first confident depth should snap to useful range');
assert.equal(scale.smoothRange(4,0,50),0,'unknown depth should disable risky crop');

const pro=from('custom/qml/NavoSonarPro.qml');
assert(pro.includes('import "NavoSonarDepthScale.js" as DepthWindow'));
assert(pro.includes('property string depthScaleMode: "auto"'), 'AUTO must be default');
assert(pro.includes('root.depthScaleMode==="raw"') || pro.includes('depthScaleMode==="raw"'), 'original RAW display mode missing');
assert(pro.includes('root.depthScaleMode="fixed"'), 'manual range control missing');
assert(pro.includes('objectName:"sonarDepthAutoButton"') && pro.includes('objectName:"sonarDepthRawButton"'));
assert(pro.includes('scaleStart, scaleRange, entry.offset, entry.range'), 'raster must be remapped by display scale only');
assert(pro.includes('onPausedChanged: if(!paused'), 'auto zoom should resume after pause');
assert(pro.includes('!depthScaleTimer.running'), 'continuous high-FPS replay must not starve scale updates');
assert(pro.includes('depthScaleMode==="raw" ? sourceDepthRange'), 'RAW must use original CHART range');
assert(!pro.includes('chartSource.setDepthRange('), 'display zoom may not change sonar hardware');
assert(pro.includes('depthScaleMode = "auto"') && pro.includes('autoDepthRangeM = 0'), 'Reset must restore AUTO');

const lab=context('custom/qml/NavoOfflineLabData.js');
const points=lab.samples(),segs=lab.contours(1),half=lab.contours(0.5),wide=lab.contours(5);
assert(points.length===23*19,'virtual bathymetry needs a real 2D grid');
assert(points.every(p=>p.synthetic&&Number.isFinite(p.lat)&&Number.isFinite(p.lon)&&p.depth>0));
assert(points.every(p=>Math.abs(p.lat)<.001&&Math.abs(p.lon)<.001),'virtual GPS must remain near neutral origin');
assert(segs.length>0&&segs.length<=3000,'contours missing or unbounded');
assert(half.length>=segs.length && wide.length<segs.length,'contour density selector not working');
assert(segs.every(s=>Number.isFinite(s.depth)&&Number.isFinite(s.a.x)&&Number.isFinite(s.a.y)&&Number.isFinite(s.b.x)&&Number.isFinite(s.b.y)));
assert.equal(lab.contours(0.1).length,0,'invalid contour steps must be rejected');
assert.deepEqual(JSON.parse(JSON.stringify(points)),JSON.parse(JSON.stringify(lab.samples())),'lab fixture must be deterministic');

const scene=from('custom/qml/NavoBathymetry3D.qml');
assert(scene.includes('property bool simulatedData:false') && scene.includes('property bool usePersistentCache:true'));
assert(scene.includes('if(usePersistentCache)meshEngine.buildCached(') && scene.includes('else meshEngine.build('),
 'lab must not write a persistent lake cache');
assert(scene.includes('SIMULARE • '),'3D synthetic measurements must not be labeled real');
const screen=from('custom/qml/NavoOfflineLab.qml');
const dashboard=from('custom/qml/NavoDashboard.qml');
const settings=from('custom/qml/NavoSettingsV3.qml');
const cmake=from('custom/CMakeLists.txt');
assert(screen.includes('objectName:"navoProOfflineLab"') && screen.includes('SIMULARE • FĂRĂ COMENZI'));
assert(screen.includes('objectName:"offlineLabRecordingPicker"') && screen.includes('onAccepted:root.replayFileSelected(selectedFile)'));
assert(screen.includes('simulatedData:true') && screen.includes('usePersistentCache:false'));
assert(screen.includes('NU ESTE KOGGER NATIV'),'virtual contours must not masquerade as native sonar');
assert(!/sendCommand\(|guidedModeGotoLocation\(|uploadMission\(|saveReplayLake\(/.test(screen),'lab must never command H743 or save real lakes');
assert(settings.includes('objectName:"settingsOpenOfflineLab"') && settings.includes('onClicked:root.offlineLabRequested()'));
assert(dashboard.includes('root.activePage === 14 ? offlineLabPage'));
assert(dashboard.includes('function openOfflineLab()') && dashboard.includes('function openLabRecording(url)'));
assert(dashboard.includes('if (!offlineLabAllowed)') && dashboard.includes('!sonar.recording') && dashboard.includes('root.vehicle.armed'));
assert(dashboard.includes('var opened=sonar.startReplay(url)'),'lab must reuse read-only recorded decoder, not fake CHART');
assert(cmake.includes('qml/NavoOfflineLab.qml') && cmake.includes('qml/NavoSonarDepthScale.js') && cmake.includes('qml/NavoOfflineLabData.js'));
console.log('PASS automatic physical-depth window, manual RAW fallback, synthetic 2D/3D lab isolation, safe replay wiring');
