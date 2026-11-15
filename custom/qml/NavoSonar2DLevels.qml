import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// NAVO-specific adaptation of KoggerApp's 2D level-window and theme controls.
// UI-only: never modifies received CHART samples, native Kogger Dataset or the H743.
Item {
    id: controls
    objectName: "sonarPro2DLevels"
    property real lowerLevel: 0
    property real upperLevel: 100
    property int paletteMode: 0   // 0 NAVO night, 1 day, 2 amber
    signal levelsEdited(real lower, real upper)
    signal paletteSelected(int mode)
    implicitWidth: 280
    implicitHeight: layout.implicitHeight

    ColumnLayout {
        id: layout
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 6

        Label {
            Layout.fillWidth: true
            text: "KOGGER 2D • NIVELE ECOGRAMĂ"
            color: "#d9edf7"
            font.pixelSize: 12
            font.bold: true
            elide: Text.ElideRight
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Label {
                text: Math.round(controls.lowerLevel) + "%"
                color: "#8eddf1"
                font.pixelSize: 12
                Layout.preferredWidth: 38
            }
            RangeSlider {
                id: levels
                objectName: "sonarProLevelRange"
                Layout.fillWidth: true
                from: 0
                to: 100
                stepSize: 1
                snapMode: RangeSlider.SnapAlways
                first.value: controls.lowerLevel
                second.value: controls.upperLevel
                first.onMoved: controls.levelsEdited(Math.min(Math.round(first.value), controls.upperLevel - 1), controls.upperLevel)
                second.onMoved: controls.levelsEdited(controls.lowerLevel, Math.max(Math.round(second.value), controls.lowerLevel + 1))
                Accessible.name: "Fereastra nivelurilor ecogramei, minim și maxim"
            }
            Label {
                text: Math.round(controls.upperLevel) + "%"
                color: "#8eddf1"
                font.pixelSize: 12
                horizontalAlignment: Text.AlignRight
                Layout.preferredWidth: 38
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 5
            Repeater {
                model: [
                    { label: "NAVO", value: 0 },
                    { label: "ZI", value: 1 },
                    { label: "AMBRĂ", value: 2 }
                ]
                delegate: Button {
                    id: paletteButton
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: 32
                    padding: 3
                    text: modelData.label
                    font.pixelSize: 11
                    checkable: true
                    checked: controls.paletteMode === modelData.value
                    Accessible.name: "Paletă " + modelData.label
                    background: Rectangle {
                        radius: 5
                        color: paletteButton.checked ? "#176b86" : "#102435"
                        border.color: paletteButton.checked ? "#45d5f5" : "#31536c"
                        border.width: paletteButton.checked ? 2 : 1
                    }
                    onClicked: controls.paletteSelected(modelData.value)
                }
            }
        }
        Label {
            Layout.fillWidth: true
            text: "Reglaje doar pentru afișare; ecourile CHART și datele GPS rămân originale."
            wrapMode: Text.WordWrap
            color: "#9db2c5"
            font.pixelSize: 10
        }
    }
}
