local _, GF = ...

-- Runtime eligibility is deliberately kept separate from feature policy.
-- This module reads Blizzard's gates, projects user-facing reasons, and
-- announces transitions. Navigation and page owners decide how to render the
-- projection; they do not need to duplicate protected API reads.
local Availability = {}
GF.Availability = Availability

local RESTRICTION_POLL_SECONDS = 0.5
local RESTRICTION_EVENT = "ADDON_RESTRICTION_STATE_CHANGED"
local EMPTY_LOCALE = {}

local function protectedCall(callback, ...)
	if type(callback) ~= "function" then
		return false
	end
	return pcall(callback, ...)
end

local function accessible(value)
	if value == nil then
		return true
	end
	if type(canaccessvalue) == "function" then
		local ok, canAccess = pcall(canaccessvalue, value)
		if ok and canAccess == false then
			return false
		end
	end
	if type(issecretvalue) == "function" then
		local ok, secret = pcall(issecretvalue, value)
		if ok and secret == true then
			return false
		end
	end
	return true
end

local function readableText(value)
	if type(value) ~= "string" or not accessible(value) then
		return nil
	end
	local ok, text = pcall(string.match, value, "^%s*(.-)%s*$")
	return ok and text ~= "" and text or nil
end

local function displayReason(value)
	local text = readableText(value)
	if not text then
		return nil
	end
	-- Blizzard failure reasons are sentence copy. Inline page labels in GF do
	-- not end with sentence punctuation, while navigation keeps native copy.
	local ok, trimmed = pcall(string.gsub, text, "[%.!。！]+$", "")
	return ok and trimmed ~= "" and trimmed or text
end

local function fallbackPremadeReason()
	local locale = GF.L or EMPTY_LOCALE
	return readableText(locale.UNAVAILABLE_PREMADE)
		or "Premade Groups are currently unavailable."
end

-- Scalar readers do not need temporary projection tables. Keep the native
-- gate and its reasons in multiple returns; GetSnapshot owns the public table.
local function premadeValues()
	local api = C_LFGInfo
	local reader = type(api) == "table" and api.CanPlayerUsePremadeGroup or nil
	local ok, canUse, nativeReason = protectedCall(reader)
	if not ok or canUse ~= false then
		return true
	end

	local level
	local levelOK, rawLevel = protectedCall(UnitLevel, "player")
	if levelOK and accessible(rawLevel) then
		local numberOK, numericLevel = pcall(tonumber, rawLevel)
		if numberOK then
			level = numericLevel
		end
	end

	local nativeText = readableText(nativeReason)
	local fallback = fallbackPremadeReason()
	local locale = GF.L or EMPTY_LOCALE
	local belowFindLevel = level ~= nil and level < 50
	local findReason = belowFindLevel
		and (readableText(locale.PREMADE_FIND_LEVEL_REQUIRED)
			or "You must reach level 50 to find a group")
		or displayReason(nativeText or fallback)
	local createReason = belowFindLevel
		and (readableText(locale.PREMADE_CREATE_LEVEL_REQUIRED)
			or "You must reach level 50 to create a premade group")
		or displayReason(nativeText or fallback)
	return false, nativeText or fallback, findReason, createReason
end

local function restrictedMessage()
	local locale = GF.L or EMPTY_LOCALE
	return readableText(locale.UNAVAILABLE_RESTRICTED)
		or "Paused in restricted scenes."
end

local function chatLockdownRestricted(forcedRestricted)
	if forcedRestricted == true then
		return true
	elseif forcedRestricted == false then
		return false
	end

	local api = C_ChatInfo
	local reader = type(api) == "table" and api.InChatMessagingLockdown or nil
	local ok, locked = protectedCall(reader)
	return ok and locked == true
end

function Availability:GetSnapshot(forcedRestricted)
	if type(forcedRestricted) ~= "boolean" then
		forcedRestricted = self.restrictionEventProjection
	end
	local restricted = chatLockdownRestricted(forcedRestricted)
	local runtimeMessage = restricted and restrictedMessage() or nil
	local allowed, nativeReason, findReason, createReason = premadeValues()
	return {
		restricted = restricted,
		lfgPaused = restricted,
		runtimeMessage = runtimeMessage,
		canUsePremadeGroup = allowed,
		premadeNavigationReason = nativeReason,
		premadeFindReason = findReason,
		premadeCreateReason = createReason,
	}
