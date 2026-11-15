import QtQml
QtObject {
 property int chartSequence:0
 function reset(){chartSequence=0}
 function feedBytes(bytes){chartSequence++}
 function flushPendingChart(){}
}
