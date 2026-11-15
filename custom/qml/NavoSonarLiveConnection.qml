import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCore

// Both PRO B V2 and PRO KGR use the same NavoSonarEthernet controller.
// This dialog never owns a transport, decoder or another Kogger Dataset.
Dialog {
    id: root
    objectName: "navoSharedSonarLiveConnection"
    property var sonar: null
    property bool udpChoice: false
    property string feedback: ""
    title: "Kogger • conexiune sonar LIVE"
    modal: true
    focus: true
    width: Math.min(430, parent ? parent.width - 18 : 430)
    height: Math.min(350, parent ? parent.height - 18 : 350)
    anchors.centerIn: parent

    Settings {
        id: saved
        category: "NavoEthernet"
        property string sonarHost: ""
        property int sonarPort: 0
        property bool sonarUdp: false
    }

    onOpened: {
        hostField.text = sonar && sonar.host ? String(sonar.host) : saved.sonarHost
        portField.text = sonar && sonar.port > 0 ? String(sonar.port)
                        : saved.sonarPort > 0 ? String(saved.sonarPort) : ""
        udpChoice = sonar ? !!sonar.udp : saved.sonarUdp
        feedback = ""
    }

    function applyAndConnect() {
        if (!sonar) { feedback = "Controllerul sonar nu este disponibil"; return }
        const host = hostField.text.trim()
        const port = Number(portField.text)
        if (!Number.isInteger(port) || port < 1 || port > 65535
                || (!udpChoice && !host.length)) {
            feedback = "Completează hostul TCP și portul 1–65535"
            return
        }
        // Same settings namespace as the dashboard Ethernet settings and
        // connectivity auto-reconnect service. No second socket is created.
        saved.sonarHost = host
        saved.sonarPort = port
        saved.sonarUdp = udpChoice
        saved.setValue("sonarHost", host)
        saved.setValue("sonarPort", port)
        saved.setValue("sonarUdp", udpChoice)
        saved.sync()

        sonar.host = host
        sonar.port = port
        sonar.udp = udpChoice
        sonar.connectSonar() // Deliberately ends replay before starting real transport.
        feedback = "Se inițiază conexiunea " + (udpChoice ? "UDP" : "TCP")
                   + " • verifică LIVE și numărul de coloane CHART"
    }
    function disconnectLive() {
        if (!sonar) return
        sonar.disconnectSonar()
        feedback = "Conexiunea sonar a fost închisă"
    }

    contentItem: ColumnLayout {
        spacing: 7
        Label {
            Layout.fillWidth: true
            text: !root.sonar ? "Controller sonar indisponibil"
                : root.sonar.replayMode ? "REPLAY • conectarea LIVE va opri redarea fișierului"
                : root.sonar.dataAlive ? "LIVE • se primesc coloane CHART"
                : root.sonar.connected ? "Conectat • aștept date CHART valide"
                : "OFFLINE • " + (root.sonar.status || "fără conexiune")
            color: root.sonar && root.sonar.dataAlive ? "#28bd7b" : "#f3c57b"
            wrapMode: Text.WordWrap
        }
        RowLayout {
            Layout.fillWidth: true
            Label { text: "Host / IP"; Layout.preferredWidth: 78 }
            TextField {
                id: hostField
                objectName: "sonarLiveHostField"
                Layout.fillWidth: true
                placeholderText: "Ex. 192.168.144.7"
                selectByMouse: true
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Label { text: "Port"; Layout.preferredWidth: 78 }
            TextField {
                id: portField
                objectName: "sonarLivePortField"
                Layout.fillWidth: true
                placeholderText: "1–65535"
                inputMethodHints: Qt.ImhDigitsOnly
                validator: IntValidator { bottom: 1; top: 65535 }
            }
            Button {
                objectName: "sonarLiveProtocolTcp"
                text: "TCP"
                checkable: true
                checked: !root.udpChoice
                onClicked: root.udpChoice = false
            }
            Button {
                objectName: "sonarLiveProtocolUdp"
                text: "UDP"
                checkable: true
                checked: root.udpChoice
                onClicked: root.udpChoice = true
            }
        }
        Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font.pixelSize: 11
            text: root.sonar ?
                "RX: " + root.sonar.rxBytes + " B / " + root.sonar.rxChunks
                + " pachete • CHART: " + root.sonar.nativeChartRecords
                + " • procesate: " + root.sonar.processedColumns
                + " • respinse: " + root.sonar.nativeChartRejected : "RX: —"
            color: "#88afc4"
        }
        Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            visible: root.feedback.length > 0
            text: root.feedback
            color: "#d4e8f5"
        }
        Item { Layout.fillHeight: true }
        RowLayout {
            Layout.fillWidth: true
            Button {
                text: "CONECTEAZĂ"
                objectName: "sonarLiveConnect"
                Layout.fillWidth: true
                onClicked: root.applyAndConnect()
            }
            Button {
                text: "DECONECTEAZĂ"
                objectName: "sonarLiveDisconnect"
                Layout.fillWidth: true
                enabled: !!(root.sonar && (root.sonar.connected || root.sonar.replayMode))
                onClicked: root.disconnectLive()
            }
            Button { text: "ÎNCHIDE"; onClicked: root.close() }
        }
    }
}
