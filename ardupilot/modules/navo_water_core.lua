-- Pure, hardware-free classifications for NAVO water probe.
-- Hysteresis: uncertain transition values never imply a confirmed dry state.
local M={}
local function finite(v)
    return type(v)=="number" and v==v and math.abs(v)<math.huge
end
function M.new(cfg)
    local self={status=1,wet=nil,fault=true,candidate=nil,count=0}
    function self:push(volts)
        if not finite(volts) or volts<0 or volts>3.3 then
            self.status=3;self.wet=nil;self.fault=true;self.candidate=nil;self.count=0
            return self.status
        end
        if not cfg.calibrated then
            self.status=5;self.wet=nil;self.fault=true;self.candidate=nil;self.count=0
            return self.status
        end
        if volts<cfg.valid_min_v or volts>cfg.valid_max_v then
            self.status=3;self.wet=nil;self.fault=true;self.candidate=nil;self.count=0
            return self.status
        end
        local candidate=nil
        if cfg.wet_above then
            if volts>=cfg.wet_on_v then candidate=true
            elseif volts<=cfg.dry_off_v then candidate=false end
        else
            if volts<=cfg.wet_on_v then candidate=true
            elseif volts>=cfg.dry_off_v then candidate=false end
        end
        -- While voltage is in the transition band, retain the last confirmed
        -- state; never treat an ambiguous startup reading as dry.
        if candidate==nil then
            self.candidate=nil;self.count=0
            self.status=self.wet==nil and 1 or 2
            self.fault=self.wet==nil
            return self.status
        end
        if self.wet==candidate then
            self.candidate=nil;self.count=0
            self.status=2;self.fault=false
            return self.status
        end
        if candidate==self.candidate then self.count=self.count+1
        else self.candidate=candidate;self.count=1 end
        if self.count>=cfg.confirm_samples then
            self.wet=candidate;self.status=2;self.fault=false
            self.candidate=nil;self.count=0
        elseif self.wet==true and candidate==false then
            -- Keep WATER DETECTED until a complete dry confirmation.
            self.status=2;self.fault=false
        else
            -- Initial acquisition or a possible new leak: wait for proof.
            self.status=1;self.wet=nil;self.fault=true
        end
        return self.status
    end
    return self
end
function M.valid_calibration(c)
    if not c.calibrated then return true end
    if not (finite(c.valid_min_v) and finite(c.valid_max_v)
       and finite(c.wet_on_v) and finite(c.dry_off_v)
       and c.valid_min_v>=0 and c.valid_max_v<=3.3
       and c.valid_min_v<c.valid_max_v and type(c.wet_above)=="boolean") then
        return false
    end
    if c.wet_above then
        return c.valid_min_v<=c.dry_off_v and c.dry_off_v<c.wet_on_v
           and c.wet_on_v<=c.valid_max_v
    else
        return c.valid_min_v<=c.wet_on_v and c.wet_on_v<c.dry_off_v
           and c.dry_off_v<=c.valid_max_v
    end
end
return M
