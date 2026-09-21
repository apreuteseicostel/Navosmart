import QtQuick
import NavoSmart.Backend 1.0
QtObject {
 id: root
 property alias host: transport.host
 property alias port: transport.port
 property alias udp: transport.udp
 readonly property bool connected: transport.connected
 readonly property string status: transport.status
 readonly property bool dataAlive: transport.dataAlive
 // Raw network transport is ready. Actual H264/MJPEG/RTSP decoding is intentionally
 // not guessed; bind a decoder when the physical camera/GR01 stream is confirmed.
 signal packetReceived(var bytes)
 function connectCamera(){transport.connectEndpoint()}
 function disconnectCamera(){transport.disconnectEndpoint()}
 property NavoEthernetTransport transport: NavoEthernetTransport {
  onBytesReceived: function(data){root.packetReceived(data)}
 }
}
