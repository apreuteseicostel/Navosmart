import QtQuick
import QtPositioning
QtObject {
    id: root
    property real laneSpacingM: 5
    property var generatedPoints: []
    property var completedLanes: []
    property int activeLaneIndex: -1
    property bool paused: false
    property string lastError: ""
    property int maxMissionPoints: 500
    property var lastBoatCoordinate: null
    signal scanReady(int pointCount)
    signal progressChanged(int completed, int total)
    signal safetyActionRequested(string action, string reason)
    function reject(reason) { lastError=reason; generatedPoints=[]; completedLanes=[]; activeLaneIndex=-1; return [] }
    function generateRectangle(cornerA, cornerB) {
        lastError=""
        if (!cornerA || !cornerB || !cornerA.isValid || !cornerB.isValid) return reject("Colțuri invalide")
        var north = Math.max(cornerA.latitude, cornerB.latitude)
        var south = Math.min(cornerA.latitude, cornerB.latitude)
        var west = Math.min(cornerA.longitude, cornerB.longitude)
        var east = Math.max(cornerA.longitude, cornerB.longitude)
        var height = QtPositioning.coordinate(south,west).distanceTo(QtPositioning.coordinate(north,west))
        if(height<1 || QtPositioning.coordinate(south,west).distanceTo(QtPositioning.coordinate(south,east))<1 || east-west>1 || north-south>1) return reject("Zona este degenerată sau prea mare")
        var lanes = Math.max(2, Math.ceil(height/Math.max(1,laneSpacingM))+1)
        if(!isFinite(lanes) || lanes*2>maxMissionPoints) return reject("Prea multe waypoint-uri; micșorează zona sau mărește spațierea")
        var pts=[]
        for(var i=0;i<lanes;i++) {
            var t=i/(lanes-1); var lat=south+(north-south)*t
            if(i%2===0){pts.push(QtPositioning.coordinate(lat,west));pts.push(QtPositioning.coordinate(lat,east))}
            else {pts.push(QtPositioning.coordinate(lat,east));pts.push(QtPositioning.coordinate(lat,west))}
        }
        generatedPoints=pts; completedLanes=[]; activeLaneIndex=0; paused=false; scanReady(pts.length); progressChanged(0, lanes); return pts
    }
    function generatePolygon(polygon) {
        lastError=""
        if(!polygon || polygon.length<3 || polygon.length>100)return reject("Poligonul necesită 3–100 puncte")
        var lat0=0,lon0=0
        for(var i=0;i<polygon.length;i++){if(!polygon[i]||!polygon[i].isValid)return reject("Coordonată poligon invalidă");lat0+=polygon[i].latitude;lon0+=polygon[i].longitude}
        lat0/=polygon.length;lon0/=polygon.length
        var mLat=111320.0,mLon=111320.0*Math.cos(lat0*Math.PI/180),xy=[]
        var minY=1e99,maxY=-1e99
        for(i=0;i<polygon.length;i++){var p={x:(polygon[i].longitude-lon0)*mLon,y:(polygon[i].latitude-lat0)*mLat};xy.push(p);minY=Math.min(minY,p.y);maxY=Math.max(maxY,p.y)}
        // Until obstacle-aware connectors exist, refuse concave/self-crossing
        // outlines instead of sending a route that can leave the selected water.
        var orientation=0
        function cross(a,b,c){return (b.x-a.x)*(c.y-a.y)-(b.y-a.y)*(c.x-a.x)}
        for(i=0;i<xy.length;i++) {
            var a=xy[i],b=xy[(i+1)%xy.length],c=xy[(i+2)%xy.length]
            if(Math.hypot(b.x-a.x,b.y-a.y)<0.5) return reject("Puncte duplicate sau prea apropiate")
            var turn=cross(a,b,c)
            if(Math.abs(turn)>0.001) {
                var sign=turn>0?1:-1
                if(orientation && sign!==orientation) return reject("Poligon concav: împarte zona în poligoane convexe")
                orientation=sign
            }
            for(var j=i+2;j<xy.length;j++) {
                if(i===0 && j===xy.length-1) continue
                var d=xy[j],e=xy[(j+1)%xy.length]
                if(cross(a,b,d)*cross(a,b,e)<=0 && cross(d,e,a)*cross(d,e,b)<=0) return reject("Laturile poligonului se intersectează")
            }
        }
        if(!orientation || maxY-minY<1 || Math.abs(mLon)<1) return reject("Poligon degenerat")
        var pts=[],lane=0,spacing=Math.max(1,laneSpacingM)
        if(!isFinite(spacing) || Math.ceil((maxY-minY)/spacing)*2>maxMissionPoints) return reject("Prea multe waypoint-uri; mărește spațierea")
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
        if(!pts.length) return reject("Zona este mai mică decât spațierea culoarelor")
        generatedPoints=pts;completedLanes=[];activeLaneIndex=pts.length?0:-1;paused=false
        scanReady(pts.length);progressChanged(0,laneCount());return pts
    }
    function laneCount() { return Math.floor(generatedPoints.length/2) }
    function markLaneCompleted(index) {
        if(index<0 || index>=laneCount() || completedLanes.indexOf(index)>=0) return
        var done=completedLanes.slice(0); done.push(index); completedLanes=done
        var next=-1
        for(var i=0;i<laneCount();i++) if(done.indexOf(i)<0){next=i;break}
        activeLaneIndex=next
        progressChanged(done.length,laneCount())
    }
    function progressPercent(){ return laneCount()?Math.round(100*completedLanes.length/laneCount()):0 }
    function hold(reason,boatCoordinate){ paused=true; if(boatCoordinate&&boatCoordinate.isValid)lastBoatCoordinate=boatCoordinate; safetyActionRequested("HOLD",reason||"Pauza scanare") }
    function rtl(reason){ paused=true; safetyActionRequested("RTL",reason||"Intoarcere la lansare") }
    function resumeRoute(boatCoordinate){
        var count=laneCount(), first=-1
        for(var n=0;n<count;n++) if(completedLanes.indexOf(n)<0){first=n;break}
        if(first<0)return []
        var out=[], from=(boatCoordinate&&boatCoordinate.isValid)?boatCoordinate:lastBoatCoordinate
        for(var i=first;i<count;i++){
            if(completedLanes.indexOf(i)>=0)continue
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
