"""Real QtLocation mission framing with production functions and offline items overlay.
No QGC/vehicle commands or tile downloads; verifies projection and viewport bounds.
"""
import os
os.environ.setdefault('QT_QPA_PLATFORM','offscreen')
os.environ.setdefault('QT_QUICK_BACKEND','software')
from pathlib import Path
import tempfile
from PySide6.QtCore import QUrl,QMetaObject,Q_RETURN_ARG,Q_ARG,QObject
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtTest import QTest
repo=Path(__file__).resolve().parent.parent
source=(repo/'custom/qml/NavoMap.qml').read_text()
functions=source[source.index('    // Frame only this mission'):source.index('    function resetView()')]
wrapper='''import QtQuick
import QtQuick.Controls
import QtLocation
import QtPositioning
ApplicationWindow {
 id:root;visible:true;width:900;height:550
 property bool recordedReplay:false
 property bool routeActive:false
 property var routeStops:[]
 property bool routeReturnsHome:true
 property bool initialCenterApplied:false
 property bool autoFollowBoat:true
 property bool headingUp:false
 property var vehicle:({coordinate:QtPositioning.coordinate(52,0),homePosition:QtPositioning.coordinate(51.999,-.002)})
 property var areaScanController:({generatedPoints:[]})
 QtObject{id:layerSettings;property bool plannedVisible:false}
 Map {id:liveMap;objectName:"projectionMap";anchors.fill:parent;plugin:Plugin{name:"itemsoverlay"}
  onMapReadyChanged:if(mapReady && root.pendingMissionFit)Qt.callLater(root.fitMission)
 }
 function seed(mode){
  recordedReplay=false;routeReturnsHome=true;autoFollowBoat=true;layerSettings.plannedVisible=false
  areaScanController={generatedPoints:[]}
  vehicle={coordinate:QtPositioning.coordinate(52,0),homePosition:QtPositioning.coordinate(51.999,-.002)}
  if(mode===0)routeStops=[{latitude:52.001,longitude:.001},{latitude:52.002,longitude:.003},{latitude:52,longitude:.004}]
  if(mode===1){routeStops=[];areaScanController={generatedPoints:[QtPositioning.coordinate(52.002,.001),QtPositioning.coordinate(52.002,.005),QtPositioning.coordinate(52,.001),QtPositioning.coordinate(52,.005)]}}
  if(mode===2){routeStops=[{latitude:52,longitude:0}];vehicle=null}
  if(mode===3){routeStops=[{latitude:10,longitude:179.99},{latitude:10.002,longitude:-179.99}];vehicle=null}
  if(mode===4){routeStops=[{latitude:NaN,longitude:0},{latitude:91,longitude:0},{latitude:52,longitude:181}];vehicle=null}
  return true
 }
 function verify(){
  var points=missionCoordinates()
  if(!points.length || autoFollowBoat || headingUp || !layerSettings.plannedVisible)return false
  for(var i=0;i<points.length;i++){
   var p=liveMap.fromCoordinate(points[i],false)
   if(!isFinite(p.x) || !isFinite(p.y) || p.x<20 || p.x>liveMap.width-20 || p.y<20 || p.y>liveMap.height-20)return false
  }
  return true
 }
}'''
wrapper=wrapper[:-1]+functions+'}'
app=QGuiApplication([]);engine=QQmlApplicationEngine();errors=[]
engine.warnings.connect(lambda ws:errors.extend(str(w) for w in ws))
with tempfile.TemporaryDirectory() as folder:
 path=Path(folder)/'Test.qml';path.write_text(wrapper);engine.load(QUrl.fromLocalFile(str(path)))
 assert engine.rootObjects(),errors
 window=engine.rootObjects()[0]
 def call(name,*args):return QMetaObject.invokeMethod(window,name,Q_RETURN_ARG('QVariant'),*(Q_ARG('QVariant',a) for a in args))
 QTest.qWait(150)
 for width,height in [(236,420),(320,550),(900,500),(500,900)]:
  window.setWidth(width);window.setHeight(height);QTest.qWait(50)
  for mode in range(4):
   call('seed',mode);assert call('fitMission'),(width,mode,errors)
   QTest.qWait(30);assert call('verify'),(width,mode)
  call('seed',4);assert not window.property('canFitMission') and not call('fitMission')
 call('seed',0);window.setProperty('recordedReplay',True)
 assert not window.property('canFitMission') and not call('fitMission')
 window.setProperty('recordedReplay',False);window.setProperty('routeActive',True);QTest.qWait(50)
 assert call('verify')
 assert not errors,errors
 print('PASS real QtLocation framing: route/scan/boat/HOME, single point, dateline, invalid GPS, replay isolation and active route; portrait and landscape')
