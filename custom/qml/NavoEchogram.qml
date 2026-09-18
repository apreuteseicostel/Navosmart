import QtQuick
Canvas {
 id:root
 property var ping:[]
 property var history:[]
 property int maxColumns:220
 property bool live:false
 function pushPing(p){
  if(!p||p.length<2)return
  var h=history.slice(0);h.push(Array.prototype.slice.call(p));if(h.length>maxColumns)h.shift();history=h;requestPaint()
 }
 onPingChanged:pushPing(ping)
 onWidthChanged:requestPaint();onHeightChanged:requestPaint()
 onPaint:{
  var c=getContext("2d");c.reset();c.fillStyle="#020b12";c.fillRect(0,0,width,height)
  c.strokeStyle="#18364a";c.lineWidth=1;for(var g=1;g<5;g++){var y=g*height/5;c.beginPath();c.moveTo(0,y);c.lineTo(width,y);c.stroke()}
  if(!history.length)return
  var cw=width/maxColumns,start=Math.max(0,maxColumns-history.length)
  for(var x=0;x<history.length;x++){var p=history[x];if(!p||!p.length)continue;var ph=height/p.length
   for(var y=0;y<p.length;y++){var v=Math.max(0,Math.min(1,Number(p[y])||0));var shade=Math.floor(30+225*v);c.fillStyle="rgb("+shade+","+shade+","+shade+")";c.fillRect((start+x)*cw,y*ph,Math.max(1,cw+0.5),Math.max(1,ph+0.5))}
  }
 }
}