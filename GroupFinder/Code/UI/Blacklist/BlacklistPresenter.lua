local _, GF = ...

-- BlacklistPresenter is the only UI-side owner of blacklist row projections,
-- selection, drafts, confirmation tickets, and player-context action plans.
-- Persistence remains exclusively behind BlacklistRepository/Blocklist.
local Presenter = {}
GF.BlacklistPresenter = Presenter

local DEFAULT_SORT_KEY = "updated"
local CATEGORY_SORT_KEY = "reason"
local CONTEXT_COPY = "copy-player-name"
local CONTEXT_ADD = "add-player"

local REASON_SORT_ORDER = {
	ad = 1,
	title_parent = 2,
	same_title_ad = 3,
	manual = 4,
}

local state = {
	sortKey = DEFAULT_SORT_KEY,
	sortAsc = false,
	revision = -1,
	rows = {},
	byKey = {},
	identityByKey = {},
	selection = nil,
	nextTicket = 0,
	pendingAdd = nil,
	pendingClear = nil,
}

local function blocklist()
	return GF.Blocklist
end

local function call(owner, methodName, ...)
	local method = owner and owner[methodName]
	if type(method) ~= "function" then
		return false, nil
	end
	local ok, value, extra = pcall(method, owner, ...)
	if not ok then
		return false, nil
	end
	return true, value, extra
end

local function localized(key, fallback)
	local locale = GF.L or {}
	local value = locale[key]
	return type(value) == "string" and value ~= "" and value
		or fallback or key
end

local function trim(value)
	if type(value) ~= "string" then
		return ""
	end
	return value:match("^%s*(.-)%s*$") or ""
end

local function currentRevision()
	local owner = blocklist()
	local ok, revision = call(owner, "GetRevision")
	return ok and math.max(0, tonumber(revision) or 0) or 0
end

local function nextTicket(prefix)
	state.nextTicket = state.nextTicket + 1
	return tostring(prefix or "blacklist") .. ":" .. tostring(state.nextTicket)
end

local function compareByUpdated(left, right, ascending)
	local leftTime = tonumber(left and (left.updatedAt or left.addedAt)) or 0
	local rightTime = tonumber(right and (right.updatedAt or right.addedAt)) or 0
	if leftTime ~= rightTime then
		if ascending then
			return leftTime < rightTime
		end
		return leftTime > rightTime
	end
	local leftName = tostring(left and (left.displayName or left.name or left.key) or "")
	local rightName = tostring(right and (right.displayName or right.name or right.key) or "")
	if leftName ~= rightName then
		return leftName < rightName
	end
	return tostring(left and left.key or "") < tostring(right and right.key or "")
end

local function compareByReason(left, right, ascending)
	local leftOrder = REASON_SORT_ORDER[left and left.reason or "manual"] or 999
	local rightOrder = REASON_SORT_ORDER[right and right.reason or "manual"] or 999
	if leftOrder ~= rightOrder then
		if ascending then
			return leftOrder < rightOrder
		end
		return leftOrder > rightOrder
	end
	return compareByUpdated(left, right)
end

local function projectEntry(owner, entry, revision)
	if type(entry) ~= "table" or entry.key == nil then
		return nil
	end
	local reason = type(entry.reason) == "string" and entry.reason or "manual"
	local reasonText = reason
	local sourceText = ""
	local ok, value = call(owner, "GetEntryReasonText", reason)
	if ok and type(value) == "string" then
		reasonText = value
	end
	ok, value = call(owner, "GetEntrySourceText", reason)
	if ok and type(value) == "string" then
		sourceText = value
	end
	return {
		key = entry.key,
		projectionKey = "blacklist:" .. tostring(entry.key),
		revision = revision,
		name = entry.name,
		realm = entry.realm,
		displayName = entry.displayName or entry.name or tostring(entry.key),
		note = tostring(entry.note or ""),
		reason = reason,
		reasonText = reasonText,
		sourceText = sourceText,
		source = entry.source,
		sourceTitle = entry.sourceTitle,
		addedAt = tonumber(entry.addedAt) or 0,
		updatedAt = tonumber(entry.updatedAt) or tonumber(entry.addedAt) or 0,
	}
end

