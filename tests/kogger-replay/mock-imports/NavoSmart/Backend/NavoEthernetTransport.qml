import QtQml
QtObject {
 property string host:""
 property int port:0
 property bool udp:false
 property bool autoReconnect:false
 property bool connected:false
 property string status:connected?"CONNECTED":"OFFLINE"
 signal bytesReceived(var bytes)
 function connectEndpoint(){connected=true}
 function disconnectEndpoint(){connected=false}
}
