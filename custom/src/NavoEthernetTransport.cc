#include "NavoEthernetTransport.h"
#include <QHostAddress>
NavoEthernetTransport::NavoEthernetTransport(QObject* p):QObject(p){
 connect(&_tcp,&QTcpSocket::connected,this,[this]{setConnected(true);setStatus(QStringLiteral("LIVE"));});
 connect(&_tcp,&QTcpSocket::disconnected,this,[this]{setConnected(false);setStatus(QStringLiteral("OFFLINE"));});
 connect(&_tcp,&QTcpSocket::readyRead,this,&NavoEthernetTransport::readTcp);
 connect(&_udpSocket,&QUdpSocket::readyRead,this,&NavoEthernetTransport::readUdp);
 connect(&_tcp,&QTcpSocket::errorOccurred,this,[this](QAbstractSocket::SocketError){setStatus(_tcp.errorString());});
}
void NavoEthernetTransport::setHost(const QString& v){if(_host==v)return;_host=v;emit endpointChanged();}
void NavoEthernetTransport::setPort(quint16 v){if(_port==v)return;_port=v;emit endpointChanged();}
void NavoEthernetTransport::setUdp(bool v){if(_udp==v)return;_udp=v;emit endpointChanged();}
void NavoEthernetTransport::setConnected(bool v){if(_connected==v)return;_connected=v;emit connectedChanged();}
void NavoEthernetTransport::setStatus(const QString& v){if(_status==v)return;_status=v;emit statusChanged();}
void NavoEthernetTransport::disconnectEndpoint(){_tcp.abort();_udpSocket.close();setConnected(false);setStatus(QStringLiteral("OFFLINE"));}
void NavoEthernetTransport::connectEndpoint(){
 disconnectEndpoint(); if(_host.isEmpty()||!_port){setStatus(QStringLiteral("ENDPOINT INVALID"));return;}
 setStatus(QStringLiteral("CONNECTING"));
 if(_udp){QHostAddress a;if(!a.setAddress(_host)){setStatus(QStringLiteral("UDP HOST INVALID"));return;}
  if(!_udpSocket.bind(QHostAddress::AnyIPv4,0)){setStatus(_udpSocket.errorString());return;}setConnected(true);setStatus(QStringLiteral("UDP READY"));}
 else _tcp.connectToHost(_host,_port);
}
void NavoEthernetTransport::readTcp(){const auto b=_tcp.readAll();if(!b.isEmpty())emit bytesReceived(b);}
void NavoEthernetTransport::readUdp(){while(_udpSocket.hasPendingDatagrams()){auto d=_udpSocket.receiveDatagram();if(!d.data().isEmpty())emit bytesReceived(d.data());}}
