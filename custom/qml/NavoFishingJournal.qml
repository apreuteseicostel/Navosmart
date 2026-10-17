import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    property var persistence
    property string lakeId: ""
    property string lakeName: ""
    property bool replayMode: false
    property var vehicle: null
    property real depthM: NaN
    property real waterTempC: NaN
    property string selectedId: ""
    readonly property var trips: persistence ? persistence.fishingTrips : []
    readonly property var selected: findTrip(selectedId)
    readonly property var activeTrip: findActive()
    property var captured: ({})
    property string editingId: ""
    property string pendingDeleteId: ""
    property string pendingEntryId: ""
    property string baitPrefix: ""
    function findTrip(id) { for(var i=0;i<trips.length;i++)if(trips[i].id===id)return trips[i];return null }
    function findActive() { for(var i=0;i<trips.length;i++)if(!trips[i].endedAt)return trips[i];return null }
    function when(value) { return value ? new Date(value).toLocaleString(Qt.locale(),Locale.ShortFormat) : "" }
    function kind(value) { return value==="catch" ? "Captură" : value==="bait" ? "Nădire" : "Observație" }
    function beginEntry(entry) {
        if(!selected || (!entry && (replayMode || selected.endedAt || selected.lakeId!==lakeId)))return false
        editingId=entry ? entry.id : ""
        captured=({})
        if(!entry) {
            var v=vehicle,c=v ? v.coordinate : null
            var valid=!!v && !!v.vehicleLinkManager && !v.vehicleLinkManager.communicationLost && !!v.gps && !!v.gps.lock && Number(v.gps.lock.rawValue)>=3 && !!c && c.isValid
            captured={positionValid:valid,depth:depthM,temperature:waterTempC}
            if(valid){captured.lat=c.latitude;captured.lon=c.longitude}
        }
        baitPrefix = entry && entry.type==="bait" && entry.text.indexOf(" • Nadă folosită:")>=0 ? entry.text.split(" • Nadă folosită:")[0] : ""
        baitDetails.text = baitPrefix ? entry.text.split(" • Nadă folosită:").slice(1).join(" • Nadă folosită:").trim().replace(/^de completat$/, "") : ""
        entryText.text=entry ? entry.text : ""
        entryType.currentIndex=entry ? ["note","catch","bait"].indexOf(entry.type) : 0
        entryDialog.open();return true
    }
    function saveEntry() {
        if(!selected || (!editingId && (replayMode || selected.lakeId!==lakeId)))return false
        var finalText = baitPrefix && entryType.currentIndex===2 ? baitPrefix+" • Nadă folosită: "+baitDetails.text.trim() : entryText.text
        var data=Object.assign({},captured,{id:editingId,text:finalText,type:["note","catch","bait"][entryType.currentIndex]})
        if(!persistence.saveFishingEntry(selectedId,data))return false
        entryDialog.close();return true
    }
    Component.onCompleted: { if(activeTrip)selectedId=activeTrip.id;else if(trips.length)selectedId=trips[0].id }
    onLakeIdChanged: entryDialog.close()
    onReplayModeChanged: entryDialog.close()
    ScrollView {
        anchors.fill: parent
        clip: true
        ScrollBar.vertical.policy: ScrollBar.AsNeeded
        ColumnLayout {
        width: Math.max(0, root.width - 18)
        spacing: 6
        Label { text:"JURNAL DE PARTIDĂ"; color:"#21b7ff"; font.bold:true }
        Label { Layout.fillWidth:true; wrapMode:Text.WordWrap; color:"#bbcbd9"; text:root.activeTrip ? "În desfășurare: "+root.activeTrip.title+" • "+root.activeTrip.lakeName : "Începe o partidă pe balta activă pentru capturi și observații." }
        RowLayout {
            Layout.fillWidth:true
            Button { text:"+ Partidă"; enabled:!!root.persistence && !root.activeTrip && !!root.lakeId && !root.replayMode; onClicked:{tripTitle.text=root.lakeName;startDialog.open()} }
            Button { text:"Partida activă"; enabled:!!root.activeTrip; Layout.fillWidth:true; onClicked:root.selectedId=root.activeTrip.id }
        }
        Label { Layout.fillWidth:true; visible:!!root.persistence && !!root.persistence.journalError; text:root.persistence ? root.persistence.journalError : ""; color:"#ff907e"; wrapMode:Text.WordWrap }
        ComboBox {
            objectName:"journalTrips"; Layout.fillWidth:true; model:root.trips; textRole:"title"
            displayText:root.selected ? root.selected.title+" • "+root.selected.lakeName : "Alege partida"
            onActivated:root.selectedId=root.trips[currentIndex].id
        }
        Label { Layout.fillWidth:true; visible:!!root.selected; color:"#bbcbd9"; wrapMode:Text.WordWrap; text:root.selected ? root.when(root.selected.startedAt)+(root.selected.endedAt ? " → "+root.when(root.selected.endedAt) : " • ACTIVĂ") : "" }
        RowLayout {
            Layout.fillWidth:true
            Button { text:"+ Notă"; enabled:!!root.selected && !root.selected.endedAt && root.selected.lakeId===root.lakeId && !root.replayMode; onClicked:root.beginEntry(null) }
            Button { text:"Încheie"; enabled:!!root.selected && !root.selected.endedAt && !root.replayMode; onClicked:finishDialog.open() }
            ToolButton { text:"×"; Accessible.name:"Șterge partida"; enabled:!!root.selected; onClicked:{root.pendingDeleteId=root.selectedId;deleteDialog.open()} }
        }
        ListView {
            objectName:"journalEntries"; Layout.fillWidth:true; Layout.preferredHeight: Math.max(220, contentHeight); interactive:false; clip:true; spacing:6
            model:root.selected ? root.selected.entries : []
            ScrollBar.vertical:ScrollBar {}
            delegate:Rectangle {
                required property var modelData
                width:ListView.view.width; height:entryColumn.implicitHeight+16; color:"#0b1a27";radius:8;border.color:"#31506a"
                ColumnLayout {
                    id:entryColumn; anchors.left:parent.left;anchors.right:parent.right;anchors.top:parent.top;anchors.margins:8;spacing:4
                    Label { Layout.fillWidth:true; color:"#21b7ff";text:root.kind(modelData.type)+" • "+root.when(modelData.createdAt);wrapMode:Text.WordWrap }
                    Label { Layout.fillWidth:true; color:"#e1eaf2";text:modelData.text;textFormat:Text.PlainText;wrapMode:Text.WrapAnywhere }
                    Label { Layout.fillWidth:true; color:"#bbcbd9";wrapMode:Text.WordWrap;text:(modelData.lat!==undefined ? Number(modelData.lat).toFixed(6)+", "+Number(modelData.lon).toFixed(6) : "GPS necunoscut")+(modelData.depth!==undefined ? " • "+Number(modelData.depth).toFixed(2)+" m" : "")+(modelData.temperature!==undefined ? " • "+Number(modelData.temperature).toFixed(1)+" °C" : "") }
                    RowLayout {
                        Button { text:"Editează";onClicked:root.beginEntry(modelData) }
                        Button { text:"Șterge";onClicked:{root.pendingEntryId=modelData.id;root.pendingDeleteId=root.selectedId;deleteEntryDialog.open()} }
                    }
                }
            }
            Label { anchors.centerIn:parent;visible:parent.count===0;text:"Nicio însemnare";color:"#bbcbd9" }
        }
        }
    }
    Dialog {
        id:startDialog; objectName:"journalStart"; parent:Overlay.overlay;anchors.centerIn:parent;width:Math.min(400,root.width);modal:true;title:"Partidă nouă";standardButtons:Dialog.Cancel
        contentItem:ColumnLayout {
            TextField { id:tripTitle;objectName:"journalTitle";Layout.fillWidth:true;maximumLength:120;placeholderText:"Titlu partidă" }
            Button { text:"Începe";enabled:tripTitle.text.trim().length>0 && !root.replayMode && !root.activeTrip;onClicked:{var id=root.persistence.startFishingTrip(root.lakeId,tripTitle.text);if(id){root.selectedId=id;startDialog.close()}} }
        }
    }
    Dialog {
        id:entryDialog;objectName:"journalEntryEditor";parent:Overlay.overlay;anchors.centerIn:parent;width:Math.min(440,root.width);height:Math.min(420,root.height);modal:true;title:root.editingId ? "Editează însemnarea" : "Însemnare nouă";standardButtons:Dialog.Cancel
        contentItem:ColumnLayout {
            ComboBox { id:entryType;objectName:"journalEntryType";Layout.fillWidth:true;model:["Observație","Captură","Nădire"] }
            Label { visible:root.baitPrefix.length>0 && entryType.currentIndex===2; Layout.fillWidth:true; wrapMode:Text.WordWrap; text:root.baitPrefix; color:"#bbcbd9" }
            TextField { id:baitDetails; visible:root.baitPrefix.length>0 && entryType.currentIndex===2; Layout.fillWidth:true; placeholderText:"Tip nadă și cantitate (ex.: boilies 500 g)" }
            ScrollView { visible:!(root.baitPrefix.length>0 && entryType.currentIndex===2); Layout.fillWidth:true;Layout.fillHeight:true;TextArea { id:entryText;objectName:"journalEntryText";wrapMode:TextEdit.Wrap;placeholderText:"Observație, specie/greutate sau nadă folosită…";selectByMouse:true } }
            Label { Layout.fillWidth:true;color:"#b83d28";wrapMode:Text.WordWrap;text:entryText.text.length+" / 1000"+(root.persistence && root.persistence.journalError ? " • "+root.persistence.journalError : "") }
            Button { text:"Salvează";enabled:root.baitPrefix.length>0 && entryType.currentIndex===2 ? baitDetails.text.trim().length>0 && (root.baitPrefix.length+baitDetails.text.length+18)<=1000 : entryText.text.trim().length>0 && entryText.text.length<=1000;onClicked:root.saveEntry() }
        }
    }
    Dialog {
        id:finishDialog;parent:Overlay.overlay;anchors.centerIn:parent;width:Math.min(360,root.width);modal:true;title:"Închei partida?";standardButtons:Dialog.Yes|Dialog.No
        onAccepted:if(root.selected)root.persistence.finishFishingTrip(root.selectedId)
    }
    Dialog {
        id:deleteDialog;parent:Overlay.overlay;anchors.centerIn:parent;width:Math.min(360,root.width);modal:true;title:"Ștergi partida și însemnările?";standardButtons:Dialog.Yes|Dialog.No
        onAccepted:if(root.persistence.deleteFishingTrip(root.pendingDeleteId))root.selectedId=""
    }
    Dialog {
        id:deleteEntryDialog;parent:Overlay.overlay;anchors.centerIn:parent;width:Math.min(360,root.width);modal:true;title:"Ștergi însemnarea?";standardButtons:Dialog.Yes|Dialog.No
        onAccepted:root.persistence.deleteFishingEntry(root.pendingDeleteId,root.pendingEntryId)
    }
}
