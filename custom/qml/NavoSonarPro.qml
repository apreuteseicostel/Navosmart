import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    property var sonar
    property var samples: []
    property bool connected: false
    property real depthM: NaN
    property real waterTempC: NaN
    signal openFullSonar()
    color: "#0b1c2e"
    radius: 10
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10
        RowLayout {
            Layout.fillWidth: true
            Label { text: "SONAR PRO • EXPERIMENTAL"; color: "#21b7ff"; font.bold: true; font.pixelSize: 17 }
            Item { Layout.fillWidth: true }
            Label { text: root.connected ? "LIVE" : "OFFLINE"; color: root.connected ? "#65dca4" : "#f2bd72" }
        }
        NavoSonarCard {
            Layout.fillWidth: true
            Layout.preferredHeight: 190
            connected: root.connected
            depthM: root.depthM
            waterTempC: root.waterTempC
            echoSamples: root.samples
            onOpenFullSonar: root.openFullSonar()
        }
        Label {
            Layout.fillWidth: true
            text: "Mod de test izolat • aceeași conexiune Kogger, fără al doilea client TCP. Procesarea avansată și harta 3D vor fi adăugate separat."
            wrapMode: Text.WordWrap
            color: "#a6bdd0"
        }
        Item { Layout.fillHeight: true }
    }
}
