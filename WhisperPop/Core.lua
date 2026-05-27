------------------------------------------------------------
-- Core.lua
--
-- Abin
-- 2015/9/06
------------------------------------------------------------

local pairs = pairs
local ipairs = ipairs
local strfind = strfind
local strlower = strlower
local strtrim = strtrim
local type = type
local tinsert = tinsert
local strsub = strsub
local strmatch = strmatch
local date = date
local time = time
local format = format
local select = select
local PlaySoundFile = PlaySoundFile
local wipe = wipe
local tremove = tremove
local tconcat = table.concat
local GetPlayerInfoByGUID = GetPlayerInfoByGUID
local BNGetNumFriends = BNGetNumFriends
local GMChatFrame_IsGM = GMChatFrame_IsGM
local ChatFrame_GetMessageEventFilters = ChatFrame_GetMessageEventFilters
local ChatFrame_SendTell = ChatFrame_SendTell or ChatFrameUtil.SendTell
local ChatFrame_SendBNetTell = ChatFrame_SendBNetTell or ChatFrameUtil.SendBNetTell
local ChatFrame_OpenChat = ChatFrame_OpenChat or ChatFrameUtil.OpenChat
local SendWho = C_FriendList.SendWho
local InviteUnit = C_PartyInfo and C_PartyInfo.InviteUnit or InviteUnit
local FriendsFrame_ShowBNDropdown = FriendsFrame_ShowBNDropdown
local DEFAULT_CHAT_FRAME = DEFAULT_CHAT_FRAME
local CloseMenus = CloseMenus
local UIDropDownMenu_CreateInfo = UIDropDownMenu_CreateInfo
local UIDropDownMenu_AddButton = UIDropDownMenu_AddButton
local UIDropDownMenu_Initialize = UIDropDownMenu_Initialize
local ToggleDropDownMenu = ToggleDropDownMenu

-- Opening FriendsFrame_*Dropdown from our list taints Blizzard's player menu; secure actions like
-- CopyToClipboard then fail (ADDON_ACTION_FORBIDDEN). BN dropdown is deferred one frame.
local function WhisperPop_DeferMenu(opener)
	if C_Timer and C_Timer.After then
		C_Timer.After(0, opener)
	else
		opener()
	end
end

local function getDeprecatedAccountInfo(accountInfo)
	if accountInfo then
		local clientProgram = accountInfo.gameAccountInfo.clientProgram ~= "" and accountInfo.gameAccountInfo.clientProgram or nil
		return
			accountInfo.bnetAccountID, accountInfo.accountName, accountInfo.battleTag, accountInfo.isBattleTagFriend,
			accountInfo.gameAccountInfo.characterName, accountInfo.gameAccountInfo.gameAccountID, clientProgram,
			accountInfo.gameAccountInfo.isOnline, accountInfo.lastOnlineTime, accountInfo.isAFK, accountInfo.isDND, accountInfo.customMessage, accountInfo.note, accountInfo.isFriend,
			accountInfo.customMessageTime, false, accountInfo.rafLinkType == Enum.RafLinkType.Recruit, accountInfo.gameAccountInfo.canSummon
	end
end

local BNGetFriendInfo = BNGetFriendInfo or function(friendIndex)
	local accountInfo = C_BattleNet.GetFriendAccountInfo(friendIndex)
	return getDeprecatedAccountInfo(accountInfo)
end

local BNGetFriendInfoByID  = BNGetFriendInfoByID or function(id)
	local accountInfo = C_BattleNet.GetAccountInfoByID(id)
	return getDeprecatedAccountInfo(accountInfo)
end

local addon = LibAddonManager:CreateAddon(...)
local L = addon.L

-- Retail 12.0+: chat text/sender may be secret during C_ChatInfo.InChatMessagingLockdown (e.g. boss combat).

local deferredWhisperEvents = {}
local deferredWhisperFrame = CreateFrame("Frame", "WhisperPopDeferredWhisperQueue")
deferredWhisperFrame:Hide()

local function WhisperPopInChatMessagingLockdown()
	local fn = C_ChatInfo and C_ChatInfo.InChatMessagingLockdown
	return fn and fn() or false
end

local function WhisperPopHasAnySecretValues(...)
	local fn = hasanysecretvalues
	return fn and fn(...) or false
end

local WhisperPopCapturePlainFromVarargs

local function WhisperPopShouldDeferChatEvent(...)
	if WhisperPopHasAnySecretValues(...) then
		return true
	end
	-- M+: lock may last the whole run; defer all whispers and drain via tail-requeue pump (no head block).
	if WhisperPopInChatMessagingLockdown() then
		return true
	end
	return false
end

local function WhisperPopStringIsEmptySafe(s)
	if s == nil or type(s) ~= "string" then
		return true
	end
	local ok, empty = pcall(function()
		return s == "" or #s == 0
	end)
	return ok and empty or false
end

local function WhisperPopStringComparable(s)
	if type(s) ~= "string" then
		return false
	end
	return pcall(function()
		local _ = s == ""
		local __ = #s
		return true
	end)
end

local function WhisperPopIsSecretValue(v)
	if v == nil then
		return false
	end
	local fn = issecretvalue
	if not fn then
		return false
	end
	local ok, sec = pcall(fn, v)
	return ok and sec
end

local function WhisperPopCaptureScratchFontPlain(raw)
	if WhisperPopIsSecretValue(raw) then
		-- Secret strings: only FontString path; no # / == / trim on raw.
	elseif raw == nil then
		return nil
	else
		local okStr, isStr = pcall(function()
			return type(raw) == "string"
		end)
		if not okStr or not isStr then
			return nil
		end
		if WhisperPopStringComparable(raw) and WhisperPopStringIsEmptySafe(raw) then
			return nil
		end
	end
	local fs = deferredWhisperFrame._wpCaptureFS
	if not fs then
		fs = deferredWhisperFrame:CreateFontString(nil, "BACKGROUND", "ChatFontNormal")
		fs:Hide()
		deferredWhisperFrame._wpCaptureFS = fs
	end
	local t
	local ok = pcall(function()
		fs:SetText(raw)
		t = fs:GetText()
	end)
	fs:SetText("")
	if not ok or type(t) ~= "string" then
		ok = pcall(function()
			fs:SetFormattedText("%s", raw)
			t = fs:GetText()
		end)
		fs:SetText("")
	end
	if ok and type(t) == "string" and WhisperPopStringComparable(t) and not WhisperPopStringIsEmptySafe(t) then
		return t
	end
	return nil
end

--- Retail 12.x: arg1/arg2 may be secret; multi-path plain capture (aligned with MtjChatDB LogCapture).
local function WhisperPopTryCapturePlainText(orig)
	if WhisperPopIsSecretValue(orig) then
		return WhisperPopCaptureScratchFontPlain(orig)
	end
	local okNil, isNil = pcall(function()
		return orig == nil
	end)
	if okNil and isNil then
		return nil
	end

	local okFmt, s = pcall(format, "%s", orig)
	if okFmt and type(s) == "string" and not WhisperPopIsSecretValue(s) then
		if WhisperPopStringIsEmptySafe(s) then
			return nil
		end
		if pcall(function()
			tconcat({ s })
		end) and WhisperPopStringComparable(s) then
			return s
		end
		local okAll, out = pcall(function()
			local n = #s
			if n == 0 then
				return ""
			end
			local parts = {}
			for i = 1, n do
				local b = s:byte(i)
				parts[i] = b and string.char(b) or "?"
			end
			return tconcat(parts)
		end)
		if okAll and type(out) == "string" and WhisperPopStringComparable(out) and not WhisperPopStringIsEmptySafe(out) then
			return out
		end
		local ft = WhisperPopCaptureScratchFontPlain(s)
		if ft then
			return ft
		end
	end
	return WhisperPopCaptureScratchFontPlain(orig)
end

function WhisperPopCapturePlainFromVarargs(...)
	local plainText, plainName
	local ok1, a1 = pcall(select, 1, ...)
	if ok1 then
		plainText = WhisperPopTryCapturePlainText(a1)
	end
	local ok2, a2 = pcall(select, 2, ...)
	if ok2 then
		plainName = WhisperPopTryCapturePlainText(a2)
	end
	return plainText, plainName
end

local function WhisperPopArgStringEmpty(v)
	if v == nil then
		return true
	end
	local ok, empty = pcall(function()
		return type(v) ~= "string" or strtrim(v) == ""
	end)
	return ok and empty
end

local function WhisperPopMergeCapturedPlainIntoArgs(args, plainText, plainName)
	if type(args) ~= "table" then
		return
	end
	if plainText and plainText ~= "" and WhisperPopArgStringEmpty(args[1]) then
		args[1] = plainText
	end
	if plainName and plainName ~= "" and WhisperPopArgStringEmpty(args[2]) then
		args[2] = plainName
	end
end

local function WhisperPopSanitizeChatArgs(...)
	local n = select("#", ...)
	local out = {}
	local cap = math.min(n, 29)
	for i = 1, cap do
		local okSel, v = pcall(select, i, ...)
		if not okSel then
			out[i] = ""
		else
			local okSec, sec = pcall(function()
				return issecretvalue and issecretvalue(v)
			end)
			if okSec and sec then
				out[i] = ""
			else
				out[i] = v
			end
		end
	end
	return out, n
end

--- Retail 12.x: only arg11 is trusted as chat line id (no arg scan).
local function WhisperPopCaptureChatLineIdFromVarargs(...)
	if select("#", ...) < 11 then
		return nil
	end
	local okSel, v = pcall(select, 11, ...)
	if not okSel or v == nil then
		return nil
	end
	local lid = v
	if type(lid) ~= "number" then
		local okTn, n = pcall(tonumber, lid)
		if okTn then
			lid = n
		end
	end
	local ok11, good = pcall(function()
		return type(lid) == "number" and lid > 0
	end)
	if ok11 and good then
		return lid
	end
	return nil
end

--- "-Realm" from wrong GetChatLine row is not a player name.
local function WhisperPopSenderLooksLikeRealmSuffixOnly(name)
	local ok, r = pcall(function()
		if type(name) ~= "string" or name == "" then
			return false
		end
		return strmatch(name, "^%-[^%-]+$") ~= nil
	end)
	return ok and r or false
end

local function WhisperPopTryResolveNameRealmFromGuid(guid)
	local ok, ret = pcall(function()
		local isSecFn = issecretvalue
		if isSecFn then
			local okS, sec = pcall(isSecFn, guid)
			if okS and sec then
				return nil
			end
		end
		if guid == nil or type(guid) ~= "string" or guid == "" then
			return nil
		end
		local _, _, _, _, _, n, r = GetPlayerInfoByGUID(guid)
		if type(n) ~= "string" or n == "" then
			return nil
		end
		if type(r) == "string" and r ~= "" then
			return n .. "-" .. r
		end
		return n
	end)
	return ok and ret or nil
end

local function WhisperPopGuidForApi(guid)
	local ok, ret = pcall(function()
		local isSecFn = issecretvalue
		if isSecFn then
			local okS, sec = pcall(isSecFn, guid)
			if okS and sec then
				return ""
			end
		end
		if guid == nil or type(guid) ~= "string" or guid == "" then
			return ""
		end
		return guid
	end)
	if ok and type(ret) == "string" then
		return ret
	end
	return ""
end

local function WhisperPopResolveSelfWhisperSessionName(name, guid)
	local p = addon.player
	local r = addon.normalizedRealm
	if type(p) ~= "string" or p == "" or type(r) ~= "string" or r == "" then
		return name
	end
	local selfFull = p .. "-" .. r
	local okPg, pgRaw = pcall(UnitGUID, "player")
	if not okPg or not pgRaw then
		return name
	end
	local pg = WhisperPopGuidForApi(pgRaw)
	local tg = WhisperPopGuidForApi(guid)
	if pg ~= "" and tg ~= "" and pg == tg then
		return selfFull
	end
	local okAmb, same = pcall(function()
		if type(name) ~= "string" or strtrim(name) == "" then
			return false
		end
		return Ambiguate(name, "none") == Ambiguate(p, "none")
	end)
	if okAmb and same then
		return selfFull
	end
	return name
