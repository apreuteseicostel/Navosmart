#include "NavoKoggerTcpClient.h"
NavoKoggerTcpClient::NavoKoggerTcpClient(QObject*p):QObject(p){
 _retry.setSingleShot(true);_retry.setInterval(2500);connect(&_retry,&QTimer::timeout,this,&NavoKoggerTcpClient::connectToSonar);
 connect(&_socket,&QTcpSocket::connected,this,[this]{_retry.stop();setStatus("CONECTAT");emit connectedChanged();});
 connect(&_socket,&QTcpSocket::disconnected,this,[this]{setStatus("DECONECTAT");emit connectedChanged();scheduleReconnect();});
 connect(&_socket,&QTcpSocket::readyRead,this,[this]{auto b=_socket.readAll();if(b.isEmpty())return;_rxBytes+=quint64(b.size());++_rxChunks;emit statisticsChanged();emit bytesReceived(b);});
 connect(&_socket,&QTcpSocket::errorOccurred,this,[this](QAbstractSocket::SocketError){setStatus("EROARE: "+_socket.errorString());scheduleReconnect();});
}
void NavoKoggerTcpClient::setStatus(const QString&s){if(_status==s)return;_status=s;emit statusChanged();}
void NavoKoggerTcpClient::scheduleReconnect(){if(_autoReconnect&&!_manualStop&&!_retry.isActive()){setStatus("RECONECTARE…");_retry.start();}}
void NavoKoggerTcpClient::connectToSonar(){_manualStop=false;if(_host.isEmpty()||!_port){setStatus("ENDPOINT INVALID");return;}if(_socket.state()!=QAbstractSocket::UnconnectedState)_socket.abort();setStatus("CONECTARE…");_socket.connectToHost(_host,_port);}
void NavoKoggerTcpClient::disconnectFromSonar(){_manualStop=true;_retry.stop();_socket.abort();setStatus("OPRIT");emit connectedChanged();}
