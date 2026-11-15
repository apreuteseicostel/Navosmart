package.path="ardupilot/modules/?.lua;"..package.path
local core=require("navo_rgb_core")
local config=require("navo_rgb_config")
assert(config.enabled==true and config.output==13 and config.required_servo_function==94,
 "H743 LED pad must map to PWM13 with scripting function 94")
local function choose(t)
 local status,rgb=core.select(t)
 return status,rgb[1],rgb[2],rgb[3]
end
local normal={water_valid=true,temperature_valid=true,wet=false,temperature_c=25,
 temp_alarm_c=45,headlight=false,positions=false,hopper_open=false}
assert(choose(normal)=="NORMAL")
normal.wet=true;assert(choose(normal)=="ALARM")
normal.wet=false;normal.temperature_c=46;assert(choose(normal)=="ALARM")
normal.temperature_c=25;normal.water_fault=true;assert(choose(normal)=="FAULT")
normal.water_fault=false;normal.hopper_open=true;assert(choose(normal)=="HOPPER")
normal.hopper_open=false;normal.headlight=true;assert(choose(normal)=="HEADLIGHT")
normal.headlight=false;normal.positions=true;assert(choose(normal)=="POSITIONS")
normal.headlight=true;assert(choose(normal)=="BOTH_LIGHTS")
normal.headlight=false;normal.positions=false
normal.water_valid=false;normal.temperature_valid=false;assert(choose(normal)=="UNMONITORED")
assert(core.scale({255,30,0},0.3)[1]==77)

local t=0
local values={SERVO13_FUNCTION=94,SERVO9_FUNCTION=135,SERVO10_FUNCTION=135}
local messages,telemetry={},{}
param={
 get=function(_,key)return values[key]end,
 add_table=function(_,key,prefix,count)
  assert(key==173 and prefix=="NVLR_" and count==8,"RGB exchange table mismatch")
  return true
 end,
 add_param=function(_,key,index,name,default)
  assert(key==173 and index>=1 and index<=8)
  values["NVLR_"..name]=default;return true
 end,
 set=function(_,key,value)
  assert(values[key]~=nil,"unknown RGB parameter "..key)
  values[key]=value;return true
 end,
}
gcs={
 send_text=function(_,severity,message)messages[#messages+1]=message end,
 send_named_float=function(_,key,value)telemetry[key]=value end
}
millis=function()return{tofloat=function()return t end}end
local relays={[0]=0,[1]=0}
relay={
 enabled=function(_,index)assert(index==0 or index==1);return true end,
 get=function(_,index)return relays[index]end,
}
local pwm={[8]=1500,[9]=1500}
SRV_Channels={get_output_pwm_chan=function(_,idx)return pwm[idx]end}
local emitted,initCount,sendCount=nil,0,0
serialLED={
 set_num_neopixel=function(_,out,count)
  assert(out==13 and count==1,"unexpected hardware LED output")
  initCount=initCount+1;return true
 end,
 set_num_neopixel_rgb=function(_,out,count)
  assert(out==13 and count==1,"RGB physical pin mismatch")
  initCount=initCount+1;return true
 end,
 set_RGB=function(_,out,index,r,g,b)
  assert(out==13 and index==-1)
  assert(r>=0 and r<=128 and g>=0 and g<=128 and b>=0 and b<=128,
      "brightness cap exceeded")
  emitted={r,g,b};return true
 end,
 send=function(_,out)assert(out==13);sendCount=sendCount+1;return true end,
}
local update=assert(dofile("ardupilot/scripts/navo_rgb_service.lua"))
assert(initCount==1 and telemetry.NV3RGBC==8 and emitted[1]>0,"unknown sensors must be amber")
local function tick(ms,code)
 t=ms;local nextfn,delay=update();assert(nextfn==update and delay==250)
 assert(telemetry.NV3RGBC==code,("RGB expected %d, got %s"):format(code,tostring(telemetry.NV3RGBC)))
end
local function monitor(now)
 for k,v in pairs({
   NVLR_WST=2,NVLR_WET=0,NVLR_WMS=now,
   NVLR_TS=2,NVLR_TV=25,NVLR_TMS=now
 })do param:set(k,v)end
end
monitor(0);tick(250,7) -- green only after valid water + temperature
assert(telemetry.NV3RGBR==0)
relays[0]=1;tick(500,4) -- white headlight
relays[1]=1;tick(750,6) -- yellow both
relays[0]=0;tick(1000,5) -- cyan positions
relays[1]=0;values.SERVO9_FUNCTION=0;pwm[8]=1900;tick(1250,3) -- legacy DO_SET_SERVO cuva blue
pwm[8]=1500;param:set("NVLR_HOP",3);param:set("NVLR_HMS",1250)
tick(1500,3) -- blue via onboard hopper cycle, no PWM feedback required
assert(telemetry.NV3RGBR==16)
tick(3250,7) -- stale onboard hopper cycle must not remain blue
param:set("NVLR_WET",1);param:set("NVLR_WMS",3250)
tick(3500,1) -- critical RED
assert(telemetry.NV3RGBR==1 and messages[#messages]:find("WATER",1,true))
param:set("NVLR_WET",-1);param:set("NVLR_WST",3);param:set("NVLR_WMS",3500)
tick(3750,2) -- magenta sensor error
param:set("NVLR_WST",2);param:set("NVLR_WET",0);param:set("NVLR_WMS",3750)
param:set("NVLR_TV",50);param:set("NVLR_TMS",3750)
tick(4000,1) -- temperature above NAVO app default 45C
assert(telemetry.NV3RGBR==2 and messages[#messages]:find("TEMP",1,true))
param:set("NVLR_TV",25)
tick(4300,7)
tick(20000,8) -- expired telemetry must not claim green
assert(sendCount>8,"physical output must have been written")
-- The LED pad often ships configured as ArduPilot notification output 120:
-- refuse a second controller until SERVO13_FUNCTION is explicitly 94.
values.SERVO13_FUNCTION=120
assert(dofile("ardupilot/scripts/navo_rgb_service.lua")==nil)
assert(initCount==1 and messages[#messages]:find("SERVO13_FUNCTION=94",1,true),
       "unverified pin must be rejected rather than changed")
print("PASS physical 5V WS2811 on LED/PWM13: priority, SHT31/water, relay, cuva, stale expiry and output gate")
