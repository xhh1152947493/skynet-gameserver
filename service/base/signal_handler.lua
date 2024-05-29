local s = require "service"
local signal = require "posix.signal"
local log = require "log"
local skynet = require("skynet")
local runconfig = require "runconfig"

local function call_exit_srv(srv_name)
    log.info(string.format("handle_signal, call server exit begin. server:%s", srv_name))
    skynet.call(srv_name, "lua", "srv_exit") -- 阻塞等待清理完
    log.info(string.format("handle_signal, call server exit end. server:%s", srv_name))
end

local function range_srv(tbl_info, name)
    for _, info in pairs(tbl_info) do
        if info.name == name then
            for id, _ in ipairs(info.list) do
                local srv_name = string.format(".%s%d", info.name, id)
                call_exit_srv(srv_name)
            end
        end
    end
end

-- 处理本节点的进程退出[main节点必须最后关闭，因为唯一服部署在main节点]
local function handle_signal(signo)
    log.info(string.format("handle_signal, recv sigin. sigin:%s", signo))

    -- kill -SIGTERM 1234
    -- ctrl + c
    if signo == signal.SIGTERM or signo == signal.SIGINT then -- 通知其他服务进行退出前的清理操作
        local node = skynet.getenv("node")
        local tbl_info = runconfig[node]

        -- 1、首先通知gate，断开与客户端的连接
        range_srv(tbl_info, "gateway")
        -- 2、退出登录服
        range_srv(tbl_info, "login")
        -- 3、退出游戏服
        range_srv(tbl_info, "srv_game")

        -- 4、退出唯一服,db最后关闭
        if node == "main" then
            call_exit_srv("login_mgr")
            call_exit_srv("db_mysql")
            call_exit_srv("db_redis")
        end

        -- 5、最后退出log服务
        call_exit_srv(".logger")

        skynet.abort()
    end
end

s.initfunc = function()
    -- 注册信号处理器
    log.info("Registering signal handlers.", signal, signal.SIGTERM, signal.SIGINT)
    signal.signal(signal.SIGTERM, handle_signal)
    signal.signal(signal.SIGINT, handle_signal)
end

s.start(...)
