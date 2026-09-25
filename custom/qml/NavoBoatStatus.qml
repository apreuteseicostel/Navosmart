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
    implicitHeight: compact ? 170 : 220

    Rectangle { anchors.fill: parent; radius: 12; color: "#101820"; border.color: root.waterDetected ? "#ff4d4d" : "#314252" }
    Text { text: "BOAT STATUS"; color: "white"; font.bold: true; anchors.horizontalCenter: parent.horizontalCenter; y: 8 }

    NavoBoatVisual {
        id: boat
        width: root.compact ? 105 : 190
        height: root.compact ? 118 : 165
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: root.compact ? 28 : 30
        leftHopperOpen: root.leftHopperCommandOpen
        rightHopperOpen: root.rightHopperCommandOpen
        headlightOn: root.headlightOn
        positionLightsOn: root.positionLightsOn
        rudderNormalized: root.rudderNormalized
        showLabel: !root.compact
    }

    Column {
        anchors.left:parent.left; anchors.leftMargin:10; anchors.bottom:parent.bottom; anchors.bottomMargin:8; spacing:2
        Text { text:"L: "+root.leftStateText; color:"#dce7ee"; font.pixelSize:root.compact ? 9 : 10 }
        Text { text:"R: "+root.rightStateText; color:"#dce7ee"; font.pixelSize:root.compact ? 9 : 10 }
    }
    Column {
        visible: !root.compact
        anchors.right:parent.right; anchors.rightMargin:10; anchors.bottom:parent.bottom; anchors.bottomMargin:8; spacing:2
        Text { text:"🌡 "+(isNaN(root.batteryTempC) ? "--" : root.batteryTempC.toFixed(1))+" °C"; color:"#dce7ee"; font.pixelSize:10 }
        Text { text:root.waterDetected ? "💧 APĂ DETECTATĂ" : "💧 CORP USCAT"; color:root.waterDetected ? "#ff6666" : "#80e29a"; font.bold:root.waterDetected; font.pixelSize:10 }
    }
}
