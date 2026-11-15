// Routing and shared-transport safety contract for PRO B V2, PRO KGR, PiP.
// Run: node tests/kogger-replay/dual-sonar-live-pip.mjs
import assert from 'node:assert/strict'
import {readFileSync, existsSync} from 'node:fs'
const read = p => readFileSync(p,'utf8')
const dash=read('custom/qml/NavoDashboard.qml')
const b=read('custom/qml/NavoKoggerSonar.qml')
const kgr=read('custom/qml/NavoSonarPro.qml')
const pip=read('custom/qml/NavoSonarPip.qml')
const connection=read('custom/qml/NavoSonarLiveConnection.qml')
const cmake=read('custom/CMakeLists.txt')
const nativeAdapter=read('custom/src/NavoKoggerDatasetAdapter.h')
const bridge=read('custom/src/NavoKoggerChartBridge.h')
const service=read('custom/kogger_native/NavoKoggerService.cpp')

assert.match(dash,/id:\s*sonarProPage\s*\n\s*NavoKoggerSonar\s*\{/,
  'PRO must launch full B V2 view')
assert.match(dash,/id:\s*koggerSonarPage\s*\n\s*NavoSonarPro\s*\{/,
  'PRO KGR must launch the C native Sonar PRO view')
assert.match(dash,/badgeLabel:"KGR"/, 'KGR icon badge missing')
assert.match(dash,/root\.activePage === 10 \? sonarProPage/,
  'B must use PRO navigation route')
assert.match(dash,/root\.activePage === 13 \? koggerSonarPage/,
  'KGR must use dedicated route')
assert.doesNotMatch(dash,/id:\s*sonarPage\b/,
  'Legacy Kogger basic page must be removed')
assert.doesNotMatch(dash,/NavoSonarFullScreen|NavoSonarCard/,
  'Basic sonar page must not be referenced')
assert.doesNotMatch(cmake,/qml\/NavoSonarFullScreen\.qml|qml\/NavoSonarCard\.qml/,
  'Do not package legacy basic sonar widgets in Android APK')
assert.ok(!existsSync('custom/qml/NavoSonarCard.qml'),
  'Unused basic SONAR card should be deleted')
assert.match(dash,/function toggleSonarPip\(\)/,'Dashboard toggle missing')
assert.match(dash,/active:\s*root\.activePage === 0 && root\.sonarPipEnabled/,
  'PiP must unload entirely when hidden or switching pages')
assert.match(dash,/id:\s*persistentSonarPip/,'Dashboard must host PiP')
assert.match(dash,/onCloseRequested:\s*\{\s*root\.sonarPipEnabled = false/,
  'Touching PiP must close only the preview')
assert.match(dash,/anchors\.bottom:\s*parent\.bottom/,
  'Sonar PiP must be anchored bottom right')
assert.match(pip,/objectName: "sonarPipNativeEpochPlot"/,
  'PiP must show native Epoch echogram')
assert.match(pip,/signal closeRequested\(\)/,
  'PiP needs a close action')
assert.match(pip,/property var sonar: null/,
  'PiP must receive existing sonar controller instead of constructing one')
assert.equal((dash.match(/NavoSonarEthernet\s*\{/g)||[]).length,1,
  'Exactly one native sonar transport must serve PRO, KGR and PiP')
for(const view of [b,kgr]){
  assert.match(view,/NavoSonarLiveConnection\s*\{/,
    'Both full-screen views need explicit LIVE connection access')
  assert.match(view,/sonar:\s*root\.chartSource/,
    'Connection dialog must share existing network controller')
}
assert.match(connection,/sonar\.connectSonar\(\)/,'Connect button must call real Ethernet method')
assert.match(connection,/sonar\.disconnectSonar\(\)/,'Disconnect button must work')
assert.match(connection,/saved\.setValue\("sonarHost", host\)/,
  'Saved connection must persist to dashboard namespace')
assert.match(connection,/saved\.setValue\("sonarPort", port\)/)
assert.match(connection,/saved\.setValue\("sonarUdp", udpChoice\)/)
assert.match(connection,/root\.sonar\.dataAlive/,
  'Connection state must not label TCP-only transport as LIVE')
assert.match(kgr,/chartSource && chartSource\.dataAlive/,
  'KGR must not report LIVE without fresh CHART')
assert.match(b,/chartSource && chartSource\.dataAlive/,
  'B V2 must not report LIVE without fresh CHART')
assert.match(nativeAdapter,/const int step = record\.version == 1 \? 2 : 1/,
  'Live v1 chart amplitude pairs must match decoder')
assert.match(bridge,/const QString identity=\(udp&&name\.isEmpty\(\)\)/,
  'UDP listen-only live endpoint must have a native channel ID')
assert.doesNotMatch(service,/record\.version!=0\)return false/,
  'Kogger Dataset must not reject valid v1 live CHART')
assert.doesNotMatch(dash,/sendCommand\([^\n]*sonarPip/,
  'PiP must never trigger a boat command')
console.log('PASS PRO B V2 / PRO KGR / Dashboard PiP shared LIVE controller, v1 and no basic page')
