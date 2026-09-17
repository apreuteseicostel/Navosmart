import QtQuick

QtObject {
 id:root
 property var vehicle
 property bool enabled:true
 property int linkGraceSeconds:30
 property int gpsRecoverySeconds:60
 property int gpsReturnHomeSeconds:120
 property int minGpsFix:3
 property bool linkLost:false
 property bool gpsLost:false
 property int linkLostSince:0
 property int gpsLostSince:0
 property bool gpsRecoveryPending:false
 property string status:"OK"
 signal holdRequested(string reason)
 signal rtlRequested(string reason)
 signal recovered(string subsystem,string action)

 function now(){return Date.now()}
 function gpsHealthy(){return vehicle && vehicle.gps && vehicle.gps.lock.rawValue>=minGpsFix && vehicle.coordinate && vehicle.coordinate.isValid}
 // QGC Vehicle exposes connectionLost; H743's own FS_GCS_* remains the authoritative
 // protection if the Android app itself disappears.
 function linkHealthy(){return vehicle && !vehicle.connectionLost}

 function tick(){
  if(!enabled||!vehicle)return
  var lh=linkHealthy()
  if(!lh){
   if(!linkLost){linkLost=true;linkLostSince=now();status="LINK PIERDUT • reconectare"}
   var ls=Math.floor((now()-linkLostSince)/1000)
   if(ls>=linkGraceSeconds){status="LINK PIERDUT • failsafe H743";rtlRequested("Legătura G20/GR01 nu a revenit")}
  } else if(linkLost){
   linkLost=false;linkLostSince=0;status="LINK RESTABILIT";recovered("LINK","Control disponibil din nou")
  }

  var gh=gpsHealthy()
  if(!gh){
   if(!gpsLost){gpsLost=true;gpsLostSince=now();gpsRecoveryPending=true;status="GPS PIERDUT • HOLD";holdRequested("GPS/poziție invalidă")}
   var gs=Math.floor((now()-gpsLostSince)/1000)
   if(gs<gpsRecoverySeconds)status="GPS PIERDUT • HOLD • "+gs+"s"
   else status="GPS PIERDUT • HOLD • aștept recuperarea"
  } else if(gpsLost){
   var outage=Math.floor((now()-gpsLostSince)/1000)
   gpsLost=false;gpsLostSince=0
   if(outage>=gpsReturnHomeSeconds){status="GPS RESTABILIT • RTL";rtlRequested("GPS a revenit după timeout")}
   else {status="GPS RESTABILIT";recovered("GPS",outage<gpsRecoverySeconds?"Poate continua după confirmare":"Poziție recuperată; aștept confirmare")}
  }
 }
 property Timer timer:Timer{interval:500;repeat:true;running:root.enabled;onTriggered:root.tick()}
}
