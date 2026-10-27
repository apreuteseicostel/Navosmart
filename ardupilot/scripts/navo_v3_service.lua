-- NAVO V3 v1: no UART/Nano dependency; disabled until hardware review.
local cfg=require("navo_v3_config")
if not cfg.enabled then gcs:send_text(6,"NAVO V3 disabled: hardware review required");return end
local core=require("navo_v3_core")
local msgs=require("MAVLink/mavlink_msgs")
local CMD=31001
local id=msgs.get_msgid("COMMAND_LONG")
local map={[id]="COMMAND_LONG"}
local function valid_int(v,lo,hi) return type(v)=="number" and v%1==0 and v>=lo and v<=hi end
local function check_hoppers()
    if not cfg.hoppers or #cfg.hoppers~=2 then return false end
    local seen={}
    for _,h in ipairs(cfg.hoppers) do
        if not valid_int(h.output,1,16) or seen[h.output] or not valid_int(h.open,900,2100) or not valid_int(h.closed,900,2100) then return false end
        seen[h.output]=true
        local p="SERVO"..h.output.."_"
        if param:get(p.."FUNCTION")~=135 or param:get(p.."TRIM")~=h.closed then return false end
        local lo,hi=param:get(p.."MIN"),param:get(p.."MAX")
        if not lo or not hi or math.min(h.open,h.closed)<lo or math.max(h.open,h.closed)>hi then return false end
    end
    return true
end
local function matches_calibration(p)
    if not cfg.hoppers then return false end
    local l,r=cfg.hoppers[1],cfg.hoppers[2]
    return p.param4==l.output+32*r.output and p.param5==l.closed+4096*l.open
        and p.param6==r.closed+4096*r.open and p.param7==cfg.hold_ms
end
local function close()
    for _,h in ipairs(cfg.hoppers or {}) do SRV_Channels:set_output_pwm_chan_timeout(h.output-1,h.closed,100) end
end
local io={
    hoppers_ready=check_hoppers,
    lights_ready=function() return cfg.lights~=nil end,
    light=function(action,value) gpio:write(action==1 and cfg.lights.head_gpio or cfg.lights.position_gpio,value) end,
    close=close,
    pulse=function(mask,duration)
        for i,h in ipairs(cfg.hoppers) do
            if mask==3 or mask==i then SRV_Channels:set_output_pwm_chan_timeout(h.output-1,h.open,duration) end
        end
    end,
}
-- Refuse obvious overlapping assignments before configuring any output.
local used={}
local function reserve(kind,pin)
    assert(valid_int(pin,0,255),"invalid "..kind)
    local key=kind..pin;assert(not used[key],"overlapping "..key);used[key]=true
end
if cfg.hoppers then assert(check_hoppers(),"NAVO hopper parameters not verified");for _,h in ipairs(cfg.hoppers) do reserve("output",h.output) end end
if cfg.rgb then reserve("output",cfg.rgb.output);assert(valid_int(cfg.rgb.count,1,1),"one RGB supported") end
if cfg.lights then reserve("gpio",cfg.lights.head_gpio);reserve("gpio",cfg.lights.position_gpio) end
if cfg.water then
    reserve("gpio",cfg.water.exc_gpio);reserve("adc",cfg.water.adc)
    assert(valid_int(cfg.water.settle_ms,100,500),"water settling invalid")
    assert(type(cfg.water.wet_above)=="boolean" and cfg.water.valid_min>=0 and cfg.water.valid_max<=3.3 and cfg.water.valid_min<cfg.water.threshold and cfg.water.threshold<cfg.water.valid_max,"invalid water calibration")
end
if cfg.temperature then reserve("adc",cfg.temperature.adc);assert(cfg.temperature.supply_v>0 and cfg.temperature.series_ohm>0 and cfg.temperature.nominal_ohm>0 and cfg.temperature.beta>0,"invalid NTC calibration") end
local function input(c)
    if not c then return nil end
    local ch=assert(analog:channel(),"ADC allocation failed");assert(ch:set_pin(c.adc),"invalid ADC pin");return ch
