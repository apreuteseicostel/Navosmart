"""Production SHT31 diagnostics and alert policy with explicit telemetry doubles."""
import os
import subprocess
import PySide6
os.environ.setdefault('QT_QPA_PLATFORM','offscreen')
os.environ.setdefault('QT_QUICK_BACKEND','software')
from pathlib import Path
from tempfile import TemporaryDirectory
from PySide6.QtCore import QObject,QUrl,QMetaObject,Q_ARG,QResource
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine,QQmlComponent
from PySide6.QtTest import QTest
app=QGuiApplication([]);app.setOrganizationName('NavoTest');app.setApplicationName('Environment')
repo=Path(__file__).resolve().parent.parent
engine=QQmlApplicationEngine();errors=[]
engine.warnings.connect(lambda ws:errors.extend(str(w) for w in ws if True))
with TemporaryDirectory() as directory:
 folder=Path(directory)
 qrc=folder/'icons.qrc';rcc=folder/'icons.rcc'
 qrc.write_text('<RCC><qresource prefix="/qml/NavoSmart/icons">'+''.join(f'<file alias="{p.name}">{p}</file>' for p in (repo/'custom/icons').glob('*.svg'))+'</qresource></RCC>')
 subprocess.run([str(Path(PySide6.__file__).parent/'Qt/libexec/rcc'),'--binary',str(qrc),'-o',str(rcc)],check=True)
 assert QResource.registerResource(str(rcc))
 p=folder/'Test.qml' 
 p.write_text('''import QtQuick
import QtQuick.Controls
import "'''+QUrl.fromLocalFile(str(repo/'custom/qml')).toString()+'''"
ApplicationWindow { visible:true; width:800; height:480
 NavoStatusDetails { objectName:"details"; viewportWidth:parent.width; viewportHeight:parent.height }
}''')
 engine.load(QUrl.fromLocalFile(str(p)));assert engine.rootObjects(),errors
 window=engine.rootObjects()[0];panel=window.findChild(QObject,'details')
 panel.setProperty('section','temperature')
 for width,height in [(320,240),(480,320),(800,480)]:
  window.setWidth(width);window.setHeight(height)
  panel.setProperty('viewportWidth',width);panel.setProperty('viewportHeight',height)
  QMetaObject.invokeMethod(panel,'open');QTest.qWait(50)
  assert panel.property('x')+panel.property('width')<=width
  assert panel.property('y')+panel.property('height')<=height
  status=window.findChild(QObject,'interiorSensorStatus');assert status
  for code,word in [(0,'Fără'),(1,'așteaptă'),(3,'eșuată'),(4,'incompatibil')]:
   panel.setProperty('interiorStatus',code);QTest.qWait(5);assert word in status.property('text')
  panel.setProperty('interiorValid',True);panel.setProperty('humidityRh',61.5);panel.setProperty('interiorTempC',24.5)
  QTest.qWait(5);assert 'LIVE' in status.property('text')
  panel.setProperty('interiorValid',False)
  QMetaObject.invokeMethod(panel,'close')
 c=QQmlComponent(engine,QUrl.fromLocalFile(str(repo/'custom/qml/NavoAlerts.qml')));alerts=c.create();assert alerts,c.errors()
 vehicle=QObject();alerts.setProperty('vehicle',vehicle);alerts.setProperty('linkHealthy',True);alerts.setProperty('gpsHealthy',True)
 raised=[];alerts.raised.connect(lambda key,text,critical:raised.append((key,critical)))
 def tick():QMetaObject.invokeMethod(alerts,'tick')
 alerts.setProperty('environmentValid',True);alerts.setProperty('humidityRh',90);alerts.setProperty('interiorTempC',50)
 tick();assert raised==[] # explicit opt in
 alerts.setProperty('environmentAlertsEnabled',True);tick();assert raised==[('humidity',False),('interior-temperature',False)]
 tick();assert len(raised)==2
 alerts.setProperty('environmentValid',False);tick();alerts.setProperty('environmentValid',True);tick();assert len(raised)==2
 alerts.setProperty('replayMode',True);tick();assert len(raised)==2
 alerts.setProperty('replayMode',False);alerts.setProperty('environmentAlertsEnabled',False);tick();assert len(raised)==2
 assert not errors,errors
 print('PASS SHT31 production diagnostics 320/480/800px; state text, opt-in alerts, dedup, invalid measurements, replay, mute')
