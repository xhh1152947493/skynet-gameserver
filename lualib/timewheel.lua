-- 时间轮节点
local wheel_node = {
    name = "", -- 定时任务名
    time = 0, -- 目标时间
    callback = nil, -- 回调函数
    canceled = false -- 是否被取消
}

-- 创建时间轮节点
function wheel_node:new(name, time, callback)
    local obj = {name = name, time = time, callback = callback, canceled = false}
    self.__index = self
    return setmetatable(obj, self)
end

-- 取消定时器
function wheel_node:cancel()
    self.canceled = true
end

-- 时间轮
local time_wheel = {
    name = "", -- 时间轮名
    slots = {}, -- 时间槽
    ticktime = 0, -- 当前时间
    currentslot = 1, -- 当前槽位
    tickinterval = 1, -- 每个槽的时间间隔
    name2node = {} -- 通过名字映射的定时器
}

-- 创建时间轮
function time_wheel:new(name, starttime, slotscount, tickinterval)
    local obj = {
        name = name,
        slots = {},
        currentslot = 1,
        tickinterval = tickinterval,
        ticktime = starttime,
        name2node = {}
    }
    for i = 1, slotscount do
        obj.slots[i] = {}
    end
    self.__index = self
    return setmetatable(obj, self)
end

-- 添加定时器
function time_wheel:add_timer(name, time, callback)
    local delay = time - self.ticktime
    if delay < 0 then
        delay = 0
    end
    local targetslot = (self.currentslot + math.floor(delay / self.tickinterval)) % #self.slots + 1
    local node = wheel_node:new(name, time, callback)
    table.insert(self.slots[targetslot], node)
    self.name2node[name] = node
end

-- 取消定时器
function time_wheel:cancel_timer(name)
    local node = self.name2node[name]
    if node then
        node:cancel()
        self.name2node[name] = nil
    end
end

function time_wheel:get_timer(name)
    return self.name2node[name]
end

-- now可以是秒也可以是毫秒等其他单位，要与tickinterval一致
function time_wheel:tick2now(now)
    while self.ticktime <= now do
        self:tick_once()
    end
end

-- 执行定时器
function time_wheel:tick_once()
    local currentslotnodes = self.slots[self.currentslot]
    for _, node in ipairs(currentslotnodes) do
        if node ~= nil and not node.canceled then
            xpcall(node.callback, Traceback)
        end
    end
    self.slots[self.currentslot] = {} -- 清空当前槽的定时器
    self.currentslot = (self.currentslot % #self.slots) + 1 -- 移动到下一个槽
    self.ticktime = self.ticktime + self.tickinterval
end

local timewheelmgr = {
    items = {}
}

function timewheelmgr:new_timewheel(name, starttime, slotscount, tickinterval)
    if self.items[name] ~= nil then
        return nil
    end
    local wheel = time_wheel:new(name, starttime, slotscount, tickinterval)
    self.items[name] = wheel
    return wheel
end

function timewheelmgr:del_timewheel(name)
    self.items[name] = nil
end

function timewheelmgr:get_timewheel(name)
    return self.items[name]
end

return timewheelmgr
