import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCore

Rectangle {
    id: root
    property var controller
    property var hopperBridge
    property var waypoint
    property var availableSpots: []
    property string waypointName: waypoint ? (waypoint.name || "WP" + waypoint.sequenceNumber) : "Niciun punct selectat"
    readonly property color secondaryTextColor: "#d7e3ee"
    property bool hopperAnimationVisible: false
    readonly property bool hopperLeftOpen: !!root.hopperBridge && root.hopperBridge.leftOpen
    readonly property bool hopperRightOpen: !!root.hopperBridge && root.hopperBridge.rightOpen
    readonly property int selectedHopper: hopperBox.currentIndex === 0 ? 1 : hopperBox.currentIndex === 1 ? 2 : hopperBox.currentIndex === 2 ? 3 : 0
    signal startConfirmed(var waypoint, string name, int hopper)
    signal abortRequested()
    signal chooseOnMapRequested()
    signal spotChosen(var spot)
    color: "#0b1c2eee"; border.color: "#21b7ff"; radius: 10
    implicitWidth: 320
    implicitHeight: summary.implicitHeight + 20

    Settings {
        id: saved
        category: "NavoBaiting"
        property int hopperIndex: 0
        property int silentRadius: 10
        property int finalRadius: 3
        property int silentSpeedTenths: 8
        property int finalSpeedTenths: 4
        property int accelerationTenths: 4
        property int decelerationTenths: 5
        property int exitDistance: 4
        property int exitSideIndex: 0
        property bool rtlAfterDrop: true
    }
    function applySettings() {
        if (!controller) return
        controller.silentRadiusM = saved.silentRadius
        controller.finalRadiusM = saved.finalRadius
        controller.silentSpeedMps = saved.silentSpeedTenths / 10
        controller.finalSpeedMps = saved.finalSpeedTenths / 10
        controller.accelerationMps2 = saved.accelerationTenths / 10
        controller.decelerationMps2 = saved.decelerationTenths / 10
        controller.exitDistanceM = saved.exitDistance
        controller.exitSide = saved.exitSideIndex === 0 ? 1 : -1
        controller.rtlAfterDrop = saved.rtlAfterDrop
    }
    Component.onCompleted: applySettings()
    onControllerChanged: applySettings()

    function syncHopperAnimation() {
        if (!root.hopperBridge) {
            root.hopperAnimationVisible = false
            return
        }
        if (root.hopperBridge.commandPending || root.hopperBridge.leftOpen || root.hopperBridge.rightOpen) {
            hopperAnimationHide.stop()
            root.hopperAnimationVisible = true
        } else if (root.hopperAnimationVisible) {
            hopperAnimationHide.restart()
        }
    }
    Timer {
        id: hopperAnimationHide
        interval: 1200
        repeat: false
        onTriggered: root.hopperAnimationVisible = false
    }
    Connections {
        target: root.hopperBridge
        ignoreUnknownSignals: true
        function onLeftOpenChanged() { root.syncHopperAnimation() }
        function onRightOpenChanged() { root.syncHopperAnimation() }
        function onCommandPendingChanged() { root.syncHopperAnimation() }
    }

    ColumnLayout {
        id: summary
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        anchors.margins: 8; spacing: 5
        RowLayout { Layout.fillWidth:true; spacing:6\n            Label { text:"NĂDIRE"; color:"white"; font.bold:true; font.pixelSize:15 }\n            Label { Layout.fillWidth:true; text:"ȚINTĂ: "+root.waypointName+"  •  CUVA: "+hopperBox.currentText; color:"#21b7ff"; font.bold:true; font.pixelSize:11; elide:Text.ElideRight; horizontalAlignment:Text.AlignRight }\n            ToolButton { text:"⚙"; font.pixelSize:18; enabled:!root.controller || !root.controller.enabled; onClicked:settingsPopup.open(); ToolTip.visible:hovered; ToolTip.text:"Setări nădire" }\n        }
        ComboBox {
            Layout.fillWidth: true
            visible: root.availableSpots.length > 0
            enabled: !root.controller || !root.controller.enabled
            model: root.availableSpots
            textRole: "name"
            displayText: "Alege un loc salvat"
            onActivated: function(index) { root.spotChosen(root.availableSpots[index]) }
        }
        Button { enabled: !root.controller || !root.controller.enabled; text: "ALEGE PUNCT PE HARTĂ"; onClicked: root.chooseOnMapRequested() }
        RowLayout {
            Layout.fillWidth: true
            Label { text: "Cuva"; color: root.secondaryTextColor }
            ComboBox {
                id: hopperBox; Layout.fillWidth: true
                model: ["Stânga", "Dreapta", "Ambele", "Fără eliberare"]
                currentIndex: saved.hopperIndex
                enabled: !root.controller || !root.controller.enabled
                onActivated: function(index) { saved.hopperIndex = index }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Button {
                Layout.fillWidth: true
                text: root.controller && root.controller.enabled ? "NĂDIRE ÎN CURS" : "PORNEȘTE NĂDIREA"
                enabled: !!root.waypoint && !!root.controller && !root.controller.enabled
                onClicked: confirmDialog.open()
            }
            Button { text: "OPREȘTE"; enabled: !!root.controller && root.controller.enabled; onClicked: root.abortRequested() }
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: root.hopperAnimationVisible ? 154 : 0
            visible: root.hopperAnimationVisible
            clip: true
            radius: 9
            color: "#06131f"
            border.color: "#21b7ff"
            border.width: 1

            Label {
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.topMargin: 7
                text: root.hopperLeftOpen && root.hopperRightOpen ? "AMBELE CUVE BASCULEAZĂ" :
                      root.hopperLeftOpen ? "CUVA STÂNGĂ BASCULEAZĂ" :
                      root.hopperRightOpen ? "CUVA DREAPTĂ BASCULEAZĂ" : "CUVE ÎNCHISE • REVENIRE"
                color: root.hopperLeftOpen || root.hopperRightOpen ? "#31d67b" : root.secondaryTextColor
                font.bold: true
                font.pixelSize: 12
            }

            Item {
                id: boatAnimation
                width: Math.min(parent.width - 18, 285)
                height: 112
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 5

                Rectangle {
                    id: boatHull
                    width: 220
                    height: 96
                    anchors.centerIn: parent
                    radius: 28
                    color: "#dfff00"
                    border.color: "#94a900"
                    border.width: 2

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 22
                        radius: 10
                        color: "#11161c"
                        opacity: 0.96
                    }
                    Rectangle {
                        width: 18; height: 46
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        radius: 7; color: "#161b22"
                    }
                    Rectangle {
                        width: 9; height: 9
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 69; radius: 5; color: "#e53935"
                    }
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 4
                        text: "NAVO SMART"
                        color: "#0b67b2"
                        font.bold: true
                        font.pixelSize: 9
                    }
                }

                Rectangle {
                    id: leftHopperVisual
                    width: 72
                    height: 62
                    x: boatHull.x + 19
                    y: boatHull.y + 13
                    radius: 7
                    color: "#111820"
                    border.color: "#4b5968"
                    border.width: 2
                    transformOrigin: Item.Right
                    rotation: root.hopperLeftOpen ? -52 : 0
                    Behavior on rotation { NumberAnimation { duration: 380; easing.type: Easing.InOutCubic } }
                    Label { anchors.centerIn: parent; text: "● ● ●\n● ● ●"; color: "#9b612d"; horizontalAlignment: Text.AlignHCenter; font.pixelSize: 11 }
                }

                Rectangle {
                    id: rightHopperVisual
                    width: 72
                    height: 62
                    x: boatHull.x + boatHull.width - width - 19
                    y: boatHull.y + 13
                    radius: 7
                    color: "#111820"
                    border.color: "#4b5968"
                    border.width: 2
                    transformOrigin: Item.Left
                    rotation: root.hopperRightOpen ? 52 : 0
                    Behavior on rotation { NumberAnimation { duration: 380; easing.type: Easing.InOutCubic } }
                    Label { anchors.centerIn: parent; text: "● ● ●\n● ● ●"; color: "#9b612d"; horizontalAlignment: Text.AlignHCenter; font.pixelSize: 11 }
                }

                Label {
                    visible: root.hopperLeftOpen
                    x: 8; y: 28
                    text: "↖"
                    color: "#21b7ff"
                    font.pixelSize: 28
                    font.bold: true
                }
                Label {
                    visible: root.hopperRightOpen
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    y: 28
                    text: "↗"
                    color: "#21b7ff"
                    font.pixelSize: 28
                    font.bold: true
                }
            }
        }
                Label { Layout.fillWidth: true; text: root.controller ? "Stare: " + root.controller.stateText(root.controller.state) : "Controler indisponibil"; color: root.controller && root.controller.enabled ? "#31d67b" : "#9db2c5"; wrapMode: Text.WordWrap }
    }

    Popup {
        id: settingsPopup; parent: Overlay.overlay; anchors.centerIn: parent
        width: Math.min(480, parent ? parent.width - 24 : 480)
        height: Math.min(560, parent ? parent.height - 24 : 560)
        modal: true; focus: true; padding: 12
        background: Rectangle { color: "#0b1c2e"; border.color: "#21b7ff"; radius: 10 }
        contentItem: ColumnLayout {
            spacing: 8
            Label { text: "SETĂRI NĂDIRE"; color: "white"; font.bold: true; font.pixelSize: 18 }
            Label { Layout.fillWidth: true; text: "Valorile se salvează automat pentru următoarea utilizare."; color: root.secondaryTextColor; wrapMode: Text.WordWrap }
            ScrollView {
                Layout.fillWidth: true; Layout.fillHeight: true; clip: true
                GridLayout {
                    width: parent.width - 16; columns: 3; columnSpacing: 6; rowSpacing: 5
                    Label { text: "Zonă silențioasă"; color: "white" }
                    SpinBox { from: 3; to: 30; value: saved.silentRadius; onValueModified: { saved.silentRadius = value; root.applySettings() } }
                    Label { text: "m"; color: "white" }
                    Label { text: "Zonă finală"; color: "white" }
                    SpinBox { from: 1; to: 10; value: saved.finalRadius; onValueModified: { saved.finalRadius = value; root.applySettings() } }
                    Label { text: "m"; color: "white" }
                    Label { text: "Viteză silențioasă"; color: "white" }
                    SpinBox { from: 2; to: 15; value: saved.silentSpeedTenths; onValueModified: { saved.silentSpeedTenths = value; root.applySettings() } }
                    Label { text: "× 0,1 m/s"; color: "white" }
                    Label { text: "Viteză finală"; color: "white" }
                    SpinBox { from: 1; to: 10; value: saved.finalSpeedTenths; onValueModified: { saved.finalSpeedTenths = value; root.applySettings() } }
                    Label { text: "× 0,1 m/s"; color: "white" }
                    Label { text: "Accelerație"; color: "white" }
                    SpinBox { from: 1; to: 10; value: saved.accelerationTenths; onValueModified: { saved.accelerationTenths = value; root.applySettings() } }
                    Label { text: "× 0,1 m/s²"; color: "white" }
                    Label { text: "Decelerație"; color: "white" }
                    SpinBox { from: 1; to: 12; value: saved.decelerationTenths; onValueModified: { saved.decelerationTenths = value; root.applySettings() } }
                    Label { text: "× 0,1 m/s²"; color: "white" }
                    Label { text: "Distanță ieșire"; color: "white" }
                    SpinBox { from: 2; to: 10; value: saved.exitDistance; onValueModified: { saved.exitDistance = value; root.applySettings() } }
                    Label { text: "m"; color: "white" }
                    Label { text: "Direcție ieșire"; color: "white" }
                    ComboBox { Layout.columnSpan: 2; model: ["Dreapta", "Stânga"]; currentIndex: saved.exitSideIndex; onActivated: function(index) { saved.exitSideIndex = index; root.applySettings() } }
                    CheckBox { Layout.columnSpan: 3; text: "RTL după eliberare"; palette.windowText: root.secondaryTextColor; palette.buttonText: root.secondaryTextColor; checked: saved.rtlAfterDrop; onToggled: { saved.rtlAfterDrop = checked; root.applySettings() } }
                }
            }
            Button { Layout.alignment: Qt.AlignRight; text: "GATA"; onClicked: settingsPopup.close() }
        }
    }
    Dialog {
        id: confirmDialog
        parent: Overlay.overlay
        modal: true
        focus: true
        anchors.centerIn: parent
        width: Math.min(500, parent ? parent.width - 32 : 500)
        height: Math.min(180, parent ? parent.height - 24 : 180)
        padding: 12
        title: "Confirmă nădirea"
        standardButtons: Dialog.Ok | Dialog.Cancel
        closePolicy: Popup.NoAutoClose
        background: Rectangle { color:"#0b1c2e"; border.color:"#21b7ff"; radius:10 }
        contentItem: Label {
            width: confirmDialog.availableWidth
            color: "#f2f7fb"
            wrapMode: Text.WordWrap
            verticalAlignment: Text.AlignVCenter
            text: root.waypointName + "  •  Cuva " + hopperBox.currentText.toLowerCase() +
                  "\nBarca va naviga, opri, elibera nada și reveni automat."
        }
        Component.onCompleted: {
            standardButton(Dialog.Ok).text = "PORNEȘTE"
            standardButton(Dialog.Cancel).text = "ANULEAZĂ"
        }
        onAccepted: root.startConfirmed(root.waypoint, root.waypointName, root.selectedHopper)
    }
}
