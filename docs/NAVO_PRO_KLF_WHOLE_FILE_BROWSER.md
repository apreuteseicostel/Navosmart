# NAVO Sonar PRO — whole-file KLF visual browsing

## Why this differs from the previous seek slider
PR #84 indexes the complete KLF file but its slider calls `seekReplayColumn`, resets the decoder/Dataset, then displays only **newly played** columns. This is not the Kogger-style workflow: moving backward should reveal recorded echoes immediately even with playback stopped or at EOF.

## Implementation
- `NavoKoggerReplay::readDisplaySlice` accesses the original **full physical CHART index** in a second read-only QFile. It does not seek or reset the live playback QFile, decoder, GPS state, annotation state, or the Kogger Dataset.
- Source CHART frames are passed through the same `FrameParser` and `NavoKoggerDecoder` as playback. Each displayed pixel holds its original indexed column number, source resolution and source bytes; no synthetic echo is created.
- A bounded 24 MiB / 4096-entry cache reuses decoded columns while scrolling in either direction. The Qt Quick native item loads 32 screen columns per event-loop turn and coalesces slider movement.
- **TOATĂ**: an overview of the entire file sampled horizontally to the screen width; this is a visual summary, not loss of data in the source. **DETALIU**: source-column window at screen width. Direct touch drag and slider inspect independent of playback.
- `▶ DE AICI` explicitly seeks/restarts playback from the selected column. Browsing itself does **not** change playback location.
- Existing 256-level native raster, depth scale, settings, and live control remain separate from file browsing. This applies to indexed local `.klf`; `.navosonar` still uses the existing chunk replay protocol.

## Verification / acceptance
- Index original `00028_DownView.klf`. Check overview spans start to end and moving the viewport from last to first with playback paused.
- Compare actual CHART byte amplitudes between the direct browse viewport and decoder playback at selected global source indices.
- Verify playback byte offset/GPS and annotations unchanged during browse. Check EOF then backwards, and button `▶ DE AICI`.
- Confirm Android ARM64 build, frame UI responsiveness and memory on G20 before merge.

## Caveats
- This is **on-demand full-file browsing**, not keeping every 2D raster image or raw CHART column in RAM. The file stays on disk, is fully indexed, and all columns remain available through the viewer.
- Overview subsamples the horizontal axis; use DETALIU for the uncompressed columns.
- This does not replace Kogger's entire Plot2D subsystem or add features beyond the KLF display. Source KoggerApp algorithms are GPL-3.0 and their attribution is retained.
