# Experiment B — independent KOGGER SONAR workspace

## Comparison baseline
- Built from the same PR #89 Sonar PRO file viewer as experiment C.
- Separate sidebar entry: **KOGGER SONAR** (page 15).
- Original **SONAR PRO** source intentionally not modified.
- Draft PR #90 targets main only to trigger the normal Android ARM64 CI; do not merge.

## Implemented
- Independent `NavoKoggerReplay`, `NavoKoggerDecoder`, `NavoEthernetTransport` and `NavoKoggerEchogramItem`.
- View full KLF index, scroll/pan/zoom, palette, depth window and inspect Epoch.
- Doesn't touch `NavoSonarEthernet`, vehicle commands, missions or shared boat telemetry.
- Live connection button disabled when NAVO's existing live sonar is connected, to avoid competing sessions.

## Not yet implemented
- Upstream KoggerApp `Core`, its original `qPlot2D`, full `Plot2D.qml`, second QML runtime and all settings. This is a *standalone integration prototype*, not a full KoggerApp port.
- Full video/GPS/3D feature equivalence is not claimed.

## On-device acceptance
1. Install *B* APK independently and open KOGGER SONAR from NAVO menu.
2. Open the same `00028_DownView.klf` on G20 and S26 as in original KoggerApp 1.0.3.
3. Compare total Epoch count, slider, texture/palette, depth and touch movement.
4. Close B, reopen SONAR PRO; confirm it remains unchanged, including SAVED lakes and telemetry.
5. Validate memory and frame latency with instrumented logs. Do not enable navigation from this prototype.

## Legal
KoggerApp original is GPL-3.0; upstream copyright and source availability obligations must be verified before distribution.
