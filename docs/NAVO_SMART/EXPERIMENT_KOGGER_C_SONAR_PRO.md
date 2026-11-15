# Experiment C — upstream Kogger rendering and UI inside Sonar PRO

Status: **scoping only — not yet implemented or Android tested**.

## Goal
Replace only the Sonar PRO *display engine and echogram interaction* with Kogger upstream `Plot2D`/`Plot2DEchogram`/`qPlot2D` behavior, preserving NAVO Sonar PRO navigation, map, mission, point-saving, transport, telemetry and layout.

## Architecture
- Source: existing `NavoSonarEthernet` live connection or `NavoKoggerReplay` KLF file.
- Adapter: existing `NavoKoggerDatasetAdapter` and `NavoKoggerService` shared `Dataset/Epoch`.
- View: original `Plot2D`/echogram engine behind a dedicated QQuickItem adapter; import only needed original QML controls from `qml/scene2d/Plot2D.qml`.
- All NAVO/QGC controls remain under NAVO. Do not initialize Kogger's global `Core` or its separate Android entry point.
- Preserve independent horizontal pan, whole-file index and seek, zoom, vertical auto/manual depth window, palette and inspector. Rendering must not be limited to the most recently replayed 4096 columns.

## Compatibility
NAVO currently builds Qt 6.8.3 arm64 and upstream KoggerApp declares Qt >=6.8, C++23 and Android support. Verify QGC target C++ standard and link closure before including native `scene2d` sources. Existing modified `Dataset/Epoch` must remain the only compiled definitions.

## Test plan
1. Compare Kogger and NAVO on the **same** KLF and same epoch.
2. Capture pixel and depth alignment at 1x/8x and vertical scales 5m/20m.
3. Scrub entire file forward/back without black gaps introduced by missing cache.
4. Ensure live sonar, GPS, bottom-depth and map synchronization still work.
5. Benchmark frame time, heap usage and latency on G20/S26 Ultra.
6. Run CI Android build and real hardware checks before merge.

## Parallel development
This branch is independent of Experiment B and does not depend on it. Existing PR #89 remains separate; cherry-pick or reconcile its whole-file viewport changes only after upstream renderer compatibility is established.

## Safety
Do not alter H743/MAVLink commands or merge experimental rendering into main without acceptance results. Preserve GPLv3 copyright notices and source availability requirements.
