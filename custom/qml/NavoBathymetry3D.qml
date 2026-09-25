import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick3D
import QtPositioning
import NavoSmart.Backend 1.0
Item {
 id:root
 property var samples:[]; property var boatTrack:[]; property var waypoints:[]; property var fishingSpots:[]; property var fishDetections:[]
 property real gridSizeM:2; property real maxGapM:6; property real verticalExaggeration:2; property real yaw:-35; property real pitch:-48; property real cameraDistance:180; property point panOffset:Qt.point(0,0)
 property var selectedPoint:null; property var selectedObject:null; property string selectedKind:""
 signal openSonarRequested()
 property bool showTrack:true; property bool showWaypoints:true; property bool showSpots:true; property bool showFish:true; property int maxTrackPoints3D:1200; property int maxFish3D:500
 readonly property int lodLevel: cameraDistance>500?3:cameraDistance>250?2:cameraDistance>110?1:0
 readonly property int adaptiveTrackLimit: lodLevel===3?180:lodLevel===2?350:lodLevel===1?700:maxTrackPoints3D
 readonly property int adaptiveFishLimit: lodLevel===3?60:lodLevel===2?140:lodLevel===1?280:maxFish3D
 property int cachedSampleCount:0
 property string cachedSampleSignature:""
 function sampleSignature(){
  if(!samples||!samples.length)return "0"
  var h=2166136261
  function mix(v){var s=String(v);for(var j=0;j<s.length;j++){h^=s.charCodeAt(j);h=Math.imul(h,16777619)}}
  mix(samples.length);mix(gridSizeM);mix(maxGapM);mix(lodLevel)
  for(var i=0;i<samples.length;i++){var s=samples[i];mix(s.lat);mix(s.lon);mix(s.depth);mix(s.time===undefined?s.timestamp:s.time);mix(s.confidence)}
  return String(h>>>0)
 }
 function rebuild(){meshEngine.buildCached(samples,gridSizeM,maxGapM,lodLevel);cachedSampleCount=samples.length;cachedSampleSignature=sampleSignature()}
 function refreshForSamples(){var sig=sampleSignature();if(sig!==cachedSampleSignature)rebuild()}
 function resetCamera(){yaw=-35;pitch=-48;cameraDistance=180;panOffset=Qt.point(0,0)} function topCamera(){yaw=0;pitch=-89;cameraDistance=180} function isoCamera(){yaw=-45;pitch=-42;cameraDistance=180}
 function localPoint(lat,lon,depth){var R=6378137,lat0=meshEngine.originLatitude*Math.PI/180,x=(lon-meshEngine.originLongitude)*Math.PI/180*Math.cos(lat0)*R,z=-(lat-meshEngine.originLatitude)*Math.PI/180*R,y=-(depth||0)*verticalExaggeration;return Qt.vector3d(x,y,z)}
 function bottomDepth(lat,lon){var best=null,bd=1e99,p=localPoint(lat,lon,0);for(var i=0;i<meshEngine.vertices.length;i++){var v=meshEngine.vertices[i],d=(v.x-p.x)*(v.x-p.x)+((-v.y)-p.z)*((-v.y)-p.z);if(d<bd){bd=d;best=v}}return best?best.depth:0}
 function decimate(a,max){if(!a||a.length<=max)return a||[];var out=[],step=(a.length-1)/(max-1);for(var i=0;i<max;i++)out.push(a[Math.round(i*step)]);return out}
 function trackLocal(){var a=decimate(boatTrack||[],adaptiveTrackLimit),o=[];for(var i=0;i<a.length;i++){var p=a[i],v=localPoint(p.latitude!==undefined?p.latitude:p.lat,p.longitude!==undefined?p.longitude:p.lon,0);o.push({x:v.x,y:v.y+.15,z:v.z})}return o}
 function labelPoint(o,kind){if(kind==="waypoint")return localPoint(o.lat!==undefined?o.lat:o.coordinate.latitude,o.lon!==undefined?o.lon:o.coordinate.longitude,Math.max(0,bottomDepth(o.lat!==undefined?o.lat:o.coordinate.latitude,o.lon!==undefined?o.lon:o.coordinate.longitude)-.7));return localPoint(o.lat,o.lon,Math.max(0,(o.depth!==null&&o.depth!==undefined?o.depth:bottomDepth(o.lat,o.lon))-.8))}
 function select(kind,obj){selectedKind=kind;selectedObject=obj;selectedPoint=null}
 function fmtTime(v){if(!v)return "--";return new Date(v).toLocaleString(Qt.locale(),"dd MMM yyyy HH:mm:ss")}
 NavoBathymetryMesh{id:meshEngine}
 Rectangle{anchors.fill:parent;color:"#071019"}
 View3D{id:view;anchors.fill:parent;camera:camera;environment:SceneEnvironment{clearColor:"#071019";backgroundMode:SceneEnvironment.Color;antialiasingMode:SceneEnvironment.MSAA;antialiasingQuality:SceneEnvironment.High}
  PerspectiveCamera{id:camera;position:Qt.vector3d(root.panOffset.x,65+root.panOffset.y,root.cameraDistance);eulerRotation.x:root.pitch;eulerRotation.y:root.yaw;clipNear:.1;clipFar:5000}
  DirectionalLight{eulerRotation.x:-45;eulerRotation.y:-35;brightness:1.15;castsShadow:true} DirectionalLight{eulerRotation.x:35;eulerRotation.y:145;brightness:.35}
  Model{id:terrain;pickable:true;geometry:NavoBathymetryGeometry{vertices:meshEngine.vertices;triangles:meshEngine.triangles;verticalExaggeration:root.verticalExaggeration;minDepth:meshEngine.minDepthM;maxDepth:meshEngine.maxDepthM}materials:PrincipledMaterial{vertexColorsEnabled:true;roughness:.72;cullMode:Material.NoCulling}}
  Node{id:overlayRoot
   Repeater3D{model:root.showWaypoints?root.waypoints:[];delegate:Model{id:wp;required property var modelData;property string kind:"waypoint";pickable:true;position:root.localPoint(modelData.lat!==undefined?modelData.lat:modelData.coordinate.latitude,modelData.lon!==undefined?modelData.lon:modelData.coordinate.longitude,Math.max(0,root.bottomDepth(modelData.lat!==undefined?modelData.lat:modelData.coordinate.latitude,modelData.lon!==undefined?modelData.lon:modelData.coordinate.longitude)-.7));source:"#Sphere";scale:Qt.vector3d(.8,.8,.8);materials:PrincipledMaterial{baseColor:"#ffd54f";emissiveFactor:Qt.vector3d(.25,.18,0)}}}
   Repeater3D{model:root.showSpots?root.fishingSpots:[];delegate:Model{id:spot;required property var modelData;property string kind:"spot";pickable:true;position:root.localPoint(modelData.lat,modelData.lon,Math.max(0,(modelData.depth!==null&&modelData.depth!==undefined?modelData.depth:root.bottomDepth(modelData.lat,modelData.lon))-.8));source:"#Cylinder";scale:Qt.vector3d(.45,1.4,.45);materials:PrincipledMaterial{baseColor:"#ff8a3d"}}}
   Repeater3D{model:root.showFish?root.decimate(root.fishDetections,root.adaptiveFishLimit):[];delegate:Model{id:fish;required property var modelData;property string kind:"fish";pickable:true;position:root.localPoint(modelData.lat,modelData.lon,modelData.targetDepth||0);source:"#Sphere";scale:Qt.vector3d(.38,.22,.65);materials:PrincipledMaterial{baseColor:(modelData.strength!==null&&modelData.strength>.65)?"#ff5252":"#67e480";emissiveFactor:Qt.vector3d(.15,.15,.15)}}}
   Model{visible:root.showTrack;geometry:NavoTrack3DGeometry{points:root.trackLocal();width:.38}materials:PrincipledMaterial{baseColor:"#21b7ff";emissiveFactor:Qt.vector3d(.1,.35,.5);cullMode:Material.NoCulling}}
  }
 }
 TapHandler{onTapped:function(e){var p=view.pick(e.position.x,e.position.y);if(!p.objectHit){selectedObject=null;selectedPoint=null;return}if(p.objectHit.kind){root.select(p.objectHit.kind,p.objectHit.modelData);return}if(p.objectHit===terrain){var best=null,bd=1e99;for(var i=0;i<meshEngine.vertices.length;i++){var v=meshEngine.vertices[i],dx=v.x-p.scenePosition.x,dz=(-v.y)-p.scenePosition.z,d=dx*dx+dz*dz;if(d<bd){bd=d;best=v}}selectedPoint=best;selectedObject=null;selectedKind="bottom"}}}
 DragHandler{target:null;acceptedButtons:Qt.LeftButton;onTranslationChanged:{root.yaw+=translation.x*.18;root.pitch=Math.max(-82,Math.min(-8,root.pitch-translation.y*.14))}} PinchHandler{target:null;onScaleChanged:root.cameraDistance=Math.max(12,Math.min(1800,root.cameraDistance/scale))} WheelHandler{onWheel:root.cameraDistance=Math.max(12,Math.min(1800,root.cameraDistance*(wheel.angleDelta.y > 0 ? 0.9 : 1.1)))}
 ColumnLayout{anchors{top:parent.top;left:parent.left;right:parent.right;margins:10}spacing:4
  Flow{Layout.fillWidth:true;spacing:5
   component Tool3D: Button { width:42;height:38;padding:0;property string hint:"";ToolTip.visible:hovered;ToolTip.text:hint;background:Rectangle{radius:7;color:parent.checked?"#123d50":"#101b25";border.color:parent.checked?"#21b7ff":"#31404d"} }
   Tool3D{hint:"Vedere de sus";contentItem:Canvas{anchors.fill:parent;onPaint:{var p=getContext("2d");p.reset();p.strokeStyle="#f2f7fb";p.lineWidth=2;p.strokeRect(11,9,20,20);p.beginPath();p.moveTo(21,5);p.lineTo(21,14);p.moveTo(17,10);p.lineTo(21,14);p.lineTo(25,10);p.stroke()}} onClicked:root.topCamera()}
   Tool3D{hint:"Vedere izometrică";contentItem:Canvas{anchors.fill:parent;onPaint:{var p=getContext("2d");p.reset();p.strokeStyle="#f2f7fb";p.lineWidth=2;p.beginPath();p.moveTo(21,6);p.lineTo(34,13);p.lineTo(34,27);p.lineTo(21,34);p.lineTo(8,27);p.lineTo(8,13);p.closePath();p.moveTo(8,13);p.lineTo(21,20);p.lineTo(34,13);p.moveTo(21,20);p.lineTo(21,34);p.stroke()}} onClicked:root.isoCamera()}
   Tool3D{hint:"Resetează camera";contentItem:Canvas{anchors.fill:parent;onPaint:{var p=getContext("2d");p.reset();p.strokeStyle="#f2f7fb";p.lineWidth=2;p.beginPath();p.arc(21,20,11,.4,5.5);p.stroke();p.beginPath();p.moveTo(29,7);p.lineTo(34,13);p.lineTo(26,14);p.stroke()}} onClicked:root.resetCamera()}
   Repeater{model:[1,2,3,5];delegate:Tool3D{required property var modelData;hint:"Exagerare verticală "+modelData+"x";checkable:true;checked:root.verticalExaggeration===modelData;contentItem:Label{text:modelData+"x";color:parent.checked?"#21b7ff":"#f2f7fb";font.bold:true;horizontalAlignment:Text.AlignHCenter;verticalAlignment:Text.AlignVCenter} onClicked:root.verticalExaggeration=modelData}}
   Tool3D{hint:"Traseu barcă";checkable:true;checked:root.showTrack;contentItem:Canvas{anchors.fill:parent;onPaint:{var p=getContext("2d");p.reset();p.strokeStyle=parent.checked?"#21b7ff":"#f2f7fb";p.lineWidth=2;p.beginPath();p.moveTo(7,29);p.bezierCurveTo(13,7,29,35,36,11);p.stroke()}} onClicked:root.showTrack=checked}
   Tool3D{hint:"Waypoint-uri";checkable:true;checked:root.showWaypoints;contentItem:Label{text:"WP";color:parent.checked?"#21b7ff":"#f2f7fb";font.bold:true;horizontalAlignment:Text.AlignHCenter;verticalAlignment:Text.AlignVCenter} onClicked:root.showWaypoints=checked}
   Tool3D{hint:"Locuri de pescuit";checkable:true;checked:root.showSpots;contentItem:Canvas{anchors.fill:parent;onPaint:{var p=getContext("2d");p.reset();p.strokeStyle=parent.checked?"#21b7ff":"#f2f7fb";p.fillStyle=p.strokeStyle;p.lineWidth=2;p.beginPath();p.arc(21,15,6,0,Math.PI*2);p.stroke();p.beginPath();p.moveTo(21,34);p.lineTo(14,19);p.lineTo(28,19);p.closePath();p.stroke();p.beginPath();p.arc(21,15,2,0,Math.PI*2);p.fill()}} onClicked:root.showSpots=checked}
   Tool3D{hint:"Detecții pești";checkable:true;checked:root.showFish;contentItem:Canvas{anchors.fill:parent;onPaint:{var p=getContext("2d");p.reset();p.strokeStyle=parent.checked?"#21b7ff":"#f2f7fb";p.lineWidth=2;p.beginPath();p.ellipse(9,12,19,13);p.moveTo(28,18);p.lineTo(36,12);p.lineTo(36,25);p.closePath();p.stroke();p.beginPath();p.arc(14,18,1.3,0,Math.PI*2);p.fillStyle=p.strokeStyle;p.fill()}} onClicked:root.showFish=checked}
  }
 }
 Rectangle{visible:!root.samples||root.samples.length===0;anchors.centerIn:parent;width:Math.min(parent.width-24,430);height:empty3d.implicitHeight+32;radius:10;color:"#102232";border.color:"#315b75"
  ColumnLayout{id:empty3d;anchors.centerIn:parent;width:parent.width-24;spacing:8
   Label{Layout.fillWidth:true;text:"Nu există încă măsurători 3D";color:"white";font.bold:true;horizontalAlignment:Text.AlignHCenter}
   Label{Layout.fillWidth:true;text:"Conectează Kogger și salvează probe sonar cu poziție GPS pentru a construi fundul bălții.";color:"#9db2c5";wrapMode:Text.WordWrap;horizontalAlignment:Text.AlignHCenter}
   ToolButton{Layout.alignment:Qt.AlignHCenter;width:44;height:40;ToolTip.visible:hovered;ToolTip.text:"Deschide sonar";contentItem:Canvas{anchors.fill:parent;onPaint:{var p=getContext("2d");p.reset();p.strokeStyle="#21b7ff";p.lineWidth=2;for(var r=5;r<=14;r+=4){p.beginPath();p.arc(width/2,height/2,r,-.75,.75);p.stroke()}p.fillStyle="#21b7ff";p.beginPath();p.arc(width/2-5,height/2,3,0,Math.PI*2);p.fill()}} onClicked:root.openSonarRequested()}
  }
 }
 Rectangle{visible:root.selectedObject!==null||root.selectedPoint!==null;anchors{left:parent.left;bottom:parent.bottom;margins:12}width:310;height:details.implicitHeight+24;radius:8;color:"#d9101c29";border.color:"#45677e"
  Column{id:details;anchors{left:parent.left;right:parent.right;top:parent.top;margins:12}spacing:4
   Text{color:"white";font.bold:true;text:selectedKind==="waypoint"?"Waypoint: "+(selectedObject?(selectedObject.name||selectedObject.friendlyName||"WP"):""):selectedKind==="spot"?"Loc pescuit: "+(selectedObject?(selectedObject.name||""):""):selectedKind==="fish"?"Detecție pește":"Fund lac"}
   Text{color:"white";text:selectedKind==="fish"&&selectedObject?"Adâncime pește: "+Number(selectedObject.targetDepth).toFixed(2)+" m":selectedObject&&selectedObject.depth!==undefined&&selectedObject.depth!==null?"Adâncime: "+Number(selectedObject.depth).toFixed(2)+" m":selectedPoint?"Adâncime: "+Number(selectedPoint.depth).toFixed(2)+" m":""}
   Text{color:"white";visible:selectedObject&&selectedObject.temp!==undefined&&selectedObject.temp!==null;text:visible?"Temperatură: "+Number(selectedObject.temp).toFixed(1)+" °C":""}
   Text{color:"white";visible:selectedObject&&(selectedObject.time||selectedObject.createdAt);text:visible?"Timp: "+root.fmtTime(selectedObject.time||selectedObject.createdAt):""}
   Text{color:"white";visible:selectedPoint!==null;text:visible?(selectedPoint.measured?"Măsurat":"Interpolat")+" • confidence "+Math.round(selectedPoint.confidence*100)+"%":""}
   Text{color:"white";visible:selectedObject&&selectedObject.strength!==undefined&&selectedObject.strength!==null;text:visible?"Intensitate sonar: "+Number(selectedObject.strength).toFixed(2):""}
  }}
 Column{anchors{right:parent.right;bottom:parent.bottom;margins:12}spacing:5;Rectangle{width:180;height:18;gradient:Gradient{orientation:Gradient.Horizontal;GradientStop{position:0;color:"#0db8c7"}GradientStop{position:.5;color:"#0a3d9e"}GradientStop{position:1;color:"#330a61"}}}Text{color:"white";text:Number(meshEngine.minDepthM).toFixed(1)+" m                         "+Number(meshEngine.maxDepthM).toFixed(1)+" m"}Text{color:"white";text:meshEngine.measuredVertexCount+" măsurate • "+meshEngine.interpolatedVertexCount+" interpolate • LOD "+root.lodLevel}}
 Timer{id:lodDebounce;interval:220;repeat:false;onTriggered:if(samples.length)root.rebuild()}
 Timer{id:sampleDebounce;interval:650;repeat:false;onTriggered:if(samples.length)root.refreshForSamples()}
 onLodLevelChanged:if(samples.length)lodDebounce.restart()
 Component.onCompleted:{if(samples.length)rebuild()}
 onSamplesChanged:{if(samples.length)sampleDebounce.restart();else{sampleDebounce.stop();meshEngine.clear();cachedSampleSignature=""}}
}
