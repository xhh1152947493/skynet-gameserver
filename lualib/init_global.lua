local timewheelmgr = require "timewheel"
local util = require "util"
local time_mgr = require "time_mgr"

-- 游戏服的时间管理器，可以偏移
_G.TIME_MGR = time_mgr
_G.TIME_MGR.update(util.second(), util.second_ms())

_G.TIMEWHEEL_GAME = timewheelmgr:new_timewheel("WHEEL_GAME", util.second(), 259200, _G.SKYNET_SECOND)
