import QtQuick

QtObject {
    id: root
    property real sensitivity: 0.72
    property int minimumRunBins: 2
    property real surfaceIgnoreM: 0.35
    property real bottomGuardM: 0.45
    property real lastDetectionTime: 0
    property real cooldownMs: 900
    signal targetDetected(real targetDepthM, real strength)

    // Conservative heuristic over Kogger raw echogram. It intentionally does not
    // claim fish size/species. The raw trace remains the source of truth, Deeper-style.
    function analyze(echoSamples, bottomDepthM) {
        if(!echoSamples || echoSamples.length<8 || isNaN(bottomDepthM) || bottomDepthM<=0)return
        var now=Date.now(); if(now-lastDetectionTime<cooldownMs)return
        var binM=bottomDepthM/echoSamples.length
        var start=Math.max(1,Math.floor(surfaceIgnoreM/binM))
        var end=Math.min(echoSamples.length-1,Math.floor((bottomDepthM-bottomGuardM)/binM))
        var bestStart=-1,bestEnd=-1,best=0,run=-1
        for(var i=start;i<end;i++){
            var v=Number(echoSamples[i])
            if(v>=sensitivity){if(run<0)run=i;if(v>best)best=v}
            else if(run>=0){if(i-run>=minimumRunBins && (bestEnd<bestStart || i-run>bestEnd-bestStart)){bestStart=run;bestEnd=i-1}run=-1}
        }
        if(run>=0 && end-run>=minimumRunBins){bestStart=run;bestEnd=end-1}
        if(bestStart>=0){lastDetectionTime=now;targetDetected(((bestStart+bestEnd)/2)*binM,best)}
    }
}
