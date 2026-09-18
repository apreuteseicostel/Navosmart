import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
Popup {
 id:root
 property bool connected:false
 property real depthM:NaN
 property real waterTempC:NaN
 property real speedMps:NaN
 property real latitude:NaN
 property real longitude:NaN
 property var echoSamples:[]
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
   Canvas{id:echogram;anchors.fill:parent
    onPaint:{var ctx=getContext("2d");ctx.reset();ctx.fillStyle="#020b12";ctx.fillRect(0,0,width,height);ctx.strokeStyle="#18364a";ctx.lineWidth=1;for(var g=1;g<5;g++){var gy=g*height/5;ctx.beginPath();ctx.moveTo(0,gy);ctx.lineTo(width,gy);ctx.stroke()}if(root.echoSamples&&root.echoSamples.length>1){ctx.strokeStyle="#21b7ff";ctx.lineWidth=2;ctx.beginPath();for(var i=0;i<root.echoSamples.length;i++){var x=i*width/(root.echoSamples.length-1);var y=height-Math.max(0,Math.min(1,root.echoSamples[i]))*height;if(i===0)ctx.moveTo(x,y);else ctx.lineTo(x,y)}ctx.stroke()}}
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