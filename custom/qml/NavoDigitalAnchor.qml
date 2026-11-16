import QtQuick
import QtQuick.Controls
import QtPositioning

// Experimental GUIDED position correction. This is not ArduPilot LOITER and
// cannot replace onboard RC/GCS/battery failsafes. Hardware approval pending.
QtObject {
    id: root
    property var vehicle
    property bool active: false
    property var anchorCoordinate: QtPositioning.coordinate()
    property real driftRadiusM: 1.5
    property real resetRadiusRatio: 0.6
    property real maxAutoCorrectionDriftM: 15
    property int minCorrectionIntervalMs: 5000
    property double lastCorrectionAtMs: 0
    property bool correctionActive: false
    property double requestedAtMs: 0
    property bool guidedConfirmed: false

    onVehicleChanged: release()
    signal status(string text)

    function gpsReady() {
        var fix = vehicle && vehicle.gps && vehicle.gps.lock
                  ? Number(vehicle.gps.lock.rawValue) : NaN
        return isFinite(fix) && fix >= 3
    }
    function modeName() {
        return vehicle && vehicle.flightMode
            ? String(vehicle.flightMode).trim().toUpperCase() : ""
    }
    function canEngageFromMode() {
        // Never seize the pilot's MANUAL/ACRO or an existing AUTO/RTL mission.
        // HOLD is the usual stationary state from which GUIDED can be requested.
        var mode = modeName()
        return mode === "HOLD" || mode === "GUIDED"
    }
    function positionHealthy() {
        return !!vehicle && !!vehicle.vehicleLinkManager &&
               !vehicle.vehicleLinkManager.communicationLost &&
               !!vehicle.coordinate && vehicle.coordinate.isValid && gpsReady()
    }
    function engage() {
        if (active) { status("Ancora GPS este deja activă; eliberează înainte de repoziționare"); return false }
        if (!positionHealthy()) { status("Ancora GPS: poziție/legătură invalidă"); return false }
        if (!canEngageFromMode()) { status("Ancora GPS blocată: treci în HOLD sau GUIDED (nu MANUAL/AUTO/RTL)"); return false }
        if (!isFinite(driftRadiusM) || driftRadiusM <= 0) { status("Ancora GPS: rază invalidă"); return false }
        if (!vehicle.guidedModeGotoLocation || !vehicle.pauseVehicle) {
            status("Ancora GPS: comenzi autopilot indisponibile"); return false
        }
        anchorCoordinate = QtPositioning.coordinate(vehicle.coordinate.latitude, vehicle.coordinate.longitude)
        if (!anchorCoordinate.isValid) { status("Ancora GPS: coordonate invalide"); return false }
        vehicle.guidedModeGotoLocation(anchorCoordinate)
        requestedAtMs = Date.now()
        lastCorrectionAtMs = 0
        guidedConfirmed = false
        correctionActive = false
        active = true
        status("Ancora experimentală: GUIDED solicitat; nu înlocuiește LOITER/H743")
        return true
    }
    function release() {
        active = false
        correctionActive = false
        guidedConfirmed = false
        requestedAtMs = 0
        lastCorrectionAtMs = 0
        status("Ancora GPS dezactivată")
    }
    function maintain() {
        if (!active) return
        if (!positionHealthy()) {
            release()
            status("Ancora suspendată: GPS/legătură pierdută; verifică H743")
            return
        }
        if (!anchorCoordinate || !anchorCoordinate.isValid) {
            release()
            status("Ancora suspendată: coordonate invalide")
            return
        }
        var mode = modeName()
        if (mode === "GUIDED") guidedConfirmed = true
        else if (mode === "HOLD" && !guidedConfirmed && Date.now() - requestedAtMs <= 3000) return
        else {
            // Immediate pilot override: do not wait 3 s if switched to MANUAL,
            // ACRO, AUTO, RTL or an unrecognized mode after engaging.
            release()
            status("Ancora suspendată: pilotul/autopilotul a schimbat modul")
            return
        }
        var drift = vehicle.coordinate.distanceTo(anchorCoordinate)
        var maximum = isFinite(Number(root.maxAutoCorrectionDriftM)) && Number(root.maxAutoCorrectionDriftM) > driftRadiusM
                      ? Number(root.maxAutoCorrectionDriftM) : 15
        if (!isFinite(drift) || drift < 0 || !isFinite(driftRadiusM) || driftRadiusM <= 0) {
            release()
            status("Ancora suspendată: derivă/rază invalidă")
            return
        }
        if (drift > maximum) {
            // Large jumps may be GPS glitches: fail closed, never chase one.
            release()
            status("Ancora suspendată: salt GPS/derivă > " + maximum.toFixed(0) + " m; verifică manual")
            return
        }
        var interval = isFinite(Number(root.minCorrectionIntervalMs)) && Number(root.minCorrectionIntervalMs) > 0
                       ? Number(root.minCorrectionIntervalMs) : 5000
        if (drift > driftRadiusM) {
            if (!correctionActive && (lastCorrectionAtMs === 0 || Date.now() - lastCorrectionAtMs >= interval)) {
                if (!vehicle.guidedModeGotoLocation) {
                    release()
                    status("Ancora suspendată: GUIDED indisponibil")
                    return
                }
                correctionActive = true
                lastCorrectionAtMs = Date.now()
                vehicle.guidedModeGotoLocation(anchorCoordinate)
                status("Ancora GPS • comandă corecție derivă " + drift.toFixed(1) + " m (neconfirmată)")
            }
        } else {
            var resetRatio = isFinite(Number(root.resetRadiusRatio)) && Number(root.resetRadiusRatio) > 0 &&
                             Number(root.resetRadiusRatio) < 1 ? Number(root.resetRadiusRatio) : 0.6
            if (correctionActive && drift <= driftRadiusM * resetRatio) {
                correctionActive = false
                status("Ancora GPS • în limita de repoziționare; nu garantează staționarea")
            }
        }
    }
    property Timer keeper: Timer {
        interval: 1500
        repeat: true
        running: root.active
        onTriggered: root.maintain()
    }
}
