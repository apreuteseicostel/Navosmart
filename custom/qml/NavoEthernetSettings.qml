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
 readonly property bool compact: width < 620
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
  anchors.fill:parent;anchors.margins:root.compact?8:14;spacing:root.compact?6:10
  Label{text:"REȚEA BARCĂ • ETHERNET";color:"#21b7ff";font.bold:true;font.pixelSize:root.compact?13:14;Layout.preferredHeight:root.compact?20:24;verticalAlignment:Text.AlignVCenter}
  GridLayout {
   Layout.fillWidth:true;Layout.fillHeight:true;columns:root.compact?1:2;columnSpacing:root.compact?0:18;rowSpacing:root.compact?10:0
   GroupBox {
    title:"KOGGER SONAR"; palette.windowText:"#d7e3ee"; Layout.fillWidth:true;Layout.fillHeight:!root.compact;Layout.preferredHeight:root.compact?250:-1;Layout.preferredWidth:320;Layout.minimumWidth:280
    GridLayout {anchors.fill:parent;anchors.margins:root.compact?4:8;columns:2;columnSpacing:8;rowSpacing:root.compact?4:6
     Layout.maximumWidth: root.compact ? 16777215 : 620
     Label{text:"IP / Host";color:"#d7e3ee"}
     TextField { id:sonarHost; color:"#f2f7fb"; placeholderTextColor:"#70879a"; selectionColor:"#21b7ff"; selectedTextColor:"#07131d"; background:Rectangle{radius:6;color:"#101b25";border.color:sonarHost.activeFocus?"#21b7ff":"#31506a"};Layout.fillWidth:true;Layout.minimumWidth:190;text:cfg.sonarHost;placeholderText:"ex. 192.168.x.x"}
     Label{text:"Port";color:"#d7e3ee"}
     TextField { id:sonarPort; color:"#f2f7fb"; placeholderTextColor:"#70879a"; selectionColor:"#21b7ff"; selectedTextColor:"#07131d"; background:Rectangle{radius:6;color:"#101b25";border.color:sonarPort.activeFocus?"#21b7ff":"#31506a"};Layout.fillWidth:true;text:cfg.sonarPort>0?cfg.sonarPort.toString():"";inputMethodHints:Qt.ImhDigitsOnly}
     Label{text:"Transport";color:"#d7e3ee"}
     CheckBox{id:sonarUdp;text:checked?"UDP":"TCP";checked:cfg.sonarUdp;palette.windowText:"#d7e3ee";indicator:Rectangle{implicitWidth:24;implicitHeight:24;radius:5;color:sonarUdp.checked?"#123b4b":"#101b25";border.color:sonarUdp.checked?"#21b7ff":"#31506a";Label{anchors.centerIn:parent;text:sonarUdp.checked?"✓":"";color:"#31d67b";font.bold:true}}}
     Item{Layout.columnSpan:2;Layout.fillHeight:true}
     Label{Layout.columnSpan:2;Layout.fillWidth:true;wrapMode:Text.WordWrap;color:"#9db2c5";font.pixelSize:10;text:"Stare: "+(sonar?sonar.status:"--")}
     Button{width:42;height:38;ToolTip.visible:hovered;ToolTip.text:"Conectează sonar";contentItem:Image{anchors.centerIn:parent;width:24;height:24;source:"qrc:/qml/NavoSmart/icons/sonar.svg"}enabled:sonar&&sonarHost.text.trim().length>0&&(parseInt(sonarPort.text)||0)>0;onClicked:{root.saveEndpoints();sonar.connectSonar()}}
    }
   }
   GroupBox {
    title:"CAMERA FAȚĂ"; palette.windowText:"#d7e3ee"; Layout.fillWidth:true;Layout.fillHeight:!root.compact;Layout.preferredHeight:root.compact?330:-1;Layout.preferredWidth:420;Layout.minimumWidth:340
    ColumnLayout {
     anchors.fill:parent;anchors.margins:root.compact?4:8;spacing:root.compact?4:6
     GridLayout {Layout.fillWidth:true;columns:2;columnSpacing:8;rowSpacing:root.compact?4:6
      Layout.maximumWidth: root.compact ? 16777215 : 620
      Label{text:"IP / Host";color:"#d7e3ee"}
      TextField { id:cameraHost; color:"#f2f7fb"; placeholderTextColor:"#70879a"; selectionColor:"#21b7ff"; selectedTextColor:"#07131d"; background:Rectangle{radius:6;color:"#101b25";border.color:cameraHost.activeFocus?"#21b7ff":"#31506a"};Layout.fillWidth:true;Layout.minimumWidth:190;text:cfg.cameraHost;placeholderText:"ex. 192.168.x.x"}
      Label{text:"Port";color:"#d7e3ee"}
      TextField { id:cameraPort; color:"#f2f7fb"; placeholderTextColor:"#70879a"; selectionColor:"#21b7ff"; selectedTextColor:"#07131d"; background:Rectangle{radius:6;color:"#101b25";border.color:cameraPort.activeFocus?"#21b7ff":"#31506a"};Layout.fillWidth:true;text:cfg.cameraPort>0?cfg.cameraPort.toString():"";inputMethodHints:Qt.ImhDigitsOnly}
      Label{text:"Transport";color:"#d7e3ee"}
      CheckBox{id:cameraUdp;text:checked?"UDP":"TCP";checked:cfg.cameraUdp;palette.windowText:"#d7e3ee";indicator:Rectangle{implicitWidth:24;implicitHeight:24;radius:5;color:cameraUdp.checked?"#123b4b":"#101b25";border.color:cameraUdp.checked?"#21b7ff":"#31506a";Label{anchors.centerIn:parent;text:cameraUdp.checked?"✓":"";color:"#31d67b";font.bold:true}}}
      Label{text:"URL video";color:"#d7e3ee"}
      TextField { id:streamUrl; color:"#f2f7fb"; placeholderTextColor:"#70879a"; selectionColor:"#21b7ff"; selectedTextColor:"#07131d"; background:Rectangle{radius:6;color:"#101b25";border.color:streamUrl.activeFocus?"#21b7ff":"#31506a"};Layout.fillWidth:true;Layout.minimumWidth:190;text:cfg.cameraStreamUrl;placeholderText:"rtsp://... sau http://..."}
      Label{text:"Protocol";color:"#d7e3ee"}
      ComboBox{id:protocol;Layout.fillWidth:true;palette.text:"#f2f7fb";palette.buttonText:"#f2f7fb";palette.base:"#101b25";palette.button:"#101b25";textRole:"text";valueRole:"value";model:[{text:"AUTO",value:"auto"},{text:"RTSP",value:"rtsp"},{text:"MJPEG/HTTP",value:"mjpeg"}];Component.onCompleted:{var i=indexOfValue(cfg.cameraProtocol);if(i>=0)currentIndex=i}}
     }
     NavoVideoPlayer{id:videoTest;visible:streamUrl.text.trim().length>0;Layout.fillWidth:true;Layout.fillHeight:visible;Layout.minimumHeight:visible?(root.compact?54:80):0;Layout.maximumHeight:visible?16777215:0;streamUrl:streamUrl.text;protocol:protocol.currentValue;onVideoError:function(message){root.status("Video: "+message)}}
     RowLayout {
      Layout.fillWidth:true
      Button{width:42;height:38;ToolTip.visible:hovered;ToolTip.text:"Testează video";contentItem:Image{anchors.centerIn:parent;width:24;height:24;source:"qrc:/qml/NavoSmart/icons/play.svg"}enabled:streamUrl.text.trim().length>0;onClicked:{root.saveEndpoints();videoTest.start()}}
      Button{width:42;height:38;ToolTip.visible:hovered;ToolTip.text:"Oprește test video";contentItem:Image{anchors.centerIn:parent;width:24;height:24;source:"qrc:/qml/NavoSmart/icons/stop.svg"}onClicked:videoTest.stop()}
     }
     Label{Layout.fillWidth:true;elide:Text.ElideRight;color:"#9db2c5";font.pixelSize:10;text:"LAN: "+(camera?camera.status:"--")+" • Video: "+videoTest.status}
    }
   }
  }
  RowLayout {
   Layout.fillWidth:true
   Button{width:42;height:38;ToolTip.visible:hovered;ToolTip.text:"Salvează toate setările";contentItem:Image{anchors.centerIn:parent;width:24;height:24;source:"qrc:/qml/NavoSmart/icons/save.svg"}onClicked:root.saveEndpoints()}
   Item{Layout.fillWidth:true}
   Label{visible:false;text:""}
  }
 }
}