// Experiment B gate: independent Kogger workspace, no replacement of Sonar PRO.
import assert from 'node:assert/strict';
import fs from 'node:fs';
const read=p=>fs.readFileSync(p,'utf8');
const ui=read('custom/qml/NavoKoggerStandalone.qml');
const dash=read('custom/qml/NavoDashboard.qml');
const cmake=read('custom/CMakeLists.txt');
const pro=read('custom/qml/NavoSonarPro.qml');
const required=(s,needle)=>assert(s.includes(needle),'Missing: '+needle);
for(const n of ['NavoKoggerReplay {','NavoKoggerDecoder {','NavoEthernetTransport {','NavoKoggerEchogramItem {',
'objectName:"koggerBFullFileTimeline"','objectName:"koggerBOpenFile"','fileReplay:root.fileMode && replay.indexReady ? replay : null',
'onBytesReady: function(bytes){decoder.feedBytes(bytes)}','onBytesReceived: function(bytes){if(!root.fileMode)decoder.feedBytes(bytes)}',
'transport.disconnectEndpoint()','replay.setPaused(true)'])required(ui,n);
required(dash,'id: koggerIndependentPage');
required(dash,'root.activePage === 15 ? koggerIndependentPage');
required(dash,'text: "KOGGER SONAR"');
required(cmake,'qml/NavoKoggerStandalone.qml');
required(pro,'objectName:"navoSonarPro"');
assert(!/sendCommand\(|guidedModeGotoLocation\(|MAV_CMD|uploadMission\(/.test(ui),'Kogger standalone must not control the boat');
assert(!/NavoSonarEthernet\s*\{/.test(ui),'standalone source must not mutate NAVO shared Dataset');
console.log('PASS B: standalone Kogger page, separate replay/live data, no MAVLink control, Sonar PRO retained');
