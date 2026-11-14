// Verify the GPL Kogger-derived 256-level palette and production QML wiring.
import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
const raw=fs.readFileSync('custom/qml/NavoKoggerPalette.js','utf8').replace(/^\.pragma library\s*$/m,'');
const context={};vm.runInNewContext(raw,context);
for(let mode=0;mode<3;mode++){
  const lut=context.table(mode);
  assert.equal(lut.length,256);
  assert.match(lut[0],/^rgb\(/);
  assert.match(lut[255],/^rgb\(/);
  assert(new Set(lut).size>100,'palette is still banded');
  assert.equal(context.index(0),0);
  assert.equal(context.index(1),255);
  assert.equal(context.index(.5),128);
  assert.equal(context.index(NaN),0);
}
const qml=fs.readFileSync('custom/qml/NavoSonarPro.qml','utf8');
const cmake=fs.readFileSync('custom/CMakeLists.txt','utf8');
assert(qml.includes('KoggerPalette.index(v)'));
assert(qml.includes('KoggerPalette.table(root.paletteMode)'));
assert(!qml.includes('v > .72 ? 4'));
assert(cmake.includes('qml/NavoKoggerPalette.js'));
assert(qml.includes('rawSamples:raw'),'raw CHART retained');
console.log('PASS Kogger upstream 256-level palettes, non-destructive CHART wiring');