end

local function WhisperPopResolveBnetAccountIdFromSender(sender)
	if not sender or sender == "" then
		return 0
	end
	local ambig = Ambiguate(sender, "none")
	for i = 1, BNGetNumFriends() do
		local id, accountName, battleTag, _, charName = BNGetFriendInfo(i)
		if id then
			if accountName and accountName == ambig then
				return id
			end
			if battleTag and battleTag == ambig then
				return id
			end
			if charName and Ambiguate(charName, "none") == ambig then
				return id
			end
		end
	end
	return 0
end

-- Forward declaration: WhisperPopRefreshDeferredChatArgs runs before this is assigned.
local WhisperPopNameNeedsRetry

local function WhisperPopRefreshDeferredChatArgs(event, args, n, ctx)
	if strsub(event, 1, 9) ~= "CHAT_MSG_" then
		return
	end
	local lineID = args[11]
	if type(lineID) ~= "number" then
		lineID = tonumber(lineID)
	end
	if not lineID or lineID == 0 then
		return
	end
	args[11] = lineID
	if not C_ChatInfo or not C_ChatInfo.GetChatLineText then
		return
	end
	local isSec = issecretvalue
	local function assignArgIfSafePlainString(slot, raw)
		if raw == nil then
			return
		end
		local ok, payload = pcall(function()
			if isSec then
				local okS, sec = pcall(isSec, raw)
				if okS and sec then
					return nil
				end
			end
			if type(raw) ~= "string" or raw == "" then
				return nil
			end
			return raw
		end)
		if ok and type(payload) == "string" and payload ~= "" then
			args[slot] = payload
		end
	end
	local okTxt, tTxt = pcall(C_ChatInfo.GetChatLineText, lineID)
	if okTxt then
		assignArgIfSafePlainString(1, tTxt)
	end
	local okWho, tWho = pcall(C_ChatInfo.GetChatLineSenderName, lineID)
	if okWho then
		local okPick, whoOut = pcall(function()
			if isSec then
				local okS, sec = pcall(isSec, tWho)
				if okS and sec then
					return nil
				end
			end
			if type(tWho) ~= "string" or tWho == "" or WhisperPopSenderLooksLikeRealmSuffixOnly(tWho) then
				return nil
			end
			return tWho
		end)
		if okPick and type(whoOut) == "string" and whoOut ~= "" then
			args[2] = whoOut
		end
	end
	local okG, tGuid = pcall(C_ChatInfo.GetChatLineSenderGUID, lineID)
	if okG then
		local g = WhisperPopGuidForApi(tGuid)
		if g ~= "" then
			args[12] = g
		end
	end
	-- Self whisper (incl. borrowed INFORM line id): GetChatLineSenderName often empty on the send line.
	if event == "CHAT_MSG_WHISPER" or event == "CHAT_MSG_WHISPER_INFORM" then
		if WhisperPopNameNeedsRetry(args[2]) then
			local okPg, pgRaw = pcall(UnitGUID, "player")
			if okPg and pgRaw then
				local pg = WhisperPopGuidForApi(pgRaw)
				local tg = WhisperPopGuidForApi(args[12])
				if pg ~= "" and tg ~= "" and pg == tg then
					local p = addon.player
					local r = addon.normalizedRealm
					if type(p) == "string" and p ~= "" and type(r) == "string" and r ~= "" then
						args[2] = p .. "-" .. r
					end
				elseif type(ctx) == "table" and ctx.restoredFromSV and pg ~= "" and tg == "" then
					local b1 = args[1]
					local bodyOk = type(b1) == "string" and strtrim(b1) ~= ""
					if bodyOk then
						local p = addon.player
						local r = addon.normalizedRealm
						if type(p) == "string" and p ~= "" and type(r) == "string" and r ~= "" then
							args[12] = pg
							args[2] = p .. "-" .. r
						end
					end
				end
			end
		end
	end
	if event == "CHAT_MSG_BN_WHISPER_INFORM" or event == "CHAT_MSG_BN_WHISPER" then
		local okBn, bnId = pcall(function()
			local s2 = args[2]
			if s2 == nil then
				return nil
			end
			if isSec then
				local okS, sec = pcall(isSec, s2)
				if okS and sec then
					return nil
				end
			end
			if type(s2) ~= "string" or s2 == "" then
				return nil
			end
			return WhisperPopResolveBnetAccountIdFromSender(s2)
		end)
		if okBn and type(bnId) == "number" and bnId > 0 then
			args[13] = bnId
		end
	end
end

local function WhisperPopRefreshChatArgsOnce(event, args, n)
	n = math.max(tonumber(n) or 18, 18)
	WhisperPopRefreshDeferredChatArgs(event, args, n)
end

local function WhisperPopMsgBodyTrimmed(text)
	local ok, r = pcall(function()
		if type(text) ~= "string" then
			return ""
		end
		return strtrim(text)
	end)
	return (ok and r) or ""
end

WhisperPopNameNeedsRetry = function(name)
	if name == nil then
		return true
	end
	local isSec = issecretvalue
	if isSec then
		local okS, sec = pcall(isSec, name)
		if okS and sec then
			return true
		end
	end
	local ok, need = pcall(function()
		if type(name) ~= "string" or strtrim(name) == "" then
			return true
		end
		return WhisperPopSenderLooksLikeRealmSuffixOnly(name)
	end)
	return not ok or need
end

--- Must exist before WhisperPopScheduleWhisperNameRetries (uses MAX / DELAY).
-- 名称补全（已进列表后的定时重试，非延迟队列）：间隔 0.7→1.0s（2026-05-20 轻量化）；MAX/EXTRA_* 次数未改。
local WHISPER_NAME_RETRY_DELAY_SEC = 1.0
local WHISPER_NAME_RETRY_MAX = 3
local WHISPER_NAME_RETRY_EXTRA_LINE = 5
local WHISPER_NAME_RETRY_EXTRA_LINE_OPEN = 2
local WHISPER_NAME_RETRY_EXTRA_DEAD = 14

-- Dedupe "empty name + empty body" fallback spam per (lineID, direction). Must not mix IN/OUT:
-- self-whisper deferred replay borrows INFORM line id onto WHISPER; sharing one key drops the other half.
local whisperPopEmptyBothLineIds = {}

local function WhisperPopEmptyBothDedupeKey(lineID, inform)
	lineID = tonumber(lineID)
	if not lineID or lineID <= 0 then
		return nil
	end
	return format("%d:%d", lineID, inform and 1 or 0)
end

local function WhisperPopMaxNameRetryAttempts(lineID)
	local m = WHISPER_NAME_RETRY_MAX
	if lineID and lineID > 0 then
		if WhisperPopInChatMessagingLockdown() then
			m = m + WHISPER_NAME_RETRY_EXTRA_LINE
		else
			m = m + WHISPER_NAME_RETRY_EXTRA_LINE_OPEN
		end
	end
	local okD, deadGhost = pcall(function()
		return (UnitIsDead("player")) or (UnitIsGhost and UnitIsGhost("player"))
	end)
	if okD and deadGhost then
		m = m + WHISPER_NAME_RETRY_EXTRA_DEAD
	end
	return m
end
local function WhisperPopMergeLineApiSnapshot(eventName, lineID, text, name, guid)
	if type(eventName) ~= "string" or strsub(eventName, 1, 9) ~= "CHAT_MSG_" then
		return text, name, guid
	end
	lineID = tonumber(lineID)
	if not lineID or lineID <= 0 then
		return text, name, guid
	end
	local args = {}
	for j = 1, 18 do
		args[j] = ""
	end
	args[11] = lineID
	local gg = WhisperPopGuidForApi(guid)
	if gg ~= "" then
		args[12] = gg
	end
	WhisperPopRefreshChatArgsOnce(eventName, args, 18)

	local tNew = text
	local okR, v1 = pcall(function()
		return args[1]
	end)
	if okR then
		local apiBody = WhisperPopMsgBodyTrimmed(v1)
		local oldBody = WhisperPopMsgBodyTrimmed(text)
		if apiBody ~= "" then
			tNew = v1
		elseif oldBody ~= "" then
			tNew = text
		else
			local okTs, isStr = pcall(function()
				return type(v1) == "string"
			end)
			tNew = (okTs and isStr and v1) or text or ""
		end
	end

	local nNew = name
	local okR2, v2 = pcall(function()
		return args[2]
	end)
	if okR2 and not WhisperPopNameNeedsRetry(v2) then
		nNew = v2
	end

	local gNew = guid
	local okG, vg = pcall(function()
		return args[12]
	end)
	if okG then
		local g2 = WhisperPopGuidForApi(vg)
		if g2 ~= "" then
			gNew = vg
		end
	end
	nNew = WhisperPopResolveSelfWhisperSessionName(nNew, gNew)
	return tNew, nNew, gNew
end

local function WhisperPopMergeLineTwice(eventName, lineID, text, name, guid)
	text, name, guid = WhisperPopMergeLineApiSnapshot(eventName, lineID, text, name, guid)
	if lineID and lineID > 0 then
		return WhisperPopMergeLineApiSnapshot(eventName, lineID, text, name, guid)
	end
	return text, name, guid
end

function addon:WhisperPopFinishWhisperWithFallbacks(text, name, flag, guid, inform, eventName, lineID)
	lineID = tonumber(lineID)
	if not lineID or lineID <= 0 then
		lineID = nil
	end
	eventName = eventName or (inform and "CHAT_MSG_WHISPER_INFORM" or "CHAT_MSG_WHISPER")
	text, name, guid = WhisperPopMergeLineTwice(eventName, lineID, text, name, guid)
	local fixed = WhisperPopTryResolveNameRealmFromGuid(guid)
	if type(fixed) == "string" and fixed ~= "" then
		name = fixed
	end
	name = WhisperPopResolveSelfWhisperSessionName(name, guid)
	local body = WhisperPopMsgBodyTrimmed(text)
	local nameBad = WhisperPopNameNeedsRetry(name)
	if not nameBad and body == "" then
		if inform then
			if flag == "GM" or flag == "DEV" or (GMChatFrame_IsGM and GMChatFrame_IsGM(name)) then
				self:ProcessChatMsg(name, "GM", text, true)
			else
				flag = select(2, GetPlayerInfoByGUID(WhisperPopGuidForApi(guid)))
				self:ProcessChatMsg(name, flag, L["whisper snapshot body error"], true)
			end
		else
			if flag == "GM" or flag == "DEV" then
				self:ProcessChatMsg(name, "GM", text, false)
			else
				flag = select(2, GetPlayerInfoByGUID(WhisperPopGuidForApi(guid)))
				self:ProcessChatMsg(name, flag, L["whisper snapshot body error"], false)
			end
		end
		return
	end
	if nameBad and body ~= "" then
		name = WhisperPopResolveSelfWhisperSessionName(name, guid)
		nameBad = WhisperPopNameNeedsRetry(name)
		if not nameBad then
			self:WhisperPopApplyResolvedWhisper(inform and "OUT" or "IN", name, text, flag, guid, inform)
			return
		end
		local pname = L["unknown whisper bucket"]
		local cls = select(2, GetPlayerInfoByGUID(WhisperPopGuidForApi(guid))) or "UNKNOWN"
		self:ProcessChatMsg(pname, cls, text, inform)
		return
	end
	if nameBad and body == "" then
		if WhisperPopInChatMessagingLockdown() then
			return
		end
		if (not lineID or lineID <= 0) and WhisperPopGuidForApi(guid) == "" then
			return
		end
		local ebKey = WhisperPopEmptyBothDedupeKey(lineID, inform)
		if ebKey and whisperPopEmptyBothLineIds[ebKey] then
			return
		end
		if ebKey then
			whisperPopEmptyBothLineIds[ebKey] = true
		end
		local pname = L["unknown whisper bucket"]
		local cls = select(2, GetPlayerInfoByGUID(WhisperPopGuidForApi(guid))) or "UNKNOWN"
		self:ProcessChatMsg(pname, cls, L["unknown whisper empty both"], inform)
		return
	end
	if not nameBad and body ~= "" then
		self:WhisperPopApplyResolvedWhisper(inform and "OUT" or "IN", name, text, flag, guid, inform)
	end
