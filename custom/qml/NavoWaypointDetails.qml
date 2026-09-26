import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtPositioning

Rectangle {
    id: root
    property var vehicle
    property var waypoint
    property string friendlyName: waypoint ? "WP" + waypoint.sequenceNumber : "Waypoint"
    property real savedDepthM: NaN
    property real savedWaterTempC: NaN
    property string note: ""

    signal navigateRequested(var waypoint)
    signal editRequested(var waypoint)
    signal deleteRequested(var waypoint)

    readonly property var wpCoordinate: waypoint ? waypoint.coordinate : QtPositioning.coordinate()
    readonly property bool coordinateValid: wpCoordinate && wpCoordinate.isValid
    readonly property bool vehiclePositionValid: vehicle && vehicle.coordinate && vehicle.coordinate.isValid
    readonly property real distanceFromBoatM: vehiclePositionValid && coordinateValid ? vehicle.coordinate.distanceTo(wpCoordinate) : NaN
    readonly property real bearingFromBoatDeg: vehiclePositionValid && coordinateValid ? vehicle.coordinate.azimuthTo(wpCoordinate) : NaN
    readonly property bool homeValid: vehicle && vehicle.homePosition && vehicle.homePosition.isValid
    readonly property real distanceFromHomeM: homeValid && coordinateValid ? vehicle.homePosition.distanceTo(wpCoordinate) : NaN

    color: "#071827ee"
    border.color: "#21b7ff"
    border.width: 1
    radius: 10
    width: 350
    implicitHeight: detailsColumn.implicitHeight + 28

    function fmt(v, decimals, suffix) {
        return isNaN(v) ? "--" : Number(v).toFixed(decimals) + suffix
    }

    ColumnLayout {
        id: detailsColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 14
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            Label { text: root.friendlyName; color: "white"; font.pixelSize: 18; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
            Label { text: root.waypoint ? "WP" + root.waypoint.sequenceNumber : ""; color: "#9db2c5" }
        }
        Rectangle { Layout.fillWidth: true; height: 1; color: "#1c4262" }

        DetailLine { title: "Distanță de la barcă"; value: root.fmt(root.distanceFromBoatM, 0, " m") }
        DetailLine { title: "Distanță de la HOME"; value: root.fmt(root.distanceFromHomeM, 0, " m") }
        DetailLine { title: "Direcție spre punct"; value: root.fmt(root.bearingFromBoatDeg, 0, "°") }
        DetailLine { title: "Adâncime salvată"; value: root.fmt(root.savedDepthM, 1, " m") }
        DetailLine { title: "Temperatura apei"; value: root.fmt(root.savedWaterTempC, 1, " °C") }
        DetailLine { title: "Latitudine"; value: root.coordinateValid ? root.wpCoordinate.latitude.toFixed(6) : "--" }
        DetailLine { title: "Longitudine"; value: root.coordinateValid ? root.wpCoordinate.longitude.toFixed(6) : "--" }

        Label {
            visible: root.note.length > 0
            Layout.fillWidth: true
            text: "Notiță: " + root.note
            color: "#d4e2ed"
            wrapMode: Text.WordWrap
            font.pixelSize: 11
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 7
            Button { width:42;height:38;ToolTip.visible:hovered;ToolTip.text:"Navighează aici";enabled:root.vehiclePositionValid&&root.coordinateValid;contentItem:Image{anchors.centerIn:parent;width:24;height:24;source:"qrc:/qml/NavoSmart/icons/navigate.svg"};onClicked:root.navigateRequested(root.waypoint) }
            Button { width:42;height:38;ToolTip.visible:hovered;ToolTip.text:"Editează";contentItem:Image{anchors.centerIn:parent;width:24;height:24;source:"qrc:/qml/NavoSmart/icons/edit.svg"};onClicked:root.editRequested(root.waypoint) }
        }
    }

    component DetailLine: RowLayout {
        property string title: ""
        property string value: "--"
        Layout.fillWidth: true
        Label { text: parent.title; color: "#9db2c5"; font.pixelSize: 11 }
        Item { Layout.fillWidth: true }
        Label { text: parent.value; color: "white"; font.bold: true; font.pixelSize: 12 }
    }
}
