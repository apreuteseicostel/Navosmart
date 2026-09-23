import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCore

Rectangle {
    id: root
    property var controller
    property var waypoint
    property var availableSpots: []
    property string waypointName: waypoint ? (waypoint.name || "WP" + waypoint.sequenceNumber) : "Niciun punct selectat"
    readonly property int selectedHopper: hopperBox.currentIndex === 0 ? 1 : hopperBox.currentIndex === 1 ? 2 : hopperBox.currentIndex === 2 ? 3 : 0
    signal startConfirmed(var waypoint, string name, int hopper)
    signal abortRequested()
    signal chooseOnMapRequested()
    signal spotChosen(var spot)
    color: "#0b1c2eee"; border.color: "#21b7ff"; radius: 10
    width: Math.min(370, parent ? parent.width - 20 : 370)
    implicitHeight: summary.implicitHeight + 28

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

    ColumnLayout {
        id: summary
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        anchors.margins: 14; spacing: 10
        Label { text: "NĂDIRE AUTOMATĂ"; color: "white"; font.bold: true; font.pixelSize: 17 }
        Label { Layout.fillWidth: true; text: "Punct: " + root.waypointName; color: "#21b7ff"; font.bold: true; wrapMode: Text.WordWrap }
        Label {
            Layout.fillWidth: true
            visible: !root.waypoint
            text: "Alege un waypoint pe hartă sau un loc de pescuit salvat. Pornirea cere apoi GPS și H743 conectate."
            color: "#9db2c5"; wrapMode: Text.WordWrap
        }
        ComboBox {
            Layout.fillWidth: true
            visible: !root.waypoint && root.availableSpots.length > 0
            model: root.availableSpots
            textRole: "name"
            displayText: "Alege un loc salvat"
            onActivated: function(index) { root.spotChosen(root.availableSpots[index]) }
        }
        Button { visible: !root.waypoint; text: "ALEGE PUNCT PE HARTĂ"; onClicked: root.chooseOnMapRequested() }
        RowLayout {
            Layout.fillWidth: true
            Label { text: "Cuva"; color: "#9db2c5" }
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
        Button { text: "⚙ SETĂRI NĂDIRE"; enabled: !root.controller || !root.controller.enabled; onClicked: settingsPopup.open() }
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
            Label { Layout.fillWidth: true; text: "Valorile se salvează automat pentru următoarea utilizare."; color: "#9db2c5"; wrapMode: Text.WordWrap }
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
                    CheckBox { Layout.columnSpan: 3; text: "RTL după eliberare"; checked: saved.rtlAfterDrop; onToggled: { saved.rtlAfterDrop = checked; root.applySettings() } }
                }
            }
            Button { Layout.alignment: Qt.AlignRight; text: "GATA"; onClicked: settingsPopup.close() }
        }
    }
    Dialog {
        id: confirmDialog; modal: true; anchors.centerIn: Overlay.overlay
        title: "Confirmă nădirea automată"
        standardButtons: Dialog.Yes | Dialog.No
        closePolicy: Popup.NoAutoClose
        Label {
            width: Math.min(400, root.width); wrapMode: Text.WordWrap
            text: "Pornești ciclul către «" + root.waypointName + "»?\n\nCuva: " + hopperBox.currentText +
                  "\nApropierea, oprirea, eliberarea, ieșirea laterală și RTL vor fi executate automat. Eliberarea este permisă numai după oprirea bărcii."
        }
        onAccepted: root.startConfirmed(root.waypoint, root.waypointName, root.selectedHopper)
    }
}
