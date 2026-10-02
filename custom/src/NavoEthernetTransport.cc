#include "NavoEthernetTransport.h"
#include <QHostAddress>

NavoEthernetTransport::NavoEthernetTransport(QObject* p):QObject(p)
{
    connect(&_tcp,&QTcpSocket::connected,this,[this]{_connectTimeout.stop();setConnected(true);setStatus(QStringLiteral("CONNECTED • WAITING DATA"));});
    connect(&_tcp,&QTcpSocket::disconnected,this,[this]{setConnected(false);setDataAlive(false);setStatus(QStringLiteral("OFFLINE"));scheduleReconnect();});
    connect(&_tcp,&QTcpSocket::readyRead,this,&NavoEthernetTransport::readTcp);
    connect(&_tcp,&QTcpSocket::errorOccurred,this,[this](QAbstractSocket::SocketError){_connectTimeout.stop();setConnected(false);setDataAlive(false);setStatus(_tcp.errorString());scheduleReconnect();});
    connect(&_udpSocket,&QUdpSocket::readyRead,this,&NavoEthernetTransport::readUdp);
    connect(&_healthTimer,&QTimer::timeout,this,&NavoEthernetTransport::healthTick);
    connect(&_reconnectTimer,&QTimer::timeout,this,&NavoEthernetTransport::connectEndpoint);
    _connectTimeout.setSingleShot(true);
    connect(&_connectTimeout,&QTimer::timeout,this,[this]{_tcp.abort();setConnected(false);setDataAlive(false);setStatus(QStringLiteral("CONNECT TIMEOUT"));scheduleReconnect();});
    _healthTimer.start(1000);
    _reconnectTimer.setSingleShot(true);
}

void NavoEthernetTransport::setHost(const QString& v){if(_host==v)return;disconnectEndpoint();_host=v.trimmed();emit endpointChanged();}
void NavoEthernetTransport::setPort(quint16 v){if(_port==v)return;disconnectEndpoint();_port=v;emit endpointChanged();}
void NavoEthernetTransport::setUdp(bool v){if(_udp==v)return;disconnectEndpoint();_udp=v;emit endpointChanged();}
void NavoEthernetTransport::setAutoReconnect(bool v){if(_autoReconnect==v)return;_autoReconnect=v;if(!v)_reconnectTimer.stop();emit autoReconnectChanged();}

void NavoEthernetTransport::connectEndpoint()
{
    if(!_port || (!_udp && _host.trimmed().isEmpty())) { setStatus(QStringLiteral("ENDPOINT INVALID")); return; }
    _connectTimeout.stop();
    _manualDisconnect=true;
    _tcp.abort(); _udpSocket.close();
    setConnected(false); setDataAlive(false);
    _manualDisconnect=false;
    _reconnectTimer.stop();
    if(_udp){
        _udpSocket.close();
        if(!_udpSocket.bind(_port,QUdpSocket::ShareAddress|QUdpSocket::ReuseAddressHint)){
            setConnected(false);setStatus(_udpSocket.errorString());scheduleReconnect();return;
        }
        setConnected(false);setStatus(QStringLiteral("UDP LISTENING • WAITING DATA"));
    }else{
        _tcp.abort();
        setStatus(QStringLiteral("CONNECTING"));
        _connectTimeout.start(5000);
        _tcp.connectToHost(_host,_port);
    }
}

void NavoEthernetTransport::disconnectEndpoint()
{
    _manualDisconnect=true;
    _connectTimeout.stop();
    _reconnectTimer.stop();
    _udpSocket.close();
    _tcp.abort();
    setConnected(false);setDataAlive(false);setStatus(QStringLiteral("OFFLINE"));
}

void NavoEthernetTransport::readTcp(){const auto b=_tcp.readAll();if(!b.isEmpty()){noteData();emit bytesReceived(b);}}
void NavoEthernetTransport::readUdp(){
    while(_udpSocket.hasPendingDatagrams()){
        QByteArray b; b.resize(int(_udpSocket.pendingDatagramSize())); QHostAddress sender;
        const auto size=_udpSocket.readDatagram(b.data(),b.size(),&sender);
        QHostAddress expected(_host);
        if(size>0 && (expected.isNull() || sender==expected)) { b.resize(int(size)); noteData(); emit bytesReceived(b); }
    }
}
void NavoEthernetTransport::noteData(){_lastData.restart();setConnected(true);setDataAlive(true);setStatus(QStringLiteral("RX DATA"));}
void NavoEthernetTransport::healthTick(){
    if(_dataAlive&&_lastData.isValid()&&_lastData.elapsed()>3000){
        setDataAlive(false); if(_udp)setConnected(false);
        setStatus(QStringLiteral("NO RECENT DATA"));
    }
}
void NavoEthernetTransport::scheduleReconnect(){if(_autoReconnect&&!_manualDisconnect&&!_reconnectTimer.isActive())_reconnectTimer.start(2000);}
void NavoEthernetTransport::setConnected(bool v){if(_connected==v)return;_connected=v;emit connectedChanged();}
void NavoEthernetTransport::setDataAlive(bool v){if(_dataAlive==v)return;_dataAlive=v;emit dataAliveChanged();}
void NavoEthernetTransport::setStatus(const QString& v){if(_status==v)return;_status=v;emit statusChanged();}
