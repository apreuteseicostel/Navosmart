# NAVO SMART

Custom Android ground-control application for Costel's bait boat, based on QGroundControl custom-build architecture.

## V0.1 target
- Romanian-first boat interface
- ArduPilot Rover/Boat
- Matek H743-WING V3
- UM982 dual-GNSS position + heading
- Map, HOME, waypoints and route
- MANUAL / AUTO / RTL controls
- Battery, speed, distance, GPS/heading status
- Kogger Sonar 2D Basic integration layer (protocol adapter to be implemented after protocol validation)

## Architecture
The `custom/` directory is designed as a QGroundControl custom overlay. Upstream QGroundControl remains the base application so MAVLink, ArduPilot, mission planning and telemetry are not reimplemented.

## Safety
V0.1 is development software. Autonomous commands must be bench-tested and then water-tested at low speed before normal use.
