local skynet = require "skynet"
local socket = require "skynet.socket"
local websocket = require "http.websocket"
local runconfig = require "runconfig"
local s = require "service"
local net = require "net"
local log = require "log"
local util = require "util"

-- 存储客户端的最后一次收到心跳消息的时间戳[在服务中使用消息队列访问，避免并发问题]
local last_ping_timestamp = {}

-- 存储客户端连接信息
local client_conns = {}

-- 存储玩家的目标game服和连接信息
local gate_players = {}

-- 单网关最大连接数
local MAX_CONNECT_COUNT = 500

local CLOSE_CODE = {
    HEART_BEAT_DISCONNECT = 1, -- 心跳断连
    FINAL_KICK = 2, -- 断线或顶替登录的踢出玩家最后一步
    SERVER_EXIT = 3 -- 服务退出
}

local function new_gateplayer()
    local m = {
        playerid = nil,
        srv_game_addr = nil, -- 玩家所在游戏服地址
        conn = nil
    }
    return m
end

local function new_clientconn()
    local m = {
        fd = nil, -- 连接句柄,通过这个发送消息给client
        playerid = nil,
        addr = nil
    }
    return m
end

local function choice_srv_login()
    local node = skynet.getenv("node")
    local cfgnode = runconfig[node]
    local login = ".login" .. cfgnode.login[math.random(1, #cfgnode.login)].id -- 随机分配一个login服
    return login
end

local function dispatch(fd, msgid, bs)
    local conn = client_conns[fd]
    if conn == nil then
        log.error(string.format("websocket dispatch fail, conn is nil: %s", fd))
        return
    end

    local pid = conn.playerid
    if pid == nil then -- 未登录,转发到本节点内的login服
        local login = choice_srv_login()
        skynet.send(login, "client", fd, msgid, bs)
    else -- 已登录,转发到本节点指定的srv_game
        local gplayer = gate_players[pid]
        if gplayer == nil then
            log.error(string.format("websocket dispatch fail, gate player is nil. playerid: %s", pid))
            return
        end
        skynet.send(gplayer.srv_game_addr, "lua", "client", fd, msgid, bs)
    end
    log.debug(string.format("gate dispatch end. pid:%s msgid:%d", pid, msgid))
end

local function disconnect(fd, code)
    -- 客户端主动断线[一般不会主动断连，客户端下线发登出消息即可。服务器会因为心跳断连]，通知login_mgr和游戏服登出即可。gate的连接已经断了
    -- 服务器因为心跳断连，login_mgr通知游戏服和gate登出。
    -- 小游戏需要考虑断线重连吗？场景恢复等[暂不考虑] todo zhangzhihui

    local conn = client_conns[fd]
    if not conn then
        return
    end
    local playerid = conn.playerid
    if not playerid then -- 还没登录完成
        return
    else -- 已在游戏中，踢玩家下线
        gate_players[playerid] = nil
        -- 踢出的最后一步&服务退出，无需通知玩家下线
        if code ~= CLOSE_CODE.FINAL_KICK and code ~= CLOSE_CODE.SERVER_EXIT then
            s.call(runconfig.unique.login_mgr.node, "login_mgr", "reqkick", playerid, "websocket disconnect")
        end
        log.info(string.format("gate disconnect end. pid:%d code:%d", playerid, code))
    end
end

local function check_heartbeat()
    -- 2秒检查一次心跳，超过5秒断连
    while true do
        skynet.sleep(2 * _G.SKYNET_SECOND)

        skynet.send(skynet.self(), "lua", "check_ping_timestamp")
    end
end

local handle = {}

function handle.connect(fd)
    local conn = new_clientconn()
    conn.fd = fd
    conn.addr = websocket.addrinfo(fd)
    client_conns[fd] = conn

    -- 超过最大连接数 todo zhangzhihui
    -- if util.count_table(client_conns) > MAX_CONNECT_COUNT then
    --     log.error(string.format("websocket connected max: %s addr: %s", fd, conn.addr))
    --     return
    -- end

    log.info(string.format("websocket connected: %s addr: %s", fd, conn.addr))
end

function handle.handshake(fd, header, url)
    local addr = websocket.addrinfo(fd)
    log.debug(string.format("websocket handshake from: %s url: %s addr: %s", fd, url, addr))
end

function handle.message(fd, payload_data, op)
    log.debug(string.format("websocket message from: %s %s %s", fd, payload_data, op))
    if op ~= "binary" and op ~= "text" then
        return
    end

    if payload_data == "ping" then
        skynet.send(skynet.self(), "lua", "set_ping_timestamp", fd, util.second())

        websocket.write(fd, "pong", "pong")
        return
    end

    -- 解包之后按消息id转发
    local msgid, bs = net.unpack(payload_data)
    dispatch(fd, msgid, bs)
end

-- 确认一下调用websocket.close是否会调用handle.close todo zhangzhihui
function handle.close(fd, code, reason)
    log.info(string.format("WebSocket closed:%s, code:%s, reason:%s", tostring(fd), code, reason))

    -- websocket 连接断时先踢出玩家
    disconnect(fd, code)

    -- 处理断线重连 todo zhangzhihui
    -- 玩家退出流程 todo

    -- 在连接关闭时，移除连接信息
    client_conns[fd] = nil
    skynet.send(skynet.self(), "lua", "set_ping_timestamp", fd, nil)
end

function handle.error(fd)
    log.error(string.format("websocket error: %s", fd))
end

-- login_mgr已经判断能登录了，但是这里又出错，则通知login_mgr踢出玩家
function s.resp.confirm_srv_game(srcaddr, fd, playerid, srv_game_addr)
    local conn = client_conns[fd]
    if not conn then
        local reason = "login not done, but gate logout"
        s.call(runconfig.unique.gsmgr.node, "login_mgr", "reqkick", playerid, reason)
        return reason
    end

    -- 提前绑定gate_players,以便srv_game登录完成时能发消息给客户端
    local gplayer = new_gateplayer()
    gplayer.playerid = playerid
    gplayer.srv_game_addr = srv_game_addr -- 绑定玩家所在的游戏服
    gplayer.conn = conn
    gate_players[playerid] = gplayer

    local err = skynet.call(srv_game_addr, "lua", "login", playerid) -- 完成游戏服的登录流程
    if err then
        local reason = "srv_game handle player login fail, err: " .. err
        s.call(runconfig.unique.gsmgr.node, "login_mgr", "reqkick", playerid, reason)
        gate_players[playerid] = nil
        return reason
    end
    -- 游戏服登录流程完成后，整个登录流程完成

    conn.playerid = playerid

    log.info(string.format("gate confirm_srv_game success. pid:%d srv_game_addr:%s", playerid, srv_game_addr))
    return nil
end

function s.resp.send_by_fd(srcaddr, fd, bs)
    websocket.write(fd, bs, "binary")
end

function s.resp.send_by_pid(srcaddr, playerid, bs)
    local gplayer = gate_players[playerid]
    if not gplayer then
        return
    end
    local conn = gplayer.conn
    if not conn then
        return
    end

    s.resp.send_by_fd(srcaddr, conn.fd, bs)
end

function s.resp.kick(srcaddr, playerid)
    local gplayer = gate_players[playerid]
    if not gplayer then
        return
    end
    local conn = gplayer.conn
    if not conn then
        return
    end

    websocket.close(conn.fd, CLOSE_CODE.FINAL_KICK)

    log.info("gate kick. pid: ", playerid)
end

function s.resp.set_ping_timestamp(srcaddr, fd, time)
    last_ping_timestamp[fd] = time
end

function s.resp.check_ping_timestamp(srcaddr)
    local delete = {}
    for fd, last_ping_time in pairs(last_ping_timestamp) do
        if last_ping_time ~= nil and util.second() - last_ping_time > 5 then
            log.info(string.format("WebSocket client timeout, closing connection: %s", fd))
            websocket.close(fd, CLOSE_CODE.HEART_BEAT_DISCONNECT)
            delete[fd] = true
        end
    end

    local new_ping_timestamp = {}
    for fd, v in pairs(last_ping_timestamp) do
        if not delete[fd] and v ~= nil then
            new_ping_timestamp[fd] = v
        end
    end

    last_ping_timestamp = new_ping_timestamp
end

-- 服务退出
function s.resp.srv_exit(srcaddr)
    for fd, _ in pairs(client_conns) do
        websocket.close(fd, CLOSE_CODE.SERVER_EXIT)
    end
    skynet.exit()
end

function s.initfunc()
    local node = skynet.getenv("node")

    local function find_port()
        for _, info in pairs(runconfig[node]) do
            if info.name == "gateway" then
                for id, v in ipairs(info.list) do
                    if id == s.id then
                        return v.port
                    end
                end
            end
        end
        return 0
    end

    local port = find_port()

    assert(port ~= 0, "fail to find gate port: " .. port)

    local listen_id = socket.listen("0.0.0.0", port)
    assert(listen_id, "failed to listen on port: " .. port)

    log.info("websocket listen on port: " .. port)

    socket.start(
        listen_id,
        function(client_id, addr)
            log.debug(string.format("accepted websocket client: %s addr: %s", client_id, addr))
            local ok, err = websocket.accept(client_id, handle, "ws", addr)
            if not ok then
                log.error("websocket accept error:", err)
            else
                skynet.send(skynet.self(), "lua", "set_ping_timestamp", client_id, util.second())
            end
        end
    )

    -- 心跳检查协程
    skynet.fork(check_heartbeat)
end

s.start(...)
