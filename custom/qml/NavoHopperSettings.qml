import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    id: form
    required property var settings
    required property var telemetry
    property bool linkAlive: false
    property bool busy: false
    property bool critical: false
    readonly property bool serviceLive: linkAlive && telemetry.connected
    readonly property bool waterValid: linkAlive && telemetry.waterValid
    readonly property bool valid: leftOutput.valid && rightOutput.valid && leftOutput.number !== rightOutput.number &&
        leftClosed.valid && rightClosed.valid && leftOpen.valid && rightOpen.valid
    readonly property bool edited: leftOutput.number !== settings.leftOutput || rightOutput.number !== settings.rightOutput ||
        leftClosed.number !== settings.leftClosed || rightClosed.number !== settings.rightClosed ||
        leftOpen.number !== settings.leftOpen || rightOpen.number !== settings.rightOpen
    readonly property bool canSave: valid && !busy && (edited || !settings.confirmed)

    function saveCalibration() {
        if (!canSave) return
        const values = {
            leftOutput: leftOutput.number, rightOutput: rightOutput.number,
            leftClosed: leftClosed.number, rightClosed: rightClosed.number,
            leftOpen: leftOpen.number, rightOpen: rightOpen.number
        }
        settings.confirmed = false
        for (const key in values) {
            settings[key] = values[key]
            settings.setValue(key, values[key])
        }
        settings.confirmed = true
        settings.setValue("confirmed", true)
        settings.sync()
    }

    component NumberField: TextField {
        id: field
        property int minimum: 900
        property int maximum: 2100
        readonly property real number: Number(text)
        readonly property bool valid: acceptableInput && Number.isInteger(number) && number >= minimum && number <= maximum
        Layout.fillWidth: true
        Layout.minimumWidth: 40
        implicitHeight: 34
        font.pixelSize: 14
        color: "#eaf2f8"
        selectionColor: "#196079"
        horizontalAlignment: Text.AlignHCenter
        selectByMouse: true
        inputMethodHints: Qt.ImhDigitsOnly
        validator: IntValidator { bottom: field.minimum; top: field.maximum; locale: "C" }
        background: Rectangle {
            radius: 6
            color: "#0a2332"
            border.color: !field.valid ? "#ff6872" : field.activeFocus ? "#20d9ed" : "#28536a"
        }
    }

    Label { text: "CUVE & SIGURANȚĂ HARDWARE"; color: "#f4f7fb"; font.pixelSize: 15; font.bold: true }
    GridLayout {
        columns: 3
        Layout.fillWidth: true
        columnSpacing: 6
        rowSpacing: 4
        Label { text: "Cuva"; color: "#eaf2f8" }
        Label { text: "Stânga"; color: "#eaf2f8" }
        Label { text: "Dreapta"; color: "#eaf2f8" }
        Label { text: "Ieșire"; color: "#dbe5ee"; font.bold: true }
        NumberField { id: leftOutput; objectName: "hopperLeftOutput"; Accessible.name: "Ieșire cuvă stânga"; minimum: 1; maximum: 16; text: String(form.settings.leftOutput) }
        NumberField { id: rightOutput; objectName: "hopperRightOutput"; Accessible.name: "Ieșire cuvă dreapta"; minimum: 1; maximum: 16; text: String(form.settings.rightOutput) }
        Label { text: "Închis µs"; color: "#dbe5ee"; font.bold: true }
        NumberField { id: leftClosed; objectName: "hopperLeftClosed"; Accessible.name: "PWM închis stânga"; text: String(form.settings.leftClosed) }
        NumberField { id: rightClosed; objectName: "hopperRightClosed"; Accessible.name: "PWM închis dreapta"; text: String(form.settings.rightClosed) }
        Label { text: "Deschis µs"; color: "#dbe5ee"; font.bold: true }
        NumberField { id: leftOpen; objectName: "hopperLeftOpen"; Accessible.name: "PWM deschis stânga"; text: String(form.settings.leftOpen) }
        NumberField { id: rightOpen; objectName: "hopperRightOpen"; Accessible.name: "PWM deschis dreapta"; text: String(form.settings.rightOpen) }
    }
    Button {
        id: saveButton
        objectName: "saveHopperCalibration"
        Layout.fillWidth: true
        implicitHeight: 34
        text: "Salvează calibrarea"
        enabled: form.canSave
        onClicked: confirmSave.open()
        background: Rectangle {
            radius: 6
            color: saveButton.down ? "#16465a" : "#0a2332"
            border.color: saveButton.enabled ? "#20d9ed" : "#28536a"
        }
        contentItem: Label {
            text: saveButton.text
            color: saveButton.enabled ? "#eff9ff" : "#91a3b5"
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }
    Label {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        font.pixelSize: 11
        color: form.valid && !form.edited && form.settings.confirmed ? "#37e9a2" : "#ffd166"
        text: !form.valid ? "Folosește ieșiri diferite (1–16) și PWM între 900 și 2100 µs."
             : form.busy ? "Salvarea este disponibilă după terminarea acțiunii."
             : form.edited ? "Modificări nesalvate."
             : form.settings.confirmed ? "Calibrare salvată." : "Calibrare neconfirmată."
    }
    Dialog {
        id: confirmSave
        objectName: "confirmHopperCalibration"
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: Math.min(360, parent.width - 24)
        implicitHeight: 164
        modal: true
        title: "Confirmi calibrarea cuvelor?"
        standardButtons: Dialog.Save | Dialog.Cancel
        palette.window: "#071e30"
        palette.windowText: "#eff9ff"
        palette.button: "#142c3c"
        palette.buttonText: "#eff9ff"
        onAccepted: form.saveCalibration()
        Label {
            width: confirmSave.availableWidth
            wrapMode: Text.WordWrap
            color: "#eff9ff"
            text: "Confirmă că ai verificat mecanic pozițiile de închidere și deschidere pentru valorile introduse."
        }
    }
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: sensorRows.implicitHeight + 14
        radius: 7
        color: "#121a24"
        border.color: form.critical ? "#ff6872" : "#273342"
        ColumnLayout {
            id: sensorRows
            anchors.fill: parent
            anchors.margins: 7
            spacing: 3
            Label {
                objectName: "hopperMavlinkStatus"
                Layout.fillWidth: true; wrapMode: Text.WordWrap; font.pixelSize: 11; font.bold: true
                text: form.linkAlive ? "H743 • MAVLink conectat" : "H743 • fără legătură MAVLink"
                color: form.linkAlive ? "#37e9a2" : "#ffd166"
            }
            Label {
                objectName: "hopperV3Status"
                Layout.fillWidth: true; wrapMode: Text.WordWrap; font.pixelSize: 11
                text: form.serviceLive ? "NAVO V3 • serviciu activ" : "NAVO V3 • fără date recente"
                color: form.serviceLive ? "#37e9a2" : "#ffd166"
            }
            Label {
                Layout.fillWidth: true; wrapMode: Text.WordWrap; font.pixelSize: 11
                text: "Temp. baterie  " + (form.serviceLive && form.telemetry.temperatureValid
                    ? Number(form.telemetry.batteryTempC).toFixed(1) + " °C" : "—")
                color: "#eaf2f8"
            }
            Label {
                objectName: "hopperWaterDiagnostic"
                Layout.fillWidth: true; wrapMode: Text.WordWrap; font.pixelSize: 11
                text: !form.linkAlive ? "Sonda apă: H743 deconectat"
                    : form.telemetry.waterMonitorStatus === 5 ? "Sonda apă: necesită calibrare (doar ADC)"
                    : form.telemetry.waterMonitorStatus === 4 ? "Sonda apă: conflict pini / configurație Lua"
                    : form.telemetry.waterMonitorStatus === 3 ? "Sonda apă: citire eronată"
                    : form.telemetry.waterMonitorStatus === 1 ? "Sonda apă: confirmare măsurători"
                    : form.telemetry.waterMonitorStatus === 2 ? "Sonda apă: telemetrie LIVE"
                    : "Sonda apă: fără date recente"
                color: form.waterValid ? "#37e9a2" : "#ffd166"
            }
            Label {
                objectName: "hopperWaterAdcVoltage"
                Layout.fillWidth: true; wrapMode: Text.WordWrap; font.pixelSize: 11
                text: "Tensiune sondă ADC: " + (form.linkAlive &&
                      isFinite(Number(form.telemetry.waterAdcVoltage))
                      ? Number(form.telemetry.waterAdcVoltage).toFixed(3) + " V" : "—")
                color: "#91c5d8"
            }
            Label {
                objectName: "hopperWaterStatus"
                Layout.fillWidth: true; wrapMode: Text.WordWrap; font.pixelSize: 11
                text: "Apă  " + (!form.waterValid ? "—" : form.telemetry.waterDetected ? "DETECTATĂ" : "OK")
                color: !form.waterValid ? "#91a3b5" : form.telemetry.waterDetected ? "#ff6872" : "#37e9a2"
            }
        }
    }
    Item { Layout.fillHeight: true }
}
