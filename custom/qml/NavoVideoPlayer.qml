import QtQuick
import QtMultimedia

Item {
 id:root
 property string streamUrl:""
 property string protocol:"auto" // auto, rtsp, mjpeg
 readonly property bool playing: player.playbackState===MediaPlayer.PlayingState
 readonly property string status: player.error===MediaPlayer.NoError ? (playing?"LIVE":(streamUrl.length?"READY":"NO URL")) : player.errorString
 signal videoError(string message)
 function normalizedUrl(){
  var u=streamUrl.trim(); if(!u.length)return ""
  if(protocol==="rtsp" && u.indexOf("://")<0)return "rtsp://"+u
  return u
 }
 function start(){var u=normalizedUrl();if(!u.length)return;player.source=u;player.play()}
 function stop(){player.stop()}
 MediaPlayer{id:player;videoOutput:video;audioOutput:AudioOutput{muted:true};onErrorOccurred:function(error,errorString){root.videoError(errorString)}}
 VideoOutput{id:video;anchors.fill:parent;fillMode:VideoOutput.PreserveAspectCrop}
}