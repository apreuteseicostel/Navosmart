import QtQuick
import QtPositioning

QtObject {
    id: root

    // NAVO SMART baiting state machine. It deliberately does not drive servos
    // directly: hopper release is emitted as a request and must be connected
    // to the verified H743/Arduino output mapping after bench testing.
    property var vehicle
    property var targetWaypoint: null
    property string targetName: ""
    property int hopper: 0              // 0 none, 1 left, 2 right, 3 both
    property bool rtlAfterDrop: true
    property bool enabled: false

    property real silentRadiusM: 10.0
    property real finalRadiusM: 3.0
    property real normalSpeedMps: 1.5
    property real silentSpeedMps: 0.8
    property real finalSpeedMps: 0.4
    property real arrivalRadiusM: 1.0
    property int settleMs: 2000
    property int postDropMs: 2000
    property real exitDistanceM: 4.0
    property int exitSide: 1             // +1 right of arrival track, -1 left

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

    property real lastRequestedSpeedMps: NaN
    property var arrivalOrigin: QtPositioning.coordinate()
    property var exitCoordinate: QtPositioning.coordinate()

    signal speedRequested(real metersPerSecond)
    signal hopperReleaseRequested(int hopper)
    signal gotoRequested(var coordinate, string reason)
    signal rtlRequested()
    signal stateChangedDetailed(int state, string text)
    signal cycleFinished(bool success, string message)

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

    function requestSpeed(v) {
        if (isNaN(lastRequestedSpeedMps) || Math.abs(lastRequestedSpeedMps - v) > 0.05) {
            lastRequestedSpeedMps = v
            speedRequested(v)
        }
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
        lastRequestedSpeedMps = NaN
        setState(Navigate)
        requestSpeed(normalSpeedMps)
        gotoRequested(targetWaypoint.coordinate, "bait-target")
        monitorTimer.start()
        return true
    }

    function abortCycle(reason) {
        enabled = false
        monitorTimer.stop()
        settleTimer.stop()
        postDropTimer.stop()
        setState(Aborted)
        cycleFinished(false, reason || "Ciclul de nădire a fost oprit")
    }

    function makeExitCoordinate() {
        if (!validTarget() || !arrivalOrigin || !arrivalOrigin.isValid) return QtPositioning.coordinate()
        // Arrival bearing points origin -> bait point. Exit at 90 degrees to the
        // chosen side so the boat clears the freshly baited line before RTL.
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
            requestSpeed(0.0)
            setState(Settle)
            settleTimer.restart()
            return
        }

        if (state === Navigate && d <= silentRadiusM) {
            setState(Approach)
            requestSpeed(silentSpeedMps)
        }
        if ((state === Navigate || state === Approach) && d <= finalRadiusM) {
            setState(FinalApproach)
            requestSpeed(finalSpeedMps)
        }
    }

    property Timer monitorTimer: Timer {
        interval: 200
        repeat: true
        onTriggered: root.update()
    }

    property Timer settleTimer: Timer {
        interval: root.settleMs
        repeat: false
        onTriggered: {
            root.setState(root.Release)
            if (root.hopper !== 0) root.hopperReleaseRequested(root.hopper)
            root.postDropTimer.restart()
        }
    }

    property Timer postDropTimer: Timer {
        interval: root.postDropMs
        repeat: false
        onTriggered: {
            root.exitCoordinate = root.makeExitCoordinate()
            if (root.exitCoordinate && root.exitCoordinate.isValid) {
                root.setState(root.Exit)
                root.requestSpeed(root.silentSpeedMps)
                root.gotoRequested(root.exitCoordinate, "clear-bait-zone")
                root.exitTimer.restart()
            } else {
                root.finishExit()
            }
        }
    }

    property Timer exitTimer: Timer {
        interval: 5000
        repeat: false
        onTriggered: root.finishExit()
    }

    function finishExit() {
        if (rtlAfterDrop) {
            setState(ReturnHome)
            rtlRequested()
        } else {
            setState(Complete)
        }
        enabled = false
        monitorTimer.stop()
        cycleFinished(true, rtlAfterDrop ? "Nada eliberată; RTL pornit" : "Nada eliberată")
    }
}
