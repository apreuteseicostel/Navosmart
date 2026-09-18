#include "CustomPlugin.h"
#include "NavoKoggerDecoder.h"
#include "NavoEthernetTransport.h"
#include <QtQml/qqml.h>
#include <QtQml/QQmlApplicationEngine>
#include <QtCore/QFile>
CustomFlyViewOptions::CustomFlyViewOptions(CustomOptions* options,QObject* parent):QGCFlyViewOptions(options,parent){}
CustomPlugin::CustomPlugin(QObject* parent):QGCCorePlugin(parent),_options(new CustomOptions(this)){
 qmlRegisterType<NavoKoggerDecoder>("NavoSmart.Backend",1,0,"NavoKoggerDecoder");
 qmlRegisterType<NavoEthernetTransport>("NavoSmart.Backend",1,0,"NavoEthernetTransport");
}
CustomPlugin::~CustomPlugin(){}
QQmlApplicationEngine* CustomPlugin::createQmlApplicationEngine(QObject* parent){
 _engine=QGCCorePlugin::createQmlApplicationEngine(parent);
 _engine->addImportPath("qrc:/qml");
 _selector=new CustomOverrideInterceptor();
 _engine->addUrlInterceptor(_selector);
 return _engine;
}
void CustomPlugin::cleanup(){if(_engine&&_selector)_engine->removeUrlInterceptor(_selector);delete _selector;_selector=nullptr;}
QUrl CustomOverrideInterceptor::intercept(const QUrl& url,DataType type){
 if((type==DataType::QmlFile||type==DataType::UrlString)&&url.scheme()=="qrc"){
  // Replace QGC FlyView with NAVO SMART dashboard while retaining QGC backend.
  if(url.path().endsWith("/FlyView.qml")) return QUrl("qrc:/qml/NavoSmart/NavoDashboard.qml");
 }
 return url;
}
