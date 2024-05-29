local skynet = require "skynet"
local s = require "service"
local runconfig = require "runconfig"
local cluster = require "skynet.cluster"
local log = require "log"

local STATUS = {
    LOGIN = 1,
    GAMEING = 2,
    LOGOUT = 3
}

local GS_MAX_PLAYER = 1000

local players = {}
local srv_game_player_count = {}

local init_pid = 100000

local function new_mgrplayer()
    local m = {
        playerid = nil,
        node = nil, -- 所在节点
        srv_game_addr = nil, -- 游戏服地址
        server_id = nil,
        status = nil, -- 状态
        gate = nil -- 登录的网关
    }
    return m
end

-- todo zhangzhihui 接入redis以保证id不重复
local function allocate_new_pid()
    init_pid = init_pid + 1
    return init_pid
end

-- 在网关节点内选择一个游戏服
local function choice_srv_game(node)
    local serverids = {}
    local cfgnode = runconfig[node]
    for id, _ in pairs(cfgnode.srv_game) do
        table.insert(serverids, id)
    end

    local min = GS_MAX_PLAYER
    local serverid = 0
    for _, srv_id in ipairs(serverids) do
        local curnum = srv_game_player_count[srv_id] or 0
        if curnum < min then
            min = curnum
            serverid = srv_id
        end
    end
    if serverid == 0 then -- 服务器全满了
        return nil, serverid
    end

    -- 名字代替地址
    local srv_game_addr = string.format(".%s%d", "srv_game", serverid)
    return srv_game_addr, serverid
end

function s.resp.reqkick(srcaddr, playerid, reason)
    local mplayer = players[playerid]
    if not mplayer then
        return
    end

    if mplayer.status ~= STATUS.GAMEING then
        return
    end

    mplayer.status = STATUS.LOGOUT

    -- 通知game离线
    s.call(mplayer.node, mplayer.srv_game_addr, "kick", playerid)
    -- 通知gate离线
    s.call(mplayer.node, mplayer.gate, "kick", playerid)

    -- 踢出流程完成，移除内存管理
    players[playerid] = nil

    log.info(string.format("login_mgr judge reqkick success. pid:%d reason:%s", playerid, reason))
end

function s.resp.reqlogin(srcaddr, srcnode, gateaddr, req)
    if req == nil then
        return nil, nil, "login_mgr judge reqlogin fail, req is nil"
    end
    local playerid = req.playerid
    if playerid == 0 then -- 新玩家，分配一个新的id
        playerid = allocate_new_pid()
    end

    local mplayer = players[playerid]
    if mplayer then
        if mplayer.status ~= STATUS.GAMEING then -- 正在登录或登出，禁止登录
            return nil, nil, string.format("login_mgr judge reqlogin fail, status err. status:%d", mplayer.status)
        end
        s.resp.reqkick(srcaddr, playerid, "repeated login")
    end

    -- 正常登录流程，分配一个游戏服
    local srv_game_addr, serverid = choice_srv_game(srcnode)
    if not srv_game_addr then
        return nil, nil, string.format("login_mgr judge reqlogin fail, all server full")
    end

    srv_game_player_count[serverid] = (srv_game_player_count[serverid] or 0) + 1

    local mplayer = new_mgrplayer()
    mplayer.playerid = playerid
    mplayer.node = srcnode
    mplayer.srv_game_addr = srv_game_addr
    mplayer.serverid = serverid
    mplayer.status = STATUS.LOGIN
    mplayer.gate = gateaddr
    players[mplayer.playerid] = mplayer

    log.info(
        string.format(
            "login_mgr judge reqlogin success. pid:%d srv_game_addr:%s serverid:%s",
            playerid,
            srv_game_addr,
            serverid
        )
    )
    return srv_game_addr, mplayer.playerid, nil
end

-- 进程退出
function s.resp.srv_exit(srcaddr)
    skynet.exit()
end

s.start(...)
