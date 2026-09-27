import QtQuick
import QtQuick.Controls

Item {
    id: root
    property real headingDeg: NaN
    property real waypointBearingDeg: NaN
    property real rollDeg: NaN
    property real pitchDeg: NaN
    property bool headingValid: isFinite(headingDeg)
    property bool expanded: false
    signal toggleRequested()
    property string cardinal: {
        if (!headingValid) return "--"
        var p=["N","NE","E","SE","S","SW","W","NW"]
        return p[Math.round(((headingDeg%360)+360)%360/45)%8]
    }
    readonly property real normalizedHeading: headingValid ? ((headingDeg%360)+360)%360 : 0
    readonly property real courseError: {
        if (!headingValid || !isFinite(waypointBearingDeg)) return NaN
        return ((waypointBearingDeg-normalizedHeading+540)%360)-180
    }

    implicitWidth: 180; implicitHeight: 180
    z: 0
    clip: false

    Rectangle {
        anchors.fill: parent; radius: width/2
        color: root.expanded ? "#07131d99" : "#07131dcc"; border.color: root.headingValid ? "#26c6da" : "#4d5b67"; border.width: 2
    }

    Item {
        id: rose
        anchors.fill: parent
        z: 3
        Repeater {
            model: root.expanded ? 36 : 0
            Rectangle {
                required property int index
                width: index%9===0 ? 2 : 1
                height: index%9===0 ? 13 : 7
                color: index%9===0 ? "#f2f7fb" : "#688093"
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top; anchors.topMargin: 7
                transform: Rotation { origin.x: width/2; origin.y: root.height/2-7; angle: index*10 }
            }
        }
        Label { visible:root.expanded; z:10; text:"N"; color:"#26c6da"; font.bold:true; font.pixelSize:22; anchors.horizontalCenter:parent.horizontalCenter; anchors.top:parent.top; anchors.topMargin:12 }
        Label { visible:root.expanded; z:10; text:"S"; color:"#f4f7fb"; font.bold:true; font.pixelSize:20; anchors.horizontalCenter:parent.horizontalCenter; anchors.bottom:parent.bottom; anchors.bottomMargin:12 }
        Label { visible:root.expanded; z:10; text:"W"; color:"#f4f7fb"; font.bold:true; font.pixelSize:20; anchors.verticalCenter:parent.verticalCenter; anchors.left:parent.left; anchors.leftMargin:12 }
        Label { visible:root.expanded; z:10; text:"E"; color:"#f4f7fb"; font.bold:true; font.pixelSize:20; anchors.verticalCenter:parent.verticalCenter; anchors.right:parent.right; anchors.rightMargin:12 }
    }

    Item {
        id: boat
        z: 2
        opacity: root.expanded ? 0.88 : 1.0
        width: Math.max(18, root.width * 0.26); height: Math.max(34, root.height * 0.52); anchors.centerIn: parent
        rotation: root.normalizedHeading
        Behavior on rotation { RotationAnimation { duration: 260; direction: RotationAnimation.Shortest } }
        Canvas {
            anchors.fill: parent
            onPaint: {
                var c=getContext("2d"); c.reset()
                // NAVO bait boat, top view: clean pointed bow, twin rear hoppers and antenna.
                c.fillStyle="#d9ff19"; c.strokeStyle="#101820"; c.lineWidth=2
                c.beginPath(); c.moveTo(width/2,0)
                c.quadraticCurveTo(width*0.82,height*0.16,width-3,height*0.39)
                c.lineTo(width-6,height-5); c.quadraticCurveTo(width/2,height-1,6,height-5)
                c.lineTo(3,height*0.39); c.quadraticCurveTo(width*0.18,height*0.16,width/2,0)
                c.closePath(); c.fill(); c.stroke()
                // NAVO SMART deck branding on the expanded map compass.\n                if (root.expanded) {\n                    c.fillStyle="#101820"; c.font="bold "+Math.max(8,Math.round(width*0.15))+"px sans-serif"; c.textAlign="center";\n                    c.fillText("NAVO",width/2,height*0.39); c.fillText("SMART",width/2,height*0.49);\n                }\n                // Two hopper openings sit aft, not at the bow.
                c.fillStyle="#101820"
                var hopperY=height*0.58, hopperH=height*0.25
                c.beginPath(); c.roundedRect(width*0.16,hopperY,width*0.25,hopperH,2,2); c.fill()
                c.beginPath(); c.roundedRect(width*0.59,hopperY,width*0.25,hopperH,2,2); c.fill()
                // Small stern antenna/mast.
                c.strokeStyle="#d9ff19"; c.lineWidth=2
                c.beginPath(); c.moveTo(width/2,height-4); c.lineTo(width/2,height+8); c.stroke()
                c.fillStyle="#26c6da"; c.beginPath(); c.arc(width/2,height+9,2,0,Math.PI*2); c.fill()
            }
        }
    }

    Rectangle {
        visible: isFinite(root.waypointBearingDeg)
        width: 8; height: 22; radius: 4; color:"#ffbf3f"
        anchors.horizontalCenter: parent.horizontalCenter; anchors.top:parent.top; anchors.topMargin:4
        transform: Rotation { origin.x:width/2; origin.y:root.height/2-4; angle: root.waypointBearingDeg }
    }

    Column {
        anchors.centerIn: parent; anchors.verticalCenterOffset: root.height * 0.32; spacing: 0
        Label { anchors.horizontalCenter:parent.horizontalCenter; text:root.headingValid ? Math.round(root.normalizedHeading)+"° "+root.cardinal : "HEADING --"; color:"white"; font.bold:true; font.pixelSize:Math.max(8,Math.min(13,root.width*0.072)) }
        Label { anchors.horizontalCenter:parent.horizontalCenter; visible:isFinite(root.courseError); text:(root.courseError<0?"← ":"→ ")+Math.abs(Math.round(root.courseError))+"°"; color:"#ffbf3f"; font.pixelSize:Math.max(7,Math.min(11,root.width*0.061)) }
    }

    ToolTip.visible: mouse.containsMouse
    ToolTip.text: root.headingValid ? "Direcție "+Math.round(root.normalizedHeading)+"° "+root.cardinal+(isFinite(root.courseError)?" • abatere "+Math.round(root.courseError)+"°":"") : "Heading indisponibil"
    MouseArea { id:mouse; anchors.fill:parent; hoverEnabled:true; onClicked: root.toggleRequested() }
}
