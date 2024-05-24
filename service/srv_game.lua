-- srv_game服务下的消息处理回调必须是非阻塞的
local skynet = require "skynet"
local s = require "service"
local util = require "util"
local log = require "log"
local timewheelmgr = require "timewheel"
local event = require "event"

-- 注册游戏系统
local systems = {}
local splayer = require "splayer"
do
    table.insert(systems, splayer)
end

local function loadconfig()
    require "jsoncfg_mgr"
end

local function initglobal()
    require "init_global"
end

-- 游戏主循环,这个循环里面任何逻辑不能直接执行，只能通过消息传递到主线程的方式来触发，避免并发问题。
local function main_loop()
    while true do
        skynet.send(skynet.self(), "lua", "tick")

        skynet.sleep(_G.SKYNET_UNIT) -- 10毫秒1次
    end
end

function s.resp.tick(srcaddr)
    local now = util.second()

    -- 更新游戏时间
    _G.TIME_MGR.update(now, util.second_ms())

    -- 时间轮转动
    _G.TIMEWHEEL_GAME:tick2now(now)

    -- 系统update
    for _, sys in ipairs(systems) do
        if sys.update then
            local s1 = util.second_ms()
            sys.update()
            local s2 = util.second_ms()
            if s2 - s1 > 50 then
                log.warning("[---tick update deal timeout---] cost time: " .. s2 - s1)
            end
        end
    end
end

function s.resp.login(srcaddr, playerid)
    event.publish_event(EVENT_MSG.EVENT_PLAYER_LOGIN, playerid, srcaddr)
end

function s.resp.kick(srcaddr, playerid)
    event.publish_event(EVENT_MSG.EVENT_PLYAER_LOGOUT, playerid)
end

-- initfunc必须在dispatch之后，不会阻塞dispatch
s.initfunc = function()
    -- 初始化全局变量
    initglobal()

    -- 加载配置表
    loadconfig()

    for _, sys in ipairs(systems) do
        if sys.awake then
            sys.awake()
        end
    end

    skynet.fork(main_loop) -- 不阻塞后续流程
end

s.start(...)
