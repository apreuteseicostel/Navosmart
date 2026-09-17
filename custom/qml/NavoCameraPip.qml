import QtQuick
import QtQuick.Controls

Rectangle {
    id: root
    property bool connected: false
    property string streamUrl: ""
    property string statusText: connected ? "LIVE • GR01" : "CAMERA GR01"
    signal fullscreenRequested()

    width: 230; height: 145; radius: 9; color: "#02070cdd"; border.color: connected ? "#31d67b" : "#1c4262"; clip: true
    Rectangle { anchors.fill: parent; anchors.margins: 2; radius: 7; color: "#071827" }
    Label { anchors.centerIn: parent; text: root.connected ? "VIDEO LIVE" : "Flux video rezervat\nGR01 → G20"; color: root.connected ? "white" : "#9db2c5"; horizontalAlignment: Text.AlignHCenter; font.bold: true }
    Rectangle { anchors.left: parent.left; anchors.top: parent.top; anchors.margins: 7; width: camLabel.implicitWidth+12; height: 25; radius: 5; color: "#06111fcc"
        Label { id: camLabel; anchors.centerIn: parent; text: root.statusText; color: root.connected ? "#31d67b" : "#9db2c5"; font.pixelSize: 10; font.bold: true }
    }
    MouseArea { anchors.fill: parent; onClicked: root.fullscreenRequested() }
}
