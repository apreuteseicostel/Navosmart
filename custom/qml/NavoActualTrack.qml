import QtQuick
import QtLocation
import QtPositioning

Item {
    id: root
    property var map
    property var vehicle
    property bool showTrack: true
    property bool taskActive: false
    property bool keepCompletedTrack: true
    property real minPointDistanceM: 1.0
    property var trackCoordinates: []
    // Keep the complete recorded route, but append to the Qt map item in place.
    // Binding the entire path to trackCoordinates reuploads every historical
    // vertex whenever a new GPS point is added.
    property bool trackMapItemReady: false
    function replaceTrack(points) {
        trackCoordinates = points
        if (trackMapItemReady) actualTrack.path = points
    }
    function appendTrackCoordinate(c) {
        trackCoordinates = trackCoordinates.concat([c])
        if (trackMapItemReady) actualTrack.addCoordinate(c)
    }
    property var homeCoordinate: QtPositioning.coordinate()
    property bool recording: false
    property bool completed: false
    signal trackStarted()
    signal trackCompleted(int pointCount)

    function valid(c) { return c && c.isValid }
    function startTask() {
        if (!vehicle || !valid(vehicle.coordinate)) return false
        homeCoordinate = vehicle.homePosition && valid(vehicle.homePosition) ? vehicle.homePosition : vehicle.coordinate
        replaceTrack([homeCoordinate])
        if (homeCoordinate.distanceTo(vehicle.coordinate) > minPointDistanceM)
            appendTrackCoordinate(vehicle.coordinate)
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
        replaceTrack([])
    }
    function appendCurrentPosition() {
        if (!recording || !vehicle || !valid(vehicle.coordinate)) return
        var c = vehicle.coordinate
        var a = trackCoordinates
        if (a.length === 0 || a[a.length - 1].distanceTo(c) >= minPointDistanceM)
            appendTrackCoordinate(c)
    }

    onTaskActiveChanged: {
        if (taskActive && !recording) startTask()
        else if (!taskActive && recording) finishTask()
    }

    Connections {
        target: root.vehicle
        function onCoordinateChanged() {
            if (root.taskActive && !root.recording) root.startTask()
            root.appendCurrentPosition()
        }
    }

    MapPolyline {
        id: actualTrack
        visible:root.showTrack
        Component.onCompleted: {
            if (root.map) {
                actualTrack.parent = root.map
                root.map.addMapItem(actualTrack)
                root.trackMapItemReady = true
                actualTrack.path = root.trackCoordinates
            }
        }
        Component.onDestruction: {
            root.trackMapItemReady = false
            if (root.map) root.map.removeMapItem(actualTrack)
        }
        line.width: 4
        line.color: "#21b7ff"
        opacity: 0.95
        z: 850
    }

    MapPolyline {
        id: homeLeg
        Component.onCompleted: {
            if (root.map) {
                homeLeg.parent = root.map
                root.map.addMapItem(homeLeg)
            }
        }
        Component.onDestruction: {
            if (root.map) root.map.removeMapItem(homeLeg)
        }
        line.width: 2
        line.color: "#31d67b"
        path: root.trackCoordinates.length > 0 && root.valid(root.homeCoordinate)
              ? [root.trackCoordinates[root.trackCoordinates.length - 1], root.homeCoordinate] : []
        opacity: 0.75
        z: 849
    }
}