end

function addon:WhisperPopApplyResolvedWhisper(direction, name, text, flag, guid, inform)
	name = WhisperPopResolveSelfWhisperSessionName(name, guid)
	local body = WhisperPopMsgBodyTrimmed(text)
	if direction == "IN" then
		if body == "" then
			if flag == "GM" or flag == "DEV" then
				self:ProcessChatMsg(name, "GM", text, false)
			else
				flag = select(2, GetPlayerInfoByGUID(WhisperPopGuidForApi(guid)))
				self:ProcessChatMsg(name, flag, L["whisper snapshot body error"], false)
			end
			return
		end
		if flag == "GM" or flag == "DEV" then
			flag = "GM"
		else
			flag = select(2, GetPlayerInfoByGUID(WhisperPopGuidForApi(guid)))
		end
		self:ProcessChatMsg(name, flag, text, false)
	else
		if body == "" then
			if flag == "GM" or flag == "DEV" or (GMChatFrame_IsGM and GMChatFrame_IsGM(name)) then
				self:ProcessChatMsg(name, "GM", text, true)
			else
				flag = select(2, GetPlayerInfoByGUID(WhisperPopGuidForApi(guid)))
				self:ProcessChatMsg(name, flag, L["whisper snapshot body error"], true)
			end
			return
		end
		if flag == "GM" or flag == "DEV" or (GMChatFrame_IsGM and GMChatFrame_IsGM(name)) then
			flag = "GM"
		else
			flag = select(2, GetPlayerInfoByGUID(WhisperPopGuidForApi(guid)))
		end
		self:ProcessChatMsg(name, flag, text, true)
	end
end

function addon:WhisperPopScheduleWhisperNameRetries(direction, text, name, flag, guid, inform, attempt, eventName, lineID)
	attempt = tonumber(attempt) or 1
	lineID = tonumber(lineID)
	if not lineID or lineID <= 0 then
		lineID = nil
	end
	eventName = eventName or (direction == "OUT" and "CHAT_MSG_WHISPER_INFORM" or "CHAT_MSG_WHISPER")
	if not C_Timer or not C_Timer.After then
		self:WhisperPopFinishWhisperWithFallbacks(text, name, flag, guid, inform, eventName, lineID)
		return
	end

	text, name, guid = WhisperPopMergeLineApiSnapshot(eventName, lineID, text, name, guid)
	name = WhisperPopResolveSelfWhisperSessionName(name, guid)
	local fixedEntry = WhisperPopTryResolveNameRealmFromGuid(guid)
	if type(fixedEntry) == "string" and fixedEntry ~= "" then
		name = fixedEntry
	end
	if not WhisperPopNameNeedsRetry(name) then
		self:WhisperPopApplyResolvedWhisper(direction, name, text, flag, guid, inform)
		return
	end

	if attempt > WhisperPopMaxNameRetryAttempts(lineID) then
		self:WhisperPopFinishWhisperWithFallbacks(text, name, flag, guid, inform, eventName, lineID)
		return
	end
	C_Timer.After(WHISPER_NAME_RETRY_DELAY_SEC, function()
		if not addon.db then
			return
		end
		text, name, guid = WhisperPopMergeLineApiSnapshot(eventName, lineID, text, name, guid)
		name = WhisperPopResolveSelfWhisperSessionName(name, guid)
		local fixedPre = WhisperPopTryResolveNameRealmFromGuid(guid)
		if type(fixedPre) == "string" and fixedPre ~= "" then
			name = fixedPre
		end
		if not WhisperPopNameNeedsRetry(name) then
			addon:WhisperPopApplyResolvedWhisper(direction, name, text, flag, guid, inform)
			return
		end
		local fixed = WhisperPopTryResolveNameRealmFromGuid(guid)
		if type(fixed) == "string" and fixed ~= "" then
			addon:WhisperPopApplyResolvedWhisper(direction, fixed, text, flag, guid, inform)
		else
			addon:WhisperPopScheduleWhisperNameRetries(direction, text, name, flag, guid, inform, attempt + 1, eventName, lineID)
		end
	end)
end

--[[--------------------------------------------------------------------
  WhisperPop 延迟队列（deferredWhisperEvents）— 调度与漏记排查（2026-05-20）

  设计：尾插轮转 + C_Timer 泵；无队列空闲 OnUpdate。入队/回放逻辑未删，只调「多久再试」与「少打重复 API」。

  【重试「次数」— 与改 CPU 前一致，勿随意改小，否则可能漏记】
  - LINE_FETCH：快 8 + 慢 12；/reload 恢复行 +24 → 单条最多约 44 次 deferredLineFetchAttempts
  - OPAQUE_LOCK_POLL_MAX = 48：锁聊无 line/无快照时 opaque 轮询次数上限
  - UNLOCK_NO_LINE_RETRIES = 40：已解锁仍无 lineID 时的轮询次数上限
  - PUMP_BURST = 20：单轮最多处理条数（只影响排水速度，不丢队里消息；改小不会漏，只会更慢进列表）

  【重试「间隔」— 有意从亚秒改为 1s（轻量化；解锁后 3～10s 进列表可接受）】
  - 原：锁聊轮询 0.65s；stall 曾误用 After(0) 每帧；无 line 0.12s
  - 现：DEFERRED_RETRY_INTERVAL_SEC = 1.0 → 锁聊 / stall / 无 line / 本轮有进展但队列未空，均约 1s 后再泵
  - 禁止：stall 或「零进展」路径使用 After(0, WhisperPop_DeferredPump)（曾导致 <10 条队列 ~50% CPU）

  【/reload 额外泵时刻 — 有意修改，非次数】
  - 原：0.25, 0.6, 1.15, 3, 6, 10 秒
  - 现：DEFERRED_RESTORE_PUMP_AFTER_SEC = { 1, 2, 3, 8, 10, 15 }

  【只省 CPU、不改变是否入队/是否最终回放 — 漏记排查时优先怀疑「次数」与暴雪 line/secret】
  - WhisperPopDeferredItemHasSnapshot → Prepare 跳过 GetChatLine*（已有 capturedPlain 或可用 args）
  - 无快照且有 lineID：仍尾插 + 定时再试；Refresh 由最多 3 次改为 1 次（同 line 少打重复 API）
  - WhisperPopRefreshChatArgsOnce：入队路径由 Twice 改为 Once
  - RequestDeferredPump 的 After(0)：仅同帧合并多次请求，不是 stall 重试间隔

  【续 7 曾临时改小次数，续 8 已回退】勿再将 OPAQUE / UNLOCK_NO_LINE / LINE_FETCH / PUMP_BURST 改小除非接受漏记风险。

  相关汇总：D:\插件备份\WhisperPop_修改汇总.md（2026-05-20 续 4～8）
----------------------------------------------------------------------]]
local DEFERRED_RETRY_INTERVAL_SEC = 1.0
local DEFERRED_LOCK_POLL_SEC = DEFERRED_RETRY_INTERVAL_SEC
local DEFERRED_LINE_FETCH_MAX = 8
local DEFERRED_LINE_FETCH_SLOW_EXTRA = 12
local DEFERRED_RESTORE_LINE_EXTRA = 24
local DEFERRED_OPAQUE_LOCK_POLL_MAX = 48
local DEFERRED_UNLOCK_NO_LINE_RETRIES = 40
local DEFERRED_UNLOCK_NO_LINE_DELAY_SEC = DEFERRED_RETRY_INTERVAL_SEC
local DEFERRED_STALL_RETRY_SEC = DEFERRED_RETRY_INTERVAL_SEC
local DEFERRED_PROCESSED_INFORM_LINE_SEC = 4
local DEFERRED_PUMP_BURST = 20
local DEFERRED_RESTORE_PUMP_AFTER_SEC = { 1, 2, 3, 8, 10, 15 }
local deferredPumpCoalesce = false
local deferredLockPollPending = false

--- SavedVariables: strip to string/number/boolean for pending queue rows.
local function WhisperPopCopyArgsForSave(args, n)
	if type(args) ~= "table" then
		return nil
	end
	n = math.min(math.max(tonumber(n) or 18, 18), 29)
	local out = {}
	for i = 1, n do
		local v = args[i]
		local tv = type(v)
		if tv == "number" or tv == "boolean" then
			out[i] = v
		elseif tv == "string" then
			if #v > 4096 then
				out[i] = strsub(v, 1, 4096)
			else
				out[i] = v
			end
		end
	end
	return out
end

local function WhisperPopSerializedArgsUseful(t)
	if type(t) ~= "table" then
		return false
	end
	for i = 1, 18 do
		local v = t[i]
		if type(v) == "string" and v ~= "" then
			return true
		end
	end
	return false
end

local function WhisperPopApplyCapturedPlainToItem(item)
	if type(item) ~= "table" or type(item.args) ~= "table" then
		return
	end
	if item.capturedPlainText and WhisperPopMsgBodyTrimmed(item.args[1]) == "" then
		item.args[1] = item.capturedPlainText
	end
	if item.capturedPlainName and WhisperPopNameNeedsRetry(item.args[2]) then
		item.args[2] = item.capturedPlainName
	end
end

local function WhisperPopDeferredItemHasSnapshot(item)
	if type(item) ~= "table" then
		return false
	end
	if WhisperPopSerializedArgsUseful(item.args) then
		return true
	end
	if item.capturedPlainText and strtrim(item.capturedPlainText) ~= "" then
		return true
	end
	if item.capturedPlainName and not WhisperPopNameNeedsRetry(item.capturedPlainName) then
		return true
	end
	return false
end

local function WhisperPopBorrowInformLineIdForWhisperItem(item)
	if type(item) ~= "table" or item.event ~= "CHAT_MSG_WHISPER" then
		return nil
	end
	local bor
	local nxt = deferredWhisperEvents[1]
	if type(nxt) == "table" and nxt.event == "CHAT_MSG_WHISPER_INFORM" then
		local b2 = nxt.args and nxt.args[11]
		if type(b2) ~= "number" or b2 <= 0 then
			b2 = nxt.captureLineID
		end
		if type(b2) ~= "number" then
			b2 = tonumber(b2)
		end
		if type(b2) == "number" and b2 > 0 then
			bor = b2
		end
	end
	if not bor then
		local li = addon._wpLastDeferredProcessedInformLineId
		local lt = addon._wpLastDeferredProcessedInformLineTime
		if type(li) == "number" and li > 0 and type(lt) == "number" and (time() - lt) <= DEFERRED_PROCESSED_INFORM_LINE_SEC then
			bor = li
		end
	end
	return bor
end

