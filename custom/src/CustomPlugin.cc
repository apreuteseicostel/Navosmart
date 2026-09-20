#include "CustomPlugin.h"
#include "NavoKoggerDecoder.h"
#include "NavoKoggerTcpClient.h"
#include "NavoPersistence.h"
#include "NavoEthernetTransport.h"
#include "NavoNanoTelemetry.h"
#include <QtQml/qqml.h>
#include <QtQml/QQmlApplicationEngine>
#include <QtCore/QFile>
#if QT_VERSION >= QT_VERSION_CHECK(6, 8, 0)
#include <QtCore/QApplicationStatic>
#endif
Q_APPLICATION_STATIC(CustomPlugin, _customPluginInstance);

CustomFlyViewOptions::CustomFlyViewOptions(CustomOptions* options,QObject* parent):QGCFlyViewOptions(options,parent){}
CustomPlugin::CustomPlugin(QObject* parent):QGCCorePlugin(parent),_options(new CustomOptions(this)){
 // The NAVO QML module is a static library. Force registration of its raw QML
 // resource collection so Android can resolve qrc:/qml/NavoSmart/qml/*.qml.
 Q_INIT_RESOURCE(NavoSmartModule_raw_qml_0);
 qmlRegisterType<NavoKoggerDecoder>("NavoSmart.Backend",1,0,"NavoKoggerDecoder");
 qmlRegisterType<NavoKoggerTcpClient>("NavoSmart.Backend",1,0,"NavoKoggerTcpClient");
 qmlRegisterType<NavoPersistence>("NavoSmart.Backend",1,0,"NavoPersistence");
 qmlRegisterType<NavoEthernetTransport>("NavoSmart.Backend",1,0,"NavoEthernetTransport");
 qmlRegisterType<NavoNanoTelemetry>("NavoSmart.Backend",1,0,"NavoNanoTelemetry");
}
CustomPlugin::~CustomPlugin(){}
QGCCorePlugin* CustomPlugin::instance(){ return _customPluginInstance(); }
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
  // QML_FILES are declared as qml/<file> under URI NavoSmart, so the
  // generated Qt resource keeps that qml/ directory below the module URI.
  if(url.path().endsWith("/FlyView.qml")) return QUrl("qrc:/qml/NavoSmart/qml/NavoDashboard.qml");
 }
 return url;
}