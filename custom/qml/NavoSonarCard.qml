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
        }
        RowLayout {
            Layout.fillWidth: true
            Label { text: isNaN(root.depthM) ? "-- m" : root.depthM.toFixed(1) + " m"; color: "#21b7ff"; font.pixelSize: 26; font.bold: true }
            Item { Layout.fillWidth: true }
            Label { text: isNaN(root.waterTempC) ? "-- °C" : root.waterTempC.toFixed(1) + " °C"; color: "white"; font.pixelSize: 18; font.bold: true }
        }
        NavoEchogram { id: echogram; Layout.fillWidth: true; Layout.fillHeight: true; ping: root.echoSamples; live: root.connected; maxColumns: 100 }
        Button { Layout.alignment: Qt.AlignRight; text: "SONAR COMPLET"; onClicked: root.openFullSonar() }
    }
}
