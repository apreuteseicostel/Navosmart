"""Production compact LAN/UART panel; mocks only network backend, sends no packets."""
import os
os.environ.setdefault('QT_QPA_PLATFORM','offscreen')
os.environ.setdefault('QT_QUICK_BACKEND','software')
from pathlib import Path
import tempfile
from PySide6.QtCore import QUrl,QObject,QMetaObject,Q_RETURN_ARG
from PySide6.QtGui import QGuiApplication
from PySide6.QtQuick import QQuickWindow
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtTest import QTest
repo=Path(__file__).resolve().parents[1]
app=QGuiApplication([]);engine=QQmlApplicationEngine();errors=[]
engine.warnings.connect(lambda ws:errors.extend(str(w) for w in ws))
source='''import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "'''+QUrl.fromLocalFile(str(repo/'custom/qml')).toString()+'''"
ApplicationWindow {
 id:root;visible:true;width:480;height:900
 property int listenCalls:0;property int verifyCalls:0;property int stopCalls:0
 QtObject {id:service
  property string host:"192.168.0.7"
  property int monitorPort:80;property int uartPort:23;property string scanAddress:"192.168.144.1";property string subnetMask:"255.255.255.0";property bool scanning:false;property var devices:[]
  property bool suspended:false;property bool monitoring:false;property bool online:false;property bool uartConnected:false
  property string status:"LAN neconfirmat";property string uartStatus:"TCP neconectat";property string preview:"";property int received:0
  property var interfaces:[{ethernet:true,name:"eth0",ip:"192.168.0.10",mask:"255.255.255.0",link:true}]
  function saveConfiguration(){return true}
  function verify(){root.verifyCalls++}
  function connectUart(){root.listenCalls++;uartConnected=true;uartStatus="TCP conectat, UART neconfirmat"}
  function stopUart(){root.stopCalls++;uartConnected=false}
  function clearPreview(){preview="";received=0}
 }
 ScrollView {anchors.fill:parent;contentWidth:availableWidth
  ColumnLayout {width:parent.width
   NavoLanDiagnosticPanel {id:panel;objectName:"panel";Layout.fillWidth:true;backend:service}
  }
 }
 function stale(){service.online=false;service.status="Dispozitiv LAN fără răspuns"}
 function rx(){service.received=4;service.preview="HEX: 00 41 ff 0a\\nTEXT: .A.."}
 function replay(){service.suspended=true}
}'''
with tempfile.TemporaryDirectory() as folder:
 p=Path(folder)/'Test.qml';p.write_text(source);engine.load(QUrl.fromLocalFile(str(p)))
 assert engine.rootObjects(),errors
 w=engine.rootObjects()[0];QTest.qWait(40)
 def item(name):
  result=w.findChild(QObject,name);assert result,name;return result
 def click(name):QMetaObject.invokeMethod(item(name),'clicked');QTest.qWait(20)
 panel=item('panel');assert panel.property('height')<180
 click('lanExpand');assert panel.property('expanded')
 assert item('lanTargetHost').property('text')=='192.168.0.7'
 # Saving drafts must not require a network test or open a UART client.
 def save():return QMetaObject.invokeMethod(panel,'saveConfiguration',Q_RETURN_ARG('QVariant'))
 item('lanTargetHost').setProperty('text','192.168.144.17')
 item('lanWebPort').setProperty('text','8080');item('lanUartPort').setProperty('text','2323')
 assert save() and w.property('listenCalls')==0 and w.property('verifyCalls')==0
 for value in ['', '0','65536','8080']:
  item('lanUartPort').setProperty('text',value);assert not save()
 item('lanUartPort').setProperty('text','23')
 click('lanVerify');assert w.property('verifyCalls')==1
 item('lanUartPort').setProperty('text','70000');click('lanUartConnect');assert w.property('listenCalls')==0
 item('lanUartPort').setProperty('text','23');click('lanUartConnect');assert w.property('listenCalls')==1
 assert not item('lanUartConnect').property('enabled')
 QMetaObject.invokeMethod(w,'rx');QTest.qWait(20);assert '4 octeți' in item('lanRxCount').property('text')
 assert '00 41 ff 0a' in item('lanUartPreview').property('text')
 click('lanExpand');assert not panel.property('expanded') and w.property('stopCalls')>=1
 click('lanExpand');QMetaObject.invokeMethod(w,'replay');QTest.qWait(20)
 assert not item('lanVerify').property('enabled') and not item('lanUartConnect').property('enabled')
 for width in [320,480,800]:
  w.setWidth(width);QTest.qWait(30)
  for name in ['lanTargetHost','lanWebPort','lanUartPort','lanVerify','lanUartConnect']:
   control=item(name);assert control.property('width')>20
  assert w.grabWindow().save(f'/tmp/navo-lan-theme-{width}.png')
 assert not errors,errors
 print('PASS production LAN/UART panel: compact/expanded, settings, invalid ports, passive listen controls, RX/HEX, close release, replay and 320/480/800 widths')
