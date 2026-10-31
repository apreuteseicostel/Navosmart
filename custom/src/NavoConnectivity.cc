#include "NavoConnectivity.h"
#include "NavoSkydroidLink.h"
#include "NavoConnectionPolicy.h"
#include "LinkManager.h"
#include "LinkConfiguration.h"
#include "LinkInterface.h"
#include "MAVLinkProtocol.h"
#include "QmlObjectListModel.h"
#include "TCPLink.h"
#include "UDPLink.h"
#include <QHostAddress>
#include <QSettings>
#include <QCoreApplication>
#ifndef QGC_NO_SERIAL_LINK
#include "QGCSerialPortInfo.h"
#include "SerialLink.h"
#include "SettingsManager.h"
#include "AutoConnectSettings.h"
#include "Fact.h"
#endif

NavoConnectivity::NavoConnectivity(QObject *parent) : QObject(parent) {
    QSettings settings;
    _autoConnect = settings.value("NavoConnectivity/autoConnect", true).toBool();
    _baud = settings.value("NavoConnectivity/serialBaud", 115200).toInt();
    if (_baud != 57600 && _baud != 115200 && _baud != 921600) _baud = 115200;
    _clock.start();
    connect(QCoreApplication::instance(), &QCoreApplication::aboutToQuit, this, [this] {
        _ready=false;_poll.stop();_dispatch.stop();_pending.clear();stopSkydroid();
    });
    _dispatch.setInterval(300);
    connect(&_dispatch, &QTimer::timeout, this, &NavoConnectivity::attemptNext);
    _poll.setInterval(1500);
    connect(&_poll, &QTimer::timeout, this, [this] { refresh(); if (_autoConnect) queue(false); });
    // QGC initializes its link configurations before FlyView is created. Allow its
    // own serial/UDP startup pass to run first; never call startAutoConnectedLinks twice.
    QTimer::singleShot(3000, this, [this] {
        _ready = true;
        connect(MAVLinkProtocol::instance(), &MAVLinkProtocol::messageReceived, this,
                [this](LinkInterface *link, const mavlink_message_t &message) {
            if (message.msgid != MAVLINK_MSG_ID_HEARTBEAT || !message.sysid) return;
            mavlink_heartbeat_t heartbeat{};
            mavlink_msg_heartbeat_decode(&message, &heartbeat);
            if (heartbeat.type == MAV_TYPE_GCS || heartbeat.autopilot == MAV_AUTOPILOT_INVALID) return;
            auto &e = _evidence[link];
            e.heartbeat = _clock.elapsed(); e.systemId = message.sysid; e.error.clear();
        });
        refresh();
        if (_autoConnect) { queue(false); emit networkConnectRequested(true); }
        _poll.start();
    });
}

void NavoConnectivity::setAutoConnect(bool enabled) {
    if (_autoConnect == enabled) return;
    _autoConnect = enabled;
    QSettings().setValue("NavoConnectivity/autoConnect", enabled);
    if (!enabled) { _pending.clear(); _dispatch.stop(); }
    emit autoConnectChanged(); emit connectionsChanged();
    if (enabled && _ready) connectAll();
}

QString NavoConnectivity::keyFor(const LinkConfiguration *config) const {
    if (!config) return {};
    if (config->name() == NavoSkydroidLink::configurationName) return "skydroid:g20";
#ifndef QGC_NO_SERIAL_LINK
    if (auto serial = qobject_cast<const SerialConfiguration *>(config)) return "serial:" + serial->portName();
#endif
    if (auto tcp = qobject_cast<const TCPConfiguration *>(config)) return "tcp:" + tcp->host() + ":" + QString::number(tcp->port());
    if (auto udp = qobject_cast<const UDPConfiguration *>(config)) return "udp:" + QString::number(udp->localPort());
    return {};
}

