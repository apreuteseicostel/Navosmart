import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick3D
import NavoSmart.Backend 1.0
Item {
 id:root; property var samples:[]; property real gridSizeM:2; property real maxGapM:6; property real verticalExaggeration:2; property real yaw:-35; property real pitch:-48; property real cameraDistance:180; property point panOffset:Qt.point(0,0); property var selectedPoint:null
 function rebuild(){meshEngine.build(samples,gridSizeM,maxGapM)}
 function resetCamera(){yaw=-35;pitch=-48;cameraDistance=180;panOffset=Qt.point(0,0)}
 function topCamera(){yaw=0;pitch=-89;cameraDistance=180}
 function isoCamera(){yaw=-45;pitch=-42;cameraDistance=180}
 NavoBathymetryMesh{id:meshEngine}
 Rectangle{anchors.fill:parent;color:"#071019"}
 View3D{id:view;anchors.fill:parent;environment:SceneEnvironment{clearColor:"#071019";backgroundMode:SceneEnvironment.Color;antialiasingMode:SceneEnvironment.MSAA;antialiasingQuality:SceneEnvironment.High}
  PerspectiveCamera{id:camera;position:Qt.vector3d(root.panOffset.x,65+root.panOffset.y,root.cameraDistance);eulerRotation.x:root.pitch;eulerRotation.y:root.yaw;clipNear:.1;clipFar:5000}
  DirectionalLight{eulerRotation.x:-45;eulerRotation.y:-35;brightness:1.15;castsShadow:true} DirectionalLight{eulerRotation.x:35;eulerRotation.y:145;brightness:.35}
  Model{id:terrain;pickable:true;geometry:NavoBathymetryGeometry{vertices:meshEngine.vertices;triangles:meshEngine.triangles;verticalExaggeration:root.verticalExaggeration;minDepth:meshEngine.minDepthM;maxDepth:meshEngine.maxDepthM}
   materials:PrincipledMaterial{vertexColorsEnabled:true;roughness:.72;metalness:0;cullMode:Material.NoCulling}}
 }
 TapHandler{onTapped:function(eventPoint){var p=view.pick(eventPoint.position.x,eventPoint.position.y);if(p.objectHit===terrain){var best=null,bd=1e99;for(var i=0;i<meshEngine.vertices.length;i++){var v=meshEngine.vertices[i],dx=v.x-p.scenePosition.x,dz=(-v.y)-p.scenePosition.z,d=dx*dx+dz*dz;if(d<bd){bd=d;best=v}}root.selectedPoint=best}}}
 DragHandler{target:null;acceptedButtons:Qt.LeftButton;onTranslationChanged:{root.yaw+=translation.x*.18;root.pitch=Math.max(-82,Math.min(-8,root.pitch-translation.y*.14))}}
 PinchHandler{target:null;onScaleChanged:root.cameraDistance=Math.max(12,Math.min(1800,root.cameraDistance/scale))}
 WheelHandler{onWheel:root.cameraDistance=Math.max(12,Math.min(1800,root.cameraDistance*(wheel.angleDelta.y>0?.9:1.1)))}
 Row{anchors{top:parent.top;left:parent.left;margins:12}spacing:6
  Button{text:"Top";onClicked:root.topCamera()} Button{text:"ISO";onClicked:root.isoCamera()} Button{text:"Reset";onClicked:root.resetCamera()}
  Button{text:"1×";onClicked:root.verticalExaggeration=1} Button{text:"2×";onClicked:root.verticalExaggeration=2} Button{text:"3×";onClicked:root.verticalExaggeration=3} Button{text:"5×";onClicked:root.verticalExaggeration=5}}
 Column{anchors{right:parent.right;bottom:parent.bottom;margins:12}spacing:5
  Rectangle{width:180;height:18;gradient:Gradient{orientation:Gradient.Horizontal;GradientStop{position:0;color:"#0db8c7"}GradientStop{position:.5;color:"#0a3d9e"}GradientStop{position:1;color:"#330a61"}}}
  Text{color:"white";text:Number(meshEngine.minDepthM).toFixed(1)+" m                         "+Number(meshEngine.maxDepthM).toFixed(1)+" m"}
  Text{color:"white";text:meshEngine.measuredVertexCount+" măsurate • "+meshEngine.interpolatedVertexCount+" interpolate"}
  Text{visible:root.selectedPoint!==null;color:"white";text:root.selectedPoint?("Punct: "+Number(root.selectedPoint.depth).toFixed(2)+" m • "+(root.selectedPoint.measured?"măsurat":"interpolat")+" • conf. "+Math.round(root.selectedPoint.confidence*100)+"%"):""}}
 Component.onCompleted:if(samples.length)rebuild();onSamplesChanged:if(samples.length)rebuild()
}