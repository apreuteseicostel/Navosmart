import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    property var planController
    property var vehicle
    property color panel: "#0b1c2e"
    property color line: "#1c4262"
    property color cyan: "#21b7ff"
    property color green: "#31d67b"
    property color textMain: "#f2f7fb"
    property color textDim: "#9db2c5"

    // Friendly labels are intentionally kept separate from the ArduPilot mission
    // sequence. ArduPilot still owns WP1/WP2/... while NAVO SMART shows names
    // useful to the angler such as "Lanseta verde" or "Lanseta roșie".
    property var waypointNames: ({})
    property var persistence
    property int selectedSequence: -1
    signal waypointNameChanged(int sequence, string friendlyName)

    color: panel
    border.color: line
    radius: 10

    function friendlyName(sequence) {
        var key = sequence.toString()
        return waypointNames[key] && waypointNames[key].length ? waypointNames[key] : "WP" + sequence
    }

    function setFriendlyName(sequence, name) {
        var copy = Object.assign({}, waypointNames)
        var clean = name.trim()
        copy[sequence.toString()] = clean.length ? clean : "WP" + sequence
        waypointNames = copy
        if (persistence) persistence.setWaypointName(sequence, copy[sequence.toString()])
        waypointNameChanged(sequence, copy[sequence.toString()])
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            Label { text: "WAYPOINT-URI / PUNCTE PESCUIT"; color: root.textMain; font.bold: true; font.pixelSize: 16 }
            Item { Layout.fillWidth: true }
            Label { text: "Numele este editabil"; color: root.cyan; font.pixelSize: 11 }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: root.line }

        ListView {
            id: waypointList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 5
            model: root.planController && root.planController.missionController ? root.planController.missionController.visualItems : null

            delegate: Rectangle {
                required property var modelData
                width: waypointList.width
                height: 48
                radius: 6
                color: root.selectedSequence === modelData.sequenceNumber ? "#123d58" : "#081724"
                border.color: root.selectedSequence === modelData.sequenceNumber ? root.cyan : root.line

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        root.selectedSequence = modelData.sequenceNumber
                        nameField.text = root.friendlyName(modelData.sequenceNumber)
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 10
                    Label { text: "WP" + modelData.sequenceNumber; color: root.textDim; Layout.preferredWidth: 42 }
                    Rectangle {
                        width: 12; height: 12; radius: 6
                        color: root.friendlyName(modelData.sequenceNumber).toLowerCase().indexOf("verde") >= 0 ? "#31d67b" :
                               root.friendlyName(modelData.sequenceNumber).toLowerCase().indexOf("roș") >= 0 || root.friendlyName(modelData.sequenceNumber).toLowerCase().indexOf("ros") >= 0 ? "#ff3e55" : root.cyan
                    }
                    Label { text: root.friendlyName(modelData.sequenceNumber); color: root.textMain; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
                    Label { text: modelData.coordinate && modelData.coordinate.isValid ? modelData.coordinate.latitude.toFixed(5) + ", " + modelData.coordinate.longitude.toFixed(5) : "--"; color: root.textDim; font.pixelSize: 10 }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 92
            radius: 7
            color: "#081724"
            border.color: root.line
            RowLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8
                ColumnLayout {
                    Layout.fillWidth: true
                    Label { text: root.selectedSequence >= 0 ? "Editează numele pentru WP" + root.selectedSequence : "Selectează un waypoint"; color: root.textDim; font.pixelSize: 11 }
                    TextField {
                        id: nameField
                        Layout.fillWidth: true
                        enabled: root.selectedSequence >= 0
                        placeholderText: "Ex: Lanseta verde, Lanseta roșie, Nădire porumb"
                        color: root.textMain
                        selectByMouse: true
                        onAccepted: if (root.selectedSequence >= 0) root.setFriendlyName(root.selectedSequence, text)
                    }
                }
                Button {
                    text: "Salvează numele"
                    enabled: root.selectedSequence >= 0 && nameField.text.trim().length > 0
                    onClicked: root.setFriendlyName(root.selectedSequence, nameField.text)
                }
            }
        }

        Label {
            Layout.fillWidth: true
            text: "ArduPilot păstrează numerotarea WP; NAVO SMART afișează numele ales de tine."
            color: root.textDim
            font.pixelSize: 10
            wrapMode: Text.WordWrap
        }
    }
}
