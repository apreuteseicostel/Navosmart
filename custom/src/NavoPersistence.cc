#include "NavoPersistence.h"
#include <QSettings>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QDateTime>
#include <QUuid>
#include <cmath>

static QByteArray jsonMap(const QVariantMap& m){return QJsonDocument(QJsonObject::fromVariantMap(m)).toJson(QJsonDocument::Compact);}
static QByteArray jsonList(const QVariantList& l){return QJsonDocument(QJsonArray::fromVariantList(l)).toJson(QJsonDocument::Compact);}

NavoPersistence::NavoPersistence(QObject* p):QObject(p){_sonarSaveTimer.setSingleShot(true);_sonarSaveTimer.setInterval(2000);connect(&_sonarSaveTimer,&QTimer::timeout,this,&NavoPersistence::flushSonar);load();}
NavoPersistence::~NavoPersistence(){if(_sonarSaveTimer.isActive())flushSonar();}
void NavoPersistence::syncSettings(){QSettings s;s.sync();}
void NavoPersistence::load() {
 QSettings settings;
 const auto waypoints=QJsonDocument::fromJson(settings.value("navo/waypointNames").toByteArray());
 if(waypoints.isObject())_waypointNames=waypoints.object().toVariantMap();
 const auto sonar=QJsonDocument::fromJson(settings.value("navo/sonarSamples").toByteArray());
 if(sonar.isArray())_sonarSamples=sonar.array().toVariantList();
 // One atomic value owns both collections, so a restart cannot observe half a
 // deletion. The old keys are read only when migrating an existing install.
 if(settings.contains("navo/catalogV1")) {
  const auto catalog=QJsonDocument::fromJson(settings.value("navo/catalogV1").toByteArray()).object();
  _lakes=catalog.value("lakes").toArray().toVariantList();
  _bathymetrySessions=catalog.value("sessions").toArray().toVariantList();
 } else {
  _lakes=QJsonDocument::fromJson(settings.value("navo/lakes").toByteArray()).array().toVariantList();
  _bathymetrySessions=QJsonDocument::fromJson(settings.value("navo/bathymetrySessions").toByteArray()).array().toVariantList();
 }
}
bool NavoPersistence::saveCatalog() {
 QSettings settings;
 settings.setAtomicSyncRequired(true);
 const bool hadPrevious=settings.contains("navo/catalogV1");
 const QVariant previous=settings.value("navo/catalogV1");
 const QJsonObject catalog{{"version",1},{"lakes",QJsonArray::fromVariantList(_lakes)},
                           {"sessions",QJsonArray::fromVariantList(_bathymetrySessions)}};
 settings.setValue("navo/catalogV1",QJsonDocument(catalog).toJson(QJsonDocument::Compact));
 settings.sync();
 if(settings.status()==QSettings::NoError)return true;
 // Revert QSettings' shared pending cache too; a later healthy sync must not
 // silently commit an operation that the UI was told had failed.
 if(hadPrevious)settings.setValue("navo/catalogV1",previous);
 else settings.remove("navo/catalogV1");
 settings.sync();
 return false;
}
void NavoPersistence::saveWaypoints(){QSettings s;s.setValue("navo/waypointNames",jsonMap(_waypointNames));s.sync();}
bool NavoPersistence::saveLakes(){return saveCatalog();}
QString NavoPersistence::saveLake(const QVariantMap& input){const auto previous=_lakes;QVariantMap lake=input;QString id=lake.value("id").toString();if(id.isEmpty())id=QString("lake-%1").arg(QUuid::createUuid().toString(QUuid::WithoutBraces));lake["id"]=id;if(!lake.contains("createdAt"))lake["createdAt"]=QDateTime::currentDateTimeUtc().toString(Qt::ISODate);lake["updatedAt"]=QDateTime::currentDateTimeUtc().toString(Qt::ISODate);for(int i=0;i<_lakes.size();++i)if(_lakes[i].toMap().value("id").toString()==id){auto old=_lakes[i].toMap();for(auto it=lake.cbegin();it!=lake.cend();++it)old[it.key()]=it.value();_lakes[i]=old;if(!saveLakes()){_lakes=previous;return {};}emit lakesChanged();return id;}_lakes.prepend(lake);if(!saveLakes()){_lakes=previous;return {};}emit lakesChanged();return id;}

QString NavoPersistence::saveReplayLake(const QString& name,const QVariantList& samples,const QVariantList& cells){
 const auto clean=name.trimmed();
 if(clean.isEmpty() || samples.size()<3 || cells.isEmpty())return {};
 for(const auto& value:samples){
  const auto sample=value.toMap();
  bool latOk=false,lonOk=false,depthOk=false;
  const auto lat=sample.value("lat").toDouble(&latOk),lon=sample.value("lon").toDouble(&lonOk),depth=sample.value("depth").toDouble(&depthOk);
  if(!latOk||!lonOk||!depthOk||!std::isfinite(lat)||!std::isfinite(lon)||!std::isfinite(depth)||std::abs(lat)>90||std::abs(lon)>180||depth<=0)return {};
 }
 const auto id=QString("replay-%1").arg(QUuid::createUuid().toString(QUuid::WithoutBraces));
 const QVariantMap state{
  {"schemaVersion",2},{"reason","recorded-replay-import"},{"recordedReplay",true},
  {"state","COMPLETE"},{"lakeName",clean},{"savedAt",QDateTime::currentMSecsSinceEpoch()},
  {"sonarSamples",samples},{"bathymetryCells",cells},{"areaPoints",QVariantList{}},
  {"fishingSpots",QVariantList{}},{"fishDetections",QVariantList{}},{"waypointNames",QVariantMap{}},
  {"currentLane",-1},{"completedLanes",QVariantList{}},{"totalLanes",0},
  {"missionCurrentIndex",-1},{"missionLanes",QVariantList{}},{"missionWaypointCount",0}
 };
 return saveLakeState(id,state)?id:QString{};
}

