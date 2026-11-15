-- Read-only relay report harness; no real GPIO or RC commands.
local sent={}
local states={[0]=0,[1]=1}
local available={[0]=true,[1]=true}
relay={
 enabled=function(_,instance) return available[instance] or false end,
 get=function(_,instance) return states[instance] end,
}
gcs={send_named_float=function(_,key,value) sent[key]=value end}
local update,interval=dofile("ardupilot/scripts/navo_relay_status.lua")
assert(interval==500 and type(update)=="function")
assert(sent.NV3RHEAD==0 and sent.NV3RPOS==1,
       "Relay1 headlight OFF and Relay2 position lights ON reported independently")
states[0]=1;states[1]=0;sent={}
update();assert(sent.NV3RHEAD==1 and sent.NV3RPOS==0,
       "Direct G20 switch changes are observed by read-only report")
available[0]=false;sent={}
update();assert(sent.NV3RHEAD==nil and sent.NV3RPOS==0,
       "Unconfigured Relay1 must be UNKNOWN, not falsely OFF")
available[0]=true;states[0]=nil;sent={}
update();assert(sent.NV3RHEAD==nil, "Unavailable logical relay state must not publish")
relay.get=function()error("relay:get unavailable on firmware")end
sent={};update();assert(next(sent)==nil, "Unsupported relay:get must not fabricate state")
relay=nil;sent={};update();assert(next(sent)==nil, "No relay binding must not publish state")
print("PASS NAVO read-only relay telemetry: direct RC changes, unknown, disabled, missing API")
