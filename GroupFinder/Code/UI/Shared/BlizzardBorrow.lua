local _, GF = ...

local Borrow = {}
GF.BlizzardBorrow = Borrow

local rememberedLayout = setmetatable({}, { __mode = "k" })
local serviceState = {
	activeOwner = nil,
	hiddenHost = nil,
}

local function usableFrame(frame)
	return frame ~= nil and type(frame.GetParent) == "function"
end

local function rememberAnchor(frame, index)
	local point, relativeTo, relativePoint, offsetX, offsetY = frame:GetPoint(index)
	return {
		point = point,
		relativeTo = relativeTo,
		relativePoint = relativePoint,
		offsetX = offsetX,
		offsetY = offsetY,
	}
end

function Borrow.CacheLayout(frame)
	if not usableFrame(frame) or rememberedLayout[frame] ~= nil then
		return
	end
	local snapshot = {
		host = frame:GetParent(),
		anchors = {},
	}
	local anchorCount = type(frame.GetNumPoints) == "function"
		and frame:GetNumPoints() or 0
	for anchorIndex = 1, anchorCount do
		snapshot.anchors[anchorIndex] = rememberAnchor(frame, anchorIndex)
	end
	if type(frame.GetSize) == "function" then
		snapshot.width, snapshot.height = frame:GetSize()
	end
	rememberedLayout[frame] = snapshot
end

local function applyAnchor(frame, anchor)
	frame:SetPoint(
		anchor.point,
		anchor.relativeTo,
		anchor.relativePoint,
		anchor.offsetX,
		anchor.offsetY
	)
end

function Borrow.RestoreLayout(frame)
	local snapshot = frame and rememberedLayout[frame]
	if snapshot == nil then
		return false
	end
	frame:SetParent(snapshot.host)
	frame:ClearAllPoints()
	for anchorIndex = 1, #snapshot.anchors do
		applyAnchor(frame, snapshot.anchors[anchorIndex])
	end
	local width, height = snapshot.width, snapshot.height
	if type(width) == "number" and width > 0
		and type(height) == "number" and height > 0
	then
		frame:SetSize(width, height)
	end
	return true
end

function Borrow.EmbedFill(frame, newParent, anchorFrame, width, height)
	if not (frame and newParent and anchorFrame) then
		return false
	end
	frame:SetParent(newParent)
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", anchorFrame, "TOPLEFT")
	if type(width) == "number" and type(height) == "number" then
		frame:SetSize(width, height)
	else
		frame:SetPoint("BOTTOMRIGHT", anchorFrame, "BOTTOMRIGHT")
	end
	if type(frame.SetFrameLevel) == "function"
		and type(newParent.GetFrameLevel) == "function"
	then
		frame:SetFrameLevel(newParent:GetFrameLevel() + 2)
	end
	frame:Show()
	return true
end

function Borrow.SetActiveOwner(owner)
	serviceState.activeOwner = owner
	GF.nativeControlActiveOwner = owner
end

function Borrow.GetActiveOwner()
	if serviceState.activeOwner ~= nil then
		return serviceState.activeOwner
	end
	return GF.nativeControlActiveOwner
end

function Borrow.MarkBorrowed(frame, owner, channel)
	if frame == nil then
		return
	end
	frame._gfBorrowOwner = owner
	frame._gfBorrowChannel = channel
end

function Borrow.ClearBorrowed(frame, owner, channel)
	if frame == nil then
		return false
	end
	local ownerMatches = owner == nil or frame._gfBorrowOwner == owner
	local channelMatches = channel == nil or frame._gfBorrowChannel == channel
	if not (ownerMatches and channelMatches) then
		return false
	end
	frame._gfBorrowOwner, frame._gfBorrowChannel = nil, nil
	return true
end

function Borrow.IsBorrowedBy(frame, owner, channel)
	if frame == nil or frame._gfBorrowOwner == nil then
		return false
	end
	if owner ~= nil and frame._gfBorrowOwner ~= owner then
		return false
	end
	return channel == nil or frame._gfBorrowChannel == channel
end

function Borrow.GetHideSink()
	if serviceState.hiddenHost == nil then
		local host = CreateFrame("Frame")
		host:Hide()
		serviceState.hiddenHost = host
	end
	return serviceState.hiddenHost
end

function Borrow.IsExternallyOwned(frame, nativeParent, owner, channel)
	if not usableFrame(frame) then
		return false
	end
	if Borrow.IsBorrowedBy(frame, owner, channel) then
		return false
	end
	local actualParent = frame:GetParent()
	if actualParent == nil
		or actualParent == nativeParent
		or actualParent == Borrow.GetHideSink()
	then
		return false
	end
	local markedOwner = frame._gfBorrowOwner
	if markedOwner ~= nil and markedOwner ~= owner then
		return true
	end
	return actualParent ~= nativeParent
end

function Borrow.ReadEditText(editBox)
	if editBox == nil or type(editBox.GetText) ~= "function" then
		return nil
	end
	local ok, value = pcall(editBox.GetText, editBox)
	if not ok then
		return nil
	end
	if type(issecretvalue) == "function" then
		local secretOK, secret = pcall(issecretvalue, value)
		if secretOK and secret == true then
			return nil
		end
	end
	return value
end

