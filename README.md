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


## NAVO SMART PRO experimental integration

This branch is isolated from the stable NAVO SMART main branch. Its baseline is
commit 8fc2a448b42d246b568d5453c59114e2f5e4ad08 (Android #651 GREEN).
The ongoing main-branch build #652 is not a validation of this branch.

### KoggerApp upstream (GPL-3.0)
Upstream: https://github.com/koggertech/KoggerApp
Protocol: https://github.com/koggertech/Kogger-Protocol

Candidate upstream modules for evaluation and staged integration:
- src/data_processor/bottom_track_processor.*, bt_worker.*
- src/data_processor/isobaths_processor.*
- src/data_processor/mosaic_processor.*, mosaic_db.*
- src/data_processor/surface_processor.*, surface_mesh.*, surface_tile.*
- src/data_processor/hot_tile_cache.*, compute_worker.*
- qml/scene3d/* and qml/scene2d/* for UI and interaction patterns
- Recording, playback, and export components (dependency audit pending).

Import the upstream files only after tracing their build dependencies, retaining
copyright notices, documenting the exact upstream revision and GPL-3.0 obligations,
and checking compatibility with the distribution model. An upstream module is
not considered integrated until it compiles and passes relevant tests.

### Integration sequence
1. Freeze a known-good Android APK and inspect upstream module dependencies.
2. Add a separately built experimental processing adapter; do not replace the
   current NAVO Kogger decoder or the H743 command dispatcher.
3. Connect CHART/depth/GNSS timestamped samples to bathymetry and tile cache.
4. Integrate isobaths, mosaic and 3D rendering, with feature flags.
5. Add recording, playback and export; benchmark map FPS/memory on G20.
6. Develop independent RT7-inspired features (precision approach, positioning,
   smart scan, geofences, bait patterns and energy monitoring).

Autonomous controls remain disabled until bench and on-water validation.
