// Contract tests for Kogger-style full-recording file browsing.
import fs from 'node:fs';
import assert from 'node:assert/strict';
const read=p=>fs.readFileSync(p,'utf8');
const replay=read('custom/src/NavoKoggerReplay.cc');
const rHeader=read('custom/src/NavoKoggerReplay.h');
const native=read('custom/src/NavoKoggerEchogramItem.cc');
const nHeader=read('custom/src/NavoKoggerEchogramItem.h');
const sonar=read('custom/qml/NavoSonarPro.qml');
const harness=read('tests/kogger-replay/replay-seek.cpp');
const screenshot=read('tests/kogger-replay/native-kogger-image.cpp');
for(const name of ['readChartColumn','readChartPacket']) {
  assert(replay.includes('NavoKoggerReplay::'+name+'('), name+' missing');
}
assert(rHeader.includes('QFile _viewFile'), 'viewport needs independent file handle');
assert(replay.includes('const qint64 start=_columns.at(index).offset'), 'must use actual full-file index');
assert(replay.includes('_viewFile.seek(start)'), 'must read selected column on disk');
assert(replay.includes('if(seq>out->bytes.size())out->bytes.append('), 'loss offsets must be preserved');
assert(native.includes('NavoKoggerReplay::ChartColumn'), 'native viewport not using raw KLF column');
assert(native.includes('fileIndexAtPixel('), 'pixel columns not mapped into full timeline');
assert(native.includes('MaxFileCacheBytes=')===false); // defined in header
assert(nHeader.includes('MaxFileCacheBytes=24*1024*1024'),'G20 cache memory budget absent');
for (const name of ['fileReplay','fileWindowStart','fileWindowColumns','fileSelectedColumn']) {
  assert(nHeader.includes('Q_PROPERTY(') && nHeader.includes(name), name+' property missing');
  assert(sonar.includes(name+':'), 'production QML does not bind '+name);
}
assert(sonar.includes('fileBrowserActive') && sonar.includes('fileZoom'), 'file browser absent');
assert(sonar.includes('root.changeFileZoom(1)'), 'show all not implemented');
assert(sonar.includes('onPositionChanged:function(mouse)'), 'drag pan absent');
assert(sonar.includes('if(root.fileBrowserActive)root.fileCenterColumn=Math.round(value)'), 'slider still seeks/replays instead of browsing');
assert(sonar.includes('chartSource.pauseReplay(true)'), 'file browser must pause background streaming');
assert(harness.includes('replay.position()==cursorBeforeBrowse'),'KLF test does not detect intrusive file seek');
assert(screenshot.includes('kogger-native-file-overview.png'),'native file overview not pixel tested');
assert(!/MAV_CMD|guidedModeGotoLocation|uploadMission/.test(native),'file renderer must never command autopilot');
console.log('PASS Kogger full-file pixel cursor, on-disk random access, bounded cache, pan/zoom, and replay isolation');
