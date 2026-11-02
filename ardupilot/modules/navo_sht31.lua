-- SHT31-DIS single-shot, high repeatability, clock stretching disabled.
-- Sensirion SHT3x-DIS datasheet: 0x2400, 6 bytes, CRC-8 poly 0x31/init 0xff.
local M={}
local function crc(a,b)
    local value=0xff
    for _,byte in ipairs({a,b}) do
        value=value ~ byte
        for _=1,8 do
            value=((value << 1) ~ ((value & 0x80)~=0 and 0x31 or 0)) & 0xff
        end
    end
    return value
end
function M.decode(data)
    if type(data)~="string" or #data~=6 then return nil end
    local a,b,c,d,e,f=string.byte(data,1,6)
    if crc(a,b)~=c or crc(d,e)~=f then return nil end
    return -45+175*(a*256+b)/65535,100*(d*256+e)/65535
end
function M.new(device)
    local self={status=1,temperature=nil,humidity=nil,measured_at=nil,next_at=0,pending=false}
    function self:tick(now)
        if now<self.next_at then return end
        if self.pending then
            self.pending=false;self.next_at=now+5000
            local ok,data=pcall(function()return device:transfer("",6)end)
            local t,h
            if ok then t,h=M.decode(data) end
            if t then self.temperature=t;self.humidity=h;self.measured_at=now;self.status=2
            else self.status=3;self.temperature=nil;self.humidity=nil end
        else
            local ok,result=pcall(function()return device:transfer(string.char(0x24,0x00),0)end)
            if ok and type(result)=="string" then self.pending=true;self.next_at=now+20
            else self.status=3;self.temperature=nil;self.humidity=nil;self.next_at=now+5000 end
        end
    end
    return self
end
return M
