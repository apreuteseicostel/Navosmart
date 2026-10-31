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
        GridLayout {
            columns:root.width<360 ? 1 : 3
            Layout.fillWidth:true
            Label { text: "Activare asistență"; color: "#eff9ff"; font.pixelSize: 12; Layout.fillWidth: true }
            Label {
                objectName:"steeringState"
                text:root.controller ? "● "+root.controller.assistLabel : "● INDISPONIBILĂ"
                color:root.controller && root.controller.pending ? "#ffd166" : root.controller && root.controller.active ? "#37e9a2" : "#c1d7e6"
                font.pixelSize: 11; font.bold: true
            }
            Button {
                objectName: "steeringEnable"
                text:root.controller && root.controller.pending ? "Așteaptă…" : root.controller && root.controller.active ? "Dezactivează" : "Activează"
                Accessible.name:text+" asistența cârmei"
                highlighted:!!root.controller && root.controller.active
                implicitHeight: 32; implicitWidth: 104
                enabled:!!root.controller && !root.controller.pending && (root.controller.active ? root.controller.canStop : root.controller.canEnable)
                onClicked:if(root.controller.active)root.controller.stop();else confirmation.open()
                background: Rectangle { radius: 8; color:parent.down ? "#154d57" : root.controller && root.controller.active ? "#13513c" : "#092838"; border.color:parent.enabled ? "#37e9a2" : "#526372" }
                contentItem: Label { text: parent.text; color: parent.enabled ? "#37e9a2" : "#a0aebe"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.pixelSize: 11; font.bold: true }
            }
        }
        Rectangle { Layout.fillWidth: true; height: 1; color: "#173c51" }
        GridLayout {
            columns:root.width<360 ? 1 : 3
            Layout.fillWidth:true
            Label { text: "Mod H743"; color: "#eff9ff"; font.pixelSize: 12; Layout.fillWidth: true }
            Label {
                objectName:"steeringMode"
                text:root.controller && root.controller.confirmedMode.length ? root.controller.confirmedMode : "NECONFIRMAT"
                color: root.controller && root.controller.steeringMode.length > 0 ? "#20d9ed" : "#ffd166"
                font.pixelSize: 11; font.bold: true
            }
            Button {
                objectName: "steeringStop"
                text:root.controller && root.controller.pending ? "Așteaptă…" : root.controller && root.controller.holdActive ? "Dezactivează HOLD" : "Activează HOLD"
                Accessible.name:text
                highlighted:!!root.controller && root.controller.holdActive
                implicitHeight:32;implicitWidth:126
                enabled:!!root.controller && root.controller.canToggleHold
                ToolTip.visible:hovered
                ToolTip.text:root.controller && root.controller.holdActive ? "Dezactivează HOLD și solicită MANUAL pe H743" : "Solicită HOLD pe H743"
                onClicked:root.controller.toggleHold()
                background: Rectangle { radius: 8; color:parent.down ? "#5c2838" : root.controller && root.controller.holdActive ? "#56352a" : "#1d2838"; border.color:parent.enabled ? "#ff6872" : "#526372" }
                contentItem: Label { text: parent.text; color: parent.enabled ? "#ff8893" : "#a0aebe"; font.pixelSize: 11; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            }
        }
        Label {
            objectName:"holdState";Layout.fillWidth:true
            text:root.controller ? "HOLD: "+root.controller.holdLabel : "HOLD: INDISPONIBIL"
            color:root.controller && root.controller.pending ? "#ffd166" : root.controller && root.controller.holdActive ? "#37e9a2" : "#c1d7e6"
            font.pixelSize:11;wrapMode:Text.WordWrap
        }
        Label {
            objectName:"steeringBlockedReason";Layout.fillWidth:true
            visible:!!root.controller && !root.controller.canEnable && !root.controller.active && !root.controller.pending
            text:root.controller ? root.controller.availabilityMessage : "H743 indisponibil"
            color:"#ffd166";font.pixelSize:11;wrapMode:Text.WordWrap
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
            text:root.controller ? (root.controller.active && !root.controller.pending ? "STEERING confirmat de H743" : root.controller.holdActive && !root.controller.pending ? "HOLD confirmat de H743" : root.controller.message) : ""
            color: "#c1d7e6"
            wrapMode:Text.WordWrap
            font.pixelSize: 10
            ToolTip.visible: messageMouse.containsMouse
            ToolTip.text: text
            MouseArea { id: messageMouse; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
        }
    }

    component ConfirmationAction: Button {
        id: action
        property color accent: "#c1d7e6"
        implicitWidth: Math.min(112, Math.max(0, (confirmation.width - 36) / 2))
        implicitHeight: 34
        padding: 7
        background: Rectangle {
            radius: 7
            color: action.down ? "#17495b" : (action.hovered ? "#103449" : "#092439")
            border.color: action.activeFocus ? "#eff9ff" : action.accent
            opacity: action.enabled ? 1 : 0.45
        }
        contentItem: Label {
            text: action.text
            color: action.enabled ? action.accent : "#8495a4"
            font.pixelSize: 12
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
    }

    Dialog {
        id: confirmation
        objectName: "steeringConfirmation"
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: Math.min(340, parent ? parent.width-24 : 340)
        height: Math.min(implicitHeight, parent ? parent.height-24 : implicitHeight)
        leftPadding: 14
        rightPadding: 14
        topPadding: 0
        bottomPadding: 0
        modal: true
        title: "Activează STEERING?"
        background: Rectangle {
            color: "#071d2d"
            radius: 11
            border.color: "#20d9ed"
            border.width: 1
        }
        Overlay.modal: Rectangle { color: "#99040d17" }
        header: Item {
            implicitHeight: 46
            Label {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                text: confirmation.title
                color: "#eff9ff"
                font.pixelSize: 14
                font.bold: true
                elide: Text.ElideRight
            }
        }
        contentItem: ScrollView {
            id: confirmationScroll
            implicitHeight: confirmationText.implicitHeight
            clip: true
            contentWidth: availableWidth
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            Label {
                id: confirmationText
                objectName: "steeringConfirmationText"
                width: confirmationScroll.availableWidth
                wrapMode: Text.WordWrap
                color: "#c1d7e6"
                font.pixelSize: 12
                text: "Manșe la neutru. Verifică zona liberă și PRE-LAUNCH.\n\nH743 controlează cârma și propulsia conform configurării sale. Viteza se comandă din G20."
            }
        }
        footer: DialogButtonBox {
            buttonLayout: DialogButtonBox.MacLayout
            spacing: 8
            topPadding: 12
            bottomPadding: 14
            leftPadding: 14
            rightPadding: 14
            alignment: Qt.AlignRight
            background: Rectangle { color: "transparent" }
            ConfirmationAction {
                objectName: "steeringCancel"
                text: "Anulează"
                DialogButtonBox.buttonRole: DialogButtonBox.RejectRole
            }
            ConfirmationAction {
                objectName: "steeringConfirmEnable"
                text: "Activează"
                accent: "#37e9a2"
                enabled: !!root.controller && root.controller.canEnable
                DialogButtonBox.buttonRole: DialogButtonBox.AcceptRole
            }
        }
        onAccepted: root.enableRequested()
    }
}

