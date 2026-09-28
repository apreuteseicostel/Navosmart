import QtQuick
import QtQuick.Controls

Rectangle {
    id: root
    property string streamUrl: ""
    property string protocol: "auto"
    signal closed()
    color: "#02070c"

    NavoVideoPlayer {
        id: video
        anchors.fill: parent
        streamUrl: root.streamUrl
        protocol: root.protocol
        autoReconnect: true
    }

    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: 14
        width: status.implicitWidth + 20
        height: 32
        radius: 6
        color: "#06111fcc"
        Label {
            id: status
            anchors.centerIn: parent
            text: "CAMERĂ FAȚĂ • " + video.status
            color: video.playing ? "#31d67b" : "#f2f7fb"
            font.bold: true
        }
    }

    Button {
        id: closeButton
        z: 10000
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 12
        anchors.bottomMargin: 12
        width: 56
        height: 56
        padding: 0
        ToolTip.visible: hovered
        ToolTip.text: "Închide Camera față"
        background: Rectangle {
            radius: 9
            color: closeButton.hovered ? "#24384a" : "#101923e6"
            border.color: "#6f8498"
            border.width: 1
        }
        contentItem: Label {
            text: "×"
            color: "#f4f7fb"
            font.pixelSize: 32
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
        onClicked: root.closed()
    }

    Component.onCompleted: video.start()
}
