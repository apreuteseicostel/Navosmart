-- Pure, hardware-free classifications for NAVO water probe.
local M={}
local function finite(v) return type(v)=="number" and v==v and math.abs(v)<math.huge end
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
        local wet=(cfg.wet_above and volts>=cfg.threshold_v) or
                  (not cfg.wet_above and volts<=cfg.threshold_v)
        if wet==self.candidate then self.count=self.count+1
        else self.candidate=wet;self.count=1 end
        if self.count < cfg.confirm_samples then
            self.status=1;self.wet=nil;self.fault=true
        else
            self.status=2;self.wet=wet;self.fault=false
        end
        return self.status
    end
    return self
end
function M.valid_calibration(c)
    if not c.calibrated then return true end
    return finite(c.valid_min_v) and finite(c.valid_max_v)
       and finite(c.threshold_v) and c.valid_min_v>=0 and c.valid_max_v<=3.3
       and c.valid_min_v<c.threshold_v and c.threshold_v<c.valid_max_v
       and type(c.wet_above)=="boolean"
end
return M
