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
        color: root.expanded ? "#07131d99" : "transparent"; border.color: root.expanded ? (root.headingValid ? "#26c6da" : "#4d5b67") : "transparent"; border.width: root.expanded ? 2 : 0
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
        Repeater {
            model: root.expanded ? [
                {t:"N",  a:0}, {t:"NE", a:45}, {t:"E",  a:90}, {t:"SE", a:135},
                {t:"S",  a:180}, {t:"SW", a:225}, {t:"W", a:270}, {t:"NW", a:315}
            ] : []
            delegate: Item {
                required property var modelData
                width: root.width; height: root.height
                anchors.centerIn: parent
                Label {
                    text: modelData.t
                    color: modelData.t==="N" ? "#26c6da" : "#f4f7fb"
                    font.bold: true
                    font.pixelSize: modelData.t.length===1 ? 19 : 12
                    x: parent.width/2-width/2 + Math.sin(modelData.a*Math.PI/180)*parent.width*0.405
                    y: parent.height/2-height/2 - Math.cos(modelData.a*Math.PI/180)*parent.height*0.405
                }
            }
        }
    }

    Item {
        id: boat
        z: 2
        opacity: root.expanded ? 0.88 : 1.0
        width: Math.max(22, root.width * (root.expanded ? 0.30 : 0.38)); height: Math.max(36, root.height * (root.expanded ? 0.52 : 0.66)); anchors.centerIn: parent; anchors.horizontalCenterOffset: root.expanded ? 0 : -14
        rotation: root.normalizedHeading
        Behavior on rotation { RotationAnimation { duration: 260; direction: RotationAnimation.Shortest } }
        NavoBoatVisual { anchors.fill: parent }
    }

    Rectangle {
        visible: isFinite(root.waypointBearingDeg)
        width: 8; height: 22; radius: 4; color:"#ffbf3f"
        anchors.horizontalCenter: parent.horizontalCenter; anchors.top:parent.top; anchors.topMargin:4
        transform: Rotation { origin.x:width/2; origin.y:root.height/2-4; angle: root.waypointBearingDeg }
    }

    Column {
        anchors.centerIn: parent
        visible: root.expanded
        anchors.verticalCenterOffset: root.height * 0.36
        spacing: root.expanded ? 2 : 0
        Label {
            anchors.horizontalCenter:parent.horizontalCenter
            text:root.headingValid ? Math.round(root.normalizedHeading)+"°" : "--"
            color:"white"; font.bold:true
            font.pixelSize:root.expanded ? 13 : Math.max(8,Math.min(12,root.width*0.072))
        }
        Label {
            anchors.horizontalCenter:parent.horizontalCenter
            visible:isFinite(root.courseError)
            text:root.expanded ? "TRASEU  "+(root.courseError<0?"← ":"→ ")+Math.abs(Math.round(root.courseError))+"°" : (root.courseError<0?"← ":"→ ")+Math.abs(Math.round(root.courseError))+"°"
            color:"#ffbf3f"; font.bold:root.expanded
            font.pixelSize:root.expanded ? 11 : Math.max(7,Math.min(10,root.width*0.061))
        }
    }

    ToolTip.visible: mouse.containsMouse
    ToolTip.text: root.headingValid ? "Direcție "+Math.round(root.normalizedHeading)+"° "+root.cardinal+(isFinite(root.courseError)?" • abatere "+Math.round(root.courseError)+"°":"") : "Heading indisponibil"
    MouseArea { id:mouse; anchors.fill:parent; hoverEnabled:true; onClicked: root.toggleRequested() }
}
