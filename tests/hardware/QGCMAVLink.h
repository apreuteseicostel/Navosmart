#pragma once
#include <cstdint>
// Transport-only fixture: exercise the production QObject/parser with Qt.
constexpr int MAV_COMP_ID_AUTOPILOT1=1;
constexpr int MAVLINK_MSG_ID_NAMED_VALUE_FLOAT=251;
struct mavlink_named_value_float_t { char name[10]{}; float value=0; };
struct mavlink_message_t { int sysid=1,compid=1,msgid=251; mavlink_named_value_float_t payload; };
inline void mavlink_msg_named_value_float_decode(const mavlink_message_t* message,mavlink_named_value_float_t* value){*value=message->payload;}
