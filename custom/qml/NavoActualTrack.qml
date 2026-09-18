import QtQuick
import QtLocation
import QtPositioning

Item {
    id: root
    property var map
    property var vehicle
    property bool taskActive: false
    property bool keepCompletedTrack: true
    property real minPointDistanceM: 1.0
    property var trackCoordinates: []
    property var homeCoordinate: QtPositioning.coordinate()
    property bool recording: false
    property bool completed: false
    signal trackStarted()
    signal trackCompleted(int pointCount)

    function valid(c) { return c && c.isValid }
    function startTask() {
        if (!vehicle || !valid(vehicle.coordinate)) return false
        homeCoordinate = vehicle.homePosition && valid(vehicle.homePosition) ? vehicle.homePosition : vehicle.coordinate
        trackCoordinates = [homeCoordinate]
        if (homeCoordinate.distanceTo(vehicle.coordinate) > minPointDistanceM)
            trackCoordinates = trackCoordinates.concat([vehicle.coordinate])
        recording = true
        completed = false
        trackStarted()
        return true
    }
    function finishTask() {
        if (!recording) return
        appendCurrentPosition()
        recording = false
        completed = true
        trackCompleted(trackCoordinates.length)
        if (!keepCompletedTrack) clearTrack()
    }
    function clearTrack() {
        recording = false
        completed = false
        trackCoordinates = []
    }
    function appendCurrentPosition() {
        if (!recording || !vehicle || !valid(vehicle.coordinate)) return
        var c = vehicle.coordinate
        var a = trackCoordinates
        if (a.length === 0 || a[a.length - 1].distanceTo(c) >= minPointDistanceM)
            trackCoordinates = a.concat([c])
    }

    onTaskActiveChanged: {
        if (taskActive && !recording) startTask()
        else if (!taskActive && recording) finishTask()
    }

    Connections {
        target: root.vehicle
        function onCoordinateChanged() { root.appendCurrentPosition() }
    }

    MapPolyline {
        id: actualTrack
        map: root.map
        line.width: 4
        line.color: "#21b7ff"
        path: root.trackCoordinates
        opacity: 0.95
        z: 850
    }

    MapPolyline {
        id: homeLeg
        map: root.map
        line.width: 2
        line.color: "#31d67b"
        path: root.trackCoordinates.length > 0 && root.valid(root.homeCoordinate)
              ? [root.homeCoordinate, root.trackCoordinates[0]] : []
        opacity: 0.75
        z: 849
    }
}
