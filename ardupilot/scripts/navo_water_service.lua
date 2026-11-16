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
    -- CU2 ADC7 is the original water connection. AirS ADC4 can replace it
    -- only AFTER moving J12.3 physically and verifying its divided input.
    -- Never interpret this software option as a physical wiring change.
    assert((cfg.adc_pin==7 or cfg.adc_pin==4) and cfg.exc_gpio==57,
           "verify J12 analog and EXC mapping")
    assert(integer(cfg.settle_ms,100,500),"invalid settle_ms")
    assert(integer(cfg.interval_ms,600,10000) and cfg.interval_ms>=cfg.settle_ms+100,"invalid interval_ms")
    assert(integer(cfg.confirm_samples,2,6),"invalid confirmation count")
    assert(type(cfg.calibrated)=="boolean" and core.valid_calibration(cfg),"invalid calibration")
    assert(param:get("SERVO8_FUNCTION")==-1,"S8 must be GPIO; do not override RC/servo")
    local battery_mode=param:get("BATT_MONITOR")
    local battery_pin=param:get("BATT_CURR_PIN")
    local battery2_mode=param:get("BATT2_MONITOR")
    local battery2_pin=param:get("BATT2_CURR_PIN")
    -- Deny sharing ANY active current-monitor ADC with the water service.
    assert(battery_mode~=nil and battery_pin~=nil and battery2_mode~=nil,
           "battery monitor parameters unavailable; refuse ADC")
    local function battery_owns_pin(pin)
        return (battery_mode~=0 and battery_mode~=3 and battery_pin==pin)
            or (battery2_mode~=0 and battery2_mode~=3 and battery2_pin==pin)
    end
    assert(not battery_owns_pin(cfg.adc_pin),"ADC reserved for battery current")
    if cfg.adc_pin==7 then
        -- Original wiring may only coexist with disabled secondary monitor.
        assert(battery2_mode==0,"CU2 may belong to battery monitor 2")
    else
        -- AirS/PC4 ADC4: verify actual pin/wire and no analog airspeed owner.
        -- ARSPD_TYPE is absent on some Rover builds; nil is not proof of
        -- availability, hence the separate mandatory wiring verification flag.
        assert(cfg.airs_wiring_verified==true,"AirS wiring not confirmed")
        local airspeed_type=param:get("ARSPD_TYPE")
        assert(airspeed_type==nil or airspeed_type==0,
               "AirS is owned by airspeed")
    end
    channel=assert(analog:channel(),"ADC channel allocation failed")
    assert(channel:set_pin(cfg.adc_pin),"ADC pin unavailable")
    gpio:pinMode(cfg.exc_gpio,1)
    gpio:write(cfg.exc_gpio,0)
    ready=true
end)
status=ready and 1 or 4
if not setup_ok then
    gcs:send_text(4,"NAVO WATER: ADC/GPIO conflict; disabled (verify AirS/CU2, S8, battery/airspeed)")
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
