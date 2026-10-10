"""Real Sonar PRO QML dialogs; backend protocol tests live in recording.cpp."""
import os
os.environ.setdefault('QT_QPA_PLATFORM','offscreen')
os.environ.setdefault('QT_QUICK_BACKEND','software')
from pathlib import Path
import tempfile, subprocess
import PySide6
from PySide6.QtCore import QUrl, QObject, QMetaObject, QResource
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlComponent
from PySide6.QtQuick import QQuickView
from PySide6.QtTest import QTest
app=QGuiApplication([])
app.setOrganizationName('NAVO tests'); app.setApplicationName('Sonar recording UI')
repo=Path(__file__).resolve().parent.parent
resource_dir=tempfile.TemporaryDirectory()
qrc=Path(resource_dir.name)/'icons.qrc'
qrc.write_text('<RCC><qresource prefix="/qml/NavoSmart/icons">'+''.join(f'<file alias="{p.name}">{p}</file>' for p in (repo/'custom/icons').glob('*.svg'))+'</qresource></RCC>')
resource=Path(resource_dir.name)/'icons.rcc'
subprocess.run([str(Path(PySide6.__file__).parent/'Qt/libexec/rcc'),'--binary',str(qrc),'-o',str(resource)],check=True)
assert QResource.registerResource(str(resource))
view=QQuickView();view.setResizeMode(QQuickView.SizeRootObjectToView)
view.engine().addImportPath(str(repo/'tests/kogger-replay/mock-imports'))
errors=[];view.engine().warnings.connect(lambda warnings:errors.extend(str(w) for w in warnings))
view.setSource(QUrl.fromLocalFile(str(repo/'custom/qml/NavoSonarPro.qml')))
assert view.status()==QQuickView.Ready,errors
root=view.rootObject()
component=QQmlComponent(view.engine())
component.setData(b'''import QtQuick
QtObject {
 property bool replayMode:false
 property bool replayActive:false
 property bool replayPaused:false
 property double replaySpeed:1
 property string replayError:""
 property bool recording:false
 property bool dataAlive:true
 property double recordingBytes:1048576
 property string recordingError:""
 property string recordingSavedName:""
 property var recordings:[{name:"Balta nord",size:1048576,createdUtc:"2026-10-09T23:00:00Z",url:"file:///tmp/nord.navosonar"}]
 property string lastName:""
 property string lastReplay:""
 function startRecording(name){lastName=name;recording=true;return true}
 function stopRecording(){recording=false;recordingSavedName=lastName;return true}
 function refreshRecordings(){}
 function startReplay(url){lastReplay=String(url);replayMode=true;return true}
 signal echoSamplesChanged()
 signal bottomColumnReady(int sequence,real depth)
}''',QUrl())
source=component.create();assert source,component.errors()
root.setProperty('chartSource',source);root.setProperty('connected',True)
view.show()
recording=root.findChild(QObject,'sonarRecordingDialog')
recordings=root.findChild(QObject,'sonarRecordingsDialog')
analysis=root.findChild(QObject,'sonarBottomAnalysisDialog')
assert recording and recordings and analysis
raw=[.05]*200
raw[98:102]=[.4,.8,.8,.4]
raw[40:43]=[.6,.6,.6]
root.setProperty('history',[{'samples':raw,'rawSamples':raw,'offset':0.0,'range':4.0,'bottom':2.0,'sequence':1}])
for width,height in [(320,600),(480,720),(900,600)]:
 view.resize(width,height)
 for popup,label in [(recording,'record'),(recordings,'offline'),(analysis,'bottom-analysis')]:
  QMetaObject.invokeMethod(popup,'open');QTest.qWait(150)
  assert popup.property('visible')
  assert popup.property('width')<=width and popup.property('height')<=height
  assert view.grabWindow().save(f'/tmp/navo-sonar-{label}-{width}.png')
  QMetaObject.invokeMethod(popup,'close')
QMetaObject.invokeMethod(analysis,'open');QTest.qWait(30)
metrics=root.property('bottomAnalysis').toVariant()
assert metrics['valid'] and abs(metrics['peak']-.8)<1e-9 and metrics['material']=='NECLASIFICAT'
root.setProperty('gain',3.0);root.setProperty('noiseFloor',.7);QTest.qWait(30)
assert root.property('bottomAnalysis').toVariant()['peak']==metrics['peak']
root.setProperty('koggerCompensation',True)
root.setProperty('history',[{'samples':[.01]*200,'rawSamples':raw,'offset':0.0,'range':4.0,'bottom':2.0,'sequence':1}]);QTest.qWait(30)
assert root.property('bottomAnalysis').toVariant()['peak']==metrics['peak']
QMetaObject.invokeMethod(analysis,'close')
name=root.findChild(QObject,'sonarRecordingName');assert name
name.setProperty('text','Balta mea');QMetaObject.invokeMethod(recording,'accepted')
assert source.property('lastName')=='Balta mea' and source.property('recording')
QMetaObject.invokeMethod(recordings,'open');QTest.qWait(150)
items=root.findChild(QObject,'sonarRecordingsList');assert items
# A stale display source with no recording API must keep old PRO views warning-free.
root.setProperty('chartSource',None);QTest.qWait(30)
assert not errors,errors
print('PASS actual Sonar PRO recording/offline/bottom-analysis dialogs at 320/480/900, named start and empty source')
