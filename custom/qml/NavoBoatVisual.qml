import QtQuick
import QtQuick.Controls

Item {
    id: root
    property bool leftHopperOpen: false
    property bool rightHopperOpen: false
    property bool headlightOn: false
    property bool positionLightsOn: false
    // RC switch demand is *not* relay/bulb feedback. Render it amber, not ON white.
    property bool headlightRequested: false
    property bool positionLightsRequested: false
    // App-only indication: NEVER proof of a physical RGB LED output.
    property string virtualRgbState: "unknown" // critical / warning / hopper / normal / unknown
    property real rudderNormalized: 0
    property bool showLabel: false

    implicitWidth: 92
    implicitHeight: 150

    Canvas {
        id: hull
        anchors.fill: parent
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            var c = getContext("2d")
            c.reset()

            // Fluorescent yellow NAVO SMART top-down hull.
            c.fillStyle = "#dfff00"
            c.strokeStyle = "#0f1820"
            c.lineWidth = Math.max(2, width * 0.035)
            c.beginPath()
            c.moveTo(width/2, 2)
            c.quadraticCurveTo(width*0.90, height*0.12, width*0.93, height*0.55)
            c.quadraticCurveTo(width*0.92, height*0.78, width*0.82, height*0.92)
            c.lineTo(width*0.18, height*0.92)
            c.quadraticCurveTo(width*0.08, height*0.78, width*0.07, height*0.55)
            c.quadraticCurveTo(width*0.10, height*0.12, width/2, 2)
            c.closePath()
            c.fill()
            c.stroke()

            // Black lower/rear hull.
            c.fillStyle = "#111820"
            c.beginPath()
            c.moveTo(width*0.12, height*0.72)
            c.lineTo(width*0.88, height*0.72)
            c.lineTo(width*0.82, height*0.93)
            c.lineTo(width*0.18, height*0.93)
            c.closePath()
            c.fill()

            // Central electronics hatch.
            c.fillStyle = "#18232d"
            c.beginPath()
            c.roundedRect(width*0.30, height*0.19, width*0.40, height*0.28, width*0.06, width*0.06)
            c.fill()

            // Front light.
            c.fillStyle = root.headlightOn ? "#fff3a6" : root.headlightRequested ? "#e9aa46" : "#4c5a64"
            c.beginPath()
            c.roundedRect(width*0.43, height*0.08, width*0.14, height*0.045, 3, 3)
            c.fill()

            // Port red / starboard green when telemetry confirms an ON command.
            // Amber means only an active G20 RC input, not confirmed lamp power.
            c.fillStyle = root.positionLightsOn ? "#ff4e5a"
                : root.positionLightsRequested ? "#e9aa46" : "#4c5a64"
            c.beginPath(); c.arc(width*0.20, height*0.84, Math.max(2,width*0.049), 0, Math.PI*2); c.fill()
            c.fillStyle = root.positionLightsOn ? "#46f29a"
                : root.positionLightsRequested ? "#e9aa46" : "#4c5a64"
            c.beginPath(); c.arc(width*0.80, height*0.84, Math.max(2,width*0.049), 0, Math.PI*2); c.fill()
        }
    }

    // The virtual RGB alarm is derived from NAVO sensor/command data; it
    // does not drive or confirm the physical serialLED on the V3 PCB.
    Rectangle {
        id: visualRgbIndicator
        objectName: "boatVirtualRgbIndicator"
        width: Math.max(6, root.width * 0.13)
        height: width
        radius: width / 2
        x: root.width / 2 - width / 2
        y: root.height * 0.39
        z: 6
        color: root.virtualRgbState === "critical" ? "#ff354e"
            : root.virtualRgbState === "warning" ? "#ffa43b"
            : root.virtualRgbState === "hopper" ? "#24aaff"
            : root.virtualRgbState === "normal" ? "#3be48d" : "#8850a4"
        border.color: "#e0edfa"
        border.width: 1
        opacity: root.virtualRgbState === "unknown" ? 0.55 : 1
    }
    Rectangle {
        id: leftHopper
        width: root.width * 0.31
        height: root.height * 0.34
        x: root.width * 0.13
        y: root.height * 0.48
        radius: Math.max(3, width * 0.09)
        color: "#111820"
        border.color: "#4e6070"
        border.width: 1
        Rectangle {
            anchors.centerIn: parent
            width: Math.max(5,parent.width*0.33)
            height: width
            radius: width/2
            color: root.leftHopperOpen ? "#28b5ff" : "#394955"
            border.color: root.leftHopperOpen ? "#d0f6ff" : "#566775"
        }
        transform: Rotation {
            origin.x: 0
            origin.y: leftHopper.height
            angle: root.leftHopperOpen ? -48 : 0
            Behavior on angle { NumberAnimation { duration: 360; easing.type: Easing.InOutCubic } }
        }
    }

    Rectangle {
        id: rightHopper
        width: root.width * 0.31
        height: root.height * 0.34
        x: root.width * 0.56
        y: root.height * 0.48
        radius: Math.max(3, width * 0.09)
        color: "#111820"
        border.color: "#4e6070"
        border.width: 1
        Rectangle {
            anchors.centerIn: parent
            width: Math.max(5,parent.width*0.33)
            height: width
            radius: width/2
            color: root.rightHopperOpen ? "#28b5ff" : "#394955"
            border.color: root.rightHopperOpen ? "#d0f6ff" : "#566775"
        }
        transform: Rotation {
            origin.x: rightHopper.width
            origin.y: rightHopper.height
            angle: root.rightHopperOpen ? 48 : 0
            Behavior on angle { NumberAnimation { duration: 360; easing.type: Easing.InOutCubic } }
        }
    }

    Rectangle {
        width: Math.max(3, root.width * 0.055)
        height: root.height * 0.13
        radius: width/2
        x: root.width/2 - width/2
        y: root.height * 0.88
        color: "#9cafba"
        transform: Rotation {
            origin.x: width/2
            origin.y: 0
            angle: Math.max(-1, Math.min(1, root.rudderNormalized)) * 35
            Behavior on angle { NumberAnimation { duration: 150 } }
        }
    }

    Connections {
        target: root
        function onHeadlightOnChanged() { hull.requestPaint() }
        function onPositionLightsOnChanged() { hull.requestPaint() }
        function onHeadlightRequestedChanged() { hull.requestPaint() }
        function onPositionLightsRequestedChanged() { hull.requestPaint() }
    }

    Label {
        visible: root.showLabel
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 1
        text: "NAVO SMART"
        color: "#1fa8d8"
        font.bold: true
        font.pixelSize: Math.max(7, Math.min(11, root.width * 0.11))
    }
}
