-- NAVO WS2811 colour priority, with a reason for app diagnostics.
-- Source validity comes from the independent water/SHT31 services.
local M={}
local function rgb(r,g,b) return {r,g,b} end
function M.select(s)
 if s.wet==true then return "ALARM",rgb(255,0,0),s.water_latched and "WATER_LATCH" or "WATER" end
 if s.temperature_valid and s.temperature_c>=s.temp_alarm_c then
     return "ALARM",rgb(255,0,0),"HOT"
 end
 if s.water_fault then return "FAULT",rgb(215,0,215),"WATER_FAULT" end
 if s.temperature_fault then return "FAULT",rgb(215,0,215),"TEMP_FAULT" end
 if s.hopper_open then return "HOPPER",rgb(0,30,255),s.hopper_source or "HOPPER_PWM" end
 if s.headlight==true and s.positions==true then return "BOTH_LIGHTS",rgb(255,200,0),"BOTH" end
 if s.headlight==true then return "HEADLIGHT",rgb(255,255,255),"FAR" end
 if s.positions==true then return "POSITIONS",rgb(0,255,195),"POZITII" end
 if s.water_valid and s.temperature_valid then return "NORMAL",rgb(0,200,0),"NORMAL" end
 return "UNMONITORED",rgb(255,100,0),"MISSING" -- never imply healthy
end
function M.scale(c,brightness)
 local v={}
 for i=1,3 do v[i]=math.max(0,math.min(255,math.floor(c[i]*brightness+0.5))) end
 return v
end
return M
