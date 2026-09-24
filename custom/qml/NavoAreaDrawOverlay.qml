import QtQuick
import QtQuick.Controls
import QtLocation
import QtPositioning

Item {
    id: root
    required property var map
    property var areaScan
    property var polygonPoints: []
    property bool drawing: false
    signal areaAccepted(var polygon, int lanes)
    signal status(string text)
    anchors.fill: parent

    function addPoint(screenPoint){
        var c=map.toCoordinate(screenPoint,false)
        if(!c||!c.isValid)return
        var a=polygonPoints.slice(0);a.push(c);polygonPoints=a
        status("Zonă scanare: "+a.length+" puncte")
    }
    function undo(){if(!polygonPoints.length)return;var a=polygonPoints.slice(0,-1);polygonPoints=a}
    function clear(){polygonPoints=[]}
    function accept(){
        if(polygonPoints.length<3){status("Sunt necesare minimum 3 puncte");return}
        var lanes=areaScan.generatePolygon(polygonPoints).length/2
        if(!lanes){status("Nu s-au putut genera culoarele");return}
        drawing=false;areaAccepted(polygonPoints,lanes);status("Zonă acceptată • "+lanes+" culoare")
    }

    MapPolygon {
        path: root.polygonPoints
        color:"#2131d67b"; border.color:"#31d67b"; border.width:3
    }
    MapItemView {
        model:root.polygonPoints
        delegate:MapQuickItem {
            required property var modelData
            coordinate:modelData;anchorPoint.x:8;anchorPoint.y:8
            sourceItem:Rectangle{width:16;height:16;radius:8;color:"#31d67b";border.color:"white";border.width:2}
        }
    }
    MouseArea {
        anchors.fill:parent
        enabled:root.drawing
        acceptedButtons:Qt.LeftButton
        onClicked:function(mouse){root.addPoint(Qt.point(mouse.x,mouse.y))}
    }
    Row {
        visible:root.drawing
        anchors.left:parent.left;anchors.bottom:parent.bottom
        anchors.leftMargin:12;anchors.bottomMargin:58;spacing:6
        z:3000
        Button{text:"↶";enabled:root.polygonPoints.length>0;onClicked:root.undo()}
        Button{text:"ȘTERGE";onClicked:root.clear()}
        Button{text:"✓ ZONĂ";enabled:root.polygonPoints.length>=3;onClicked:root.accept()}
        Rectangle{width:110;height:40;radius:6;color:"#071827e8";Label{anchors.centerIn:parent;text:root.polygonPoints.length+" puncte";color:"white"}}
    }
}
