import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    property var sonar
    property var mapping
    property var vehicle
    color: "#0b1c2e"
    radius: 10
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8
        RowLayout {
            Layout.fillWidth: true
            Label { text: "SONAR PRO • EXPERIMENTAL"; color: "#21b7ff"; font.bold: true; font.pixelSize: 17 }
            Item { Layout.fillWidth: true }
            Label { text: root.sonar && root.sonar.dataAlive ? "LIVE" : "OFFLINE"; color: root.sonar && root.sonar.dataAlive ? "#65dca4" : "#f2bd72" }
        }
        Label {
            Layout.fillWidth: true
            text: "Spațiu de test separat. Sonarul NAVO standard și comenzile H743 nu sunt modificate."
            wrapMode: Text.WordWrap; color: "#a6bdd0"
        }
        NavoSonarCard {
            Layout.fillWidth: true
            Layout.preferredHeight: 175
            depthM: root.sonar ? root.sonar.depthM : NaN
            waterTempC: root.sonar ? root.sonar.waterTempC : NaN
        }
        NavoSonarMapping {
            Layout.fillWidth: true
            Layout.fillHeight: true
            vehicle: root.vehicle
            depthM: root.sonar ? root.sonar.depthM : NaN
            waterTempC: root.sonar ? root.sonar.waterTempC : NaN
            sonarConnected: root.sonar ? root.sonar.dataAlive : false
            externalSampleIngestion: true
        }
    }
}
