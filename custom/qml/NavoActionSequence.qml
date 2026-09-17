import QtQuick
QtObject {
    id: root
    property var vehicle
    property var hopperBridge
    property bool running:false
    property var actions:[]
    property int index:-1
    signal status(string text)
    signal finished(bool success)
    function start(sequence){ if(running||!vehicle)return false; actions=sequence||[];index=-1;running=true;next();return true }
    function abort(reason){running=false;timer.stop();if(vehicle)vehicle.pauseVehicle();status(reason);finished(false)}
    function next(){if(!running)return;index++;if(index>=actions.length){running=false;finished(true);return}execute(actions[index])}
    function execute(a){
        if(!a){next();return}
        if(a.type==="hold"){vehicle.pauseVehicle();wait(a.ms||1500)}
        else if(a.type==="rtl"){vehicle.guidedModeRTL(false);running=false;finished(true)}
        else if(a.type==="speed"){vehicle.guidedModeChangeGroundSpeedMetersSecond(a.value);next()}
        else if(a.type==="hopper"){if(!hopperBridge||!hopperBridge.release(a.value)){abort("Cuva necalibrată");return}wait(a.ms||1200)}
        else next()
    }
    function wait(ms){timer.interval=ms;timer.restart()}
    property Timer timer:Timer{repeat:false;onTriggered:root.next()}
}