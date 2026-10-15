import QtQuick
import QtCore

QtObject {
    id:root
    property var output:null
    property bool replayMode:false
    property var vehicle:null
    property bool nanoConnected:false
    property bool waterValid:nanoConnected
    property bool temperatureValid:nanoConnected
    property bool waterConfirmed:false
    property real batteryTempC:NaN
    property real batteryPercent:NaN
    property bool gpsHealthy:false
    property bool linkHealthy:false
    property string latest:""
    property var previous:({})
    property var lastTimes:({})
    property var trackedVehicle:null
    property var audioQueue:[]
    property double lastAudioAt:0
    property Settings preferences:Settings {
        category:"NavoAlerts"
        property bool soundEnabled:false
        property bool voiceEnabled:false
        property real volume:0.7
    }
    readonly property bool soundEnabled:preferences.soundEnabled
    readonly property bool voiceEnabled:preferences.voiceEnabled
    readonly property real volume:preferences.volume
    signal raised(string key,string text,bool critical)
    function configure(sound,voice,value) {
        preferences.soundEnabled=sound;preferences.voiceEnabled=voice
        preferences.volume=Math.max(0,Math.min(1,value))
        if(!sound && !voice){audioQueue=[];if(output)output.stop()}
    }
    function notify(key,text,critical) {
        if(replayMode)return false
        var now=Date.now()
        if(lastTimes[key]!==undefined && now-Number(lastTimes[key])<10000)return false
        var times=Object.assign({},lastTimes);times[key]=now;lastTimes=times
        latest=text;raised(key,text,critical)
        if(output && (soundEnabled || voiceEnabled)) {
            var queue=audioQueue.filter(function(item){return item.key!==key})
            var priorities={water:5,temperature:4,link:3,gps:2,battery:1}
            queue.push({key:key,text:text,critical:critical,at:now,priority:priorities[key]||0})
            queue.sort(function(a,b){return b.priority-a.priority})
            audioQueue=queue.slice(0,8)
        }
        return true
    }
    function edge(key,active,text,critical) {
        // Unknown telemetry does not count as recovery. Only a known healthy
        // measurement re-arms an alert, avoiding repeats during intermittent loss.
        if(active===null)return
        var old=previous[key],next=Object.assign({},previous)
        if(!active)audioQueue=audioQueue.filter(function(item){return item.key!==key})
        if(active && old!==true && !notify(key,text,critical))return
        next[key]=active;previous=next
    }
    function tick() {
        if(replayMode)return
        if(vehicle!==trackedVehicle){trackedVehicle=vehicle;previous=({});lastTimes=({});audioQueue=[];if(output)output.stop()}
        if(!vehicle)return
        edge("link",!linkHealthy,"Legătura cu barca este pierdută",true)
        edge("gps",linkHealthy ? !gpsHealthy : null,"Poziția GPS este pierdută",true)
        edge("battery",linkHealthy && isFinite(batteryPercent) && batteryPercent>=0 ? batteryPercent<=20 : null,"Bateria bărcii este scăzută",true)
        edge("water",waterValid ? waterConfirmed : null,"Apă confirmată în barcă",true)
        edge("temperature",temperatureValid && isFinite(batteryTempC) ? batteryTempC>=55 : null,"Temperatura bateriei este critică",true)
    }
    function dispatch() {
        if(replayMode || !output || (!soundEnabled && !voiceEnabled))return
        var now=Date.now(),queue=audioQueue.filter(function(item){return now-item.at<20000})
        audioQueue=queue
        if(!queue.length || now-lastAudioAt<2500 || (voiceEnabled && output.busy))return
        var item=queue[0];audioQueue=queue.slice(1);lastAudioAt=now
        output.play(soundEnabled,voiceEnabled,item.text,item.critical)
    }
    function test() {
        latest="Test alerte NAVO SMART"
        if(output)output.play(soundEnabled,voiceEnabled,latest,false)
    }
    onReplayModeChanged: { previous=({});lastTimes=({});audioQueue=[];if(output)output.stop() }
    property Timer dispatcher:Timer { interval:250;repeat:true;running:true;onTriggered:root.dispatch() }
    property Timer monitor:Timer { interval:500;repeat:true;running:true;onTriggered:root.tick() }
}
