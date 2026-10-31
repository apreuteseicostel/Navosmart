-- Independent read-only environment service; never controls actuators or modes.
local cfg=require("navo_v3_config").interior_sht31
if not cfg or not cfg.enabled then return end
local sensor,status,last_sample=nil,4,nil
local ok=pcall(function()
    assert(type(cfg.bus)=="number" and cfg.bus%1==0 and cfg.bus>=0 and cfg.bus<=3,"review I2C bus")
    assert(cfg.address==0x44 or cfg.address==0x45,"invalid SHT31 address")
    local dev=assert(i2c:get_device(cfg.bus,cfg.address,100000),"I2C unavailable")
    -- transfer() is required for reads without a register byte. No fake fallback.
    assert(type(dev.transfer)=="function","firmware lacks I2C transfer")
    dev:set_retries(1)
    sensor=require("navo_sht31").new(dev)
end)
if not ok then gcs:send_text(4,"NAVO SHT31: unsupported I2C/config; check firmware and bus") end
local previous,now,publish_at=nil,0,0
local function update()
    local raw=millis():tofloat()
    if previous then now=now+(raw-previous)%4294967296 end
    previous=raw
    if sensor then
        local good=pcall(function()sensor:tick(now)end)
        status=good and sensor.status or 3
        if status==2 and sensor.measured_at~=last_sample then
            gcs:send_named_float("NV3ITMP",sensor.temperature)
            gcs:send_named_float("NV3HUM",sensor.humidity)
            last_sample=sensor.measured_at
        end
        if status==2 and now-sensor.measured_at>=12000 then status=3 end
    end
    if now>=publish_at then gcs:send_named_float("NV3ENV",status);publish_at=now+1000 end
    return update,20
end
return update()