bool NavoConnectivity::serialBusy() const {
#ifndef QGC_NO_SERIAL_LINK
    for (const auto &link : LinkManager::instance()->links())
        if (link && link->linkConfiguration()->type() == LinkConfiguration::TypeSerial) return true;
#endif
    return false;
}

void NavoConnectivity::stopSkydroid() {
    // Own only the SDK link; do not disturb a working USB/TCP connection.
    for (const auto &link : LinkManager::instance()->links())
        if (link && link->linkConfiguration()->name() == NavoSkydroidLink::configurationName) link->disconnect();
}

void NavoConnectivity::setLiveSuspended(bool suspended) {
    if (_liveSuspended == suspended) return;
    _liveSuspended = suspended;
    if (suspended) { _pending.clear(); _dispatch.stop(); stopSkydroid(); }
    if (_ready) refresh();
}

bool NavoConnectivity::replayActive() const {
    if (_liveSuspended) return true;
    for (const auto &link : LinkManager::instance()->links())
        if (link && link->isLogReplay()) return true;
    return false;
}

bool NavoConnectivity::usable(const LinkConfiguration *config) const {
    if (config && config->name() == NavoSkydroidLink::configurationName) {
        const auto info = NavoSkydroidLink::deviceInfo();
        return info.value("arm").toBool() && (info.value("supported").toBool() || QSettings().value("NavoConnectivity/g20Selected", false).toBool());
    }
    if (!config || config->isForwarding() || keyFor(config).isEmpty()) return false;
#ifndef QGC_NO_SERIAL_LINK
    if (auto serial = qobject_cast<const SerialConfiguration *>(config))
        return _serialPorts.contains(serial->portName()) && !_excluded.contains(serial->portName());
#endif
    return true;
}

void NavoConnectivity::discover() {
    auto manager = LinkManager::instance();
    auto model = manager->property("linkConfigurations").value<QmlObjectListModel *>();
    if (!model) return;
    _configs.clear();
#ifdef Q_OS_ANDROID
    // Dynamic descriptor used by the pinned factory hook, never a UDP socket.
    bool hasSkydroid = false;
    for (int i = 0; i < model->count(); ++i) {
        auto config = qobject_cast<LinkConfiguration *>(model->get(i));
        if (config && config->name() == NavoSkydroidLink::configurationName) hasSkydroid = true;
    }
    if (!hasSkydroid) {
        auto config = new UDPConfiguration(NavoSkydroidLink::configurationName);
        config->setDynamic(true); manager->addConfiguration(config);
    }
#endif
    for (int i = 0; i < model->count(); ++i) {
        auto config = qobject_cast<LinkConfiguration *>(model->get(i));
        const auto key = keyFor(config);
        if (key.isEmpty() || config->isForwarding()) continue;
        if (!_configs.contains(key) || config->link()) _configs[key] = config;
    }
#ifndef QGC_NO_SERIAL_LINK
    // Pinned QGC v5.0.7 explicitly supports ONE serial link on Android. Its
    // Android driver leaks descriptors if enumerated repeatedly while connected.
#ifdef Q_OS_ANDROID
    const bool enumerate = !serialBusy();
#else
    const bool enumerate = true;
#endif
    if (enumerate) {
        _serialPorts.clear(); _excluded.clear();
        const QString nmea = SettingsManager::instance()->autoConnectSettings()->autoConnectNmeaPort()->cookedValueString();
        for (const auto &port : QGCSerialPortInfo::availablePorts()) {
            const QString location = port.systemLocation().trimmed();
            if (location.isEmpty()) continue;
            _serialPorts[location] = port.description();
            QGCSerialPortInfo::BoardType_t type = QGCSerialPortInfo::BoardTypeUnknown;
            QString name; port.getBoardInfo(type, name);
            if (port.isBootloader()) _excluded[location] = "Bootloader • fără telemetrie";
            else if (QGCSerialPortInfo::isSystemPort(port)) _excluded[location] = "Port de sistem";
            else if (type == QGCSerialPortInfo::BoardTypeRTKGPS || location == nmea || port.portName() == nmea)
                _excluded[location] = "GPS/RTK rezervat • nu se deschide ca MAVLink";
            if (_excluded.contains(location) || _configs.contains("serial:" + location)) continue;
            auto config = new SerialConfiguration("NAVO USB • " + port.portName());
            config->setDynamic(true); config->setPortName(location); config->setBaud(_baud);
            config->setUsbDirect(type == QGCSerialPortInfo::BoardTypePixhawk);
            manager->addConfiguration(config);
            _configs["serial:" + location] = config;
        }
    }
    for (const auto &link : manager->links()) {
        auto config = qobject_cast<SerialConfiguration *>(link->linkConfiguration().get());
        if (config) _serialPorts.insert(config->portName(), config->name());
    }
#endif
    // Reuse QGC's default UDP listener, including its name so its own scanner
    // will not add a second 14550 socket on a later tick.
    if (_autoConnect && !_configs.contains("udp:14550")) {
        auto config = new UDPConfiguration("UDP Link (AutoConnect)");
        config->setLocalPort(14550); config->setDynamic(true); config->setAutoConnect(true);
        manager->addConfiguration(config); _configs["udp:14550"] = config;
    }
}

