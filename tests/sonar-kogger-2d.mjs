// Fast, offline regression tests for NAVO's Kogger-inspired 2D display controls.
// Display transformations must never alter the raw CHART sample/dataset pathway.
import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';

const qml = fs.readFileSync('custom/qml/NavoSonarPro.qml', 'utf8');
const control = fs.readFileSync('custom/qml/NavoSonar2DLevels.qml', 'utf8');
const cmake = fs.readFileSync('custom/CMakeLists.txt', 'utf8');
function qmlFn(name, context) {
  const signature = 'function ' + name + '(';
  const start = qml.indexOf(signature);
  assert(start >= 0, name + ' missing');
  const next = qml.indexOf('\n    }', start);
  assert(next >= 0, name + ' unterminated');
  const src = qml.slice(start, next + 6);
  return vm.runInNewContext('(' + src + ')', context);
}
assert(cmake.includes('qml/NavoSonar2DLevels.qml'), 'QML component is not registered in CMake');
assert(control.includes('RangeSlider') && control.includes('signal levelsEdited'), 'two-ended level control missing');
assert(control.includes('signal paletteSelected'), 'palette signals missing');
assert(control.includes('Reglaje doar pentru afișare'), 'display-only indication missing');
assert(qml.includes('NavoSonar2DLevels {'), '2D control not used by Sonar PRO');
assert(qml.includes('v = levelStrength(v)'), 'echogram raster must apply levels');
assert(qml.includes('levelStrength(Math.max(0, Math.min(1, (value - noiseFloor) * gain)))'), 'live echo must use the same levels');
assert(qml.includes('levelLow, levelHigh].join(":")'), 'raster cache key must include both levels');
assert(qml.includes('onLevelLowChanged: repaint()') && qml.includes('onLevelHighChanged: repaint()'), 'redraw on level changes');
assert(qml.includes('onBottomColumnReady(sequence,depth)') && qml.includes('root.captureGeoChart(); root.pushHistory()'), 'live source and bottom updates preserved');

const ctx = {levelLow: 0, levelHigh: 100, dayPalette: false, amberPalette: false, gain: 1, noiseFloor: .10, noiseFilterEnabled: false};
const strength = qmlFn('levelStrength', ctx);
const close = (a,b) => assert(Math.abs(a-b)<1e-10, a + ' != ' + b);
for (const v of [0, .1, .3, .5, .9, 1]) close(strength(v), v);
ctx.levelLow=25;ctx.levelHigh=75;
close(strength(.25),0);close(strength(.5),.5);close(strength(.75),1);
close(strength(.01),0);close(strength(.99),1);
ctx.levelLow=80;ctx.levelHigh=80; // guard against a degenerate range
assert(Number.isFinite(strength(.9)));
const select = qmlFn('selectPalette', ctx);
select(2);assert.equal(ctx.amberPalette,true);assert.equal(ctx.dayPalette,false);
select(1);assert.equal(ctx.amberPalette,false);assert.equal(ctx.dayPalette,true);
select(0);assert.equal(ctx.amberPalette,false);assert.equal(ctx.dayPalette,false);
select(99);assert.equal(ctx.dayPalette,false);assert.equal(ctx.amberPalette,false);
ctx.levelLow=30;ctx.levelHigh=70;ctx.amberPalette=true;
const reset = qmlFn('resetDisplaySettings', ctx);reset();
assert.deepEqual([ctx.levelLow,ctx.levelHigh,ctx.amberPalette,ctx.dayPalette], [0,100,false,false]);
assert.equal(ctx.noiseFloor,.10);
console.log('PASS NAVO Kogger 2D level-window math, palettes, CMake, signal and non-destructive render path');
