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
 _indexTimer.setInterval(12); connect(&_indexTimer,&QTimer::timeout,this,&NavoKoggerReplay::indexTick);
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
 beginIndexing();
 _active=true; _paused=false; _pacing.start(); _timer.start(); emit stateChanged(); emit progressChanged(); return true;
}
void NavoKoggerReplay::stop() {
 _timer.stop();_indexTimer.stop();_indexFile.close();_indexBuffer.clear();_columns.clear();
 _indexBufferOffset=0;_indexProcessed=0;_indexReady=false;_haveChart=false;
 _scanPacketCount=0;_scanPose=Pose();_lastSeqEnd=0;_lastAddress=-1;
 _previewStopOffset=-1;_previewFlushLast=false;
 _lastResolution=0;_lastAbsoluteOffset=0;_lastVersion=0;
 emit indexChanged();
 _pacing.invalidate(); _file.close(); _parser=std::make_unique<Parsers::FrameParser>();
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
// Full KLF index: scan physical byte offsets without importing the large
// KoggerApp Plot2D dependency graph. Work is spread across Qt event loops,
// so the G20 can continue displaying the file during indexing.
double NavoKoggerReplay::indexProgress() const {
 if(_indexReady)return 1.0;
 return _indexFile.isOpen() && _indexFile.size()>0
   ?std::clamp(double(_indexFile.pos())/double(_indexFile.size()),0.0,1.0):0.0;
}
int NavoKoggerReplay::currentColumn() const {
 if(_columns.isEmpty())return 0;
 const qint64 pos=_file.isOpen()?_file.pos():0;
 auto it=std::upper_bound(_columns.cbegin(),_columns.cend(),pos,
     [](qint64 value,const ColumnOffset& col){return value<col.offset;});
 return int(std::max<qint64>(0,std::distance(_columns.cbegin(),it)-1));
}
bool NavoKoggerReplay::seekColumn(int column) {
 if(_archive||!_indexReady||column<0||column>=_columns.size()||!_file.isOpen())return false;
 const auto entry=_columns.at(column);
 if(entry.offset<0||entry.offset>=_file.size()||!_file.seek(entry.offset))return false;
 const bool preservePause=_active && _paused;
 // For an already-paused replay, decode just enough to publish the selected
 // column (the NEXT CHART start closes it), then stop without autoplay.
 _previewStopOffset=preservePause
   ?(column+1<_columns.size()
       ?_columns.at(column+1).offset+_columns.at(column+1).firstPacketSize
       :_file.size()) : -1;
 _previewFlushLast=preservePause && column==_columns.size()-1;
 _parser=std::make_unique<Parsers::FrameParser>();
 _gpsFix=entry.pose.gpsFix;_lat=entry.pose.lat;_lon=entry.pose.lon;
 _heading=entry.pose.heading;_pitch=entry.pose.pitch;_roll=entry.pose.roll;
 // Recorded KBP frame ordinal, not an artificial new recording identity.
 _deliveredFrame=entry.frameBefore;_deliveredMilliseconds=-1;
 _pending=false;_blocked=false;_active=true;_paused=false;
 _error.clear();_pacing.start();_timer.start();
 emit annotationAnchorChanged();emit stateChanged();emit progressChanged();
 // The transport resets decoder/Dataset before calling seekColumn().
 // Decode from the selected *on-disk* column, never from file start.
 QTimer::singleShot(0,this,[this](){if(_active&&!_paused)tick();});
 return true;
}
void NavoKoggerReplay::beginIndexing() {
 // NAVOSONAR chunk archives need an independent record seek protocol.
 // KLF is byte-indexed; do not mislabel archive chunks as sonar columns.
 if(_archive)return;
 if(_file.size()<=0||_file.size()>2147483647LL)return;
 _indexFile.setFileName(_file.fileName());
 if(!_indexFile.open(QIODevice::ReadOnly)||_indexFile.isSequential())return;
 _indexTimer.start();
}
void NavoKoggerReplay::updatePose(Pose& pose,const uchar* raw,int len,bool v2) {
 const int header=v2?10:6;
 if(len<header+2)return;
 const int length=raw[1];
 if(header+length+2>len)return;
 const unsigned id=v2?(unsigned(raw[7])|(unsigned(raw[8])<<8)|(unsigned(raw[9])<<16)):raw[5];
 const uchar* p=raw+header;
 if(id==24&&length>=30){
  pose.gpsFix=p[28]>=3;
  pose.lat=pose.gpsFix?double(qFromLittleEndian<qint32>(p+8))*1e-7:qQNaN();
  pose.lon=pose.gpsFix?double(qFromLittleEndian<qint32>(p+12))*1e-7:qQNaN();
 }else if(id==33&&length>=28&&pose.gpsFix){
  pose.lat=double(qFromLittleEndian<qint32>(p+4))*1e-7;
  pose.lon=double(qFromLittleEndian<qint32>(p+8))*1e-7;
  const auto heading=qFromLittleEndian<quint16>(p+26);
  if(heading!=65535)pose.heading=heading*0.01;
 }else if(id==30&&length>=16){
  double* values[]={&pose.roll,&pose.pitch,&pose.heading};
  for(int k=0;k<3;k++){
   const quint32 bits=qFromLittleEndian<quint32>(p+4+k*4);
   float angle;std::memcpy(&angle,&bits,4);
   *values[k]=double(angle)*180.0/3.14159265358979323846;
  }
 }
}
bool NavoKoggerReplay::indexKoggerFrame(const char* bytes,int length,qint64 offset) {
 const auto* f=reinterpret_cast<const uchar*>(bytes);
 ++_scanPacketCount;
 const bool extended=f[0]==0xcc;
 int payloadStart=6,address=-1,type=0,version=0,id=0;
 if(extended) {
  const int options=f[4],header=4+options;
  if(options<3||header+3>length-2)return false;
  const quint16 flags=qFromLittleEndian<quint16>(f+5);
  int required=3;
  if(flags&2){required+=2;if(options>=5)address=f[7];}
  if(flags&4)required+=7;
  if(flags&8)required+=4;
  if((flags>>4)&3)required+=8;
  if((flags&1)||required>options)return false;
  const auto iv=qFromLittleEndian<quint16>(f+header+1);
  type=f[header]&3;id=iv>>3;version=iv&7;payloadStart=header+3;
 }else{
  address=f[2];type=f[3]&3;version=(f[3]>>3)&7;id=f[4];
 }
 if(type!=1||id!=3||(version!=0&&version!=1)||payloadStart+6>length-2)return false;
 const auto* p=f+payloadStart;
 const int seq=qFromLittleEndian<quint16>(p),res=qFromLittleEndian<quint16>(p+2);
 const int off=qFromLittleEndian<quint16>(p+4);
 const int payload=length-2-(payloadStart+6);
 if(res<=0||payload<=0||seq+payload>128*1024)return false;
 const bool newColumn=!_haveChart||seq==0||seq<_lastSeqEnd||
    res!=_lastResolution||off!=_lastAbsoluteOffset||
    version!=_lastVersion||address!=_lastAddress;
 if(newColumn){
  if(_columns.size()>=500000)return false;
  _columns.push_back({offset,_scanPacketCount-1,_scanPose,length});
 }
 _haveChart=true;_lastSeqEnd=seq+payload;_lastResolution=res;
 _lastAbsoluteOffset=off;_lastVersion=quint8(version);_lastAddress=address;
 return newColumn;
}
void NavoKoggerReplay::indexTick() {
 if(!_indexFile.isOpen()){_indexTimer.stop();return;}
 const QByteArray input=_indexFile.read(128*1024);
 if(!input.isEmpty())_indexBuffer+=input;
 if(_indexBuffer.size()>129*1024){_indexTimer.stop();_indexFile.close();return;}
 auto* bytes=reinterpret_cast<const uchar*>(_indexBuffer.constData());
 int i=0;
 while(i+8<=_indexBuffer.size()){
  const int available=_indexBuffer.size()-i;
  const uchar a=bytes[i],b=bytes[i+1];
  if((a==0xbb||a==0xcc)&&b==0x55){
   if(available<6)break;
   const int length=a==0xcc?int(qFromLittleEndian<quint16>(bytes+i+2)):8+int(bytes[i+5]);
   if(length<8||length>(a==0xcc?383:263)){++i;continue;}
   if(available<length)break;
   quint8 sum=0,check=0;
   for(int p=2;p<length-2;p++){sum=quint8(sum+bytes[i+p]);check=quint8(check+sum);}
   if(sum==bytes[i+length-2]&&check==bytes[i+length-1])
     indexKoggerFrame(_indexBuffer.constData()+i,length,_indexBufferOffset+i);
  }else if(a==0xfe||a==0xfd){
   if(available<(a==0xfd?10:6))break;
   const int size=(a==0xfd?12:8)+int(bytes[i+1])+
       ((a==0xfd&&(bytes[i+2]&1))?13:0);
   if(size<8||size>280){++i;continue;}
   if(available<size){
    if(!_indexFile.atEnd())break;
   }else{
    Parsers::FrameParser parser;
    parser.setContext(const_cast<uchar*>(bytes+i),size);
    parser.process();
    if(parser.isCompleteAsMAVLink()&&parser.frameLen()==size)
     updatePose(_scanPose,bytes+i,size,a==0xfd);
   }
  }
  // Advance one byte to also index CHART/MAVLink nested inside KP2 proxies.
  ++i;
 }
 if(_indexFile.atEnd())i=_indexBuffer.size();
 _indexBuffer.remove(0,i);_indexBufferOffset+=i;
 _indexProcessed=_indexFile.pos();
 if(_indexFile.atEnd()){
  _indexTimer.stop();_indexFile.close();_indexBuffer.clear();_indexReady=true;
 }
 emit indexChanged();
}
void NavoKoggerReplay::readPosition() {
 Pose pose{_gpsFix,_lat,_lon,_heading,_pitch,_roll};
 updatePose(pose,reinterpret_cast<const uchar*>(_parser->frame()),_parser->frameLen(),
            _parser->proto()==Parsers::FrameParser::ProtoMAVLink2);
 _gpsFix=pose.gpsFix;_lat=pose.lat;_lon=pose.lon;
 _heading=pose.heading;_pitch=pose.pitch;_roll=pose.roll;
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
 const qint64 remaining=_previewStopOffset>=0?_previewStopOffset-_file.pos():budget;
 if(_previewStopOffset>=0&&remaining<=0){
  _timer.stop();_paused=true;_previewStopOffset=-1;
  if(_previewFlushLast){_previewFlushLast=false;emit previewLastColumnReady();}
  emit stateChanged();return;
 }
 QByteArray bytes=_file.read(int(std::min<qint64>(budget,remaining)));
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
 if(_previewStopOffset>=0&&_file.pos()>=_previewStopOffset) {
  _timer.stop();_paused=true;_previewStopOffset=-1;
  if(_previewFlushLast){_previewFlushLast=false;emit previewLastColumnReady();}
  emit stateChanged();return;
 }
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
