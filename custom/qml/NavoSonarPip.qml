import QtQuick
import QtQuick.Controls
import NavoSmart.Backend 1.0

// Lightweight sonar picture-in-picture: a view of the shared controller.
// The PiP creates neither a second network connection nor a second decoder.
Rectangle {
    id: root
    objectName: "navoSonarDashboardPip"
    property var sonar: null
    signal closeRequested()

    readonly property bool live: !!(sonar && sonar.dataAlive)
    readonly property bool replay: !!(sonar && sonar.replayMode)
    readonly property bool ready: live || replay
    width: 205
    height: 137
    radius: 9
    clip: true
    color: "#04101a"
    border.width: 1
    border.color: live ? "#2bcc91" : replay ? "#20d9ed" : "#31536c"

    Rectangle {
        id: titleBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 30
        color: "#de0a2333"
        Label {
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.right: closeButton.left
            anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            text: root.replay ? "KGR • REPLAY" : root.live ? "SONAR • LIVE"
                  : root.sonar && root.sonar.connected ? "SONAR • AȘTEPT CHART" : "SONAR • OFFLINE"
            font.pixelSize: 10
            font.bold: true
            color: root.live ? "#66ecb3" : "#d7eaf5"
            elide: Text.ElideRight
        }
        Button {
            id: closeButton
            objectName: "sonarPipClose"
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 2
            width: 27
            height: 26
            padding: 0
            Accessible.name: "Ascunde sonar PiP"
            background: Rectangle { radius: 5; color: closeButton.down ? "#185167" : "#102f43" }
            contentItem: Label {
                text: "×"
                color: "#e4f5fb"
                font.pixelSize: 20
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            onClicked: root.closeRequested()
        }
    }

    NavoKoggerEpochPlotItem {
        id: miniPlot
        objectName: "sonarPipNativeEpochPlot"
        anchors.top: titleBar.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        fileReplay: root.replay ? root.sonar.replay : null
        horizontalZoom: 1
        position: root.replay ? 0.5 : 0.98
        depthRange: 20
        visible: root.ready
    }

    Label {
        anchors.centerIn: miniPlot
        visible: !root.ready
        width: parent.width - 16
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        color: "#b0cada"
        font.pixelSize: 11
        text: root.sonar && root.sonar.connected
            ? "Conectat • aștept coloane CHART"
            : "Fără date live • configurează PRO / KGR"
    }

    // A single tap on the preview closes it, just like the requested sonar toggle.
    MouseArea {
        anchors.fill: miniPlot
        cursorShape: Qt.PointingHandCursor
        onClicked: root.closeRequested()
        Accessible.name: "Ascunde previzualizarea sonar"
    }
}