local function WhisperPopPrepareDeferredItem(item)
	if type(item) ~= "table" or type(item.args) ~= "table" then
		return
	end
	local nArg = math.max(tonumber(item.n) or 18, 18)
	-- 有快照：不调用 GetChatLine*（不漏记；正文/名已在入队捕获或 args 中）
	if WhisperPopDeferredItemHasSnapshot(item) then
		WhisperPopApplyCapturedPlainToItem(item)
		local lidPeek = item.args[11]
		if type(lidPeek) ~= "number" or lidPeek <= 0 then
			lidPeek = item.captureLineID
			if type(lidPeek) ~= "number" then
				lidPeek = tonumber(lidPeek)
			end
		end
		return lidPeek
	end
	local lidPeek = item.args[11]
	if type(lidPeek) ~= "number" or lidPeek <= 0 then
		lidPeek = item.captureLineID
		if type(lidPeek) ~= "number" then
			lidPeek = tonumber(lidPeek)
		end
		if lidPeek and lidPeek > 0 then
			item.args[11] = lidPeek
		end
	end
	if item.event == "CHAT_MSG_WHISPER" and not (type(lidPeek) == "number" and lidPeek > 0) and not WhisperPopSerializedArgsUseful(item.args) then
		local bor = WhisperPopBorrowInformLineIdForWhisperItem(item)
		if type(bor) == "number" and bor > 0 then
			item.args[11] = bor
			item.captureLineID = bor
			lidPeek = bor
		end
	end
	-- 无快照：仅有 lineID 时 Refresh 一次，再尾插重试（次数见文件头 LINE_FETCH / OPAQUE / UNLOCK_NO_LINE）
	if type(lidPeek) == "number" and lidPeek > 0 then
		WhisperPopRefreshDeferredChatArgs(item.event, item.args, nArg, item)
	end
	WhisperPopApplyCapturedPlainToItem(item)
	return lidPeek
end

local function WhisperPopPlayDeferredBatchSoundIfNeeded()
	if #deferredWhisperEvents == 0 then
		if addon._deferredBatchPlaySound and addon.db and addon.db.sound then
			addon:PlaySound()
			addon._deferredBatchPlaySound = nil
		end
		addon:BroadcastEvent("OnListUpdate")
	end
end

local function WhisperPopInvokeDeferredItemHandler(item)
	local handler = addon[item.event]
	if type(handler) ~= "function" then
		return
	end
	addon._whisperDeferredPlayback = true
	handler(addon, unpack(item.args, 1, item.n))
	addon._whisperDeferredPlayback = nil
	if item.event == "CHAT_MSG_WHISPER_INFORM" then
		local lp = item.args and item.args[11]
		if type(lp) ~= "number" or lp <= 0 then
			lp = item.captureLineID
		end
		if type(lp) ~= "number" then
			lp = tonumber(lp)
		end
		if type(lp) == "number" and lp > 0 then
			addon._wpLastDeferredProcessedInformLineId = lp
			addon._wpLastDeferredProcessedInformLineTime = time()
		end
	end
	deferredLockPollPending = false
end

local function WhisperPopRequeueDeferredItemTail(item)
	tinsert(deferredWhisperEvents, item)
end

--- RequestDeferredPump must be declared before WhisperPop_DeferredPump (forward local).
local WhisperPop_DeferredPump
local WhisperPop_RequestDeferredPump

local function WhisperPop_ResetDeferredLineFetchAttempts()
	for i = 1, #deferredWhisperEvents do
		local it = deferredWhisperEvents[i]
		if type(it) == "table" then
			it.deferredLineFetchAttempts = nil
		end
	end
end

WhisperPop_RequestDeferredPump = function()
	if #deferredWhisperEvents == 0 then
		return
	end
	deferredWhisperFrame:Show()
	if deferredPumpCoalesce then
		return
	end
	deferredPumpCoalesce = true
	if C_Timer and C_Timer.After then
		C_Timer.After(0, function()
			deferredPumpCoalesce = false
			WhisperPop_DeferredPump()
		end)
	else
		deferredPumpCoalesce = false
		WhisperPop_DeferredPump()
	end
end

WhisperPop_DeferredPump = function()
	if #deferredWhisperEvents == 0 then
		deferredLockPollPending = false
		deferredWhisperFrame:SetScript("OnUpdate", nil)
		deferredWhisperFrame.wpLockPollAcc = nil
		deferredWhisperFrame:Hide()
		return
	end

	deferredWhisperFrame:SetScript("OnUpdate", nil)
	deferredWhisperFrame.wpLockPollAcc = nil

	local locked = WhisperPopInChatMessagingLockdown()
	local qStart = #deferredWhisperEvents
	local stalled = 0
	local processed = 0
	local needLockPoll = false
	local needUnlockDelay = false

	while processed < DEFERRED_PUMP_BURST and #deferredWhisperEvents > 0 do
		local item = tremove(deferredWhisperEvents, 1)
		if not item then
			break
		end

		local lidPeek = WhisperPopPrepareDeferredItem(item)
		local hasSnap = WhisperPopDeferredItemHasSnapshot(item)
		local hasLine = type(lidPeek) == "number" and lidPeek > 0
		local forcePlay = false

		if not hasSnap then
			if hasLine then
				item.deferredLineFetchAttempts = (item.deferredLineFetchAttempts or 0) + 1
				local maxTotal = DEFERRED_LINE_FETCH_MAX + DEFERRED_LINE_FETCH_SLOW_EXTRA
				if item.restoredFromSV then
					maxTotal = maxTotal + DEFERRED_RESTORE_LINE_EXTRA
				end
				if item.deferredLineFetchAttempts <= maxTotal or (locked and not hasSnap) then
					WhisperPopRequeueDeferredItemTail(item)
					if locked and not hasSnap then
						needLockPoll = true
					end
					stalled = stalled + 1
					if stalled >= qStart then
						break
					end
				else
					if hasSnap or (type(item.capturedPlainText) == "string" and item.capturedPlainText ~= "")
						or (type(item.capturedPlainName) == "string" and not WhisperPopNameNeedsRetry(item.capturedPlainName)) then
						forcePlay = true
					else
						item.deferredLineFetchAttempts = nil
						WhisperPopRequeueDeferredItemTail(item)
						needUnlockDelay = true
						stalled = stalled + 1
						if stalled >= qStart then
							break
						end
					end
				end
			elseif locked then
				if not hasLine then
					item.deferredLockOpaquePolls = (item.deferredLockOpaquePolls or 0) + 1
				end
				local opaqueExhausted = item.deferredLockOpaquePolls and item.deferredLockOpaquePolls > DEFERRED_OPAQUE_LOCK_POLL_MAX
				if opaqueExhausted then
					forcePlay = hasSnap
						or (type(item.capturedPlainText) == "string" and item.capturedPlainText ~= "")
						or (type(item.capturedPlainName) == "string" and not WhisperPopNameNeedsRetry(item.capturedPlainName))
					if not forcePlay then
						stalled = stalled + 1
						if stalled >= qStart then
							break
						end
					end
				else
					WhisperPopRequeueDeferredItemTail(item)
					needLockPoll = true
					stalled = stalled + 1
					if stalled >= qStart then
						break
					end
				end
			else
				item.deferredUnlockNoLinePolls = (item.deferredUnlockNoLinePolls or 0) + 1
				if item.deferredUnlockNoLinePolls <= DEFERRED_UNLOCK_NO_LINE_RETRIES then
					WhisperPopRequeueDeferredItemTail(item)
					needUnlockDelay = true
					stalled = stalled + 1
					if stalled >= qStart then
						break
					end
				else
					if item.capturedPlainText ~= nil or item.capturedPlainName ~= nil then
						forcePlay = true
					else
						stalled = stalled + 1
						if stalled >= qStart then
							break
						end
					end
				end
			end
		end

		if hasSnap or forcePlay then
			WhisperPopApplyCapturedPlainToItem(item)
			WhisperPopInvokeDeferredItemHandler(item)
			processed = processed + 1
			stalled = 0
		end
	end

	if #deferredWhisperEvents == 0 then
		deferredLockPollPending = false
		WhisperPopPlayDeferredBatchSoundIfNeeded()
		deferredWhisperFrame:Hide()
		return
	end

	-- 泵尾调度（间隔见文件头 DEFERRED_*；勿对 stall 用 After(0)）：
	-- processed>0 且队列未空 → 1s 续泵（非漏记；原 needSoonPump+After(0) 未真正调度已废除）
	-- needLockPoll → 1s；needUnlockDelay / stalled → 1s（DEFERRED_UNLOCK / STALL）
	if processed > 0 and #deferredWhisperEvents > 0 then
		if C_Timer and C_Timer.After then
			C_Timer.After(DEFERRED_RETRY_INTERVAL_SEC, WhisperPop_RequestDeferredPump)
		else
			WhisperPop_RequestDeferredPump()
		end
	elseif needLockPoll and not deferredLockPollPending then
		deferredLockPollPending = true
		if C_Timer and C_Timer.After then
			C_Timer.After(DEFERRED_LOCK_POLL_SEC, function()
				deferredLockPollPending = false
				WhisperPop_DeferredPump()
			end)
		else
			deferredLockPollPending = false
			deferredWhisperFrame.wpLockPollAcc = 0
			deferredWhisperFrame:SetScript("OnUpdate", function(self, elapsed)
				if #deferredWhisperEvents == 0 then
					self:SetScript("OnUpdate", nil)
					self.wpLockPollAcc = nil
					self:Hide()
					return
				end
				self.wpLockPollAcc = (self.wpLockPollAcc or 0) + (elapsed or 0)
				if self.wpLockPollAcc < DEFERRED_LOCK_POLL_SEC then
					return
				end
				self.wpLockPollAcc = 0
				WhisperPop_DeferredPump()
			end)
		end
	elseif needUnlockDelay then
		if C_Timer and C_Timer.After then
			C_Timer.After(DEFERRED_UNLOCK_NO_LINE_DELAY_SEC, WhisperPop_RequestDeferredPump)
		else
			WhisperPop_RequestDeferredPump()
		end
	elseif stalled > 0 and not (needLockPoll and deferredLockPollPending) then
		if C_Timer and C_Timer.After then
			C_Timer.After(DEFERRED_STALL_RETRY_SEC, WhisperPop_RequestDeferredPump)
		else
			WhisperPop_RequestDeferredPump()
		end
	end
end

function addon:EnqueueDeferredWhisperEvent(event, ...)
	local hadLockAtEntry = WhisperPopInChatMessagingLockdown()
	local hadSecret = WhisperPopHasAnySecretValues(...)
	local capturedPlainText, capturedPlainName = WhisperPopCapturePlainFromVarargs(...)
	local captureLineID = WhisperPopCaptureChatLineIdFromVarargs(...)
	local args, n = WhisperPopSanitizeChatArgs(...)
	WhisperPopMergeCapturedPlainIntoArgs(args, capturedPlainText, capturedPlainName)
	if captureLineID then
		args[11] = captureLineID
		local nUse = math.max(tonumber(n) or 18, 18)
		WhisperPopRefreshChatArgsOnce(event, args, nUse)
	end
	if event == "CHAT_MSG_WHISPER_INFORM" then
		local lidI = captureLineID
		if (not lidI or lidI <= 0) and args[11] then
			lidI = tonumber(args[11])
		end
		if type(lidI) == "number" and lidI > 0 then
			addon._wpLastDeferredInformLineId = lidI
			addon._wpLastDeferredInformLineTime = time()
		end
	end
	if event == "CHAT_MSG_WHISPER" and (hadLockAtEntry or hadSecret or WhisperPopInChatMessagingLockdown()) then
		if (not captureLineID or captureLineID <= 0) and not WhisperPopSerializedArgsUseful(args) then
			local bor
			for qi = #deferredWhisperEvents, 1, -1 do
				local o = deferredWhisperEvents[qi]
				if type(o) == "table" and o.event == "CHAT_MSG_WHISPER_INFORM" then
					local lid = o.args and o.args[11]
					if type(lid) ~= "number" or lid <= 0 then
						lid = o.captureLineID
					end
					if type(lid) ~= "number" then
						lid = tonumber(lid)
					end
					if type(lid) == "number" and lid > 0 then
						bor = lid
						break
					end
				end
			end
			local usedGlobal
			if not bor then
				local li = addon._wpLastDeferredInformLineId
				local lt = addon._wpLastDeferredInformLineTime
				if type(li) == "number" and li > 0 and type(lt) == "number" and (time() - lt) <= 2 then
					bor = li
					usedGlobal = true
				end
			end
			if type(bor) == "number" and bor > 0 then
				captureLineID = bor
				args[11] = bor
				local nUse = math.max(tonumber(n) or 18, 18)
				WhisperPopRefreshChatArgsOnce(event, args, nUse)
				if usedGlobal then
					addon._wpLastDeferredInformLineId = nil
					addon._wpLastDeferredInformLineTime = nil
				end
			end
		end
	end
	if not captureLineID and not WhisperPopSerializedArgsUseful(args) then
		if not (hadLockAtEntry or hadSecret or WhisperPopInChatMessagingLockdown()) then
			return
		end
	end
	tinsert(deferredWhisperEvents, {
		event = event,
		args = args,
		n = n,
		captureLineID = captureLineID,
		capturedPlainText = capturedPlainText,
		capturedPlainName = capturedPlainName,
	})
	WhisperPop_RequestDeferredPump()
