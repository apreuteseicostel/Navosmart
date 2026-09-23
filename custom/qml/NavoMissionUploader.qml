import QtQuick
import QtPositioning

QtObject {
    id: root
    property var planController
    property var vehicle
    property bool uploadInProgress: false
    property int preparedCount: 0
    property string lastError: ""
    property int uploadTimeoutMs: 15000
    signal status(string text)
    signal uploadFinished(bool success, string message)

    function canUpload() {
        if(!planController || !planController.missionController){lastError="MissionController indisponibil";return false}
        if(!vehicle){lastError="H743/vehicul neconectat";return false}
        if(planController.offline){lastError="QGC este offline";return false}
        if(planController.syncInProgress || planController.missionController.syncInProgress){lastError="Sincronizare misiune deja în curs";return false}
        return true
    }

    function prepare(points) {
        if(!planController || !planController.missionController || !points || !points.length)return false
        var mc=planController.missionController
        if(mc.syncInProgress){lastError="MissionController ocupat";return false}
        // Keep QGC's MissionSettingsItem at index 0 and rebuild only mission waypoints.
        mc.removeAll()
        for(var i=0;i<points.length;i++){
            var p=points[i]
            var c=(p.latitude!==undefined)?QtPositioning.coordinate(p.latitude,p.longitude):p
            if(!c || !c.isValid){lastError="Coordonată invalidă la punctul "+(i+1);mc.removeAll();return false}
            mc.insertSimpleMissionItem(c,mc.visualItems.count,true)
        }
        preparedCount=points.length
        status("Misiune Area Scan pregătită în QGroundControl • "+preparedCount+" WP")
        return true
    }

    function uploadPrepared() {
        if(!canUpload() || preparedCount<1){if(!lastError.length)lastError="Nu există misiune pregătită";status(lastError);return false}
        uploadInProgress=true;lastError=""
        uploadTimeout.restart()
        status("Încarc "+preparedCount+" waypoint-uri în H743…")
        // Use QGC's normal PlanMasterController upload path. It converts VisualMissionItems
        // to MissionItems and MissionManager writes them over MAVLink.
        planController.sendToVehicle()
        return true
    }

    property Timer uploadTimeout: Timer {
        interval: root.uploadTimeoutMs
        repeat: false
        onTriggered: {
            if(!root.uploadInProgress)return
            root.uploadInProgress=false
            root.lastError="Timeout upload H743: nu am primit confirmarea QGroundControl"
            root.status(root.lastError)
            root.uploadFinished(false,root.lastError)
        }
    }

    property QtObject missionControllerConnections: Connections {
        target: planController ? planController.missionController : null
        function onSendComplete() {
            if(!root.uploadInProgress)return
            uploadTimeout.stop()
            root.uploadInProgress=false
            root.status("Misiune Area Scan încărcată în H743 • "+root.preparedCount+" WP")
            root.uploadFinished(true,"Upload H743 terminat")
        }
    }
}
