# NAVOMODEL Nano ↔ Matek H743 telemetry

Target: Arduino Nano / ATmega328P 5 V on NAVOMODEL Rev.D.

## Physical link
- Nano D1/TX -> 1 kΩ series resistor -> Matek H743-WING V3 RX4
- Nano D0/RX <- Matek H743-WING V3 TX4
- GND <-> GND
- H743 UART4 maps to ArduPilot SERIAL6 and is documented as 5 V tolerant.
- Do not use UART7/TELEM1 for a direct 5 V Nano TX connection.

## Serial settings
Initial integration: 57600 baud, 8N1.

The Nano emits one ASCII status frame every 500 ms:
`$NAVO,1,uptime_ms,battery_mV,temp_c10,water,water_fault,headlight,position,hopper_l,hopper_r,rudder,alarm*CS\r\n`

- `temp_c10`: temperature in tenths of °C; use -32768 for unavailable/fault.
- boolean fields: 0/1.
- servo fields: last measured pulse width in microseconds; 0 means stale/unavailable.
- `alarm`: bitmask (bit0 water, bit1 water-sensor fault, bit2 battery low, bit3 temperature).
- `CS`: two-digit uppercase XOR checksum over characters between `$` and `*`.

This is deliberately a small transport protocol. Conversion into MAVLink/NAVO SMART belongs on the H743/companion side rather than making the Nano pretend to be an autopilot.

## Safety
Telemetry must never block light control, water detection, alarms, servo monitoring, or propulsion/autopilot paths. The Rev.D PCB is auxiliary and does not carry propulsion current.

## Integration status
The existing Rev.D design reserves Nano D0/D1 for serial. The original Rev.D firmware is described in the engineering package but its source file is not currently exposed as a standalone File Library object, so this GitHub branch adds the H743 transport as an isolated module first. Merge it into the exact Rev.D `main.c` only after that source is available, preserving its tested pin map and safety logic.
