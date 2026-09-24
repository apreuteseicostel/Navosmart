#include "NavoPersistence.h"
#include <QSettings>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QDateTime>
#include <QUuid>

static QByteArray jsonMap(const QVariantMap& m){return QJsonDocument(QJsonObject::fromVariantMap(m)).toJson(QJsonDocument::Compact);}
static QByteArray jsonList(const QVariantList& l){return QJsonDocument(QJsonArray::fromVariantList(l)).toJson(QJsonDocument::Compact);}

NavoPersistence::NavoPersistence(QObject* p):QObject(p){_sonarSaveTimer.setSingleShot(true);_sonarSaveTimer.setInterval(2000);connect(&_sonarSaveTimer,&QTimer::timeout,this,&NavoPersistence::flushSonar);load();}
void NavoPersistence::syncSettings(){QSettings s;s.sync();}
void NavoPersistence::load(){QSettings s;auto w=QJsonDocument::fromJson(s.value("navo/waypointNames").toByteArray());if(w.isObject())_waypointNames=w.object().toVariantMap();auto a=QJsonDocument::fromJson(s.value("navo/sonarSamples").toByteArray());if(a.isArray())_sonarSamples=a.array().toVariantList();auto b=QJsonDocument::fromJson(s.value("navo/bathymetrySessions").toByteArray());if(b.isArray())_bathymetrySessions=b.array().toVariantList();auto l=QJsonDocument::fromJson(s.value("navo/lakes").toByteArray());if(l.isArray())_lakes=l.array().toVariantList();}
void NavoPersistence::saveWaypoints(){QSettings s;s.setValue("navo/waypointNames",jsonMap(_waypointNames));s.sync();}
bool NavoPersistence::saveLakes(){QSettings s;s.setValue("navo/lakes",jsonList(_lakes));s.sync();return s.status()==QSettings::NoError;}
QString NavoPersistence::saveLake(const QVariantMap& input){const auto previous=_lakes;QVariantMap lake=input;QString id=lake.value("id").toString();if(id.isEmpty())id=QString("lake-%1").arg(QUuid::createUuid().toString(QUuid::WithoutBraces));lake["id"]=id;if(!lake.contains("createdAt"))lake["createdAt"]=QDateTime::currentDateTimeUtc().toString(Qt::ISODate);lake["updatedAt"]=QDateTime::currentDateTimeUtc().toString(Qt::ISODate);for(int i=0;i<_lakes.size();++i)if(_lakes[i].toMap().value("id").toString()==id){auto old=_lakes[i].toMap();for(auto it=lake.cbegin();it!=lake.cend();++it)old[it.key()]=it.value();_lakes[i]=old;if(!saveLakes()){_lakes=previous;return {};}emit lakesChanged();return id;}_lakes.prepend(lake);if(!saveLakes()){_lakes=previous;return {};}emit lakesChanged();return id;}
QVariantMap NavoPersistence::lakeState(const QString& lakeId) const {for(const auto& v:_lakes){auto m=v.toMap();if(m.value("id").toString()==lakeId)return m.value("state").toMap();}return {};}
bool NavoPersistence::saveLakeState(const QString& lakeId,const QVariantMap& state){
 if(lakeId.trimmed().isEmpty())return false;
 const auto previous=_lakes;
 for(int i=0;i<_lakes.size();++i){auto m=_lakes[i].toMap();if(m.value("id").toString()!=lakeId)continue;m["state"]=state;m["updatedAt"]=QDateTime::currentDateTimeUtc().toString(Qt::ISODate);_lakes[i]=m;if(!saveLakes()){_lakes=previous;return false;}emit lakesChanged();return true;}
 QVariantMap lake{{"id",lakeId},{"name",state.value("lakeName",QString("Balta"))},{"createdAt",QDateTime::currentDateTimeUtc().toString(Qt::ISODate)},{"updatedAt",QDateTime::currentDateTimeUtc().toString(Qt::ISODate)},{"state",state}};
 _lakes.prepend(lake);if(!saveLakes()){_lakes=previous;return false;}emit lakesChanged();return true;
}
bool NavoPersistence::deleteLake(const QString& lakeId){for(int i=0;i<_lakes.size();++i)if(_lakes[i].toMap().value("id").toString()==lakeId){_lakes.removeAt(i);for(int j=_bathymetrySessions.size()-1;j>=0;--j)if(_bathymetrySessions[j].toMap().value("lakeId").toString()==lakeId)_bathymetrySessions.removeAt(j);saveLakes();saveBathymetrySessions();emit lakesChanged();emit bathymetrySessionsChanged();return true;}return false;}
bool NavoPersistence::assignSessionToLake(const QString& sessionId,const QString& lakeId){bool lakeFound=false;for(const auto& v:_lakes)if(v.toMap().value("id").toString()==lakeId){lakeFound=true;break;}if(!lakeFound)return false;for(int i=0;i<_bathymetrySessions.size();++i){auto m=_bathymetrySessions[i].toMap();if(m.value("id").toString()==sessionId){m["lakeId"]=lakeId;_bathymetrySessions[i]=m;saveBathymetrySessions();emit bathymetrySessionsChanged();return true;}}return false;}
void NavoPersistence::saveBathymetrySessions(){QSettings s;s.setValue("navo/bathymetrySessions",jsonList(_bathymetrySessions));s.sync();}
QString NavoPersistence::saveBathymetrySession(const QVariantMap& metadata,const QVariantList& samples){if(samples.size()<3)return {};QVariantMap session=metadata;QString id=session.value("id").toString();if(id.isEmpty())id=QString::number(QDateTime::currentMSecsSinceEpoch());session["id"]=id;session["savedAt"]=QDateTime::currentDateTimeUtc().toString(Qt::ISODate);session["samples"]=samples;for(int i=_bathymetrySessions.size()-1;i>=0;--i)if(_bathymetrySessions[i].toMap().value("id").toString()==id)_bathymetrySessions.removeAt(i);_bathymetrySessions.prepend(session);saveBathymetrySessions();emit bathymetrySessionsChanged();return id;}
bool NavoPersistence::deleteBathymetrySession(const QString& id){for(int i=0;i<_bathymetrySessions.size();++i)if(_bathymetrySessions[i].toMap().value("id").toString()==id){_bathymetrySessions.removeAt(i);saveBathymetrySessions();emit bathymetrySessionsChanged();return true;}return false;}
void NavoPersistence::scheduleSonarSave(){if(!_sonarSaveTimer.isActive())_sonarSaveTimer.start();}
void NavoPersistence::flushSonar(){QSettings s;s.setValue("navo/sonarSamples",jsonList(_sonarSamples));s.sync();}
void NavoPersistence::setWaypointName(int seq,const QString& name){auto n=name.trimmed();_waypointNames[QString::number(seq)]=n.isEmpty()?QString("WP%1").arg(seq):n;saveWaypoints();emit waypointNamesChanged();}
void NavoPersistence::replaceWaypointNames(const QVariantMap& names){if(_waypointNames==names)return;_waypointNames=names;saveWaypoints();emit waypointNamesChanged();}
void NavoPersistence::addSonarSample(const QVariantMap& sample){if(!sample.contains("lat")||!sample.contains("lon")||!sample.contains("depth"))return;_sonarSamples.append(sample);while(_sonarSamples.size()>_maxSamples)_sonarSamples.removeFirst();scheduleSonarSave();emit sonarSamplesChanged();}
void NavoPersistence::clearSonarSamples(){_sonarSamples.clear();_sonarSaveTimer.stop();flushSonar();emit sonarSamplesChanged();}
