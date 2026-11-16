-- Standalone water service tests: no motor/servo/lights, safe GPIO, calibration gate.
package.path="ardupilot/modules/?.lua;"..package.path
local core=require("navo_water_core")
local cfg={enabled=false,adc_pin=7,exc_gpio=57,settle_ms=120,interval_ms=1000,
           confirm_samples=3,calibrated=false}
local c=core.new(cfg)
assert(c:push(1.5)==5 and c.wet==nil and c.fault)
assert(c:push(0/0)==3 and c.wet==nil)
cfg.calibrated=true;cfg.valid_min_v=0.2;cfg.valid_max_v=3.0
cfg.wet_on_v=1.0;cfg.dry_off_v=0.6;cfg.wet_above=true
assert(core.valid_calibration(cfg))
c=core.new(cfg)
assert(c:push(1.5)==1 and c.wet==nil)
assert(c:push(1.5)==1 and c:push(1.5)==2 and c.wet and not c.fault)
assert(c:push(0.5)==2 and c.wet==true)
assert(c:push(0.5)==2 and c:push(0.5)==2 and not c.wet)
assert(c:push(3.2)==3 and c.fault and c.wet==nil)
assert(c:push(0.4)==1 and c:push(0.4)==1 and c:push(0.4)==2)
-- An intermediate voltage (electrodes drying) holds the last confirmed wet state.
c=core.new(cfg)
assert(c:push(1.8)==1 and c:push(1.8)==1 and c:push(1.8)==2)
assert(c.wet==true and c:push(0.8)==2 and c.wet==true)
assert(c:push(0.5)==2 and c.wet==true)
assert(c:push(0.5)==2 and c.wet==true)
assert(c:push(0.5)==2 and c.wet==false)
-- A single wet spike cannot become a confirmed dry status or a confirmed leak.
assert(c:push(1.5)==1 and c.wet==nil)
assert(c:push(0.8)==1 and c.wet==nil)
-- Actual 13 Nov bench sequence: dry <0.003, water ~1.8-2.13, dry after ~9 s.
local logcfg={calibrated=true,valid_min_v=0,valid_max_v=3.0,
              wet_on_v=1.0,dry_off_v=0.1,wet_above=true,confirm_samples=3}
assert(core.valid_calibration(logcfg))
local bench=core.new(logcfg)
for _,v in ipairs({0.0017,0.0021,0.0014}) do bench:push(v) end
assert(bench.status==2 and bench.wet==false)
for _,v in ipairs({2.1333,2.0917,2.0624}) do bench:push(v) end
assert(bench.status==2 and bench.wet==true)
for _,v in ipairs({1.1759,0.6695,0.2647,0.2147}) do
 assert(bench:push(v)==2 and bench.wet==true)
end
for _,v in ipairs({0.03555,0.01662}) do
 assert(bench:push(v)==2 and bench.wet==true)
end
assert(bench:push(0.01425)==2 and bench.wet==false)
cfg.wet_on_v=3.3;assert(not core.valid_calibration(cfg))
cfg.wet_on_v=1.0
cfg.dry_off_v=1.0;assert(not core.valid_calibration(cfg))
cfg.dry_off_v=0.6

