local _, GF = ...

GF.JoinAnnounce = {}
local JA = GF.JoinAnnounce

local ANNOUNCE_RETRY_MAX = 6
local ANNOUNCE_RETRY_DELAY = 0.5
local ANNOUNCED_TTL = 30
local KSTRING_BAD_LFG_NAME = "|Kr0|k"
local UNKNOWN_LFG_TEXTS = {
	["未知目标"] = true,
	["Unknown Target"] = true,
}
local ACTIVITY_TITLE_KEYS = { "fullName", "shortName", "name" }

local function chat(message)
	if not message or message == "" then
		return
	end
	if GF.ShowStatusMessage then
		GF.ShowStatusMessage(message)
	elseif DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
		DEFAULT_CHAT_FRAME:AddMessage(tostring(message))
	end
end

local function normalizeReadableText(text)
	if text == nil then
		return nil
	end
	if issecretvalue and issecretvalue(text) then
		return nil
	end
	text = tostring(text)
	if strtrim then
		text = strtrim(text)
	end
	if text == "" or text == KSTRING_BAD_LFG_NAME or text == "?" then
		return nil
	end
	if UNKNOWN_LFG_TEXTS[text] then
		return nil
	end
	if _G.UNKNOWNOBJECT and text == _G.UNKNOWNOBJECT then
		return nil
	end
	if _G.UNKNOWNBEING and text == _G.UNKNOWNBEING then
		return nil
	end
	return text
end

local function isReadableText(text)
	return normalizeReadableText(text) ~= nil
end

local function colorText(text, colorCode)
	text = normalizeReadableText(text)
	if not text then
		return nil
	end
	return (colorCode or "") .. text .. (GF.CHAT_RESET_COLOR_CODE or "|r")
end

local function appendColoredSegment(segments, text, colorCode)
	local segment = colorText(text, colorCode)
	if segment then
		table.insert(segments, segment)
	end
end

local function getSearchResultInfo(resultID)
	if not resultID or not C_LFGList or not C_LFGList.GetSearchResultInfo then
		return nil
	end
	local ok, info = pcall(C_LFGList.GetSearchResultInfo, resultID)
	if ok then
		return info
	end
	return nil
end

local function getActivityTitle(info)
	local activityID = info and info.activityIDs and info.activityIDs[1] or info and info.activityID
	if not activityID or not C_LFGList or not C_LFGList.GetActivityInfoTable then
		return nil
	end
	local ok, activity = pcall(C_LFGList.GetActivityInfoTable, activityID, info.questID, info.isWarMode)
	if not ok or not activity then
		return nil
	end
	for _, key in ipairs(ACTIVITY_TITLE_KEYS) do
		local title = normalizeReadableText(activity[key])
		if title then
			return title
		end
	end
	return nil
end

local function getListingTitle(info)
	return normalizeReadableText(info and info.name)
end

function JA:IsEnabled()
	local db = GF.GetDB and GF.GetDB()
	return db and db.joinAnnounceEnabled == true
end

function JA:Init()
	if self._inited then
		return
	end
	self._inited = true
	self._announced = {}
end

function JA:FormatAnnouncement(activityTitle, listingTitle)
	local L = GF.L or {}
	local highlightColor = GF.CHAT_STATUS_HIGHLIGHT_COLOR_CODE or GF.CHAT_WARNING_PREFIX_COLOR_CODE or "|cffffd200"
	local titleColor = GF.CHAT_STATUS_BODY_COLOR_CODE or "|cffffffff"
	local segments = {}
	appendColoredSegment(segments, L.JOIN_ANNOUNCE_JOINED or "joined group", highlightColor)
	appendColoredSegment(segments, activityTitle, highlightColor)
	appendColoredSegment(segments, listingTitle, titleColor)
	return table.concat(segments, " ")
end

