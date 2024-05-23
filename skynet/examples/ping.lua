local skynet = require "skynet"
local cluster = require "skynet.cluster"
local mynode = skynet.getenv("node")

require "skynet.manager"

local CMD = {}

function CMD.start(source, target_node, target)
    cluster.send(target_node, target, "ping", mynode, skynet.self(), 1)
end

function CMD.ping(source, source_node, source_srv, count)
    local id = skynet.self()
    skynet.error("[" .. id .. "] recv ping count=" .. count)
    skynet.sleep(100)
    cluster.send(source_node, source_srv, "ping", mynode, skynet.self(), count + 1)
end

skynet.start(
    function()
        skynet.dispatch(
            "lua",
            function(session, source, cmd, ...) --skynet.dispatch指定参数一类型消息的处理方式（这里是“lua”类型，Lua服务间的消息类型是“lua”），即处理lua服务之间的消息
                local f = assert(CMD[cmd])
                f(source, ...)
            end
        )
    end
)
