import QtQuick

// H743 owns rudder/throttle regulation. NAVO only requests a reported Rover mode.
QtObject {
    id: root
    property var vehicle
    property bool readOnly: false
    property bool operationsBusy: false
    property bool preLaunchReady: false
    property string preLaunchMessage: ""
    property string state: "IDLE"
    property string message: "Asistență dezactivată"
    property double requestedAt: 0
    property string previousMode: ""
    readonly property string confirmedMode: linked() && !readOnly ? String(vehicle.flightMode||"").toUpperCase() : ""
    readonly property bool active: confirmedMode==="STEERING"
    readonly property bool holdActive: confirmedMode==="HOLD"
    readonly property bool pending: state==="REQUESTED" || state==="STOP_REQUESTED" || state==="MANUAL_REQUESTED"
    readonly property bool busy: active || pending || state==="ACTIVE"
    readonly property string steeringMode: findMode("STEERING")
    readonly property bool canEnable: !busy && !readOnly && !operationsBusy && preLaunchReady && healthy() && steeringMode.length>0
    readonly property bool canStop: linked() && !readOnly && (active || state==="REQUESTED") && state!=="STOP_REQUESTED" && state!=="MANUAL_REQUESTED"
    readonly property bool canToggleHold: linked() && !readOnly && (!operationsBusy || active || state==="REQUESTED") && (!pending || state==="REQUESTED") && (holdActive ? findMode("MANUAL").length>0 : findMode("HOLD").length>0)
    readonly property string availabilityMessage: readOnly ? "Replay activ • comenzi live blocate" : !linked() ? "H743 deconectat • verifică legătura MAVLink" : operationsBusy ? "Oprește misiunea/ancora înainte de activare" : !healthy() ? "GPS, poziție sau direcție H743 invalide" : !preLaunchReady ? (preLaunchMessage.length ? preLaunchMessage : "Verifică PRE-LAUNCH: HOME și bateria") : !steeringMode.length ? "H743 nu raportează modul STEERING" : "Mod disponibil • reglajele cârmei și ESC trebuie validate fizic"
    readonly property string assistLabel: !linked() || readOnly ? "NECONFIRMATĂ" : state==="REQUESTED" ? "ACTIVARE…" : state==="STOP_REQUESTED" && active ? "OPRIRE…" : active ? "ACTIVĂ" : "OPRITĂ"
    readonly property string holdLabel: !linked() || readOnly ? "NECONFIRMAT" : state==="STOP_REQUESTED" ? "ACTIVARE…" : state==="MANUAL_REQUESTED" ? "DEZACTIVARE…" : holdActive ? "ACTIV" : "INACTIV"
    signal status(string text)
    onVehicleChanged: reset(vehicle ? "Asistență dezactivată" : "H743 indisponibil")
    function findMode(name) {
        var modes=vehicle ? vehicle.flightModes : null
        if(!modes)return ""
        for(var i=0;i<modes.length;i++)if(String(modes[i]).toUpperCase()===name)return String(modes[i])
        return ""
    }
    function linked() {
        return !!vehicle && vehicle.rover && vehicle.vehicleLinkManager && !vehicle.vehicleLinkManager.communicationLost
    }
    function healthy() {
        return linked() &&
            vehicle.gps && vehicle.gps.lock && vehicle.gps.lock.rawValue>=3 && vehicle.coordinate && vehicle.coordinate.isValid &&
            vehicle.heading && typeof vehicle.heading.rawValue==="number" && isFinite(vehicle.heading.rawValue)
    }
    function report(text){message=text;status(text)}
    function reset(text){state="IDLE";requestedAt=0;previousMode="";report(text)}
    function enable() {
        if(!canEnable){report("STEERING blocat: "+availabilityMessage);return false}
        previousMode=String(vehicle.flightMode||"").toUpperCase()
        requestedAt=Date.now();state="REQUESTED"
        vehicle.flightMode=steeringMode
        report("STEERING solicitat • aștept confirmarea H743")
        return true
    }
    function stop() {
        if(!canStop)return false
        return requestHold()
    }
    function requestHold() {
        if(!canToggleHold || holdActive || !vehicle.pauseVehicle)return false
        previousMode=String(vehicle.flightMode||"").toUpperCase()
        requestedAt=Date.now();state="STOP_REQUESTED";vehicle.pauseVehicle()
        report("HOLD solicitat • aștept confirmarea H743");return true
    }
    function toggleHold() {
        if(!canToggleHold)return false
        if(!holdActive)return requestHold()
        // Explicitly leave HOLD for MANUAL; never resume AUTO/GUIDED or a mission.
        previousMode=confirmedMode;requestedAt=Date.now();state="MANUAL_REQUESTED"
        vehicle.flightMode=findMode("MANUAL")
        report("MANUAL solicitat • aștept confirmarea H743");return true
    }
    function observe() {
        if(!busy)return
        if(readOnly || !linked()){reset("Legătură live indisponibilă • modul H743 nu este confirmat");return}
        var mode=vehicle ? String(vehicle.flightMode||"").toUpperCase() : ""
        if(state==="MANUAL_REQUESTED") {
            if(mode==="MANUAL"){reset("MANUAL confirmat • HOLD dezactivat");return}
            if(mode!==previousMode){reset("Mod schimbat de pilot • verifică modul H743");return}
        } else if(state==="STOP_REQUESTED") {
            if(mode==="HOLD"){reset("HOLD confirmat • asistență oprită");return}
            if(mode!=="STEERING" && mode!==previousMode){reset("Pilotul a schimbat modul • asistență oprită");return}
        } else if(state==="REQUESTED" && mode==="STEERING") {
            state="ACTIVE";report("STEERING confirmat • cârma neutră: menținere direcție; propulsie din G20")
        } else if(state==="ACTIVE" && mode!=="STEERING") {
            reset("Mod schimbat de pilot • asistență oprită");return
        } else if(state==="REQUESTED" && mode!==previousMode) {
            reset("Autopilotul a raportat alt mod • asistență oprită");return
        }
        if((state==="REQUESTED" || state==="ACTIVE") && !healthy()){reset("Telemetrie/GPS indisponibile • nu reiau automat STEERING");return}
        if(pending && Date.now()-requestedAt>5000)reset("Comanda nu a fost confirmată • verifică modul în H743")
    }
    property Timer monitor: Timer {interval:250;repeat:true;running:root.busy;onTriggered:root.observe()}
}
