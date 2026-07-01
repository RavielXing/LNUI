local _, GF = ...

GF.Availability = {}

local restrictionFrame
local restrictedPollElapsed = 0
local RESTRICTED_STATE_POLL_INTERVAL = 0.5

local function inChatMessagingLockdown()
	local ci = C_ChatInfo
	if ci and ci.InChatMessagingLockdown then
		return ci.InChatMessagingLockdown()
	end
	return false
end

local function getPremadeUnavailableFallback()
	local L = GF.L or {}
	return L.UNAVAILABLE_PREMADE or "Premade Groups are currently unavailable."
end

local function trimTrailingSentencePeriod(text)
	if type(text) ~= "string" then
		return text
	end
	text = text:gsub("%s+$", "")
	return text:gsub("[。%.]+$", "")
end

local function getPremadeUseStatus()
	if C_LFGInfo and C_LFGInfo.CanPlayerUsePremadeGroup then
		local canUse, failureReason = C_LFGInfo.CanPlayerUsePremadeGroup()
		if canUse == false then
			if type(failureReason) == "string" and failureReason ~= "" then
				return false, trimTrailingSentencePeriod(failureReason)
			end
			return false, trimTrailingSentencePeriod(getPremadeUnavailableFallback())
		end
	end
	return true, nil
end

function GF.Availability:CanUsePremadeGroup()
	return getPremadeUseStatus()
end

function GF.Availability:GetPremadeBlockMessage()
	local canUse, failureReason = getPremadeUseStatus()
	if canUse == false then
		return failureReason
	end
	return nil
end

function GF.Availability:GetRuntimeRestrictionMessage()
	if inChatMessagingLockdown() then
		local L = GF.L or {}
		return L.UNAVAILABLE_RESTRICTED
			or "Game API restrictions are active. Use the system Premade Groups feature, or leave the current instance before continuing to use this addon."
	end
	return nil
end

function GF.Availability:IsRestricted()
	return self:GetRuntimeRestrictionMessage() ~= nil
end

function GF.Availability:IsLfgPaused()
	return self._restricted == true
end

function GF.Availability:GetBlockMessage()
	return self:GetRuntimeRestrictionMessage()
end

function GF.Availability:ReleaseBlizzardHandoff()
	if GF.SubtitleBar and GF.SubtitleBar.ReleaseBlizzardSearchBox then
		GF.SubtitleBar:ReleaseBlizzardSearchBox()
	end
	if GF.CreatePanel and GF.CreatePanel.ReleaseCreateFields then
		GF.CreatePanel:ReleaseCreateFields("addon")
	end
	if GF.CreateDrawer and GF.CreateDrawer.IsOpen and GF.CreateDrawer:IsOpen() then
		GF.CreateDrawer:Close(true)
	end
end

function GF.Availability:OnEnterRestricted()
	self:ReleaseBlizzardHandoff()
	local mf = GF.MainFrame
	if mf and mf.frame and mf.frame:IsShown() then
		local msg = self:GetBlockMessage()
		mf:HideFrame()
		if msg then
			self:NotifyBlocked(msg)
		end
	end
	if GF.FloatButton and GF.FloatButton.RefreshAlert then
		GF.FloatButton:RefreshAlert()
	end
end

function GF.Availability:OnLeaveRestricted()
	if GF.FloatButton and GF.FloatButton.RefreshAlert then
		GF.FloatButton:RefreshAlert()
	end
end

function GF.Availability:UpdateRestrictedState()
	local nowRestricted = self:IsRestricted()
	if nowRestricted and not self._restricted then
		self._restricted = true
		self:OnEnterRestricted()
	elseif not nowRestricted and self._restricted then
		self._restricted = false
		self:OnLeaveRestricted()
	end
	return self._restricted
end

function GF.Availability:ShouldProcessLfgEvent()
	self:UpdateRestrictedState()
	return not self._restricted
end

function GF.Availability:Init()
	if self._inited then
		return
	end
	self._inited = true
	self._restricted = false
	if not restrictionFrame then
		restrictionFrame = CreateFrame("Frame")
		restrictionFrame:SetScript("OnEvent", function()
			GF.Availability:UpdateRestrictedState()
		end)
		restrictionFrame:SetScript("OnUpdate", function(_, elapsed)
			restrictedPollElapsed = restrictedPollElapsed + (elapsed or 0)
			if restrictedPollElapsed < RESTRICTED_STATE_POLL_INTERVAL then
				return
			end
			restrictedPollElapsed = 0
			GF.Availability:UpdateRestrictedState()
		end)
	end
	restrictionFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
	restrictionFrame:RegisterEvent("PLAYER_LOGIN")
end

function GF.Availability:NotifyBlocked(msg)
	if not msg or msg == "" then
		return
	end
	if GF.ShowWarningMessage then
		GF.ShowWarningMessage(msg, DEFAULT_CHAT_FRAME)
	end
end
