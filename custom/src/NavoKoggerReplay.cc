#include "NavoKoggerReplay.h"
#include "../../third_party/KoggerApp/src/proto_binnary.h"
#include <QtEndian>
#include <QSaveFile>
#include <QStandardPaths>
#include <QDir>
#include <QFileInfo>
#include <QCryptographicHash>
#include <QJsonDocument>
#include <QJsonArray>
#include <QUuid>
#include <QDateTime>
#include <QSet>
#include <cmath>
#include <cstring>
#include <algorithm>
NavoKoggerReplay::NavoKoggerReplay(QObject* parent):QObject(parent),_parser(std::make_unique<Parsers::FrameParser>()) {
 _timer.setInterval(40); connect(&_timer,&QTimer::timeout,this,&NavoKoggerReplay::tick);
}
NavoKoggerReplay::~NavoKoggerReplay()=default;
bool NavoKoggerReplay::open(const QUrl& url) {
 stop(); _error.clear();
 if (!url.isLocalFile() && url.scheme()!=QLatin1String("content")) {
  _error=QStringLiteral("Selectează un fișier local .klf sau .navosonar"); emit stateChanged(); return false;
 }
 _file.setFileName(url.isLocalFile()?url.toLocalFile():url.toString());
 if (!_file.open(QIODevice::ReadOnly)) { _error=_file.errorString(); emit stateChanged(); return false; }
 _archive = _file.peek(NavoSonarArchive::magic.size()) == NavoSonarArchive::magic;
 if (_archive) {
  QJsonObject metadata;
  if (_file.size()>NavoSonarArchive::maxFile || !NavoSonarArchive::readHeader(_file,metadata)) {
   _error=QStringLiteral("Antet NAVO invalid."); _file.close(); emit stateChanged(); return false;
  }
 } else if (url.path().endsWith(QLatin1String(".navosonar"),Qt::CaseInsensitive)) {
  _error=QStringLiteral("Fișierul nu este o înregistrare NAVO v1."); _file.close(); emit stateChanged(); return false;
 }
 loadAnnotations(url);
 _active=true; _paused=false; _pacing.start(); _timer.start(); emit stateChanged(); emit progressChanged(); return true;
}
void NavoKoggerReplay::stop() {
 _timer.stop(); _pacing.invalidate(); _file.close(); _parser=std::make_unique<Parsers::FrameParser>();
 _active=false; _paused=false; _blocked=false; _gpsFix=false;
 _annotationKey.clear();_annotationError.clear();_annotations.clear();_annotationsWritable=true;
 _deliveredFrame=0;_deliveredMilliseconds=-1;emit annotationAnchorChanged();emit annotationsChanged();
 _archive=false; _pending=false; _archiveTime=0; _previousTime=0; _record=NavoSonarArchive::Record();
 _lat=_lon=_heading=_pitch=_roll=qQNaN(); emit stateChanged(); emit progressChanged();
}
void NavoKoggerReplay::setPaused(bool value) {
 if (!_active || _paused==value)return;
 _paused=value; _pacing.start(); if(value)_timer.stop();else _timer.start(); emit stateChanged();
}
void NavoKoggerReplay::setSpeed(double value) {
 if(!std::isfinite(value))return;
 value=std::clamp(value,0.5,5.0);
 if(_speed==value)return;_speed=value;_pacing.start();emit stateChanged();
}
void NavoKoggerReplay::readPosition() {
 const auto* raw=_parser->frame();
 const bool v2=_parser->proto()==Parsers::FrameParser::ProtoMAVLink2;
 const int header=v2?10:6, length=raw[1];
 const unsigned id=v2?(unsigned(raw[7])|(unsigned(raw[8])<<8)|(unsigned(raw[9])<<16)):raw[5];
 const auto* p=raw+header;
 if(id==24 && length>=30) {
  _gpsFix=p[28]>=3;
  _lat=_gpsFix?double(qFromLittleEndian<qint32>(p+8))*1e-7:qQNaN();
  _lon=_gpsFix?double(qFromLittleEndian<qint32>(p+12))*1e-7:qQNaN();
 } else if(id==33 && length>=28 && _gpsFix) {
  _lat=double(qFromLittleEndian<qint32>(p+4))*1e-7;
  _lon=double(qFromLittleEndian<qint32>(p+8))*1e-7;
  const auto heading=qFromLittleEndian<quint16>(p+26);
  if(heading!=65535)_heading=heading*0.01;
 } else if(id==30 && length>=16) {
  double* values[]={&_roll,&_pitch,&_heading};
  for(int i=0;i<3;++i){const quint32 bits=qFromLittleEndian<quint32>(p+4+i*4);float f;std::memcpy(&f,&bits,4);*values[i]=f*180.0/3.14159265358979323846;}
 }
}
void NavoKoggerReplay::tick() {
 if(!_active||_paused||_blocked){if(_pacing.isValid())_pacing.restart();return;}
 // Qt timers coalesce missed intervals when the UI is rendering. Compensate
 // for actual elapsed time rather than silently reducing the requested speed.
 // Bound each read so native backpressure can still stop the next tick.
 const qint64 elapsed=_pacing.isValid()?_pacing.restart():40;
 if(_archive){archiveTick(elapsed);return;}
 const int nominal=int(4096*_speed);
 const int budget=std::clamp(int(4096.0*_speed*std::min<qint64>(elapsed,1000)/40.0),nominal,65536);
 QByteArray bytes=_file.read(budget);
 _parser->setContext(reinterpret_cast<uint8_t*>(bytes.data()),bytes.size());
 while(_parser->availContext()>0) {
  _parser->process();
  if(_parser->isCompleteAsMAVLink())readPosition();
  else if(_parser->completeAsKBP() || _parser->completeAsKBP2()) {
   // Refresh recorded position immediately before feeding each frame. No live vehicle GPS.
   ++_deliveredFrame;emit annotationAnchorChanged();
   emit positionReady(_lat,_lon,_heading,_pitch,_roll);
   emit bytesReady(QByteArray(reinterpret_cast<const char*>(_parser->frame()),_parser->frameLen()));
  }
 }
 emit progressChanged();
 if(_file.atEnd()) {
  // Preserve native results for preview; EOF is not an explicit session reset.
  _timer.stop(); _active=false; emit stateChanged();
 }
}

