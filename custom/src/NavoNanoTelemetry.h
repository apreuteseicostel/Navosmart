#pragma once
#include <QObject>
#include <QByteArray>
class QIODevice;
class NavoNanoTelemetry : public QObject {
 Q_OBJECT
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
 explicit NavoNanoTelemetry(QObject* p=nullptr):QObject(p){}
 bool connected()const{return _connected;} double batteryVoltage()const{return _batteryMv/1000.0;} double batteryTempC()const{return _tempC10/10.0;}
 bool waterDetected()const{return _water;} bool waterSensorFault()const{return _waterFault;} bool headlightOn()const{return _head;}
 bool positionLightsOn()const{return _pos;} int hopperLeftUs()const{return _hl;} int hopperRightUs()const{return _hr;} int rudderUs()const{return _rud;} int alarmMask()const{return _alarm;}
 Q_INVOKABLE bool ingestLine(const QString& line);
signals:void telemetryChanged(); void frameRejected(QString reason);
private: bool _connected=false,_water=false,_waterFault=false,_head=false,_pos=false; quint32 _batteryMv=0; qint16 _tempC10=-32768; int _hl=0,_hr=0,_rud=0,_alarm=0;
};
