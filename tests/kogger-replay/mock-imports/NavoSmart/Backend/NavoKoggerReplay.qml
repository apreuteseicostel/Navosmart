import QtQml
QtObject {
 property bool active:false
 property bool paused:false
 property real speed:1
 property real indexProgress:1
 property bool indexReady:false
 property int indexedColumns:0
 property int currentColumn:0
 property string error:""
 signal bytesReady(var bytes)
 signal previewLastColumnReady()
 signal indexChanged()
 function open(url){active=true;paused=false;indexReady=true;indexedColumns=6925;indexChanged();return true}
 function stop(){active=false;paused=false;indexReady=false;indexedColumns=0;indexChanged()}
 function setPaused(value){paused=!!value}
 function setSpeed(value){speed=Number(value)}
}
