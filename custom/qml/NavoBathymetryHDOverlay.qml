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
            color: root.depthColor(modelData.depth)
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
        height: 78
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
                Text { text:"BATIMETRIE HD"; color:"white"; font.bold:true; font.pixelSize:11 }
                Text { text:hdModel.gridCells.length+" celule"; color:"#9fb5c7"; font.pixelSize:9 }
            }
            Rectangle {
                width:174
                height:10
                gradient: Gradient {
                    orientation:Gradient.Horizontal
                    GradientStop{position:0;color:"#ff2e00"}
                    GradientStop{position:.2;color:"#ffd500"}
                    GradientStop{position:.4;color:"#23d35b"}
                    GradientStop{position:.65;color:"#00bfff"}
                    GradientStop{position:1;color:"#1635d8"}
                }
            }
            Row {
                width:174
                Text { width:87; text:Number(hdModel.minDepthM).toFixed(1)+" m"; color:"#d7e3ee"; font.pixelSize:9 }
                Text { width:87; horizontalAlignment:Text.AlignRight; text:Number(hdModel.maxDepthM).toFixed(1)+" m"; color:"#d7e3ee"; font.pixelSize:9 }
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
        width: 116
        height: 34
        radius: 6
        color: "#d6071827"
        border.color: "#38556b"
        visible: root.enabled && hdModel.ready
        Row {
            anchors.centerIn: parent
            spacing: 4
            Text { text:"HD"; color:"white"; font.bold:true; anchors.verticalCenter:parent.verticalCenter }
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
