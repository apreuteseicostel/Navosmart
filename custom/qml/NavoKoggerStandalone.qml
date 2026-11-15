// NAVO experiment B: independent Kogger-style workspace.
// Does not reuse the dashboard sonar/vehicle controller, so it cannot
// trigger H743 commands or clear NAVO's shared bathymetry Dataset.
// Built from NAVO's already vendored GPL-3.0 Kogger decoder/renderer components.
// The complete upstream KoggerApp Core/Plot2D is NOT embedded at this stage.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import NavoSmart.Backend 1.0

Rectangle {
    id: root
    objectName: "koggerStandalonePage"
    color: "#07141c"
    property bool navoSonarBusy: false
    property bool fileMode: false
    property int selectedColumn: 0
    property int horizontalZoom: 1
    property real verticalRange: 15
    property int palette: 0
    property bool inspectorEnabled: true
    property var inspected: ({})
    readonly property int total: replay.indexReady ? replay.indexedColumns : 0
    readonly property int windowColumns: total>0 ? Math.max(1,Math.ceil(total/horizontalZoom)) : 1
    readonly property int windowStart: total>0 ?
        Math.max(0,Math.min(total-windowColumns,selectedColumn-Math.floor(windowColumns/2))) : 0
    readonly property string modeLabel: fileMode ? (replay.indexReady ? "KLF indexat" :
        "Indexare "+Math.round(replay.indexProgress*100)+"%") :
        (transport.connected ? "LIVE TCP/UDP" : "OFFLINE")
    signal closed()

    function openFile(url) {
        transport.disconnectEndpoint()
        decoder.reset()
        replay.stop()
        fileMode=true
        selectedColumn=0
        horizontalZoom=1
        inspected=({})
        return replay.open(url)
    }
    function closeSession() {
        replay.stop()
        transport.disconnectEndpoint()
        decoder.reset()
        fileMode=false
        inspected=({})
    }
    function setZoom(value) {
        horizontalZoom=Math.max(1,Math.min(64,Math.round(value)))
    }
    function moveCursor(delta) {
        if(total<1)return
        selectedColumn=Math.max(0,Math.min(total-1,selectedColumn+Math.round(delta)))
    }

    NavoKoggerReplay {
        id: replay
        onBytesReady: function(bytes){decoder.feedBytes(bytes)}
        onPreviewLastColumnReady: decoder.flushPendingChart()
        onIndexChanged: {
            if(indexReady && indexedColumns>0) {
                selectedColumn=Math.floor(indexedColumns/2)
                replay.setPaused(true)
            }
        }
    }
    NavoKoggerDecoder { id: decoder }
    NavoEthernetTransport {
        id: transport
        autoReconnect: false
        host: hostField.text.trim()
        port: Math.max(0,Math.min(65535,parseInt(portField.text)||0))
        udp: protocolSwitch.currentIndex===1
        onBytesReceived: function(bytes){if(!root.fileMode)decoder.feedBytes(bytes)}
    }
    FileDialog {
        id: klfPicker
        title: "Deschide fișier sonar Kogger"
        nameFilters: ["Kogger / NAVO Sonar (*.klf *.navosonar)", "Toate fișierele (*)"]
        onAccepted: root.openFile(selectedFile)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 7
        RowLayout {
            Layout.fillWidth:true; spacing:8
            Label {
                text:"KOGGER SONAR";font.pixelSize:18;font.bold:true;color:"#e0f5ff"
            }
            Label {
                text:"B • experiment izolat";font.pixelSize:11;color:"#63d3ff"
            }
            Label {
                Layout.fillWidth:true;text:root.modeLabel;horizontalAlignment:Text.AlignRight
                font.pixelSize:12;color:"#a3dbe9";elide:Text.ElideRight
            }
            Button {objectName:"koggerBOpenFile";text:"DESCHIDE .KLF";onClicked:klfPicker.open()}
            Button {
                text:replay.paused ? "▶" : "Ⅱ"
                enabled:root.fileMode && replay.active
                onClicked:replay.setPaused(!replay.paused)
                Accessible.name:replay.paused ? "Continuă redarea Kogger" : "Pauză redare Kogger"
            }
            Button {text:"STOP";onClicked:root.closeSession()}
            Button {text:"ÎNCHIDE";objectName:"koggerBClose";onClicked:root.closed()}
        }
        RowLayout {
            Layout.fillWidth:true; spacing:6
            Label {text:"IP:";color:"#dbeffd"}
            TextField {
                id:hostField
                objectName:"koggerBHost"
                text:"192.168.144.7"
                Layout.preferredWidth:145
                placeholderText:"IP sonar"
            }
            Label {text:"Port:";color:"#dbeffd"}
            TextField {id:portField;text:"6000";Layout.preferredWidth:77;inputMethodHints:Qt.ImhDigitsOnly}
            ComboBox {id:protocolSwitch;model:["TCP","UDP"];Layout.preferredWidth:85}
            Button {
                text:transport.connected ? "DECONECTEAZĂ" : "CONECTEAZĂ"
                enabled:transport.connected || (!root.fileMode && !root.navoSonarBusy && portField.text.length>0)
                onClicked: {
                    if(transport.connected)transport.disconnectEndpoint()
                    else {replay.stop();root.fileMode=false;decoder.reset();transport.connectEndpoint()}
                }
            }
            Label {
                Layout.fillWidth:true;elide:Text.ElideRight;color:"#a0c4d7";font.pixelSize:11
                text:root.navoSonarBusy && !transport.connected ?
                    "Conexiunea LIVE NAVO este deja activă; folosește un fișier" :
                    "Sursă separată · "+transport.status
            }
        }
        RowLayout {
            Layout.fillWidth:true;spacing:5
            Label{text:"Scară:";color:"#c5e6f4"}
            ComboBox {
                model:["5 m","10 m","15 m","20 m","50 m","100 m","120 m"]
                currentIndex:2
                onActivated:function(index){root.verticalRange=[5,10,15,20,50,100,120][index]}
                Layout.preferredWidth:96
            }
            Label{text:"Culori:";color:"#c5e6f4"}
            ComboBox {model:["Classic","Ice","Sepia"];currentIndex:root.palette;onActivated:function(i){root.palette=i};Layout.preferredWidth:110}
            CheckBox {text:"Inspector";checked:root.inspectorEnabled;onToggled:root.inspectorEnabled=checked}
            Label {
                Layout.fillWidth:true;text:root.inspected && root.inspected.column ?
                    "Epoch / coloană "+root.inspected.column+
                    " • "+Number(root.inspected.selectedDepthM).toFixed(2)+" m" :
                    "Atinge ecograma pentru inspectare"
                color:"#b5dfe9";elide:Text.ElideRight
            }
        }
        Rectangle {
            id: chartArea
            Layout.fillWidth:true
            Layout.fillHeight:true
            color:"#000"
            border.color:"#235577";clip:true
            NavoKoggerEchogramItem {
                id: chart
                objectName:"koggerBOriginalDataEchogram"
                anchors.fill:parent
                decoder:decoder
                fileReplay:root.fileMode && replay.indexReady ? replay : null
                fileWindowStart:root.windowStart
                fileWindowColumns:root.windowColumns
                fileSelectedColumn:root.selectedColumn
                depthFrom:0
                depthRange:root.verticalRange
                paletteMode:root.palette
                lowLevel:0
                highLevel:100
                gain:1
                noiseFloor:0
                frozen:false
                showBottomTrack:true
            }
            MouseArea {
                anchors.fill:parent
                property real pressedX:0
                property int pressedColumn:0
                property bool dragged:false
                onPressed:function(mouse){pressedX=mouse.x;pressedColumn=root.selectedColumn;dragged=false}
                onPositionChanged:function(mouse){
                    if(!pressed||!root.fileMode||root.total<=0||root.horizontalZoom<=1)return
                    var distance=mouse.x-pressedX
                    if(Math.abs(distance)>5)dragged=true
                    if(dragged)root.selectedColumn=Math.max(0,Math.min(root.total-1,
                        pressedColumn-Math.round(distance/Math.max(1,width)*root.windowColumns)))
                }
                onClicked:function(mouse){
                    if(dragged || !root.inspectorEnabled)return
                    root.inspected=chart.inspectAt(mouse.x,mouse.y)
                    if(root.fileMode && root.inspected.column)
                        root.selectedColumn=Math.max(0,Math.min(root.total-1,root.inspected.column-1))
                }
            }
        }
        RowLayout {
            Layout.fillWidth:true;spacing:7
            Label {
                color:"#b5d9ec";font.pixelSize:11
                text:root.fileMode ? "Epoch "+(root.selectedColumn+1)+" / "+root.total :
                    "CHART "+decoder.chartSequence
                Layout.preferredWidth:145
            }
            Slider {
                id: wholeFile
                objectName:"koggerBFullFileTimeline"
                Layout.fillWidth:true
                from:0;to:Math.max(1,root.total-1)
                enabled:root.fileMode && root.total>1
                value:root.selectedColumn
                onMoved:root.selectedColumn=Math.round(value)
                Accessible.name:"Kogger B poziție în întregul fișier"
            }
            Button{text:"−";enabled:root.total>0;onClicked:root.moveCursor(-Math.max(1,Math.ceil(root.windowColumns/3)))}
            Button{text:"+";enabled:root.total>0;onClicked:root.moveCursor(Math.max(1,Math.ceil(root.windowColumns/3)))}
            Button{text:"−×";enabled:root.horizontalZoom>1;onClicked:root.setZoom(root.horizontalZoom/2)}
            Label{text:root.horizontalZoom+"×";color:"#e0f5ff"}
            Button{text:"+×";enabled:root.horizontalZoom<64;onClicked:root.setZoom(root.horizontalZoom*2)}
            Button{text:"TOT";enabled:root.horizontalZoom>1;onClicked:root.setZoom(1)}
        }
        Label {
            Layout.fillWidth:true;color:"#729db3";font.pixelSize:10;wrapMode:Text.WordWrap
            text:"Varianta B: spațiu Kogger independent pentru testare. Folosește decoderul și Dataset/rendererul Kogger deja portate; integrarea întregului KoggerApp Core/Plot2D rămâne separată până la validarea dependențelor."
        }
    }
    Component.onDestruction: closeSession()
}
