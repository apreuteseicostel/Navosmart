#include "NavoH743Telemetry.h"
#include "Vehicle.h"
#include <QDateTime>
#include <QTimer>
#include <cstring>
#include <cmath>
NavoH743Telemetry::NavoH743Telemetry(QObject*p):QObject(p){_clock.start();auto*t=new QTimer(this);t->setInterval(1000);connect(t,&QTimer::timeout,this,&NavoH743Telemetry::_timeout);t->start();}
QObject* NavoH743Telemetry::vehicle()const{return _vehicle.data();}
void NavoH743Telemetry::setVehicle(QObject*o){Vehicle*v=qobject_cast<Vehicle*>(o);if(v==_vehicle)return;if(_vehicle)disconnect(_vehicle,nullptr,this,nullptr);_vehicle=v;if(_vehicle)connect(_vehicle,&Vehicle::mavlinkMessageReceived,this,&NavoH743Telemetry::_mavlink);_reset();emit vehicleChanged();emit telemetryChanged();}
void NavoH743Telemetry::_reset(){
 _capMs=_headMs=_posMs=_hopMs=_requestMs=-1;_caps=_hopperMask=_request=0;
 _interiorTemp=_humidity=qQNaN();_interiorTempMs=_humidityMs=_environmentMs=-1;_environmentStatus=0;
 _lastMs=0; _batteryV=0; _tempC=qQNaN();
 _water=_waterFault=_head=_pos=false; _hl=_hr=_rud=_alarm=0;
 _tempMs=_waterMs=_faultMs=_heartbeatMs=-1;
 _waterStatusMs=_waterAdcMs=-1;_waterStatus=0;_waterAdcV=qQNaN();
 _standWetMs=_standFaultMs=-1;_standWet=false;_standFault=true;_waterStandaloneSeen=false;
}
void NavoH743Telemetry::setV3Profile(bool value){
 // NAVO V3 has no Nano: refuse legacy mode and keep the H743 namespace.
 if(!value || _v3)return;
 _v3=true; _reset(); emit telemetryChanged();
}
bool NavoH743Telemetry::_fresh(qint64 timestamp)const{
 return timestamp>=0 && _clock.elapsed()-timestamp<2500;
}
bool NavoH743Telemetry::connected()const{return _fresh(_heartbeatMs);}
int NavoH743Telemetry::interiorStatus()const{
 return connected() && _fresh(_environmentMs) ? _environmentStatus : 0;
}
qint64 NavoH743Telemetry::interiorAgeMs()const{
 return _interiorTempMs>=0 && _humidityMs>=0 ? _clock.elapsed()-qMin(_interiorTempMs,_humidityMs) : -1;
}
bool NavoH743Telemetry::interiorValid()const{
 return interiorStatus()==2 && interiorAgeMs()>=0 && interiorAgeMs()<12000
     && std::isfinite(_interiorTemp) && std::isfinite(_humidity);
}
bool NavoH743Telemetry::temperatureValid()const{
 return connected() && _fresh(_tempMs) && std::isfinite(_tempC);
}
int NavoH743Telemetry::waterMonitorStatus()const{
 return _fresh(_waterStatusMs) ? _waterStatus : 0;
}
bool NavoH743Telemetry::waterValid()const{
 if(_waterStandaloneSeen){
  return waterMonitorStatus()==2 && _fresh(_standWetMs) && _fresh(_standFaultMs) && !_standFault;
 }
 return connected() && _fresh(_waterMs) && _fresh(_faultMs) && !_waterFault;
}
void NavoH743Telemetry::_timeout(){emit telemetryChanged();}
void NavoH743Telemetry::_set(const char*n,float v){
 const qint64 now=_clock.elapsed();
 // V3 has a separate namespace: legacy Nano frames cannot impersonate it.
 if(_v3){
  if(!strcmp(n,"NV3VER")){_heartbeatMs=v==1.0f?now:-1;}
  else if(!strcmp(n,"NV3CAP")){_caps=std::isfinite(v)&&v>=0&&v<=31&&std::floor(v)==v?int(v):0;_capMs=now;}
  else if(!strcmp(n,"NV3HEAD")){_head=v==1;_headMs=(v==0||v==1)?now:-1;}
  else if(!strcmp(n,"NV3POS")){_pos=v==1;_posMs=(v==0||v==1)?now:-1;}
  else if(!strcmp(n,"NV3HOP")){_hopperMask=std::isfinite(v)&&v>=0&&v<=3&&std::floor(v)==v?int(v):-1;_hopMs=_hopperMask>=0?now:-1;}
  else if(!strcmp(n,"NV3REQ")){_request=std::isfinite(v)&&v>=0&&v<=16777215&&std::floor(v)==v?int(v):-1;_requestMs=_request>=0?now:-1;}
  else if(!strcmp(n,"NV3ENV")){
   _environmentStatus=std::isfinite(v)&&v>=1&&v<=4&&std::floor(v)==v?int(v):0;_environmentMs=now;
   if(_environmentStatus!=2){_interiorTempMs=_humidityMs=-1;_interiorTemp=_humidity=qQNaN();}
  }
  else if(!strcmp(n,"NV3ITMP")){_interiorTemp=std::isfinite(v)&&v>=-40&&v<=125?v:qQNaN();_interiorTempMs=now;}
  else if(!strcmp(n,"NV3HUM")){_humidity=std::isfinite(v)&&v>=0&&v<=100?v:qQNaN();_humidityMs=now;}
  else if(!strcmp(n,"NV3TEMP")){_tempC=std::isfinite(v)&&v>-1000?v:qQNaN();_tempMs=now;}
  else if(!strcmp(n,"NV3WSTAT")){
   _waterStandaloneSeen=true;
   _waterStatus=std::isfinite(v)&&v>=1&&v<=5&&std::floor(v)==v?int(v):0;
   _waterStatusMs=_waterStatus?now:-1;
   if(_waterStatus!=2){_standWetMs=_standFaultMs=-1;_standWet=false;_standFault=true;}
  }
  else if(!strcmp(n,"NV3WADC")){
   _waterAdcV=std::isfinite(v)&&v>=0&&v<=3.3?v:qQNaN();
   _waterAdcMs=std::isfinite(_waterAdcV)?now:-1;
  }
  else if(!strcmp(n,"NV3WDET")){
   _waterStandaloneSeen=true;_standWet=v==1.0f;
   _standWetMs=(v==0.0f||v==1.0f)?now:-1;
  }
  else if(!strcmp(n,"NV3WFLT")){
   _waterStandaloneSeen=true;_standFault=v!=0.0f;
   _standFaultMs=(v==0.0f||v==1.0f)?now:-1;
  }
  else if(!strcmp(n,"NV3WATER")){_water=v==1.0f;_waterMs=(v==0.0f||v==1.0f)?now:-1;}
  else if(!strcmp(n,"NV3WFAULT")){_waterFault=v!=0.0f;_faultMs=(v==0.0f||v==1.0f)?now:-1;}
  else return;
 }

 _lastMs=QDateTime::currentMSecsSinceEpoch();emit telemetryChanged();
}
void NavoH743Telemetry::_mavlink(const mavlink_message_t&m){if(!_vehicle || m.sysid!=_vehicle->id() || m.compid!=MAV_COMP_ID_AUTOPILOT1 || m.msgid!=MAVLINK_MSG_ID_NAMED_VALUE_FLOAT)return;mavlink_named_value_float_t p{};mavlink_msg_named_value_float_decode(&m,&p);char n[11]{};memcpy(n,p.name,10);_set(n,p.value);}

