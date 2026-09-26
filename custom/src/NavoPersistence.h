#pragma once
#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include <QTimer>
class NavoPersistence : public QObject {
 Q_OBJECT
 Q_PROPERTY(QVariantMap waypointNames READ waypointNames NOTIFY waypointNamesChanged)
 Q_PROPERTY(QVariantList sonarSamples READ sonarSamples NOTIFY sonarSamplesChanged)
 Q_PROPERTY(QVariantList bathymetrySessions READ bathymetrySessions NOTIFY bathymetrySessionsChanged)
 Q_PROPERTY(QVariantList lakes READ lakes NOTIFY lakesChanged)
public:
 explicit NavoPersistence(QObject* parent=nullptr);
 ~NavoPersistence() override;
 QVariantMap waypointNames() const{return _waypointNames;} QVariantList sonarSamples() const{return _sonarSamples;} QVariantList bathymetrySessions() const{return _bathymetrySessions;} QVariantList lakes() const{return _lakes;}
 Q_INVOKABLE void setWaypointName(int sequence,const QString& name);
 Q_INVOKABLE void replaceWaypointNames(const QVariantMap& names);
 Q_INVOKABLE void addSonarSample(const QVariantMap& sample);
 Q_INVOKABLE void clearSonarSamples();
 Q_INVOKABLE QString saveBathymetrySession(const QVariantMap& metadata,const QVariantList& samples);
 Q_INVOKABLE bool deleteBathymetrySession(const QString& id);
 Q_INVOKABLE QString saveLake(const QVariantMap& lake);
 Q_INVOKABLE QVariantMap lakeState(const QString& lakeId) const;
 Q_INVOKABLE bool saveLakeState(const QString& lakeId,const QVariantMap& state);
 Q_INVOKABLE bool deleteLake(const QString& lakeId);
 Q_INVOKABLE bool assignSessionToLake(const QString& sessionId,const QString& lakeId);
signals:void waypointNamesChanged();void sonarSamplesChanged();void bathymetrySessionsChanged();void lakesChanged();
private slots:void flushSonar();
private:void load();void saveWaypoints();void saveBathymetrySessions();bool saveLakes();void scheduleSonarSave();void syncSettings();
 QVariantMap _waypointNames; QVariantList _sonarSamples; QVariantList _bathymetrySessions; QVariantList _lakes; int _maxSamples=50000; QTimer _sonarSaveTimer;
};