// SPDX-License-Identifier: GPL-3.0-or-later
// NAVO adapter of KoggerApp src/scene2d/plot2D_echogram.cpp colormapFor/setColorScheme.
// Upstream: https://github.com/koggertech/KoggerApp (GPL-3.0).
// Retains 256 intensity levels; never changes the raw CHART samples.
.pragma library
var themes = [
 {colors:[[0,0,40],[20,0,120],[40,0,200],[0,90,255],[0,200,255],[0,255,200],[0,255,80],[220,255,0],[255,120,0],[255,40,40],[255,255,255]],levels:[0,18,36,60,90,120,150,185,210,235,255]},
 {colors:[[0,0,0],[40,0,80],[0,30,150],[20,230,30],[255,50,20],[255,255,255]],levels:[0,30,80,120,150,255]},
 {colors:[[0,0,0],[28,10,0],[55,18,0],[95,35,0],[150,70,10],[210,105,15],[245,175,70],[255,232,160]],levels:[0,12,26,52,92,140,200,255]}
]
var tables = []
function table(theme) {
    var t = Math.max(0,Math.min(themes.length-1,theme|0))
    if (tables[t]) return tables[t]
    var config=themes[t], result=new Array(256)
    for(var segment=0;segment<config.levels.length-1;++segment) {
        var from=config.levels[segment],to=config.levels[segment+1],a=config.colors[segment],b=config.colors[segment+1]
        for(var i=from;i<=to;++i) {
            var w=(i-from)/(to-from),r=Math.round(a[0]*(1-w)+b[0]*w),g=Math.round(a[1]*(1-w)+b[1]*w),blue=Math.round(a[2]*(1-w)+b[2]*w)
            result[i]="rgb("+r+","+g+","+blue+")"
        }
    }
    tables[t]=result
    return result
}
function index(strength) {
    if(!isFinite(strength)||strength<=0)return 0
    return Math.max(0,Math.min(255,Math.round(strength*255)))
}
function color(theme,strength) {return table(theme)[index(strength)]}
