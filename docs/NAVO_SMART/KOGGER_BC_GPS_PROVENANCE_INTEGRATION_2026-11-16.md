# NAVO SMART — Kogger B/C GPS provenance integration (16 Nov 2026)

Status: **experimental software-only patch** based on the KOGGER/PRO UI draft #101.
This patch also ports targeted georeference validation and CHART receive-time
snapshot changes from draft #116/#117. None of these are merged into `main`.

## Existing integrations respected

- KOGGER B V2: `NavoKoggerSonar.qml` and one native
  `NavoKoggerEpochPlotItem` (Epoch::chartTo 256-colour raster).
- NAVO PRO C: existing Sonar PRO with selectable native Kogger renderer and
  legacy display, live map, GPS historical route, inspector, recordings, replay.
- PiP: shares the existing decoder and Kogger Dataset via
  `NavoSonarEthernet.qml`. No new socket, Dataset, timer or renderer instance.

## Fixes

1. `NavoSonarEthernet.qml` now has a single `liveGpsReady()` check:
   3D-fix-or-better, valid numeric latitude and longitude, active QGC link,
   not replay; results are exposed read-only as `liveGpsUsable`.
   The raw recording path, native Kogger position source and legacy
   CHART geosample all respect the same validity check. The branch's
   CHART v0/v1 native-handling gate remains unchanged.
2. `NavoSonarPro.qml` takes one `columnGpsSnapshot()` and
   `Date.now()` **per real CHART event** and gives those fields to
   `captureGeoChart()` and `pushHistoryWithSnapshot()`. The inspector/
   point-picker uses the historical column's captured position rather than
   the boat's later live position. Existing zero-argument `pushHistory()`
   is preserved for Qt's QMetaObject/UI tests.
3. A compensation toggle and opening a live Sonar PRO view do not
   fabricate another GPS-stamped CHART frame. History and associated raw
   metadata are cleared on replay-mode/source/lake switch.
4. Numeric WGS84 bounds and strictly positive depth are enforced in the
   bathymetry ingress and the C++ persistent sonar archive. Missing/null,
   string or boolean coordinates never become a false point at (0,0).
   Actual numeric (0,0) is still allowed.
5. Both full-screen KOGGER B and NAVO PRO C show passive `GPS FIX` vs
   `GPS —` when live CHART is being received. This indicates usable H743
   position only, **not GPS confirmation per displayed ping**.

## Provenance and limitations

- `Date.now()` is the host/phone CHART reception time, **not** the Kogger
  transducer ping's source clock. No exact sonar/GNSS time synchronization,
  correction latency measurement or transducer lever-arm compensation.
- The B native renderer indexes actual Kogger epochs independently; its
  recorded KLF GPS history must remain separate from current H743 GPS.
- An H743 fix >=3 alone does not prove RTK accuracy or up-to-date
  position in seconds. We fail closed on lost link but cannot estimate
  actual receiver age from the shared QGC coordinate property alone.
- This does not claim pixel-for-pixel parity with full KoggerApp.
- No ArduPilot settings or commands are changed: no motors, servo actions,
  RC mappings, hopper opening, RTL or flight modes.

## CI and device acceptance

- Node/JS: `tests/audit-regressions.mjs`, incl. receive snapshots with
  moving H743 GPS, malformed inputs, replay and lost-link behavior.
- Qt/C++: `tests/persistence/persistence.cpp` with null, nonnumeric,
  NaN/Inf, bounds and true numeric zero.
- Sonar display/performance, recorded Kogger CHART replay, NAVO V3 UI and
  Android ARM64 must pass on the exact PR head.
- Hardware bench (propeller removed): compare Kogger B and NAVO PRO C with
  GPS fix/reconnect/replay, and disable/re-enable compensation in both.
  Inspect whether the map drops invalid positions without hiding sonar.
- On S26 Ultra and G20: compare live fluency, memory/fps, B/C gestures,
  zoom, timeline and PiP overlap; verify saved spots correspond to their
  original column rather than the boat's later position.
- Real water: compare stored GNSS track against independently measured
  points and evaluate network / ping age before claiming precise 3D maps.

## Review ordering

#101 is the upstream experimental base. This branch integrates the
compatible parts of #116 and #117, so review all three for duplicates and
overlaps before any eventual merge. Never merge the broad #101 stack without
separate Android and physical sonar acceptance.
