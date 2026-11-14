"""Actual Settings and Dashboard bindings, with an explicit LAN-discovery double."""
import os
os.environ.setdefault('QT_QPA_PLATFORM','offscreen')
os.environ.setdefault('QT_QUICK_BACKEND','software')
from pathlib import Path
import tempfile,subprocess
import PySide6
from PySide6.QtCore import QPoint,Qt,QObject,Property,Signal,Slot,QResource,QUrl,QMetaObject,Q_ARG,Q_RETURN_ARG,QPointF,QCoreApplication,QEvent
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
app=QGuiApplication([]);app.setOrganizationName('NAVO tests');app.setApplicationName('Settings tabs '+str(os.getpid()))
qmlRegisterType(Discovery,'NavoSmart.Backend',1,0,'NavoLanDiscovery')
engine=QQmlApplicationEngine();engine.addImportPath(str(repo/'custom/qml'));errors=[]
engine.warnings.connect(lambda ws:errors.extend(str(w) for w in ws))
wrapper='''import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "'''+QUrl.fromLocalFile(str(repo/'custom/qml')).toString()+'''"
ApplicationWindow {
 id:root;visible:true;width:800;height:650;color:"#051521"
 property var lanService:diagnostics
 property int lanSaves:0
 QtObject {id:diagnostics
  property string host:"192.168.144.7";property int monitorPort:80;property int uartPort:23;property string scanAddress:"192.168.144.1";property string subnetMask:"255.255.255.0";property bool scanning:false;property var devices:[]
  property bool suspended:false;property bool monitoring:false;property bool online:false;property bool uartConnected:false
  property string status:"LAN neconfirmat";property string uartStatus:"";property string preview:"";property int received:0;property var interfaces:[]
  function stopUart(){} function clearPreview(){} function verify(){} function connectUart(){}
  function saveConfiguration(){root.lanSaves++;return true}
 }
 property int settingsStartTab:0
 property bool actionActive:false
 property bool offlineLabAllowed:true
 property var sonar:sonarMock
 QtObject {
  id:persistence;objectName:"backupBackend"
  property url exportedTo
  property url importedFrom
  function exportBackup(url){exportedTo=url;return ""}
  function stageBackupRestore(url){importedFrom=url;return ""}
  function backupRestorePending(){return String(importedFrom).length>0}
 }
 property bool cameraConnected:false
 QtObject {id:connectivityController;property var connections:[];property bool autoConnect:false;property bool busy:false;property string status:"Test";property int serialBaud:115200}
 property bool linkAlive:false
 property var vehicle:null
 property bool viewSwitchAllowed:true
 property int parameterOpens:0
 property int vehicleOpens:0
 property int applicationOpens:0
 function connectVehicle(){vehicle=({});linkAlive=true}
 QtObject {
  id:mainWindow
  function allowViewSwitch(){return root.viewSwitchAllowed}
  function showVehicleConfigParametersPage(){root.parameterOpens++}
  function showVehicleConfig(){root.vehicleOpens++}
  function showSettingsTool(){root.applicationOpens++}
 }
 property var sonarController:sonarMock
 readonly property var settingsAlertsController:alerts
 property var alertAudio:null
 property var steeringAssist:null
 property var g20Controller:null
 property var energySettings:null
 property var stealthController:null
 property string cameraStreamUrl:""
 property string cameraProtocol:"auto"
 property string cameraDecoder:"hardware"
 property string cameraRtspTransport:"tcp"
 property string lastNavigationStatus:""
 property alias page:settingsLoader.item
 QtObject {id:alerts;objectName:"alertsBackend";property bool soundEnabled:true;property bool voiceEnabled:false;property real volume:.7;property string latest:"";function configure(s,v,n){soundEnabled=s;voiceEnabled=v;volume=n}function test(){}}
 QtObject {id:sonarMock;property string host:"";property int port:0;property bool udp:false;property bool connected:false;property bool dataAlive:false;property bool recording:false;property string status:"OFFLINE";function connectSonar(){} function disconnectSonar(){}}
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
 page.setProperty('selectedTab',2);QTest.qWait(20)
 assert window.findChild(QObject,'settingsIntegrationTab').property('text')=='Conexiuni'
 assert window.findChild(QObject,'settingsConnectivity').property('visible')
 QMetaObject.invokeMethod(window.findChild(QObject,'settingsConnectivity'),'clicked');QTest.qWait(20)
 assert page.property('selectedTab')==4 and window.findChild(QObject,'settingsConnectivityPanel').property('visible')
 QMetaObject.invokeMethod(window.findChild(QObject,'connectivityBack'),'clicked');QTest.qWait(20);assert page.property('selectedTab')==2
 # The global Save includes collapsed LAN/UART drafts, without invoking network tests.
 window.findChild(QObject,'settingsVideoDecoder').setProperty('currentIndex',1)
 window.findChild(QObject,'settingsVideoRtspTransport').setProperty('currentIndex',1)
 window.findChild(QObject,'lanTargetHost').setProperty('text','192.168.144.77')
 window.findChild(QObject,'lanWebPort').setProperty('text','8080')
 window.findChild(QObject,'lanUartPort').setProperty('text','2323')
 assert QMetaObject.invokeMethod(page,'saveAll',Q_RETURN_ARG('QVariant'))
 service=page.property('lanDiagnostics')
 assert service.property('host')=='192.168.144.77' and service.property('monitorPort')==8080 and service.property('uartPort')==2323
 assert page.property('cameraDecoder')=='software' and page.property('cameraRtspTransport')=='udp'
 from PySide6.QtCore import QSettings
 persisted=QSettings();assert persisted.value('NavoEthernet/cameraDecoder')=='software' and persisted.value('NavoEthernet/cameraRtspTransport')=='udp'
 assert window.property('lanSaves')==1
 window.findChild(QObject,'lanUartPort').setProperty('text','0')
 assert not QMetaObject.invokeMethod(page,'saveAll',Q_RETURN_ARG('QVariant'))
 assert window.property('lanSaves')==1 and service.property('uartPort')==2323
 window.findChild(QObject,'lanUartPort').setProperty('text','2323')
 window.findChild(QObject,'settingsCameraPort').setProperty('text','70000')
 assert not QMetaObject.invokeMethod(page,'saveAll',Q_RETURN_ARG('QVariant'))
 # Invoke the actual Dashboard handlers through the Settings controls. Only QGC's native window is doubled.
 page.setProperty('selectedTab',3);window.setWidth(800);QTest.qWait(40)
 params=window.findChild(QObject,'settingsOpenParameters');vehicle=window.findChild(QObject,'settingsOpenVehicle')
 assert not params.property('enabled') and not vehicle.property('enabled')
 def press(button):
  pos=button.mapToScene(QPointF(button.property('width')/2,button.property('height')/2))
  QTest.mouseClick(window,Qt.LeftButton,Qt.NoModifier,QPoint(round(pos.x()),round(pos.y())));QTest.qWait(20)
 press(params);assert window.property('parameterOpens')==0
 QMetaObject.invokeMethod(window,'connectVehicle');QTest.qWait(30)
 assert params.property('enabled') and vehicle.property('enabled')
 window.setProperty('viewSwitchAllowed',False);press(params);assert window.property('parameterOpens')==0
 window.setProperty('viewSwitchAllowed',True);press(params);assert window.property('parameterOpens')==1
 assert window.property('applicationOpens')==0 and window.property('vehicleOpens')==0
 press(vehicle);assert window.property('vehicleOpens')==1 and window.property('parameterOpens')==1
 for width in [320,480,800]:
  window.setWidth(width);QTest.qWait(40)
  for button in [params,vehicle,window.findChild(QObject,'settingsOpenQgc')]:
   pos=button.mapToScene(QPointF(0,0));assert pos.x()>=0 and pos.x()+button.property('width')<=width
   assert pos.y()>=0 and pos.y()+button.property('height')<=window.height()
  assert window.grabWindow().save(f'/tmp/navo-native-parameters-{width}.png')
 window.setProperty('linkAlive',False);QTest.qWait(30)
 assert not params.property('enabled') and not vehicle.property('enabled')
 calls=[]
 page.settingsToolRequested.connect(lambda:calls.append(True))
 QMetaObject.invokeMethod(window.findChild(QObject,'settingsOpenQgc'),'clicked')
 assert len(calls)==1
 page.setProperty('selectedTab',0)
 export_button=window.findChild(QObject,'navoBackupExport')
 import_button=window.findChild(QObject,'navoBackupImport')
 assert export_button.property('enabled') and import_button.property('enabled')
 window.setProperty('actionActive',True)
 assert not export_button.property('enabled') and not import_button.property('enabled')
 window.setProperty('actionActive',False)
 backend=window.findChild(QObject,'backupBackend')
 selected=folder/'navo-backup.json';selected.write_text('{}')
 url=QUrl.fromLocalFile(str(selected))
 export_picker=window.findChild(QObject,'navoBackupExportPicker')
 assert export_picker.setProperty('selectedFile',url)
 assert QMetaObject.invokeMethod(export_picker,'accepted')
 assert backend.property('exportedTo')==url
 import_picker=window.findChild(QObject,'navoBackupImportPicker')
 confirm=window.findChild(QObject,'navoBackupRestoreConfirmation')
 assert import_picker.setProperty('selectedFile',url)
 assert QMetaObject.invokeMethod(import_picker,'accepted')
 assert confirm.property('visible') and backend.property('importedFrom').isEmpty()
 assert QMetaObject.invokeMethod(confirm,'reject')
 assert backend.property('importedFrom').isEmpty()
 assert QMetaObject.invokeMethod(import_picker,'accepted')
 assert QMetaObject.invokeMethod(confirm,'accept')
 assert backend.property('importedFrom')==url
 window.close();window.deleteLater()
 QCoreApplication.sendPostedEvents(None,QEvent.DeferredDelete);app.processEvents()
 assert not errors,errors
 print('PASS Settings tabs/forms/save; native parameter/vehicle/application routing, connection and view-switch guards; buttons contained at 320/480/800')

