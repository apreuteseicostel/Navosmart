import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import NavoSmart.Backend 1.0
Popup {
 id:root
 property bool connected:false
 property real depthM:NaN
 property real waterTempC:NaN
 property real speedMps:NaN
 property real latitude:NaN
 property real longitude:NaN
 property var echoSamples:[]\n property var fishHotspots:[]
 signal saveWaypointRequested(real latitude,real longitude,real depthM,real waterTempC)
 modal:true
 focus:true
 closePolicy:Popup.CloseOnEscape
 padding:0
 background:Rectangle{color:"#03101a";border.color:"#21b7ff"}
 contentItem:ColumnLayout{
  spacing:8
  RowLayout{Layout.fillWidth:true;Layout.margins:12
   Label{text:"KOGGER BASIC 2D+ • SONAR LIVE";color:"white";font.pixelSize:20;font.bold:true}
   Label{text:root.connected?"● LIVE":"● FĂRĂ DATE";color:root.connected?"#31d67b":"#9db2c5"}
   Item{Layout.fillWidth:true}
   Label{text:isNaN(root.depthM)?"-- m":root.depthM.toFixed(1)+" m";color:"#21b7ff";font.pixelSize:28;font.bold:true}
   Label{text:isNaN(root.waterTempC)?"-- °C":root.waterTempC.toFixed(1)+" °C";color:"white";font.pixelSize:20}
   Button{text:"ÎNCHIDE";onClicked:root.close()}
  }
  Rectangle{Layout.fillWidth:true;Layout.fillHeight:true;color:"#020b12"
   Repeater {\n    model: 5\n    Label { anchors.left:parent.left; anchors.leftMargin:8; y:index*(parent.height/4)-height/2; text:(index===0?"0.0":(!isNaN(root.depthM)?(root.depthM*index/4).toFixed(1):"--"))+" m"; color:"#d9edf7"; z:3 }\n   }\n   Canvas{id:echogram;anchors.fill:parent
    onPaint:{var ctx=getContext("2d");ctx.reset();ctx.fillStyle="#020b12";ctx.fillRect(0,0,width,height);ctx.strokeStyle="#18364a";ctx.lineWidth=1;for(var g=1;g<5;g++){var gy=g*height/5;ctx.beginPath();ctx.moveTo(0,gy);ctx.lineTo(width,gy);ctx.stroke()}if(root.echoSamples&&root.echoSamples.length>1){ctx.strokeStyle="#21b7ff";ctx.lineWidth=2;ctx.beginPath();for(var i=0;i<root.echoSamples.length;i++){var x=i*width/(root.echoSamples.length-1);var y=height-Math.max(0,Math.min(1,root.echoSamples[i]))*height;if(i===0)ctx.moveTo(x,y);else ctx.lineTo(x,y)}ctx.stroke()} if(root.fishHotspots){ctx.font="bold 18px sans-serif";ctx.fillStyle="#f2f7fb";for(var f=0;f<root.fishHotspots.length;f++){var h=root.fishHotspots[f];if(!isNaN(root.depthM)&&root.depthM>0){var fy=Math.max(18,Math.min(height-8,h.minTargetDepth/root.depthM*height));ctx.fillText("🐟"+(h.count>1?h.count:""),width-70,fy)}}}}
    Connections{target:root;function onEchoSamplesChanged(){echogram.requestPaint()}}
   }
   Label{anchors.centerIn:parent;visible:!root.connected;text:"Aștept date reale de la Kogger\nEcograma nu este simulată";horizontalAlignment:Text.AlignHCenter;color:"#9db2c5";font.pixelSize:18}
  }
  RowLayout{Layout.fillWidth:true;Layout.margins:12
   Label{text:"Viteză: "+(isNaN(root.speedMps)?"--":root.speedMps.toFixed(1)+" m/s");color:"#9db2c5"}
   Label{text:"GPS: "+(isNaN(root.latitude)?"--":root.latitude.toFixed(6)+", "+root.longitude.toFixed(6));color:"#9db2c5"}
   Item{Layout.fillWidth:true}
   Button{text:"SALVEAZĂ PUNCT AICI";enabled:root.connected&&!isNaN(root.latitude)&&!isNaN(root.longitude)&&!isNaN(root.depthM);onClicked:root.saveWaypointRequested(root.latitude,root.longitude,root.depthM,root.waterTempC)}
  }
 }
}