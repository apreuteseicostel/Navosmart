import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import NavoSmart.Backend 1.0

// Standalone Kogger Sonar experimental panel. Does not instantiate another
// Android activity/Core nor command the autopilot. Uses original Epoch::chartTo.
Rectangle {
    id: root
    objectName: "navoKoggerSonarExperimentB"
    color: "#050d17"
    property var chartSource: null
    property int selectedEpoch: -1
    property real selectedDepthM: NaN
    property bool dragToPan: false
    signal closed()

    readonly property bool replayReady: chartSource && chartSource.replayMode
    readonly property string statusText: replayReady
        ? (plot.fileReady ? "KLF • " + plot.indexedColumns + " Epoch" : "Indexare .klf…")
        : (chartSource && chartSource.connected ? "LIVE • Kogger Dataset" : "Sonar neconectat")
    FileDialog {
        id: chooser
        title: "Deschide înregistrare Kogger .klf"
        nameFilters: ["Kogger recording (*.klf)", "Toate fișierele (*)"]
        onAccepted: {
            if(!root.chartSource)return
            if(root.chartSource.startReplay(selectedFile))
                root.chartSource.pauseReplay(true)
        }
    }

    ColumnLayout {
        anchors.fill:parent
        anchors.margins:8
        spacing:6
        RowLayout {
            Layout.fillWidth:true
            spacing:7
            Label {
                text:"KOGGER SONAR • B"
                color:"#eafaff";font.pixelSize:16;font.bold:true
            }
            Label {
                text:root.statusText
                color:"#91c6df";font.pixelSize:11
                Layout.fillWidth:true;elide:Text.ElideRight
            }
            Button {text:"DESCHIDE .KLF";onClicked:chooser.open()}
            Button {
                text:root.chartSource && root.chartSource.replayMode ? "OPREȘTE REPLAY" : "LIVE"
                enabled:root.chartSource && root.chartSource.replayMode
                onClicked:root.chartSource.stopReplay()
            }
            Button {text:"ÎNCHIDE";onClicked:root.closed()}
        }
        RowLayout {
            Layout.fillWidth:true
            spacing:8
            Label {text:"Adâncime";color:"#b3d6e7"}
            SpinBox {
                id:depthSpin
                from:1;to:200;value:50;editable:true
                onValueModified:plot.depthRange=value
            }
            Label {text:"m";color:"#b3d6e7"}
            Label {text:"Paletă";color:"#b3d6e7"}
            ComboBox {
                id:palette
                model:["Kogger Classic","Kogger Ice","Kogger Sepia"]
                onActivated:plot.palette=currentIndex
            }
            Button {
                text:plot.compensate ? "COMPENSAT" : "BRUT"
                checkable:true
                checked:plot.compensate
                onClicked:plot.compensate=checked
            }
            Button {
                text:root.dragToPan?"PAN":"INSPECTOR"
                checkable:true;checked:root.dragToPan
                onClicked:root.dragToPan=checked
            }
            Item {Layout.fillWidth:true}
            Label {text:root.selectedEpoch>=0 ? "Epoch: "+root.selectedEpoch+"  •  "+root.selectedDepthM.toFixed(2)+" m" : "Atinge ecograma pentru inspector";color:"#dceefa";font.pixelSize:11}
        }
        Item {
            Layout.fillWidth:true;Layout.fillHeight:true
            clip:true
            NavoKoggerEpochPlotItem {
                id:plot
                objectName:"koggerNativeOriginalEpochViewB"
                anchors.fill:parent
                fileReplay:root.chartSource && root.chartSource.replayMode ? root.chartSource.replay : null
                depthRange:50
                horizontalZoom:1
                position:0.5
            }
            MouseArea {
                anchors.fill:plot
                acceptedButtons:Qt.LeftButton
                property real dragStartX:0
                property real dragStartPosition:0
                onPressed:function(mouse){
                    dragStartX=mouse.x;dragStartPosition=plot.position
                }
                onPositionChanged:function(mouse){
                    if(!pressed)return
                    if(root.dragToPan){
                        plot.position=Math.max(0,Math.min(1,dragStartPosition-(mouse.x-dragStartX)/Math.max(1,width)/plot.horizontalZoom))
                    }else{
                        var hit=plot.inspectAt(mouse.x,mouse.y)
                        root.selectedEpoch=hit.epoch===undefined?-1:Number(hit.epoch)
                        root.selectedDepthM=hit.depthM===undefined?NaN:Number(hit.depthM)
                    }
                }
                onClicked:function(mouse){
                    var hit=plot.inspectAt(mouse.x,mouse.y)
                    root.selectedEpoch=hit.epoch===undefined?-1:Number(hit.epoch)
                    root.selectedDepthM=hit.depthM===undefined?NaN:Number(hit.depthM)
                }
            }
            Rectangle {
                visible:root.selectedEpoch>0 && !root.dragToPan
                width:1;height:parent.height
                x:plot.indexedColumns>0
                    ? Math.max(0,Math.min(parent.width-1,((root.selectedEpoch-1)/plot.indexedColumns)*parent.width)) : 0
                color:"#fbc04d";opacity:.7
            }
        }
        RowLayout {
            Layout.fillWidth:true;spacing:8
            Button {text:"−";onClicked:plot.horizontalZoom=Math.max(1,Math.floor(plot.horizontalZoom/2))}
            Label {text:plot.horizontalZoom+"×";color:"#dceefa"}
            Button {text:"+";onClicked:plot.horizontalZoom=Math.min(64,plot.horizontalZoom*2)}
            Button {text:"TOT";onClicked:{plot.horizontalZoom=1;plot.position=0.5}}
            Slider {
                id:timeline
                objectName:"koggerFileTimelineB"
                Layout.fillWidth:true
                from:0;to:1
                value:plot.position
                enabled:plot.indexedColumns>1
                onMoved:plot.position=value
                Accessible.name:"Explorează fișierul Kogger fără a muta replay-ul"
            }
            Label {
                text:plot.indexedColumns>0
                  ? Math.round(plot.position*(plot.indexedColumns-1)+1)+" / "+plot.indexedColumns
                  : "0 / 0"
                color:"#dceefa";font.pixelSize:12
                Layout.preferredWidth:110;horizontalAlignment:Text.AlignRight
            }
        }
        Label {
            Layout.fillWidth:true
            color:"#7193a5";font.pixelSize:10
            text:"Experiment B • motor Kogger Epoch::chartTo • ecran separat • nu controlează H743 • fișierul .klf este indexat pe disc"
            elide:Text.ElideRight
        }
    }
}
