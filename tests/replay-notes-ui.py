"""Production replay note dialogs with an explicit backend double; native persistence is tested in recording.cpp."""
import os
os.environ.setdefault('QT_QPA_PLATFORM','offscreen')
os.environ.setdefault('QT_QUICK_BACKEND','software')
from pathlib import Path
from PySide6.QtCore import QUrl,QObject,QMetaObject,Q_ARG,Q_RETURN_ARG
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlComponent
from PySide6.QtQuick import QQuickView
from PySide6.QtTest import QTest
app=QGuiApplication([]);repo=Path(__file__).resolve().parent.parent
view=QQuickView();view.setResizeMode(QQuickView.SizeRootObjectToView);errors=[]
view.engine().warnings.connect(lambda ws:errors.extend(str(w) for w in ws))
view.setSource(QUrl.fromLocalFile(str(repo/'custom/qml/NavoReplayNotes.qml')))
assert view.status()==QQuickView.Ready,errors
root=view.rootObject();component=QQmlComponent(view.engine())
component.setData(b'''import QtQuick
QtObject {
 property bool replayMode:true
 property bool replayActive:true
 property bool replayPaused:false
 property var replayAnnotationAnchor:({source:"first",frame:8,milliseconds:1200,latitude:52,longitude:0})
 property var replayAnnotations:[]
 property string replayAnnotationError:""
 property bool failSave:false
 property var lastSaved:null
 function pauseReplay(value){replayPaused=value}
 function saveReplayAnnotation(anchor,text,depth,temp){
  if(failSave){replayAnnotationError="Test write failure";return false}
  lastSaved={anchor:anchor,text:text,depth:depth,temp:temp}
  replayAnnotations=[{source:anchor.source,id:"note",frame:anchor.frame,milliseconds:anchor.milliseconds,latitude:anchor.latitude,longitude:anchor.longitude,text:text,depth:depth,temperature:temp}];return true
 }
 function editReplayAnnotation(id,text){var next=replayAnnotations.slice();next[0]=Object.assign({},next[0],{text:text});replayAnnotations=next;return true}
 function removeReplayAnnotation(id){replayAnnotations=[];return true}
}''',QUrl())
source=component.create();assert source,component.errors();root.setProperty('source',source)
view.show();editor=root.findChild(QObject,'replayNoteEditor');catalog=root.findChild(QObject,'replayNotesCatalog');text=root.findChild(QObject,'replayNoteText')
column={'replay':True,'replayAnchor':{'source':'first','frame':7,'milliseconds':1000,'latitude':52,'longitude':0},'bottom':2.4,'temp':18}
def begin(c=column):return QMetaObject.invokeMethod(root,'begin',Q_RETURN_ARG('QVariant'),Q_ARG('QVariant',c))
for width,height in [(236,600),(320,600),(900,600)]:
 view.resize(width,height);root.setProperty('viewWidth',width);root.setProperty('viewHeight',height)
 assert begin();QTest.qWait(50)
 assert editor.property('visible') and source.property('replayPaused')
 assert editor.property('width')<=width and editor.property('height')<=height
 assert view.grabWindow().save(f'/tmp/navo-replay-note-{width}.png')
 text.setProperty('text','Prag observat')
 assert QMetaObject.invokeMethod(root,'save',Q_RETURN_ARG('QVariant'));QTest.qWait(30)
 assert not editor.property('visible') and not source.property('replayPaused')
 saved=source.property('lastSaved').toVariant();assert saved['anchor']['frame']==7 and saved['anchor']['milliseconds']==1000 and saved['depth']==2.4
 QMetaObject.invokeMethod(root,'showNotes');QTest.qWait(30)
 assert catalog.property('visible') and root.findChild(QObject,'replayNotesList').property('count')==1
 QMetaObject.invokeMethod(catalog,'close')
# Edit and confirmed deletion use the production handlers.
note=source.property('replayAnnotations').toVariant()[0]
QMetaObject.invokeMethod(root,'edit',Q_ARG('QVariant',note));QTest.qWait(20)
assert editor.property('visible') and root.property('editingId')=='note'
text.setProperty('text','Prag revizuit');assert QMetaObject.invokeMethod(root,'save',Q_RETURN_ARG('QVariant'))
assert source.property('replayAnnotations').toVariant()[0]['text']=='Prag revizuit'
delete=root.findChild(QObject,'replayNoteDeleteConfirm');delete.setProperty('noteId','note')
QMetaObject.invokeMethod(delete,'accepted');assert source.property('replayAnnotations').toVariant()==[]
# Already-paused replay stays paused; failed save retains the editor and captured column.
source.setProperty('replayPaused',True);assert begin();source.setProperty('failSave',True);text.setProperty('text','Another note')
assert not QMetaObject.invokeMethod(root,'save',Q_RETURN_ARG('QVariant'))
assert editor.property('visible') and source.property('replayPaused')
source.setProperty('failSave',False);QMetaObject.invokeMethod(editor,'close');assert source.property('replayPaused')
assert not begin({'replay':False})
assert not begin({'replay':True,'replayAnchor':{'source':'other','frame':1}})
assert begin();source.setProperty('replayAnnotationAnchor',{'source':'second','frame':1});QTest.qWait(30)
assert not editor.property('visible')
source.setProperty('replayMode',False);assert not begin()
root.setProperty('source',None);QTest.qWait(30);assert not errors,errors
print('PASS replay notes UI: responsive editor/catalog, frozen column, pause restoration, failed save retention and source/live guards')
