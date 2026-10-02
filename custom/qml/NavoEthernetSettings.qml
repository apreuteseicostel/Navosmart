import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCore
import NavoSmart.Backend 1.0

Rectangle {
 id: root
 property var sonar
 property var camera
 property string cameraStreamUrl:""
 property string cameraProtocol:"auto"
 readonly property bool compact: width < 620
 signal status(string text)
 signal unitsRequested()
 NavoLanDiscovery { id: lanDiscovery }
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
  property bool connectOnStartup:true
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
 Component.onCompleted:{loadEndpoints();root.cameraStreamUrl=cfg.cameraStreamUrl;root.cameraProtocol=cfg.cameraProtocol; if(cfg.connectOnStartup) startupConnections.start()}
 Timer { id:startupConnections; interval:1200; repeat:false; onTriggered:{if(sonar && cfg.sonarHost.trim().length>0 && cfg.sonarPort>0) sonar.connectSonar(); if(camera && cfg.cameraHost.trim().length>0 && cfg.cameraPort>0) camera.connectCamera()} }
 ColumnLayout {
  anchors.fill:parent;anchors.margins:8;spacing:root.compact?5:8
  CheckBox { text:"Conectare automată la pornire"; checked:cfg.connectOnStartup; onToggled:cfg.connectOnStartup=checked; palette.windowText:"#d7e3ee" }
  RowLayout{Layout.fillWidth:true;Layout.preferredHeight:40
   Label{text:"REȚEA BARCĂ • ETHERNET";color:"#21b7ff";font.bold:true;font.pixelSize:root.compact?13:14;verticalAlignment:Text.AlignVCenter}
   Item{Layout.fillWidth:true}
   Button{Layout.preferredWidth:46;Layout.preferredHeight:42;padding:0;ToolTip.visible:hovered;ToolTip.text:"Salvează toate setările";background:Rectangle{radius:8;color:parent.hovered?"#123d50":"#101b25";border.color:"#21b7ff"}contentItem:Image{anchors.centerIn:parent;width:24;height:24;source:"qrc:/qml/NavoSmart/icons/save.svg";fillMode:Image.PreserveAspectFit}onClicked:root.saveEndpoints()}
   Button{Layout.preferredWidth:104;Layout.preferredHeight:42;padding:0;ToolTip.visible:hovered;ToolTip.text:"Unități de măsură";background:Rectangle{radius:8;color:parent.hovered?"#123d50":"#101b25";border.color:"#21b7ff"}contentItem:Label{text:"UNITĂȚI";color:"#d7e3ee";font.bold:true;font.pixelSize:12;horizontalAlignment:Text.AlignHCenter;verticalAlignment:Text.AlignVCenter}onClicked:root.unitsRequested()}
  }
  RowLayout {
   Layout.fillWidth:true;spacing:8
   Button { text:lanDiscovery.scanning?"Oprește căutarea":"Caută dispozitive LAN"; onClicked:lanDiscovery.scanning?lanDiscovery.stop():lanDiscovery.scan() }
   Label { Layout.fillWidth:true;color:"#9db2c5";elide:Text.ElideRight;text:lanDiscovery.scanning?"Se caută dispozitive...":lanDiscovery.devices.length+" conexiuni TCP detectate (neidentificate)" }
  }
  ScrollView {
   Layout.fillWidth:true;Layout.preferredHeight:lanDiscovery.devices.length?Math.min(110,lanDiscovery.devices.length*36):0
   visible:lanDiscovery.devices.length>0;clip:true
   ListView {
    model:lanDiscovery.devices;spacing:3
    delegate:RowLayout {
     required property var modelData
     width:ListView.view.width
     Label { Layout.fillWidth:true;color:"#d7e3ee";text:modelData.host+":"+modelData.port+" • candidat" }
     Button { text:"Sonar";onClicked:{sonarHost.text=modelData.host;sonarPort.text=String(modelData.port);sonarUdp.checked=false;root.status("Adresă sonar selectată; verifică adaptorul USR și salvează.")} }
     Button { text:"Cameră";onClicked:{cameraHost.text=modelData.host;cameraPort.text=String(modelData.port);cameraUdp.checked=false;root.status("Adresă cameră selectată; verifică URL-ul video și salvează.")} }
    }
   }
  }
  GridLayout {
   Layout.fillWidth:true;Layout.fillHeight:true;columns:root.compact?1:2;columnSpacing:root.compact?0:10;rowSpacing:root.compact?8:0;uniformCellWidths:true
   GroupBox {
    title:"KOGGER SONAR"; palette.windowText:"#d7e3ee"; Layout.fillWidth:true;Layout.fillHeight:!root.compact;Layout.preferredHeight:root.compact?250:-1;Layout.minimumWidth:root.compact?250:250
    GridLayout {anchors.fill:parent;anchors.margins:root.compact?4:8;columns:2;columnSpacing:8;rowSpacing:root.compact?4:6
     Layout.fillWidth:true
     Label{text:"IP / Host";color:"#d7e3ee"}
     TextField { palette.text:"#0b1118"; palette.base:"#ffffff"; palette.placeholderText:"#5f6b76"; palette.highlight:"#21b7ff"; palette.highlightedText:"#ffffff";id:sonarHost;Layout.fillWidth:true;Layout.minimumWidth:root.compact?190:120;Layout.maximumWidth:16777215;text:cfg.sonarHost;placeholderText:"ex. 192.168.x.x"}
     Label{text:"Port";color:"#d7e3ee"}
     TextField { palette.text:"#0b1118"; palette.base:"#ffffff"; palette.placeholderText:"#5f6b76"; palette.highlight:"#21b7ff"; palette.highlightedText:"#ffffff";id:sonarPort;Layout.fillWidth:true;Layout.maximumWidth:16777215;text:cfg.sonarPort>0?cfg.sonarPort.toString():"";inputMethodHints:Qt.ImhDigitsOnly}
     Label{text:"Transport";color:"#d7e3ee"}
     CheckBox{id:sonarUdp;text:checked?"UDP":"TCP";checked:cfg.sonarUdp}
     Item{Layout.columnSpan:2;Layout.fillHeight:true}
     Label{Layout.columnSpan:2;Layout.fillWidth:true;wrapMode:Text.WordWrap;color:"#9db2c5";font.pixelSize:10;text:"Stare: "+(sonar?sonar.status:"--")}
     RowLayout{Layout.columnSpan:2;Layout.fillWidth:true;Item{Layout.fillWidth:true}Button{Layout.preferredWidth:46;Layout.preferredHeight:42;padding:0;ToolTip.visible:hovered;ToolTip.text:"Conectează sonar";background:Rectangle{radius:8;color:parent.hovered?"#123d50":"#101b25";border.color:"#21b7ff"}contentItem:Image{anchors.centerIn:parent;width:26;height:26;source:"qrc:/qml/NavoSmart/icons/sonar.svg";fillMode:Image.PreserveAspectFit}enabled:sonar&&sonarHost.text.trim().length>0&&(parseInt(sonarPort.text)||0)>0;onClicked:{root.saveEndpoints();sonar.connectSonar()}}}
    }
   }
   GroupBox {
    title:"CAMERA FAȚĂ"; palette.windowText:"#d7e3ee"; Layout.fillWidth:true;Layout.fillHeight:!root.compact;Layout.preferredHeight:root.compact?330:-1;Layout.minimumWidth:root.compact?250:250
    ColumnLayout {
     anchors.fill:parent;anchors.margins:root.compact?4:8;spacing:root.compact?4:6
     GridLayout {Layout.fillWidth:true;columns:2;columnSpacing:8;rowSpacing:root.compact?4:6
      Label{text:"IP / Host";color:"#d7e3ee"}
      TextField { palette.text:"#0b1118"; palette.base:"#ffffff"; palette.placeholderText:"#5f6b76"; palette.highlight:"#21b7ff"; palette.highlightedText:"#ffffff";id:cameraHost;Layout.fillWidth:true;Layout.minimumWidth:root.compact?190:120;Layout.maximumWidth:16777215;text:cfg.cameraHost;placeholderText:"ex. 192.168.x.x"}
      Label{text:"Port";color:"#d7e3ee"}
      TextField { palette.text:"#0b1118"; palette.base:"#ffffff"; palette.placeholderText:"#5f6b76"; palette.highlight:"#21b7ff"; palette.highlightedText:"#ffffff";id:cameraPort;Layout.fillWidth:true;Layout.maximumWidth:16777215;text:cfg.cameraPort>0?cfg.cameraPort.toString():"";inputMethodHints:Qt.ImhDigitsOnly}
      Label{text:"Transport";color:"#d7e3ee"}
      CheckBox{id:cameraUdp;text:checked?"UDP":"TCP";checked:cfg.cameraUdp}
      Label{text:"URL video";color:"#d7e3ee"}
      TextField { palette.text:"#0b1118"; palette.base:"#ffffff"; palette.placeholderText:"#5f6b76"; palette.highlight:"#21b7ff"; palette.highlightedText:"#ffffff";id:streamUrl;Layout.fillWidth:true;Layout.minimumWidth:190;text:cfg.cameraStreamUrl;placeholderText:"rtsp://... sau http://..."}
      Label{text:"Protocol";color:"#d7e3ee"}
      ComboBox{id:protocol;Layout.fillWidth:true;textRole:"text";valueRole:"value";model:[{text:"AUTO",value:"auto"},{text:"RTSP",value:"rtsp"},{text:"MJPEG/HTTP",value:"mjpeg"}];Component.onCompleted:{var i=indexOfValue(cfg.cameraProtocol);if(i>=0)currentIndex=i}}
     }
     NavoVideoPlayer{id:videoTest;Layout.fillWidth:true;Layout.fillHeight:true;Layout.minimumHeight:root.compact?54:80;streamUrl:streamUrl.text;protocol:protocol.currentValue;onVideoError:function(message){root.status("Video: "+message)}}
     RowLayout {
      Layout.fillWidth:true;Layout.topMargin:4;Layout.bottomMargin:4;spacing:8
      Item{Layout.fillWidth:true}
      Button{Layout.preferredWidth:46;Layout.preferredHeight:42;padding:0;ToolTip.visible:hovered;ToolTip.text:"Testează video";background:Rectangle{radius:8;color:parent.hovered?"#123d50":"#101b25";border.color:"#21b7ff"}contentItem:Image{anchors.centerIn:parent;width:24;height:24;source:"qrc:/qml/NavoSmart/icons/play.svg";fillMode:Image.PreserveAspectFit}enabled:streamUrl.text.trim().length>0;onClicked:{root.saveEndpoints();videoTest.start()}}
      Button{Layout.preferredWidth:46;Layout.preferredHeight:42;padding:0;ToolTip.visible:hovered;ToolTip.text:"Oprește test video";background:Rectangle{radius:8;color:parent.hovered?"#3a2025":"#101b25";border.color:"#ff6b6b"}contentItem:Image{anchors.centerIn:parent;width:24;height:24;source:"qrc:/qml/NavoSmart/icons/stop.svg";fillMode:Image.PreserveAspectFit}onClicked:videoTest.stop()}
      Item{Layout.preferredWidth:8}
     }
     Label{Layout.fillWidth:true;elide:Text.ElideRight;color:"#9db2c5";font.pixelSize:10;text:"LAN: "+(camera?camera.status:"--")+" • Video: "+videoTest.status}
    }
   }
  }
 }
}