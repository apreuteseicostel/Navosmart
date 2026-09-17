import QtQuick
import QtPositioning

QtObject {
    id: root
    property var vehicle
    property var targetWaypoint: null
    property string targetName: ""
    property int hopper: 0
    property bool rtlAfterDrop: true
    property bool enabled: false

    // Global quiet mode can be used independently of an automatic baiting cycle.
    property bool silentMode: false
    property real manualSilentSpeedMps: 0.6

    property real silentRadiusM: 10.0
    property real finalRadiusM: 3.0
    property real normalSpeedMps: 1.5
    property real silentSpeedMps: 0.8
    property real finalSpeedMps: 0.4
    property real arrivalRadiusM: 1.0
    property int settleMs: 2000
    property int postDropMs: 2000
    property real exitDistanceM: 4.0
    property int exitSide: 1

    // Speed set-points are ramped instead of being stepped.
    property real commandedSpeedMps: 0.0
    property real targetSpeedMps: 0.0
    property real accelerationMps2: 0.35
    property real decelerationMps2: 0.45
    property int rampIntervalMs: 100

    readonly property int Idle: 0
    readonly property int Navigate: 1
    readonly property int Approach: 2
    readonly property int FinalApproach: 3
    readonly property int Settle: 4
    readonly property int Release: 5
    readonly property int Exit: 6
    readonly property int ReturnHome: 7
    readonly property int Complete: 8
    readonly property int Aborted: 9
    property int state: Idle

    property var arrivalOrigin: QtPositioning.coordinate()
    property var exitCoordinate: QtPositioning.coordinate()

    signal speedRequested(real metersPerSecond)
    signal hopperReleaseRequested(int hopper)
    signal gotoRequested(var coordinate, string reason)
    signal rtlRequested()
    signal stateChangedDetailed(int state, string text)
    signal cycleFinished(bool success, string message)
    signal silentModeChangedDetailed(bool active)

    function stateText(s) {
        switch (s) {
        case Idle: return "Pregătit"
        case Navigate: return "Navigare"
        case Approach: return "Apropiere silențioasă"
        case FinalApproach: return "Apropiere finală"
        case Settle: return "Stabilizare"
        case Release: return "Eliberare nadă"
        case Exit: return "Ieșire din punct"
        case ReturnHome: return "Întoarcere HOME"
        case Complete: return "Finalizat"
        case Aborted: return "Oprit"
        }
        return "--"
    }

    function setState(s) {
        if (state === s) return
        state = s
        stateChangedDetailed(state, stateText(state))
    }

    function validTarget() {
        return targetWaypoint && targetWaypoint.coordinate && targetWaypoint.coordinate.isValid
    }

    function distanceToTarget() {
        if (!vehicle || !vehicle.coordinate || !vehicle.coordinate.isValid || !validTarget()) return NaN
        return vehicle.coordinate.distanceTo(targetWaypoint.coordinate)
    }

    function setTargetSpeed(v) {
        targetSpeedMps = Math.max(0.0, v)
        if (!rampTimer.running) rampTimer.start()
    }

    function toggleSilentMode() {
        silentMode = !silentMode
        silentModeChangedDetailed(silentMode)
        // In manual use this requests a quiet speed ceiling/set-point. The final
        // RC/manual limiting behaviour must also be validated in ArduPilot Rover.
        if (!enabled) setTargetSpeed(silentMode ? manualSilentSpeedMps : normalSpeedMps)
    }

    function startCycle(waypoint, name, selectedHopper) {
        if (!vehicle || !waypoint || !waypoint.coordinate || !waypoint.coordinate.isValid) {
            cycleFinished(false, "Barca sau waypoint-ul nu sunt disponibile")
            return false
        }
        targetWaypoint = waypoint
        targetName = name
        hopper = selectedHopper
        arrivalOrigin = vehicle.coordinate
        enabled = true
        setState(Navigate)
        setTargetSpeed(silentMode ? silentSpeedMps : normalSpeedMps)
        gotoRequested(targetWaypoint.coordinate, "bait-target")
        monitorTimer.start()
        return true
    }

    function abortCycle(reason) {
        enabled = false
        monitorTimer.stop()
        settleTimer.stop()
        postDropTimer.stop()
        exitTimer.stop()
        setTargetSpeed(0.0)
        setState(Aborted)
        cycleFinished(false, reason || "Ciclul de nădire a fost oprit")
    }

    function makeExitCoordinate() {
        if (!validTarget() || !arrivalOrigin || !arrivalOrigin.isValid) return QtPositioning.coordinate()
        var arrivalBearing = arrivalOrigin.azimuthTo(targetWaypoint.coordinate)
        var exitBearing = arrivalBearing + (exitSide >= 0 ? 90 : -90)
        if (exitBearing < 0) exitBearing += 360
        if (exitBearing >= 360) exitBearing -= 360
        return targetWaypoint.coordinate.atDistanceAndAzimuth(exitDistanceM, exitBearing)
    }

    function update() {
        if (!enabled || !vehicle || !validTarget()) return
        var d = distanceToTarget()
        if (isNaN(d)) return

        if ((state === Navigate || state === Approach || state === FinalApproach) && d <= arrivalRadiusM) {
            setTargetSpeed(0.0)
            setState(Settle)
            settleTimer.restart()
            return
        }
        if (state === Navigate && d <= silentRadiusM) {
            setState(Approach)
            setTargetSpeed(silentSpeedMps)
        }
        if ((state === Navigate || state === Approach) && d <= finalRadiusM) {
            setState(FinalApproach)
            setTargetSpeed(finalSpeedMps)
        }
    }

    property Timer rampTimer: Timer {
        interval: root.rampIntervalMs
        repeat: true
        onTriggered: {
            var dt = interval / 1000.0
            var diff = root.targetSpeedMps - root.commandedSpeedMps
            if (Math.abs(diff) < 0.01) {
                root.commandedSpeedMps = root.targetSpeedMps
                root.speedRequested(root.commandedSpeedMps)
                stop()
                return
            }
            var step = (diff > 0 ? root.accelerationMps2 : root.decelerationMps2) * dt
            if (Math.abs(diff) <= step) root.commandedSpeedMps = root.targetSpeedMps
            else root.commandedSpeedMps += diff > 0 ? step : -step
            root.speedRequested(Math.max(0.0, root.commandedSpeedMps))
        }
    }

    property Timer monitorTimer: Timer { interval: 200; repeat: true; onTriggered: root.update() }

    property Timer settleTimer: Timer {
        interval: root.settleMs; repeat: false
        onTriggered: {
            root.setState(root.Release)
            if (root.hopper !== 0) root.hopperReleaseRequested(root.hopper)
            root.postDropTimer.restart()
        }
    }

    property Timer postDropTimer: Timer {
        interval: root.postDropMs; repeat: false
        onTriggered: {
            root.exitCoordinate = root.makeExitCoordinate()
            if (root.exitCoordinate && root.exitCoordinate.isValid) {
                root.setState(root.Exit)
                root.setTargetSpeed(root.silentSpeedMps)
                root.gotoRequested(root.exitCoordinate, "clear-bait-zone")
                root.exitTimer.restart()
            } else root.finishExit()
        }
    }

    property Timer exitTimer: Timer { interval: 5000; repeat: false; onTriggered: root.finishExit() }

    function finishExit() {
        if (rtlAfterDrop) {
            setState(ReturnHome)
            setTargetSpeed(silentMode ? manualSilentSpeedMps : normalSpeedMps)
            rtlRequested()
        } else setState(Complete)
        enabled = false
        monitorTimer.stop()
        cycleFinished(true, rtlAfterDrop ? "Nada eliberată; RTL pornit" : "Nada eliberată")
    }
}
