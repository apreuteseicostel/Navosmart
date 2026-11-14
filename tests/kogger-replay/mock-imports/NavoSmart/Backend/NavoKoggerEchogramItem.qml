import QtQuick
// CI-only placeholder for QML tests running without NAVO's C++ plugin.
// Native renderer itself is linked and tested by navo-native-kogger-image.
Item {
 objectName:"mockKoggerNativeEchogram"
 property var decoder:null
 property real depthFrom:0
 property real depthRange:50
 property int paletteMode:0
 property real lowLevel:0
 property real highLevel:100
 property real gain:1
 property real noiseFloor:0
 property bool frozen:false
 property bool showBottomTrack:true
 property int columnCount:0
 function resetColumns(){columnCount=0}
 function setBottomDepth(sequence,depth){}
 function inspectAt(x,y){return ({})}
}