end

function Availability:CanUsePremadeGroup()
	return premadeValues() == true
end

function Availability:GetPremadeBlockMessage()
	local _, _, _, createReason = premadeValues()
	return createReason
end

function Availability:GetPremadeFindBlockMessage()
	local _, _, findReason = premadeValues()
	return findReason
end

function Availability:GetPremadeNavigationRestriction()
	local _, nativeReason = premadeValues()
	return nativeReason
end

function Availability:GetRuntimeRestrictionMessage()
	if chatLockdownRestricted(self.restrictionEventProjection) then
		return restrictedMessage()
	end
	return nil
end

function Availability:IsRestricted()
	return chatLockdownRestricted(self.restrictionEventProjection)
end

function Availability:IsLfgPaused()
	return chatLockdownRestricted(self.restrictionEventProjection)
end

function Availability:GetBlockMessage()
	return self:GetRuntimeRestrictionMessage()
end

function Availability:ShouldProcessLfgEvent()
	return not self:IsLfgPaused()
end

local function invoke(owner, methodName, ...)
	local method = owner and owner[methodName]
	if type(method) ~= "function" then
		return nil
	end
	local ok, value = pcall(method, owner, ...)
	return ok and value or nil
end

function Availability:ReleaseBlizzardHandoff()
	-- Borrowed native controls have their own ownership implementations. The
	-- runtime gate asks those owners to release; it never reparents fields.
	invoke(GF.SubtitleBar, "ReleaseBlizzardSearchBox")
	invoke(GF.CreatePanel, "ReleaseCreateFields", "restricted")
	if GF.BlizzardBorrow and type(GF.BlizzardBorrow.SetActiveOwner) == "function" then
		pcall(GF.BlizzardBorrow.SetActiveOwner, "blizzard")
	end
end

function Availability:NotifyBlocked(message)
	message = readableText(message) or self:GetRuntimeRestrictionMessage()
	if not message then
		return false
	end
	if type(GF.ShowWarningMessage) == "function" then
		local ok = pcall(GF.ShowWarningMessage, message)
		if ok then
			return true
		end
	end
	local errorFrame = UIErrorsFrame
	if errorFrame and type(errorFrame.AddMessage) == "function" then
		local red = RED_FONT_COLOR
		local r = red and red.r or 1
		local g = red and red.g or 0.2
		local b = red and red.b or 0.2
		local ok = pcall(errorFrame.AddMessage, errorFrame, message, r, g, b, 1)
		if ok then
			return true
		end
	end
	return false
end

