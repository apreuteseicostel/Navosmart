#include "NavoEthernetTransport.h"
#include <QHostAddress>

NavoEthernetTransport::NavoEthernetTransport(QObject* p):QObject(p)
{
    connect(&_tcp,&QTcpSocket::connected,this,[this]{setConnected(true);setStatus(QStringLiteral("ONLINE"));});
    connect(&_tcp,&QTcpSocket::disconnected,this,[this]{setConnected(false);setDataAlive(false);setStatus(QStringLiteral("OFFLINE"));scheduleReconnect();});
    connect(&_tcp,&QTcpSocket::readyRead,this,&NavoEthernetTransport::readTcp);
    connect(&_tcp,&QTcpSocket::errorOccurred,this,[this](QAbstractSocket::SocketError){setStatus(_tcp.errorString());});
    connect(&_udpSocket,&QUdpSocket::readyRead,this,&NavoEthernetTransport::readUdp);
    connect(&_healthTimer,&QTimer::timeout,this,&NavoEthernetTransport::healthTick);
    connect(&_reconnectTimer,&QTimer::timeout,this,&NavoEthernetTransport::connectEndpoint);
    _healthTimer.start(1000);
    _reconnectTimer.setSingleShot(true);
}

void NavoEthernetTransport::setHost(const QString& v){if(_host==v)return;_host=v;emit endpointChanged();}
void NavoEthernetTransport::setPort(quint16 v){if(_port==v)return;_port=v;emit endpointChanged();}
void NavoEthernetTransport::setUdp(bool v){if(_udp==v)return;_udp=v;emit endpointChanged();}
void NavoEthernetTransport::setAutoReconnect(bool v){if(_autoReconnect==v)return;_autoReconnect=v;emit autoReconnectChanged();}

void NavoEthernetTransport::connectEndpoint()
{
    _manualDisconnect=false;
    _reconnectTimer.stop();
    if(_udp){
        _udpSocket.close();
        if(!_udpSocket.bind(_port,QUdpSocket::ShareAddress|QUdpSocket::ReuseAddressHint)){
            setConnected(false);setStatus(_udpSocket.errorString());scheduleReconnect();return;
        }
        setConnected(true);setStatus(QStringLiteral("ONLINE"));
    }else{
        _tcp.abort();
        setStatus(QStringLiteral("CONNECTING"));
        _tcp.connectToHost(_host,_port);
    }
}

void NavoEthernetTransport::disconnectEndpoint()
{
    _manualDisconnect=true;
    _reconnectTimer.stop();
    _udpSocket.close();
    _tcp.abort();
    setConnected(false);setDataAlive(false);setStatus(QStringLiteral("OFFLINE"));
}

void NavoEthernetTransport::readTcp(){const auto b=_tcp.readAll();if(!b.isEmpty()){noteData();emit bytesReceived(b);}}
void NavoEthernetTransport::readUdp(){while(_udpSocket.hasPendingDatagrams()){QByteArray b; b.resize(int(_udpSocket.pendingDatagramSize())); if(_udpSocket.readDatagram(b.data(),b.size())>=0&&!b.isEmpty()){noteData();emit bytesReceived(b);}}}
void NavoEthernetTransport::noteData(){_lastData.restart();setDataAlive(true);}
void NavoEthernetTransport::healthTick(){if(_dataAlive&&_lastData.isValid()&&_lastData.elapsed()>3000)setDataAlive(false);}
void NavoEthernetTransport::scheduleReconnect(){if(_autoReconnect&&!_manualDisconnect&&!_reconnectTimer.isActive())_reconnectTimer.start(2000);}
void NavoEthernetTransport::setConnected(bool v){if(_connected==v)return;_connected=v;emit connectedChanged();}
void NavoEthernetTransport::setDataAlive(bool v){if(_dataAlive==v)return;_dataAlive=v;emit dataAliveChanged();}
void NavoEthernetTransport::setStatus(const QString& v){if(_status==v)return;_status=v;emit statusChanged();}

// The custom QGC build injects this source into the final application target.
// Including the generated moc unit here guarantees the QObject meta-object code
// is linked with the same translation unit instead of depending on cross-target
// AUTOMOC propagation from the custom QML static library.
#include "NavoEthernetTransport.moc"
