#include "NavoLanDiagnostics.h"
#include <QNetworkInterface>
#include <QHostAddress>
#include <QSettings>

NavoLanDiagnostics::NavoLanDiagnostics(QObject* parent):QObject(parent) {
    QSettings config;
    config.beginGroup("NavoLanDiagnostics");
    _scanAddress=config.value("scanAddress","192.168.144.1").toString();
    _subnetMask=config.value("subnetMask","255.255.255.0").toString();
    _host=config.value("host",QStringLiteral("192.168.144.7")).toString().trimmed();
    if(_host.isEmpty())_host=QStringLiteral("192.168.144.7");
    _monitorPort=config.value("monitorPort",80).toInt();
    _uartPort=config.value("uartPort",23).toInt();
    if(_monitorPort<1 || _monitorPort>65535)_monitorPort=80;
    if(_uartPort<1 || _uartPort>65535)_uartPort=23;
    _monitoring=config.value("monitoring",false).toBool();
    _serial.setAutoReconnect(false);
    _timer.setInterval(5000);
    connect(&_timer,&QTimer::timeout,this,&NavoLanDiagnostics::refresh);
    _timer.start();
    _timeout.setSingleShot(true);_timeout.setInterval(1500);
    connect(&_timeout,&QTimer::timeout,this,[this]{_status="Dispozitiv LAN fără răspuns; verifică IP-ul, subrețeaua și alimentarea.";_witness.invalidate();_probe.abort();emit changed();});
    connect(&_probe,&QTcpSocket::connected,this,[this]{
        _timeout.stop();_witness.restart();_status="Dispozitiv LAN accesibil prin TCP. Alimentarea switch-ului nu este măsurată direct.";
        _probe.abort();emit changed();
    });
    connect(&_probe,&QTcpSocket::errorOccurred,this,[this](QAbstractSocket::SocketError){
        _timeout.stop();_witness.invalidate();_status="Dispozitiv LAN neconfirmat: "+_probe.errorString();emit changed();
    });
    connect(&_serial,&NavoEthernetTransport::connectedChanged,this,&NavoLanDiagnostics::changed);
    connect(&_serial,&NavoEthernetTransport::statusChanged,this,&NavoLanDiagnostics::changed);
    connect(&_serial,&NavoEthernetTransport::bytesReceived,this,[this](const QByteArray& bytes){
        _received+=qulonglong(bytes.size());_preview.append(bytes.right(1024));
        if(_preview.size()>1024)_preview=_preview.right(1024);
        emit changed();
    });
    QTimer::singleShot(0,this,&NavoLanDiagnostics::refresh);
}
bool NavoLanDiagnostics::saveConfiguration() {
    QSettings config;
    config.setValue("NavoLanDiagnostics/host",_host);
    config.setValue("NavoLanDiagnostics/scanAddress",_scanAddress);
    config.setValue("NavoLanDiagnostics/subnetMask",_subnetMask);
    config.setValue("NavoLanDiagnostics/monitorPort",_monitorPort);
    config.setValue("NavoLanDiagnostics/uartPort",_uartPort);
    config.setValue("NavoLanDiagnostics/monitoring",_monitoring);
    config.sync();
    return config.status()==QSettings::NoError;
}
bool NavoLanDiagnostics::localTarget() const {
    QHostAddress a(_host);
    if(a.protocol()!=QAbstractSocket::IPv4Protocol)return false;
    quint32 ip=a.toIPv4Address();
    return a.isLoopback() || (ip>>24)==10 || (ip>>20)==0xac1 || (ip>>16)==0xc0a8 || (ip>>16)==0xa9fe;
}
bool NavoLanDiagnostics::busy(int port) const {
    for(const auto& v:_busyEndpoints){const auto e=v.toMap();if(e.value("host").toString()==_host && e.value("port").toInt()==port)return true;}
    return false;
}
void NavoLanDiagnostics::invalidate(){_timeout.stop();_probe.abort();_witness.invalidate();_serial.disconnectEndpoint();_status.clear();_uartError.clear();clearPreview();}
void NavoLanDiagnostics::setHost(const QString& s){if(_host==s.trimmed())return;invalidate();_host=s.trimmed();QSettings().setValue("NavoLanDiagnostics/host",_host);emit endpointChanged();emit changed();}
void NavoLanDiagnostics::setMonitorPort(int p){if(p==_monitorPort)return;invalidate();_monitorPort=p;QSettings().setValue("NavoLanDiagnostics/monitorPort",p);emit endpointChanged();emit changed();}
void NavoLanDiagnostics::setUartPort(int p){if(p==_uartPort)return;invalidate();_uartPort=p;QSettings().setValue("NavoLanDiagnostics/uartPort",p);emit endpointChanged();emit changed();}
void NavoLanDiagnostics::setMonitoring(bool on){if(on==_monitoring)return;_monitoring=on;QSettings().setValue("NavoLanDiagnostics/monitoring",on);_timeout.stop();_probe.abort();_witness.invalidate();if(on)verify();emit changed();}
void NavoLanDiagnostics::setSuspended(bool s){if(s==_suspended)return;_suspended=s;if(s){stopDiscovery();invalidate();}else if(_monitoring)verify();emit changed();}
bool NavoLanDiagnostics::online() const {return !_suspended && (_serial.connected() || (_monitoring && _witness.isValid() && _witness.elapsed()<12000));}
QString NavoLanDiagnostics::status() const {
    if(_suspended)return "Redare activă: verificările LAN și testul UART sunt oprite.";
    if(_serial.connected())return "LAN ON: conexiune TCP la convertor. Traficul UART se confirmă separat prin RX.";
    if(!_monitoring)return "LAN neconfirmat: configurează IP-ul convertorului și activează verificarea.";
    return _status.isEmpty()?QStringLiteral("Se verifică dispozitivul LAN..."):_status;
}
QString NavoLanDiagnostics::uartStatus() const {
    if(!_uartError.isEmpty())return _uartError;
    if(_serial.connected())return _serial.dataAlive()?QStringLiteral("RX recent: convertorul livrează octeți. Protocolul și corectitudinea UART nu sunt încă validate."):QStringLiteral("TCP conectat, fără RX recent: UART neconfirmat. Verifică TX/RX, GND, baud și sursa de date.");
    return _serial.status();
}
QString NavoLanDiagnostics::preview() const {
    QString text;for(char c:_preview){const auto u=static_cast<unsigned char>(c);text+=u>=32&&u<127?QChar(u):QChar('.');}
    return "HEX: "+QString::fromLatin1(_preview.toHex(' '))+"\nTEXT: "+text;
}
void NavoLanDiagnostics::verify(){
    if(_suspended || !_monitoring || _probe.state()!=QAbstractSocket::UnconnectedState)return;
    if(!localTarget() || _monitorPort<1 || _monitorPort>65535 || _monitorPort==_uartPort || busy(_monitorPort)){
        _witness.invalidate();_status="Verificare blocată: folosește un IP LAN și portul web al convertorului, separat de portul UART și de conexiunile active.";emit changed();return;
    }
    _status="Verificare TCP la "+_host+":"+QString::number(_monitorPort);_timeout.start();_probe.connectToHost(_host,quint16(_monitorPort));emit changed();
}
void NavoLanDiagnostics::connectUart(){
    stopUart();clearPreview();
    if(_suspended || !localTarget() || _uartPort<1 || _uartPort>65535 || _uartPort==_monitorPort || busy(_uartPort)){
        _uartError="Test UART blocat: IP/port invalid, port web sau conexiune deja folosită. Oprește mai întâi conexiunea activă la acel port.";emit changed();return;
    }
    _serial.setHost(_host);_serial.setPort(quint16(_uartPort));_serial.setUdp(false);_serial.connectEndpoint();
}
void NavoLanDiagnostics::stopUart(){_serial.disconnectEndpoint();_uartError.clear();emit changed();}
void NavoLanDiagnostics::clearPreview(){_received=0;_preview.clear();emit changed();}
void NavoLanDiagnostics::stopDiscovery(){
    ++_scanGeneration;_discovering=false;
    const auto sockets=_scanSockets;_scanSockets.clear();
    for(auto* socket:sockets){socket->disconnect(this);socket->abort();socket->deleteLater();}
    _discoveryStatus="Căutare oprită; rezultatele existente sunt păstrate.";emit changed();
}
void NavoLanDiagnostics::discover(){
    stopDiscovery();_devices.clear();
    QHostAddress address(_scanAddress), mask(_subnetMask);
    const quint32 ip=address.toIPv4Address(), m=mask.toIPv4Address(), inverse=~m;
    if(_suspended || address.protocol()!=QAbstractSocket::IPv4Protocol || mask.protocol()!=QAbstractSocket::IPv4Protocol ||
       inverse<3 || inverse>255 || (inverse&(inverse+1))!=0 ||
       !((ip>>24)==10 || (ip>>20)==0xac1 || (ip>>16)==0xc0a8 || (ip>>16)==0xa9fe)){
        _discoveryStatus="IP privat și mască /24–/30 necesare (maximum 254 adrese). Replay blochează scanarea.";emit changed();return;
    }
    _scanNetwork=ip&m;_scanTotal=int(inverse-1)*3;_scanNext=0;_discovering=true;
    _discoveryStatus="Căutare TCP 80/443/554; fără răspuns nu înseamnă dispozitiv absent.";
    pumpDiscovery();emit changed();
}
void NavoLanDiagnostics::pumpDiscovery(){
    static const int ports[]={80,443,554};
    while(_discovering && _scanSockets.size()<16 && _scanNext<_scanTotal){
        const int job=_scanNext++, port=ports[job%3];
        const QString host=QHostAddress(_scanNetwork+quint32(job/3+1)).toString();
        bool blocked=false;for(const auto& v:_busyEndpoints){const auto e=v.toMap();if(e.value("host").toString()==host && e.value("port").toInt()==port)blocked=true;}
        if(blocked || (host==_host && ((_serial.connected() && port==_uartPort) || (_probe.state()!=QAbstractSocket::UnconnectedState && port==_monitorPort))))continue;
        auto* socket=new QTcpSocket(this);_scanSockets.append(socket);
        const auto generation=_scanGeneration;
        auto finish=[this,socket,generation,host,port](bool found){
            if(generation!=_scanGeneration || !_scanSockets.removeOne(socket))return;
            socket->disconnect(this);socket->abort();socket->deleteLater();
            if(found){_devices.append(QVariantMap{{"ip",host},{"port",port},{"service",port==554?"RTSP posibil":port==443?"HTTPS":"HTTP"}});}
            emit changed();QTimer::singleShot(0,this,&NavoLanDiagnostics::pumpDiscovery);
        };
        connect(socket,&QTcpSocket::connected,this,[finish]{finish(true);});
        connect(socket,&QTcpSocket::errorOccurred,this,[finish](QAbstractSocket::SocketError){finish(false);});
        QTimer::singleShot(700,socket,[finish]{finish(false);});
        socket->connectToHost(host,quint16(port));
    }
    if(_discovering && _scanNext>=_scanTotal && _scanSockets.isEmpty()){
        _discovering=false;_discoveryStatus="Căutare terminată: "+QString::number(_devices.size())+" servicii TCP accesibile. IP-ul camerei poate fi în altă subrețea; masca nu schimbă rețeaua Android.";emit changed();
    }
}
void NavoLanDiagnostics::refresh(){
    QVariantList list;
    for(const auto& iface:QNetworkInterface::allInterfaces()){
        if(!(iface.flags()&QNetworkInterface::IsUp) || iface.flags()&QNetworkInterface::IsLoopBack)continue;
        if(iface.type()!=QNetworkInterface::Ethernet && iface.type()!=QNetworkInterface::Wifi)continue;
        for(const auto& addr:iface.addressEntries())if(addr.ip().protocol()==QAbstractSocket::IPv4Protocol)
            list.append(QVariantMap{{"name",iface.humanReadableName()},{"ip",addr.ip().toString()},{"mask",addr.netmask().toString()},{"ethernet",iface.type()==QNetworkInterface::Ethernet},{"link",bool(iface.flags()&QNetworkInterface::IsRunning)}});
    }
    _interfaces=list;emit changed();verify();
}

void NavoLanDiagnostics::setBlocked(const QVariantList& endpoints){
    if(_busyEndpoints==endpoints)return;
    _busyEndpoints=endpoints;
    if(_serial.connected() && busy(_uartPort)){stopUart();_uartError="Test UART închis: portul este folosit de o conexiune activă.";}
    if(busy(_monitorPort)){_timeout.stop();_probe.abort();_witness.invalidate();}
    emit changed();
}
