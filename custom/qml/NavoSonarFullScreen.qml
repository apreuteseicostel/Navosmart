import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import NavoSmart.Backend 1.0
Popup {
 id: root
 property bool connected:false
 property real depthM:NaN
 property real waterTempC:NaN
 property real speedMps:NaN
 property real latitude:NaN
 property real longitude:NaN
 property var echoSamples:[]
 property var fishHotspots:[]
 property var transport:null
 property var history:[]
 property int historyColumns:180
 property real gain:1.0
 property real noiseFloor:0.10
 property real surfaceBlankM:0.30
 property bool fishIcons:true
 property bool showRawTrace:false
 signal saveWaypointRequested(real latitude,real longitude,real depthM,real waterTempC)
 function pushHistory(){if(!echoSamples||!echoSamples.length)return;var h=history.slice(0);h.push(echoSamples.slice(0));while(h.length>historyColumns)h.shift();history=h}
 function palette(v){v=Math.max(0,Math.min(1,v));if(v<.22)return "rgba(16,92,170,"+(0.25+v*2)+")";if(v<.48)return "rgba(28,205,225,"+(0.45+v)+")";if(v<.72)return "rgba(246,218,70,"+(0.55+v*.5)+")";return "rgba(244,75,46,"+(0.65+v*.35)+")"}
 modal:true;focus:true;closePolicy:Popup.CloseOnEscape;padding:0
 background:Rectangle{color:"#03101a";border.color:"#21b7ff"}
 contentItem:ColumnLayout{
  spacing:6
  RowLayout{Layout.fillWidth:true;Layout.margins:10
   Label{text:"KOGGER BASIC 2D • SONAR LIVE";color:"white";font.pixelSize:20;font.bold:true}
   Label{text:root.connected?"● LIVE":"● FĂRĂ DATE";color:root.connected?"#31d67b":"#9db2c5"}
   Item{Layout.fillWidth:true}
   Label{text:isNaN(root.depthM)?"-- m":root.depthM.toFixed(1)+" m";color:"#21b7ff";font.pixelSize:28;font.bold:true}
   Label{text:isNaN(root.waterTempC)?"-- °C":root.waterTempC.toFixed(1)+" °C";color:"white";font.pixelSize:20}
   Button{text:"ÎNCHIDE";onClicked:root.close()}
  }
  RowLayout{Layout.fillWidth:true;Layout.leftMargin:10;Layout.rightMargin:10
   Label{text:"SENSIBILITATE";color:"#9db2c5"}
   Slider{id:gainSlider;from:.5;to:2.2;value:root.gain;stepSize:.05;Layout.preferredWidth:170;onMoved:root.gain=value}
   Label{text:Math.round(root.gain*100)+"%";color:"white";Layout.preferredWidth:45}
   Label{text:"FILTRU ZGOMOT";color:"#9db2c5"}
   Slider{id:noiseSlider;from:0;to:.35;value:root.noiseFloor;stepSize:.01;Layout.preferredWidth:140;onMoved:root.noiseFloor=value}
   Button{text:root.fishIcons?"🐟 PEȘTI ON":"PEȘTI OFF";checkable:true;checked:root.fishIcons;onClicked:root.fishIcons=checked}
   Button{text:root.showRawTrace?"ECOU BRUT ON":"ECOU BRUT";checkable:true;checked:root.showRawTrace;onClicked:root.showRawTrace=checked}
   Item{Layout.fillWidth:true}
  }
  Rectangle{Layout.fillWidth:true;Layout.fillHeight:true;color:"#020b12"
   Repeater{model:5;Label{anchors.left:parent.left;anchors.leftMargin:8;y:index*(parent.height/4)-height/2;text:(index===0?"0.0":(!isNaN(root.depthM)?(root.depthM*index/4).toFixed(1):"--"))+" m";color:"#d9edf7";z:3}}
   Canvas{id:echogram;anchors.fill:parent
    onPaint:{
     var ctx=getContext("2d");ctx.reset();ctx.fillStyle="#020b12";ctx.fillRect(0,0,width,height)
     ctx.strokeStyle="#18364a";ctx.lineWidth=1;for(var g=1;g<5;g++){var gy=g*height/5;ctx.beginPath();ctx.moveTo(0,gy);ctx.lineTo(width,gy);ctx.stroke()}
     if(root.history&&root.history.length){var cw=width/root.historyColumns;for(var hx=0;hx<root.history.length;hx++){var col=root.history[hx],px=width-(root.history.length-hx)*cw;for(var hy=0;hy<col.length;hy++){var d=!isNaN(root.depthM)?hy*root.depthM/col.length:0;if(d<root.surfaceBlankM)continue;var v=Math.max(0,Math.min(1,(Number(col[hy])-root.noiseFloor)*root.gain));if(v<=0)continue;ctx.fillStyle=root.palette(v);ctx.fillRect(px,hy*height/col.length,Math.max(1,cw+0.5),Math.max(1,height/col.length+0.7))}}}
     if(root.showRawTrace&&root.echoSamples&&root.echoSamples.length>1){ctx.strokeStyle="#f2f7fb";ctx.lineWidth=1;ctx.beginPath();for(var i=0;i<root.echoSamples.length;i++){var x=i*width/(root.echoSamples.length-1),y=height-Math.max(0,Math.min(1,root.echoSamples[i]))*height;if(i===0)ctx.moveTo(x,y);else ctx.lineTo(x,y)}ctx.stroke()}
     if(root.fishIcons&&root.fishHotspots){ctx.font="bold 18px sans-serif";ctx.fillStyle="#f2f7fb";for(var f=0;f<root.fishHotspots.length;f++){var h=root.fishHotspots[f];if(!isNaN(root.depthM)&&root.depthM>0){var fy=Math.max(18,Math.min(height-8,h.minTargetDepth/root.depthM*height));ctx.fillText("🐟"+(h.count>1?h.count:""),width-70,fy)}}}
     if(!isNaN(root.depthM)&&root.depthM>0){var by=height-2;ctx.strokeStyle="#ffcc4d";ctx.lineWidth=2;ctx.beginPath();ctx.moveTo(0,by);ctx.lineTo(width,by);ctx.stroke()}
    }
    Connections{target:root;function onEchoSamplesChanged(){root.pushHistory();echogram.requestPaint()}function onGainChanged(){echogram.requestPaint()}function onNoiseFloorChanged(){echogram.requestPaint()}function onFishIconsChanged(){echogram.requestPaint()}function onShowRawTraceChanged(){echogram.requestPaint()}}
   }
   Label{anchors.centerIn:parent;visible:!root.connected;text:"Aștept date reale de la Kogger\nEcograma nu este simulată";horizontalAlignment:Text.AlignHCenter;color:"#9db2c5";font.pixelSize:18}
  }
  RowLayout{Layout.fillWidth:true;Layout.margins:10
   Label{text:"Viteză: "+(isNaN(root.speedMps)?"--":(root.speedMps*3.6).toFixed(1)+" km/h");color:"#9db2c5"}
   Label{text:"GPS: "+(isNaN(root.latitude)?"--":root.latitude.toFixed(6)+", "+root.longitude.toFixed(6));color:"#9db2c5"}
   Label{visible:root.transport;text:root.transport?(root.transport.status+" • RX "+root.transport.rxBytes+" B / "+root.transport.rxChunks):"";color:root.transport&&root.transport.connected?"#31d67b":"#9db2c5"}
   Item{Layout.fillWidth:true}
   Button{visible:root.transport;text:root.transport&&root.transport.connected?"DECONECTEAZĂ":"CONECTEAZĂ KOGGER";onClicked:{if(root.transport.connected)root.transport.disconnectFromSonar();else root.transport.connectToSonar()}}
   Button{text:"SALVEAZĂ PUNCT";enabled:root.connected&&!isNaN(root.latitude)&&!isNaN(root.longitude)&&!isNaN(root.depthM);onClicked:root.saveWaypointRequested(root.latitude,root.longitude,root.depthM,root.waterTempC)}
  }
 }
}