#include "NavoNanoTelemetry.h"
#include "Vehicle.h"
#include <QDateTime>
#include <QTimer>
#include <cstring>
NavoNanoTelemetry::NavoNanoTelemetry(QObject*p):QObject(p){auto*t=new QTimer(this);t->setInterval(1000);connect(t,&QTimer::timeout,this,&NavoNanoTelemetry::_timeout);t->start();}
QObject* NavoNanoTelemetry::vehicle()const{return _vehicle;}
void NavoNanoTelemetry::setVehicle(QObject*o){Vehicle*v=qobject_cast<Vehicle*>(o);if(v==_vehicle)return;if(_vehicle)disconnect(_vehicle,nullptr,this,nullptr);_vehicle=v;if(_vehicle)connect(_vehicle,&Vehicle::mavlinkMessageReceived,this,&NavoNanoTelemetry::_mavlink);_lastMs=0;emit vehicleChanged();emit telemetryChanged();}
bool NavoNanoTelemetry::connected()const{return _lastMs&&QDateTime::currentMSecsSinceEpoch()-_lastMs<2500;}
void NavoNanoTelemetry::_timeout(){emit telemetryChanged();}
void NavoNanoTelemetry::_set(const char*n,float v){if(!strcmp(n,"NVBATV"))_batteryV=v;else if(!strcmp(n,"NVBATTEMP"))_tempC=v;else if(!strcmp(n,"NVWATER"))_water=v>0.5f;else if(!strcmp(n,"NVWFAULT"))_waterFault=v>0.5f;else if(!strcmp(n,"NVHEAD"))_head=v>0.5f;else if(!strcmp(n,"NVPOS"))_pos=v>0.5f;else if(!strcmp(n,"NVHOPL"))_hl=qRound(v);else if(!strcmp(n,"NVHOPR"))_hr=qRound(v);else if(!strcmp(n,"NVRUD"))_rud=qRound(v);else if(!strcmp(n,"NVALARM"))_alarm=qRound(v);else return;_lastMs=QDateTime::currentMSecsSinceEpoch();emit telemetryChanged();}
void NavoNanoTelemetry::_mavlink(const mavlink_message_t&m){if(m.msgid!=MAVLINK_MSG_ID_NAMED_VALUE_FLOAT)return;mavlink_named_value_float_t p{};mavlink_msg_named_value_float_decode(&m,&p);char n[11]{};memcpy(n,p.name,10);_set(n,p.value);}
