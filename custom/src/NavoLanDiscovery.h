#pragma once
#include <QObject>
#include <QVariantList>
#include <QTcpSocket>
#include <QTimer>
#include <QHostAddress>
#include <QNetworkInterface>
#include <QSet>
#include <QQueue>
class NavoLanDiscovery : public QObject {
 Q_OBJECT
 Q_PROPERTY(bool scanning READ scanning NOTIFY scanningChanged)
 Q_PROPERTY(QVariantList devices READ devices NOTIFY devicesChanged)
 Q_PROPERTY(QString protectedHost MEMBER protectedHost)
 Q_PROPERTY(int serialPort MEMBER serialPort)
public:
 QString protectedHost;
 int serialPort=8899;
 explicit NavoLanDiscovery(QObject* parent=nullptr);
 ~NavoLanDiscovery() override { stop(); }
 bool scanning() const { return _scanning; }
 QVariantList devices() const { return _devices; }
 Q_INVOKABLE void scan();
 Q_INVOKABLE void stop();
 Q_INVOKABLE void probe(const QString& host,int port);
signals:
 void scanningChanged();
 void devicesChanged();
 void probeResult(QString host,int port,bool reachable);
private:
 struct Target { QString host; quint16 port; };
 void pump();
 void finishOne();
 QQueue<Target> _queue;
 QSet<QTcpSocket*> _active;
 QVariantList _devices;
 bool _scanning=false;
 int _generation=0;
 static constexpr int concurrency=20;
};
