-- NAVO SMART read-only G20 relay status. This script never writes GPIO,
-- toggles relays, or takes ownership from RC7/L2 and RC16/R2.
-- OPTIONAL: install only after confirming relay:get support on H743 firmware.
-- relay instance 0 = headlight (Relay1), 1 = position lights (Relay2).
-- NAMED_VALUE_FLOAT names are <= 10 characters (NV3RHEAD, NV3RPOS).
local function read_state(instance)
    if not relay then return nil end
    local enabled_ok,enabled=pcall(function() return relay:enabled(instance) end)
    if not enabled_ok or enabled ~= true then return nil end
    local state_ok,state=pcall(function() return relay:get(instance) end)
    if not state_ok or (state ~= 0 and state ~= 1) then return nil end
    return state
end

local function update()
    local head=read_state(0)
    local positions=read_state(1)
    -- An unavailable relay must never be advertised as OFF.
    if head ~= nil then gcs:send_named_float("NV3RHEAD",head) end
    if positions ~= nil then gcs:send_named_float("NV3RPOS",positions) end
    return update,500
end

return update()
