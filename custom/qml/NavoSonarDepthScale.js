.pragma library
// Sonar PRO DISPLAY WINDOW ONLY. No changes to CHART bytes, native Dataset,
// bottom detection, GPS or saved recordings.
// Do not treat near-surface ringing (0.1–0.9 m) as a confirmed lake bottom.
function targetRange(history, depthHint, sourceOffset, sourceRange) {
    if (!isFinite(sourceOffset) || !isFinite(sourceRange) || sourceRange <= 0) return 0;
    var end = sourceOffset + sourceRange;
    var values = [];
    var a = history || [];
    for (var i = Math.max(0, a.length - 90); i < a.length; i++) {
        var d = Number(a[i].bottom);
        // Ignore uninitialised, implausibly shallow, out-of-window and invalid readings.
        if (isFinite(d) && d >= 1.0 && d >= sourceOffset && d <= end) values.push(d);
    }
    var bottom = NaN;
    if (values.length >= 4) {
        values.sort(function(a,b){return a-b});
        // A robust high percentile shows most of the observed bottom shape
        // without a single isolated depth glitch expanding the entire chart.
        bottom = values[Math.floor((values.length-1)*0.90)];
        // A credible recent deeper change expands the view immediately.
        if (values.length >= 12) {
            var recent = [];
            for(var n=Math.max(0,a.length-6);n<a.length;n++) {
                var d=Number(a[n].bottom);
                if(isFinite(d)&&d>=1&&d>=sourceOffset&&d<=end)recent.push(d);
            }
            if(recent.length>=3) {
                recent.sort(function(a,b){return a-b});
                bottom = Math.max(bottom,recent[Math.floor(recent.length/2)]);
            }
        }
    } else {
        // Fallback to a plausible instrument depth only when no dependable
        // processed bottom history exists; never use the echo amplitude itself.
        var hint = Number(depthHint);
        if (isFinite(hint) && hint >= 1.0 && hint >= sourceOffset && hint <= end)
            bottom = hint;
    }
    if(!isFinite(bottom))return 0; // Keep original sonar range until trustworthy.
    var visibleEnd = Math.max(sourceOffset+1.5,bottom*1.25);
    var step=visibleEnd<=5?0.5:visibleEnd<=15?1:visibleEnd<=40?2:5;
    visibleEnd = Math.ceil(visibleEnd/step)*step;
    return Math.max(0,Math.min(sourceRange,visibleEnd-sourceOffset));
}
function smoothRange(current,target,sourceRange) {
    if (!(target>0) || !(sourceRange>0)) return 0;
    target=Math.max(1.5,Math.min(sourceRange,target));
    if(!(current>0) || current>sourceRange)return target;
    // Expand immediately when the water gets deeper; shrink gradually to avoid
    // a visually distracting zoom oscillation at the boundary.
    if(target>current)return target;
    if(target>=current*0.85)return current;
    return Math.max(target,Math.ceil(current*0.70*2)/2);
}
