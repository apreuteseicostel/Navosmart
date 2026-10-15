"""Production journal UI; persistence tested by the compiled persistence suite."""
import os
os.environ.setdefault('QT_QPA_PLATFORM','offscreen');os.environ.setdefault('QT_QUICK_BACKEND','software')
from pathlib import Path
from PySide6.QtCore import QUrl,QObject,QMetaObject,Q_ARG,Q_RETURN_ARG
from PySide6.QtGui import QGuiApplication,QColor
from PySide6.QtQml import QQmlComponent
from PySide6.QtQuick import QQuickView
from PySide6.QtTest import QTest
app=QGuiApplication([]);repo=Path(__file__).resolve().parent.parent
view=QQuickView();view.setColor(QColor("#081522"));view.setResizeMode(QQuickView.SizeRootObjectToView);errors=[]
view.engine().warnings.connect(lambda ws:errors.extend(str(w) for w in ws))
view.setSource(QUrl.fromLocalFile(str(repo/'custom/qml/NavoFishingJournal.qml')))
assert view.status()==QQuickView.Ready,errors
root=view.rootObject();component=QQmlComponent(view.engine())
component.setData(b'''import QtQuick
QtObject {
 property var fishingTrips:[{id:"trip",lakeId:"lake",lakeName:"Lake",title:"Test",startedAt:"2026-10-15T00:00:00Z",endedAt:"",entries:[]}]
 property string journalError:""
 property var lastSaved:null
 property bool failSave:false
 function saveFishingEntry(id,data){if(failSave){journalError="Write failed";return ""}lastSaved=data;return "entry"}
}''',QUrl())
store=component.create();root.setProperty('persistence',store);root.setProperty('lakeId','lake');root.setProperty('selectedId','trip');root.setProperty('depthM',2.5)
view.show()
def begin(entry=None): return QMetaObject.invokeMethod(root,'beginEntry',Q_RETURN_ARG('QVariant'),Q_ARG('QVariant',entry))
for w in [236,320,900]:
 view.resize(w,600);assert begin();QTest.qWait(30)
 editor=root.findChild(QObject,'journalEntryEditor');assert editor.property('visible');assert editor.property('width')<=w
 root.setProperty('depthM',9.0)
 text=root.findChild(QObject,'journalEntryText');text.setProperty('text','Prag observat')
 assert QMetaObject.invokeMethod(root,'saveEntry',Q_RETURN_ARG('QVariant'))
 saved=store.property('lastSaved').toVariant();assert saved['depth']==(2.5 if w==236 else 9.0) and not saved['positionValid'] and 'lat' not in saved
 assert view.grabWindow().save(f'/tmp/navo-journal-{w}.png')
assert begin();store.setProperty('failSave',True);text.setProperty('text','retry')
assert not QMetaObject.invokeMethod(root,'saveEntry',Q_RETURN_ARG('QVariant'));assert editor.property('visible')
root.setProperty('replayMode',True);QTest.qWait(10);assert not editor.property('visible') and not begin()
root.setProperty('replayMode',False);root.setProperty('lakeId','other');assert not begin()
assert not errors,errors
print('PASS journal UI: frozen context, unknown GPS, replay/lake gates, failed save retention, 236/320/900px')
