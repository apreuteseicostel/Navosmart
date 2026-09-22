import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtPositioning

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlyView
import QGroundControl.FlightMap
import QGroundControl.PlanView
import NavoSmart 1.0

Item {
    id: root
    implicitWidth: 1280
    implicitHeight: 720

    property var vehicle: QGroundControl.multiVehicleManager.activeVehicle
    property var battery: vehicle && vehicle.batteries.count > 0 ? vehicle.batteries.get(0) : null
    property var waypointNames: ({})
    property real depthM: NaN
    property real waterTempC: NaN
    property bool sonarConnected: false
    property string lastNavigationStatus: ""
    property bool silentModeActive: false
    property bool cameraConnected: false
    property bool cameraFullscreen: false
    property string flightMode: vehicle ? vehicle.flightMode : ""
    property real distanceToHome: vehicle && vehicle.distanceToHome ? vehicle.distanceToHome.rawValue : 0
    property real distanceToTarget: vehicle && vehicle.distanceToGoal ? vehicle.distanceToGoal.rawValue : 0
    property string boatId: "NAV0001"
    property int activePage: 0
    property bool hopperStatusExpanded: false
    property bool mapFullscreen: false
    property string selectedHopper: "none"
    property int manualHopperHoldMs: 1500
    readonly property bool manualMode: root.flightMode.toUpperCase() === "MANUAL"
    readonly property bool nearBaitingPoint: root.distanceToTarget > 0 && root.distanceToTarget <= 8
    readonly property bool hopperControlsEnabled: root.manualMode || root.nearBaitingPoint
    property color bg: "#0b1016"
    property color panel: "#121a24"
    property color line: "#273342"
    property color text: "#eaf2f8"
    property color muted: "#91a3b5"
    property color accent: "#26c6da"
    property color ok: "#47d16c"
    property color warn: "#ffc857"
    property color danger: "#ff5c5c"

    function modeColor() {
        var m = root.flightMode.toUpperCase()
        if (m === "AUTO" || m === "GUIDED") return root.ok
        if (m === "RTL" || m === "HOLD") return root.warn
        return root.accent
    }
    function openHopper(side) {
        if (!root.hopperControlsEnabled) {
            root.lastNavigationStatus = "Cuve blocate: mergi aproape de punct sau treci pe MANUAL"
            return
        }
        root.selectedHopper = side
        root.lastNavigationStatus = "Cuva " + side + " deschisa"
        hopperPulse.restart()
    }
    function closeHoppers() {
        root.selectedHopper = "none"
        root.lastNavigationStatus = "Cuve inchise"
    }
    function startMission() { root.lastNavigationStatus = "Misiune pornita" }
    function holdMission() {
        if (vehicle && vehicle.pauseVehicle) vehicle.pauseVehicle()
        root.lastNavigationStatus = "HOLD activ"
    }
    function rtlMission() {
        if (vehicle && vehicle.guidedModeRTL) vehicle.guidedModeRTL(false)
        root.lastNavigationStatus = "RTL activ"
    }
    function stopMission() {
        if (vehicle && vehicle.pauseVehicle) vehicle.pauseVehicle()
        root.lastNavigationStatus = "Misiune oprita"
    }
    function navigateToCoordinate(c) {
        if (!vehicle || !c || !c.isValid) {
            root.lastNavigationStatus = "Navigatie indisponibila"
            return
        }
        if (vehicle.guidedModeGotoLocation) vehicle.guidedModeGotoLocation(c)
        root.lastNavigationStatus = "Navighez la punct"
    }

    Timer { id: hopperPulse; interval: root.manualHopperHoldMs; onTriggered: root.closeHoppers() }

    Rectangle { anchors.fill: parent; color: root.bg }

    Rectangle {
        id: header
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        height: 64; color: "#101822"; border.color: root.line
        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16; spacing: 12
            ColumnLayout {
                Layout.fillWidth: true; spacing: 1
                Text { text: "NAVO SMART"; color: root.text; font.pixelSize: 22; font.bold: true }
                Text { text: "Pescarul lu Peste"; color: root.muted; font.pixelSize: 11 }
            }
            Rectangle { width: 10; height: 10; radius: 5; color: root.sonarConnected ? root.ok : root.danger }
            Text { text: root.sonarConnected ? "SONAR" : "SONAR OFF"; color: root.text; font.pixelSize: 12 }
            Rectangle { width: 10; height: 10; radius: 5; color: root.cameraConnected ? root.ok : root.muted }
            Text { text: root.cameraConnected ? "CAM" : "CAM OFF"; color: root.text; font.pixelSize: 12 }
            Rectangle {
                radius: 12; height: 32; width: modeText.width + 22; color: root.modeColor()
                Text { id: modeText; anchors.centerIn: parent; text: root.flightMode || "NO MODE"; color: "#071014"; font.bold: true; font.pixelSize: 12 }
            }
        }
    }

    Rectangle {
        id: sidebar
        anchors.left: parent.left; anchors.top: header.bottom; anchors.bottom: footer.top
        width: root.mapFullscreen ? 0 : 190; visible: !root.mapFullscreen; color: "#0e151e"; border.color: root.line
        ColumnLayout {
            anchors.fill: parent; anchors.margins: 10; spacing: 8
            Repeater {
                model: ["HARTA", "SONAR", "BALTI", "CAMERA", "SETARI"]
                delegate: Rectangle {
                    Layout.fillWidth: true; height: 42; radius: 8
                    color: root.activePage === index ? "#203242" : "#151f2a"; border.color: root.activePage === index ? root.accent : root.line
                    Text { anchors.centerIn: parent; text: modelData; color: root.text; font.bold: root.activePage === index; font.pixelSize: 12 }
                    MouseArea { anchors.fill: parent; onClicked: root.activePage = index }
                }
            }
            Item { Layout.fillHeight: true }
            Rectangle {
                Layout.fillWidth: true; height: 58; radius: 8; color: "#151f2a"; border.color: root.line
                Column { anchors.centerIn: parent; spacing: 2
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: "ID BARCA"; color: root.muted; font.pixelSize: 10 }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.boatId; color: root.text; font.pixelSize: 13; font.bold: true }
                }
            }
        }
    }

    Rectangle {
        id: rightPanel
        anchors.right: parent.right; anchors.top: header.bottom; anchors.bottom: footer.top
        width: root.mapFullscreen ? 0 : 250; visible: !root.mapFullscreen; color: "#0e151e"; border.color: root.line
        Flickable {
            anchors.fill: parent; contentHeight: rightCol.height + 20; clip: true
            Column {
                id: rightCol; width: parent.width - 20; x: 10; y: 10; spacing: 9
                Rectangle {
                    width: parent.width; height: 84; radius: 9; color: root.panel; border.color: root.line
                    Column { anchors.fill: parent; anchors.margins: 10; spacing: 5
                        Text { text: "BATERIE"; color: root.muted; font.pixelSize: 10 }
                        Text { text: root.battery ? Number(root.battery.percentRemaining.rawValue).toFixed(0) + "%" : "--%"; color: root.text; font.pixelSize: 24; font.bold: true }
                        Rectangle { width: parent.width; height: 7; radius: 3; color: "#27313b"
                            Rectangle { height: parent.height; radius: 3; width: parent.width * (root.battery ? Math.max(0, Math.min(100, Number(root.battery.percentRemaining.rawValue))) : 0) / 100; color: root.ok }
                        }
                    }
                }
                Rectangle {
                    width: parent.width; height: 70; radius: 9; color: root.panel; border.color: root.line
                    RowLayout { anchors.fill: parent; anchors.margins: 10
                        ColumnLayout { Layout.fillWidth: true
                            Text { text: "ADANCIME"; color: root.muted; font.pixelSize: 10 }
                            Text { text: isNaN(root.depthM) ? "--.- m" : root.depthM.toFixed(1) + " m"; color: root.text; font.pixelSize: 19; font.bold: true }
                        }
                        ColumnLayout {
                            Text { text: "APA"; color: root.muted; font.pixelSize: 10 }
                            Text { text: isNaN(root.waterTempC) ? "--.- C" : root.waterTempC.toFixed(1) + " C"; color: root.waterTempC > 30 ? root.danger : (root.waterTempC > 25 ? root.warn : root.text); font.pixelSize: 16; font.bold: true }
                        }
                    }
                }
                Rectangle {
                    width: parent.width; height: 82; radius: 9; color: root.panel; border.color: root.line
                    Column { anchors.fill: parent; anchors.margins: 10; spacing: 5
                        Text { text: "DISTANTE"; color: root.muted; font.pixelSize: 10 }
                        Text { text: "Acasa: " + root.distanceToHome.toFixed(0) + " m"; color: root.text; font.pixelSize: 14 }
                        Text { text: "Tinta: " + root.distanceToTarget.toFixed(0) + " m"; color: root.text; font.pixelSize: 14 }
                    }
                }
                Rectangle {
                    width: parent.width; height: root.hopperStatusExpanded ? 132 : 76; radius: 9; color: root.panel; border.color: root.line
                    Column { anchors.fill: parent; anchors.margins: 10; spacing: 5
                        Row { spacing: 8
                            Text { text: "CUVE"; color: root.muted; font.pixelSize: 10 }
                            Text { text: root.hopperControlsEnabled ? "ACTIVE" : "BLOCATE"; color: root.hopperControlsEnabled ? root.ok : root.warn; font.pixelSize: 10; font.bold: true }
                        }
                        Text { text: root.selectedHopper === "none" ? "Inchise" : ("Deschisa: " + root.selectedHopper); color: root.text; font.pixelSize: 14 }
                        MouseArea { anchors.fill: parent; onClicked: root.hopperStatusExpanded = !root.hopperStatusExpanded }
                        Row {
                            visible: root.hopperStatusExpanded; spacing: 6
                            Rectangle { width: 65; height: 32; radius: 6; color: root.hopperControlsEnabled ? "#24465a" : "#242b31"; Text { anchors.centerIn: parent; text: "STG"; color: root.text; font.pixelSize: 11 }; MouseArea { anchors.fill: parent; enabled: root.hopperControlsEnabled; onPressAndHold: root.openHopper("stanga") } }
                            Rectangle { width: 65; height: 32; radius: 6; color: root.hopperControlsEnabled ? "#24465a" : "#242b31"; Text { anchors.centerIn: parent; text: "DR"; color: root.text; font.pixelSize: 11 }; MouseArea { anchors.fill: parent; enabled: root.hopperControlsEnabled; onPressAndHold: root.openHopper("dreapta") } }
                            Rectangle { width: 65; height: 32; radius: 6; color: root.hopperControlsEnabled ? "#24465a" : "#242b31"; Text { anchors.centerIn: parent; text: "AMBELE"; color: root.text; font.pixelSize: 9 }; MouseArea { anchors.fill: parent; enabled: root.hopperControlsEnabled; onPressAndHold: root.openHopper("ambele") } }
                        }
                    }
                }
                Rectangle {
                    width: parent.width; height: 74; radius: 9; color: root.panel; border.color: root.line
                    Column { anchors.fill: parent; anchors.margins: 10; spacing: 5
                        Text { text: "STATUS"; color: root.muted; font.pixelSize: 10 }
                        Text { width: parent.width; wrapMode: Text.Wrap; text: root.lastNavigationStatus || "Pregatit"; color: root.text; font.pixelSize: 12 }
                    }
                }
            }
        }
    }

    Rectangle {
        id: mapPanel
        anchors.left: root.mapFullscreen ? parent.left : sidebar.right
        anchors.right: root.mapFullscreen ? parent.right : rightPanel.left
        anchors.top: root.mapFullscreen ? parent.top : header.bottom
        anchors.bottom: root.mapFullscreen ? parent.bottom : footer.top
        anchors.margins: root.mapFullscreen ? 0 : 10
        radius: root.mapFullscreen ? 0 : 10
        color: root.panel; border.color: root.mapFullscreen ? "transparent" : root.line; clip: true
        z: root.mapFullscreen ? 100 : 0

        Loader {
            anchors.fill: parent
            active: root.activePage === 0
            sourceComponent: Component {
                FlightMap {
                    id: flightMap
                    anchors.fill: parent
                    mapName: "NAVO SMART"
                    center: root.vehicle ? root.vehicle.coordinate : QtPositioning.coordinate(45.0, 25.0)
                    zoomLevel: 17
                    Rectangle {
                        anchors.left: parent.left; anchors.top: parent.top; anchors.margins: 10
                        width: 94; height: 34; radius: 8; color: "#b0101822"; border.color: root.line; z: 20
                        Text { anchors.centerIn: parent; text: root.mapFullscreen ? "INCHIDE" : "HARTA MARE"; color: root.text; font.pixelSize: 10; font.bold: true }
                        MouseArea { anchors.fill: parent; onClicked: root.mapFullscreen = !root.mapFullscreen }
                    }
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.RightButton
                        onClicked: function(mouse) {
                            var c = flightMap.toCoordinate(Qt.point(mouse.x, mouse.y), false)
                            root.navigateToCoordinate(c)
                        }
                    }
                }
            }
        }

        Loader {
            anchors.fill: parent; active: root.activePage === 1
            sourceComponent: Component {
                NavoSonarFullScreen {
                    anchors.fill: parent
                    depthM: root.depthM
                    waterTempC: root.waterTempC
                    connected: root.sonarConnected
                }
            }
        }

        Loader {
            anchors.fill: parent; active: root.activePage === 2
            sourceComponent: Component {
                Rectangle {
                    color: root.bg
                    Column { anchors.centerIn: parent; spacing: 12
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "BALTILE MELE"; color: root.text; font.pixelSize: 22; font.bold: true }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Hartile salvate si punctele de pescuit vor aparea aici"; color: root.muted; font.pixelSize: 13 }
                        Rectangle { width: 220; height: 44; radius: 8; color: "#1c2a38"; border.color: root.accent; Text { anchors.centerIn: parent; text: "SALVEAZA BALTA CURENTA"; color: root.text; font.bold: true; font.pixelSize: 11 } }
                    }
                }
            }
        }

        Loader {
            anchors.fill: parent; active: root.activePage === 3
            sourceComponent: Component {
                Rectangle {
                    color: "#080b0f"
                    Column { anchors.centerIn: parent; spacing: 10
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "CAMERA ETHERNET"; color: root.text; font.pixelSize: 22; font.bold: true }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.cameraConnected ? "Flux video conectat" : "Camera nu este conectata"; color: root.cameraConnected ? root.ok : root.muted; font.pixelSize: 13 }
                        Rectangle { width: 190; height: 42; radius: 8; color: "#1c2a38"; border.color: root.line; Text { anchors.centerIn: parent; text: "FULL SCREEN"; color: root.text; font.bold: true }; MouseArea { anchors.fill: parent; onClicked: root.cameraFullscreen = !root.cameraFullscreen } }
                    }
                }
            }
        }

        Loader {
            anchors.fill: parent; active: root.activePage === 4
            sourceComponent: Component {
                Rectangle {
                    color: root.bg
                    Column { anchors.centerIn: parent; spacing: 10
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "SETARI NAVO SMART"; color: root.text; font.pixelSize: 22; font.bold: true }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "LAN / SONAR / CAMERA / MAVLink"; color: root.muted; font.pixelSize: 13 }
                    }
                }
            }
        }
    }

    Rectangle {
        id: footer
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        height: 66; color: "#101822"; border.color: root.line
        RowLayout {
            anchors.fill: parent; anchors.margins: 10; spacing: 8
            Repeater {
                model: [
                    {t:"START MISIUNE", c:"#1f6f43", a:"start"},
                    {t:"HOLD", c:"#735d1d", a:"hold"},
                    {t:"RTL", c:"#6a3e20", a:"rtl"},
                    {t:"STOP", c:"#6f2424", a:"stop"}
                ]
                delegate: Rectangle {
                    Layout.fillWidth: true; height: 44; radius: 8; color: modelData.c; border.color: "#ffffff22"
                    Text { anchors.centerIn: parent; text: modelData.t; color: "white"; font.bold: true; font.pixelSize: 11 }
                    MouseArea { anchors.fill: parent; onClicked: { if (modelData.a === "start") root.startMission(); else if (modelData.a === "hold") root.holdMission(); else if (modelData.a === "rtl") root.rtlMission(); else root.stopMission() } }
                }
            }
            Rectangle {
                Layout.preferredWidth: 180; height: 44; radius: 8; color: root.silentModeActive ? "#315b4b" : "#1c2a38"; border.color: root.line
                Text { anchors.centerIn: parent; text: root.silentModeActive ? "SILENT ON" : "SILENT OFF"; color: root.text; font.bold: true; font.pixelSize: 11 }
                MouseArea { anchors.fill: parent; onClicked: root.silentModeActive = !root.silentModeActive }
            }
        }
    }

    Rectangle {
        visible: root.cameraFullscreen
        anchors.fill: parent; z: 200; color: "#050608"
        Text { anchors.centerIn: parent; text: "CAMERA FULL SCREEN"; color: root.text; font.pixelSize: 28; font.bold: true }
        Rectangle { anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 16; width: 90; height: 38; radius: 8; color: "#99151f2a"; Text { anchors.centerIn: parent; text: "INCHIDE"; color: root.text }; MouseArea { anchors.fill: parent; onClicked: root.cameraFullscreen = false } }
    }
}
