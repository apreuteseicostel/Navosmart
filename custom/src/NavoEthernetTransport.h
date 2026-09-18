#pragma once
#include <QObject>
#include <QTcpSocket>
#include <QUdpSocket>

class NavoEthernetTransport : public QObject {
 Q_OBJECT
 Q_PROPERTY(QString host READ host WRITE setHost NOTIFY endpointChanged)
 Q_PROPERTY(quint16 port READ port WRITE setPort NOTIFY endpointChanged)
 Q_PROPERTY(bool udp READ udp WRITE setUdp NOTIFY endpointChanged)
 Q_PROPERTY(bool connected READ connected NOTIFY connectedChanged)
 Q_PROPERTY(QString status READ status NOTIFY statusChanged)
public:
 explicit NavoEthernetTransport(QObject* parent=nullptr);
 QString host() const{return _host;} quint16 port() const{return _port;} bool udp() const{return _udp;}
 bool connected() const{return _connected;} QString status() const{return _status;}
 void setHost(const QString&); void setPort(quint16); void setUdp(bool);
 Q_INVOKABLE void connectEndpoint(); Q_INVOKABLE void disconnectEndpoint();
signals:
 void endpointChanged(); void connectedChanged(); void statusChanged();
 void bytesReceived(const QByteArray& data);
private:
 void setConnected(bool); void setStatus(const QString&); void readTcp(); void readUdp();
 QString _host; quint16 _port=0; bool _udp=false; bool _connected=false; QString _status=QStringLiteral("OFFLINE");
 QTcpSocket _tcp; QUdpSocket _udpSocket;
};