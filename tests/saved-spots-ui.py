"""Tap/hold through the production map input layer; real offline QtLocation markers."""
import os
os.environ.setdefault('QT_QPA_PLATFORM','offscreen')
os.environ.setdefault('QT_QUICK_BACKEND','software')
from pathlib import Path
import tempfile,shutil
from PySide6.QtCore import QUrl,QObject,QMetaObject,QPointF,QPoint,Qt
from PySide6.QtGui import QGuiApplication,QInputDevice
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtTest import QTest
from PySide6.QtQuick import QQuickWindow,QQuickItem
repo=Path(__file__).resolve().parent.parent
source=(repo/'custom/qml/NavoMap.qml').read_text()
start=source.index('    MouseArea {\n        anchors.fill: parent\n        enabled: !root.recordedReplay && root.areaDrawMode === "none"')
inputLayer=source[start:source.index('    MouseArea {',start+20)]
wrapper='''import QtQuick
import QtQuick.Controls
import QtLocation
import QtPositioning
ApplicationWindow {
 id:root;visible:true;width:900;height:650
 property bool recordedReplay:false
 property string areaDrawMode:"none"
 property bool baitPointPickMode:false
 property bool rulerMode:false
 property var pendingFishingCoordinate:null
 property string pendingFishingColor:""
 property int actions:0
 property string lastAction:""
 property int lastHopper:0
 property real lastSize:0
 QtObject{id:spots;property var fishingSpots:[{id:"green",name:"Lanseta verde",lat:52,lon:0,depth:2.4,temp:18,note:"Prag observat",createdAt:1000}]}
 TextField{id:fishingName;visible:false}
 Dialog{id:fishingSaveDialog;objectName:"newSpotDialog";title:"Punct nou"}
 Map{id:liveMap;anchors.fill:parent;plugin:Plugin{name:"itemsoverlay"}center:QtPositioning.coordinate(52,0);zoomLevel:17
 // QGC FlightMap also has a touch area under the NAVO map input layer.
 MultiPointTouchArea { anchors.fill:parent;maximumTouchPoints:1;mouseEnabled:true
  onGestureStarted:function(gesture){gesture.grab()}
 }
}
 NavoBathymetryOverlay {
  id:savedPointsOverlay;objectName:"savedPointsOverlay";map:liveMap;fishingSpotsModel:spots
  onSpotActionRequested:function(spot,action,hopper,size){root.actions++;root.lastAction=action;root.lastHopper=hopper;root.lastSize=size}
 }
 function clearSpots(){spots.fishingSpots=[]}
}'''
wrapper=wrapper[:-1]+inputLayer+'}'
app=QGuiApplication([]);device=QTest.createTouchDevice(QInputDevice.DeviceType.TouchScreen);engine=QQmlApplicationEngine();errors=[]
engine.warnings.connect(lambda ws:errors.extend(str(w) for w in ws))
with tempfile.TemporaryDirectory() as folder:
 folder=Path(folder);shutil.copy(repo/'custom/qml/NavoBathymetryOverlay.qml',folder)
 (folder/'Test.qml').write_text(wrapper);engine.load(QUrl.fromLocalFile(str(folder/'Test.qml')))
 assert engine.rootObjects(),errors
 window=engine.rootObjects()[0];QTest.qWait(150)
 overlay=window.findChild(QObject,'savedPointsOverlay');dialog=window.findChild(QObject,'savedSpotDetails')
 for width,height in [(236,600),(320,640),(900,650)]:
  window.setWidth(width);window.setHeight(height);QTest.qWait(80)
  def findVisual(item,name):
   if item.objectName()==name:return item
   for child in item.childItems():
    found=findVisual(child,name)
    if found is not None:return found
  pin=findVisual(window.contentItem(),'savedSpotPin');assert pin
  pos=pin.mapToScene(QPointF(pin.width()/2,pin.height()/2));point=QPoint(round(pos.x()),round(pos.y()))
  # A tap on either the coloured dot or its label opens the existing point.
  for localX in [9,pin.width()*.7]:
   tap=pin.mapToScene(QPointF(localX,pin.height()/2));tapPoint=QPoint(round(tap.x()),round(tap.y()))
   QTest.touchEvent(window,device).press(0,tapPoint,window).commit();QTest.qWait(40)
   QTest.touchEvent(window,device).release(0,tapPoint,window).commit();QTest.qWait(40)
   assert dialog.property('visible'),errors
   QMetaObject.invokeMethod(dialog,'close');QTest.qWait(20)
  emptyPoint=QPoint(30,height-40)
  QTest.touchEvent(window,device).press(0,emptyPoint,window).commit();QTest.qWait(40)
  QTest.touchEvent(window,device).release(0,emptyPoint,window).commit();QTest.qWait(40)
  assert not dialog.property('visible')
  assert not window.findChild(QObject,'newSpotDialog').property('visible')
  QTest.touchEvent(window,device).press(0,point,window).commit();QTest.qWait(1200);QTest.touchEvent(window,device).release(0,point,window).commit();QTest.qWait(40)
  assert dialog.property('visible'),errors
  assert not window.findChild(QObject,'newSpotDialog').property('visible')
  assert dialog.property('width')<=min(320,width-20) and dialog.property('height')<=height*.48
  assert not dialog.property('modal') and not dialog.property('dim')
  assert not dialog.property('expanded')
  QMetaObject.invokeMethod(window.findChild(QObject,'savedSpotMore'),'clicked');QTest.qWait(30)
  assert dialog.property('expanded')
  QMetaObject.invokeMethod(window.findChild(QObject,'savedSpotMore'),'clicked');QTest.qWait(30)
  assert not dialog.property('expanded')
  assert window.grabWindow().save(f'/tmp/navo-saved-spot-{width}.png')
  outside=QPoint(25,25)
  QTest.touchEvent(window,device).press(0,outside,window).commit();QTest.qWait(40)
  QTest.touchEvent(window,device).release(0,outside,window).commit();QTest.qWait(40)
  assert not dialog.property('visible')
  QMetaObject.invokeMethod(dialog,'open');QTest.qWait(30)
  QMetaObject.invokeMethod(window.findChild(QObject,'savedSpotClose'),'clicked');QTest.qWait(30)
  assert not dialog.property('visible')
  for name,action in [('savedSpotNavigate','navigate'),('savedSpotBait','bait'),('savedSpotScan','scan')]:
   if not dialog.property('visible'):QMetaObject.invokeMethod(dialog,'open');QTest.qWait(30)
   button=window.findChild(QObject,name);assert button.property('enabled')
   QMetaObject.invokeMethod(button,'clicked');QTest.qWait(30)
   assert window.property('lastAction')==action and not dialog.property('visible')
  assert window.property('lastHopper')==0 and window.property('lastSize')==20
 QMetaObject.invokeMethod(dialog,'open');overlay.setProperty('actionsAllowed',False);QTest.qWait(30)
 for name in ['savedSpotNavigate','savedSpotBait','savedSpotScan']:assert not window.findChild(QObject,name).property('enabled')
 QMetaObject.invokeMethod(window,'clearSpots');QTest.qWait(30);assert not dialog.property('visible')
 assert not errors,errors
 print('PASS saved spot dot/label tap and long press through production map layer, responsive details/actions, operation gates and removed/lake-switched spot closure')
