"""Actual Settings and Dashboard bindings, with an explicit LAN-discovery double."""
import os
os.environ.setdefault('QT_QPA_PLATFORM','offscreen')
os.environ.setdefault('QT_QUICK_BACKEND','software')
from pathlib import Path
import tempfile,subprocess
import PySide6
from PySide6.QtCore import QObject,Property,Signal,Slot,QResource,QUrl,QMetaObject,Q_ARG,Q_RETURN_ARG,QPointF,QCoreApplication,QEvent
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine,qmlRegisterType
from PySide6.QtQuick import QQuickItem,QQuickWindow
from PySide6.QtTest import QTest
class Discovery(QObject):
 changed=Signal()
 def __init__(self,parent=None):super().__init__(parent);self._host='';self._port=8899
 devices=Property('QVariantList',lambda self:[],notify=changed)
 scanning=Property(bool,lambda self:False,notify=changed)
 protectedHost=Property(str,lambda self:self._host,lambda self,v:setattr(self,'_host',v),notify=changed)
 serialPort=Property(int,lambda self:self._port,lambda self,v:setattr(self,'_port',v),notify=changed)
 @Slot()
 def scan(self):pass
 @Slot()
 def stop(self):pass
repo=Path(__file__).resolve().parent.parent
source=(repo/'custom/qml/NavoDashboard.qml').read_text()
a=source.index('    Component {\n        id: settingsPage');b=source.index('\n    Loader {',a)
page=source[a:b]
assert 'alerts: root.settingsAlertsController' in page
app=QGuiApplication([]);app.setOrganizationName('NAVO tests');app.setApplicationName('Settings tabs')
qmlRegisterType(Discovery,'NavoSmart.Backend',1,0,'NavoLanDiscovery')
engine=QQmlApplicationEngine();engine.addImportPath(str(repo/'custom/qml'));errors=[]
engine.warnings.connect(lambda ws:errors.extend(str(w) for w in ws))
wrapper='''import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "'''+QUrl.fromLocalFile(str(repo/'custom/qml')).toString()+'''"
ApplicationWindow {
 id:root;visible:true;width:800;height:650;color:"#051521"
 property var sonarController:sonarMock
 readonly property var settingsAlertsController:alerts
 property var alertAudio:null
 property var steeringAssist:null
 property var g20Controller:null
 property var energySettings:null
 property string cameraStreamUrl:""
 property string cameraProtocol:"auto"
 property string lastNavigationStatus:""
 property alias page:settingsLoader.item
 QtObject {id:alerts;objectName:"alertsBackend";property bool soundEnabled:true;property bool voiceEnabled:false;property real volume:.7;property string latest:"";function configure(s,v,n){soundEnabled=s;voiceEnabled=v;volume=n}function test(){}}
 QtObject {id:sonarMock;property string host:"";property int port:0;property bool udp:false;property bool connected:false;property bool dataAlive:false;property string status:"OFFLINE";function connectSonar(){} function disconnectSonar(){}}
 QtObject {id:cameraEthernet;property string host:"";property int port:0;property bool udp:false;property bool connected:false;property bool dataAlive:false;property string status:"OFFLINE"}
 Loader {id:settingsLoader;anchors.fill:parent;sourceComponent:settingsPage}
}'''
# The test uses the production settingsPage and its source bindings verbatim.
wrapper=wrapper[:-1]+page+'}'
with tempfile.TemporaryDirectory() as directory:
 folder=Path(directory);qrc=folder/'icons.qrc';resource=folder/'icons.rcc'
 qrc.write_text('<RCC><qresource prefix="/qml/NavoSmart/icons">'+''.join(f'<file alias="{p.name}">{p}</file>' for p in (repo/'custom/icons').glob('*.svg'))+'</qresource></RCC>')
 subprocess.run([str(Path(PySide6.__file__).parent/'Qt/libexec/rcc'),'--binary',str(qrc),'-o',str(resource)],check=True);assert QResource.registerResource(str(resource))
 f=folder/'Test.qml';f.write_text(wrapper);engine.load(QUrl.fromLocalFile(str(f)));assert engine.rootObjects(),errors
 window=engine.rootObjects()[0];QTest.qWait(60);page=window.property('page');assert page
 assert page.property('alerts')==window.findChild(QObject,'alertsBackend')
 forms=window.findChild(QObject,'settingsEthernetForms');assert forms
 names=['settingsGeneralTab','settingsAdvancedTab','settingsIntegrationTab','settingsQgcTab']
 for width in [480,640,800,1024]:
  window.setWidth(width);QTest.qWait(40)
  for index,name in enumerate(names):
   # Return to top before inspecting/clicking tabs after a long integration form.
   button=window.findChild(QObject,name);assert button
   assert button.property('text')!='Unități'
   QMetaObject.invokeMethod(button,'clicked');QTest.qWait(40)
   assert page.property('selectedTab')==index
   assert forms.property('visible')==(index==2)
   footer=window.findChild(QObject,'settingsSaveFooter')
   assert footer.property('visible')==(index in [0,2])
   pos=button.mapToScene(QPointF(0,0))
   assert 0<=pos.x() and pos.x()+button.property('width')<=width
   assert window.grabWindow().save(f'/tmp/navo-settings-{width}-{index}.png')
   if index==2:
    window.findChild(QObject,'settingsSonarHost').setProperty('text','192.168.0.7')
    window.findChild(QObject,'settingsSonarPort').setProperty('text','23')
  # Switching tabs must preserve the same live form instance and unsaved input.
  page.setProperty('selectedTab',2);QTest.qWait(20)
  assert forms==window.findChild(QObject,'settingsEthernetForms')
  assert window.findChild(QObject,'settingsSonarPort').property('text')=='23'
 assert QMetaObject.invokeMethod(page,'saveAll',Q_RETURN_ARG('QVariant'))
 window.findChild(QObject,'settingsCameraPort').setProperty('text','70000')
 assert not QMetaObject.invokeMethod(page,'saveAll',Q_RETURN_ARG('QVariant'))
 calls=[]
 page.settingsToolRequested.connect(lambda:calls.append(True))
 QMetaObject.invokeMethod(window.findChild(QObject,'settingsOpenQgc'),'clicked')
 assert len(calls)==1
 window.close();window.deleteLater()
 QCoreApplication.sendPostedEvents(None,QEvent.DeferredDelete);app.processEvents()
 assert not errors,errors
 print('PASS actual Settings tabs at 480/640/800/1024: four tabs, full Integration forms, retained edits/save validation and non-circular alerts binding')
