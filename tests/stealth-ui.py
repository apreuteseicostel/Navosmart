"""Production profile, panel and alert policy. All hardware commands are mocked."""
import os
os.environ.setdefault('QT_QPA_PLATFORM','offscreen')
os.environ.setdefault('QT_QUICK_BACKEND','software')
from pathlib import Path
from tempfile import TemporaryDirectory
import subprocess,PySide6
from PySide6.QtCore import QObject,QUrl,QMetaObject,Q_ARG,Q_RETURN_ARG,QResource
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine,QQmlComponent
from PySide6.QtTest import QTest
from PySide6.QtQuick import QQuickItem
app=QGuiApplication([]);app.setOrganizationName('NavoTest');app.setApplicationName('Stealth')
repo=Path(__file__).resolve().parent.parent;engine=QQmlApplicationEngine();errors=[]
engine.warnings.connect(lambda ws:errors.extend(str(w) for w in ws))
with TemporaryDirectory() as directory:
 qrc=Path(directory)/'icons.qrc';resource=Path(directory)/'icons.rcc'
 qrc.write_text('<RCC><qresource prefix="/qml/NavoSmart/icons">'+''.join(f'<file alias="{p.name}">{p}</file>' for p in (repo/'custom/icons').glob('*.svg'))+'</qresource></RCC>')
 subprocess.run([str(Path(PySide6.__file__).parent/'Qt/libexec/rcc'),'--binary',str(qrc),'-o',str(resource)],check=True)
 assert QResource.registerResource(str(resource))
 p=Path(directory)/'Test.qml'
 p.write_text('''import QtQuick
import QtQuick.Controls
import "'''+(repo/'custom/qml').as_uri()+'''" as Navo
ApplicationWindow {
 id:window;visible:true;width:480;height:600
 property var lights:[];property var speeds:[];property bool rejectLights:false
 QtObject{id:boat}
 QtObject{id:otherBoat}
 Navo.NavoStealth {
  id:profile;objectName:"profile";vehicle:boat;linkReady:true;gpsReady:true
  lightsReady:true;headlightOn:true;positionLightsOn:false
  dispatchLight:function(target,value){
   if(window.rejectLights)return false
   window.lights=window.lights.concat([{target:target,value:value}])
   return true
  }
  onSpeedRequested:function(speed){window.speeds=window.speeds.concat([speed])}
 }
 Navo.NavoStealthPanel {id:settingsPanel;objectName:"panel";width:parent.width;controller:profile}
 Navo.NavoBaitingController {id:bait}
 Navo.NavoRoutePlan {id:route}
 Navo.NavoBaitingPanel {id:baitPanel;objectName:"baitPanel";width:parent.width;visible:false;controller:bait;routePlan:route;hopperBridge:null;waypoint:null;stealth:profile}
 function activate(){return profile.activate()}
 function observe(){profile.observe()}
 function off(){profile.deactivate(true)}
 function limit(){return profile.setSpeedLimit(5)}
 function invalidLimit(){return profile.setSpeedLimit(0)}
 function overrideLight(){profile.manualLightOverride()}
 function retry(){return profile.applyLights()}
 function timeout(){profile.requestedAt=Date.now()-6000;profile.observe()}
 function swap(){profile.vehicle=otherBoat}
 function relayAckAccepted(){return profile.relayCommandResult(0,0)}
 function relayAckDenied(){return profile.relayCommandResult(4,0)}
 function relayAckDuplicate(){return profile.relayCommandResult(4,2)}
 function relayTimeout(){return profile.relayAckTimeout()}
}''')
 engine.load(QUrl.fromLocalFile(str(p)));assert engine.rootObjects(),errors
 w=engine.rootObjects()[0];c=w.findChild(QObject,'profile');panel=w.findChild(QQuickItem,'panel')
 def call(name):return QMetaObject.invokeMethod(w,name,Q_RETURN_ARG('QVariant'))
 def run(name):QMetaObject.invokeMethod(w,name)
 def lights():return w.property('lights').toVariant()
 def speeds():return w.property('speeds').toVariant()
 assert not c.property('active') # never re-enable from persisted preference
 w.setProperty('rejectLights',True)
 assert call('activate') and c.property('lightState')=='FAILED' and not lights()
 run('off');w.setProperty('rejectLights',False)
 c.setProperty('linkReady',False);assert not call('activate') and not lights()
 c.setProperty('linkReady',True);assert call('activate')
 assert lights()==[{'target':2,'value':1}] and not speeds()
 assert not call('activate') # duplicate activation cannot lose original light snapshot
 c.setProperty('positionLightsOn',True);run('observe');assert lights()[-1]=={'target':1,'value':0}
 c.setProperty('headlightOn',False);run('observe');assert c.property('lightState')=='CONFIRMED'
 c.setProperty('navigationActive',True);c.setProperty('flightMode','GUIDED');run('observe')
 assert speeds()[-1]==c.property('speedLimitMps')
 count=len(speeds());run('observe');assert len(speeds())==count
 assert call('limit') and speeds()[-1]==0.5 and not call('invalidLimit')
 for mode in ['MANUAL','ACRO','HOLD','RTL','SMART_RTL','STEERING']:
  c.setProperty('flightMode',mode);run('observe');assert len(speeds())==count+1
 c.setProperty('flightMode','AUTO');c.setProperty('gpsReady',False);run('observe');assert len(speeds())==count+1
 c.setProperty('gpsReady',True);run('observe');assert speeds()[-1]==0.5
 run('overrideLight');c.setProperty('headlightOn',True);run('observe');assert c.property('lightState')=='PILOT'
 assert call('retry');run('timeout');assert c.property('lightState')=='TIMEOUT'
 count=len(lights());run('observe');assert len(lights())==count # no command flooding
 c.setProperty('headlightOn',False);run('off');assert lights()[-1]=={'target':1,'value':1}
 assert all(not(x['target']==2 and x['value']==0) for x in lights())
 assert call('activate');count=len(lights());c.setProperty('linkReady',False)
 assert not c.property('active') and len(lights())==count
 c.setProperty('linkReady',True);assert not c.property('active') # no reconnect activation
 assert call('activate');c.setProperty('replayMode',True);assert not c.property('active')
 c.setProperty('replayMode',False);assert call('activate');run('swap');assert not c.property('active')
 for width in [236,320,480,900]:
  w.setWidth(width);QTest.qWait(40);assert panel.width()==width
  button=w.findChild(QObject,'stealthToggle');assert button and button.property('text')=='Activează Stealth'
  assert panel.property('implicitHeight')>0
 # The production baiting button shares the same profile as Settings; no second state.
 toggle=w.findChild(QObject,'baitingStealthToggle');assert toggle
 assert 'OFF' in toggle.property('text')
 c.setProperty('linkReady',False);QTest.qWait(20);assert not toggle.property('enabled')
 c.setProperty('linkReady',True);QTest.qWait(20)
 QMetaObject.invokeMethod(toggle,'clicked');QTest.qWait(20)
 assert c.property('active') and 'ON' in toggle.property('text')
 assert w.findChild(QObject,'stealthToggle').property('text')=='Dezactivează Stealth'
 QMetaObject.invokeMethod(w.findChild(QObject,'stealthToggle'),'clicked');QTest.qWait(20)
 assert not c.property('active') and 'OFF' in toggle.property('text')
 QMetaObject.invokeMethod(toggle,'clicked');c.setProperty('linkReady',False);QTest.qWait(20)
 assert not c.property('active') and 'OFF' in toggle.property('text')
 c.setProperty('linkReady',True)
 for width in [236,320,480]:
  w.setWidth(width);QTest.qWait(30)
  assert 0<toggle.property('width')<=width
 # Native Relay1/Relay2: no NV3 telemetry, no misleading confirmed state,
 # physical G20 buttons can override without software re-assertion.
 c.setProperty('relayMode',True)
 count=len(lights())
 assert call('activate') and c.property('lightState')=='RELAY_POS_PENDING'
 assert lights()[count:]==[{'target':2,'value':1}]
 assert not call('retry') # cannot send a second MAV_CMD 181 until first ACK.
 run('observe');assert len(lights())==count+1
 assert call('relayAckAccepted') and c.property('lightState')=='RELAY_HEAD_PENDING'
 assert lights()[count:]==[{'target':2,'value':1},{'target':1,'value':0}]
 assert call('relayAckAccepted') and c.property('lightState')=='RELAY_UNVERIFIED'
 assert not call('relayAckAccepted')
 run('off');assert len(lights())==count+2 # no restore: original state unknown
 # Refused first command must not extinguish far.
 count=len(lights());assert call('activate')
 assert lights()[count:]==[{'target':2,'value':1}]
 assert call('relayAckDenied') and c.property('lightState')=='FAILED'
 assert len(lights())==count+1
 # A duplicate failure from QGC must not trigger a second command.
 assert call('retry') and c.property('lightState')=='RELAY_POS_PENDING'
 assert call('relayAckDuplicate') and c.property('lightState')=='FAILED'
 assert len(lights())==count+2
 assert call('retry') and call('relayTimeout') and c.property('lightState')=='TIMEOUT'
 assert not call('relayAckAccepted') # never complete after timeout
 run('off')
 # Loss of link / deactivation cancels the pending far-off step.
 count=len(lights());assert call('activate')
 c.setProperty('linkReady',False)
 assert not c.property('active') and len(lights())==count+1
 assert not call('relayAckAccepted')
 c.setProperty('linkReady',True)
 c.setProperty('relayMode',False)
 # Audio policy: silence routine only, even with ordinary audio disabled.
 alertComponent=QQmlComponent(engine,QUrl.fromLocalFile(str(repo/'custom/qml/NavoAlerts.qml')));a=alertComponent.create();assert a,alertComponent.errors()
 q=QQmlComponent(engine);q.setData(b'''import QtQuick
QtObject {property var calls:[];property int stops:0;property bool busy:false
function stop(){stops++}
function play(sound,voice,text,critical){calls=calls.concat([{sound:sound,critical:critical}])}
}''',QUrl());audio=q.create();a.setProperty('output',audio)
 a.setProperty('stealthQuiet',True)
 def notify(key,critical):
  QMetaObject.invokeMethod(a,'notify',Q_ARG('QVariant',key),Q_ARG('QVariant',key),Q_ARG('QVariant',critical))
 notify('routine',False);QMetaObject.invokeMethod(a,'dispatch');assert not audio.property('calls').toVariant()
 notify('water',True);QMetaObject.invokeMethod(a,'dispatch');assert audio.property('calls').toVariant()==[{'sound':True,'critical':True}]
 stops=audio.property('stops');a.setProperty('stealthQuiet',False);a.setProperty('stealthQuiet',True);assert audio.property('stops')==stops
 a.setProperty('replayMode',True);notify('temperature',True);QMetaObject.invokeMethod(a,'dispatch');assert len(audio.property('calls').toVariant())==1
 assert not errors,errors
 print('PASS Stealth: light telemetry/timeout/override, bounded requests, speed/mode/GPS gates, session reset, 236–900px, routine mute and critical tone preserved')
