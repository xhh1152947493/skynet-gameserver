local skynet = require "skynet.manager"
local cluster = require "skynet.cluster"
local log = require "log"
local net = require "net"
local pbtool = require "pbtool"

-- 每个服务单独保有一份
local service = {
    name = "",
    name_register = "",
    id = nil,
    exitfunc = nil,
    initfunc = nil,
    resp = {},
    client = {},
    bootstraped = false -- 该服务是否已经启动完成
}

function Traceback(err)
    log.error(tostring(err))
    log.error(debug.traceback())
end

-- 服务器的各service之间通信
local function dispatch(session, srcaddr, cmd, ...)
    local fun = service.resp[cmd]
    if not fun then
        skynet.ret()
        return
    end

    local ret = table.pack(xpcall(fun, Traceback, srcaddr, ...))
    local isok = ret[1]

    if not isok then -- xpcall有报错,程序不中断,返回空值给请求方
        skynet.ret()
        return
    end

    skynet.retpack(table.unpack(ret, 2)) -- 真实的返回值从ret[2]开始
end

local function initfunc()
    skynet.dispatch("lua", dispatch)

    service.register_name()

    if service.initfunc then
        service.initfunc()
    end

    service.bootstraped = true

    log.info(
        string.format(
            "[------start server end------] node:%s, name:%s id:%s, register_name:%s, addr:%s",
            skynet.getenv("node"),
            service.name,
            service.id,
            service.name_register,
            skynet.self()
        )
    )
end

-- req请求统一在此处返回resp给client
function service.resp.client(srcaddr, fd, cmd, bs)
    local func = service.client[cmd]
    if not func then
        log.error(string.format("client req msg not found. cmd:%d ID:%s name:%s", cmd, service.id, service.name))
        return
    end
    local resp = func(fd, srcaddr, bs)
    if resp == nil then
        return
    end
    skynet.send(srcaddr, "lua", "send_by_fd", fd, resp)
end

-- 统一注册client消息处理回调的接口
function service.register_clientmsg_handle(msg, func)
    service.client = service.client or {} -- s.client每个服务都有自己一份
    assert(service.client[msg.ID] == nil, string.format("register clientmsg handle fail, msg repeat:%s", msg.ID))

    local wrap = function(fd, srcaddr, bs)
        local req = pbtool.decode(msg.Msg, bs)
        local ret = func(fd, srcaddr, req)
        if ret == nil then
            return nil
        end
        local resp, err_info = ret[0], ret[1]
        if err_info ~= nil then -- 返回统一错误信息
            return net.pack_msg(MESSAGE_TYPE.GS2C_COMMON_ERR, err_info)
        end
        return resp -- 请求和返回不是同一条协议，不能统一打包
    end

    service.client[msg.ID] = wrap
    log.info(string.format("register clientmsg handle success. cmd:%d ID:%s name:%s", msg.ID, service.id, service.name))
end

function service.call(node, dstaddr, ...)
    local mynode = skynet.getenv("node")
    if node == mynode then
        return skynet.call(dstaddr, "lua", ...)
    else
        return cluster.call(node, dstaddr, ...)
    end
end

function service.send(node, dstaddr, ...)
    local mynode = skynet.getenv("node")
    if node == mynode then
        return skynet.send(dstaddr, "lua", ...)
    else
        return cluster.send(node, dstaddr, ...)
    end
end

-- 给当前服务在本节点内起一个别名
function service.register_name()
    local name = ""
    if service.id ~= nil then
        name = string.format(".%s%d", service.name, tonumber(service.id))
    else
        name = string.format(".%s", service.name)
    end
    service.name_register = name
    skynet.register(service.name_register)
    log.info(string.format("server register name success. addr:%s register_name:%s", skynet.self(), service.name_register))
end

function service.resp.is_bootstraped(srcaddr)
    return service.bootstraped
end

-- 大坑，都是字符串形式传进来的
function service.start(name, id, ...)
    service.name = name
    if id ~= nil then
        service.id = tonumber(id)
    end
    skynet.start(initfunc)
end

return service
