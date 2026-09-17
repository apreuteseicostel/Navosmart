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


## V1.1 roadmap — functions benchmarked from 2025–2026 smart bait boats

Priority features selected for NAVO SMART:
- Area Scan: rectangular zig-zag survey with configurable lane spacing and mission ETA.
- Sonar + GPS synchronized recording; replay scan history and create a waypoint from any interesting sonar position.
- Bathymetric map generation with depth contours / optional 3D bottom view.
- Digital Anchor: GPS position hold for stationary sonar/bait placement.
- Action Groups: reusable sequences such as GoTo -> Hold -> hopper action -> lateral exit -> RTL.
- Per-waypoint actions: left/right/both hopper, wait time, speed, sonar snapshot, auto-return.
- Mission repeat: save and repeat a successful baiting/scanning mission.
- Offline maps and local session storage; cloud sync can remain optional.
- Voice/audio feedback for arrival, bait released, low battery, GPS/link warnings and RTL.
- Range/battery failsafes with onboard ArduPilot as authority; app visualizes and configures rather than replacing onboard safety.
- Mission energy/range estimate before launch and low-battery auto-return threshold.
- Fishing log metadata on spots: bait/rig/note/depth/temp/time and later catch history.

Implementation rule: UI controls remain disabled or explicitly marked unconfigured until their real backend/hardware path is implemented and validated.
