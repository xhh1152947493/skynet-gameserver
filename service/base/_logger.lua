local skynet = require "skynet"
local s = require "service"
local lfs = require "lfs"
local log = require "log"

local log_path = skynet.getenv("self_logpath")
local logfile_maxcount = skynet.getenv("self_logfile_count")

local _current_file = {
    name = "",
    bytes_count = 0,
    file = nil
}

local _max_bytes_count = 5 * 1024 * 1024 -- 5Mb

local function check_exists(path)
    local attr = lfs.attributes(path)
    if not attr then
        lfs.mkdir(path)
        log.info(string.format("logger check_exists and create path:%s", path))
    elseif attr.mode ~= "directory" then
        log.info(string.format("logger check_exists, exists but is not a directory. path:%s", path))
    end
end

local function full_filepath(file_name)
    return log_path .. file_name
end

local function new_file()
    local timestamp = math.floor(skynet.time())
    local current_time = os.date("*t", timestamp)

    local formatted_time =
        string.format(
        "%04d%02d%02d%-02d%:02d:02d",
        current_time.year,
        current_time.month,
        current_time.day,
        current_time.hour,
        current_time.min,
        current_time.sec
    )
    local file_name = formatted_time .. ".log"

    local file, err = io.open(full_filepath(file_name), "a")

    log.info(string.format("logger new_file end. file_name:%s err:%s", file_name, err))
    return file, file_name
end

local function set_cur_file(file, name)
    _current_file.name = name
    _current_file.bytes_count = 0
    _current_file.file = file
    log.info(string.format("logger set cur file. name:%s", _current_file.name))
end

local function parse_datetime2num(datetime_str)
    local cleaned_str = datetime_str:gsub("[%-:]", "")
    return tonumber(cleaned_str)
end

local function check_max_file_count()
    if not (logfile_maxcount ~= nil and type(logfile_maxcount) == "number" and logfile_maxcount > 0) then
        return
    end

    local oldest_file = "20991231-00:00:00"
    local cur_file_count = 0
    for file_name in lfs.dir(log_path) do
        if file_name ~= "." and file_name ~= ".." then
            local mode = lfs.attributes(full_filepath(file_name), "mode")
            if mode == "file" and file_name:match("(.*)%.log$") then
                local oldest_num = parse_datetime2num(oldest_file)
                local cur_file = file_name:match("(.*)%.log$")
                local cur_num = parse_datetime2num(cur_file)
                if cur_num < oldest_num then
                    oldest_file = cur_file
                end
                cur_file_count = cur_file_count + 1
            end
        end
    end

    if cur_file_count > logfile_maxcount then
        os.remove(full_filepath(oldest_file))
        log.info(
            string.format(
                "logger check_max_file_count remove fail. oldest_file:%s file_count:%s",
                oldest_file,
                cur_file_count
            )
        )
    end
end

local function try_rebase_file()
    if _current_file.bytes_count >= _max_bytes_count then -- 文件过大创建新文件
        local file, name = new_file()
        if not file then
            _current_file.bytes_count = 0
            log.info(string.format("logger in logging new file filed. lasted file:%s", _current_file.name))
            return
        end
        _current_file.file:close() -- 创建成功关闭旧文件

        set_cur_file(file, name) -- 设置写入为新文件

        check_max_file_count() -- 检查日志数量是否过多
    end
end

function s.resp.logging(source, str)
    if not _current_file.file then
        return
    end

    _current_file.file:write(str .. "\n")
    _current_file.file:flush()

    _current_file.bytes_count = _current_file.bytes_count + #str

    try_rebase_file()
end

-- 服务退出
function s.resp.srv_exit(srcaddr)
    skynet.exit()
end

s.initfunc = function()
    check_exists(log_path)

    local file, name = new_file()
    assert(file ~= nil, "bootstrap logger server failed, create new file err.")

    set_cur_file(file, name)
end

s.start(...)
