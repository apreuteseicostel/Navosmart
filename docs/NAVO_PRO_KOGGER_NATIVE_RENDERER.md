# NAVO SMART PRO — Native Kogger Sonar Engine, integration stage 1

## Purpose

Replace the *visible* four-band Sonar PRO Canvas with a native Qt Quick
renderer based on the original KoggerApp image algorithm and palettes.
Keep NAVO's current navigation/H743/RC architecture independent.

Source and attribution: KoggerApp under GPL-3.0,
- `src/scene2d/plot2D_echogram.cpp`: 256-colour indexed image,
  original Classic/Ice/SepiaNew interpolation stops and percentage remapping;
- `src/epoch.h` `Epoch::chartTo`: pixel sampling, averaging when reducing
  the vertical resolution and interpolation when magnifying.
Original library license: `third_party/KoggerApp/LICENSE`.

This stage **adapts** the two isolated original Kogger algorithms instead of
linking all 20+ `Plot2D` layers into QGroundControl. It is not yet the
entire original KoggerApp user interface.

## Implemented

1. `NavoKoggerEchogramItem`: QQuickPaintedItem producing
   `QImage::Format_Indexed8` at physical screen resolution; 256 colours,
   no 4-bin quantisation, no per-sample QML `fillRect`.
2. Receives complete CHART bytes by connecting directly to the existing
   `NavoKoggerDecoder::chartColumnReady` C++ signal. QML never serializes the
   amplitude array to draw the native renderer.
3. GPU refresh/coalescing: 33-ms maximum redraw rate. Retains a bounded
   4096-column / 24MiB raw ring for recent screen inspection and live/recorded data;
   snapshots protected by QMutex. The original replay file is *not* truncated.
4. Menu switch: **Kogger nativ 256 niveluri** (default), legacy NAVO Canvas
   (fallback). RAW/AUTO/FIX depth controls from #81 work on the native view.
5. Tap the native plot to inspect *that CHART column*: physical cursor depth,
   raw echo percentage, source depth offset, sample resolution, bottom-depth
   metadata when valid. No guessed fish identifications.
6. Recorded replay start/stop, switching lake and stale native bottom records
   invalidate the image cache. No hardware commands, MAVLink changes or
   GPS/boat control routes added.
7. CI: native palette/sampling/Qt painter test, QML wiring tests, full
   Kogger recorded replay, QML screenshot fixture with explicit old-Canvas
   baseline, Android arm64 build.

## Still required for full Kogger-equivalent experience

- Full `.klf` column index for arbitrary positioning; a 4096-column ring is
  a *screen cache*, not a whole-file seek index.
- A full-file slider, pause/seek/zoom/speed, stable replay geometry and
  annotations anchored to exact epoch rather than only recent columns.
- Advanced native Kogger compensation/TGC and original full palette/theme
  list; today's native view uses the existing NAVO gain and noise floor.
- Pixel-for-pixel comparison with KoggerApp on the same sample, scale, theme,
  compensation and calibration, and actual G20 FPS/RAM measurements.
- Kogger’s full `Plot2D` class also owns map, contacts, navigation layers,
  touch events and Core services; do **not** copy it into the boat control
  UI without a dependency/license/resource review.

## Safety and integration

This branch is stacked on #81 (which contains #76–#80). Draft only.
The navigation/control stack stays on QGC/H743. Bench-test the sonar APK
with `00028_DownView.klf` and verify old/new renderer toggle before merge.
Do not claim equality to commercial KoggerApp performance until measured.
