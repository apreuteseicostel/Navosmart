#include "NavoKoggerDecoder.h"
#include <QtCore/QtEndian>
#include <cstring>
NavoKoggerDecoder::NavoKoggerDecoder(QObject* p):QObject(p){}
quint16 NavoKoggerDecoder::le16(const char* p){return qFromLittleEndian<quint16>(reinterpret_cast<const uchar*>(p));}
quint32 NavoKoggerDecoder::le32(const char* p){return qFromLittleEndian<quint32>(reinterpret_cast<const uchar*>(p));}
void NavoKoggerDecoder::reset(){_buffer.clear();_chart.clear();_echoSamples.clear();_connected=false;_depthM=qQNaN();_waterTempC=qQNaN();emit connectedChanged();emit depthChanged();emit temperatureChanged();emit echoSamplesChanged();}
void NavoKoggerDecoder::feedBytes(const QByteArray& b){
 if(b.isEmpty())return;
 _buffer.append(b);
 if(_buffer.size()>MaxBufferBytes){
  int sync=_buffer.lastIndexOf(QByteArray::fromHex("bb55"));
  if(sync>=0)_buffer=_buffer.mid(sync);else _buffer.clear();
  emit frameRejected();
 }
 process();
}
bool NavoKoggerDecoder::validFrame(const QByteArray& f)const{
 if(f.size()<8||quint8(f[0])!=0xBB||quint8(f[1])!=0x55)return false;
 quint8 a=0,b=0;for(int i=2;i<f.size()-2;i++){a=quint8(a+quint8(f[i]));b=quint8(b+a);}
 return a==quint8(f[f.size()-2])&&b==quint8(f[f.size()-1]);
}
void NavoKoggerDecoder::process(){
 while(true){
  int s=_buffer.indexOf(QByteArray::fromHex("bb55"));if(s<0){if(_buffer.size()>1)_buffer=_buffer.right(1);return;}if(s>0)_buffer.remove(0,s);if(_buffer.size()<8)return;
  int payload=quint8(_buffer[5]);int total=8+payload;
  if(total<8||total>263){_buffer.remove(0,1);emit frameRejected();continue;}
  if(_buffer.size()<total)return;
  QByteArray f=_buffer.left(total);
  if(!validFrame(f)){
   // Drop one byte only, then rescan for BB55. This preserves a valid frame that
   // may already follow a corrupt length/checksum instead of discarding it.
   _buffer.remove(0,1);emit frameRejected();continue;
  }
  _buffer.remove(0,total);if(!_connected){_connected=true;emit connectedChanged();}
  quint8 mode=quint8(f[3]);quint8 version=(mode>>3)&0x07;quint8 id=quint8(f[4]);const char* p=f.constData()+6;
  if(id==0x02&&version==0&&payload>=4){_depthM=double(le32(p))/1000.0;emit depthChanged();}
  else if(id==0x05&&version==0&&payload>=2){qint16 raw=qFromLittleEndian<qint16>(reinterpret_cast<const uchar*>(p));_waterTempC=double(raw)*0.01;emit temperatureChanged();}
  else if(id==0x03&&(version==0||version==1)&&payload>=6){
   quint16 seq=le16(p),res=le16(p+2),off=le16(p+4);QByteArray part(p+6,payload-6);
   if(res==0){_chart.clear();emit frameRejected();continue;}
   // Kogger CHART sampleResol describes sample resolution, not the byte
   // length of an echogram column. The official KoggerApp closes the
   // previous column when a new sequence starts (seqOffset == 0) or the
   // resolution/absolute-offset metadata changes.
   const bool newColumn=(seq==0&&!_chart.isEmpty())||
                        (!_chart.isEmpty()&&(res!=_chartResolution||off!=_chartAbsoluteOffset));
   if(newColumn){
    QVariantList out;int step=version==1?2:1;
    for(int i=0;i+step-1<_chart.size();i+=step)out.append(double(quint8(_chart[i]))/255.0);
    if(!out.isEmpty()){_echoSamples=out;emit echoSamplesChanged();}
    _chart.clear();
   }
   if(_chart.isEmpty()){_chartResolution=res;_chartAbsoluteOffset=off;}
   if(int(seq)+part.size()>MaxChartBytes){_chart.clear();emit frameRejected();continue;}
   if(seq==_chart.size()) { _chart.append(part); }
   else if(seq>_chart.size()) {
    // Match KoggerApp loss handling: preserve seqOffset by zero-filling
    // missing fragments instead of discarding the whole column.
    _chart.append(QByteArray(int(seq)-_chart.size(), char(0)));_chart.append(part);
   }
   else {
    // A backwards seqOffset means the first fragment(s) of a new column
    // were lost. Publish what we assembled, then rebuild at the advertised
    // offset with zero-fill, as KoggerApp does.
    QVariantList out;int step=version==1?2:1;
    for(int i=0;i+step-1<_chart.size();i+=step)out.append(double(quint8(_chart[i]))/255.0);
    if(!out.isEmpty()){_echoSamples=out;emit echoSamplesChanged();}
    _chart=QByteArray(int(seq),char(0));_chart.append(part);
    _chartResolution=res;_chartAbsoluteOffset=off;
   }
  }
 }
}