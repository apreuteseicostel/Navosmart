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
    ScrollView {
        id:offlineScroll
        anchors.fill:parent;contentWidth:availableWidth
        ColumnLayout {
            width:offlineScroll.availableWidth;spacing:8
            Label { text:"HĂRȚI OFFLINE";color:"#21b7ff";font.bold:true }
            Label { Layout.fillWidth:true;color:"#bbcbd9";wrapMode:Text.WordWrap;text:"Alege zona vizibilă pe hartă, tipul hărții și nivelurile de zoom. Descarcă înainte de plecare. O zonă este completă numai când toate imaginile au fost salvate." }
            Button { text:"Alege zona pe hartă";onClicked:root.chooseRegionRequested() }
            Label { Layout.fillWidth:true;color:"#bbcbd9";wrapMode:Text.WordWrap;text:root.validRegion ? "N "+Number(root.region.north).toFixed(5)+" • S "+Number(root.region.south).toFixed(5)+"\nV "+Number(root.region.west).toFixed(5)+" • E "+Number(root.region.east).toFixed(5) : "Pe hartă: Straturi → Salvează zona offline." }
            TextField { id:setName;objectName:"offlineSetName";Layout.fillWidth:true;maximumLength:120;text:(root.lakeName||"Baltă")+" • "+new Date().toLocaleString(Qt.locale(),Locale.ShortFormat);placeholderText:"Numele zonei" }
            ComboBox { id:typeChoice;objectName:"offlineMapType";Layout.fillWidth:true;model:root.manager ? root.manager.mapList : [];onCurrentIndexChanged:root.estimate() }
            RowLayout {
                Layout.fillWidth:true
                Label { text:"Zoom";color:"#bbcbd9" }
                SpinBox { id:minZoom;objectName:"offlineMinZoom";from:2;to:20;value:13;Layout.fillWidth:true;onValueModified:root.estimate() }
                SpinBox { id:maxZoom;objectName:"offlineMaxZoom";from:2;to:20;value:17;Layout.fillWidth:true;onValueModified:root.estimate() }
            }
            Label { Layout.fillWidth:true;wrapMode:Text.WordWrap;color:root.ready ? "#bbcbd9" : "#ffb56b";text:root.manager && root.validRegion ? root.manager.tileCountStr+" imagini • estimat "+root.manager.tileSizeStr+" • limită "+Math.min(5000,root.tileLimit) : "Nicio zonă aleasă" }
            Button { text:root.pendingName.length ? "Se creează…" : "Descarcă zona";enabled:root.ready && setName.text.trim().length>0;onClicked:root.beginDownload() }
            Label { Layout.fillWidth:true;visible:root.status.length>0;text:root.status;textFormat:Text.PlainText;color:"#ffb56b";wrapMode:Text.WrapAnywhere }
            Label { Layout.fillWidth:true;color:"#bbcbd9";wrapMode:Text.WordWrap;text:"Batimetria, punctele și misiunile salvate rămân în Bălțile mele. Harta de fundal folosește automat imaginile locale pentru tipul și zoomul descărcate." }
            Repeater {
                model:root.manager ? root.manager.tileSets : null
                delegate:Rectangle {
                    required property var object
                    readonly property var tileSet:object
                    Layout.fillWidth:true;Layout.preferredHeight:tileColumn.implicitHeight+16
                    visible:!tileSet.defaultSet
                    Layout.maximumHeight:visible ? -1 : 0
                    color:"#0b1a27";radius:8;border.color:tileSet.complete ? "#31d67b" : "#31506a"
                    ColumnLayout {
                        id:tileColumn;anchors.left:parent.left;anchors.right:parent.right;anchors.top:parent.top;anchors.margins:8
                        Label { Layout.fillWidth:true;text:tileSet.name;color:"#e1eaf2";wrapMode:Text.WrapAnywhere }
                        Label { Layout.fillWidth:true;text:tileSet.mapTypeStr+" • zoom "+tileSet.minZoom+"–"+tileSet.maxZoom;color:"#bbcbd9";wrapMode:Text.WordWrap }
                        Label { Layout.fillWidth:true;wrapMode:Text.WordWrap;text:(tileSet.complete ? "COMPLETĂ" : tileSet.downloading ? "DESCĂRCARE" : "INCOMPLETĂ")+" • "+tileSet.savedTileCount+" / "+tileSet.totalTileCount+" • erori "+tileSet.errorCount;color:tileSet.complete ? "#31d67b" : "#ffb56b" }
                        ProgressBar { Layout.fillWidth:true;from:0;to:Math.max(1,tileSet.totalTileCount);value:tileSet.savedTileCount }
                        Flow {
                            Layout.fillWidth:true;spacing:4
                            Button { text:tileSet.downloading ? "Pauză" : "Reia";visible:!tileSet.complete;enabled:!tileSet.deleting;onClicked:tileSet.downloading ? tileSet.cancelDownloadTask() : tileSet.resumeDownloadTask() }
                            Button { text:"Afișează";enabled:!tileSet.deleting;onClicked:root.showRegionRequested({west:tileSet.topleftLon,north:tileSet.topleftLat,east:tileSet.bottomRightLon,south:tileSet.bottomRightLat,zoom:tileSet.maxZoom},tileSet.mapTypeStr) }
                            Button { text:"Șterge";enabled:!tileSet.downloading && !tileSet.deleting;onClicked:{root.pendingDelete=tileSet;deleteDialog.open()} }
                        }
                    }
                }
            }
        }
    }
    Dialog {
        id:deleteDialog;parent:Overlay.overlay;anchors.centerIn:parent;width:Math.min(360,root.width);modal:true;title:"Ștergi zona offline?";standardButtons:Dialog.Yes|Dialog.No
        onAccepted:{if(root.pendingDelete && !root.pendingDelete.defaultSet && !root.pendingDelete.downloading)root.manager.deleteTileSet(root.pendingDelete);root.pendingDelete=null}
        onRejected:root.pendingDelete=null
    }
}
