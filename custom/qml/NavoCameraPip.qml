import QtQuick
import QtQuick.Controls
Rectangle {
 id:root
 property bool connected:false
 property string streamUrl:""
 property string protocol:"auto"
 property string decoder:"hardware"
 property string rtspTransport:"tcp"
 readonly property bool live:player.live
 property string statusText:player.live?"FAȚĂ • LIVE":player.status
 signal fullscreenRequested()
 signal closeRequested()
 function syncPlayback(){if(visible && connected && streamUrl.length)player.start();else player.stop()}
 onVisibleChanged:syncPlayback()
 onConnectedChanged:syncPlayback()
 onStreamUrlChanged:syncPlayback()
 Component.onCompleted:syncPlayback()
 width:230;height:160;radius:9;color:"#02070c";border.color:player.live?"#31d67b":"#1c4262";clip:true
 // Header is outside the native surface so X always remains reachable on Android.
 Label {anchors.left:parent.left;anchors.right:closeButton.left;anchors.top:parent.top;anchors.margins:7;height:25;text:root.statusText;color:player.live?"#31d67b":"#c1d7e6";font.pixelSize:10;font.bold:true;elide:Text.ElideRight;verticalAlignment:Text.AlignVCenter}
 Button {
  id:closeButton;objectName:"cameraPipClose";anchors.right:parent.right;anchors.top:parent.top;anchors.margins:3
  width:34;height:30;padding:0;Accessible.name:"Închide previzualizarea camerei"
  background:Rectangle {color:closeButton.down?"#174c60":"#08273a";border.color:"#20d9ed";radius:7}
  contentItem:Label {text:"×";color:"#eff9ff";font.pixelSize:24;horizontalAlignment:Text.AlignHCenter;verticalAlignment:Text.AlignVCenter}
  onClicked:{player.stop();root.closeRequested()}
 }
 NavoVideoPlayer {
  id:player;objectName:"cameraPipPlayer";anchors.left:parent.left;anchors.right:parent.right;anchors.top:parent.top;anchors.topMargin:37;anchors.bottom:parent.bottom;anchors.margins:3
  streamUrl:root.streamUrl;protocol:root.protocol;decoder:root.decoder;rtspTransport:root.rtspTransport
  onTapped:root.fullscreenRequested()
 }
 Label {anchors.centerIn:player;width:player.width-12;wrapMode:Text.WordWrap;visible:!player.playing;text:root.streamUrl.length?player.status:"Configurează URL RTSP/MJPEG";color:"#c1d7e6";horizontalAlignment:Text.AlignHCenter;font.pixelSize:11}
 MouseArea {anchors.fill:player;onClicked:root.fullscreenRequested()}
}
