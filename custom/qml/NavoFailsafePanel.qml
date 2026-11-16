import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QGroundControl.Controllers

// Read-only audit of cached onboard ArduPilot Rover failsafe parameters.
// Never sets an ArduPilot parameter, mode, relay or actuator. An enabled
// parameter is CONFIGURED, not proof of a safe RTL on the water.
Rectangle {
    id: root
    property var controller
    readonly property var liveVehicle: controller ? controller.vehicle : null
    readonly property bool linkAlive: !!(controller && controller.linkHealthy && controller.linkHealthy())
    property string lowBatteryStatus: "NECITIT"
    property string criticalBatteryStatus: "NECITIT"
    property string rcStatus: "NECITIT"
    property string gcsStatus: "NECITIT"
    property string onboardStatus: "AȘTEPT PARAMETRI H743"
    property bool onboardSafetyVerified: false // Hardware acceptance never inferred from parameter readback.

    color: "#0b1c2eee"
    border.color: "#1c4262"
    radius: 9
    implicitHeight: box.implicitHeight + 18

    // QGC controller exposes cached Fact values from the current vehicle. Its
    // Vehicle* is captured when constructed, so guard against vehicle switches.
    FactPanelController { id: parameterReader }
    function readParam(name) {
        if (!linkAlive || !liveVehicle || !parameterReader.vehicle ||
            parameterReader.vehicle !== liveVehicle ||
            !liveVehicle.parameterManager || !liveVehicle.parameterManager.parametersReady ||
            !parameterReader.parameterExists(-1, name)) return NaN
        var fact = parameterReader.getParameterFact(-1, name, false)
        if (!fact || fact.rawValue === undefined || fact.rawValue === null) return NaN
        var value = Number(fact.rawValue)
        return isFinite(value) ? value : NaN
    }
    function actionName(value) {
        if (!isFinite(value) || !Number.isInteger(value)) return "NECITIT"
        switch (value) {
        case 0: return "doar avertizare / fără acțiune"
        case 1: return "RTL"
        case 2: return "HOLD"
        case 3: return "SmartRTL sau RTL"
        case 4: return "SmartRTL sau HOLD"
        case 5: return "TERMINATE"
        case 6: return "LOITER sau HOLD"
        default: return "valoare necunoscută " + value
        }
    }
    function batteryStage(volts, milliampHours, action, monitor) {
        if (![volts, milliampHours, action, monitor].every(function(v) { return isFinite(v) })) return "NECITIT"
        if (monitor <= 0) return "FĂRĂ MONITOR BATERIE"
        if (volts < 0 || milliampHours < 0 || !Number.isInteger(action) || action < 0 || action > 6)
            return "PARAMETRI INVALIZI"
        if (volts === 0 && milliampHours === 0) return "DEZACTIVAT • fără prag de declanșare"
        var threshold = (volts > 0 ? volts.toFixed(2) + " V" : "") +
                        (volts > 0 && milliampHours > 0 ? " / " : "") +
                        (milliampHours > 0 ? milliampHours.toFixed(0) + " mAh" : "")
        if (action === 0) return "DOAR AVERTIZARE • " + threshold
        return "CONFIGURAT (netestat) • " + threshold + " → " + actionName(action) +
               (volts === 0 ? " • capacitate necalibrată" : "")
    }
    function radioStage(enabled, action, source) {
        if (!isFinite(enabled) || !isFinite(action)) return "NECITIT"
        if (!Number.isInteger(enabled) || !Number.isInteger(action) ||
            enabled < 0 || enabled > 2 || action < 0 || action > 6) return "PARAMETRI INVALIZI"
        if (enabled === 0) return "DEZACTIVAT"
        if (action === 0) return "FĂRĂ ACȚIUNE • verifică FS_ACTION"
        var exception = enabled === 2 ? " • AUTO exceptat" : ""
        return "CONFIGURAT (netestat) • " + actionName(action) + exception
    }
    function refreshAudit() {
        if (!linkAlive || !liveVehicle ||
            !parameterReader.vehicle || parameterReader.vehicle !== liveVehicle) {
            lowBatteryStatus = "NECITIT"; criticalBatteryStatus = "NECITIT"
            rcStatus = "NECITIT"; gcsStatus = "NECITIT"
            onboardStatus = "H743 offline / sursă parametri neconfirmată"
            return
        }
        var monitor = readParam("BATT_MONITOR")
        lowBatteryStatus = batteryStage(readParam("BATT_LOW_VOLT"), readParam("BATT_LOW_MAH"),
                                        readParam("BATT_FS_LOW_ACT"), monitor)
        criticalBatteryStatus = batteryStage(readParam("BATT_CRT_VOLT"), readParam("BATT_CRT_MAH"),
                                             readParam("BATT_FS_CRT_ACT"), monitor)
        var sharedAction = readParam("FS_ACTION")
        rcStatus = radioStage(readParam("FS_THR_ENABLE"), sharedAction, "RC")
        gcsStatus = radioStage(readParam("FS_GCS_ENABLE"), sharedAction, "GCS")
        var statuses = [lowBatteryStatus, criticalBatteryStatus, rcStatus, gcsStatus]
        if (statuses.some(function(s) { return s === "NECITIT" }))
            onboardStatus = "PARAMETRI INCOMPLEȚI • fără confirmare failsafe"
        else if (statuses.some(function(s) { return s.indexOf("CONFIGURAT") !== 0 }))
            onboardStatus = "PROTECȚII H743 INCOMPLETE • verifică configurarea"
        else
            onboardStatus = "CONFIGURAT ÎN H743 • NU ESTE VALIDAT PE APĂ"
    }
    onControllerChanged: refreshAudit()
    onLinkAliveChanged: refreshAudit()
    onLiveVehicleChanged: refreshAudit()
    Component.onCompleted: refreshAudit()
    Timer {
        interval: 3000
        repeat: true
        running: root.linkAlive && root.visible
        onTriggered: root.refreshAudit()
    }
    ColumnLayout {
        id: box
        anchors.fill: parent
        anchors.margins: 9
        spacing: 5
        Label { text: "SIGURANȚĂ & FAILSAFE"; color: "white"; font.bold: true }
        Label {
            Layout.fillWidth: true
            text: controller ? controller.status : "H743 OFFLINE"
            color: controller && (controller.linkLost || controller.gpsLost) ? "#ff3e55" : "#9db2c5"
            font.bold: true
            wrapMode: Text.WordWrap
        }
        GridLayout {
            columns: 3
            Layout.fillWidth: true
            Label { text: "Link (diagnostic)"; color: "#9db2c5" }
            SpinBox { id: linkT; from: 5; to: 120; value: controller ? controller.linkGraceSeconds : 30; onValueModified: if (controller) controller.linkGraceSeconds = value }
            Label { text: "s"; color: "white" }
            Label { text: "GPS recovery"; color: "#9db2c5" }
            SpinBox { id: gpsT; from: 10; to: 180; value: controller ? controller.gpsRecoverySeconds : 60; onValueModified: if (controller) controller.gpsRecoverySeconds = value }
            Label { text: "s"; color: "white" }
            Label { text: "GPS → HOME"; color: "#9db2c5" }
            SpinBox { id: rtlT; from: 30; to: 300; value: controller ? controller.gpsReturnHomeSeconds : 120; onValueModified: if (controller) controller.gpsReturnHomeSeconds = value }
            Label { text: "s"; color: "white" }
        }
        Label {
            Layout.fillWidth: true; wrapMode: Text.WordWrap; font.pixelSize: 10
            color: "#ffbd69"
            text: "Timpii de mai sus sunt pentru aplicație; NU configurează FS_TIMEOUT, FS_ACTION sau RTL în H743."
        }
        Label { Layout.fillWidth: true; wrapMode: Text.WordWrap; font.pixelSize: 11; font.bold: true; color: "#ffbd69"; text: root.onboardStatus }
        GridLayout {
            columns: 2
            Layout.fillWidth: true
            columnSpacing: 9; rowSpacing: 4
            Label { text: "Baterie LOW"; color: "#9db2c5"; font.pixelSize: 11 }
            Label { Layout.fillWidth: true; text: root.lowBatteryStatus; wrapMode: Text.WordWrap; color: "#e2edf5"; font.pixelSize: 11 }
            Label { text: "Baterie CRIT"; color: "#9db2c5"; font.pixelSize: 11 }
            Label { Layout.fillWidth: true; text: root.criticalBatteryStatus; wrapMode: Text.WordWrap; color: "#e2edf5"; font.pixelSize: 11 }
            Label { text: "RC / GR01"; color: "#9db2c5"; font.pixelSize: 11 }
            Label { Layout.fillWidth: true; text: root.rcStatus; wrapMode: Text.WordWrap; color: "#e2edf5"; font.pixelSize: 11 }
            Label { text: "GCS / MAVLink"; color: "#9db2c5"; font.pixelSize: 11 }
            Label { Layout.fillWidth: true; text: root.gcsStatus; wrapMode: Text.WordWrap; color: "#e2edf5"; font.pixelSize: 11 }
        }
        Label {
            Layout.fillWidth: true; wrapMode: Text.WordWrap; font.pixelSize: 10; color: "#9db2c5"
            text: "Citire pasivă din cache-ul QGC, numai pentru H743 conectat. RC și GCS au declanșatori diferiți; protecția H743 trebuie verificată la banc. Niciun parametru nu este modificat."
        }
        Label {
            Layout.fillWidth: true; wrapMode: Text.WordWrap; font.pixelSize: 10; color: "#9db2c5"
            text: "GPS invalid: aplicația poate cere HOLD doar cu MAVLink activ. RTL se poate cere după revenirea poziției; nu înlocuiește failsafe-ul autonom."
        }
    }
}
