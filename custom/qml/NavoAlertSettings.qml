import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Compact, accessible NAVO V3 alert configuration. Retains the existing audio APIs.
Rectangle {
    id: root
    property var controller: null
    property var audio: null
    property bool helpOpen: false
    color: "#061827"
    border.color: "#20d9ed"
    border.width: 1
    radius: 10
    implicitHeight: body.implicitHeight + 20

    function apply() {
        if (controller) controller.configure(sound.checked, voice.checked, volume.value)
    }
    component CompactToggle: Switch {
        id: control
        font.pixelSize: 12
        spacing: 8
        implicitHeight: 30
        indicator: Rectangle {
            implicitWidth: 40
            implicitHeight: 22
            x: 0
            anchors.verticalCenter: parent.verticalCenter
            radius: 11
            color: control.checked ? "#20d9ed" : "#315063"
            Rectangle {
                x: control.checked ? parent.width - width - 3 : 3
                anchors.verticalCenter: parent.verticalCenter
                width: 16; height: 16; radius: 8
                color: "#eff9ff"
            }
        }
        contentItem: Label {
            text: control.text
            color: "#eff9ff"
            font.pixelSize: 12
            font.bold: false
            leftPadding: control.indicator.width + control.spacing
            verticalAlignment: Text.AlignVCenter
        }
    }
    component ActionButton: Button {
        id: action
        property color tint: "#20d9ed"
        implicitHeight: 32
        padding: 6
        font.pixelSize: 11
        background: Rectangle {
            color: action.hovered ? "#123448" : "#082537"
            border.color: action.tint; radius: 8
        }
        contentItem: Label {
            text: action.text; color: action.tint
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            font: action.font
        }
    }
    ColumnLayout {
        id: body
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 10
        spacing: 4
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Label { text: "◖))"; color: "#20d9ed"; font.pixelSize: 19 }
            Label { text: "Alerte sonore și vocale"; color: "#eff9ff"; font.pixelSize: 16; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
            Button {
                text: "ⓘ"
                Accessible.name: "Informații despre alerte"
                ToolTip.visible: hovered
                ToolTip.text: "Alertele de siguranță au prioritate. Testul audio nu controlează barca."
                onClicked: root.helpOpen = !root.helpOpen
                implicitWidth: 29; implicitHeight: 27
                background: Rectangle { color: "transparent" }
                contentItem: Label { text: parent.text; color: "#20d9ed"; font.pixelSize: 17; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            }
        }
        Rectangle { Layout.fillWidth: true; height: 1; color: "#19546b" }
        RowLayout {
            Layout.fillWidth: true; Layout.preferredHeight: 30
            CompactToggle { id: sound; objectName: "alertsSound"; text: "Alerte sonore"; checked: root.controller ? root.controller.soundEnabled : false; onToggled: root.apply() }
            Item { Layout.fillWidth: true }
        }
        Rectangle { Layout.fillWidth: true; height: 1; color: "#173c51" }
        RowLayout {
            Layout.fillWidth: true; Layout.preferredHeight: 30
            CompactToggle { id: voice; objectName: "alertsVoice"; text: "Alerte vocale"; checked: root.controller ? root.controller.voiceEnabled : false; onToggled: root.apply() }
            Item { Layout.fillWidth: true }
            Label { visible: !!root.audio && !root.audio.voiceAvailable; text: "Voce indisponibilă"; color: "#ffd166"; font.pixelSize: 10 }
        }
        Rectangle { Layout.fillWidth: true; height: 1; color: "#173c51" }
        RowLayout {
            Layout.fillWidth: true; spacing: 8; Layout.preferredHeight: 34
            Label { text: "Volum"; color: "#eff9ff"; font.pixelSize: 12; Layout.preferredWidth: 64 }
            Slider {
                id: volume
                Accessible.name: "Volum alerte"
                Layout.fillWidth: true
                Layout.maximumWidth: 205
                implicitHeight: 27
                from: 0; to: 1; stepSize: 0.05
                value: root.controller ? root.controller.volume : 0.7
                onMoved: root.apply()
                background: Rectangle {
                    x: volume.leftPadding
                    y: volume.topPadding + volume.availableHeight/2 - height/2
                    width: volume.availableWidth
                    height: 5
                    radius: 3
                    color: "#35566b"
                    Rectangle { width: volume.visualPosition * parent.width; height: parent.height; radius: 3; color: "#20d9ed" }
                }
                handle: Rectangle {
                    x: volume.leftPadding + volume.visualPosition * (volume.availableWidth - width)
                    y: volume.topPadding + volume.availableHeight/2 - height/2
                    width: 16; height: 16; radius: 8
                    color: "#eff9ff"
                    border.color: "#20d9ed"; border.width: 2
                }
            }
            Label { text: Math.round(volume.value*100) + "%"; color: "#eff9ff"; font.pixelSize: 12; Layout.preferredWidth: 35 }
            Item { Layout.fillWidth: true }
            ActionButton { text: "▶ Test"; tint: "#37e9a2"; enabled: !!root.controller && (sound.checked || voice.checked); onClicked: { root.apply(); root.controller.test() } }
            ActionButton { text: "■ Stop"; tint: "#ff6872"; enabled: !!root.audio; onClicked: root.audio.stop() }
        }
        Label {
            visible: root.helpOpen
            Layout.fillWidth: true
            text: "Se pot anunța pierderea GPS/legăturii, bateria scăzută, apa detectată și sfârșitul nădirii. Verifică volumul multimedia Android și Bluetooth. Alertele automate sunt oprite în replay."
            color: "#c1d7e6"; wrapMode: Text.WordWrap; font.pixelSize: 11
        }
        Label {
            visible: !!root.audio && !!root.audio.voiceError && root.audio.voiceError.length>0
            Layout.fillWidth: true; wrapMode: Text.WordWrap
            color: "#ff9ea7"; font.pixelSize: 11
            text: root.audio ? root.audio.voiceError : ""
        }
        Label {
            visible: !!root.audio && !!root.audio.soundError && root.audio.soundError.length>0
            Layout.fillWidth: true; wrapMode: Text.WordWrap
            color: "#ff9ea7"; font.pixelSize: 11
            text: root.audio ? root.audio.soundError : ""
        }
        Label {
            visible: !!root.audio && !!root.audio.lastPlaybackStatus && root.audio.lastPlaybackStatus.length>0
            Layout.fillWidth: true; wrapMode: Text.WordWrap
            color: "#c1d7e6"; font.pixelSize: 10
            text: root.audio ? root.audio.lastPlaybackStatus : ""
        }
        Label {
            Layout.fillWidth: true
            visible: !!root.controller && !!root.controller.latest && root.controller.latest.length>0
            text: root.controller ? root.controller.latest : ""
            color: "#9bdced"; font.pixelSize: 10; elide: Text.ElideRight
            ToolTip.visible: hover.containsMouse
            ToolTip.text: text
            MouseArea { id: hover; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
        }
    }
}
