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
    property double clockMs:Date.now()
    property string entryTripId:""
    property int entryFilter:0
    readonly property var summary:tripSummary(selected)
    readonly property var visibleEntries: {
        var entries=selected && selected.entries && typeof selected.entries.length==="number" ? selected.entries : []
        return entryFilter===0 ? entries : entries.filter(function(entry){return entry && entry.type===["","catch","bait","note"][entryFilter]})
    }
    readonly property bool weightValid:!entryWeight.text.trim().length || (/^\d+(?:[.,]\d{1,3})?$/).test(entryWeight.text.trim()) && Number(entryWeight.text.replace(",","."))>0 && Number(entryWeight.text.replace(",","."))<=1000
    Timer {interval:60000;repeat:true;running:!!root.selected && !root.selected.endedAt;onTriggered:root.clockMs=Date.now()}
    function tripSummary(trip) {
        var result={catches:0,bait:0,notes:0,weighed:0,totalKg:0,maxKg:0,minutes:0}
        if(!trip || !trip.entries || typeof trip.entries.length!=="number")return result
        for(var i=0;i<trip.entries.length;i++){
            var entry=trip.entries[i]
            if(!entry)continue
            if(entry.type==="catch"){
                result.catches++
                if(typeof entry.weightKg==="number" && isFinite(entry.weightKg) && entry.weightKg>0 && entry.weightKg<=1000){result.weighed++;result.totalKg+=entry.weightKg;result.maxKg=Math.max(result.maxKg,entry.weightKg)}
            } else if(entry.type==="bait")result.bait++
            else if(entry.type==="note")result.notes++
        }
        var start=Date.parse(trip.startedAt),end=trip.endedAt ? Date.parse(trip.endedAt) : clockMs
        result.minutes=isFinite(start) && isFinite(end) ? Math.max(0,Math.floor((end-start)/60000)) : 0
        return result
    }
    function entryDetails(entry) {
        return (entry.species || "")+(typeof entry.weightKg==="number" && isFinite(entry.weightKg) && entry.weightKg>0 && entry.weightKg<=1000 ? " • "+entry.weightKg.toFixed(3)+" kg" : "")+(entry.bait ? " • Nadă: "+entry.bait : "")
    }
    property string pendingDeleteId: ""
    property string pendingEntryId: ""
    function findTrip(id) { for(var i=0;i<trips.length;i++)if(trips[i].id===id)return trips[i];return null }
    function findActive() { for(var i=0;i<trips.length;i++)if(!trips[i].endedAt)return trips[i];return null }
    function when(value) { return value ? new Date(value).toLocaleString(Qt.locale(),Locale.ShortFormat) : "" }
    function kind(value) { return value==="catch" ? "Captură" : value==="bait" ? "Nădire" : "Observație" }
    function beginEntry(entry) {
        if(!selected || (!entry && (replayMode || selected.endedAt || selected.lakeId!==lakeId)))return false
        entryTripId=selectedId
        editingId=entry ? entry.id : ""
        clockMs=Date.now()
        captured=({})
        if(!entry) {
            var v=vehicle,c=v ? v.coordinate : null
            var valid=!!v && !!v.vehicleLinkManager && !v.vehicleLinkManager.communicationLost && !!v.gps && !!v.gps.lock && Number(v.gps.lock.rawValue)>=3 && !!c && c.isValid
            captured={positionValid:valid,depth:depthM,temperature:waterTempC}
            if(valid){captured.lat=c.latitude;captured.lon=c.longitude}
        }
        entrySpecies.text=entry && entry.species ? entry.species : ""
        entryWeight.text=entry && typeof entry.weightKg==="number" ? String(entry.weightKg) : ""
        entryBait.text=entry && entry.bait ? entry.bait : ""
        entryText.text=entry ? entry.text : ""
        entryType.currentIndex=entry ? ["note","catch","bait"].indexOf(entry.type) : 0
        entryDialog.open();return true
    }
    function saveEntry() {
        if(!selected || selectedId!==entryTripId || (!editingId && (replayMode || selected.endedAt || selected.lakeId!==lakeId)) || (entryType.currentIndex===1 && !weightValid))return false
        var data=Object.assign({},captured,{id:editingId,text:entryText.text,type:["note","catch","bait"][entryType.currentIndex],
            species:entrySpecies.text,bait:entryBait.text,weightKg:entryWeight.text.trim().length ? Number(entryWeight.text.replace(",",".")) : null})
        if(!persistence.saveFishingEntry(selectedId,data))return false
        entryDialog.close();return true
    }
    Component.onCompleted: { if(activeTrip)selectedId=activeTrip.id;else if(trips.length)selectedId=trips[0].id }
    onLakeIdChanged: entryDialog.close()
    onReplayModeChanged: entryDialog.close()
    onSelectedIdChanged:entryDialog.close()
    ColumnLayout {
        anchors.fill: parent; spacing: 6
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
        Label {
            objectName:"journalSummary";Layout.fillWidth:true;visible:!!root.selected;color:"#67dfdc";font.pixelSize:12;wrapMode:Text.WordWrap
            text:Math.floor(root.summary.minutes/60)+" h "+root.summary.minutes%60+" min • "+root.summary.catches+" însemnări captură • "+root.summary.bait+" nădire • "+root.summary.notes+" observații\n"+
                root.summary.weighed+" cântărite • total "+root.summary.totalKg.toFixed(3)+" kg"+(root.summary.weighed ? " • maxim "+root.summary.maxKg.toFixed(3)+" kg" : "")
        }
        ComboBox {objectName:"journalEntryFilter";Layout.fillWidth:true;model:["Toate însemnările","Capturi","Nădire","Observații"];onCurrentIndexChanged:root.entryFilter=currentIndex}
        RowLayout {
            Layout.fillWidth:true
            Button { text:"+ Notă"; enabled:!!root.selected && !root.selected.endedAt && root.selected.lakeId===root.lakeId && !root.replayMode; onClicked:root.beginEntry(null) }
            Button { text:"Încheie"; enabled:!!root.selected && !root.selected.endedAt && !root.replayMode; onClicked:finishDialog.open() }
            ToolButton { text:"×"; Accessible.name:"Șterge partida"; enabled:!!root.selected; onClicked:{root.pendingDeleteId=root.selectedId;deleteDialog.open()} }
        }
        ListView {
            objectName:"journalEntries"; Layout.fillWidth:true; Layout.fillHeight:true; clip:true; spacing:6
            model:root.visibleEntries
            ScrollBar.vertical:ScrollBar {}
            delegate:Rectangle {
                required property var modelData
                width:ListView.view.width; height:entryColumn.implicitHeight+16; color:"#0b1a27";radius:8;border.color:"#31506a"
                ColumnLayout {
                    id:entryColumn; anchors.left:parent.left;anchors.right:parent.right;anchors.top:parent.top;anchors.margins:8;spacing:4
                    Label { Layout.fillWidth:true; color:"#21b7ff";text:root.kind(modelData.type)+" • "+root.when(modelData.createdAt);wrapMode:Text.WordWrap }
                    Label { Layout.fillWidth:true; color:"#e1eaf2";text:modelData.text;textFormat:Text.PlainText;wrapMode:Text.WrapAnywhere }
                    Label { Layout.fillWidth:true; color:"#bbcbd9";wrapMode:Text.WordWrap;text:(modelData.lat!==undefined ? Number(modelData.lat).toFixed(6)+", "+Number(modelData.lon).toFixed(6) : "GPS necunoscut")+(modelData.depth!==undefined ? " • "+Number(modelData.depth).toFixed(2)+" m" : "")+(modelData.temperature!==undefined ? " • "+Number(modelData.temperature).toFixed(1)+" °C" : "") }
                    Label {Layout.fillWidth:true;visible:text.length>0;color:"#67dfdc";wrapMode:Text.WordWrap;text:root.entryDetails(modelData);textFormat:Text.PlainText}
                    RowLayout {
                        Button { text:"Editează";onClicked:root.beginEntry(modelData) }
                        Button { text:"Șterge";onClicked:{root.pendingEntryId=modelData.id;root.pendingDeleteId=root.selectedId;deleteEntryDialog.open()} }
                    }
                }
            }
            Label { anchors.centerIn:parent;visible:parent.count===0;text:root.entryFilter ? "Nicio însemnare de acest tip" : "Nicio însemnare";color:"#bbcbd9" }
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
        id:entryDialog;objectName:"journalEntryEditor";parent:Overlay.overlay;anchors.centerIn:parent;width:Math.min(440,root.width);height:Math.min(420,root.height);modal:true;title:root.editingId ? "Editează însemnarea" : "Însemnare nouă";standardButtons:Dialog.NoButton
        contentItem:ScrollView {
            id:entryScroll;clip:true;contentWidth:availableWidth
            ColumnLayout {
                width:entryScroll.availableWidth;spacing:6
                ComboBox { id:entryType;objectName:"journalEntryType";Layout.fillWidth:true;model:["Observație","Captură","Nădire"] }
                TextField {id:entrySpecies;objectName:"journalSpecies";visible:entryType.currentIndex===1;Layout.fillWidth:true;maximumLength:80;placeholderText:"Specie (opțional)";Accessible.name:"Specia capturii"}
                RowLayout {
                    visible:entryType.currentIndex===1;Layout.fillWidth:true
                    TextField {id:entryWeight;objectName:"journalWeight";Layout.fillWidth:true;placeholderText:"Greutate (opțional)";inputMethodHints:Qt.ImhFormattedNumbersOnly;maximumLength:12;Accessible.name:"Greutatea capturii în kilograme"}
                    Label {text:"kg"}
                }
                Label {Layout.fillWidth:true;visible:entryType.currentIndex===1 && !root.weightValid;color:"#b83d28";wrapMode:Text.WordWrap;text:"Greutate mai mare de 0 și cel mult 1000 kg, cu maximum 3 zecimale. Lasă gol dacă nu ai cântărit."}
                TextField {id:entryBait;objectName:"journalBait";visible:entryType.currentIndex!==0;Layout.fillWidth:true;maximumLength:120;placeholderText:"Nadă / momeală (opțional)";Accessible.name:"Nada sau momeala folosită"}
                TextArea { id:entryText;objectName:"journalEntryText";Layout.fillWidth:true;Layout.preferredHeight:110;wrapMode:TextEdit.Wrap;placeholderText:"Observație despre captură sau nadă…";selectByMouse:true }
                Label { Layout.fillWidth:true;color:"#b83d28";wrapMode:Text.WordWrap;text:entryText.text.length+" / 1000"+(root.persistence && root.persistence.journalError ? " • "+root.persistence.journalError : "") }
            }
        }
        footer:DialogButtonBox {
            Button {objectName:"journalEntrySave";text:"Salvează";enabled:entryText.text.trim().length>0 && entryText.text.length<=1000 && (entryType.currentIndex!==1 || root.weightValid);onClicked:root.saveEntry()}
            Button {text:"Renunță";onClicked:entryDialog.close()}
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
