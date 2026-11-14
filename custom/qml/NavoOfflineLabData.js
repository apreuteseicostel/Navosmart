.pragma library
// Deterministic, clearly synthetic *display-only* lake for Offline Lab.
// Coordinates 0,0 are a neutral local geometry origin, NOT a real fishing lake.
var cols=23,rows=19,cellM=2;
function depthAt(x,y){
    var ridge=1.6*Math.exp(-((x+7)*(x+7)+(y-4)*(y-4))/95);
    var hollow=2.5*Math.exp(-((x-8)*(x-8)+(y+5)*(y+5))/160);
    return Math.max(1.1,2.3+0.045*(x+22)+0.018*(y+18)+hollow-ridge);
}
function grid(){
    var out=[];
    for(var j=0;j<rows;j++){
        var y=(j-(rows-1)/2)*cellM;
        for(var i=0;i<cols;i++){
            var x=(i-(cols-1)/2)*cellM;
            out.push({x:x,y:y,depth:depthAt(x,y)});
        }
    }
    return out;
}
function samples(){
    // No identifiers, no timestamps and no GPS observations: these are
    // temporary demo points in memory and must never enter My Lakes.
    var source=grid(),out=[],metresToDegrees=1/111320;
    for(var i=0;i<source.length;i++){
        var p=source[i];
        out.push({lat:p.y*metresToDegrees,lon:p.x*metresToDegrees,
                  depth:p.depth,synthetic:true});
    }
    return out;
}
function contours(step){
    var interval=Number(step);
    if(!isFinite(interval)||interval<.5||interval>5)return [];
    var g=grid(),out=[],low=Infinity,high=-Infinity;
    for(var a=0;a<g.length;a++){low=Math.min(low,g[a].depth);high=Math.max(high,g[a].depth)}
    function hit(a,b,level){
        if((a.depth<level)===(b.depth<level))return null;
        var frac=(level-a.depth)/(b.depth-a.depth);
        return {x:a.x+(b.x-a.x)*frac,y:a.y+(b.y-a.y)*frac};
    }
    for(var level=Math.ceil(low/interval)*interval;level<=high;level+=interval){
        for(var j=0;j<rows-1;j++)for(var i=0;i<cols-1;i++){
            var p00=g[j*cols+i],p10=g[j*cols+i+1],
                p01=g[(j+1)*cols+i],p11=g[(j+1)*cols+i+1];
            var crossings=[
                hit(p00,p10,level),hit(p10,p11,level),
                hit(p11,p01,level),hit(p01,p00,level)
            ].filter(function(p){return p!==null});
            if(crossings.length===2)out.push({a:crossings[0],b:crossings[1],depth:level});
            else if(crossings.length===4){
                out.push({a:crossings[0],b:crossings[1],depth:level});
                out.push({a:crossings[2],b:crossings[3],depth:level});
            }
            if(out.length>=3000)return out;
        }
    }
    return out;
}
