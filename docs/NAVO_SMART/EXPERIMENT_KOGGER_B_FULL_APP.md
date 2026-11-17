# Experiment B — isolated KoggerApp experience inside NAVO

Status: **scoping only — not yet implemented or Android tested**.

## Goal
Provide a separate **Kogger Sonar** navigation entry and screen while leaving **Sonar PRO** unchanged. The Kogger-native view should use original upstream 2D user interaction and file playback rather than NAVO's custom echogram.

## Boundaries
- Never replace the QGroundControl application entry point, Android activity, main QQmlApplicationEngine or H743 MAVLink authority.
- Port the Kogger 2D application *experience* as a self-contained Qt Quick screen hosted by NAVO. The upstream KoggerApp `Core`, `main.cpp`, singleton context properties, and renderer globals require adapters.
- Preserve original Kogger navigation: whole-file overview, horizontal pan/zoom, vertical depth scale, palette/levels, epoch cursor, file replay and live display.
- Reuse exactly one existing NAVO TCP/UDP/file transport; avoid duplicate device ownership.
- Keep Sonar PRO and existing Kogger decoder paths untouched. New entry must be feature gated until real native renderer builds.

## Upstream dependency graph (verified)
`qml/scene2d/Plot2D.qml` -> `WaterFall/qPlot2D` -> `Plot2D` -> `Plot2DEchogram` -> `Dataset/Epoch`, with `Core`, `Themes`, `DataProcessor`, additional plot layers and QML imports.

NAVO already compiles a modified Kogger `Dataset/Epoch` and several processing modules in `custom/kogger_native`. Do **not** link upstream copies of the same C++ classes a second time. Resolve symbol and ABI conflicts through a single dataset implementation.

## Acceptance
1. Separate Kogger Sonar menu opens independently of Sonar PRO and closes cleanly.
2. Same KLF file renders and scrubs backward/forward in KoggerApp and NAVO.
3. Compare same epoch, depth window, palette, amplitude levels and screen density.
4. Confirm no conflicts with camera, map, QGC vehicle control, or sonar connection.
5. Android arm64 build passes; memory and FPS measured on G20 and S26 Ultra.
6. Document GPL-3.0 source obligations before distributing combined APK.

## Excluded
No changes to boat commands, mission control, Sonar PRO rendering or default app startup.
