import QtQuick
import QtPositioning

QtObject {
    id: root
    property var areaScan
    property var sonarMapping
    property var bathymetry
    property var persistence
    property var fishingSpots
    property var fishStore
    property var vehicle
    property string lakeId: ""
    property string lakeName: ""
    onLakeIdChanged: {
        if(sonarMapping && sonarMapping.lakeId !== lakeId)
            sonarMapping.lakeId = lakeId
    }
    property var areaPoints: []
    property var bathymetryCells: []
    property string state: "IDLE"
    property int missionCurrentIndex: -1
    property int lastCompletedLaneFromMission: -1
    property int lastCompletedRouteLaneFromMission: -1
    property var missionLanes: []
    signal status(string text)
    signal missionPrepared(var missionPoints)

    function missionIndexChanged(index) {
        if(!areaScan || state !== "SCANNING" || index === undefined || index === null || index < 0) return
        missionCurrentIndex=index
        // QGC mission index 0 is MissionSettings/Home; Area Scan WP start at 1.
        // A lane has two WP. Entering the first WP of the next lane confirms
        // the previous lane was completed by the autopilot.
        var missionWp=Math.max(0,index-1)
        var completedThrough=Math.floor(missionWp/2)-1
        // When ArduPilot advances beyond the final Area Scan waypoint, the
        // last lane is complete as well. Some firmwares expose this as an
        // index equal to the number of mission waypoints.
        if(index >= missionLanes.length*2 + 1) completedThrough=missionLanes.length-1
        completedThrough=Math.min(completedThrough,missionLanes.length-1)
        for(var routeLane=lastCompletedRouteLaneFromMission+1;routeLane<=completedThrough;routeLane++) {
            var lane=missionLanes[routeLane]
            if (lane === undefined) break
            laneCompleted(lane)
            lastCompletedLaneFromMission=lane
            lastCompletedRouteLaneFromMission=routeLane
        }
        status("Area Scan • WP "+index+" • "+areaScan.progressPercent()+"%")
    }

    function preparePolygon(polygon) {
        if(!areaScan) return []
        var pts=areaScan.generatePolygon(polygon); areaPoints=pts
        state=pts.length ? "AREA_DEFINED" : "IDLE"
        if(sonarMapping){sonarMapping.lakeId=lakeId; sonarMapping.totalLanes=areaScan.laneCount()}
        checkpoint("area-polygon"); status("Area Scan poligon pregătit • "+areaScan.laneCount()+" culoare"); return pts
    }
    function prepareRectangle(cornerA, cornerB) {
        if(!areaScan) return []
        var boat=vehicle && vehicle.coordinate && vehicle.coordinate.isValid ? vehicle.coordinate : null
        var pts=areaScan.generateRectangle(cornerA,cornerB,boat); areaPoints=pts
        state=pts.length ? "AREA_DEFINED" : "IDLE"
        if(sonarMapping){sonarMapping.lakeId=lakeId; sonarMapping.totalLanes=areaScan.laneCount()}
        checkpoint("area"); status("Area Scan pregătit • "+areaScan.laneCount()+" culoare"); return pts
    }
    function prepareMission(resumeOnly) {
        if(!areaScan) return []
        var boat=vehicle && vehicle.coordinate && vehicle.coordinate.isValid ? vehicle.coordinate : null
        var route=resumeOnly ? areaScan.resumeRoute(boat) : areaScan.generatedPoints
        var mission=areaScan.exportMissionPoints(route)
        if (!mission.length) state=resumeOnly ? "PAUSED" : "AREA_DEFINED"
        if (mission.length) {
            var mapped=[]
            for (var lane=0;lane<areaScan.laneCount();lane++)
                if (!resumeOnly || areaScan.completedLanes.indexOf(lane)<0) mapped.push(lane)
            missionLanes=mapped
            lastCompletedRouteLaneFromMission=-1
            state=resumeOnly ? "RESUME_READY" : "READY"
            checkpoint("mission-prepared")
            missionPrepared(mission)
        }
        status((resumeOnly?"Resume":"Area Scan")+" • "+mission.length+" waypoint-uri pregătite"); return mission
    }
    function start() {
        if(state!=="READY") {status("Scanare blocată: misiunea nu este pregătită");return false}
        if(!sonarMapping || !areaScan || !areaScan.generatedPoints.length) {status("Scanare blocată: definește zona");return false}
        sonarMapping.startScan(); if(!sonarMapping.scanning) return false
        state="SCANNING"; missionCurrentIndex=-1; lastCompletedLaneFromMission=-1; lastCompletedRouteLaneFromMission=-1; checkpoint("start"); return true
    }
    function laneCompleted(index) {
        if(!areaScan || !sonarMapping || index<0) return
        areaScan.markLaneCompleted(index); sonarMapping.setLaneProgress(areaScan.activeLaneIndex,areaScan.completedLanes.length,areaScan.laneCount())
        checkpoint("lane"); if(areaScan.completedLanes.length>=areaScan.laneCount()) finish()
    }
    function pause(reason) {if(!areaScan||!sonarMapping)return;var boat=vehicle&&vehicle.coordinate?vehicle.coordinate:null;areaScan.hold(reason||"Pauză scanare",boat);sonarMapping.pauseScan();state="PAUSED";checkpoint("pause")}
    function resume() {
        if(!areaScan || !sonarMapping){status("Resume indisponibil: controlere neinițializate");return []}
        if(!areaScan.generatedPoints || !areaScan.generatedPoints.length){status("Resume indisponibil: traseul Area Scan lipsește");return []}
        var mission=prepareMission(true)
        if(!mission.length){status("Nu există culoare rămase");return []}
        return mission
    }
    function activateResume() {
        if(state!=="RESUME_READY") return false
        sonarMapping.resumeScan()
        if(!sonarMapping.scanning){status("Misiunea rulează, dar sonarul nu a intrat în scanare");return false}
        state="SCANNING";checkpoint("resume");return true
    }
    function rtl(reason) {if(!areaScan||!sonarMapping)return;areaScan.rtl(reason||"RTL scanare");sonarMapping.pauseScan();state="RTL";checkpoint("rtl")}
    function finish() {if(!sonarMapping)return;sonarMapping.finishAndBuild();if(bathymetry)bathymetryCells=bathymetry.rebuild(sonarMapping.rawSamples);state="COMPLETE";checkpoint("complete");status("Scanare terminată • "+bathymetryCells.length+" celule batimetrice")}

    function jsonCoordinates(points) {
        var out=[]
        if(!points)return out
        for(var i=0;i<points.length;i++) {
            var p=points[i]
            if(p && p.isValid) out.push({latitude:p.latitude,longitude:p.longitude})
            else if(p && p.latitude!==undefined && p.longitude!==undefined) out.push({latitude:Number(p.latitude),longitude:Number(p.longitude)})
        }
        return out
    }
    function geoCoordinates(points) {
        var out=[]
        if(!points)return out
        for(var i=0;i<points.length;i++) {
            var p=points[i]
            if(p && p.isValid) out.push(p)
            else if(p && p.latitude!==undefined && p.longitude!==undefined) out.push(QtPositioning.coordinate(Number(p.latitude),Number(p.longitude)))
        }
        return out
    }

    function checkpoint(reason) {
        if(!persistence || !sonarMapping || !areaScan || !lakeId.length) return false
        var payload={
            schemaVersion:2, reason:reason, state:state, lakeName:lakeName, savedAt:Date.now(),
            areaPoints:jsonCoordinates(areaPoints), sonarSamples:sonarMapping.rawSamples,
            fishingSpots:fishingSpots ? fishingSpots.fishingSpots : [],
            fishDetections:fishStore ? fishStore.detections : [],
            bathymetryCells:bathymetryCells,
            currentLane:areaScan.activeLaneIndex, completedLanes:areaScan.completedLanes,
            totalLanes:areaScan.laneCount(),
            missionCurrentIndex:missionCurrentIndex,
            lastCompletedLaneFromMission:lastCompletedLaneFromMission,
            lastCompletedRouteLaneFromMission:lastCompletedRouteLaneFromMission,
            missionLanes:missionLanes
        }
        return persistence.saveLakeState(lakeId,payload)
    }
    function restoreLake(id) {
        if(!persistence || !id.length) return false
        var p=persistence.lakeState(id); if(!p || Object.keys(p).length===0){status("Balta nu are încă stare salvată");return false}
        lakeId=id; lakeName=p.lakeName||lakeName; areaPoints=geoCoordinates(p.areaPoints||[])
        sonarMapping.lakeId=id; sonarMapping.rawSamples=p.sonarSamples||[]
        if(fishingSpots) fishingSpots.fishingSpots=p.fishingSpots||[]
        if(fishStore){fishStore.detections=p.fishDetections||[];fishStore.rebuildHotspots()}
        // A restored session cannot be considered live until the mission is
        // uploaded again and H743 confirms AUTO for this connection.
        state=(p.state==="COMPLETE" ? "COMPLETE" : "PAUSED"); bathymetryCells=p.bathymetryCells||[]
        areaScan.generatedPoints=areaPoints; areaScan.completedLanes=p.completedLanes||[]
        areaScan.activeLaneIndex=(p.currentLane===undefined?-1:Number(p.currentLane))
        missionCurrentIndex=(p.missionCurrentIndex===undefined?-1:Number(p.missionCurrentIndex))
        lastCompletedLaneFromMission=(p.lastCompletedLaneFromMission===undefined?-1:Number(p.lastCompletedLaneFromMission))
        lastCompletedRouteLaneFromMission=(p.lastCompletedRouteLaneFromMission===undefined?-1:Number(p.lastCompletedRouteLaneFromMission))
        missionLanes=p.missionLanes||[]
        if(lastCompletedLaneFromMission<0)
            for(var ci=0;ci<areaScan.completedLanes.length;ci++) lastCompletedLaneFromMission=Math.max(lastCompletedLaneFromMission,Number(areaScan.completedLanes[ci]))
        sonarMapping.restoreCheckpoint({lakeId:id,currentLane:areaScan.activeLaneIndex,completedLanes:areaScan.completedLanes.length,totalLanes:p.totalLanes||areaScan.laneCount(),sampleCount:sonarMapping.rawSamples.length,reason:"restart-restore",time:Date.now()})
        if(bathymetry && sonarMapping.rawSamples.length) bathymetryCells=bathymetry.rebuild(sonarMapping.rawSamples)
        status("Balta restaurată • sonar, puncte și Area Scan pregătite pentru Resume"); return true
    }
    property QtObject areaScanConnections: Connections {target:areaScan;function onSafetyActionRequested(action,reason){if(action==="HOLD"&&vehicle)vehicle.pauseVehicle();else if(action==="RTL"&&vehicle)vehicle.guidedModeRTL(false);status(action+": "+reason)}}
}