local function findSourceIdentity(sourceEntry)
	if type(sourceEntry) ~= "table" then
		return nil
	end
	return sourceEntry._row or sourceEntry
end

local function reconcileSelection(nextByKey, nextIdentities)
	local selection = state.selection
	if not selection then
		return
	end
	local row = nextByKey[selection.key]
	local identity = nextIdentities[selection.key]
	if not row or identity == nil or identity ~= selection.identity then
		state.selection = nil
		return
	end
	selection.revision = row.revision
	if selection.kind == "edit-note"
		and selection.originalNote ~= row.note
	then
		selection.conflicted = true
	end
end

function Presenter:IsEnabled()
	local ok, enabled = call(blocklist(), "IsEnabled")
	return ok and enabled == true
end

function Presenter:GetRevision()
	return math.max(0, tonumber(state.revision) or 0)
end

function Presenter:GetSortKey()
	return state.sortKey
end

function Presenter:GetSortState()
	return { column = state.sortKey, asc = state.sortAsc }
end

function Presenter:SetSortKey(sortKey, ascending)
	local resolved = sortKey == CATEGORY_SORT_KEY
		and CATEGORY_SORT_KEY or DEFAULT_SORT_KEY
	if type(ascending) ~= "boolean" then
		if state.sortKey == resolved then
			ascending = state.sortAsc
		else
			ascending = resolved == CATEGORY_SORT_KEY
		end
	end
	if state.sortKey == resolved and state.sortAsc == ascending then
		return false
	end
	state.sortKey = resolved
	state.sortAsc = ascending
	return true
end

function Presenter:ToggleSort(sortKey)
	if state.sortKey == sortKey then
		return self:SetSortKey(sortKey, not state.sortAsc)
	end
	return self:SetSortKey(sortKey)
end

