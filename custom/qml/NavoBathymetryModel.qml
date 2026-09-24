import QtQuick
import QtPositioning

QtObject {
    id: root
    property var samples: []
    property var cells: []
    property real gridSizeM: 2.0
    property real minDepthM: NaN
    property real maxDepthM: NaN
    signal rebuilt(int cellCount)

    function rebuild(inputSamples) {
        samples=inputSamples||[]
        cells=[]
        minDepthM=NaN; maxDepthM=NaN
        if(!samples.length){rebuilt(0);return []}

        var origin=QtPositioning.coordinate(samples[0].lat,samples[0].lon)
        var buckets={}
        var size=Math.max(0.5,gridSizeM)
        for(var i=0;i<samples.length;i++){
            var s=samples[i]
            if(s===null || isNaN(s.depth)) continue
            var c=QtPositioning.coordinate(s.lat,s.lon)
            if(!c.isValid) continue
            var north=origin.distanceTo(QtPositioning.coordinate(c.latitude,origin.longitude))*(c.latitude>=origin.latitude?1:-1)
            var east=origin.distanceTo(QtPositioning.coordinate(origin.latitude,c.longitude))*(c.longitude>=origin.longitude?1:-1)
            var gx=Math.round(east/size), gy=Math.round(north/size), key=gx+":"+gy
            if(!buckets[key]) buckets[key]={gx:gx,gy:gy,sum:0,count:0,min:s.depth,max:s.depth,hardSum:0,hardCount:0,echoSum:0,echoCount:0}
            var b=buckets[key]; b.sum+=s.depth; b.count++; b.min=Math.min(b.min,s.depth); b.max=Math.max(b.max,s.depth); if(s.hardness!==undefined&&!isNaN(s.hardness)){b.hardSum+=s.hardness;b.hardCount++} if(s.bottomEcho!==undefined&&!isNaN(s.bottomEcho)){b.echoSum+=s.bottomEcho;b.echoCount++}
            minDepthM=isNaN(minDepthM)?s.depth:Math.min(minDepthM,s.depth)
            maxDepthM=isNaN(maxDepthM)?s.depth:Math.max(maxDepthM,s.depth)
        }
        var out=[]
        for(var k in buckets){
            var b=buckets[k]
            var center=origin.atDistanceAndAzimuth(Math.sqrt(Math.pow(b.gx*size,2)+Math.pow(b.gy*size,2)),Math.atan2(b.gx,b.gy)*180/Math.PI)
            out.push({lat:center.latitude,lon:center.longitude,depth:b.sum/b.count,minDepth:b.min,maxDepth:b.max,samples:b.count,hardness:b.hardCount?b.hardSum/b.hardCount:NaN,bottomEcho:b.echoCount?b.echoSum/b.echoCount:NaN})
        }
        cells=out; rebuilt(out.length); return out
    }

    function nearestDepth(coordinate) {
        if(!coordinate || !coordinate.isValid || !cells.length) return NaN
        var best=NaN,bestD=1e99
        for(var i=0;i<cells.length;i++){
            var c=QtPositioning.coordinate(cells[i].lat,cells[i].lon), d=coordinate.distanceTo(c)
            if(d<bestD){bestD=d;best=cells[i].depth}
        }
        return best
    }
}
