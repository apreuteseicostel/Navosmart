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
    signal status(string text)
    function engage() {
        if (!vehicle || !vehicle.vehicleLinkManager || vehicle.vehicleLinkManager.communicationLost || !vehicle.coordinate || !vehicle.coordinate.isValid || !vehicle.gps || vehicle.gps.lock.rawValue<3) { status("Ancora GPS: poziție/legătură invalidă"); return false }
        anchorCoordinate = vehicle.coordinate
        vehicle.guidedModeGotoLocation(anchorCoordinate)
        active=true; status("Ancora GPS: comandă trimisă; verifică modul și poziția")
        return true
    }
    function release() { active=false; correctionActive=false; status("Ancora GPS dezactivată") }
    function maintain() {
        if(active && (!vehicle || !vehicle.vehicleLinkManager || vehicle.vehicleLinkManager.communicationLost || !vehicle.gps || vehicle.gps.lock.rawValue<3)) { release(); status("Ancora suspendată: GPS/legătură pierdută"); return }
        if (!active || !vehicle || !vehicle.coordinate || !vehicle.coordinate.isValid || !anchorCoordinate.isValid) return
        var drift=vehicle.coordinate.distanceTo(anchorCoordinate)
        if (drift > driftRadiusM) {
            if(!correctionActive){correctionActive=true;vehicle.guidedModeGotoLocation(anchorCoordinate);status("Ancora GPS • corectez deriva "+drift.toFixed(1)+" m")}
        } else if(correctionActive) {
            correctionActive=false
            vehicle.pauseVehicle()
            status("Ancora GPS • poziție restabilită")
        }
    }
    property Timer keeper: Timer { interval: 1500; repeat: true; running: root.active; onTriggered: root.maintain() }
}
