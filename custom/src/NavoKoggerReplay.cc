#include "NavoKoggerReplay.h"
#include "../../third_party/KoggerApp/src/proto_binnary.h"
#include <QtEndian>
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
  _error=QStringLiteral("Selectează un fișier local .klf"); emit stateChanged(); return false;
 }
 _file.setFileName(url.isLocalFile()?url.toLocalFile():url.toString());
 if (!_file.open(QIODevice::ReadOnly)) { _error=_file.errorString(); emit stateChanged(); return false; }
 _active=true; _paused=false; _timer.start(); emit stateChanged(); emit progressChanged(); return true;
}
void NavoKoggerReplay::stop() {
 _timer.stop(); _file.close(); _parser=std::make_unique<Parsers::FrameParser>();
 _active=false; _paused=false; _blocked=false; _gpsFix=false;
 _lat=_lon=_heading=_pitch=_roll=qQNaN(); emit stateChanged(); emit progressChanged();
}
void NavoKoggerReplay::setPaused(bool value) {
 if (!_active || _paused==value)return;
 _paused=value; if(value)_timer.stop();else _timer.start(); emit stateChanged();
}
void NavoKoggerReplay::setSpeed(double value) {
 value=std::clamp(value,0.5,5.0);
 if(_speed==value)return;_speed=value;emit stateChanged();
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
 if(!_active||_paused||_blocked)return;
 QByteArray bytes=_file.read(int(4096*_speed));
 _parser->setContext(reinterpret_cast<uint8_t*>(bytes.data()),bytes.size());
 while(_parser->availContext()>0) {
  _parser->process();
  if(_parser->isCompleteAsMAVLink())readPosition();
  else if(_parser->completeAsKBP() || _parser->completeAsKBP2()) {
   // Refresh recorded position immediately before feeding each frame. No live vehicle GPS.
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
