import QtQuick
import QtPositioning
QtObject {
    id: root
    property real laneSpacingM: 5
    property var generatedPoints: []
    property var completedLanes: []
    property int activeLaneIndex: -1
    property bool paused: false
    property var lastBoatCoordinate: null
    signal scanReady(int pointCount)
    signal progressChanged(int completed, int total)
    signal safetyActionRequested(string action, string reason)
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
        generatedPoints=pts; completedLanes=[]; activeLaneIndex=0; paused=false; scanReady(pts.length); progressChanged(0, lanes); return pts
    }
    function laneCount() { return Math.floor(generatedPoints.length/2) }
    function markLaneCompleted(index) {
        if(index<0 || index>=laneCount() || completedLanes.indexOf(index)>=0) return
        var done=completedLanes.slice(0); done.push(index); completedLanes=done
        activeLaneIndex=done.length<laneCount()?done.length:-1
        progressChanged(done.length,laneCount())
    }
    function progressPercent(){ return laneCount()?Math.round(100*completedLanes.length/laneCount()):0 }
    function hold(reason,boatCoordinate){ paused=true; if(boatCoordinate&&boatCoordinate.isValid)lastBoatCoordinate=boatCoordinate; safetyActionRequested("HOLD",reason||"Pauza scanare") }
    function rtl(reason){ paused=true; safetyActionRequested("RTL",reason||"Intoarcere la lansare") }
    function resumeRoute(boatCoordinate){
        var first=completedLanes.length, count=laneCount(); if(first>=count)return []
        var out=[], from=(boatCoordinate&&boatCoordinate.isValid)?boatCoordinate:lastBoatCoordinate
        for(var i=first;i<count;i++){
            var a=generatedPoints[i*2], b=generatedPoints[i*2+1]
            if(i===first && from&&from.isValid && from.distanceTo(b)<from.distanceTo(a)){out.push(b);out.push(a)}else{out.push(a);out.push(b)}
        }
        paused=false; activeLaneIndex=first; return out
    }
    function exportMissionPoints(points){
        var src=points||generatedPoints, out=[]
        for(var i=0;i<src.length;i++) if(src[i]&&src[i].isValid) out.push({seq:out.length,command:16,frame:3,latitude:src[i].latitude,longitude:src[i].longitude,altitude:0})
        return out
    }
}