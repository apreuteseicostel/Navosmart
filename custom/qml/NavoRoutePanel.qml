import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    id: root
    objectName:"navoRoutePanel"
    property var routePlan
    property var waypoint
    property var availableSpots: []
    property var estimate: ({valid:false})
    property string energyText: ""
    signal spotChosen(var spot)
    signal chooseOnMapRequested()
    signal startRequested(bool loadConfirmed)
    signal stopRequested()
    spacing: 8
    Label { text:"TRASEU CU OPRIRI"; color:"white"; font.bold:true; font.pixelSize:18 }
    Label { Layout.fillWidth:true; text:"Alege punctele în ordine. Fiecare cuvă poate fi folosită o dată per încărcare."; color:"#d7e3ee"; wrapMode:Text.WordWrap }
    ComboBox {
        Layout.fillWidth:true; model:root.availableSpots; textRole:"name"
        enabled:!!root.routePlan && (!root.routePlan.active && !root.routePlan.readOnly); displayText:"Alege un punct salvat"
        onActivated:function(index){root.spotChosen(root.availableSpots[index])}
    }
    RowLayout {
        Layout.fillWidth:true
        Label { Layout.fillWidth:true; text:root.waypoint ? root.waypoint.name||"Punct hartă" : "Alege punctul"; color:"#21b7ff"; elide:Text.ElideRight }
        Button { text:"Hartă"; enabled:!!root.routePlan && (!root.routePlan.active && !root.routePlan.readOnly); onClicked:root.chooseOnMapRequested() }
    }
    RowLayout {
        Layout.fillWidth:true
        ComboBox { id:actionBox; Layout.fillWidth:true; model:["Doar navigare","Cuva stângă","Cuva dreaptă","Ambele cuve"]; enabled:!!root.routePlan && (!root.routePlan.active && !root.routePlan.readOnly) }
        Button { text:"+"; Accessible.name:"Adaugă oprirea"; enabled:!!root.waypoint && !!root.routePlan && (!root.routePlan.active && !root.routePlan.readOnly)
            onClicked:{if(root.routePlan.addStop(root.waypoint,root.waypoint.name,actionBox.currentIndex))loadCheck.checked=false} }
    }
    ListView {
        Layout.fillWidth:true; Layout.fillHeight:true; Layout.minimumHeight:90
        clip:true; spacing:4; model:root.routePlan ? root.routePlan.stops : []
        delegate:Rectangle {
            required property var modelData
            required property int index
            width:ListView.view.width; height:64; radius:6
            color:root.routePlan.active && root.routePlan.currentIndex===index ? "#164963" : "#102536"
            ColumnLayout {
                anchors.fill:parent; anchors.margins:5; spacing:0
                Label { Layout.fillWidth:true; text:(index+1)+". "+modelData.name+" • "+["Navigare","Stânga","Dreapta","Ambele"][modelData.hopper]; color:"white"; elide:Text.ElideRight }
                RowLayout {
                    Item { Layout.fillWidth:true }
                    Button { text:"↑"; implicitHeight:28; implicitWidth:38; Accessible.name:"Mută oprirea în sus"; enabled:(!root.routePlan.active && !root.routePlan.readOnly) && index>0; onClicked:{root.routePlan.moveStop(index,-1);loadCheck.checked=false} }
                    Button { text:"↓"; implicitHeight:28; implicitWidth:38; Accessible.name:"Mută oprirea în jos"; enabled:(!root.routePlan.active && !root.routePlan.readOnly) && index<root.routePlan.stops.length-1; onClicked:{root.routePlan.moveStop(index,1);loadCheck.checked=false} }
                    Button { text:"×"; implicitHeight:28; implicitWidth:38; Accessible.name:"Șterge oprirea"; enabled:(!root.routePlan.active && !root.routePlan.readOnly); onClicked:{root.routePlan.removeStop(index);loadCheck.checked=false} }
                }
            }
        }
    }
    RowLayout {
        Label { text:"La final"; color:"white" }
        ComboBox { Layout.fillWidth:true; model:["Întoarcere HOME","Ancoră GPS","HOLD"]
            enabled:!!root.routePlan && (!root.routePlan.active && !root.routePlan.readOnly)
            currentIndex:root.routePlan ? ["RTL","ANCHOR","HOLD"].indexOf(root.routePlan.finishAction) : 0
            onActivated:function(index){root.routePlan.finishAction=["RTL","ANCHOR","HOLD"][index];root.routePlan.changed();loadCheck.checked=false} }
    }
    Label { Layout.fillWidth:true; wrapMode:Text.WordWrap; color:"#d7e3ee"
        text:root.estimate.valid ? "~"+Math.ceil(root.estimate.distanceM)+" m • ~"+Math.ceil(root.estimate.durationSeconds/60)+" min\nEstimare; vântul, virajele și stabilizarea pot prelungi durata.\n"+root.energyText : "Estimare indisponibilă: verifică traseul, GPS și HOME" }
    Label {
        Layout.fillWidth:true; color:"#d7e3ee"; wrapMode:Text.WordWrap
        visible:!!root.routePlan && root.routePlan.history.length>0
        text: {
            if(!root.routePlan || !root.routePlan.history.length)return ""
            var entry=root.routePlan.history[root.routePlan.history.length-1]
            return "Ultimul traseu: "+new Date(entry.finishedAt).toLocaleString()+" • "+entry.completedStops+"/"+entry.stopCount+" opriri • "+(entry.result==="DISPATCHED"?"acțiuni comandate":"oprit")
        }
    }
    CheckBox { id:loadCheck; Layout.fillWidth:true; text:"Am încărcat/reîncărcat cuvele"; palette.windowText:"white"; enabled:!!root.routePlan && (!root.routePlan.active && !root.routePlan.readOnly) }
    Label { Layout.fillWidth:true; text:root.routePlan ? root.routePlan.lastError : ""; color:"#ffc857"; wrapMode:Text.WordWrap; visible:text.length>0 }
    RowLayout {
        Button { text:root.routePlan && root.routePlan.state==="DISPATCHED" ? "REPETĂ" : "START"; enabled:!!root.routePlan && (!root.routePlan.active && !root.routePlan.readOnly) && root.routePlan.stops.length>0
            onClicked:confirmation.open() }
        Button { text:"STOP"; enabled:!!root.routePlan && root.routePlan.active; onClicked:root.stopRequested() }
        Label { Layout.fillWidth:true; color:"#31d67b"; wrapMode:Text.WordWrap; text:root.routePlan && root.routePlan.active ? "Oprire "+(root.routePlan.currentIndex+1)+"/"+root.routePlan.runningStops.length : "" }
    }
    Dialog {
        objectName:"navoRouteConfirmation"
        id:confirmation; parent:Overlay.overlay; anchors.centerIn:parent
        width:Math.min(440,parent ? parent.width-24 : 440); height:Math.min(220,parent ? parent.height-24 : 220); modal:true; title:"Confirmă traseul"
        standardButtons:Dialog.Ok|Dialog.Cancel
        contentItem:Label { text:"Barca va parcurge opririle și va executa acțiunile cuvelor. Verifică traseul liber și încărcarea cuvelor."; wrapMode:Text.WordWrap; color:"white" }
        background:Rectangle{color:"#0b1c2e";radius:8;border.color:"#21b7ff"}
        onAccepted:{root.startRequested(loadCheck.checked);loadCheck.checked=false}
    }
}
