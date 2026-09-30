# Kogger sonar / bathymetry / 3D

## Kogger software
Real decoder handles sync 0xBB55, depth message 0x02, temperature 0x05 and CHART 0x03. CHART fragmentation must use seqOffset as fragment position; finalize a column at seqOffset==0 or metadata change and zero-fill missing fragments. Do not interpret sampleResol as fragment position.

Pipeline target: Ethernet bytes -> NavoKoggerDecoder.echoSamples -> NavoFishDetector -> H743 GPS -> georeferenced fish detections/bathymetry -> lake persistence.

## Echogram
Fullscreen echogram maximizes useful area. Putere ecou is a narrow full-height right legend. Sensitivity/noise/filter controls are compact icons/sliders. Fish detection and map fish markers remain linked to real georeferenced sonar samples.

## Bathymetry
HD overlay supports interpolated depth and relative bottom-hardness visualization. Current hardness derived from bottom echo is a relative 0–100-type metric, not a calibrated physical Kogger hardness value; UI should say DURITATE RELATIVĂ and show percent when using this metric.

3D has cached mesh/LOD. If hardness becomes part of 3D geometry/color, cache/sample signatures must include hardness/bottomEcho so metadata changes invalidate the view. Persistence belongs to lake/session state.

## Hardware status
Kogger physical hardware is not yet present/validated. Software may be completed first. Physical Kogger and camera integration are last.
