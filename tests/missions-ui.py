"""Render the production Missions layout with Qt; replace only map/hardware surfaces.
Requires PySide6 6.8.3 Essentials+Addons. Does not validate MAVLink or hardware.
"""
import os
os.environ.setdefault('QT_QPA_PLATFORM', 'offscreen')
os.environ.setdefault('QT_QUICK_BACKEND', 'software')
from pathlib import Path
import tempfile, shutil, subprocess
import PySide6
from PySide6.QtCore import QUrl, QMetaObject, Q_RETURN_ARG, Q_ARG, QObject, QResource, QPointF, QPoint, Qt
from PySide6.QtGui import QGuiApplication, QInputDevice
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuick import QQuickWindow
from PySide6.QtTest import QTest
repo=Path(__file__).resolve().parent.parent
source=(repo/'custom/qml/NavoDashboard.qml').read_text()
start=source.index('    Component {\n        id: areaPage')
page=source[start:source.index('    Component {\n        id: fishingPage',start)]
map_start=page.index('                        NavoMap {')
map_end=page.index('                        }\n                    }\n                    ScrollView',map_start)+len('                        }')
page=page[:map_start]+'''Rectangle {id:areaScanMap;property bool canFitMission:true;function fitMission(){root.fits++;return true}objectName:"testMissionMap";anchors.fill:parent;color:"#133046";Label{anchors.centerIn:parent;text:"Hartă (substitut test)";color:"white"}}'''+page[map_end:]
strip_start=source.index('    NavoMissionStatus {')
strip=source[strip_start:source.index('    Rectangle {\n        id: content',strip_start)]
selection=source[source.index('    function missionStateLabel('):source.index('    NavoRoutePlan {',source.index('    function selectMission('))]
a=source.index('    Dialog {\n        id:clearAreaConfirm;')
clearDialog=source[a:source.index('    function saveSonarPoint(',a)]
wrapper='''import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtPositioning
ApplicationWindow {
 id:root;width:900;height:700;visible:true;color:"#0b1c2e"
 signal savedSpotPrepared()
 property int activePage:2
 property bool mapMaximized:false
 property bool missionScanSelected:true
 property bool compactUi:width<700
 property bool linkAlive:true
 property real routeLegDistanceM:100
 property real scanEstimateSpeedMps:1.5
 property string areaScanFinishAction:"HOLD"
 property string pendingAreaDrawMode:"none"
 property bool pendingBaitPointPick:false
 property bool directGotoActive:false
 property string flightMode:"HOLD"
 property string pendingMode:""
 property string pendingModeLabel:""
 property int cancels:0
 function cancelCurrentAction(){cancels++;directGotoActive=false;pendingMode="";flightMode="HOLD";holdMission()}
 property string lastNavigationStatus:""
 property string panel:"#0b1c2e"
 property string line:"#31506a"
 property string muted:"#d7e3ee"
 property string bg:"#0b1c2e"
 property int responsiveMargin:8
 property int responsiveGap:6
 property bool awaitingMissionStart:false
 property var vehicle:({homePosition:QtPositioning.coordinate(52,0),guidedModeRTL:function(){}})
 property alias routePlanController:routePlan
 property var routeEstimate:({valid:true,distanceM:420,durationSeconds:240})
 property string routeEnergyText:"Energie: consum de calibrat"
 property var scanEstimate:({valid:true,distanceM:520,durationSeconds:350})
 readonly property bool missionBusy:routePlan.active || scanCoordinator.state==="SCANNING" || awaitingMissionStart || missionUploader.uploadInProgress
    readonly property bool rtlActive: root.pendingModeLabel==="RTL" && root.pendingMode.length>0 ||
        ["RTL","SMARTRTL","SMART_RTL"].indexOf(String(root.flightMode).toUpperCase())>=0 ||
        (!!root.vehicle && !!root.vehicle.rtlFlightMode && String(root.flightMode).toUpperCase()===String(root.vehicle.rtlFlightMode).toUpperCase())
    readonly property bool actionActive: root.missionBusy || root.directGotoActive || root.rtlActive ||
        root.pendingMode.length>0 || ["AUTO","GUIDED"].indexOf(String(root.flightMode).toUpperCase())>=0
 property bool canClearArea:false
 property int clearCalls:0
 function clearAreaScan(){if(!canClearArea)return false;clearCalls++;return true}
 property int scanUploads:0
 property int scanStarts:0
 function setScanStage(stage){scanCoordinator.state="READY";missionUploader.preparedCount=stage===0 ? 0 : 10;missionUploader.uploadInProgress=stage===2;missionUploader.uploadVerified=stage===3}
 function startMission(){if(missionUploader.uploadVerified)scanStarts++;else scanUploads++}
 property int fits:0
 property int pauses:0
 property int homes:0
 function holdMission(){pauses++;routePlan.cancel("HOLD");scanCoordinator.state="PAUSED"}
 function stopMission(){holdMission()}
 function allowLiveAction(){return !sonar.replayMode}
 function startRoute(loaded){missionScanSelected=false;return routePlan.start(loaded)}
 QtObject{id:sonar;property bool replayMode:false}
 QtObject{id:scanCoordinator;property string state:"IDLE";property int missionCurrentIndex:0;function resume(){return []}}
 QtObject{id:missionUploader;property bool uploadInProgress:false;property bool uploadVerified:false;property int preparedCount:0}
 QtObject{id:areaScanController;property var generatedPoints:[];property var completedLanes:[];function laneCount(){return 0}function progressPercent(){return 0}}
 QtObject{id:fishingSpots;property var fishingSpots:[]}
 QtObject{id:baitingController;property var targetWaypoint:({name:"Destinație",coordinate:QtPositioning.coordinate(52,.001)});property bool silentMode:false;property real normalSpeedMps:1.5;property real silentSpeedMps:.8;property int state:1;function distanceToTarget(){return 50}function stateText(state){return "Navigare"}}
 NavoRoutePlan{id:routePlan}
 Item{id:header;height:0;anchors.top:parent.top}
 Item{id:sidebar;width:0;anchors.left:parent.left}
 Dialog{id:homeRtlConfirm;objectName:"testHomeDialog";title:"HOME";standardButtons:Dialog.Ok|Dialog.Cancel;onAccepted:root.homes++}
 Loader{anchors.left:parent.left;anchors.right:parent.right;anchors.top:missionStrip.bottom;anchors.bottom:parent.bottom;sourceComponent:areaPage}
 function exercise(){
  if(!selectMission(0) || !routePlan.setPoint(baitingController.targetWaypoint,"Destinație",0))return false
  if(!startRoute(false) || selectMission(1))return false
  return true
 }
 function seedEditor(){
  if(routePlan.missionKind==="point")return routePlan.setPoint(baitingController.targetWaypoint,"Lanseta verde",0)
  if(routePlan.stops.length)return true
  return routePlan.addStop(baitingController.targetWaypoint,"Lanseta verde",1) && routePlan.addStop(baitingController.targetWaypoint,"Lanseta roșie",2) && routePlan.addStop(baitingController.targetWaypoint,"Punct salvat",0)
 }
 function replaceBaitPoint(hopper){return routePlan.setPoint(baitingController.targetWaypoint,"Noua destinație",hopper)}
 function choose(index){return selectMission(index)}
}'''
wrapper=wrapper[:-1]+selection+strip+page+clearDialog+'}'
app=QGuiApplication([])
device=QTest.createTouchDevice(QInputDevice.DeviceType.TouchScreen)
engine=QQmlApplicationEngine();errors=[]
engine.warnings.connect(lambda ws:errors.extend(str(w) for w in ws))
with tempfile.TemporaryDirectory() as folder:
 folder=Path(folder)
 qrc=folder/'icons.qrc'
 qrc.write_text('<RCC><qresource prefix="/qml/NavoSmart/icons">'+''.join(f'<file alias="{p.name}">{p}</file>' for p in (repo/'custom/icons').glob('*.svg'))+'</qresource></RCC>')
 resource=folder/'icons.rcc'
 subprocess.run([str(Path(PySide6.__file__).parent/'Qt/libexec/rcc'),'--binary',str(qrc),'-o',str(resource)],check=True)
 assert QResource.registerResource(str(resource))
 for name in ['NavoRoutePanel.qml','NavoRoutePlan.qml','NavoMissionStatus.qml']:
  shutil.copy(repo/'custom/qml'/name,folder/name)
 (folder/'Test.qml').write_text(wrapper)
 engine.load(QUrl.fromLocalFile(str(folder/'Test.qml')))
 assert engine.rootObjects(),errors
 window=engine.rootObjects()[0]
 def call(name,*args):
  return QMetaObject.invokeMethod(window,name,Q_RETURN_ARG('QVariant'),*(Q_ARG('QVariant',a) for a in args))
 assert call('exercise')
 QTest.qWait(60)
 pause=window.findChild(QObject,'missionPause');home=window.findChild(QObject,'missionHome')
 assert pause.property('enabled') and home.property('enabled')
 window.setProperty('linkAlive',False);QTest.qWait(20)
 assert not pause.property('enabled') and not home.property('enabled')
 window.setProperty('linkAlive',True);QTest.qWait(20)
 QMetaObject.invokeMethod(home,'clicked');QTest.qWait(20)
 dialog=window.findChild(QObject,'testHomeDialog');assert dialog.property('visible')
 QMetaObject.invokeMethod(dialog,'accept');QTest.qWait(20);assert window.property('homes')==1
 QMetaObject.invokeMethod(pause,'clicked');QTest.qWait(30)
 assert window.property('pauses')==1 and not pause.property('enabled')
 window.setProperty('mapMaximized',False)
 for mode in [0,1,2]:
  assert call('choose',mode)
  if mode!=2:assert call('seedEditor')
  for width,height in [(236,600),(320,640),(480,720),(900,650)]:
   window.setWidth(width);window.setHeight(height);QTest.qWait(100)
   assert window.grabWindow().save(f'/tmp/navo-missions-{mode}-{width}.png')
   if mode!=2:
    details=window.findChild(QObject,'missionDetails')
    editor=window.findChild(QObject,'missionRouteEditor')
    QMetaObject.invokeMethod(details,'clicked');QTest.qWait(60)
    assert editor.property('visible') and editor.property('height')<=height-24
    hide=window.findChild(QObject,'missionHideDetails')
    assert hide.property('visible') and hide.property('y')+hide.property('height')<80
    scroll=window.findChild(QObject,'missionRouteScroll')
    assert scroll.property('contentHeight')>0
    if width==236:assert scroll.property('contentHeight')>scroll.property('availableHeight')
    flick=scroll.property('contentItem')
    flick.setProperty('contentY',max(0,scroll.property('contentHeight')-scroll.property('availableHeight')))
    QTest.qWait(30)
    assert window.grabWindow().save(f'/tmp/navo-missions-editor-bottom-{mode}-{width}.png')
    assert window.grabWindow().save(f'/tmp/navo-missions-editor-{mode}-{width}.png')
    chooseMap=window.findChild(QObject,'routeChooseOnMap')
    QMetaObject.invokeMethod(chooseMap,'clicked');QTest.qWait(30)
    assert not editor.property('visible') and window.property('pendingBaitPointPick')
    QMetaObject.invokeMethod(details,'clicked');QTest.qWait(20)
    QMetaObject.invokeMethod(hide,'clicked');QTest.qWait(20)
    assert not editor.property('visible')
   fit=window.findChild(QObject,'missionFitRoute');QMetaObject.invokeMethod(fit,'clicked');QTest.qWait(30)
   assert window.property('fits')>0
   status=window.findChild(QObject,'navoMissionStatus');assert status.property('height')<=68
   configure=window.findChild(QObject,'missionConfigure');assert configure.property('width')<=44
   mapItem=window.findChild(QObject,'testMissionMap');before=(mapItem.property('width'),mapItem.property('height'))
   expand=window.findChild(QObject,'missionExpand');assert expand
   QMetaObject.invokeMethod(expand,'clicked');QTest.qWait(100)
   assert window.property('mapMaximized')
   assert mapItem.property('width')>=before[0] and mapItem.property('height')>=before[1]
   assert mapItem.property('width')>=width-32
   assert window.grabWindow().save(f'/tmp/navo-missions-expanded-{mode}-{width}.png')
   QMetaObject.invokeMethod(expand,'clicked');QTest.qWait(40)
   assert not window.property('mapMaximized')
 assert call('choose',0) and call('replaceBaitPoint',1)
 load=window.findChild(QObject,'routeLoadCheck');assert load
 load.setProperty('checked',True)
 assert call('replaceBaitPoint',2);QTest.qWait(20)
 assert not load.property('checked')
 assert call('exercise')
 QTest.qWait(50)
 assert window.property('mapMaximized') and pause.property('enabled') and home.property('enabled')
 details=window.findChild(QObject,'missionDetails');editor=window.findChild(QObject,'missionRouteEditor')
 QMetaObject.invokeMethod(details,'clicked');QTest.qWait(30)
 assert editor.property('visible') and not window.findChild(QObject,'routeChooseOnMap').property('enabled')
 QMetaObject.invokeMethod(window.findChild(QObject,'missionHideDetails'),'clicked');QTest.qWait(20)
 assert not editor.property('visible') and window.property('mapMaximized')
 QMetaObject.invokeMethod(home,'clicked');QTest.qWait(20);assert dialog.property('visible')
 QMetaObject.invokeMethod(dialog,'reject')
 QMetaObject.invokeMethod(pause,'clicked');QTest.qWait(20)
 assert window.property('pauses')==2 and not pause.property('enabled')
 # Cancellation must remain available during RTL and after link loss.
 window.setProperty('flightMode','RTL');QTest.qWait(30)
 cancel=window.findChild(QObject,'missionCancel')
 assert cancel.property('enabled') and cancel.property('text')=='ANULEAZĂ RTL'
 window.setProperty('linkAlive',False);QTest.qWait(20)
 assert cancel.property('enabled') and not pause.property('enabled')
 QMetaObject.invokeMethod(cancel,'clicked');QTest.qWait(20)
 assert window.property('cancels')==1 and window.property('flightMode')=='HOLD'
 # Actual compact scan tools and confirmation: hover/touch help, reject, guard, accept.
 window.setProperty('linkAlive',True);window.setProperty('canClearArea',True)
 window.setProperty('mapMaximized',False);assert call('choose',2)
 def setStage(stage):
  QMetaObject.invokeMethod(window,'setScanStage',Q_ARG('QVariant',stage))
 # Upload and START must have persistent labels; upload confirmation never issues START by itself.
 primary=window.findChild(QObject,'scanUploadStart');prepare=window.findChild(QObject,'scanPrepare')
 assert primary and prepare and prepare.property('text')=='PREGĂTEȘTE'
 setStage(0);QTest.qWait(30)
 assert not primary.property('enabled') and primary.property('text')=='ÎNCARCĂ MISIUNEA'
 setStage(1);QTest.qWait(30)
 assert primary.property('enabled')
 def pressPrimary():
  pos=primary.mapToScene(QPointF(primary.property('width')/2,primary.property('height')/2))
  QTest.mouseClick(window,Qt.LeftButton,Qt.NoModifier,QPoint(round(pos.x()),round(pos.y())));QTest.qWait(20)
 pressPrimary();assert window.property('scanUploads')==1 and window.property('scanStarts')==0
 setStage(2);QTest.qWait(30)
 assert not primary.property('enabled') and primary.property('text')=='SE ÎNCARCĂ…'
 setStage(3);QTest.qWait(30)
 assert primary.property('enabled') and primary.property('text')=='START AUTOPILOT' and window.property('scanStarts')==0
 pressPrimary();assert window.property('scanStarts')==1
 setStage(0)
 for width,height in [(480,420),(800,600)]:
  window.setWidth(width);window.setHeight(height);QTest.qWait(60)
  for control in [primary,prepare]:
   pos=control.mapToScene(QPointF(0,0))
   assert pos.y()>=0 and pos.y()+control.property('height')<=height
   assert pos.x()>=0 and pos.x()+control.property('width')<=width
  clear=window.findChild(QObject,'scanClearArea');cancel=window.findChild(QObject,'scanCancel')
  assert clear.property('width')==52 and clear.property('height')==46
  assert cancel.property('width')==52 and cancel.property('height')==46
  tooltip=clear.findChild(QObject,'scanToolTip');assert tooltip
  position=clear.mapToScene(QPointF(clear.property('width')/2,clear.property('height')/2))
  point=QPoint(round(position.x()),round(position.y()))
  assert 0<=point.x()<width and 0<=point.y()<height
  QTest.mouseMove(window,point);QTest.qWait(500)
  assert tooltip.property('visible')
  QTest.mouseMove(window,QPoint(10,10));QTest.qWait(50);assert not tooltip.property('visible')
  QTest.touchEvent(window,device).press(0,point,window).commit();QTest.qWait(40)
  assert tooltip.property('visible')
  QTest.touchEvent(window,device).release(0,point,window).commit();QTest.qWait(60)
  dialog=window.findChild(QObject,'scanClearConfirm');assert dialog.property('visible')
  assert dialog.property('width')<=360 and dialog.property('height')<=226
  assert window.grabWindow().save(f'/tmp/navo-scan-clear-{width}.png')
  before=window.property('clearCalls')
  QMetaObject.invokeMethod(window.findChild(QObject,'scanClearCancel'),'clicked');QTest.qWait(20)
  assert not dialog.property('visible') and window.property('clearCalls')==before
  QTest.mouseMove(window,QPoint(10,10));QTest.qWait(4100);assert not tooltip.property('visible')
  QMetaObject.invokeMethod(clear,'clicked');QTest.qWait(20)
  accept=window.findChild(QObject,'scanClearAccept');window.setProperty('canClearArea',False);QTest.qWait(20)
  assert not accept.property('enabled')
  window.setProperty('canClearArea',True);QTest.qWait(20)
  QMetaObject.invokeMethod(accept,'clicked');QTest.qWait(20)
  assert window.property('clearCalls')==before+1 and not dialog.property('visible')
  assert window.grabWindow().save(f'/tmp/navo-scan-tools-{width}.png')
 assert not errors,errors
 print('PASS Missions at 236/320/480/900: scrollable stop editor, map picking, hide/reopen while active, auto-expanded START, PAUZĂ/HOME and link-loss controls')

