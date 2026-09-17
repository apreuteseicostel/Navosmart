# NAVO SMART auxiliary-board telemetry protocol v1

Transport: UART, newline-delimited ASCII. Initial bench target: 115200 8N1.
Physical voltage levels MUST be verified before connecting the auxiliary MCU to a Matek H743 UART.

Board -> H743 frames:
NAVO,1,WATER=0,BTEMP=31.4,BOARDTEMP=33.0,LIGHT=1,HOPL=0,HOPR=0

H743/app acknowledgement/config frames can be added later. Unknown keys must be ignored for forward compatibility.

Safety ownership:
- Auxiliary board detects/debounces sensors and transmits state.
- H743/ArduPilot is the authority for vehicle HOLD/RTL/failsafe.
- NAVO SMART displays, logs, announces and can request actions, but Android is not the only safety layer.
- Water alarm means hull/electronics compartment sensor, not normal water associated with a bait hopper.
- Never issue RTL without valid position and HOME; request HOLD if position is invalid.
