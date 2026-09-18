import QtQuick
import QtLocation
import QtPositioning

Item {
 id: root
 required property var map
 property var samples: []
 property real minDepthM: NaN
 property real maxDepthM: NaN
 property bool showLabels: true
 property bool showEstimated: true
 property real estimateRadiusPx: 70
 property int gridPx: 24

 function depthColor(d,a) {
  if(isNaN(d)||isNaN(minDepthM)||isNaN(maxDepthM)) return "rgba(157,178,197,0.35)"
  var r=maxDepthM>minDepthM?(d-minDepthM)/(maxDepthM-minDepthM):0.5
  var c=r<0.25?[79,215,255]:r<0.5?[33,183,255]:r<0.75?[57,118,217]:[23,60,156]
  return "rgba("+c[0]+","+c[1]+","+c[2]+","+(a===undefined?1:a)+")"
 }
 function nearestEstimate(x,y) {
  var sw=0, sd=0, nearest=1e9, used=0
  for(var i=0;i<(samples||[]).length;i++){
   var s=samples[i], p=map.fromCoordinate(QtPositioning.coordinate(s.latitude,s.longitude),false)
   var dx=p.x-x,dy=p.y-y,dist=Math.sqrt(dx*dx+dy*dy)
   nearest=Math.min(nearest,dist)
   if(dist<=estimateRadiusPx && !isNaN(s.depth)){
    var w=1/Math.max(16,dist*dist); sw+=w; sd+=w*s.depth; used++
   }
  }
  return used>=2 && nearest<=estimateRadiusPx ? sd/sw : NaN
 }

 Canvas {
  id: heat
  anchors.fill: parent
  visible: root.showEstimated && (root.samples||[]).length>=3
  opacity: 0.72
  onPaint: {
   var ctx=getContext("2d"); ctx.clearRect(0,0,width,height)
   var step=Math.max(16,root.gridPx)
   for(var y=step/2;y<height;y+=step) for(var x=step/2;x<width;x+=step){
    var d=root.nearestEstimate(x,y)
    if(!isNaN(d)){ctx.fillStyle=root.depthColor(d,0.55);ctx.fillRect(x-step/2,y-step/2,step,step)}
   }
  }
 }
 Timer { interval:250; repeat:false; running:false; id:repaintTimer; onTriggered:heat.requestPaint() }
 onSamplesChanged: repaintTimer.restart()
 onMinDepthMChanged: repaintTimer.restart()
 onMaxDepthMChanged: repaintTimer.restart()
 Connections { target:root.map; function onCenterChanged(){repaintTimer.restart()} function onZoomLevelChanged(){repaintTimer.restart()} }

 Repeater {
  model: root.samples||[]
  delegate: MapQuickItem {
   required property var modelData
   coordinate: QtPositioning.coordinate(modelData.latitude,modelData.longitude)
   anchorPoint.x: dot.width/2; anchorPoint.y: dot.height/2; z:850
   sourceItem: Rectangle {
    id:dot; width:root.map.zoomLevel>=17?18:12; height:width; radius:width/2
    color:root.depthColor(modelData.depth,1); border.color:"#e8f6ff"; border.width:1
    Text { visible:root.showLabels&&root.map.zoomLevel>=18; anchors.left:parent.right; anchors.leftMargin:3; anchors.verticalCenter:parent.verticalCenter; text:Number(modelData.depth).toFixed(1)+"m"; color:"white"; font.pixelSize:10; font.bold:true; style:Text.Outline; styleColor:"#03101a" }
   }
   Component.onCompleted:root.map.addMapItem(this)
   Component.onDestruction:root.map.removeMapItem(this)
  }
 }

 Rectangle {
  anchors.left:parent.left; anchors.bottom:parent.bottom; anchors.margins:12
  width:190; height:42; radius:6; color:"#071827dd"; border.color:"#1c4262"; z:900
  Row {
   anchors.centerIn:parent; spacing:10
   Text { text:"● Măsurat"; color:"#f2f7fb"; font.pixelSize:11 }
   Text { text:"▦ Estimat (IDW)"; color:"#9db2c5"; font.pixelSize:11 }
  }
 }
}