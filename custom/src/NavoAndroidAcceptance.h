#pragma once
#include <QObject>
#include <QVariantMap>
#include <QFile>
#include <QSaveFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QStandardPaths>
#include <QCryptographicHash>
#include <QJSValue>
#include <QDebug>
#include <QQuickItem>
#include <QQuickWindow>
#include <QPointer>
#include <QSet>

// Instantiated only in the explicit CI x86_64 acceptance build. No simulated
// vehicle, sonar, map projection or persistence is installed by this helper.
class NavoAndroidAcceptance : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantMap configuration READ configuration CONSTANT)
    Q_PROPERTY(bool active READ active CONSTANT)
    Q_PROPERTY(QString directory READ directory CONSTANT)
public:
    explicit NavoAndroidAcceptance(QObject* parent=nullptr):QObject(parent),dir_(QStandardPaths::writableLocation(QStandardPaths::AppDataLocation)) {
        qInfo().noquote()<<"NAVO_ACCEPTANCE_DIR:"<<dir_;
        QFile input(dir_+"/navo-acceptance-request.json");
        if(input.open(QIODevice::ReadOnly) && input.size()<32768)
            configuration_=QJsonDocument::fromJson(input.readAll()).object().toVariantMap();
    }
    QVariantMap configuration() const{return configuration_;}
    QString directory() const{return dir_;}
    bool active() const{return configuration_.value("phase")=="record" || configuration_.value("phase")=="restore";}
    Q_INVOKABLE bool claim(QObject* dashboard) {
        auto* item=qobject_cast<QQuickItem*>(dashboard);
        if(!item || !item->isVisible() || !item->window() || !item->window()->isVisible()
           || item->width()<=0 || item->height()<=0)return false;
        if(!owner_) {
            owner_=dashboard;
            qInfo()<<"NAVO_ACCEPTANCE_OWNER:"<<dashboard;
        }
        return owner_==dashboard;
    }
    Q_INVOKABLE bool verifiedFixture() const {
        QFile fixture(dir_+"/00028_DownView.klf");if(!fixture.open(QIODevice::ReadOnly))return false;
        QCryptographicHash hash(QCryptographicHash::Sha256);
        return hash.addData(&fixture) && hash.result().toHex()=="1ff5e23abbdd37e31eeacd7875c4e8a457ccb927641e47ea77c861151ab2ace0";
    }
    Q_INVOKABLE bool report(const QVariantMap& state) const {
        QSaveFile output(dir_+"/navo-acceptance-report.json");if(!output.open(QIODevice::WriteOnly))return false;
        const auto bytes=QJsonDocument(QJsonObject::fromVariantMap(state)).toJson(QJsonDocument::Compact);
        return output.write(bytes)==bytes.size() && output.commit();
    }
    Q_INVOKABLE QVariantMap inspect(QObject* dashboard) const {
        QVariantMap result{{"nativePaintedTriangles",0},{"mesh3dVisible",false},{"mesh3dVertices",0},{"mesh3dTriangles",0},{"sonarHistoryColumns",0}};
        if(!dashboard)return result;
        for(auto* object:sceneObjects(dashboard)) {
            if(object->objectName()=="navoBathymetry3D") {
                auto* item=qobject_cast<QQuickItem*>(object);
                result["mesh3dVisible"]=item && item->isVisible() && item->window() && item->width()>0 && item->height()>0;
            }
            if(object->objectName()=="navoNativeSurfaceOverlay" && object->property("visible").toBool()) {
                result["nativePaintedTriangles"]=object->property("renderedTriangles");
                result["nativePaintMs"]=object->property("lastPaintMs");
            }
            if(object->objectName()=="navoBathymetryMesh") {
                result["mesh3dVertices"]=listSize(object->property("vertices"));
                result["mesh3dTriangles"]=listSize(object->property("triangles"));
            }
            if(object->objectName()=="navoSonarPro" && object->property("visible").toBool())
                result["sonarHistoryColumns"]=listSize(object->property("history"));
        }
        return result;
    }
    Q_INVOKABLE void enableNativeMap(QObject* dashboard) const {
        if(!dashboard)return;
        for(auto* object:sceneObjects(dashboard))
            if(object->objectName()=="navoMap" && object->property("visible").toBool())object->setProperty("bathymetryHDEnabled",true);
    }
private:
    static int listSize(const QVariant& value) {
        if(value.metaType()==QMetaType::fromType<QJSValue>())
            return value.value<QJSValue>().property("length").toInt();
        return value.toList().size();
    }
    static QList<QObject*> sceneObjects(QObject* root) {
        QList<QObject*> objects{root};QSet<QObject*> seen{root};
        for(qsizetype i=0;i<objects.size();++i) {
            auto append=[&](QObject* child){if(child && !seen.contains(child)){seen.insert(child);objects.append(child);}};
            for(auto* child:objects[i]->children())append(child);
            if(auto* item=qobject_cast<QQuickItem*>(objects[i]))
                for(auto* child:item->childItems())append(child);
        }
        return objects;
    }
    QPointer<QObject> owner_;
    QVariantMap configuration_;
    QString dir_;
};
