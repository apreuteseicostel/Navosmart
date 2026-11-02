import QtQuick
import NavoSmart.Backend 1.0

NavoFpvItem {
    id:root
    property string protocol:"rtsp"
    property string decoder:"hardware"
    property string rtspTransport:"tcp"
    hardware:decoder!=="software"
    transport:rtspTransport
    signal videoError(string message)
    function start(){active=true}
    function stop(){active=false}
    Component.onDestruction:active=false
}
