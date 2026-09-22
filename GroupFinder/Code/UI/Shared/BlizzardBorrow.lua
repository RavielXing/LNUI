local _, GF = ...

-- BlizzardBorrow is the only UI-side owner of native-frame leases. It never
-- reads, caches, or writes protected creation text. CreatePanel supplies the
-- visual projection; this module owns identity, generations, rollback, and
-- the exact native state restored at the end of a lease.
local Borrow = {}
GF.BlizzardBorrow = Borrow

Borrow.STATE_IDLE = "idle"
Borrow.STATE_PENDING = "pending"
Borrow.STATE_OWNED = "owned"
Borrow.STATE_RELEASING = "releasing"

local ACTIVE_ENTRY_EVENT = "LFG_LIST_ACTIVE_ENTRY_UPDATE"
local CREATE_FIELD_CHANNEL = "entryCreation"

local rememberedLayout = setmetatable({}, { __mode = "k" })
local serviceState = {
	activeOwner = nil,
	hiddenHost = nil,
	entry = {
		generation = 0,
		phase = Borrow.STATE_IDLE,
		lease = nil,
	},
	context = {
		generation = 0,
		phase = Borrow.STATE_IDLE,
		lease = nil,
	},
	fence = {
		generation = 0,
		phase = Borrow.STATE_IDLE,
		lease = nil,
	},
}

local function usableFrame(frame)
	return frame ~= nil and type(frame.GetParent) == "function"
end

local function callMethod(owner, methodName, ...)
	local method = owner and owner[methodName]
	if type(method) ~= "function" then
		return false
	end
	return pcall(method, owner, ...)
end

local function readMethod(owner, methodName, ...)
	local method = owner and owner[methodName]
	if type(method) ~= "function" then
		return nil, false
	end
	local ok, value = pcall(method, owner, ...)
	return ok and value or nil, ok
end

local function nextGeneration(channel)
	channel.generation = channel.generation + 1
	return channel.generation
end

local function appendAnchor(frame, anchors, index)
	local ok, point, relativeTo, relativePoint, offsetX, offsetY = pcall(
		frame.GetPoint,
		frame,
		index
	)
	if not ok then
		return false
	end
	anchors[#anchors + 1] = {
		point = point,
		relativeTo = relativeTo,
		relativePoint = relativePoint,
		offsetX = offsetX,
		offsetY = offsetY,
	}
	return true
end

local function captureLayout(frame)
	if not usableFrame(frame) then
		return nil
	end
	local parent, parentOK = readMethod(frame, "GetParent")
	if not parentOK then
		return nil
	end
	local snapshot = {
		parent = parent,
		anchors = {},
	}
	local count = 0
	if type(frame.GetNumPoints) == "function" then
		local ok, value = pcall(frame.GetNumPoints, frame)
		if not ok or type(value) ~= "number" or value < 0 then
			return nil
		end
		count = value
	end
	for index = 1, count do
		if not appendAnchor(frame, snapshot.anchors, index) then
			return nil
		end
	end
	if type(frame.GetSize) == "function" then
		local ok, width, height = pcall(frame.GetSize, frame)
		if not ok then
			return nil
		end
		snapshot.width, snapshot.height = width, height
	end
	return snapshot
end

local function applyAnchor(frame, anchor)
	return callMethod(
		frame,
		"SetPoint",
		anchor.point,
		anchor.relativeTo,
		anchor.relativePoint,
		anchor.offsetX,
		anchor.offsetY
	)
end

local function restoreLayout(frame, snapshot, restoreParent)
	if not usableFrame(frame) or type(snapshot) ~= "table" then
		return false
	end
	local ok = true
	if restoreParent ~= false then
		ok = callMethod(frame, "SetParent", snapshot.parent) and ok
	else
		local parent, parentOK = readMethod(frame, "GetParent")
		-- Protected EntryCreation children are never independently reparented by
		-- GroupFinder. A changed parent chain is an ownership violation.
		if not parentOK or parent ~= snapshot.parent then
			return false
		end
	end
	ok = callMethod(frame, "ClearAllPoints") and ok
	for index = 1, #(snapshot.anchors or {}) do
		ok = applyAnchor(frame, snapshot.anchors[index]) and ok
	end
	if type(snapshot.width) == "number"
		and type(snapshot.height) == "number"
	then
		ok = callMethod(
			frame,
			"SetSize",
			snapshot.width,
			snapshot.height
		) and ok
	end
	return ok
