import os
os.environ.setdefault('QT_QPA_PLATFORM','offscreen');os.environ.setdefault('QT_QUICK_BACKEND','software')
from pathlib import Path
from PySide6.QtCore import QUrl,QMetaObject,Q_ARG,Q_RETURN_ARG,QObject
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlComponent,QQmlEngine
app=QGuiApplication([]);app.setOrganizationName('NavoTest');app.setApplicationName('Alerts')
repo=Path(__file__).resolve().parent.parent;engine=QQmlEngine();errors=[]
engine.warnings.connect(lambda ws:errors.extend(str(w) for w in ws))
component=QQmlComponent(engine,QUrl.fromLocalFile(str(repo/'custom/qml/NavoAlerts.qml')));root=component.create();assert root,component.errors()
fake=QQmlComponent(engine);fake.setData(b'''import QtQuick
QtObject {property var played:[];property int stops:0;property bool busy:false
 function play(sound,voice,text,critical){played=played.concat([{sound:sound,voice:voice,text:text,critical:critical}])}
 function stop(){stops++}
}''',QUrl());output=fake.create();root.setProperty('output',output)
vehicle=QObject();root.setProperty('vehicle',vehicle);root.setProperty('linkHealthy',True);root.setProperty('gpsHealthy',True);root.setProperty('batteryPercent',80)
def tick():QMetaObject.invokeMethod(root,'tick')
QMetaObject.invokeMethod(root,'configure',Q_ARG('QVariant',True),Q_ARG('QVariant',True),Q_ARG('QVariant',0.5));tick()
assert output.property('played').toVariant()==[]
root.setProperty('batteryPercent',19);tick();QMetaObject.invokeMethod(root,'dispatch');assert len(output.property('played').toVariant())==1
for _ in range(10):tick()
assert len(output.property('played').toVariant())==1
root.setProperty('batteryPercent',float('nan'));tick();root.setProperty('batteryPercent',18);tick();assert len(output.property('played').toVariant())==1
root.setProperty('replayMode',True);root.setProperty('linkHealthy',False);root.setProperty('telemetryConnected',True);root.setProperty('waterConfirmed',True);tick()
assert len(output.property('played').toVariant())==1 and output.property('stops')>=1
QMetaObject.invokeMethod(root,'configure',Q_ARG('QVariant',False),Q_ARG('QVariant',False),Q_ARG('QVariant',0.5))
root.setProperty('replayMode',False);tick();assert len(output.property('played').toVariant())==1
assert not errors,errors
# Parse actual platform audio and settings components; hardware audio is not claimed.
for name in ['NavoAlertAudio.qml','NavoAlertSettings.qml']:
 c=QQmlComponent(engine,QUrl.fromLocalFile(str(repo/'custom/qml'/name)));assert c.status()==QQmlComponent.Ready,c.errors()
print('PASS alert policies: threshold edge, deduplication, unknown measurement, replay suppression, mute; audio/settings QML compile')
