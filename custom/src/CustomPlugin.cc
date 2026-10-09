#include "CustomPlugin.h"
#include "NavoKoggerDecoder.h"
#include "NavoKoggerReplay.h"
#include "NavoKoggerRecorder.h"
#include "NavoKoggerChartBridge.h"
#include "NavoKoggerTcpClient.h"
#include "NavoPersistence.h"
#include "NavoMissionBridge.h"
#include "NavoEthernetTransport.h"
#include "NavoLanDiscovery.h"
#include "NavoNanoTelemetry.h"
#include "NavoBathymetryMesh.h"
#include "NavoBathymetryGeometry.h"
#include "NavoTrack3DGeometry.h"
#include "NavoAndroidAcceptance.h"
#include <QQmlContext>
#include "AppSettings.h"
#include "UnitsSettings.h"
#include <QSettings>
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
 // NAVO uses metres and Celsius on first install. Existing unit preferences
 // are preserved and remain editable in Settings without a blocking prompt.
 QSettings units;
 units.beginGroup("Units");
 const QVariantMap defaults{{"horizontalDistanceUnits",UnitsSettings::HorizontalDistanceUnitsMeters},
                            {"verticalDistanceUnits",UnitsSettings::VerticalDistanceUnitsMeters},
                            {"areaUnits",UnitsSettings::AreaUnitsSquareMeters},
                            {"speedUnits",UnitsSettings::SpeedUnitsMetersPerSecond},
                            {"temperatureUnits",UnitsSettings::TemperatureUnitsCelsius}};
 for(auto it=defaults.cbegin();it!=defaults.cend();++it)if(!units.contains(it.key()))units.setValue(it.key(),it.value());
 units.endGroup();units.sync();
 qmlRegisterType<NavoKoggerRecorder>("NavoSmart.Backend",1,0,"NavoKoggerRecorder");
 qmlRegisterType<NavoKoggerReplay>("NavoSmart.Backend",1,0,"NavoKoggerReplay");
 qmlRegisterType<NavoKoggerDecoder>("NavoSmart.Backend",1,0,"NavoKoggerDecoder");
 qmlRegisterType<NavoKoggerChartBridge>("NavoSmart.Backend",1,0,"NavoKoggerChartBridge");
 qmlRegisterType<NavoKoggerTcpClient>("NavoSmart.Backend",1,0,"NavoKoggerTcpClient");
 qmlRegisterType<NavoPersistence>("NavoSmart.Backend",1,0,"NavoPersistence");
 qmlRegisterType<NavoMissionBridge>("NavoSmart.Backend",1,0,"NavoMissionBridge");
 qmlRegisterType<NavoEthernetTransport>("NavoSmart.Backend",1,0,"NavoEthernetTransport");
 qmlRegisterType<NavoLanDiscovery>("NavoSmart.Backend",1,0,"NavoLanDiscovery");
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
#ifdef NAVO_ANDROID_ACCEPTANCE
 _engine->rootContext()->setContextProperty("navoAcceptance",new NavoAndroidAcceptance(_engine));
#else
 _engine->rootContext()->setContextProperty("navoAcceptance",QVariant::fromValue<QObject*>(nullptr));
#endif
 _engine->addImportPath("qrc:/qml");
 _selector=new CustomOverrideInterceptor();
 _engine->addUrlInterceptor(_selector);
 return _engine;
}
void CustomPlugin::cleanup(){NavoKoggerService::instance().shutdown();if(_engine&&_selector)_engine->removeUrlInterceptor(_selector);delete _selector;_selector=nullptr;}
QUrl CustomOverrideInterceptor::intercept(const QUrl& url,DataType type){
 if((type==DataType::QmlFile||type==DataType::UrlString)&&url.scheme()=="qrc"){
  // QML_FILES are declared as qml/<file> under URI NavoSmart, so the
  // generated Qt resource keeps that qml/ directory below the module URI.
  if(url.path().endsWith("/FlyView.qml")) return QUrl("qrc:/qml/NavoSmart/qml/NavoDashboard.qml");
 }
 return url;
}
