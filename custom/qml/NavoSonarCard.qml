import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    property bool connected: false
    property real depthM: NaN
    property real waterTempC: NaN
    property var echoSamples: []
    signal openFullSonar()

    radius: 9
    color: "#06131eee"
    border.color: connected ? "#31d67b" : "#1c4262"
    implicitHeight: 190

    ColumnLayout {
        anchors.fill: parent; anchors.margins: 10; spacing: 6
        RowLayout {
            Layout.fillWidth: true
            Label { text: "KOGGER BASIC 2D+"; color: "white"; font.bold: true }
            Item { Layout.fillWidth: true }
            Label { text: root.connected ? "● LIVE" : "● OFFLINE"; color: root.connected ? "#31d67b" : "#9db2c5" }
            Button { text: "⛶"; Accessible.name: "Mărește sonarul"; onClicked: root.openFullSonar() }
        }
        RowLayout {
            Layout.fillWidth: true
            Label { text: isNaN(root.depthM) ? "-- m" : root.depthM.toFixed(1) + " m"; color: "#21b7ff"; font.pixelSize: 26; font.bold: true }
            Item { Layout.fillWidth: true }
            Label { text: isNaN(root.waterTempC) ? "-- °C" : root.waterTempC.toFixed(1) + " °C"; color: "white"; font.pixelSize: 18; font.bold: true }
        }
        Canvas {
            id: echogram
            Layout.fillWidth: true; Layout.fillHeight: true
            onPaint: {
                var ctx=getContext("2d"); ctx.reset(); ctx.fillStyle="#03101a"; ctx.fillRect(0,0,width,height)
                ctx.strokeStyle="#21b7ff"; ctx.lineWidth=1
                if (root.echoSamples && root.echoSamples.length>1) {
                    ctx.beginPath()
                    for (var i=0;i<root.echoSamples.length;i++) {
                        var x=i*(width/(root.echoSamples.length-1))
                        var y=height-Math.max(0,Math.min(1,root.echoSamples[i]))*height
                        if(i===0) ctx.moveTo(x,y); else ctx.lineTo(x,y)
                    }
                    ctx.stroke()
                }
            }
            Connections { target: root; function onEchoSamplesChanged(){ echogram.requestPaint() } }
        }
    }
}
