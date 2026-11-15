import QtQuick
// Lightweight standalone UI test substitute. Real C++ renderer is built by Android CI.
Item {
 property var fileReplay:null
 property bool fileReady:false
 property int indexedColumns:0
 property real position:0.5
 property int horizontalZoom:1
 property real depthFrom:0
 property real depthRange:50
 property int palette:0
 property real levelLow:10
 property real levelHigh:100
 property bool compensate:false
 property bool showDepthGrid:true
 function inspectAt(x,y){return ({})}
}
