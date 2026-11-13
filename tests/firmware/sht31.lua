package.path="ardupilot/modules/?.lua;"..package.path
local module=require("navo_sht31")
-- Datasheet CRC vector BE EF -> 92; known raw temperature/RH vectors.
local valid=string.char(0x66,0x66,0x93,0x80,0,0xa2)
local t,h=module.decode(valid)
assert(t and math.abs(t-25)<0.001 and math.abs(h-50)<0.001)
assert(module.decode(string.char(0xbe,0xef,0x92,0xbe,0xef,0x92)))
for _,v in ipairs({"",valid:sub(1,5),valid.."x",string.char(0x66,0x66,0,0x80,0,0xa2),string.char(0x66,0x66,0x93,0x80,0,0)}) do assert(module.decode(v)==nil) end
local count,fail=0,false
local device={set_retries=function()end,transfer=function(_,bytes,n)
 count=count+1
 if fail then return nil end
 if n==0 then assert(bytes==string.char(0x24,0));return "" end
 assert(bytes=="" and n==6);return valid
end}
local sensor=module.new(device)
sensor:tick(0);assert(count==1 and sensor.status==1)
sensor:tick(19);assert(count==1)
sensor:tick(20);assert(count==2 and sensor.status==2 and sensor.measured_at==20)
sensor:tick(5019);assert(count==2)
fail=true;sensor:tick(5020);assert(sensor.status==3 and sensor.temperature==nil)
fail=false;sensor:tick(10020);sensor:tick(10040);assert(sensor.status==2)
-- Execute the shipped adapter, including disabled and unsupported firmware paths.
local cfg={enabled=false,bus=0,address=0x44}
package.loaded.navo_sht31_config=cfg
i2c={get_device=function()error("disabled must not acquire I2C")end}
assert(dofile("ardupilot/scripts/navo_sht31_service.lua")==nil)
cfg.enabled=true
local raw,pub=0,{}
millis=function()return{tofloat=function()return raw end}end
gcs={send_text=function()end,send_named_float=function(_,k,v)pub[k]=v end}
i2c={get_device=function()return{set_retries=function()end}end}
local update=dofile("ardupilot/scripts/navo_sht31_service.lua");assert(pub.NV3ENV==4 and not pub.NV3HUM)
i2c.get_device=function(_,bus,address,hz)assert(bus==0 and address==0x44 and hz==100000);return device end
update=dofile("ardupilot/scripts/navo_sht31_service.lua");assert(pub.NV3ENV==1)
raw=20;update();assert(math.abs(pub.NV3HUM-50)<0.001 and pub.NV3ITMP==25)
raw=1000;update();assert(pub.NV3ENV==2)
fail=true;raw=5020;update();assert(pub.NV3ENV==3)
fail=false;raw=10020;update();raw=10040;update();raw=11020;update();assert(pub.NV3ENV==2)
-- millis rollover must not freeze sampling/freshness.
raw=4294967290;update();raw=10;update();raw=30;update()
print("PASS SHT31: CRC, exact length, conversion, nonblocking 20ms/5s state, failure/recovery, disabled, unsupported API, actual telemetry adapter, clock wrap")
