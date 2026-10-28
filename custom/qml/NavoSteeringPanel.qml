import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    property var controller
    property bool helpOpen: false
    signal enableRequested()
    color: "#061827"
    border.color: "#20d9ed"
    border.width: 1
    radius: 10
    implicitHeight: body.implicitHeight + 20

    ColumnLayout {
        id: body
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 10
        spacing: 6
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Label { text: "⚙"; color: "#20d9ed"; font.pixelSize: 21 }
            Label { text: "Asistență cârmă"; color: "#eff9ff"; font.pixelSize: 16; font.bold: true; Layout.fillWidth: true }
            Button {
                text: "ⓘ"
                Accessible.name: "Detalii asistență cârmă"
                implicitWidth: 29; implicitHeight: 27
                onClicked: root.helpOpen = !root.helpOpen
                ToolTip.visible: hovered
                ToolTip.text: "STEERING necesită H743, GNSS valid și verificarea mecanică a cârmei."
                background: Rectangle { color: "transparent" }
                contentItem: Label { text: parent.text; color: "#20d9ed"; font.pixelSize: 17; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            }
        }
        Rectangle { Layout.fillWidth: true; height: 1; color: "#19546b" }
        RowLayout {
            Layout.fillWidth: true; Layout.preferredHeight: 33
            Label { text: "Activare asistență"; color: "#eff9ff"; font.pixelSize: 12; Layout.fillWidth: true }
            Label {
                text: root.controller && root.controller.busy ? "● STEERING" : "● OPRIT"
                color: root.controller && root.controller.busy ? "#37e9a2" : "#c1d7e6"
                font.pixelSize: 11; font.bold: true
            }
            Button {
                objectName: "steeringEnable"
                text: "Activează"
                Accessible.name: "Activează asistența cârmei"
                implicitHeight: 32; implicitWidth: 89
                enabled: !!root.controller && root.controller.canEnable
                onClicked: confirmation.open()
                background: Rectangle { radius: 8; color: parent.down ? "#154d57" : "#092838"; border.color: "#37e9a2" }
                contentItem: Label { text: parent.text; color: parent.enabled ? "#37e9a2" : "#a0aebe"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.pixelSize: 11; font.bold: true }
            }
        }
        Rectangle { Layout.fillWidth: true; height: 1; color: "#173c51" }
        RowLayout {
            Layout.fillWidth: true; Layout.preferredHeight: 34
            Label { text: "Mod H743"; color: "#eff9ff"; font.pixelSize: 12; Layout.fillWidth: true }
            Label {
                text: root.controller && root.controller.steeringMode.length > 0 ? root.controller.steeringMode : "INDISPONIBIL"
                color: root.controller && root.controller.steeringMode.length > 0 ? "#20d9ed" : "#ffd166"
                font.pixelSize: 11; font.bold: true
            }
            Button {
                objectName: "steeringStop"
                text: "■ HOLD"
                implicitHeight: 32; implicitWidth: 83
                enabled: !!root.controller && root.controller.busy && !root.controller.readOnly
                onClicked: root.controller.stop()
                background: Rectangle { radius: 8; color: "#1d2838"; border.color: "#ff6872" }
                contentItem: Label { text: parent.text; color: parent.enabled ? "#ff8893" : "#a0aebe"; font.pixelSize: 11; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            }
        }
        Rectangle { Layout.fillWidth: true; height: 1; color: "#173c51" }
        RowLayout {
            Layout.fillWidth: true
            Label { text: "Reglaje cârmă / sensibilitate"; color: "#eff9ff"; font.pixelSize: 11; Layout.fillWidth: true; elide: Text.ElideRight }
            Label { text: "Parametri H743"; color: "#9bdced"; font.pixelSize: 11 }
        }
        Label {
            visible: root.helpOpen
            Layout.fillWidth: true
            text: "Viteza rămâne pe G20. Setările de reglaj se configurează și se testează în ArduPilot/QGroundControl. Nu afișăm un slider local fără un parametru firmware validat."
            color: "#c1d7e6"
            wrapMode: Text.WordWrap
            font.pixelSize: 11
        }
        Label {
            visible: !!root.controller && root.controller.message.length > 0
            Layout.fillWidth: true
            text: root.controller ? root.controller.message : ""
            color: "#c1d7e6"
            elide: Text.ElideRight
            font.pixelSize: 10
            ToolTip.visible: messageMouse.containsMouse
            ToolTip.text: text
            MouseArea { id: messageMouse; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
        }
    }

    Dialog {
        id: confirmation
        objectName: "steeringConfirmation"
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: Math.min(410, parent ? parent.width-24 : 410)
        height: Math.min(268, parent ? parent.height-24 : 268)
        modal: true
        title: "Activează STEERING?"
        standardButtons: Dialog.Ok | Dialog.Cancel
        contentItem: ScrollView {
            clip: true
            contentWidth: availableWidth
            Label {
                width: parent.width
                wrapMode: Text.WordWrap
                text: "Pune manșele la neutru înainte de schimbarea modului. H743 controlează cârma și propulsia conform configurării sale; viteza se comandă din G20. Verifică zona liberă și pregătirea PRE-LAUNCH."
            }
        }
        onAccepted: root.enableRequested()
    }
}
