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
    function analyze(echoSamples, bottomDepthM, offsetM, rangeM) {
        if(!echoSamples || echoSamples.length<8 || !isFinite(bottomDepthM) || bottomDepthM<=0 ||
           !isFinite(offsetM) || offsetM<0 || !isFinite(rangeM) || rangeM<=0)return
        var now=Date.now(); if(now-lastDetectionTime<cooldownMs)return
        var binM=rangeM/echoSamples.length
        var start=Math.max(0,Math.ceil((surfaceIgnoreM-offsetM)/binM))
        var end=Math.min(echoSamples.length,Math.floor((bottomDepthM-bottomGuardM-offsetM)/binM))
        var bestStart=-1,bestEnd=-1,best=0,run=-1
        for(var i=start;i<end;i++){
            var v=Number(echoSamples[i])
            if(v>=sensitivity){if(run<0)run=i;if(v>best)best=v}
            else if(run>=0){if(i-run>=minimumRunBins && (bestEnd<bestStart || i-run>bestEnd-bestStart)){bestStart=run;bestEnd=i-1}run=-1}
        }
        if(run>=0 && end-run>=minimumRunBins){bestStart=run;bestEnd=end-1}
        if(bestStart>=0){lastDetectionTime=now;targetDetected(offsetM+((bestStart+bestEnd)/2)*binM,best)}
    }
}
