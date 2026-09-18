#pragma once
#include <QObject>
#include <QUdpSocket>
#include <QHostAddress>
class NavoKoggerTransport:public QObject{
 Q_OBJECT
 Q_PROPERTY(bool listening READ listening NOTIFY stateChanged)
 Q_PROPERTY(QString lastSender READ lastSender NOTIFY stateChanged)
 Q_PROPERTY(quint64 bytesReceived READ bytesReceived NOTIFY statisticsChanged)
public:
 explicit NavoKoggerTransport(QObject*p=nullptr);
 bool listening()const{return _socket.state()==QAbstractSocket::BoundState;}
 QString lastSender()const{return _lastSender;}
 quint64 bytesReceived()const{return _bytes;}
 Q_INVOKABLE bool startUdp(quint16 port=14560);
 Q_INVOKABLE void stop();
signals:void bytesReady(QByteArray bytes);void stateChanged();void statisticsChanged();void transportError(QString message);
private slots:void _read();
private:QUdpSocket _socket;QString _lastSender;quint64 _bytes=0;
};