end

function Borrow.CacheLayout(frame)
	if not usableFrame(frame) or rememberedLayout[frame] ~= nil then
		return false
	end
	local snapshot = captureLayout(frame)
	if snapshot == nil then
		return false
	end
	rememberedLayout[frame] = snapshot
	return true
end

function Borrow.RestoreLayout(frame)
	local snapshot = frame and rememberedLayout[frame]
	return snapshot ~= nil and restoreLayout(frame, snapshot, true) or false
end

function Borrow.EmbedFill(frame, newParent, anchorFrame, width, height)
	if not (frame and newParent and anchorFrame) then
		return false
	end
	local ok = callMethod(frame, "SetParent", newParent)
	ok = callMethod(frame, "ClearAllPoints") and ok
	ok = callMethod(frame, "SetPoint", "TOPLEFT", anchorFrame, "TOPLEFT")
		and ok
	if type(width) == "number" and type(height) == "number" then
		ok = callMethod(frame, "SetSize", width, height) and ok
	else
		ok = callMethod(
			frame,
			"SetPoint",
			"BOTTOMRIGHT",
			anchorFrame,
			"BOTTOMRIGHT"
		) and ok
	end
	if type(frame.SetFrameLevel) == "function"
		and type(newParent.GetFrameLevel) == "function"
	then
		local level, readOK = readMethod(newParent, "GetFrameLevel")
		if readOK then
			ok = callMethod(frame, "SetFrameLevel", (level or 0) + 2) and ok
		end
	end
	ok = callMethod(frame, "Show") and ok
	return ok
end

function Borrow.SetActiveOwner(owner)
	serviceState.activeOwner = owner
	GF.nativeControlActiveOwner = owner
	return owner
end

function Borrow.GetActiveOwner()
	local lease = serviceState.entry.lease
	if lease ~= nil and lease.released ~= true then
		return lease.owner
	end
	if serviceState.activeOwner ~= nil then
		return serviceState.activeOwner
	end
	return GF.nativeControlActiveOwner
end

function Borrow.MarkBorrowed(frame, owner, channel, token)
	if frame == nil then
		return false
	end
	local currentToken = frame._gfBorrowToken
	if currentToken ~= nil and currentToken ~= token then
		return false
	end
	frame._gfBorrowOwner = owner
	frame._gfBorrowChannel = channel
	if token ~= nil then
		frame._gfBorrowToken = token
		frame._gfBorrowGeneration = token.generation
	end
	return true
end

function Borrow.ClearBorrowed(frame, owner, channel, token)
	if frame == nil then
		return false
	end
	local ownerMatches = owner == nil or frame._gfBorrowOwner == owner
	local channelMatches = channel == nil or frame._gfBorrowChannel == channel
	local markedToken = frame._gfBorrowToken
	local tokenMatches = markedToken == nil or token ~= nil and markedToken == token
	if not (ownerMatches and channelMatches and tokenMatches) then
		return false
	end
	frame._gfBorrowOwner = nil
	frame._gfBorrowChannel = nil
	if token ~= nil or markedToken == nil then
		frame._gfBorrowToken = nil
		frame._gfBorrowGeneration = nil
	end
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

-- Kept for search-field API parity. EntryCreation leases never call this:
-- protected name/comment/voice text remains exclusively Blizzard-owned.
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
		if not secretOK or secret == true then
			return nil
		end
	end
	return value
end

-- EntryCreation visual lease -------------------------------------------------

local ENTRY_CHILD_PATHS = {
	{ "Name" },
	{ "Description" },
	{ "Description", "EditBox" },
	{ "VoiceChat" },
	{ "VoiceChat", "EditBox" },
	{ "VoiceChat", "CheckButton" },
	{ "VoiceChat", "Label" },
	{ "VoiceChat", "WarningFrame" },
}

local function resolvePath(root, path)
	local value = root
	for index = 1, #path do
		value = value and value[path[index]]
	end
	return value
end

local function captureFrameState(frame, restoreParent)
	if not usableFrame(frame) then
		return nil
	end
	local state = {
		frame = frame,
		layout = captureLayout(frame),
		restoreParent = restoreParent == true,
	}
	for _, spec in ipairs({
		{ "shown", "IsShown" },
		{ "alpha", "GetAlpha" },
		{ "scale", "GetScale" },
		{ "frameLevel", "GetFrameLevel" },
		{ "frameStrata", "GetFrameStrata" },
		{ "enabled", "IsEnabled" },
		{ "mouseEnabled", "IsMouseEnabled" },
	}) do
		if type(frame[spec[2]]) == "function" then
			local value, ok = readMethod(frame, spec[2])
			if not ok then
				return nil
			end
			state[spec[1]] = value
		end
	end
	return state
