-- NAVO SMART V3 independent read-only water/leak probe service.
-- Only drives one verified probe EXC GPIO while sampling and transmits MAVLink.
-- Does not arm, move the boat, change ArduPilot params, switch lights or servos.
local cfg=require("navo_water_config")
if not cfg or not cfg.enabled then return end
local core=require("navo_water_core")
local state=core.new(cfg)
local channel,ready=nil,false
local status,phase=4,"idle"
local next_sample,settled_at,publish_at=0,0,0
local raw_previous,now=nil,0
local function finite(v) return type(v)=="number" and v==v and math.abs(v)<math.huge end
local function integer(v,lo,hi) return finite(v) and v%1==0 and v>=lo and v<=hi end
local setup_ok=pcall(function()
    -- RevF pin selection is a proposal; never accept an arbitrary motor/servo output.
    assert(cfg.adc_pin==7 and cfg.exc_gpio==57,"verify J12 hardware mapping")
    assert(integer(cfg.settle_ms,100,500),"invalid settle_ms")
    assert(integer(cfg.interval_ms,600,10000) and cfg.interval_ms>=cfg.settle_ms+100,"invalid interval_ms")
    assert(integer(cfg.confirm_samples,2,6),"invalid confirmation count")
    assert(type(cfg.calibrated)=="boolean" and core.valid_calibration(cfg),"invalid calibration")
    assert(param:get("SERVO8_FUNCTION")==-1,"S8 must be GPIO; do not override RC/servo")
    assert(param:get("BATT2_MONITOR")==0,"CU2 may belong to battery monitor 2")
    channel=assert(analog:channel(),"ADC channel allocation failed")
    assert(channel:set_pin(cfg.adc_pin),"ADC pin unavailable")
    gpio:pinMode(cfg.exc_gpio,1)
    gpio:write(cfg.exc_gpio,0)
    ready=true
end)
status=ready and 1 or 4
if not setup_ok then
    gcs:send_text(4,"NAVO WATER: config/pin conflict; disabled (check J12, SERVO8, BATT2)")
end
local function clock_ms()
    local raw=millis():tofloat()
    if raw_previous~=nil then now=now+(raw-raw_previous)%4294967296 end
    raw_previous=raw
    return now
end
local function update()
    local time=clock_ms()
    if ready then
        if phase=="idle" and time>=next_sample then
            gpio:write(cfg.exc_gpio,1)
            phase="settling"
            settled_at=time+cfg.settle_ms
        elseif phase=="settling" and time>=settled_at then
            -- Always turn excitation off *before* interpreting measurements.
            local reading=channel:voltage_latest()
            gpio:write(cfg.exc_gpio,0)
            phase="idle"
            next_sample=time+cfg.interval_ms
            if finite(reading) and reading>=0 and reading<=3.3 then
                gcs:send_named_float("NV3WADC",reading)
            end
            status=state:push(reading)
            -- An uncalibrated probe NEVER claims water present or dry.
            if status==2 then
                gcs:send_named_float("NV3WDET",state.wet and 1 or 0)
                gcs:send_named_float("NV3WFLT",0)
            elseif status==3 then
                gcs:send_named_float("NV3WFLT",1)
            end
        end
    end
    if time>=publish_at then
        gcs:send_named_float("NV3WSTAT",status)
        publish_at=time+1000
    end
    return update,20
end
local function protected()
    local ok,next_fn,delay=pcall(update)
    if not ok then
        pcall(function() if ready then gpio:write(cfg.exc_gpio,0) end end)
        ready=false
        status=3
        gcs:send_named_float("NV3WSTAT",3)
        gcs:send_text(3,"NAVO WATER: runtime failure; excitation OFF")
        return -- do not fake healthy telemetry
    end
    return protected,delay
end
return protected()
