local skynet = require "skynet"
local runconfig = require "runconfig"
local cluster = require "skynet.cluster"
local log = require "log"

-- local bootstrap_wait = 30
local bootstrap_wait = 10

-- 同步启动，保证启动完成才往下执行.避免还没启动完成消息已经来了
local function sync_bootstrap(srv, name, id)
    log.debug(string.format("sync_bootstrap start. srv:%s name:%s id:%s", srv, name, id))

    local loopcnt = 0
    local addr = skynet.newservice(srv, name, id)
    while true do
        local bootstraped = skynet.call(addr, "lua", "is_bootstraped")
        log.info(string.format("sync_bootstrap start. srv:%s name:%s id:%s bootstraped:%s", srv, name, id, bootstraped))
        if bootstraped then
            log.info(string.format("sync_bootstrap success. srv:%s name:%s id:%s", srv, name, id))
            return true
        end
        loopcnt = loopcnt + 1
        if loopcnt >= bootstrap_wait then -- 60秒还没启动完成
            assert(nil, string.format("sync_bootstrap fail. srv:%s name:%s id:%s", srv, name, id))
            return false
        end
        skynet.sleep(SKYNET_SECOND)
    end
end

skynet.start(
    function()
        sync_bootstrap("logger", "logger", nil) -- 启动logger服务

        local selfnode = skynet.getenv("node")
        log.info("[--------start bootstrap main--------] node: ", selfnode)

        cluster.reload(runconfig.cluster) -- 重新加载集群配置
        cluster.open(selfnode) -- 打开当前节点

        if selfnode == runconfig.unique.login_mgr.node then
            local addr = skynet.uniqueservice("login_mgr", "login_mgr", runconfig.unique.login_mgr.id)
            cluster.register("login_mgr", addr) -- 注册login_mgr服务，不用.前缀，其他节点可以通过这个别名直接通信
        end

        skynet.newservice("debug_console", runconfig.debug_console[selfnode].port) -- 启动debug_console服务

        local cfgnode = runconfig[selfnode]
        for _, info in ipairs(cfgnode) do -- 顺序启动
            for id, _ in ipairs(info.list) do
                sync_bootstrap(info.name, info.name, id) -- 本节点服务，服务内部自己注册别名
            end
        end

        sync_bootstrap("signal_handler", "signal_handler", nil) -- 启动信号捕捉服务

        log.info("[--------end bootstrap main--------] node: ", selfnode)
        skynet.exit() -- 退出当前服务
    end
)
