import QtQuick
import QtPositioning

QtObject {
    id: root
    property var vehicle
    property var targetWaypoint: null
    property string targetName: ""
    property int hopper: 0
    property bool rtlAfterDrop: true
    property bool enabled: false
    property bool silentMode: false
    property real manualSilentSpeedMps: 0.6

    property real silentRadiusM: 10.0
    property real finalRadiusM: 3.0
    property real normalSpeedMps: 1.5
    property real silentSpeedMps: 0.8
    property real finalSpeedMps: 0.4
    property real arrivalRadiusM: 1.0
    property real releaseMaxSpeedMps: 0.12
    property int settleMs: 2000
    property int postDropMs: 2000
    property real exitDistanceM: 4.0
    property real exitArrivalRadiusM: 0.8
    property int exitSide: 1
    property int gpsLossGraceMs: 1500

    property real commandedSpeedMps: 0.0
    property real targetSpeedMps: 0.0
    property real accelerationMps2: 0.35
    property real decelerationMps2: 0.45
    property int rampIntervalMs: 100
    property int invalidGpsSinceMs: 0

    readonly property int idleState:0
    readonly property int navigateState:1
    readonly property int approachState:2
    readonly property int finalApproachState:3
    readonly property int settleState:4
    readonly property int releaseState:5
    readonly property int exitState:6
    readonly property int returnHomeState:7
    readonly property int completeState:8
    readonly property int abortedState:9
    property int state: idleState
    property var arrivalOrigin: QtPositioning.coordinate()
    property var exitCoordinate: QtPositioning.coordinate()

    signal speedRequested(real metersPerSecond)
    signal stopRequested(string reason)
    signal hopperReleaseRequested(int hopper)
    signal gotoRequested(var coordinate, string reason)
    signal rtlRequested()
    signal stateChangedDetailed(int state, string text)
    signal cycleFinished(bool success, string message)
    signal silentModeChangedDetailed(bool active)

    function stateText(s) {
        switch(s) {
        case idleState:return "Pregătit"; case navigateState:return "Navigare"; case approachState:return "Apropiere silențioasă"
        case finalApproachState:return "Apropiere finală"; case settleState:return "Stabilizare"; case releaseState:return "Eliberare nadă"
        case exitState:return "Ieșire din punct"; case returnHomeState:return "Întoarcere HOME"; case completeState:return "Finalizat"; case abortedState:return "Oprit"
        } return "--"
    }
    function setState(s){ if(state===s)return; state=s; stateChangedDetailed(state,stateText(state)) }
    function validTarget(){ return targetWaypoint && targetWaypoint.coordinate && targetWaypoint.coordinate.isValid }
    function vehicleCoordinateValid(){ return vehicle && vehicle.coordinate && vehicle.coordinate.isValid }
    function groundSpeed(){ return vehicle && vehicle.groundSpeed && !isNaN(vehicle.groundSpeed.rawValue) ? vehicle.groundSpeed.rawValue : NaN }
    function distanceToTarget(){ return vehicleCoordinateValid() && validTarget() ? vehicle.coordinate.distanceTo(targetWaypoint.coordinate) : NaN }
    function distanceToExit(){ return vehicleCoordinateValid() && exitCoordinate && exitCoordinate.isValid ? vehicle.coordinate.distanceTo(exitCoordinate) : NaN }
    function setTargetSpeed(v){ targetSpeedMps=Math.max(0,v); if(!rampTimer.running)rampTimer.start() }
    function toggleSilentMode(){ silentMode=!silentMode; silentModeChangedDetailed(silentMode); if(!enabled)setTargetSpeed(silentMode?manualSilentSpeedMps:normalSpeedMps) }

    function startCycle(wp,name,selectedHopper){
        if(!vehicle || !wp || !wp.coordinate || !wp.coordinate.isValid || !vehicleCoordinateValid()){ cycleFinished(false,"Barca, GPS-ul sau waypoint-ul nu sunt disponibile"); return false }
        targetWaypoint=wp; targetName=name; hopper=selectedHopper; arrivalOrigin=vehicle.coordinate; enabled=true; invalidGpsSinceMs=0
        setState(navigateState); setTargetSpeed(silentMode?silentSpeedMps:normalSpeedMps); gotoRequested(targetWaypoint.coordinate,"bait-target"); monitorTimer.start(); return true
    }
    function abortCycle(reason){
        enabled=false; monitorTimer.stop(); settleTimer.stop(); postDropTimer.stop(); setTargetSpeed(0); stopRequested(reason||"Oprire de siguranță")
        setState(abortedState); cycleFinished(false,reason||"Ciclul de nădire a fost oprit")
    }
    function makeExitCoordinate(){
        if(!validTarget() || !arrivalOrigin || !arrivalOrigin.isValid)return QtPositioning.coordinate()
        var b=arrivalOrigin.azimuthTo(targetWaypoint.coordinate)+(exitSide>=0?90:-90); if(b<0)b+=360;if(b>=360)b-=360
        return targetWaypoint.coordinate.atDistanceAndAzimuth(exitDistanceM,b)
    }
    function update(){
        if(!enabled)return
        if(!vehicleCoordinateValid()){
            if(invalidGpsSinceMs===0)invalidGpsSinceMs=Date.now()
            else if(Date.now()-invalidGpsSinceMs>=gpsLossGraceMs)abortCycle("GPS/poziție pierdută")
            return
        }
        invalidGpsSinceMs=0
        if(state===exitState){
            var ex=distanceToExit()
            if(!isNaN(ex) && ex<=exitArrivalRadiusM)finishExit()
            return
        }
        if(!validTarget())return
        var d=distanceToTarget(); if(isNaN(d))return
        if((state===navigateState||state===approachState||state===finalApproachState)&&d<=arrivalRadiusM){
            setTargetSpeed(0); stopRequested("Punct de nădire atins"); setState(settleState); settleTimer.restart(); return
        }
        if(state===navigateState&&d<=silentRadiusM){setState(approachState);setTargetSpeed(silentSpeedMps)}
        if((state===navigateState||state===approachState)&&d<=finalRadiusM){setState(finalApproachState);setTargetSpeed(finalSpeedMps)}
    }

    property Timer rampTimer: Timer {
        interval:root.rampIntervalMs; repeat:true
        onTriggered:{
            var dt=interval/1000.0,diff=root.targetSpeedMps-root.commandedSpeedMps
            if(Math.abs(diff)<0.01){root.commandedSpeedMps=root.targetSpeedMps;if(root.commandedSpeedMps>0.05)root.speedRequested(root.commandedSpeedMps);stop();return}
            var step=(diff>0?root.accelerationMps2:root.decelerationMps2)*dt
            root.commandedSpeedMps=Math.abs(diff)<=step?root.targetSpeedMps:root.commandedSpeedMps+(diff>0?step:-step)
            if(root.commandedSpeedMps>0.05)root.speedRequested(root.commandedSpeedMps)
        }
    }
    property Timer monitorTimer: Timer { interval:200; repeat:true; onTriggered:root.update() }
    property Timer settleTimer: Timer {
        interval:root.settleMs; repeat:false
        onTriggered:{
            var s=root.groundSpeed()
            if(!isNaN(s)&&s>root.releaseMaxSpeedMps){root.stopRequested("Aștept oprirea completă");restart();return}
            root.setState(root.releaseState); if(root.hopper!==0)root.hopperReleaseRequested(root.hopper); root.postDropTimer.restart()
        }
    }
    property Timer postDropTimer: Timer {
        interval:root.postDropMs; repeat:false
        onTriggered:{
            root.exitCoordinate=root.makeExitCoordinate()
            if(root.exitCoordinate&&root.exitCoordinate.isValid){root.setState(root.exitState);root.setTargetSpeed(root.silentSpeedMps);root.gotoRequested(root.exitCoordinate,"clear-bait-zone")}
            else root.finishExit()
        }
    }
    function finishExit(){
        if(rtlAfterDrop){setState(returnHomeState);setTargetSpeed(silentMode?manualSilentSpeedMps:normalSpeedMps);rtlRequested()} else setState(completeState)
        enabled=false;monitorTimer.stop();cycleFinished(true,rtlAfterDrop?"Nada eliberată; RTL pornit":"Nada eliberată")
    }
}
