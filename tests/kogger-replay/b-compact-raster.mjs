// Regression contract for the isolated Kogger B mobile view.
// No external dependencies; run: node tests/kogger-replay/b-compact-raster.mjs
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

const qml = readFileSync('custom/qml/NavoKoggerSonar.qml', 'utf8')
const cpp = readFileSync('custom/src/NavoKoggerEpochPlotItem.cc', 'utf8')
const header = readFileSync('custom/src/NavoKoggerEpochPlotItem.h', 'utf8')

for (const name of [
  'koggerBCompactStatus', 'koggerBLeftRail', 'koggerBRightRail',
  'koggerBLeftRevealTab', 'koggerBRightRevealTab',
  'koggerBCompactTimeline', 'koggerNativeOriginalEpochViewB'
]) assert.ok(qml.includes(name), `Missing compact control: ${name}`)

assert.match(qml, /anchors\.fill:\s*parent\s*\n\s*fileReplay:/, 'Plot must fill the viewport')
assert.match(qml, /component SonarRailButton: Button \{/, 'Dark Kogger-style component missing')
assert.doesNotMatch(qml, /component SonarRailButton: SonarRailButton/, 'Button cannot inherit from itself')
assert.match(qml, /interval:\s*4500/, 'Auto-hide timeout missing')
assert.match(qml, /else root\.controlsVisible = false/, 'Controls never auto-hide')
assert.match(qml, /visible:\s*root\.controlsVisible && plot\.fileReady/, 'Timeline must hide with controls')
assert.match(qml, /onClicked: root\.toggleControls\(\)/, 'Side reveal tabs must work')
assert.match(qml, /root\.chartSource\.startReplay\(selectedFile\)/, 'File replay must remain wired')
assert.match(qml, /root\.chartSource\.stopReplay\(\)/, 'Live/replay control must remain wired')
assert.match(qml, /root\.dragToPan/, 'Pan/inspector switch missing')
assert.match(qml, /plot\.position = Math\.max/, 'Pan must move real indexed view')
assert.match(qml, /onMoved:\s*\{\s*plot\.position = value/, 'Timeline must browse independent of decoder seek')
assert.doesNotMatch(qml, /guidedModeGotoLocation|sendCommand|MAV_CMD/, 'Sonar view must not command the boat')

// Source-level invariants specific to the missing-column artifacts in the video.
assert.match(header, /struct FileColumn \{QByteArray raster;\}/, 'Expect bounded raster cache')
assert.match(cpp, /c\.raster\.resize\(h\)/, 'Pre-rasterize original Epoch columns')
assert.match(cpp, /if\(pending\)_loadTimer\.start\(\)/,
    'Load next visible batch even when LRU cache is full')
assert.doesNotMatch(cpp, /if\(pending && canContinue\)/, 'Old black-strip starvation gate returned')
assert.match(cpp, /if\(_file&&!fileReady\(\)\)/,
    'KLF index-pending must not fall through to stale live Dataset')
assert.match(cpp, /if\(_file && !fileReady\(\)\)return \{\}/,
    'Inspector must not report live epochs during KLF indexing')
assert.match(cpp, /next\.height\(\)!=old\.height\(\)\)clearFileCache\(\)/,
    'Raster geometry invalidation missing')
assert.match(cpp, /_range=v;clearFileCache\(\)/, 'Depth changes must invalidate raster')
assert.match(cpp, /_compensate=v;clearFileCache\(\)/,
    'Compensation changes must invalidate raster')
const paint = cpp.split('void NavoKoggerEpochPlotItem::paint(QPainter* p){')[1]
assert.ok(paint, 'Missing native painter')
const filePath = paint.split('if(onFile){')[1]?.split('}else{')[0]
assert.ok(filePath, 'Missing file-cache painter')
assert.match(filePath, /column\.at\(y\)/, 'Paint must use existing 8-bit column')
assert.doesNotMatch(filePath, /chartTo|readChartColumn|setChart/,
    'File-mode paint must not decode or rasterize CHART again')

// Full 15,424-column KLF fits the new entry cap. Beyond it, LRU still evicts.
// a full cache evicts old entries before rendering the new window.
const limit = 32768
const cache = new Map()
let evictions = 0
for (let index = 0; index < 65536; index += 620) {
  for (let column = index; column < Math.min(index + 620, 65536); ++column) {
    if (cache.has(column)) continue
    cache.set(column, 1)
    if (cache.size > limit) {
      cache.delete(cache.keys().next().value)
      ++evictions
    }
  }
}
assert.ok(evictions > 0 && cache.has(15423), 'Far end of KLF must remain accessible after eviction')
console.log('PASS Kogger B auto-hide rails, file isolation, 8-bit raster caching, bounded eviction')
