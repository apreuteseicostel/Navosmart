"""Production journal UI; persistence tested by the compiled persistence suite."""
import os
os.environ.setdefault('QT_QPA_PLATFORM','offscreen');os.environ.setdefault('QT_QUICK_BACKEND','software')
from pathlib import Path
from PySide6.QtCore import QUrl,QObject,QMetaObject,Q_ARG,Q_RETURN_ARG,QPointF
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
# Structured catch form uses decimal comma, supports unknown weight and keeps Save visible.
for w in [236,320,900]:
 view.resize(w,600);assert begin();QTest.qWait(30)
 kind=root.findChild(QObject,'journalEntryType');kind.setProperty('currentIndex',1)
 root.findChild(QObject,'journalSpecies').setProperty('text','Carp')
 weight=root.findChild(QObject,'journalWeight');weight.setProperty('text','2,375')
 root.findChild(QObject,'journalBait').setProperty('text','Corn')
 text.setProperty('text','Released')
 QTest.qWait(30);assert root.property('weightValid')
 saveButton=root.findChild(QObject,'journalEntrySave');corner=saveButton.mapToScene(QPointF(0,0))
 assert 0<=corner.x() and corner.x()+saveButton.property('width')<=w and corner.y()+saveButton.property('height')<=600
 assert view.grabWindow().save(f'/tmp/navo-journal-catch-{w}.png')
 assert QMetaObject.invokeMethod(root,'saveEntry',Q_RETURN_ARG('QVariant'))
 saved=store.property('lastSaved').toVariant();assert saved['species']=='Carp' and saved['weightKg']==2.375 and saved['bait']=='Corn'
assert begin();kind.setProperty('currentIndex',1);text.setProperty('text','Invalid weight')
for bad in ['-1','0','1001','abc','2,3.4','2e1','2.1234']:
 weight.setProperty('text',bad);QTest.qWait(10)
 assert not root.property('weightValid')
 assert not root.findChild(QObject,'journalEntrySave').property('enabled')
 assert not QMetaObject.invokeMethod(root,'saveEntry',Q_RETURN_ARG('QVariant'))
weight.setProperty('text','');assert root.property('weightValid')
assert QMetaObject.invokeMethod(root,'saveEntry',Q_RETURN_ARG('QVariant'))
assert store.property('lastSaved').toVariant()['weightKg'] is None
# Mixed legacy/structured rows: unknown/string weights excluded from totals; filters do not change summary.
entries=[{'id':'a','type':'catch','text':'Released','weightKg':2.375,'species':'Carp'},
 {'id':'b','type':'catch','text':'Legacy, 9kg mentioned'}, {'id':'c','type':'catch','text':'Bad weight','weightKg':'5'},
 {'id':'d','type':'catch','text':'Small','weightKg':.625},{'id':'e','type':'bait','text':'Corn'},{'id':'f','type':'note','text':'Wind'}]
store.setProperty('fishingTrips',[{'id':'trip','lakeId':'lake','lakeName':'Lake','title':'Test','startedAt':'2026-10-15T00:00:00Z','endedAt':'2026-10-15T02:30:00Z','entries':entries}]);QTest.qWait(20)
summary=root.property('summary').toVariant();assert summary=={'catches':4,'bait':1,'notes':1,'weighed':2,'totalKg':3,'maxKg':2.375,'minutes':150},summary
filterControl=root.findChild(QObject,'journalEntryFilter');listing=root.findChild(QObject,'journalEntries')
for index,count in [(0,6),(1,4),(2,1),(3,1)]:
 filterControl.setProperty('currentIndex',index);QTest.qWait(20);assert listing.property('count')==count
 assert root.property('summary').toVariant()==summary
# Moving to another trip closes the editor and refuses a stale save.
legacy={'id':'a','type':'catch','text':'Released','weightKg':2.375,'species':'Carp'}
assert begin(legacy);root.setProperty('selectedId','missing');QTest.qWait(20)
assert not editor.property('visible') and not QMetaObject.invokeMethod(root,'saveEntry',Q_RETURN_ARG('QVariant'))
root.setProperty('selectedId','trip')
store.setProperty('fishingTrips',[{'id':'trip','lakeId':'lake','lakeName':'Lake','title':'Test','startedAt':'2026-10-15T00:00:00Z','endedAt':'','entries':[]}])
assert begin();store.setProperty('failSave',True);text.setProperty('text','retry')
assert not QMetaObject.invokeMethod(root,'saveEntry',Q_RETURN_ARG('QVariant'));assert editor.property('visible')
root.setProperty('replayMode',True);QTest.qWait(10);assert not editor.property('visible') and not begin()
root.setProperty('replayMode',False);root.setProperty('lakeId','other');assert not begin()
assert not errors,errors
print('PASS journal UI: structured catch fields, decimal/unknown/invalid weights, summary/filter, frozen context, replay/lake/trip gates, failed saves and 236/320/900px')
