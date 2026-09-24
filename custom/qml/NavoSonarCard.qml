import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    property bool connected: false
    property real depthM: NaN
    property real waterTempC: NaN
    property var echoSamples: []
    property var history: []
    property int historyColumns: 80
    function pushHistory(){ if(!echoSamples||!echoSamples.length)return; var h=history.slice(0); h.push(echoSamples.slice(0)); while(h.length>historyColumns)h.shift(); history=h }
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
            Button {
                width: 30; height: 30; padding: 0; flat: true
                Accessible.name: "Mărește sonarul"
                ToolTip.visible: hovered; ToolTip.text: "Mărește sonarul"
                contentItem: Label {
                    text: "↗"; color: "#d7e3ee"; font.pixelSize: 20; font.bold: true
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle { color: "transparent"; border.color: "#31536c"; radius: 5 }
                onClicked: root.openFullSonar()
            }
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
                if(root.history&&root.history.length){var cw=width/root.historyColumns;for(var hx=0;hx<root.history.length;hx++){var col=root.history[hx],px=width-(root.history.length-hx)*cw;for(var hy=0;hy<col.length;hy++){var v=Math.max(0,Math.min(1,Number(col[hy])));if(v<.08)continue;ctx.fillStyle=v>.72?"#f44b2e":v>.48?"#f6da46":v>.24?"#1ccde1":"#105caa";ctx.fillRect(px,hy*height/col.length,Math.max(1,cw+0.5),Math.max(1,height/col.length+0.5))}}}
            }
            Connections { target: root; function onEchoSamplesChanged(){ root.pushHistory(); echogram.requestPaint() } }
        }
    }
}
