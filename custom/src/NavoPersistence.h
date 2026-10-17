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
 Q_PROPERTY(QVariantList fishingTrips READ fishingTrips NOTIFY fishingTripsChanged)
 Q_PROPERTY(QString journalError READ journalError NOTIFY journalErrorChanged)
 Q_PROPERTY(QVariantList lakes READ lakes NOTIFY lakesChanged)
public:
 explicit NavoPersistence(QObject* parent=nullptr);
 ~NavoPersistence() override;
 QVariantMap waypointNames() const{return _waypointNames;} QVariantList sonarSamples() const{return _sonarSamples;} QVariantList bathymetrySessions() const{return _bathymetrySessions;} QVariantList lakes() const{return _lakes;}
 QVariantList fishingTrips() const{return _fishingTrips;}
 QString journalError() const{return _journalError;}
 Q_INVOKABLE QVariantList pendingBaitJournalEvents() const;
 Q_INVOKABLE bool storePendingBaitJournalEvents(const QVariantList& events);
 Q_INVOKABLE QString startFishingTrip(const QString& lakeId,const QString& title);
 Q_INVOKABLE bool finishFishingTrip(const QString& tripId);
 Q_INVOKABLE bool deleteFishingTrip(const QString& tripId);
 Q_INVOKABLE QString saveFishingEntry(const QString& tripId,const QVariantMap& entry);
 Q_INVOKABLE bool deleteFishingEntry(const QString& tripId,const QString& entryId);
 Q_INVOKABLE void setWaypointName(int sequence,const QString& name);
 Q_INVOKABLE void replaceWaypointNames(const QVariantMap& names);
 Q_INVOKABLE void addSonarSample(const QVariantMap& sample);
 Q_INVOKABLE void clearSonarSamples();
 Q_INVOKABLE QString saveBathymetrySession(const QVariantMap& metadata,const QVariantList& samples);
 Q_INVOKABLE bool deleteBathymetrySession(const QString& id);
 Q_INVOKABLE QString saveLake(const QVariantMap& lake);
 Q_INVOKABLE QString saveReplayLake(const QString& name,const QVariantList& samples,const QVariantList& cells,const QVariantMap& nativeSurface=QVariantMap());
 Q_INVOKABLE QVariantMap lakeState(const QString& lakeId) const;
 Q_INVOKABLE bool saveLakeState(const QString& lakeId,const QVariantMap& state);
 Q_INVOKABLE bool deleteLake(const QString& lakeId);
 Q_INVOKABLE bool assignSessionToLake(const QString& sessionId,const QString& lakeId);
signals:void fishingTripsChanged();void journalErrorChanged();void waypointNamesChanged();void sonarSamplesChanged();void bathymetrySessionsChanged();void lakesChanged();
private slots:void flushSonar();
private:bool journalFailure(const QString& message);bool commitTrips(const QVariantList& trips);void load();void saveWaypoints();bool saveCatalog();bool saveBathymetrySessions();bool saveLakes();void scheduleSonarSave();void syncSettings();
 QVariantList _fishingTrips;QString _journalError;bool _catalogValid=true;
 QVariantMap _waypointNames; QVariantList _sonarSamples; QVariantList _bathymetrySessions; QVariantList _lakes; int _maxSamples=50000; QTimer _sonarSaveTimer;
};