import QtQuick

QtObject {
 id:root
 property var vehicle
 property int leftServoOutput: 9
 property int rightServoOutput: 10
 property int leftClosedPwm: 1500
 property int leftOpenPwm: 1900
 property int rightClosedPwm: 1500
 property int rightOpenPwm: 1900
 property int releaseHoldMs: 900
 property bool calibrated: false
 property bool leftOpen: false
 property bool rightOpen: false
 property bool commandPending: false
 property string lastCommand: ""
 readonly property int mavCompAutopilot1: 1
 readonly property int mavCmdDoSetServo: 183
 signal commandSent(string text)
 signal commandRejected(string reason)

 function setServo(output,pwm){
  if(!vehicle){commandRejected("H743/MAVLink indisponibil");return false}
  if(!calibrated){commandRejected("Cuve necalibrate");return false}
  if(!vehicle.sendCommand){commandRejected("Interfața MAVLink nu poate trimite comenzi");return false}
  vehicle.sendCommand(mavCompAutopilot1,mavCmdDoSetServo,true,output,pwm,0,0,0,0,0)
  commandPending=true
  lastCommand="SERVO "+output+" -> "+pwm+" us"
  return true
 }
 function release(hopper){
  if(!calibrated){commandRejected("Cuve necalibrate - comanda blocată");return false}
  var ok=true
  if(hopper===1||hopper===3)ok=setServo(leftServoOutput,leftOpenPwm)&&ok
  if(hopper===2||hopper===3)ok=setServo(rightServoOutput,rightOpenPwm)&&ok
  if(!ok)return false
  pendingHopper=hopper;closeTimer.restart()
  commandSent(hopper===3?"Comandă trimisă: deschide ambele cuve":(hopper===1?"Comandă trimisă: deschide cuva stânga":"Comandă trimisă: deschide cuva dreapta"))
  return true
 }
 property int pendingHopper:0
 property Timer closeTimer:Timer{interval:root.releaseHoldMs;repeat:false;onTriggered:{if(root.pendingHopper===1||root.pendingHopper===3)root.setServo(root.leftServoOutput,root.leftClosedPwm);if(root.pendingHopper===2||root.pendingHopper===3)root.setServo(root.rightServoOutput,root.rightClosedPwm);root.leftOpen=false;root.rightOpen=false;root.commandSent("Comandă trimisă: închide cuva/cuvele");root.commandPending=false;root.pendingHopper=0}}
}
