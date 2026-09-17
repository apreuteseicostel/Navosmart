import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
 id:root; property var controller; property var waypoint; property string waypointName: waypoint?"WP"+waypoint.sequenceNumber:"Niciun punct"; property int selectedHopper:1
 signal startConfirmed(var waypoint,string name,int hopper); signal abortRequested()
 color:"#0b1c2eee"; border.color:"#21b7ff"; radius:10; width:330; implicitHeight:content.implicitHeight+24
 ColumnLayout {
  id:content; anchors.fill:parent; anchors.margins:12; spacing:7
  Label{text:"NĂDIRE SILENȚIOASĂ";color:"white";font.bold:true;font.pixelSize:15}
  Label{text:root.waypointName;color:"#21b7ff";font.bold:true}
  RowLayout{Layout.fillWidth:true;Label{text:"Cuva";color:"#9db2c5"};ComboBox{id:hopperBox;Layout.fillWidth:true;model:["Stânga","Dreapta","Ambele","Fără eliberare"];onCurrentIndexChanged:root.selectedHopper=currentIndex===0?1:(currentIndex===1?2:(currentIndex===2?3:0))}}
  GridLayout {
   columns:3; Layout.fillWidth:true
   Label{text:"Zonă silent";color:"#9db2c5"};SpinBox{id:silentR;from:3;to:30;value:controller?Math.round(controller.silentRadiusM):10;onValueModified:if(controller)controller.silentRadiusM=value};Label{text:"m";color:"white"}
   Label{text:"Zonă finală";color:"#9db2c5"};SpinBox{id:finalR;from:1;to:10;value:controller?Math.round(controller.finalRadiusM):3;onValueModified:if(controller)controller.finalRadiusM=value};Label{text:"m";color:"white"}
   Label{text:"Viteză silent";color:"#9db2c5"};SpinBox{id:silentV;from:2;to:15;value:controller?Math.round(controller.silentSpeedMps*10):8;onValueModified:if(controller)controller.silentSpeedMps=value/10.0};Label{text:(silentV.value/10).toFixed(1)+" m/s";color:"white"}
   Label{text:"Viteză finală";color:"#9db2c5"};SpinBox{id:finalV;from:1;to:10;value:controller?Math.round(controller.finalSpeedMps*10):4;onValueModified:if(controller)controller.finalSpeedMps=value/10.0};Label{text:(finalV.value/10).toFixed(1)+" m/s";color:"white"}
   Label{text:"Accelerație";color:"#9db2c5"};SpinBox{id:accel;from:1;to:10;value:controller?Math.round(controller.accelerationMps2*10):4;onValueModified:if(controller)controller.accelerationMps2=value/10.0};Label{text:(accel.value/10).toFixed(1)+" m/s²";color:"white"}
   Label{text:"Decelerație";color:"#9db2c5"};SpinBox{id:decel;from:1;to:12;value:controller?Math.round(controller.decelerationMps2*10):5;onValueModified:if(controller)controller.decelerationMps2=value/10.0};Label{text:(decel.value/10).toFixed(1)+" m/s²";color:"white"}
   Label{text:"Ieșire";color:"#9db2c5"};SpinBox{id:exitD;from:2;to:10;value:controller?Math.round(controller.exitDistanceM):4;onValueModified:if(controller)controller.exitDistanceM=value};Label{text:"m";color:"white"}
  }
  RowLayout{Layout.fillWidth:true;Label{text:"Ieșire după nădire";color:"#9db2c5"};ComboBox{Layout.fillWidth:true;model:["Dreapta","Stânga"];onCurrentIndexChanged:if(controller)controller.exitSide=currentIndex===0?1:-1}}
  CheckBox{text:"RTL după ieșirea din punct";checked:controller?controller.rtlAfterDrop:true;onToggled:if(controller)controller.rtlAfterDrop=checked}
  RowLayout {
   Layout.fillWidth:true
   Button{Layout.fillWidth:true;text:controller&&controller.enabled?"NĂDIRE ÎN CURS":"NĂDIRE AUTOMATĂ";enabled:root.waypoint&&controller&&!controller.enabled;onClicked:confirmDialog.open()}
   Button{text:"OPREȘTE";enabled:controller&&controller.enabled;onClicked:root.abortRequested()}
  }
  Label{Layout.fillWidth:true;wrapMode:Text.WordWrap;text:controller?"Stare: "+controller.stateText(controller.state):"";color:controller&&controller.enabled?"#31d67b":"#9db2c5";font.bold:controller&&controller.enabled}
 }
 Dialog {
  id:confirmDialog;modal:true;anchors.centerIn:Overlay.overlay;title:"Confirmă nădirea automată";standardButtons:Dialog.Yes|Dialog.No;closePolicy:Popup.NoAutoClose
  Label{width:400;wrapMode:Text.WordWrap;text:"Pornești ciclul către «"+root.waypointName+"»?\n\nCuva: "+hopperBox.currentText+"\nApropierea, oprirea, eliberarea, ieșirea laterală și RTL vor fi executate automat. Eliberarea este permisă numai după oprirea bărcii.\n\nTestează mai întâi pe uscat."}
  onAccepted:root.startConfirmed(root.waypoint,root.waypointName,root.selectedHopper)
 }
}
