#pragma once
#include <QObject>
#include <QStringList>
#include <QElapsedTimer>
#include <QHash>
#include <QMap>
#include <QPointer>
#include <QSet>
#include <QTimer>
#include <QVariantList>
#include <QVariantMap>

class LinkConfiguration;
class LinkInterface;

class NavoConnectivity : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList connections READ connections NOTIFY connectionsChanged)
    Q_PROPERTY(bool autoConnect READ autoConnect WRITE setAutoConnect NOTIFY autoConnectChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY connectionsChanged)
    Q_PROPERTY(int serialBaud READ serialBaud NOTIFY connectionsChanged)
    Q_PROPERTY(QString status READ status NOTIFY connectionsChanged)
public:
    explicit NavoConnectivity(QObject *parent = nullptr);
    QVariantList connections() const { return _rows; }
    bool autoConnect() const { return _autoConnect; }
    void setAutoConnect(bool enabled);
    int serialBaud() const { return _baud; }
    bool busy() const { return !_pending.isEmpty(); }
    QString status() const { return _status; }
    Q_INVOKABLE void refresh();
    Q_INVOKABLE void connectAll();
    Q_INVOKABLE void connectOne(const QString &key);
    Q_INVOKABLE void verifyOne(const QString &key);
    Q_INVOKABLE bool addTcp(const QString &host, int port);
    Q_INVOKABLE void setSerialBaud(int baud);
    Q_INVOKABLE QVariantMap savedEthernet() const;
signals:
    void connectionsChanged();
    void autoConnectChanged();
    void networkConnectRequested(bool automatic);
private:
    struct Evidence { qint64 heartbeat = 0; qint64 bytes = 0; QString error; int systemId = 0; };
    struct Retry { int attempts = 0; qint64 at = 0; };
    QString keyFor(const LinkConfiguration *config) const;
    void discover();
    void observe();
    void queue(bool force);
    void attemptNext();
    bool serialBusy() const;
    bool replayActive() const;
    bool usable(const LinkConfiguration *config) const;
    QElapsedTimer _clock;
    QTimer _poll, _dispatch;
    QVariantList _rows;
    QMap<QString, QPointer<LinkConfiguration>> _configs;
    QMap<QString, QString> _serialPorts, _excluded;
    QHash<LinkInterface *, Evidence> _evidence;
    QSet<LinkInterface *> _watched;
    QHash<QString, Retry> _retry;
    QStringList _pending;
    QString _status;
    bool _autoConnect = true;
    bool _ready = false;
    int _baud = 115200;
};
