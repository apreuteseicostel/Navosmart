.pragma library
// Display-only state: never exported to navigation, tracks, sonar or saved points.
function reset() { return { lat: NaN, lon: NaN, at: 0, rawLat: NaN, rawLon: NaN, dx: 0, dy: 0, coherent: 0, fast: 0 }; }
function wrap(x) { return ((x + 540) % 360) - 180; }
function update(s, lat, lon, speed, accuracy, now) {
    if (!isFinite(lat) || !isFinite(lon) || Math.abs(lat)>90 || Math.abs(lon)>180) return s;
    if (!isFinite(s.lat) || now-s.at>3000 || now<s.at) {
        var first=reset();first.lat=first.rawLat=lat;first.lon=first.rawLon=lon;first.at=now;return first;
    }
    var scale=111195, cos=Math.max(0.001,Math.cos(lat*Math.PI/180));
    var dx=wrap(lon-s.rawLon)*scale*cos, dy=(lat-s.rawLat)*scale;
    var d=Math.sqrt(dx*dx+dy*dy), old=Math.sqrt(s.dx*s.dx+s.dy*s.dy);
    var coherent=d>0.06 && old>0.06 && (dx*s.dx+dy*s.dy)>0.6*d*old ? s.coherent+1 : 0;
    var fast=isFinite(speed) && speed>0.6 ? s.fast+1 : 0;
    var moving=fast>=2 || coherent>=2;
    // Missing accuracy uses conservative light smoothing, never a fabricated radius.
    var tau=moving ? 0.10 : (isFinite(accuracy) && accuracy>0 ? Math.min(1.5,Math.max(0.4,accuracy*0.3)) : 0.4);
    var dt=Math.max(0,now-s.at)/1000, alpha=1-Math.exp(-dt/tau);
    var error=Math.sqrt(Math.pow(wrap(lon-s.lon)*scale*cos,2)+Math.pow((lat-s.lat)*scale,2));
    // Do not conceal a persistent displacement behind an old display position.
    if(error>Math.max(10,isFinite(accuracy)?accuracy*3:10)) alpha=1;
    return {lat:s.lat+(lat-s.lat)*alpha,lon:wrap(s.lon+wrap(lon-s.lon)*alpha),at:now,
            rawLat:lat,rawLon:lon,dx:dx,dy:dy,coherent:coherent,fast:fast};
}
