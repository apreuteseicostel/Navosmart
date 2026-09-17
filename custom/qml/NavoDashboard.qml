import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    implicitWidth: 1280
    implicitHeight: 720

    // V0.1 dashboard contract. Next step binds these to QGC Vehicle/Facts.
    property real batteryPercent: 87
    property real batteryVoltage: 23.4
    property real speedMps: 1.8
    property real distanceHomeM: 328
    property int satellites: 12
    property real headingDeg: 278
    property string flightMode: "AUTO"
    property real depthM: 3.2
    property real waterTempC: 18.6
    property bool vehicleConnected: true
    property bool gpsRtk: true
    property bool sonarConnected: true
    property int waypointCount: 3
    property real routeLengthM: 245

    readonly property color bg: "#06111f"
    readonly property color panel: "#0b1c2e"
    readonly property color panel2: "#10273d"
    readonly property color line: "#1c4262"
    readonly property color cyan: "#21b7ff"
    readonly property color green: "#31d67b"
    readonly property color textMain: "#f2f7fb"
    readonly property color textDim: "#9db2c5"
    readonly property color danger: "#ff3e55"

    Rectangle { anchors.fill: parent; color: root.bg }

    // Header
    Rectangle {
        id: header
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        height: 72; color: "#071827"; border.color: root.line

        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 20; anchors.rightMargin: 20; spacing: 18
            ColumnLayout {
                spacing: 0
                Label { text: "NAVO SMART"; color: root.cyan; font.pixelSize: 25; font.bold: true }
                Label { text: "Pescarul lu peste"; color: root.textDim; font.pixelSize: 12 }
            }
            Item { Layout.fillWidth: true }
            StatusPill { label: root.gpsRtk ? "GPS RTK" : "GPS"; value: root.satellites + " sat"; ok: root.satellites >= 8 }
            StatusPill { label: "BATERIE"; value: Math.round(root.batteryPercent) + "%  " + root.batteryVoltage.toFixed(1) + "V"; ok: root.batteryPercent > 25 }
            StatusPill { label: "VITEZĂ"; value: root.speedMps.toFixed(1) + " m/s"; ok: true }
            StatusPill { label: "DIRECȚIE"; value: Math.round(root.headingDeg) + "°"; ok: true }
            StatusPill { label: "MOD"; value: root.flightMode; ok: root.flightMode === "AUTO" }
        }
    }

    // Left navigation
    Rectangle {
        id: sidebar
        anchors.left: parent.left; anchors.top: header.bottom; anchors.bottom: footer.top
        width: 190; color: "#071522"; border.color: root.line
        ColumnLayout {
            anchors.fill: parent; anchors.margins: 12; spacing: 8
            NavButton { text: "Hartă"; active: true }
            NavButton { text: "Sonar" }
            NavButton { text: "Puncte" }
            NavButton { text: "Trasee" }
            NavButton { text: "Setări" }
            Item { Layout.fillHeight: true }
            Label { text: "ArduPilot Rover"; color: root.textDim; font.pixelSize: 11 }
            Label { text: "Matek H743-WING V3"; color: root.textDim; font.pixelSize: 10 }
        }
    }

    // Main map workspace
    Rectangle {
        id: mapPanel
        anchors.left: sidebar.right; anchors.right: rightPanel.left
        anchors.top: header.bottom; anchors.bottom: footer.top
        anchors.margins: 10; color: "#0c2232"; radius: 10; border.color: root.line

        // Temporary visual map surface until QGC FlyView map is embedded.
        Rectangle {
            anchors.fill: parent; anchors.margins: 2; radius: 9; color: "#12384a"
            Canvas {
                anchors.fill: parent
                onPaint: {
                    var c = getContext("2d"); c.clearRect(0,0,width,height)
                    c.strokeStyle = "#275267"; c.lineWidth = 1
                    for (var x=0; x<width; x+=55) { c.beginPath(); c.moveTo(x,0); c.lineTo(x,height); c.stroke() }
                    for (var y=0; y<height; y+=55) { c.beginPath(); c.moveTo(0,y); c.lineTo(width,y); c.stroke() }
                    c.strokeStyle = root.cyan; c.lineWidth = 3
                    c.beginPath(); c.moveTo(width*.18,height*.72); c.lineTo(width*.38,height*.48); c.lineTo(width*.62,height*.30); c.stroke()
                }
            }
            Label { anchors.left: parent.left; anchors.top: parent.top; anchors.margins: 16; text: "HARTĂ / NAVIGAȚIE"; color: root.textMain; font.bold: true }
            Rectangle { x: parent.width*.17; y: parent.height*.69; width: 34; height: 34; radius: 17; color: root.green; Label { anchors.centerIn: parent; text: "H"; color: "#052114"; font.bold: true } }
            Repeater {
                model: 3
                Rectangle {
                    required property int index
                    x: mapPanel.width * (0.34 + index*.14); y: mapPanel.height * (0.44 - index*.08)
                    width: 30; height: 30; radius: 15; color: root.cyan
                    Label { anchors.centerIn: parent; text: (index+1).toString(); color: "#001725"; font.bold: true }
                }
            }
            Label { anchors.centerIn: parent; text: "▲"; color: "white"; font.pixelSize: 34; rotation: root.headingDeg }
        }

        RowLayout {
            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
            anchors.margins: 14; spacing: 8
            SmallAction { text: "+ Punct" }
            SmallAction { text: "Acasă" }
            SmallAction { text: "Șterge traseu" }
            Item { Layout.fillWidth: true }
            Rectangle { width: 128; height: 32; radius: 6; color: "#091827cc"; Label { anchors.centerIn: parent; text: "Distanță: " + root.distanceHomeM.toFixed(0) + " m"; color: root.textMain } }
        }
    }

    // Right mission/sonar panel
    Rectangle {
        id: rightPanel
        anchors.right: parent.right; anchors.top: header.bottom; anchors.bottom: footer.top
        anchors.topMargin: 10; anchors.bottomMargin: 10; anchors.rightMargin: 10
        width: 310; color: root.panel; radius: 10; border.color: root.line
        ColumnLayout {
            anchors.fill: parent; anchors.margins: 14; spacing: 10
            Label { text: "NAVIGAȚIE"; color: root.textMain; font.bold: true; font.pixelSize: 15 }
            Label { text: "Puncte active: " + root.waypointCount; color: root.textDim }
            Label { text: "Traseu: " + root.routeLengthM.toFixed(0) + " m"; color: root.textDim }
            Label { text: "Acasă: " + root.distanceHomeM.toFixed(0) + " m"; color: root.textDim }

            RowLayout {
                Layout.fillWidth: true; spacing: 7
                ModeButton { text: "MANUAL"; selected: root.flightMode === "MANUAL" }
                ModeButton { text: "AUTO"; selected: root.flightMode === "AUTO" }
                ModeButton { text: "RTL"; selected: root.flightMode === "RTL" }
            }
            Button { Layout.fillWidth: true; text: "▶  PORNEȘTE TRASEUL" }

            Rectangle { Layout.fillWidth: true; height: 1; color: root.line }
            RowLayout { Layout.fillWidth: true; Label { text: "SONAR 2D"; color: root.textMain; font.bold: true }; Item { Layout.fillWidth: true }; Label { text: root.sonarConnected ? "● Conectat" : "● Neconectat"; color: root.sonarConnected ? root.green : root.danger } }
            Rectangle {
                Layout.fillWidth: true; Layout.fillHeight: true; Layout.minimumHeight: 150
                radius: 7; color: "#06131e"; border.color: root.line; clip: true
                Canvas {
                    anchors.fill: parent
                    onPaint: {
                        var c=getContext("2d"); c.clearRect(0,0,width,height)
                        c.strokeStyle="#154d70"; c.lineWidth=1
                        for(var y=20;y<height;y+=25){c.beginPath();c.moveTo(0,y);c.lineTo(width,y);c.stroke()}
                        c.strokeStyle=root.cyan; c.lineWidth=2; c.beginPath(); c.moveTo(0,height*.72)
                        for(var x=0;x<width;x+=12){c.lineTo(x,height*.70 + Math.sin(x*.08)*12 + Math.sin(x*.023)*10)} c.stroke()
                    }
                }
                Column { anchors.left: parent.left; anchors.top: parent.top; anchors.margins: 10; spacing: 2
                    Label { text: root.depthM.toFixed(1) + " m"; color: root.textMain; font.pixelSize: 26; font.bold: true }
                    Label { text: root.waterTempC.toFixed(1) + " °C"; color: root.textDim }
                }
            }
            Label { text: "Kogger Sonar 2D Basic"; color: root.textDim; font.pixelSize: 11 }
            Button { Layout.fillWidth: true; text: "■  OPREȘTE MOTOARELE"; highlighted: true }
        }
    }

    // Footer
    Rectangle {
        id: footer
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        height: 38; color: "#071522"; border.color: root.line
        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 18; anchors.rightMargin: 18
            Label { text: root.vehicleConnected ? "●  Conectat la ArduPilot" : "●  ArduPilot neconectat"; color: root.vehicleConnected ? root.green : root.danger }
            Item { Layout.fillWidth: true }
            Label { text: "NAVO SMART  •  Pescarul lu peste  •  V0.1"; color: root.textDim; font.pixelSize: 11 }
        }
    }

    component StatusPill: Rectangle {
        property string label: ""; property string value: ""; property bool ok: false
        Layout.preferredWidth: 120; Layout.preferredHeight: 48; radius: 7; color: root.panel2; border.color: ok ? root.green : root.line
        Column { anchors.centerIn: parent; spacing: 1
            Label { anchors.horizontalCenter: parent.horizontalCenter; text: label; color: root.textDim; font.pixelSize: 9 }
            Label { anchors.horizontalCenter: parent.horizontalCenter; text: value; color: ok ? root.green : root.textMain; font.pixelSize: 14; font.bold: true }
        }
    }
    component NavButton: Button {
        property bool active: false
        Layout.fillWidth: true; Layout.preferredHeight: 44
        background: Rectangle { radius: 7; color: parent.active ? "#123d58" : "transparent"; border.color: parent.active ? root.cyan : "transparent" }
        contentItem: Label { text: parent.text; color: parent.active ? root.cyan : root.textMain; verticalAlignment: Text.AlignVCenter; leftPadding: 10; font.bold: parent.active }
    }
    component ModeButton: Button {
        property bool selected: false
        Layout.fillWidth: true
        background: Rectangle { radius: 6; color: parent.selected ? "#0e7048" : root.panel2; border.color: parent.selected ? root.green : root.line }
        contentItem: Label { text: parent.text; color: parent.selected ? "white" : root.textDim; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.bold: true; font.pixelSize: 11 }
    }
    component SmallAction: Button { height: 34; font.pixelSize: 11 }
}
