// Load the production coordinator wiring and basic Popup with real Qt/QML.
#include <QGuiApplication>
#include <QQuickView>
#include <QQuickItem>
#include <QQmlComponent>
#include <QQmlEngine>
#include <QFile>
#include <QFileInfo>
#include <QEventLoop>
#include <QTimer>
#include <QVector2D>
#include <cmath>
#include <iostream>
#include <stdexcept>
static QStringList errors;
static void message(QtMsgType,const QMessageLogContext&,const QString& s){if(s.contains("TypeError")||s.contains("ReferenceError")||s.contains("managed by a layout")||s.contains("Binding loop")||s.contains("Unable to assign"))errors<<s;std::cerr<<s.toStdString()<<'\n';}
static void require(bool ok,const char* s){if(!ok)throw std::runtime_error(s);}
int main(int argc,char** argv){qputenv("QT_QPA_PLATFORM","offscreen");qputenv("QT_QUICK_BACKEND","software");QGuiApplication app(argc,argv);qInstallMessageHandler(message);
 try{require(argc>=3,"usage: page-wiring Dashboard.qml mock-imports [qml-directory]");QFile f(argv[1]);require(f.open(QIODevice::ReadOnly),"Dashboard missing");QString source=QString::fromUtf8(f.readAll());QString dir=argc>3?QString::fromLocal8Bit(argv[3]):QFileInfo(f).absolutePath();int begin=source.indexOf("    NavoScanCoordinator {"),end=source.indexOf("    property alias areaCoordinator:",begin);require(begin>=0&&end>begin,"coordinator block missing");QString block=source.mid(begin,end-begin);block.replace("NavoScanCoordinator {","Navo.NavoScanCoordinator {");QString aliases;for(const auto& line:source.split('\n'))if(line.contains("property alias lakePersistence:")||line.contains("property alias fishingSpotsController:")||line.contains("property alias fishStoreController:")||line.contains("property alias sonarMappingController:")||line.contains("property alias hopperBridgeController:")||line.contains("property alias sonarController:")||line.contains("readonly property var mapBaitingController:")||line.contains("readonly property var mapAreaScanController:"))aliases+=line+'\n';
 QString imports="import QtQuick\nimport \""+QUrl::fromLocalFile(dir).toString()+"\" as Navo\n";
 QString wrapper=imports+R"QML(Item { id:root
 property var vehicle:null
 property string lastNavigationStatus:""
 QtObject { id:persistence }
 QtObject { id:fishingSpots; property var fishingSpots:[] }
 QtObject { id:fishStore }
 QtObject { id:sonarMapping }
 QtObject { id:bathymetryModel }
 QtObject { id:areaScanController; signal safetyActionRequested(string action,string reason) }
 QtObject { id:baitingController }
 QtObject { id:hopperBridge }
 QtObject { id:sonar; property bool replayMode:false }
)QML"+aliases+block+R"QML(function replayBinding(){sonar.replayMode=true;return scanCoordinator.readOnlyReplay}
function validate(){ return scanCoordinator.persistence===persistence && scanCoordinator.fishingSpots===fishingSpots && scanCoordinator.fishStore===fishStore && scanCoordinator.sonarMapping===sonarMapping && scanCoordinator.bathymetry===bathymetryModel && scanCoordinator.areaScan===areaScanController && root.hopperBridgeController===hopperBridge && root.sonarController===sonar && root.mapBaitingController===baitingController && root.mapAreaScanController===areaScanController }
})QML";
 QQmlEngine engine;engine.addImportPath(argv[2]);QQmlComponent coordinator(&engine);coordinator.setData(wrapper.toUtf8(),QUrl::fromLocalFile(dir+"/DashboardWiringTest.qml"));require(coordinator.isReady(),coordinator.errorString().toUtf8().constData());QObject* object=coordinator.create();require(object,"wiring load failed");QVariant result;require(QMetaObject::invokeMethod(object,"validate",Q_RETURN_ARG(QVariant,result))&&result.toBool(),"Dashboard controller references are not connected");require(QMetaObject::invokeMethod(object,"replayBinding",Q_RETURN_ARG(QVariant,result))&&result.toBool(),"Replay edit gate is not connected");delete object;
 QFile gestures(dir+"/NavoBathymetry3D.qml");require(gestures.open(QIODevice::ReadOnly),"3D gesture source missing");QString gs=QString::fromUtf8(gestures.readAll());int hs=gs.indexOf(" // Evaluate cumulative gesture"),he=gs.indexOf(" function localPoint(",hs),ps=gs.indexOf(" DragHandler{"),pe=gs.indexOf(" ColumnLayout{",ps);require(hs>=0&&he>hs&&ps>=0&&pe>ps,"3D handlers missing");
 QQmlComponent gesture(&engine);gesture.setData(("import QtQuick\nItem {id:root;property real yaw:-35;property real pitch:-48;property real cameraDistance:180;"+gs.mid(hs,he-hs)+gs.mid(ps,pe-ps)+"}").toUtf8(),QUrl());require(gesture.isReady(),gesture.errorString().toUtf8().constData());auto* g=gesture.create();require(g,"gesture creation failed");auto* orbit=g->findChild<QObject*>("bathymetryOrbit");auto* zoom=g->findChild<QObject*>("bathymetryZoom");require(orbit&&zoom,"gesture handlers unavailable");
 auto orbitStep=[&](double x,double y){QVariant result;return QMetaObject::invokeMethod(g,"orbitCameraGesture",Q_RETURN_ARG(QVariant,result),Q_ARG(QVariant,QVariant(-35)),Q_ARG(QVariant,QVariant(-48)),Q_ARG(QVariant,QVariant(x)),Q_ARG(QVariant,QVariant(y)))&&result.toBool();};
 for(const auto& value:{QVector2D(5,2),QVector2D(10,4),QVector2D(20,8)})require(orbitStep(value.x(),value.y()),"orbit update failed");require(std::abs(g->property("yaw").toDouble()+31.4)<.0001&&std::abs(g->property("pitch").toDouble()+49.12)<.0001,"3D orbit compounds cumulative drag");
 auto zoomStep=[&](double scale){QVariant result;return QMetaObject::invokeMethod(g,"zoomCameraGesture",Q_RETURN_ARG(QVariant,result),Q_ARG(QVariant,QVariant(180)),Q_ARG(QVariant,QVariant(1)),Q_ARG(QVariant,QVariant(scale)))&&result.toBool();};
 for(double scale:{1.2,1.5})require(zoomStep(scale),"zoom update failed");require(std::abs(g->property("cameraDistance").toDouble()-120)<.0001,"3D zoom compounds cumulative scale");require(!zoomStep(0)&&g->property("cameraDistance").toDouble()==120,"invalid zoom corrupted camera");require(zoomStep(100)&&g->property("cameraDistance").toDouble()==12,"near zoom limit failed");require(zoomStep(.001)&&g->property("cameraDistance").toDouble()==1800,"far zoom limit failed");delete g;std::cout<<"PASS production 3D handler loading, gesture snapshots and bounded zoom\n";
 QQuickView view;view.engine()->addImportPath(argv[2]);QQmlComponent popup(view.engine());popup.setData((imports+"Item { width:960; height:540; Navo.NavoSonarFullScreen { id:popup } function openPopup(){popup.open()} }").toUtf8(),QUrl::fromLocalFile(dir+"/BasicPopupTest.qml"));require(popup.isReady(),popup.errorString().toUtf8().constData());QObject* item=popup.create();require(item,"Popup creation failed");view.setResizeMode(QQuickView::SizeRootObjectToView);view.resize(960,540);view.setContent(QUrl(),&popup,item);view.show();require(QMetaObject::invokeMethod(item,"openPopup"),"Popup open failed");QEventLoop loop;QTimer::singleShot(500,&loop,&QEventLoop::quit);loop.exec();auto* close=item->findChild<QQuickItem*>("basicSonarClose");require(close&&close->isVisible(),"basic sonar close control unavailable");auto position=close->mapToScene(QPointF(close->width()/2,close->height()/2));require(position.x()>0&&position.y()>0&&position.x()<view.width()&&position.y()<view.height(),"basic sonar close control off screen");require(errors.isEmpty(),errors.join('\n').toUtf8().constData());require(view.grabWindow().save("sonar-basic-popup.png"),"Popup screenshot failed");std::cout<<"PASS production Dashboard coordinator/controllers, basic Popup layout and reachable close control\n";
 }catch(const std::exception& e){std::cerr<<e.what()<<'\n';return 1;} }
