import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
Rectangle {
 id: root
 property var controller
 color: "#0b1c2eee"
 border.color: "#1c4262"
 radius: 9
 implicitHeight: box.implicitHeight + 18
 ColumnLayout {
  id: box
  anchors.fill: parent
  anchors.margins: 9
  spacing: 5
  Label { text: "SIGURANȚĂ & FAILSAFE"; color: "white"; font.bold: true }
  Label { Layout.fillWidth: true; text: controller ? controller.status : "--"; color: controller && (controller.linkLost || controller.gpsLost) ? "#ff3e55" : "#31d67b"; font.bold: true; wrapMode: Text.WordWrap }
  GridLayout {
   columns: 3
   Layout.fillWidth: true
   Label { text: "Link G20"; color: "#9db2c5" }
   SpinBox { id: linkT; from: 5; to: 120; value: controller ? controller.linkGraceSeconds : 30; onValueModified: if (controller) controller.linkGraceSeconds = value }
   Label { text: "s"; color: "white" }
   Label { text: "GPS recovery"; color: "#9db2c5" }
   SpinBox { id: gpsT; from: 10; to: 180; value: controller ? controller.gpsRecoverySeconds : 60; onValueModified: if (controller) controller.gpsRecoverySeconds = value }
   Label { text: "s"; color: "white" }
   Label { text: "GPS → HOME"; color: "#9db2c5" }
   SpinBox { id: rtlT; from: 30; to: 300; value: controller ? controller.gpsReturnHomeSeconds : 120; onValueModified: if (controller) controller.gpsReturnHomeSeconds = value }
   Label { text: "s"; color: "white" }
  }
  Label { Layout.fillWidth: true; text: "GPS invalid: HOLD. RTL se cere numai după ce poziția GPS revine validă."; color: "#9db2c5"; font.pixelSize: 10; wrapMode: Text.WordWrap }
 }
}
