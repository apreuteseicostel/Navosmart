import QtQuick

// Android RTSP uses the official FPV SDK; desktop/MJPEG retain Qt Multimedia.
Item {
    id:root
    property string streamUrl:""
    property string protocol:"auto"
    property string decoder:"hardware"
    property string rtspTransport:"tcp"
    property bool autoReconnect:true
    property bool desiredPlaying:false
    readonly property bool playing:!!backend.item && backend.item.playing
    readonly property bool live:!!backend.item && backend.item.live
    readonly property string status:backend.item ? backend.item.status : "STOPPED"
    readonly property bool nativeVideo:Qt.platform.os==="android" && normalizedUrl().toLowerCase().indexOf("rtsp://")===0
    signal videoError(string message)
    signal tapped()
    function normalizedUrl() {
        var url=streamUrl.trim()
        if(url.length && url.indexOf("://")<0) {
            if(protocol==="rtsp")return "rtsp://"+url
            if(protocol==="mjpeg")return "http://"+url
        }
        return url
    }
    function configure() {
        if(!backend.item)return
        backend.item.streamUrl=root.normalizedUrl()
        backend.item.protocol=root.protocol
        backend.item.autoReconnect=root.autoReconnect
        backend.item.decoder=root.decoder
        backend.item.rtspTransport=root.rtspTransport
        if(root.desiredPlaying && root.visible)backend.item.start()
    }
    function start(){desiredPlaying=true;configure()}
    function stop(){desiredPlaying=false;if(backend.item)backend.item.stop()}
    onStreamUrlChanged:configure()
    onProtocolChanged:configure()
    onDecoderChanged:configure()
    onRtspTransportChanged:configure()
    onVisibleChanged:if(!visible)stop()
    Component.onDestruction:stop()
    Loader {
        id:backend;anchors.fill:parent
        source:root.nativeVideo ? "NavoAndroidFpvPlayer.qml" : "NavoQtVideoPlayer.qml"
        onLoaded:root.configure()
    }
    Connections {target:backend.item;ignoreUnknownSignals:true
        function onVideoError(message){root.videoError(message)}
        function onTapped(){root.tapped()}
    }
}
