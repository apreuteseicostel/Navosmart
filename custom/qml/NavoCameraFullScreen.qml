import QtQuick
import QtQuick.Controls
Rectangle{
 id:root
 property string streamUrl:""
 property string protocol:"auto"
 signal closed()
 color:"#02070c"
 NavoVideoPlayer{id:video;anchors.fill:parent;streamUrl:root.streamUrl;protocol:root.protocol;autoReconnect:true}
 Rectangle{anchors.left:parent.left;anchors.top:parent.top;anchors.margins:14;width:status.implicitWidth+20;height:32;radius:6;color:"#06111fcc"
  Label{id:status;anchors.centerIn:parent;text:"CAMERĂ • "+video.status;color:video.playing?"#31d67b":"#f2f7fb";font.bold:true}}
 Button{anchors.right:parent.right;anchors.top:parent.top;anchors.margins:14;text:"✕";onClicked:root.closed()}
 Component.onCompleted:video.start()
}