#include "NavoKoggerTcpClient.h"
NavoKoggerTcpClient::NavoKoggerTcpClient(QObject* p):QObject(p){
 connect(&_socket,&QTcpSocket::connected,this,[this]{setStatus("CONECTAT");emit connectedChanged();});
 connect(&_socket,&QTcpSocket::disconnected,this,[this]{setStatus("DECONECTAT");emit connectedChanged();});
 connect(&_socket,&QTcpSocket::readyRead,this,[this]{auto b=_socket.readAll();if(!b.isEmpty())emit bytesReceived(b);});
 connect(&_socket,&QTcpSocket::errorOccurred,this,[this](QAbstractSocket::SocketError){setStatus("EROARE: "+_socket.errorString());});
}
void NavoKoggerTcpClient::setStatus(const QString&s){if(_status==s)return;_status=s;emit statusChanged();}
void NavoKoggerTcpClient::connectToSonar(){if(_host.isEmpty()||!_port){setStatus("ENDPOINT INVALID");return;}if(_socket.state()!=QAbstractSocket::UnconnectedState)_socket.abort();setStatus("CONECTARE…");_socket.connectToHost(_host,_port);}
void NavoKoggerTcpClient::disconnectFromSonar(){_socket.disconnectFromHost();}
