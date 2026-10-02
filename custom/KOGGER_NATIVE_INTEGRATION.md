# Kogger native integration: build gates

Upstream source: third_party/KoggerApp, GPL-3.0. The NAVO adapter is
custom/src/NavoKoggerDatasetAdapter.h. It is NOT linked into the Android
application yet; the existing sonar display path must remain functional.

## Verified dependency blockers

- third_party/KoggerApp/src/epoch.cpp includes `core.h`.
- third_party/KoggerApp/src/dataset.cpp includes `core.h`.
- `core.h` is not present in the imported third_party/KoggerApp/src tree.
- `data_processor.cpp` requires QtConcurrent and additional upstream
  application/worker/scene dependencies.
- `dataset.h` includes black_stripes_processor.h,
  data_interpolator.h, epoch.h, id_binnary.h and dataset_defs.h.
- Upstream CMake expects a complete target named KoggerApp, not the NAVO
  Android/QGroundControl target.
- CHART v1 is not yet validated for conversion into 8-bit Epoch amplitude.
- Upstream Dataset channel identity must come from a real configured
  sonar connection, not a random or fabricated UUID.
- Host arrival time is not an original device acquisition timestamp.

## Integration gates

1. Import and audit the missing upstream dependency closure and licensing.
2. Compile the upstream Dataset/Epoch sources as a separate target for the
   actual Android Qt version, including required Qt modules.
3. Add a native QObject bridge owning the Dataset and a stable ChannelId.
   Connect it to completed decoder CHART events; feed raw data only.
4. Validate CHART v0 sample units, absolute offset and epoch alignment
   against actual Kogger frames. Resolve v1 encoding separately.
5. Run Android CI and recorded-frame tests for CHART fragmentation,
   checksum failures, missing GPS, reconnection, memory limits and depth.
6. Connect original DataProcessor and its processors one by one; only then
   enable downstream bottom track, mosaic, surface and isobaths in UI.
7. Review GPL-3.0 obligations before distributing a combined APK.

Do not merge the adapter into main or claim upstream processors are live
until the build and runtime gates above have been satisfied.
