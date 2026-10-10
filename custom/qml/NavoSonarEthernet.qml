import QtQuick
import NavoSmart.Backend 1.0
QtObject {
 id: root
 property alias host: transportObject.host
 property alias port: transportObject.port
 property alias udp: transportObject.udp
 property alias autoReconnect: transportObject.autoReconnect
 readonly property bool connected: transportObject.connected || replayMode
 readonly property bool replayActive: replayObject.active
 readonly property bool replayPaused: replayObject.paused
 readonly property double replaySpeed: replayObject.speed
 readonly property double replayPosition: replayObject.position
 readonly property double replaySize: replayObject.size
 readonly property string replayError: replayObject.error
 readonly property bool recording: recorderObject.recording
 readonly property double recordingBytes: recorderObject.bytes
 readonly property string recordingError: recorderObject.error
 readonly property string recordingSavedName: recorderObject.savedName
 readonly property var recordings: recorderObject.sessions
 property NavoKoggerRecorder recorder: NavoKoggerRecorder { id: recorderObject }
 function startRecording(name) { return !replayMode && dataAlive && recorderObject.start(name) }
 function stopRecording() { return recorderObject.stop() }
 function refreshRecordings() { recorderObject.refresh() }
 property bool replayMode: false
 function startReplay(url) {
  recorderObject.stop(); transportObject.disconnectEndpoint(); replayObject.stop(); decoderObject.reset()
  replayMode=true; chartBridge.setConnectionEndpoint('replay:'+String(url),1,false)
  chartBridge.clear(); chartBridge.setPosition(NaN,NaN,NaN,NaN,NaN)
  var opened=replayObject.open(url)
  if(!opened)stopReplay()
  return opened
 }
 function stopReplay() { replayObject.stop(); replayMode=false; decoderObject.reset(); chartBridge.setConnectionEndpoint(root.host,root.port,root.udp); root.updateNativePosition() }
 function pauseReplay(paused) { replayObject.setPaused(paused) }
 function setReplaySpeed(speed) { replayObject.setSpeed(speed) }
 property NavoKoggerReplay replay: NavoKoggerReplay {
  id: replayObject
  onPositionReady: function(lat,lon,heading,pitch,roll) { chartBridge.setPosition(lat,lon,heading,pitch,roll) }
  onBytesReady: function(data) { decoderObject.feedBytes(data) }
 }
 onNativeCapacityFullChanged: replayObject.setBlocked(nativeCapacityFull)
 readonly property string status: transportObject.status
 property double lastDepthMs: 0
 property double lastEchoMs: 0
 property double clockMs: 0
 readonly property bool dataAlive: !replayMode && transportObject.dataAlive && echoFresh
 readonly property bool echoFresh: !replayMode && connected && decoderObject.chartRawByteCount>0 && lastEchoMs>0 && clockMs-lastEchoMs<1500
 readonly property real bottomEchoStrength: computeBottomEchoStrength(decoderObject.echoSamples)
 function computeBottomEchoStrength(samples){ if(!echoFresh||!samples||!samples.length)return NaN; var n=Math.max(3,Math.floor(samples.length*0.10)),sum=0,cnt=0; for(var i=Math.max(0,samples.length-n);i<samples.length;i++){var v=Number(samples[i]);if(isFinite(v)){sum+=v;cnt++}} return cnt?sum/cnt:NaN }
 property Timer freshness: Timer { interval:500; repeat:true; running:true; onTriggered:root.clockMs=Date.now() }
 property alias depthM: decoderObject.depthM
 property alias waterTempC: decoderObject.waterTempC
 property alias echoSamples: decoderObject.echoSamples
 property alias compensatedSamples: decoderObject.compensatedSamples
 property alias chartRawBytes: decoderObject.chartRawBytes
 readonly property int chartRawByteCount: decoderObject.chartRawByteCount
 readonly property int chartResolution: decoderObject.chartResolution
 readonly property int chartAbsoluteOffset: decoderObject.chartAbsoluteOffset
 readonly property double chartSequence: decoderObject.chartSequence
 readonly property int chartVersion: decoderObject.chartVersion
 readonly property real chartResolutionMeters: decoderObject.chartResolutionMeters
 readonly property real chartOffsetMeters: decoderObject.chartOffsetMeters
 readonly property real chartRangeMeters: decoderObject.chartRangeMeters
 readonly property real processedBottomDepthM: chartBridge.bottomDepthM
 readonly property int processedColumns: chartBridge.processedColumns
 readonly property var nativeSurfaceMesh: chartBridge.nativeSurfaceMesh
 readonly property int bathymetryTileCount: chartBridge.bathymetryTileCount
 readonly property int mosaicTileCount: chartBridge.mosaicTileCount
 readonly property bool nativeChannelReady: chartBridge.channelReady
 readonly property bool nativeCapacityFull: chartBridge.capacityFull
 property var vehicle
 property int rxBytes: 0
 property int rxChunks: 0
 readonly property int nativeChartRecords: chartBridge.recordCount
 readonly property int nativeChartRejected: chartBridge.rejectedColumns
 readonly property double nativeChartRawBytes: chartBridge.retainedRawBytes
 onVehicleChanged: updateNativePosition()
 function updateNativePosition(){
  if(replayMode)return
  var fixValid=!replayMode && vehicle && vehicle.gps && vehicle.gps.lock.rawValue>=3 &&
               vehicle.vehicleLinkManager && !vehicle.vehicleLinkManager.communicationLost
  var c=fixValid && vehicle.coordinate ? vehicle.coordinate : null
  var lat=c && c.isValid ? c.latitude : NaN, lon=c && c.isValid ? c.longitude : NaN
  chartBridge.setPosition(lat,
                          lon,
                          vehicle && vehicle.heading ? vehicle.heading.rawValue : NaN,
                          vehicle && vehicle.pitch ? vehicle.pitch.rawValue : NaN,
                          vehicle && vehicle.roll ? vehicle.roll.rawValue : NaN)
 }
 property NavoKoggerChartBridge nativeBridge: NavoKoggerChartBridge {
  id: chartBridge
  Component.onCompleted: { setConnectionEndpoint(root.host,root.port,root.udp); setDecoder(decoderObject); root.updateNativePosition() }
  onGeoSampleReady: function(sample){ var published={}; for(var key in sample)published[key]=sample[key]; published.replay=root.replayMode; root.geoSample(published) }
  onBottomColumnReady: function(sequence,depth){root.bottomColumnReady(sequence,depth)}
 }
 property Timer nativeSurfaceRefresh: Timer {
  interval:2000; repeat:true; running:root.connected
  onTriggered:chartBridge.requestReplaySurface()
 }
 property Connections gpsUpdates: Connections {
  target: root.vehicle || null
  ignoreUnknownSignals: true
  function onCoordinateChanged(){root.updateNativePosition()}
 }
 property Connections fixUpdates: Connections {
  target: root.vehicle && root.vehicle.gps ? root.vehicle.gps.lock : null
  ignoreUnknownSignals: true
  function onRawValueChanged(){root.updateNativePosition()}
 }
 property Connections linkUpdates: Connections {
  target: root.vehicle ? root.vehicle.vehicleLinkManager : null
  ignoreUnknownSignals: true
  function onCommunicationLostChanged(){root.updateNativePosition()}
 }
 signal geoSample(var sample)
 signal bottomColumnReady(double sequence,real depth)
 function connectSonar(){ stopReplay(); transportObject.connectEndpoint() }
 function disconnectSonar(){ recorderObject.stop(); stopReplay(); transportObject.disconnectEndpoint(); decoderObject.reset() }
 function connectToSonar(){ connectSonar() }
 function disconnectFromSonar(){ disconnectSonar() }
 property NavoEthernetTransport transport: NavoEthernetTransport {
  id: transportObject
  onConnectedChanged: if(!connected && !root.replayMode) { root.lastDepthMs=0; root.lastEchoMs=0; decoderObject.reset() }
  onEndpointChanged: { recorderObject.stop(); decoderObject.reset(); chartBridge.setConnectionEndpoint(host,port,udp) }
  onBytesReceived: function(data){ if(root.replayMode)return; root.rxBytes += data.length; root.rxChunks += 1;
   var v=root.vehicle
   var valid=v && v.gps && v.gps.lock.rawValue>=3 && v.vehicleLinkManager && !v.vehicleLinkManager.communicationLost && v.coordinate && v.coordinate.isValid
   recorderObject.append(data,valid?v.coordinate.latitude:NaN,valid?v.coordinate.longitude:NaN,
                         v && v.heading?v.heading.rawValue:NaN,v && v.pitch?v.pitch.rawValue:NaN,v && v.roll?v.roll.rawValue:NaN)
   decoderObject.feedBytes(data) }
 }
 property NavoKoggerDecoder decoder: NavoKoggerDecoder {
  id: decoderObject
  onEchoSamplesChanged: {
   if(!chartRawByteCount){root.lastEchoMs=0;return}
   root.lastEchoMs=Date.now(); root.clockMs=root.lastEchoMs
   if(root.nativeChannelReady && decoderObject.chartVersion===0)return
   // Publish only completed CHART columns paired with recent depth and valid GPS.
   if(root.replayMode || !isFinite(depthM) || depthM<=0 || root.lastDepthMs<=0 ||
      root.lastEchoMs-root.lastDepthMs>1500 || !root.vehicle ||
      !root.vehicle.coordinate || !root.vehicle.coordinate.isValid) return
   root.geoSample({time:root.lastEchoMs,lat:root.vehicle.coordinate.latitude,
                   lon:root.vehicle.coordinate.longitude,
                   heading:root.vehicle.heading ? root.vehicle.heading.rawValue : NaN,
                   depth:depthM,temp:waterTempC,bottomEcho:root.bottomEchoStrength,
                   chartResolution:decoderObject.chartResolution,
                   chartAbsoluteOffset:decoderObject.chartAbsoluteOffset,
                   chartVersion:decoderObject.chartVersion,
                   chartResolutionMeters:decoderObject.chartResolutionMeters,
                   chartOffsetMeters:decoderObject.chartOffsetMeters,
                   chartRangeMeters:decoderObject.chartRangeMeters})
  }
  onDepthChanged: {
   if(!isFinite(depthM) || depthM<=0) return
   root.lastDepthMs=Date.now(); root.clockMs=root.lastDepthMs
  }
 }
}
