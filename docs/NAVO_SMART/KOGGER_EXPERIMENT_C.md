# Experiment C — Kogger rendering and controls inside SONAR PRO

## Comparison baseline
- Built from the same PR #89 file viewer as experiment B.
- Uses the **existing SONAR PRO** menu, no separate KOGGER SONAR page.
- Draft PR #91 targets main only for Android ARM64 CI; do not merge.

## Implemented
- Runtime toggle in Sonar PRO: Kogger original C mode (default ON only on this branch).
- Native KoggerApp `Epoch::chartTo` column-raster algorithm faithfully ported to `NavoKoggerOriginalRaster.h` (GPLv3 attribution), including average/interpolate split and optional source amplitude compensation.
- AIM touch gestures inspect a column without changing playback. PAN touch gestures move the viewport when zoomed.
- Original-style toolbar for RAW/COMP, Classic/Ice/Sepia, depth window and Epoch.
- Existing NAVO decoder, file index, raw-column source, QGroundControl and boat H743 command handling remain unchanged.

## Limitations
- This is a focused **upstream algorithm port**, not yet direct full-linking of KoggerApp's `Plot2D`, `qPlot2D`, 3D and global `Core`.
- Kogger CHART v1 semantics are not verified for the original upstream v0 sampler; v1 falls back to NAVO's existing sampling. No payloads are rewritten.
- Whole-file view still samples representative columns horizontally. Test GPU/CPU time on G20.

## On-device acceptance
1. Install C APK, open SONAR PRO, confirm Kogger original C mode is active.
2. Open same `00028_DownView.klf` on C and original KoggerApp 1.0.3.
3. Match palette, contrast window, RAW vs COMP and 5/10/20/50 m scale.
4. Drag in AIM mode: inspect Epoch but do not shift picture. Drag in PAN mode at 8x: move picture but not playback cursor.
5. Toggle C OFF: renderer falls back to original NAVO behaviour.
6. Compare FPS/memory, scan and replay fluidity on G20 and S26.

## Legal
Keep original GPL-3.0 attribution and provide source as required before any redistribution.
