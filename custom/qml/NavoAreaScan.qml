import QtQuick
import QtPositioning

QtObject {
    id: root
    property real laneSpacingM: 5
    property real marginM: 0
    property var generatedPoints: []
    property var boundary: []
    property real estimatedDistanceM: 0
    property real estimatedAreaM2: 0
    property int laneCount: 0
    property string orientation: ""
    signal scanReady(int pointCount)

    function valid(c) { return c && c.isValid }
    function appendLane(pts, p1, p2) {
        if (pts.length) root.estimatedDistanceM += pts[pts.length-1].distanceTo(p1)
        pts.push(p1); root.estimatedDistanceM += p1.distanceTo(p2); pts.push(p2)
    }
    function generateRectangle(cornerA, cornerB) {
        if (!valid(cornerA) || !valid(cornerB)) return []
        var north=Math.max(cornerA.latitude,cornerB.latitude), south=Math.min(cornerA.latitude,cornerB.latitude)
        var west=Math.min(cornerA.longitude,cornerB.longitude), east=Math.max(cornerA.longitude,cornerB.longitude)
        var sw=QtPositioning.coordinate(south,west), nw=QtPositioning.coordinate(north,west)
        var se=QtPositioning.coordinate(south,east), ne=QtPositioning.coordinate(north,east)
        var height=sw.distanceTo(nw), width=sw.distanceTo(se)
        if(height < 1 || width < 1) return []
        var spacing=Math.max(1,Math.min(20,laneSpacingM))
        estimatedAreaM2=height*width; estimatedDistanceM=0
        boundary=[sw,nw,ne,se,sw]
        var pts=[], lanes, i, t, p1, p2
        // Run lanes along the long side: fewer turns and lower energy use.
        if(width >= height) {
            orientation="E-W"
            lanes=Math.max(2,Math.ceil(height/spacing)+1)
            for(i=0;i<lanes;i++){
                t=i/(lanes-1)
                var lat=south+(north-south)*t
                p1=QtPositioning.coordinate(lat,i%2===0?west:east)
                p2=QtPositioning.coordinate(lat,i%2===0?east:west)
                appendLane(pts,p1,p2)
            }
        } else {
            orientation="N-S"
            lanes=Math.max(2,Math.ceil(width/spacing)+1)
            for(i=0;i<lanes;i++){
                t=i/(lanes-1)
                var lon=west+(east-west)*t
                p1=QtPositioning.coordinate(i%2===0?south:north,lon)
                p2=QtPositioning.coordinate(i%2===0?north:south,lon)
                appendLane(pts,p1,p2)
            }
        }
        laneCount=lanes; generatedPoints=pts; scanReady(pts.length); return pts
    }
    function reverseForNearestStart(currentCoordinate) {
        if(!valid(currentCoordinate) || generatedPoints.length < 2) return generatedPoints
        var first=currentCoordinate.distanceTo(generatedPoints[0])
        var last=currentCoordinate.distanceTo(generatedPoints[generatedPoints.length-1])
        if(last < first) generatedPoints=generatedPoints.slice(0).reverse()
        return generatedPoints
    }
    function clear(){ generatedPoints=[]; boundary=[]; estimatedDistanceM=0; estimatedAreaM2=0; laneCount=0; orientation="" }
}