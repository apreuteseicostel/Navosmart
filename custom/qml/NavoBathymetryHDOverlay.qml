import QtQuick
import QtQuick.Controls
import QtLocation
import QtPositioning

Item {
    id: root
    required property var map
    property var cells: []
    property bool enabled: false
    property bool showContours: true
    property bool showHardness: false
    readonly property bool hardnessAvailable: isFinite(Number(hdModel.minHardness)) && isFinite(Number(hdModel.maxHardness))
    property bool showLegend: true
    property real opacityLevel: 0.64
    property int resolution: 28
    property real interpolationDistanceM: 15.0
    property real contourStepM: 0.5

    anchors.fill: parent
    visible: enabled

    NavoBathymetryHDModel {
        id: hdModel
        sourceCells: root.cells
        targetResolution: root.resolution
        maxInterpolationDistanceM: root.interpolationDistanceM
        contourStepM: root.contourStepM
    }

    function depthColor(d) {
        var lo=hdModel.minDepthM
        var hi=hdModel.maxDepthM
        var t=hi>lo?(Number(d)-lo)/(hi-lo):0
        t=Math.max(0,Math.min(1,t))
        // Shallow -> deep: red/orange, yellow, green, cyan, blue.
        if(t<.20)return Qt.rgba(1,.18+.55*t/.20,0,opacityLevel)
        if(t<.40)return Qt.rgba(1-(t-.20)/.20,.85,.05,opacityLevel)
        if(t<.60)return Qt.rgba(.05,.85,.25+(t-.40)/.20*.65,opacityLevel)
        if(t<.80)return Qt.rgba(.02,.75-(t-.60)/.20*.35,1,opacityLevel)
        return Qt.rgba(.05,.25-(t-.80)/.20*.12,1,opacityLevel)
    }

    function hardnessColor(h) {
        if(!root.hardnessAvailable || !isFinite(Number(h))) return Qt.rgba(.20,.24,.28,opacityLevel)
        var lo=hdModel.minHardness, hi=hdModel.maxHardness
        var t=hi>lo?(Number(h)-lo)/(hi-lo):0.5
        t=Math.max(0,Math.min(1,t))
        // Soft -> hard bottom: dark brown, sand, amber, near-white.
        if(t<.33)return Qt.rgba(.28+.42*t/.33,.18+.25*t/.33,.10,opacityLevel)
        if(t<.66)return Qt.rgba(.70+.25*(t-.33)/.33,.43+.30*(t-.33)/.33,.10,opacityLevel)
        return Qt.rgba(.95,.73+.25*(t-.66)/.34,.10+.78*(t-.66)/.34,opacityLevel)
    }

    // Independent HD renderer: IDW-interpolated rectangular cells. The
    // existing bathymetry overlay remains untouched and can be used as fallback.
    Repeater {
        model: root.enabled ? hdModel.gridCells : []
        delegate: MapRectangle {
            required property var modelData
            Component.onCompleted: { parent=root.map; root.map.addMapItem(this) }
            Component.onDestruction: root.map.removeMapItem(this)
            topLeft: QtPositioning.coordinate(Number(modelData.north),Number(modelData.west))
            bottomRight: QtPositioning.coordinate(Number(modelData.south),Number(modelData.east))
            color: root.showHardness ? root.hardnessColor(modelData.hardness) : root.depthColor(modelData.depth)
            border.width: 0
        }
    }

    // Marching-squares contour segments. They are generated from the same
    // interpolated grid, so contour geometry and the color surface stay aligned.
    Repeater {
        model: root.enabled && root.showContours ? hdModel.contourSegments : []
        delegate: MapPolyline {
            required property var modelData
            Component.onCompleted: { parent=root.map; root.map.addMapItem(this) }
            Component.onDestruction: root.map.removeMapItem(this)
            line.width: Math.abs(Number(modelData.level)-Math.round(Number(modelData.level)))<0.02 ? 2.2 : 1.1
            line.color: Math.abs(Number(modelData.level)-Math.round(Number(modelData.level)))<0.02 ? "#e9ffffff" : "#a8ffffff"
            path: [
                QtPositioning.coordinate(Number(modelData.aLat),Number(modelData.aLon)),
                QtPositioning.coordinate(Number(modelData.bLat),Number(modelData.bLon))
            ]
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 10
        width: 188
        height: 82
        radius: 7
        color: "#df071827"
        border.color: "#21b7ff"
        visible: root.enabled && root.showLegend && hdModel.ready
        Column {
            anchors.fill: parent
            anchors.margins: 7
            spacing: 4
            Row {
                spacing: 8
                Text { text:root.showHardness ? "DURITATE FUND" : "BATIMETRIE HD"; color:"white"; font.bold:true; font.pixelSize:11 }
                Text { text:hdModel.gridCells.length+" celule"; color:"#9fb5c7"; font.pixelSize:9 }
            }
            Rectangle {
                width:174
                height:10
                gradient: Gradient {
                    orientation:Gradient.Horizontal
                    GradientStop{position:0;color:root.showHardness ? "#472e1a" : "#ff2e00"}
                    GradientStop{position:.25;color:root.showHardness ? "#8f5720" : "#ffd500"}
                    GradientStop{position:.5;color:root.showHardness ? "#d99b28" : "#23d35b"}
                    GradientStop{position:.75;color:root.showHardness ? "#f2c75c" : "#00bfff"}
                    GradientStop{position:1;color:root.showHardness ? "#fff2dc" : "#1635d8"}
                }
            }
            Row {
                width:174
                Text { width:87; text:root.showHardness ? Number(hdModel.minHardness).toFixed(2) : Number(hdModel.minDepthM).toFixed(1)+" m"; color:"#d7e3ee"; font.pixelSize:9 }
                Text { width:87; horizontalAlignment:Text.AlignRight; text:root.showHardness ? Number(hdModel.maxHardness).toFixed(2) : Number(hdModel.maxDepthM).toFixed(1)+" m"; color:"#d7e3ee"; font.pixelSize:9 }
            }
            Text {
                text: root.showContours ? "Curbe nivel: "+Number(root.contourStepM).toFixed(1)+" m" : "Curbe nivel: ascunse"
                color:"#9fb5c7"; font.pixelSize:9
            }
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: 10
        width: 252
        height: 34
        radius: 6
        color: "#d6071827"
        border.color: "#38556b"
        visible: root.enabled && hdModel.ready
        Row {
            anchors.centerIn: parent
            spacing: 4
            Button {
                width:112; height:27; padding:2
                text:root.showHardness ? "DURITATE" : "ADÂNCIME"
                enabled:root.hardnessAvailable
                onClicked:root.showHardness=!root.showHardness
            }
            Button {
                width:76; height:27; padding:2
                text:root.showContours ? "CURBE ✓" : "CURBE"
                checkable:true
                checked:root.showContours
                onToggled:root.showContours=checked
            }
        }
    }
}
