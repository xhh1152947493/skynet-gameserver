local skynet = require "skynet"
local runconfig = require "runconfig"
local cluster = require "skynet.cluster"
local log = require "log"

skynet.start(
    function()
        skynet.newservice("logger") -- 启动logger服务

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
        for sname, info in pairs(cfgnode) do
            for index, _ in ipairs(info) do
                skynet.newservice(sname, sname, index) -- 本节点服务，服务内部自己注册别名
            end
        end

        log.info("[--------end bootstrap main--------] node: ", selfnode)
        skynet.exit() -- 退出当前服务
    end
)
