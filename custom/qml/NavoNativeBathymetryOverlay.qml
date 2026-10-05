import QtQuick
import QtQuick.Controls
import QtPositioning

Item {
    id: root
    objectName:"navoNativeSurfaceOverlay"
    required property var map
    property var surface: ({})
    property bool active: false
    readonly property bool ready: surface && surface.version===1 && surface.vertices &&
        surface.indices && surface.indices.length>=3 && surface.vertices.length<=8192 &&
        surface.indices.length<=49152
    property var nativeBridge: null
    property var projected: []
    property int renderedTriangles: 0
    property real lastPaintMs: 0
    anchors.fill: parent
    visible: active && ready

    function invalidateProjection(requestTiles) {
        projected=[]
        if(!paintTimer.running)paintTimer.start()
        if(requestTiles && active && !viewportTimer.running)viewportTimer.start()
    }
    onSurfaceChanged: invalidateProjection(false)
    onActiveChanged: invalidateProjection(true)
    function depthColor(depth) {
        var lo=Number(surface.minDepth),hi=Number(surface.maxDepth)
        var t=hi>lo?(depth-lo)/(hi-lo):0.5
        t=Math.max(0,Math.min(1,t))
        if(t<.25)return Qt.rgba(1, .2+2.4*t, .05, .64)
        if(t<.5)return Qt.rgba(1-3.6*(t-.25), .8, .05+2.8*(t-.25), .64)
        if(t<.75)return Qt.rgba(.1, .8-1.6*(t-.5), .75+(t-.5), .64)
        return Qt.rgba(.1, .4-1.0*(t-.75), 1, .64)
    }
    function requestViewport() {
        if(!active || !nativeBridge || !map || map.width<=0 || map.height<=0)return
        var corners=[map.toCoordinate(Qt.point(0,0),false),
            map.toCoordinate(Qt.point(map.width,0),false),
            map.toCoordinate(Qt.point(0,map.height),false),
            map.toCoordinate(Qt.point(map.width,map.height),false)]
        var south=90,north=-90,west=180,east=-180
        for(var i=0;i<corners.length;i++) {
            var c=corners[i]
            if(!c || !c.isValid)return
            south=Math.min(south,c.latitude);north=Math.max(north,c.latitude)
            west=Math.min(west,c.longitude);east=Math.max(east,c.longitude)
        }
        nativeBridge.requestNativeViewport(south,west,north,east)
    }
    Timer { id:paintTimer; interval:33; onTriggered:canvas.requestPaint() }
    Timer { id:viewportTimer; interval:250; onTriggered:root.requestViewport() }
    Connections {
        target:root.map
        ignoreUnknownSignals:true
        function onCenterChanged(){root.invalidateProjection(true)}
        function onZoomLevelChanged(){root.invalidateProjection(true)}
        function onBearingChanged(){root.invalidateProjection(true)}
        function onTiltChanged(){root.invalidateProjection(true)}
        function onWidthChanged(){root.invalidateProjection(true)}
        function onHeightChanged(){root.invalidateProjection(true)}
    }
    Canvas {
        id:canvas
        objectName:"nativeBathymetryCanvas"
        anchors.fill:parent
        onWidthChanged:root.invalidateProjection(true)
        onHeightChanged:root.invalidateProjection(true)
        onPaint: {
            var ctx=getContext("2d"),started=Date.now()
            ctx.clearRect(0,0,width,height)
            root.renderedTriangles=0
            if(!root.active || !root.ready || !root.map)return
            var vertices=root.surface.vertices,indices=root.surface.indices
            if(!root.projected.length) {
                var out=[]
                for(var v=0;v<vertices.length;v++) {
                    var p=vertices[v]
                    if(!p || p.length!==4 || !isFinite(p[0]) || !isFinite(p[1]) ||
                        !isFinite(p[2]) || p[2]<=0 || Math.abs(p[0])>90 ||
                        Math.abs(p[1])>180 || p[3]<1 || p[3]>3) {out.push(null);continue}
                    var screen=root.map.fromCoordinate(QtPositioning.coordinate(p[0],p[1]),false)
                    out.push(screen && isFinite(screen.x) && isFinite(screen.y)?screen:null)
                }
                root.projected=out
            }
            var count=0
            for(var i=0;i+2<indices.length;i+=3) {
                var ia=Number(indices[i]),ib=Number(indices[i+1]),ic=Number(indices[i+2])
                if(ia%1 || ib%1 || ic%1 || ia<0 || ib<0 || ic<0 ||
                    ia>=vertices.length || ib>=vertices.length || ic>=vertices.length)continue
                var a=root.projected[ia],b=root.projected[ib],c=root.projected[ic]
                if(!a || !b || !c)continue
                if(Math.max(a.x,b.x,c.x)<0 || Math.min(a.x,b.x,c.x)>width ||
                    Math.max(a.y,b.y,c.y)<0 || Math.min(a.y,b.y,c.y)>height)continue
                ctx.fillStyle=root.depthColor((vertices[ia][2]+vertices[ib][2]+vertices[ic][2])/3)
                ctx.beginPath();ctx.moveTo(a.x,a.y);ctx.lineTo(b.x,b.y);ctx.lineTo(c.x,c.y)
                ctx.closePath();ctx.fill();count++
            }
            root.renderedTriangles=count
            root.lastPaintMs=Date.now()-started
        }
    }
    Rectangle {
        objectName:"nativeBathymetryLegend"
        anchors.left:parent.left;anchors.bottom:parent.bottom;anchors.margins:10
        width:210;height:62;radius:7;color:"#df071827";border.color:"#21b7ff"
        Column {
            anchors.fill:parent;anchors.margins:7;spacing:4
            Text {text:"BATIMETRIE NATIVĂ";color:"white";font.bold:true;font.pixelSize:11}
            Text {text:Number(root.surface.minDepth||0).toFixed(1)+" — "+Number(root.surface.maxDepth||0).toFixed(1)+" m";color:"#d7e3ee";font.pixelSize:10}
            Text {text:root.surface.truncated?"Suprafață Kogger • afișare limitată":"Suprafață interpolată Kogger";color:"#9fb5c7";font.pixelSize:9}
        }
    }
}
