#pragma once
#include <QObject>
#include <QVariantList>
#include <QElapsedTimer>
#include <QTcpSocket>
#include <QTimer>
#include "NavoEthernetTransport.h"

// Passive UART receiver and explicit LAN witness. Never sends serial commands.
class NavoLanDiagnostics : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString host READ host WRITE setHost NOTIFY endpointChanged)
    Q_PROPERTY(int monitorPort READ monitorPort WRITE setMonitorPort NOTIFY endpointChanged)
    Q_PROPERTY(int uartPort READ uartPort WRITE setUartPort NOTIFY endpointChanged)
    Q_PROPERTY(bool monitoring READ monitoring WRITE setMonitoring NOTIFY changed)
    Q_PROPERTY(bool suspended READ suspended WRITE setSuspended NOTIFY changed)
    Q_PROPERTY(bool online READ online NOTIFY changed)
    Q_PROPERTY(bool uartConnected READ uartConnected NOTIFY changed)
    Q_PROPERTY(QString status READ status NOTIFY changed)
    Q_PROPERTY(QString uartStatus READ uartStatus NOTIFY changed)
    Q_PROPERTY(QString preview READ preview NOTIFY changed)
    Q_PROPERTY(qulonglong received READ received NOTIFY changed)
    Q_PROPERTY(QVariantList interfaces READ interfaces NOTIFY changed)
    Q_PROPERTY(QVariantList busyEndpoints READ blocked WRITE setBlocked NOTIFY changed)
    Q_PROPERTY(QString scanAddress MEMBER _scanAddress NOTIFY changed)
    Q_PROPERTY(QString subnetMask MEMBER _subnetMask NOTIFY changed)
    Q_PROPERTY(bool discovering READ discovering NOTIFY changed)
    Q_PROPERTY(QVariantList devices READ devices NOTIFY changed)
    Q_PROPERTY(QString discoveryStatus READ discoveryStatus NOTIFY changed)
public:
    explicit NavoLanDiagnostics(QObject* parent=nullptr);
    QString host() const { return _host; }
    int monitorPort() const { return _monitorPort; }
    int uartPort() const { return _uartPort; }
    bool monitoring() const { return _monitoring; }
    bool suspended() const { return _suspended; }
    bool online() const;
    bool uartConnected() const { return _serial.connected(); }
    QString status() const;
    QString uartStatus() const;
    QString preview() const;
    qulonglong received() const { return _received; }
    QVariantList interfaces() const { return _interfaces; }
    QVariantList blocked() const { return _busyEndpoints; }
    void setBlocked(const QVariantList&);
    void setHost(const QString&);
    void setMonitorPort(int);
    void setUartPort(int);
    void setMonitoring(bool);
    void setSuspended(bool);
    Q_INVOKABLE void verify();
    Q_INVOKABLE void connectUart();
    Q_INVOKABLE void stopUart();
    Q_INVOKABLE void clearPreview();
    Q_INVOKABLE bool saveConfiguration();
    Q_INVOKABLE void discover();
    Q_INVOKABLE void stopDiscovery();
    bool discovering() const { return _discovering; }
    QVariantList devices() const { return _devices; }
    QString discoveryStatus() const { return _discoveryStatus; }
signals:
    void endpointChanged();
    void changed();
private:
    void pumpDiscovery();
    QString _scanAddress="192.168.144.1", _subnetMask="255.255.255.0", _discoveryStatus;
    bool _discovering=false;
    quint64 _scanGeneration=0;
    int _scanNext=0, _scanTotal=0;
    quint32 _scanNetwork=0;
    QVariantList _devices;
    QList<QTcpSocket*> _scanSockets;
    bool localTarget() const;
    bool busy(int port) const;
    void invalidate();
    void refresh();
    QString _host, _status, _uartError;
    int _monitorPort=80, _uartPort=0;
    bool _monitoring=false, _suspended=false;
    qulonglong _received=0;
    QByteArray _preview;
    QVariantList _interfaces, _busyEndpoints;
    QElapsedTimer _witness;
    QTimer _timer, _timeout;
    QTcpSocket _probe;
    NavoEthernetTransport _serial;
};
