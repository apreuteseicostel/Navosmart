import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';

// Execute the actual QML JavaScript functions with a passive, simulated
// battery Fact: these tests never command a relay or contact hardware.
const src = fs.readFileSync('custom/qml/NavoStatusDetails.qml', 'utf8');
function extract(name) {
    const start = src.indexOf('function ' + name + '(');
    assert(start >= 0, 'Missing production function ' + name);
    let open = src.indexOf('{', start), depth = 0, end = open;
    for (; end < src.length; ++end) {
        if (src[end] === '{') depth++;
        if (src[end] === '}') { depth--; if (depth === 0) break; }
    }
    assert(end < src.length, 'Unterminated ' + name);
    return src.slice(start, end + 1);
}
// A simple lexical brace scanner is enough for these functions: no braces in
// quoted strings or template literals.
const details = {
    loadSampleReady: true, linkAlive: true,
    voltage: 16.0, current: 0.19,
    lampOffSample: null, lampOnSample: null,
};
const ctx = vm.createContext({ details, Number, isFinite, NaN });
const fn = {};
for (const name of ['resetLampTest', 'captureLampSample', 'lampDeltaCurrent', 'lampDeltaPower']) {
    fn[name] = vm.runInContext('(' + extract(name) + ')', ctx);
}
assert(Number.isNaN(fn.lampDeltaCurrent()));
assert.equal(fn.captureLampSample(false), true);
assert.equal(details.lampOffSample.current, 0.19);
// Far nominal 10W on a 16V pack means about 0.625A extra at its input.
details.current = 0.815;
assert.equal(fn.captureLampSample(true), true);
assert(Math.abs(fn.lampDeltaCurrent() - 0.625) < 1e-9);
assert(Math.abs(fn.lampDeltaPower() - 10) < 1e-9);
assert.equal(details.lampOffSample.current, 0.19, 'OFF snapshot must not be overwritten');
fn.resetLampTest();
assert(Number.isNaN(fn.lampDeltaPower()));
assert.equal(details.lampOnSample, null);
details.loadSampleReady = false;
assert.equal(fn.captureLampSample(true), false, 'Disconnected/invalid telemetry must not be captured');
assert.equal(details.lampOnSample, null);
// Zero delta is diagnostic evidence of a bypassed / uncalibrated monitor,
// not permission to invent the missing 10 W.
details.loadSampleReady = true;
details.current = 0.19;
fn.captureLampSample(false);
fn.captureLampSample(true);
assert.equal(fn.lampDeltaCurrent(), 0);
assert.equal(fn.lampDeltaPower(), 0);
assert(src.includes('Curentul este raportat de monitorul H743'));
assert(src.includes('BATT_AMP_PERVLT'));
assert(src.includes('onLinkAliveChanged: { if (!linkAlive) resetLampTest() }'));
assert(src.includes('onVehicleChanged: { temperatureSamples = []; resetLampTest() }'));
console.log('PASS battery current: 10W load delta, zero delta, invalid telemetry, snapshot resets, passive controls');
