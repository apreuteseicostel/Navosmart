// Shared Kogger native viewport regression contract for experiment B and C.
// Run: node tests/kogger-replay/viewport-atomic.mjs
import assert from 'node:assert/strict'
import {readFileSync} from 'node:fs'

const cpp=readFileSync('custom/src/NavoKoggerEpochPlotItem.cc','utf8')
const head=readFileSync('custom/src/NavoKoggerEpochPlotItem.h','utf8')
const replay=readFileSync('custom/src/NavoKoggerReplay.cc','utf8')
const decoder=readFileSync('custom/src/NavoKoggerDecoder.cc','utf8')

assert.match(head,/QImage _lastCompleteFrame/, 'Painter must retain last complete viewport')
assert.match(head,/MaxEntries=32768/, 'Must retain full 15,424-column file with 20MiB budget when possible')
assert.match(head,/MaxBytes=20\*1024\*1024/, 'Native cache must remain memory-bounded')
assert.match(cpp,/if\(_file&&!fileReady\(\)\)/, 'KLF indexing must not show the live dataset')
assert.match(cpp,/QElapsedTimer budget/, 'Bounded adaptive GUI-thread CHART batches missing')
assert.match(cpp,/added>=96\|\|\(added>=8&&budget\.elapsed\(\)>=7\)/,
  'Batch must have both a time limit and a column limit')
assert.match(cpp,/if\(pending\)_loadTimer\.start\(\)/,
  'A full LRU cache must not starve a newly visible viewport')
assert.match(cpp,/if\(added&&!pending\)update\(\)/,
  'Partial load batches must not publish half-rendered frames')
assert.match(cpp,/if\(waitingColumns\)/,
  'Missing columns must be explicitly handled during paint')
assert.match(cpp,/_lastCompleteFrame=image/, 'Only a full viewport may replace last complete frame')
assert.match(cpp,/Se încarcă %1 coloane CHART/,
  'Viewport must label loading, not show black vertical strips as data')
assert.match(cpp,/raw\.version<=1/, 'Kogger CHART v1 must be accepted')
assert.match(cpp,/step=raw\.version==1\?2:1/,
  'Kogger CHART v1 amplitudes are two-byte pairs')
assert.match(decoder,/const int step=_chartVersion==1\?2:1/,
  'Match upstream decoder sample interpretation')
assert.match(replay,/\(v!=0&&v!=1\)/,
  'Indexer must accept the same valid Kogger CHART v0/v1 range')
assert.match(cpp,/clearFileCache\(\);emit viewChanged\(\);queueVisible\(\)/,
  'Raster must be invalidated on scale or compensation change')
assert.doesNotMatch(cpp,/if\(pending && canContinue\)/,
  'The old LRU starvation gate would reintroduce black stripes')

console.log('PASS Kogger B/C: atomic KLF viewport, adaptive scheduler, CHART v0/v1, bounded LRU')
