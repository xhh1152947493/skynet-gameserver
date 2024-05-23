local skynet = require "skynet"
local cluster = require "skynet.cluster"
local log = require "log"
local net = require "net"
local pbtool = require "pbtool"

-- 每个服务单独保有一份
local service = {
    name = "",
    id = 0,
    exitfunc = nil,
    initfunc = nil,
    resp = {},
    client = {}
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
    if service.initfunc then
        service.initfunc()
    end
end

-- req请求统一在此处返回resp给client
function service.resp.client(srcaddr, fd, cmd, bs)
    local func = service.client[cmd]
    if not func then
        log.error(string.format("client req msg not found. cmd:%d ID:%s name:%s", cmd, service.id, service.name))
        return
    end
    local resp = func(fd, bs, srcaddr)
    if resp == nil then
        return
    end
    skynet.send(srcaddr, "lua", "send_by_fd", fd, resp)
end

-- 统一注册client消息处理回调的接口
function service.register_clientmsg_handle(msg, func)
    service.client = service.client or {} -- s.client每个服务都有自己一份
    assert(service.client[msg.ID] == nil, string.format("register clientmsg handle fail, msg repeat:%s", msg.ID))

    local wrap = function(fd, bs, srcaddr)
        local req = pbtool.decode(msg.Msg, bs)
        local ret = func(fd, srcaddr, req)
        if ret == nil then
            return nil
        end
        local resp, info = ret[0], ret[1]
        if info ~= nil then -- 返回统一错误信息
            return net.pack_msg(MESSAGE_TYPE.GS2C_COMMON_ERR, info)
        end
        return resp
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

function service.start(name, id, ...)
    service.name = name
    if id == nil then
        service.id = 1
    end
    service.id = tonumber(id)
    skynet.start(initfunc)
end

return service
