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
    property int lakesTab: 0 // Prezentare, Sesiuni, Acțiuni
    component LakeIconButton: Button {
        id: iconButton
        width: 36; height: 35; padding: 0
        property string hint: ""
        ToolTip.visible: hovered; ToolTip.text: hint
        Accessible.name: hint
        background: Rectangle {
            radius: 8
            color: iconButton.down ? "#17485d" : (iconButton.hovered ? "#10374a" : "#08283a")
            border.color: iconButton.enabled ? "#20d9ed" : "#506778"
        }
    }
    component LakeAction: Button {
        id: action
        property color tint: "#20d9ed"
        implicitHeight: 35
        padding: 7
        font.pixelSize: 12
        font.bold: true
        background: Rectangle {
            radius: 8
            color: action.down ? "#17485d" : (action.hovered ? "#10374a" : "#08283a")
            border.color: action.enabled ? action.tint : "#506778"
        }
        contentItem: Label {
            text: action.text; font: action.font
            color: action.enabled ? "#eff9ff" : "#b7c3cf"
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
    }
    component LakeTab: Button {
        id: tab
        property int target: 0
        implicitHeight: 36; implicitWidth: 120
        onClicked: root.lakesTab = target
        background: Rectangle {
            radius: 8
            color: root.lakesTab === tab.target ? "#10394d" : "#071e30"
            border.color: root.lakesTab === tab.target ? "#20d9ed" : "#26718b"
            border.width: root.lakesTab === tab.target ? 2 : 1
        }
        contentItem: Label {
            text: tab.text; color: "#eff9ff"
            font.pixelSize: 12; font.bold: root.lakesTab===tab.target
            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
        }
    }

    modal: true
    focus: true
    width: Math.min(960, parent ? parent.width - 18 : 960)
    height: Math.min(630, parent ? parent.height - 18 : 630)
    anchors.centerIn: parent
    background: Rectangle { color: "#051521"; border.color: "#20d9ed"; border.width: 1.4; radius: 13 }

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

    function restoreAndOpen(destination) {
        if (!selectedLakeId || !scanCoordinator || !scanCoordinator.restoreLake(selectedLakeId)) {
            saveStatus = "Datele bălții nu pot fi încărcate acum"
            return false
        }
        lakeRestored(selectedLakeId)
        if (destination === "map") openLakeMap(selectedLakeId)
        else if (destination === "3d") openLakeBathymetry(selectedLakeId)
        else if (destination === "spots") openLakeFishingSpots(selectedLakeId)
        else if (destination === "resume") resumeLakeScan(selectedLakeId)
        close()
        return true
    }
    function lakeStats() {
        if(!selectedLake || !persistence) return {samples:0, spots:0, fish:0, done:0, total:0, percent:0}
        var state=persistence.lakeState(selectedLakeId)||({})
        var samples=(state.sonarSamples||[]).length
        var spots=(state.fishingSpots||[]).length
        var fish=(state.fishDetections||[]).length
        var done=(state.completedLanes||[]).length
        var total=Number(state.totalLanes||0)
        return {samples:samples, spots:spots, fish:fish, done:done, total:total,
                percent:total>0 ? Math.round(100*done/total) : 0}
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 11
        spacing: 9
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 47
            color: "#071e30"; border.color: "#20d9ed"; radius: 10
            RowLayout {
                anchors.fill: parent; anchors.margins: 8
                spacing: 9
                Image { source: "qrc:/qml/NavoSmart/icons/lake.svg"; Layout.preferredWidth: 25; Layout.preferredHeight: 25 }
                Label { text: "BĂLȚILE MELE"; color: "#eff9ff"; font.bold: true; font.pixelSize: 19; Layout.fillWidth: true }
                LakeIconButton {
                    hint: "Închide"
                    contentItem: Label { anchors.centerIn: parent; text: "✕"; font.pixelSize: 19; color: "#20d9ed" }
                    onClicked: root.close()
                }
            }
        }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 53
            radius: 9; color: "#061827"; border.color: "#19546b"
            RowLayout {
                anchors.fill: parent; anchors.margins: 7
                spacing: 8
                TextField {
                    id: newLakeName
                    Layout.fillWidth: true
                    implicitHeight: 37
                    color: "#eff9ff"; placeholderTextColor: "#a7c1d3"
                    selectByMouse: true
                    placeholderText: "Nume baltă / lac"
                    onAccepted: root.addLake()
                    background: Rectangle {
                        color: "#092439"; radius: 8
                        border.color: newLakeName.activeFocus ? "#20d9ed" : "#54869d"
                    }
                }
                LakeAction {
                    text: "+ Salvează balta"
                    tint: "#37e9a2"
                    enabled: newLakeName.text.trim().length>0
                    onClicked: root.addLake()
                }
            }
        }
        Label {
            Layout.fillWidth: true
            visible: root.saveStatus.length>0
            text: root.saveStatus; textFormat: Text.PlainText
            color: "#9be9e2"; wrapMode: Text.WordWrap; font.pixelSize: 11
        }
        SplitView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            orientation: root.width < 600 ? Qt.Vertical : Qt.Horizontal
            handle: Rectangle { implicitWidth: 6; implicitHeight: 6; color: "#103b4f" }

            Rectangle {
                SplitView.preferredWidth: Math.min(270, root.width*.32)
                SplitView.minimumWidth: 170
                SplitView.preferredHeight: root.width < 600 ? 175 : root.height - 170
                color: "#061827"; border.color: "#20d9ed"; radius: 10
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 8; spacing: 7
                    RowLayout {
                        Layout.fillWidth: true
                        Label { text: "Bălți salvate"; color: "#eff9ff"; font.bold: true; font.pixelSize: 14; Layout.fillWidth: true }
                        Label { text: root.persistence ? String(root.persistence.lakes.length) : "0"; color: "#20d9ed"; font.pixelSize: 12 }
                    }
                    Rectangle { Layout.fillWidth: true; height: 1; color: "#19546b" }
                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true; spacing: 5
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded; width: 5 }
                        model: root.persistence ? root.persistence.lakes : []
                        delegate: Rectangle {
                            required property var modelData
                            width: ListView.view.width
                            height: 47; radius: 8
                            color: root.selectedLakeId===modelData.id ? "#10394d" : "#092334"
                            border.color: root.selectedLakeId===modelData.id ? "#20d9ed" : "#2a7892"
                            RowLayout {
                                anchors.fill: parent; anchors.margins: 4; spacing: 3
                                Button {
                                    Layout.fillWidth: true; Layout.fillHeight: true
                                    text: modelData.name || "Baltă"
                                    flat: true
                                    padding: 5
                                    contentItem: Label {
                                        text: parent.text; color: "#eff9ff"; font.pixelSize: 12; font.bold: true
                                        verticalAlignment: Text.AlignVCenter
                                        elide: Text.ElideRight
                                    }
                                    onClicked: root.selectLake(modelData)
                                }
                                LakeIconButton {
                                    hint: "Redenumește"
                                    Layout.preferredWidth: 30; Layout.preferredHeight: 32
                                    contentItem: Label { anchors.centerIn: parent; text: "✎"; color: "#20d9ed"; font.pixelSize: 17 }
                                    onClicked: root.beginRename(modelData)
                                }
                                LakeIconButton {
                                    hint: "Șterge"
                                    ToolTip.text: "Șterge"
                                    Layout.preferredWidth: 30; Layout.preferredHeight: 32
                                    contentItem: Label { anchors.centerIn: parent; text: "×"; color: "#ff8793"; font.pixelSize: 20 }
                                    onClicked: root.beginDelete(modelData)
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                SplitView.fillWidth: true
                SplitView.fillHeight: true
                color: "#061827"; border.color: "#20d9ed"; radius: 10
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 9; spacing: 7
                    RowLayout {
                        Layout.fillWidth: true
                        Label {
                            text: root.selectedLake ? (root.selectedLake.name || "Baltă") : "Selectează o baltă"
                            color: "#eff9ff"; font.pixelSize: 17; font.bold: true
                            Layout.fillWidth: true; elide: Text.ElideRight
                        }
                        LakeIconButton {
                            visible: !!root.selectedLake
                            hint: "Redenumește balta"
                            contentItem: Label { anchors.centerIn: parent; text: "✎"; color: "#20d9ed"; font.pixelSize: 18 }
                            onClicked: root.beginRename(root.selectedLake)
                        }
                        LakeIconButton {
                            visible: !!root.selectedLake
                            hint: "Șterge balta"
                            contentItem: Label { anchors.centerIn: parent; text: "×"; color: "#ff8793"; font.pixelSize: 20 }
                            onClicked: root.beginDelete(root.selectedLake)
                        }
                    }
                    Rectangle { Layout.fillWidth: true; height: 1; color: "#19546b" }
                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: 43
                        radius: 8; color: "#071e30"; border.color: "#19546b"
                        Flickable {
                            anchors.fill: parent; anchors.margins: 4
                            clip: true; contentWidth: lakeTabs.implicitWidth; contentHeight: height
                            boundsBehavior: Flickable.StopAtBounds
                            Row {
                                id: lakeTabs; spacing: 6; height: parent.height
                                LakeTab { text: "Prezentare"; target: 0 }
                                LakeTab { text: "Sesiuni sonar"; target: 1 }
                                LakeTab { text: "Acțiuni"; target: 2 }
                            }
                        }
                    }

                    ColumnLayout {
                        visible: root.lakesTab===0
                        Layout.fillWidth: true; spacing: 8
                        Label {
                            Layout.fillWidth: true
                            color: "#c1d7e6"; font.pixelSize: 12; wrapMode: Text.WordWrap
                            text: root.selectedLake ? "Date salvate pentru această baltă" : "Selectează o baltă din listă pentru a vedea datele și acțiunile disponibile."
                        }
                        Rectangle {
                            visible: !!root.selectedLake
                            Layout.fillWidth: true
                            implicitHeight: statsColumn.implicitHeight+18
                            color: "#092334"; border.color: "#2a7892"; radius: 9
                            ColumnLayout {
                                id: statsColumn
                                anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                                anchors.margins: 9; spacing: 5
                                Label { text: root.lakeStats().samples+" eșantioane sonar"; color: "#eff9ff"; font.pixelSize: 12 }
                                Rectangle { Layout.fillWidth: true; height: 1; color: "#19546b" }
                                Label { text: root.lakeStats().spots+" puncte pescuit • "+root.lakeStats().fish+" pești detectați"; color: "#eff9ff"; font.pixelSize: 12 }
                                Rectangle { Layout.fillWidth: true; height: 1; color: "#19546b" }
                                Label { text: "Area Scan: "+root.lakeStats().percent+"% • "+root.lakeStats().done+"/"+root.lakeStats().total+" culoare"; color: "#79eff0"; font.pixelSize: 12 }
                            }
                        }
                        RowLayout {
                            visible: !!root.selectedLake
                            Layout.fillWidth: true
                            LakeAction { text: "Hartă"; onClicked: root.restoreAndOpen("map") }
                            LakeAction { text: "3D"; onClicked: root.restoreAndOpen("3d") }
                            LakeAction { text: "Puncte"; onClicked: root.restoreAndOpen("spots") }
                            Item { Layout.fillWidth: true }
                        }
                    }

                    ListView {
                        visible: root.lakesTab===1
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true; spacing: 7
                        model: root.selectedLake ? root.sessionsForLake(root.selectedLakeId) : []
                        delegate: Rectangle {
                            required property var modelData
                            width: ListView.view.width
                            height: 65; radius: 9
                            color: "#092334"; border.color: "#2a7892"
                            RowLayout {
                                anchors.fill: parent; anchors.margins: 8
                                ColumnLayout {
                                    Layout.fillWidth: true; spacing: 4
                                    Label { text: modelData.name || "Scanare"; color: "#eff9ff"; font.pixelSize: 12; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
                                    Label {
                                        text: (modelData.sampleCount||0)+" puncte • "+Number(modelData.minDepthM||0).toFixed(1)+"–"+Number(modelData.maxDepthM||0).toFixed(1)+" m"
                                        color: "#c1d7e6"; font.pixelSize: 11
                                    }
                                }
                                LakeAction { text: "3D"; onClicked: root.openSession(modelData) }
                            }
                        }
                        Label {
                            anchors.centerIn: parent; visible: parent.count===0
                            text: "Nicio sesiune sonar salvată"
                            color: "#c1d7e6"; font.pixelSize: 12
                        }
                    }

                    ColumnLayout {
                        visible: root.lakesTab===2 && !!root.selectedLake
                        Layout.fillWidth: true; spacing: 9
                        Label { text: "Acțiuni pentru balta selectată"; color: "#eff9ff"; font.pixelSize: 13; font.bold: true }
                        Flow {
                            Layout.fillWidth: true; spacing: 7
                            LakeAction { text: "Deschide harta"; onClicked: root.restoreAndOpen("map") }
                            LakeAction { text: "Batimetrie 3D"; onClicked: root.restoreAndOpen("3d") }
                            LakeAction { text: "Puncte pescuit"; onClicked: root.restoreAndOpen("spots") }
                            LakeAction {
                                text: "Continuă Area Scan"
                                tint: "#37e9a2"
                                enabled: root.lakeStats().total>0 && root.lakeStats().done<root.lakeStats().total
                                onClicked: root.restoreAndOpen("resume")
                            }
                            LakeAction {
                                text: "Restaurează datele"
                                onClicked: root.restoreAndOpen("")
                            }
                        }
                        Rectangle { Layout.fillWidth: true; height: 1; color: "#19546b" }
                        Label {
                            Layout.fillWidth: true
                            color: "#c1d7e6"; font.pixelSize: 11; wrapMode: Text.WordWrap
                            text: "Restaurarea include eșantioanele sonar, punctele salvate și progresul Area Scan. Ștergerea bălții cere confirmare separată."
                        }
                    }
                    Item { Layout.fillHeight: true }
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
        width: Math.min(390, root.width - 32)
        padding: 14
        closePolicy: Popup.NoAutoClose
        background: Rectangle { radius: 10; color: "#101a26"; border.color: "#ef5b6b"; border.width: 1 }
        header: Label {
            text: "Șterge balta?"
            color: "#f2f7fb"; font.bold: true; font.pixelSize: 17
            padding: 14
        }
        contentItem: Label {
            width: deleteDialog.availableWidth
            wrapMode: Text.WordWrap
            color: "#c9d5df"; font.pixelSize: 13
            text: "Ștergi «"+(root.editLake ? (root.editLake.name||"Baltă") : "Baltă")+"» și toate datele salvate? Acțiunea nu poate fi anulată."
        }
        footer: Row {
            spacing: 10
            padding: 12
            layoutDirection: Qt.RightToLeft
            Button { text: "ȘTERGE"; width: 92; onClicked: root.deleteCurrentLake() }
            Button { text: "ANULEAZĂ"; width: 100; onClicked: deleteDialog.close() }
        }
    }
}
