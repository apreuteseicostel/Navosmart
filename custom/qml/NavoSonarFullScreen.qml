import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import NavoSmart.Backend 1.0
Popup {
 id: root
 property bool menuOpen:false
 property bool mapEnabled:false
 signal mapToggled(bool enabled)
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
 property string paletteMode:"NAVO"
 property bool noiseFilter:true
 property bool paused:false
 property bool recording:false
 component SonarIconButton: Button { width:38; height:38; padding:0; property string hint:""; ToolTip.visible:hovered; ToolTip.text:hint; background:Rectangle{radius:7;color:parent.checked?"#123d50":"#101b25";border.color:parent.checked?"#21b7ff":"#31404d"} }
 property var bottomStrengthHistory:[]
 property var bottomDepthHistory:[]
 readonly property real bottomEchoStrength: bottomStrengthHistory.length?Number(bottomStrengthHistory[bottomStrengthHistory.length-1]):NaN
 readonly property real bottomHardnessPercent: isNaN(bottomEchoStrength)?NaN:Math.max(0,Math.min(100,((bottomEchoStrength-noiseFloor)*gain)*100))
 signal saveWaypointRequested(real latitude,real longitude,real depthM,real waterTempC)
 signal recordingRequested(bool start)
 function pushHistory(){if(root.paused||!echoSamples||!echoSamples.length)return;var h=history.slice(0);h.push({samples:echoSamples.slice(0),depth:depthM});while(h.length>historyColumns)h.shift();history=h;var n=Math.max(3,Math.floor(echoSamples.length*0.10)),sum=0,cnt=0;for(var i=Math.max(0,echoSamples.length-n);i<echoSamples.length;i++){sum+=Number(echoSamples[i]);cnt++}var b=bottomStrengthHistory.slice(0);b.push(cnt?sum/cnt:0);while(b.length>historyColumns)b.shift();bottomStrengthHistory=b;var bd=bottomDepthHistory.slice(0);bd.push(depthM);while(bd.length>historyColumns)bd.shift();bottomDepthHistory=bd}
 function bottomColor(v){v=Math.max(0,Math.min(1,(v-root.noiseFloor)*root.gain));if(root.paletteMode==="DAY"){if(v>.72)return "#ffe44d";if(v>.42)return "#ef493d";return "#245fa8"}if(v>.78)return "#fff36a";if(v>.60)return "#f33b2f";if(v>.40)return "#ff8b28";if(v>.22)return "#55c85a";return "#1767a7"}
 function palette(v){v=Math.max(0,Math.min(1,v));if(root.paletteMode==="DAY"){if(v<.18)return "rgba(220,238,248,"+(0.30+v*2)+")";if(v<.42)return "rgba(48,150,205,"+(0.45+v)+")";if(v<.68)return "rgba(245,202,55,"+(0.60+v*.45)+")";return "rgba(215,55,38,"+(0.72+v*.28)+")"}if(v<.22)return "rgba(16,92,170,"+(0.25+v*2)+")";if(v<.48)return "rgba(28,205,225,"+(0.45+v)+")";if(v<.72)return "rgba(246,218,70,"+(0.55+v*.5)+")";return "rgba(244,75,46,"+(0.65+v*.35)+")"}
 modal:true;focus:true;visible:false;closePolicy:Popup.CloseOnEscape;padding:0
 width: parent ? Math.max(320,parent.width-8) : 960
 height: parent ? Math.max(320,parent.height-8) : 640
 anchors.centerIn: parent
 background:Rectangle{color:"#03101a";border.color:"#21b7ff"}
 // Close control is anchored to the popup itself so it can never be pushed off-screen by header content.
 Button{id:closeButton;z:10000;anchors.top:parent.top;anchors.right:parent.right;anchors.topMargin:8;anchors.rightMargin:8;width:46;height:46;flat:true;ToolTip.visible:hovered;ToolTip.text:"Închide sonar";contentItem:Label{text:"×";color:"white";font.pixelSize:32;font.bold:true;horizontalAlignment:Text.AlignHCenter;verticalAlignment:Text.AlignVCenter}onClicked:root.close()}
 contentItem:ColumnLayout{
  anchors.fill:parent
  spacing:3
  RowLayout{Layout.fillWidth:true;Layout.leftMargin:6;Layout.rightMargin:6;Layout.topMargin:4;Layout.bottomMargin:2
   Label{text:"KOGGER BASIC 2D • SONAR LIVE";color:"white";font.pixelSize:Math.max(14,Math.min(20,root.width/48));font.bold:true;Layout.maximumWidth:Math.max(180,root.width*0.48);elide:Text.ElideRight}
   Label{text:root.connected?"● LIVE":"● FĂRĂ DATE";color:root.connected?"#31d67b":"#9db2c5"}
   Item{Layout.fillWidth:true}
   Label{text:isNaN(root.depthM)?"-- m":root.depthM.toFixed(1)+" m";color:"#21b7ff";font.pixelSize:28;font.bold:true}
   Label{text:isNaN(root.waterTempC)?"-- °C":root.waterTempC.toFixed(1)+" °C";color:"white";font.pixelSize:20;Layout.rightMargin:52}
  }
  RowLayout{Layout.fillWidth:true;Layout.fillHeight:true;Layout.minimumHeight:180;Layout.leftMargin:2;Layout.rightMargin:2;Layout.bottomMargin:2;spacing:4
  Rectangle{Layout.fillWidth:true;Layout.fillHeight:true;Layout.minimumWidth:0;Layout.preferredWidth:Math.max(180,root.width-92);color:"#020b12"

   // Overlay controls: the sonar canvas retains the entire available height.
   Button { id:menuButton; z:30; anchors.left:parent.left;anchors.top:parent.top;anchors.margins:8;width:42;height:42
     text:root.menuOpen?"‹":"☰";ToolTip.visible:hovered;ToolTip.text:"Controale Sonar PRO"
     background:Rectangle{radius:7;color:"#b3101e2b";border.color:"#41647a"}
     contentItem:Label{text:menuButton.text;color:"#ffffff";font.pixelSize:23;horizontalAlignment:Text.AlignHCenter;verticalAlignment:Text.AlignVCenter}
     onClicked:root.menuOpen=!root.menuOpen
   }
   Rectangle {id:controlsOverlay;z:29;visible:root.menuOpen;anchors.left:parent.left;anchors.top:menuButton.bottom;anchors.topMargin:4;width:Math.min(265,parent.width*0.48);height:Math.min(parent.height-menuButton.height-12,controlsScroll.contentHeight+12);radius:8;color:"#ee0b1b29";border.color:"#42647a"
     ScrollView{id:controlsScroll;anchors.fill:parent;anchors.margins:6;clip:true;ScrollBar.horizontal.policy:ScrollBar.AlwaysOff
       ColumnLayout{width:controlsScroll.availableWidth;spacing:4
         Button{text:root.mapEnabled?"▣ Hartă: ON":"▧ Hartă: OFF";Layout.fillWidth:true;onClicked:{root.mapEnabled=!root.mapEnabled;root.mapToggled(root.mapEnabled)}}
         Label{text:"Sensibilitate  "+Math.round(root.gain*100)+"%";color:"white"}
         Slider{from:.5;to:2.2;value:root.gain;stepSize:.05;Layout.fillWidth:true;onMoved:root.gain=value}
         CheckBox{text:"Filtru zgomot";checked:root.noiseFilter;onToggled:root.noiseFilter=checked}
         Label{text:"Prag zgomot  "+Math.round(root.noiseFloor*100)+"%";color:"white"}
         Slider{from:0;to:.35;value:root.noiseFloor;stepSize:.01;enabled:root.noiseFilter;Layout.fillWidth:true;onMoved:root.noiseFloor=value}
         CheckBox{text:"Marcaje pești";checked:root.fishIcons;onToggled:root.fishIcons=checked}
         CheckBox{text:"Ecou brut";checked:root.showRawTrace;onToggled:root.showRawTrace=checked}
         ComboBox{model:["NAVO","DAY"];currentIndex:root.paletteMode==="NAVO"?0:1;Layout.fillWidth:true;onActivated:function(i){root.paletteMode=model[i]}}
         Button{text:root.paused?"▶ Continuă":"Ⅱ Pauză";Layout.fillWidth:true;onClicked:root.paused=!root.paused}
         Button{text:root.recording?"■ Oprește înregistrarea":"● Înregistrează";Layout.fillWidth:true;onClicked:{root.recording=!root.recording;root.recordingRequested(root.recording)}}
         Button{text:"◎ Salvează punct";Layout.fillWidth:true;enabled:root.connected&&isFinite(root.latitude)&&isFinite(root.longitude)&&isFinite(root.depthM);onClicked:root.saveWaypointRequested(root.latitude,root.longitude,root.depthM,root.waterTempC)}
         Button{visible:root.transport!==null;text:root.transport&&root.transport.connected?"Deconectează Kogger":"Conectează Kogger";Layout.fillWidth:true;onClicked:{if(root.transport){if(root.transport.connected)root.transport.disconnectFromSonar();else root.transport.connectToSonar()}}}
       }
     }
   }
   Canvas{id:echogram;anchors.fill:parent
    onPaint:{
     var ctx=getContext("2d");ctx.reset();ctx.fillStyle="#020b12";ctx.fillRect(0,0,width,height)
     ctx.strokeStyle="#18364a";ctx.lineWidth=1;for(var g=1;g<5;g++){var gy=g*height/5;ctx.beginPath();ctx.moveTo(0,gy);ctx.lineTo(width,gy);ctx.stroke()}
     if(root.history&&root.history.length){var cw=width/root.historyColumns;for(var hx=0;hx<root.history.length;hx++){var entry=root.history[hx],col=entry.samples||entry,historyDepth=entry.depth,px=width-(root.history.length-hx)*cw;for(var hy=0;hy<col.length;hy++){var d=!isNaN(historyDepth)?hy*historyDepth/col.length:0;if(d<root.surfaceBlankM)continue;var v=Math.max(0,Math.min(1,(Number(col[hy])-(root.noiseFilter?root.noiseFloor:0))*root.gain));if(v<=0)continue;ctx.fillStyle=root.palette(v);ctx.fillRect(px,hy*height/col.length,Math.max(1,cw+0.5),Math.max(1,height/col.length+0.7))}}}
     if(root.showRawTrace&&root.echoSamples&&root.echoSamples.length>1){ctx.strokeStyle="#f2f7fb";ctx.lineWidth=1;ctx.beginPath();for(var i=0;i<root.echoSamples.length;i++){var x=i*width/(root.echoSamples.length-1),y=height-Math.max(0,Math.min(1,root.echoSamples[i]))*height;if(i===0)ctx.moveTo(x,y);else ctx.lineTo(x,y)}ctx.stroke()}
     if(root.fishIcons&&root.fishHotspots){ctx.font="bold 18px sans-serif";ctx.fillStyle="#f2f7fb";for(var f=0;f<root.fishHotspots.length;f++){var h=root.fishHotspots[f];if(!isNaN(root.depthM)&&root.depthM>0){var fy=Math.max(18,Math.min(height-8,h.minTargetDepth/root.depthM*height));ctx.fillText("F"+(h.count>1?h.count:""),width-70,fy)}}}
     if(root.bottomDepthHistory.length){var bcw=width/root.historyColumns,maxD=0;for(var md=0;md<root.bottomDepthHistory.length;md++)if(isFinite(root.bottomDepthHistory[md]))maxD=Math.max(maxD,root.bottomDepthHistory[md]);if(maxD>0){ctx.beginPath();for(var bx=0;bx<root.bottomDepthHistory.length;bx++){var dep=Number(root.bottomDepthHistory[bx]);if(!isFinite(dep))continue;var bpx=width-(root.bottomDepthHistory.length-bx)*bcw,by=Math.min(height-1,(dep/maxD)*height);if(bx===0)ctx.moveTo(bpx,by);else ctx.lineTo(bpx,by)}ctx.lineTo(width,height);ctx.lineTo(Math.max(0,width-root.bottomDepthHistory.length*bcw),height);ctx.closePath();var bv=root.bottomEchoStrength;ctx.fillStyle=root.bottomColor(isNaN(bv)?0:bv);ctx.globalAlpha=.72;ctx.fill();ctx.globalAlpha=1}}}
    }
    Connections{target:root;function onEchoSamplesChanged(){root.pushHistory();echogram.requestPaint()}function onNoiseFilterChanged(){echogram.requestPaint()}function onGainChanged(){echogram.requestPaint()}function onNoiseFloorChanged(){echogram.requestPaint()}function onFishIconsChanged(){echogram.requestPaint()}function onShowRawTraceChanged(){echogram.requestPaint()}function onPaletteModeChanged(){echogram.requestPaint()}}
   }
   Repeater{model:5;Label{z:12;anchors.right:parent.right;anchors.rightMargin:8;y:Math.max(0,Math.min(parent.height-height,index*(parent.height/4)-height/2));text:(index===0?"0.0":(isFinite(root.depthM)?(root.depthM*index/4).toFixed(1):"--"))+" m";color:"#e2f3ff";font.pixelSize:12}}
   Label{anchors.centerIn:parent;visible:!root.connected;text:"Aștept date reale de la Kogger\nEcograma nu este simulată";horizontalAlignment:Text.AlignHCenter;color:"#9db2c5";font.pixelSize:18}
  }
  Rectangle{Layout.preferredWidth:64;Layout.minimumWidth:64;Layout.maximumWidth:64;Layout.fillHeight:true;Layout.alignment:Qt.AlignRight;color:"#06131e";border.color:"#1c4262";radius:5;ToolTip.visible:legendMouse.containsMouse;ToolTip.text:"Putere ecou: puternic → slab"
   Label{id:echoStrong;anchors.top:parent.top;anchors.topMargin:5;anchors.horizontalCenter:parent.horizontalCenter;text:"PUTERNIC";color:"#d9edf7";font.pixelSize:8;font.bold:true}
   Rectangle{id:echoScale;anchors.top:echoStrong.bottom;anchors.topMargin:4;anchors.bottom:echoWeak.top;anchors.bottomMargin:4;anchors.horizontalCenter:parent.horizontalCenter;width:24;radius:3;gradient:Gradient{GradientStop{position:0;color:"#f44b2e"}GradientStop{position:.28;color:"#f6da46"}GradientStop{position:.52;color:"#32d26f"}GradientStop{position:.75;color:"#1ccde1"}GradientStop{position:1;color:"#105caa"}}}
   Label{id:echoWeak;anchors.bottom:echoLabel.top;anchors.bottomMargin:2;anchors.horizontalCenter:parent.horizontalCenter;text:"SLAB";color:"#9db2c5";font.pixelSize:8;font.bold:true}
   Label{id:echoLabel;anchors.bottom:parent.bottom;anchors.bottomMargin:5;anchors.horizontalCenter:parent.horizontalCenter;text:"ECOU";color:"#21b7ff";font.pixelSize:9;font.bold:true}
   MouseArea{id:legendMouse;anchors.fill:parent;hoverEnabled:true}
  }

  Rectangle{visible:false;Layout.preferredWidth:0;Layout.minimumWidth:0;Layout.maximumWidth:0;Layout.fillHeight:true;color:"#06131e";border.color:"#1c4262";radius:8
   ColumnLayout{anchors.fill:parent;anchors.margins:10;spacing:8
    Label{text:"ADÂNCIME";color:"#9db2c5"} Label{text:isNaN(root.depthM)?"-- m":root.depthM.toFixed(1)+" m";color:"#f2f7fb";font.pixelSize:30;font.bold:true}
    Rectangle{Layout.fillWidth:true;height:1;color:"#17364a"}
    Label{text:"TEMPERATURA APĂ";color:"#9db2c5"} Label{text:isNaN(root.waterTempC)?"-- °C":root.waterTempC.toFixed(1)+" °C";color:"#f2f7fb";font.pixelSize:22}
    Label{text:"VITEZĂ NAVĂ";color:"#9db2c5"} Label{text:isNaN(root.speedMps)?"--":(root.speedMps*3.6).toFixed(1)+" km/h";color:"#f2f7fb";font.pixelSize:20}
    Label{text:"COORDONATE GPS";color:"#9db2c5"} Label{text:isNaN(root.latitude)?"--":root.latitude.toFixed(6)+" N\n"+root.longitude.toFixed(6)+" E";color:"#d9edf7";font.pixelSize:14}
    Rectangle{Layout.fillWidth:true;height:1;color:"#17364a"}
    Label{text:"KOGGER BASIC";color:"#21b7ff";font.bold:true}
    Label{text:root.connected?"● Conectat":"● Fără date";color:root.connected?"#31d67b":"#9db2c5"}
    Label{text:"FUND (ecou relativ): "+(isNaN(root.bottomHardnessPercent)?"--":Math.round(root.bottomHardnessPercent)+"%");color:root.bottomColor(isNaN(root.bottomEchoStrength)?0:root.bottomEchoStrength);ToolTip.visible:bottomEchoMouse.containsMouse;ToolTip.text:"Estimare relativă din intensitatea ecoului; nu este o măsurare fizică a durității"}
    MouseArea{id:bottomEchoMouse;visible:false}
    Label{visible:root.transport;text:root.transport?"RX "+root.transport.rxBytes+" B / "+root.transport.rxChunks:"";color:"#9db2c5";font.pixelSize:12}
    Item{Layout.fillHeight:true}
    SonarIconButton { visible:root.transport; hint:root.transport&&root.transport.connected?"Deconectează Kogger":"Conectează Kogger"; contentItem:Image{anchors.centerIn:parent;width:22;height:22;source:"qrc:/qml/NavoSmart/icons/sonar.svg";fillMode:Image.PreserveAspectFit} onClicked:{if(root.transport.connected)root.transport.disconnectFromSonar();else root.transport.connectToSonar()} }
   }
  }
}
}
