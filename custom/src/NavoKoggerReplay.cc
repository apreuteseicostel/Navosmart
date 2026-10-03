#include "NavoKoggerReplay.h"
#include <QtGlobal>
#include <algorithm>
NavoKoggerReplay::NavoKoggerReplay(QObject* parent):QObject(parent) {
 _timer.setInterval(40);
 connect(&_timer,&QTimer::timeout,this,&NavoKoggerReplay::tick);
}
bool NavoKoggerReplay::open(const QUrl& url) {
 stop(); _error.clear();
 if (!url.isLocalFile() && url.scheme()!=QLatin1String("content")) {
  _error=QStringLiteral("Selectează un fișier local .klf"); emit stateChanged(); return false;
 }
 _file.setFileName(url.isLocalFile()?url.toLocalFile():url.toString());
 if (!_file.open(QIODevice::ReadOnly)) {
  _error=_file.errorString(); emit stateChanged(); return false;
 }
 _active=true; _paused=false; _timer.start(); emit stateChanged(); emit progressChanged(); return true;
}
void NavoKoggerReplay::stop() {
 _timer.stop(); _file.close(); _pending.clear();
 _active=false; _paused=false; emit stateChanged(); emit progressChanged();
}
void NavoKoggerReplay::setPaused(bool value) {
 if (!_active || _paused==value)return;
 _paused=value; if(value)_timer.stop();else _timer.start(); emit stateChanged();
}
void NavoKoggerReplay::setSpeed(double value) {
 value=std::clamp(value,0.5,5.0);
 if(_speed==value)return;_speed=value;emit stateChanged();
}
void NavoKoggerReplay::tick() {
 if(!_active||_paused)return;
 // Frame-aligned chunks: the same decoder receives the exact KLF bytes as live TCP.
 // Bounded work on the UI thread; no full-recording memory allocation.
 const int budget=int(4096*_speed);
 int sent=0;
 while(sent<budget) {
  if(_pending.size()<4) {
   const QByteArray more=_file.read(4-_pending.size());
   if(more.isEmpty())break;
   _pending.append(more);
  }
  if(_pending.size()<4)break;
  if(quint8(_pending[0])!=0xcc && quint8(_pending[0])!=0xbb) {
   _pending.remove(0,1); continue;
  }
  if(quint8(_pending[1])!=0x55) { _pending.remove(0,1);continue; }
  int len=quint8(_pending[0])==0xcc
      ? (quint8(_pending[2]) | (int(quint8(_pending[3]))<<8))
      : -1;
  if(len<0) {
   const QByteArray more=_file.read(2);
   _pending.append(more);
   if(_pending.size()<6)break;
   len=8+quint8(_pending[5]);
  }
  if(len<8 || len>383) { _pending.remove(0,1);continue; }
  if(_pending.size()<len)_pending.append(_file.read(len-_pending.size()));
  if(_pending.size()<len)break;
  emit bytesReady(_pending.left(len));
  _pending.remove(0,len);sent+=len;
 }
 emit progressChanged();
 if(_file.atEnd()) {
  // Do not feed a trailing, incomplete frame into the decoder.
  stop();
 }
}
