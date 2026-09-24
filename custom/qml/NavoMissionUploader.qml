import QtQuick
import QtPositioning
import NavoSmart.Backend 1.0

QtObject {
    id: root
    property var planController
    property var vehicle
    property bool uploadInProgress: false
    property bool uploadVerified: false
    property NavoMissionBridge missionBridge: NavoMissionBridge {
        id: missionBridge
        vehicle: root.vehicle
        onVehicleChanged: {
            root.uploadVerified = false
            if (root.uploadInProgress) {
                uploadTimeout.stop()
                root.uploadInProgress = false
                root.lastError = "Conexiunea autopilot s-a schimbat în timpul upload-ului"
                root.uploadFinished(false, root.lastError)
            }
        }
        onUploadCompleted: function(success) {
            if (!root.uploadInProgress) return
            uploadTimeout.stop()
            root.uploadInProgress = false
            root.uploadVerified = success
            if (!success && !root.lastError.length) root.lastError = "autopilot a respins upload-ul misiunii"
            root.status(success ? "autopilot confirmă misiunea încărcată" : root.lastError)
            root.uploadFinished(success, success ? "Upload autopilot confirmat; apasă START încă o dată pentru pornire" : root.lastError)
        }
        onMissionError: function(message) {
            if (root.uploadInProgress) {
                root.lastError = message
                root.status("Upload autopilot: " + message)
            }
        }
    }
    property int preparedCount: 0
    property string lastError: ""
    property int uploadTimeoutMs: 15000
    signal status(string text)
    signal uploadFinished(bool success, string message)

    function invalidate() {
        uploadTimeout.stop()
        uploadInProgress = false
        uploadVerified = false
        preparedCount = 0
    }

    function canUpload() {
        if(!planController || !planController.missionController){lastError="MissionController indisponibil";return false}
        if(!vehicle){lastError="autopilot/vehicul neconectat";return false}
        if(planController.offline){lastError="QGC este offline";return false}
        if(planController.syncInProgress || planController.missionController.syncInProgress){lastError="Sincronizare misiune deja în curs";return false}
        return true
    }

    function prepare(points) {
        invalidate()
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
        uploadVerified=false
        status("Misiune Area Scan pregătită în QGroundControl • "+preparedCount+" WP")
        return true
    }

    function uploadPrepared() {
        if(!canUpload() || preparedCount<1){if(!lastError.length)lastError="Nu există misiune pregătită";status(lastError);return false}
        uploadInProgress=true;uploadVerified=false;lastError=""
        uploadTimeout.restart()
        status("Încarc "+preparedCount+" waypoint-uri în autopilot…")
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
            root.uploadVerified=false
            root.lastError="Timeout upload autopilot: nu am primit confirmarea QGroundControl"
            root.status(root.lastError)
            root.uploadFinished(false,root.lastError)
        }
    }

}
