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
local last_frame_ms = 0
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
    local f={}
    for v in payload:gmatch("[^,]+") do f[#f+1]=v end
    if #f ~= 13 or f[1] ~= "NAVO" or f[2] ~= "1" then return false end
    for i=3,13 do if tonumber(f[i]) == nil then return false end end
    publish(f); last_frame_ms=millis():toint(); return true
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
    local target=math.floor(p.param1+0.5)==1 and "HEAD" or (math.floor(p.param1+0.5)==2 and "POS" or nil)
    local mode=math.floor(p.param2+0.5)
    local op=mode==0 and "OFF" or (mode==1 and "ON" or (mode==2 and "TOGGLE" or nil))
    local result=3 -- MAV_RESULT_UNSUPPORTED
    if target and op then send_nano_command(target,op); result=0 end
    local ack={command=p.command,result=result,progress=0,result_param2=0,target_system=p.sysid,target_component=p.compid}
    mavlink:send_chan(chan,mavlink_msgs.encode("COMMAND_ACK",ack))
end

local function update()
    handle_gcs_commands()
    local n=uart:available()
    while n>0 do
        local b=uart:read()
        if b < 0 then break end
        if b==10 then
            if #line>0 then parse(line); line="" end
        elseif b~=13 then
            if #line<180 then line=line..string.char(b) else line="" end
        end
        n=n-1
    end
    return update,20
end
return update()
