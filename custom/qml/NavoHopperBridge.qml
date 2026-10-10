import QtQuick

QtObject {
 id:root
 signal servoCommandFailed(string reason)
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
 onVehicleChanged: resetServoFeedback()
 function receiveServoResult(vehicleId,component,command,result,failure){
  if(!vehicle || vehicleId!==vehicle.id || component!==mavCompAutopilot1 || command!==mavCmdDoSetServo)return false
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
 function release(hopper){
  if(hopper!==1 && hopper!==2 && hopper!==3){commandRejected("Selecție cuvă invalidă");return false}
  if(commandPending){commandRejected("Comandă cuvă deja în curs");return false}
  if(!calibrated){commandRejected("Cuve necalibrate - comanda blocată");return false}
  if(!releaseAllowed){commandRejected("Așteaptă telemetria Nano sau timeout-ul de două secunde");return false}
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
