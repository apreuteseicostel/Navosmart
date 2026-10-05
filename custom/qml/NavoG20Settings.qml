import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    property var controller
    property var cfg: controller ? controller.settings : null
    color: "#0b1c2e"; border.color: "#1c4262"; radius: 10
    implicitHeight: content.implicitHeight + 24
    readonly property var bindings: [
        {label:"HOME",key:"homeChannel",action:"hAction"},
        {label:"L1",key:"leftHopperChannel",action:"l1Action"},
        {label:"R1",key:"rightHopperChannel",action:"r1Action"},
        {label:"L2",key:"lightChannel",action:"l2Action"},
        {label:"R2",key:"sonarChannel",action:"r2Action"},
        {label:"CAMERA",key:"cameraChannel",action:"cameraAction"},
        {label:"STOP",key:"holdChannel",action:"pauseAction"}
    ]
    ColumnLayout {
        id: content
        anchors.left: parent.left; anchors.right: parent.right
        anchors.top: parent.top; anchors.margins: 12
        spacing: 8
        Label { text:"AVANSAT • INTEGRARE G20 / H743"; color:"#21b7ff"; font.bold:true }
        Label {
            Layout.fillWidth:true; wrapMode:Text.WordWrap; color:"#9db2c5"
            text:"Butoanele, Reverse și limitele se configurează în G20 Device Tool. Aici asociem canalele primite de la H743 cu acțiunile NAVO. X2/Y2 rămân pentru pilotaj."
        }
        Switch {
            Layout.fillWidth:true
            text:"Comenzi NAVO din canalele RC"
            checked:root.cfg ? root.cfg.hardwareActionsEnabled : false
            onToggled:if(root.cfg) root.cfg.hardwareActionsEnabled=checked
        }
        Label {
            Layout.fillWidth:true; wrapMode:Text.WordWrap; color:"#ffc857"
            text:"Activează după verificarea funcțiilor H743. Evită comanda aceluiași actuator atât direct din H743, cât și prin NAVO. Cuvele și RTL cer apăsare lungă; după reconectare, eliberează butonul înainte de comandă."
        }
        Repeater {
            model:root.bindings
            RowLayout {
                required property var modelData
                Layout.fillWidth:true
                Label { text:modelData.label; color:"#d7e3ee"; Layout.preferredWidth:65 }
                SpinBox {
                    from:0; to:16
                    value:root.cfg ? root.cfg[modelData.key] : 0
                    onValueModified: { root.cfg[modelData.key]=value; root.controller.resetInput() }
                    ToolTip.visible:hovered
                    ToolTip.text:"Canal RC_CHANNELS (0 = dezactivat)"
                }
                ComboBox {
                    Layout.fillWidth:true
                    textRole:"text"; valueRole:"value"
                    model:root.controller ? root.controller.actions : []
                    currentIndex:root.cfg ? Math.max(0,indexOfValue(root.cfg[modelData.action])) : 0
                    onActivated: { root.cfg[modelData.action]=currentValue; root.controller.resetInput() }
                }
            }
        }
        RowLayout {
            Layout.fillWidth:true
            Label { text:"Cuve (ms)"; color:"#d7e3ee" }
            SpinBox { from:800;to:3000;stepSize:100;value:root.cfg?root.cfg.hopperHoldMs:1500;onValueModified:root.cfg.hopperHoldMs=value }
            Item { Layout.fillWidth:true }
        }
        RowLayout {
            Layout.fillWidth:true
            Label { text:"RTL (ms)"; color:"#d7e3ee" }
            SpinBox { from:1000;to:4000;stepSize:100;value:root.cfg?root.cfg.rtlHoldMs:1800;onValueModified:root.cfg.rtlHoldMs=value }
            Item { Layout.fillWidth:true }
        }
        Label {
            Layout.fillWidth:true; wrapMode:Text.WordWrap; color:"#9db2c5"
            text:root.controller && root.controller.channels.length ?
                "RC primit • " + root.controller.channels.map(function(v,i){return "CH"+(i+1)+": "+(v>0?v:"—")}).join("   ") :
                "RC offline • H743 trebuie să transmită MAVLink RC_CHANNELS"
        }
        Button {
            text:"Restabilește presetul NAVO"
            onClicked:if(root.controller) root.controller.resetDefaults()
        }
    }
}
