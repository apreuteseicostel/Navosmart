import QtQuick
import QtQuick.Controls
Rectangle {
 id:root
 property bool connected:false
 property string streamUrl:""
 property string protocol:"auto"
 property string statusText: player.playing?"LIVE • LAN":(connected?"CAMERA LAN • READY":"CAMERA LAN")
 signal fullscreenRequested()
 width:230;height:145;radius:9;color:"#02070cdd";border.color:player.playing?"#31d67b":"#1c4262";clip:true
 NavoVideoPlayer{id:player;anchors.fill:parent;streamUrl:root.streamUrl;protocol:root.protocol;onVideoError:function(message){console.warn("NAVO camera:",message)}}
 Rectangle{anchors.fill:parent;color:"#071827";visible:!player.playing}
 Label{anchors.centerIn:parent;visible:!player.playing;text:root.streamUrl.length?"Camera pregătită\natinge pentru pornire":"Configurează URL RTSP/MJPEG";color:"#9db2c5";horizontalAlignment:Text.AlignHCenter;font.bold:true}
 Rectangle{anchors.left:parent.left;anchors.top:parent.top;anchors.margins:7;width:camLabel.implicitWidth+12;height:25;radius:5;color:"#06111fcc"
  Label{id:camLabel;anchors.centerIn:parent;text:root.statusText;color:player.playing?"#31d67b":"#9db2c5";font.pixelSize:10;font.bold:true}}
 MouseArea{anchors.fill:parent;onClicked:{if(!player.playing&&root.streamUrl.length)player.start();else root.fullscreenRequested()}}
}