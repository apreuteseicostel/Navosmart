import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import "NavoOfflineLabData.js" as LabData

// Deliberately isolated UI. No Vehicle, MAVLink, flight controller, sensors,
// native bridge or persistence object is reachable from this component.
Rectangle {
    id:root
    objectName:"navoProOfflineLab"
    color:"#071925"
    radius:10
    border.color:"#20d9ed"
    property bool show3D:false
    property real contourStepM:1
    readonly property var demoSamples:LabData.samples()
    readonly property var contourSegments:LabData.contours(contourStepM)
    signal replayFileSelected(url fileUrl)
    signal closeRequested()

    FileDialog {
        id:labRecordingPicker
        objectName:"offlineLabRecordingPicker"
        title:"NAVO PRO • Deschide înregistrare Kogger"
        nameFilters:["Kogger / NAVO sonar (*.klf *.navosonar)","Toate fișierele (*)"]
        onAccepted:root.replayFileSelected(selectedFile)
    }

    ColumnLayout {
        anchors.fill:parent
        anchors.margins:8
        spacing:5
        RowLayout {
            Layout.fillWidth:true;spacing:7
            Label {
                text:"NAVO PRO • OFFLINE LAB"
                color:"#20d9ed";font.bold:true;font.pixelSize:15
                Layout.fillWidth:true;elide:Text.ElideRight
            }
            Label {
                objectName:"offlineLabSimulationBadge"
                text:"SIMULARE • FĂRĂ COMENZI"
                color:"#ffcb75";font.bold:true;font.pixelSize:10
            }
            Button {text:"✕";implicitWidth:40;implicitHeight:34;onClicked:root.closeRequested();Accessible.name:"Închide laboratorul"}
        }
        Label {
            Layout.fillWidth:true
            text:"Model 2D/3D sintetic separat de Bălțile mele. Pentru ecograma reală, încarcă o înregistrare .klf."
            color:"#a9c7d8";font.pixelSize:11;wrapMode:Text.WordWrap
        }
        RowLayout {
            Layout.fillWidth:true;spacing:6
            Button {
                objectName:"offlineLab2DButton"
                text:"CURBE DEMO 2D";checkable:true;checked:!root.show3D
                onClicked:root.show3D=false
            }
            Button {
                objectName:"offlineLab3DButton"
                text:"RELIEF 3D";checkable:true;checked:root.show3D
                onClicked:root.show3D=true
            }
            ComboBox {
                objectName:"offlineLabContourSpacing"
                visible:!root.show3D
                model:[0.5,1,2,5]
                currentIndex:1
                implicitWidth:110
                displayText:root.contourStepM+" m"
                onActivated:function(index){root.contourStepM=model[index]}
                Accessible.name:"Pasul liniilor de nivel simulate"
            }
            Item {Layout.fillWidth:true}
            Button {
                objectName:"offlineLabOpenRecording"
                text:"DESCHIDE .KLF"
                onClicked:labRecordingPicker.open()
                ToolTip.visible:hovered;ToolTip.text:"Fișier real Kogger pentru replay, fără sonar conectat"
            }
        }
        Rectangle {
            Layout.fillWidth:true;Layout.fillHeight:true
            color:"#08283b";radius:8;clip:true
            border.color:"#24516c"
            Canvas {
                id:mapCanvas
                objectName:"offlineLabContourCanvas"
                anchors.fill:parent
                visible:!root.show3D
                onWidthChanged:requestPaint()
                onHeightChanged:requestPaint()
                onPaint:{
                    var ctx=getContext("2d")
                    ctx.reset()
                    ctx.fillStyle="#092b40"
                    ctx.fillRect(0,0,width,height)
                    if(width<30||height<30)return
                    var inset=28,scale=Math.min((width-2*inset)/48,(height-2*inset)/40)
                    function sx(x){return width/2+x*scale}
                    function sy(y){return height/2-y*scale}
                    ctx.fillStyle="#123f56"
                    ctx.fillRect(sx(-23),sy(19),46*scale,38*scale)
                    ctx.strokeStyle="#2d667f";ctx.lineWidth=1
                    for(var x=-20;x<=20;x+=10) {
                        ctx.beginPath();ctx.moveTo(sx(x),sy(-18));ctx.lineTo(sx(x),sy(18));ctx.stroke()
                    }
                    for(var y=-10;y<=10;y+=10) {
                        ctx.beginPath();ctx.moveTo(sx(-22),sy(y));ctx.lineTo(sx(22),sy(y));ctx.stroke()
                    }
                    var lines=root.contourSegments
                    for(var i=0;i<lines.length;i++) {
                        var s=lines[i]
                        ctx.strokeStyle=s.depth>=4?"#f5d26f":"#42dbec"
                        ctx.lineWidth=1.5
                        ctx.beginPath();ctx.moveTo(sx(s.a.x),sy(s.a.y));ctx.lineTo(sx(s.b.x),sy(s.b.y));ctx.stroke()
                    }
                    ctx.fillStyle="#f5e5b7";ctx.font="11px sans-serif"
                    ctx.fillText("CURBE SIMULATE • "+root.contourStepM+" m",12,20)
                    ctx.fillText("44 m × 36 m • GPS fictiv",12,height-12)
                }
                onVisibleChanged:if(visible)requestPaint()
            }
            Loader {
                anchors.fill:parent
                active:root.show3D
                visible:active
                sourceComponent:Component {
                    NavoBathymetry3D {
                        anchors.fill:parent
                        samples:root.demoSamples
                        boatTrack:[]
                        fishingSpots:[]
                        fishDetections:[]
                        gridSizeM:2
                        maxGapM:3
                        simulatedData:true
                        usePersistentCache:false
                    }
                }
            }
            Label {
                anchors.right:parent.right;anchors.bottom:parent.bottom
                anchors.margins:9
                visible:root.show3D
                color:"#ffcb75";font.bold:true;font.pixelSize:12
                text:"RELIEF SIMULAT • NU ESTE KOGGER NATIV"
                background:Rectangle {color:"#dd081b2a";radius:5}
            }
        }
        RowLayout {
            Layout.fillWidth:true
            Label {
                Layout.fillWidth:true;color:"#a9c7d8";font.pixelSize:10
                text:"Liniile demo nu validează adâncimile reale; procesorul Kogger nativ este testat separat în CI."
                wrapMode:Text.WordWrap
            }
            Button {
                text:"Exemplu .KLF"
                implicitHeight:28
                ToolTip.visible:hovered;ToolTip.text:"Descarcă înregistrarea de test Kogger pentru replay"
                onClicked:Qt.openUrlExternally("https://kogger.tech/wp-content/uploads/00028_DownView.klf")
            }
        }
    }
    onContourStepMChanged:mapCanvas.requestPaint()
}
