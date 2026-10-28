import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id:root
    property var manager: null
    property var region: ({})
    property string lakeName: ""
    property int tileLimit: 5000
    property string status: ""
    property string pendingName: ""
    property var pendingDelete: null
    readonly property bool validRegion: region && isFinite(region.west) && isFinite(region.east) && isFinite(region.north) && isFinite(region.south) && region.west>=-180 && region.east<=180 && region.west<region.east && region.south>=-85 && region.north<=85 && region.south<region.north
    readonly property bool ready: !!manager && validRegion && typeChoice.currentIndex>=0 && minZoom.value<=maxZoom.value && Number(manager.tileCount)>0 && Number(manager.tileCount)<=Math.min(5000,tileLimit) && !pendingName.length
    signal chooseRegionRequested()
    signal showRegionRequested(var region,string mapType)
    function estimate() {
        if(!manager || !validRegion || !typeChoice.currentText.length)return
        // Bathymetry is saved by NAVO per lake. QGC elevation is terrain, not lake depth.
        manager.fetchElevation=false
        manager.updateForCurrentView(region.west,region.north,region.east,region.south,minZoom.value,maxZoom.value,typeChoice.currentText)
    }
    function useRegion() {
        if(!validRegion)return
        var types=manager ? manager.mapList : []
        for(var i=0;i<types.length;i++)if(types[i]===region.mapType){typeChoice.currentIndex=i;break}
        minZoom.value=Math.max(2,Math.min(18,Math.floor(Number(region.zoom)||15)-2))
        maxZoom.value=Math.max(minZoom.value,Math.min(20,Math.floor(Number(region.zoom)||15)+1))
        estimate()
    }
    function beginDownload() {
        estimate()
        if(!ready || !setName.text.trim().length)return false
        var name=setName.text.trim()
        if(manager.findName(name)){status="Există deja o zonă cu acest nume.";return false}
        pendingName=name;status="Se creează zona offline…"
        manager.startDownload(name,typeChoice.currentText)
        return true
    }
    function checkCreated() {
        if(!manager || !pendingName.length)return
        for(var i=0;i<manager.tileSets.count;i++)if(manager.tileSets.get(i).name===pendingName){pendingName="";status="Zona a fost creată; urmărește progresul descărcării.";return}
    }
    Component.onCompleted:{if(manager && manager.tileSets.count===0)manager.loadTileSets();useRegion()}
    onRegionChanged:useRegion()
    Connections {
        target:root.manager;ignoreUnknownSignals:true
        function onTileSetsChanged(){root.checkCreated()}
        function onErrorMessageChanged(){if(root.manager.errorMessage.length){root.status=root.manager.errorMessage;root.pendingName=""}}
    }
    Timer { interval:300;repeat:true;running:root.pendingName.length>0;onTriggered:root.checkCreated() }
    property int offlineTab: 0 // Descarcă / Zone salvate / Informații
    component OfflineAction: Button {
        id: action
        property color tint: "#20d9ed"
        implicitHeight: 35
        padding: 7
        font.pixelSize: 12
        background: Rectangle {
            color: action.down ? "#154253" : (action.hovered ? "#103448" : "#092638")
            border.color: action.enabled ? action.tint : "#526978"
            radius: 8
            border.width: 1
        }
        contentItem: Label {
            text: action.text; color: action.enabled ? "#eff9ff" : "#b7c3cf"
            font: action.font; horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
    }
    component OfflineTab: Button {
        id: tab
        property int target: 0
        implicitWidth: 135
        implicitHeight: 38
        onClicked: root.offlineTab = target
        font.pixelSize: 12
        background: Rectangle {
            radius: 9
            color: root.offlineTab===tab.target ? "#10394d" : "#071e30"
            border.width: root.offlineTab===tab.target ? 2 : 1
            border.color: root.offlineTab===tab.target ? "#20d9ed" : "#26718b"
        }
        contentItem: Label {
            text: tab.text
            color: "#eff9ff"; font.pixelSize: 12; font.bold: root.offlineTab===tab.target
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }
    component OfflineSpin: SpinBox {
        id: spin
        implicitHeight: 37
        implicitWidth: 110
        leftPadding: 32; rightPadding: 32
        font.pixelSize: 13
        editable: true
        contentItem: TextInput {
            text: spin.textFromValue(spin.value, spin.locale)
            font: spin.font; color: "#eff9ff"
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            readOnly: !spin.editable
            validator: spin.validator
            inputMethodHints: Qt.ImhFormattedNumbersOnly
        }
        up.indicator: Rectangle {
            x: spin.width - width
            width: 32; height: spin.height
            color: spin.up.pressed ? "#174c60" : "#0b344a"
            radius: 6; border.color: "#26718b"
            Label { anchors.centerIn: parent; text: "+"; font.pixelSize: 19; color: "#eff9ff" }
        }
        down.indicator: Rectangle {
            width: 32; height: spin.height
            color: spin.down.pressed ? "#174c60" : "#0b344a"
            radius: 6; border.color: "#26718b"
            Label { anchors.centerIn: parent; text: "−"; font.pixelSize: 19; color: "#eff9ff" }
        }
        background: Rectangle { color: "#092439"; border.color: spin.activeFocus ? "#20d9ed" : "#54869d"; radius: 8 }
    }
    component OfflineField: TextField {
        id: field
        implicitHeight: 38
        color: "#eff9ff"
        placeholderTextColor: "#a7c1d3"
        selectByMouse: true
        font.pixelSize: 12
        padding: 8
        background: Rectangle {
            radius: 8
            color: "#0a293e"
            border.color: field.activeFocus ? "#20d9ed" : "#54869d"
            border.width: field.activeFocus ? 2 : 1
        }
    }

    Rectangle { anchors.fill: parent; color: "#051521"; radius: 10; border.color: "#174c68" }
    ScrollView {
        id: offlineScroll
        anchors.fill: parent; anchors.margins: 8
        clip: true; contentWidth: availableWidth
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: ScrollBar.AsNeeded
        ColumnLayout {
            width: offlineScroll.availableWidth
            spacing: 9
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: offlineHeading.implicitHeight + 16
                color: "#071e30"; border.color: "#20d9ed"; radius: 10
                ColumnLayout {
                    id: offlineHeading
                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                    anchors.margins: 8; spacing: 5
                    GridLayout {
                        Layout.fillWidth: true
                        columns: root.width < 370 ? 2 : 3
                        columnSpacing: 7; rowSpacing: 6
                        Image { source: "qrc:/qml/NavoSmart/icons/map.svg"; Layout.preferredWidth: 25; Layout.preferredHeight: 25 }
                        Label { text: "HĂRȚI OFFLINE"; color: "#eff9ff"; font.pixelSize: root.width < 370 ? 15 : 18; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
                        OfflineAction {
                            text: "Alege zona"; tint: "#37e9a2"
                            Layout.columnSpan: root.width < 370 ? 2 : 1
                            Layout.alignment: root.width < 370 ? Qt.AlignLeft : Qt.AlignRight
                            onClicked: root.chooseRegionRequested()
                        }
                    }
                    Label {
                        Layout.fillWidth: true
                        text: root.lakeName.length ? "Baltă: " + root.lakeName : "Hărți locale pentru navigație fără internet"
                        color: "#c1d7e6"; font.pixelSize: 11; elide: Text.ElideRight
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 49
                radius: 9; color: "#071e30"; border.color: "#19546b"
                Flickable {
                    anchors.fill: parent; anchors.margins: 5
                    contentWidth: offlineTabs.implicitWidth; contentHeight: height
                    clip: true; boundsBehavior: Flickable.StopAtBounds
                    Row {
                        id: offlineTabs
                        height: parent.height; spacing: 7
                        OfflineTab { text: "Descarcă"; target: 0 }
                        OfflineTab { text: "Zone salvate"; target: 1 }
                        OfflineTab { text: "Informații"; target: 2 }
                    }
                }
            }

            Rectangle {
                visible: root.offlineTab===0
                Layout.fillWidth: true
                implicitHeight: downloadBody.implicitHeight + 20
                color: "#061827"; border.color: "#20d9ed"; radius: 10
                ColumnLayout {
                    id: downloadBody
                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                    anchors.margins: 10; spacing: 9
                    Label { text: "Pregătire hartă offline"; color: "#eff9ff"; font.pixelSize: 15; font.bold: true }
                    Rectangle { Layout.fillWidth: true; height: 1; color: "#19546b" }
                    Label {
                        Layout.fillWidth: true
                        text: root.validRegion ? "N " + Number(root.region.north).toFixed(5) + " • S " + Number(root.region.south).toFixed(5) +
                                               " • V " + Number(root.region.west).toFixed(5) + " • E " + Number(root.region.east).toFixed(5)
                             : "Nu există o zonă selectată. Apasă «Alege zona» pentru a o delimita pe hartă."
                        color: root.validRegion ? "#79eff0" : "#c1d7e6"
                        font.pixelSize: 11; wrapMode: Text.WordWrap
                    }
                    GridLayout {
                        Layout.fillWidth: true
                        columns: root.width < 620 ? 1 : 2
                        columnSpacing: 12; rowSpacing: 8
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 4
                            Label { text: "Nume zonă"; color: "#eff9ff"; font.pixelSize: 12 }
                            OfflineField {
                                id: setName; objectName: "offlineSetName"
                                Layout.fillWidth: true; maximumLength: 120
                                text: (root.lakeName||"Baltă") + " • " + new Date().toLocaleString(Qt.locale(), Locale.ShortFormat)
                                placeholderText: "Numele zonei"
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 4
                            Label { text: "Tip hartă"; color: "#eff9ff"; font.pixelSize: 12 }
                            ComboBox {
                                id: typeChoice; objectName: "offlineMapType"
                                Layout.fillWidth: true
                                implicitHeight: 38
                                model: root.manager ? root.manager.mapList : []
                                onCurrentIndexChanged: root.estimate()
                                contentItem: Label {
                                    text: typeChoice.displayText; color: "#eff9ff"; font.pixelSize: 12
                                    leftPadding: 10; rightPadding: 27; elide: Text.ElideRight
                                    verticalAlignment: Text.AlignVCenter
                                }
                                background: Rectangle { radius: 8; color: "#0a293e"; border.color: "#54869d" }
                            }
                        }
                    }
                    GridLayout {
                        Layout.fillWidth: true
                        columns: root.width < 380 ? 2 : 5
                        columnSpacing: 7; rowSpacing: 5
                        Label {
                            text: "Zoom"
                            color: "#eff9ff"; font.pixelSize: 12; font.bold: true
                            Layout.columnSpan: root.width < 380 ? 2 : 1
                        }
                        Label { text: "Min"; color: "#c1d7e6"; font.pixelSize: 11 }
                        OfflineSpin {
                            id: minZoom; objectName: "offlineMinZoom"
                            from: 2; to: 20; value: 13; editable: true
                            Layout.preferredWidth: 108
                            onValueModified: root.estimate()
                        }
                        Label { text: "Max"; color: "#c1d7e6"; font.pixelSize: 11 }
                        OfflineSpin {
                            id: maxZoom; objectName: "offlineMaxZoom"
                            from: 2; to: 20; value: 17; editable: true
                            Layout.preferredWidth: 108
                            onValueModified: root.estimate()
                        }
                    }
                    Rectangle { Layout.fillWidth: true; height: 1; color: "#19546b" }
                    GridLayout {
                        Layout.fillWidth: true
                        columns: root.width < 440 ? 1 : 2
                        columnSpacing: 9; rowSpacing: 6
                        Label {
                            Layout.fillWidth: true
                            text: root.manager && root.validRegion ?
                                  root.manager.tileCountStr + " imagini • " + root.manager.tileSizeStr + " • max " + Math.min(5000,root.tileLimit)
                                : "Alege mai întâi o zonă validă"
                            color: root.ready ? "#79eff0" : "#ffd98c"
                            font.pixelSize: 11; wrapMode: Text.WordWrap
                        }
                        OfflineAction {
                            text: root.pendingName.length ? "Se creează…" : "↓ Descarcă zona"
                            tint: "#37e9a2"
                            Layout.alignment: Qt.AlignLeft
                            enabled: root.ready && setName.text.trim().length>0
                            onClicked: root.beginDownload()
                        }
                    }
                    Label {
                        visible: root.status.length>0
                        Layout.fillWidth: true; text: root.status; textFormat: Text.PlainText
                        color: "#ffd98c"; font.pixelSize: 11; wrapMode: Text.WrapAnywhere
                    }
                }
            }

            Rectangle {
                visible: root.offlineTab===1
                Layout.fillWidth: true
                implicitHeight: savedBody.implicitHeight + 20
                color: "#061827"; border.color: "#20d9ed"; radius: 10
                ColumnLayout {
                    id: savedBody
                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                    anchors.margins: 10; spacing: 8
                    RowLayout {
                        Layout.fillWidth: true
                        Label { text: "Zone salvate"; color: "#eff9ff"; font.pixelSize: 15; font.bold: true; Layout.fillWidth: true }
                        OfflineAction {
                            text: "Reîncarcă"
                            onClicked: if (root.manager) root.manager.loadTileSets()
                        }
                    }
                    Rectangle { Layout.fillWidth: true; height: 1; color: "#19546b" }
                    Label {
                        visible: !!root.manager && root.manager.tileSets.count===0
                        Layout.fillWidth: true
                        color: "#c1d7e6"; text: "Nu există zone offline salvate."
                        font.pixelSize: 11
                    }
                    Repeater {
                        model: root.manager ? root.manager.tileSets : null
                        delegate: Rectangle {
                            required property var object
                            readonly property var tileSet: object
                            Layout.fillWidth: true
                            implicitHeight: tileColumn.implicitHeight + 17
                            visible: !tileSet.defaultSet
                            Layout.maximumHeight: visible ? -1 : 0
                            color: "#092334"; radius: 9
                            border.color: tileSet.complete ? "#37e9a2" : "#2a7892"
                            ColumnLayout {
                                id: tileColumn
                                anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                                anchors.margins: 9; spacing: 7
                                RowLayout {
                                    Layout.fillWidth: true
                                    Label { text: tileSet.name; color: "#eff9ff"; font.pixelSize: 13; font.bold: true; Layout.fillWidth: true; wrapMode: Text.WrapAnywhere }
                                    Label { text: tileSet.complete ? "● COMPLETĂ" : tileSet.downloading ? "● DESCĂRCARE" : "● INCOMPLETĂ"; color: tileSet.complete ? "#37e9a2" : "#ffd98c"; font.pixelSize: 10; font.bold: true }
                                }
                                Rectangle { Layout.fillWidth: true; height: 1; color: "#19546b" }
                                Label {
                                    Layout.fillWidth: true
                                    text: tileSet.mapTypeStr + " • Zoom " + tileSet.minZoom + "–" + tileSet.maxZoom +
                                          " • " + tileSet.savedTileCount + "/" + tileSet.totalTileCount + " imagini • " + tileSet.errorCount + " erori"
                                    color: "#c1d7e6"; font.pixelSize: 11; wrapMode: Text.WordWrap
                                }
                                ProgressBar {
                                    id: tileProgress
                                    Layout.fillWidth: true
                                    implicitHeight: 14
                                    from: 0; to: Math.max(1, tileSet.totalTileCount); value: tileSet.savedTileCount
                                    background: Rectangle { implicitHeight: 7; radius: 4; color: "#315063" }
                                    contentItem: Item {
                                        implicitHeight: 7
                                        Rectangle {
                                            height: 7; radius: 4
                                            width: tileProgress.visualPosition * parent.width
                                            color: tileSet.complete ? "#37e9a2" : "#20d9ed"
                                        }
                                    }
                                }
                                Flow {
                                    Layout.fillWidth: true; spacing: 7
                                    OfflineAction { text: tileSet.downloading ? "Ⅱ Pauză" : "▶ Reia"; visible: !tileSet.complete; enabled: !tileSet.deleting; onClicked: tileSet.downloading ? tileSet.cancelDownloadTask() : tileSet.resumeDownloadTask() }
                                    OfflineAction {
                                        text: "Afișează"
                                        enabled: !tileSet.deleting
                                        onClicked: root.showRegionRequested({west: tileSet.topleftLon, north: tileSet.topleftLat,
                                            east: tileSet.bottomRightLon, south: tileSet.bottomRightLat, zoom: tileSet.maxZoom}, tileSet.mapTypeStr)
                                    }
                                    OfflineAction {
                                        text: "Șterge"; tint: "#ff8793"
                                        enabled: !tileSet.downloading && !tileSet.deleting
                                        onClicked: { root.pendingDelete=tileSet; deleteDialog.open() }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                visible: root.offlineTab===2
                Layout.fillWidth: true
                implicitHeight: helpContent.implicitHeight + 20
                color: "#061827"; border.color: "#20d9ed"; radius: 10
                ColumnLayout {
                    id: helpContent
                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                    anchors.margins: 10; spacing: 9
                    Label { text: "Cum funcționează hărțile offline"; color: "#eff9ff"; font.pixelSize: 15; font.bold: true }
                    Rectangle { Layout.fillWidth: true; height: 1; color: "#19546b" }
                    Label {
                        Layout.fillWidth: true; wrapMode: Text.WordWrap; color: "#c1d7e6"; font.pixelSize: 12
                        text: "Selectează zona pe hartă, tipul de hartă și zoomul. Descarcă înainte de plecare. O zonă este completă numai când toate imaginile sunt salvate. Imaginile locale sunt folosite la același tip de hartă și nivel de zoom."
                    }
                    Label {
                        Layout.fillWidth: true; wrapMode: Text.WordWrap; color: "#79eff0"; font.pixelSize: 12
                        text: "Batimetria, punctele de pescuit și misiunile NAVO se păstrează separat, în Bălțile mele. Harta de fundal nu înlocuiește datele sonar."
                    }
                    OfflineAction { text: "Înapoi la descărcare"; onClicked: root.offlineTab=0 }
                }
            }
        }
    }
    Dialog {
        id:deleteDialog;parent:Overlay.overlay;anchors.centerIn:parent;width:Math.min(360,root.width);modal:true;title:"Ștergi zona offline?";standardButtons:Dialog.Yes|Dialog.No
        palette.windowText: "#eff9ff"; palette.text: "#eff9ff"
        background: Rectangle { radius: 12; color: "#071e30"; border.color: "#ff8793" }
        onAccepted:{if(root.pendingDelete && !root.pendingDelete.defaultSet && !root.pendingDelete.downloading)root.manager.deleteTileSet(root.pendingDelete);root.pendingDelete=null}
        onRejected:root.pendingDelete=null
    }
}
