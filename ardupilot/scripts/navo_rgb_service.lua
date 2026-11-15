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
local function hopper_open()
 if not SRV_Channels then return false end
 for _,out in ipairs(cfg.hopper_outputs) do
  -- Servo output belongs to timed hopper service only when FUNCTION=135.
  if param:get("SERVO"..out.."_FUNCTION")==135 then
   local success,pwm=pcall(function()
       return SRV_Channels:get_output_pwm_chan(out-1)
   end)
   if success and finite(pwm) and
      math.abs(pwm-cfg.hopper_open_pwm)<=cfg.hopper_tolerance_us then
      return true
   end
  end
 end
 return false
end
local colourCodes={
 ALARM=1,FAULT=2,HOPPER=3,HEADLIGHT=4,POSITIONS=5,
 BOTH_LIGHTS=6,NORMAL=7,UNMONITORED=8,
}
local last,previous,now=nil,nil,0
local lastReportMs=-100000
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
 local hopperActive=(fresh(onboardHopperTime,raw,cfg.hopper_expiry_ms)
                  and finite(onboardHopper) and onboardHopper>0)
                  or hopper_open()
 local far=relay_state(0)
 local pos=relay_state(1)
 local alarmWater=validWater and wet==1
 local alarmTemp=validTemp and temp>=cfg.temp_alarm_c
 local status,color=core.select({
     wet=alarmWater,
     water_valid=validWater,
     water_fault=waterAlive and wts==3,
     temperature_valid=validTemp,
     temperature_c=validTemp and temp or -1000,
     temperature_fault=tempAlive and ts==3,
     temp_alarm_c=cfg.temp_alarm_c,
     hopper_open=hopperActive,
     headlight=far,
     positions=pos,
 })
 local c=core.scale(color,cfg.brightness)
 assert(serialLED:set_RGB(chan,-1,c[1],c[2],c[3]),"set_RGB failed")
 assert(serialLED:send(chan),"serialLED send failed")
 local changed=status~=last
 if changed then
     local why=status
     if status=="ALARM" then
         why=alarmWater and alarmTemp and "ALARM WATER+TEMP"
              or alarmWater and "ALARM WATER" or "ALARM TEMP"
     elseif status=="FAULT" then
         why=(waterAlive and wts==3 and "FAULT WATER" or "")
            ..(tempAlive and ts==3 and " FAULT TEMP" or "")
     elseif status=="HOPPER" then
         why="HOPPER PWM/ONBOARD"
     elseif status=="POSITIONS" then why="POSITIONS RELAY2"
     elseif status=="HEADLIGHT" then why="HEADLIGHT RELAY1"
     elseif status=="BOTH_LIGHTS" then why="HEADLIGHT+POSITIONS"
     end
     gcs:send_text(6,"NAVO RGB: "..why)
     last=status
 end
 -- Explicit reason bits; no false claim of electrical LED feedback.
 -- 1=water alarm, 2=temperature alarm, 4=water sensor fault,
 -- 8=temp sensor fault, 16=hopper cycle, 32=far, 64=positions.
 local reason=(alarmWater and 1 or 0)+(alarmTemp and 2 or 0)
     +(waterAlive and wts==3 and 4 or 0)
     +(tempAlive and ts==3 and 8 or 0)
     +(hopperActive and 16 or 0)+(far==true and 32 or 0)
     +(pos==true and 64 or 0)
 gcs:send_named_float("NV3RGBC",colourCodes[status] or 0)
 if changed or now-lastReportMs>=1000 then
     gcs:send_named_float("NV3RGBR",reason)
     lastReportMs=now
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
