local skynet = require "skynet"

local is_enable = skynet.getenv("self_logenable") == "true"
local is_debug = skynet.getenv("self_logdebug") == "true"
local is_daemon = skynet.getenv("daemon") ~= nil

local log = {}

local LOG_LEVEL = {
    DEBUG = 1,
    INFO = 2,
    WARN = 3,
    ERROR = 4,
    FATAL = 5
}

local LOG_LEVEL_DESC = {
    [1] = "DEBUG",
    [2] = "INFO",
    [3] = "WARN",
    [4] = "ERROR",
    [5] = "FATAL"
}

local function format_log_content(level, str)
    -- 不能在文件头引用，避免循环引用
    local s = require "service"

    return string.format(
        "[:%08x][%s][%s][%s] %s",
        skynet.self(),
        os.date("%H:%M:%S"),
        s.name_register,
        LOG_LEVEL_DESC[level],
        str
    )
end

-- 未启用使用skynet.error标准输出
local send_log_fun = function(level, str)
    skynet.error(str)
end

if is_enable then
    if is_daemon then -- 后台运行模式，通知logger服写入文件记录log
        send_log_fun = function(level, str)
            skynet.send(".logger123", "lua", "logging", format_log_content(level, str))
        end
    else -- 非后台运行模式，直接打印结果
        send_log_fun = function(level, str)
            print(format_log_content(level, str))
        end
    end
end

local function send_log(level, content)
    local str = content

    if level >= LOG_LEVEL.WARN then -- 追加打印出错的文件与行号
        local info = debug.getinfo(3)
        if info then
            local filename = string.match(info.short_src, "[^/.]+.lua")
            str = string.format("%s  <%s:%d>", str, filename, info.currentline)
        end
    end

    send_log_fun(level, str)
end

function log.debug(content)
    if not is_debug then -- 非debug模式,不记录debug等级日志
        return
    end
    send_log(LOG_LEVEL.DEBUG, content)
end

function log.info(content)
    send_log(LOG_LEVEL.INFO, content)
end

function log.warning(content)
    send_log(LOG_LEVEL.WARN, content)
end

function log.error(content)
    send_log(LOG_LEVEL.ERROR, content)
end

function log.fatal(content)
    send_log(LOG_LEVEL.FATAL, content)
end

return log
