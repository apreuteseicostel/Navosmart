import QtQuick

QtObject {
    id: root
    property var vehicle
    property bool enabled: true
    property bool waterDetected: false
    property real batteryTempC: NaN
    property real warningTempC: 45
    property real criticalTempC: 55
    property int waterConfirmMs: 4000
    property bool waterConfirmed: false
    property bool criticalLatched: false
    property string state: "NORMAL"
    property string reason: ""
    signal warning(string reason)
    signal holdRequested(string reason)
    signal rtlRequested(string reason)
    signal stateChangedDetailed(string state, string reason)

    function gpsValid() {
        return vehicle && vehicle.coordinate && vehicle.coordinate.isValid &&
               vehicle.gps && vehicle.gps.lock.rawValue >= 3
    }
    function homeValid() {
        return vehicle && vehicle.homePosition && vehicle.homePosition.isValid
    }
    function setState(s, r) {
        if (state === s && reason === r) return
        state=s; reason=r; stateChangedDetailed(s,r)
    }
    function evaluate() {
        if (!enabled) return
        var hot = (!isNaN(batteryTempC) && batteryTempC >= criticalTempC)
        var warm = (!isNaN(batteryTempC) && batteryTempC >= warningTempC)

        if (waterConfirmed || hot) {
            var r = waterConfirmed ? "Apă confirmată în compartimentul electronic" : "Temperatură critică"
            setState("CRITICAL", r)
            if (!criticalLatched) {
                criticalLatched=true
                if (gpsValid() && homeValid()) rtlRequested(r)
                else holdRequested(r + " • GPS/HOME invalid")
            }
        } else if (warm) {
            criticalLatched=false
            setState("WARNING","Temperatură ridicată")
            warning(reason)
        } else {
            criticalLatched=false
            setState("NORMAL","Sistem sigur")
        }
    }
    onWaterDetectedChanged: {
        if (waterDetected) waterTimer.restart()
        else { waterTimer.stop(); waterConfirmed=false; evaluate() }
    }
    onBatteryTempCChanged: evaluate()

    property Timer waterTimer: Timer {
        interval: root.waterConfirmMs; repeat:false
        onTriggered: { if(root.waterDetected){root.waterConfirmed=true;root.evaluate()} }
    }
}
