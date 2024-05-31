local skynet = require "skynet"
local s = require "service"
local net = require "net"
local runconfig = require "runconfig"
local log = require "log"
local util = require "util"

require "message_def"
require "pb_enum"

-- login服的主要功能为验证登录
-- 验证成功后，向login_mgr服发起登录请求，login_mgr确认可以登录后将消息回发给gateway完成登录流程

-- todo zhangzhihu 完成登录验证流程
local function handle_login(fd, srcaddr, req)
    -- login_mgr验证能否登录
    local srv_game_addr, playerid, err =
        s.call(runconfig.unique.login_mgr.node, "login_mgr", "reqlogin", skynet.getenv("node"), srcaddr, req)
    if err then
        return nil, net.format_err(CommonErrCode.ERR_CODE_LOGIN_FAIL, err)
    end

    -- login_mgr裁决能登录，通知gateway完成登录流程，分配游戏服务地址
    local err = skynet.call(srcaddr, "lua", "confirm_srv_game", fd, playerid, srv_game_addr)
    if err then
        return nil, net.format_err(CommonErrCode.ERR_CODE_LOGIN_FAIL, err)
    end

    -- login服不直接返回结果给客户端，等game服完成登录流程由game服返回登录消息
    log.debug(string.format("srv_login judge end. req:%s", util.dump_table(req)))
    return nil, nil
end

s.initfunc = function()
    s.register_clientmsg_handle(MESSAGE_TYPE.C2GS_LOGIN, handle_login)
end

s.start(...)
