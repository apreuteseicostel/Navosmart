import QtQuick

QtObject {
 id:root
 signal servoCommandFailed(string reason)
 property bool onboardTiming: false
 property var hardwareTelemetry: null
 property var nextRequest: null
 property int onboardRequest: 0
 property bool onboardCycleComplete: false
 property var vehicle
 property int leftServoOutput: 9
 property int rightServoOutput: 10
 property int leftClosedPwm: 1500
 property int leftOpenPwm: 1900
 property int rightClosedPwm: 1500
 property int rightOpenPwm: 1900
 property int releaseHoldMs: 900
 property bool calibrated: false
 property bool releaseAllowed: true
 property bool leftOpen: false
 property bool rightOpen: false
 property bool commandPending: false
 property string lastCommand: ""
 // leftOpen/rightOpen are requested servo states, not sensor feedback.
 property string servoResponse: "Niciun răspuns servo H743"
 property double servoResponseAtMs: 0
 readonly property bool physicalPositionConfirmed: false
 readonly property string physicalPositionStatus: "Poziția fizică a cuvelor: neconfirmată"
 readonly property int mavCompAutopilot1: 1
 readonly property int mavCmdDoSetServo: 183
 signal commandSent(string text)
 signal commandRejected(string reason)

 function resetServoFeedback(){
  servoResponse="Niciun răspuns servo H743";servoResponseAtMs=0
 }
 onVehicleChanged: {
  resetServoFeedback()
  if(onboardTiming){onboardWatchdog.stop();onboardRequest=0;onboardCycleComplete=false;commandPending=false;leftOpen=false;rightOpen=false}
 }
 function receiveServoResult(vehicleId,component,command,result,failure){
  if(!vehicle || vehicleId!==vehicle.id || component!==mavCompAutopilot1)return false
  if(onboardTiming && command===31001 && commandPending){
   if(failure!==0 || (result!==0 && result!==5)){
    onboardWatchdog.stop();commandPending=false;onboardCycleComplete=false
    servoCommandFailed("H743 a respins ciclul cuvelor sau nu a confirmat comanda")
   }
   return true
  }
  if(command!==mavCmdDoSetServo)return false
  // QGC's result is command-level and cannot identify an individual output.
  // Never use this to assert the physical position of either hopper.
  if(failure===1)servoResponse="Servo H743: fără răspuns (timeout)"
  else if(failure===2)servoResponse="Servo H743: comandă duplicată netrimisă"
  else if(failure!==0)servoResponse="Servo H743: eroare de trimitere"
  else if(result===0)servoResponse="Ultimul răspuns servo H743: acceptat"
  else if(result===5)servoResponse="Ultimul răspuns servo H743: în curs"
  else servoResponse="Ultimul răspuns servo H743: respins ("+result+")"
  servoResponseAtMs=Date.now()
  if(failure!==0 || (result!==0 && result!==5))servoCommandFailed(servoResponse)
  return true
 }
 property Connections servoResults: Connections {
  target:root.vehicle || null
  ignoreUnknownSignals:true
  function onMavCommandResult(vehicleId,targetComponent,command,ackResult,failureCode){
   root.receiveServoResult(vehicleId,targetComponent,command,ackResult,failureCode)
  }
 }

 function canSendServo(output,pwm){
  if(!vehicle){commandRejected("H743/MAVLink indisponibil");return false}
  if(!calibrated){commandRejected("Cuve necalibrate");return false}
  if(!vehicle.vehicleLinkManager || vehicle.vehicleLinkManager.communicationLost){commandRejected("Legătura H743 este pierdută");return false}
  if(!Number.isInteger(output) || output<1 || output>16 || !Number.isInteger(pwm) || pwm<900 || pwm>2100){commandRejected("Ieșire/PWM cuvă invalidă");return false}
  if(!vehicle.sendCommand){commandRejected("Interfața MAVLink nu poate trimite comenzi");return false}
  return true
 }
 function setServo(output,pwm){
  if(!canSendServo(output,pwm))return false
  servoResponse="Comandă servo trimisă; răspuns H743 în așteptare";servoResponseAtMs=0
  vehicle.sendCommand(mavCompAutopilot1,mavCmdDoSetServo,true,output,pwm,0,0,0,0,0)
  commandPending=true
  lastCommand="SERVO "+output+" -> "+pwm+" us"
  return true
 }
 function sendOnboard(action,value){
  if(!vehicle || !vehicle.sendCommand || !vehicle.vehicleLinkManager || vehicle.vehicleLinkManager.communicationLost){commandRejected("H743 deconectat");return false}
  if(!hardwareTelemetry || !hardwareTelemetry.connected || !(hardwareTelemetry.capabilities & 8) || !hardwareTelemetry.hopperStateValid){commandRejected("Serviciul cuve H743/V3 indisponibil");return false}
  if(commandPending){commandRejected("Există deja o comandă H743 în așteptare");return false}
  if(action===3 && (!calibrated || !releaseAllowed || hardwareTelemetry.hopperMask!==0)){commandRejected("Cuve necalibrate sau ciclu activ");return false}
  var request=nextRequest ? nextRequest() : 0
  if(!request){commandRejected("Secvența comenzilor V3 indisponibilă");return false}
  onboardRequest=request;onboardCycleComplete=false;commandPending=true
  vehicle.sendCommand(mavCompAutopilot1,31001,true,action,value,request,
      leftServoOutput+32*rightServoOutput,leftClosedPwm+4096*leftOpenPwm,
      rightClosedPwm+4096*rightOpenPwm,releaseHoldMs)
  onboardWatchdog.restart()
  commandSent("Ciclu cuve solicitat H743; temporizare la bord")
  return true
 }
 function closeOnboard(){return sendOnboard(4,0)}
 function updateOnboard(){
  if(!onboardTiming || !hardwareTelemetry || !hardwareTelemetry.hopperStateValid)return
  leftOpen=(hardwareTelemetry.hopperMask & 1)!==0
  rightOpen=(hardwareTelemetry.hopperMask & 2)!==0
  if(commandPending && onboardRequest && hardwareTelemetry.lastRequest===onboardRequest && hardwareTelemetry.hopperMask===0){
   commandPending=false;onboardRequest=0;onboardCycleComplete=true;onboardWatchdog.stop()
   commandSent("H743 raportează ciclul închis; poziția mecanică neconfirmată")
  }
 }
 property Connections onboardUpdates: Connections {
  target:root.hardwareTelemetry
  ignoreUnknownSignals:true
  function onTelemetryChanged(){root.updateOnboard()}
 }
 property Timer onboardWatchdog: Timer {
  interval:5000;repeat:false
  onTriggered:{root.servoCommandFailed("Ciclu H743 neconfirmat; verifică telemetria și cuvele");root.commandPending=false;root.onboardRequest=0;root.onboardCycleComplete=false}
 }
 function release(hopper){
  if(hopper!==1 && hopper!==2 && hopper!==3){commandRejected("Selecție cuvă invalidă");return false}
  if(onboardTiming)return sendOnboard(3,hopper)
  if(commandPending){commandRejected("Comandă cuvă deja în curs");return false}
  if(!calibrated){commandRejected("Cuve necalibrate - comanda blocată");return false}
  if(!releaseAllowed){commandRejected("Cuve indisponibile: verifică legătura H743 și calibrarea");return false}
  if((hopper===1||hopper===3) && (!canSendServo(leftServoOutput,leftOpenPwm)||!canSendServo(leftServoOutput,leftClosedPwm)))return false
  if((hopper===2||hopper===3) && (!canSendServo(rightServoOutput,rightOpenPwm)||!canSendServo(rightServoOutput,rightClosedPwm)))return false
  if(hopper===3 && leftServoOutput===rightServoOutput){commandRejected("Ieșirile cuvelor trebuie să fie diferite");return false}
  var ok=true
  if(hopper===1||hopper===3)ok=setServo(leftServoOutput,leftOpenPwm)&&ok
  if(hopper===2||hopper===3)ok=setServo(rightServoOutput,rightOpenPwm)&&ok
  if(!ok)return false
  if(hopper===1||hopper===3)leftOpen=true
  if(hopper===2||hopper===3)rightOpen=true
  pendingHopper=hopper;closeTimer.restart()
  commandSent(hopper===3?"Comandă trimisă: deschide ambele cuve":(hopper===1?"Comandă trimisă: deschide cuva stânga":"Comandă trimisă: deschide cuva dreapta"))
  return true
 }
 function closePending(){
  if(onboardTiming)return closeOnboard()
  var ok=true
  if((pendingHopper===1||pendingHopper===3) && leftOpen){
   if(setServo(leftServoOutput,leftClosedPwm))leftOpen=false
   else ok=false
  }
  if((pendingHopper===2||pendingHopper===3) && rightOpen){
   if(setServo(rightServoOutput,rightClosedPwm))rightOpen=false
   else ok=false
  }
  if(!ok){closeTimer.restart();return false}
  commandPending=false;pendingHopper=0
  commandSent("Comandă trimisă: închide cuva/cuvele")
  return true
 }
 property int pendingHopper:0
 property Timer closeTimer:Timer{interval:root.releaseHoldMs;repeat:false;onTriggered:root.closePending()}
}
