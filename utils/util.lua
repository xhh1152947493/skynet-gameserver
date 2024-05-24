local skynet = require "skynet"
require "common_def"

local util = {}

function util.dump_table(tbl, indent)
    if not indent then
        indent = 0
    end
    local padding = string.rep("  ", indent)
    local output = padding .. "{\n"

    for key, value in pairs(tbl) do
        key = type(key) == "number" and "[" .. key .. "]" or '["' .. key .. '"]'
        local valueType = type(value)

        if valueType == "table" then
            output = output .. padding .. key .. " = " .. util.dump_table(value, indent + 1) .. ",\n"
        elseif valueType == "function" then
            output = output .. padding .. key .. " = " .. tostring(value) .. ",\n"
        else
            output = output .. padding .. key .. " = " .. tostring(value) .. ",\n"
        end
    end

    output = output .. padding .. "}"
    return output
end

function util.second()
    return math.floor(skynet.time())
end

function util.second_ms()
    return math.floor(skynet.time() * _G.SECOND_MS)
end

function util.deepcopy(original)
    if type(original) ~= "table" then
        return original
    end
    local copy = {}
    for key, value in pairs(original) do
        copy[key] = util.deepcopy(value)
    end
    return copy
end

function util.timepoller()
    local poller = {time = util.second()}

    function poller:poll(now, period)
        local delta = now - self.time
        if delta < 0 then
            delta = period
        end
        if delta < period then
            return 0
        end
        self.time = now
        return math.floor(delta / period)
    end

    return poller
end

function util.count_table(tbl)
    if type(tbl) ~= "table" then
        return 0
    end
    local rlt = 0
    for _ in pairs(tbl) do
        rlt = rlt + 1
    end
    return rlt
end

return util
