import QtQuick
import QtPositioning

QtObject {
    id: root
    property var fishingSpots: []
    property int nextSpotNumber: 1
    signal spotSaved(var spot)
    signal spotRemoved(string id)
    signal spotUpdated(var spot)

    function _valid(c){ return c && c.isValid }

    function suggestedName(kind) {
        var base=kind&&kind.length?kind:"Loc pescuit"
        var n=1, used={}
        for(var i=0;i<fishingSpots.length;i++) used[fishingSpots[i].name]=true
        while(used[base+" "+n]) n++
        return base+" "+n
    }

    function saveSpot(coordinate, depthM, waterTempC, name, note, sonarEvidence, markerColor) {
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
            color:markerColor||"#31d67b",
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

    // Update user metadata together; preserve identity, creation time and sonar evidence.
    function updateSpot(id, fields) {
        if(!fields || typeof fields.name!=="string" || !fields.name.trim().length ||
           typeof fields.lat!=="number" || !isFinite(fields.lat) || Math.abs(fields.lat)>90 ||
           typeof fields.lon!=="number" || !isFinite(fields.lon) || Math.abs(fields.lon)>180 ||
           (fields.depth!==null && (typeof fields.depth!=="number" || !isFinite(fields.depth) || fields.depth<0)) ||
           (fields.temp!==null && (typeof fields.temp!=="number" || !isFinite(fields.temp))) ||
           typeof fields.note!=="string" || typeof fields.color!=="string" || !/^#[0-9a-fA-F]{6}$/.test(fields.color)) return false
        var a=fishingSpots.slice(0)
        for(var i=0;i<a.length;i++) if(a[i].id===id){
            var s=Object.assign({},a[i])
            s.name=fields.name.trim();s.lat=fields.lat;s.lon=fields.lon
            s.depth=fields.depth;s.temp=fields.temp;s.note=fields.note;s.color=fields.color
            a[i]=s;fishingSpots=a;spotUpdated(s);return true
        }
        return false
    }

    function renameSpot(id, name) {
        var n=(name||"").trim()
        if(!n.length)return false
        var a=fishingSpots.slice(0)
        for(var i=0;i<a.length;i++) if(a[i].id===id){
            var s=Object.assign({},a[i]); s.name=n; a[i]=s; fishingSpots=a; spotUpdated(s); return true
        }
        return false
    }

    function setSpotColor(id, color) {
        var a=fishingSpots.slice(0)
        for(var i=0;i<a.length;i++) if(a[i].id===id){
            var s=Object.assign({},a[i]); s.color=color||"#31d67b"; a[i]=s; fishingSpots=a; spotUpdated(s); return true
        }
        return false
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

