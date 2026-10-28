import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
const source=fs.readFileSync(new URL('../custom/qml/NavoG20Controller.qml',import.meta.url),'utf8');
function body(name) {
    const start=source.indexOf('function '+name+'(');
    assert.ok(start>=0);
    const open=source.indexOf('{',start);
    let depth=1,end=open+1;
    for(;depth;end++) {
        if(source[end]==='{') depth++;
        if(source[end]==='}') depth--;
    }
    return source.slice(start,end);
}
function setup() {
    const cfg={hardwareActionsEnabled:true,homeChannel:6,leftHopperChannel:11,rightHopperChannel:15,
        lightChannel:7,sonarChannel:16,cameraChannel:8,holdChannel:13,
        hAction:'RTL',l1Action:'CUVA_STANGA',r1Action:'CUVA_DREAPTA',
        l2Action:'FAR',r2Action:'SONAR',cameraAction:'CAMERA',pauseAction:'HOLD',
        hopperHoldMs:1500,rtlHoldMs:1800};
    const events=[];
    const c=vm.createContext({cfg,nativeModeChannel:5,inputAllowed:true,channels:[],buttonStates:{},lastFrameMs:0,
        actionRequested:(control,action)=>events.push([control,action])});
    c.root=c;
    vm.runInContext(['resetInput','trigger','ingestChannels'].map(body).join('\n'),c);
    return {c,cfg,events};
}
const low=()=>Array(16).fill(1050);
function frames(c,values,from,to) { for(let t=from;t<=to;t+=100)c.ingestChannels(values,t); }
{
    const {c,cfg,events}=setup();cfg.hardwareActionsEnabled=false;
    c.ingestChannels(low(),1000);const v=low();v[14]=1950;frames(c,v,1100,4000);
    assert.equal(events.length,0);
}
{
    const {c,events}=setup();const v=low();v[14]=1950;frames(c,v,1000,4000);
    assert.equal(events.length,0,'held at startup must not release hopper');
    c.ingestChannels(low(),4100);frames(c,v,4200,5600);assert.equal(events.length,0);
    frames(c,v,5700,6500);assert.deepEqual(events,[['R1','CUVA_DREAPTA']]);
    c.ingestChannels(low(),6600);frames(c,v,6700,8300);assert.equal(events.length,2);
}
{
    const {c,events}=setup();c.ingestChannels(low(),1000);const v=low();v[5]=1950;
    frames(c,v,1100,2800);assert.equal(events.length,0);
    c.ingestChannels(v,2900);assert.deepEqual(events,[['H','RTL']]);
}
{
    const {c,cfg,events}=setup();cfg.leftHopperChannel=15;c.ingestChannels(low(),1000);
    const v=low();v[14]=1950;frames(c,v,1100,4000);assert.equal(events.length,0);
}
{
    const {c,events}=setup();c.ingestChannels(low(),1000);const v=low();v[14]=1950;
    c.ingestChannels(v,1100);frames(c,v,3000,5000);assert.equal(events.length,0,'stale frame resets readiness');
    c.ingestChannels(low(),5100);v[14]=65535;frames(c,v,5200,7000);assert.equal(events.length,0);
    v[14]=1950;frames(c,v,7100,9000);assert.equal(events.length,0,'invalid PWM requires release');
}
{
    const {c,events}=setup();c.ingestChannels(low(),1000);const v=low();v[14]=1950;
    frames(c,v,1100,2000);v[14]=1700;c.ingestChannels(v,2100);
    v[14]=1950;frames(c,v,2200,3600);assert.equal(events.length,0);c.ingestChannels(v,3700);assert.equal(events.length,1);
    c.inputAllowed=false;frames(c,v,3800,6000);assert.equal(events.length,1);
    c.inputAllowed=true;frames(c,v,6100,8000);assert.equal(events.length,1);
}
{
    const {c,events}=setup();c.ingestChannels(low(),1000);const v=low();v[6]=1950;
    c.ingestChannels(v,1100);c.ingestChannels(v,1200);assert.equal(events.length,0);
    c.ingestChannels(v,1300);frames(c,v,1400,2000);assert.deepEqual(events,[['L2','FAR']]);
}
{
    const {c,cfg,events}=setup();cfg.homeChannel=5;
    c.ingestChannels(low(),1000);const v=low();v[4]=1950;frames(c,v,1100,4000);
    assert.equal(events.length,0,'native CH5 must never also trigger a NAVO action');
}
{
    const text=fs.readFileSync(new URL('../ardupilot/params/navo_ch5_manual_auto_guided.param',import.meta.url),'utf8');
    const params=Object.fromEntries(text.split('\n').map(l=>l.trim()).filter(l=>l && !l.startsWith('#')).map(l=>{const [k,v]=l.split(/\s+/);return [k,Number(v)]}));
    assert.deepEqual(params,{MODE_CH:5,MODE1:0,MODE2:0,MODE3:10,MODE4:10,MODE5:15,MODE6:15,RC5_OPTION:0});
    // Native Rover slots, as documented by ArduPilot; no application mode emulator.
    assert.equal(params.MODE1,0);assert.equal(params.MODE3,10);assert.equal(params.MODE4,10);assert.equal(params.MODE6,15);
}
console.log('PASS 9 G20/profile scenarios: RC action guards, reserved CH5 and deployable native Rover mode parameters');
