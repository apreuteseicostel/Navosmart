#include "NavoKoggerDecoder.h"
#include <QtCore/QtEndian>
#include <cstring>
#include <algorithm>
#include <cmath>
NavoKoggerDecoder::NavoKoggerDecoder(QObject* p):QObject(p){}
void NavoKoggerDecoder::publishChart(){
 QVariantList raw, compensated;
 const int step=_chartVersion==1?2:1;
 const float resolution=float(_chartResolution)*0.001f;
 // KoggerApp Epoch::Echogram::compensateInPlace, retained as the original
 // amplitude-compensation algorithm on our decoded 8-bit CHART samples.
 float average=255.f;
 for(int i=0, sample=0;i+step-1<_chart.size();i+=step,++sample){
  const quint8 amplitude=quint8(_chart[i]);
  raw.append(double(amplitude)/255.0);
  float value=float(amplitude);
  average+=(value-average)*(0.05f+average*0.0006f);
  value=(value-average*0.55f)*(0.85f+float(sample)*resolution*0.006f)*2.f;
  value=std::clamp(value,0.f,255.f);
  compensated.append(double(quint8(value))/255.0);
 }
 if(raw.isEmpty())return;
 ++_chartSequence;
 _publishedChartAddress=_chartAddress;
 _publishedChartResolution=_chartResolution;
 _publishedChartAbsoluteOffset=_chartAbsoluteOffset;
 _publishedChartVersion=_chartVersion;
 _publishedChartRaw=_chart;
 _echoSamples=raw;
 _compensatedSamples=compensated;
 emit chartColumnReady();
 emit echoSamplesChanged();
}
quint16 NavoKoggerDecoder::le16(const char* p){return qFromLittleEndian<quint16>(reinterpret_cast<const uchar*>(p));}
quint32 NavoKoggerDecoder::le32(const char* p){return qFromLittleEndian<quint32>(reinterpret_cast<const uchar*>(p));}
void NavoKoggerDecoder::reset(){_buffer.clear();_chart.clear();_publishedChartRaw.clear();_echoSamples.clear();_compensatedSamples.clear();_chartAddress=-1;_publishedChartAddress=-1;_chartResolution=0;_chartAbsoluteOffset=0;_chartVersion=0;_publishedChartResolution=0;_publishedChartAbsoluteOffset=0;_publishedChartVersion=0;_connected=false;_depthM=qQNaN();_waterTempC=qQNaN();emit connectedChanged();emit depthChanged();emit temperatureChanged();emit echoSamplesChanged();}
void NavoKoggerDecoder::feedBytes(const QByteArray& b){
 if(b.isEmpty())return;
 for(qsizetype offset=0;offset<b.size();){
  const qsizetype size=std::min(qsizetype(4096),b.size()-offset);
  _buffer.append(b.constData()+offset,size);
  offset+=size;
  process();
 }

}
bool NavoKoggerDecoder::validFrame(const QByteArray& f)const{
 if(f.size()<8||(quint8(f[0])!=0xBB&&quint8(f[0])!=0xCC)||quint8(f[1])!=0x55)return false;
 quint8 a=0,b=0;for(int i=2;i<f.size()-2;i++){a=quint8(a+quint8(f[i]));b=quint8(b+a);}
 return a==quint8(f[f.size()-2])&&b==quint8(f[f.size()-1]);
}
void NavoKoggerDecoder::process(){
 while(true){
  const int kp1=_buffer.indexOf(QByteArray::fromHex("bb55"));
  const int kp2=_buffer.indexOf(QByteArray::fromHex("cc55"));
  const int sync=kp1<0?kp2:(kp2<0?kp1:std::min(kp1,kp2));
  if(sync<0){if(_buffer.size()>1)_buffer=_buffer.right(1);return;}
  if(sync>0)_buffer.remove(0,sync);
  if(_buffer.size()<8)return;
  const bool extended=quint8(_buffer[0])==0xCC;
  const int total=extended?int(le16(_buffer.constData()+2)):8+quint8(_buffer[5]);
  // Upstream FrameParser uses a 384-byte KP2 buffer.
  if(total<8||total>(extended?383:263)){_buffer.remove(0,1);emit frameRejected();continue;}
  if(_buffer.size()<total)return;
  QByteArray f=_buffer.left(total);
  if(!validFrame(f)){
   _buffer.remove(0,1);emit frameRejected();continue;
  }
  _buffer.remove(0,total);
  int payloadStart=6;
  quint8 version=0, type=0;
  quint16 id=0;
  int address=-1;
  if(extended){
   const int optionsLen=quint8(f[4]);
   const int header=4+optionsLen;
   if(optionsLen<3||header+3>total-2){emit frameRejected();continue;}
   const quint16 flags=le16(f.constData()+5);
   int required=3; // length byte and option flags
   if(flags&2){required+=2;address=quint8(f[7]);} // destination and source addresses
   if(flags&4)required+=7; // stream flags, id and offset
   if(flags&8)required+=4; // local time
   if((flags>>4)&3)required+=8; // global time
   // Proxy payloads contain another protocol, not a CHART payload.
   if((flags&1)||required>optionsLen){emit frameRejected();continue;}
   const quint16 idVersion=le16(f.constData()+header+1);
   type=quint8(f[header])&3;
   id=idVersion>>3;
   version=idVersion&7;
   payloadStart=header+3;
  }else{
   const quint8 mode=quint8(f[3]);
   type=mode&3;version=(mode>>3)&7;id=quint8(f[4]);address=quint8(f[2]);
  }
  if(!_connected){_connected=true;emit connectedChanged();}
  // SETTING/GETTING responses must not enter the measurement stream.
  if(type!=1)continue;
  const int payload=total-2-payloadStart;
  const char* p=f.constData()+payloadStart;
  if(id==0x02&&version==0&&payload>=4){_depthM=double(le32(p))/1000.0;emit depthChanged();}
  else if(id==0x05&&version==0&&payload>=2){qint16 raw=qFromLittleEndian<qint16>(reinterpret_cast<const uchar*>(p));_waterTempC=double(raw)*0.01;emit temperatureChanged();}
  else if(id==0x03&&(version==0||version==1)&&payload>=6){
   quint16 seq=le16(p),res=le16(p+2),off=le16(p+4);QByteArray part(p+6,payload-6);
   if(res==0){_chart.clear();_chartResolution=0;_chartAbsoluteOffset=0;_chartVersion=0;emit frameRejected();continue;}
   // Kogger CHART sampleResol describes sample resolution, not the byte
   // length of an echogram column. The official KoggerApp closes the
   // previous column when a new sequence starts (seqOffset == 0) or the
   // resolution/absolute-offset metadata changes.
   const bool newColumn=(seq==0&&!_chart.isEmpty())||
                        (!_chart.isEmpty()&&(res!=_chartResolution||off!=_chartAbsoluteOffset||version!=_chartVersion||address!=_chartAddress));
   if(newColumn){
    publishChart();
    _chart.clear();
   }
   if(_chart.isEmpty()){_chartAddress=address;_chartResolution=res;_chartAbsoluteOffset=off;_chartVersion=version;}
   if(int(seq)+part.size()>MaxChartBytes){_chart.clear();_chartResolution=0;_chartAbsoluteOffset=0;_chartVersion=0;emit frameRejected();continue;}
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
    publishChart();
    _chart=QByteArray(int(seq),char(0));_chart.append(part);
    _chartAddress=address;_chartResolution=res;_chartAbsoluteOffset=off;_chartVersion=version;
   }
  }
 }
}