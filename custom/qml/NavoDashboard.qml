import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    // These properties are intentionally generic in V0.1. They will be bound
    // to QGC Vehicle/Facts once the overlay is pinned to the selected QGC tag.
    property real batteryPercent: 0
    property real speedMps: 0
    property real distanceHomeM: 0
    property int satellites: 0
    property real headingDeg: 0
    property string flightMode: "NECONECTAT"
    property real depthM: 0
    property bool sonarConnected: false

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        Label {
            text: "NAVO SMART"
            font.pixelSize: 26
            font.bold: true
        }

        GridLayout {
            columns: 3
            columnSpacing: 12
            rowSpacing: 8

            Label { text: "Baterie: " + Math.round(root.batteryPercent) + "%" }
            Label { text: "Viteză: " + root.speedMps.toFixed(1) + " m/s" }
            Label { text: "Acasă: " + root.distanceHomeM.toFixed(0) + " m" }
            Label { text: "Sateliți: " + root.satellites }
            Label { text: "Direcție: " + root.headingDeg.toFixed(0) + "°" }
            Label { text: "Mod: " + root.flightMode }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 8
            border.width: 1
            color: "transparent"

            Label {
                anchors.centerIn: parent
                text: "HARTĂ / TRASEU / WAYPOINTS\n(QGC Fly View va fi integrat aici)"
                horizontalAlignment: Text.AlignHCenter
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Button { text: "MANUAL" }
            Button { text: "AUTO" }
            Button { text: "RTL / ACASĂ" }
            Item { Layout.fillWidth: true }
            Label {
                text: root.sonarConnected ? ("Sonar: " + root.depthM.toFixed(1) + " m") : "Sonar: neconectat"
            }
        }
    }
}
