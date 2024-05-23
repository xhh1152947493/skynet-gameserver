-- Generate by tools, Do not Edit.
local mgr = {}

function mgr.PlayerBaseData()
	return {
		PlayerID = 0,
		LastLoginTime = 0,
	}
end

function mgr.CommonErrResp()
	return {
		ErrCode = 0,
		Reason = "",
	}
end

function mgr.LoginReq()
	return {
		IsGuest = false,
	}
end

function mgr.LoginResp()
	return {
		Base = mgr.PlayerBaseData(), -- 玩家信息 
	}
end

return mgr
