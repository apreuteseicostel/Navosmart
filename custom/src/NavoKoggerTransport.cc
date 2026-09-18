#include "NavoKoggerTransport.h"
NavoKoggerTransport::NavoKoggerTransport(QObject*p):QObject(p){
 connect(&_socket,&QUdpSocket::readyRead,this,&NavoKoggerTransport::_read);
 connect(&_socket,&QUdpSocket::errorOccurred,this,[this](QAbstractSocket::SocketError){emit transportError(_socket.errorString());});
}
bool NavoKoggerTransport::startUdp(quint16 port){
 stop();_bytes=0;_lastSender.clear();
 bool ok=_socket.bind(QHostAddress::AnyIPv4,port,QUdpSocket::ShareAddress|QUdpSocket::ReuseAddressHint);
 emit stateChanged();return ok;
}
void NavoKoggerTransport::stop(){if(_socket.state()!=QAbstractSocket::UnconnectedState)_socket.close();emit stateChanged();}
void NavoKoggerTransport::_read(){
 while(_socket.hasPendingDatagrams()){
  QNetworkDatagram d=_socket.receiveDatagram();QByteArray b=d.data();if(b.isEmpty())continue;
  _lastSender=d.senderAddress().toString()+":"+QString::number(d.senderPort());_bytes+=quint64(b.size());
  emit bytesReady(b);emit statisticsChanged();emit stateChanged();
 }
}
