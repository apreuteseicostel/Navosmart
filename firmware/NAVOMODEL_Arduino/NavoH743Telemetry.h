#pragma once
#include <Arduino.h>

struct NavoTelemetryState {
  uint32_t battery_mV;
  int16_t temp_c10;
  bool water;
  bool waterFault;
  bool headlight;
  bool position;
  uint16_t hopperLeftUs;
  uint16_t hopperRightUs;
  uint16_t rudderUs;
  uint8_t alarmMask;
};

class NavoH743Telemetry {
public:
  explicit NavoH743Telemetry(Stream& serial) : _serial(serial) {}

  void send(const NavoTelemetryState& s, uint32_t uptimeMs) {
    char payload[150];
    snprintf(payload, sizeof(payload),
      "NAVO,1,%lu,%lu,%d,%u,%u,%u,%u,%u,%u,%u,%u",
      (unsigned long)uptimeMs,
      (unsigned long)s.battery_mV,
      (int)s.temp_c10,
      s.water ? 1 : 0,
      s.waterFault ? 1 : 0,
      s.headlight ? 1 : 0,
      s.position ? 1 : 0,
      (unsigned)s.hopperLeftUs,
      (unsigned)s.hopperRightUs,
      (unsigned)s.rudderUs,
      (unsigned)s.alarmMask);

    uint8_t cs = 0;
    for (const char* p = payload; *p; ++p) cs ^= (uint8_t)*p;

    _serial.print('$');
    _serial.print(payload);
    _serial.print('*');
    if (cs < 0x10) _serial.print('0');
    _serial.print(cs, HEX);
    _serial.print("\r\n");
  }

private:
  Stream& _serial;
};
