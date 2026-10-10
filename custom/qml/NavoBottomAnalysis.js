.pragma library

// Descriptive CHART metrics. No physical substrate label or probability is inferred.
function finite(v) { return typeof v === "number" && isFinite(v) }
function column(raw, offset, range, bottom) {
    if(!raw || raw.length<16 || raw.length>65536 || !finite(offset) || offset<0 ||
       !finite(range) || range<=0 || !finite(bottom) || bottom<=0 || bottom<offset || bottom>=offset+range)
        return {valid:false,reason:"Fund sau scară CHART indisponibile"}
    var step=range/raw.length, radius=Math.max(3,Math.ceil(0.15/step))
    var center=Math.floor((bottom-offset)/step), first=center-radius, last=center+radius
    // Require the complete measurement window. Missing coverage is never zero echo.
    if(first<0 || last>=raw.length)return {valid:false,reason:"Fereastră incompletă în jurul fundului"}
    var peak=-1, peakIndex=-1, sum=0
    for(var i=first;i<=last;i++) {
        if(!finite(raw[i]) || raw[i]<0 || raw[i]>1)return {valid:false,reason:"Amplitudini brute invalide"}
        sum+=raw[i]
        if(raw[i]>peak){peak=raw[i];peakIndex=i}
    }
    var left=peakIndex,right=peakIndex
    if(peak>0) {
        while(left>first && raw[left-1]>=peak/2)left--
        while(right<last && raw[right+1]>=peak/2)right++
    }
    var noise=[], waterEnd=Math.max(0,first-Math.ceil(0.20/step))
    var waterStart=Math.max(0,Math.ceil((Math.max(0.25,offset)-offset)/step))
    for(var w=waterStart;w<waterEnd;w++) {
        if(!finite(raw[w]) || raw[w]<0 || raw[w]>1)return {valid:false,reason:"Amplitudini brute invalide"}
        noise.push(raw[w])
    }
    noise.sort(function(a,b){return a-b})
    var baseline=noise.length ? noise[Math.floor(noise.length/2)] : NaN
    var threshold=finite(baseline) ? Math.max(0.2,baseline+0.15) : NaN
    var run=0, above=0, maxHeight=NaN
    for(var b=waterStart;b<waterEnd;b++) {
        if(raw[b]>=threshold)run++
        else {
            if(run>=3){above++;var h=bottom-(offset+(b-run)*step);maxHeight=finite(maxHeight)?Math.max(maxHeight,h):h}
            run=0
        }
    }
    if(run>=3){above++;var height=bottom-(offset+(waterEnd-run)*step);maxHeight=finite(maxHeight)?Math.max(maxHeight,height):height}
    return {valid:true,bottomM:bottom,peak:peak,mean:sum/(last-first+1),stepM:step,
        widthM:peak>0 ? (right-left+1)*step : 0,widthLimited:peak>0 && (left===first || right===last),
        baseline:baseline,contrast:finite(baseline)?peak-baseline:NaN,aboveEchoes:finite(threshold)?above:null,
        aboveHeightM:maxHeight,material:"NECLASIFICAT"}
}
function profile(history) {
    var depths=[]
    if(!history)return {valid:false,count:0}
    for(var i=Math.max(0,history.length-40);i<history.length;i++) {
        var d=history[i].bottom
        if(finite(d) && d>0 && finite(history[i].offset) && finite(history[i].range) && history[i].range>0 && d>=history[i].offset && d<history[i].offset+history[i].range)depths.push(d)
    }
    if(depths.length<3)return {valid:false,count:depths.length}
    var min=Math.min.apply(null,depths),max=Math.max.apply(null,depths)
    return {valid:true,count:depths.length,minM:min,maxM:max,variationM:max-min}
}
