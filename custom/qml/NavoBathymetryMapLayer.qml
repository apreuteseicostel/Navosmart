import QtQuick
import QtLocation
import QtPositioning
Item{
 id:root
 required property var map
 property var samples:[]
 property real minDepthM:NaN
 property real maxDepthM:NaN
 property bool showLabels:true
 function depthColor(d){
  if(isNaN(d)||isNaN(minDepthM)||isNaN(maxDepthM))return "#9db2c5"
  var r=maxDepthM>minDepthM?(d-minDepthM)/(maxDepthM-minDepthM):0.5
  if(r<0.25)return "#4fd7ff";if(r<0.5)return "#21b7ff";if(r<0.75)return "#3976d9";return "#173c9c"
 }
 Repeater{
  model:root.samples||[]
  delegate:MapQuickItem{
   required property var modelData
   coordinate:QtPositioning.coordinate(modelData.latitude,modelData.longitude)
   anchorPoint.x:dot.width/2;anchorPoint.y:dot.height/2;z:850
   sourceItem:Rectangle{id:dot;width:root.map.zoomLevel>=17?18:12;height:width;radius:width/2;color:root.depthColor(modelData.depth);border.color:"#e8f6ff";border.width:1
    Text{visible:root.showLabels&&root.map.zoomLevel>=18;anchors.left:parent.right;anchors.leftMargin:3;anchors.verticalCenter:parent.verticalCenter;text:Number(modelData.depth).toFixed(1)+"m";color:"white";font.pixelSize:10;font.bold:true;style:Text.Outline;styleColor:"#03101a"}
   }
   Component.onCompleted:root.map.addMapItem(this)
   Component.onDestruction:root.map.removeMapItem(this)
  }
 }
}