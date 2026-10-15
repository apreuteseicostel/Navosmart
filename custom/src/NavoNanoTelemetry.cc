#include "NavoNanoTelemetry.h"
#include "Vehicle.h"
#include <QDateTime>
#include <QTimer>
#include <cstring>
#include <cmath>
NavoNanoTelemetry::NavoNanoTelemetry(QObject*p):QObject(p){_clock.start();auto*t=new QTimer(this);t->setInterval(1000);connect(t,&QTimer::timeout,this,&NavoNanoTelemetry::_timeout);t->start();}
QObject* NavoNanoTelemetry::vehicle()const{return _vehicle.data();}
void NavoNanoTelemetry::setVehicle(QObject*o){Vehicle*v=qobject_cast<Vehicle*>(o);if(v==_vehicle)return;if(_vehicle)disconnect(_vehicle,nullptr,this,nullptr);_vehicle=v;if(_vehicle)connect(_vehicle,&Vehicle::mavlinkMessageReceived,this,&NavoNanoTelemetry::_mavlink);_reset();emit vehicleChanged();emit telemetryChanged();}
void NavoNanoTelemetry::_reset(){
 _capMs=_headMs=_posMs=_hopMs=_requestMs=-1;_caps=_hopperMask=_request=0;
 _lastMs=0; _batteryV=0; _tempC=qQNaN();
 _water=_waterFault=_head=_pos=false; _hl=_hr=_rud=_alarm=0;
 _tempMs=_waterMs=_faultMs=_heartbeatMs=-1;
}
void NavoNanoTelemetry::setV3Profile(bool value){
 if(_v3==value)return;
 _v3=value; _reset(); emit telemetryChanged();
}
bool NavoNanoTelemetry::_fresh(qint64 timestamp)const{
 return timestamp>=0 && _clock.elapsed()-timestamp<2500;
}
bool NavoNanoTelemetry::connected()const{return _fresh(_heartbeatMs);}
bool NavoNanoTelemetry::temperatureValid()const{
 return connected() && _fresh(_tempMs) && std::isfinite(_tempC);
}
bool NavoNanoTelemetry::waterValid()const{
 return connected() && _fresh(_waterMs) && _fresh(_faultMs) && !_waterFault;
}
void NavoNanoTelemetry::_timeout(){emit telemetryChanged();}
void NavoNanoTelemetry::_set(const char*n,float v){
 const qint64 now=_clock.elapsed();
 // V3 has a separate namespace: legacy Nano frames cannot impersonate it.
 if(_v3){
  if(!strcmp(n,"NV3VER")){_heartbeatMs=v==1.0f?now:-1;}
  else if(!strcmp(n,"NV3CAP")){_caps=std::isfinite(v)&&v>=0&&v<=31&&std::floor(v)==v?int(v):0;_capMs=now;}
  else if(!strcmp(n,"NV3HEAD")){_head=v==1;_headMs=(v==0||v==1)?now:-1;}
  else if(!strcmp(n,"NV3POS")){_pos=v==1;_posMs=(v==0||v==1)?now:-1;}
  else if(!strcmp(n,"NV3HOP")){_hopperMask=std::isfinite(v)&&v>=0&&v<=3&&std::floor(v)==v?int(v):-1;_hopMs=_hopperMask>=0?now:-1;}
  else if(!strcmp(n,"NV3REQ")){_request=std::isfinite(v)&&v>=0&&v<=16777215&&std::floor(v)==v?int(v):-1;_requestMs=_request>=0?now:-1;}
  else if(!strcmp(n,"NV3TEMP")){_tempC=std::isfinite(v)&&v>-1000?v:qQNaN();_tempMs=now;}
  else if(!strcmp(n,"NV3WATER")){_water=v==1.0f;_waterMs=(v==0.0f||v==1.0f)?now:-1;}
  else if(!strcmp(n,"NV3WFAULT")){_waterFault=v!=0.0f;_faultMs=(v==0.0f||v==1.0f)?now:-1;}
  else return;
 }else{
  if(!strcmp(n,"NVBATV"))_batteryV=v;
  else if(!strcmp(n,"NVBATTEMP")){_tempC=std::isfinite(v)&&v>-1000?v:qQNaN();_tempMs=now;}
  else if(!strcmp(n,"NVWATER")){_water=v==1.0f;_waterMs=(v==0.0f||v==1.0f)?now:-1;}
  else if(!strcmp(n,"NVWFAULT")){_waterFault=v!=0.0f;_faultMs=(v==0.0f||v==1.0f)?now:-1;}
  else if(!strcmp(n,"NVHEAD"))_head=v>0.5f;
  else if(!strcmp(n,"NVPOS"))_pos=v>0.5f;
  else if(!strcmp(n,"NVHOPL")&&std::isfinite(v))_hl=qRound(v);
  else if(!strcmp(n,"NVHOPR")&&std::isfinite(v))_hr=qRound(v);
  else if(!strcmp(n,"NVRUD")&&std::isfinite(v))_rud=qRound(v);
  else if(!strcmp(n,"NVALARM")&&std::isfinite(v))_alarm=qRound(v);
  else return;
  _heartbeatMs=now;
 }
 _lastMs=QDateTime::currentMSecsSinceEpoch();emit telemetryChanged();
}
void NavoNanoTelemetry::_mavlink(const mavlink_message_t&m){if(!_vehicle || m.sysid!=_vehicle->id() || m.compid!=MAV_COMP_ID_AUTOPILOT1 || m.msgid!=MAVLINK_MSG_ID_NAMED_VALUE_FLOAT)return;mavlink_named_value_float_t p{};mavlink_msg_named_value_float_decode(&m,&p);char n[11]{};memcpy(n,p.name,10);_set(n,p.value);}
