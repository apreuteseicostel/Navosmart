import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtPositioning
import "../custom/qml" as Navo
ApplicationWindow {
    id:root; width:480; height:720; visible:true; color:"#0b1c2e"
    property var outputActions: []
    property alias plan:plan
    Navo.NavoRoutePlan {
        id:plan
        libraryAvailable:true
        persistLibrary:function(){return true}
        onStepRequested:function(stop){root.outputActions=root.outputActions.concat([stop.hopper])}
    }
    Navo.NavoRoutePanel {
        objectName:"routePanel"; anchors.fill:parent; anchors.margins:12
        routePlan:plan
        waypoint:({name:"Punct test",coordinate:QtPositioning.coordinate(52,0.002)})
        availableSpots: [{name:"Punct A",lat:52,lon:0.001},{name:"Punct B",lat:52,lon:0.002}]
        estimate:({valid:true,distanceM:420,durationSeconds:240})
        energyText:"Verificare energie dezactivată • calibrează consumul"
    }
    QtObject {
        id:mockController
        property bool enabled:false
        property bool rtlAfterDrop:true
        property real silentRadiusM:10
        property real finalRadiusM:3
        property real silentSpeedMps:0.8
        property real finalSpeedMps:0.4
        property real accelerationMps2:0.4
        property real decelerationMps2:0.5
        property real exitDistanceM:4
        property int exitSide:1
        property int state:0
        function stateText(s){return "Pregătit"}
    }
    Navo.NavoBaitingPanel {
        visible:false; width:300;height:600
        controller:mockController; hopperBridge:null; routePlan:plan
        waypoint:({name:"Punct test",coordinate:QtPositioning.coordinate(52,0.002)})
        availableSpots: [{name:"Punct A",lat:52,lon:0.001},{name:"Punct B",lat:52,lon:0.002}]
        routeEstimate:({valid:true,distanceM:420,durationSeconds:240})
        routeEnergyText:"Verificare energie dezactivată • calibrează consumul"
    }
    function seed() {
        plan.addStop({coordinate:QtPositioning.coordinate(52,0.001)},"Punct A",1)
        plan.addStop({coordinate:QtPositioning.coordinate(52,0.002)},"Punct B",2)
        return plan.stops.length===2
    }
    function libraryExercise() {
        if(!plan.savePreset("Morning route"))return false
        var saved=plan.snapshot()
        plan.removeStop(0)
        if(!plan.restore(saved) || plan.library.length!==1)return false
        return plan.loadPreset(plan.library[0].id) && !plan.active && plan.stops.length===2
    }
    function exercise() {
        if(plan.start(false))return false
        if(!plan.start(true))return false
        if(outputActions.length!==1 || outputActions[0]!==1)return false
        plan.stepFinished(true,"A")
        return true
    }
    function complete() {
        if(outputActions.length!==2 || outputActions[1]!==2)return false
        plan.stepFinished(true,"B")
        var saved=plan.snapshot()
        if(plan.active || !plan.restore(saved) || plan.state!=="DRAFT")return false
        return true
    }
}
