import QtQuick
import QtLocation
import QtPositioning

Item {
    id: root
    required property var map
    property var cells: []
    property bool enabled: false
    property real opacityLevel: 0.68
    property int maxCells: 900

    anchors.fill: parent
    visible: enabled

    function validDepth(v) { return isFinite(Number(v)) && Number(v) >= 0 }
    function minDepth() {
        var m=1e9
        for(var i=0;i<cells.length;i++) if(validDepth(cells[i].depth)) m=Math.min(m,Number(cells[i].depth))
        return m===1e9?0:m
    }
    function maxDepth() {
        var m=0
        for(var i=0;i<cells.length;i++) if(validDepth(cells[i].depth)) m=Math.max(m,Number(cells[i].depth))
        return m
    }
    function depthColor(d) {
        var lo=minDepth(), hi=maxDepth(), t=hi>lo?(Number(d)-lo)/(hi-lo):0
        t=Math.max(0,Math.min(1,t))
        // Shallow red/orange -> yellow/green -> cyan/blue -> deep indigo.
        if(t<.20)return Qt.rgba(1,.18+.55*t/.20,0,opacityLevel)
        if(t<.40)return Qt.rgba(1-(t-.20)/.20,.85,.05,opacityLevel)
        if(t<.60)return Qt.rgba(.05,.85,.25+(t-.40)/.20*.65,opacityLevel)
        if(t<.80)return Qt.rgba(.02,.75-(t-.60)/.20*.35,1,opacityLevel)
        return Qt.rgba(.05,.25-(t-.80)/.20*.12,1,opacityLevel)
    }

    // First HD stage: independent colored bathymetry layer. The source model
    // stays untouched; interpolation/contours can replace this renderer later.
    Repeater {
        model: root.enabled ? Math.min(root.cells.length,root.maxCells) : 0
        delegate: MapCircle {
            required property int index
            property var cell: root.cells[index]
            Component.onCompleted: { parent=root.map; root.map.addMapItem(this) }
            Component.onDestruction: root.map.removeMapItem(this)
            center: QtPositioning.coordinate(Number(cell.lat),Number(cell.lon))
            radius: Math.max(2.5,Number(cell.radiusM||cell.cellSizeM||6)*0.72)
            color: root.depthColor(cell.depth)
            border.width: 0
        }
    }

    Rectangle {
        anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.margins: 10
        width: 174; height: 52; radius: 7; color: "#df071827"; border.color:"#21b7ff"
        visible: root.enabled && root.cells.length>0
        Column {
            anchors.fill:parent;anchors.margins:7;spacing:3
            Text{text:"BATIMETRIE HD";color:"white";font.bold:true;font.pixelSize:11}
            Rectangle {
                width:160;height:10
                gradient: Gradient {
                    orientation:Gradient.Horizontal
                    GradientStop{position:0;color:"#ff2e00"} GradientStop{position:.2;color:"#ffd500"}
                    GradientStop{position:.4;color:"#23d35b"} GradientStop{position:.65;color:"#00bfff"}
                    GradientStop{position:1;color:"#1635d8"}
                }
            }
            Text{text:Number(root.minDepth()).toFixed(1)+" m                                      "+Number(root.maxDepth()).toFixed(1)+" m";color:"#d7e3ee";font.pixelSize:8}
        }
    }
}
