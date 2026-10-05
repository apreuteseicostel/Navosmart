import QtQuick
import QtPositioning
import "../../custom/qml" as Navo

// Explicit projection test double: exercises the production Canvas only.
// Real QtLocation and Android acceptance belong to the installed APK checks.
Rectangle {
    id: root
    width:960; height:540; color:"#071827"
    property var mesh: ({})
    property real latitude:40
    property real longitude:44
    property real scale:10000
    property alias overlay: surface
    Item {
        id: projection
        anchors.fill:parent
        property var center:QtPositioning.coordinate(root.latitude,root.longitude)
        property real zoomLevel:root.scale
        property real bearing:0
        property real tilt:0
        function fromCoordinate(c,clip) {
            return Qt.point(width/2+(c.longitude-center.longitude)*zoomLevel,
                height/2-(c.latitude-center.latitude)*zoomLevel)
        }
        function toCoordinate(p,clip) {
            return QtPositioning.coordinate(center.latitude-(p.y-height/2)/zoomLevel,
                center.longitude+(p.x-width/2)/zoomLevel)
        }
    }
    Navo.NavoNativeBathymetryOverlay {
        id:surface
        objectName:"surfaceOverlay"
        map:projection; surface:root.mesh; active:true
    }
}
