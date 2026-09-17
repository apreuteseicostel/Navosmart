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
 readonly property int mavCompAutopilot1: 1
 readonly property int mavCmdDoSetServo: 183
 signal commandSent(string text)

 function setServo(output,pwm){
  if(!vehicle||!calibrated)return false
  vehicle.sendCommand(mavCompAutopilot1,mavCmdDoSetServo,true,output,pwm,0,0,0,0,0)
  return true
 }
 function release(hopper){
  if(!calibrated){commandSent("Cuve necalibrate - comanda blocată");return false}
  if(hopper===1||hopper===3)setServo(leftServoOutput,leftOpenPwm)
  if(hopper===2||hopper===3)setServo(rightServoOutput,rightOpenPwm)
  pendingHopper=hopper;closeTimer.restart();commandSent(hopper===3?"Ambele cuve deschise":(hopper===1?"Cuva stânga deschisă":"Cuva dreapta deschisă"));return true
 }
 property int pendingHopper:0
 property Timer closeTimer:Timer{interval:root.releaseHoldMs;repeat:false;onTriggered:{if(root.pendingHopper===1||root.pendingHopper===3)root.setServo(root.leftServoOutput,root.leftClosedPwm);if(root.pendingHopper===2||root.pendingHopper===3)root.setServo(root.rightServoOutput,root.rightClosedPwm);root.commandSent("Cuva/cuve închise");root.pendingHopper=0}}
}
