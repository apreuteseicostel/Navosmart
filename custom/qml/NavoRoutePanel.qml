import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    id: root
    objectName:"navoRoutePanel"
    property real speedMps: 1.5
    property bool showSpeed: true
    property bool speedEditable: false
    signal speedRequested(real speed)
    readonly property bool singlePoint: !!routePlan && routePlan.missionKind==="point"
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
    Button { Layout.fillWidth:true;text:"MISIUNI SALVATE";objectName:"missionLibraryButton"
        enabled:!!root.routePlan && !!root.routePlan.libraryAvailable && !root.routePlan.active && !root.routePlan.readOnly
        onClicked:missionLibraryDialog.open() }
    Dialog {
        id:missionLibraryDialog;objectName:"missionLibraryDialog";parent:Overlay.overlay
        anchors.centerIn:parent;modal:true;title:"Misiunile acestei bălți"
        width:Math.min(440,parent ? parent.width-16 : 440);height:Math.min(430,parent ? parent.height-16 : 430)
        contentItem:ColumnLayout {
            TextField { id:missionLibraryName;objectName:"missionLibraryName";Layout.fillWidth:true;maximumLength:80;placeholderText:"Nume pentru configurația curentă" }
            Button { Layout.fillWidth:true;text:"SALVEAZĂ CONFIGURAȚIA";enabled:!!root.routePlan && !!root.routePlan.libraryAvailable && !root.routePlan.active && !root.routePlan.readOnly
                onClicked:if(root.routePlan.savePreset(missionLibraryName.text.trim()))missionLibraryName.text="" }
            Label { Layout.fillWidth:true;wrapMode:Text.WordWrap;text:"Puncte, acțiuni cuve și comportament final. Viteza folosește setarea curentă; START se confirmă separat." }
            Label { Layout.fillWidth:true;wrapMode:Text.WordWrap;text:root.routePlan ? root.routePlan.lastError : "" }
            ListView {
                Layout.fillWidth:true;Layout.fillHeight:true;clip:true;spacing:4
                model:root.routePlan ? root.routePlan.library : [];ScrollBar.vertical:ScrollBar {}
                delegate:RowLayout {
                    required property var modelData
                    width:ListView.view.width
                    Label { Layout.fillWidth:true;text:modelData.name;elide:Text.ElideRight }
                    Button { text:"Încarcă";enabled:!!root.routePlan.libraryAvailable && !root.routePlan.active && !root.routePlan.readOnly
                        onClicked:if(root.routePlan.loadPreset(modelData.id)){loadCheck.checked=false;missionLibraryDialog.close()} }
                    Button { text:"×";Accessible.name:"Șterge misiunea "+modelData.name;enabled:!!root.routePlan.libraryAvailable && !root.routePlan.active && !root.routePlan.readOnly
                        onClicked:{deleteMissionDialog.presetId=modelData.id;deleteMissionDialog.open()} }
                }
            }
            Button { Layout.fillWidth:true;text:"ÎNCHIDE";onClicked:missionLibraryDialog.close() }
        }
    }
    Dialog { id:deleteMissionDialog;property string presetId:"";parent:Overlay.overlay;anchors.centerIn:parent
        modal:true;title:"Ștergi misiunea salvată?";standardButtons:Dialog.Yes|Dialog.No
        onAccepted:root.routePlan.removePreset(presetId) }
    Label { text:root.singlePoint ? "MERGI LA PUNCT" : "TRASEU CU OPRIRI"; color:"white"; font.bold:true; font.pixelSize:18 }
    Label { Layout.fillWidth:true; text:root.singlePoint ? "Alege destinația și acțiunea cuvelor." : "Alege punctele în ordine. Fiecare cuvă poate fi folosită o dată per încărcare."; color:"#d7e3ee"; wrapMode:Text.WordWrap }
    RowLayout {
        visible:root.showSpeed
        Layout.fillWidth:true
        Label {text:"Viteză (m/s)";color:"white"}
        SpinBox { objectName:"missionSpeed"; from:1;to:30;stepSize:1;value:Math.round(root.speedMps*10)
            enabled:root.speedEditable && !!root.routePlan && !root.routePlan.active && !root.routePlan.readOnly
            textFromValue:function(v,locale){return Number(v/10).toLocaleString(locale,'f',1)}
            onValueModified:root.speedRequested(value/10) }
    }
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
        Button { text:root.singlePoint ? "Aplică" : "+"; Accessible.name:root.singlePoint ? "Aplică destinația" : "Adaugă oprirea"; enabled:!!root.waypoint && !!root.routePlan && (!root.routePlan.active && !root.routePlan.readOnly)
            onClicked:{if(root.singlePoint ? root.routePlan.setPoint(root.waypoint,root.waypoint.name,actionBox.currentIndex) : root.routePlan.addStop(root.waypoint,root.waypoint.name,actionBox.currentIndex))loadCheck.checked=false} }
    }
    ListView {
        Layout.fillWidth:true; Layout.fillHeight:true; Layout.minimumHeight:root.singlePoint ? 64 : 90
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
                    Button { visible:!root.singlePoint; text:"↑"; implicitHeight:28; implicitWidth:38; Accessible.name:"Mută oprirea în sus"; enabled:(!root.routePlan.active && !root.routePlan.readOnly) && index>0; onClicked:{root.routePlan.moveStop(index,-1);loadCheck.checked=false} }
                    Button { visible:!root.singlePoint; text:"↓"; implicitHeight:28; implicitWidth:38; Accessible.name:"Mută oprirea în jos"; enabled:(!root.routePlan.active && !root.routePlan.readOnly) && index<root.routePlan.stops.length-1; onClicked:{root.routePlan.moveStop(index,1);loadCheck.checked=false} }
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
        visible:!root.singlePoint && !!root.routePlan && root.routePlan.history.length>0
        text: {
            if(!root.routePlan || !root.routePlan.history.length)return ""
            var entry=root.routePlan.history[root.routePlan.history.length-1]
            return "Ultimul traseu: "+new Date(entry.finishedAt).toLocaleString()+" • "+entry.completedStops+"/"+entry.stopCount+" opriri • "+(entry.result==="DISPATCHED"?"acțiuni comandate":"oprit")
        }
    }
    CheckBox { id:loadCheck; visible:!!root.routePlan && root.routePlan.stops.some(function(s){return s.hopper!==0}); Layout.fillWidth:true; text:"Am încărcat/reîncărcat cuvele"; palette.windowText:"white"; enabled:!!root.routePlan && (!root.routePlan.active && !root.routePlan.readOnly) }
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
        width:Math.min(440,parent ? parent.width-24 : 440); height:Math.min(220,parent ? parent.height-24 : 220); modal:true; title:root.singlePoint ? "Confirmă destinația" : "Confirmă traseul"
        standardButtons:Dialog.Ok|Dialog.Cancel
        contentItem:Label { text:root.singlePoint ? "Barca va merge la destinație și va executa acțiunea aleasă. Verifică drumul liber și cuvele." : "Barca va parcurge opririle și va executa acțiunile cuvelor. Verifică traseul liber și încărcarea cuvelor."; wrapMode:Text.WordWrap; color:"white" }
        background:Rectangle{color:"#0b1c2e";radius:8;border.color:"#21b7ff"}
        onAccepted:{root.startRequested(loadCheck.checked);loadCheck.checked=false}
    }
}
