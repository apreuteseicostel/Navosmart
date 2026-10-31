import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
const source=fs.readFileSync(new URL('../custom/qml/NavoDashboard.qml',import.meta.url),'utf8');
const begin=source.indexOf('    function connectConfiguredNetworkServices(');
const end=source.indexOf('    readonly property string activePageName:',begin);
const code=source.slice(begin,end);
function setup(saved={}) {
 const calls={sonar:0,camera:0};
 const root={networkStartupLoaded:false,sonarStartupEnabled:true,cameraStreamUrl:'',cameraProtocol:'auto'};
 const sonar={host:'',port:0,udp:false,replayMode:false,connected:false,connectSonar(){calls.sonar++}};
 const cameraEthernet={host:'',port:0,udp:false,connected:false,connectCamera(){calls.camera++}};
 const context={root,sonar,cameraEthernet,connectivityController:{savedEthernet(){return saved}}};
 vm.createContext(context);vm.runInContext(code,context);
 return {calls,root,sonar,camera:cameraEthernet,run:context.connectConfiguredNetworkServices};
}
let s=setup();s.run(true);assert.deepEqual(s.calls,{sonar:0,camera:0});
s=setup({sonarHost:'192.168.0.7',sonarPort:23,cameraHost:'192.168.0.8',cameraPort:554,cameraStreamUrl:'rtsp://192.168.0.8/live'});
s.run(true);assert.deepEqual(s.calls,{sonar:1,camera:1});assert.equal(s.root.cameraStreamUrl,'rtsp://192.168.0.8/live');
s.sonar.connected=true;s.camera.connected=true;s.run(false);assert.deepEqual(s.calls,{sonar:1,camera:1});
s=setup({sonarHost:'192.168.0.7',sonarPort:23});s.sonar.replayMode=true;s.run(true);assert.equal(s.calls.sonar,0);
s=setup({sonarHost:'192.168.0.7',sonarPort:23,connectOnStartup:false});s.run(true);assert.equal(s.calls.sonar,0);s.run(false);assert.equal(s.calls.sonar,1);
s=setup({sonarPort:2000,sonarUdp:true,cameraPort:70000,cameraHost:'192.168.0.8'});s.run(true);assert.deepEqual(s.calls,{sonar:1,camera:0});
s.sonar.host='edited';s.sonar.port=3000;s.run(false);assert.equal(s.sonar.host,'edited');assert.equal(s.sonar.port,3000);
assert(!/startMission|sendCommand|arm\(/.test(code));
console.log('PASS startup connections: saved endpoints, no duplicates, replay isolation, per-sonar opt-out, UDP, invalid ports, no actuator commands');
