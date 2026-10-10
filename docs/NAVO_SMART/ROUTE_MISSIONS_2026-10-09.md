# Ordered mission routes — 9 October 2026

The Baiting page now exposes a compact route icon. The editor adds selected map
or saved points in order, with no release / left / right / both actions, reorder
and remove controls, and RTL / digital anchor / HOLD at the final position.
The map draws the stop sequence and allows independent visibility of actual
track, planned route/Area Scan, sonar markers and HD bathymetry.

## Behaviour

- The dashboard owns the route model outside page Loaders. Each stop uses the
  existing GUIDED baiting controller, including slow approach, stationary
  release guards, Nano fallback and lateral exit after a bait command.
  Navigation-only stops do not perform the lateral exit.
- A route is limited to 50 stops. A physical hopper may release once per run;
  repeated delivery from the same load is refused. START/repeat requires an
  explicit load confirmation if any stop uses a hopper.
- Travel estimates include slow/final approach, dwell and lateral exit. Energy
  distance always includes return HOME, including HOLD/anchor runs. Estimates
  omit variable acceleration, wind, turn and prolonged settling effects, so
  the UI labels them as estimates. Calibration remains opt-in and requires
  actual boat measurements. Existing battery/GPS/HOME pre-launch gates apply.
- Starting requires an active lake and successful checkpoint. Route definitions
  and the last 50 run summaries are stored in its existing atomic snapshot.
  Restore produces a draft, never a running mission. Edited routes checkpoint
  immediately; replay blocks editing/starting and live route checkpoints.
- STOP/HOLD/RTL cancel the route and invalidate queued next-stop callbacks.
  Manual pilot mode changes cancel baiting without sending HOLD over MANUAL.
  GPS/link loss, changed autopilot and failed servo command results stop the
  operation. A disconnected phone cannot drive the remaining GUIDED sequence;
  H743 onboard failsafes still need physical configuration and acceptance.
- The map's separate waypoint navigation cannot override an active route.
  Manual hopper controls and concurrent Area Scan starts are blocked.
- A run labelled `DISPATCHED` means stop actions were commanded. Neither servo
  ACKs nor timers prove actual bait release, closed hoppers or arrival HOME.
  Final anchoring uses the current final position, after the configured lateral
  exit if the last stop released bait. A physical confirmation remains separate.

## Validation

- `node tests/audit-regressions.mjs`: 51 scenarios.
- `node tests/route-plan.mjs`: 13 scenarios, including queued cancellation,
  replay isolation, per-lake snapshots, energy/pre-launch/save failures,
  repeated load confirmation, manual override and rejected/timeout servo results.
- `node tests/g20-input.mjs`: 7 scenarios.
- Qt 6.8.3 qmlformat parses all 55 production QML files.
- `python tests/route-ui.py` with PySide6 6.8.3: real Qt sequencing, restore as
  draft, production editor renders at 320/480/900 widths, and the actual
  Baiting route popup opens at 320x600 without QML warnings. Explicit test
  vehicle/settings fixtures; this is not installed Android or hardware evidence.
- Route regressions are included in both Android and core CI workflows.

Android current-head build/emulator acceptance and G20/H743/servo boat tests
remain required. This change does not implement cloud sync, Deeper protocol
integration, raw KLF recording/export or a complete native offline tile archive.
Existing per-lake sonar samples/bathymetry snapshots and new route history are
local; full session recording/archive remains separate work.
