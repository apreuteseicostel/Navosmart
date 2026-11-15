// Source-level regression contract for S26 Ultra polish / recorded KLF GPS route.
// Real QML/C++ validation still runs in Android and recorded replay CI.
import assert from 'node:assert/strict'
import {readFileSync} from 'node:fs'
const read = p => readFileSync(p,'utf8')
const dash=read('custom/qml/NavoDashboard.qml')
const map=read('custom/qml/NavoMap.qml')
const kgr=read('custom/qml/NavoKoggerSonar.qml')
const pro=read('custom/qml/NavoSonarPro.qml')
const ethernet=read('custom/qml/NavoSonarEthernet.qml')
const replayH=read('custom/src/NavoKoggerReplay.h')
const replayCpp=read('custom/src/NavoKoggerReplay.cc')

assert.ok(dash.includes('text: "KGR"; proBadge: true; badgeLabel: "KGR"'),
  'Sidebar KGR should launch native B V2, not the NAVO PRO page')
assert.ok(dash.includes('text:"PRO";proBadge:true;badgeLabel:"PRO"'),
  'Sidebar PRO should launch advanced NAVO sonar')
assert.ok(dash.includes('width: Math.max(208, Math.min(252, root.width * 0.22))'),
  'Sonar picture-in-picture should be wider than original 170px')
assert.ok(dash.includes('persistentCameraPip.y + persistentCameraPip.height'),
  'PiP must account for vertical space below camera PiP')

for (const side of ['left','right']){
  const cap=side[0].toUpperCase()+side.slice(1)
  assert.ok(map.includes('property bool '+side+'MapRailVisible: true'),
    side+' map rail must have independent visibility')
  assert.ok(map.includes('id: '+side+'MapAutoHide'),
    side+' map rail needs a dedicated auto-hide timer')
  assert.ok(map.includes('navoMap'+cap+'EdgeReveal'),
    side+' map rail must reopen from narrow touchscreen edge')
}
assert.equal((map.match(/interval: 1000/g)||[]).length,2,
  'Map rails must each auto-hide in one second')
assert.ok(map.includes('border.color: parent.checked ? "#30dcff"'),
  'Right rail active controls must have visible selected border')
assert.ok(/checked:\s*root\.headingUp/.test(map) &&
          /checked:\s*root\.rulerMode/.test(map) &&
          /checked:\s*root\.bathymetryHDEnabled/.test(map),
  'Map North/ruler/bathymetry selection must stay indicated')

assert.ok(kgr.includes('koggerBDraggableInspectorCursor'),
  'Kogger yellow cursor needs enlarged interactive drag target')
assert.ok(kgr.includes('root.selectedEpoch > 0'),
  'Kogger selection must keep epoch/depth status visible independently')
assert.ok(kgr.includes('root.inspectScreenAt(hit.x, hit.y)'),
  'Dragging selected cursor must inspect the real Kogger viewport')
assert.ok(kgr.includes('railButton.active ? "#3ee5ff"'),
  'KGR right menu needs visible active state')

assert.ok(pro.includes('id: bottomToolsHide') &&
          pro.includes('interval: 1500') &&
          pro.includes('navoSonarBottomEdgeReveal'),
  'NAVO PRO file timeline must hide after 1.5 seconds and reopen on edge touch')
assert.ok(pro.includes('bottomToolsSlider.visualPosition') &&
          pro.includes('SonarBottomButton: Button'),
  'NAVO PRO bottom slider must use themed track, handle, and buttons')

assert.ok(replayH.includes('Q_PROPERTY(QVariantList indexedGeoTrack READ indexedGeoTrack NOTIFY indexChanged)'),
  'KLF reader must expose the full indexed GPS route')
assert.ok(replayH.includes('geoAtFraction(double fraction) const'),
  'Selected KLF column must expose its recorded coordinate')
assert.ok(replayCpp.includes('MaxGeoSamples=3000'),
  'GPS path must be downsampled to a safe viewport budget')
assert.ok(replayCpp.includes('if(!p.gpsFix||!std::isfinite(p.lat)'),
  'Invalid recorded GPS must not be displayed as historical position')
assert.ok(ethernet.includes('property real replayViewPosition: 0.5'),
  'Selected replay fraction must be shared between KGR, NAVO PRO and the map')
assert.ok(dash.includes('readonly property var indexedReplayRoute: indexedGeoCoordinates()'),
  'Dashboard must render complete indexed GPS route, not only played frames')
assert.ok(dash.includes('replayCursorCoordinate: root.replaySelectionCoordinate'),
  'Dashboard map must receive the historical selection position')
assert.ok(map.includes('navoIndexedKlfGpsRoute') &&
          map.includes('navoIndexedKlfSelectedGps'),
  'Map must show recorded KLF track and separate selected-frame marker')
assert.ok(pro.includes('property var replayCursorCoordinate: QtPositioning.coordinate()'),
  'Advanced NAVO PRO map must follow the same historical cursor')
assert.ok(kgr.includes('root.chartSource.replayViewPosition = plot.position'),
  'Kogger B cursor must feed shared selected KLF position')
console.log('PASS sonar badge routing, map rails, NAVO slider and KLF GPS replay index')
