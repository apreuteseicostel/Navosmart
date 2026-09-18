#include "NavoKoggerDecoder.h"
#include <QtCore/QtEndian>
#include <cstring>
NavoKoggerDecoder::NavoKoggerDecoder(QObject* p):QObject(p){}
quint16 NavoKoggerDecoder::le16(const char* p){return qFromLittleEndian<quint16>(reinterpret_cast<const uchar*>(p));}
quint32 NavoKoggerDecoder::le32(const char* p){return qFromLittleEndian<quint32>(reinterpret_cast<const uchar*>(p));}
void NavoKoggerDecoder::reset(){_buffer.clear();_chart.clear();_echoSamples.clear();_connected=false;_depthM=qQNaN();_waterTempC=qQNaN();emit connectedChanged();emit depthChanged();emit temperatureChanged();emit echoSamplesChanged();}
void NavoKoggerDecoder::feedBytes(const QByteArray& b){if(b.isEmpty())return;_buffer.append(b);process();}
bool NavoKoggerDecoder::validFrame(const QByteArray& f)const{
 if(f.size()<8||quint8(f[0])!=0xBB||quint8(f[1])!=0x55)return false;
 quint8 a=0,b=0;for(int i=2;i<f.size()-2;i++){a=quint8(a+quint8(f[i]));b=quint8(b+a);}
 return a==quint8(f[f.size()-2])&&b==quint8(f[f.size()-1]);
}
void NavoKoggerDecoder::process(){
 while(true){
  int s=_buffer.indexOf(QByteArray::fromHex("bb55"));if(s<0){if(_buffer.size()>1)_buffer=_buffer.right(1);return;}if(s>0)_buffer.remove(0,s);if(_buffer.size()<8)return;
  int payload=quint8(_buffer[5]);int total=8+payload;if(_buffer.size()<total)return;QByteArray f=_buffer.left(total);_buffer.remove(0,total);
  if(!validFrame(f)){emit frameRejected();continue;}if(!_connected){_connected=true;emit connectedChanged();}
  quint8 mode=quint8(f[3]);quint8 version=(mode>>3)&0x07;quint8 id=quint8(f[4]);const char* p=f.constData()+6;
  if(id==0x02&&version==0&&payload>=4){_depthM=double(le32(p))/1000.0;emit depthChanged();}
  else if(id==0x05&&version==0&&payload>=2){qint16 raw=qFromLittleEndian<qint16>(reinterpret_cast<const uchar*>(p));_waterTempC=double(raw)*0.01;emit temperatureChanged();}
  else if(id==0x03&&(version==0||version==1)&&payload>=6){
   quint16 seq=le16(p),res=le16(p+2),off=le16(p+4);QByteArray part(p+6,payload-6);
   if(seq==0||res!=_chartResolution||off!=_chartAbsoluteOffset){if(!_chart.isEmpty()){QVariantList out;int step=version==1?2:1;for(int i=0;i<_chart.size();i+=step)out.append(double(quint8(_chart[i]))/255.0);_echoSamples=out;emit echoSamplesChanged();}_chart.clear();_chartResolution=res;_chartAbsoluteOffset=off;}
   if(seq==_chart.size()) { _chart.append(part); }\n   else if(seq>_chart.size()) { _chart.append(QByteArray(seq-_chart.size(), char(0))); _chart.append(part); }\n   else if(seq<_chart.size()) { _chart.clear(); _chart.append(QByteArray(seq, char(0))); _chart.append(part); }
  }
 }
}