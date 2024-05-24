local time = {
    s = 0,
    ms = 0,
    delta = 0
}

local time_mgr = {}

function time_mgr.update(s, ms, delta)
    time = time or {}
    time.s = s
    time.ms = s
    time.delta = delta
end

function time_mgr.second()
    if time ~= nil then
        return time.s + time.delta
    end
    return 0
end

function time_mgr.second_ms()
    if time ~= nil then
        return time.ms + time.delta * 1000
    end
    return 0
end

return time_mgr
