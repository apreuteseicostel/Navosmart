import QtQuick
import QtQuick.Controls
Rectangle {
 id:root
 property string streamUrl:""
 property string protocol:"auto"
 property string decoder:"hardware"
 property string rtspTransport:"tcp"
 signal closed()
 color:"#02070c"
 Label {anchors.left:parent.left;anchors.right:closeButton.left;anchors.top:parent.top;anchors.margins:10;height:34;text:"CAMERĂ • "+video.status;color:video.live?"#31d67b":"#eff9ff";font.pixelSize:12;elide:Text.ElideRight;verticalAlignment:Text.AlignVCenter}
 Button {
  id:closeButton;objectName:"cameraFullscreenClose";anchors.right:parent.right;anchors.top:parent.top;anchors.margins:6;width:46;height:40;padding:0
  Accessible.name:"Închide Camera față"
  background:Rectangle {color:closeButton.down?"#174c60":"#08273a";border.color:"#20d9ed";radius:8}
  contentItem:Label {text:"×";color:"#eff9ff";font.pixelSize:28;horizontalAlignment:Text.AlignHCenter;verticalAlignment:Text.AlignVCenter}
  onClicked:{video.stop();root.closed()}
 }
 NavoVideoPlayer {id:video;objectName:"cameraFullscreenPlayer";anchors.left:parent.left;anchors.right:parent.right;anchors.top:parent.top;anchors.topMargin:54;anchors.bottom:parent.bottom
  streamUrl:root.streamUrl;protocol:root.protocol;decoder:root.decoder;rtspTransport:root.rtspTransport}
 Component.onCompleted:video.start()
 Component.onDestruction:video.stop()
}
