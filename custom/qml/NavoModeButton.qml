import QtQuick
import QtQuick.Controls

Button {
    id: root
    property bool activeMode: false
    property color activeColor: "#18c75b"

    font.bold: true
    font.pixelSize: 20

    background: Rectangle {
        radius: 8
        color: root.activeMode ? root.activeColor : "#18314a"
        border.color: root.activeMode ? "#57f38c" : "#31516d"
        border.width: 1
    }
    contentItem: Text {
        text: root.text
        color: "white"
        font: root.font
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}
