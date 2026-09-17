import QtQuick
import QtQuick.Controls
import QtPositioning
QtObject {
    id: root
    property var vehicle
    property bool active: false
    property var anchorCoordinate: QtPositioning.coordinate()
    property real driftRadiusM: 1.5
    signal status(string text)
    function engage() {
        if (!vehicle || !vehicle.coordinate || !vehicle.coordinate.isValid) { status("Ancora GPS: poziție invalidă"); return false }
        anchorCoordinate = vehicle.coordinate
        var ok = vehicle.guidedModeGotoLocation(anchorCoordinate)
        if (ok) { active = true; status("Ancora GPS activă") }
        else status("Ancora GPS refuzată de autopilot")
        return ok
    }
    function release() { active=false; status("Ancora GPS dezactivată") }
    function maintain() {
        if (!active || !vehicle || !vehicle.coordinate || !vehicle.coordinate.isValid || !anchorCoordinate.isValid) return
        if (vehicle.coordinate.distanceTo(anchorCoordinate) > driftRadiusM) vehicle.guidedModeGotoLocation(anchorCoordinate)
        else vehicle.pauseVehicle()
    }
    property Timer keeper: Timer { interval: 1500; repeat: true; running: root.active; onTriggered: root.maintain() }
}