void NavoConnectivity::observe() {
    for (const auto &link : LinkManager::instance()->links()) {
        auto ptr = link.get();
        if (_watched.contains(ptr)) continue;
        _watched.insert(ptr);
        if (!_evidence.contains(ptr)) _evidence.insert(ptr, {});
        connect(ptr, &LinkInterface::bytesReceived, this, [this](LinkInterface *sender, const QByteArray &bytes) {
            _evidence[sender].bytes += bytes.size();
        });
        connect(ptr, &LinkInterface::communicationError, this, [this, ptr](const QString &, const QString &error) {
            _evidence[ptr].error = error;
            _lastErrors[keyFor(ptr->linkConfiguration().get())] = error;
            emit connectionsChanged();
        });
        connect(ptr, &QObject::destroyed, this, [this, ptr] { _evidence.remove(ptr); _watched.remove(ptr); });
    }
}

void NavoConnectivity::refresh() {
    if (!_ready) return;
    if (replayActive()) stopSkydroid();
    discover(); observe();
    QVariantList rows;
    const auto now = _clock.elapsed();
    for (auto it = _configs.cbegin(); it != _configs.cend(); ++it) {
        auto config = it.value().data();
        if (!config) continue;
        auto link = config->link();
        const bool connected = link && link->isConnected();
        const Evidence evidence = link ? _evidence.value(link) : Evidence{};
        const bool live = NavoConnectionPolicy::heartbeatFresh(connected, evidence.heartbeat, now);
        if (live) { _retry.remove(it.key()); _lastErrors.remove(it.key()); }
        QString state = live ? "MAVLINK LIVE" : connected ? "TRANSPORT DESCHIS • fără HEARTBEAT recent" : link ? "CONECTARE ÎN CURS" : "DECONECTAT";
        QString detail = evidence.error.isEmpty() ? _lastErrors.value(it.key()) : evidence.error;
        if (!link && detail.isEmpty() && _retry.value(it.key()).attempts>0) detail="Conectare eșuată • verifică alimentarea, permisiunea, adresa și viteza serială";
        bool available = usable(config) && !replayActive();
        if (replayActive()) detail="Redare MAVLink • conectarea live este blocată";
#ifndef QGC_NO_SERIAL_LINK
        if (auto serial = qobject_cast<SerialConfiguration *>(config)) {
            if (!available) detail = _excluded.value(serial->portName(), "Port USB indisponibil");
#ifdef Q_OS_ANDROID
            if (!link && serialBusy()) {available = false;detail = "Android/QGC: un singur USB serial simultan";}
#endif
        }
#endif
        if (link && evidence.heartbeat > 0 && !live) detail = "HEARTBEAT expirat • autopilot neconfirmat";
        if (!link && _retry.value(it.key()).attempts >= 5) detail = "Încercări automate oprite • verifică și reconectează manual";
        QString endpoint = it.key();
        if (it.key() == "skydroid:g20") {
            auto info = NavoSkydroidLink::deviceInfo();
            if (auto sdk = qobject_cast<NavoSkydroidLink *>(link)) info = sdk->diagnostics();
            endpoint = "SDK Skydroid 1.9.2 • G20 / GR01 • " + info.value("model").toString();
            state = live ? "MAVLINK LIVE • H743 CONFIRMAT" : connected ? "CANAL GR01 DESCHIS • fără HEARTBEAT recent" : info.value("rc").toBool() ? "TELECOMANDĂ CONECTATĂ • se deschide canalul GR01" : link ? "CONECTARE RCSDK ÎN CURS" : "RCSDK OPRIT";
            if (!info.value("arm").toBool()) detail = "Necesită Android ARM și adaptorul RCSDK inclus în APK";
            else if (!info.value("supported").toBool() && !QSettings().value("NavoConnectivity/g20Selected", false).toBool()) detail = "Model G20 nedetectat automat • apasă Conectează numai pe G20";
            else if (!info.value("error").toString().isEmpty()) detail = info.value("error").toString();
            else if (detail.isEmpty()) detail = "Telecomandă: " + QString(info.value("rc").toBool() ? "DA" : "NU") + " • canal GR01: " + QString(info.value("channel").toBool() ? "DA" : "NU") + " • TX SDK: " + QString::number(info.value("tx").toLongLong()) + " • RX pierdut: " + QString::number(info.value("dropped").toLongLong()) + " • închide FLY/Device Tool; firmware G20 ≥20250110";
            available = info.value("arm").toBool() && !replayActive();
            if (replayActive()) detail = "Redare activă • canalul live RCSDK este oprit";
            else if (_g20Stopped) { state = "OPRIT MANUAL"; detail = "Canalul SDK este oprit • apasă Conectează pentru reluare"; }
            else if (!link && _retry.value(it.key()).attempts >= 5) detail += " • 5 încercări epuizate; reconectare manuală";
        }
        rows.append(QVariantMap{{"key", it.key()}, {"name", config->name()}, {"endpoint", endpoint},
                               {"state", state}, {"detail", detail}, {"live", live}, {"connected", connected},
                               {"canConnect", available && !link}, {"bytes", evidence.bytes}, {"systemId", evidence.systemId}});
    }
    for (auto it = _excluded.cbegin(); it != _excluded.cend(); ++it)
        if (!_configs.contains("serial:" + it.key())) rows.append(QVariantMap{{"key", "excluded:" + it.key()},
            {"name", _serialPorts.value(it.key())}, {"endpoint", it.key()}, {"state", "REZERVAT"},
            {"detail", it.value()}, {"live", false}, {"connected", false}, {"canConnect", false}, {"bytes", 0}});
    _rows = rows;
    _status = _pending.isEmpty() ? "Verificare: " + QString::number(rows.size()) + " legături/porturi" : "Conectare: " + QString::number(_pending.size()) + " în așteptare";
    emit connectionsChanged();
}

