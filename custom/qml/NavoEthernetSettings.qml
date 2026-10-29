import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCore
import NavoSmart.Backend 1.0

// NAVO V3 compact Ethernet/sonar/camera configuration.
// Real, editable endpoints and real connection actions; no demo values.
Rectangle {
    id: root
    property var sonar
    property var camera
    property string cameraStreamUrl: ""
    property string cameraProtocol: "auto"
    readonly property bool compact: width < 750
    readonly property color accent: "#20d9ed"
    readonly property color bright: "#eff9ff"
    readonly property color subdued: "#c1d7e6"
    readonly property color mint: "#37e9a2"
    readonly property color warning: "#ffd166"
    readonly property color danger: "#ff6872"
    signal status(string text)

    color: "transparent"
    implicitHeight: body.implicitHeight

    Settings {
        id: cfg
        category: "NavoEthernet"
        property string sonarHost: ""
        property int sonarPort: 0
        property bool sonarUdp: false
        property string cameraHost: ""
        property int cameraPort: 0
        property bool cameraUdp: false
        property string cameraStreamUrl: ""
        property string cameraProtocol: "auto"
        property bool connectOnStartup: true
    }
    NavoLanDiscovery {
        id: lanDiscovery
        protectedHost: root.sonar && root.sonar.connected ? root.sonar.host : ""
        serialPort: parseInt(sonarPort.text) || 8899
    }
    function loadEndpoints() {
        if (sonar) { sonar.host = cfg.sonarHost; sonar.port = cfg.sonarPort; sonar.udp = cfg.sonarUdp }
        if (camera) { camera.host = cfg.cameraHost; camera.port = cfg.cameraPort; camera.udp = cfg.cameraUdp }
    }
    function saveEndpoints() {
        if ((sonarPort.text.length && !sonarPort.acceptableInput) ||
            (cameraPort.text.length && !cameraPort.acceptableInput)) {
            status("Port invalid: folosește valori între 1 și 65535")
            return false
        }
        cfg.sonarHost = sonarHost.text.trim()
        cfg.sonarPort = parseInt(sonarPort.text) || 0
        cfg.sonarUdp = sonarUdp.checked
        cfg.cameraHost = cameraHost.text.trim()
        cfg.cameraPort = parseInt(cameraPort.text) || 0
        cfg.cameraUdp = cameraUdp.checked
        cfg.cameraStreamUrl = streamUrl.text.trim()
        cfg.cameraProtocol = protocol.currentValue
        root.cameraStreamUrl = cfg.cameraStreamUrl
        root.cameraProtocol = cfg.cameraProtocol
        loadEndpoints()
        status("Setări Ethernet, Kogger și cameră salvate")
        return true
    }
    Component.onCompleted: {
        loadEndpoints()
        root.cameraStreamUrl = cfg.cameraStreamUrl
        root.cameraProtocol = cfg.cameraProtocol
    }

    component NavField: TextField {
        id: field
        Layout.minimumWidth: 0
        implicitHeight: 34
        font.pixelSize: 12
        color: "#eff9ff"
        placeholderTextColor: "#9ebacf"
        selectByMouse: true
        padding: 8
        background: Rectangle {
            radius: 7
            color: "#092439"
            border.width: field.activeFocus ? 2 : 1
            border.color: field.activeFocus ? "#20d9ed" : "#537b91"
        }
    }
    component SmallHelp: Button {
        id: help
        property string hint: ""
        implicitWidth: 25
        implicitHeight: 29
        padding: 0
        text: "ⓘ"
        Accessible.name: hint
        ToolTip.visible: hovered || pressed
        ToolTip.delay: 250
        ToolTip.text: hint
        background: Rectangle { color: "transparent" }
        contentItem: Label {
            text: help.text; color: "#40e5fc"; font.pixelSize: 18
            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
        }
    }
    component NavCommand: Button {
        id: command
        property color commandColor: "#20d9ed"
        implicitHeight: 34
        implicitWidth: Math.ceil(contentItem.implicitWidth) + leftPadding + rightPadding
        padding: 6
        font.pixelSize: 12
        font.bold: true
        background: Rectangle {
            radius: 8
            color: command.down ? "#17495b" : (command.hovered ? "#103449" : "#071d2a")
            border.color: command.commandColor
            border.width: 1.3
        }
        contentItem: Label {
            text: command.text
            color: command.enabled ? command.commandColor : "#a4b7c6"
            font: command.font
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }
    component TransportSelector: Rectangle {
        id: transportSelector
        property bool checked: false // Existing persisted endpoint flag: false=TCP, true=UDP.
        implicitWidth: 132
        implicitHeight: 32
        Layout.preferredWidth: 132
        Layout.maximumWidth: 132
        color: "#092439"
        radius: 7
        border.color: "#537b91"
        RowLayout {
            anchors.fill: parent
            anchors.margins: 3
            spacing: 3
            Repeater {
                model: ["TCP", "UDP"]
                delegate: Button {
                    id: transportChoice
                    required property string modelData
                    required property int index
                    readonly property bool selected: transportSelector.checked === (index === 1)
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    padding: 0
                    text: modelData
                    Accessible.role: Accessible.RadioButton
                    Accessible.name: modelData
                    Accessible.checkable: true
                    Accessible.checked: selected
                    onClicked: transportSelector.checked = index === 1
                    background: Rectangle {
                        radius: 5
                        color: transportChoice.selected ? "#17634f" : "transparent"
                        border.color: transportChoice.activeFocus ? root.bright : (transportChoice.selected ? root.mint : "transparent")
                    }
                    contentItem: Label {
                        text: transportChoice.text
                        color: transportChoice.selected ? root.mint : root.subdued
                        font.pixelSize: 12
                        font.bold: transportChoice.selected
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }
    }
    component NavSelect: ComboBox {
        id: selection
        implicitHeight: 34
        font.pixelSize: 12
        contentItem: Label {
            text: selection.displayText
            color: "#eff9ff"
            leftPadding: 10
            rightPadding: 27
            font: selection.font
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
        indicator: Label {
            x: selection.width - width - 10
            anchors.verticalCenter: parent.verticalCenter
            text: "⌄"
            color: "#20d9ed"
            font.pixelSize: 17
        }
        background: Rectangle {
            radius: 7
            color: "#092439"
            border.color: selection.activeFocus ? "#20d9ed" : "#537b91"
        }
        delegate: ItemDelegate {
            width: selection.width - 8
            implicitHeight: 32
            highlighted: selection.highlightedIndex === index
            contentItem: Label {
                text: modelData.text
                color: "#eff9ff"
                leftPadding: 8
                verticalAlignment: Text.AlignVCenter
                font.pixelSize: 12
            }
            background: Rectangle { radius: 6; color: parent.highlighted ? "#17485a" : "#092439" }
        }
        popup: Popup {
            y: selection.height - 1
            width: selection.width
            implicitHeight: Math.min(contentItem.implicitHeight + 8, 165)
            padding: 4
            contentItem: ListView {
                clip: true
                implicitHeight: contentHeight
                model: selection.popup.visible ? selection.delegateModel : null
                currentIndex: selection.highlightedIndex
                ScrollIndicator.vertical: ScrollIndicator {}
            }
            background: Rectangle { color: "#071d2d"; border.color: "#20d9ed"; radius: 8 }
        }
    }

    ColumnLayout {
        id: body
        anchors.fill: parent
        spacing: 8
        GridLayout {
            id: panels
            Layout.fillWidth: true
            columns: root.compact ? 1 : 2
            columnSpacing: 10
            rowSpacing: 9
            uniformCellWidths: false

            Rectangle {
                id: cameraBox
                objectName: "settingsCameraBox"
                Layout.fillWidth: true
                Layout.preferredWidth: root.compact ? root.width : root.width*0.59
                // Include every form row, preview and playback control in the card.
                Layout.minimumHeight: cameraContent.implicitHeight + 20
                Layout.preferredHeight: Math.max(root.compact ? 335 : 264, cameraContent.implicitHeight + 20)
                color: "#061827"
                border.color: "#20d9ed"
                border.width: 1
                radius: 10
                ColumnLayout {
                    id: cameraContent
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 7
                    RowLayout {
                        Layout.fillWidth: true
                        Label { text: "▣"; color: "#20d9ed"; font.pixelSize: 22 }
                        Label { text: "Cameră față"; color: "#eff9ff"; font.pixelSize: 17; font.bold: true; Layout.fillWidth: true }
                        SmallHelp { hint: "Cameră IP prin LAN. Setează URL-ul video și salvează înainte de a apăsa Play." }
                    }
                    Rectangle { Layout.fillWidth: true; height: 1; color: "#18627b" }

                    GridLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        columns: root.compact ? 1 : 2
                        columnSpacing: 9
                        rowSpacing: 5
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            spacing: 5
                            GridLayout {
                                Layout.fillWidth: true
                                columns: 2
                                columnSpacing: 7
                                rowSpacing: 5
                                Label { text: "IP / Host"; color: root.bright; font.pixelSize: 12 }
                                NavField { id: cameraHost; objectName: "settingsCameraHost"; Layout.fillWidth: true; text: cfg.cameraHost; placeholderText: "192.168.x.x"; Accessible.name: "Adresă IP cameră" }
                                Label { text: "Port"; color: root.bright; font.pixelSize: 12 }
                                NavField { id: cameraPort; objectName: "settingsCameraPort"; Layout.fillWidth: true; text: cfg.cameraPort > 0 ? String(cfg.cameraPort) : ""; validator: IntValidator { bottom: 1; top: 65535 } inputMethodHints: Qt.ImhDigitsOnly; placeholderText: "554"; Accessible.name: "Port rețea cameră" }
                                Label { text: "Transport"; color: root.bright; font.pixelSize: 12 }
                                TransportSelector { id: cameraUdp; objectName: "settingsCameraTransport"; checked: cfg.cameraUdp }
                                Label { text: "URL video"; color: root.bright; font.pixelSize: 12 }
                                NavField { id: streamUrl; objectName: "settingsStreamUrl"; Layout.fillWidth: true; text: cfg.cameraStreamUrl; placeholderText: "rtsp://... sau http://..."; Accessible.name: "URL video cameră" }
                                Label { text: "Protocol"; color: root.bright; font.pixelSize: 12 }
                                NavSelect {
                                    id: protocol
                                    Layout.fillWidth: true
                                    textRole: "text"; valueRole: "value"
                                    model: [{text:"AUTO",value:"auto"}, {text:"RTSP",value:"rtsp"}, {text:"MJPEG/HTTP",value:"mjpeg"}]
                                    Component.onCompleted: { var i = indexOfValue(cfg.cameraProtocol); if (i >= 0) currentIndex = i }
                                }
                            }
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.minimumWidth: root.compact ? 0 : 155
                            id: cameraPreview
                            objectName: "settingsCameraPreview"
                            Layout.minimumHeight: previewContent.implicitHeight + 14
                            Layout.preferredHeight: Math.max(150, previewContent.implicitHeight + 14)
                            radius: 8
                            color: "#081f2e"
                            border.color: "#2f849b"
                            ColumnLayout {
                                id: previewContent
                                anchors.fill: parent
                                anchors.margins: 7
                                spacing: 4
                                Label { text: "Previzualizare video"; color: root.bright; font.pixelSize: 12; font.bold: true }
                                Label { text: "Stare: " + videoTest.status; color: videoTest.live ? root.mint : (videoTest.status==="NO URL" ? root.subdued : root.danger); font.pixelSize: 11; elide: Text.ElideRight; Layout.fillWidth: true }
                                NavoVideoPlayer {
                                    id: videoTest
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    Layout.minimumHeight: 72
                                    Layout.preferredHeight: 96
                                    streamUrl: streamUrl.text
                                    protocol: protocol.currentValue
                                    onVideoError: function(message) { root.status("Video: " + message) }
                                }
                                RowLayout {
                                    Layout.alignment: Qt.AlignHCenter
                                    spacing: 9
                                    NavCommand {
                                        text: "▶"
                                        Accessible.name: "Pornește test video"
                                        ToolTip.visible: hovered; ToolTip.text: "Pornește fluxul video configurat"
                                        commandColor: root.mint
                                        Layout.preferredWidth: 55
                                        enabled: streamUrl.text.trim().length > 0
                                        onClicked: { if (root.saveEndpoints()) videoTest.start() }
                                    }
                                    NavCommand {
                                        text: "■"
                                        Accessible.name: "Oprește test video"
                                        ToolTip.visible: hovered; ToolTip.text: "Oprește fluxul video"
                                        commandColor: root.danger
                                        Layout.preferredWidth: 55
                                        onClicked: videoTest.stop()
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: sonarBox
                Layout.fillWidth: true
                Layout.preferredWidth: root.compact ? root.width : root.width*0.36
                Layout.preferredHeight: Math.max(root.compact ? 231 : 264, sonarContent.implicitHeight + 20)
                color: "#061827"
                border.color: "#20d9ed"
                border.width: 1
                radius: 10
                ColumnLayout {
                    id: sonarContent
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 7
                    RowLayout {
                        Layout.fillWidth: true
                        Image { source: "qrc:/qml/NavoSmart/icons/sonar.svg"; Layout.preferredWidth: 24; Layout.preferredHeight: 24 }
                        Label { text: "Kogger Sonar"; Layout.fillWidth: true; color: "#eff9ff"; font.pixelSize: 17; font.bold: true }
                        SmallHelp { hint: "NAVO folosește Kogger prin TCP/UDP Ethernet; setările de baud serial nu sunt aplicabile adaptorului LAN." }
                    }
                    Rectangle { Layout.fillWidth: true; height: 1; color: "#18627b" }
                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2; columnSpacing: 8; rowSpacing: 7
                        Label { text: "IP / Host"; color: root.bright; font.pixelSize: 12 }
                        NavField { id: sonarHost; objectName: "settingsSonarHost"; Layout.fillWidth: true; text: cfg.sonarHost; placeholderText: "192.168.x.x"; Accessible.name: "IP Kogger" }
                        Label { text: "Port"; color: root.bright; font.pixelSize: 12 }
                        NavField { id: sonarPort; objectName: "settingsSonarPort"; Layout.fillWidth: true; text: cfg.sonarPort > 0 ? String(cfg.sonarPort) : ""; validator: IntValidator { bottom: 1; top: 65535 } inputMethodHints: Qt.ImhDigitsOnly; placeholderText: "8899"; Accessible.name: "Port Kogger" }
                        Label { text: "Transport"; color: root.bright; font.pixelSize: 12 }
                        TransportSelector { id: sonarUdp; objectName: "settingsSonarTransport"; checked: cfg.sonarUdp }
                    }
                    Label {
                        Layout.fillWidth: true
                        objectName: "settingsSonarStatus"
                        text: !root.sonar ? "Stare: OFFLINE" : root.sonar.replayMode ? "Stare: REDARE • fără conexiune live" :
                              "Stare " + (root.sonar.udp ? "UDP" : "TCP") + ": " +
                              (root.sonar.dataAlive ? "KOGGER LIVE" : root.sonar.status === "RX DATA" ? "Date recepționate • fără ecogramă validă" : root.sonar.status)
                        color: root.sonar && !root.sonar.replayMode && root.sonar.dataAlive ? root.mint : root.subdued
                        font.pixelSize: 11; wrapMode: Text.WordWrap
                    }
                    Label {
                        Layout.fillWidth: true
                        visible: !!root.sonar && sonarUdp.checked !== root.sonar.udp
                        text: "Selectat: " + (sonarUdp.checked ? "UDP" : "TCP") + " • apasă Conectează pentru aplicare"
                        color: root.warning
                        font.pixelSize: 10; wrapMode: Text.WordWrap
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 7
                        NavCommand { objectName: "settingsSonarConnect"; text: "Conectează"; Layout.preferredWidth: 108; Layout.maximumWidth: 108; Layout.preferredHeight: 32; commandColor: root.mint; enabled: !!root.sonar && (sonarUdp.checked || sonarHost.text.trim().length > 0) && sonarPort.acceptableInput && sonarPort.text.length > 0; onClicked: { if (root.saveEndpoints()) root.sonar.connectSonar() } }
                        NavCommand { objectName: "settingsSonarStop"; text: "Stop"; Layout.preferredWidth: 53; Layout.maximumWidth: 53; Layout.preferredHeight: 32; commandColor: root.danger; enabled: !!root.sonar; onClicked: root.sonar.disconnectSonar() }
                        Item { Layout.fillWidth: true }
                    }
                    Item { Layout.fillHeight: true }
                }
            }
        }
        GridLayout {
            Layout.fillWidth: true
            columns: root.width < 500 ? 2 : 3
            columnSpacing: 10
            rowSpacing: 5
            CheckBox { Layout.columnSpan: root.width < 500 ? 2 : 1; Layout.fillWidth: true; text: "Conectare Kogger la pornire"; checked: cfg.connectOnStartup; onToggled: cfg.connectOnStartup = checked; palette.windowText: root.bright; font.pixelSize: 11 }
            NavCommand { text: lanDiscovery.scanning ? "Oprește căutarea" : "Caută LAN"; commandColor: root.accent; onClicked: lanDiscovery.scanning ? lanDiscovery.stop() : lanDiscovery.scan() }
            Label { text: lanDiscovery.scanning ? "Căutare..." : (lanDiscovery.devices.length + " dispozitive"); color: root.subdued; font.pixelSize: 10 }
        }
        ListView {
            visible: lanDiscovery.devices.length > 0
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? Math.min(98, lanDiscovery.devices.length*34+6) : 0
            clip: true
            model: lanDiscovery.devices
            spacing: 2
            delegate: RowLayout {
                required property var modelData
                width: ListView.view.width
                height: 33
                Label { Layout.fillWidth: true; text: modelData.host + ":" + modelData.port + " • " + modelData.role; color: root.bright; font.pixelSize: 11; elide: Text.ElideRight }
                NavCommand { text: "Sonar"; enabled: modelData.role!=="RTSP" && modelData.role!=="USR • interfață web"; onClicked: { sonarHost.text=modelData.host; sonarPort.text=String(modelData.port); sonarUdp.checked=false; root.status("Adresă sonar selectată; verifică și salvează.") } }
                NavCommand { text: "Cameră"; onClicked: { cameraHost.text=modelData.host; cameraPort.text=String(modelData.port); cameraUdp.checked=false; if(modelData.role==="RTSP") { streamUrl.text="rtsp://"+modelData.host+":"+modelData.port+"/"; protocol.currentIndex=protocol.indexOfValue("rtsp") }; root.status("Adresă cameră selectată; verifică și salvează.") } }
            }
        }
    }
}


