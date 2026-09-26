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
    property int missionWaypointCount: 0
    signal status(string text)
    signal missionPrepared(var missionPoints)
    signal lakeActivated(string id)
    signal scanFinished(bool bathymetrySaved, int sampleCount)

    function activateLake(id, name) {
        if(!persistence || !sonarMapping || !areaScan || !id.length) return false
        if(state==="SCANNING" || state==="READY" || state==="RESUME_READY") {
            status("Oprește misiunea înainte de schimbarea bălții"); return false
        }
        if(lakeId===id) return true
        if(lakeId.length && !checkpoint("lake-switch")) return false
        var saved=persistence.lakeState(id)
        if(saved && Object.keys(saved).length) {
            if(!restoreLake(id)) return false
        } else {
            lakeId=id; lakeName=name||"Baltă"; areaPoints=[]; bathymetryCells=[]
            areaScan.generatedPoints=[]; areaScan.completedLanes=[]; areaScan.activeLaneIndex=-1; areaScan.paused=false; areaScan.lastBoatCoordinate=null
            sonarMapping.scanning=false; sonarMapping.paused=false; sonarMapping.rawSamples=[]; sonarMapping.trackCoordinates=[]
            sonarMapping.currentLane=0; sonarMapping.completedLanes=0; sonarMapping.totalLanes=0
            if(fishingSpots) fishingSpots.fishingSpots=[]
            if(fishStore) fishStore.clear()
            if(persistence.replaceWaypointNames) persistence.replaceWaypointNames({})
            state="IDLE"; missionLanes=[]; missionWaypointCount=0; missionCurrentIndex=-1
            lastCompletedLaneFromMission=-1; lastCompletedRouteLaneFromMission=-1
            if(!checkpoint("lake-created")) return false
        }
        lakeActivated(id); return true
    }

    function clearActiveLake() {
        if(!sonarMapping || !areaScan) return false
        lakeId=""; lakeName=""; areaPoints=[]; bathymetryCells=[]
        areaScan.generatedPoints=[]; areaScan.completedLanes=[]; areaScan.activeLaneIndex=-1
        areaScan.paused=false; areaScan.lastBoatCoordinate=null
        sonarMapping.scanning=false; sonarMapping.paused=false; sonarMapping.lakeId=""
        sonarMapping.rawSamples=[]; sonarMapping.trackCoordinates=[]
        sonarMapping.currentLane=0; sonarMapping.completedLanes=0; sonarMapping.totalLanes=0
        if(fishingSpots) fishingSpots.fishingSpots=[]
        if(fishStore) fishStore.clear()
        if(persistence && persistence.replaceWaypointNames) persistence.replaceWaypointNames({})
        state="IDLE"; missionLanes=[]; missionWaypointCount=0; missionCurrentIndex=-1
        lastCompletedLaneFromMission=-1; lastCompletedRouteLaneFromMission=-1
        lakeActivated("")
        return true
    }

    function renameLake(id, name) {
        if(!persistence || !id || !id.length) return false
        var clean=String(name||"").trim()
        if(!clean.length) { status("Numele bălții nu poate fi gol"); return false }
        var savedId=persistence.saveLake({id:id,name:clean})
        if(!savedId) { status("Redenumirea bălții a eșuat"); return false }
        if(lakeId===id) {
            lakeName=clean
            if(!checkpoint("lake-renamed")) return false
        }
        status("Baltă redenumită: "+clean)
        return true
    }

    function deleteLake(id) {
        if(!persistence || !id || !id.length) return false
        if(state==="SCANNING" || state==="READY" || state==="RESUME_READY") {
            status("Oprește misiunea înainte de ștergerea bălții")
            return false
        }
        var deletingActive=lakeId===id
        if(!persistence.deleteLake(id)) {
            status("Ștergerea bălții a eșuat")
            return false
        }
        if(deletingActive) clearActiveLake()
        status("Balta și datele asociate au fost șterse")
        return true
    }

    property Timer autosave: Timer {
        interval: 5000; repeat: true; running: root.lakeId.length>0
        onTriggered: root.checkpoint("autosave")
    }

    function missionIndexChanged(index) {
        if(!areaScan || state !== "SCANNING" || index === undefined || index === null || index < 0) return
        missionCurrentIndex=index
        // MISSION_CURRENT identifies the current target, not proof of arrival.
        // Completion is recorded only from MISSION_ITEM_REACHED.
        status("Area Scan • WP "+index+" • "+areaScan.progressPercent()+"%")
        if(missionWaypointCount>0 && index >= missionWaypointCount + 1 && areaScan.completedLanes.length>=areaScan.laneCount() && state==="SCANNING") finish()
    }

    function preparePolygon(polygon) {
        if(!areaScan || state==="SCANNING") return []
        var pts=areaScan.generatePolygon(polygon); areaPoints=pts
        state=pts.length ? "AREA_DEFINED" : "IDLE"
        if(sonarMapping){sonarMapping.lakeId=lakeId; sonarMapping.totalLanes=areaScan.laneCount()}
        checkpoint("area-polygon"); status("Area Scan poligon pregătit • "+areaScan.laneCount()+" culoare"); return pts
    }
    function prepareRectangle(cornerA, cornerB) {
        if(!areaScan || state==="SCANNING") return []
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
            missionWaypointCount=mission.length
            missionCurrentIndex=-1
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
    function missionItemReached(sequence) {
        // ArduPilot Rover reserves item 0 for home. Each lane ends at an even
        // sequence (2, 4, ...). Ignore messages outside this uploaded route.
        if(!areaScan || state!=="SCANNING" || sequence < 2 ||
           sequence > missionWaypointCount || sequence % 2 !== 0) return false
        var routeLane=sequence / 2 - 1
        if(routeLane >= missionLanes.length || routeLane <= lastCompletedRouteLaneFromMission) return false
        lastCompletedRouteLaneFromMission=routeLane
        lastCompletedLaneFromMission=missionLanes[routeLane]
        laneCompleted(lastCompletedLaneFromMission)
        return true
    }

    function laneCompleted(index) {
        if(!areaScan || !sonarMapping || index<0) return
        areaScan.markLaneCompleted(index); sonarMapping.setLaneProgress(areaScan.activeLaneIndex,areaScan.completedLanes.length,areaScan.laneCount())
        checkpoint("lane"); if(areaScan.completedLanes.length>=areaScan.laneCount()) finish()
    }
    function pause(reason) {if(!areaScan||!sonarMapping)return;var boat=vehicle&&vehicle.coordinate?vehicle.coordinate:null;areaScan.hold(reason||"Pauză scanare",boat);sonarMapping.pauseScan();state="PAUSED";checkpoint("pause")}
    function resume() {
        if(state!=="PAUSED" && state!=="RTL"){status("Resume disponibil numai după HOLD/STOP/RTL");return []}
        if(!areaScan || !sonarMapping){status("Resume indisponibil: controlere neinițializate");return []}
        if(!areaScan.generatedPoints || !areaScan.generatedPoints.length){status("Resume indisponibil: traseul Area Scan lipsește");return []}
        var mission=prepareMission(true)
        if(!mission.length){status("Nu există culoare rămase");return []}
        return mission
    }
    function activateResume() {
        if(state!=="RESUME_READY") return false
        if(!sonarMapping.resumeScan()){status("Resume blocat: GPS și sonar trebuie să fie LIVE");return false}
        if(!sonarMapping.scanning || sonarMapping.paused){status("Misiunea rulează, dar sonarul nu a intrat în scanare");return false}
        state="SCANNING";checkpoint("resume");return true
    }
    function rtl(reason) {if(!areaScan||!sonarMapping)return;areaScan.rtl(reason||"RTL scanare");sonarMapping.pauseScan();state="RTL";checkpoint("rtl")}
    function finish() {
        if(!sonarMapping || state==="COMPLETE" || state==="FINISHING") return false
        state="FINISHING"
        sonarMapping.finishAndBuild()
        var bathyOk=false
        if(sonarMapping.rawSamples.length>=3 && bathymetry && bathymetry.rebuild) {
            var rebuilt=bathymetry.rebuild(sonarMapping.rawSamples)
            if(rebuilt!==undefined && rebuilt!==null) {
                bathymetryCells=rebuilt
                bathyOk=true
            }
        }
        sonarMapping.markBathymetrySaved(bathyOk)
        state="COMPLETE"
        areaScan.activeLaneIndex=-1
        areaScan.paused=false
        sonarMapping.setLaneProgress(-1,areaScan.laneCount(),areaScan.laneCount())
        var saved=checkpoint("complete")
        status(saved
               ? "Area Scan 100% • "+sonarMapping.rawSamples.length+" măsurători salvate"+(bathyOk?" • batimetrie generată":" • batimetrie indisponibilă")
               : "Area Scan 100% • EROARE la salvarea finală")
        scanFinished(bathyOk && saved, sonarMapping.rawSamples.length)
        return saved
    }

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
            waypointNames:persistence.waypointNames || ({}),
            bathymetryCells:bathymetryCells,
            currentLane:areaScan.activeLaneIndex, completedLanes:areaScan.completedLanes,
            lastBoatCoordinate:(areaScan.lastBoatCoordinate && areaScan.lastBoatCoordinate.isValid) ? {latitude:areaScan.lastBoatCoordinate.latitude,longitude:areaScan.lastBoatCoordinate.longitude} : null,
            totalLanes:areaScan.laneCount(),
            missionCurrentIndex:missionCurrentIndex,
            lastCompletedLaneFromMission:lastCompletedLaneFromMission,
            lastCompletedRouteLaneFromMission:lastCompletedRouteLaneFromMission,
            missionLanes:missionLanes, missionWaypointCount:missionWaypointCount
        }
        var ok=persistence.saveLakeState(lakeId,payload)
        if(!ok) status("Salvarea bălții a eșuat; datele nu sunt confirmate pe disc")
        return ok
    }
    function restoreLake(id) {
        if(!persistence || !sonarMapping || !areaScan || !id.length || state==="SCANNING") return false
        if(lakeId && lakeId!==id && !checkpoint("before-restore")) return false
        var p=persistence.lakeState(id); if(!p || Object.keys(p).length===0){status("Balta nu are încă stare salvată");return false}
        lakeId=id; lakeName=p.lakeName||lakeName; areaPoints=geoCoordinates(p.areaPoints||[])
        sonarMapping.lakeId=id; sonarMapping.rawSamples=(p.sonarSamples||[]).slice(0)
        sonarMapping.trackCoordinates=[]
        if(fishingSpots) fishingSpots.fishingSpots=(p.fishingSpots||[]).slice(0)
        if(fishStore){fishStore.detections=(p.fishDetections||[]).slice(0);fishStore.rebuildHotspots()}
        if(persistence.replaceWaypointNames) persistence.replaceWaypointNames(p.waypointNames||({}))
        // A restored session cannot be considered live until the mission is
        // uploaded again and the autopilot confirms AUTO for this connection.
        state=(p.state==="COMPLETE" ? "COMPLETE" : (p.state==="RTL" ? "RTL" : "PAUSED")); bathymetryCells=p.bathymetryCells||[]
        areaScan.generatedPoints=areaPoints; areaScan.completedLanes=p.completedLanes||[]
        areaScan.activeLaneIndex=(p.currentLane===undefined?-1:Number(p.currentLane))
        areaScan.lastBoatCoordinate=(p.lastBoatCoordinate && p.lastBoatCoordinate.latitude!==undefined && p.lastBoatCoordinate.longitude!==undefined) ? QtPositioning.coordinate(Number(p.lastBoatCoordinate.latitude),Number(p.lastBoatCoordinate.longitude)) : null
        missionCurrentIndex=(p.missionCurrentIndex===undefined?-1:Number(p.missionCurrentIndex))
        lastCompletedLaneFromMission=(p.lastCompletedLaneFromMission===undefined?-1:Number(p.lastCompletedLaneFromMission))
        lastCompletedRouteLaneFromMission=(p.lastCompletedRouteLaneFromMission===undefined?-1:Number(p.lastCompletedRouteLaneFromMission))
        missionLanes=p.missionLanes||[]
        missionWaypointCount=(p.missionWaypointCount===undefined ? missionLanes.length*2 : Number(p.missionWaypointCount))
        // Recompute the active lane from completedLanes. This avoids resuming
        // from a stale currentLane if the app was killed between checkpoints.
        if(state!=="COMPLETE") {
            var nextLane=-1
            for(var li=0;li<areaScan.laneCount();li++) if(areaScan.completedLanes.indexOf(li)<0){nextLane=li;break}
            areaScan.activeLaneIndex=nextLane
        }
        if(lastCompletedLaneFromMission<0)
            for(var ci=0;ci<areaScan.completedLanes.length;ci++) lastCompletedLaneFromMission=Math.max(lastCompletedLaneFromMission,Number(areaScan.completedLanes[ci]))
        sonarMapping.restoreCheckpoint({lakeId:id,currentLane:areaScan.activeLaneIndex,completedLanes:areaScan.completedLanes.length,totalLanes:p.totalLanes||areaScan.laneCount(),sampleCount:sonarMapping.rawSamples.length,reason:"restart-restore",time:Date.now()})
        if(state==="COMPLETE") { sonarMapping.scanning=false; sonarMapping.paused=false }
        if(bathymetry && sonarMapping.rawSamples.length) bathymetryCells=bathymetry.rebuild(sonarMapping.rawSamples)
        status("Balta restaurată • sonar, puncte și Area Scan pregătite pentru Resume"); return true
    }
    property QtObject areaScanConnections: Connections { target: areaScan; function onSafetyActionRequested(action,reason) { status(action+": "+reason) } }
}