void NavoKoggerReplay::archiveTick(qint64 elapsed) {
 // Paused and backpressured time is excluded by tick/setBlocked/setPaused.
 _archiveTime += std::min<qint64>(elapsed,1000)*_speed;
 int budget=65536;
 while(_active && !_blocked && budget>0) {
  if(!_pending) {
   const int result=NavoSonarArchive::readRecord(_file,_record,_previousTime);
   if(result<=0) {
    if(result<0)_error=QStringLiteral("Înregistrare NAVO incompletă sau coruptă.");
    _timer.stop();_active=false;emit stateChanged();break;
   }
   _previousTime=_record.milliseconds;_pending=true;
  }
  if(_record.milliseconds>_archiveTime || _record.bytes.size()>budget)break;
  ++_deliveredFrame;_deliveredMilliseconds=_record.milliseconds;
  _lat=_record.lat;_lon=_record.lon;emit annotationAnchorChanged();
  emit positionReady(_record.lat,_record.lon,_record.heading,_record.pitch,_record.roll);
  emit bytesReady(_record.bytes);
  budget-=_record.bytes.size();_pending=false;
 }
 emit progressChanged();
}

QVariantMap NavoKoggerReplay::annotationAnchor() const {
 if(_annotationKey.isEmpty() || _deliveredFrame<=0)return {};
 const bool gps=std::isfinite(_lat) && std::isfinite(_lon) && std::abs(_lat)<=90 && std::abs(_lon)<=180;
 return {{"source",_annotationKey},{"frame",_deliveredFrame},{"milliseconds",_deliveredMilliseconds},
         {"latitude",gps?QVariant(_lat):QVariant()},
         {"longitude",gps?QVariant(_lon):QVariant()}};
}
QString NavoKoggerReplay::annotationPath() const {
 return QStandardPaths::writableLocation(QStandardPaths::AppDataLocation)+"/replay-annotations/"+_annotationKey+".json";
}
void NavoKoggerReplay::loadAnnotations(const QUrl& url) {
 // A bounded fingerprint of the selected source/version, not a full-file checksum.
 // Local replacements change mtime; moving a source intentionally creates a new association.
 const QFileInfo info(_file);
 const QByteArray identity=url.toString(QUrl::FullyEncoded).toUtf8()+'\n'+QByteArray::number(_file.size())+'\n'+
     info.lastModified().toUTC().toString(Qt::ISODateWithMs).toUtf8()+'\n'+_file.peek(65536);
 _annotationKey=QString::fromLatin1(QCryptographicHash::hash(identity,QCryptographicHash::Sha256).toHex());
 QFile notes(annotationPath());
 if(notes.exists()) {
  if(!notes.open(QIODevice::ReadOnly) || notes.size()>1048576) {
   _annotationError=QStringLiteral("Notele nu pot fi citite; fișierul existent este păstrat.");_annotationsWritable=false;
  } else {
   QJsonParseError error;const auto doc=QJsonDocument::fromJson(notes.readAll(),&error);const auto object=doc.object();
   const auto array=object.value("notes").toArray();bool valid=error.error==QJsonParseError::NoError && doc.isObject() &&
       object.value("version").toInt()==1 && object.value("source").toString()==_annotationKey && object.value("notes").isArray() && array.size()<=500;
   auto optionalNumber=[](const QJsonValue& value){return value.isNull() || (value.isDouble() && std::isfinite(value.toDouble()));};
   QSet<QString> ids;
   for(const auto& value:array) {
    const auto n=value.toObject();const auto id=n.value("id").toString();const auto text=n.value("text").toString();
    valid=valid && value.isObject() && !id.isEmpty() && id.size()<=64 && !ids.contains(id) && !text.trimmed().isEmpty() && text.size()<=1000 &&
        n.value("source").toString()==_annotationKey && n.value("frame").isDouble() && n.value("frame").toDouble()>=1 &&
        n.value("frame").toDouble()<=9007199254740991.0 && std::floor(n.value("frame").toDouble())==n.value("frame").toDouble();
    valid=valid && optionalNumber(n.value("latitude")) && optionalNumber(n.value("longitude")) && optionalNumber(n.value("depth")) && optionalNumber(n.value("temperature")) && optionalNumber(n.value("columnSequence")) &&
        (n.value("latitude").isNull() || std::abs(n.value("latitude").toDouble())<=90) &&
        (n.value("longitude").isNull() || std::abs(n.value("longitude").toDouble())<=180) &&
        (n.value("depth").isNull() || n.value("depth").toDouble()>=0) &&
        n.value("milliseconds").isDouble() && n.value("milliseconds").toDouble()>=-1 &&
        n.value("milliseconds").toDouble()<=7.0*24*3600*1000 && std::floor(n.value("milliseconds").toDouble())==n.value("milliseconds").toDouble();
    ids.insert(id);
   }
   if(valid)_annotations=array.toVariantList();
   else {_annotationError=QStringLiteral("Fișier de note invalid; nu va fi suprascris.");_annotationsWritable=false;}
  }
 }
 emit annotationsChanged();
}
bool NavoKoggerReplay::storeAnnotations(const QVariantList& next) {
 if(_annotationKey.isEmpty() || !_annotationsWritable)return false;
 const auto directory=QFileInfo(annotationPath()).absolutePath();QSaveFile file(annotationPath());file.setDirectWriteFallback(false);
 const auto bytes=QJsonDocument(QJsonObject{{"version",1},{"source",_annotationKey},{"notes",QJsonArray::fromVariantList(next)}}).toJson(QJsonDocument::Compact);
 if(bytes.size()>1048576 || !QDir().mkpath(directory) || !file.open(QIODevice::WriteOnly) || file.write(bytes)!=bytes.size() || !file.commit()) {
  _annotationError=QStringLiteral("Nota nu a fost salvată. Verifică spațiul și accesul la stocare.");emit annotationsChanged();return false;
 }
 _annotations=next;_annotationError.clear();emit annotationsChanged();return true;
}
bool NavoKoggerReplay::saveAnnotation(const QVariantMap& anchor,const QString& text,double depth,double temperature) {
 const auto clean=text.trimmed();bool ok=false,timeOk=false;const auto frame=anchor.value("frame").toLongLong(&ok);
 const auto milliseconds=anchor.value("milliseconds").toLongLong(&timeOk);
 const auto lat=anchor.value("latitude"),lon=anchor.value("longitude");
 auto validCoordinate=[](const QVariant& v,double bound){if(v.isNull())return true;bool valid=false;const auto number=v.toDouble(&valid);return valid && std::isfinite(number) && std::abs(number)<=bound;};
 if(_annotationKey.isEmpty() || anchor.value("source").toString()!=_annotationKey || !ok || frame<1 || frame>_deliveredFrame || !timeOk || (_archive ? milliseconds<0 || milliseconds>_deliveredMilliseconds : milliseconds!=-1) ||
     !validCoordinate(lat,90) || !validCoordinate(lon,180) || clean.isEmpty() || clean.size()>1000 || _annotations.size()>=500)return false;
 QVariantMap note{{"source",_annotationKey},{"frame",frame},{"milliseconds",milliseconds},{"latitude",lat.isNull()?QVariant():QVariant(lat.toDouble())},{"longitude",lon.isNull()?QVariant():QVariant(lon.toDouble())}};note.insert("id",QUuid::createUuid().toString(QUuid::WithoutBraces));note.insert("text",clean);
 bool sequenceOk=false;const auto sequence=anchor.value("columnSequence").toDouble(&sequenceOk);
 note.insert("columnSequence",sequenceOk && std::isfinite(sequence) && sequence>=0 ? QVariant(sequence) : QVariant());
 note.insert("createdUtc",QDateTime::currentDateTimeUtc().toString(Qt::ISODateWithMs));
 note.insert("depth",std::isfinite(depth)&&depth>=0?QVariant(depth):QVariant());
 note.insert("temperature",std::isfinite(temperature)?QVariant(temperature):QVariant());
 auto next=_annotations;next.append(note);return storeAnnotations(next);
}
bool NavoKoggerReplay::editAnnotation(const QString& id,const QString& text) {
 const auto clean=text.trimmed();if(clean.isEmpty() || clean.size()>1000)return false;
 auto next=_annotations;
 for(auto& value:next){auto n=value.toMap();if(n.value("id").toString()!=id)continue;n.insert("text",clean);value=n;return storeAnnotations(next);}
 return false;
}
bool NavoKoggerReplay::removeAnnotation(const QString& id) {
 auto next=_annotations;
 for(qsizetype i=0;i<next.size();++i)if(next[i].toMap().value("id").toString()==id){next.removeAt(i);return storeAnnotations(next);}
 return false;
}
