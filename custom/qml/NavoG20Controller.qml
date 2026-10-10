import QtQuick
import QtCore
import NavoSmart.Backend 1.0

Item {
    id: root
    visible: false
    property var vehicle: null
    property bool inputAllowed: false
    property alias settings: cfg
    property var channels: []
    property var buttonStates: ({})
    property double lastFrameMs: 0
    signal actionRequested(string control, string action)
    signal zoomRequested(int direction)
    Settings {
        id: cfg
        category: "NavoG20"
        property bool hardwareActionsEnabled: false
        property int homeChannel: 6
        property int leftHopperChannel: 11
        property int rightHopperChannel: 15
        property int lightChannel: 7
        property int sonarChannel: 16
        property int cameraChannel: 8
        property int holdChannel: 13
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

    property int settingsRevision: 0
    function resetDefaults() {
        cfg.hAction="RTL"; cfg.mode3Action="MANUAL/HOLD/AUTO"
        cfg.l1Action="CUVA_STANGA"; cfg.r1Action="CUVA_DREAPTA"
        cfg.l2Action="FAR"; cfg.r2Action="SONAR"; cfg.cameraAction="CAMERA"
        cfg.pauseAction="HOLD"; cfg.leftStickAction="ZOOM_HARTA"
        cfg.hopperHoldMs=1500; cfg.rtlHoldMs=1800
        cfg.hardwareActionsEnabled=false
        cfg.homeChannel=6; cfg.leftHopperChannel=11; cfg.rightHopperChannel=15
        cfg.lightChannel=7; cfg.sonarChannel=16; cfg.cameraChannel=8; cfg.holdChannel=13
        resetInput()
        settingsRevision++
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


    function resetInput() {
        channels = []
        buttonStates = ({})
        lastFrameMs = 0
    }
    function ingestChannels(values, nowMs) {
        if (!inputAllowed) { resetInput(); return }
        if (lastFrameMs && nowMs - lastFrameMs >= 1000) buttonStates = ({})
        channels = values
        lastFrameMs = nowMs
        if (!cfg.hardwareActionsEnabled) { buttonStates = ({}); return }
        var bindings = [
            {control:"H",channel:cfg.homeChannel},
            {control:"L1",channel:cfg.leftHopperChannel},
            {control:"R1",channel:cfg.rightHopperChannel},
            {control:"L2",channel:cfg.lightChannel},
            {control:"R2",channel:cfg.sonarChannel},
            {control:"CAMERA",channel:cfg.cameraChannel},
            {control:"PAUSE",channel:cfg.holdChannel}
        ]
        var used = ({})
        for (var i=0; i<bindings.length; ++i) {
            var binding=bindings[i], ch=binding.channel
            if(ch<1 || ch>16) continue
            if(used[ch]) { used[ch]="DUPLICATE"; continue }
            used[ch]=binding.control
        }
        for (var j=0; j<bindings.length; ++j) {
            var b=bindings[j], pwm=values[b.channel-1]
            if(used[b.channel]!==b.control) { delete buttonStates[b.control]; continue }
            if(!isFinite(pwm) || pwm<900 || pwm>2100) { delete buttonStates[b.control]; continue }
            var state=buttonStates[b.control]
            if(!state) state=buttonStates[b.control]={ready:false,since:0,fired:false}
            // Require a released position after startup/reconnection.
            if(pwm<=1600) { state.ready=true; state.since=0; state.fired=false; continue }
            if(pwm<1800) { state.since=0; continue }
            if(!state.ready || state.fired) continue
            if(!state.since) state.since=nowMs
            var action=b.control==="H"?cfg.hAction:
                b.control==="L1"?cfg.l1Action:b.control==="R1"?cfg.r1Action:
                b.control==="L2"?cfg.l2Action:b.control==="R2"?cfg.r2Action:
                b.control==="CAMERA"?cfg.cameraAction:cfg.pauseAction
            var hold=action==="RTL"?cfg.rtlHoldMs:
                (action.indexOf("CUVA")===0?cfg.hopperHoldMs:120)
            if(nowMs-state.since>=hold) {
                state.fired=true
                trigger(b.control,true)
            }
        }
    }
    onInputAllowedChanged: resetInput()
    Connections {
        target: cfg
        function onHardwareActionsEnabledChanged() { root.resetInput() }
    }
    NavoMissionBridge {
        vehicle: root.vehicle
        onRcChannelsReceived: function(values) { root.ingestChannels(values,Date.now()) }
        onVehicleChanged: root.resetInput()
    }
    Timer {
        interval:250; repeat:true; running:true
        onTriggered: {
            if(root.lastFrameMs && Date.now()-root.lastFrameMs>=1000) root.resetInput()
        }
    }
}