-- Bump relisting copies the active entry into Blizzard's protected singleton,
-- removes the old entry and immediately creates the replacement in one click
-- stack. Only listeners known to clear that singleton are paused for the
-- synchronous inactive event; they are restored before CreateListing runs.
local ACTIVE_ENTRY_EVENT = "LFG_LIST_ACTIVE_ENTRY_UPDATE"
local BUMP_CONSUMER_SPECS = {
	{
		addonName = "MeetingStone",
		moduleName = "CreatePanel",
	},
	{
		addonName = "MyKeyStone",
		callbackName = "HandleMeetingStoneActiveEntryUpdate",
	},
}

local function addonLoadState(name)
	local isLoaded = C_AddOns and C_AddOns.IsAddOnLoaded
	if type(isLoaded) ~= "function" then
		return "unknown"
	end
	local ok, loadedOrLoading, loaded = pcall(isLoaded, name)
	if not ok then
		return "unknown"
	end
	if loaded == true then
		return "loaded"
	end
	if loadedOrLoading == false and loaded == false then
		return "unloaded"
	end
	return "unknown"
end

local function aceAddon(name)
	local resolver = GF.GetOptionalLibrary
	if type(resolver) ~= "function" then
		return nil
	end
	local registry = resolver("AceAddon-3.0")
	if type(registry) ~= "table"
		or type(registry.GetAddon) ~= "function"
	then
		return nil
	end
	local ok, addon = pcall(registry.GetAddon, registry, name, true)
	return ok and addon or nil
end

local function resolveConsumer(spec)
	local addon = aceAddon(spec.addonName)
	if type(addon) ~= "table" then
		return nil
	end
	if spec.moduleName == nil then
		return addon
	end
	if type(addon.GetModule) ~= "function" then
		return nil
	end
	local ok, module = pcall(
		addon.GetModule,
		addon,
		spec.moduleName,
		true
	)
	return ok and module or nil
end

local function consumerIsRunning(consumer)
	if type(consumer) ~= "table" then
		return nil
	end
	if type(consumer.IsEnabled) ~= "function" then
		return true
	end
	local ok, enabled = pcall(consumer.IsEnabled, consumer)
	if not ok or type(enabled) ~= "boolean" then
		return nil
	end
	return enabled
end

local function prepareConsumer(spec)
	local loadState = addonLoadState(spec.addonName)
	if loadState == "unloaded" then
		return "skipped"
	end
	if loadState ~= "loaded" then
		return "failed"
	end

	local consumer = resolveConsumer(spec)
	local running = consumerIsRunning(consumer)
	if running == false then
		return "skipped"
	end
	if running ~= true then
		return "failed"
	end
	if type(consumer.UnregisterEvent) ~= "function"
		or type(consumer.RegisterEvent) ~= "function"
	then
		return "failed"
	end
	local callbackMethod = spec.callbackName or ACTIVE_ENTRY_EVENT
	if type(consumer[callbackMethod]) ~= "function" then
		return "failed"
	end
	return "ready", {
		consumer = consumer,
		callbackName = spec.callbackName,
	}
end

local function pauseConsumer(lease, state)
	local consumer = state and state.consumer
	local ok = pcall(consumer.UnregisterEvent, consumer, ACTIVE_ENTRY_EVENT)
	if not ok then
		return false
	end
	lease.paused[#lease.paused + 1] = state
	return true
end

local function resumeOne(state)
	local register = state.consumer and state.consumer.RegisterEvent
	if type(register) ~= "function" then
		return false
	end
	if state.callbackName ~= nil then
		return pcall(
			register,
			state.consumer,
			ACTIVE_ENTRY_EVENT,
			state.callbackName
		)
	end
	return pcall(register, state.consumer, ACTIVE_ENTRY_EVENT)
end

local function resumeLease(lease)
	if type(lease) ~= "table" or type(lease.paused) ~= "table" then
		return true
	end
	local failed = {}
	for index = #lease.paused, 1, -1 do
		local state = lease.paused[index]
		if not resumeOne(state) then
			failed[#failed + 1] = state
		end
	end
	lease.paused = #failed > 0 and failed or nil
	return lease.paused == nil
end

local function entryTextFieldsExist()
	local frame = LFGListFrame
	local creation = frame and frame.EntryCreation
	return creation ~= nil
		and creation.Name ~= nil
		and creation.Description ~= nil
		and creation.Description.EditBox ~= nil
end

function Borrow.AcquireEntryCreationBumpLease()
	if not entryTextFieldsExist() then
		return nil
	end
	local prepared = {}
	for _, spec in ipairs(BUMP_CONSUMER_SPECS) do
		local status, state = prepareConsumer(spec)
		if status == "failed" then
			return nil
		end
		if status == "ready" then
			prepared[#prepared + 1] = state
		end
	end

	local lease = { paused = {} }
	for _, state in ipairs(prepared) do
		if not pauseConsumer(lease, state) then
			resumeLease(lease)
			return nil
		end
	end
	return lease
end

function Borrow.ResumeEntryCreationBumpConsumers(lease)
	return resumeLease(lease)
end

function Borrow.ReleaseEntryCreationBumpLease(lease)
	resumeLease(lease)
end

local listing = GF.RecruitmentSession
if listing ~= nil and type(listing.SetRelistFieldBridge) == "function" then
	listing:SetRelistFieldBridge({
		Acquire = function()
			return Borrow.AcquireEntryCreationBumpLease()
		end,
		ResumeAfterRemove = function(lease)
			return Borrow.ResumeEntryCreationBumpConsumers(lease)
		end,
		Release = function(lease)
			Borrow.ReleaseEntryCreationBumpLease(lease)
		end,
	})
end
