"""Optional real Qt 6.8.3 component smoke. Requires PySide6-Essentials, not HIL."""
import os
os.environ.setdefault('QT_QPA_PLATFORM','offscreen')
os.environ.setdefault('QT_QUICK_BACKEND','software')
from pathlib import Path
import tempfile, subprocess
import PySide6
from PySide6.QtCore import QUrl, QMetaObject, Q_RETURN_ARG, Q_ARG, QObject, QResource
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuick import QQuickWindow
from PySide6.QtTest import QTest
app=QGuiApplication([])
app.setOrganizationName("NAVO tests")
app.setOrganizationDomain("tests.navo.local")
app.setApplicationName("Route UI")
resourceDir=tempfile.TemporaryDirectory()
repo=Path(__file__).resolve().parent.parent
qrc=Path(resourceDir.name)/'icons.qrc'
qrc.write_text('<RCC><qresource prefix="/qml/NavoSmart/icons">'+''.join(f'<file alias="{p.name}">{p}</file>' for p in (repo/'custom/icons').glob('*.svg'))+'</qresource></RCC>')
rcc=Path(PySide6.__file__).parent/'Qt/libexec/rcc'
resource=Path(resourceDir.name)/'icons.rcc'
subprocess.run([str(rcc),'--binary',str(qrc),'-o',str(resource)],check=True)
assert QResource.registerResource(str(resource))
engine=QQmlApplicationEngine()
errors=[]
engine.warnings.connect(lambda warnings:errors.extend(str(w) for w in warnings))
engine.load(QUrl.fromLocalFile(str(Path(__file__).with_suffix('.qml').resolve())))
assert engine.rootObjects(),errors
window=engine.rootObjects()[0]
def invoke(name):
    return QMetaObject.invokeMethod(window,name,Q_RETURN_ARG('QVariant'))
assert invoke('seed')
assert invoke('exercise')
QTest.qWait(50)
assert invoke('complete')
assert invoke('libraryExercise')
library=window.findChild(QObject,'missionLibraryDialog');assert library
for width,height in [(320,600),(480,720),(900,600)]:
    window.setWidth(width);window.setHeight(height)
    QTest.qWait(150)
    image=window.grabWindow()
    assert not image.isNull()
    path=Path('/tmp')/f'navo-route-{width}.png'
    assert image.save(str(path))
    QMetaObject.invokeMethod(library,'open');QTest.qWait(80)
    assert library.property('visible') and library.property('width')<=width
    assert window.grabWindow().save(f'/tmp/navo-mission-library-{width}.png')
    QMetaObject.invokeMethod(library,'close')
popup=window.findChild(QObject,'navoRoutePopup')
assert popup
window.setWidth(320);window.setHeight(600)
QMetaObject.invokeMethod(popup,'open')
QTest.qWait(150)
assert popup.property('visible')
assert window.grabWindow().save('/tmp/navo-route-popup-320.png')
QMetaObject.invokeMethod(popup,'close')
assert not errors,errors
panel=window.findChild(QObject,'baitingPanel');assert panel
panel.setProperty('waypoint',{'name':'A very long fishing destination name that must truncate in a narrow baiting panel'})
panel.setProperty('visible',True);QTest.qWait(80)
target=panel.findChild(QObject,'baitingTargetLabel');assert target and target.property('truncated')
assert not errors,errors
print('PASS real Qt route sequencing, restart as draft, and panel render at 320/480/900 widths')
