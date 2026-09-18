#pragma once
#include <QObject>
#include <QVariantList>
#include <QVariantMap>
class QSettings;
class NavoPersistence : public QObject {
 Q_OBJECT
 Q_PROPERTY(QVariantMap waypointNames READ waypointNames NOTIFY waypointNamesChanged)
 Q_PROPERTY(QVariantList sonarSamples READ sonarSamples NOTIFY sonarSamplesChanged)
public:
 explicit NavoPersistence(QObject* parent=nullptr);
 QVariantMap waypointNames() const{return _waypointNames;} QVariantList sonarSamples() const{return _sonarSamples;}
 Q_INVOKABLE void setWaypointName(int sequence,const QString& name);
 Q_INVOKABLE void addSonarSample(const QVariantMap& sample);
 Q_INVOKABLE void clearSonarSamples();
signals:void waypointNamesChanged();void sonarSamplesChanged();
private:void load();void saveWaypoints();void saveSonar();
 QVariantMap _waypointNames; QVariantList _sonarSamples; int _maxSamples=50000;
};