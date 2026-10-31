import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    property var controller
    property var cfg: controller ? controller.settings : null
    property bool showHelp: false
    color: "#061827"; border.color: "#20d9ed"; radius: 10
    implicitHeight: content.implicitHeight + 24
    readonly property bool narrowRows: width < 430

    // Bound the entire control, including its +/- indicators. Android styles
    // otherwise contribute a large implicit minimum to the settings content.
    component ChannelSpinBox: SpinBox {
        id: spin
        implicitWidth: 116; implicitHeight: 44
        leftPadding: 36; rightPadding: 36
        font.pixelSize: 14
        contentItem: TextInput {
            text: spin.textFromValue(spin.value, spin.locale)
            font: spin.font; color: "#e8f4ff"
            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
            readOnly: !spin.editable; validator: spin.validator
            inputMethodHints: Qt.ImhFormattedNumbersOnly
        }
        up.indicator: Rectangle {
            x: spin.width - width; width: 36; height: spin.height
            color: spin.up.pressed ? "#21516c" : "#143149"
            Text { anchors.centerIn: parent; text: "+"; color: spin.enabled && spin.value < spin.to ? "#e8f4ff" : "#61798a"; font.pixelSize: 20 }
        }
        down.indicator: Rectangle {
            width: 36; height: spin.height
            color: spin.down.pressed ? "#21516c" : "#143149"
            Text { anchors.centerIn: parent; text: "−"; color: spin.enabled && spin.value > spin.from ? "#e8f4ff" : "#61798a"; font.pixelSize: 20 }
        }
        background: Rectangle { color: "#092439"; border.color: spin.activeFocus ? "#20d9ed" : "#537b91"; radius: 6 }
    }
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
        RowLayout {
            Layout.fillWidth: true
            Label { text: "G20 / H743 • Asocieri RC"; color: "#eff9ff"; font.pixelSize: 16; font.bold: true; Layout.fillWidth: true }
            Button {
                text: "ⓘ"; implicitWidth: 30; implicitHeight: 30
                Accessible.name: "Informații integrare G20"
                onClicked: root.showHelp = !root.showHelp
                ToolTip.visible: hovered
                ToolTip.text: "Canalele sunt configurate în G20 Device Tool; NAVO trimite numai acțiuni permise."
                background: Rectangle { color: "transparent" }
                contentItem: Label { text: parent.text; color: "#20d9ed"; font.pixelSize: 18; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            }
        }
        Rectangle { Layout.fillWidth: true; height: 1; color: "#19546b" }
        Label {
            visible: root.showHelp
            Layout.fillWidth:true; wrapMode:Text.WordWrap; color:"#c1d7e6"; font.pixelSize: 11
            text:"Butoanele, Reverse și limitele se configurează în G20 Device Tool. Aici asociem canalele primite de la H743 cu acțiunile NAVO. X2/Y2 rămân pentru pilotaj."
        }
        Label {
            Layout.fillWidth:true;wrapMode:Text.WordWrap;color:"#79eff0";font.pixelSize:12
            text:"Selector mod CH5 → H743: MANUAL / AUTO / GUIDED. Configurare nativă MODE_CH=5 și MODE1…MODE6 conform profilului NAVO. Cardul MOD afișează numai modul confirmat de H743."
        }
        Switch {
            id: enableActions
            Layout.fillWidth:true
            text:"Comenzi NAVO din RC"
            contentItem: Label {
                text:enableActions.text; color:"#d7e3ee"; font:enableActions.font
                leftPadding:enableActions.indicator.width + enableActions.spacing
                verticalAlignment:Text.AlignVCenter; wrapMode:Text.WordWrap
            }
            checked:root.cfg ? root.cfg.hardwareActionsEnabled : false
            onToggled:if(root.cfg) root.cfg.hardwareActionsEnabled=checked
        }
        Label {
            Layout.fillWidth:true; wrapMode:Text.WordWrap; color:"#ffd98c"; font.pixelSize: 11
            text: root.showHelp
                ? "Activează după verificarea funcțiilor H743. Evită comanda aceluiași actuator atât direct din H743, cât și prin NAVO. Cuvele și RTL cer apăsare lungă; după reconectare, eliberează butonul înainte de comandă."
                : "Comenzile RC necesită calibrare și validare hardware."
        }
        Repeater {
            model:root.bindings
            Item {
                id: mappingRow
                required property var modelData
                objectName: "g20Mapping_" + modelData.key
                Layout.fillWidth:true
                implicitHeight: root.narrowRows ? 94 : 44
                Label {
                    text:mappingRow.modelData.label; color:"#d7e3ee"
                    width:64; height:44; verticalAlignment:Text.AlignVCenter
                    font.pixelSize:13; elide:Text.ElideRight
                }
                ChannelSpinBox {
                    objectName: "g20Channel_" + mappingRow.modelData.key
                    x:70; width:116; height:44
                    from:0; to:16
                    value:root.cfg ? root.cfg[mappingRow.modelData.key] : 0
                    onValueModified:if(root.cfg) { root.cfg[mappingRow.modelData.key]=value; root.controller.resetInput() }
                    ToolTip.visible:hovered
                    ToolTip.text:"Canal RC_CHANNELS (0 = dezactivat; CH5 rezervat selectorului de mod)"
                }
                ComboBox {
                    id: actionSelector
                    objectName: "g20Action_" + mappingRow.modelData.key
                    x:root.narrowRows ? 70 : 194
                    y:root.narrowRows ? 50 : 0
                    width:Math.max(0, Math.min(240, mappingRow.width-x)); height:44
                    font.pixelSize:14
                    textRole:"text"; valueRole:"value"
                    model:root.controller ? root.controller.actions : []
                    currentIndex:count > 0 && root.cfg ? Math.max(0,indexOfValue(root.cfg[mappingRow.modelData.action])) : 0
                    onActivated:if(root.cfg) { root.cfg[mappingRow.modelData.action]=currentValue; root.controller.resetInput() }
                    contentItem: Label {
                        text:actionSelector.displayText; font:actionSelector.font; color:"#e8f4ff"
                        leftPadding:10; rightPadding:32; verticalAlignment:Text.AlignVCenter
                        elide:Text.ElideRight
                    }
                    indicator: Text {
                        x:actionSelector.width-width-12; anchors.verticalCenter:parent.verticalCenter
                        text:"▾"; color:"#21b7ff"; font.pixelSize:18
                    }
                    background: Rectangle { color:actionSelector.down ? "#174c60" : "#092439"; border.color:actionSelector.activeFocus ? "#20d9ed" : "#537b91"; radius:7 }
                    ToolTip.visible:hovered; ToolTip.text:displayText
                }
            }
        }
        RowLayout {
            Layout.alignment:Qt.AlignLeft
            Label { text:"Cuve ms"; color:"#d7e3ee"; Layout.preferredWidth:64; font.pixelSize:13 }
            ChannelSpinBox { Layout.preferredWidth:128; Layout.maximumWidth:128; from:800;to:3000;stepSize:100;value:root.cfg?root.cfg.hopperHoldMs:1500;onValueModified:if(root.cfg)root.cfg.hopperHoldMs=value }
        }
        RowLayout {
            Layout.alignment:Qt.AlignLeft
            Label { text:"RTL ms"; color:"#d7e3ee"; Layout.preferredWidth:64; font.pixelSize:13 }
            ChannelSpinBox { Layout.preferredWidth:128; Layout.maximumWidth:128; from:1000;to:4000;stepSize:100;value:root.cfg?root.cfg.rtlHoldMs:1800;onValueModified:if(root.cfg)root.cfg.rtlHoldMs=value }
        }
        Label {
            Layout.fillWidth:true; wrapMode:Text.WordWrap; color:"#9db2c5"
            text:root.controller && root.controller.channels.length ?
                "RC primit • " + root.controller.channels.map(function(v,i){return "CH"+(i+1)+": "+(v>0?v:"—")}).join("   ") :
                "RC offline • H743 trebuie să transmită MAVLink RC_CHANNELS"
        }
        Button {
            Layout.maximumWidth:210
            text:"Reset preset NAVO"
            onClicked:if(root.controller) root.controller.resetDefaults()
        }
    }
}

