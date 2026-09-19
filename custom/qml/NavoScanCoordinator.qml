import QtQuick
import QtPositioning

QtObject {
    id: root
    property var areaScan
    property var sonarMapping
    property var bathymetry
    property var persistence
    property var vehicle
    property string lakeId: ""
    property string lakeName: ""
    property var areaPoints: []
    property var bathymetryCells: []
    property string state: "IDLE"
    signal status(string text)
    signal missionPrepared(var missionPoints)

    function prepareRectangle(cornerA, cornerB) {
        if(!areaScan) return []
        var boat=vehicle && vehicle.coordinate && vehicle.coordinate.isValid ? vehicle.coordinate : null
        var pts=areaScan.generateRectangle(cornerA,cornerB,boat)
        areaPoints=pts
        if(sonarMapping){sonarMapping.lakeId=lakeId; sonarMapping.totalLanes=areaScan.laneCount()}
        checkpoint("area")
        status("Area Scan pregătit • "+areaScan.laneCount()+" culoare")
        return pts
    }

    function prepareMission(resumeOnly) {
        if(!areaScan) return []
        var boat=vehicle && vehicle.coordinate && vehicle.coordinate.isValid ? vehicle.coordinate : null
        var route=resumeOnly ? areaScan.resumeRoute(boat) : areaScan.generatedPoints
        var mission=areaScan.exportMissionPoints(route)
        missionPrepared(mission)
        status((resumeOnly?"Resume":"Area Scan")+" • "+mission.length+" waypoint-uri pregătite")
        return mission
    }

    function start() {
        if(!sonarMapping || !areaScan || !areaScan.generatedPoints.length) {status("Scanare blocată: definește zona");return false}
        sonarMapping.startScan()
        if(!sonarMapping.scanning) return false
        state="SCANNING"; checkpoint("start"); return true
    }

    function laneCompleted(index) {
        areaScan.markLaneCompleted(index)
        sonarMapping.setLaneProgress(areaScan.activeLaneIndex,areaScan.completedLanes.length,areaScan.laneCount())
        checkpoint("lane")
        if(areaScan.completedLanes.length>=areaScan.laneCount()) finish()
    }

    function pause(reason) {
        var boat=vehicle&&vehicle.coordinate?vehicle.coordinate:null
        areaScan.hold(reason||"Pauză scanare",boat)
        sonarMapping.pauseScan(); state="PAUSED"; checkpoint("pause")
    }

    function resume() {
        var mission=prepareMission(true)
        if(!mission.length){status("Nu există culoare rămase");return []}
        sonarMapping.resumeScan(); state="SCANNING"; checkpoint("resume"); return mission
    }

    function rtl(reason) {
        areaScan.rtl(reason||"RTL scanare")
        sonarMapping.pauseScan(); state="RTL"; checkpoint("rtl")
    }

    function finish() {
        sonarMapping.finishAndBuild()
        if(bathymetry) bathymetryCells=bathymetry.rebuild(sonarMapping.rawSamples)
        state="COMPLETE"; checkpoint("complete")
        status("Scanare terminată • "+bathymetryCells.length+" celule batimetrice")
    }

    function checkpoint(reason) {
        if(!persistence || !sonarMapping || !areaScan) return
        persistence.lakeId=lakeId; persistence.lakeName=lakeName
        persistence.areaPoints=areaPoints
        persistence.samples=sonarMapping.rawSamples
        persistence.scanState={
            reason:reason, state:state, currentLane:areaScan.activeLaneIndex,
            completedLanes:areaScan.completedLanes, totalLanes:areaScan.laneCount(),
            bathymetryCells:bathymetryCells, savedAt:Date.now()
        }
        sonarMapping.saveCheckpoint(reason)
    }

    function restore(jsonText) {
        if(!persistence.restore(jsonText)) return false
        lakeId=persistence.lakeId; lakeName=persistence.lakeName
        areaPoints=persistence.areaPoints||[]
        sonarMapping.rawSamples=persistence.samples||[]
        var s=persistence.scanState||({})
        state=s.state||"PAUSED"; bathymetryCells=s.bathymetryCells||[]
        areaScan.generatedPoints=areaPoints
        areaScan.completedLanes=s.completedLanes||[]
        areaScan.activeLaneIndex=(s.currentLane===undefined?-1:s.currentLane)
        sonarMapping.restoreCheckpoint({lakeId:lakeId,currentLane:areaScan.activeLaneIndex,completedLanes:areaScan.completedLanes.length,totalLanes:s.totalLanes||areaScan.laneCount(),sampleCount:sonarMapping.rawSamples.length,reason:"restore",time:Date.now()})
        if(bathymetry && sonarMapping.rawSamples.length) bathymetryCells=bathymetry.rebuild(sonarMapping.rawSamples)
        status("Balta restaurată • scanarea poate continua")
        return true
    }

    Connections {
        target: areaScan
        function onSafetyActionRequested(action,reason) {
            if(action==="HOLD" && vehicle) vehicle.pauseVehicle()
            else if(action==="RTL" && vehicle) vehicle.guidedModeRTL(false)
            status(action+": "+reason)
        }
    }
}
