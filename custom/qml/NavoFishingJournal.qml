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
    function findTrip(id) { for(var i=0;i<trips.length;i++)if(trips[i].id===id)return trips[i];return null }
    function findActive() { for(var i=0;i<trips.length;i++)if(!trips[i].endedAt)return trips[i];return null }
    function when(value) { return value ? new Date(value).toLocaleString(Qt.locale(),Locale.ShortFormat) : "" }
    function kind(value) { return value==="catch" ? "Captură" : value==="bait" ? "Nădire" : "Observație" }
    function beginEntry(entry) {
        if(!selected || (!entry && (replayMode || selected.endedAt || selected.lakeId!==lakeId)))return false
        entryTripId=selectedId
        clockMs=Date.now()
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
        entrySpecies.text=entry && entry.species ? entry.species : ""
        entryWeight.text=entry && typeof entry.weightKg==="number" ? String(entry.weightKg) : ""
        entryBait.text=entry && entry.bait ? entry.bait : ""
        entryText.text=entry ? entry.text : ""
        entryType.currentIndex=entry ? ["note","catch","bait"].indexOf(entry.type) : 0
        entryDialog.open();return true
    }
    function saveEntry() {
        if(!selected || selectedId!==entryTripId || (!editingId && (replayMode || selected.endedAt || selected.lakeId!==lakeId)) || (entryType.currentIndex===1 && !weightValid))return false
        var finalText = baitPrefix && entryType.currentIndex===2 ? baitPrefix+" • Nadă folosită: "+baitDetails.text.trim() : entryText.text
        var data=Object.assign({},captured,{id:editingId,text:finalText,type:["note","catch","bait"][entryType.currentIndex],
            species:entrySpecies.text,bait:entryBait.text,weightKg:entryWeight.text.trim().length ? Number(entryWeight.text.replace(",",".")) : null})
        if(!persistence.saveFishingEntry(selectedId,data))return false
        entryDialog.close();return true
    }
    Component.onCompleted: { if(activeTrip)selectedId=activeTrip.id;else if(trips.length)selectedId=trips[0].id }
    onLakeIdChanged: entryDialog.close()
    onReplayModeChanged: entryDialog.close()
    onSelectedIdChanged: entryDialog.close()
    Timer {interval:60000;repeat:true;running:!!root.selected && !root.selected.endedAt;onTriggered:root.clockMs=Date.now()}
    readonly property color navoCyan: "#20d9ed"
    readonly property color navoText: "#eff9ff"
    readonly property color navoMuted: "#c1d7e6"
    property int journalTab: 0 // Partide, Însemnări, Statistici

    component JournalButton: Button {
        id: btn
        property color tint: "#20d9ed"
        implicitHeight: 35
        padding: 7
        font.pixelSize: 12
        font.bold: true
        background: Rectangle {
            radius: 8
            color: btn.down ? "#16475c" : (btn.hovered ? "#103247" : "#082236")
            border.color: btn.enabled ? btn.tint : "#506779"
            border.width: 1
        }
        contentItem: Label {
            text: btn.text
            font: btn.font
            color: btn.enabled ? "#eff9ff" : "#b7c3cf"
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }
    component JournalTab: Button {
        id: tab
        property int target: 0
        implicitHeight: 38
        implicitWidth: 128
        font.pixelSize: 12
        font.bold: root.journalTab === target
        onClicked: root.journalTab = target
        background: Rectangle {
            radius: 9
            color: root.journalTab === tab.target ? "#10394d" : "#071e30"
            border.width: root.journalTab === tab.target ? 2 : 1
            border.color: root.journalTab === tab.target ? "#20d9ed" : "#26718b"
        }
        contentItem: Label {
            text: tab.text; font: tab.font
            color: "#eff9ff"
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }
    Rectangle { anchors.fill: parent; color: "#051521"; radius: 10; border.color: "#174c68" }
    ScrollView {
        id: journalScroll
        anchors.fill: parent
        anchors.margins: 8
        contentWidth: availableWidth
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: ScrollBar.AsNeeded
        ColumnLayout {
            width: journalScroll.availableWidth
            spacing: 9

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: headingContent.implicitHeight + 16
                color: "#071e30"
                radius: 10
                border.color: "#20d9ed"
                ColumnLayout {
                    id: headingContent
                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                    anchors.margins: 8
                    spacing: 5
                    RowLayout {
                        Layout.fillWidth: true
                        Label { text: "◷"; color: "#20d9ed"; font.pixelSize: 20 }
                        Label { text: "JURNAL DE PARTIDĂ"; color: "#eff9ff"; font.bold: true; font.pixelSize: 18; Layout.fillWidth: true; elide: Text.ElideRight }
                        JournalButton {
                            text: "+ Partidă"
                            tint: "#37e9a2"
                            enabled: !!root.persistence && !root.activeTrip && !!root.lakeId && !root.replayMode
                            onClicked: { tripTitle.text = root.lakeName; startDialog.open() }
                        }
                    }
                    Label {
                        Layout.fillWidth: true
                        text: root.activeTrip ? "● ACTIVĂ • " + root.activeTrip.title + " • " + root.activeTrip.lakeName
                            : (root.lakeId ? "Fără partidă activă • selectează sau creează una" : "Selectează mai întâi o baltă")
                        color: root.activeTrip ? "#37e9a2" : "#c1d7e6"
                        wrapMode: Text.WordWrap
                        font.pixelSize: 11
                    }
                    Label {
                        visible: !!root.persistence && !!root.persistence.journalError
                        Layout.fillWidth: true
                        text: root.persistence ? root.persistence.journalError : ""
                        color: "#ffb0b8"; font.pixelSize: 12; wrapMode: Text.WordWrap
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 49
                radius: 9; color: "#071e30"; border.color: "#19546b"
                Flickable {
                    anchors.fill: parent; anchors.margins: 5
                    contentWidth: journalTabs.implicitWidth; contentHeight: height
                    clip: true; boundsBehavior: Flickable.StopAtBounds
                    Row {
                        id: journalTabs
                        height: parent.height; spacing: 7
                        JournalTab { text: "Partide"; target: 0 }
                        JournalTab { text: "Însemnări"; target: 1 }
                        JournalTab { text: "Statistici"; target: 2 }
                    }
                }
            }

            Rectangle {
                visible: root.journalTab === 0
                Layout.fillWidth: true
                implicitHeight: tripContent.implicitHeight + 20
                color: "#061827"; radius: 10; border.color: "#20d9ed"
                ColumnLayout {
                    id: tripContent
                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                    anchors.margins: 10
                    spacing: 9
                    RowLayout {
                        Layout.fillWidth: true
                        Label { text: "Partide salvate"; color: "#eff9ff"; font.pixelSize: 15; font.bold: true; Layout.fillWidth: true }
                        JournalButton {
                            text: "Partida activă"
                            enabled: !!root.activeTrip
                            onClicked: root.selectedId = root.activeTrip.id
                        }
                    }
                    Rectangle { Layout.fillWidth: true; height: 1; color: "#19546b" }
                    Label { text: "Alege partida"; color: "#c1d7e6"; font.pixelSize: 11 }
                    ComboBox {
                        id: journalTrips
                        objectName: "journalTrips"
                        Layout.fillWidth: true
                        implicitHeight: 39
                        model: root.trips; textRole: "title"
                        displayText: root.selected ? root.selected.title + " • " + root.selected.lakeName : "Alege partida"
                        onActivated: root.selectedId = root.trips[currentIndex].id
                        contentItem: Label {
                            text: journalTrips.displayText
                            color: "#eff9ff"; font.pixelSize: 13
                            leftPadding: 10; rightPadding: 27
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle { color: "#0a293e"; border.color: "#54869d"; radius: 8 }
                    }
                    Label {
                        Layout.fillWidth: true; visible: !!root.selected
                        text: root.selected ? root.when(root.selected.startedAt) +
                              (root.selected.endedAt ? " → " + root.when(root.selected.endedAt) : " • ACTIVĂ") : ""
                        color: "#c1d7e6"; font.pixelSize: 12; wrapMode: Text.WordWrap
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        JournalButton {
                            text: "Deschide însemnările"
                            enabled: !!root.selected
                            onClicked: root.journalTab = 1
                        }
                        JournalButton {
                            text: "Încheie"
                            tint: "#ffd166"
                            enabled: !!root.selected && !root.selected.endedAt && !root.replayMode
                            onClicked: finishDialog.open()
                        }
                        Item { Layout.fillWidth: true }
                        JournalButton {
                            text: "Șterge"
                            tint: "#ff8793"
                            Accessible.name: "Șterge partida"
                            enabled: !!root.selected
                            onClicked: { root.pendingDeleteId = root.selectedId; deleteDialog.open() }
                        }
                    }
                }
            }

            Rectangle {
                visible: root.journalTab === 1
                Layout.fillWidth: true
                implicitHeight: notesContent.implicitHeight + 18
                color: "#061827"; radius: 10; border.color: "#20d9ed"
                ColumnLayout {
                    id: notesContent
                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                    anchors.margins: 9
                    spacing: 8
                    RowLayout {
                        Layout.fillWidth: true
                        Label { text: "Capturi • Nădiri • Observații"; color: "#eff9ff"; font.bold: true; font.pixelSize: 14; Layout.fillWidth: true; elide: Text.ElideRight }
                        JournalButton {
                            text: "+ Însemnare"
                            tint: "#37e9a2"
                            enabled: !!root.selected && !root.selected.endedAt && root.selected.lakeId===root.lakeId && !root.replayMode
                            onClicked: root.beginEntry(null)
                        }
                    }
                    Rectangle { Layout.fillWidth: true; height: 1; color: "#19546b" }
                    ComboBox {
                        id: journalEntryFilter
                        objectName: "journalEntryFilter"
                        Layout.fillWidth: true
                        implicitHeight: 36
                        model: ["Toate însemnările", "Capturi", "Nădire", "Observații"]
                        onCurrentIndexChanged: root.entryFilter = currentIndex
                        contentItem: Label {
                            text: journalEntryFilter.displayText; color: "#eff9ff"
                            leftPadding: 10; rightPadding: 29
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle { color: "#0a293e"; border.color: "#54869d"; radius: 8 }
                    }
                    ListView {
                        objectName: "journalEntries"
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.max(190, contentHeight)
                        clip: true; interactive: false; spacing: 7
                        model: root.visibleEntries
                        delegate: Rectangle {
                            required property var modelData
                            width: ListView.view.width
                            height: entryColumn.implicitHeight + 17
                            radius: 9
                            color: "#092334"
                            border.color: "#2a7892"
                            ColumnLayout {
                                id: entryColumn
                                anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                                anchors.margins: 8; spacing: 5
                                Label { Layout.fillWidth: true; text: root.kind(modelData.type)+" • "+root.when(modelData.createdAt); color: "#20d9ed"; font.bold: true; wrapMode: Text.WordWrap }
                                Rectangle { Layout.fillWidth: true; height: 1; color: "#19546b" }
                                Label { Layout.fillWidth: true; text: modelData.text; textFormat: Text.PlainText; color: "#eff9ff"; wrapMode: Text.WrapAnywhere }
                                Label {
                                    Layout.fillWidth: true
                                    text: (modelData.lat!==undefined ? Number(modelData.lat).toFixed(6)+", "+Number(modelData.lon).toFixed(6) : "GPS necunoscut")
                                         +(modelData.depth!==undefined ? " • "+Number(modelData.depth).toFixed(2)+" m" : "")
                                         +(modelData.temperature!==undefined ? " • "+Number(modelData.temperature).toFixed(1)+" °C" : "")
                                    color: "#c1d7e6"; font.pixelSize: 11; wrapMode: Text.WordWrap
                                }
                                Label { Layout.fillWidth: true; visible: text.length>0; text: root.entryDetails(modelData); textFormat: Text.PlainText; color: "#79eff0"; wrapMode: Text.WordWrap; font.pixelSize: 11 }
                                RowLayout {
                                    Layout.fillWidth: true
                                    JournalButton { text: "Editează"; onClicked: root.beginEntry(modelData) }
                                    JournalButton {
                                        text: "Șterge"
                                        tint: "#ff8793"
                                        onClicked: { root.pendingEntryId=modelData.id; root.pendingDeleteId=root.selectedId; deleteEntryDialog.open() }
                                    }
                                    Item { Layout.fillWidth: true }
                                }
                            }
                        }
                        Label {
                            anchors.centerIn: parent
                            visible: parent.count === 0
                            text: root.entryFilter ? "Nicio însemnare de acest tip" : "Nicio însemnare"
                            color: "#c1d7e6"; font.pixelSize: 12
                        }
                    }
                }
            }

            Rectangle {
                visible: root.journalTab === 2
                Layout.fillWidth: true
                implicitHeight: statsContent.implicitHeight + 20
                radius: 10; color: "#061827"; border.color: "#20d9ed"
                ColumnLayout {
                    id: statsContent
                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                    anchors.margins: 10; spacing: 9
                    Label { text: "Rezumat partidă"; color: "#eff9ff"; font.pixelSize: 16; font.bold: true }
                    Rectangle { Layout.fillWidth: true; height: 1; color: "#19546b" }
                    Label {
                        objectName: "journalSummary"
                        Layout.fillWidth: true
                        text: Math.floor(root.summary.minutes/60)+" h "+root.summary.minutes%60+" min • "+root.summary.catches+" capturi • "+root.summary.bait+" nădiri • "+root.summary.notes+" observații\n"+root.summary.weighed+" cântărite • total "+root.summary.totalKg.toFixed(3)+" kg"+(root.summary.weighed ? " • maxim "+root.summary.maxKg.toFixed(3)+" kg" : "")
                        color: "#79eff0"; font.pixelSize: 13; wrapMode: Text.WordWrap
                    }
                    Label {
                        Layout.fillWidth: true; color: "#c1d7e6"; font.pixelSize: 11; wrapMode: Text.WordWrap
                        text: "Statistici calculate din însemnările reale ale partidei selectate. Greutățile lipsă nu sunt estimate."
                    }
                }
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
                Label {visible:root.baitPrefix.length>0 && entryType.currentIndex===2;Layout.fillWidth:true;wrapMode:Text.WordWrap;text:root.baitPrefix;color:"#bbcbd9"}
                TextField {id:baitDetails;visible:root.baitPrefix.length>0 && entryType.currentIndex===2;Layout.fillWidth:true;placeholderText:"Tip nadă și cantitate (ex.: boilies 500 g)"}
                TextArea {id:entryText;objectName:"journalEntryText";visible:!(root.baitPrefix.length>0 && entryType.currentIndex===2);Layout.fillWidth:true;Layout.preferredHeight:110;wrapMode:TextEdit.Wrap;placeholderText:"Observație despre captură sau nadă…";selectByMouse:true}
                Label {Layout.fillWidth:true;color:"#b83d28";wrapMode:Text.WordWrap;text:entryText.text.length+" / 1000"+(root.persistence && root.persistence.journalError ? " • "+root.persistence.journalError : "")}
            }
        }
        footer:DialogButtonBox {
            Button {objectName:"journalEntrySave";text:"Salvează";enabled:(root.baitPrefix.length>0 && entryType.currentIndex===2 ? baitDetails.text.trim().length>0 && (root.baitPrefix.length+baitDetails.text.length+18)<=1000 : entryText.text.trim().length>0 && entryText.text.length<=1000) && (entryType.currentIndex!==1 || root.weightValid);onClicked:root.saveEntry()}
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
