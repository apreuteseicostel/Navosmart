import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Popup {
    id: root
    property var persistence
    property var scanCoordinator
    property string selectedLakeId: ""
    property var selectedLake: null
    property string saveStatus: ""
    property var editLake: null
    component LakeIconButton: Button { width:42; height:38; padding:0; property string hint:""; ToolTip.visible:hovered; ToolTip.text:hint; background:Rectangle{radius:7;color:parent.down?"#18354a":"#101b25";border.color:parent.enabled?"#31506a":"#26313a"} }

    modal: true
    focus: true
    width: Math.min(620, parent ? parent.width - 24 : 620)
    height: Math.min(650, parent ? parent.height - 24 : 650)
    anchors.centerIn: parent
    background: Rectangle { color: "#081522"; border.color: "#1c4262"; radius: 12 }

    function sessionsForLake(id) {
        var out=[]
        if(!persistence) return out
        for(var i=0;i<persistence.bathymetrySessions.length;i++) {
            var s=persistence.bathymetrySessions[i]
            if(s.lakeId===id) out.push(s)
        }
        return out
    }
    function selectLake(lake) {
        if(!lake || !scanCoordinator || !scanCoordinator.activateLake(lake.id,lake.name)) {
            saveStatus="Schimbarea bălții nu a fost permisă"
            return false
        }
        selectedLake=lake
        selectedLakeId=lake.id
        return true
    }
    function refreshSelected(id) {
        if(!persistence) return
        for(var i=0;i<persistence.lakes.length;i++) {
            if(persistence.lakes[i].id===id) {
                selectedLake=persistence.lakes[i]
                selectedLakeId=id
                return
            }
        }
        selectedLake=null
        selectedLakeId=""
    }
    function addLake() {
        var name=newLakeName.text.trim()
        if(!name.length || !persistence) {
            saveStatus="Introdu numele bălții înainte de salvare"
            return
        }
        var id=persistence.saveLake({name:name})
        if(!id) {
            saveStatus="Salvarea bălții a eșuat"
            return
        }
        for(var i=0;i<persistence.lakes.length;i++)
            if(persistence.lakes[i].id===id) { selectLake(persistence.lakes[i]); break }
        if(scanCoordinator) scanCoordinator.checkpoint("lake-created")
        newLakeName.clear()
        saveStatus="Baltă salvată: "+name
    }
    function beginRename(lake) {
        if(!lake) return
        editLake=lake
        renameField.text=lake.name||""
        renameDialog.open()
    }
    function beginDelete(lake) {
        if(!lake) return
        editLake=lake
        deleteDialog.open()
    }
    function renameCurrentLake() {
        if(!editLake || !scanCoordinator) return
        var name=renameField.text.trim()
        if(scanCoordinator.renameLake(editLake.id,name)) {
            refreshSelected(editLake.id)
            saveStatus="Nume nou salvat: "+name
            renameDialog.close()
        } else saveStatus="Redenumirea nu a fost salvată"
    }
    function deleteCurrentLake() {
        if(!editLake || !scanCoordinator) return
        var id=editLake.id
        var name=editLake.name||"Baltă"
        if(scanCoordinator.deleteLake(id)) {
            if(selectedLakeId===id) { selectedLake=null; selectedLakeId="" }
            saveStatus="Ștearsă: "+name
            deleteDialog.close()
        } else saveStatus="Ștergerea nu este permisă acum"
    }

    signal openSession(var session)
    signal lakeRestored(string lakeId)
    signal openLakeMap(string lakeId)
    signal openLakeBathymetry(string lakeId)
    signal openLakeFishingSpots(string lakeId)
    signal resumeLakeScan(string lakeId)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            Label { text: "BĂLȚILE MELE"; color: "#21b7ff"; font.bold: true; font.pixelSize: 20 }
            Item { Layout.fillWidth: true }
            LakeIconButton { hint:"Închide"; contentItem:Label{text:"X";color:"#f2f7fb";font.bold:true;horizontalAlignment:Text.AlignHCenter;verticalAlignment:Text.AlignVCenter}; onClicked:root.close() }
        }

        RowLayout {
            Layout.fillWidth: true
            TextField { palette.text:"#0b1118"; palette.base:"#ffffff"; palette.placeholderText:"#5f6b76"; palette.highlight:"#21b7ff"; palette.highlightedText:"#ffffff";
                id: newLakeName
                Layout.fillWidth: true
                placeholderText: "Nume baltă / lac"
                onAccepted: root.addLake()
            }
            LakeIconButton { hint:"Adaugă baltă"; enabled:newLakeName.text.trim().length>0; contentItem:Label{text:"+";color:"#21b7ff";font.pixelSize:28;font.bold:true;horizontalAlignment:Text.AlignHCenter;verticalAlignment:Text.AlignVCenter}; onClicked:root.addLake() }
        }

        Label {
            Layout.fillWidth: true
            visible: root.saveStatus.length>0
            text: root.saveStatus
            color: "#31d67b"
            wrapMode: Text.WordWrap
        }

        SplitView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            orientation: root.width<560 ? Qt.Vertical : Qt.Horizontal
            handle: Rectangle { implicitWidth: 4; implicitHeight: 4; color: "#1c4262" }

            ListView {
                SplitView.preferredWidth: Math.min(250, root.width*.42)
                SplitView.preferredHeight: root.width<560 ? 180 : root.height-130
                clip: true
                spacing: 5
                model: root.persistence ? root.persistence.lakes : []
                delegate: Rectangle {
                    required property var modelData
                    width: ListView.view.width
                    height: 46
                    radius: 7
                    color: root.selectedLakeId===modelData.id ? "#153552" : "#0d2235"
                    border.color: root.selectedLakeId===modelData.id ? "#21b7ff" : "#1c4262"
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 4
                        spacing: 4
                        Button {
                            Layout.fillWidth: true
                            text: modelData.name||"Baltă"
                            flat: true
                            onClicked: root.selectLake(modelData)
                        }
                        Button {
                            Layout.preferredWidth: 38; Layout.preferredHeight: 38
                            text: ""
                            ToolTip.visible: hovered; ToolTip.text: "Redenumește"
                            contentItem: Item {
                                Canvas {
                                    anchors.centerIn: parent; width: 20; height: 20
                                    onPaint: {
                                        var p=getContext("2d"); p.reset(); p.strokeStyle="#f2f7fb"; p.fillStyle="#f2f7fb"; p.lineWidth=2.2; p.lineCap="round"; p.lineJoin="round"
                                        p.beginPath(); p.moveTo(4,15); p.lineTo(5.5,11); p.lineTo(13.5,3); p.lineTo(17,6.5); p.lineTo(9,14.5); p.closePath(); p.stroke()
                                        p.beginPath(); p.moveTo(4,16.5); p.lineTo(9,15); p.stroke()
                                    }
                                }
                            }
                            onClicked: root.beginRename(modelData)
                        }
                        Button {
                            Layout.preferredWidth: 38; Layout.preferredHeight: 38
                            text: ""
                            ToolTip.visible: hovered; ToolTip.text: "Șterge"
                            contentItem: Item {
                                Canvas {
                                    anchors.centerIn: parent; width: 20; height: 20
                                    onPaint: {
                                        var p=getContext("2d"); p.reset(); p.strokeStyle="#ff6b6b"; p.lineWidth=2; p.lineCap="round"; p.lineJoin="round"
                                        p.beginPath(); p.moveTo(4,6); p.lineTo(16,6); p.moveTo(8,3.5); p.lineTo(12,3.5); p.lineTo(13,6); p.moveTo(6,7); p.lineTo(7,17); p.lineTo(13,17); p.lineTo(14,7); p.stroke()
                                        p.beginPath(); p.moveTo(9,9); p.lineTo(9,14); p.moveTo(12,9); p.lineTo(12,14); p.stroke()
                                    }
                                }
                            }
                            onClicked: root.beginDelete(modelData)
                        }
                    }
                }
            }

            ColumnLayout {
                SplitView.fillWidth: true
                RowLayout {
                    Layout.fillWidth: true
                    Label {
                        Layout.fillWidth: true
                        text: root.selectedLake ? (root.selectedLake.name||"Baltă") : "Selectează o baltă"
                        color: "#f2f7fb"
                        font.bold: true
                        font.pixelSize: 18
                        elide: Text.ElideRight
                    }
                    LakeIconButton { visible:!!root.selectedLake; hint:"Redenumește balta"; contentItem:Canvas{anchors.fill:parent;onPaint:{var p=getContext("2d");p.reset();p.strokeStyle="#f2f7fb";p.lineWidth=2;p.beginPath();p.moveTo(11,29);p.lineTo(14,21);p.lineTo(28,7);p.lineTo(34,13);p.lineTo(20,27);p.closePath();p.stroke()}};onClicked:root.beginRename(root.selectedLake) }
                    LakeIconButton { visible:!!root.selectedLake; hint:"Șterge balta"; contentItem:Canvas{anchors.fill:parent;onPaint:{var p=getContext("2d");p.reset();p.strokeStyle="#ff6b6b";p.lineWidth=2;p.beginPath();p.moveTo(10,11);p.lineTo(32,11);p.moveTo(15,8);p.lineTo(27,8);p.moveTo(13,14);p.lineTo(15,32);p.lineTo(27,32);p.lineTo(29,14);p.stroke()}};onClicked:root.beginDelete(root.selectedLake) }
                }
                Label {
                    visible: !!root.selectedLake
                    text: {
                        if(!root.selectedLake || !root.persistence) return ""
                        var st=root.persistence.lakeState(root.selectedLakeId)||({})
                        var samples=(st.sonarSamples||[]).length
                        var spots=(st.fishingSpots||[]).length
                        var fish=(st.fishDetections||[]).length
                        var done=(st.completedLanes||[]).length
                        var total=Number(st.totalLanes||0)
                        var pct=total>0 ? Math.round(done*100/total) : 0
                        return samples+" sonar • "+spots+" puncte pescuit • "+fish+" pești • Area Scan "+pct+"%"
                    }
                    color: "#9db2c5"
                    wrapMode: Text.WordWrap
                }
                GridLayout {
                    Layout.fillWidth: true
                    visible: !!root.selectedLake
                    columns: root.width < 560 ? 2 : 3
                    columnSpacing: 6; rowSpacing: 6
                    Button {
                        text: "HARTĂ"; ToolTip.visible:hovered; ToolTip.text:"Deschide harta"; Layout.fillWidth:true
                        onClicked: {
                            if(root.scanCoordinator && root.scanCoordinator.restoreLake(root.selectedLakeId)) {
                                root.lakeRestored(root.selectedLakeId); root.openLakeMap(root.selectedLakeId); root.close()
                            }
                        }
                    }
                    Button {
                        text: "3D"; ToolTip.visible:hovered; ToolTip.text:"Deschide harta 3D"; Layout.fillWidth:true
                        onClicked: {
                            if(root.scanCoordinator && root.scanCoordinator.restoreLake(root.selectedLakeId)) {
                                root.lakeRestored(root.selectedLakeId); root.openLakeBathymetry(root.selectedLakeId); root.close()
                            }
                        }
                    }
                    Button {
                        text: "PIN"; ToolTip.visible:hovered; ToolTip.text:"Puncte de pescuit"; Layout.fillWidth:true
                        onClicked: {
                            if(root.scanCoordinator && root.scanCoordinator.restoreLake(root.selectedLakeId)) {
                                root.lakeRestored(root.selectedLakeId); root.openLakeFishingSpots(root.selectedLakeId); root.close()
                            }
                        }
                    }
                    Button {
                        text: "SCAN"; ToolTip.visible:hovered; ToolTip.text:"Continuă Area Scan"; Layout.fillWidth:true
                        enabled: {
                            if(!root.persistence || !root.selectedLake) return false
                            var st=root.persistence.lakeState(root.selectedLakeId)||({})
                            return Number(st.totalLanes||0)>0 && (st.completedLanes||[]).length<Number(st.totalLanes||0)
                        }
                        onClicked: {
                            if(root.scanCoordinator && root.scanCoordinator.restoreLake(root.selectedLakeId)) {
                                root.lakeRestored(root.selectedLakeId); root.resumeLakeScan(root.selectedLakeId); root.close()
                            }
                        }
                    }
                }
                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: root.selectedLake ? root.sessionsForLake(root.selectedLakeId) : []
                    delegate: Rectangle {
                        required property var modelData
                        width: ListView.view.width
                        height: 82
                        radius: 8
                        color: "#0d2235"
                        border.color: "#1c4262"
                        Column {
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            Label { text: modelData.name||"Scanare"; color: "#f2f7fb"; font.bold: true }
                            Label {
                                text: (modelData.sampleCount||0)+" puncte • "+Number(modelData.minDepthM||0).toFixed(1)+"–"+Number(modelData.maxDepthM||0).toFixed(1)+" m"
                                color: "#9db2c5"
                            }
                        }
                        Button {
                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text:"3D"; width:42; ToolTip.visible:hovered; ToolTip.text:"Deschide scanarea 3D"
                            onClicked:root.openSession(modelData)
                        }
                    }
                }
                RowLayout {
                    Layout.fillWidth:true; visible:!!root.selectedLake
                    LakeIconButton { hint:"Încarcă toate datele salvate"; contentItem:Canvas{anchors.fill:parent;onPaint:{var p=getContext("2d");p.reset();p.strokeStyle="#31d67b";p.lineWidth=2;p.beginPath();p.moveTo(21,7);p.lineTo(21,27);p.moveTo(13,20);p.lineTo(21,28);p.lineTo(29,20);p.moveTo(10,33);p.lineTo(32,33);p.stroke()}};onClicked:{if(root.scanCoordinator&&root.scanCoordinator.restoreLake(root.selectedLakeId)){root.lakeRestored(root.selectedLakeId);root.close()}} }
                    Item { Layout.fillWidth:true }
                    Label { text:"Sonar • puncte • Area Scan"; color:"#31d67b" }
                }
            }
        }
    }

    Dialog {
        id: renameDialog
        parent: Overlay.overlay
        anchors.centerIn: parent
        modal: true
        title: "Redenumește balta"
        standardButtons: Dialog.Save | Dialog.Cancel
        TextField { palette.text:"#0b1118"; palette.base:"#ffffff"; palette.placeholderText:"#5f6b76"; palette.highlight:"#21b7ff"; palette.highlightedText:"#ffffff";
            id: renameField
            width: Math.min(320, parent ? parent.width-40 : 320)
            placeholderText: "Nume baltă"
            selectByMouse: true
        }
        onAccepted: root.renameCurrentLake()
    }

    Dialog {
        id: deleteDialog
        parent: Overlay.overlay
        anchors.centerIn: parent
        modal: true
        title: "Șterge balta?"
        standardButtons: Dialog.Yes | Dialog.No
        closePolicy: Popup.NoAutoClose
        Label {
            width: Math.min(380, parent ? parent.width-40 : 380)
            wrapMode: Text.WordWrap
            text: "Se șterg «"+(root.editLake ? (root.editLake.name||"Baltă") : "Baltă")+"» și datele ei salvate: batimetrie, sonar, puncte de pescuit și starea Area Scan. Operația nu poate fi anulată."
        }
        onAccepted: root.deleteCurrentLake()
    }
}
