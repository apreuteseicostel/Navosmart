"""Production MOD card shows H743 confirmation only; removed popup cannot open."""
import os
os.environ.setdefault('QT_QPA_PLATFORM','offscreen');os.environ.setdefault('QT_QUICK_BACKEND','software')
from pathlib import Path
import tempfile,subprocess
import PySide6
from PySide6.QtCore import QUrl,QResource,QMetaObject,Q_ARG,Q_RETURN_ARG,QPoint,Qt,QObject,QCoreApplication,QEvent
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuick import QQuickWindow
from PySide6.QtTest import QTest
repo=Path(__file__).resolve().parent.parent
s=(repo/'custom/qml/NavoDashboard.qml').read_text()
card=next(l for l in s.splitlines() if 'StatusPill {' in l and 'title: "MOD"' in l)
card=card.replace('StatusPill {','StatusPill {id:modeCard;objectName:"modeCard";anchors.centerIn:parent;width:100;height:42;',1)
a=s.index('    component StatusPill:');b=s.index('    component NavButton:',a)
wrapper='''import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "'''+QUrl.fromLocalFile(str(repo/'custom/qml')).toString()+'''"
ApplicationWindow {
 id:root;visible:true;width:800;height:600;color:"#071926"
 property bool linkAlive:true
 property bool compactUi:true
 property color ok:"#31d67b"
 property color text:"#eff9ff"
 property color line:"#174c68"
 property int switchPwm:1000
 property var vehicle:autopilot
 readonly property string flightMode:vehicle.flightMode
 QtObject {id:autopilot;objectName:"testH743";property string flightMode:"Hold"}
 QtObject {id:header;property real telemetryScale:1}
 NavoStatusDetails {id:details;objectName:"statusDetails";viewportWidth:root.width;viewportHeight:root.height;linkAlive:root.linkAlive}
}'''
wrapper=wrapper[:-1]+card+s[a:b]+'}'
app=QGuiApplication([]);engine=QQmlApplicationEngine();errors=[]
engine.warnings.connect(lambda ws:errors.extend(str(w) for w in ws))
with tempfile.TemporaryDirectory() as directory:
 folder=Path(directory);qrc=folder/'icons.qrc';resource=folder/'icons.rcc'
 qrc.write_text('<RCC><qresource prefix="/qml/NavoSmart/icons">'+''.join(f'<file alias="{p.name}">{p}</file>' for p in (repo/'custom/icons').glob('*.svg'))+'</qresource></RCC>')
 subprocess.run([str(Path(PySide6.__file__).parent/'Qt/libexec/rcc'),'--binary',str(qrc),'-o',str(resource)],check=True);assert QResource.registerResource(str(resource))
 f=folder/'Test.qml';f.write_text(wrapper);engine.load(QUrl.fromLocalFile(str(f)));assert engine.rootObjects(),errors
 window=engine.rootObjects()[0];QTest.qWait(40)
 card=window.findChild(QObject,'modeCard');backend=window.findChild(QObject,'testH743');details=window.findChild(QObject,'statusDetails')
 assert card.property('value')=='HOLD' and not card.property('interactive')
 for pwm in [1000,1500,2000]:
  window.setProperty('switchPwm',pwm);QTest.qWait(10);assert card.property('value')=='HOLD'
 for mode in ['Manual','Auto','Guided','RTL','Hold']:
  backend.setProperty('flightMode',mode);QTest.qWait(10);assert card.property('value')==mode.upper()
 QTest.mouseClick(window,Qt.LeftButton,Qt.NoModifier,QPoint(400,300));QTest.qWait(20);assert not details.property('visible')
 assert not QMetaObject.invokeMethod(details,'showSection',Q_RETURN_ARG('QVariant'),Q_ARG('QVariant','mode'))
 assert not details.property('visible')
 window.setProperty('linkAlive',False);QTest.qWait(20);assert card.property('value')=='--'
 window.setProperty('linkAlive',True);backend.setProperty('flightMode','Guided');QTest.qWait(20);assert card.property('value')=='GUIDED'
 for section in ['battery','temperature']:
  assert QMetaObject.invokeMethod(details,'showSection',Q_RETURN_ARG('QVariant'),Q_ARG('QVariant',section));QTest.qWait(20)
  assert details.property('visible');QMetaObject.invokeMethod(details,'close')
 window.close();window.deleteLater();QCoreApplication.sendPostedEvents(None,QEvent.DeferredDelete);app.processEvents()
 assert not errors,errors
 print('PASS real MOD card: confirmed H743 modes only, no inferred switch mode, no click/popup, lost-link -- and battery/temperature retained')
