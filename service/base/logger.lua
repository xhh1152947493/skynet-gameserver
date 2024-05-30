local skynet = require "skynet"
local s = require "service"
local lfs = require "lfs"

local log_path = skynet.getenv("self_logpath")
local is_debug = skynet.getenv("self_log_debug") == "true"

local _current_file = nil

local function check_exists(path)
    local attr = lfs.attributes(path)
    if not attr then
        lfs.mkdir(path)
    elseif attr.mode ~= "directory" then
        print(path .. " exists but is not a directory")
    end
end

local function full_file(file_name)
    return log_path .. file_name
end

local function new_file()
    local timestamp = math.floor(skynet.time())
    local current_time = os.date("*t", timestamp)

    local formatted_time =
        string.format(
        "%04d%02d%02d-%02d:%02d",
        current_time.year,
        current_time.month,
        current_time.day,
        current_time.hour,
        current_time.min
    )
    local file_name = formatted_time .. ".log"

    local file, _ = io.open(full_file(file_name), "a")
    return file
end

-- 避免无限生成文件
local function checkfix_file_count()
    print("checkfix_file_count...........start")

    -- if is_debug then
    --     return
    -- end

    local oldest_file = ""
    local file_count = 0
    for file_name in lfs.dir(log_path) do
        if file_name ~= "." and file_name ~= ".." then
            local file_path = full_file(file_name)
            local mode = lfs.attributes(file_path, "mode")

            if mode == "file" then
                local oldest_num = tonumber(oldest_file) or 0
                local cur_file = file_name:match("(.*)%.log$")
                local cur_num = tonumber(cur_file)
                if cur_num < oldest_num then
                    oldest_file = cur_file
                end
                file_count = file_count + 1
            end
        end
    end

    print("checkfix_file_count...........end", file_count)

    if file_count > 200 then
        os.remove(full_file(oldest_file))
    end
end

local function time_file()
    print("time_file...........")
    if _current_file ~= nil then
        _current_file:close()
    end

    local file = new_file()
    if not file then
        return
    end

    _current_file = file

    checkfix_file_count()

    -- 每5分钟创建一个新文件
    skynet.sleep(_G.SKYNET_MINUTE * 5)
end

function s.resp.logging(source, str)
    if not _current_file then
        return
    end

    _current_file:write(str .. "\n")
    _current_file:flush()
end

-- 服务退出
function s.resp.srv_exit(srcaddr)
    skynet.exit()
end

s.initfunc = function()
    check_exists(log_path)

    skynet.fork(time_file)
end

s.start(...)