function JA:FormatToastText(activityTitle, listingTitle)
	activityTitle = normalizeReadableText(activityTitle)
	listingTitle = normalizeReadableText(listingTitle)
	if not activityTitle or not listingTitle then
		return nil
	end
	return activityTitle .. " - " .. listingTitle
end

function JA:BuildAnnouncementData(resultID)
	local info = getSearchResultInfo(resultID)
	if not info then
		return nil
	end
	local activityTitle = getActivityTitle(info)
	local listingTitle = getListingTitle(info)
	if not isReadableText(activityTitle) or not isReadableText(listingTitle) then
		return nil
	end
	return {
		activityTitle = activityTitle,
		listingTitle = listingTitle,
		message = self:FormatAnnouncement(activityTitle, listingTitle),
		toastText = self:FormatToastText(activityTitle, listingTitle),
	}
end

function JA:BuildAnnouncementMessage(resultID)
	local data = self:BuildAnnouncementData(resultID)
	return data and data.message
end

function JA:ShowToast(text)
	if not isReadableText(text) then
		return
	end
	if GF.JoinAnnounceToast and GF.JoinAnnounceToast.Show then
		GF.JoinAnnounceToast:Show(text)
	end
end

function JA:PreviewToast()
	local L = GF.L or {}
	self:ShowToast(L.JOIN_ANNOUNCE_PREVIEW_POPUP or "自定义 PvE - 测试队伍")
end

function JA:MarkAnnounced(resultID)
	self._announced = self._announced or {}
	local now = GetTime and GetTime() or 0
	self._announced[resultID] = now + ANNOUNCED_TTL
	for id, expires in pairs(self._announced) do
		if expires <= now then
			self._announced[id] = nil
		end
	end
end

function JA:WasRecentlyAnnounced(resultID)
	local expires = self._announced and self._announced[resultID]
	return expires and expires > ((GetTime and GetTime()) or 0)
end

function JA:Announce(resultID, allowFallback)
	if not resultID or self:WasRecentlyAnnounced(resultID) then
		return true
	end
	local data = self:BuildAnnouncementData(resultID)
	if data and isReadableText(data.message) then
		chat(data.message)
		self:ShowToast(data.toastText)
		self:MarkAnnounced(resultID)
		return true
	end
	if allowFallback then
		chat(self:FormatAnnouncement())
		self:MarkAnnounced(resultID)
		return true
	end
	return false
end

function JA:ScheduleRetry()
	local pending = self._pending
	if not pending or pending.timer then
		return
	end
	if not C_Timer or not C_Timer.After then
		self:TryAnnounce(pending.token, true)
		return
	end
	pending.timer = true
	C_Timer.After(ANNOUNCE_RETRY_DELAY, function()
		if not JA._pending or JA._pending.token ~= pending.token then
			return
		end
		JA._pending.timer = nil
		JA:TryAnnounce(pending.token)
	end)
end

function JA:TryAnnounce(token, force)
	local pending = self._pending
	if not pending or pending.token ~= token then
		return
	end
	if self:Announce(pending.resultID, force) then
		self._pending = nil
		return
	end
	pending.attempts = (pending.attempts or 0) + 1
	if pending.attempts >= ANNOUNCE_RETRY_MAX then
		self:Announce(pending.resultID, true)
		self._pending = nil
		return
	end
	self:ScheduleRetry()
end

function JA:Queue(resultID)
	if not self:IsEnabled() or not resultID or self:WasRecentlyAnnounced(resultID) then
		return
	end
	self._token = (self._token or 0) + 1
	self._pending = {
		resultID = resultID,
		token = self._token,
		attempts = 0,
	}
	self:TryAnnounce(self._token)
end

function JA:OnApplicationStatusUpdated(resultID, newStatus)
	if newStatus ~= "inviteaccepted" then
		return
	end
	self:Queue(resultID)
end

function JA:OnGroupRosterChanged()
	local pending = self._pending
	if pending then
		self:TryAnnounce(pending.token)
	end
end
