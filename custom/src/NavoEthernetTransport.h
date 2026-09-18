#pragma once
#include <QObject>
#include <QTcpSocket>
#include <QUdpSocket>
#include <QTimer>
#include <QElapsedTimer>
class NavoEthernetTransport:public QObject{Q_OBJECT
 Q_PROPERTY(QString host READ host WRITE setHost NOTIFY endpointChanged) Q_PROPERTY(quint16 port READ port WRITE setPort NOTIFY endpointChanged)
 Q_PROPERTY(bool udp READ udp WRITE setUdp NOTIFY endpointChanged) Q_PROPERTY(bool connected READ connected NOTIFY connectedChanged)
 Q_PROPERTY(bool dataAlive READ dataAlive NOTIFY dataAliveChanged) Q_PROPERTY(bool autoReconnect READ autoReconnect WRITE setAutoReconnect NOTIFY autoReconnectChanged)
 Q_PROPERTY(QString status READ status NOTIFY statusChanged)
public: explicit NavoEthernetTransport(QObject* p=nullptr);QString host()const{return _host;}quint16 port()const{return _port;}bool udp()const{return _udp;}bool connected()const{return _connected;}bool dataAlive()const{return _dataAlive;}bool autoReconnect()const{return _autoReconnect;}QString status()const{return _status;}
 void setHost(const QString&);void setPort(quint16);void setUdp(bool);void setAutoReconnect(bool);Q_INVOKABLE void connectEndpoint();Q_INVOKABLE void disconnectEndpoint();
signals:void endpointChanged();void connectedChanged();void dataAliveChanged();void autoReconnectChanged();void statusChanged();void bytesReceived(const QByteArray&);
private:void setConnected(bool);void setDataAlive(bool);void setStatus(const QString&);void readTcp();void readUdp();void noteData();void healthTick();void scheduleReconnect();
 QString _host;quint16 _port=0;bool _udp=false,_connected=false,_dataAlive=false,_autoReconnect=true,_manualDisconnect=false;QString _status=QStringLiteral("OFFLINE");QTcpSocket _tcp;QUdpSocket _udpSocket;QTimer _healthTimer,_reconnectTimer;QElapsedTimer _lastData;};