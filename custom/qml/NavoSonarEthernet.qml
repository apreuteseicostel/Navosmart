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
 property alias depthM: decoder.depthM
 property alias waterTempC: decoder.waterTempC
 property alias echoSamples: decoder.echoSamples
 property var vehicle
 property int rxBytes: 0
 property int rxChunks: 0
 signal geoSample(var sample)
 function connectSonar(){ transport.connectEndpoint() }
 function disconnectSonar(){ transport.disconnectEndpoint(); decoder.reset() }
 function connectToSonar(){ connectSonar() }
 function disconnectFromSonar(){ disconnectSonar() }
 property NavoEthernetTransport transport: NavoEthernetTransport {
  onBytesReceived: function(data){ root.rxBytes += data.length; root.rxChunks += 1; decoder.feedBytes(data) }
 }
 property NavoKoggerDecoder decoder: NavoKoggerDecoder {
  onDepthChanged: {
   if(root.vehicle && root.vehicle.coordinate && root.vehicle.coordinate.isValid && !isNaN(depthM))
    root.geoSample({time:Date.now(),lat:root.vehicle.coordinate.latitude,lon:root.vehicle.coordinate.longitude,
                    heading:root.vehicle.heading ? root.vehicle.heading.rawValue : NaN,depth:depthM,temp:waterTempC})
  }
 }
}