QVariantMap NavoPersistence::lakeState(const QString& lakeId) const {for(const auto& v:_lakes){auto m=v.toMap();if(m.value("id").toString()==lakeId)return m.value("state").toMap();}return {};}
bool NavoPersistence::saveLakeState(const QString& lakeId,const QVariantMap& state){
 if(lakeId.trimmed().isEmpty())return false;
 const auto previous=_lakes;
 for(int i=0;i<_lakes.size();++i){auto m=_lakes[i].toMap();if(m.value("id").toString()!=lakeId)continue;m["state"]=state;m["updatedAt"]=QDateTime::currentDateTimeUtc().toString(Qt::ISODate);_lakes[i]=m;if(!saveLakes()){_lakes=previous;return false;}emit lakesChanged();return true;}
 QVariantMap lake{{"id",lakeId},{"name",state.value("lakeName",QString("Balta"))},{"createdAt",QDateTime::currentDateTimeUtc().toString(Qt::ISODate)},{"updatedAt",QDateTime::currentDateTimeUtc().toString(Qt::ISODate)},{"state",state}};
 _lakes.prepend(lake);if(!saveLakes()){_lakes=previous;return false;}emit lakesChanged();return true;
}
bool NavoPersistence::deleteLake(const QString& lakeId) {
 const auto lakesBefore=_lakes, sessionsBefore=_bathymetrySessions;
 int index=-1;
 for(int i=0;i<_lakes.size();++i)if(_lakes[i].toMap().value("id").toString()==lakeId){index=i;break;}
 if(index<0)return false;
 _lakes.removeAt(index);
 for(int i=_bathymetrySessions.size()-1;i>=0;--i)
  if(_bathymetrySessions[i].toMap().value("lakeId").toString()==lakeId)_bathymetrySessions.removeAt(i);
 if(!saveCatalog()){_lakes=lakesBefore;_bathymetrySessions=sessionsBefore;return false;}
 emit lakesChanged();emit bathymetrySessionsChanged();return true;
}
bool NavoPersistence::assignSessionToLake(const QString& sessionId,const QString& lakeId) {
 bool found=false;for(const auto& lake:_lakes)if(lake.toMap().value("id").toString()==lakeId){found=true;break;}
 if(!found)return false;
 for(int i=0;i<_bathymetrySessions.size();++i) {
  auto session=_bathymetrySessions[i].toMap();
  if(session.value("id").toString()!=sessionId)continue;
  const auto before=_bathymetrySessions;session["lakeId"]=lakeId;_bathymetrySessions[i]=session;
  if(!saveCatalog()){_bathymetrySessions=before;return false;}
  emit bathymetrySessionsChanged();return true;
 }
 return false;
}
bool NavoPersistence::saveBathymetrySessions(){return saveCatalog();}
QString NavoPersistence::saveBathymetrySession(const QVariantMap& metadata,const QVariantList& samples) {
 if(samples.size()<3)return {};
 const auto before=_bathymetrySessions;auto session=metadata;QString id=session.value("id").toString();
 if(id.isEmpty())id=QUuid::createUuid().toString(QUuid::WithoutBraces);
 session["id"]=id;session["savedAt"]=QDateTime::currentDateTimeUtc().toString(Qt::ISODate);session["samples"]=samples;
 for(int i=_bathymetrySessions.size()-1;i>=0;--i)if(_bathymetrySessions[i].toMap().value("id").toString()==id)_bathymetrySessions.removeAt(i);
 _bathymetrySessions.prepend(session);
 if(!saveCatalog()){_bathymetrySessions=before;return {};}
 emit bathymetrySessionsChanged();return id;
}
bool NavoPersistence::deleteBathymetrySession(const QString& id) {
 const auto before=_bathymetrySessions;
 for(int i=0;i<_bathymetrySessions.size();++i)if(_bathymetrySessions[i].toMap().value("id").toString()==id) {
  _bathymetrySessions.removeAt(i);
  if(!saveCatalog()){_bathymetrySessions=before;return false;}
  emit bathymetrySessionsChanged();return true;
 }
 return false;
}
void NavoPersistence::setWaypointName(int seq,const QString& name){auto n=name.trimmed();_waypointNames[QString::number(seq)]=n.isEmpty()?QString("WP%1").arg(seq):n;saveWaypoints();emit waypointNamesChanged();}
void NavoPersistence::replaceWaypointNames(const QVariantMap& names){if(_waypointNames==names)return;_waypointNames=names;saveWaypoints();emit waypointNamesChanged();}
void NavoPersistence::addSonarSample(const QVariantMap& sample){if(!sample.contains("lat")||!sample.contains("lon")||!sample.contains("depth"))return;_sonarSamples.append(sample);while(_sonarSamples.size()>_maxSamples)_sonarSamples.removeFirst();scheduleSonarSave();emit sonarSamplesChanged();}
void NavoPersistence::clearSonarSamples(){_sonarSamples.clear();_sonarSaveTimer.stop();flushSonar();emit sonarSamplesChanged();}

void NavoPersistence::scheduleSonarSave(){if(!_sonarSaveTimer.isActive())_sonarSaveTimer.start();}
void NavoPersistence::flushSonar(){QSettings s;s.setValue("navo/sonarSamples",jsonList(_sonarSamples));s.sync();}
