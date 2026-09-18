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
 signal geoSample(var sample)
 function connectSonar(){ transport.connectEndpoint() }
 function disconnectSonar(){ transport.disconnectEndpoint(); decoder.reset() }
 NavoEthernetTransport {
  id: transport
  onBytesReceived: function(data){ decoder.feedBytes(data) }
 }
 NavoKoggerDecoder {
  id: decoder
  onDepthChanged: {
   if(root.vehicle && root.vehicle.coordinate && root.vehicle.coordinate.isValid && !isNaN(depthM))
    root.geoSample({time:Date.now(),lat:root.vehicle.coordinate.latitude,lon:root.vehicle.coordinate.longitude,
                    heading:root.vehicle.heading ? root.vehicle.heading.rawValue : NaN,depth:depthM,temp:waterTempC})
  }
 }
}