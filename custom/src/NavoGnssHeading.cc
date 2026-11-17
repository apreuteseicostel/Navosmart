#include "NavoGnssHeading.h"
#include "Vehicle.h"
#include "ParameterManager.h"
#include "Fact.h"

#include <QTimer>
#include <QByteArray>
#include <QStringList>
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
    _queueInitialParameterRead();
}

void NavoGnssHeading::_reset() {
    _gps1 = Receiver{};
    _gps2 = Receiver{};
    _autopilotHeadingDeg = qQNaN();
    _lastAbsoluteYawMs = -1;
    _magStatusMs = -1;
    _magHealthy = false;
    _ekfCompassFallback = false;
    _ekfYawMode = -1;
    _compassUse = -1;
    _compassDevIdPresent = -1;
    _parameterFacts.clear();
    _parameterResponses.clear();
    _parameterRefreshPending = false;
    _initialParameterReadQueued = false;
    _lastParameterRequestMs = -1;
}

void NavoGnssHeading::setLinkAlive(bool alive) {
    if (_linkAlive == alive) return;
    _linkAlive = alive;
    if (!alive) {
        // A reconnect must supply a *new* valid GPS-yaw MAVLink packet.
        _reset(); // no stale magnetic fallback or gyro holdover after link loss
    }
    emit headingChanged();
    if (alive) _queueInitialParameterRead();
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
    _lastAbsoluteYawMs = receiver.lastYawMs;
    _ekfCompassFallback = false; // fresh UM982 yaw outranks previous fallback event
}

