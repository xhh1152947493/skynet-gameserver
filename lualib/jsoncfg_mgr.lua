-- 加载json数据并添加到内存管理
local json = require "cjson"
local lfs = require "lfs"
local cfgmgr = require "jsoncfg_def"
local log = require "log"

local directory_path = "./config/server_json/"

local function load_jsoncfg(filename)
    local file = io.open(filename, "r")
    assert(file ~= nil)
    local items = json.decode(file:read("*all"))
    file:close()

    local new = {}
    for _, item in ipairs(items) do
        if item and next(item) ~= nil then
            new[item.ID] = item
        end
    end

    local cfgname = "cfg" .. filename:match(".*/(.-)%.json$")

    cfgmgr[cfgname].items = new
    log.info("load json success...: ", cfgname)
end

local function traverse_directory(path)
    for file_name in lfs.dir(path) do
        if file_name ~= "." and file_name ~= ".." then
            local file_path = path .. file_name
            local mode = lfs.attributes(file_path, "mode")

            if mode == "file" then
                load_jsoncfg(file_path)
            elseif mode == "directory" then
                traverse_directory(file_path)
            end
        end
    end
end

cfgmgr.find_item = function(cfg, id)
    if not cfg or not cfg.items then
        return nil
    end
    return cfg.items[id]
end

traverse_directory(directory_path)

-- 添加自己的自定义方法onloadpost

-- function cfgmgr.CfgAchievement:onloadpost()
--     local items_hash = {}
--     for id, value in ipairs(self.items) do
--         items_hash[id * 1000] = value
--     end
--     self.items_hash = items_hash
-- end


-- function cfgmgr.CfgAchievement:find_by_hash(id)
--     local hash = id * 1000
--     return self.items_hash[hash]
-- end

-- 

local function onloadpost()
    for _, value in pairs(cfgmgr) do
        if type(value) == "table" and type(value.onloadpost) == "function" then
            value:onloadpost()
        end
    end
end

onloadpost()

return cfgmgr
