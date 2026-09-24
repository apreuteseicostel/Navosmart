import QtQuick
import QtPositioning

QtObject {
    id: root
    property var fishingSpots: []
    property int nextSpotNumber: 1
    signal spotSaved(var spot)
    signal spotRemoved(string id)

    function _valid(c){ return c && c.isValid }

    function suggestedName(kind) {
        var base=kind&&kind.length?kind:"Loc pescuit"
        var n=1, used={}
        for(var i=0;i<fishingSpots.length;i++) used[fishingSpots[i].name]=true
        while(used[base+" "+n]) n++
        return base+" "+n
    }

    function saveSpot(coordinate, depthM, waterTempC, name, note, sonarEvidence) {
        if(!_valid(coordinate)) return null
        var finalName=(name&&name.trim().length)?name.trim():suggestedName("Loc pescuit")
        var spot={
            id:"spot_"+Date.now()+"_"+Math.floor(Math.random()*10000),
            name:finalName,
            lat:coordinate.latitude,
            lon:coordinate.longitude,
            depth:isNaN(depthM)?null:depthM,
            temp:isNaN(waterTempC)?null:waterTempC,
            note:note||"",
            sonarEvidence:sonarEvidence||null,
            createdAt:Date.now()
        }
        var a=fishingSpots.slice(0); a.push(spot); fishingSpots=a
        spotSaved(spot); return spot
    }

    function saveFromBathymetry(cell, name, note) {
        if(!cell) return null
        var c=QtPositioning.coordinate(cell.lat,cell.lon)
        return saveSpot(c,cell.depth,NaN,name,note,{minDepth:cell.minDepth,maxDepth:cell.maxDepth,samples:cell.samples})
    }

    function removeSpot(id) {
        var a=[]
        for(var i=0;i<fishingSpots.length;i++) if(fishingSpots[i].id!==id)a.push(fishingSpots[i])
        if(a.length===fishingSpots.length)return false
        fishingSpots=a; spotRemoved(id); return true
    }

    function nearestSpot(coordinate,maxDistanceM) {
        if(!_valid(coordinate))return null
        var best=null,bestD=(maxDistanceM===undefined?1e99:maxDistanceM)
        for(var i=0;i<fishingSpots.length;i++){
            var s=fishingSpots[i],c=QtPositioning.coordinate(s.lat,s.lon),d=coordinate.distanceTo(c)
            if(d<=bestD){bestD=d;best=s}
        }
        return best
    }
}
