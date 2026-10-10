"""Render the production Missions layout with Qt; replace only map/hardware surfaces.
Requires PySide6 6.8.3 Essentials+Addons. Does not validate MAVLink or hardware.
"""
import os
os.environ.setdefault('QT_QPA_PLATFORM', 'offscreen')
os.environ.setdefault('QT_QUICK_BACKEND', 'software')
from pathlib import Path
import tempfile, shutil
from PySide6.QtCore import QUrl, QMetaObject, Q_RETURN_ARG, Q_ARG, QObject
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuick import QQuickWindow
from PySide6.QtTest import QTest
repo=Path(__file__).resolve().parent.parent
source=(repo/'custom/qml/NavoDashboard.qml').read_text()
start=source.index('    Component {\n        id: areaPage')
page=source[start:source.index('    Component {\n        id: fishingPage',start)]
map_start=page.index('                        NavoMap {')
map_end=page.index('                        }\n                    }\n                    ScrollView',map_start)+len('                        }')
page=page[:map_start]+'''Rectangle {anchors.fill:parent;color:"#133046";Label{anchors.centerIn:parent;text:"Hartă (substitut test)";color:"white"}}'''+page[map_end:]
strip_start=source.index('    NavoMissionStatus {')
strip=source[strip_start:source.index('    Rectangle {\n        id: content',strip_start)]
selection=source[source.index('    function missionStateLabel('):source.index('    NavoRoutePlan {',source.index('    function selectMission('))]
wrapper='''import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtPositioning
ApplicationWindow {
 id:root;width:900;height:700;visible:true;color:"#0b1c2e"
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
 function choose(index){return selectMission(index)}
}'''
wrapper=wrapper[:-1]+selection+strip+page+'}'
app=QGuiApplication([])
engine=QQmlApplicationEngine();errors=[]
engine.warnings.connect(lambda ws:errors.extend(str(w) for w in ws))
with tempfile.TemporaryDirectory() as folder:
 folder=Path(folder)
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
 for mode in [0,1,2]:
  assert call('choose',mode)
  for width,height in [(236,600),(320,640),(480,720),(900,650)]:
   window.setWidth(width);window.setHeight(height);QTest.qWait(100)
   assert window.grabWindow().save(f'/tmp/navo-missions-{mode}-{width}.png')
 assert not errors,errors
 print('PASS production Missions layout in three modes at 236/320/480/900; immutable active selection, PAUZĂ/HOME dispatch and link-loss controls')
