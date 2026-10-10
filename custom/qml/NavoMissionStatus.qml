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
    implicitHeight: body.implicitHeight + 16
    ColumnLayout {
        id: body
        anchors.fill: parent; anchors.margins: 8; spacing: 4
        RowLayout {
            Layout.fillWidth: true
            Label { Layout.fillWidth: true; text: root.statusText; color: "white"; wrapMode: Text.WordWrap }
            Label { objectName:"missionConnection"; text:root.connected ? "● CONECTAT" : "● FĂRĂ LEGĂTURĂ"; color:root.connected ? "#31d67b" : "#ff5c5c"; font.pixelSize:11 }
        }
        ProgressBar { Layout.fillWidth: true; from:0; to:100; value:root.progress }
        RowLayout {
            Layout.fillWidth: true
            Label { Layout.fillWidth:true; text:Math.floor(root.progress)+"%"; color:"#d7e3ee" }
            Button { objectName:"missionPause"; text:"PAUZĂ"; enabled:root.active && root.connected; onClicked:root.pauseRequested() }
            Button { objectName:"missionHome"; text:"HOME"; enabled:root.homeAvailable && root.connected; onClicked:root.homeRequested() }
        }
    }
}
