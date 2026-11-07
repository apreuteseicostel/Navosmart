"""Exercise production camera controls with a stand-in decoder and dashboard shell."""
import os
os.environ.setdefault('QT_QPA_PLATFORM','offscreen');os.environ.setdefault('QT_QUICK_BACKEND','software')
from pathlib import Path
import re,tempfile,shutil
from PySide6.QtCore import QObject,QPointF,QUrl,QMetaObject,Qt
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuick import QQuickWindow
from PySide6.QtTest import QTest
repo=Path(__file__).resolve().parents[1]
dashboard=(repo/'custom/qml/NavoDashboard.qml').read_text()
close_camera=re.search(r'^    function closeFullscreenCamera\(\) \{.*?^    }',dashboard,re.M|re.S).group()
fullscreen_loader=re.search(r'^    Loader \{\n        id: fullscreenCameraLoader\n.*?^    }',dashboard,re.M|re.S).group()
home_click=re.search(r'title: "HOME";[^\n]+\n( +onClicked: \{.*?\n +})\n +onPressAndHold:',dashboard,re.S).group(1)
app=QGuiApplication([]);engine=QQmlApplicationEngine();errors=[]
engine.warnings.connect(lambda warnings:errors.extend(str(w) for w in warnings))
with tempfile.TemporaryDirectory() as directory:
 d=Path(directory)
 for name in ['NavoVideoPlayer.qml','NavoCameraPip.qml','NavoCameraFullScreen.qml']:shutil.copy(repo/'custom/qml'/name,d/name)
 (d/'NavoQtVideoPlayer.qml').write_text('''import QtQuick
Item {objectName:"decoderDouble";property string streamUrl:"";property string protocol:"auto";property string decoder:"hardware";property string rtspTransport:"tcp";property bool autoReconnect:true;property bool playing:false;property bool live:playing;property string status:playing?"LIVE":"STOPPED";function start(){playing=true}function stop(){playing=false}}
''')
 (d/'Test.qml').write_text('''import QtQuick
import QtQuick.Controls
ApplicationWindow {id:root;width:320;height:260;visible:true
 property bool cameraFullscreen:false;property bool cameraPipEnabled:true;property bool cameraConnected:false
 property int activePage:0
 property string cameraStreamUrl:pip.streamUrl
 property string cameraProtocol:pip.protocol
 property string cameraDecoder:"hardware"
 property string cameraRtspTransport:"tcp"
 property string lastNavigationStatus:""
 property int homeCenters:0
 property QtObject mapController: QtObject {function centerHome(){root.homeCenters++;return true}}
 Rectangle {id:header;objectName:"header";anchors.top:parent.top;width:parent.width;height:64;z:2000
  Button {objectName:"home";text:"HOME";@HOME_CLICK@}
 }
 NavoCameraPip {id:pip;objectName:"pip";anchors.top:header.bottom;anchors.right:parent.right;anchors.left:parent.left;anchors.bottom:parent.bottom;visible:root.cameraPipEnabled && !root.cameraFullscreen && root.activePage===0;connected:true;streamUrl:"rtsp://test/stream";onCloseRequested:root.cameraPipEnabled=false;onFullscreenRequested:root.cameraFullscreen=true}
 @FULLSCREEN_LOADER@
 @CLOSE_CAMERA@
 function fullscreen(){pip.fullscreenRequested()}
}'''.replace('@HOME_CLICK@',home_click).replace('@FULLSCREEN_LOADER@',fullscreen_loader).replace('@CLOSE_CAMERA@',close_camera))
 engine.load(QUrl.fromLocalFile(str(d/'Test.qml')));assert engine.rootObjects(),errors
 w=engine.rootObjects()[0]
 def item(name):
  obj=w.findChild(QObject,name);assert obj,name;return obj
 def click(name):
  button=item(name)
  center=button.mapToScene(QPointF(button.width()/2,button.height()/2)).toPoint()
  QTest.mouseClick(w,Qt.LeftButton,Qt.NoModifier,center)
  QTest.qWait(40)
 QTest.qWait(60)
 p=item('cameraPipPlayer');assert p.property('desiredPlaying') and p.property('live')
 item('pip').setProperty('protocol','rtsp');item('pip').setProperty('streamUrl','  camera-host/stream  ');QTest.qWait(20)
 assert item('decoderDouble').property('streamUrl')=='rtsp://camera-host/stream'
 click('cameraPipClose');assert not w.property('cameraPipEnabled') and not p.property('desiredPlaying') and not p.property('live')
 QTest.qWait(200);assert not p.property('desiredPlaying') # no delayed reopen after close
 for expected_home_centers,width in enumerate([236,320,480,900],start=1):
  w.setWidth(width);w.setProperty('cameraPipEnabled',True);QTest.qWait(40)
  assert p.property('live')
  close=item('cameraPipClose');assert close.property('x')+close.property('width')<=width
  assert p.property('y')>=close.property('y')+close.property('height')
  for control in ['cameraFullscreenClose','home']:
   w.setProperty('activePage',5)
   QMetaObject.invokeMethod(w,'fullscreen');QTest.qWait(50)
   fullscreen_player=item('cameraFullscreenPlayer')
   assert not p.property('live') and fullscreen_player.property('live') and w.property('cameraConnected')
   close=item('cameraFullscreenClose')
   assert close.mapToScene(QPointF()).y()>=item('header').height()
   assert close.mapToScene(QPointF(close.width(),close.height())).x()<=width
   assert fullscreen_player.mapToScene(QPointF()).y()>=close.mapToScene(QPointF(0,close.height())).y()
   click(control)
   assert w.property('activePage')==0 and not w.property('cameraFullscreen')
   assert not w.property('cameraPipEnabled') and not w.property('cameraConnected') and not p.property('live')
   assert w.findChild(QObject,'cameraFullscreenPlayer') is None
  assert w.property('homeCenters')==expected_home_centers
 assert not errors,errors
 print('PASS production video wrapper/PiP/fullscreen: autostart, exclusive playback, visible × and HOME close by touch, 236–900px')
