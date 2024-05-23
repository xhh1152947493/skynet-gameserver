-- 单服务事件系统[没必要做跨服务的,太复杂反而不好维护]
local log = require "log"

local event = {}
local event_pool = {}

function event.register_event(id, name, func)
    assert(func ~= nil, string.format("register event fail, func nil. id:%d name:%s", id, name))

    if event_pool[id] == nil then
        event_pool[id] = {}
    end

    assert(event_pool[id][name] == nil, string.format("register event fail, repeat. id:%d name:%s", id, name))

    event_pool[id][name] = func
    log.info(string.format("register event success. id:%d name:%s", id, name))
end

function event.unregister_event(id, name)
    if event_pool[id] == nil then
        return
    end

    event_pool[id][name] = nil
    log.info(string.format("unregister event success. id:%d name:%s", id, name))
end

function event.publish_event(id, ...)
    if event_pool[id] == nil then
        return
    end

    for _, func in pairs(event_pool[id]) do
        if func ~= nil then
            func(...)
        end
    end
end

return event
