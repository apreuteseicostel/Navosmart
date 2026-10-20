import os
os.environ.setdefault('QT_QPA_PLATFORM','offscreen');os.environ.setdefault('QT_QUICK_BACKEND','software')
from pathlib import Path
from PySide6.QtCore import QUrl,QObject,QMetaObject,Q_ARG,Q_RETURN_ARG,QAbstractListModel,QModelIndex,Qt,Property,Signal,Slot
from PySide6.QtGui import QGuiApplication,QColor
from PySide6.QtQml import QQmlComponent
from PySide6.QtQuick import QQuickView
from PySide6.QtTest import QTest
class Sets(QAbstractListModel):
 countChanged=Signal()
 def __init__(self):super().__init__();self.items=[]
 def rowCount(self,parent=QModelIndex()):return len(self.items)
 def roleNames(self):return {int(Qt.UserRole):b'object'}
 def data(self,index,role):return self.items[index.row()] if index.isValid() and role==int(Qt.UserRole) else None
 @Property(int,notify=countChanged)
 def count(self):return len(self.items)
 @Slot(int,result=QObject)
 def get(self,index):return self.items[index]
 @Slot(QObject)
 def append(self,item):
  self.beginInsertRows(QModelIndex(),len(self.items),len(self.items));self.items.append(item);self.endInsertRows();self.countChanged.emit()
 @Slot()
 def clear(self):self.beginResetModel();self.items=[];self.endResetModel();self.countChanged.emit()
app=QGuiApplication([]);repo=Path(__file__).resolve().parent.parent
view=QQuickView();view.setColor(QColor("#081522"));view.setResizeMode(QQuickView.SizeRootObjectToView);errors=[]
view.engine().warnings.connect(lambda ws:errors.extend(str(w) for w in ws))
view.setSource(QUrl.fromLocalFile(str(repo/'custom/qml/NavoOfflineMaps.qml')))
assert view.status()==QQuickView.Ready,errors
root=view.rootObject();component=QQmlComponent(view.engine())
component.setData(b'''import QtQuick
Item {
 id:mockRoot
 property alias manager:backend
 property var sets:null
 QtObject {
  id:tile;property string name:"Lake";property string mapTypeStr:"Google Satellite"
  property bool defaultSet:false;property bool complete:false;property bool downloading:true;property bool deleting:false
  property int minZoom:13;property int maxZoom:17;property int totalTileCount:100;property int savedTileCount:50;property int errorCount:0
  property real topleftLon:0;property real topleftLat:52;property real bottomRightLon:0.1;property real bottomRightLat:51.9
  function cancelDownloadTask(){downloading=false}
  function resumeDownloadTask(){downloading=true}
 }
 QtObject {
  id:backend;property var tileSets:mockRoot.sets;property var mapList:["Google Satellite"]
  property int tileCount:100;property string tileCountStr:"100";property string tileSizeStr:"1MiB"
  property bool fetchElevation:true;property string errorMessage:"";property var lastBounds:null
  function loadTileSets(){}
  function findName(name){for(var i=0;i<tileSets.count;i++)if(tileSets.get(i).name===name)return true;return false}
  function updateForCurrentView(w,n,e,s,min,max,type){lastBounds=[w,n,e,s,min,max,type]}
  function startDownload(name,type){tile.name=name;tileSets.append(tile)}
  function deleteTileSet(t){tileSets.clear()}
 }
}''',QUrl())
mock=component.create();assert mock,component.errors();sets=Sets();mock.setProperty('sets',sets);manager=mock.property('manager');root.setProperty('manager',manager)
root.setProperty('region',{'west':0,'east':0.1,'north':52,'south':51.9,'zoom':16,'mapType':'Google Satellite'})
view.show();QTest.qWait(50);assert root.property('ready')
name=root.findChild(QObject,'offlineSetName');name.setProperty('text','Lake')
assert QMetaObject.invokeMethod(root,'beginDownload',Q_RETURN_ARG('QVariant'));QTest.qWait(400)
assert root.property('pendingName')=='';assert not QMetaObject.invokeMethod(root,'beginDownload',Q_RETURN_ARG('QVariant'))
for w in [236,320,900]:
 view.resize(w,600);QTest.qWait(30);assert view.grabWindow().save(f'/tmp/navo-offline-{w}.png')
manager.setProperty('tileCount',5001);assert not root.property('ready')
root.setProperty('region',{'west':170,'east':-170,'north':52,'south':51.9});assert not root.property('validRegion') and not root.property('ready')
assert not errors,errors
print('PASS offline UI: actual manager API double, region/limit guards, duplicate names, asynchronous creation, 236/320/900px')
