.pragma library
// Lightweight viewport pan reuse for the display-only bathymetry mesh.
// Safety: never reuse projected points across zoom, bearing, tilt or resize.
function panOffset(map, cachedView) {
    if (!map || !map.mapReady || !cachedView || !cachedView.center ||
        !cachedView.center.isValid || !map.center || !map.center.isValid ||
        !(map.width > 0) || !(map.height > 0) ||
        map.width !== cachedView.width || map.height !== cachedView.height ||
        Math.abs(map.zoomLevel - cachedView.zoomLevel) > 0.000001 ||
        Math.abs(map.bearing - cachedView.bearing) > 0.000001 ||
        Math.abs(map.tilt) > 0.000001 || Math.abs(cachedView.tilt) > 0.000001)
        return null;
    if (map.center.latitude === cachedView.center.latitude &&
        map.center.longitude === cachedView.center.longitude)
        return { x: 0, y: 0 };
    var oldPoint = map.fromCoordinate(cachedView.center, false);
    var newPoint = map.fromCoordinate(map.center, false);
    if (!oldPoint || !newPoint || !isFinite(oldPoint.x) ||
        !isFinite(oldPoint.y) || !isFinite(newPoint.x) || !isFinite(newPoint.y))
        return null;
    var dx = oldPoint.x - newPoint.x;
    var dy = oldPoint.y - newPoint.y;
    // Large pans/dateline discontinuities use a full accurate reprojection.
    if (Math.abs(dx) > map.width || Math.abs(dy) > map.height) return null;
    return { x: dx, y: dy };
}
function translateProjected(points, offset) {
    if (!points || !offset) return points;
    for (var i = 0; i < points.length; ++i) {
        var point = points[i];
        if (point) { point.x += offset.x; point.y += offset.y; }
    }
    return points;
}
