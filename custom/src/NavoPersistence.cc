#include "NavoPersistence.h"
#include <QSettings>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
NavoPersistence::NavoPersistence(QObject* p):QObject(p){_sonarSaveTimer.setSingleShot(true);_sonarSaveTimer.setInterval(2000);connect(&_sonarSaveTimer,&QTimer::timeout,this,&NavoPersistence::flushSonar);load();}
void NavoPersistence::load(){QSettings s;auto w=QJsonDocument::fromJson(s.value("navo/waypointNames").toByteArray());if(w.isObject())_waypointNames=w.object().toVariantMap();auto a=QJsonDocument::fromJson(s.value("navo/sonarSamples").toByteArray());if(a.isArray())_sonarSamples=a.array().toVariantList();}
void NavoPersistence::saveWaypoints(){QSettings s;s.setValue("navo/waypointNames",QJsonDocument(QJsonObject::fromVariantMap(_waypointNames)).toJson(QJsonDocument::Compact));}
void NavoPersistence::scheduleSonarSave(){if(!_sonarSaveTimer.isActive())_sonarSaveTimer.start();}\nvoid NavoPersistence::flushSonar(){QSettings s;s.setValue("navo/sonarSamples",QJsonDocument(QJsonArray::fromVariantList(_sonarSamples)).toJson(QJsonDocument::Compact));}
void NavoPersistence::setWaypointName(int seq,const QString& name){auto n=name.trimmed();_waypointNames[QString::number(seq)]=n.isEmpty()?QString("WP%1").arg(seq):n;saveWaypoints();emit waypointNamesChanged();}
void NavoPersistence::addSonarSample(const QVariantMap& sample){if(!sample.contains("lat")||!sample.contains("lon")||!sample.contains("depth"))return;_sonarSamples.append(sample);while(_sonarSamples.size()>_maxSamples)_sonarSamples.removeFirst();scheduleSonarSave();emit sonarSamplesChanged();}
void NavoPersistence::clearSonarSamples(){_sonarSamples.clear();_sonarSaveTimer.stop();flushSonar();emit sonarSamplesChanged();}
