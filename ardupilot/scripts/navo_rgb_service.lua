-- NAVO physical WS2811 status LED, 5V / GND / DATA, one RGB owner.
-- Passive readback only: never changes RC inputs, relays, GPIO or servo PWM.
-- Sensor exchange uses RAM-only NVLR_* ArduPilot scripting parameters. Existing
-- water/SHT31 services write them when installed and calibrated.
local cfg=require("navo_rgb_config")
if not cfg.enabled then return end
local core=require("navo_rgb_core")
local function fail(reason)
 gcs:send_text(4,"NAVO RGB: "..reason)
 return nil
end
local chan=cfg.output
if type(chan)~="number" or chan%1~=0 or chan<1 or chan>16 then
 return fail("invalid output")
end
if param:get("SERVO"..chan.."_FUNCTION")~=cfg.required_servo_function then
 return fail("blocked: check LED wire / SERVO"..chan.."_FUNCTION="..cfg.required_servo_function)
end
if cfg.count~=1 or (cfg.order~="GRB" and cfg.order~="RGB") or
  type(cfg.brightness)~="number" or cfg.brightness<0 or cfg.brightness>0.5 then
 return fail("invalid WS2811 configuration")
end
-- Use an isolated table (key 173) shared with the independent sensor scripts.
-- Never call set_and_save; no flash wear from high-rate sensor telemetry.
local KEY=173
assert(param:add_table(KEY,"NVLR_",8),"NVLR param table conflict")
for i,name in ipairs({"WST","WET","WMS","TS","TMS","TV","HOP","HMS"}) do
 assert(param:add_param(KEY,i,name,-1),"NVLR parameter conflict: "..name)
 assert(param:set("NVLR_"..name,-1),"NVLR reset failed")
end
local ok
if cfg.order=="GRB" then ok=serialLED:set_num_neopixel(chan,1)
else ok=serialLED:set_num_neopixel_rgb(chan,1) end
if not ok then return fail("serialLED unsupported on output "..chan) end
local function finite(x)
 return type(x)=="number" and x==x and math.abs(x)<math.huge
end
local function fresh(time,now,expiry)
 return finite(time) and time>=0 and
     ((now-time+4294967296)%4294967296)<=(expiry or cfg.source_expiry_ms)
end
local function relay_state(index)
 if not relay then return nil end
 local e,v=pcall(function()return relay:enabled(index)end)
 if not e or v~=true then return nil end
 local good,state=pcall(function()return relay:get(index)end)
 if not good then return nil end
 if state==1 or state==true then return true end
 if state==0 or state==false then return false end
 return nil
end
-- Three independent, passive ways to discover a hopper operation:
-- (1) confirmed onboard V3 cycle, (2) read-only output PWM when API exists,
-- (3) G20 L1/R1 hold (fallback when the firmware cannot read per-channel PWM).
-- RC detects an operator request, not proof the mechanical lid moved.
local function hopper_pwm()
 if not SRV_Channels then return false end
 for _,out in ipairs(cfg.hopper_outputs) do
  local fn=param:get("SERVO"..out.."_FUNCTION")
  if cfg.hopper_servo_functions[fn] then
   local ok,pwm=pcall(function()return SRV_Channels:get_output_pwm_chan(out-1)end)
   if ok and finite(pwm) and
       math.abs(pwm-cfg.hopper_open_pwm)<=cfg.hopper_tolerance_us then
       return true
   end
  end
 end
 -- Stock ArduPilot Lua exposes get_output_pwm(function), not necessarily
 -- get_output_pwm_chan(channel). This only observes the FIRST output 135.
 local ok,pwm=pcall(function()return SRV_Channels:get_output_pwm(135)end)
 return ok and finite(pwm) and
     math.abs(pwm-cfg.hopper_open_pwm)<=cfg.hopper_tolerance_us
end
local rcHighSince={}
local lastRcHopper=-1
local function hopper_rc(now)
 if not rc then return false end
 for _,channel in ipairs(cfg.hopper_rc_channels) do
  local ok,pwm=pcall(function()return rc:get_pwm(channel)end)
  if ok and finite(pwm) and pwm>=cfg.hopper_rc_high_us then
   if rcHighSince[channel]==nil then rcHighSince[channel]=now end
   if ((now-rcHighSince[channel]+4294967296)%4294967296)>=cfg.hopper_rc_hold_ms then
      lastRcHopper=now
   end
  else
   rcHighSince[channel]=nil
  end
 end
 return fresh(lastRcHopper,now,cfg.hopper_blue_hold_ms)
