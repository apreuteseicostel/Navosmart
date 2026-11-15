#pragma once
#include <cstdint>
// Transport-only fixture: exercise production QObject/parser with Qt.
constexpr int MAV_COMP_ID_AUTOPILOT1=1;
constexpr int MAVLINK_MSG_ID_NAMED_VALUE_FLOAT=251;
constexpr int MAVLINK_MSG_ID_SERVO_OUTPUT_RAW=36;
struct mavlink_named_value_float_t { char name[10]{}; float value=0; };
struct mavlink_servo_output_raw_t {
 uint8_t port=0;
 uint16_t servo1_raw=0,servo2_raw=0,servo3_raw=0,servo4_raw=0;
 uint16_t servo5_raw=0,servo6_raw=0,servo7_raw=0,servo8_raw=0;
 uint16_t servo9_raw=0,servo10_raw=0,servo11_raw=0,servo12_raw=0;
 uint16_t servo13_raw=0,servo14_raw=0,servo15_raw=0,servo16_raw=0;
};
struct mavlink_message_t {
 int sysid=1,compid=1,msgid=251;
 uint8_t len=21;
 mavlink_named_value_float_t payload;
 mavlink_servo_output_raw_t servo_payload;
};
inline void mavlink_msg_named_value_float_decode(const mavlink_message_t* message,mavlink_named_value_float_t* value){*value=message->payload;}
inline void mavlink_msg_servo_output_raw_decode(const mavlink_message_t* message,mavlink_servo_output_raw_t* value){*value=message->servo_payload;}
