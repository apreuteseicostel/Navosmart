#pragma once
#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include <QTimer>
class QSettings;
class NavoPersistence : public QObject {
 Q_OBJECT
 Q_PROPERTY(QVariantMap waypointNames READ waypointNames NOTIFY waypointNamesChanged)
 Q_PROPERTY(QVariantList sonarSamples READ sonarSamples NOTIFY sonarSamplesChanged)
 Q_PROPERTY(QVariantList bathymetrySessions READ bathymetrySessions NOTIFY bathymetrySessionsChanged)
public:
 explicit NavoPersistence(QObject* parent=nullptr);
 QVariantMap waypointNames() const{return _waypointNames;} QVariantList sonarSamples() const{return _sonarSamples;} QVariantList bathymetrySessions() const{return _bathymetrySessions;}
 Q_INVOKABLE void setWaypointName(int sequence,const QString& name);
 Q_INVOKABLE void addSonarSample(const QVariantMap& sample);
 Q_INVOKABLE void clearSonarSamples();
 Q_INVOKABLE QString saveBathymetrySession(const QVariantMap& metadata,const QVariantList& samples);
 Q_INVOKABLE bool deleteBathymetrySession(const QString& id);
signals:void waypointNamesChanged();void sonarSamplesChanged();void bathymetrySessionsChanged();
private slots:void flushSonar();
private:void load();void saveWaypoints();void saveBathymetrySessions();void scheduleSonarSave();
 QVariantMap _waypointNames; QVariantList _sonarSamples; QVariantList _bathymetrySessions; int _maxSamples=50000; QTimer _sonarSaveTimer;
};