void NavoConnectivity::queue(bool force) {
    if (!_ready || replayActive()) { _pending.clear(); _dispatch.stop(); return; }
    for (auto it = _configs.cbegin(); it != _configs.cend(); ++it) {
        auto config = it.value().data();
        if (it.key() == "skydroid:g20" && _g20Stopped) continue;
        if (!usable(config) || config->link() || _pending.contains(it.key())) continue;
        const auto retry = _retry.value(it.key());
        if (force || NavoConnectionPolicy::retryAllowed(false, retry.attempts, retry.at, _clock.elapsed())) _pending.append(it.key());
    }
    if (!_pending.isEmpty() && !_dispatch.isActive()) _dispatch.start();
    emit connectionsChanged();
}

void NavoConnectivity::connectAll() {
    _g20Stopped = false;
    refresh();
    if(replayActive())return;
    queue(true);
    emit networkConnectRequested(false);
}

void NavoConnectivity::connectOne(const QString &key) {
    refresh();
    if (key == "skydroid:g20" && !replayActive() && NavoSkydroidLink::deviceInfo().value("arm").toBool())
        QSettings().setValue("NavoConnectivity/g20Selected", true);
    if (replayActive() || !_configs.contains(key) || !usable(_configs[key]) || _configs[key]->link()) return;
    if (key == "skydroid:g20") _g20Stopped = false;
    _lastErrors.remove(key); _retry.remove(key);
    if (!_pending.contains(key)) _pending.append(key);
    _dispatch.start(); emit connectionsChanged();
}

