import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCore

Rectangle {
 id: root
 property var sonar
 property var camera
 property string cameraStreamUrl:""
 property string cameraProtocol:"auto"
 readonly property bool compact: width < 900 || height < 520
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
  property string cameraStreamUrl:""
  property string cameraProtocol:"auto"
 }
 function loadEndpoints(){
  if(sonar){sonar.host=cfg.sonarHost;sonar.port=cfg.sonarPort;sonar.udp=cfg.sonarUdp}
  if(camera){camera.host=cfg.cameraHost;camera.port=cfg.cameraPort;camera.udp=cfg.cameraUdp}
 }
 function saveEndpoints(){
  cfg.sonarHost=sonarHost.text.trim();cfg.sonarPort=parseInt(sonarPort.text)||0;cfg.sonarUdp=sonarUdp.checked
  cfg.cameraHost=cameraHost.text.trim();cfg.cameraPort=parseInt(cameraPort.text)||0;cfg.cameraUdp=cameraUdp.checked
  cfg.cameraStreamUrl=streamUrl.text.trim();cfg.cameraProtocol=protocol.currentValue;root.cameraStreamUrl=cfg.cameraStreamUrl;root.cameraProtocol=cfg.cameraProtocol
  loadEndpoints();status("Setări Ethernet/video salvate")
 }
 Component.onCompleted:{loadEndpoints();root.cameraStreamUrl=cfg.cameraStreamUrl;root.cameraProtocol=cfg.cameraProtocol}
 ColumnLayout {
  anchors.fill:parent;anchors.margins:root.compact?6:10;spacing:root.compact?3:5
  Label{text:"REȚEA BARCĂ • ETHERNET";color:"#21b7ff";font.bold:true;font.pixelSize:root.compact?13:14;Layout.preferredHeight:root.compact?20:24;verticalAlignment:Text.AlignVCenter}
  GridLayout {
   Layout.fillWidth:true;Layout.fillHeight:true;columns:root.compact?1:2;columnSpacing:root.compact?0:12;rowSpacing:root.compact?6:0
   GroupBox {
    title:"KOGGER SONAR"; palette.windowText:"#d7e3ee"; Layout.fillWidth:true;Layout.fillHeight:!root.compact;Layout.preferredHeight:root.compact?190:-1;Layout.preferredWidth:1
    GridLayout {anchors.fill:parent;anchors.margins:root.compact?4:8;columns:2;columnSpacing:8;rowSpacing:root.compact?4:6
     Label{text:"IP / Host";color:"#d7e3ee"}
     TextField { palette.text:"#0b1118"; palette.base:"#ffffff"; palette.placeholderText:"#5f6b76"; palette.highlight:"#21b7ff"; palette.highlightedText:"#ffffff";id:sonarHost;Layout.fillWidth:true;text:cfg.sonarHost;placeholderText:"ex. 192.168.x.x"}
     Label{text:"Port";color:"#d7e3ee"}
     TextField { palette.text:"#0b1118"; palette.base:"#ffffff"; palette.placeholderText:"#5f6b76"; palette.highlight:"#21b7ff"; palette.highlightedText:"#ffffff";id:sonarPort;Layout.fillWidth:true;text:cfg.sonarPort>0?cfg.sonarPort.toString():"";inputMethodHints:Qt.ImhDigitsOnly}
     Label{text:"Transport";color:"#d7e3ee"}
     CheckBox{id:sonarUdp;text:checked?"UDP":"TCP";checked:cfg.sonarUdp}
     Item{Layout.columnSpan:2;Layout.fillHeight:true}
     Label{Layout.columnSpan:2;Layout.fillWidth:true;wrapMode:Text.WordWrap;color:"#9db2c5";font.pixelSize:10;text:"Stare: "+(sonar?sonar.status:"--")}
     Button{width:42;height:38;ToolTip.visible:hovered;ToolTip.text:"Conectează sonar";contentItem:Image{anchors.centerIn:parent;width:24;height:24;source:"qrc:/qml/NavoSmart/icons/sonar.svg"};enabled:sonar&&sonarHost.text.trim().length>0&&(parseInt(sonarPort.text)||0)>0;onClicked:{root.saveEndpoints();sonar.connectSonar()}}
    }
   }
   GroupBox {
    title:"CAMERA FAȚĂ"; palette.windowText:"#d7e3ee"; Layout.fillWidth:true;Layout.fillHeight:!root.compact;Layout.preferredHeight:root.compact?280:-1;Layout.preferredWidth:1
    ColumnLayout {
     anchors.fill:parent;anchors.margins:root.compact?4:8;spacing:root.compact?4:6
     GridLayout {Layout.fillWidth:true;columns:2;columnSpacing:8;rowSpacing:root.compact?4:6
      Label{text:"IP / Host";color:"#d7e3ee"}
      TextField { palette.text:"#0b1118"; palette.base:"#ffffff"; palette.placeholderText:"#5f6b76"; palette.highlight:"#21b7ff"; palette.highlightedText:"#ffffff";id:cameraHost;Layout.fillWidth:true;text:cfg.cameraHost;placeholderText:"ex. 192.168.x.x"}
      Label{text:"Port";color:"#d7e3ee"}
      TextField { palette.text:"#0b1118"; palette.base:"#ffffff"; palette.placeholderText:"#5f6b76"; palette.highlight:"#21b7ff"; palette.highlightedText:"#ffffff";id:cameraPort;Layout.fillWidth:true;text:cfg.cameraPort>0?cfg.cameraPort.toString():"";inputMethodHints:Qt.ImhDigitsOnly}
      Label{text:"Transport";color:"#d7e3ee"}
      CheckBox{id:cameraUdp;text:checked?"UDP":"TCP";checked:cfg.cameraUdp}
      Label{text:"URL video";color:"#d7e3ee"}
      TextField { palette.text:"#0b1118"; palette.base:"#ffffff"; palette.placeholderText:"#5f6b76"; palette.highlight:"#21b7ff"; palette.highlightedText:"#ffffff";id:streamUrl;Layout.fillWidth:true;text:cfg.cameraStreamUrl;placeholderText:"rtsp://... sau http://..."}
      Label{text:"Protocol";color:"#d7e3ee"}
      ComboBox{id:protocol;Layout.fillWidth:true;textRole:"text";valueRole:"value";model:[{text:"AUTO",value:"auto"},{text:"RTSP",value:"rtsp"},{text:"MJPEG/HTTP",value:"mjpeg"}];Component.onCompleted:{var i=indexOfValue(cfg.cameraProtocol);if(i>=0)currentIndex=i}}
     }
     NavoVideoPlayer{id:videoTest;Layout.fillWidth:true;Layout.fillHeight:true;Layout.minimumHeight:root.compact?54:80;streamUrl:streamUrl.text;protocol:protocol.currentValue;onVideoError:function(message){root.status("Video: "+message)}}
     RowLayout {
      Layout.fillWidth:true
      Button{width:42;height:38;ToolTip.visible:hovered;ToolTip.text:"Testează video";contentItem:Image{anchors.centerIn:parent;width:24;height:24;source:"qrc:/qml/NavoSmart/icons/play.svg"};enabled:streamUrl.text.trim().length>0;onClicked:{root.saveEndpoints();videoTest.start()}}
      Button{width:42;height:38;ToolTip.visible:hovered;ToolTip.text:"Oprește test video";contentItem:Image{anchors.centerIn:parent;width:24;height:24;source:"qrc:/qml/NavoSmart/icons/stop.svg"};onClicked:videoTest.stop()}
     }
     Label{Layout.fillWidth:true;elide:Text.ElideRight;color:"#9db2c5";font.pixelSize:10;text:"LAN: "+(camera?camera.status:"--")+" • Video: "+videoTest.status}
    }
   }
  }
  RowLayout {
   Layout.fillWidth:true
   Button{width:42;height:38;ToolTip.visible:hovered;ToolTip.text:"Salvează toate setările";contentItem:Image{anchors.centerIn:parent;width:24;height:24;source:"qrc:/qml/NavoSmart/icons/save.svg"};onClicked:root.saveEndpoints()}
   Item{Layout.fillWidth:true}
   Label{visible:false;text:""}
  }
 }
}