end
-- Confirmed wet is latched until a continuously valid DRY state lasts 3s:
-- no misleading red/green flicker if the probe drifts near its threshold.
local wetLatched=false
local drySince=nil
local function wet_state(now,valid,wet)
 if valid and wet==1 then wetLatched=true;drySince=nil end
 if wetLatched and valid and wet==0 then
  if drySince==nil then drySince=now
  elseif ((now-drySince+4294967296)%4294967296)>=3000 then
    wetLatched=false;drySince=nil
  end
 else
  drySince=nil
 end
 return wetLatched
end
local colourCodes={
 ALARM=1,FAULT=2,HOPPER=3,HEADLIGHT=4,POSITIONS=5,
 BOTH_LIGHTS=6,NORMAL=7,UNMONITORED=8,
}
-- NV3RGBS gives the exact origin of the commanded physical colour.
local reasonCodes={
 WATER=1,HOT=2,WATER_FAULT=3,TEMP_FAULT=4,
 HOPPER_V3=5,HOPPER_PWM=6,HOPPER_RC=7,
 FAR=8,POZITII=9,BOTH=10,NORMAL=11,MISSING=12,WATER_LATCH=13,
}
local last,lastReason,previous,now=nil,nil,nil,0
local nextPublish=0
local function update()
 local raw=millis():tofloat()
 if previous~=nil then now=now+(raw-previous)%4294967296 end
 previous=raw
 local wts,wms=param:get("NVLR_WST"),param:get("NVLR_WMS")
 local ts,tms=param:get("NVLR_TS"),param:get("NVLR_TMS")
 local wet=param:get("NVLR_WET")
 local temp=param:get("NVLR_TV")
 local onboardHopper=param:get("NVLR_HOP")
 local onboardHopperTime=param:get("NVLR_HMS")
 -- Source times are raw millis(); use raw for rollover-safe freshness.
 local waterAlive=fresh(wms,raw)
 local tempAlive=fresh(tms,raw)
 local validWater=waterAlive and wts==2 and (wet==0 or wet==1)
 local validTemp=tempAlive and ts==2 and finite(temp) and temp>=-40 and temp<=125
 local wetAlarm=wet_state(raw,validWater,wet)
 local hopperSource=nil
 if fresh(onboardHopperTime,raw,cfg.hopper_expiry_ms)
     and finite(onboardHopper) and onboardHopper>0 then
    hopperSource="HOPPER_V3"
 elseif hopper_pwm() then hopperSource="HOPPER_PWM"
 elseif hopper_rc(raw) then hopperSource="HOPPER_RC" end
 local status,color,reason=core.select({
     wet=wetAlarm,
     water_latched=wetAlarm and not (validWater and wet==1),
     water_valid=validWater,
     water_fault=waterAlive and wts==3,
     temperature_valid=validTemp,
     temperature_c=validTemp and temp or -1000,
     temperature_fault=tempAlive and ts==3,
     temp_alarm_c=cfg.temp_alarm_c,
     hopper_open=hopperSource~=nil,
     hopper_source=hopperSource,
     headlight=relay_state(0),
     positions=relay_state(1),
 })
 local c=core.scale(color,cfg.brightness)
 assert(serialLED:set_RGB(chan,-1,c[1],c[2],c[3]),"set_RGB failed")
 assert(serialLED:send(chan),"serialLED send failed")
 local changed=status~=last or reason~=lastReason
 if changed then
     gcs:send_text(6,"NAVO RGB: "..status.." / "..reason)
     last=status;lastReason=reason
 end
 -- Publish every transition immediately; repeat only at 1Hz while steady.
 if changed or now>=nextPublish then
     gcs:send_named_float("NV3RGBC",colourCodes[status] or 0)
     gcs:send_named_float("NV3RGBS",reasonCodes[reason] or 0)
     nextPublish=now+1000
 end
 return update,cfg.update_ms
end
local function protected()
 local succeeded,next,delay=pcall(update)
 if not succeeded then
   pcall(function()serialLED:set_RGB(chan,-1,0,0,0);serialLED:send(chan)end)
   gcs:send_text(3,"NAVO RGB stopped: LED update error")
   return
 end
 return protected,delay
end
return protected()
