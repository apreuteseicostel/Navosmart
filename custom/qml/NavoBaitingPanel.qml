import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    property var controller
    property var waypoint
    property string waypointName: waypoint ? "WP" + waypoint.sequenceNumber : "Niciun punct"
    property int selectedHopper: 1
    signal startConfirmed(var waypoint, string name, int hopper)
    signal abortRequested()

    color: "#0b1c2eee"
    border.color: "#21b7ff"
    radius: 10
    width: 310
    implicitHeight: content.implicitHeight + 24

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        Label { text: "NĂDIRE AUTOMATĂ"; color: "white"; font.bold: true; font.pixelSize: 15 }
        Label { text: root.waypointName; color: "#21b7ff"; font.bold: true }

        Label { text: "Cuva"; color: "#9db2c5" }
        ComboBox {
            id: hopperBox
            Layout.fillWidth: true
            model: ["Stânga", "Dreapta", "Ambele", "Fără eliberare"]
            onCurrentIndexChanged: root.selectedHopper = currentIndex === 0 ? 1 : (currentIndex === 1 ? 2 : (currentIndex === 2 ? 3 : 0))
        }

        GridLayout {
            columns: 2
            Layout.fillWidth: true
            Label { text: "Mod silențios"; color: "#9db2c5" }
            Label { text: controller ? controller.silentRadiusM.toFixed(0) + " m" : "--"; color: "white" }
            Label { text: "Ultimii metri"; color: "#9db2c5" }
            Label { text: controller ? controller.finalRadiusM.toFixed(0) + " m" : "--"; color: "white" }
            Label { text: "Viteză finală"; color: "#9db2c5" }
            Label { text: controller ? controller.finalSpeedMps.toFixed(1) + " m/s" : "--"; color: "white" }
            Label { text: "Ieșire laterală"; color: "#9db2c5" }
            Label { text: controller ? controller.exitDistanceM.toFixed(0) + " m" : "--"; color: "white" }
        }

        RowLayout {
            Layout.fillWidth: true
            Button {
                Layout.fillWidth: true
                text: controller && controller.enabled ? "NĂDIRE ÎN CURS" : "NĂDIRE AUTOMATĂ"
                enabled: root.waypoint && controller && !controller.enabled
                onClicked: confirmDialog.open()
            }
            Button {
                text: "OPREȘTE"
                enabled: controller && controller.enabled
                onClicked: root.abortRequested()
            }
        }

        Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: controller ? "Stare: " + controller.stateText(controller.state) : ""
            color: controller && controller.enabled ? "#31d67b" : "#9db2c5"
            font.bold: controller && controller.enabled
        }
    }

    Dialog {
        id: confirmDialog
        modal: true
        anchors.centerIn: Overlay.overlay
        title: "Confirmă nădirea automată"
        standardButtons: Dialog.Yes | Dialog.No
        closePolicy: Popup.NoAutoClose
        Label {
            width: 380
            wrapMode: Text.WordWrap
            text: "Pornești ciclul automat către «" + root.waypointName + "»?\n\n" +
                  "Cuva: " + hopperBox.currentText + "\n" +
                  "Barca va încetini automat, va ajunge la punct, va solicita eliberarea cuvei, va ieși lateral și apoi va porni RTL.\n\n" +
                  "Folosește funcția numai după testarea pe uscat și la viteză redusă pe apă."
        }
        onAccepted: root.startConfirmed(root.waypoint, root.waypointName, root.selectedHopper)
    }
}
