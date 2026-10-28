"""Load the actual Dashboard editor with real FishingSpots and a disk-write double."""
import os
os.environ.setdefault('QT_QPA_PLATFORM', 'offscreen')
os.environ.setdefault('QT_QUICK_BACKEND', 'software')
from pathlib import Path
import shutil, tempfile
from PySide6.QtCore import QUrl, QObject, QMetaObject, Q_RETURN_ARG, QPointF
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtTest import QTest
from PySide6.QtQuick import QQuickItem, QQuickWindow

repo = Path(__file__).resolve().parent.parent
source = (repo/'custom/qml/NavoDashboard.qml').read_text()
start = source.index('            property string spotEditLakeId:')
editor = source[start:source.index('\n        }\n    }\n\n    Component {\n        id: waypointEditorPage', start)]
wrapper = '''import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
ApplicationWindow {
 id:root;visible:true;width:900;height:650
 property bool missionBusy:false
 property bool actionActive:false
 property bool steeringModeBusy:false
 property color panel:"#0b1c2e"
 property color text:"#eff9ff"
 property color bg:"#061827"
 property color line:"#1c4262"
 property color cyan:"#21b7ff"
 property color muted:"#c1d7e6"
 property color warn:"#ffd166"
 property string lastNavigationStatus:""
 property bool failSave:false
 QtObject { id:sonar;property bool replayMode:false }
 QtObject { id:scanCoordinator;property string lakeId:"lake";function checkpoint(reason){return !root.failSave} }
 NavoFishingSpots { id:fishingSpots }
 function launch(){
  fishingSpots.fishingSpots=[{id:"s",name:"Lanseta",lat:52,lon:-1,depth:null,temp:null,note:"Prag",color:"#31d67b",createdAt:123,sonarEvidence:{samples:9}}]
  fishingPageRoot.openEdit(fishingSpots.fishingSpots[0]);return true
 }
 function saved(){return fishingSpots.fishingSpots[0]}
 Item {
  id:fishingPageRoot
  property string spotEditId:""
  property string spotEditColor:"#31d67b"
'''+editor+'\n }\n}'
app = QGuiApplication([])
engine = QQmlApplicationEngine(); errors = []
engine.warnings.connect(lambda ws: errors.extend(str(w) for w in ws))
with tempfile.TemporaryDirectory() as directory:
 folder = Path(directory)
 shutil.copy(repo/'custom/qml/NavoFishingSpots.qml', folder)
 (folder/'Test.qml').write_text(wrapper)
 engine.load(QUrl.fromLocalFile(str(folder/'Test.qml')))
 assert engine.rootObjects(), errors
 window = engine.rootObjects()[0]
 def call(name):
  value = QMetaObject.invokeMethod(window, name, Q_RETURN_ARG('QVariant'))
  return value.toVariant() if hasattr(value, 'toVariant') else value
 for width,height in [(236,320),(320,600),(900,650)]:
  window.setWidth(width);window.setHeight(height);assert call('launch');QTest.qWait(60)
  dialog = window.findChild(QObject,'savedSpotEditor');assert dialog.property('visible')
  save = window.findChild(QObject,'spotEditSave');origin = save.mapToScene(QPointF(0,0))
  assert 0<=origin.x() and origin.x()+save.property('width')<=width
  assert 0<=origin.y() and origin.y()+save.property('height')<=height
  for name,value in [('spotEditName','Nou'),('spotEditLatitude','53,25'),('spotEditLongitude','-2.5'),('spotEditDepth','4.2'),('spotEditTemperature','0'),('spotEditNote','Mâl')]:
   window.findChild(QObject,name).setProperty('text',value)
  window.setProperty('failSave',True)
  QMetaObject.invokeMethod(save,'clicked');QTest.qWait(20)
  assert dialog.property('visible') and call('saved')['name']=='Lanseta'
  window.setProperty('failSave',False)
  assert window.grabWindow().save(f'/tmp/navo-spot-editor-{width}.png')
  QMetaObject.invokeMethod(save,'clicked');QTest.qWait(20)
  result = call('saved')
  assert not dialog.property('visible') and result['name']=='Nou' and result['lat']==53.25
  assert result['depth']==4.2 and result['temp']==0 and result['note']=='Mâl'
  assert result['createdAt']==123 and result['sonarEvidence']['samples']==9
 assert not errors, errors
 print('PASS actual saved-point editor at 236/320/900: fields, visible footer, disk failure/retry, preserved sonar evidence')