local raw=0
millis=function()return{tofloat=function()return raw end}end
local outputs,events,notes={},{},{}
local gpio_state=0
gcs={
 send_text=function(_,level,msg)notes[#notes+1]=msg end,
 send_named_float=function(_,name,value)
     events[#events+1]={name=name,value=value}
     outputs[name]=value
 end
}
local servo_function,second_battery=-1,0
local battery_mode,battery_pin=4,11
local battery2_pin,airspeed_type=7,0
param={get=function(_,name)
 if name=="SERVO8_FUNCTION" then return servo_function end
 if name=="BATT_MONITOR" then return battery_mode end
 if name=="BATT_CURR_PIN" then return battery_pin end
 if name=="BATT2_MONITOR" then return second_battery end
 if name=="BATT2_CURR_PIN" then return battery2_pin end
 if name=="ARSPD_TYPE" then return airspeed_type end
end}
local adcV=1.5
local selected_adc=-1
analog={channel=function()
 return {set_pin=function(_,pin)assert(pin==7 or pin==4);selected_adc=pin;return true end,
         voltage_latest=function()return adcV end}
end}
local gpio_writes={}
gpio={
 pinMode=function(_,pin,mode)assert(pin==57 and mode==1)end,
 write=function(_,pin,value)
    assert(pin==57 and (value==0 or value==1))
    gpio_state=value;gpio_writes[#gpio_writes+1]=value
 end
}
package.loaded.navo_water_config=cfg
assert(dofile("ardupilot/scripts/navo_water_service.lua")==nil) -- safe disabled
cfg.enabled=true
servo_function=0
local invalid=dofile("ardupilot/scripts/navo_water_service.lua")
assert(type(invalid)=="function" and outputs.NV3WSTAT==4 and gpio_state==0)
servo_function=-1
second_battery=4
invalid=dofile("ardupilot/scripts/navo_water_service.lua")
assert(type(invalid)=="function" and outputs.NV3WSTAT==4)
second_battery=0

-- Without calibrating the electrodes, only raw ADC voltage is reported.
cfg.calibrated=false
raw=0;local update=dofile("ardupilot/scripts/navo_water_service.lua")
assert(outputs.NV3WSTAT==1 and gpio_state==1)
raw=119;update();assert(gpio_state==1)
raw=120;update();assert(gpio_state==0 and outputs.NV3WADC==1.5)
raw=1120;update();raw=1240;update();assert(outputs.NV3WSTAT==5 and outputs.NV3WDET==nil)
-- Hardware restart with verified calibration after dry/wet/open/short measurement.
cfg.calibrated=true
raw=0;update=dofile("ardupilot/scripts/navo_water_service.lua")
raw=120;update();assert(gpio_state==0)
raw=1120;update();raw=1240;update();assert(outputs.NV3WDET==nil)
raw=2240;update();raw=2360;update()
assert(outputs.NV3WDET==1 and outputs.NV3WFLT==0 and gpio_state==0)
raw=3360;update();assert(outputs.NV3WSTAT==2)
-- Electrodes go dry: require three independent consistent ADC samples.
adcV=0.5
raw=3480;update();assert(gpio_state==0 and outputs.NV3WDET==1)
raw=4480;update();raw=4600;update()
raw=5600;update();raw=5720;update()
assert(outputs.NV3WDET==0 and outputs.NV3WFLT==0)
-- Out-of-range fault never publishes a false dry reading.
adcV=3.2
raw=6720;update();raw=6840;update()
assert(outputs.NV3WFLT==1 and gpio_state==0)
raw=7840;update();assert(outputs.NV3WSTAT==3)
-- Clock rollover must not hold excitation forever.
raw=4294967290;update();raw=10;update();raw=130;update()
assert(gpio_state==0 or gpio_state==1)
-- A primary total-pack current sensor on CU2 (pin 7) MUST exclude water.
cfg.calibrated=false
cfg.adc_pin=7
battery_pin=7
raw=0
local conflict=dofile("ardupilot/scripts/navo_water_service.lua")
assert(type(conflict)=="function" and outputs.NV3WSTAT==4)
battery_pin=11

-- New AirS ADC4 requires verified physical migration and unused airspeed.
cfg.adc_pin=4
cfg.airs_wiring_verified=false
raw=0
conflict=dofile("ardupilot/scripts/navo_water_service.lua")
assert(type(conflict)=="function" and outputs.NV3WSTAT==4)
cfg.airs_wiring_verified=true
airspeed_type=1
conflict=dofile("ardupilot/scripts/navo_water_service.lua")
assert(type(conflict)=="function" and outputs.NV3WSTAT==4)
airspeed_type=0

-- BATT current monitor must never reserve the same AirS pin.
battery_pin=4
conflict=dofile("ardupilot/scripts/navo_water_service.lua")
assert(type(conflict)=="function" and outputs.NV3WSTAT==4)
battery_pin=11
second_battery=4
battery2_pin=4
conflict=dofile("ardupilot/scripts/navo_water_service.lua")
assert(type(conflict)=="function" and outputs.NV3WSTAT==4)
second_battery=0
battery2_pin=7

raw=0
local air_update=dofile("ardupilot/scripts/navo_water_service.lua")
assert(type(air_update)=="function" and outputs.NV3WSTAT==1 and selected_adc==4)
raw=120;air_update()
assert(outputs.NV3WADC==adcV and outputs.NV3WDET~=1 and gpio_state==0)
-- The new pin defaults UNCALIBRATED regardless of old CU2 dry/wet examples.
raw=1120;air_update();raw=1240;air_update()
assert(outputs.NV3WSTAT==5)

print("PASS water service: CU2 and AirS pin ownership, verified AirS, dry/wet/fault, excitation shutdown")
