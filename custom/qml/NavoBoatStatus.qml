import QtQuick
import QtQuick.Controls

Item {
    id: root
    property bool leftHopperCommandOpen: false
    property bool rightHopperCommandOpen: false
    property bool waterDetected: false
    property real batteryTempC: NaN
    property bool headlightOn: false
    property bool positionLightsOn: false
    property real rudderNormalized: 0
    property bool compact: false
    property bool confirmedLeftOpen: false
    property bool confirmedRightOpen: false
    property string leftStateText: leftHopperCommandOpen ? "COMANDATĂ DESCHISĂ" : "COMANDATĂ ÎNCHISĂ"
    property string rightStateText: rightHopperCommandOpen ? "COMANDATĂ DESCHISĂ" : "COMANDATĂ ÎNCHISĂ"

    implicitWidth: compact ? 150 : 320
    implicitHeight: compact ? 105 : 220

    Rectangle { anchors.fill: parent; radius: 12; color: "#101820"; border.color: root.waterDetected ? "#ff4d4d" : "#314252" }
    Text { text: "BOAT STATUS"; color: "white"; font.bold: true; anchors.horizontalCenter: parent.horizontalCenter; y: 8 }

    Item {
        id: boat
        width: 170; height: 150
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top; anchors.topMargin: 34

        Rectangle {
            anchors.centerIn: parent; width: 142; height: 138; radius: 50
            color: "#253442"; border.color: "#73899c"; border.width: 2
        }
        Rectangle {
            id:leftHopper; width:54; height:70; x:24; y:35; radius:7
            color:"#17232d"; border.color:"#5d7283"
            transform: Rotation { origin.x:0; origin.y:leftHopper.height; angle:root.leftHopperCommandOpen ? -32 : 0
                Behavior on angle { NumberAnimation { duration:350; easing.type:Easing.InOutQuad } } }
            Text { anchors.centerIn:parent; text:"L"; color:"white"; font.bold:true }
        }
        Rectangle {
            id:rightHopper; width:54; height:70; x:92; y:35; radius:7
            color:"#17232d"; border.color:"#5d7283"
            transform: Rotation { origin.x:rightHopper.width; origin.y:rightHopper.height; angle:root.rightHopperCommandOpen ? 32 : 0
                Behavior on angle { NumberAnimation { duration:350; easing.type:Easing.InOutQuad } } }
            Text { anchors.centerIn:parent; text:"R"; color:"white"; font.bold:true }
        }
        Rectangle {
            width:6;height:26;radius:3;x:82;y:122;color:"#9db0bd"
            transform: Rotation { origin.x:3; origin.y:0; angle:Math.max(-1,Math.min(1,root.rudderNormalized))*35
                Behavior on angle { NumberAnimation { duration:150 } } }
        }
        Rectangle { width:16;height:5;radius:2;x:77;y:3;color:root.headlightOn ? "#fff6a8" : "#52616c" }
        Rectangle { width:7;height:7;radius:4;x:28;y:115;color:root.positionLightsOn ? "#e9f6ff" : "#52616c" }
        Rectangle { width:7;height:7;radius:4;x:135;y:115;color:root.positionLightsOn ? "#e9f6ff" : "#52616c" }
    }

    Column {
        anchors.left:parent.left; anchors.leftMargin:10; anchors.bottom:parent.bottom; anchors.bottomMargin:8; spacing:2
        Text { text:"L: "+root.leftStateText; color:"#dce7ee"; font.pixelSize:root.compact ? 7 : 10 }
        Text { text:"R: "+root.rightStateText; color:"#dce7ee"; font.pixelSize:root.compact ? 7 : 10 }
    }
    Column {
        anchors.right:parent.right; anchors.rightMargin:10; anchors.bottom:parent.bottom; anchors.bottomMargin:8; spacing:2
        Text { text:"🌡 "+(isNaN(root.batteryTempC) ? "--" : root.batteryTempC.toFixed(1))+" °C"; color:"#dce7ee"; font.pixelSize:10 }
        Text { text:root.waterDetected ? "💧 APĂ DETECTATĂ" : "💧 CORP USCAT"; color:root.waterDetected ? "#ff6666" : "#80e29a"; font.bold:root.waterDetected; font.pixelSize:10 }
    }
}