function Presenter:RefreshProjection(query)
	local owner = blocklist()
	local revision = currentRevision()
	local sourceEntries = {}
	local ok, value = call(owner, "GetBlacklistEntries")
	if ok and type(value) == "table" then
		sourceEntries = value
	end

	local rows, byKey, identities = {}, {}, {}
	for index = 1, #sourceEntries do
		local sourceEntry = sourceEntries[index]
		local row = projectEntry(owner, sourceEntry, revision)
		if row and byKey[row.key] == nil then
			rows[#rows + 1] = row
			byKey[row.key] = row
			identities[row.key] = findSourceIdentity(sourceEntry)
		end
	end
	local compare = state.sortKey == CATEGORY_SORT_KEY
		and compareByReason or compareByUpdated
	local ascending = state.sortAsc
	table.sort(rows, function(left, right)
		return compare(left, right, ascending)
	end)

	reconcileSelection(byKey, identities)
	state.rows = rows
	state.byKey = byKey
	state.identityByKey = identities
	state.revision = revision
	local total = #rows
	query = trim(query):lower()
	if query ~= "" then
		local matches = {}
		for _, row in ipairs(rows) do
			if tostring(row.displayName):lower():find(query, 1, true) or row.note:lower():find(query, 1, true) then
				matches[#matches + 1] = row
			end
		end
		state.rows = matches
	end
	return state.rows, revision, total
end

function Presenter:GetRows()
	return state.rows, self:GetRevision()
end

function Presenter:GetRow(key)
	return key ~= nil and state.byKey[key] or nil
end

function Presenter:GetSelection()
	local selection = state.selection
	if not selection then
		return nil
	end
	return {
		kind = selection.kind,
		key = selection.key,
		revision = selection.revision,
		ticket = selection.ticket,
		draft = selection.draft,
		originalNote = selection.originalNote,
		conflicted = selection.conflicted == true,
	}
end

function Presenter:GetSelectedKey()
	return state.selection and state.selection.key or nil
end

function Presenter:IsSelected(key, kind)
	local selection = state.selection
	return selection ~= nil
		and selection.key == key
		and (kind == nil or selection.kind == kind)
end

function Presenter:ClearSelection(kind)
	if not state.selection
		or (kind ~= nil and state.selection.kind ~= kind)
	then
		return false
	end
	state.selection = nil
	return true
end

local function selectRow(key, kind)
	local row = state.byKey[key]
	local identity = state.identityByKey[key]
	if not row or identity == nil then
		return nil
	end
	local selection = {
		kind = kind,
		key = key,
		identity = identity,
		revision = row.revision,
		ticket = nextTicket(kind),
	}
	state.selection = selection
	return selection, row
end

function Presenter:BeginNoteEdit(key)
	local selection, row = selectRow(key, "edit-note")
	if not selection then
		return nil
	end
	selection.originalNote = row.note
	selection.draft = row.note
	selection.conflicted = false
	return self:GetSelection()
end

function Presenter:GetNoteDraft(key)
	local selection = state.selection
	if not selection or selection.kind ~= "edit-note"
		or (key ~= nil and key ~= selection.key)
	then
		return nil
	end
	return selection.draft or "", selection.originalNote or ""
end

function Presenter:UpdateNoteDraft(value)
	local selection = state.selection
	if not selection or selection.kind ~= "edit-note" then
		return false
	end
	selection.draft = tostring(value or "")
	return true
end

function Presenter:CanSaveNote()
	local selection = state.selection
	return selection ~= nil
		and selection.kind == "edit-note"
		and selection.conflicted ~= true
		and (selection.draft or "") ~= (selection.originalNote or "")
end

function Presenter:PlanSaveNote()
	local selection = state.selection
	if not self:CanSaveNote() then
		return nil
	end
	return {
		kind = "save-note",
		key = selection.key,
		ticket = selection.ticket,
		expectedNote = selection.originalNote or "",
		note = selection.draft or "",
		revision = selection.revision,
	}
end

local function selectionMatchesPlan(plan, selection, kind)
	return type(plan) == "table"
		and selection ~= nil
		and selection.kind == kind
		and plan.ticket == selection.ticket
		and plan.key == selection.key
		and state.identityByKey[selection.key] == selection.identity
end

function Presenter:ConfirmSaveNote(plan)
	local selection = state.selection
	if not selectionMatchesPlan(plan, selection, "edit-note")
		or selection.conflicted == true
	then
		return false
	end
	local row = state.byKey[selection.key]
	if not row or row.note ~= (plan.expectedNote or "") then
		selection.conflicted = true
		return false
	end
	-- Clear first: Blocklist refreshes the visible page synchronously on success.
	state.selection = nil
	local ok, committed = call(
		blocklist(), "SetBlacklistNote", plan.key, tostring(plan.note or ""))
	if not ok or committed ~= true then
		state.selection = selection
		return false
	end
	return true
end

function Presenter:CancelNoteEdit()
	return self:ClearSelection("edit-note")
end

function Presenter:PlanRemove(key)
	local selection, row = selectRow(key, "remove")
	if not selection then
		return nil
	end
	selection.displayName = row.displayName
	return {
		kind = "remove",
		key = key,
		ticket = selection.ticket,
		revision = selection.revision,
		displayName = row.displayName,
	}
end

function Presenter:ConfirmRemove(plan)
	local selection = state.selection
	if not selectionMatchesPlan(plan, selection, "remove") then
		return false
	end
	state.selection = nil
	local ok, removed = call(blocklist(), "RemovePlayerFromBlacklist", plan.key)
	if not ok or removed ~= true then
		state.selection = selection
		return false
	end
	return true
end

function Presenter:CancelRemove(ticket)
	local selection = state.selection
	if not selection or selection.kind ~= "remove"
		or (ticket ~= nil and ticket ~= selection.ticket)
	then
		return false
	end
	state.selection = nil
	return true
end

function Presenter:CanAddManualPlayer()
	local owner = blocklist()
	return self:IsEnabled()
		and owner ~= nil
		and type(owner.AddManualPlayer) == "function"
end

function Presenter:PlanManualAdd(playerName, options)
	options = type(options) == "table" and options or {}
	if not self:CanAddManualPlayer()
		or type(playerName) ~= "string" or playerName == ""
		or options.isSelf ~= false
	then
		return nil
	end
	local pending = {
		kind = "manual-add",
		ticket = nextTicket("manual-add"),
		playerName = playerName,
		classFile = options.classFile,
		displayName = options.displayName or playerName,
		draft = "",
		onAdded = type(options.onAdded) == "function" and options.onAdded or nil,
	}
	state.pendingAdd = pending
	return {
		kind = pending.kind,
		ticket = pending.ticket,
		playerName = pending.playerName,
		classFile = pending.classFile,
		displayName = pending.displayName,
		draft = pending.draft,
	}
end

function Presenter:GetPendingAdd()
	local pending = state.pendingAdd
	if not pending then
		return nil
	end
	return {
		kind = pending.kind,
		ticket = pending.ticket,
		playerName = pending.playerName,
		classFile = pending.classFile,
		displayName = pending.displayName,
		draft = pending.draft,
	}
end

function Presenter:UpdateAddDraft(ticket, note)
	local pending = state.pendingAdd
	if not pending or (ticket ~= nil and ticket ~= pending.ticket) then
		return false
	end
	pending.draft = tostring(note or "")
	return true
end

function Presenter:ConfirmManualAdd(ticket, note)
	local pending = state.pendingAdd
	if not pending or (ticket ~= nil and ticket ~= pending.ticket)
		or not self:CanAddManualPlayer()
	then
		return false
	end
	local resolvedNote = trim(note == nil and pending.draft or note)
	if resolvedNote == "" then
		local ok, fallback = call(blocklist(), "GetBlacklistNoteManual")
		resolvedNote = ok and type(fallback) == "string" and fallback
			or "手动拉黑"
	end
	local ok, added = call(
		blocklist(), "AddManualPlayer", pending.playerName, resolvedNote)
	if not ok or added ~= true then
		return false
	end
	state.pendingAdd = nil
	if pending.onAdded then
		pcall(pending.onAdded, pending.playerName)
	end
	return true
end

function Presenter:CancelManualAdd(ticket)
	local pending = state.pendingAdd
	if not pending or (ticket ~= nil and ticket ~= pending.ticket) then
		return false
	end
	state.pendingAdd = nil
	return true
end

function Presenter:PlanClear()
	local owner = blocklist()
	if not self:IsEnabled() or not owner or type(owner.ClearBlacklist) ~= "function" then return nil end
	state.pendingClear = nextTicket("clear")
	return state.pendingClear
end

function Presenter:ConfirmClear(ticket)
	if not ticket or ticket ~= state.pendingClear or not self:IsEnabled() then return false end
	self:CancelNoteEdit()
	self:CancelManualAdd()
	local ok, cleared = call(blocklist(), "ClearBlacklist")
	if ok and cleared == true and state.pendingClear == ticket then state.pendingClear = nil end
	return ok and cleared == true
end

function Presenter:CancelClear(ticket)
	if ticket and ticket == state.pendingClear then state.pendingClear = nil; return true end
	return false
end

function Presenter:BuildContextActionPlan(playerName, options)
	options = type(options) == "table" and options or {}
	if type(playerName) ~= "string" or playerName == ""
		or type(options.isSelf) ~= "boolean"
	then
		return nil
	end
	local plan = {
		title = localized("PLAYER_CONTEXT_MENU_TITLE", "GroupFinder"),
		playerName = playerName,
		copyPlayerName = type(options.copyPlayerName) == "string"
			and options.copyPlayerName ~= "" and options.copyPlayerName
			or playerName,
		classFile = options.classFile,
		isSelf = options.isSelf,
		actions = {
			{
				id = CONTEXT_COPY,
				labelKey = "APPLICANT_COPY_NAME",
				fallback = "复制角色名",
			},
		},
	}
	if options.isSelf == false and self:CanAddManualPlayer() then
		plan.actions[#plan.actions + 1] = {
			id = CONTEXT_ADD,
			labelKey = "BLOCKLIST_SOURCE_MANUAL",
			fallback = "加入黑名单",
			danger = true,
		}
	end
	return plan
end

function Presenter:GetContextActionLabel(action)
	if type(action) ~= "table" then
		return ""
	end
	return localized(action.labelKey, action.fallback)
end

function Presenter:GetContextActionIDs()
	return CONTEXT_COPY, CONTEXT_ADD
end

function Presenter:ResetRuntimeState()
	state.sortKey = DEFAULT_SORT_KEY
	state.sortAsc = false
	state.revision = -1
	state.rows = {}
	state.byKey = {}
	state.identityByKey = {}
	state.selection = nil
	state.pendingAdd = nil
	state.pendingClear = nil
	state.nextTicket = 0
end
