import QtQuick
import QtQuick.Controls

Rectangle {
    id: root
    property string title: ""
    property string value: "--"
    property string detail: ""
    property color accent: "#21d07a"

    radius: 8
    color: "#101a24"
    border.color: "#2a3b4c"
    border.width: 1

    Column {
        anchors.centerIn: parent
        spacing: 5
        Text { text: root.title; color: "#dce6ef"; font.pixelSize: 16 }
        Text { text: root.value; color: "white"; font.bold: true; font.pixelSize: 30 }
        Text { text: root.detail; color: root.accent; font.pixelSize: 14; visible: text.length > 0 }
    }
}