end
local temp_in=input(cfg.temperature)
local water_in=input(cfg.water)
if cfg.lights then for _,pin in ipairs({cfg.lights.head_gpio,cfg.lights.position_gpio}) do gpio:pinMode(pin,1);gpio:write(pin,0) end end
if cfg.water then gpio:pinMode(cfg.water.exc_gpio,1);gpio:write(cfg.water.exc_gpio,0) end
if cfg.rgb then
    assert(cfg.rgb.order=="RGB" or cfg.rgb.order=="GRB","invalid RGB order")
    local ok
    if cfg.rgb.order=="RGB" then ok=serialLED:set_num_neopixel_rgb(cfg.rgb.output,cfg.rgb.count)
    else ok=serialLED:set_num_neopixel(cfg.rgb.output,cfg.rgb.count) end
    assert(ok,"RGB output unavailable")
end
if cfg.hoppers then close() end
local state=core.new(cfg,io)
local temperature,water,fault=-32768,0,1
local phase,next_sample,publish_at="idle",0,0
local raw_previous,elapsed=nil,0
local function clock()
    local raw=millis():tofloat()
    if raw_previous then elapsed=elapsed+(raw-raw_previous)%4294967296 end
    raw_previous=raw
    return elapsed
end
mavlink:init(10,1);mavlink:register_rx_msgid(id);mavlink:block_command(CMD)
local function update()
    local now=clock()
    state:tick(now)
    -- Bounded input processing; closure is always serviced before commands.
    for _=1,4 do
        local raw,chan=mavlink:receive_chan();if not raw then break end
        local p=msgs.decode(raw,map)
        if p and p.command==CMD and p.target_system==param:get("SYSID_THISMAV") and p.target_component==1
            and p.sysid==cfg.gcs_system and p.compid==cfg.gcs_component then
            local result
            if p.param1==3 and not matches_calibration(p) then result=4
            elseif p.param1==1 and p.param2==1 and temp_in and (temperature<=-1000 or temperature>=55) then result=4
            else result=state:command(p.param1,p.param2,p.param3,now) end
            mavlink:send_chan(chan,msgs.encode("COMMAND_ACK",{command=CMD,result=result,progress=0,result_param2=0,target_system=p.sysid,target_component=p.compid}))
        end
    end
    if temp_in then temperature=core.ntc(temp_in:voltage_latest(),cfg.temperature) end
    if cfg.lights and temp_in and (temperature<=-1000 or temperature>=55) and state.head~=0 then
        io.light(1,0);state.head=0
    end
    if water_in then
        if phase=="idle" and now>=next_sample then
            gpio:write(cfg.water.exc_gpio,1);phase="settle";next_sample=now+cfg.water.settle_ms
        elseif phase=="settle" and now>=next_sample then
            water,fault=core.water(water_in:voltage_latest(),cfg.water)
            gpio:write(cfg.water.exc_gpio,0);phase="idle";next_sample=now+400
        end
    end
    if now>=publish_at then
        local caps=(cfg.lights and 1 or 0)+(temp_in and 2 or 0)+(water_in and 4 or 0)+(check_hoppers() and 8 or 0)+(cfg.rgb and 16 or 0)
        gcs:send_named_float("NV3VER",1);gcs:send_named_float("NV3CAP",caps)
        gcs:send_named_float("NV3TEMP",temperature);gcs:send_named_float("NV3WATER",water);gcs:send_named_float("NV3WFAULT",fault)
        gcs:send_named_float("NV3HEAD",state.head);gcs:send_named_float("NV3POS",state.pos)
        gcs:send_named_float("NV3HOP",state.hopper);gcs:send_named_float("NV3REQ",state.last_request)
        if cfg.rgb then
            local r,g,b=0,40,0
            if fault~=0 or temperature<=-1000 then r,g,b=40,0,40
            elseif water==1 or temperature>=55 then r,g,b=80,0,0
            elseif state.hopper~=0 then r,g,b=0,0,50 end
            assert(serialLED:set_RGB(cfg.rgb.output,-1,r,g,b),"RGB write failed");assert(serialLED:send(cfg.rgb.output),"RGB send failed")
        end
        publish_at=now+500
    end
    return update,20
end
local function protected()
    local ok,_,delay=pcall(update)
    if not ok then
        pcall(close)
        if cfg.water then pcall(function() gpio:write(cfg.water.exc_gpio,0) end) end
        if cfg.lights then pcall(function() io.light(1,0);io.light(2,0) end) end
        gcs:send_text(3,"NAVO V3 stopped: runtime fault; outputs closing")
        return -- no healthy heartbeat after a runtime failure
    end
    return protected,delay
end
return protected()
