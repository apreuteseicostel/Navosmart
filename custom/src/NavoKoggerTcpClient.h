#pragma once
#include <QObject>
#include <QTcpSocket>
#include <QTimer>
class NavoKoggerTcpClient:public QObject{
 Q_OBJECT
 Q_PROPERTY(QString host READ host WRITE setHost NOTIFY endpointChanged)
 Q_PROPERTY(quint16 port READ port WRITE setPort NOTIFY endpointChanged)
 Q_PROPERTY(bool connected READ connected NOTIFY connectedChanged)
 Q_PROPERTY(bool autoReconnect READ autoReconnect WRITE setAutoReconnect NOTIFY autoReconnectChanged)
 Q_PROPERTY(QString status READ status NOTIFY statusChanged)
 Q_PROPERTY(quint64 rxBytes READ rxBytes NOTIFY statisticsChanged)
 Q_PROPERTY(quint64 rxChunks READ rxChunks NOTIFY statisticsChanged)
public:
 explicit NavoKoggerTcpClient(QObject* parent=nullptr);
 QString host()const{return _host;} quint16 port()const{return _port;} bool connected()const{return _socket.state()==QAbstractSocket::ConnectedState;}
 bool autoReconnect()const{return _autoReconnect;} QString status()const{return _status;} quint64 rxBytes()const{return _rxBytes;} quint64 rxChunks()const{return _rxChunks;}
 void setHost(const QString&v){if(_host==v)return;_host=v;emit endpointChanged();} void setPort(quint16 v){if(_port==v)return;_port=v;emit endpointChanged();}
 void setAutoReconnect(bool v){if(_autoReconnect==v)return;_autoReconnect=v;emit autoReconnectChanged();}
 Q_INVOKABLE void connectToSonar(); Q_INVOKABLE void disconnectFromSonar(); Q_INVOKABLE void resetStatistics(){_rxBytes=_rxChunks=0;emit statisticsChanged();}
signals:
 void endpointChanged();void connectedChanged();void autoReconnectChanged();void statusChanged();void statisticsChanged();void bytesReceived(const QByteArray&);
private:
 void setStatus(const QString&);void scheduleReconnect();
 QTcpSocket _socket;QTimer _retry;QString _host="192.168.0.7";quint16 _port=8899;QString _status="OPRIT";bool _autoReconnect=true;bool _manualStop=false;quint64 _rxBytes=0,_rxChunks=0;
};