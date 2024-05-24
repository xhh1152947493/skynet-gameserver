local util = require "util"
local event = require "event"
local net = require "net"
local pb_struct = require "pb_struct"

local splayer = {
    timepoller = util.timepoller()
}

local function do_player_login(plyaerid, node)
    local resp = pb_struct.LoginResp()

    net.send_by_player(nil, MESSAGE_TYPE.GS2C_LOGIN, resp)
end

function splayer.awake()
    event.register_event(EVENT_MSG.EVENT_PLAYER_LOGIN, "onPlyaerLogin", do_player_login)
end

return splayer
