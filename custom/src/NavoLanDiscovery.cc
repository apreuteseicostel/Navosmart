#include "NavoLanDiscovery.h"
#include <QAbstractSocket>
NavoLanDiscovery::NavoLanDiscovery(QObject* parent):QObject(parent){}
void NavoLanDiscovery::stop(){
 ++_generation; _queue.clear();
 for(auto* socket : _active){socket->disconnect(this);socket->abort();socket->deleteLater();}
 _active.clear();
 if(_scanning){_scanning=false;emit scanningChanged();}
}
void NavoLanDiscovery::scan(){
 stop();_devices.clear();emit devicesChanged();
 QSet<quint32> subnets;
 for(const auto& iface:QNetworkInterface::allInterfaces()){
  if(!(iface.flags() & QNetworkInterface::IsUp) || (iface.flags() & QNetworkInterface::IsLoopBack))continue;
  for(const auto& entry:iface.addressEntries()){
   const auto ip=entry.ip();
   if(ip.protocol()!=QAbstractSocket::IPv4Protocol || ip.isLoopback())continue;
   subnets.insert(ip.toIPv4Address() & 0xffffff00u);
  }
 }
 // Limit to two /24 networks; do not scan mobile/VPN-wide address ranges.
 int networks=0;
 for(quint32 subnet:subnets){
  if(networks++>=2)break;
  for(quint32 host=1;host<255;++host){
   const auto address=QHostAddress(subnet|host).toString();
   for(quint16 port:{quint16(80),quint16(554),quint16(8899)})
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
 auto* completed=new bool(false);
 auto finish=[this,socket,timeout,completed,host,port](bool ok){
  if(*completed)return;
  *completed=true;timeout->stop();emit probeResult(host,port,ok);
  socket->abort();socket->deleteLater();delete completed;
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
  auto done=[this,socket,timer,target,generation](bool ok){
   if(!_active.contains(socket))return;
   _active.remove(socket);timer->stop();
   if(ok && generation==_generation){
    QVariantMap item{{"host",target.host},{"port",int(target.port)},{"role",QStringLiteral("candidate")},{"verified",false}};
    _devices.append(item);emit devicesChanged();
   }
   socket->abort();socket->deleteLater();finishOne();
  };
  connect(timer,&QTimer::timeout,socket,[done]{done(false);});
  connect(socket,&QTcpSocket::connected,socket,[done]{done(true);});
  connect(socket,&QTcpSocket::errorOccurred,socket,[done](QAbstractSocket::SocketError){done(false);});
  timer->start(450);socket->connectToHost(target.host,target.port);
 }
 if(_scanning && _queue.isEmpty() && _active.isEmpty()){_scanning=false;emit scanningChanged();}
}
void NavoLanDiscovery::finishOne(){pump();}
