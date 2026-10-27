"""Production STEERING controller/panel with a simulated vehicle, never HIL."""
import os
os.environ.setdefault('QT_QPA_PLATFORM','offscreen')
os.environ.setdefault('QT_QUICK_BACKEND','software')
from pathlib import Path
import tempfile
from PySide6.QtCore import QUrl,QObject,QMetaObject,Q_RETURN_ARG,Q_ARG
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuick import QQuickWindow
from PySide6.QtTest import QTest
repo=Path(__file__).resolve().parent.parent
app=QGuiApplication([]);engine=QQmlApplicationEngine();errors=[]
engine.warnings.connect(lambda ws:errors.extend(str(w) for w in ws))
qml='''import QtQuick
import QtQuick.Controls
import QtPositioning
import "'''+(repo/'custom/qml').as_uri()+'''" as Navo
ApplicationWindow {
 id:root;width:480;height:720;visible:true;color:"#0b1c2e"
 QtObject {
  id:vehicle
  property bool rover:true
  property var flightModes:["Manual","Steering","Hold"]
  property string flightMode:"Manual"
  property var coordinate:QtPositioning.coordinate(52,0)
  property QtObject heading:QtObject{property real rawValue:359}
  property QtObject gps:QtObject{property QtObject lock:QtObject{property int rawValue:3}}
  property QtObject vehicleLinkManager:QtObject{property bool communicationLost:false}
  function pauseVehicle(){flightMode="Hold"}
 }
 Navo.NavoSteeringAssist{id:assist;vehicle:vehicle;preLaunchReady:true}
 Navo.NavoSteeringPanel {anchors.left:parent.left;anchors.right:parent.right;anchors.top:parent.top;controller:assist;onEnableRequested:assist.enable()}
 function mode(){return assist.state}
 function manual(){vehicle.flightMode="Manual";assist.observe();return assist.state}
 function disconnect(){vehicle.vehicleLinkManager.communicationLost=true;return assist.canEnable}
}'''
with tempfile.TemporaryDirectory() as folder:
 path=Path(folder)/'Test.qml';path.write_text(qml);engine.load(QUrl.fromLocalFile(str(path)))
 assert engine.rootObjects(),errors
 window=engine.rootObjects()[0]
 enable=window.findChild(QObject,'steeringEnable');stop=window.findChild(QObject,'steeringStop');dialog=window.findChild(QObject,'steeringConfirmation')
 assert enable and stop and dialog and enable.property('enabled') and not stop.property('enabled')
 def call(name):return QMetaObject.invokeMethod(window,name,Q_RETURN_ARG('QVariant'))
 for width,height in [(236,600),(320,600),(480,720),(900,600)]:
  window.setWidth(width);window.setHeight(height);QTest.qWait(60)
  assert window.grabWindow().save(f'/tmp/navo-steering-{width}.png')
  QMetaObject.invokeMethod(enable,'clicked');QTest.qWait(30)
  assert dialog.property('visible') and dialog.property('width')<=width
  assert window.grabWindow().save(f'/tmp/navo-steering-confirm-{width}.png')
  QMetaObject.invokeMethod(dialog,'reject')
 QMetaObject.invokeMethod(enable,'clicked');QMetaObject.invokeMethod(dialog,'accept');QTest.qWait(300)
 assert call('mode')=='ACTIVE' and stop.property('enabled') and not enable.property('enabled')
 QMetaObject.invokeMethod(stop,'clicked');QTest.qWait(300);assert call('mode')=='IDLE'
 assert call('manual')=='IDLE';assert not call('disconnect');QTest.qWait(30);assert not enable.property('enabled')
 assert not errors,errors
 print('PASS real Qt STEERING panel/confirmation at 236/320/480/900; reported activation, HOLD and disconnect gating')
