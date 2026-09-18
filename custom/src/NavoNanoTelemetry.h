#pragma once
#include <QObject>
#include "QGCMAVLink.h"
class Vehicle;
class NavoNanoTelemetry : public QObject {
 Q_OBJECT
 Q_PROPERTY(QObject* vehicle READ vehicle WRITE setVehicle NOTIFY vehicleChanged)
 Q_PROPERTY(bool connected READ connected NOTIFY telemetryChanged)
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
 explicit NavoNanoTelemetry(QObject* p=nullptr);
 QObject* vehicle() const; void setVehicle(QObject*);
 bool connected()const; double batteryVoltage()const{return _batteryV;} double batteryTempC()const{return _tempC;}
 bool waterDetected()const{return _water;} bool waterSensorFault()const{return _waterFault;} bool headlightOn()const{return _head;}
 bool positionLightsOn()const{return _pos;} int hopperLeftUs()const{return _hl;} int hopperRightUs()const{return _hr;} int rudderUs()const{return _rud;} int alarmMask()const{return _alarm;}
signals:void telemetryChanged();void vehicleChanged();
private slots:void _mavlink(const mavlink_message_t&);void _timeout();
private:void _set(const char*,float);
 Vehicle* _vehicle=nullptr; qint64 _lastMs=0; double _batteryV=0,_tempC=qQNaN(); bool _water=false,_waterFault=false,_head=false,_pos=false; int _hl=0,_hr=0,_rud=0,_alarm=0;
};
