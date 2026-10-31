"""Production connectivity panel; all network effects are explicit doubles."""
import os
os.environ.setdefault('QT_QPA_PLATFORM','offscreen')
os.environ.setdefault('QT_QUICK_BACKEND','software')
from pathlib import Path
import tempfile
from PySide6.QtCore import QUrl,QObject,QMetaObject,Q_ARG,Qt,QPoint,QPointF
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuick import QQuickItem
from PySide6.QtTest import QTest
repo=Path(__file__).resolve().parents[1]
app=QGuiApplication([])
scene='''import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "'''+QUrl.fromLocalFile(str(repo/'custom/qml')).toString()+'''"
ApplicationWindow {
 id:root;width:480;height:640;visible:true;color:"#051521"
 property int stopCalls:0;property int allCalls:0;property int refreshCalls:0;property int connectCalls:0;property int verifyCalls:0;property int tcpCalls:0;property string selectedKey:""
 function sdkChannel(){backend.connections=[{key:"skydroid:g20",name:"G20 / GR01 RCSDK",endpoint:"RCSDK 1.9.2",state:"CANAL GR01 DESCHIS • fără HEARTBEAT recent",detail:"Telecomandă: DA • canal GR01: DA",live:false,canConnect:false,bytes:250}];backend.connectionsChanged()}
 function liveHeartbeat(){backend.connections=[{key:"tcp:127.0.0.1:5760",name:"GR01 test",endpoint:"tcp:127.0.0.1:5760",state:"MAVLINK LIVE",live:true,canConnect:false,bytes:250}];backend.connectionsChanged()}
 function noHeartbeat(){backend.connections=[{key:"tcp:127.0.0.1:5760",name:"GR01 test",endpoint:"tcp:127.0.0.1:5760",state:"TRANSPORT DESCHIS • fără HEARTBEAT recent",live:false,canConnect:false,bytes:120}];backend.connectionsChanged()}
 QtObject {
  id:backend;property bool autoConnect:true;property bool busy:false;property string status:"Test";property int serialBaud:115200
  property var connections:[{key:"serial:/dev/usb/1",name:"USB test",endpoint:"serial:/dev/usb/1",state:"DECONECTAT",detail:"",live:false,canConnect:true,bytes:0}]
  function disconnectOne(key){root.stopCalls++;root.selectedKey=key}
  function connectAll(){root.allCalls++}
  function refresh(){root.refreshCalls++}
  function connectOne(key){root.connectCalls++;root.selectedKey=key}
  function verifyOne(key){root.verifyCalls++;root.selectedKey=key}
  function addTcp(host,port){root.tcpCalls++;return true}
  function setSerialBaud(baud){serialBaud=baud}
 }
 QtObject {id:sonar;property bool replayMode:true;property bool connected:true;property bool dataAlive:false;property string status:"REPLAY";property string host:"";property int port:0;property bool udp:false;function connectSonar(){throw Error("Replay must not connect")}}
 QtObject {id:camera;property bool connected:false;property int port:0;property string host:"";property bool udp:false;function connectCamera(){throw Error("Missing endpoint must not connect")}}
 ScrollView {id:scroll;objectName:"scroll";anchors.fill:parent;contentWidth:availableWidth
  NavoConnectivityPanel {id:panel;objectName:"panel";width:scroll.availableWidth;controller:backend;sonar:sonar;camera:camera}
 }
}'''
with tempfile.TemporaryDirectory() as folder:
 p=Path(folder)/'Test.qml';p.write_text(scene)
 engine=QQmlApplicationEngine();errors=[];engine.warnings.connect(lambda ws:errors.extend(str(w) for w in ws));engine.load(QUrl.fromLocalFile(str(p)))
 assert engine.rootObjects(),errors
 w=engine.rootObjects()[0];QTest.qWait(60)
 def find(name):
  def scan(item):
   if item.objectName()==name:return item
   for child in item.childItems():
    found=scan(child)
    if found:return found
  return w.findChild(QObject,name) or scan(w.contentItem())
 def click(name):
  button=find(name);assert button
  QMetaObject.invokeMethod(button,'clicked');QTest.qWait(20)
 click('connectivityAll');assert w.property('allCalls')==1
 click('connectivityRefresh');assert w.property('refreshCalls')==1
 click('connectivityConnect');assert w.property('connectCalls')==1 and w.property('selectedKey')=='serial:/dev/usb/1'
 click('connectivityVerify');assert w.property('verifyCalls')==1
 assert not w.findChild(QObject,'connectivitySonarConnect').property('enabled')
 assert not w.findChild(QObject,'connectivityCameraConnect').property('enabled')
 port=w.findChild(QObject,'connectivityTcpPort');host=w.findChild(QObject,'connectivityTcpHost');add=w.findChild(QObject,'connectivityAddTcp')
 host.setProperty('text','127.0.0.1');port.setProperty('text','70000');QTest.qWait(20);assert not add.property('enabled')
 port.setProperty('text','5760');QTest.qWait(20);assert add.property('enabled');click('connectivityAddTcp');assert w.property('tcpCalls')==1
 QMetaObject.invokeMethod(w,'noHeartbeat');QTest.qWait(20)
 def walk(item):
  for child in item.childItems():
   yield child;yield from walk(child)
 assert any('fără HEARTBEAT' in str(i.property('text') or '') for i in walk(w.contentItem()))
 assert not find('connectivityConnect').property('enabled')
 QMetaObject.invokeMethod(w,'liveHeartbeat');QTest.qWait(20)
 assert any(i.property('text')=='MAVLINK LIVE' for i in walk(w.contentItem()))
 QMetaObject.invokeMethod(w,'sdkChannel');QTest.qWait(20)
 assert any('canal GR01: DA' in str(i.property('text') or '') for i in walk(w.contentItem()))
 assert find('connectivitySkydroidStop').property('visible')
 click('connectivitySkydroidStop');assert w.property('stopCalls')==1 and w.property('selectedKey')=='skydroid:g20'
 assert not find('connectivityConnect').property('enabled')
 panel=w.findChild(QObject,'panel')
 for width in [320,480,800]:
  w.setWidth(width);QTest.qWait(40)
  for name in ['connectivityAll','connectivityRefresh','connectivityTcpHost','connectivityTcpPort']:
   button=w.findChild(QObject,name);pos=button.mapToScene(QPointF(0,0));assert pos.x()>=0 and pos.x()+button.property('width')<=width
  assert w.grabWindow().save(f'/tmp/navo-connectivity-{width}.png')
 assert not errors,errors
 print('PASS connectivity panel: per-link actions, TCP validation, replay/no-endpoint guards, transport vs heartbeat, 320/480/800 layout')
