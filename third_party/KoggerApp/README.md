# KoggerApp experimental source import

Upstream: https://github.com/koggertech/KoggerApp
Upstream tree revision: 3a7f526681f5e0aa2285e8617f27e4cfee97d777 (master)
License: GPL-3.0; original text in LICENSE.

## Imported upstream source (unmodified)

- BottomTrackProcessor and BtWorker
- Dataset, Epoch, Dataset definitions, DataHorizon and DataInterpolator
- DataProcessor, ComputeWorker and processor definitions
- Isobaths, Surface, SurfaceMesh, SurfaceTile and Mosaic processors
- MosaicDB, MosaicIndexProvider and HotTileCache
- BottomTrack scene domain and draw utilities

## Integration state

These files are vendor source only, not registered with the NAVO CMake target.
KoggerApp classes refer to other application-level interfaces, scene and
dataset types. The dependency closure and Android/Qt compatibility have not
yet been validated. Copying the original code does not mean it can compile
standalone or process the existing NAVO CHART stream.

Next: audit all local includes, identify missing transitive dependencies,
design a CHART/GPS-to-Dataset adapter, then enable a separate build target
and resolve compiler/linker errors before connecting the PRO UI.

The original NAVO sonar path and H743 command path remain unchanged.
Distributing a combined application requires GPL-3.0 compliance, including
appropriate notices and corresponding source code.

## NAVO-to-Kogger adapter contract (not yet implemented)

Input: completed CHART echo column (QVariantList), depth in metres,
water temperature, timestamp in milliseconds, and valid H743 GNSS
latitude/longitude. The current NAVO decoder emits completed columns
via echoSamplesChanged. NAVO publishes geoSample only if depth is fresh
(within 1500 ms) and vehicle GPS is valid.

An adapter must preserve the original CHART resolution/scale, channel
identity, acquisition timestamp, and range before creating Kogger Epoch
and DatasetChannel records. The existing NAVO QVariantList currently
exposes normalized echo amplitudes, but not all Kogger metadata. Do not
synthesize missing physical range/channel values or call the original
BottomTrackProcessor on fabricated Epoch records. First extend the
NAVO decoder's metadata interface, then map the validated fields.

Kogger's original BottomTrackProcessor operates over Dataset epochs and
is not a drop-in replacement for NAVO's QML bottom-echo estimate.
