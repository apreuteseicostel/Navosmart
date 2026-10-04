-- Executes the actual ArduPilot bridge with explicit UART/GCS/MAVLink mocks.
local input=""
local publications,acks,writes={},{},{}
local command
local uart={}
function uart:begin() end
function uart:set_flow_control() end
function uart:available() return #input end
function uart:read() local b=input:byte(1);input=input:sub(2);return b or -1 end
function uart:writestring(s) writes[#writes+1]=s end
serial={find_serial=function()return uart end}
gcs={send_text=function()end,send_named_float=function(_,name,value)publications[#publications+1]={name,value}end}
mavlink={init=function()end,register_rx_msgid=function()end,block_command=function()end,
 receive_chan=function()local p=command;command=nil;return p,0 end,
 send_chan=function(_,_,ack)acks[#acks+1]=ack end}
package.preload["MAVLink/mavlink_msgs"]=function()return {
 get_msgid=function()return 76 end,decode=function(p)return p end,encode=function(_,p)return p end}end
local update=dofile("ardupilot/scripts/navo_nano_bridge.lua")
local function frame(payload)
 local sum=0;for i=1,#payload do sum=sum~payload:byte(i)end
 return "$"..payload.."*"..string.format("%02X",sum).."\r\n"
end
local good="NAVO,1,500,16000,220,0,0,1,1,1500,1900,1500,0"
local function drain(bytes) input=input..bytes;while #input>0 do update()end end
for i=1,#frame(good)do drain(frame(good):sub(i,i))end
assert(#publications==10 and publications[1][2]==16 and publications[2][2]==22)
for _,bad in ipairs({good..",0",good:gsub("NAVO,1","NAVO,2"),good:gsub(",16000,",",1e999,"),good:gsub(",220,",",220,,"),good:gsub(",1500,1900,",",3000,1900,"),good:gsub(",0,0,1,1,",",2,0,1,1,"),(good:gsub(",220,",",nan,"))})do drain(frame(bad));assert(#publications==10)end
drain(frame(good):gsub("%*..","*00"));assert(#publications==10)
-- A valid-looking tail after overflow must be discarded until newline.
drain(string.rep("x",181)..frame(good));assert(#publications==10)
drain(frame(good));assert(#publications==20)
command={msgid=76,command=31000,param1=1,param2=2,sysid=255,compid=190};update()
assert(#writes==1 and writes[1]==frame("NAVOCMD,1,HEAD,TOGGLE") and acks[1].result==0)
command={msgid=76,command=31000,param1=1.4,param2=2,sysid=255,compid=190};update()
assert(#writes==1 and acks[2].result==3)
command={msgid=76,command=31000,sysid=255,compid=190};update()
assert(#writes==1 and acks[3].result==3)
print("PASS actual H743 Lua bridge: fragments, checksum, fields, overflow, recovery, command validation")
