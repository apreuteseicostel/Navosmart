import QtQuick
import QtPositioning

QtObject {
    id: root
    property var detections: []
    property var hotspots: []
    property real clusterRadiusM: 8
    property int minimumHotspotDetections: 2
    property int maxDetections: 2000
    signal detectionAdded(var detection)
    signal hotspotsChangedDetailed(int count)

    function addDetection(coordinate,targetDepthM,bottomDepthM,strength,sourceTime) {
        if(!coordinate||!coordinate.isValid||isNaN(targetDepthM))return null
        var d={id:"fish_"+Date.now()+"_"+detections.length,lat:coordinate.latitude,lon:coordinate.longitude,
               targetDepth:targetDepthM,bottomDepth:isNaN(bottomDepthM)?null:bottomDepthM,
               strength:isNaN(strength)?null:strength,time:sourceTime||Date.now()}
        var a=detections.slice(0);a.push(d);if(a.length>maxDetections)a=a.slice(a.length-maxDetections);detections=a;detectionAdded(d);rebuildHotspots();return d
    }

    function rebuildHotspots(){
        var groups=[]
        for(var i=0;i<detections.length;i++){
            var d=detections[i],dc=QtPositioning.coordinate(d.lat,d.lon),best=-1,bestDist=clusterRadiusM
            for(var g=0;g<groups.length;g++){var gc=QtPositioning.coordinate(groups[g].lat,groups[g].lon),dist=dc.distanceTo(gc);if(dist<=bestDist){bestDist=dist;best=g}}
            if(best<0)groups.push({lat:d.lat,lon:d.lon,count:1,minTargetDepth:d.targetDepth,maxTargetDepth:d.targetDepth,lastTime:d.time})
            else {var h=groups[best],n=h.count+1;h.lat=(h.lat*h.count+d.lat)/n;h.lon=(h.lon*h.count+d.lon)/n;h.count=n;h.minTargetDepth=Math.min(h.minTargetDepth,d.targetDepth);h.maxTargetDepth=Math.max(h.maxTargetDepth,d.targetDepth);h.lastTime=Math.max(h.lastTime,d.time)}
        }
        var filtered=[];for(var k=0;k<groups.length;k++)if(groups[k].count>=minimumHotspotDetections)filtered.push(groups[k])
        hotspots=filtered;hotspotsChangedDetailed(filtered.length)
    }
    function clear(){detections=[];hotspots=[]}
}
