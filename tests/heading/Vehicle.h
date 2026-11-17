#pragma once
#include <QObject>
#include "QGCMAVLink.h"
#include "ParameterManager.h"
class Vehicle:public QObject {
 Q_OBJECT
public:
 int id()const{return 1;}
 ParameterManager* parameterManager(){return &_parameters;}
 void send(const mavlink_message_t &message){emit mavlinkMessageReceived(message);}
private:
 ParameterManager _parameters;
signals:
 void mavlinkMessageReceived(const mavlink_message_t &message);
};
