import QtQuick
import QtPositioning

QtObject {
    id: root

    property var sourceCells: []
    property int targetResolution: 28
    property real interpolationPower: 2.0
    property real maxInterpolationDistanceM: 15.0
    property real contourStepM: 0.5

    property var gridCells: []
    property var contourSegments: []
    property real minDepthM: NaN
    property real maxDepthM: NaN
    property int columns: 0
    property int rows: 0
    property bool ready: false

    signal rebuilt(int gridCellCount, int contourSegmentCount)

    function _validNumber(v) {
        var n=Number(v)
        return isFinite(n)
    }

    function _validCell(c) {
        return c && _validNumber(c.lat) && _validNumber(c.lon) &&
               _validNumber(c.depth) && Number(c.depth) >= 0
    }

    function _metersPerDegLon(latDeg) {
        return 111320.0 * Math.cos(Number(latDeg) * Math.PI / 180.0)
    }

    function _distanceM(lat0, lon0, lat1, lon1) {
        var dy=(Number(lat1)-Number(lat0))*111320.0
        var dx=(Number(lon1)-Number(lon0))*_metersPerDegLon((Number(lat0)+Number(lat1))*0.5)
        return Math.sqrt(dx*dx+dy*dy)
    }

    function _idw(lat, lon, valid) {
        var weighted=0, weights=0, nearest=1e99
        for(var i=0;i<valid.length;i++) {
            var c=valid[i]
            var d=_distanceM(lat,lon,c.lat,c.lon)
            if(d<nearest) nearest=d
            if(d<0.20) return {depth:Number(c.depth),nearest:d,valid:true}
            var w=1.0/Math.pow(Math.max(0.20,d),Math.max(1.0,interpolationPower))
            weighted+=Number(c.depth)*w
            weights+=w
        }
        if(weights<=0 || nearest>maxInterpolationDistanceM)
            return {depth:NaN,nearest:nearest,valid:false}
        return {depth:weighted/weights,nearest:nearest,valid:true}
    }

    function _edgePoint(aLat,aLon,aDepth,bLat,bLon,bDepth,level) {
        var den=Number(bDepth)-Number(aDepth)
        var t=Math.abs(den)<0.000001 ? 0.5 : (Number(level)-Number(aDepth))/den
        t=Math.max(0,Math.min(1,t))
        return {
            lat:Number(aLat)+(Number(bLat)-Number(aLat))*t,
            lon:Number(aLon)+(Number(bLon)-Number(aLon))*t
        }
    }

    function _crosses(a,b,level) {
        if(!_validNumber(a) || !_validNumber(b)) return false
        return (Number(a)<=level && Number(b)>level) || (Number(b)<=level && Number(a)>level)
    }

    function rebuild() {
        ready=false
        gridCells=[]
        contourSegments=[]
        minDepthM=NaN
        maxDepthM=NaN
        columns=0
        rows=0

        var valid=[]
        var minLat=1e99,maxLat=-1e99,minLon=1e99,maxLon=-1e99
        for(var i=0;i<sourceCells.length;i++) {
            var c=sourceCells[i]
            if(!_validCell(c)) continue
            valid.push(c)
            minLat=Math.min(minLat,Number(c.lat)); maxLat=Math.max(maxLat,Number(c.lat))
            minLon=Math.min(minLon,Number(c.lon)); maxLon=Math.max(maxLon,Number(c.lon))
            minDepthM=isNaN(minDepthM)?Number(c.depth):Math.min(minDepthM,Number(c.depth))
            maxDepthM=isNaN(maxDepthM)?Number(c.depth):Math.max(maxDepthM,Number(c.depth))
        }
        if(valid.length<3 || minLat>=maxLat || minLon>=maxLon) {
            rebuilt(0,0)
            return
        }

        var centerLat=(minLat+maxLat)*0.5
        var heightM=(maxLat-minLat)*111320.0
        var widthM=(maxLon-minLon)*_metersPerDegLon(centerLat)
        var longRes=Math.max(12,Math.min(40,targetResolution))
        var nx,ny
        if(widthM>=heightM) {
            nx=longRes
            ny=Math.max(8,Math.round(longRes*Math.max(0.20,heightM/Math.max(1,widthM))))
        } else {
            ny=longRes
            nx=Math.max(8,Math.round(longRes*Math.max(0.20,widthM/Math.max(1,heightM))))
        }
        columns=nx
        rows=ny

        var nodeDepths=[]
        var r,cx
        for(r=0;r<=ny;r++) {
            var row=[]
            var lat=minLat+(maxLat-minLat)*(r/ny)
            for(cx=0;cx<=nx;cx++) {
                var lon=minLon+(maxLon-minLon)*(cx/nx)
                var sample=_idw(lat,lon,valid)
                row.push(sample.valid?sample.depth:NaN)
            }
            nodeDepths.push(row)
        }

        var out=[]
        for(r=0;r<ny;r++) {
            var south=minLat+(maxLat-minLat)*(r/ny)
            var north=minLat+(maxLat-minLat)*((r+1)/ny)
            for(cx=0;cx<nx;cx++) {
                var west=minLon+(maxLon-minLon)*(cx/nx)
                var east=minLon+(maxLon-minLon)*((cx+1)/nx)
                var mid=_idw((south+north)*0.5,(west+east)*0.5,valid)
                if(!mid.valid) continue
                out.push({
                    north:north,south:south,west:west,east:east,
                    depth:mid.depth
                })
            }
        }
        gridCells=out

        var segs=[]
        var step=Math.max(0.10,Number(contourStepM))
        var first=Math.ceil(minDepthM/step)*step
        var maxSegments=2400
        for(var level=first;level<=maxDepthM+0.0001 && segs.length<maxSegments;level+=step) {
            for(r=0;r<ny && segs.length<maxSegments;r++) {
                var lat0=minLat+(maxLat-minLat)*(r/ny)
                var lat1=minLat+(maxLat-minLat)*((r+1)/ny)
                for(cx=0;cx<nx && segs.length<maxSegments;cx++) {
                    var lon0=minLon+(maxLon-minLon)*(cx/nx)
                    var lon1=minLon+(maxLon-minLon)*((cx+1)/nx)
                    var d00=nodeDepths[r][cx]
                    var d10=nodeDepths[r][cx+1]
                    var d11=nodeDepths[r+1][cx+1]
                    var d01=nodeDepths[r+1][cx]
                    if(!_validNumber(d00)||!_validNumber(d10)||!_validNumber(d11)||!_validNumber(d01)) continue
                    var points=[]
                    if(_crosses(d00,d10,level)) points.push(_edgePoint(lat0,lon0,d00,lat0,lon1,d10,level))
                    if(_crosses(d10,d11,level)) points.push(_edgePoint(lat0,lon1,d10,lat1,lon1,d11,level))
                    if(_crosses(d11,d01,level)) points.push(_edgePoint(lat1,lon1,d11,lat1,lon0,d01,level))
                    if(_crosses(d01,d00,level)) points.push(_edgePoint(lat1,lon0,d01,lat0,lon0,d00,level))
                    if(points.length===2) {
                        segs.push({aLat:points[0].lat,aLon:points[0].lon,bLat:points[1].lat,bLon:points[1].lon,level:level})
                    } else if(points.length===4) {
                        segs.push({aLat:points[0].lat,aLon:points[0].lon,bLat:points[1].lat,bLon:points[1].lon,level:level})
                        if(segs.length<maxSegments)
                            segs.push({aLat:points[2].lat,aLon:points[2].lon,bLat:points[3].lat,bLon:points[3].lon,level:level})
                    }
                }
            }
        }
        contourSegments=segs
        ready=gridCells.length>0
        rebuilt(gridCells.length,contourSegments.length)
    }

    onSourceCellsChanged: rebuild()
    onTargetResolutionChanged: rebuild()
    onInterpolationPowerChanged: rebuild()
    onMaxInterpolationDistanceMChanged: rebuild()
    onContourStepMChanged: rebuild()
}
