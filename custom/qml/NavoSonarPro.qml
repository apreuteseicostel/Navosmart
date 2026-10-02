import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    property int chartResolution: 0
    property int chartAbsoluteOffset: 0
    property int chartVersion: 0
    property int chartRawByteCount: 0
    property real chartResolutionMeters: NaN
    property real chartOffsetMeters: NaN
    property real chartRangeMeters: NaN
    property var samples: []
    property bool connected: false
    property real depthM: NaN
    property real waterTempC: NaN
    property real gain: 1.0
    property real noiseFloor: 0.10
    property bool bottomTrackEnabled: true
    // Experimental bottom peak tracker; calibrated physical hardness is NOT inferred.
    readonly property var bottomResult: {
        if (!bottomTrackEnabled || !samples || samples.length < 8)
            return ({ index: -1, strength: NaN, confidence: 0 })
        var n = samples.length
        var start = Math.max(1, Math.floor(n * 0.25))
        var end = n - 2
        var best = -1
        var bestScore = 0
        var second = 0
        for (var i = start; i <= end; ++i) {
            var left = Number(samples[i - 1])
            var center = Number(samples[i])
            var right = Number(samples[i + 1])
            if (!isFinite(left) || !isFinite(center) || !isFinite(right)) continue
            var score = Math.max(0, (left + 2 * center + right) / 4 - noiseFloor)
            if (score > bestScore) { second = bestScore; bestScore = score; best = i }
            else if (score > second) second = score
        }
        if (best < 0 || bestScore <= 0)
            return ({ index: -1, strength: NaN, confidence: 0 })
        return ({ index: best, strength: Math.min(1, bestScore * gain),
                  confidence: Math.max(0, Math.min(1, (bestScore - second) / Math.max(bestScore, 0.001))) })
    }
    readonly property real bottomEcho: bottomResult.strength
    readonly property real bottomDepthEstimate: bottomResult.index >= 0 && isFinite(depthM)
        ? depthM * bottomResult.index / Math.max(1, samples.length - 1) : NaN
    signal openFullSonar()
    onOpenFullSonar: proFullscreen.open()
    Popup {
        id: proFullscreen
        parent: Overlay.overlay
        modal: true
        focus: true
        padding: 12
        x: 0
        y: 0
        width: parent ? parent.width : root.width
        height: parent ? parent.height : root.height
        background: Rectangle { color: "#0b1c2e" }
        ColumnLayout {
            anchors.fill: parent
            spacing: 8
            RowLayout {
                Layout.fillWidth: true
                Label { text: "SONAR PRO • FULLSCREEN"; color: "#21b7ff"; font.bold: true; font.pixelSize: 18 }
                Item { Layout.fillWidth: true }
                Label { text: root.connected ? "LIVE" : "OFFLINE"; color: root.connected ? "#65dca4" : "#f2bd72" }
                Button { text: "✕"; accessible.name: "Închide Sonar PRO fullscreen"; onClicked: proFullscreen.close() }
            }
            NavoSonarCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                connected: root.connected
                depthM: root.depthM
                waterTempC: root.waterTempC
                echoSamples: root.samples
                onOpenFullSonar: proFullscreen.close()
            }
            Label {
                Layout.fillWidth: true
                color: "#a6bdd0"
                text: root.samples.length > 0
                    ? "CHART v" + root.chartVersion + " • " + root.samples.length + " eșantioane • Ecou relativ: " + (isNaN(root.bottomEcho) ? "—" : Math.round(root.bottomEcho * 100) + "%")
                    : "CHART: aștept date valide"
            }
        }
    }
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
            color: "#a6bdd0"
            font.pixelSize: 13
            wrapMode: Text.WordWrap
            text: root.samples.length > 0 && root.chartResolution > 0
                ? "CHART v" + root.chartVersion + " • scală " + root.chartResolutionMeters.toFixed(3) + " m/eșantion"
                  + " • offset " + root.chartOffsetMeters.toFixed(3) + " m • lungime " + root.chartRangeMeters.toFixed(2) + " m\n"
                  + "Raw: " + root.chartRawByteCount + " B • " + root.samples.length + " eșantioane/canal"
                  + " • " + (root.chartVersion === 1 ? "2 canale" : "1 canal")
                  + " • rezoluție " + root.chartResolution + " mm • offset " + root.chartAbsoluteOffset + " eșantioane"
                : "CHART: aștept date valide"
        }
        RowLayout {
            Layout.fillWidth: true
            CheckBox { text: "Bottom Track"; checked: root.bottomTrackEnabled; onToggled: root.bottomTrackEnabled = checked }
            Label { text: isNaN(root.bottomEcho) ? "Ecou: —" : "Ecou relativ: " + Math.round(root.bottomEcho * 100) + "%"; color: "#a6bdd0" }
        }
        Label { Layout.fillWidth: true; color: "#a6bdd0"; text: root.bottomResult.index < 0 ? "Profil fund: indisponibil" : "Vârf ecou: eșantion " + root.bottomResult.index + " / " + root.samples.length + " • încredere relativă " + Math.round(root.bottomResult.confidence * 100) + "%" }
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
