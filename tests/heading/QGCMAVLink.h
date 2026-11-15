#pragma once
#include <cstdint>
constexpr int MAV_COMP_ID_AUTOPILOT1=1;
constexpr int MAVLINK_MSG_ID_GPS_RAW_INT=24;
constexpr int MAVLINK_MSG_ID_GPS2_RAW=124;
constexpr int MAVLINK_MSG_ID_SYS_STATUS=1;
constexpr int MAVLINK_MSG_ID_PARAM_VALUE=22;
constexpr int MAVLINK_MSG_ID_STATUSTEXT=253;
constexpr uint32_t MAV_SYS_STATUS_SENSOR_3D_MAG=4;
struct mavlink_gps_raw_int_t {
 uint8_t fix_type=0,satellites_visible=0;
 uint16_t yaw=0;
 uint32_t h_acc=0;
};
struct mavlink_gps2_raw_t {
 uint8_t fix_type=0,satellites_visible=0;
 uint16_t yaw=0;
};
struct mavlink_sys_status_t {
 uint32_t onboard_control_sensors_present=0;
 uint32_t onboard_control_sensors_enabled=0;
 uint32_t onboard_control_sensors_health=0;
};
struct mavlink_param_value_t { char param_id[16]{}; float param_value=0; };
struct mavlink_statustext_t { uint8_t severity=6; char text[50]{}; };
struct mavlink_message_t {
 int sysid=1,compid=1,msgid=MAVLINK_MSG_ID_GPS_RAW_INT;
 mavlink_gps_raw_int_t gps;
 mavlink_gps2_raw_t gps2;
 mavlink_sys_status_t status;
 mavlink_param_value_t param;
 mavlink_statustext_t text;
};
inline void mavlink_msg_gps_raw_int_decode(const mavlink_message_t*m,mavlink_gps_raw_int_t*v){*v=m->gps;}
inline void mavlink_msg_gps2_raw_decode(const mavlink_message_t*m,mavlink_gps2_raw_t*v){*v=m->gps2;}
inline void mavlink_msg_sys_status_decode(const mavlink_message_t*m,mavlink_sys_status_t*v){*v=m->status;}
inline void mavlink_msg_param_value_decode(const mavlink_message_t*m,mavlink_param_value_t*v){*v=m->param;}
inline void mavlink_msg_statustext_decode(const mavlink_message_t*m,mavlink_statustext_t*v){*v=m->text;}
