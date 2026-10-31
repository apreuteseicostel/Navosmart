#pragma once
#include "LinkInterface.h"
#include <QTimer>
#include <QElapsedTimer>
#include <QVariantMap>

// Created by the small pinned-QGC factory hook. The UDP configuration is only
// a LinkManager-owned descriptor; this class never opens a network socket.
class NavoSkydroidLink : public LinkInterface {
    Q_OBJECT
public:
    explicit NavoSkydroidLink(SharedLinkConfigurationPtr &config, QObject *parent = nullptr);
    ~NavoSkydroidLink() override;
    bool isConnected() const override { return _connected; }
    bool isSecureConnection() const override { return false; }
    void disconnect() override;
    static QVariantMap deviceInfo();
    QVariantMap diagnostics() const { return _diagnostics; }
    static constexpr const char *configurationName = "NAVO G20 / GR01 (RCSDK)";
protected:
    bool _connect() override;
private:
    void _writeBytes(const QByteArray &bytes) override;
    void poll();
    QTimer _poll;
    QElapsedTimer _started;
    qint64 _session = 0;
    bool _connected = false, _stopping = false;
    QVariantMap _diagnostics;
};
