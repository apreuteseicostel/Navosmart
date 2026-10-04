// Measures the production Canvas with full-resolution input. Desktop software
// timing is comparative evidence, not Android/G20 FPS certification.
#include <QGuiApplication>
#include <QQuickView>
#include <QQuickItem>
#include <QQmlEngine>
#include <QQmlContext>
#include <QQmlExpression>
#include <QEventLoop>
#include <QElapsedTimer>
#include <QTimer>
#include <QJsonDocument>
#include <QJsonArray>
#include <QFile>
#include <algorithm>
#include <iostream>
#include <stdexcept>
static QStringList errors;
static void message(QtMsgType,const QMessageLogContext&,const QString& s){if(s.contains("TypeError")||s.contains("ReferenceError")||s.contains("Cannot anchor")||s.contains("Binding loop")||s.contains("managed by a layout")||s.contains("Unable to assign"))errors<<s;std::cerr<<s.toStdString()<<'\n';}
static void require(bool ok,const char* text){if(!ok)throw std::runtime_error(text);}
int main(int argc,char** argv){
 qputenv("QT_QPA_PLATFORM","offscreen");qputenv("QT_QUICK_BACKEND","software");
 QGuiApplication app(argc,argv);qInstallMessageHandler(message);
 try{
 require(argc>=3,"usage: sonar-performance source.qml mock-imports [columns.json]");
 QQuickView view;view.engine()->addImportPath(argv[2]);view.setResizeMode(QQuickView::SizeRootObjectToView);view.resize(960,540);view.setSource(QUrl::fromLocalFile(argv[1]));require(view.status()==QQuickView::Ready,"QML load failed");auto* root=view.rootObject();
 auto evaluate=[&](const QString& s){QQmlExpression x(view.engine()->rootContext(),root,s);auto v=x.evaluate();if(x.hasError())throw std::runtime_error(x.error().toString().toStdString());return v;};
 root->setProperty("connected",true);root->setProperty("chartOffsetMeters",0);root->setProperty("chartRangeMeters",50);
 if(argc==4){QFile f(argv[3]);require(f.open(QIODevice::ReadOnly),"fixture missing");root->setProperty("history",QJsonDocument::fromJson(f.readAll()).array().toVariantList());evaluate("history=Array.from(history,function(e){return {samples:Array.from(e.samples),offset:e.offset,range:e.range,bottom:e.bottom,sequence:e.sequence}})");}
 else evaluate("(function(){var h=[];for(var c=0;c<240;c++){var s=[];for(var i=0;i<5000;i++)s.push(((i*37+c*11)%256)/255);h.push({samples:s,offset:0,range:50,bottom:35,sequence:c+1})}history=h})()");
 evaluate("samples=history[history.length-1].samples");
 auto* canvas=root->findChild<QObject*>("sonarProEchogram");require(canvas,"Canvas object missing");
 view.show();QEventLoop setup;QTimer::singleShot(1800,&setup,&QEventLoop::quit);setup.exec();
 for(const char* name:{"sonarProMenuButton","sonarProCloseButton"}){
 auto* control=root->findChild<QQuickItem*>(name);require(control&&control->isVisible()&&control->isEnabled(),"PRO control unavailable");auto pos=control->mapToScene(QPointF(control->width()/2,control->height()/2));require(pos.x()>0&&pos.y()>0&&pos.x()<view.width()&&pos.y()<view.height(),"PRO control off screen");}
 require(errors.isEmpty(),errors.join('\n').toUtf8().constData());
 std::vector<double> times;
 for(int n=0;n<24;n++){
 QEventLoop loop;bool painted=false;QObject::connect(canvas,SIGNAL(painted()),&loop,SLOT(quit()));
 QTimer timeout;timeout.setSingleShot(true);QObject::connect(&timeout,&QTimer::timeout,&loop,&QEventLoop::quit);timeout.start(10000);
 QElapsedTimer clock;clock.start();evaluate("pushHistory()");loop.exec();painted=timeout.isActive();require(painted,"Canvas paint timed out");times.push_back(clock.nsecsElapsed()/1e6);
 }
 { QEventLoop loop; QObject::connect(canvas,SIGNAL(painted()),&loop,SLOT(quit())); QTimer timeout;timeout.setSingleShot(true);QObject::connect(&timeout,&QTimer::timeout,&loop,&QEventLoop::quit);timeout.start(10000);QElapsedTimer clock;clock.start();evaluate("gain=1.07; repaint()");loop.exec();require(timeout.isActive(),"settings paint timed out");std::cout<<"PERF gain_change_ms="<<clock.nsecsElapsed()/1e6<<"\n"; }
 std::sort(times.begin(),times.end());std::cout<<"PERF paint_ms median="<<times[times.size()/2]<<" p95="<<times[22]<<" max="<<times.back()<<" columns=240 samples_per_column=5000 viewport=960x540 software\n";
 require(view.grabWindow().save("sonar-performance.png"),"screenshot failed");
 if(root->metaObject()->indexOfMethod("displayRaster(QVariant,QVariant)")>=0 || evaluate("typeof displayRaster==='function'").toBool()){
 require(evaluate("history.length===240 && history[0].samples.length===5000 && rasterCache.length<=historyColumns").toBool(),"raw history/cache bound regression");
 require(evaluate("(function(){noiseFloor=0;gain=1;noiseFilterEnabled=false;var e={samples:[0,.95,0,0],offset:0,range:4};history=[e];var a=displayRaster(e,1);if(a.strengths[0]<.94||a.bins[0]!==4||displayRaster(e,1)!==a)return false;noiseFilterEnabled=true;var b=displayRaster(e,1);if(b.strengths[0]!==0)return false;noiseFilterEnabled=false;var base=displayRaster(e,1);gain=.1;var c=displayRaster(e,1);if(c.strengths[0]>.10||c.peaks!==base.peaks)return false;gain=1;var shifted={samples:[1,1],offset:8,range:2};return displayRaster(shifted,4).bins.every(function(v){return v===0})})()").toBool(),"peak/filter/gain/cache/physical crop regression");
 std::cout<<"PASS display peak preservation, raw sample retention, filter/gain invalidation, cache reuse and physical crop\n";
 }
 if(root->metaObject()->indexOfProperty("replayMode")>=0){
 evaluate(R"QML(vehicle=Qt.createQmlObject('import QtQuick; QtObject {property var coordinate:({latitude:52,longitude:0,isValid:true});property var heading:({rawValue:0})}',this); chartSource=Qt.createQmlObject('import QtQuick; QtObject {property bool replayMode:true;property bool replayActive:false;property bool replayPaused:false;property real replaySpeed:1;signal echoSamplesChanged();signal bottomColumnReady(int sequence,real depth)}',this); boatTrack=[];plannedTrack=[{latitude:52,longitude:0,isValid:true}];mapEnabled=true)QML");
 QEventLoop map;QTimer::singleShot(100,&map,&QEventLoop::quit);map.exec();auto* marker=root->findChild<QQuickItem*>("sonarProBoatMarker");auto* planned=root->findChild<QObject*>("sonarProPlannedTrack");require(marker&&!marker->isVisible(),"Replay without GPS displays connected live boat");require(planned&&planned->property("path").toList().isEmpty(),"Replay displays live mission route");
 evaluate("boatTrack=[{latitude:51,longitude:1,isValid:true}]");QEventLoop update;QTimer::singleShot(100,&update,&QEventLoop::quit);update.exec();require(marker->isVisible(),"Recorded boat marker missing");require(errors.isEmpty(),errors.join('\n').toUtf8().constData());std::cout<<"PASS PRO replay map excludes live boat without recorded GPS and live mission route\n";
 }
 }catch(const std::exception& e){std::cerr<<e.what()<<'\n';return 1;}
}
