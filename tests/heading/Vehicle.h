#pragma once
#include <QObject>
#include "QGCMAVLink.h"
#include "ParameterManager.h"
class Vehicle:public QObject {
 Q_OBJECT
public:
 int id()const{return 1;}
 ParameterManager* parameterManager(){return &_params;}
 const ParameterManager* parameterManager()const{return &_params;}
 void send(const mavlink_message_t &message){emit mavlinkMessageReceived(message);}
signals:
 void mavlinkMessageReceived(const mavlink_message_t &message);
private:
 ParameterManager _params;
};
