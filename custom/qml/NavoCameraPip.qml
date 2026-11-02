import QtQuick
import QtQuick.Controls
Rectangle {
 id:root
 property bool connected:false
 property string streamUrl:""
 property string protocol:"auto"
 readonly property bool live: player.live
 property string statusText: player.live?"FAȚĂ • LIVE":(connected?"CAMERA FAȚĂ • READY":"CAMERA FAȚĂ")
 signal fullscreenRequested()
 signal closeRequested()
 onVisibleChanged: if(!visible)player.stop()
 width:230;height:145;radius:9;color:"#02070cdd";border.color:player.live?"#31d67b":"#1c4262";clip:true
 NavoVideoPlayer{id:player;anchors.fill:parent;streamUrl:root.streamUrl;protocol:root.protocol;onVideoError:function(message){console.warn("NAVO camera:",message)}}
 Rectangle{anchors.fill:parent;color:"#071827";visible:!player.playing}
 Label{anchors.centerIn:parent;width:parent.width-20;wrapMode:Text.WordWrap;visible:!player.playing;text:player.desiredPlaying ? player.status : (root.streamUrl.length?"Camera pregătită\natinge pentru pornire":"Configurează URL RTSP/MJPEG");color:"#9db2c5";horizontalAlignment:Text.AlignHCenter;font.bold:true}
 Rectangle{anchors.left:parent.left;anchors.top:parent.top;anchors.margins:7;width:camLabel.implicitWidth+12;height:25;radius:5;color:"#06111fcc"
  Label{id:camLabel;anchors.centerIn:parent;text:root.statusText;color:player.live?"#31d67b":"#9db2c5";font.pixelSize:10;font.bold:true}}
 MouseArea{anchors.fill:parent;onClicked:{if(!player.playing&&root.streamUrl.length)player.start();else root.fullscreenRequested()}}
 Button {
  anchors.right:parent.right;anchors.top:parent.top;anchors.margins:4
  width:36;height:32;text:"×";Accessible.name:"Închide previzualizarea camerei"
  onClicked:{player.stop();root.closeRequested()}
 }
}
