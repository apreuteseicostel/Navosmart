import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import NavoSmart.Backend 1.0

// Experiment B only: Kogger Epoch plot with transient side controls.
// This page owns no H743/MAVLink commands. Sonar PRO is untouched.
Rectangle {
    id: root
    objectName: "navoKoggerSonarExperimentB"
    color: "#050d17"

    property var chartSource: null
    property int selectedEpoch: -1
    property real selectedDepthM: NaN
    property bool dragToPan: false
    // Each overlay has its own visibility state, timer and reveal tab.
    property bool leftPanelVisible: true
    property bool rightPanelVisible: true
    property bool timelineVisible: true
    readonly property bool replayReady: !!(chartSource && chartSource.replayMode)
    readonly property string statusText: replayReady
        ? (plot.fileReady ? "KLF • " + plot.indexedColumns + " Epoch"
           : (chartSource.replayError && chartSource.replayError.length
              ? chartSource.replayError : "Indexare KLF…"))
        : (chartSource && chartSource.connected ? "LIVE • Kogger Dataset" : "Sonar neconectat")
    signal closed()

    // Reusable Kogger-style dark compact button, with visible press feedback.
    component SonarRailButton: Button {
        font.pixelSize: 11
        background: Rectangle {
            radius: 5
            color: parent.down ? "#215b72" : parent.hovered ? "#194257" : "#102b3d"
            border.color: parent.enabled ? "#407087" : "#263e4b"
            border.width: 1
        }
        contentItem: Text {
            text: parent.text
            color: parent.enabled ? "#e4f5fc" : "#668396"
            font: parent.font
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
    }

    function revealLeftPanel() {
        leftPanelVisible = true
        leftAutoHide.restart()
    }
    function revealRightPanel() {
        rightPanelVisible = true
        rightAutoHide.restart()
    }
    function revealTimeline() {
        timelineVisible = true
        timelineAutoHide.restart()
    }
    function toggleLeftPanel() {
        leftPanelVisible = !leftPanelVisible
        if (leftPanelVisible) leftAutoHide.restart()
        else leftAutoHide.stop()
    }
    function toggleRightPanel() {
        rightPanelVisible = !rightPanelVisible
        if (rightPanelVisible) rightAutoHide.restart()
        else rightAutoHide.stop()
    }
    function toggleTimeline() {
        timelineVisible = !timelineVisible
        if (timelineVisible) timelineAutoHide.restart()
        else timelineAutoHide.stop()
    }
    function changeDepth(direction) {
        var options = [2, 3, 5, 10, 20, 50, 100, 200]
        var index = options.indexOf(Math.round(plot.depthRange))
        if (index < 0) index = 5
        plot.depthRange = options[Math.max(0, Math.min(options.length - 1, index + direction))]
        revealLeftPanel()
    }
    function cursorPixel() {
        var n = plot.indexedColumns
        if (selectedEpoch <= 0 || n <= 0 || plot.width <= 0) return -1
        var count = Math.max(1, Math.min(n, Math.ceil(n / plot.horizontalZoom)))
        var center = Math.max(0, Math.min(n - 1, Math.round(plot.position * (n - 1))))
        var begin = Math.max(0, Math.min(n - count, center - Math.floor(count / 2)))
        var idx = selectedEpoch - 1
        if (idx < begin || idx >= begin + count) return -1
        return ((idx - begin + 0.5) / count) * plot.width
    }

    Timer {
        id: leftAutoHide
        interval: 4500
        repeat: false
        running: true
        onTriggered: {
            if (chooser.visible) restart()
            else root.leftPanelVisible = false
        }
    }
    Timer {
        id: rightAutoHide
        interval: 4500
        repeat: false
        running: true
        onTriggered: root.rightPanelVisible = false
    }
    Timer {
        id: timelineAutoHide
        interval: 4500
        repeat: false
        running: true
        onTriggered: {
            if (timeline.pressed) restart()
            else root.timelineVisible = false
        }
    }

    FileDialog {
        id: chooser
        title: "Deschide înregistrare Kogger .klf"
        nameFilters: ["Kogger recording (*.klf)", "Toate fișierele (*)"]
        onAccepted: {
            if (!root.chartSource) return
            root.selectedEpoch = -1
            root.selectedDepthM = NaN
            if (root.chartSource.startReplay(selectedFile))
                root.chartSource.pauseReplay(true)
            root.revealLeftPanel()
        }
        onRejected: root.revealLeftPanel()
    }

    NavoKoggerEpochPlotItem {
        id: plot
        objectName: "koggerNativeOriginalEpochViewB"
        anchors.fill: parent
        fileReplay: root.replayReady ? root.chartSource.replay : null
        depthRange: 10
        horizontalZoom: 1
        position: 0.5
    }
    MouseArea {
        id: sonarTouch
        anchors.fill: plot
        z: 1
        acceptedButtons: Qt.LeftButton
        property real dragStartX: 0
        property real dragStartPosition: 0
        function inspect(mouse) {
            var hit = plot.inspectAt(mouse.x, mouse.y)
            root.selectedEpoch = hit.epoch === undefined ? -1 : Number(hit.epoch)
            root.selectedDepthM = hit.depthM === undefined ? NaN : Number(hit.depthM)
        }
        onPressed: function(mouse) {
            dragStartX = mouse.x
            dragStartPosition = plot.position
            if (!root.dragToPan) inspect(mouse)
        }
        onPositionChanged: function(mouse) {
            if (!pressed) return
            if (root.dragToPan) {
                plot.position = Math.max(0, Math.min(1,
                    dragStartPosition - (mouse.x - dragStartX) / Math.max(1, width) / plot.horizontalZoom))
            } else inspect(mouse)
        }
        onClicked: function(mouse) { if (!root.dragToPan) inspect(mouse) }
    }
    Rectangle {
        id: cursor
        z: 2
        visible: !root.dragToPan && root.selectedEpoch > 0 && root.cursorPixel() >= 0
        width: 1
        height: parent.height
        x: root.cursorPixel()
        color: "#fbc04d"
        opacity: .8
    }

    // A single compact status overlay replaces the two permanent toolbar rows.
    Rectangle {
        id: statusBar
        objectName: "koggerBCompactStatus"
        z: 5
        visible: root.leftPanelVisible || root.rightPanelVisible || root.timelineVisible
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 34
        anchors.rightMargin: 34
        height: 27
        radius: 5
        color: "#d9091a28"
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 7
            anchors.rightMargin: 7
            spacing: 6
            Label {
                text: "KOGGER B"
                color: "#eafaff"
                font.pixelSize: 11
                font.bold: true
            }
            Label {
                text: root.statusText
                color: "#a9cada"
                font.pixelSize: 10
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            Label {
                visible: root.selectedEpoch > 0 && isFinite(root.selectedDepthM)
                text: root.selectedEpoch + " • " + root.selectedDepthM.toFixed(2) + " m"
                color: "#e8edf7"
                font.pixelSize: 10
            }
        }
    }

    Rectangle {
        id: leftPanel
        objectName: "koggerBLeftRail"
        z: 5
        visible: root.leftPanelVisible
        width: 116
        height: Math.min(214, parent.height - 45)
        anchors.left: parent.left
        anchors.leftMargin: 29
        anchors.top: parent.top
        anchors.topMargin: 32
        radius: 7
        color: "#df071827"
        border.color: "#31536c"
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 5
            spacing: 3
            SonarRailButton {
                text: "DESCHIDE KLF"
                Layout.fillWidth: true
                Layout.preferredHeight: 31
                onClicked: { root.revealLeftPanel(); chooser.open() }
            }
            SonarRailButton {
                text: root.replayReady ? "OPREȘTE" : "LIVE"
                enabled: root.replayReady
                Layout.fillWidth: true
                Layout.preferredHeight: 29
                onClicked: { root.chartSource.stopReplay(); root.revealLeftPanel() }
            }
            Label {
                text: "ZOOM  " + plot.horizontalZoom + "×"
                color: "#aed4e4"
                font.pixelSize: 11
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 3
                SonarRailButton {
                    text: "−"
                    Layout.fillWidth: true
                    Layout.preferredHeight: 29
                    onClicked: { plot.horizontalZoom = Math.max(1, Math.floor(plot.horizontalZoom / 2)); root.revealLeftPanel() }
                }
                SonarRailButton {
                    text: "+"
                    Layout.fillWidth: true
                    Layout.preferredHeight: 29
                    onClicked: { plot.horizontalZoom = Math.min(64, plot.horizontalZoom * 2); root.revealLeftPanel() }
                }
            }
            SonarRailButton {
                text: "TOT • 1×"
                Layout.fillWidth: true
                Layout.preferredHeight: 29
                onClicked: { plot.horizontalZoom = 1; plot.position = 0.5; root.revealLeftPanel() }
            }
            Label {
                text: "SCARĂ  " + Math.round(plot.depthRange) + " m"
                color: "#aed4e4"
                font.pixelSize: 11
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 3
                SonarRailButton {
                    text: "−"
                    Layout.fillWidth: true
                    Layout.preferredHeight: 29
                    onClicked: root.changeDepth(-1)
                }
                SonarRailButton {
                    text: "+"
                    Layout.fillWidth: true
                    Layout.preferredHeight: 29
                    onClicked: root.changeDepth(1)
                }
            }
        }
    }

    Rectangle {
        id: rightPanel
        objectName: "koggerBRightRail"
        z: 5
        visible: root.rightPanelVisible
        width: 110
        height: Math.min(162, parent.height - 45)
        anchors.right: parent.right
        anchors.rightMargin: 29
        anchors.top: parent.top
        anchors.topMargin: 32
        radius: 7
        color: "#df071827"
        border.color: "#31536c"
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 5
            spacing: 3
            SonarRailButton {
                text: ["CLASSIC", "ICE", "SEPIA"][plot.palette]
                Layout.fillWidth: true
                Layout.preferredHeight: 31
                onClicked: { plot.palette = (plot.palette + 1) % 3; root.revealRightPanel() }
            }
            SonarRailButton {
                text: plot.compensate ? "COMPENSAT" : "BRUT"
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                onClicked: { plot.compensate = !plot.compensate; root.revealRightPanel() }
            }
            SonarRailButton {
                text: root.dragToPan ? "PAN" : "INSPECTOR"
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                onClicked: { root.dragToPan = !root.dragToPan; root.revealRightPanel() }
            }
            SonarRailButton {
                text: "IEȘIRE"
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                onClicked: root.closed()
            }
        }
    }

    // Narrow side tabs remain visible even when panels have disappeared.
    SonarRailButton {
        id: leftHandle
        objectName: "koggerBLeftRevealTab"
        z: 8
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 27
        height: 44
        text: root.leftPanelVisible ? "‹" : "›"
        Accessible.name: root.leftPanelVisible ? "Ascunde meniul stâng Kogger" : "Deschide meniul stâng Kogger"
        onClicked: root.toggleLeftPanel()
    }
    SonarRailButton {
        id: rightHandle
        objectName: "koggerBRightRevealTab"
        z: 8
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 27
        height: 44
        text: root.rightPanelVisible ? "›" : "‹"
        Accessible.name: root.rightPanelVisible ? "Ascunde meniul drept Kogger" : "Deschide meniul drept Kogger"
        onClicked: root.toggleRightPanel()
    }

    Rectangle {
        id: timelineBar
        objectName: "koggerBCompactTimeline"
        z: 5
        visible: root.timelineVisible && plot.fileReady
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 34
        anchors.rightMargin: 34
        anchors.bottomMargin: 3
        height: 32
        radius: 6
        color: "#e5081828"
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 9
            anchors.rightMargin: 9
            spacing: 7
            Label {
                text: plot.horizontalZoom + "×"
                color: "#c9e3ef"
                font.pixelSize: 11
            }
            Slider {
                id: timeline
                objectName: "koggerFileTimelineB"
                Layout.fillWidth: true
                from: 0
                to: 1
                value: plot.position
                enabled: plot.fileReady && plot.indexedColumns > 1
                onMoved: { plot.position = value; root.revealTimeline() }
                Accessible.name: "Explorează fișierul Kogger fără a muta replay-ul"
            }
            Label {
                text: plot.indexedColumns > 0
                    ? Math.round(plot.position * (plot.indexedColumns - 1) + 1) + "/" + plot.indexedColumns
                    : "0/0"
                color: "#e2f3fb"
                font.pixelSize: 11
                Layout.preferredWidth: 85
                horizontalAlignment: Text.AlignRight
            }
        }
    }
    // Bottom reveal tab is independent of both side rails.
    SonarRailButton {
        id: timelineHandle
        objectName: "koggerBTimelineRevealTab"
        z: 8
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.timelineVisible && plot.fileReady ? 36 : 1
        width: 72
        height: 24
        enabled: plot.fileReady
        text: root.timelineVisible && plot.fileReady ? "CURSOR  ⌄" : "CURSOR  ⌃"
        Accessible.name: root.timelineVisible && plot.fileReady
            ? "Ascunde sliderul Kogger" : "Deschide sliderul Kogger"
        onClicked: root.toggleTimeline()
    }
}
