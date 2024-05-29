local skynet = require "skynet.manager"
local runconfig = require "runconfig"
local cluster = require "skynet.cluster"
local log = require "log"
local signal = require "posix.signal"

local function handle_signal(signo)
    log.info(string.format("handle_signal, recv sigin. sigin:%s", signo))
    skynet.exit()
end

local function catch_signal()
    log.info(string.format("catch_signal register"))

    signal.signal(signal.SIGTERM, handle_signal)
    signal.signal(signal.SIGINT, handle_signal)
end

skynet.start(
    -- 顺序启动服务，任何一个服务启动失败则退出进程
    function()
        skynet.newservice("logger", "logger") -- 启动logger服务

        local selfnode = skynet.getenv("node")
        log.info("[--------start bootstrap main--------] node: ", selfnode)

        cluster.reload(runconfig.cluster) -- 重新加载集群配置
        cluster.open(selfnode) -- 打开当前节点

        if selfnode == runconfig.unique.login_mgr.node then
            local addr = skynet.uniqueservice("login_mgr", "login_mgr")
            cluster.register("login_mgr", addr) -- 注册login_mgr服务，不用.前缀，其他节点可以通过这个别名直接通信
        end

        skynet.newservice("debug_console", runconfig.debug_console[selfnode].port) -- 启动debug_console服务

        -- skynet.newservice("signal_handler", "signal_handler") -- 启动信号处理服务

        local cfgnode = runconfig[selfnode]
        for _, info in ipairs(cfgnode) do -- 顺序启动
            for id, _ in ipairs(info.list) do
                skynet.newservice(info.name, info.name, id) -- 本节点服务，服务内部自己注册别名
            end
        end

        catch_signal()

        log.info("[--------end bootstrap main--------] node: ", selfnode)
    end
)
