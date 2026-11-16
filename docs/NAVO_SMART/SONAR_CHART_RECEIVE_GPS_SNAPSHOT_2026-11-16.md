# NAVO SMART — CHART receive-event GPS snapshot
Date: 16 Nov 2026. Stacked on Draft #116 (sonar georeferencing input validation).

## Problem verified in actual main source

`NavoSonarPro.qml` calls `captureGeoChart()` and `pushHistory()`
separately for each completed CHART column; both previously read
`vehicle.coordinate` and `Date.now()` independently. A UI-only switch of
Kogger compensation also cleared history and called `pushHistory()`
without an incoming CHART, which could silently attach the **boat's current
GPS/time** to an older echo column.

The B/C experimental renderers remain separate Draft PRs; this fix targets
the shared main Sonar PRO ingestion path, not a complete native KoggerApp port.

## Change

- `onChartColumnReceived()` is called **only** from real
  `chartSource.echoSamplesChanged`. It captures **one host receive time**
  and one `columnGpsSnapshot()`, then supplies the same objects to
  `captureGeoChart()` (native raw metadata) and `pushHistory()`
  (on-screen waterfall/point-picker history).
- Require 3D fix, QGC link healthy and finite numeric WGS84 coordinates.
  If the source has the newer `liveGpsReady()` API from #116, honor it too.
  In replay, never substitute current boat GPS.
- Preserve the original GPS/time for each completed column even if the
  boat moves before the user selects a historical CHART.
- Compensation switch still starts a new display-history segment because
  old columns cannot be retroactively reprocessed from the newest
  compensation buffer; **it no longer synthesizes a new CHART column**.
  Next real incoming frame repopulates the display.
- Clear the in-memory associated raw CHART records when the selected lake,
  replay mode or sonar source changes; no cross-lake positions.
- No direct H743 or GNSS commands.

## Test scenarios

1. Synthetic CHART sequence 41 at GPS (52,-1) receive time 1000:
   both history and raw metadata use exactly these fields.
2. Sequence 42 received at (53,-2), time 1200: previous column retains
   original position/time; second matches its new position.
3. GPS fix drop, shared live fix gate refusal, MAVLink lost and replay:
   display still receives raw CHART but does not invent mapped GPS.
4. UI-only compensation toggle no longer invokes `pushHistory()`.
5. Underlying #116: invalid persisted coordinates do not create 0,0 points.

## Limitations and acceptance

This is **receive-time co-sampling**, not true GNSS–sonar device timestamp
synchronization. QGC coordinate may lag the actual ping because of
network/decoder latency. Do not imply centimeter accuracy, transducer
offset compensation or deterministic RTK age from this code.

- CI: `node tests/audit-regressions.mjs`, NAVO V3, Qt screen tests,
  Kogger CHART replay, sonar display/performance, Android ARM64 at exact
  PR head.
- Bench (boat disarmed) record rapid GPS changes, stopped GNSS, MAVLink
  loss, active lake switches and Kogger compensation toggle.
- On G20/S26 verify smoothness, memory, B/C native renderer interaction
  and timestamp/position consistency.
- Keep Draft until #116 is accepted; its GPS guard is an explicit dependency.
  The large B/C UI PRs #92/#93/#98/#99/#101 must be reconciled carefully
  when integrated, not silently cherry-picked into this branch.
