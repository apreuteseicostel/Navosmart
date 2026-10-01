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
    property real gain: 1.0
    property real noiseFloor: 0.10
    property bool bottomTrackEnabled: true
    readonly property real bottomEcho: {
        if (!bottomTrackEnabled || !samples || samples.length === 0) return NaN
        var start = Math.floor(samples.length * 0.9)
        var sum = 0
        var count = 0
        for (var i = start; i < samples.length; ++i) {
            var v = Number(samples[i])
            if (isFinite(v)) { sum += v; count++ }
        }
        return count ? Math.max(0, Math.min(1, (sum / count - noiseFloor) * gain)) : NaN
    }
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
        RowLayout {
            Layout.fillWidth: true
            CheckBox { text: "Bottom Track"; checked: root.bottomTrackEnabled; onToggled: root.bottomTrackEnabled = checked }
            Label { text: isNaN(root.bottomEcho) ? "Ecou: —" : "Ecou relativ: " + Math.round(root.bottomEcho * 100) + "%"; color: "#a6bdd0" }
        }
        RowLayout {
            Layout.fillWidth: true
            Label { text: "Sensibilitate"; color: "#a6bdd0" }
            Slider { Layout.fillWidth: true; from: 0.5; to: 3; value: root.gain; onMoved: root.gain = value }
            Label { text: root.gain.toFixed(1) + "×"; color: "white" }
        }
        RowLayout {
            Layout.fillWidth: true
            Label { text: "Zgomot"; color: "#a6bdd0" }
            Slider { Layout.fillWidth: true; from: 0; to: 0.5; value: root.noiseFloor; onMoved: root.noiseFloor = value }
            Label { text: Math.round(root.noiseFloor * 100) + "%"; color: "white" }
        }
        Label {
            Layout.fillWidth: true
            text: "Mod de test izolat • aceeași conexiune Kogger, fără al doilea client TCP. Ecoul este relativ, nu o măsurătoare calibrată a durității."
            wrapMode: Text.WordWrap
            color: "#a6bdd0"
        }
        Item { Layout.fillHeight: true }
    }
}
