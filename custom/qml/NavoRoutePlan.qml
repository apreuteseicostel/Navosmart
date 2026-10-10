import QtQuick
import QtPositioning

// Ordered GUIDED cycles, owned by the dashboard rather than the page Loader.
// Completion means commanded drop/exit, never measured hopper position or RTL arrival.
QtObject {
    id: root
    property var stops: []
    property string missionKind: "route"
    property var otherDraft: []
    property string otherFinishAction: "RTL"
    property string finishAction: "RTL"
    property bool readOnly: false
    property bool active: false
    property int currentIndex: -1
    property var runningStops: []
    property string runningFinishAction: "RTL"
    property string state: "DRAFT"
    property string lastError: ""
    property var history: []
    property double startedAtMs: 0
    property int generation: 0
    signal changed()
    signal stepRequested(var stop)
    signal finishRequested(string action)
    signal status(string text)

    function coordinate(stop) {
        return QtPositioning.coordinate(stop ? stop.latitude : NaN, stop ? stop.longitude : NaN)
    }
    function validStop(stop) {
        return !!stop && typeof stop.latitude === "number" && typeof stop.longitude === "number" &&
                isFinite(stop.latitude) && isFinite(stop.longitude) && coordinate(stop).isValid &&
                Number.isInteger(stop.hopper) && stop.hopper >= 0 && stop.hopper <= 3
    }
    function validate(points, action) {
        if(!points || !points.length || points.length > 50) return "Alege între 1 și 50 de opriri"
        if(["RTL", "ANCHOR", "HOLD"].indexOf(action) < 0) return "Acțiune finală invalidă"
        var used = 0
        for(var i=0; i<points.length; i++) {
            if(!validStop(points[i])) return "Oprirea " + (i+1) + " este invalidă"
            // Each physical hopper has one load. Do not promise two deliveries from one load.
            if(used & points[i].hopper) return "Aceeași cuvă nu poate elibera la două opriri fără reîncărcare"
            used |= points[i].hopper
        }
        return ""
    }
    // Switching editors preserves both drafts; never switches a running mission.
    function selectKind(kind) {
        if(readOnly || active || ["point","route"].indexOf(kind)<0) return false
        if(kind===missionKind) return true
        var previous=stops, previousAction=finishAction
        stops=otherDraft; finishAction=otherFinishAction
        otherDraft=previous; otherFinishAction=previousAction; missionKind=kind
        currentIndex=-1; state="DRAFT"; lastError=""; changed(); return true
    }
    function setPoint(wp, name, hopper) {
        if(readOnly || active || missionKind!=="point" || !wp || !wp.coordinate) return false
        var stop={name:String(name||"Punct"),latitude:wp.coordinate.latitude,longitude:wp.coordinate.longitude,hopper:hopper}
        var error=validate([stop],finishAction)
        if(error.length) {lastError=error;status(error);return false}
        stops=[stop];state="DRAFT";lastError="";changed();return true
    }
    function addStop(wp, name, hopper) {
        if(readOnly || active || !wp || !wp.coordinate || !wp.coordinate.isValid || stops.length >= 50 || (missionKind==="point" && stops.length>=1)) return false
        var stop = {name: String(name || "Punct"), latitude: wp.coordinate.latitude,
                    longitude: wp.coordinate.longitude, hopper: hopper}
        var next = stops.concat([stop]), error = validate(next, finishAction)
        if(error.length) { lastError=error; status(error); return false }
        stops=next; state="DRAFT"; lastError=""; changed(); return true
    }
    function removeStop(index) {
        if(readOnly || active || index<0 || index>=stops.length) return false
        var next=stops.slice(); next.splice(index,1); stops=next; state="DRAFT"; changed(); return true
    }
    function moveStop(index, offset) {
        var target=index+offset
        if(readOnly || active || index<0 || index>=stops.length || target<0 || target>=stops.length) return false
        var next=stops.slice(), stop=next.splice(index,1)[0]; next.splice(target,0,stop)
        stops=next; state="DRAFT"; changed(); return true
    }
    function snapshot() {
        return {version:1, missionKind:missionKind, otherDraft:otherDraft.map(function(s){return {name:s.name,latitude:s.latitude,longitude:s.longitude,hopper:s.hopper}}), otherFinishAction:otherFinishAction, history:history.slice(-50), stops:stops.map(function(s){return {name:s.name,latitude:s.latitude,longitude:s.longitude,hopper:s.hopper}}), finishAction:finishAction}
    }
    function restore(saved) {
        if(active) return false
        if(!saved || saved.version!==1 || !Array.isArray(saved.stops) ||
           (saved.stops.length && validate(saved.stops,saved.finishAction).length)) {
            stops=[]; otherDraft=[]; otherFinishAction="RTL"; missionKind="route"; history=[]; finishAction="RTL"; state="DRAFT"; return false
        }
        missionKind=saved.missionKind==="point" ? "point" : "route"
        if(missionKind==="point" && saved.stops.length>1) {stops=[];otherDraft=[];missionKind="route";return false}
        otherFinishAction=["RTL","ANCHOR","HOLD"].indexOf(saved.otherFinishAction)>=0 ? saved.otherFinishAction : "RTL"
        otherDraft=Array.isArray(saved.otherDraft) && (!saved.otherDraft.length || !validate(saved.otherDraft,otherFinishAction).length) &&
            (missionKind==="point" || saved.otherDraft.length<=1) ? saved.otherDraft.map(function(s){return {name:String(s.name||"Punct"),latitude:s.latitude,longitude:s.longitude,hopper:s.hopper}}) : []
        history=Array.isArray(saved.history) ? saved.history.filter(function(h){
            return h && typeof h.startedAt==="number" && isFinite(h.startedAt) &&
                typeof h.finishedAt==="number" && isFinite(h.finishedAt) &&
                ["DISPATCHED","STOPPED"].indexOf(h.result)>=0 && Number.isInteger(h.stopCount) && h.stopCount>0 && h.stopCount<=50
        }).slice(-50) : []
        stops=saved.stops.map(function(s){return {name:String(s.name||"Punct"),latitude:s.latitude,longitude:s.longitude,hopper:s.hopper}})
        finishAction=["RTL","ANCHOR","HOLD"].indexOf(saved.finishAction)>=0 ? saved.finishAction : "RTL"
        currentIndex=-1; runningStops=[]; state="DRAFT"; lastError=""; return true
    }
    function start(loadConfirmed) {
        if(readOnly || active) return false
        var error=missionKind==="point" && stops.length!==1 ? "Alege o singură destinație" : validate(stops,finishAction)
        if(!error.length && stops.some(function(s){return s.hopper!==0}) && !loadConfirmed)
            error="Confirmă încărcarea cuvelor înainte de START sau repetare"
        if(error.length) { lastError=error; status(error); return false }
        runningStops=snapshot().stops; runningFinishAction=finishAction
        startedAtMs=Date.now(); generation++; active=true; currentIndex=0; state="RUNNING"; lastError=""
        changed(); dispatchStep(); return active
    }
    function dispatchStep() {
        if(!active || currentIndex<0 || currentIndex>=runningStops.length) return
        status("Traseu • oprirea " + (currentIndex+1) + "/" + runningStops.length)
        stepRequested(runningStops[currentIndex])
    }
    function stepFinished(success, message) {
        if(!active) return
        if(!success) { cancel(message || "Oprirea a eșuat"); return }
        currentIndex++
        if(currentIndex>=runningStops.length) {
            recordHistory("DISPATCHED", "Acțiunile opririlor au fost comandate; sosirea HOME/poziția cuvelor nu sunt confirmate")
            active=false; state="DISPATCHED"; changed(); finishRequested(runningFinishAction); return
        }
        changed()
        var token=generation
        Qt.callLater(function(){ if(root.active && root.generation===token) root.dispatchStep() })
    }
    function recordHistory(result, message) {
        if(!startedAtMs) return
        history=history.concat([{startedAt:startedAtMs,finishedAt:Date.now(),result:result,
                                stopCount:runningStops.length,completedStops:Math.min(currentIndex,runningStops.length),
                                finishAction:runningFinishAction,message:message}]).slice(-50)
        startedAtMs=0
    }
    function cancel(reason) {
        if(active) recordHistory("STOPPED",reason||"Traseu oprit")
        generation++; active=false; state="STOPPED"; lastError=reason||"Traseu oprit"
        changed(); status(lastError)
    }
    function estimate(origin, home, controller) {
        if(!origin || !origin.isValid || !controller || validate(stops,finishAction).length)
            return {valid:false}
        var values=[controller.silentRadiusM,controller.finalRadiusM,controller.exitDistanceM,controller.settleMs,controller.postDropMs]
        if(values.some(function(v){return !isFinite(v)||v<0}) || controller.finalRadiusM>controller.silentRadiusM) return {valid:false}
        var previous=origin, distance=0, seconds=0
        var normal=controller.silentMode ? controller.silentSpeedMps : controller.normalSpeedMps
        var slow=controller.silentSpeedMps, finalSpeed=controller.finalSpeedMps
        if(!isFinite(normal)||normal<=0||!isFinite(slow)||slow<=0||!isFinite(finalSpeed)||finalSpeed<=0) return {valid:false}
        for(var i=0;i<stops.length;i++) {
            var target=coordinate(stops[i]), d=previous.distanceTo(target)
            if(!isFinite(d)||d<0) return {valid:false}
            var finalD=Math.min(d,controller.finalRadiusM)
            var slowD=Math.min(Math.max(0,d-finalD),Math.max(0,controller.silentRadiusM-controller.finalRadiusM))
            distance+=d; seconds+=(d-finalD-slowD)/normal+slowD/slow+finalD/finalSpeed
            seconds+=(controller.settleMs+controller.postDropMs)/1000
            var bearing=previous.azimuthTo(target)+(controller.exitSide>=0?90:-90)
            var exitM=stops[i].hopper!==0 ? controller.exitDistanceM : 0
            previous=target.atDistanceAndAzimuth(exitM,bearing)
            distance+=exitM; seconds+=exitM/slow
        }
        // Energy always includes a return reserve, even when the selected final action is HOLD/ANCHOR.
        if(!home || !home.isValid) return {valid:false}
        var returnM=previous.distanceTo(home)
        if(!isFinite(returnM)||returnM<0||!isFinite(seconds)||seconds<0) return {valid:false}
        return {valid:true, distanceM:distance+(finishAction==="RTL"?returnM:0),
                durationSeconds:seconds+(finishAction==="RTL"?returnM/normal:0), energyDistanceM:distance+returnM}
    }
}
