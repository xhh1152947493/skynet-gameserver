local skynet = require "skynet.manager"
local runconfig = require "runconfig"
local cluster = require "skynet.cluster"
local log = require "log"

local function _bootstrap(srv, name, id)
    log.debug(string.format("_bootstrap start. srv:%s name:%s id:%s", srv, name, id))
    local addr = skynet.newservice(srv, name, id)
    if addr == nil then
        log.error(string.format("_bootstrap fail. srv:%s name:%s id:%s", srv, name, id))
        skynet.abort()
    end
end

skynet.start(
    -- 顺序启动服务，任何一个服务启动失败则退出进程
    function()
        _bootstrap("logger", "logger", nil) -- 启动logger服务

        local selfnode = skynet.getenv("node")
        log.info("[--------start bootstrap main--------] node: ", selfnode)

        cluster.reload(runconfig.cluster) -- 重新加载集群配置
        cluster.open(selfnode) -- 打开当前节点

        if selfnode == runconfig.unique.login_mgr.node then
            local addr = skynet.uniqueservice("login_mgr", "login_mgr", nil)
            if addr == nil then
                log.error("_bootstrap login_mgr fail. srv:%s name:%s id:%s")
                skynet.abort()
            end
            cluster.register("login_mgr", addr) -- 注册login_mgr服务，不用.前缀，其他节点可以通过这个别名直接通信
        end

        _bootstrap("debug_console", runconfig.debug_console[selfnode].port) -- 启动debug_console服务

        local cfgnode = runconfig[selfnode]
        for _, info in ipairs(cfgnode) do -- 顺序启动
            for id, _ in ipairs(info.list) do
                _bootstrap(info.name, info.name, id) -- 本节点服务，服务内部自己注册别名
            end
        end

        _bootstrap("signal_handler", "signal_handler", nil) -- 启动信号处理服务

        log.info("[--------end bootstrap main--------] node: ", selfnode)
        skynet.exit() -- 退出当前服务
    end
)
