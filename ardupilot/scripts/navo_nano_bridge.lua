-- NAVO SMART Nano -> H743 -> MAVLink bridge
-- H743 UART connected to Nano must be SERIALx_PROTOCOL=28 (Scripting), SERIALx_BAUD=57.
-- First scripting serial port is instance 0.
local uart = serial:find_serial(0)
if not uart then
    gcs:send_text(3, "NAVO: UART scripting port missing")
    return
end
uart:begin(57600)
uart:set_flow_control(0)

local line = ""
local dropping_line = false
local mavlink_msgs = require("MAVLink/mavlink_msgs")
local COMMAND_LONG_ID = mavlink_msgs.get_msgid("COMMAND_LONG")
local msg_map = {}; msg_map[COMMAND_LONG_ID] = "COMMAND_LONG"
local MAV_CMD_WAYPOINT_USER_1 = 31000
mavlink:init(10, 1)
mavlink:register_rx_msgid(COMMAND_LONG_ID)
mavlink:block_command(MAV_CMD_WAYPOINT_USER_1)

local function xor_checksum(payload)
    local cs = 0
    for i=1,#payload do cs = cs ~ string.byte(payload,i) end
    return cs
end

local function publish(f)
    -- Standard MAVLink NAMED_VALUE_FLOAT messages. Names <= 10 chars.
    gcs:send_named_float("NVBATV", tonumber(f[4]) / 1000.0)
    local tc10=tonumber(f[5])
    -- Publish invalidity too: otherwise the app keeps the last good temperature.
    gcs:send_named_float("NVBATTEMP", tc10 == -32768 and -32768 or tc10 / 10.0)
    gcs:send_named_float("NVWATER", tonumber(f[6]))
    gcs:send_named_float("NVWFAULT", tonumber(f[7]))
    gcs:send_named_float("NVHEAD", tonumber(f[8]))
    gcs:send_named_float("NVPOS", tonumber(f[9]))
    gcs:send_named_float("NVHOPL", tonumber(f[10]))
    gcs:send_named_float("NVHOPR", tonumber(f[11]))
    gcs:send_named_float("NVRUD", tonumber(f[12]))
    gcs:send_named_float("NVALARM", tonumber(f[13]))
end

local function parse(s)
    local payload,hex=s:match("^%$(.-)%*([0-9A-Fa-f][0-9A-Fa-f])$")
    if not payload or xor_checksum(payload) ~= tonumber(hex,16) then return false end
    if payload:find(",,",1,true) or payload:sub(-1)=="," then return false end
    local f={}
    for v in payload:gmatch("[^,]+") do f[#f+1]=v end
    if #f ~= 13 or f[1] ~= "NAVO" or f[2] ~= "1" then return false end
    local function integer(value,minimum,maximum)
        return value and value==value and value>=minimum and value<=maximum and value%1==0
    end
    local v={}
    for i=3,13 do v[i]=tonumber(f[i]); if not v[i] or v[i]~=v[i] then return false end end
    if not integer(v[3],0,4294967295) or not integer(v[4],0,60000) then return false end
    if v[5]~=-32768 and not integer(v[5],-500,1500) then return false end
    for i=6,9 do if not integer(v[i],0,1) then return false end end
    for i=10,12 do if v[i]~=0 and not integer(v[i],900,2100) then return false end end
    if not integer(v[13],0,15) then return false end
    publish(f); return true
end

local function send_nano_command(target, op)
    local payload="NAVOCMD,1,"..target..","..op
    uart:writestring("$"..payload.."*"..string.format("%02X",xor_checksum(payload)).."\r\n")
end

local function handle_gcs_commands()
    local msg, chan=mavlink:receive_chan()
    if not msg then return end
    local p=mavlink_msgs.decode(msg,msg_map)
    if not p or p.msgid~=COMMAND_LONG_ID or p.command~=MAV_CMD_WAYPOINT_USER_1 then return end
    local target=p.param1==1 and "HEAD" or (p.param1==2 and "POS" or nil)
    local mode=p.param2
    local op=mode==0 and "OFF" or (mode==1 and "ON" or (mode==2 and "TOGGLE" or nil))
    local result=3 -- MAV_RESULT_UNSUPPORTED
    if target and op then send_nano_command(target,op); result=0 end
    local ack={command=p.command,result=result,progress=0,result_param2=0,target_system=p.sysid,target_component=p.compid}
    mavlink:send_chan(chan,mavlink_msgs.encode("COMMAND_ACK",ack))
end

local function update()
    handle_gcs_commands()
    local n=math.min(uart:available(),256)
    while n>0 do
        local b=uart:read()
        if b < 0 then break end
        if b==10 then
            if not dropping_line and #line>0 then parse(line) end
            line=""; dropping_line=false
        elseif b~=13 and not dropping_line then
            if #line<180 then line=line..string.char(b) else line=""; dropping_line=true end
        end
        n=n-1
    end
    return update,20
end
return update()
