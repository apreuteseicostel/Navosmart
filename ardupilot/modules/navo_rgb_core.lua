-- Pure, testable colour priorities for one physical WS2811 status LED.
-- Never signal healthy green when alarm sensors have not both been verified.
local M={}
local function rgb(r,g,b) return {r,g,b} end
function M.select(s)
 if s.wet==true or (s.temperature_valid and s.temperature_c>=s.temp_alarm_c) then
     return "ALARM",rgb(255,0,0) -- wet/thermal, highest priority
 end
 if s.water_fault or s.temperature_fault then
     return "FAULT",rgb(215,0,215) -- failed installed sensor
 end
 if s.hopper_open then return "HOPPER",rgb(0,30,255) end
 if s.headlight==true and s.positions==true then
     return "BOTH_LIGHTS",rgb(255,200,0)
 end
 if s.headlight==true then return "HEADLIGHT",rgb(255,255,255) end
 if s.positions==true then return "POSITIONS",rgb(0,255,195) end
 if s.water_valid and s.temperature_valid then return "NORMAL",rgb(0,200,0) end
 return "UNMONITORED",rgb(255,100,0) -- do not claim normal
end
function M.scale(c,brightness)
 local v={}
 for i=1,3 do v[i]=math.max(0,math.min(255,math.floor(c[i]*brightness+0.5))) end
 return v
end
return M
