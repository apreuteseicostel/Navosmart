package.path="ardupilot/modules/?.lua;"..package.path
local core=require('navo_v3_core')
local pulses,closes,lights=0,0,0
local s=core.new({hold_ms=900},{lights_ready=function()return true end,hoppers_ready=function()return true end,
 light=function()lights=lights+1 end,pulse=function()pulses=pulses+1 end,close=function()closes=closes+1 end})
assert(s:command(3,3,1,0)==0 and pulses==1)
assert(s:command(3,3,1,500)==0 and pulses==1 and s.deadline==900)
assert(s:command(3,1,1,500)==4)
assert(s:command(3,1,2,500)==1)
s:tick(899);assert(closes==0);s:tick(900);assert(closes==1 and s.hopper==0)
assert(s:command(3,3,1,1000)==0 and pulses==1) -- delayed retry must not reopen
assert(s:command(1,2,2,1000)==4) -- no TOGGLE retry ambiguity
assert(s:command(1,1,2,1000)==0 and lights==1)
assert(s:command(3,1,1,1000)==4) -- stale sequence
assert(s:command(3,1,3,1000)==0);assert(s:command(4,0,4,1001)==0 and s.hopper==0)
local tc={supply_v=3.3,series_ohm=10000,nominal_ohm=10000,beta=3950,ntc_to_ground=true}
assert(math.abs(core.ntc(1.65,tc)-25)<0.001)
assert(core.ntc(0,tc)==-32768 and core.ntc(3.3,tc)==-32768 and core.ntc(0/0,tc)==-32768)
local wet,broken=core.water(0/0,{valid_min=0.1,valid_max=3,threshold=1,wet_above=true});assert(wet==0 and broken==1)
-- Execute real service adapter, with explicit transport/hardware fixtures.
local cfg={enabled=true,gcs_system=255,gcs_component=190,hold_ms=900,
 hoppers={{output=9,closed=1500,open=1900},{output=10,closed=1500,open=1900}},lights={head_gpio=55,position_gpio=56}}
package.loaded.navo_v3_config=cfg
local now,command=0,nil
local pub,acks,overrides={},{},{}
millis=function()return{tofloat=function()return now end}end
param={get=function(_,name)
 if name=='SYSID_THISMAV' then return 1 end
 if name:find('FUNCTION') then return 135 end
 if name:find('TRIM') then return 1500 end
 if name:find('MIN') then return 900 end
 if name:find('MAX') then return 2100 end
end}
gcs={send_text=function()end,send_named_float=function(_,key,value)pub[key]=value end}
gpio={pinMode=function()end,write=function()end}
SRV_Channels={set_output_pwm_chan_timeout=function(_,ch,pwm,duration)overrides[#overrides+1]={ch,pwm,duration}end}
mavlink={init=function()end,register_rx_msgid=function()end,block_command=function()end,
 receive_chan=function()local c=command;command=nil;return c,0 end,
 send_chan=function(_,_,ack)acks[#acks+1]=ack end}
package.preload['MAVLink/mavlink_msgs']=function()return{get_msgid=function()return 76 end,decode=function(p)return p end,encode=function(_,p)return p end}end
local update=dofile('ardupilot/scripts/navo_v3_service.lua');assert(pub.NV3CAP==9)
local function release(request)
 return{command=31001,target_system=1,target_component=1,sysid=255,compid=190,param1=3,param2=3,param3=request,
 param4=9+32*10,param5=1500+4096*1900,param6=1500+4096*1900,param7=900}
end
command=release(1);command.target_system=2;update();assert(#acks==0)
command=release(1);command.sysid=2;update();assert(#acks==0)
command=release(1);command.param7=1000;update();assert(acks[#acks].result==4)
command=release(1);update();assert(acks[#acks].result==0)
assert(overrides[#overrides][1]==9 and overrides[#overrides][2]==1900 and overrides[#overrides][3]==900)
local count=#overrides;now=500;command=release(1);update();assert(#overrides==count)
-- No app traffic after opening: onboard loop closes and publishes completion.
now=920;update();assert(overrides[#overrides][2]==1500)
now=1020;update();assert(pub.NV3HOP==0 and pub.NV3REQ==1)
-- A wrong servo function refuses configuration before opening.
param.get=function()return 0 end
assert(not pcall(function()dofile('ardupilot/scripts/navo_v3_service.lua')end))
print('PASS V3 core + service: timer without app, duplicate/stale request, sender/target, calibration, NTC and invalid water')
-- Exercise ADC pulsing and RGB paths in the actual adapter too.
cfg.hoppers=nil;cfg.lights=nil
cfg.temperature={adc=8,supply_v=3.3,series_ohm=10000,nominal_ohm=10000,beta=3950,ntc_to_ground=true}
cfg.water={adc=7,exc_gpio=57,settle_ms=100,valid_min=0.1,valid_max=3.0,threshold=1.0,wet_above=true}
cfg.rgb={output=13,count=1,order='GRB'}
local adc_values={[8]=1.65,[7]=1.2};local excitation;local rgb
analog={channel=function()return{set_pin=function(self,pin)self.pin=pin;return true end,voltage_latest=function(self)return adc_values[self.pin]end}end}
gpio.write=function(_,pin,value)if pin==57 then excitation=value end end
serialLED={set_num_neopixel=function()return true end,set_RGB=function(_,_,_,r,g,b)rgb={r,g,b};return true end,send=function()return true end}
now=0;update=dofile('ardupilot/scripts/navo_v3_service.lua')
assert(excitation==1 and pub.NV3WFAULT==1 and math.abs(pub.NV3TEMP-25)<0.001)
now=99;update();assert(excitation==1)
now=100;update();assert(excitation==0)
now=500;update();assert(pub.NV3WATER==1 and pub.NV3WFAULT==0 and rgb[1]==80)
adc_values[8]=0;now=1000;update();assert(pub.NV3TEMP==-32768)
-- RGB runtime failure withdraws the heartbeat and removes excitation.
serialLED.send=function()error('driver failed')end
now=1500;assert(update()==nil and excitation==0)
print('PASS actual V3 sensor/RGB adapter: settling, wet detection, NTC open circuit and safe runtime shutdown')
