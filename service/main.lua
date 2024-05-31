local skynet = require "skynet.manager"
local runconfig = require "runconfig"
local cluster = require "skynet.cluster"
local log = require "log"

skynet.start(
    function()
        skynet.newservice("_logger", "_logger") -- 启动logger服务，_前缀是为了避免与skynet系统的logger服务冲突

        local selfnode = skynet.getenv("node")
        log.info("[--------start bootstrap main--------] node: " .. selfnode)

        cluster.reload(runconfig.cluster) -- 重新加载集群配置
        cluster.open(selfnode) -- 打开当前节点

        skynet.newservice("debug_console", runconfig.debug_console[selfnode].port) -- 启动debug_console服务

        local cfgnode = runconfig[selfnode]
        for _, info in ipairs(cfgnode) do -- 顺序启动
            for id, _ in ipairs(info.list) do
                skynet.newservice(info.name, info.name, id) -- 本节点服务，服务内部自己注册别名
            end
        end

        if selfnode == runconfig.unique.admin.node then
            cluster.register("login_mgr", skynet.uniqueservice("login_mgr", "login_mgr")) -- 注册login_mgr服务，不用.前缀，其他节点可以通过这个别名直接通信
            cluster.register("admin", skynet.uniqueservice("admin", "admin")) -- 管理服
        end

        log.info("[--------end bootstrap main--------] node: " .. selfnode)
        skynet.exit()
    end
)
