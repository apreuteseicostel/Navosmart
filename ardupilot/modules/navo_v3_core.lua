-- Pure state machine. Hardware calls are injected by navo_v3_service.lua.
local M={}
local function finite(v) return type(v)=="number" and v==v and math.abs(v)<math.huge end
local function integer(v,lo,hi) return finite(v) and v%1==0 and v>=lo and v<=hi end
function M.new(cfg,io)
    assert(integer(cfg.hold_ms,100,2000),"invalid hold time")
    local s={head=0,pos=0,hopper=0,last_request=0,deadline=0}
    function s:command(action,value,request,now)
        if not integer(request,1,16777215) then return 4 end
        -- Strict monotonic sequence for the configured GCS for this boot.
        -- A retry acknowledges the same operation without extending a pulse.
        if request==self.last_request then
            if action==self.last_action and value==self.last_value then return self.last_result end
            return 4
        end
        if request<self.last_request then return 4 end
        if action==1 or action==2 then
            if not io.lights_ready() then return 3 end
            if not integer(value,0,1) then return 4 end -- idempotent ON/OFF only
            io.light(action,value)
            if action==1 then self.head=value else self.pos=value end
        elseif action==3 then
            if not io.hoppers_ready() then return 3 end
            if not integer(value,1,3) then return 4 end
            if self.hopper~=0 then return 1 end
            -- Driver uses the autopilot's bounded override, never an app timer.
            io.pulse(value,cfg.hold_ms)
            self.hopper=value;self.deadline=now+cfg.hold_ms
        elseif action==4 then
            if not io.hoppers_ready() then return 3 end
            if value~=0 then return 4 end
            io.close();self.hopper=0
        else return 3 end
        self.last_request=request;self.last_action=action;self.last_value=value;self.last_result=0
        return 0
    end
    function s:tick(now)
        if self.hopper~=0 and now>=self.deadline then io.close();self.hopper=0 end
    end
    return s
end
-- Explicit divider topology and actual measured ADC supply are configuration.
function M.ntc(v,c)
    if not finite(v) or v<=0.03 or v>=c.supply_v-0.03 then return -32768 end
    local r=c.ntc_to_ground and c.series_ohm*v/(c.supply_v-v) or c.series_ohm*(c.supply_v-v)/v
    local t=1/(1/298.15+math.log(r/c.nominal_ohm)/c.beta)-273.15
    if not finite(t) or t < -40 or t > 125 then return -32768 end
    return t
end
function M.water(v,c)
    if not finite(v) or v<c.valid_min or v>c.valid_max then return 0,1 end
    return (c.wet_above and v>=c.threshold or not c.wet_above and v<=c.threshold) and 1 or 0,0
end
return M
