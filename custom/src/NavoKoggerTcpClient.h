#pragma once
#include <QObject>
#include <QTcpSocket>

class NavoKoggerTcpClient : public QObject {
 Q_OBJECT
 Q_PROPERTY(QString host READ host WRITE setHost NOTIFY endpointChanged)
 Q_PROPERTY(quint16 port READ port WRITE setPort NOTIFY endpointChanged)
 Q_PROPERTY(bool connected READ connected NOTIFY connectedChanged)
 Q_PROPERTY(QString status READ status NOTIFY statusChanged)
public:
 explicit NavoKoggerTcpClient(QObject* parent=nullptr);
 QString host()const{return _host;} quint16 port()const{return _port;}
 bool connected()const{return _socket.state()==QAbstractSocket::ConnectedState;}
 QString status()const{return _status;}
 void setHost(const QString& v){if(_host==v)return;_host=v;emit endpointChanged();}
 void setPort(quint16 v){if(_port==v)return;_port=v;emit endpointChanged();}
 Q_INVOKABLE void connectToSonar();
 Q_INVOKABLE void disconnectFromSonar();
signals:
 void endpointChanged(); void connectedChanged(); void statusChanged();
 void bytesReceived(const QByteArray& bytes);
private:
 void setStatus(const QString& s);
 QTcpSocket _socket; QString _host="192.168.0.7"; quint16 _port=8899; QString _status="OPRIT";
};
