import QtQuick
import QtMultimedia

Item {
 id:root
 property string streamUrl:""
 property string protocol:"auto" // auto, rtsp, mjpeg
 readonly property bool playing: player.playbackState===MediaPlayer.PlayingState
 readonly property string status: retryTimer.running ? "RECONNECT" : (player.error===MediaPlayer.NoError ? (playing?"LIVE":(streamUrl.length?"READY":"NO URL")) : player.errorString)
 property bool autoReconnect:true
 property int reconnectMs:3000
 signal videoError(string message)
 function normalizedUrl(){
  var u=streamUrl.trim(); if(!u.length)return ""
  if(protocol==="rtsp" && u.indexOf("://")<0)return "rtsp://"+u
  return u
 }
 function start(){var u=normalizedUrl();if(!u.length)return;player.source=u;player.play()}
 function stop(){retryTimer.stop();player.stop()}
 function scheduleReconnect(){if(autoReconnect&&streamUrl.length&&!retryTimer.running)retryTimer.start()}
 Timer{id:retryTimer;interval:root.reconnectMs;repeat:false;onTriggered:root.start()}
 MediaPlayer{id:player;videoOutput:video;audioOutput:AudioOutput{muted:true};onErrorOccurred:function(error,errorString){root.videoError(errorString);root.scheduleReconnect()} onPlaybackStateChanged:{if(playbackState===MediaPlayer.StoppedState&&root.streamUrl.length)root.scheduleReconnect()}}
 VideoOutput{id:video;anchors.fill:parent;fillMode:VideoOutput.PreserveAspectCrop}
}