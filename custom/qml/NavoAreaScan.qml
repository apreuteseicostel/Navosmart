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
    function generatePolygon(polygon) {
        if(!polygon || polygon.length<3)return []
        var lat0=0,lon0=0
        for(var i=0;i<polygon.length;i++){if(!polygon[i]||!polygon[i].isValid)return [];lat0+=polygon[i].latitude;lon0+=polygon[i].longitude}
        lat0/=polygon.length;lon0/=polygon.length
        var mLat=111320.0,mLon=111320.0*Math.cos(lat0*Math.PI/180),xy=[]
        var minY=1e99,maxY=-1e99
        for(i=0;i<polygon.length;i++){var p={x:(polygon[i].longitude-lon0)*mLon,y:(polygon[i].latitude-lat0)*mLat};xy.push(p);minY=Math.min(minY,p.y);maxY=Math.max(maxY,p.y)}
        var pts=[],lane=0,spacing=Math.max(1,laneSpacingM)
        for(var y=minY+spacing/2;y<=maxY;y+=spacing){
            var xs=[]
            for(i=0;i<xy.length;i++){
                var a=xy[i],b=xy[(i+1)%xy.length]
                if((a.y<=y&&b.y>y)||(b.y<=y&&a.y>y))xs.push(a.x+(y-a.y)*(b.x-a.x)/(b.y-a.y))
            }
            xs.sort(function(a,b){return a-b})
            for(i=0;i+1<xs.length;i+=2){
                var left=QtPositioning.coordinate(lat0+y/mLat,lon0+xs[i]/mLon)
                var right=QtPositioning.coordinate(lat0+y/mLat,lon0+xs[i+1]/mLon)
                if(lane%2===0){pts.push(left);pts.push(right)}else{pts.push(right);pts.push(left)}
                lane++
            }
        }
        generatedPoints=pts;completedLanes=[];activeLaneIndex=pts.length?0:-1;paused=false
        scanReady(pts.length);progressChanged(0,laneCount());return pts
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