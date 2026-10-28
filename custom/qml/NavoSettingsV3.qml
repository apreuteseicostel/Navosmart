import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Compact, tabbed NAVO SMART Settings from the approved cyan/navy visual reference.
// All control actions are backed by existing NAVO modules; QGC handles its own parameters.
Rectangle {
    id: root
    property var sonar: null
    property var camera: null
    property var alerts: null
    property var audio: null
    property var steering: null
    property var g20: null
    property var energy: null
    property string cameraStreamUrl: ""
    property string cameraProtocol: "auto"
    property int selectedTab: 0
    property bool showEnergyHelp: false
    property string statusText: ""
    readonly property color surface: "#061827"
    readonly property color fill: "#0a2536"
    readonly property color line: "#1b6680"
    readonly property color cyan: "#20d9ed"
    readonly property color fg: "#eff9ff"
    readonly property color muted: "#c1d7e6"
    readonly property bool narrow: width < 890
    signal status(string message)
    signal settingsToolRequested()
    signal enableSteeringRequested()
    color: "#051521"
    border.color: "#174c68"
    border.width: 1
    radius: 10

    function saveAll() {
        // Energy preferences are persisted by QtCore.Settings when edited.
        // Camera/Kogger endpoint edits are committed only by saveEndpoints().
        if (!ethernetSettings.saveEndpoints()) {
            statusText = "Verifică porturile: valorile nu au fost salvate."
            return false
        }
        statusText = "Setări salvate • rețea, cameră și preferințe NAVO"
        status(statusText)
        return true
    }

    component NavTab: Button {
        id: tab
        property int tabIndex: 0
        property string tabIcon: ""
        property bool selected: root.selectedTab === tabIndex
        implicitHeight: 42
        implicitWidth: 120
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        ToolTip.visible: hovered
        ToolTip.text: text
        font.pixelSize: 13
        font.bold: selected
        onClicked: root.selectedTab = tabIndex
        Accessible.name: text
        background: Rectangle {
            color: tab.selected ? "#0d3446" : (tab.hovered ? "#0a2b3d" : "#061b2a")
            radius: 9
            border.color: tab.selected ? "#20d9ed" : "#167998"
            border.width: tab.selected ? 2 : 1
        }
        contentItem: RowLayout {
            spacing: 5
            Label { text: tab.tabIcon; color: "#20d9ed"; font.pixelSize: 17; font.bold: true }
            Label { Layout.fillWidth:true;Layout.minimumWidth:0;text:tab.text;color:"#eff9ff";font.pixelSize:tab.font.pixelSize;font.bold:tab.selected;elide:Text.ElideRight;horizontalAlignment:Text.AlignHCenter }
        }
    }
    component HelpDot: Button {
        id: help
        property string explanation: ""
        property bool opened: false
        implicitWidth: 26
        implicitHeight: 30
        text: "ⓘ"
        Accessible.name: explanation
        ToolTip.visible: hovered || pressed
        ToolTip.text: explanation
        ToolTip.delay: 350
        onClicked: opened = !opened
        background: Rectangle { color: "transparent" }
        contentItem: Label {
            text: help.text; font.pixelSize: 17; color: "#20d9ed"
            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
        }
    }
    component ActionButton: Button {
        id: action
        property color tint: "#20d9ed"
        implicitHeight: 38
        padding: 6
        font.pixelSize: 12
        background: Rectangle {
            color: action.hovered ? "#103d50" : "#08273a"
            border.color: action.tint
            border.width: 1.3
            radius: 9
        }
        contentItem: Label {
            text: action.text
            color: action.enabled ? action.tint : "#9aaebd"
            font.pixelSize: action.font.pixelSize
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }
    component EnergyStepper: SpinBox {
        id: spin
        implicitWidth: 117
        implicitHeight: 37
        leftPadding: 33; rightPadding: 33
        editable: true
        font.pixelSize: 14
        contentItem: TextInput {
            text: spin.textFromValue(spin.value, spin.locale)
            font: spin.font
            color: "#eff9ff"
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            readOnly: !spin.editable
            validator: spin.validator
            inputMethodHints: Qt.ImhFormattedNumbersOnly
        }
        up.indicator: Rectangle {
            x: spin.width - width
            width: 33; height: spin.height
            color: spin.up.pressed ? "#174c60" : "#0b344a"
            border.color: "#167998"
            radius: 5
            Label { anchors.centerIn: parent; text: "+"; color: spin.enabled && spin.value < spin.to ? "#20d9ed" : "#7f9daf"; font.pixelSize: 20 }
        }
        down.indicator: Rectangle {
            width: 33; height: spin.height
            color: spin.down.pressed ? "#174c60" : "#0b344a"
            border.color: "#167998"
            radius: 5
            Label { anchors.centerIn: parent; text: "−"; color: spin.enabled && spin.value > spin.from ? "#20d9ed" : "#7f9daf"; font.pixelSize: 20 }
        }
        background: Rectangle { color: "#061827"; border.color: spin.activeFocus ? "#20d9ed" : "#167998"; radius: 7 }
    }

    ScrollView {
        id: scroll
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: saveFooter.visible ? saveFooter.top : parent.bottom
        anchors.margins: 9
        clip: true
        contentWidth: availableWidth
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: contentHeight > availableHeight ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff

        ColumnLayout {
            id: layout
            width: scroll.availableWidth
            spacing: 9
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                spacing: 10
                Label { text: "⚙"; color: root.cyan; font.pixelSize: 26 }
                Label {
                    text: "SETĂRI NAVO SMART"
                    color: root.fg
                    font.pixelSize: root.narrow ? 18 : 23
                    font.bold: true
                    Layout.fillWidth: true
                }
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: tabs.implicitHeight + 10
                radius: 10
                color: "#071d2d"
                border.color: "#19546b"
                GridLayout {
                    id: tabs
                    anchors.fill: parent
                    anchors.margins: 5
                    columns: root.width < 640 ? 2 : 4
                    uniformCellWidths: true
                    columnSpacing: 6;rowSpacing: 6
                    NavTab { objectName:"settingsGeneralTab";text:"General";tabIcon:"⚙";tabIndex:0 }
                    NavTab { objectName:"settingsAdvancedTab";text:"Avansat";tabIcon:"☷";tabIndex:1 }
                    NavTab { objectName:"settingsIntegrationTab";text:"Integrare";tabIcon:"↗";tabIndex:2 }
                    NavTab { objectName:"settingsQgcTab";text:"QGroundControl";tabIcon:"◎";tabIndex:3 }
                }
            }

            ColumnLayout {
                visible: root.selectedTab === 0
                objectName:"settingsGeneralPanel"
                Layout.fillWidth: true
                spacing: 9

                GridLayout {
                    Layout.fillWidth: true
                    columns: root.narrow ? 1 : 2
                    columnSpacing: 10
                    rowSpacing: 9
                    uniformCellWidths: true
                    NavoAlertSettings {
                        Layout.fillWidth: true
                        Layout.preferredHeight: implicitHeight
                        controller: root.alerts
                        audio: root.audio
                    }
                    NavoSteeringPanel {
                        Layout.fillWidth: true
                        Layout.preferredHeight: implicitHeight
                        controller: root.steering
                        onEnableRequested: root.enableSteeringRequested()
                    }
                }
                Rectangle {
                    id: energyCard
                    Layout.fillWidth: true
                    implicitHeight: energyContent.implicitHeight + 19
                    color: "#061827"
                    border.color: "#20d9ed"
                    border.width: 1
                    radius: 10
                    ColumnLayout {
                        id: energyContent
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 9
                        spacing: 8
                        RowLayout {
                            Layout.fillWidth: true
                            Label { text: "▣"; color: root.cyan; font.pixelSize: 19 }
                            Label { text: "Rezervă energie și consum"; color: root.fg; font.pixelSize: 16; font.bold: true; Layout.fillWidth: true }
                            HelpDot {
                                explanation: "Verificarea rutei necesită măsurarea consumului real. Nu schimbă parametrii de failsafe și nu trimite automat RTL."
                                onClicked: root.showEnergyHelp = !root.showEnergyHelp
                            }
                        }
                        Rectangle { Layout.fillWidth: true; height: 1; color: "#19546b" }
                        Flow {
                            Layout.fillWidth: true
                            spacing: 12
                            RowLayout {
                                spacing: 6
                                Label { text: "Rezervă %"; color: root.fg; font.pixelSize: 12 }
                                EnergyStepper {
                                    id: reserveSpin
                                    from: 5; to: 80
                                    value: root.energy ? root.energy.reservePercent : 25
                                    onValueModified: if (root.energy) { root.energy.confirmed = false; root.energy.reservePercent = value }
                                    Accessible.name: "Rezervă energie procent"
                                }
                            }
                            Rectangle { width: 1; height: 34; color: "#19546b" }
                            RowLayout {
                                spacing: 6
                                Label { text: "Consum %/km"; color: root.fg; font.pixelSize: 12 }
                                EnergyStepper {
                                    id: consumeSpin
                                    from: 1; to: 100
                                    value: root.energy ? root.energy.consumptionPercentPerKm : 12
                                    onValueModified: if (root.energy) { root.energy.confirmed = false; root.energy.consumptionPercentPerKm = value }
                                    Accessible.name: "Consum energetic procent pe kilometru"
                                }
                            }
                            Rectangle { width: 1; height: 34; color: "#19546b" }
                            CheckBox {
                                id: energyConfirmed
                                text: "Consum verificat"
                                font.pixelSize: 12
                                palette.windowText: root.fg
                                checked: root.energy ? root.energy.confirmed : false
                                onToggled: if (root.energy) root.energy.confirmed = checked
                                ToolTip.visible: hovered
                                ToolTip.text: "Confirmă doar după calibrarea consumului pe barcă; debifează automat la schimbarea valorilor."
                            }
                        }
                        Label {
                            visible: root.showEnergyHelp
                            Layout.fillWidth: true
                            text: "Estimează energia necesară pentru navigare, nădire și Area Scan, inclusiv întoarcerea. Nu reprezintă o comandă RTL. Confirmă procentul per kilometru numai după măsurători reale."
                            color: root.muted; font.pixelSize: 11; wrapMode: Text.WordWrap
                        }
                    }
                }
            }

            ColumnLayout {
                visible: root.selectedTab === 1
                objectName:"settingsAdvancedPanel"
                Layout.fillWidth: true
                spacing: 8
                Rectangle {
                    Layout.fillWidth: true; implicitHeight: 54
                    color: root.surface; border.color: root.cyan; radius: 9
                    Label {
                        anchors.fill: parent; anchors.margins: 10
                        text: "AVANSAT • G20 / H743. Verifică mai întâi canalele în Device Tool, apoi testează comenzile pe banc."
                        color: root.fg; font.pixelSize: 12; wrapMode: Text.WordWrap
                    }
                }
                NavoG20Settings {
                    id: advancedG20
                    Layout.fillWidth: true
                    Layout.preferredHeight: implicitHeight
                    controller: root.g20
                }
            }
            ColumnLayout {
                visible: root.selectedTab === 2
                objectName:"settingsIntegrationPanel"
                Layout.fillWidth: true
                spacing: 9
                NavoEthernetSettings {
                    id: ethernetSettings
                    objectName:"settingsEthernetForms"
                    Layout.fillWidth: true
                    Layout.preferredHeight: implicitHeight
                    sonar: root.sonar
                    camera: root.camera
                    onCameraStreamUrlChanged: root.cameraStreamUrl = cameraStreamUrl
                    onCameraProtocolChanged: root.cameraProtocol = cameraProtocol
                    onStatus: function(message) { root.statusText = message; root.status(message) }
                }
            }
            Rectangle {
                visible: root.selectedTab === 3
                Layout.fillWidth: true
                implicitHeight: qgcColumn.implicitHeight + 22
                color: root.surface; border.color: root.cyan; radius: 10
                ColumnLayout {
                    id: qgcColumn
                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                    anchors.margins: 11; spacing: 10
                    Label { text: "QGROUNDCONTROL • CONFIGURARE COMPLETĂ"; color: root.fg; font.pixelSize: 16; font.bold: true }
                    Rectangle { Layout.fillWidth: true; height: 1; color: root.line }
                    Label {
                        Layout.fillWidth: true; wrapMode: Text.WordWrap; color: root.muted; font.pixelSize: 12
                        text: "Deschide setările native QGroundControl. Testele radio, calibrarea și parametrii ArduPilot trebuie verificați în instrumentele dedicate; NAVO nu oferă o clonă a acestor funcții."
                    }
                    ActionButton { objectName:"settingsOpenQgc";text: "Deschide QGroundControl"; implicitWidth: 236; onClicked: root.settingsToolRequested() }
                }
            }

            Label {
                Layout.fillWidth: true
                visible: root.statusText.length > 0
                text: root.statusText
                color: "#9be9e2"
                font.pixelSize: 11
                wrapMode: Text.WordWrap
                Accessible.name: root.statusText
            }
        }
    }
    // Keep Save accessible at the bottom of the viewport, even when cards scroll.
    Rectangle {
        id: saveFooter
        visible: root.selectedTab === 0 || root.selectedTab === 2
        objectName:"settingsSaveFooter"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 9
        anchors.rightMargin: 9
        anchors.bottomMargin: 5
        height: 45
        radius: 9
        color: "#071d2d"
        border.color: "#1b6680"
        RowLayout {
            anchors.fill: parent
            anchors.margins: 4
            spacing: 9
            Label {
                text: root.statusText.length ? root.statusText : "NAVO SMART • Setări"
                color: root.statusText.length ? "#9be9e2" : "#c1d7e6"
                font.pixelSize: 11
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
            ActionButton {
                text: "▣  Salvare"
                tint: root.cyan
                implicitWidth: 139
                implicitHeight: 37
                Accessible.name: "Salvează setările NAVO"
                onClicked: root.saveAll()
            }
        }
    }
}

