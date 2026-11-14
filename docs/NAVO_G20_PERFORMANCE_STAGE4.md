# NAVO SMART PRO — Stage 4 G20 performance acceptance

## Changes
The existing Kogger native surface remains source-of-truth. This stage does not
resample soundings, decimate native depth triangles (which would introduce
unknown-water holes), or touch MAVLink/H743 control paths.

- **3D terrain**: QML updates vertices, triangle indices, depth range and
  exaggeration separately. C++ now coalesces those notifications into a single
  Qt event-loop GPU-buffer build.
- **3D track**: unchanged paths and unchanged line width no longer rebuild the
  geometry/Ramer–Douglas–Peucker simplification.
- **3D quality**: FLUID (default) disables MSAA and dynamic shadows, with tighter
  **decorative-only** track/fish LOD; HD restores original high-quality AA and
  shadows. Camera, surface triangles, depths and GPS data remain identical.
- **3D diagnostics**: footer reports the **last geometry CPU build time (ms)**
  and **vertex+index bytes (MiB)**. This is NOT frame rate or total process RAM.
- **2D map**: the native raster reuses screen-projected vertices after pans
  without rewriting all 8,192 vertex coordinates; offset is applied at paint.
  Zoom, map rotation, tilt, resize and large jumps force full reprojection.
  Triangle colours are calculated once per native mesh update and reused.
  Hiding the map drops the projected vertex cache.

## Test protocol: G20 real-device acceptance

Use the **same** saved lake/native Kogger geometry and GPS track in each run.

1. Install a compatible test APK. Keep all recorded lake files intact; back up
   first. Don't merge this experimental branch into stable `main` yet.
2. In the 3D page select native **K3D**, and compare **FLUID** vs **HD** using
   orbit, pinch zoom and repeated top/isometric changes. Repeat at both near
   and far zoom (where decorative LOD changes).
3. Compare batymetry 2D map while panning/rotating/zooming at fixed zoom 17;
   inspect alignment of fishing spots and of depth-contour overlays with the
   raw track. Replay and map split-screen must retain correct latitude/longitude.
4. Collect **actual frame timing and process RAM** from Android. The installed
   package in current NAVO builds is `org.mavlink.qgroundcontrol`; confirm the
   package on your G20 before running:
   ```bash
   adb shell pm list packages | grep qgroundcontrol
   adb shell dumpsys gfxinfo org.mavlink.qgroundcontrol reset
   # Orbit/pan the same lake view for ~30 seconds, then:
   adb shell dumpsys gfxinfo org.mavlink.qgroundcontrol framestats > g20-3d-fluid-framestats.txt
   adb shell dumpsys meminfo org.mavlink.qgroundcontrol > g20-3d-fluid-memory.txt
   ```
   Repeat with the HD profile, and with the baseline #78 APK. If GPU frame
   metrics are not exposed for the Qt renderer, use Android GPU Inspector/
   Perfetto on-device and report that limitation instead of invented FPS.
5. Inspect thermal throttling/long sessions (at least 10 minutes), foreground
   / background recovery, native mesh refresh, live network disconnect, and
   corrupt or missing GPS mesh. When disabled, FLUID/HD must not change any H743
   output, telemetry or actuator state.

### Pass criteria

- No visual offset, holes or triangles spanning unscanned lake regions.
- No increase in lost raw CHART/Epoch data; recordings and replay remain equal.
- Crash-free switch between FLUID and HD (and K3D and sample-based mode).
- Compare **measured** median/p95 frame time, janky-frame share, memory and
  battery behaviour, rather than declaring an FPS improvement from unit tests.
- Roll back any graphics optimisation that worsens frame pacing or map accuracy.

## Stacked development

Stage 4 branch is **based on PR #78** and targets its branch in a separate
draft PR. PR #78 itself builds from stable main. Stage 1 #76 and Stage 2 #77
remain independent; integrate only after dependency order and CI/hardware
checks are satisfied.
