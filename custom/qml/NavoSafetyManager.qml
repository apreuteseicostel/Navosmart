import QtQuick

QtObject {
    id: root
    property var vehicle
    property bool enabled: true
    property bool telemetryLive: false
    property bool temperatureValid: telemetryLive && isFinite(batteryTempC)
    property bool waterValid: telemetryLive && !waterSensorFault
    property bool waterSensorFault: false
    property bool waterDetected: false
    property real batteryTempC: NaN
    property real warningTempC: 45
    property real criticalTempC: 55
    property int waterConfirmMs: 4000
    property bool waterConfirmed: false
    property bool criticalLatched: false
    property string state: "UNKNOWN"
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
        var hot = temperatureValid && isFinite(batteryTempC) && batteryTempC >= criticalTempC
        var warm = temperatureValid && isFinite(batteryTempC) && batteryTempC >= warningTempC

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
        } else if (!temperatureValid || !waterValid) {
            setState("UNKNOWN", "Senzor apă sau temperatură indisponibil")
            warning(reason)
        } else {
            criticalLatched=false
            setState("NORMAL","Senzori în limite")
        }
    }
    function updateWater() {
        if (!waterValid) {
            // Loss stops pending confirmation, but does not clear a known leak.
            waterTimer.stop()
        } else if (!waterDetected) {
            waterTimer.stop()
            waterConfirmed=false
        } else if (!waterConfirmed && !waterTimer.running) {
            waterTimer.restart()
        }
        evaluate()
    }
    function resetVehicle() {
        waterTimer.stop()
        waterConfirmed=false
        criticalLatched=false
        setState("UNKNOWN", "Aștept datele senzorilor")
    }
    onVehicleChanged: resetVehicle()
    onWaterDetectedChanged: updateWater()
    onWaterValidChanged: updateWater()
    onTemperatureValidChanged: evaluate()
    onBatteryTempCChanged: evaluate()
    onTelemetryLiveChanged: evaluate()
    onWaterSensorFaultChanged: updateWater()

    property Timer waterTimer: Timer {
        interval: root.waterConfirmMs; repeat:false
        onTriggered: { if(root.waterValid && root.waterDetected){root.waterConfirmed=true;root.evaluate()} }
    }
}
