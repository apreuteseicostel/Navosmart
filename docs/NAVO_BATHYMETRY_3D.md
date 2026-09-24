# NAVO SMART — 3D Bathymetry

Status: isolated development branch; do not merge into the unified Android branch until the stable APK milestone is reached.

## Goal
Build an interactive 3D model of a scanned lake from NAVO SMART bathymetry data. The model must be derived from saved sonar/GNSS samples, not from QGroundControl Viewer3D.

## Input
Each accepted sample should expose at minimum:
- latitude
- longitude
- depth in metres
- timestamp
- optional water temperature
- quality/confidence where available

The existing NavoBathymetryModel and lake persistence data remain the source of truth.

## Pipeline
1. Load the saved lake/session bathymetry samples.
2. Convert WGS84 latitude/longitude to a local metric XY frame around the lake origin.
3. Reject invalid/outlier depth samples and retain a confidence/coverage mask.
4. Interpolate only inside adequately sampled regions; never invent a continuous lake bottom across unknown/unscanned areas.
5. Build a regular/adaptive bathymetry grid.
6. Generate triangle vertices, indices, normals and depth values.
7. Render the mesh in a dedicated NAVO 3D view.
8. Cache derived mesh data so reopening My Lakes does not require rebuilding unchanged scans.

## Planned modules
- NavoBathymetryMesh: mesh/grid generation from NavoBathymetryModel samples.
- NavoBathymetry3D.qml: interactive renderer.
- NavoBathymetry3DController: camera, selection, vertical exaggeration and layer state if native support is required.
- Persistence extension: mesh revision/cache metadata, while raw sonar/GNSS samples remain authoritative.

## UI
Entry point: Bathymetry screen -> 2D / 3D toggle.

3D interactions:
- orbit/rotate
- pan
- pinch zoom
- reset/top/isometric camera
- vertical exaggeration: 1x, 2x, 3x, 5x
- metric depth legend
- tap/pick a bottom point to display coordinates/depth and available temperature
- optional overlays: boat track, fishing spots, waypoints, fish detections, Area Scan lanes
- clear visual distinction between measured/interpolated/unknown regions

## Android constraints
This feature is separate from QGroundControl Viewer3D. Renderer choice must be validated on the target Android hardware before integration. Keep a 2D fallback and avoid making application startup depend on the 3D renderer.

## Integration gate
Do not merge this branch into feature/unified-navosmart-integration until:
1. unified branch produces a stable installable APK and passes emulator smoke test;
2. 2D bathymetry/persistence data contract is stable;
3. 3D view can be disabled without affecting navigation/sonar;
4. Android performance and memory are acceptable on the target device.

## Implementation order
1. Freeze bathymetry sample/data contract.
2. Implement coordinate conversion + grid/outlier handling.
3. Implement mesh generation and unit tests with synthetic lake data.
4. Implement 3D renderer and camera controls.
5. Add depth legend, point picking and vertical exaggeration.
6. Add saved-lake loading/cache.
7. Add optional NAVO overlays.
8. Validate Android performance.
9. Integrate only after stable APK gate.
