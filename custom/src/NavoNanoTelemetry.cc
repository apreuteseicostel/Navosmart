#include "NavoNanoTelemetry.h"
#include <QStringList>
bool NavoNanoTelemetry::ingestLine(const QString& input){
 QString s=input.trimmed(); if(!s.startsWith('$')){emit frameRejected("prefix");return false;} int star=s.lastIndexOf('*'); if(star<2||star+2>=s.size()){emit frameRejected("format");return false;}
 QByteArray p=s.mid(1,star-1).toLatin1(); bool ok=false; int rx=s.mid(star+1,2).toInt(&ok,16); if(!ok){emit frameRejected("checksum");return false;} quint8 cs=0; for(char c:p)cs^=(quint8)c; if(cs!=rx){emit frameRejected("checksum");return false;}
 QStringList f=QString::fromLatin1(p).split(','); if(f.size()!=13||f[0]!="NAVO"||f[1]!="1"){emit frameRejected("version");return false;}
 bool all=true,o=true; auto ui=[&](int i){uint v=f[i].toUInt(&o);all&=o;return v;}; auto si=[&](int i){int v=f[i].toInt(&o);all&=o;return v;};
 ui(2); quint32 batt=ui(3); int temp=si(4); bool water=ui(5),wf=ui(6),head=ui(7),pos=ui(8); int hl=ui(9),hr=ui(10),rud=ui(11),alarm=ui(12);
 if(!all||batt>30000||temp>1500||temp<-32768){emit frameRejected("range");return false;}
 _batteryMv=batt;_tempC10=(qint16)temp;_water=water;_waterFault=wf;_head=head;_pos=pos;_hl=hl;_hr=hr;_rud=rud;_alarm=alarm;_connected=true;emit telemetryChanged();return true;
}
