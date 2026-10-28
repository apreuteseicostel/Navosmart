#pragma once

#include <QObject>
#include <QPointer>
#include <QElapsedTimer>
#include <QString>
#include <QtGlobal>
#include "QGCMAVLink.h"

class Vehicle;

// Read-only MAVLink GPS-yaw monitor. It never changes the EKF or vehicle mode.
// Do not confuse GPS course-over-ground with the dual-antenna heading baseline.
class NavoGnssHeading final : public QObject {
    Q_OBJECT
    Q_PROPERTY(QObject* vehicle READ vehicle WRITE setVehicle NOTIFY vehicleChanged)
    Q_PROPERTY(bool linkAlive READ linkAlive WRITE setLinkAlive NOTIFY headingChanged)
    Q_PROPERTY(double autopilotHeadingDeg READ autopilotHeadingDeg WRITE setAutopilotHeadingDeg NOTIFY headingChanged)
    Q_PROPERTY(bool gpsYawValid READ gpsYawValid NOTIFY headingChanged)
    Q_PROPERTY(double gpsYawDeg READ gpsYawDeg NOTIFY headingChanged)
    Q_PROPERTY(double selectedHeadingDeg READ selectedHeadingDeg NOTIFY headingChanged)
    Q_PROPERTY(QString headingSource READ headingSource NOTIFY headingChanged)
    Q_PROPERTY(QString headingDetail READ headingDetail NOTIFY headingChanged)
    Q_PROPERTY(int gpsFixType READ gpsFixType NOTIFY headingChanged)
    Q_PROPERTY(int satellites READ satellites NOTIFY headingChanged)
    Q_PROPERTY(int gpsYawAgeMs READ gpsYawAgeMs NOTIFY headingChanged)
    Q_PROPERTY(bool fallbackActive READ fallbackActive NOTIFY headingChanged)

public:
    explicit NavoGnssHeading(QObject* parent = nullptr);
    QObject* vehicle() const;
    void setVehicle(QObject*);
    bool linkAlive() const { return _linkAlive; }
    void setLinkAlive(bool);
    double autopilotHeadingDeg() const { return _autopilotHeadingDeg; }
    void setAutopilotHeadingDeg(double);

    bool gpsYawValid() const;
    double gpsYawDeg() const;
    double selectedHeadingDeg() const;
    QString headingSource() const;
    QString headingDetail() const;
    int gpsFixType() const;
    int satellites() const;
    int gpsYawAgeMs() const;
    bool fallbackActive() const;

signals:
    void vehicleChanged();
    void headingChanged();

private slots:
    void _mavlink(const mavlink_message_t&);
    void _refresh();

private:
    struct Receiver {
        double yawDeg = qQNaN();
        qint64 lastYawMs = -1;
        int fix = 0;
        int sats = -1;
        qint64 lastPacketMs = -1;
    };
    static constexpr qint64 kYawTimeoutMs = 3000;
    void _reset();
    void _observe(Receiver&, uint8_t fix, uint8_t satellites, uint16_t rawYaw);
    bool _available(const Receiver&) const;
    const Receiver* _activeGps() const;
    const Receiver* _diagnosticGps() const;

    QPointer<Vehicle> _vehicle;
    QElapsedTimer _clock;
    Receiver _gps1, _gps2;
    bool _linkAlive = false;
    double _autopilotHeadingDeg = qQNaN();
};
