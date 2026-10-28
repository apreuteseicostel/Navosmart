import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Read-only cockpit diagnostics. No vehicle commands are sent from this popup.
Popup {
    id: details
    property string section: "battery" // battery | temperature
    property var vehicle: null
    property var battery: null
    property bool linkAlive: false
    property bool temperatureFresh: false
    property real temperatureC: NaN
    property string temperatureSource: "NTC / H743"
    property int viewportWidth: 1280
    property int viewportHeight: 720
    property var temperatureSamples: []
    readonly property color cyan: "#20d9ed"
    readonly property color mint: "#31d6a5"
    readonly property color fg: "#edf8ff"
    readonly property color muted: "#a2bdd0"
    readonly property color line: "#174e68"
    readonly property real batteryPercent: batteryFact("percentRemaining")
    readonly property real voltage: batteryFact("voltage")
    readonly property real current: batteryFact("current")
    readonly property real usedMah: batteryFact("mahConsumed")
    readonly property bool batteryPercentValid: isFinite(batteryPercent) && batteryPercent >= 0 && batteryPercent <= 100

    function batteryFact(key) {
        if (!linkAlive || !battery) return NaN
        var fact = battery[key]
        if (!fact || fact.rawValue === undefined || fact.rawValue === null) return NaN
        var value = Number(fact.rawValue)
        return isFinite(value) ? value : NaN
    }
    function format(value, decimals, suffix) {
        return isFinite(value) ? Number(value).toFixed(decimals) + (suffix || "") : "--"
    }
    function sampleStats() {
        var samples = temperatureSamples
        if (!samples.length) return { min: NaN, max: NaN, avg: NaN }
        var min = Infinity, max = -Infinity, sum = 0
        for (var i = 0; i < samples.length; ++i) {
            min = Math.min(min, samples[i].v)
            max = Math.max(max, samples[i].v)
            sum += samples[i].v
        }
        return { min: min, max: max, avg: sum / samples.length }
    }
    function showSection(which) {
        if(which!=="battery" && which!=="temperature")return false
        section = which
        open()
        return true
    }
    onVehicleChanged: temperatureSamples = []
    Timer {
        interval: 10000
        repeat: true
        triggeredOnStart: true
        running: details.linkAlive
        onTriggered: {
            // Only actual fresh H743 samples; never generate a fake temperature curve.
            if (!details.temperatureFresh || !isFinite(details.temperatureC)) return
            var t = Date.now()
            var history = details.temperatureSamples.filter(function(sample) { return sample.t >= t - 3600000 })
            history.push({t: t, v: Number(details.temperatureC)})
            details.temperatureSamples = history.slice(-360)
        }
    }

    parent: Overlay.overlay
    modal: false
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    width: Math.min(section === "temperature" ? 640 : 530, Math.max(260, viewportWidth - 28))
    height: Math.min(section === "temperature" ? 490 : 460, Math.max(245, viewportHeight - 28))
    x: Math.max(8, (viewportWidth - width) / 2)
    y: Math.max(8, (viewportHeight - height) / 2)
    padding: 16
    z: 6900
    background: Rectangle {
        radius: 15
        color: "#071926"
        border.color: details.cyan
        border.width: 1.5
    }

    component DetailRow: RowLayout {
        property string caption: ""
        property string amount: "--"
        property color amountColor: details.fg
        Layout.fillWidth: true
        Layout.preferredHeight: 29
        spacing: 8
        Label { text: parent.caption; color: details.muted; font.pixelSize: 12; Layout.fillWidth: true; elide: Text.ElideRight }
        Label { text: parent.amount; color: parent.amountColor; font.pixelSize: 13; font.bold: true }
    }
    component StatChip: Rectangle {
        property string caption: ""
        property string amount: "--"
        Layout.fillWidth: true
        Layout.preferredHeight: 59
        color: "#0c2837"
        radius: 9
        border.color: details.line
        Column {
            anchors.centerIn: parent
            spacing: 4
            Label { anchors.horizontalCenter: parent.horizontalCenter; text: parent.parent.caption; color: details.muted; font.pixelSize: 10 }
            Label { anchors.horizontalCenter: parent.horizontalCenter; text: parent.parent.amount; color: details.fg; font.bold: true; font.pixelSize: 16 }
        }
    }

    Flickable {
        id: scrollBody
        anchors.fill: parent
        contentWidth: width
        contentHeight: allSections.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        ColumnLayout {
            id: allSections
            width: scrollBody.width - 4
            spacing: 11
            RowLayout {
                Layout.fillWidth: true
                spacing: 9
                Image {
                    source: details.section === "battery" ? "qrc:/qml/NavoSmart/icons/battery.svg"
                           : "qrc:/qml/NavoSmart/icons/temp.svg"
                    Layout.preferredWidth: 25
                    Layout.preferredHeight: 25
                    fillMode: Image.PreserveAspectFit
                }
                Label {
                    Layout.fillWidth: true
                    text: details.section === "battery" ? "Baterie • Diagnostic"
                        : "Temperatură • Grafic"
                    color: details.fg
                    font.pixelSize: 19
                    font.bold: true
                    elide: Text.ElideRight
                }
                Button {
                    id: detailsCloseButton
                    Accessible.name: "Închide diagnosticul"
                    Layout.minimumWidth: 44
                    Layout.minimumHeight: 44
                    implicitWidth: 44
                    implicitHeight: 44
                    padding: 0
                    onClicked: details.close()
                    background: Rectangle {
                        radius: 9
                        color: detailsCloseButton.down ? "#20536a" : "#103044"
                        border.color: "#20d9ed"
                        border.width: 1.5
                    }
                    // Vector icon stays visible even when Android lacks the Unicode cross glyph.
                    contentItem: Item {
                        Image {
                            anchors.centerIn: parent
                            width: 24
                            height: 24
                            source: "qrc:/qml/NavoSmart/icons/close.svg"
                            fillMode: Image.PreserveAspectFit
                        }
                    }
                }
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: details.line }

            ColumnLayout {
                visible: details.section === "battery"
                Layout.fillWidth: true
                spacing: 10
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 75
                    radius: 11; color: "#0c2735"; border.color: details.line
                    RowLayout {
                        anchors.fill: parent; anchors.margins: 12; spacing: 13
                        Image { source: "qrc:/qml/NavoSmart/icons/battery.svg"; Layout.preferredWidth: 34; Layout.preferredHeight: 34 }
                        ColumnLayout {
                            spacing: 3
                            Label { text: "BATERIA PRINCIPALĂ • 4S"; color: details.muted; font.pixelSize: 10 }
                            Label { text: details.batteryPercentValid ? details.format(details.batteryPercent, 0, "%") : "--"; color: details.batteryPercentValid && details.batteryPercent > 20 ? details.mint : "#ffd166"; font.pixelSize: 29; font.bold: true }
                        }
                        Item { Layout.fillWidth: true }
                        Label { text: details.linkAlive && details.battery ? "DATE MAVLink" : "FĂRĂ TELEMETRIE"; color: details.linkAlive && details.battery ? details.mint : "#ffd166"; font.pixelSize: 11; font.bold: true }
                    }
                }
                DetailRow { caption: "Tensiune pachet"; amount: details.format(details.voltage, 2, " V") }
                Rectangle { Layout.fillWidth: true; height: 1; color: details.line }
                DetailRow { caption: "Tensiune medie / celulă (4S, calculată)"; amount: details.voltage >= 8 && details.voltage <= 17 ? details.format(details.voltage / 4, 2, " V") : "--" }
                Rectangle { Layout.fillWidth: true; height: 1; color: details.line }
                DetailRow { caption: "Curent raportat"; amount: details.format(details.current, 2, " A") }
                Rectangle { Layout.fillWidth: true; height: 1; color: details.line }
                DetailRow { caption: "Putere estimată V × A"; amount: isFinite(details.voltage) && isFinite(details.current) ? details.format(details.voltage * details.current, 1, " W") : "--" }
                Rectangle { Layout.fillWidth: true; height: 1; color: details.line }
                DetailRow { caption: "Capacitate consumată (MAVLink)"; amount: details.format(details.usedMah, 0, " mAh") }
                Rectangle { Layout.fillWidth: true; height: 1; color: details.line }
                DetailRow { caption: "Stare BMS / echilibrare celule"; amount: "Neraportată" }
                Rectangle { Layout.fillWidth: true; height: 1; color: details.line }
                DetailRow { caption: "Autonomie calculată"; amount: "Necesită calibrare" }
                Label {
                    Layout.fillWidth: true
                    text: "Nu deducem sănătatea bateriei sau tensiunile celulelor din procent. Datele lipsă rămân --."
                    color: details.muted; font.pixelSize: 11; wrapMode: Text.WordWrap
                }
            }

            ColumnLayout {
                visible: details.section === "temperature"
                Layout.fillWidth: true
                spacing: 11
                RowLayout {
                    Layout.fillWidth: true; spacing: 7
                    StatChip { caption: "ACTUAL"; amount: details.temperatureFresh ? details.format(details.temperatureC, 1, " °C") : "--" }
                    StatChip { caption: "MINIM"; amount: details.format(details.sampleStats().min, 1, " °C") }
                    StatChip { caption: "MAXIM"; amount: details.format(details.sampleStats().max, 1, " °C") }
                    StatChip { caption: "MEDIE"; amount: details.format(details.sampleStats().avg, 1, " °C") }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Label { Layout.fillWidth: true; text: details.temperatureSource + " • ultimele 60 min (sesiunea curentă)"; color: details.muted; font.pixelSize: 11; wrapMode: Text.WordWrap }
                    Label { text: details.temperatureFresh ? "● LIVE" : "● FĂRĂ DATE NOI"; color: details.temperatureFresh ? details.mint : "#ffd166"; font.pixelSize: 10 }
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 230
                    color: "#081e2b"
                    radius: 10
                    border.color: details.line
                    Canvas {
                        id: tempChart
                        anchors.fill: parent; anchors.margins: 7
                        onWidthChanged: requestPaint()
                        onHeightChanged: requestPaint()
                        Connections { target: details; function onTemperatureSamplesChanged() { tempChart.requestPaint() } }
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            var samples = details.temperatureSamples
                            var left = 39, right = Math.max(left + 5, width - 12)
                            var top = 15, bottom = Math.max(top + 5, height - 27)
                            var ymin = 0, ymax = 1
                            if (samples.length) {
                                ymin = Infinity; ymax = -Infinity
                                for (var i = 0; i < samples.length; i++) {
                                    ymin = Math.min(ymin, samples[i].v)
                                    ymax = Math.max(ymax, samples[i].v)
                                }
                                ymin = Math.floor((ymin - 0.8) * 2) / 2
                                ymax = Math.ceil((ymax + 0.8) * 2) / 2
                            }
                            ctx.font = "10px sans-serif"
                            for (var k = 0; k <= 4; k++) {
                                var y = top + (bottom - top) * k / 4
                                ctx.strokeStyle = "#1a4053"
                                ctx.beginPath(); ctx.moveTo(left, y); ctx.lineTo(right, y); ctx.stroke()
                                ctx.fillStyle = "#8fb0c1"
                                ctx.fillText((ymax - (ymax - ymin) * k / 4).toFixed(1), 1, y + 3)
                            }
                            ctx.fillStyle = "#8fb0c1"
                            ctx.fillText("-60m", left, height - 8)
                            ctx.fillText("acum", right - 26, height - 8)
                            if (samples.length === 0) return
                            var now = Date.now(), begin = now - 3600000
                            ctx.strokeStyle = "#20d9ed"
                            ctx.lineWidth = 2
                            ctx.beginPath()
                            for (var n = 0; n < samples.length; n++) {
                                var px = left + Math.max(0, Math.min(1, (samples[n].t - begin) / 3600000)) * (right - left)
                                var py = bottom - (samples[n].v - ymin) / (ymax - ymin) * (bottom - top)
                                if (n === 0) ctx.moveTo(px, py); else ctx.lineTo(px, py)
                            }
                            if (samples.length === 1) ctx.lineTo(left + 1, bottom - (samples[0].v - ymin) / (ymax - ymin) * (bottom - top))
                            ctx.stroke()
                        }
                    }
                    Label {
                        visible: details.temperatureSamples.length === 0
                        anchors.centerIn: parent
                        width: parent.width - 30
                        text: "Graficul va începe după primirea unei temperaturi valide de la H743."
                        color: details.muted; wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignHCenter
                        font.pixelSize: 12
                    }
                }
                Label {
                    text: "Istoric doar cât aplicația este deschisă. Nu folosim valori simulate sau citiri expirate."
                    color: details.muted; font.pixelSize: 11; Layout.fillWidth: true; wrapMode: Text.WordWrap
                }
            }


        }
    }
}

