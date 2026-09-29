local _, GF = ...

GF.NetEaseActivity = GF.NetEaseActivity or {}
local Activity = GF.NetEaseActivity

Activity.ID = "netease_newbie_2026_08"
Activity.START_AT = 1786604400 -- 2026-08-13 15:00:00 Asia/Shanghai
Activity.END_AT = 1796227199 -- 2026-12-02 23:59:59 Asia/Shanghai
Activity.PROTOCOL_VERSION = "12.2.2"
Activity.MIN_KEYSTONE_LEVEL = 10
Activity.NEWBIE_MAX_TIMED_RUNS = 10
Activity.VETERAN_MIN_TIMED_RUNS = 11

GF.NETEASE_IDENTITY_NEWBIE = "netease_newbie"
GF.NETEASE_IDENTITY_LOCOMOTIVE = "netease_locomotive"
GF.NETEASE_IDENTITY_STAR = "netease_star"
GF.NETEASE_IDENTITY_VETERAN = "netease_veteran"
GF.NETEASE_IDENTITY_LOADING = "netease_loading"
GF.NETEASE_IDENTITY_OFFLINE = "netease_offline"
GF.NETEASE_IDENTITY_FAULT = "netease_fault"

GF.NETEASE_SERVICE_ICON_TEXTURE =
	"Interface\\AddOns\\GroupFinder\\Art\\Icon\\NetEase.png"

GF.NETEASE_IDENTITY_ICON = {
	[GF.NETEASE_IDENTITY_NEWBIE] =
		"Interface\\AddOns\\GroupFinder\\Art\\Icon\\Newbie.png",
	[GF.NETEASE_IDENTITY_LOCOMOTIVE] =
		"Interface\\AddOns\\GroupFinder\\Art\\Icon\\Leader.png",
	[GF.NETEASE_IDENTITY_STAR] =
		"Interface\\AddOns\\GroupFinder\\Art\\Icon\\Star.png",
	[GF.NETEASE_IDENTITY_VETERAN] =
		"Interface\\AddOns\\GroupFinder\\Art\\Icon\\Veteran.png",
}

local function currentTimestamp()
	local value
	if type(GetServerTime) == "function" then
		local ok
		ok, value = pcall(GetServerTime)
		if not ok then
			value = nil
		end
	end
	if type(value) ~= "number" and type(time) == "function" then
		local ok
		ok, value = pcall(time)
		if not ok then
			value = nil
		end
	end
	return type(value) == "number" and value or 0
end

function Activity:GetTimestamp()
	return currentTimestamp()
end

function Activity:IsSupportedClient()
	if type(GetLocale) ~= "function" then
		return false
	end
	local ok, locale = pcall(GetLocale)
	return ok and locale == "zhCN"
end

function Activity:GetPhase(at)
	at = tonumber(at) or currentTimestamp()
	if at < self.START_AT then
		return "upcoming"
	end
	if at <= self.END_AT then
		return "active"
	end
	return "ended"
end

function Activity:IsActive(at)
	return self:GetPhase(at) == "active"
end
