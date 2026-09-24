#pragma once
#include "QGCCorePlugin.h"
#include "QGCOptions.h"
#include <QtQml/QQmlAbstractUrlInterceptor>
class QQmlApplicationEngine;
class CustomOptions;
class CustomOverrideInterceptor;
class CustomFlyViewOptions: public QGCFlyViewOptions {
public: CustomFlyViewOptions(CustomOptions* options,QObject* parent=nullptr);
 bool showInstrumentPanel() const final { return false; }
 bool showMultiVehicleList() const final { return false; }
};
class CustomOptions: public QGCOptions {
public: CustomOptions(QObject* parent=nullptr):QGCOptions(parent),_fly(new CustomFlyViewOptions(this,this)){}
 QGCFlyViewOptions* flyViewOptions() const final { return _fly; }
private: CustomFlyViewOptions* _fly;
};
class CustomPlugin: public QGCCorePlugin {
 Q_OBJECT
public:
 explicit CustomPlugin(QObject* parent=nullptr);
 ~CustomPlugin();
 static QGCCorePlugin* instance();
 QGCOptions* options() final { return _options; }
 bool adjustSettingMetaData(const QString& settingsGroup, FactMetaData& metaData) final;
 QList<int> firstRunPromptStdIds() final { return QList<int>({ kUnitsFirstRunPromptId }); }
 QQmlApplicationEngine* createQmlApplicationEngine(QObject* parent) final;
 void cleanup() final;
private:
 CustomOptions* _options=nullptr;
 QQmlApplicationEngine* _engine=nullptr;
 CustomOverrideInterceptor* _selector=nullptr;
};
class CustomOverrideInterceptor: public QQmlAbstractUrlInterceptor {
public: QUrl intercept(const QUrl& url,DataType type) final;
};
