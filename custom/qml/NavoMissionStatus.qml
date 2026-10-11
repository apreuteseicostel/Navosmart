import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    objectName: "navoMissionStatus"
    property bool active: false
    property bool connected: false
    property real progress: 0
    property string statusText: "Pregătit"
    property bool homeAvailable: false
    signal pauseRequested()
    signal homeRequested()
    color: "#102536"; radius: 8
    implicitHeight: body.implicitHeight + 12
    component MissionAction: Button {
        property string glyph: ""
        implicitWidth: root.width<480 ? 36 : 82
        implicitHeight: 34; padding: 5
        font.pixelSize: 11
        Accessible.name: text
        ToolTip.visible: hovered; ToolTip.text: text
        background: Rectangle {
            radius:6;color:parent.down ? "#1c5066" : parent.hovered ? "#173d51" : "#102b3b"
            border.color:parent.enabled ? "#38badb" : "#35434e"
            opacity:parent.enabled ? 1 : .5
        }
        contentItem: Row {
            spacing:5
            Image { width:18;height:18;anchors.verticalCenter:parent.verticalCenter
                source:"qrc:/qml/NavoSmart/icons/"+parent.parent.glyph+".svg"
                opacity:parent.parent.enabled ? 1 : .45 }
            Label { visible:root.width>=480;anchors.verticalCenter:parent.verticalCenter
                text:parent.parent.text;color:parent.parent.enabled ? "#e0f5ff" : "#788b98";font.pixelSize:11 }
        }
    }
    ColumnLayout {
        id: body
        anchors.fill: parent; anchors.margins: 6; spacing: 3
        RowLayout {
            Layout.fillWidth: true;spacing:6
            Label {
                Layout.fillWidth:true;Layout.minimumWidth:0;text:root.statusText
                color:"white";font.pixelSize:12;elide:Text.ElideRight
                HoverHandler { id:statusHover }
                ToolTip.visible:truncated && statusHover.hovered;ToolTip.text:text
            }
            Label {
                objectName:"missionConnection"
                text:root.width>=650 ? (root.connected ? "● CONECTAT" : "● FĂRĂ LEGĂTURĂ") : "●"
                Accessible.name:root.connected ? "Conectat" : "Fără legătură"
                color:root.connected ? "#31d67b" : "#ff5c5c";font.pixelSize:11
                HoverHandler { id:connectionHover }
                ToolTip.visible:connectionHover.hovered;ToolTip.text:root.connected ? "Conectat" : "Fără legătură"
            }
            MissionAction { objectName:"missionPause";text:"PAUZĂ";glyph:"pause";enabled:root.active && root.connected;onClicked:root.pauseRequested() }
            MissionAction { objectName:"missionHome";text:"HOME";glyph:"home";enabled:root.homeAvailable && root.connected;onClicked:root.homeRequested() }
        }
        RowLayout {
            Layout.fillWidth:true;spacing:6
            Label { text:Math.floor(root.progress)+"%";color:"#d7e3ee";font.pixelSize:10 }
            ProgressBar {
                Layout.fillWidth:true;implicitHeight:6;from:0;to:100;value:root.progress
                background:Rectangle { color:"#243f50";radius:3 }
                contentItem:Item { implicitHeight:6;Rectangle { width:parent.width*parent.parent.visualPosition;height:parent.height;radius:3;color:"#26bbd6" } }
            }
        }
    }
}
