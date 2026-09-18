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
    signal scanReady(int pointCount)

    function valid(c) { return c && c.isValid }
    function generateRectangle(cornerA, cornerB) {
        if (!valid(cornerA) || !valid(cornerB)) return []
        var north=Math.max(cornerA.latitude,cornerB.latitude), south=Math.min(cornerA.latitude,cornerB.latitude)
        var west=Math.min(cornerA.longitude,cornerB.longitude), east=Math.max(cornerA.longitude,cornerB.longitude)
        var sw=QtPositioning.coordinate(south,west), nw=QtPositioning.coordinate(north,west)
        var se=QtPositioning.coordinate(south,east), ne=QtPositioning.coordinate(north,east)
        var height=sw.distanceTo(nw), width=sw.distanceTo(se)
        if(height < 1 || width < 1) return []
        estimatedAreaM2=height*width
        boundary=[sw,nw,ne,se,sw]
        var lanes=Math.max(2,Math.ceil(height/Math.max(1,laneSpacingM))+1)
        var pts=[], distance=0
        for(var i=0;i<lanes;i++){
            var t=i/(lanes-1), lat=south+(north-south)*t
            var p1=QtPositioning.coordinate(lat,i%2===0?west:east)
            var p2=QtPositioning.coordinate(lat,i%2===0?east:west)
            if(pts.length) distance+=pts[pts.length-1].distanceTo(p1)
            pts.push(p1); distance+=p1.distanceTo(p2); pts.push(p2)
        }
        generatedPoints=pts; estimatedDistanceM=distance; scanReady(pts.length); return pts
    }
    function clear(){ generatedPoints=[]; boundary=[]; estimatedDistanceM=0; estimatedAreaM2=0 }
}