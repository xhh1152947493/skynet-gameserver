local pbtool = require "pbtool"
local skynet = require "skynet"
local gdata = require "dglobal"
local log = require "log"

require "message_def"

local net = {}

-- 本游戏服广播 todo zhangzhihui
function net.board_cast_local(msgtype, info)
    local bs = net.pack_msg(msgtype, info)
    net.send_by_player(nil, bs)
end

-- 本节点广播 todo zhangzhihui
function net.board_cast_node()
end

-- 全服广播 todo zhangzhihui
function net.board_cast_world()
end

-- 统一返回给client的错误信息
function net.format_err(code, reason)
    local err = {}
    err.ErrCode = code
    err.Reason = reason
    return err
end

-- todo zhangzhihui
function net.send_by_pid(pid, msgtype, info)
    net.send_by_player(nil, msgtype, info)
end

function net.send_by_player(player, msgtype, info)
    if player == nil or player.gate then
        log.error("send msg to client by player fail, player or gate nil")
        return
    end

    skynet.send(player.gate, "lua", "send_by_pid", player.id, net.pack_msg(msgtype, info))
end

function net.pack(msgid, bs)
    return string.pack(">H", msgid) .. bs
end

function net.pack_msg(msgtype, info)
    return net.pack(msgtype.ID, pbtool.encode(msgtype.Msg, info))
end

function net.unpack(bs)
    local msgid, bsleft = string.unpack(">H", bs)
    return msgid, bsleft
end

return net
