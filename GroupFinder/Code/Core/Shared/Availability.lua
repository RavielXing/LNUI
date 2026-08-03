local _, GF = ...

local Availability = {}
GF.Availability = Availability

local CREATE_LEVEL = 50
local POLL_SECONDS = 0.5
local runtime = {
	frame = nil,
	elapsed = 0,
	restricted = false,
	initialized = false,
}

local function localized(key, fallback)
	local L = GF.L or {}
	return L[key] or fallback
end

local function withoutSentenceTerminator(text)
	if type(text) ~= "string" then
		return text
	end
	local compact = text:gsub("%s+$", "")
	return compact:gsub("[%.。]+$", "")
end

local function playerLevel()
	if type(UnitLevel) ~= "function" then
		return nil
	end
	local ok, value = pcall(UnitLevel, "player")
	if ok and type(value) == "number" and value > 0 then
		return value
	end
	return nil
end

local function belowCreateLevel()
	local level = playerLevel()
	return level ~= nil and level < CREATE_LEVEL
end

local function nativePermission(apiName, fallbackKey, fallbackText)
	local api = C_LFGInfo and C_LFGInfo[apiName]
	if type(api) ~= "function" then
		return true, nil
	end
	local ok, allowed, reason = pcall(api)
	if not ok or allowed ~= false then
		return true, nil
	end
	local fallback = localized(
		fallbackKey or "UNAVAILABLE_PREMADE",
		fallbackText or "Premade Groups are currently unavailable."
	)
	local message = type(reason) == "string" and reason ~= ""
		and reason or fallback
	return false, message
end

local function creationPermission()
	local allowed, reason = nativePermission(
		"CanPlayerUsePremadeGroup",
		"UNAVAILABLE_PREMADE",
		"Premade Groups are currently unavailable."
	)
	if allowed then
		return true, nil
	end
	if belowCreateLevel() then
		return false, localized(
			"PREMADE_CREATE_LEVEL_REQUIRED",
			"You must reach level 50 to create a premade group"
		)
	end
	return false, withoutSentenceTerminator(reason)
end

local function chatIsLocked()
	local api = C_ChatInfo and C_ChatInfo.InChatMessagingLockdown
	if type(api) ~= "function" then
		return false
	end
	local ok, locked = pcall(api)
	return ok and not not locked
end

function Availability:CanUsePremadeGroup()
	return creationPermission()
end

function Availability:GetPremadeBlockMessage()
	local allowed, reason = creationPermission()
	return allowed and nil or reason
end

-- Navigation tooltips deliberately retain Blizzard's native failureReason,
-- including punctuation. The create form has a separate product-facing copy
-- rule for levels 1-49 and must not leak into this native availability view.
function Availability:GetPremadeNavigationRestriction()
	local allowed, reason = nativePermission(
		"CanPlayerUsePremadeGroup",
		"UNAVAILABLE_PREMADE",
		"Premade Groups are currently unavailable."
	)
	return allowed and nil or reason
end

function Availability:GetRuntimeRestrictionMessage()
	if not chatIsLocked() then
		return nil
	end
	return localized(
		"UNAVAILABLE_RESTRICTED",
		"Game API restrictions are active. Use the system Premade Groups feature, or leave the current instance before continuing to use this addon."
	)
end

function Availability:IsRestricted()
	return self:GetRuntimeRestrictionMessage() ~= nil
end

function Availability:IsLfgPaused()
	return runtime.restricted
end

function Availability:GetBlockMessage()
	return self:GetRuntimeRestrictionMessage()
end

local function releaseBorrowedSurfaces()
	local subtitle = GF.SubtitleBar
	if subtitle and type(subtitle.ReleaseBlizzardSearchBox) == "function" then
		subtitle:ReleaseBlizzardSearchBox()
	end
	local create = GF.CreatePanel
	if create and type(create.ReleaseCreateFields) == "function" then
		create:ReleaseCreateFields("addon")
	end
	local drawer = GF.CreateDrawer
	if drawer and type(drawer.IsOpen) == "function" and drawer:IsOpen()
		and type(drawer.Close) == "function" then
		drawer:Close(true)
	end
end

function Availability:ReleaseBlizzardHandoff()
	releaseBorrowedSurfaces()
end

local function refreshFloatingStatus()
	local button = GF.FloatButton
	if button and type(button.RefreshAlert) == "function" then
		button:RefreshAlert()
	end
end

function Availability:NotifyBlocked(message)
	if type(message) ~= "string" or message == "" then
		return
	end
	if type(GF.ShowWarningMessage) == "function" then
		GF.ShowWarningMessage(message, DEFAULT_CHAT_FRAME)
	end
end

function Availability:OnEnterRestricted()
	releaseBorrowedSurfaces()
	local main = GF.MainFrame
	local frame = main and main.frame
	if frame and frame:IsShown() then
		local message = self:GetRuntimeRestrictionMessage()
		if type(main.HideFrame) == "function" then
			main:HideFrame()
		end
		if message then
			self:NotifyBlocked(message)
		end
	end
	refreshFloatingStatus()
end

function Availability:OnLeaveRestricted()
	refreshFloatingStatus()
end

function Availability:UpdateRestrictedState()
	local nextState = self:IsRestricted()
	if nextState == runtime.restricted then
		return runtime.restricted
	end
	runtime.restricted = nextState
	if nextState then
		self:OnEnterRestricted()
	else
		self:OnLeaveRestricted()
	end
	return runtime.restricted
end

function Availability:ShouldProcessLfgEvent()
	return not self:UpdateRestrictedState()
end

local function pollRestrictions(_, elapsed)
	runtime.elapsed = runtime.elapsed + (tonumber(elapsed) or 0)
	if runtime.elapsed < POLL_SECONDS then
		return
	end
	runtime.elapsed = runtime.elapsed % POLL_SECONDS
	Availability:UpdateRestrictedState()
end

local function buildWatcher()
	local frame = CreateFrame("Frame")
	frame:SetScript("OnEvent", function()
		Availability:UpdateRestrictedState()
	end)
	frame:SetScript("OnUpdate", pollRestrictions)
	frame:RegisterEvent("PLAYER_ENTERING_WORLD")
	frame:RegisterEvent("PLAYER_LOGIN")
	return frame
end

function Availability:Init()
	if runtime.initialized then
		return
	end
	runtime.initialized = true
	runtime.restricted = false
	runtime.elapsed = 0
	runtime.frame = runtime.frame or buildWatcher()
end
