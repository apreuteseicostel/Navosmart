"""Production lake popup layout, SVG actions and scroll reachability; no hardware."""
import os
os.environ.setdefault('QT_QPA_PLATFORM','offscreen');os.environ.setdefault('QT_QUICK_BACKEND','software')
from pathlib import Path
import tempfile,subprocess
import PySide6
from PySide6.QtCore import QResource,QUrl,QObject,QMetaObject,QPointF,QCoreApplication,QEvent
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuick import QQuickItem,QQuickWindow
from PySide6.QtTest import QTest
repo=Path(__file__).resolve().parent.parent
app=QGuiApplication([]);engine=QQmlApplicationEngine();errors=[]
engine.warnings.connect(lambda ws:errors.extend(str(w) for w in ws))
wrapper='''import QtQuick
import QtQuick.Controls
import "'''+QUrl.fromLocalFile(str(repo/'custom/qml')).toString()+'''"
ApplicationWindow {
 id:root;visible:true;width:800;height:420;color:"#051521"
 property int deleted:0
 QtObject {
  id:db
  property var lakes:[{id:"lake",name:"Balta cu un nume mai lung"}]
  property var bathymetrySessions:[{lakeId:"lake",name:"Sesiune",sampleCount:50,minDepthM:1,maxDepthM:4}]
  function lakeState(id){return {sonarSamples:[1,2],fishingSpots:[1],completedLanes:[0,1],totalLanes:10}}
 }
 QtObject {
  id:coordinator
  function activateLake(id,name){return true}
  function restoreLake(id){return true}
  function renameLake(id,name){return true}
  function deleteLake(id){root.deleted++;return true}
 }
 NavoMyLakes {id:lakes;objectName:"lakesManager";parent:Overlay.overlay;persistence:db;scanCoordinator:coordinator}
 Component.onCompleted:{lakes.selectLake(db.lakes[0]);lakes.open()}
}'''
with tempfile.TemporaryDirectory() as directory:
 folder=Path(directory);qrc=folder/'icons.qrc';resource=folder/'icons.rcc'
 qrc.write_text('<RCC><qresource prefix="/qml/NavoSmart/icons">'+''.join(f'<file alias="{p.name}">{p}</file>' for p in (repo/'custom/icons').glob('*.svg'))+'</qresource></RCC>')
 subprocess.run([str(Path(PySide6.__file__).parent/'Qt/libexec/rcc'),'--binary',str(qrc),'-o',str(resource)],check=True);assert QResource.registerResource(str(resource))
 f=folder/'Test.qml';f.write_text(wrapper);engine.load(QUrl.fromLocalFile(str(f)));assert engine.rootObjects(),errors
 window=engine.rootObjects()[0];QTest.qWait(80);popup=window.findChild(QObject,'lakesManager');assert popup
 def visual(item,name):
  if item.objectName()==name:return item
  for child in item.childItems():
   found=visual(child,name)
   if found is not None:return found
 for width,height in [(480,420),(800,420),(1024,600)]:
  window.setWidth(width);window.setHeight(height);QTest.qWait(50)
  for name in ['lakeSelectedRename','lakeSelectedDelete','lakeListRename','lakeListDelete']:
   button=window.findChild(QObject,name) or visual(window.contentItem(),name);assert button,name
   assert button.property('width')>=42 and button.property('height')>=40
  scroll=window.findChild(QObject,'lakeDetailsScroll');assert scroll
  for tab in [0,1,2]:
   popup.setProperty('lakesTab',tab);QTest.qWait(50)
   flick=scroll.property('contentItem')
   flick.setProperty('contentY',max(0,scroll.property('contentHeight')-scroll.property('availableHeight')));QTest.qWait(30)
   if tab==2:
    help=window.findChild(QObject,'lakeActionsHelp');pos=help.mapToScene(QPointF(0,help.property('height')))
    top=scroll.mapToScene(QPointF(0,0)).y()
    assert top<=pos.y()<=top+scroll.property('availableHeight')+1,(width,height,pos.y(),top,scroll.property('availableHeight'))
   assert window.grabWindow().save(f'/tmp/navo-lakes-{width}-{height}-{tab}.png')
 # Opening rename or delete does not perform either operation immediately.
 QMetaObject.invokeMethod(window.findChild(QObject,'lakeSelectedRename'),'clicked');QTest.qWait(30)
 rename=window.findChild(QObject,'lakeRenameDialog');assert rename.property('visible')
 QMetaObject.invokeMethod(rename,'reject');QTest.qWait(20)
 QMetaObject.invokeMethod(window.findChild(QObject,'lakeSelectedDelete'),'clicked');QTest.qWait(30)
 delete=window.findChild(QObject,'lakeDeleteDialog');assert delete.property('visible') and window.property('deleted')==0
 QMetaObject.invokeMethod(delete,'close');QTest.qWait(20);assert window.property('deleted')==0
 window.close();window.deleteLater();QCoreApplication.sendPostedEvents(None,QEvent.DeferredDelete);app.processEvents()
 assert not errors,errors
 print('PASS lake manager at 480x420/800x420/1024x600: SVG actions, larger hit areas, three tabs, final help line reachable and confirmed delete preserved')
