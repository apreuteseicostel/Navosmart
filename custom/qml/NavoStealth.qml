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
    property bool lightCommandBusy: false // Reserved for optional V3 service, not required by ArduPilot Relay.
    property string lightUnavailableReason: ""
    property var dispatchLight: null // Single dashboard dispatcher, native MAV_CMD_DO_SET_RELAY (181).
    property bool relayMode: false // Use ArduPilot Relay1/Relay2; no independent light telemetry available.
    property bool headlightOn: false
    property bool positionLightsOn: false
    property bool active: false // Session only: never auto-enable at startup/reconnect.
    property string lightState: "OFF"
    // The same MAV_CMD_DO_SET_RELAY(181) cannot be sent twice until QGC
    // completes the first command with a terminal COMMAND_ACK.
    readonly property bool relayAckPending: relayMode && active &&
        (lightState==="RELAY_POS_PENDING" || lightState==="RELAY_HEAD_PENDING")
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
    function relayCommandResult(ackResult,failureCode) {
        if(!relayAckPending)return false
        // QGC Vehicle::MavCmdResultCommandResultOnly=0 and MAV_RESULT_ACCEPTED=0.
        if(failureCode!==0 || ackResult!==0) {
            relayAckWatchdog.stop()
            lightState="FAILED"
            return true
        }
        if(lightState==="RELAY_POS_PENDING") {
            if(!canActivate || !lightsReady || lightOverride) {
                relayAckWatchdog.stop()
                lightState="UNAVAILABLE"
                return true
            }
            lightState="RELAY_HEAD_PENDING"
            relayAckWatchdog.restart() // Separate bounded wait for the headlight ACK.
            if(!sendLight(1,0)) {
                relayAckWatchdog.stop()
                lightState="FAILED"
            }
            return true
        }
        if(lightState==="RELAY_HEAD_PENDING") {
            relayAckWatchdog.stop()
            lightState="RELAY_UNVERIFIED" // Both ACKed; still no lamp state feedback.
            return true
        }
        return false
    }
    function relayAckTimeout() {
        if(!relayAckPending)return false
        lightState="TIMEOUT"
        return true // Never auto-retry a pending MAVLink 181.
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
        var restoreHead=restore && active && !relayMode && capturedLights && !lightOverride && lightsReady && !lightCommandBusy && !headlightOn
        relayAckWatchdog.stop()
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
        if(relayMode) {
            // RC7/RC16 still own physical S6/S7. NEVER send both MAV_CMD 181
            // commands synchronously: QGC rejects a second 181 before first ACK.
            if(relayAckPending)return false
            lightOverride=false
            lightState="RELAY_POS_PENDING"
            requestedAt=Date.now()
            relayAckWatchdog.restart()
            if(!sendLight(2,1)){relayAckWatchdog.stop();lightState="FAILED";return false}
            return true // Relay1 OFF is sent ONLY by relayCommandResult on accepted ACK.
        }
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
        relayAckWatchdog.stop()
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
        if(relayMode)return // Never overwrite a later physical G20 button press.
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
    property Timer relayAckWatchdog: Timer {
        interval:12000;repeat:false;running:false
        onTriggered:root.relayAckTimeout()
    }
    property Timer monitor: Timer { interval:250;repeat:true;running:root.active;onTriggered:root.observe() }
}
