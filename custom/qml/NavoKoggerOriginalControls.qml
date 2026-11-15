// Experiment C: compact NAVO host controls for upstream Kogger 2D interaction.
// Adapted from KoggerApp qml/scene2d/Plot2D.qml concepts (GPL-3.0):
// epoch inspection, explicit scroll mode, depth window and echogram theme.
// No Kogger Core singleton, no navigation or motor commands.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    objectName:"koggerCOriginalToolbar"
    property bool inspectMode:true
    property bool compensated:false
    property int paletteMode:0
    property real depthWindow:5
    property int epoch:0
    property int epochCount:0
    signal inspectModeRequested(bool inspect)
    signal compensationRequested(bool compensated)
    signal paletteRequested(int palette)
    signal depthWindowRequested(real depth)

    radius:7
    color:"#e6091c27"
    border.color:"#376f87"
    height:40
    implicitWidth:buttons.implicitWidth+16
    RowLayout {
        id:buttons
        anchors.fill:parent
        anchors.leftMargin:7
        anchors.rightMargin:7
        spacing:4
        Label {
            text:"KOGGER"
            font.bold:true;font.pixelSize:11;color:"#72d9fa"
        }
        ToolButton {
            objectName:"koggerCInspectorMode"
            text:"AIM"
            checkable:true;checked:root.inspectMode
            onClicked:root.inspectModeRequested(true)
            ToolTip.visible:hovered
            ToolTip.text:"Inspectează Epoch fără a deplasa ecograma"
        }
        ToolButton {
            objectName:"koggerCPanMode"
            text:"PAN"
            checkable:true;checked:!root.inspectMode
            onClicked:root.inspectModeRequested(false)
            ToolTip.visible:hovered
            ToolTip.text:"Deplasează fereastra vizibilă"
        }
        ToolButton {
            objectName:"koggerCCompensation"
            text:root.compensated?"COMP":"RAW"
            checkable:true;checked:root.compensated
            onClicked:root.compensationRequested(!root.compensated)
            ToolTip.visible:hovered
            ToolTip.text:"Compensarea originală Kogger pentru CHART v0"
        }
        ComboBox {
            objectName:"koggerCPalette"
            Layout.preferredWidth:87
            model:["Classic","Ice","Sepia"]
            currentIndex:root.paletteMode
            onActivated:function(i){root.paletteRequested(i)}
            ToolTip.visible:hovered
            ToolTip.text:"Paletă originală Kogger"
        }
        ComboBox {
            objectName:"koggerCDepthScale"
            Layout.preferredWidth:76
            model:["5 m","10 m","15 m","20 m","50 m","100 m"]
            currentIndex:Math.max(0,[5,10,15,20,50,100].indexOf(root.depthWindow))
            onActivated:function(i){root.depthWindowRequested([5,10,15,20,50,100][i])}
            ToolTip.visible:hovered
            ToolTip.text:"Scară verticală de adâncime"
        }
        Label {
            text:root.epochCount>0?"E "+Math.max(1,root.epoch)+" / "+root.epochCount:"LIVE"
            font.pixelSize:10;color:"#d9edf7"
            Layout.preferredWidth:83;elide:Text.ElideRight
        }
    }
}
