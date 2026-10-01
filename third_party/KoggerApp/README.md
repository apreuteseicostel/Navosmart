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
