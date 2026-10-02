#include "NavoLanDiscovery.h"
#include <QAbstractSocket>
#include <QSharedPointer>
#include "NavoKoggerDecoder.h"
NavoLanDiscovery::NavoLanDiscovery(QObject* parent):QObject(parent){}
void NavoLanDiscovery::stop(){
 ++_generation; _queue.clear();
 const auto active=_active; _active.clear();
 for(auto* socket : active){socket->disconnect();socket->abort();socket->deleteLater();}
 if(_scanning){_scanning=false;emit scanningChanged();}
}
void NavoLanDiscovery::scan(){
 stop();_devices.clear();emit devicesChanged();
 QSet<quint32> subnets;
 for(const auto& iface:QNetworkInterface::allInterfaces()){
  if(!(iface.flags() & QNetworkInterface::IsUp) || (iface.flags() & QNetworkInterface::IsLoopBack) || (iface.type()!=QNetworkInterface::Ethernet && iface.type()!=QNetworkInterface::Wifi))continue;
  for(const auto& entry:iface.addressEntries()){
   const auto ip=entry.ip();
   if(ip.protocol()!=QAbstractSocket::IPv4Protocol || ip.isLoopback())continue;
   const quint32 address=ip.toIPv4Address();
   const bool privateLan=(address>>24)==10 || (address>>20)==0xac1 || (address>>16)==0xc0a8;
   if(!privateLan || entry.prefixLength()<1 || entry.prefixLength()>24)continue;
   subnets.insert(address & 0xffffff00u);
  }
 }
 // Limit to two /24 networks; do not scan mobile/VPN-wide address ranges.
 int networks=0;
 for(quint32 subnet:subnets){
  if(networks++>=2)break;
  for(quint32 host=1;host<255;++host){
   const auto address=QHostAddress(subnet|host).toString();
   if(address==protectedHost)continue; // Never seize a live single-client serial bridge.
   for(quint16 port:{quint16(80),quint16(554),quint16(qBound(1,serialPort,65535))})
    _queue.enqueue({address,port});
  }
 }
 if(_queue.isEmpty())return;
 _scanning=true;emit scanningChanged();pump();
}
void NavoLanDiscovery::probe(const QString& host,int port){
 if(host.trimmed().isEmpty()||port<1||port>65535){emit probeResult(host,port,false);return;}
 auto* socket=new QTcpSocket(this);
 auto* timeout=new QTimer(socket);timeout->setSingleShot(true);
 auto completed=QSharedPointer<bool>::create(false);
 auto finish=[this,socket,timeout,completed,host,port](bool ok){
  if(*completed)return;
  *completed=true;timeout->stop();emit probeResult(host,port,ok);
  socket->abort();socket->deleteLater();
 };
 connect(timeout,&QTimer::timeout,socket,[finish]{finish(false);});
 connect(socket,&QTcpSocket::connected,socket,[finish]{finish(true);});
 connect(socket,&QTcpSocket::errorOccurred,socket,[finish](QAbstractSocket::SocketError){finish(false);});
 timeout->start(1500);socket->connectToHost(host,quint16(port));
}
void NavoLanDiscovery::pump(){
 while(_scanning && _active.size()<concurrency && !_queue.isEmpty()){
  const Target target=_queue.dequeue();const int generation=_generation;
  auto* socket=new QTcpSocket(this);_active.insert(socket);
  auto* timer=new QTimer(socket);timer->setSingleShot(true);
  auto response=QSharedPointer<QByteArray>::create();
  auto role=QSharedPointer<QString>::create(QStringLiteral("TCP • neidentificat"));
  auto opened=QSharedPointer<bool>::create(false);
  auto* decoder=new NavoKoggerDecoder(socket);
  auto done=[this,socket,timer,target,generation,role](bool ok){
   if(!_active.contains(socket))return;
   _active.remove(socket);timer->stop();
   if(ok && generation==_generation){
    QVariantMap item{{"host",target.host},{"port",int(target.port)},{"role",*role},{"verified",*role!=QStringLiteral("TCP • neidentificat")}};
    _devices.append(item);emit devicesChanged();
   }
   socket->disconnect();socket->abort();socket->deleteLater();QTimer::singleShot(0,this,&NavoLanDiscovery::finishOne);
  };
  connect(timer,&QTimer::timeout,socket,[done,opened]{done(*opened);});
  connect(socket,&QTcpSocket::connected,socket,[socket,timer,target,opened]{
   *opened=true;timer->start(1000);
   if(target.port==80) socket->write("GET / HTTP/1.0\r\nHost: "+target.host.toUtf8()+"\r\n\r\n");
   else if(target.port==554) socket->write("OPTIONS rtsp://"+target.host.toUtf8()+"/ RTSP/1.0\r\nCSeq: 1\r\n\r\n");
   // Serial candidates are passive: never send unknown commands to the sonar.
  });
  connect(socket,&QTcpSocket::readyRead,socket,[socket,response,role,decoder,done]{
   const auto bytes=socket->readAll();
   if(response->size()<32768)response->append(bytes.left(32768-response->size()));
   decoder->feedBytes(bytes);
   const auto lower=response->toLower();
   if(decoder->connected()) *role=QStringLiteral("KOGGER");
   else if(response->startsWith("RTSP/1.0 ")) *role=QStringLiteral("RTSP");
   else if(response->startsWith("HTTP/") && (lower.contains("usr-tcp") || lower.contains("usr iot") || lower.contains("pusr"))) *role=QStringLiteral("USR • interfață web");
   if(*role!=QStringLiteral("TCP • neidentificat"))done(true);
  });
  connect(socket,&QTcpSocket::disconnected,socket,[done,opened]{done(*opened);});
  connect(socket,&QTcpSocket::errorOccurred,socket,[done,opened](QAbstractSocket::SocketError){done(*opened);});
  timer->start(450);socket->connectToHost(target.host,target.port);
 }
 if(_scanning && _queue.isEmpty() && _active.isEmpty()){_scanning=false;emit scanningChanged();}
}
void NavoLanDiscovery::finishOne(){pump();}
