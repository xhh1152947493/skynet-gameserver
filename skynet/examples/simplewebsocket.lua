local skynet = require "skynet"
local socket = require "skynet.socket"
local websocket = require "http.websocket"

local handle = {}

-- 用于存储客户端的最后一次收到心跳消息的时间戳
local last_ping_timestamp = {}

-- 在文件的开头定义全局变量 client_info
_G.client_info = _G.client_info or {}

function handle.connect(id)
    print("WebSocket connected: " .. tostring(id))

    -- 在连接建立时，保存连接信息
    _G.client_info[id] = {id = id, addr = websocket.addrinfo(id)}
end

function handle.handshake(id, header, url)
    local addr = websocket.addrinfo(id)
    print("WebSocket handshake from: " .. tostring(id), "url", url, "addr:", addr)
    print("----header-----")
    for k, v in pairs(header) do
        print(k, v)
    end
    print("--------------")
end

function handle.message(id, msg, msg_type)
    print("WebSocket message from: " .. tostring(id), msg, msg_type)
    assert(msg_type == "binary" or msg_type == "text")

    if msg == "ping" then
        last_ping_timestamp[id] = skynet.time()
        websocket.write(id, "pong", "pong")
    end

    websocket.write(id, msg)
end

function handle.close(id, code, reason)
    print("WebSocket closed: " .. tostring(id), code, reason)

    -- 在连接关闭时，移除连接信息
    _G.client_info[id] = nil
end

function handle.error(id)
    print("WebSocket error: " .. tostring(id))
end

-- 检查客户端是否超时，如果超时则关闭连接
local function check_timeout()
    while true do
        skynet.sleep(1000) -- 间隔一秒钟检查一次

        for id, last_ping_time in pairs(last_ping_timestamp) do
            if skynet.time() - last_ping_time > 5 then -- 超过5秒没有收到心跳消息
                print("WebSocket client timeout, closing connection: " .. tostring(id))
                websocket.close(id)
            end
        end
    end
end

skynet.start(
    function()
        -- 启动检查超时的协程
        skynet.fork(check_timeout)

        local listen_id = socket.listen("0.0.0.0", 8801)
        assert(listen_id, "Failed to listen on port 8801")
        print("WebSocket server listening on port 8801")

        socket.start(
            listen_id,
            function(client_id, addr)
                print(string.format("Accepted WebSocket client: %s, addr: %s", client_id, addr))
                last_ping_timestamp[client_id] = skynet.time()
                local ok, err = websocket.accept(client_id, handle, "ws", addr)
                if not ok then
                    print("WebSocket accept error:", err)
                end
            end
        )
    end
)
