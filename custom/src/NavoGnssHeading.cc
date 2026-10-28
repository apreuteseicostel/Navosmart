#include "NavoGnssHeading.h"
#include "Vehicle.h"

#include <QTimer>
#include <cmath>

NavoGnssHeading::NavoGnssHeading(QObject* parent) : QObject(parent) {
    _clock.start();
    auto* timer = new QTimer(this);
    timer->setInterval(500);
    connect(timer, &QTimer::timeout, this, &NavoGnssHeading::_refresh);
    timer->start();
}

QObject* NavoGnssHeading::vehicle() const { return _vehicle.data(); }

void NavoGnssHeading::setVehicle(QObject* value) {
    Vehicle* next = qobject_cast<Vehicle*>(value);
    if (next == _vehicle) return;
    if (_vehicle) disconnect(_vehicle, nullptr, this, nullptr);
    _vehicle = next;
    _reset();                       // Never carry GPS yaw across vehicles.
    if (_vehicle) {
        connect(_vehicle, &Vehicle::mavlinkMessageReceived,
                this, &NavoGnssHeading::_mavlink);
        connect(_vehicle, &QObject::destroyed, this, [this]() {
            _vehicle = nullptr;
            _reset();
            emit vehicleChanged();
            emit headingChanged();
        });
    }
    emit vehicleChanged();
    emit headingChanged();
}

void NavoGnssHeading::_reset() {
    _gps1 = Receiver{};
    _gps2 = Receiver{};
    _autopilotHeadingDeg = qQNaN();
}

void NavoGnssHeading::setLinkAlive(bool alive) {
    if (_linkAlive == alive) return;
    _linkAlive = alive;
    if (!alive) {
        // A reconnect must supply a *new* valid GPS-yaw MAVLink packet.
        _gps1 = Receiver{};
        _gps2 = Receiver{};
    }
    emit headingChanged();
}

void NavoGnssHeading::setAutopilotHeadingDeg(double degrees) {
    double value = std::isfinite(degrees)
        ? std::fmod(std::fmod(degrees, 360.0) + 360.0, 360.0) : qQNaN();
    if ((_autopilotHeadingDeg == value) ||
        (!std::isfinite(_autopilotHeadingDeg) && !std::isfinite(value))) return;
    _autopilotHeadingDeg = value;
    emit headingChanged();
}

void NavoGnssHeading::_observe(Receiver& receiver, uint8_t fix,
                              uint8_t sats, uint16_t rawYaw) {
    receiver.fix = fix;
    receiver.sats = sats == 255 ? -1 : static_cast<int>(sats);
    receiver.lastPacketMs = _clock.elapsed();

    // MAVLink 2 GPS_RAW_INT.yaw / GPS2_RAW.yaw units: centidegrees.
    // 0 = no GPS yaw, 65535 = GPS yaw temporarily unavailable.
    // 36000 is *valid* north. Do not use .cog (track over ground).
    const bool valid = fix >= 3 && receiver.sats >= 4
        && rawYaw >= 1 && rawYaw <= 36000;
    if (!valid) {
        receiver.yawDeg = qQNaN();
        receiver.lastYawMs = -1;    // Explicit invalidation is immediate.
        return;
    }
    receiver.yawDeg = rawYaw == 36000 ? 0.0 : double(rawYaw) / 100.0;
    receiver.lastYawMs = receiver.lastPacketMs;
}

void NavoGnssHeading::_mavlink(const mavlink_message_t& message) {
    if (!_linkAlive || !_vehicle || message.sysid != _vehicle->id()
        || message.compid != MAV_COMP_ID_AUTOPILOT1) return;

    switch (message.msgid) {
    case MAVLINK_MSG_ID_GPS_RAW_INT: {
        mavlink_gps_raw_int_t gps{};
        mavlink_msg_gps_raw_int_decode(&message, &gps);
        _observe(_gps1, gps.fix_type, gps.satellites_visible, gps.yaw);
        emit headingChanged();
        break;
    }
    case MAVLINK_MSG_ID_GPS2_RAW: {
        mavlink_gps2_raw_t gps{};
        mavlink_msg_gps2_raw_decode(&message, &gps);
        _observe(_gps2, gps.fix_type, gps.satellites_visible, gps.yaw);
        emit headingChanged();
        break;
    }
    default:
        break;
    }
}

bool NavoGnssHeading::_available(const Receiver& r) const {
    return _linkAlive && _vehicle && r.fix >= 3 && r.sats >= 4
        && std::isfinite(r.yawDeg) && r.lastYawMs >= 0
        && _clock.elapsed() - r.lastYawMs >= 0
        && _clock.elapsed() - r.lastYawMs < kYawTimeoutMs;
}

const NavoGnssHeading::Receiver* NavoGnssHeading::_activeGps() const {
    if (_available(_gps1)) return &_gps1;  // UM982 is normally GPS1.
    if (_available(_gps2)) return &_gps2;
    return nullptr;
}

const NavoGnssHeading::Receiver* NavoGnssHeading::_diagnosticGps() const {
    if (_gps1.lastPacketMs >= 0 && _clock.elapsed() - _gps1.lastPacketMs < kYawTimeoutMs)
        return &_gps1;
    if (_gps2.lastPacketMs >= 0 && _clock.elapsed() - _gps2.lastPacketMs < kYawTimeoutMs)
        return &_gps2;
    return nullptr;
}

bool NavoGnssHeading::gpsYawValid() const { return _activeGps() != nullptr; }

double NavoGnssHeading::gpsYawDeg() const {
    const auto* r = _activeGps();
    return r ? r->yawDeg : qQNaN();
}

double NavoGnssHeading::selectedHeadingDeg() const {
    if (!_linkAlive || !_vehicle) return qQNaN();
    if (const auto* r = _activeGps()) return r->yawDeg;
    return _autopilotHeadingDeg;    // Only display fallback; EKF is untouched.
}

bool NavoGnssHeading::fallbackActive() const {
    return _linkAlive && _vehicle && !_activeGps() && std::isfinite(_autopilotHeadingDeg);
}

QString NavoGnssHeading::headingSource() const {
    if (_activeGps() == &_gps1) return QStringLiteral("GNSS GPS1");
    if (_activeGps() == &_gps2) return QStringLiteral("GNSS GPS2");
    if (fallbackActive()) return QStringLiteral("H743 (rezervă)");
    return QStringLiteral("Indisponibil");
}

QString NavoGnssHeading::headingDetail() const {
    if (_activeGps()) return QStringLiteral("GPS yaw dual-antenă din MAVLink, nu COG");
    if (!_linkAlive || !_vehicle) return QStringLiteral("Legătura cu H743 este indisponibilă");
    if (_diagnosticGps()) return QStringLiteral("Poziția GPS poate fi validă, dar yaw GNSS lipsește sau este invalid");
    return QStringLiteral("H743 furnizează heading; GPS yaw neconfirmat sau expirat");
}

int NavoGnssHeading::gpsFixType() const {
    const auto* r = _diagnosticGps();
    return r ? r->fix : -1;
}
int NavoGnssHeading::satellites() const {
    const auto* r = _diagnosticGps();
    return r ? r->sats : -1;
}
int NavoGnssHeading::gpsYawAgeMs() const {
    const auto* r = _activeGps();
    return r ? int(_clock.elapsed() - r->lastYawMs) : -1;
}

void NavoGnssHeading::_refresh() {
    // Periodically notify QML when yaw freshness expires (even without packets).
    emit headingChanged();
}
