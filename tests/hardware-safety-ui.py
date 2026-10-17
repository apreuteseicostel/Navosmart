"""Load production safety/pre-launch objects and exercise Qt signal bindings."""
import os
os.environ.setdefault('QT_QPA_PLATFORM','offscreen')
from pathlib import Path
from PySide6.QtCore import QUrl,QMetaObject
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlComponent,QQmlEngine
app=QGuiApplication([]); engine=QQmlEngine(); errors=[]
engine.warnings.connect(lambda ws:errors.extend(str(w) for w in ws))
base=Path(__file__).resolve().parent.parent/'custom/qml'
c=QQmlComponent(engine,QUrl.fromLocalFile(str(base/'NavoSafetyManager.qml')))
s=c.create();assert s,c.errors()
s.setProperty('telemetryLive',True);s.setProperty('batteryTempC',60)
s.setProperty('waterSensorFault',True)
assert s.property('state')=='CRITICAL'
s.setProperty('batteryTempC',20);assert s.property('state')=='UNKNOWN'
s.setProperty('waterSensorFault',False);assert s.property('state')=='NORMAL'
s.setProperty('waterDetected',True);s.setProperty('waterValid',False)
assert not s.property('waterConfirmed') and s.property('state')=='UNKNOWN'
c2=QQmlComponent(engine,QUrl.fromLocalFile(str(base/'NavoPreLaunchCheck.qml')))
p=c2.create();assert p,c2.errors()
p.setProperty('sensorLabel','H743 / V3')
assert p.property('checks').toVariant()[4]['name']=='H743 / V3'
assert not errors,errors
print('PASS Qt safety bindings: independent hazards, invalid water, V3 pre-launch label')
