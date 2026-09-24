#include "CustomPlugin.h"
#include "NavoKoggerDecoder.h"
#include "NavoKoggerTcpClient.h"
#include "NavoPersistence.h"
#include "NavoMissionBridge.h"
#include "NavoEthernetTransport.h"
#include "NavoNanoTelemetry.h"
#include "NavoBathymetryMesh.h"
#include "NavoBathymetryGeometry.h"
#include "NavoTrack3DGeometry.h"
#include "AppSettings.h"
#include "FactMetaData.h"
#include "QGCMAVLink.h"
#include <QtQml/qqml.h>
#include <QtQml/QQmlApplicationEngine>
#include <QtCore/QFile>
#if QT_VERSION >= QT_VERSION_CHECK(6, 8, 0)
#include <QtCore/QApplicationStatic>
#endif
Q_APPLICATION_STATIC(CustomPlugin, _customPluginInstance);

CustomFlyViewOptions::CustomFlyViewOptions(CustomOptions* options,QObject* parent):QGCFlyViewOptions(options,parent){}
CustomPlugin::CustomPlugin(QObject* parent):QGCCorePlugin(parent),_options(new CustomOptions(this)){
 qmlRegisterType<NavoKoggerDecoder>("NavoSmart.Backend",1,0,"NavoKoggerDecoder");
 qmlRegisterType<NavoKoggerTcpClient>("NavoSmart.Backend",1,0,"NavoKoggerTcpClient");
 qmlRegisterType<NavoPersistence>("NavoSmart.Backend",1,0,"NavoPersistence");
 qmlRegisterType<NavoMissionBridge>("NavoSmart.Backend",1,0,"NavoMissionBridge");
 qmlRegisterType<NavoEthernetTransport>("NavoSmart.Backend",1,0,"NavoEthernetTransport");
 qmlRegisterType<NavoNanoTelemetry>("NavoSmart.Backend",1,0,"NavoNanoTelemetry");
 qmlRegisterType<NavoBathymetryMesh>("NavoSmart.Backend",1,0,"NavoBathymetryMesh");
 qmlRegisterType<NavoBathymetryGeometry>("NavoSmart.Backend",1,0,"NavoBathymetryGeometry");
 qmlRegisterType<NavoTrack3DGeometry>("NavoSmart.Backend",1,0,"NavoTrack3DGeometry");
}
CustomPlugin::~CustomPlugin(){}
QGCCorePlugin* CustomPlugin::instance(){ return _customPluginInstance(); }
bool CustomPlugin::adjustSettingMetaData(const QString& settingsGroup, FactMetaData& metaData){
 bool visible=QGCCorePlugin::adjustSettingMetaData(settingsGroup,metaData);
 if(settingsGroup==AppSettings::settingsGroup){
  if(metaData.name()==AppSettings::offlineEditingFirmwareClassName) metaData.setRawDefaultValue(QGCMAVLink::FirmwareClassArduPilot);
  else if(metaData.name()==AppSettings::offlineEditingVehicleClassName) metaData.setRawDefaultValue(QGCMAVLink::VehicleClassRoverBoat);
 }
 return visible;
}
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