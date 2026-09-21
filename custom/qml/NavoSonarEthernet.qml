import QtQuick
import NavoSmart.Backend 1.0
QtObject {
 id: root
 property alias host: transportObject.host
 property alias port: transportObject.port
 property alias udp: transportObject.udp
 readonly property bool connected: transportObject.connected
 readonly property string status: transportObject.status
 readonly property bool dataAlive: transportObject.dataAlive
 property alias depthM: decoderObject.depthM
 property alias waterTempC: decoderObject.waterTempC
 property alias echoSamples: decoderObject.echoSamples
 property var vehicle
 property int rxBytes: 0
 property int rxChunks: 0
 signal geoSample(var sample)
 function connectSonar(){ transportObject.connectEndpoint() }
 function disconnectSonar(){ transportObject.disconnectEndpoint(); decoderObject.reset() }
 function connectToSonar(){ connectSonar() }
 function disconnectFromSonar(){ disconnectSonar() }
 property NavoEthernetTransport transport: NavoEthernetTransport {
  id: transportObject
  onBytesReceived: function(data){ root.rxBytes += data.length; root.rxChunks += 1; decoderObject.feedBytes(data) }
 }
 property NavoKoggerDecoder decoder: NavoKoggerDecoder {
  id: decoderObject
  onDepthChanged: {
   if(root.vehicle && root.vehicle.coordinate && root.vehicle.coordinate.isValid && !isNaN(depthM))
    root.geoSample({time:Date.now(),lat:root.vehicle.coordinate.latitude,lon:root.vehicle.coordinate.longitude,
                    heading:root.vehicle.heading ? root.vehicle.heading.rawValue : NaN,depth:depthM,temp:waterTempC})
  }
 }
}