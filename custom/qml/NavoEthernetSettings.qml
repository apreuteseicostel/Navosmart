import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCore

Rectangle {
 id: root
 property var sonar
 property var camera
 signal status(string text)
 color:"#0b1c2e"; border.color:"#1c4262"; radius:10

 Settings {
  id: cfg
  category:"NavoEthernet"
  property string sonarHost:""
  property int sonarPort:0
  property bool sonarUdp:false
  property string cameraHost:""
  property int cameraPort:0
  property bool cameraUdp:false
 }
 function loadEndpoints(){
  if(sonar){sonar.host=cfg.sonarHost;sonar.port=cfg.sonarPort;sonar.udp=cfg.sonarUdp}
  if(camera){camera.host=cfg.cameraHost;camera.port=cfg.cameraPort;camera.udp=cfg.cameraUdp}
 }
 function saveEndpoints(){
  cfg.sonarHost=sonarHost.text.trim();cfg.sonarPort=parseInt(sonarPort.text)||0;cfg.sonarUdp=sonarUdp.checked
  cfg.cameraHost=cameraHost.text.trim();cfg.cameraPort=parseInt(cameraPort.text)||0;cfg.cameraUdp=cameraUdp.checked
  loadEndpoints();status("Setări Ethernet salvate")
 }
 Component.onCompleted:loadEndpoints()
 ColumnLayout {
  anchors.fill:parent;anchors.margins:14;spacing:10
  Label{text:"REȚEA BARCĂ • ETHERNET";color:"#21b7ff";font.bold:true;font.pixelSize:16}
  Label{Layout.fillWidth:true;wrapMode:Text.WordWrap;color:"#9db2c5";text:"IP-urile și porturile nu sunt presetate până la configurarea modulelor reale."}
  GroupBox {
   title:"Kogger Sonar";Layout.fillWidth:true
   GridLayout {columns:2;anchors.fill:parent
    Label{text:"IP / Host"}
    TextField{id:sonarHost;Layout.fillWidth:true;text:cfg.sonarHost;placeholderText:"ex. 192.168.x.x"}
    Label{text:"Port"}
    TextField{id:sonarPort;Layout.fillWidth:true;text:cfg.sonarPort>0?cfg.sonarPort.toString():"";inputMethodHints:Qt.ImhDigitsOnly}
    Label{text:"Transport"}
    CheckBox{id:sonarUdp;text:checked?"UDP":"TCP";checked:cfg.sonarUdp}
   }
  }
  GroupBox {
   title:"Cameră";Layout.fillWidth:true
   GridLayout {columns:2;anchors.fill:parent
    Label{text:"IP / Host"}
    TextField{id:cameraHost;Layout.fillWidth:true;text:cfg.cameraHost;placeholderText:"ex. 192.168.x.x"}
    Label{text:"Port"}
    TextField{id:cameraPort;Layout.fillWidth:true;text:cfg.cameraPort>0?cfg.cameraPort.toString():"";inputMethodHints:Qt.ImhDigitsOnly}
    Label{text:"Transport"}
    CheckBox{id:cameraUdp;text:checked?"UDP":"TCP";checked:cfg.cameraUdp}
   }
  }
  RowLayout {
   Layout.fillWidth:true
   Button{text:"SALVEAZĂ";onClicked:root.saveEndpoints()}
   Button{text:"CONECTEAZĂ SONAR";enabled:sonar&&sonar.host.length>0&&sonar.port>0;onClicked:sonar.connectSonar()}
   Button{text:"CONECTEAZĂ CAMERA";enabled:camera&&camera.host.length>0&&camera.port>0;onClicked:camera.connectCamera()}
  }
  Label{color:"#9db2c5";text:"Sonar: "+(sonar?sonar.status:"--")+" • Cameră: "+(camera?camera.status:"--")}
 }
}