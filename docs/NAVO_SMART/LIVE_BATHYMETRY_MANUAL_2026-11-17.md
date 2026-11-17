# NAVO SMART — Live bathymetry in MANUAL/GUIDED (17 Nov 2026)

## Goal

Build the active lake's **2D and 3D bottom map as the boat moves**, from
real georeferenced Kogger CHART bottom samples. No AUTO/Area Scan is required.
This is a software-only, operator-controlled mapping session. The existing
Kogger native Dataset / surface-tile renderer still runs from the same sonar
socket; this patch does **not** create a second decoder or network connection.

This PR is stacked on experimental Kogger B/C PR #118 (itself based on
#101 and incorporating the GPS fixes from #116/#117). Keep as Draft.

## How to use

1. In **My Lakes**, activate the correct lake. The 3D viewer must not attach
   live samples to a different lake.
2. Connect the H743 to QGC and get a healthy >=3 GPS fix with finite valid
   coordinates; connect Kogger and confirm live CHART data.
3. Open **BATIMETRIE 3D**. The top bar shows the sample and grid-cell counts.
   Press **PORNEȘTE**. This records georeferenced samples as the operator
   manually drives, with no RC / waypoint / flight mode commands.
4. Navigate to the map screen and enable the existing **MAP/HD bathymetry**
   layer if desired. The common 2D-cell preview refreshes every 2.5s.
   Existing native Kogger tiles will supersede HD preview where available.
5. Return to **BATIMETRIE 3D**, and use **PAUZĂ**, **REIA**, or
   **OPREȘTE + SALVEAZĂ**. Only explicit resume can restart acquisition
   after lost H743 GPS fix or sonar link.
6. The lake checkpoint is also autosaved every 5s by the existing
   `NavoScanCoordinator`. On stop the current cells and all accepted raw
   samples are checkpointed to the selected lake. Verify successful status;
   if the storage write fails, do not uninstall the app.

## Processing and performance

- Input: existing `NavoSonarEthernet.onGeoSample` native bottom-track
  geosamples and legacy CHART fallback. Both are already validated
  by GPS/MAVLink checks from #118; manual sample ingress additionally
  requires an active lake and the live GPS/sonar flags.
- `NavoSonarMapping` gains `liveMappingActive` and
  `liveMappingPaused`, independent of `scanning` for Area Scan.
  Starting Area Scan while manual mapping is active is blocked.
- Raw samples remain in the existing per-lake sonar archive; active raw
  collection is capped at **25,000** observations. It pauses rather than
  deleting data when full. Previously saved samples are preserved.
- `NavoBathymetryModel` generates 2m grid cells from a bounded, evenly
  spaced representative subset of up to **6,000** stored observations.
  This is a **live preview**, not a complete full-resolution reprocessing
  of all 25,000 readings.
- Rebuild is throttled to **2.5 seconds**, and skips unchanged counts.
  3D geometry already has its own debounce and receives this limited
  snapshot during live scanning. The native Kogger surface still uses
  its independent tile pipeline, not display-filtered raster values.
- `scanCoordinator.bathymetryCells` now updates during scanning and is
  included in existing checkpoints, rather than only at scan completion.
  This also improves autonomous Area Scan previews.
- Source lake/replay switch clears the preview cache and stops manual
  mapping automatically; switching into replay never writes to the live lake.

## Safety limitations

- Visualized map is a **provisional bathymetry**, not a guaranteed safe
  navigation chart. Do not generate shallow-water routing automatically
  from these cells or command H743 to follow contours.
- GPS fix >=3 and host arrival time do not prove RTK accuracy or exact
  ping/GNSS synchronization. Physical transducer offset, sonar speed
  of sound and latency have **not** been calibrated.
- A single track of depth samples measures along-track points; it does
  not create real lateral coverage. Interpolated cells are not
  additional measured observations.
- If the user switches from live to replay unexpectedly, the existing
  lake autosave is the last durable checkpoint. Explicit SAVE before
  switching is preferred.
- No autopilot parameters, RC channels, motor, hopper, relay, HOLD or RTL
  commands are sent by these changes.

## Acceptance

- JS regression: manual start/pause/resume/stop, absent GPS, replay and
  Area Scan separation; capacity; bounded preview; lake guard.
- Qt: load full Batimetrie 3D and controls at phone widths; spot check
  finished/error display.
- Android ARM64 and actual Kogger CHART/replay CI at the exact PR SHA.
- **Bench without propeller:** select a lake; feed Kogger data and moving
  QGC GPS; verify grid cell count and 3D geometry increase; pause freezes;
  link loss auto-pauses and never resumes without explicit REIA.
- **S26 Ultra/G20:** monitor CPU/RAM and FPS while displaying the 2D map
  and 3D scene during manual drive. Compare against native KoggerApp.
- **On-water acceptance:** verify route, echogram, GPS and sounding points;
  compare known water depth to the provisional map before making
  any navigation use of the resulting cells.

## PR coordination

Depends on #118 (Kogger B/C experimental), #117 (one GPS/time per CHART)
and #116 (validated GPS and persistence boundary). These features must
not be independently merged into main without ordering the dependencies
and re-running CI.
