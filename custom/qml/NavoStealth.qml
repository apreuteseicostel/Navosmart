import QtQuick
import QtCore

QtObject {
    id: root
    property var vehicle: null
    property bool linkReady: false
    property bool replayMode: false
    property bool gpsReady: false
    property bool navigationActive: false // NAVO direct GoTo/Area Scan only
    property string flightMode: ""
    property real nominalSpeedMps: 1.5
    property bool lightsReady: false
    property bool lightCommandBusy: false // Transient hopper request is not an offline V3 light service.
    property string lightUnavailableReason: ""
    property var dispatchLight: null // Shared dashboard MAVLink 31001 path; returns bool if accepted for dispatch.
    property bool headlightOn: false
    property bool positionLightsOn: false
    property bool active: false // Session only: never auto-enable at startup/reconnect.
    property string lightState: "OFF"
    property string speedState: "Viteză nemodificată"
    property string message: "Stealth dezactivat"
    property bool previousHead: false
    property bool capturedLights: false
    property bool lightOverride: false
    property double requestedAt: 0
    property string speedToken: ""
    property Settings preferences: Settings {
        category: "NavoStealth"
        property int speedTenths: 6
    }
    readonly property real speedLimitMps: Math.max(2, Math.min(15, preferences.speedTenths)) / 10
    readonly property bool canActivate: !!vehicle && linkReady && !replayMode
    readonly property bool navigationMode: ["AUTO", "GUIDED"].indexOf(flightMode.toUpperCase()) >= 0
    signal lightRequested(int target, int value)
    signal speedRequested(real metersPerSecond)

    function sendLight(target,value) {
        if(typeof dispatchLight==="function")return dispatchLight(target,value)===true
        lightRequested(target,value) // Kept for isolated QML/component harnesses.
        return true
    }
    function setSpeedLimit(tenths) {
        if(!Number.isInteger(tenths) || tenths<2 || tenths>15)return false
        preferences.speedTenths=tenths
        speedToken=""
        observe()
        return true
    }
    function capSpeed(speed) {
        return active && isFinite(speed) && speed>0 ? Math.min(speed, speedLimitMps) : speed
    }
    function activate() {
        if(active || !canActivate)return false
        active=true;capturedLights=false;lightOverride=false;speedToken=""
        message="Stealth activ • avertizările critice rămân sonore"
        applyLights();observe();return true
    }
    function deactivate(restore) {
        var restoreHead=restore && active && capturedLights && !lightOverride && lightsReady && !lightCommandBusy && !headlightOn
        active=false;lightState="OFF";message="Stealth dezactivat";speedToken=""
        // Explicit user deactivation only; never restore on lost link, replay or vehicle change.
        if(restore && canActivate && gpsReady && navigationActive && navigationMode && isFinite(nominalSpeedMps) && nominalSpeedMps>0) {
            speedRequested(nominalSpeedMps);speedState="Viteză normală solicitată H743"
        } else speedState="Viteză nemodificată"
        if(restoreHead && canActivate && previousHead)sendLight(1,1)
        // Never turn position lights off on exit. Pilot can control them separately.
        capturedLights=false
    }
    function applyLights() {
        if(!active || !canActivate)return false
        if(!lightsReady){lightState="UNAVAILABLE";return false}
        if(lightCommandBusy){lightState="BUSY";return false}
        if(!capturedLights){previousHead=headlightOn;capturedLights=true}
        lightOverride=false
        if(!positionLightsOn) {
            if(!sendLight(2,1)){lightState="FAILED";return false}
            lightState="POSITIONS"
        } else if(headlightOn) {
            if(!sendLight(1,0)){lightState="FAILED";return false}
            lightState="HEAD"
        } else lightState="CONFIRMED"
        requestedAt=Date.now()
        return true
    }
    function manualLightOverride() {
        if(!active)return
        lightOverride=true;lightState="PILOT"
    }
    function observe() {
        if(!active)return
        if(!vehicle || !linkReady || replayMode){deactivate(false);message="Stealth oprit • reconectarea nu reactivează profilul";return}
        if(!navigationActive || !navigationMode || !gpsReady) {
            speedToken="";speedState="MANUAL/HOLD/RTL • viteză nemodificată"
        } else {
            var wanted=capSpeed(nominalSpeedMps)
            var token=flightMode+":"+wanted
            if(isFinite(wanted) && wanted>0 && token!==speedToken){speedToken=token;speedRequested(wanted);speedState="Limită solicitată H743 • "+wanted.toFixed(1)+" m/s"}
        }
        if(lightOverride)return
        if(!lightsReady){lightState="UNAVAILABLE";return}
        if(lightState==="POSITIONS" && positionLightsOn) {
            if(headlightOn) {
                if(lightCommandBusy)return
                if(sendLight(1,0)){lightState="HEAD";requestedAt=Date.now()}
                else lightState="FAILED"
            } else lightState="CONFIRMED"
        }
        if(lightState==="HEAD" && !headlightOn && positionLightsOn)lightState="CONFIRMED"
        if(lightState==="CONFIRMED" && (headlightOn || !positionLightsOn))lightState="CHANGED"
        if((lightState==="POSITIONS" || lightState==="HEAD") && Date.now()-requestedAt>5000)lightState="TIMEOUT"
    }
    onVehicleChanged: if(active)deactivate(false)
    onLinkReadyChanged: observe()
    onReplayModeChanged: observe()
    property Timer monitor: Timer { interval:250;repeat:true;running:root.active;onTriggered:root.observe() }
}
