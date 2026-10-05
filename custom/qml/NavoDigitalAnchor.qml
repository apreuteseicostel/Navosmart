import QtQuick
import QtQuick.Controls
import QtPositioning
QtObject {
    id: root
    property var vehicle
    property bool active: false
    property var anchorCoordinate: QtPositioning.coordinate()
    property real driftRadiusM: 1.5
    property bool correctionActive: false
    property double requestedAtMs:0
    property bool guidedConfirmed:false
    onVehicleChanged: release()
    signal status(string text)
    function gpsReady() { return !!vehicle && !!vehicle.gps && !!vehicle.gps.lock && isFinite(vehicle.gps.lock.rawValue) && vehicle.gps.lock.rawValue>=3 }
    function engage() {
        if (!vehicle || !vehicle.vehicleLinkManager || vehicle.vehicleLinkManager.communicationLost || !vehicle.coordinate || !vehicle.coordinate.isValid || !gpsReady()) { status("Ancora GPS: poziție/legătură invalidă"); return false }
        if(!vehicle.guidedModeGotoLocation || !vehicle.pauseVehicle){status("Ancora GPS: comenzi autopilot indisponibile");return false}
        anchorCoordinate = QtPositioning.coordinate(vehicle.coordinate.latitude,vehicle.coordinate.longitude)
        vehicle.guidedModeGotoLocation(anchorCoordinate)
        requestedAtMs=Date.now();guidedConfirmed=false;active=true; status("Ancora GPS: comandă trimisă; verifică modul și poziția")
        return true
    }
    function release() { active=false; correctionActive=false;guidedConfirmed=false;requestedAtMs=0; status("Ancora GPS dezactivată") }
    function maintain() {
        if(active && (!vehicle || !vehicle.vehicleLinkManager || vehicle.vehicleLinkManager.communicationLost || !gpsReady())) { release(); status("Ancora suspendată: GPS/legătură pierdută"); return }
        if (!active) return
        if(!vehicle.coordinate || !vehicle.coordinate.isValid || !anchorCoordinate.isValid){release();status("Ancora suspendată: coordonate invalide");return}
        // A pilot mode change cancels NAVO corrections. Never override MANUAL.
        if(String(vehicle.flightMode).toUpperCase()==="GUIDED")guidedConfirmed=true
        else if(guidedConfirmed || Date.now()-requestedAtMs>3000){release();status("Ancora suspendată: modul GUIDED nu este activ");return}
        else return
        var drift=vehicle.coordinate.distanceTo(anchorCoordinate)
        if (drift > driftRadiusM) {
            if(!correctionActive){correctionActive=true;vehicle.guidedModeGotoLocation(anchorCoordinate);status("Ancora GPS • corectez deriva "+drift.toFixed(1)+" m")}
        } else if(correctionActive) {
            correctionActive=false
            status("Ancora GPS • poziție restabilită")
        }
    }
    property Timer keeper: Timer { interval: 1500; repeat: true; running: root.active; onTriggered: root.maintain() }
}