end

local function captureEntryState(creation)
	local container = captureFrameState(creation, true)
	if container == nil or container.layout == nil then
		return nil
	end
	local snapshot = {
		container = container,
		children = {},
	}
	local seen = {}
	for index = 1, #ENTRY_CHILD_PATHS do
		local frame = resolvePath(creation, ENTRY_CHILD_PATHS[index])
		if usableFrame(frame) and not seen[frame] then
			seen[frame] = true
			local state = captureFrameState(frame, false)
			if state == nil or state.layout == nil then
				return nil
			end
			snapshot.children[#snapshot.children + 1] = state
		end
	end
	return snapshot
end

local function protectedChildrenKeepNativeParents(creation)
	if creation == nil then
		return false
	end
	for _, fieldName in ipairs({ "Name", "Description", "VoiceChat" }) do
		local field = creation[fieldName]
		if field ~= nil then
			if not usableFrame(field) then
				return false
			end
			local parent, parentOK = readMethod(field, "GetParent")
			if not parentOK or parent ~= creation then
				return false
			end
		end
	end
	local descriptionEdit = creation.Description
		and creation.Description.EditBox
	if descriptionEdit ~= nil then
		if not usableFrame(descriptionEdit) then
			return false
		end
		local parent, parentOK = readMethod(descriptionEdit, "GetParent")
		if not parentOK or parent ~= creation.Description
		then
			return false
		end
	end
	local voiceEdit = creation.VoiceChat and creation.VoiceChat.EditBox
	if voiceEdit ~= nil then
		if not usableFrame(voiceEdit) then
			return false
		end
		local parent, parentOK = readMethod(voiceEdit, "GetParent")
		if not parentOK or parent ~= creation.VoiceChat
		then
			return false
		end
	end
	return true
end

local function setOptionalState(frame, methodName, value)
	if value == nil or type(frame[methodName]) ~= "function" then
		return true
	end
	return callMethod(frame, methodName, value)
end

local function restoreFrameState(state, restoreVisibility)
	local frame = state and state.frame
	if frame == nil then
		return false
	end
	local ok = restoreLayout(frame, state.layout, state.restoreParent)
	ok = setOptionalState(frame, "SetScale", state.scale) and ok
	ok = setOptionalState(frame, "SetAlpha", state.alpha) and ok
	ok = setOptionalState(frame, "SetFrameStrata", state.frameStrata) and ok
	ok = setOptionalState(frame, "SetFrameLevel", state.frameLevel) and ok
	ok = setOptionalState(frame, "SetEnabled", state.enabled) and ok
	ok = setOptionalState(frame, "EnableMouse", state.mouseEnabled) and ok
	if restoreVisibility == true and state.shown ~= nil then
		ok = setOptionalState(frame, "SetShown", state.shown == true) and ok
	end
	return ok
end

local function restoreEntryState(lease, restoreContainerVisibility)
	local snapshot = lease and lease.snapshot
	if snapshot == nil then
		return false
	end
	local ok = true
	for index = #snapshot.children, 1, -1 do
		ok = restoreFrameState(snapshot.children[index], true) and ok
	end
	ok = restoreFrameState(
		snapshot.container,
		restoreContainerVisibility == true
	) and ok
	return ok
end

local function refreshNativeAuthentication(creation)
	if creation == nil or creation.selectedActivity == nil then
		return true
	end
	local ok = true
	if type(LFGListEntryCreation_UpdateAuthenticatedState) == "function" then
		ok = pcall(LFGListEntryCreation_UpdateAuthenticatedState, creation) and ok
	end
	if creation.Name and type(creation.Name.UpdateEnabledState) == "function" then
		ok = pcall(creation.Name.UpdateEnabledState, creation.Name) and ok
	end
	if creation.Description
		and type(creation.Description.UpdateEnabledState) == "function"
	then
		ok = pcall(
			creation.Description.UpdateEnabledState,
			creation.Description
		) and ok
	end
	return ok
end

local function entryLeaseMatches(lease, options)
	if type(lease) ~= "table" or lease.released == true
		or serviceState.entry.lease ~= lease
		or serviceState.entry.generation ~= lease.generation
	then
		return false
	end
	if type(options) ~= "table" then
		return true
	end
	if options.owner ~= nil and lease.owner ~= options.owner then
		return false
	end
	if options.channel ~= nil and lease.channel ~= options.channel then
		return false
	end
	if options.creation ~= nil and lease.creation ~= options.creation then
		return false
	end
	if options.host ~= nil and lease.host ~= options.host then
		return false
	end
	if options.contextKey ~= nil and lease.contextKey ~= options.contextKey then
		return false
	end
	return true
end

function Borrow.GetEntryCreationLeaseState()
	local state = serviceState.entry
	return state.phase, state.generation, state.lease
end

function Borrow.GetEntryCreationLease()
	return serviceState.entry.lease
end

function Borrow.IsEntryCreationLeaseCurrent(lease, options)
	return entryLeaseMatches(lease, options)
end

function Borrow.RecoverEntryCreationLease()
	local lease = serviceState.entry.lease
	if lease == nil then
		return true
	end
	return Borrow.ReleaseEntryCreationLease(lease)
end

function Borrow.AcquireEntryCreationLease(options)
	options = options or {}
	local channel = serviceState.entry
	if channel.lease ~= nil and channel.lease.aborted == true then
		Borrow.RecoverEntryCreationLease()
	end
	local creation = options.creation
		or (LFGListFrame and LFGListFrame.EntryCreation)
	local nativeParent = options.nativeParent or LFGListFrame
	local host = options.host
	local owner = options.owner
	local leaseChannel = options.channel or CREATE_FIELD_CHANNEL
	if channel.lease ~= nil or owner == nil or host == nil
		or not usableFrame(creation)
		or not protectedChildrenKeepNativeParents(creation)
	then
		return nil
	end
	local parent, parentOK = readMethod(creation, "GetParent")
	if not parentOK
		or parent ~= nativeParent and parent ~= Borrow.GetHideSink()
	then
		return nil
	end

	channel.phase = Borrow.STATE_PENDING
	local snapshot = captureEntryState(creation)
	if snapshot == nil then
		channel.phase = Borrow.STATE_IDLE
		return nil
	end
	local lease = {
		kind = "entry-creation",
		generation = nextGeneration(channel),
		owner = owner,
		channel = leaseChannel,
		contextKey = options.contextKey,
		creation = creation,
		nativeParent = nativeParent,
		host = host,
		snapshot = snapshot,
		phase = Borrow.STATE_PENDING,
	}
	channel.lease = lease

	local embedded = callMethod(creation, "Hide")
	embedded = callMethod(creation, "SetParent", host) and embedded
	embedded = callMethod(creation, "ClearAllPoints") and embedded
	embedded = callMethod(creation, "SetPoint", "TOPLEFT", host, "TOPLEFT")
		and embedded
	embedded = callMethod(
		creation,
		"SetPoint",
		"BOTTOMRIGHT",
		host,
		"BOTTOMRIGHT"
	) and embedded
	if type(creation.SetFrameLevel) == "function"
		and type(host.GetFrameLevel) == "function"
	then
		local level, levelOK = readMethod(host, "GetFrameLevel")
		if levelOK then
			embedded = callMethod(
				creation,
				"SetFrameLevel",
				(level or 0) + 2
			) and embedded
		else
			embedded = false
		end
	end
	embedded = Borrow.MarkBorrowed(
		creation,
		owner,
		leaseChannel,
		lease
	) and embedded

	if not embedded then
		local restored = restoreEntryState(lease, true)
		if restored then
			Borrow.ClearBorrowed(creation, owner, leaseChannel, lease)
			lease.released = true
			channel.lease = nil
			channel.phase = Borrow.STATE_IDLE
		else
			lease.aborted = true
			lease.phase = Borrow.STATE_RELEASING
			channel.phase = Borrow.STATE_RELEASING
		end
		return nil
	end
	lease.phase = Borrow.STATE_OWNED
	channel.phase = Borrow.STATE_OWNED
	Borrow.SetActiveOwner(owner)
	return lease
end

function Borrow.SetEntryCreationLeaseVisible(lease, shown)
	if not entryLeaseMatches(lease) then
		return false
	end
	local creation = lease.creation
	local marker = shown and "_gfShowingBorrowedEntryCreation"
		or "_gfHidingBorrowedEntryCreation"
	creation[marker] = true
	local ok = callMethod(creation, "SetShown", shown == true)
	creation[marker] = nil
	return ok
end

local function resolveReleaseVisibility(lease, options)
	local requested = options and options.show
	if type(requested) == "function" then
		local ok, shown = pcall(requested, lease)
		if not ok then
			return nil, false
		end
		return shown == true, true
	end
	if requested ~= nil then
		return requested == true, true
	end
	return lease.snapshot.container.shown == true, true
end

function Borrow.ReleaseEntryCreationLease(lease, options)
	if type(lease) == "table" and lease.released == true then
		return true
	end
	if not entryLeaseMatches(lease) then
		return false
	end
	options = options or lease.releaseOptions or {}
	lease.releaseOptions = options
	local channel = serviceState.entry
	channel.phase = Borrow.STATE_RELEASING
	lease.phase = Borrow.STATE_RELEASING
	local creation = lease.creation
	local ok = callMethod(creation, "Hide")

	local beforeRestore = options.beforeRestore
	if type(beforeRestore) == "function" then
		ok = pcall(beforeRestore, lease) and ok
	end
	ok = restoreEntryState(lease) and ok
	ok = refreshNativeAuthentication(creation) and ok

	local shown, visibilityOK = resolveReleaseVisibility(lease, options)
	ok = visibilityOK and ok
	creation._gfRestoringBorrowedEntryCreation = true
	if visibilityOK then
		ok = callMethod(creation, "SetShown", shown) and ok
	end
	creation._gfRestoringBorrowedEntryCreation = nil

	local afterRestore = options.afterRestore
	if type(afterRestore) == "function" then
		ok = pcall(afterRestore, lease, ok) and ok
	end
	if not ok then
		return false
	end
	Borrow.ClearBorrowed(creation, lease.owner, lease.channel, lease)
	lease.released = true
	lease.aborted = nil
	lease.phase = Borrow.STATE_IDLE
	lease.snapshot = nil
	channel.lease = nil
	channel.phase = Borrow.STATE_IDLE
	Borrow.SetActiveOwner(options.ownerAfterRelease)
	return true
end

-- Short-lived selection context lease used by quest create/relist. Only
-- ordinary scalar selection fields are snapshotted; protected text is cleared
-- through NativeCreationGateway by the caller's synchronous apply callback.
function Borrow.GetEntryCreationContextLeaseState()
	local state = serviceState.context
	return state.phase, state.generation, state.lease
end

local function restoreContextValues(lease)
	local creation = lease and lease.creation
	if creation == nil or type(lease.values) ~= "table" then
		return false
	end
	local ok = true
	for key, wrapped in pairs(lease.values) do
		local wrote = pcall(function()
			creation[key] = wrapped.value
		end)
		ok = wrote and ok
	end
	return ok
end

function Borrow.IsEntryCreationContextLeaseCurrent(lease)
	return type(lease) == "table" and lease.released ~= true
		and serviceState.context.lease == lease
		and serviceState.context.generation == lease.generation
end

function Borrow.RecoverEntryCreationContextLease()
	local lease = serviceState.context.lease
	if lease == nil then
		return true
	end
	return Borrow.ReleaseEntryCreationContextLease(lease)
end

function Borrow.AcquireEntryCreationContextLease(options)
	options = options or {}
	local channel = serviceState.context
	if channel.lease ~= nil and channel.lease.aborted == true then
		Borrow.RecoverEntryCreationContextLease()
	end
	local creation = options.creation
		or (LFGListFrame and LFGListFrame.EntryCreation)
	local fields = options.fields
	if channel.lease ~= nil or not usableFrame(creation)
		or type(fields) ~= "table" or type(options.apply) ~= "function"
	then
		return nil
	end
	local entryLease = serviceState.entry.lease
	if entryLease ~= nil and options.entryLease ~= entryLease then
		return nil
	end

	channel.phase = Borrow.STATE_PENDING
	local lease = {
		kind = "entry-creation-context",
		generation = nextGeneration(channel),
		owner = options.owner,
		channel = options.channel,
		creation = creation,
		values = {},
		phase = Borrow.STATE_PENDING,
	}
	for index = 1, #fields do
		local key = fields[index]
		lease.values[key] = { value = creation[key] }
	end
	channel.lease = lease
	local callOK, applied = pcall(options.apply, creation, lease)
	if not callOK or applied ~= true then
		if restoreContextValues(lease) then
			lease.released = true
			channel.lease = nil
			channel.phase = Borrow.STATE_IDLE
		else
			lease.aborted = true
			lease.phase = Borrow.STATE_RELEASING
			channel.phase = Borrow.STATE_RELEASING
		end
		return nil
	end
	lease.phase = Borrow.STATE_OWNED
	channel.phase = Borrow.STATE_OWNED
	return lease
end

function Borrow.ReleaseEntryCreationContextLease(lease, options)
	if type(lease) == "table" and lease.released == true then
		return true
	end
	if not Borrow.IsEntryCreationContextLeaseCurrent(lease) then
		return false
	end
	local channel = serviceState.context
	channel.phase = Borrow.STATE_RELEASING
	lease.phase = Borrow.STATE_RELEASING
	local ok = restoreContextValues(lease)
	local validate = options and options.validate
	if type(validate) == "function" then
		ok = pcall(validate, lease.creation, lease) and ok
	end
	if not ok then
		return false
	end
	lease.released = true
	lease.aborted = nil
	lease.phase = Borrow.STATE_IDLE
	lease.values = nil
	channel.lease = nil
	channel.phase = Borrow.STATE_IDLE
	return true
end

-- Active-entry relist event fence -------------------------------------------

local BUMP_CONSUMER_SPECS = {
	{ nativeLFGRoot = true },
	{
		addonName = "MeetingStone",
		moduleName = "CreatePanel",
	},
	{
		addonName = "MyKeyStone",
		callbackName = "HandleMeetingStoneActiveEntryUpdate",
	},
}

local function groupFinderEventFrame(frame)
	if frame == GF.LFGEventDispatcher then
		return true
	end
	local ok, marked = pcall(function()
		return frame._groupFinderEventConsumer
	end)
	return ok and marked == true
end

local function addonLoadState(name)
	local getLoadState = GF.Compat and GF.Compat.GetAddOnLoadState
	if type(getLoadState) ~= "function" then
		return "unknown"
	end
	local loadedOrLoading, loaded, reason = getLoadState(name)
	if reason ~= nil then
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
	if spec.nativeLFGRoot == true then
		return LFGListFrame
	end
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
	local consumerType = type(consumer)
	if consumerType ~= "table" and consumerType ~= "userdata" then
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
	if spec.nativeLFGRoot ~= true then
		local loadState = addonLoadState(spec.addonName)
		if loadState == "unloaded" then
			return "skipped"
		end
		if loadState ~= "loaded" then
			return "failed"
		end
	end
	local consumer = resolveConsumer(spec)
	local running = consumerIsRunning(consumer)
	if running == false then
		return "skipped"
	end
	if running ~= true
		or type(consumer.UnregisterEvent) ~= "function"
		or type(consumer.RegisterEvent) ~= "function"
	then
		return "failed"
	end
	if spec.nativeLFGRoot == true then
		if type(consumer.IsEventRegistered) ~= "function" then
			return "failed"
		end
		local registeredOK, registered = pcall(
			consumer.IsEventRegistered,
			consumer,
			ACTIVE_ENTRY_EVENT
		)
		if not registeredOK or registered ~= true then
			return "failed"
		end
		return "ready", {
			consumer = consumer,
			eventFrame = true,
			source = "native",
		}
	end
	local callbackMethod = spec.callbackName or ACTIVE_ENTRY_EVENT
	if type(consumer[callbackMethod]) ~= "function" then
		return "failed"
	end
	return "ready", {
		consumer = consumer,
		callbackName = spec.callbackName,
		source = spec.addonName,
	}
end

local function appendPrepared(prepared, seen, state)
	local consumer = state and state.consumer
	if consumer == nil or seen[consumer] then
		return true
	end
	seen[consumer] = true
	prepared[#prepared + 1] = state
	return true
end

local function appendRegisteredEventConsumers(prepared, seen)
	local enumerate = GetFramesRegisteredForEvent
	if type(enumerate) ~= "function" then
		return false
	end
	local ok, frames = pcall(function()
		return { enumerate(ACTIVE_ENTRY_EVENT) }
	end)
	if not ok then
		return false
	end
	for index = 1, #frames do
		local frame = frames[index]
		if frame ~= nil and not seen[frame] and not groupFinderEventFrame(frame) then
			if type(frame.UnregisterEvent) ~= "function"
				or type(frame.RegisterEvent) ~= "function"
				or type(frame.IsEventRegistered) ~= "function"
			then
				return false
			end
			local registeredOK, registered = pcall(
				frame.IsEventRegistered,
				frame,
				ACTIVE_ENTRY_EVENT
			)
			if not registeredOK or registered ~= true then
				return false
			end
			appendPrepared(prepared, seen, {
				consumer = frame,
				eventFrame = true,
				source = "public-frame",
			})
		end
	end
	return true
end

local function resumeOne(state)
	if state == nil or state.paused ~= true then
		return true
	end
	local consumer = state.consumer
	local register = consumer and consumer.RegisterEvent
	if type(register) ~= "function" then
		return false
	end
	local ok
	if state.callbackName ~= nil then
		ok = pcall(
			register,
			consumer,
			ACTIVE_ENTRY_EVENT,
			state.callbackName
		)
	else
		ok = pcall(register, consumer, ACTIVE_ENTRY_EVENT)
	end
	if ok and state.eventFrame == true then
		local checked, registered = pcall(
			consumer.IsEventRegistered,
			consumer,
			ACTIVE_ENTRY_EVENT
		)
		ok = checked and registered == true
	end
	if ok then
		state.paused = false
	end
	return ok
end

local function resumeFence(lease)
	if type(lease) ~= "table" or type(lease.consumers) ~= "table" then
		return false
	end
	local ok = true
	for index = #lease.consumers, 1, -1 do
		ok = resumeOne(lease.consumers[index]) and ok
	end
	lease.resumed = ok
	return ok
end

local function pauseOne(state)
	state.paused = true
	local consumer = state.consumer
	local ok = pcall(
		consumer.UnregisterEvent,
		consumer,
		ACTIVE_ENTRY_EVENT
	)
	if ok and state.eventFrame == true then
		local checked, registered = pcall(
			consumer.IsEventRegistered,
			consumer,
			ACTIVE_ENTRY_EVENT
		)
		ok = checked and registered == false
	end
	if not ok and state.eventFrame == true
		and type(consumer.IsEventRegistered) == "function"
	then
		local checked, registered = pcall(
			consumer.IsEventRegistered,
			consumer,
			ACTIVE_ENTRY_EVENT
		)
		-- If UnregisterEvent raised after mutating state, rollback must still
		-- include this consumer.
		state.paused = not checked or registered ~= true
	elseif not ok then
		state.paused = true
	end
	return ok
end

local function replayInactiveToOne(state)
	if state == nil or state.inactiveReplayed == true then
		return true
	end
	local consumer = state.consumer
	if consumer == nil then
		return false
	end
	local getScript = consumer.GetScript
	if type(getScript) == "function" then
		local scriptOK, onEvent = pcall(getScript, consumer, "OnEvent")
		if not scriptOK then
			return false
		end
		if type(onEvent) == "function" then
			local ok = pcall(onEvent, consumer, ACTIVE_ENTRY_EVENT, nil)
			if ok then
				state.inactiveReplayed = true
			end
			return ok
		end
	end
	local callbackMethod = state.callbackName or ACTIVE_ENTRY_EVENT
	local callback = consumer[callbackMethod]
	if type(callback) ~= "function" then
		return false
	end
	local ok = pcall(callback, consumer, ACTIVE_ENTRY_EVENT, nil)
	if ok then
		state.inactiveReplayed = true
	end
	return ok
end

local function replayInactive(lease)
	if type(lease) ~= "table" or type(lease.consumers) ~= "table" then
		return false
	end
	local ok = true
	for _, state in ipairs(lease.consumers) do
		-- Known AceEvent consumers are reached through their public dispatcher
		-- frame. Replaying their callback separately would deliver the missed
		-- transition twice.
		if state.eventFrame == true then
			ok = replayInactiveToOne(state) and ok
		end
	end
	lease.replayed = ok
	return ok
end

local function entryTextFieldsExist()
	local frame = LFGListFrame
	local creation = frame and frame.EntryCreation
	return creation ~= nil
		and creation.Name ~= nil
		and creation.Description ~= nil
		and creation.Description.EditBox ~= nil
end

function Borrow.GetEntryCreationBumpLeaseState()
	local state = serviceState.fence
	return state.phase, state.generation, state.lease
end

function Borrow.IsEntryCreationBumpLeaseCurrent(lease)
	return type(lease) == "table" and lease.released ~= true
		and serviceState.fence.lease == lease
		and serviceState.fence.generation == lease.generation
end

function Borrow.RecoverEntryCreationBumpLease()
	local lease = serviceState.fence.lease
	if lease == nil then
		return true
	end
	return Borrow.ReleaseEntryCreationBumpLease(lease)
end

function Borrow.AcquireEntryCreationBumpLease()
	local channel = serviceState.fence
	if channel.lease ~= nil and channel.lease.restoreFailed == true then
		Borrow.RecoverEntryCreationBumpLease()
	end
	if channel.lease ~= nil or not entryTextFieldsExist() then
		return nil
	end
	channel.phase = Borrow.STATE_PENDING
	local prepared, seen = {}, {}
	for _, spec in ipairs(BUMP_CONSUMER_SPECS) do
		local status, state = prepareConsumer(spec)
		if status == "failed" then
			channel.phase = Borrow.STATE_IDLE
			return nil
		end
		if status == "ready" then
			appendPrepared(prepared, seen, state)
		end
	end
	if not appendRegisteredEventConsumers(prepared, seen) then
		channel.phase = Borrow.STATE_IDLE
		return nil
	end

	local lease = {
		kind = "active-entry-fence",
		generation = nextGeneration(channel),
		phase = Borrow.STATE_PENDING,
		consumers = prepared,
	}
	channel.lease = lease
	for index = 1, #prepared do
		if not pauseOne(prepared[index]) then
			lease.restoreFailed = not resumeFence(lease)
			if lease.restoreFailed then
				channel.phase = Borrow.STATE_RELEASING
				lease.phase = Borrow.STATE_RELEASING
			else
				lease.released = true
				channel.lease = nil
				channel.phase = Borrow.STATE_IDLE
			end
			return nil
		end
	end
	lease.phase = Borrow.STATE_OWNED
	channel.phase = Borrow.STATE_OWNED
	return lease
end

function Borrow.ResumeEntryCreationBumpConsumers(lease)
	if type(lease) == "table" and lease.released == true then
		return true
	end
	if not Borrow.IsEntryCreationBumpLeaseCurrent(lease) then
		return false
	end
	serviceState.fence.phase = Borrow.STATE_RELEASING
	lease.phase = Borrow.STATE_RELEASING
	return resumeFence(lease)
end

function Borrow.ResumeAndReplayInactiveEntry(lease)
	if type(lease) == "table" and lease.released == true then
		return true
	end
	if not Borrow.IsEntryCreationBumpLeaseCurrent(lease) then
		return false
	end
	lease.replayRequested = true
	if not Borrow.ResumeEntryCreationBumpConsumers(lease) then
		return false
	end
	return replayInactive(lease)
end

function Borrow.ReleaseEntryCreationBumpLease(lease)
	if type(lease) == "table" and lease.released == true then
		return true
	end
	if not Borrow.IsEntryCreationBumpLeaseCurrent(lease) then
		return false
	end
	local ok = resumeFence(lease)
	if ok and lease.replayRequested == true then
		ok = replayInactive(lease)
	end
	if not ok then
		lease.restoreFailed = true
		serviceState.fence.phase = Borrow.STATE_RELEASING
		lease.phase = Borrow.STATE_RELEASING
		return false
	end
	lease.restoreFailed = nil
	lease.released = true
	lease.phase = Borrow.STATE_IDLE
	serviceState.fence.lease = nil
	serviceState.fence.phase = Borrow.STATE_IDLE
	return true
end

local listing = GF.RecruitmentSession
if listing ~= nil and type(listing.SetRelistFieldBridge) == "function" then
	listing:SetRelistFieldBridge({
		Acquire = function()
			return Borrow.AcquireEntryCreationBumpLease()
		end,
		Resume = function(lease, replayMissedInactive)
			if replayMissedInactive == true then
				return Borrow.ResumeAndReplayInactiveEntry(lease)
			end
			return Borrow.ResumeEntryCreationBumpConsumers(lease)
		end,
		Release = function(lease)
			return Borrow.ReleaseEntryCreationBumpLease(lease)
		end,
		PrepareQuest = function(resolved)
			local panel = GF.CreatePanel
			if panel == nil
				or type(panel.AcquireQuestRelistFieldLease) ~= "function"
			then
				return nil
			end
			return panel:AcquireQuestRelistFieldLease(resolved)
		end,
		ReleaseQuest = function(lease)
			local panel = GF.CreatePanel
			if panel ~= nil
				and type(panel.ReleaseQuestRecruitmentFieldLease) == "function"
			then
				return panel:ReleaseQuestRecruitmentFieldLease(lease)
			end
			return false
		end,
	})
end
