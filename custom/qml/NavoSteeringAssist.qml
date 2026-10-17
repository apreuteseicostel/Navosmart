import QtQuick

// H743 owns rudder/throttle regulation. NAVO only requests a reported Rover mode.
QtObject {
    id: root
    property var vehicle
    property bool readOnly: false
    property bool operationsBusy: false
    property bool preLaunchReady: false
    property string state: "IDLE"
    property string message: "Asistență dezactivată"
    property double requestedAt: 0
    property string previousMode: ""
    readonly property bool busy: state==="REQUESTED" || state==="ACTIVE" || state==="STOP_REQUESTED"
    readonly property string steeringMode: findMode("STEERING")
    readonly property bool canEnable: !busy && !readOnly && !operationsBusy && preLaunchReady && healthy() && steeringMode.length>0
    readonly property string availabilityMessage: readOnly ? "Replay activ • comenzi live blocate" : operationsBusy ? "Oprește misiunea/ancora înainte de activare" : !healthy() ? "Verifică legătura H743, GPS și direcția" : !preLaunchReady ? "Verifică PRE-LAUNCH și bateria" : !steeringMode.length ? "H743 nu raportează modul STEERING" : "Mod disponibil • reglajele cârmei și ESC trebuie validate fizic"
    signal status(string text)
    onVehicleChanged: reset(vehicle ? "Asistență dezactivată" : "H743 indisponibil")
    function findMode(name) {
        var modes=vehicle ? vehicle.flightModes : null
        if(!modes)return ""
        for(var i=0;i<modes.length;i++)if(String(modes[i]).toUpperCase()===name)return String(modes[i])
        return ""
    }
    function healthy() {
        return !!vehicle && vehicle.rover && vehicle.vehicleLinkManager && !vehicle.vehicleLinkManager.communicationLost &&
            vehicle.gps && vehicle.gps.lock && vehicle.gps.lock.rawValue>=3 && vehicle.coordinate && vehicle.coordinate.isValid &&
            vehicle.heading && typeof vehicle.heading.rawValue==="number" && isFinite(vehicle.heading.rawValue)
    }
    function report(text){message=text;status(text)}
    function reset(text){state="IDLE";requestedAt=0;previousMode="";report(text)}
    function enable() {
        if(!canEnable){report("STEERING blocat: verifică modul disponibil, GPS, bateria și operațiile active");return false}
        previousMode=String(vehicle.flightMode||"").toUpperCase()
        requestedAt=Date.now();state="REQUESTED"
        vehicle.flightMode=steeringMode
        report("STEERING solicitat • aștept confirmarea H743")
        return true
    }
    function stop() {
        if(!busy || readOnly || !vehicle || !vehicle.vehicleLinkManager || vehicle.vehicleLinkManager.communicationLost)return false
        var mode=String(vehicle.flightMode||"").toUpperCase()
        if(mode!=="STEERING" && state!=="REQUESTED"){reset("Mod schimbat de pilot • nu trimit HOLD");return false}
        if(!vehicle.pauseVehicle){report("HOLD indisponibil");return false}
        requestedAt=Date.now();state="STOP_REQUESTED";vehicle.pauseVehicle()
        report("HOLD solicitat • aștept confirmarea H743");return true
    }
    function observe() {
        if(!busy)return
        var mode=vehicle ? String(vehicle.flightMode||"").toUpperCase() : ""
        if(state==="STOP_REQUESTED") {
            if(mode==="HOLD"){reset("HOLD confirmat • asistență oprită");return}
            if(mode!=="STEERING" && mode!==previousMode){reset("Pilotul a schimbat modul • asistență oprită");return}
        } else if(state==="REQUESTED" && mode==="STEERING") {
            state="ACTIVE";report("STEERING confirmat • cârma neutră: menținere direcție; propulsie din G20")
        } else if(state==="ACTIVE" && mode!=="STEERING") {
            reset("Mod schimbat de pilot • asistență oprită");return
        } else if(state==="REQUESTED" && mode!==previousMode) {
            reset("Autopilotul a raportat alt mod • asistență oprită");return
        }
        if(readOnly){reset("Replay activ • monitorizare suspendată; verifică modul H743");return}
        if(!healthy()){reset("Telemetrie/GPS indisponibile • nu reiau automat STEERING");return}
        if(state!=="ACTIVE" && Date.now()-requestedAt>5000)reset("Comanda nu a fost confirmată • verifică modul în H743")
    }
    property Timer monitor: Timer {interval:250;repeat:true;running:root.busy;onTriggered:root.observe()}
}