end

--- /reload + PLAYER_LOGOUT: persist deferred queue; Refresh before copy when possible.
local DEFERRED_WHISPER_SAVE_CAP = 96

function addon:SaveDeferredWhisperQueueToDB()
	local db = self.db
	if not db then
		return
	end
	if #deferredWhisperEvents == 0 then
		db.pendingDeferredWhispers = nil
		return
	end
	local pending = {}
	local lim = math.min(#deferredWhisperEvents, DEFERRED_WHISPER_SAVE_CAP)
	for i = 1, lim do
		local item = deferredWhisperEvents[i]
		if type(item.event) ~= "string" then
			-- skip
		else
			local n = math.max(tonumber(item.n) or 18, 18)
			if not WhisperPopDeferredItemHasSnapshot(item) then
				local lidPeek = item.args and item.args[11]
				if type(lidPeek) ~= "number" or lidPeek <= 0 then
					lidPeek = item.captureLineID
					if type(lidPeek) == "number" and lidPeek > 0 then
						item.args[11] = lidPeek
					end
				end
				if type(lidPeek) == "number" and lidPeek > 0 then
					WhisperPopRefreshDeferredChatArgs(item.event, item.args, n, item)
				end
			end
			local lid = item.captureLineID
			if type(lid) ~= "number" or lid <= 0 then
				lid = item.args and item.args[11]
			end
			if type(lid) ~= "number" then
				lid = tonumber(lid)
			end
			WhisperPopApplyCapturedPlainToItem(item)
			local savedArgs = WhisperPopCopyArgsForSave(item.args, n) or {}
			-- Persist every queued row across /reload. In M+ many rows have no serializable text yet but
			-- still carry lineID after refresh; rows with neither cannot be recovered after reload anyway.
			local row = {
				event = item.event,
				lineID = (lid and lid > 0) and lid or nil,
				n = n,
				args = savedArgs,
			}
			if type(item.capturedPlainText) == "string" and item.capturedPlainText ~= "" then
				row.capturedPlainText = item.capturedPlainText
			end
			if type(item.capturedPlainName) == "string" and item.capturedPlainName ~= "" then
				row.capturedPlainName = item.capturedPlainName
			end
			pending[#pending + 1] = row
		end
	end
	db.pendingDeferredWhispers = #pending > 0 and pending or nil
end

function addon:RestoreDeferredWhisperQueueFromDB()
	local db = self.db
	if not db or type(db.pendingDeferredWhispers) ~= "table" then
		return
	end
	local saved = db.pendingDeferredWhispers
	db.pendingDeferredWhispers = nil
	for i = #saved, 1, -1 do
		local s = saved[i]
		if type(s) == "table" and type(s.event) == "string" then
			local n = math.max(tonumber(s.n) or 18, 18)
			local lid = s.lineID
			if type(lid) ~= "number" then
				lid = tonumber(lid)
			end
			local args = {}
			for j = 1, n do
				args[j] = ""
			end
			if type(s.args) == "table" then
				for j = 1, n do
					local v = s.args[j]
					if v ~= nil then
						args[j] = v
					end
				end
			end
			if lid and lid > 0 then
				args[11] = lid
			end
			local restored = {
				event = s.event,
				args = args,
				n = n,
				captureLineID = (lid and lid > 0) and lid or nil,
				restoredFromSV = true,
			}
			if type(s.capturedPlainText) == "string" and s.capturedPlainText ~= "" then
				restored.capturedPlainText = s.capturedPlainText
			end
			if type(s.capturedPlainName) == "string" and s.capturedPlainName ~= "" then
				restored.capturedPlainName = s.capturedPlainName
			end
			WhisperPopMergeCapturedPlainIntoArgs(restored.args, restored.capturedPlainText, restored.capturedPlainName)
			tinsert(deferredWhisperEvents, 1, restored)
		end
	end
	if #deferredWhisperEvents > 0 then
		WhisperPop_RequestDeferredPump()
		if C_Timer and C_Timer.After then
			for _, sec in ipairs(DEFERRED_RESTORE_PUMP_AFTER_SEC) do
				C_Timer.After(sec, function()
					if addon.db and #deferredWhisperEvents > 0 then
						WhisperPop_RequestDeferredPump()
					end
				end)
			end
		end
	end
end

addon:RegisterDB("WhisperPopDB")
addon:RegisterSlashCmd("whisperpop", "wp") -- Type /whisperpop or /wp to toggle the frame

addon.ICON_FILE = "Interface\\Icons\\INV_Letter_05"
addon.SOUND_PRESET_FILES = {
	"Interface\\AddOns\\WhisperPop\\Media\\Sounds\\wp_preset1.ogg",
	"Interface\\AddOns\\WhisperPop\\Media\\Sounds\\wp_preset2.ogg",
	"Interface\\AddOns\\WhisperPop\\Media\\Sounds\\wp_preset3.ogg",
	"Interface\\AddOns\\WhisperPop\\Media\\Sounds\\wp_preset4.ogg",
	"Interface\\AddOns\\WhisperPop\\Media\\Sounds\\wp_preset5.ogg",
}
addon.BACKGROUND = "Interface\\DialogFrame\\UI-DialogBox-Background"
addon.BORDER = "Interface\\Tooltips\\UI-Tooltip-Border"
addon.UI_STYLE_CLASSIC = "classic"
addon.UI_STYLE_BORDERLESS = "borderless"

addon.MAX_MESSAGES = 500 -- Maximum messages stored for each conversation

-- Message are saved in format of: [1/0][timestamp][contents]
-- The first char is 1 if this message is inform, 0 otherwise
addon.TimestampFormat = {
	[1] = "%m/%d %H:%M",
	[2] = "%m/%d %H:%M:%S",
	[3] = "%m/%d/%y %H:%M",
	[4] = "%m/%d/%y %H:%M:%S",
	[5] = "%y/%m/%d %H:%M",
	[6] = "%y/%m/%d %H:%M:%S",
	[7] = "%Y/%m/%d %H:%M",
	[8] = "%Y/%m/%d %H:%M:%S",
	[9] = "%m-%d %H:%M",
	[10] = "%m-%d %H:%M:%S",
	[11] = "%Y-%m-%d %H:%M",
	[12] = "%Y-%m-%d %H:%M:%S",
}

function addon:FormatTimestamp(timeFormat, timestamp)
	return format("[%s]", date(timeFormat, timestamp))
end

function addon:GetFormattedTime(timestamp)
	return addon:FormatTimestamp(addon.TimestampFormat[self.db.timeFormat], timestamp)
end

function addon:EncodeMessage(text, inform)
	local timestamp = time()
	local formattedTime = addon:GetFormattedTime(timestamp)
	return (inform and "1" or "0")..format("[T%d]", timestamp)..(text or ""), formattedTime
end

function addon:DecodeMessage(line)
	if type(line) ~= "string" then
		return
	end

	local inform
	if strsub(line, 1, 1) == "1" then
		inform = 1
	end

	local timestamp, text = strmatch(line, "^[01]%[T(%d-)%](.*)")
	local formattedTime = timestamp and addon:GetFormattedTime(timestamp)
	if not formattedTime then
		formattedTime, text = strmatch(line, "^[01](%[.-%])(.*)")
	end
	if not formattedTime then
		formattedTime = strsub(line, 2, 17)
		text = strsub(line, 18)
	end

	return text, inform, formattedTime
end

addon._searchFilteredDisplay = {}

function addon:GetActiveSearchNeedle()
	local n = self._searchNeedleLower
	if type(n) == "string" and n ~= "" then
		return n
	end
end

function addon:HistoryEntryMatchesSearch(data, needleLower)
	if not needleLower or needleLower == "" or not data or type(data.messages) ~= "table" then
		return false
	end
	for i = 1, #data.messages do
		local text = select(1, self:DecodeMessage(data.messages[i]))
		if type(text) == "string" then
			local low = strlower(text)
			if strfind(low, needleLower, 1, true) then
				return true
			end
		end
	end
	return false
end

function addon:RefreshSearchListBinding()
	local fr = self.frame
	local list = fr and fr.list
	local db = self.db
	if not list or not db or type(db.history) ~= "table" then
		return
	end
	local needle = self._searchNeedleLower
	if type(needle) ~= "string" or needle == "" then
		if list.listData ~= db.history then
			list:BindDataList(db.history)
		else
			list:RefreshContents()
		end
	else
		wipe(self._searchFilteredDisplay)
		local hist = db.history
		for i = 1, #hist do
			local data = hist[i]
			if self:HistoryEntryMatchesSearch(data, needle) then
				tinsert(self._searchFilteredDisplay, data)
			end
		end
		if list.listData ~= self._searchFilteredDisplay then
			list:BindDataList(self._searchFilteredDisplay)
		else
			list:RefreshContents()
		end
	end
end

function addon:PruneExpiredHistory()
	local cfg = self.DB_DEFAULTS.saveDays
	local days = self.db.saveDays
	if type(days) ~= "number" or days < cfg.min or days > cfg.max then
		days = cfg.default
		self.db.saveDays = days
	end

	local cutoff = time() - days * 86400
	local history = self.db.history
	local changed

	for hi = #history, 1, -1 do
		local data = history[hi]
		if type(data) == "table" and type(data.messages) == "table" and not data.protected then
			for i = #data.messages, 1, -1 do
				local line = data.messages[i]
				local msgTime = type(line) == "string" and tonumber(strmatch(line, "^[01]%[T(%d+)%]"))
				if msgTime and msgTime < cutoff then
					tremove(data.messages, i)
					changed = true
				end
			end
			if #data.messages == 0 then
				tremove(history, hi)
				changed = true
			end
		end
	end

	if changed then
		self:BroadcastEvent("OnListUpdate")
	end
end

-- Splits name-realm
function addon:ParseNameRealm(text)
	if type(text) == "string" then
		local _, _, name, realm = strfind(text, "(.+)%-(.+)")
		return name or text, realm
	end
end

function addon:GetDisplayName(text, forceRealm)
	if self:IsBattleTag(text) then
		local _, name = self:GetBNInfoFromTag(text)
		return name or text
	end

	if forceRealm then
		return text
	end

	local name, realm = self:ParseNameRealm(text)
	if self.db.showRealm then
		if self.db.foreignOnly and realm == self.normalizedRealm then
			return name
		else
			return text
		end
	else
		return name
	end
end

function addon:GetBNInfoFromTag(tag)
	if type(tag) ~= "string" then
		return
	end

	for i = 1, BNGetNumFriends() do
		local id, name, battleTag, _, _, _, _, online = BNGetFriendInfo(i)
		if battleTag == tag then
			return id, name, online, i
		end
	end
end

function addon:IsBattleTag(name)
	if type(name) == "string" then
		local _, _, prefix, surfix = strfind(name, "(.+)#(%d+)$")
		return prefix, surfix
	end
end

function addon:GetNewMessage()
	for i = 1, #self.db.history do
		local data = self.db.history[i]
		if data.new then
			return addon:GetDisplayName(data.name), data.class, addon:DecodeMessage(data.messages[1])
		end
	end
end

function addon:ClearAllNews()
	for i = 1, #self.db.history do
		local data = self.db.history[i]
		if data.new then
			data.new = nil
		end
	end

	self:BroadcastEvent("OnListUpdate")
end

function addon:GetNewNames()
	local newNames = {}
	for i = 1, #self.db.history do
		local data = self.db.history[i]
		if data.new then
			tinsert(newNames, addon:GetDisplayName(data.name))
		end
	end
	return newNames
end

function addon:AddTooltipText(tooltip)
	local gold = GOLD_FONT_COLOR
	local gr, gg, gb = 1, 0.82, 0
	if gold then
		if gold.GetRGB then
			gr, gg, gb = gold:GetRGB()
		elseif gold.r then
			gr, gg, gb = gold.r, gold.g, gold.b
		end
	end
	local newNames = self:GetNewNames()
	if newNames[1] then
		tooltip:AddLine(L["new messages from"], gr, gg, gb, true)
		for i = 1, #newNames do
			tooltip:AddLine(newNames[i], 0, 1, 0, true)
		end
	else
		tooltip:AddLine(L["no new messages"], gr, gg, gb, true)
	end
end

function addon:BattlenetInvite(bnId, bnIndex)
	if FriendsFrame_BattlenetInviteByIndex then
		FriendsFrame_BattlenetInviteByIndex(bnIndex)
	elseif FriendsFrame_BattlenetInvite then
		FriendsFrame_BattlenetInvite(nil, bnId)
	end
end

-- Lightweight player context menu for the whisper list (avoids FriendsFrame_ShowDropdown taint on retail 12.x).
local playerContextMenu

local function WhisperPop_IsNameIgnored(playerName)
	if type(playerName) ~= "string" or not (C_FriendList and C_FriendList.GetNumIgnores and C_FriendList.GetIgnoreName) then
		return false
	end
	local target = Ambiguate(playerName, "none")
	local n = C_FriendList.GetNumIgnores()
	for i = 1, n do
		local ign = C_FriendList.GetIgnoreName(i)
		if ign and ign ~= "" and Ambiguate(ign, "none") == target then
			return true
		end
	end
	return false
end

local function WhisperPop_PlayerContextMenu_Init()
	local name = playerContextMenu and playerContextMenu.whisperPopName
	if type(name) ~= "string" then
		return
	end
	local L = addon.L

	local function addButton(text, fn)
		local info = UIDropDownMenu_CreateInfo()
		info.text = text
		info.notCheckable = 1
		info.topPadding = 3 -- extra vertical gap between menu lines (retail UIDropDownMenu)
		info.leftPadding = 2 -- slight horizontal breathing room for text
		info.func = fn
		UIDropDownMenu_AddButton(info)
	end

	addButton(L["context whisper"], function()
		addon:HandleAction(name, "WHISPER")
	end)
	addButton(L["context invite"], function()
		addon:HandleAction(name, "INVITE")
	end)
	addButton(L["context who"], function()
		addon:HandleAction(name, "WHO")
	end)
	addButton(L["context insert name to chat"], function()
		ChatFrame_OpenChat(name .. " ", SELECTED_DOCK_FRAME)
	end)
	if C_FriendList and C_FriendList.AddOrDelIgnore then
		if WhisperPop_IsNameIgnored(name) then
			addButton(L["context unignore"], function()
				addon:HandleAction(name, "IGNORE")
			end)
		else
			addButton(L["context ignore"], function()
				addon:HandleAction(name, "IGNORE")
			end)
		end
	end
end

function addon:ShowWhisperListContextMenu(name)
	if type(name) ~= "string" then
		return
	end
	if not (UIDropDownMenu_Initialize and ToggleDropDownMenu and UIDropDownMenu_CreateInfo) then
		ChatFrame_OpenChat(name .. " ", SELECTED_DOCK_FRAME)
		return
	end
	if not playerContextMenu then
		playerContextMenu = CreateFrame("Frame", "WhisperPopPlayerContextMenu", UIParent, "UIDropDownMenuTemplate")
	end
	if CloseMenus then
		CloseMenus()
	end
	playerContextMenu.whisperPopName = name
	UIDropDownMenu_Initialize(playerContextMenu, WhisperPop_PlayerContextMenu_Init, "MENU")
	ToggleDropDownMenu(1, nil, playerContextMenu, "cursor", 0, 0)
end

function addon:HandleAction(name, action)
	if type(name) ~= "string" then
		return
	end

	local bnId, bnName, bnOnline, bnIndex
	if addon:IsBattleTag(name) then
		bnId, bnName, bnOnline, bnIndex = self:GetBNInfoFromTag(name)
		if not bnId then
			return
		end
	end

	if action == "MENU" then
		if bnId then
			WhisperPop_DeferMenu(function()
				FriendsFrame_ShowBNDropdown(bnName, bnOnline, nil, nil, nil, 1, bnId)
			end)
		else
			self:ShowWhisperListContextMenu(name)
		end

	elseif action == "WHO" then
		if not bnId then
			SendWho(WHO_TAG_EXACT..name)
		end

	elseif action == "INVITE" then
		if bnId and bnIndex then
			self:BattlenetInvite(bnId, bnIndex)
		else
			InviteUnit(name)
		end

	elseif action == "WHISPER" then
		if bnName then
			ChatFrame_SendBNetTell(bnName)
		else
			ChatFrame_SendTell(name, SELECTED_DOCK_FRAME)
		end

	elseif action == "IGNORE" then
		if not bnId and C_FriendList and C_FriendList.AddOrDelIgnore then
			C_FriendList.AddOrDelIgnore(name)
		end
	end
end

addon.SOUND_OUTPUT_CHANNELS = { "Master", "Music", "SFX", "Ambience", "Dialog" }

addon.FRAME_STRATA_CHOICES = { "LOW", "MEDIUM", "HIGH", "DIALOG", "TOOLTIP" }
addon.FRAME_STRATA_DEFAULT = "MEDIUM"

function addon:IsValidFrameStrata(str)
	if type(str) ~= "string" then
		return false
	end
	for _, s in ipairs(self.FRAME_STRATA_CHOICES) do
		if str == s then
			return true
		end
	end
	return false
end

function addon:GetFrameStrataSetting()
	local s = self.db and self.db.frameStrata
	if self:IsValidFrameStrata(s) then
		return s
	end
	return self.FRAME_STRATA_DEFAULT
end

function addon:ApplyGameplayFrameStrata()
	local strata = self:GetFrameStrataSetting()
	local function applyStrata(f)
		if f and f.SetFrameStrata then
			pcall(f.SetFrameStrata, f, strata)
		end
	end

	local function applyToplevel(f, enabled)
		if f and f.SetToplevel then
			pcall(f.SetToplevel, f, enabled and true or false)
		end
	end
	applyStrata(self.notifyButton)
	applyStrata(self.frame)
	applyStrata(self.messageFrame)
	local list = self.messageFrame and self.messageFrame.messageScrollList
	applyStrata(list)


	applyToplevel(self.frame, true)
	applyToplevel(self.messageFrame, false)
	applyToplevel(list, false)

	applyToplevel(self.notifyButton, false)
end

addon:RegisterOptionCallback("frameStrata", function()
	addon:ApplyGameplayFrameStrata()
end)

function addon:GetSoundOutputChannel()
	local ch = self.db and self.db.soundChannel
	if type(ch) == "string" then
		for _, c in ipairs(self.SOUND_OUTPUT_CHANNELS) do
			if ch == c then
				return ch
			end
		end
	end
	return "Master"
end

function addon:PlaySound()
	local preset = self.db.soundPreset
	if type(preset) ~= "number" or preset < 1 or preset > #self.SOUND_PRESET_FILES then
		preset = 1
	end
	local file = self.SOUND_PRESET_FILES[preset]
	if file then
		PlaySoundFile(file, self:GetSoundOutputChannel())
	end
end

--- DB_VERSION = saved schema (not toc display); bump when migration needed.
addon.DB_VERSION = 5.2

addon.DB_BOOL_DEFAULTS = {
	notifyButton = true,
	notifyIconFlash = true,
	locked = false,
	receiveOnly = false,
	clearUnreadOnOutgoingWhisper = false,
	sound = true,
	showRealm = true,
	foreignOnly = true,
	ignoreTags = false,
	applyFilters = false,
	messageHoverLinks = true,
	deleteConfirm = true,
	time = true,
}

addon.DB_DEFAULTS = {
	timeFormat = 2,
	buttonScale = { min = 50, max = 200, step = 5, default = 100 },
	listScale = { min = 50, max = 200, step = 5, default = 100 },
	listWidth = { min = 100, max = 400, step = 5, default = 200 },
	listHeight = { min = 100, max = 640, step = 20, default = 250 },--lnui
	listWheelLines = { min = 1, max = 20, step = 1, default = 3 },
	messageWheelLines = { min = 1, max = 20, step = 1, default = 3 },
	soundPreset = { min = 1, max = 5, step = 1, default = 1 },
	saveDays = { min = 1, max = 9999, default = 1095 },
	contentFontObject = "ChatFontNormal",
}

function addon:EnsureBoolFields(db)
	if type(db) ~= "table" then
		return
	end
	for key, defaultVal in pairs(self.DB_BOOL_DEFAULTS) do
		local v = db[key]
		if v == true or v == false then
			db[key] = v
		elseif v == 1 then
			db[key] = true
		elseif v == 0 then
			db[key] = false
		elseif v == nil then
			db[key] = defaultVal
		else
			db[key] = defaultVal
		end
	end
	db.save = nil
end

addon.CONTENT_FONT_CANDIDATES = {
	"ChatFontNormal",
	"ChatFontSmall",
	"GameFontNormal",
	"NumberFontNormalSmall",
	"QuestFont",
}

addon.CONTENT_FONT_PROTECT_FALLBACK = {
	NumberFontNormalSmall = true,
}

function addon:GetFontObjectForProtectLabel()
	local key = self:GetContentFontObjectName()
	if self.CONTENT_FONT_PROTECT_FALLBACK[key] then
		return _G.GameFontNormalSmall or _G.GameFontNormal
	end
	return _G[key]
end

function addon:InitContentFontRegistry()
	if type(self.CONTENT_FONT_KEYS) == "table" and #self.CONTENT_FONT_KEYS > 0 then
		return
	end
	self.CONTENT_FONT_KEYS = {}
	for _, name in ipairs(self.CONTENT_FONT_CANDIDATES) do
		if type(name) == "string" and _G[name] then
			tinsert(self.CONTENT_FONT_KEYS, name)
		end
	end
	if #self.CONTENT_FONT_KEYS == 0 then
		tinsert(self.CONTENT_FONT_KEYS, "GameFontNormal")
	end
	local def = self.DB_DEFAULTS.contentFontObject
	local defOk
	if type(def) == "string" then
		for _, k in ipairs(self.CONTENT_FONT_KEYS) do
			if k == def then
				defOk = true
				break
			end
		end
	end
	if not defOk then
		self.DB_DEFAULTS.contentFontObject = self.CONTENT_FONT_KEYS[1]
	end
end

function addon:IsRegisteredContentFont(name)
	if type(name) ~= "string" then
		return false
	end
	self:InitContentFontRegistry()
	for _, k in ipairs(self.CONTENT_FONT_KEYS) do
		if k == name then
			return true
		end
	end
	return false
end

function addon:GetContentFontObjectName()
	self:InitContentFontRegistry()
	local name = self.db and self.db.contentFontObject
	if self:IsRegisteredContentFont(name) then
		return name
	end
	return self.CONTENT_FONT_KEYS[1] or "GameFontNormal"
end

function addon:ApplyContentFontStyle(force)
	self:InitContentFontRegistry()
	local key = self:GetContentFontObjectName()
	if not force and self._appliedContentFontKey == key then
		return
	end

	local fontObj = _G[key]
	if not fontObj then
		return
	end

	local lst = self.frame and self.frame.list
	if lst and lst.listButtons then
		for _, btn in ipairs(lst.listButtons) do
			if btn.text and btn.text.SetFontObject then
				pcall(btn.text.SetFontObject, btn.text, fontObj)
			end
		end
		if lst.RefreshContents then
			lst:RefreshContents()
		end
	end

	local mf = self.messageFrame
	if mf then
		if mf.text and mf.text.SetFontObject then
			pcall(mf.text.SetFontObject, mf.text, fontObj)
		end
		local protectFontObj = self:GetFontObjectForProtectLabel()
		if mf.protectCheckText and mf.protectCheckText.SetFontObject and protectFontObj then
			pcall(mf.protectCheckText.SetFontObject, mf.protectCheckText, protectFontObj)
			--- WhisperPop message frame: protect label refresh only on font change (see MessageFrame comment).
			if mf.RefreshProtectCheckLabel then
				mf:RefreshProtectCheckLabel()
			end
		end
		local smf = mf.messageScrollList
		if smf and smf.SetFontObject then
			pcall(smf.SetFontObject, smf, fontObj)
			if smf.SetJustifyH then
				pcall(smf.SetJustifyH, smf, "LEFT")
			end
			if smf.SetIndentedWordWrap then
				pcall(smf.SetIndentedWordWrap, smf, false)
			end
		end
		if mf.messageTestFont and mf.messageTestFont.SetFontObject then
			pcall(mf.messageTestFont.SetFontObject, mf.messageTestFont, fontObj)
		end
		if mf.RecalculateContentFontMetrics then
			mf:RecalculateContentFontMetrics()
		end
		if mf:IsShown() and mf.GetCurrentConversationData and mf.CommitConversationMessages then
			local data = mf:GetCurrentConversationData()
			if data then
				mf:CommitConversationMessages(data)
			end
		end
	end

	self._appliedContentFontKey = key
end

function addon:OnInitialize(db, firstTime)
	if type(db.version) ~= "number" or db.version < self.DB_VERSION then
		self:EnsureBoolFields(db)
		db.version = self.DB_VERSION
	end

	if not db.timeFormat then
		db.timeFormat = addon.DB_DEFAULTS.timeFormat
	end

	self:InitContentFontRegistry()
	if not self:IsRegisteredContentFont(db.contentFontObject) then
		db.contentFontObject = self.CONTENT_FONT_KEYS[1] or self.DB_DEFAULTS.contentFontObject
	end

	do
		local ch = db.soundChannel
		local ok
		if type(ch) == "string" then
			for _, c in ipairs(self.SOUND_OUTPUT_CHANNELS) do
				if ch == c then
					ok = true
					break
				end
			end
		end
		if not ok then
			db.soundChannel = "Master"
		end
	end

	if not self:IsValidFrameStrata(db.frameStrata) then
		db.frameStrata = self.FRAME_STRATA_DEFAULT
	end

	--- UI style / backdrop colors (WhisperPopAppearance.lua)
	do
		local bs = db.uiStyle
		if bs == 2 or bs == "2" then
			db.uiStyle = addon.UI_STYLE_BORDERLESS
		elseif bs ~= addon.UI_STYLE_BORDERLESS and bs ~= addon.UI_STYLE_CLASSIC then
			db.uiStyle = addon.UI_STYLE_CLASSIC
		end
		for _, key in ipairs({ "appearanceMain", "appearancePreview", "appearanceBorder" }) do
			if type(db[key]) ~= "table" then
				local d = addon.APPEARANCE_COLOR_DEFAULTS and addon.APPEARANCE_COLOR_DEFAULTS[key]
				if type(d) == "table" then
					db[key] = { d[1], d[2], d[3], d[4] }
				else
					db[key] = { 1, 1, 1, 1 }
				end
			else
				local n = addon:NormalizeAppearanceRGBA(db[key])
				db[key][1], db[key][2], db[key][3], db[key][4] = n[1], n[2], n[3], n[4]
			end
		end
	end

	for _, key in ipairs({ "buttonScale", "listScale", "listWidth", "listHeight", "listWheelLines", "messageWheelLines", "soundPreset", "saveDays" }) do
		local cfg = self.DB_DEFAULTS[key]
		if type(cfg) == "table" then
			if type(db[key]) ~= "number" or db[key] < cfg.min or db[key] > cfg.max then
				db[key] = cfg.default
			end
		end
	end

	if not db.positions then
		db.positions = {}
	end

	self:SetMovable(addon.frame)
	self:SetMovable(addon.notifyButton)

	if type(db.history) ~= "table" then
		db.history = {}
	end

	self:PruneExpiredHistory()

	if C_Timer and C_Timer.After then
		C_Timer.After(0.12, function()
			addon:RestoreDeferredWhisperQueueFromDB()
		end)
	else
		self:RestoreDeferredWhisperQueueFromDB()
	end

	self:BroadcastEvent("OnInitialize", db)

	for k in pairs(self.DB_BOOL_DEFAULTS) do
		self:BroadcastOptionEvent(k, db[k])
	end
	for k in pairs(self.DB_DEFAULTS) do
		self:BroadcastOptionEvent(k, db[k])
	end

	self:ApplyContentFontStyle()
	self:ApplyGameplayFrameStrata()

	self:RegisterEvent("PLAYER_LOGOUT")
	self:RegisterEvent("PLAYER_UNGHOST")
	self:RegisterEvent("PLAYER_ALIVE")
	self:RegisterEvent("PLAYER_REGEN_ENABLED")
	self:RegisterEvent("PLAYER_LEAVING_WORLD")
	self:RegisterEvent("CHAT_MSG_WHISPER")
	self:RegisterEvent("CHAT_MSG_WHISPER_INFORM")
	self:RegisterEvent("CHAT_MSG_BN_WHISPER")
	self:RegisterEvent("CHAT_MSG_BN_WHISPER_INFORM")

	self:BroadcastEvent("OnListUpdate")
end

function addon:PLAYER_LOGOUT()
	wipe(whisperPopEmptyBothLineIds)
	addon._wpLastDeferredInformLineId = nil
	addon._wpLastDeferredInformLineTime = nil
	addon._wpLastDeferredProcessedInformLineId = nil
	addon._wpLastDeferredProcessedInformLineTime = nil
	self:SaveDeferredWhisperQueueToDB()
end

function addon:WhisperPopDeferredPumpIfNeeded()
	if #deferredWhisperEvents > 0 then
		WhisperPop_ResetDeferredLineFetchAttempts()
		WhisperPop_RequestDeferredPump()
	end
end

function addon:WhisperPopDeferredPumpAfterRez()
	if #deferredWhisperEvents > 0 then
		WhisperPop_ResetDeferredLineFetchAttempts()
		WhisperPop_RequestDeferredPump()
	end
end

addon.PLAYER_UNGHOST = addon.WhisperPopDeferredPumpAfterRez
addon.PLAYER_ALIVE = addon.WhisperPopDeferredPumpAfterRez
addon.PLAYER_REGEN_ENABLED = addon.WhisperPopDeferredPumpIfNeeded
addon.PLAYER_LEAVING_WORLD = addon.WhisperPopDeferredPumpIfNeeded

function addon:Clear()
	local history = self.db.history
	for i = #history, 1, -1 do
		if not history[i].protected then
			tremove(history, i)
		end
	end

	self:BroadcastEvent("OnListUpdate")
	self:BroadcastEvent("OnClearMessages")
end

--- Reset settings to defaults; keeps history and pendingDeferredWhispers.
function addon:ResetAllSettingsExceptHistory()
	local db = self.db
	if type(db) ~= "table" then
		return
	end

	local history = type(db.history) == "table" and db.history or {}
	local pending = db.pendingDeferredWhispers
	db.history = history

	for k, v in pairs(self.DB_BOOL_DEFAULTS) do
		db[k] = v
	end

	db.version = self.DB_VERSION
	db.timeFormat = self.DB_DEFAULTS.timeFormat
	db.soundChannel = "Master"
	db.uiStyle = self.UI_STYLE_CLASSIC
	db.frameStrata = self.FRAME_STRATA_DEFAULT

	self:InitContentFontRegistry()
	db.contentFontObject = self.CONTENT_FONT_KEYS[1] or self.DB_DEFAULTS.contentFontObject

	for _, key in ipairs({ "buttonScale", "listScale", "listWidth", "listHeight", "listWheelLines", "messageWheelLines", "soundPreset", "saveDays" }) do
		local cfg = self.DB_DEFAULTS[key]
		if type(cfg) == "table" and type(cfg.default) == "number" then
			db[key] = cfg.default
		end
	end

	if type(db.positions) ~= "table" then
		db.positions = {}
	else
		wipe(db.positions)
	end

	db.pendingDeferredWhispers = pending

	if self.ResetAppearanceColors then
		self:ResetAppearanceColors()
	end

	for k in pairs(self.DB_BOOL_DEFAULTS) do
		self:BroadcastOptionEvent(k, db[k])
	end
	for k in pairs(self.DB_DEFAULTS) do
		self:BroadcastOptionEvent(k, db[k])
	end
	self:BroadcastOptionEvent("soundChannel", db.soundChannel)
	self:BroadcastOptionEvent("uiStyle", db.uiStyle)
	self:BroadcastOptionEvent("frameStrata", db.frameStrata)

	self:ApplyContentFontStyle(true)
	self:BroadcastEvent("OnResetFrames")
	self:BroadcastEvent("OnListUpdate")
	self:BroadcastEvent("OnSettingsResetExceptHistory")
end

function addon:FindPlayerData(name)
	for index, data in ipairs(self.db.history) do
		if data.name == name then
			return index, data
		end
	end
end

function addon:Delete(name)
	local index, data = self:FindPlayerData(name)
	if index and not data.protected then
		tremove(self.db.history, index)
		self:BroadcastEvent("OnListUpdate")
	end
end

function addon:ProcessChatMsg(name, class, text, inform, bnid)
	if issecretvalue and issecretvalue(text) then
		return
	end

	if type(text) ~= "string" or type(name) ~= "string" then
		return
	end

	if self.db.ignoreTags then
		local tag = strsub(text, 1, 1)
		if tag == "<" or tag == "[" then
			return
		end
	end

	if self:IsIgnoredMessage(text) then
		return -- Ignored message
	end

	-- Names must be in the "name-realm" format except for BN friends
	if class == "BN" then
		name = select(3, BNGetFriendInfoByID(bnid or 0)) -- Seemingly better than my original solution, credits to Warbaby
		if not name then
			return
		end
	elseif class ~= "GM" and class ~= "UNKNOWN" then
		local _, realm = self:ParseNameRealm(name)
		if not realm then
			name = name.."-"..self.normalizedRealm
		end
	end

	-- Add data into message history
	local index, data = self:FindPlayerData(name)
	if index then
		if index > 1 then
			tremove(self.db.history, index)
			tinsert(self.db.history, 1, data)
		end
	else
		data = { name = name, class = class }
		tinsert(self.db.history, 1, data)
	end

	if type(data.messages) ~= "table" then
		data.messages = {}
	end

	-- Incoming: mark unread until opened/hovered (MainFrame) or cleared (notify button / option below).
	if not inform then
		data.new = 1
		data.received = 1
	elseif self.db.clearUnreadOnOutgoingWhisper then
		-- `data` is only the session for this whisper's recipient (FindPlayerData above); never touch other rows.
		if data.new then
			data.new = nil
		end
	end

	local msg, timestamp = self:EncodeMessage(text, inform)
	tinsert(data.messages, msg)

	while #data.messages > self.MAX_MESSAGES do
		tremove(data.messages, 1)
	end

	self:BroadcastEvent("OnListUpdate")

	-- It's a new message (deferred replay: coalesce to one ding when the queue drains)
	if not inform and self.db.sound then
		if self._whisperDeferredPlayback then
			self._deferredBatchPlaySound = true
		else
			self:PlaySound()
		end
	end

	self:BroadcastEvent("OnNewMessage", name, class, text, inform, timestamp)
end

function addon:CHAT_MSG_WHISPER(...)
	if not self._whisperDeferredPlayback and WhisperPopShouldDeferChatEvent(...) then
		self:EnqueueDeferredWhisperEvent("CHAT_MSG_WHISPER", ...)
		return
	end

	local text, name, _, _, _, flag, _, _, _, _, _, guid, _, _, _, hide = ...
	if hide then
		return
	end

	if WhisperPopMsgBodyTrimmed(text) == "" then
		local okR, raw = pcall(select, 1, ...)
		local cap = okR and WhisperPopTryCapturePlainText(raw) or nil
		if cap and WhisperPopMsgBodyTrimmed(cap) ~= "" then
			text = cap
		end
	end
	if WhisperPopNameNeedsRetry(name) then
		local okN, rawN = pcall(select, 2, ...)
		local capN = okN and WhisperPopTryCapturePlainText(rawN) or nil
		if capN and not WhisperPopNameNeedsRetry(capN) then
			name = capN
		end
	end

	if flag ~= "GM" and flag ~= "DEV" and self.db.applyFilters then
		if ChatFrame_GetMessageEventFilters then
			local filtersList = ChatFrame_GetMessageEventFilters("CHAT_MSG_WHISPER")
			if filtersList then
				for _, func in ipairs(filtersList) do
					if type(func) == "function" and func(DEFAULT_CHAT_FRAME, "CHAT_MSG_WHISPER", ...) then
						return
					end
				end
			end
		elseif ChatFrameUtil and ChatFrameUtil.ProcessMessageEventFilters then
			if ChatFrameUtil.ProcessMessageEventFilters(DEFAULT_CHAT_FRAME, "CHAT_MSG_WHISPER", ...) then
				return
			end
		end
	end

	local lineID = WhisperPopCaptureChatLineIdFromVarargs(...)
	name = WhisperPopResolveSelfWhisperSessionName(name, guid)
	local fixedNow = WhisperPopTryResolveNameRealmFromGuid(guid)
	if type(fixedNow) == "string" and fixedNow ~= "" then
		name = fixedNow
	end

	if flag ~= "GM" and flag ~= "DEV" and WhisperPopNameNeedsRetry(name) then
		self:WhisperPopScheduleWhisperNameRetries("IN", text, name, flag, guid, false, 1, "CHAT_MSG_WHISPER", lineID)
		return
	end

	if flag ~= "GM" and flag ~= "DEV" and WhisperPopMsgBodyTrimmed(text) == "" then
		text, name, guid = WhisperPopMergeLineApiSnapshot("CHAT_MSG_WHISPER", lineID, text, name, guid)
		local fixed2 = WhisperPopTryResolveNameRealmFromGuid(guid)
		if type(fixed2) == "string" and fixed2 ~= "" then
			name = fixed2
		end
		name = WhisperPopResolveSelfWhisperSessionName(name, guid)
		if WhisperPopMsgBodyTrimmed(text) ~= "" then
			if flag == "GM" or flag == "DEV" then
				flag = "GM"
			else
				flag = select(2, GetPlayerInfoByGUID(WhisperPopGuidForApi(guid)))
			end
			self:ProcessChatMsg(name, flag, text, false)
			return
		end
		if flag == "GM" or flag == "DEV" then
			flag = "GM"
		else
			flag = select(2, GetPlayerInfoByGUID(WhisperPopGuidForApi(guid)))
		end
		self:ProcessChatMsg(name, flag, L["whisper snapshot body error"], false)
		return
	end

	if flag == "GM" or flag == "DEV" then
		flag = "GM"
	else
		flag = select(2, GetPlayerInfoByGUID(WhisperPopGuidForApi(guid)))
	end

	self:ProcessChatMsg(name, flag, text)
end

function addon:CHAT_MSG_WHISPER_INFORM(...)
	if not self._whisperDeferredPlayback and WhisperPopShouldDeferChatEvent(...) then
		self:EnqueueDeferredWhisperEvent("CHAT_MSG_WHISPER_INFORM", ...)
		return
	end

	local text, name, _, _, _, flag, _, _, _, _, _, guid = ...
	if WhisperPopMsgBodyTrimmed(text) == "" then
		local okR, raw = pcall(select, 1, ...)
		local cap = okR and WhisperPopTryCapturePlainText(raw) or nil
		if cap and WhisperPopMsgBodyTrimmed(cap) ~= "" then
			text = cap
		end
	end
	if WhisperPopNameNeedsRetry(name) then
		local okN, rawN = pcall(select, 2, ...)
		local capN = okN and WhisperPopTryCapturePlainText(rawN) or nil
		if capN and not WhisperPopNameNeedsRetry(capN) then
			name = capN
		end
	end
	local lineID = WhisperPopCaptureChatLineIdFromVarargs(...)
	name = WhisperPopResolveSelfWhisperSessionName(name, guid)
	local fixedNow = WhisperPopTryResolveNameRealmFromGuid(guid)
	if type(fixedNow) == "string" and fixedNow ~= "" then
		name = fixedNow
	end

	if not (flag == "GM" or flag == "DEV" or (GMChatFrame_IsGM and GMChatFrame_IsGM(name))) and WhisperPopNameNeedsRetry(name) then
		self:WhisperPopScheduleWhisperNameRetries("OUT", text, name, flag, guid, true, 1, "CHAT_MSG_WHISPER_INFORM", lineID)
		return
	end

	if not (flag == "GM" or flag == "DEV" or (GMChatFrame_IsGM and GMChatFrame_IsGM(name))) and WhisperPopMsgBodyTrimmed(text) == "" then
		text, name, guid = WhisperPopMergeLineApiSnapshot("CHAT_MSG_WHISPER_INFORM", lineID, text, name, guid)
		local fixed2 = WhisperPopTryResolveNameRealmFromGuid(guid)
		if type(fixed2) == "string" and fixed2 ~= "" then
			name = fixed2
		end
		name = WhisperPopResolveSelfWhisperSessionName(name, guid)
		if WhisperPopMsgBodyTrimmed(text) ~= "" then
			if flag == "GM" or flag == "DEV" or (GMChatFrame_IsGM and GMChatFrame_IsGM(name)) then
				flag = "GM"
			else
				flag = select(2, GetPlayerInfoByGUID(WhisperPopGuidForApi(guid)))
			end
			self:ProcessChatMsg(name, flag, text, 1)
			return
		end
		if flag == "GM" or flag == "DEV" or (GMChatFrame_IsGM and GMChatFrame_IsGM(name)) then
			flag = "GM"
		else
			flag = select(2, GetPlayerInfoByGUID(WhisperPopGuidForApi(guid)))
		end
		self:ProcessChatMsg(name, flag, L["whisper snapshot body error"], true)
		return
	end

	if flag == "GM" or flag == "DEV" or (GMChatFrame_IsGM and GMChatFrame_IsGM(name)) then
		flag = "GM"
	else
		flag = select(2, GetPlayerInfoByGUID(WhisperPopGuidForApi(guid)))
	end

	self:ProcessChatMsg(name, flag, text, 1)
end

function addon:CHAT_MSG_BN_WHISPER(...)
	if not self._whisperDeferredPlayback and WhisperPopShouldDeferChatEvent(...) then
		self:EnqueueDeferredWhisperEvent("CHAT_MSG_BN_WHISPER", ...)
		return
	end

	local text, name, _, _, _, _, _, _, _, _, _, _, bnid = ...
	self:ProcessChatMsg(name, "BN", text, nil, bnid)
end

function addon:CHAT_MSG_BN_WHISPER_INFORM(...)
	if not self._whisperDeferredPlayback and WhisperPopShouldDeferChatEvent(...) then
		self:EnqueueDeferredWhisperEvent("CHAT_MSG_BN_WHISPER_INFORM", ...)
		return
	end

	local text, name, _, _, _, _, _, _, _, _, _, _, bnid = ...
	self:ProcessChatMsg(name, "BN", text, 1, bnid)
end

------------------------------------------------------
-- Position functions
------------------------------------------------------

function addon:Round(number, idp)
	idp = idp or 0
	local mult = 10 ^ idp
	return floor(number * mult + .5) / mult
end

function addon:SavePosition(f)
	local orig, _, tar, x, y = f:GetPoint()
	x = self:Round(x, 2)
	y = self:Round(y, 2)

	local db = self.db
	local key = f.key or f:GetName()
	db.positions[key] = {orig, "UIParent", tar, x, y}
	f:ClearAllPoints()
	f:SetPoint(orig, "UIParent", tar, x, y)
end

function addon:LoadPosition(f)
	local db = self.db
	local key = f.key or f:GetName()
	db.positions[key] = db.positions[key] or {}
	local p, r, rp, x, y = unpack(db.positions[key])

	f:ClearAllPoints()
	if not p then
		if f.defaultPos then
			f:SetPoint(unpack(f.defaultPos))
		else
			f:SetPoint("CENTER")
		end
		self:SavePosition(f)
	else
		f:SetPoint(p, r, rp, x, y)
	end
end

local function Move_OnDragStart(self)
	if not self.locked then
		self:StartMoving()
	end
end

local function Move_OnDragStop(self)
	self:StopMovingOrSizing()
	addon:SavePosition(self)

	if self:GetScript("OnMouseUp") then
		self:GetScript("OnMouseUp")(self)
	end
end

function addon:SetMovable(f)
	f:EnableMouse(true)
	f:SetMovable(true)
	f:SetClampedToScreen(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", Move_OnDragStart)
	f:SetScript("OnDragStop", Move_OnDragStop)
	self:LoadPosition(f)
end

------------------------------------------------------
-- Depreciated functions
------------------------------------------------------
-- It is not recommended to use WhisperPop's IGNORED_MESSAGES array to filter messages anymore,
-- I've added codes in v4 to support third-party filters so it's better let other professional addons do
-- the message-filtering job and we simply take their filter results.
------------------------------------------------------

addon.IGNORED_MESSAGES = {} -- Do not use anymore

-- Add additional ignoring patterns into addon.IGNORED_MESSAGES to filter messages in particular, not recommended since v4.0
function addon:AddIgnore(pattern)
	if type(pattern) ~= "string" then
		return
	end

	for index, str in ipairs(self.IGNORED_MESSAGES) do
		if str == pattern then
			return
		end
	end

	tinsert(self.IGNORED_MESSAGES, pattern)
end

function addon:IsIgnoredMessage(text)
	if type(text) ~= "string" then
		return
	end

	for _, pattern in ipairs(self.IGNORED_MESSAGES) do
		if strfind(text, pattern) then
			return pattern
		end
	end
end