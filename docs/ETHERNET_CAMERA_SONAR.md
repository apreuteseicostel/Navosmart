# NAVO SMART — Ethernet Camera + Sonar Infrastructure

Status: staged for next main build. This branch does not trigger the Android main workflow.

## Network topology
G20/NAVO SMART <-> Ethernet link <-> embedded 10/100 switch
- Port A: camera/video endpoint
- Port B: Kogger Sonar 2D Basic transport endpoint
- Port C/uplink: NAVO SMART/G20 network path

## Software boundaries
1. EthernetTransport
   - configurable IPv4 host/port
   - TCP/UDP transport selection
   - connect/disconnect/reconnect state
   - receive buffer, timeout and error reporting
   - no assumed Kogger packet format

2. SonarTransport
   - consumes raw Ethernet bytes/datagrams
   - timestamp each receive block
   - forwards raw frames to KoggerDecoder
   - exposes connection/data-rate status

3. KoggerDecoder
   - protocol adapter boundary only until verified protocol captures/docs are available
   - must never invent packet framing, checksum, scaling or units
   - output model: timestamp, depth, echo samples, optional temperature/quality fields when verified

4. SonarGeoSample
   - pairs decoded sonar sample with current H743/UM982 navigation state
   - fields: monotonic timestamp, UTC timestamp when available, latitude, longitude, heading, depth, quality
   - feeds echogram recording and future bathymetry/Area Scan

5. CameraTransport
   - independent endpoint from sonar
   - stream URL/host/port configurable
   - video decoder/backend chosen only after actual camera stream protocol is confirmed
   - reconnect/status interface shared with NAVO SMART UI

## UI contract
- Camera view is on-demand, not permanently occupying the main boat screen.
- Sonar panel exposes connection state, live depth and echogram.
- Main screen keeps only compact camera/sonar status indicators.
- No duplicate battery widget and no permanent hopper-control clutter.

## Integration order for next green build
1. Add common Ethernet connection settings/state.
2. Add SonarTransport + KoggerDecoder interface and test fixtures.
3. Add live echogram data model/rendering path.
4. Add GNSS/depth recording model for bathymetry.
5. Add camera transport/view shell.
6. Add waypoint persistence + Area Scan hooks without coupling them to unverified sonar protocol details.

## Validation gates
- CI/emulator: build, install, launch, UI navigation, settings persistence.
- Recorded-data tests: parser/decoder only after real Kogger captures or authoritative protocol data.
- Hardware validation: only after G20, Ethernet modules, camera and Kogger are physically connected.