void NavoConnectivity::attemptNext() {
    if (!_ready || replayActive() || _pending.isEmpty()) { _pending.clear(); _dispatch.stop(); return; }
    const QString key = _pending.takeFirst();
    auto config = _configs.value(key).data();
    if (usable(config) && !config->link()) {
#if defined(Q_OS_ANDROID) && !defined(QGC_NO_SERIAL_LINK)
        if (config->type() == LinkConfiguration::TypeSerial && serialBusy()) {refresh();return;}
#endif
        auto &retry = _retry[key]; retry.attempts++; retry.at = _clock.elapsed();
        LinkManager::instance()->createConnectedLink(config);
    }
    refresh();
}

void NavoConnectivity::disconnectOne(const QString &key) {
    if (key != "skydroid:g20") return;
    _g20Stopped = true;
    _pending.removeAll(key);
    _retry[key] = Retry{5, _clock.elapsed()};
    stopSkydroid(); refresh();
}

void NavoConnectivity::verifyOne(const QString &key) {
    refresh();
    for (const auto &row : _rows) {
        const auto r = row.toMap();
        if (r.value("key").toString() != key) continue;
        _status = r.value("name").toString() + " • " + r.value("state").toString() + " • " + r.value("detail").toString();
        emit connectionsChanged(); return;
    }
}

bool NavoConnectivity::addTcp(const QString &host, int port) {
    QHostAddress address;
    if (!address.setAddress(host.trimmed()) || address.isNull() || address.isMulticast() || address == QHostAddress(QHostAddress::AnyIPv4) || address == QHostAddress(QHostAddress::AnyIPv6) || address == QHostAddress(QHostAddress::Broadcast) || port < 1 || port > 65535) {
        _status = "Introdu o adresă IP validă și portul telemetriei G20/GR01.";emit connectionsChanged();return false;
    }
    refresh();
    const QString key = "tcp:" + address.toString() + ":" + QString::number(port);
    if (!_configs.contains(key)) {
        auto config = new TCPConfiguration("NAVO telemetrie • " + address.toString());
        config->setHost(address.toString());config->setPort(static_cast<quint16>(port));config->setAutoConnect(_autoConnect);
        LinkManager::instance()->endCreateConfiguration(config);
    }
    connectOne(key);return true;
}

void NavoConnectivity::setSerialBaud(int baud) {
    if (baud != 57600 && baud != 115200 && baud != 921600) return;
    _baud = baud;QSettings().setValue("NavoConnectivity/serialBaud", baud);
#ifndef QGC_NO_SERIAL_LINK
    for (const auto &ptr : _configs) {
        auto serial = qobject_cast<SerialConfiguration *>(ptr.data());
        if (serial && !serial->link() && serial->name().startsWith("NAVO USB")) serial->setBaud(baud);
    }
#endif
    _status = "Viteză pentru porturile USB NAVO neconectate: " + QString::number(baud);emit connectionsChanged();
}

QVariantMap NavoConnectivity::savedEthernet() const {
    QSettings settings;settings.beginGroup("NavoEthernet");QVariantMap result;
    for (const QString &key : settings.childKeys()) result.insert(key, settings.value(key));
    return result;
}
