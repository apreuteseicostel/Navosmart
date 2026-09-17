import QtQuick
import QtPositioning
QtObject {
    id: root
    property real laneSpacingM: 5
    property var generatedPoints: []
    signal scanReady(int pointCount)
    function generateRectangle(cornerA, cornerB) {
        if (!cornerA || !cornerB || !cornerA.isValid || !cornerB.isValid) return []
        var north = Math.max(cornerA.latitude, cornerB.latitude)
        var south = Math.min(cornerA.latitude, cornerB.latitude)
        var west = Math.min(cornerA.longitude, cornerB.longitude)
        var east = Math.max(cornerA.longitude, cornerB.longitude)
        var height = QtPositioning.coordinate(south,west).distanceTo(QtPositioning.coordinate(north,west))
        var lanes = Math.max(2, Math.ceil(height/Math.max(1,laneSpacingM))+1)
        var pts=[]
        for(var i=0;i<lanes;i++) {
            var t=i/(lanes-1); var lat=south+(north-south)*t
            if(i%2===0){pts.push(QtPositioning.coordinate(lat,west));pts.push(QtPositioning.coordinate(lat,east))}
            else {pts.push(QtPositioning.coordinate(lat,east));pts.push(QtPositioning.coordinate(lat,west))}
        }
        generatedPoints=pts; scanReady(pts.length); return pts
    }
}