void NavoGnssHeading::_mavlink(const mavlink_message_t& message) {
    if (!_linkAlive || !_vehicle || message.sysid != _vehicle->id()
        || message.compid != MAV_COMP_ID_AUTOPILOT1) return;

    switch (message.msgid) {
    case MAVLINK_MSG_ID_GPS_RAW_INT: {
        mavlink_gps_raw_int_t gps{};
        mavlink_msg_gps_raw_int_decode(&message, &gps);
        _observe(_gps1, gps.fix_type, gps.satellites_visible, gps.yaw);
        // GPS_RAW_INT.h_acc is a MAVLink2 extension in millimetres; zero is unknown.
        _gps1.accuracyM = gps.h_acc > 0 && gps.h_acc < UINT32_MAX
            ? double(gps.h_acc) / 1000.0 : qQNaN();
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
    case MAVLINK_MSG_ID_SYS_STATUS: {
        mavlink_sys_status_t status{};
        mavlink_msg_sys_status_decode(&message, &status);
        constexpr uint32_t mag = MAV_SYS_STATUS_SENSOR_3D_MAG;
        _magHealthy = (status.onboard_control_sensors_present & mag)
            && (status.onboard_control_sensors_enabled & mag)
            && (status.onboard_control_sensors_health & mag);
        _magStatusMs = _clock.elapsed();
        if (compassFallbackActive()) _lastAbsoluteYawMs = _magStatusMs;
        emit headingChanged();
        break;
    }
    case MAVLINK_MSG_ID_PARAM_VALUE: {
        mavlink_param_value_t paramValue{};
        mavlink_msg_param_value_decode(&message, &paramValue);
        // Fixed 16-byte MAVLink name can lack NUL terminator.
        const QByteArray key = QByteArray(paramValue.param_id, sizeof(paramValue.param_id))
                                   .split('\0').first();
        const QString name=QString::fromLatin1(key);
        // The autopilot can answer a targeted PARAM_REQUEST_READ even if
        // other parameters were absent from the initial QGC download.
        static const QStringList requested={
            QStringLiteral("EK3_SRC1_YAW"),QStringLiteral("EK3_SRC2_YAW"),
            QStringLiteral("EK3_SRC3_YAW"),QStringLiteral("COMPASS_USE"),
            QStringLiteral("COMPASS_USE2"),QStringLiteral("COMPASS_USE3"),
            QStringLiteral("COMPASS_DEV_ID"),QStringLiteral("COMPASS_DEV_ID2"),
            QStringLiteral("COMPASS_DEV_ID3"),QStringLiteral("COMPASS_PRIO1_ID"),
            QStringLiteral("COMPASS_PRIO2_ID"),QStringLiteral("COMPASS_PRIO3_ID")};
        if(!requested.contains(name))break;
        _parameterResponses.insert(name);
        if(key=="EK3_SRC1_YAW")_ekfYawMode=std::isfinite(paramValue.param_value)
            ? int(paramValue.param_value):-1;
        else if(key=="COMPASS_USE")_compassUse=std::isfinite(paramValue.param_value)
            ? int(paramValue.param_value):-1;
        else if(key=="COMPASS_DEV_ID") {
            // Raw PARAM_VALUE float cannot reliably encode all 32 bits of
            // ArduPilot device IDs; identity is decoded only from QGC Fact.
            _compassDevIdPresent=std::isfinite(paramValue.param_value) &&
                paramValue.param_value>0 ? 1:0;
        }
        _readParameterFacts();
        emit headingChanged();
        break;
    }
    case MAVLINK_MSG_ID_STATUSTEXT: {
        mavlink_statustext_t status{};
        mavlink_msg_statustext_decode(&message, &status);
        const QString line = QString::fromLatin1(status.text, sizeof(status.text));
        // EKF3 reports an actual GPS->magnetic transition; merely receiving
        // vehicle.heading or a magnetometer health flag cannot prove its source.
        if (!line.startsWith(QStringLiteral("EKF3 IMU"))) break;
        if (line.contains(QStringLiteral("yaw fallback active"))) {
            _ekfCompassFallback = true;
            if (compassHealthy()) _lastAbsoluteYawMs = _clock.elapsed();
        } else if (line.contains(QStringLiteral("yaw external"))) {
            _ekfCompassFallback = false;
        } else break;
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

bool NavoGnssHeading::compassHealthy() const {
    return _linkAlive && _vehicle && _magHealthy && _magStatusMs >= 0
        && _clock.elapsed()-_magStatusMs >= 0
        && _clock.elapsed()-_magStatusMs < kMagTimeoutMs;
}

bool NavoGnssHeading::compassFallbackActive() const {
    // All four gates are necessary: a configured external compass, EKF3 GPS
    // with compass fallback, fresh magnetometer health, and an explicit EKF3
    // "yaw fallback active" event. This does not prove the sensor model.
    return _linkAlive && _vehicle && !_activeGps() && _ekfCompassFallback
        && _ekfYawMode == 3 && _compassUse == 1
        && _compassDevIdPresent == 1 && compassHealthy()
        && std::isfinite(_autopilotHeadingDeg);
}

bool NavoGnssHeading::h743FallbackActive() const {
    // Tertiary: only short H743/EKF holdover after a known absolute yaw.
    // An unaided gyro integrates drift; never start an unanchored heading.
    return _linkAlive && _vehicle && !_activeGps() && !compassFallbackActive()
        && std::isfinite(_autopilotHeadingDeg)
        && _lastAbsoluteYawMs >= 0
        && _clock.elapsed()-_lastAbsoluteYawMs >= 0
        && _clock.elapsed()-_lastAbsoluteYawMs < kInertialHoldoverMs;
}

double NavoGnssHeading::selectedHeadingDeg() const {
    if (!_linkAlive || !_vehicle) return qQNaN();
    if (const auto* r = _activeGps()) return r->yawDeg;
    if (compassFallbackActive()) return _autopilotHeadingDeg;
    if (h743FallbackActive()) return _autopilotHeadingDeg;
    return qQNaN();
}

bool NavoGnssHeading::fallbackActive() const {
    return compassFallbackActive() || h743FallbackActive();
}

QString NavoGnssHeading::headingSource() const {
    if (_activeGps() == &_gps1) return QStringLiteral("GNSS GPS1 / UM982");
    if (_activeGps() == &_gps2) return QStringLiteral("GNSS GPS2");
    if (compassFallbackActive()) return QStringLiteral("Busolă externă / EKF3");
    if (h743FallbackActive()) return QStringLiteral("H743 / EKF (temporar)");
    return QStringLiteral("HEADING --");
}

QString NavoGnssHeading::compassStatus() const {
    if (!_linkAlive || !_vehicle) return QStringLiteral("H743 deconectat");
    if (_compassDevIdPresent != 1)
        return QStringLiteral("Busolă fără ID verificat; confirmă IST8310 pe I2C1");
    if (_compassUse != 1)
        return QStringLiteral("COMPASS_USE trebuie verificat (1 = activ)");
    if (_ekfYawMode != 3)
        return QStringLiteral("EK3_SRC1_YAW nu confirmă GPS cu rezervă busolă (3)");
    if (!compassHealthy())
        return QStringLiteral("Magnetometrul nu este HEALTHY sau telemetria este veche");
    if (_activeGps()) return QStringLiteral("Busolă disponibilă; GNSS are prioritate");
    if (_ekfCompassFallback)
        return QStringLiteral("EKF3 a anunțat fallback magnetic; modelul IST8310 se verifică fizic");
    return QStringLiteral("Aștept mesaj EKF3 yaw fallback active; H743 doar estimativ");
}

QString NavoGnssHeading::headingDetail() const {
    if (_activeGps()) return QStringLiteral(
        "1/3 UM982: yaw GNSS dual-antenă valid; nu este COG.");
    if (compassFallbackActive()) return QStringLiteral(
        "2/3 Busolă: EKF3 confirmă fallback magnetic și magnetometru sănătos. "
        "Sursa fizică IST8310 necesită verificare I2C1 și calibrare.");
    if (h743FallbackActive()) return QStringLiteral(
        "3/3 H743/EKF: estimare temporară până la 12s după ultimul yaw "
        "absolut. Poate deriva; nu este busolă și nu confirmă navigație sigură.");
    if (!_linkAlive || !_vehicle) return QStringLiteral("Legătura cu H743 este indisponibilă");
    return QStringLiteral(
        "HEADING indisponibil: fără yaw GNSS, fallback magnetic confirmat "
        "sau estimare H743 suficient de recentă. Nu confunda GPS fix cu GPS yaw.");
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


void NavoGnssHeading::_queueInitialParameterRead() {
    if (_initialParameterReadQueued || !_linkAlive || !_vehicle) return;
    _initialParameterReadQueued = true;
    // Wait for the initial QGC parameter negotiation, then refresh just the
    // diagnostic set. The lambda rechecks the actual bound vehicle.
    const QPointer<Vehicle> expected=_vehicle;
    QTimer::singleShot(1500,this,[this,expected]() {
        if (_linkAlive && _vehicle && _vehicle==expected)
            requestDiagnosticParameters();
    });
}

void NavoGnssHeading::requestDiagnosticParameters() {
    if (!_linkAlive || !_vehicle || !_vehicle->parameterManager()) return;
    if (_lastParameterRequestMs >= 0 &&
        _clock.elapsed()-_lastParameterRequestMs < 1500) return;
    const qint64 stamp=_clock.elapsed();
    _lastParameterRequestMs=stamp;
    _parameterRefreshPending=true;
    _parameterResponses.clear();
    static const QStringList names={
        QStringLiteral("EK3_SRC1_YAW"), QStringLiteral("EK3_SRC2_YAW"),
        QStringLiteral("EK3_SRC3_YAW"), QStringLiteral("COMPASS_USE"),
        QStringLiteral("COMPASS_USE2"), QStringLiteral("COMPASS_USE3"),
        QStringLiteral("COMPASS_DEV_ID"), QStringLiteral("COMPASS_DEV_ID2"),
        QStringLiteral("COMPASS_DEV_ID3"), QStringLiteral("COMPASS_PRIO1_ID"),
        QStringLiteral("COMPASS_PRIO2_ID"), QStringLiteral("COMPASS_PRIO3_ID")};
    auto* manager=_vehicle->parameterManager();
    for(const QString& name:names)
        manager->refreshParameter(MAV_COMP_ID_AUTOPILOT1,name);
    _readParameterFacts();
    emit headingChanged();
    QTimer::singleShot(6500,this,[this,stamp]() {
        if (_lastParameterRequestMs!=stamp || !_linkAlive || !_vehicle) return;
        _parameterRefreshPending=false;
        _readParameterFacts();
        emit headingChanged();
    });
}

void NavoGnssHeading::_readParameterFacts() {
    if (!_linkAlive || !_vehicle || !_vehicle->parameterManager()) return;
    auto* manager=_vehicle->parameterManager();
    static const QStringList names={
        QStringLiteral("EK3_SRC1_YAW"), QStringLiteral("EK3_SRC2_YAW"),
        QStringLiteral("EK3_SRC3_YAW"), QStringLiteral("COMPASS_USE"),
        QStringLiteral("COMPASS_USE2"), QStringLiteral("COMPASS_USE3"),
        QStringLiteral("COMPASS_DEV_ID"), QStringLiteral("COMPASS_DEV_ID2"),
        QStringLiteral("COMPASS_DEV_ID3"), QStringLiteral("COMPASS_PRIO1_ID"),
        QStringLiteral("COMPASS_PRIO2_ID"), QStringLiteral("COMPASS_PRIO3_ID")};
    for(const QString& name:names) {
        if(!manager->parameterExists(MAV_COMP_ID_AUTOPILOT1,name))continue;
        Fact* fact=manager->getParameter(MAV_COMP_ID_AUTOPILOT1,name);
        if(!fact)continue;
        const QVariant value=fact->rawValue();
        if(value.isValid() && !value.isNull())_parameterFacts.insert(name,value);
    }
    const auto yaw=_parameterFacts.constFind(QStringLiteral("EK3_SRC1_YAW"));
    if(yaw!=_parameterFacts.cend()){
        bool ok=false;const double value=yaw.value().toDouble(&ok);
        if(ok && std::isfinite(value) && std::trunc(value)==value)
            _ekfYawMode=int(value);
    }
    const auto use=_parameterFacts.constFind(QStringLiteral("COMPASS_USE"));
    if(use!=_parameterFacts.cend()){
        bool ok=false;const double value=use.value().toDouble(&ok);
        if(ok && std::isfinite(value) && std::trunc(value)==value)
            _compassUse=int(value);
    }
    bool hasDeviceIdParameter=false,hasDevice=false;
    for(const QString& name:{QStringLiteral("COMPASS_DEV_ID"),
                             QStringLiteral("COMPASS_DEV_ID2"),
                             QStringLiteral("COMPASS_DEV_ID3")}) {
        const auto it=_parameterFacts.constFind(name);
        if(it==_parameterFacts.cend())continue;
        hasDeviceIdParameter=true;
        quint32 id=0;int busType=0,bus=0,address=0,devType=0;
        if(_decodeCompassDeviceId(it.value(),id,busType,bus,address,devType))
            hasDevice=true;
    }
    if(hasDeviceIdParameter)_compassDevIdPresent=hasDevice?1:0;
}

bool NavoGnssHeading::_decodeCompassDeviceId(
    const QVariant& raw,quint32& id,int& busType,int& bus,
    int& address,int& deviceType) {
    bool ok=false;const double value=raw.toDouble(&ok);
    // Device ID is a packed 32-bit INTEGER. Never decode the IEEE-754
    // float transmitted by PARAM_VALUE as a decimal hardware ID.
    if(!ok || !std::isfinite(value) || value<=0 ||
       value>4294967295.0 || std::trunc(value)!=value)return false;
    id=quint32(quint64(value));
    busType=int(id&0x07u);bus=int((id>>3)&0x1fu);
    address=int((id>>8)&0xffu);deviceType=int((id>>16)&0xffffu);
    return true;
}

QString NavoGnssHeading::ekfYawStatus() const {
    if(!_linkAlive || !_vehicle)return QStringLiteral("H743 deconectat");
    if(_ekfYawMode<0)
        return _parameterRefreshPending
            ? QStringLiteral("Se citește EK3_SRC1_YAW…")
            : QStringLiteral("EK3_SRC1_YAW necitit • verifică telemetria și parametrii");
    QString detail;
    switch(_ekfYawMode) {
    case 0:detail=QStringLiteral("Niciun senzor yaw");break;
    case 1:detail=QStringLiteral("Busolă");break;
    case 2:detail=QStringLiteral("GPS yaw");break;
    case 3:detail=QStringLiteral("GPS yaw + rezervă busolă (configurat)");break;
    default:detail=QStringLiteral("Cod yaw neinterpretat");break;
    }
    return QString::number(_ekfYawMode)+QStringLiteral(" • ")+detail+
        (_parameterResponses.contains(QStringLiteral("EK3_SRC1_YAW"))
        ? QStringLiteral(" • răspuns MAVLink")
        : QStringLiteral(" • valoare QGC/cache; verifică refresh"));
}

QString NavoGnssHeading::compassIdentity() const {
    if(!_linkAlive || !_vehicle)return QStringLiteral("H743 deconectat");
    bool readAny=false,foundOther=false;
    for(const QString& key:{QStringLiteral("COMPASS_DEV_ID"),
                            QStringLiteral("COMPASS_DEV_ID2"),
                            QStringLiteral("COMPASS_DEV_ID3")}) {
        auto it=_parameterFacts.constFind(key);
        if(it==_parameterFacts.cend())continue;
        readAny=true;
        quint32 id=0;int busType=0,bus=0,address=0,deviceType=0;
        if(!_decodeCompassDeviceId(it.value(),id,busType,bus,address,deviceType))continue;
        foundOther=true;
        if(busType==1 && deviceType==0x0a)
            return QStringLiteral("IST8310 identificat în %1 • I2C bus %2 • adresă 0x%3 • ID %4. Conectorul fizic necesită verificare.")
                .arg(key).arg(bus).arg(address,2,16,QChar('0')).arg(id);
    }
    if(!readAny)
        return _parameterRefreshPending ? QStringLiteral("Se citesc ID-urile busolelor…")
               : QStringLiteral("ID-uri busolă necitite; verifică managerul de parametri");
    return foundOther
        ? QStringLiteral("Există busolă, dar niciun ID nu confirmă IST8310 pe I2C")
        : QStringLiteral("ID-urile citite nu indică o busolă instalată");
}

QString NavoGnssHeading::compassPriorityStatus() const {
    if(!_linkAlive || !_vehicle)return QStringLiteral("H743 deconectat");
    QStringList priorities;
    for(int p=1;p<=3;++p) {
        const QString key=QStringLiteral("COMPASS_PRIO%1_ID").arg(p);
        auto it=_parameterFacts.constFind(key);
        if(it==_parameterFacts.cend())continue;
        quint32 id=0;int busType=0,bus=0,address=0,devType=0;
        if(!_decodeCompassDeviceId(it.value(),id,busType,bus,address,devType)) {
            priorities<<QStringLiteral("%1: fără ID").arg(p);continue;
        }
        const QString model=(busType==1 && devType==0x0a)
            ? QStringLiteral("IST8310"):QStringLiteral("alt senzor");
        priorities<<QStringLiteral("%1: %2 / ID %3").arg(p).arg(model).arg(id);
    }
    return priorities.isEmpty()?QStringLiteral("Prioritatea busolelor necitită")
        :priorities.join(QStringLiteral(" • "));
}

QString NavoGnssHeading::parameterReadStatus() const {
    if(!_linkAlive || !_vehicle)return QStringLiteral("H743 deconectat");
    if(_parameterRefreshPending)
        return QStringLiteral("Citire diagnostică în curs • %1 răspunsuri MAVLink, %2 valori QGC")
            .arg(_parameterResponses.size()).arg(_parameterFacts.size());
    if(_lastParameterRequestMs<0)return QStringLiteral("Citire neinițiată");
    return QStringLiteral("Citire încheiată • %1 răspunsuri, %2 valori disponibile în QGC; restul neconfirmate")
        .arg(_parameterResponses.size()).arg(_parameterFacts.size());
}

void NavoGnssHeading::_refresh() {
    // QGC's parameter download/cache may finish after the first GNSS packets.
    // Refresh our read-only Fact snapshot without sending repeated MAVLink requests.
    _readParameterFacts();
    emit headingChanged();
}

// GPS1 precision is not HDOP and is independent of dual-antenna yaw availability.
bool NavoGnssHeading::positionFresh() const {
    return _linkAlive && _vehicle && _gps1.fix >= 3 && _gps1.lastPacketMs >= 0
        && _clock.elapsed() - _gps1.lastPacketMs < kYawTimeoutMs;
}
double NavoGnssHeading::positionAccuracyM() const {
    return positionFresh() ? _gps1.accuracyM : qQNaN();
}
