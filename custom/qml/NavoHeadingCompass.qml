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
    z: expanded ? 10000 : 0
    scale: expanded ? 2.35 : 1.0
    transformOrigin: Item.TopRight
    Behavior on scale { NumberAnimation { duration: 160 } }

    Rectangle {
        anchors.fill: parent; radius: width/2
        color: "#07131dcc"; border.color: root.headingValid ? "#26c6da" : "#4d5b67"; border.width: 2
    }

    Item {
        id: rose
        anchors.fill: parent
        Repeater {
            model: 36
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
        Label { text:"N"; color:"#26c6da"; font.bold:true; anchors.horizontalCenter:parent.horizontalCenter; anchors.top:parent.top; anchors.topMargin:16 }
        Label { text:"S"; color:"#d8e2ea"; anchors.horizontalCenter:parent.horizontalCenter; anchors.bottom:parent.bottom; anchors.bottomMargin:16 }
        Label { text:"W"; color:"#d8e2ea"; anchors.verticalCenter:parent.verticalCenter; anchors.left:parent.left; anchors.leftMargin:17 }
        Label { text:"E"; color:"#d8e2ea"; anchors.verticalCenter:parent.verticalCenter; anchors.right:parent.right; anchors.rightMargin:17 }
    }

    Item {
        id: boat
        width: 46; height: 88; anchors.centerIn: parent
        rotation: root.normalizedHeading
        Behavior on rotation { RotationAnimation { duration: 260; direction: RotationAnimation.Shortest } }
        Canvas {
            anchors.fill: parent
            onPaint: {
                var c=getContext("2d"); c.reset()
                c.fillStyle="#d9ff19"; c.strokeStyle="#101820"; c.lineWidth=2
                c.beginPath(); c.moveTo(width/2,1); c.quadraticCurveTo(width-2,20,width-4,74)
                c.lineTo(width-9,height-3); c.lineTo(9,height-3); c.lineTo(4,74)
                c.quadraticCurveTo(2,20,width/2,1); c.closePath(); c.fill(); c.stroke()
                c.fillStyle="#101820"; c.fillRect(8,45,12,31); c.fillRect(width-20,45,12,31)
                c.fillStyle="#18232d"; c.beginPath(); c.roundedRect(12,19,width-24,24,5,5); c.fill()
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
        anchors.centerIn: parent; anchors.verticalCenterOffset: 57; spacing: 0
        Label { anchors.horizontalCenter:parent.horizontalCenter; text:root.headingValid ? Math.round(root.normalizedHeading)+"° "+root.cardinal : "HEADING --"; color:"white"; font.bold:true; font.pixelSize:13 }
        Label { anchors.horizontalCenter:parent.horizontalCenter; visible:isFinite(root.courseError); text:(root.courseError<0?"← ":"→ ")+Math.abs(Math.round(root.courseError))+"°"; color:"#ffbf3f"; font.pixelSize:11 }
    }

    ToolTip.visible: mouse.containsMouse
    ToolTip.text: root.headingValid ? "Direcție "+Math.round(root.normalizedHeading)+"° "+root.cardinal+(isFinite(root.courseError)?" • abatere "+Math.round(root.courseError)+"°":"") : "Heading indisponibil"
    MouseArea { id:mouse; anchors.fill:parent; hoverEnabled:true; onClicked: root.expanded = !root.expanded }
}
