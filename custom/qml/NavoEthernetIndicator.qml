import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
Rectangle {
 id:root
 property bool sonarConnected:false
 property bool sonarAlive:false
 property bool cameraConnected:false
 property bool cameraAlive:false
 property string sonarStatus:"OFFLINE"
 property string cameraStatus:"OFFLINE"
 readonly property bool lanUp: sonarConnected || cameraConnected
 radius:7;color:"#071827dd";border.color:lanUp?"#31d67b":"#1c4262"
 implicitWidth:250;implicitHeight:34
 RowLayout {
  anchors.fill:parent;anchors.leftMargin:9;anchors.rightMargin:9;spacing:8
  StatusDot{label:"LAN";ok:root.lanUp;alive:root.lanUp}
  Rectangle{width:1;Layout.fillHeight:true;Layout.topMargin:7;Layout.bottomMargin:7;color:"#1c4262"}
  StatusDot{label:"SONAR";ok:root.sonarConnected;alive:root.sonarAlive;tip:root.sonarStatus}
  StatusDot{label:"CAM";ok:root.cameraConnected;alive:root.cameraAlive;tip:root.cameraStatus}
 }
 component StatusDot:RowLayout{
  property string label:"";property bool ok:false;property bool alive:false;property string tip:""
  spacing:4
  Rectangle{width:8;height:8;radius:4;color:parent.alive?"#31d67b":(parent.ok?"#f0b429":"#667786")}
  Label{text:parent.label;color:parent.alive?"#f2f7fb":"#9db2c5";font.pixelSize:10;font.bold:true
   ToolTip.visible:ma.containsMouse;ToolTip.text:parent.tip.length?parent.tip:(parent.alive?"LIVE":(parent.ok?"CONECTAT":"OFFLINE"))
   MouseArea{id:ma;anchors.fill:parent;hoverEnabled:true}
  }
 }
}