local skynet = require "skynet.manager"
local s = require "service"
local runconfig = require "runconfig"
local socket = require "skynet.socket"
local log = require "log"

local _tips = "Please enter cmd.\r\nStop:stop all server and abort this skynet node\r\n"

local _Command = {}

local function read_with_timeout(fd, timeout)
    local result
    local co = coroutine.running()

    -- 创建一个定时器
    skynet.timeout(
        timeout,
        function()
            skynet.wakeup(co)
        end
    )

    -- 异步读取数据
    skynet.fork(
        function()
            result = socket.readline(fd, "\r\n")
            skynet.wakeup(co)
        end
    )

    -- 挂起当前协程，等待读取完成或超时
    skynet.wait(co)

    return result
end

local function connect(fd, addr)
    socket.start(fd)
    socket.write(fd, _tips)

    while true do
        local cmd = read_with_timeout(fd, 6000) -- 设置超时时间为60秒（6000 * 0.01秒）
        if not cmd then
            socket.write(fd, "Timeout or connection closed.\r\n")
            return
        end

        local cb = _Command[cmd]
        if cb == nil then
            socket.write(fd, string.format("This cmd:%s not found\r\n", cmd))
        else
            cb(fd)
        end
    end
end

function _Command.Close(fd)
    socket.write(fd, "connection closed by cmd close.\r\n")
    socket.close(fd)
end

function _Command.Stop(fd)
end

s.initfunc = function()
    local selfnode = skynet.getenv("node")

    local port = runconfig.debug_console[selfnode].port
    assert(port ~= nil and port ~= 0, "fail to find admin port: " .. port)

    local listen_id = socket.listen("127.0.0.1", port) -- 只监听本地端口
    assert(listen_id, "failed to listen admin on port: " .. port)

    log.info("admin listen on port: " .. port)

    socket.start(listen_id, connect)
end

s.start(...)
