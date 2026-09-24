import QtQuick
import NavoSmart.Backend 1.0
QtObject {
 id: root
 property alias host: transportBackend.host
 property alias port: transportBackend.port
 property alias udp: transportBackend.udp
 readonly property bool connected: transportBackend.connected
 readonly property string status: transportBackend.status
 readonly property bool dataAlive: transportBackend.dataAlive
 // Raw network transport is ready. Actual H264/MJPEG/RTSP decoding is intentionally
 // not guessed; bind a decoder when the physical camera/GR01 stream is confirmed.
 signal packetReceived(var bytes)
 function connectCamera(){transportBackend.connectEndpoint()}
 function disconnectCamera(){transportBackend.disconnectEndpoint()}
 property NavoEthernetTransport transport: NavoEthernetTransport {
  id: transportBackend
  onBytesReceived: function(data){root.packetReceived(data)}
 }
}
