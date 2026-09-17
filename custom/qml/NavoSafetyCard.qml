import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    property bool obstacleSensorConnected: false
    property bool motorProtectionConnected: false
    property bool waterAlarm: false
    property bool obstacleAlarm: false
    property bool motorBlockedAlarm: false
    radius: 7; color: "#10273d"; border.color: (waterAlarm||obstacleAlarm||motorBlockedAlarm) ? "#ff3e55" : "#1c4262"
    implicitHeight: grid.implicitHeight + 18
    GridLayout {
        id:grid; anchors.fill: parent; anchors.margins:9; columns:2
        Label { text:"SAFETY"; color:"white"; font.bold:true }
        Label { text:(root.waterAlarm||root.obstacleAlarm||root.motorBlockedAlarm)?"ALARMĂ":"Pregătit"; color:(root.waterAlarm||root.obstacleAlarm||root.motorBlockedAlarm)?"#ff3e55":"#31d67b"; font.bold:true }
        Label { text:"Obstacol"; color:"#9db2c5" }
        Label { text:root.obstacleSensorConnected?(root.obstacleAlarm?"STOP":"OK"):"Viitor"; color:root.obstacleAlarm?"#ff3e55":"white" }
        Label { text:"Motor/elice"; color:"#9db2c5" }
        Label { text:root.motorProtectionConnected?(root.motorBlockedAlarm?"BLOCAT":"OK"):"Viitor"; color:root.motorBlockedAlarm?"#ff3e55":"white" }
        Label { text:"Apă în barcă"; color:"#9db2c5" }
        Label { text:root.waterAlarm?"ALARMĂ":"OK"; color:root.waterAlarm?"#ff3e55":"white" }
    }
}
