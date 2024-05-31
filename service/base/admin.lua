local skynet = require "skynet.manager"
local s = require "service"
local runconfig = require "runconfig"
local socket = require "skynet.socket"
local log = require "log"

local _tp_cmd = {
    "Help: Get all cmd help info.\n",
    "Stop: Stop all server and abort this skynet node.\n"
}
local function _init_tips()
    local tips = "\nPlease enter cmd.\n"
    for _, info in ipairs(_tp_cmd) do
        tips = tips .. info
    end
    tips = tips .. "\n"
    return tips
end
local _tips = _init_tips()

local _command = {}

local function read_with_timeout(fd, timeout)
    local result
    local co = coroutine.running()

    local cancel = false

    -- 创建一个定时器
    skynet.timeout(
        timeout,
        function()
            if not cancel then
                skynet.wakeup(co)
                log.info("admin timeout on fd: " .. fd)
            end
        end
    )

    -- 异步读取数据
    skynet.fork(
        function()
            result = socket.readline(fd, "\r\n") -- 客户端quit telnet 时, result为false
            cancel = true
            skynet.wakeup(co)
            log.info(string.format("admin readline on fd:%s msg:%s", fd, result))
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
            socket.write(fd, "connection closed by timeout or client quit.\r\n") -- 超时或客户端主动关闭连接
            socket.close(fd)
            log.info(string.format("admin close connet by timeout on fd:%s", fd))
            return
        end

        local cb = _command[cmd]
        if cb == nil then
            socket.write(fd, string.format("This cmd:%s not found\r\n", cmd))
        else
            log.info(string.format("admin start execute cmd:%s on fd:%s", cmd, fd))
            cb(fd)
            log.info(string.format("admin over execute cmd:%s on fd:%s", cmd, fd))
        end
    end
end

function _command.Help(fd)
    socket.write(fd, _tips)
end

function _command.Stop(fd)
    local selfnode = skynet.getenv("node")

    local function call_srv_exit(node, srv_name)
        -- 等待目标服务退出并返回
        s.call(node, srv_name, "lua", "srv_exit")
    end

    local function range_srv_all_node(name, fn)
        if not fn then
            return
        end

        for node, _ in pairs(runconfig.cluster) do
            for _, info in pairs(runconfig[node]) do
                if info.name == name then
                    for id, _ in ipairs(info.list) do
                        fn(node, s.format_register_name(id, info.name))
                    end
                end
            end
        end
    end

    local node_srv_list = {
        "gateway",
        "login",
        "srv_game"
    }

    for _, name in ipairs(node_srv_list) do
        range_srv_all_node(
            name,
            function(node, srv_name)
                call_srv_exit(node, srv_name)
            end
        )
    end

    if selfnode == "main" then
        call_srv_exit(".login_mgr")
    end

    log.info("admin stop all server success!")

    call_srv_exit("._logger")

    skynet.abort()
end

s.initfunc = function()
    local selfnode = skynet.getenv("node")

    local port = runconfig.admin[selfnode].port
    assert(port ~= nil and port ~= 0, "fail to find admin port: " .. port)

    local listen_id = socket.listen("127.0.0.1", port) -- 只监听本地端口
    assert(listen_id, "failed to listen admin on port: " .. port)

    log.info("admin listen on port: " .. port)

    socket.start(listen_id, connect)
end

s.start(...)
