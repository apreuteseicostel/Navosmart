"""Production wrapper/PiP/fullscreen lifecycle; mock only decoder/network output."""
import os
os.environ.setdefault('QT_QPA_PLATFORM','offscreen');os.environ.setdefault('QT_QUICK_BACKEND','software')
from pathlib import Path
import tempfile,shutil
from PySide6.QtCore import QObject,QUrl,QMetaObject
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuick import QQuickWindow
from PySide6.QtTest import QTest
repo=Path(__file__).resolve().parents[1]
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
 property bool full:false;property bool showPip:true
 NavoCameraPip {id:pip;objectName:"pip";anchors.fill:parent;visible:root.showPip && !root.full;connected:true;streamUrl:"rtsp://test/stream";onCloseRequested:root.showPip=false;onFullscreenRequested:root.full=true}
 Loader {id:large;anchors.fill:parent;active:root.full;sourceComponent:Component{NavoCameraFullScreen {streamUrl:pip.streamUrl;onClosed:{root.full=false;root.showPip=false}}}}
 function fullscreen(){pip.fullscreenRequested()}
}''')
 engine.load(QUrl.fromLocalFile(str(d/'Test.qml')));assert engine.rootObjects(),errors
 w=engine.rootObjects()[0]
 def item(name):
  obj=w.findChild(QObject,name);assert obj,name;return obj
 def click(name):QMetaObject.invokeMethod(item(name),'clicked');QTest.qWait(40)
 QTest.qWait(60)
 p=item('cameraPipPlayer');assert p.property('desiredPlaying') and p.property('live')
 item('pip').setProperty('protocol','rtsp');item('pip').setProperty('streamUrl','  camera-host/stream  ');QTest.qWait(20)
 assert item('decoderDouble').property('streamUrl')=='rtsp://camera-host/stream'
 click('cameraPipClose');assert not w.property('showPip') and not p.property('desiredPlaying') and not p.property('live')
 QTest.qWait(200);assert not p.property('desiredPlaying') # no delayed reopen after close
 w.setProperty('showPip',True);QTest.qWait(40);assert p.property('live')
 QMetaObject.invokeMethod(w,'fullscreen');QTest.qWait(50)
 assert not p.property('live') and item('cameraFullscreenPlayer').property('live')
 click('cameraFullscreenClose');assert not w.property('full') and not w.property('showPip') and not p.property('live')
 for width in [236,320,480,900]:
  w.setWidth(width);w.setProperty('showPip',True);QTest.qWait(30)
  close=item('cameraPipClose');assert close.property('x')+close.property('width')<=width
  assert p.property('y')>=close.property('y')+close.property('height')
  assert w.grabWindow().save(f'/tmp/navo-camera-{width}.png')
 assert not errors,errors
 print('PASS production video wrapper/PiP/fullscreen: autostart, stop/no reopen, one visible player, close surface outside controls, 236–900px')