function Availability:AddListener(callback)
	if type(callback) ~= "function" then
		return nil
	end
	self.listeners = self.listeners or {}
	self.listeners[#self.listeners + 1] = callback
	return callback
end

local function publish(owner, snapshot, reason)
	owner.revision = (owner.revision or 0) + 1
	for _, callback in ipairs(owner.listeners or {}) do
		pcall(callback, snapshot, reason, owner.revision)
	end
end

function Availability:OnEnterRestricted(snapshot)
	self:ReleaseBlizzardHandoff()
	invoke(GF.MainFrame, "HideFrame")
	publish(self, snapshot or self:GetSnapshot(), "restricted")
end

function Availability:OnLeaveRestricted(snapshot)
	publish(self, snapshot or self:GetSnapshot(), "available")
end

function Availability:UpdateRestrictedState(forcedRestricted)
	local snapshot = self:GetSnapshot(forcedRestricted)
	local restricted = snapshot.restricted == true
	local previous = self.lastRestricted
	self.lastRestricted = restricted
	self.snapshot = snapshot
	if previous == restricted then
		return restricted
	end
	if restricted then
		self:OnEnterRestricted(snapshot)
	elseif previous ~= nil then
		self:OnLeaveRestricted(snapshot)
	else
		publish(self, snapshot, "initial")
	end
	return restricted
end

function Availability:PollRestrictedState()
	local restricted = chatLockdownRestricted()
	if self.lastRestricted == restricted then
		return restricted
	end
	-- The steady-state compatibility poll reads only the chat gate. Build the
	-- more expensive premade-group projection only when an edge is detected.
	return self:UpdateRestrictedState(restricted)
end

local function restrictionLifecycleCapability()
	local eventUtils = C_EventUtils
	local isEventValid = type(eventUtils) == "table"
		and eventUtils.IsEventValid or nil
	local enums = Enum
	local restrictionTypes = type(enums) == "table"
		and enums.AddOnRestrictionType or nil
	local restrictionStates = type(enums) == "table"
		and enums.AddOnRestrictionState or nil
	if type(isEventValid) ~= "function"
		or type(restrictionTypes) ~= "table"
		or restrictionTypes.Chat == nil
		or type(restrictionStates) ~= "table"
		or restrictionStates.Inactive == nil
		or restrictionStates.Activating == nil then
		return nil
	end
	local ok, valid = pcall(isEventValid, RESTRICTION_EVENT)
	if not ok or valid ~= true then
		return nil
	end
	return {
		chat = restrictionTypes.Chat,
		inactive = restrictionStates.Inactive,
		activating = restrictionStates.Activating,
		active = restrictionStates.Active,
		stateReader = type(C_RestrictedActions) == "table"
			and C_RestrictedActions.GetAddOnRestrictionState or nil,
	}
end

local function projectedRestrictionState(capability, state)
	if state == capability.inactive then
		return false
	elseif state == capability.activating
		or (capability.active ~= nil and state == capability.active) then
		return true
	end
	return nil
end

function Availability:HandleRestrictionStateChanged(restrictionType, state)
	local capability = self.restrictionLifecycle
	if not capability or restrictionType ~= capability.chat then
		return false
	end

	local restricted = projectedRestrictionState(capability, state)
	if type(restricted) ~= "boolean" then
		return false
	end

	-- Blizzard announces Activating before the raw chat API flips. Preserve the
	-- event projection until the matching Inactive edge so an intervening LFG
	-- event cannot briefly restore protected UI or resume message dispatch.
	self.restrictionEventProjection = restricted
	self:UpdateRestrictedState(restricted)
	return true
end

function Availability:GetRevision()
	return self.revision or 0
end

function Availability:Init()
	if self.initialized then
		return self:UpdateRestrictedState()
	end
	self.initialized = true
	if type(CreateFrame) == "function" then
		local ok, frame = pcall(CreateFrame, "Frame")
		if ok and frame then
			self.eventFrame = frame
			for _, eventName in ipairs({
				"PLAYER_ENTERING_WORLD",
				"ZONE_CHANGED_NEW_AREA",
			}) do
				pcall(frame.RegisterEvent, frame, eventName)
			end
			self.restrictionLifecycle = restrictionLifecycleCapability()
			if self.restrictionLifecycle then
				local registered = pcall(
					frame.RegisterEvent, frame, RESTRICTION_EVENT)
				if not registered then
					self.restrictionLifecycle = nil
				else
					local reader = self.restrictionLifecycle.stateReader
					local stateOK, state = protectedCall(
						reader, self.restrictionLifecycle.chat)
					if stateOK then
						self.restrictionEventProjection = projectedRestrictionState(
							self.restrictionLifecycle, state)
					end
				end
			end
			if not self.restrictionLifecycle then
				local elapsedSincePoll = 0
				frame:SetScript("OnUpdate", function(_, elapsed)
					elapsedSincePoll = elapsedSincePoll + (tonumber(elapsed) or 0)
					if elapsedSincePoll < RESTRICTION_POLL_SECONDS then
						return
					end
					elapsedSincePoll = elapsedSincePoll % RESTRICTION_POLL_SECONDS
					Availability:PollRestrictedState()
				end)
			end
			frame:SetScript("OnEvent", function(_, eventName, ...)
				if eventName == RESTRICTION_EVENT then
					Availability:HandleRestrictionStateChanged(...)
				else
					Availability:UpdateRestrictedState()
				end
			end)
			if self.restrictionLifecycle
				and self.restrictionEventProjection == nil then
				local after = type(C_Timer) == "table" and C_Timer.After or nil
				if type(after) == "function" then
					pcall(after, 0, function()
						if Availability.restrictionEventProjection == nil then
							Availability:UpdateRestrictedState()
						end
					end)
				end
			end
		end
	end
	return self:UpdateRestrictedState()
end
