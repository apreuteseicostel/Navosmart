#pragma once
#include <QObject>
#include <QPointer>
#include <QElapsedTimer>
#include "QGCMAVLink.h"
class Vehicle;
class NavoH743Telemetry : public QObject {
 Q_OBJECT
 Q_PROPERTY(QObject* vehicle READ vehicle WRITE setVehicle NOTIFY vehicleChanged)
 Q_PROPERTY(int capabilities READ capabilities NOTIFY telemetryChanged)
 Q_PROPERTY(bool lightsValid READ lightsValid NOTIFY telemetryChanged)
 Q_PROPERTY(bool hopperStateValid READ hopperStateValid NOTIFY telemetryChanged)
 Q_PROPERTY(int hopperMask READ hopperMask NOTIFY telemetryChanged)
 Q_PROPERTY(int lastRequest READ lastRequest NOTIFY telemetryChanged)
 Q_PROPERTY(bool v3Profile READ v3Profile WRITE setV3Profile NOTIFY telemetryChanged)
 Q_PROPERTY(bool temperatureValid READ temperatureValid NOTIFY telemetryChanged)
 Q_PROPERTY(bool waterValid READ waterValid NOTIFY telemetryChanged)
 Q_PROPERTY(bool connected READ connected NOTIFY telemetryChanged)
 Q_PROPERTY(qint64 lastUpdateMs READ lastUpdateMs NOTIFY telemetryChanged)
 Q_PROPERTY(double batteryVoltage READ batteryVoltage NOTIFY telemetryChanged)
 Q_PROPERTY(double batteryTempC READ batteryTempC NOTIFY telemetryChanged)
 Q_PROPERTY(bool waterDetected READ waterDetected NOTIFY telemetryChanged)
 Q_PROPERTY(bool waterSensorFault READ waterSensorFault NOTIFY telemetryChanged)
 Q_PROPERTY(bool headlightOn READ headlightOn NOTIFY telemetryChanged)
 Q_PROPERTY(bool positionLightsOn READ positionLightsOn NOTIFY telemetryChanged)
 Q_PROPERTY(int hopperLeftUs READ hopperLeftUs NOTIFY telemetryChanged)
 Q_PROPERTY(int hopperRightUs READ hopperRightUs NOTIFY telemetryChanged)
 Q_PROPERTY(int rudderUs READ rudderUs NOTIFY telemetryChanged)
 Q_PROPERTY(int alarmMask READ alarmMask NOTIFY telemetryChanged)
public:
 explicit NavoH743Telemetry(QObject* p=nullptr);
 int capabilities() const { return connected() && _fresh(_capMs) ? _caps : 0; }
 bool lightsValid() const { return connected() && _fresh(_headMs) && _fresh(_posMs); }
 bool hopperStateValid() const { return connected() && _fresh(_hopMs) && _fresh(_requestMs); }
 int hopperMask() const { return _hopperMask; }
 int lastRequest() const { return _request; }
 bool v3Profile() const { return _v3; }
 void setV3Profile(bool value);
 bool temperatureValid() const;
 bool waterValid() const;
 qint64 lastUpdateMs()const{return _lastMs;}
 QObject* vehicle() const; void setVehicle(QObject*);
 bool connected()const; double batteryVoltage()const{return _batteryV;} double batteryTempC()const{return temperatureValid() ? _tempC : qQNaN();}
 bool waterDetected()const{return _water;} bool waterSensorFault()const{return _waterFault;} bool headlightOn()const{return _head;}
 bool positionLightsOn()const{return _pos;} int hopperLeftUs()const{return _hl;} int hopperRightUs()const{return _hr;} int rudderUs()const{return _rud;} int alarmMask()const{return _alarm;}
signals:void telemetryChanged();void vehicleChanged();
private slots:void _mavlink(const mavlink_message_t&);void _timeout();
private:
 void _reset();
 bool _fresh(qint64 timestamp) const;
 QElapsedTimer _clock;
 bool _v3=true; // NAVO V3 only; legacy Nano mode unsupported
 int _caps=0,_hopperMask=0,_request=0;
 qint64 _capMs=-1,_headMs=-1,_posMs=-1,_hopMs=-1,_requestMs=-1;
 qint64 _tempMs=-1, _waterMs=-1, _faultMs=-1, _heartbeatMs=-1;
 void _set(const char*,float);
 QPointer<Vehicle> _vehicle; qint64 _lastMs=0; double _batteryV=0,_tempC=qQNaN(); bool _water=false,_waterFault=false,_head=false,_pos=false; int _hl=0,_hr=0,_rud=0,_alarm=0;
};
