#pragma once
#include <QObject>
#include "QGCMAVLink.h"
class Vehicle:public QObject {
 Q_OBJECT
public:
 int id()const{return 1;}
 void send(const mavlink_message_t& message){emit mavlinkMessageReceived(message);}
signals:
 void mavlinkMessageReceived(const mavlink_message_t& message);
};
