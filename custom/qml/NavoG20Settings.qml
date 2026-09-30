import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCore

Rectangle {
    id: root
    color: "#0b1c2e"; border.color: "#1c4262"; radius: 10
    signal actionRequested(string control, string action)
    signal zoomRequested(int direction)

    Settings {
        id: cfg
        category: "NavoG20"
        property string hAction: "RTL"
        property string mode3Action: "MANUAL/HOLD/AUTO"
        property string l1Action: "CUVA_STANGA"
        property string r1Action: "CUVA_DREAPTA"
        property string l2Action: "FAR"
        property string r2Action: "SONAR"
        property string cameraAction: "CAMERA"
        property string pauseAction: "HOLD"
        property string leftStickAction: "ZOOM_HARTA"
        property int hopperHoldMs: 1500
        property int rtlHoldMs: 1800
    }

    readonly property var actions: [
        {text:"Nimic",value:"NONE"}, {text:"Cuva stânga",value:"CUVA_STANGA"},
        {text:"Cuva dreapta",value:"CUVA_DREAPTA"}, {text:"Ambele cuve",value:"CUVE_AMBELE"},
        {text:"Far ON/OFF",value:"FAR"}, {text:"Poziții ON/OFF",value:"POZITII"}, {text:"Sonar fullscreen",value:"SONAR"},
        {text:"Camera față",value:"CAMERA"}, {text:"HOLD",value:"HOLD"},
        {text:"RTL / Acasă",value:"RTL"}
    ]

    function resetDefaults() {
        cfg.hAction="RTL"; cfg.mode3Action="MANUAL/HOLD/AUTO"
        cfg.l1Action="CUVA_STANGA"; cfg.r1Action="CUVA_DREAPTA"
        cfg.l2Action="FAR"; cfg.r2Action="SONAR"; cfg.cameraAction="CAMERA"
        cfg.pauseAction="HOLD"; cfg.leftStickAction="ZOOM_HARTA"
        cfg.hopperHoldMs=1500; cfg.rtlHoldMs=1800
    }
    function trigger(control, longPress) {
        var a="NONE"
        if(control==="H") a=cfg.hAction
        else if(control==="L1") a=cfg.l1Action
        else if(control==="R1") a=cfg.r1Action
        else if(control==="L2") a=cfg.l2Action
        else if(control==="R2") a=cfg.r2Action
        else if(control==="CAMERA") a=cfg.cameraAction
        else if(control==="PAUSE") a=cfg.pauseAction
        if((a==="RTL" || a.indexOf("CUVA")===0 || a==="CUVE_AMBELE") && !longPress) return
        actionRequested(control,a)
    }
    function modeSwitch(position) {
        if(position<=0) actionRequested("MODE3","MANUAL")
        else if(position===1) actionRequested("MODE3","HOLD")
        else actionRequested("MODE3","AUTO")
    }
    function leftStick(y) {
        if(cfg.leftStickAction!=="ZOOM_HARTA") return
        if(y>0.55) zoomRequested(1)
        else if(y< -0.55) zoomRequested(-1)
    }

    ColumnLayout {
        anchors.fill: parent; anchors.margins: 10; spacing: 8
        RowLayout {
            Layout.fillWidth: true
            Label { text:"TELECOMANDĂ G20 • BUTOANE"; color:"#21b7ff"; font.bold:true; font.pixelSize:14 }
            Item { Layout.fillWidth:true }
            Button { text:"RESET DEFAULT"; onClicked:root.resetDefaults() }
        }
        Label {
            Layout.fillWidth:true; wrapMode:Text.WordWrap; color:"#9db2c5"; font.pixelSize:11
            text:"Preset NAVO: H=RTL • 3 poziții=MANUAL/HOLD/AUTO • L1/R1=cuve stânga/dreapta • L2=far • R2=sonar • Camera=camera față • Pause=HOLD • joystick stâng ↑/↓=zoom hartă. Joystick dreapta rămâne rezervat pilotajului."
        }
        GridLayout {
            Layout.fillWidth:true; columns:4; columnSpacing:8; rowSpacing:6
            Label{text:"Control";color:"#d7e3ee";font.bold:true}
            Label{text:"Funcție";color:"#d7e3ee";font.bold:true}
            Label{text:"Control";color:"#d7e3ee";font.bold:true}
            Label{text:"Funcție";color:"#d7e3ee";font.bold:true}

            Label{text:"L1";color:"#d7e3ee"}; ActionCombo{settingValue:cfg.l1Action;onPicked:v=>cfg.l1Action=v}
            Label{text:"R1";color:"#d7e3ee"}; ActionCombo{settingValue:cfg.r1Action;onPicked:v=>cfg.r1Action=v}
            Label{text:"L2";color:"#d7e3ee"}; ActionCombo{settingValue:cfg.l2Action;onPicked:v=>cfg.l2Action=v}
            Label{text:"R2";color:"#d7e3ee"}; ActionCombo{settingValue:cfg.r2Action;onPicked:v=>cfg.r2Action=v}
            Label{text:"Camera";color:"#d7e3ee"}; ActionCombo{settingValue:cfg.cameraAction;onPicked:v=>cfg.cameraAction=v}
            Label{text:"Pause";color:"#d7e3ee"}; ActionCombo{settingValue:cfg.pauseAction;onPicked:v=>cfg.pauseAction=v}
            Label{text:"H (long press)";color:"#d7e3ee"}; ActionCombo{settingValue:cfg.hAction;onPicked:v=>cfg.hAction=v}
            Label{text:"3 poziții";color:"#d7e3ee"}; Label{text:"MANUAL / HOLD / AUTO";color:"#47d16c";font.bold:true}
            Label{text:"Joystick stâng";color:"#d7e3ee"}; Label{text:"↑ Zoom +  •  ↓ Zoom −";color:"#47d16c";font.bold:true}
            Label{text:"Joystick dreapta";color:"#d7e3ee"}; Label{text:"PILOTAJ • blocat";color:"#ffc857";font.bold:true}
        }
        RowLayout {
            Layout.fillWidth:true
            Label{text:"Long press cuve";color:"#d7e3ee"}
            SpinBox{from:800;to:3000;stepSize:100;value:cfg.hopperHoldMs;onValueModified:cfg.hopperHoldMs=value}
            Label{text:"ms";color:"#9db2c5"}
            Item{Layout.fillWidth:true}
            Label{text:"Long press RTL";color:"#d7e3ee"}
            SpinBox{from:1000;to:4000;stepSize:100;value:cfg.rtlHoldMs;onValueModified:cfg.rtlHoldMs=value}
            Label{text:"ms";color:"#9db2c5"}
        }
        Label {
            Layout.fillWidth:true; wrapMode:Text.WordWrap; color:"#ffc857"; font.pixelSize:10
            text:"Siguranță: RTL și cuvele cer long-press. AUTO selectează modul, dar nu pornește singur o misiune. Confirmarea RTL rămâne în fluxul NAVO."
        }
    }

    component ActionCombo: ComboBox {
        property string settingValue:"NONE"
        signal picked(string value)
        Layout.fillWidth:true
        textRole:"text"; valueRole:"value"; model:root.actions
        Component.onCompleted:{var i=indexOfValue(settingValue);if(i>=0)currentIndex=i}
        onActivated:picked(currentValue)
    }
}
