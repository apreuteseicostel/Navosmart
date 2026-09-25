import QtQuick
import QtQuick.Controls

Item {
    id: root
    property bool leftHopperOpen: false
    property bool rightHopperOpen: false
    property bool headlightOn: false
    property bool positionLightsOn: false
    property real rudderNormalized: 0
    property bool showLabel: false

    implicitWidth: 92
    implicitHeight: 150

    Canvas {
        id: hull
        anchors.fill: parent
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
            c.fillStyle = root.headlightOn ? "#fff3a6" : "#4c5a64"
            c.beginPath()
            c.roundedRect(width*0.43, height*0.08, width*0.14, height*0.045, 3, 3)
            c.fill()

            // Position lights.
            c.fillStyle = root.positionLightsOn ? "#e8f8ff" : "#4c5a64"
            c.beginPath(); c.arc(width*0.20, height*0.84, width*0.035, 0, Math.PI*2); c.fill()
            c.beginPath(); c.arc(width*0.80, height*0.84, width*0.035, 0, Math.PI*2); c.fill()
        }
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
            origin.x: parent.width/2
            origin.y: 0
            angle: Math.max(-1, Math.min(1, root.rudderNormalized)) * 35
            Behavior on angle { NumberAnimation { duration: 150 } }
        }
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
