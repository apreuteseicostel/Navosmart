import QtQuick
QtObject {
    id: root
    property bool recording: false
    property var samples: []
    property int maxSamples: 50000
    signal sampleRecorded(int count)
    function start(){ samples=[]; recording=true }
    function stop(){ recording=false }
    function addSample(coordinate, depthM, waterTempC) {
        if(!recording || !coordinate || !coordinate.isValid || isNaN(depthM)) return
        var a=samples.slice(0); a.push({lat:coordinate.latitude,lon:coordinate.longitude,depth:depthM,temp:waterTempC,time:Date.now()})
        if(a.length>maxSamples) a.shift(); samples=a; sampleRecorded(a.length)
    }
    function nearest(lat,lon) {
        if(!samples.length) return null
        var best=null,bestD=1e99
        for(var i=0;i<samples.length;i++){var s=samples[i],d=(s.lat-lat)*(s.lat-lat)+(s.lon-lon)*(s.lon-lon);if(d<bestD){bestD=d;best=s}}
        return best
    }
}