local addonName, GF = ...

-- GF.Apply is the compatibility and presentation boundary for Find Group
-- application behavior. ApplicationService owns native state and actions;
-- this facade owns dialogs, notes, click gestures, and visible refreshes.
GF.Apply = {}
local AP = GF.Apply
local ApplicationService = assert(
	GF.ApplicationService,
	"GroupFinder ApplicationService must load before Apply")

AP.DBLCLICK_SEC = 0.3

local SERVICE_STATE_KEYS = {
	_applicationPriorityByResultID = true,
	_applicationPrioritySequence = true,
	_rejectionLedger = true,
	_acceptInFlight = true,
	_roleCheckConfirmInFlight = true,
	localCancelled = true,
	localCancelledTokens = true,
	joinedApplications = true,
	suppressedJoinedApplications = true,
	currentGroupResultID = true,
	currentGroupPartyGUID = true,
	_wasInHomeGroup = true,
}

setmetatable(AP, {
	__index = function(_, key)
		if SERVICE_STATE_KEYS[key] then
			return ApplicationService[key]
		end
	end,
	__newindex = function(owner, key, value)
		if SERVICE_STATE_KEYS[key] then
			ApplicationService[key] = value
			return
		end
		rawset(owner, key, value)
	end,
})

local PresentationPort = {}

function PresentationPort:GetRejectionFeedbackScope()
	local panel = GF.BrowsePanel
	if type(panel) ~= "table"
		or panel.awaitingGFSearch == true
		or panel.gfOwnsSearch ~= true
	then
		return nil
	end
	if type(panel.ShouldProcessSearchUpdates) == "function"
		and panel:ShouldProcessSearchUpdates() ~= true
	then
		return nil
	end
	local activeKey = panel.activeSearchKey
	local selectionKey = type(panel.GetSelectionKey) == "function"
		and panel:GetSelectionKey() or nil
	if activeKey == nil or activeKey ~= selectionKey then
		return nil
	end
	return {
		searchToken = panel._searchToken,
		activeKey = activeKey,
	}
end

function PresentationPort:DiscardManualDeclineIntent()
	local panel = GF.BrowsePanel
	if panel
		and type(panel.DiscardPendingManualDeclineIntent) == "function"
	then
		panel:DiscardPendingManualDeclineIntent()
	elseif panel and type(panel.DiscardManualDeclineRefresh) == "function" then
		panel:DiscardManualDeclineRefresh()
	end
end

function PresentationPort:OnRejectionFeedbackExpired()
	local tab = GF.FindGroupTab
	if tab and type(tab.ApplyClientFilters) == "function" then
		tab:ApplyClientFilters({ preserveOrder = true })
	end
end

function PresentationPort:GetApplicationContext()
	local panel = GF.BrowsePanel
	if not panel then return nil end
	return { searchToken = panel._searchToken, searchKey = panel.activeSearchKey }
end

function PresentationPort:OnApplicationChanged()
	if self._applicationRefreshQueued then return end
	self._applicationRefreshQueued = true
	local function flush()
		PresentationPort._applicationRefreshQueued = nil
		AP:RefreshApplicationDisplays(false, true)
	end
	if C_Timer and C_Timer.After then C_Timer.After(0, flush) else flush() end
end

ApplicationService:SetPresentationPort(PresentationPort)

local function exposeServiceMethod(name)
	AP[name] = function(_, ...)
		return ApplicationService[name](ApplicationService, ...)
	end
end

for _, methodName in ipairs({
	"ObserveApplicationPriority",
	"ForgetApplicationPriority",
	"GetApplicationPriority",
	"PeekApplicationPriority",
	"ResolveApplyTarget",
	"IsDelisted",
	"CanSelectRow",
	"GetCurrentGroupPartyGUID",
	"SetCurrentGroupResultID",
	"IsCurrentGroupResult",
	"TrackJoinedApplication",
	"ClearJoinedApplication",
	"IsJoinedApplicationTracked",
	"SuppressJoinedApplication",
	"IsJoinedApplicationSuppressed",
	"IsRetryAllowed",
	"SnapshotRejectedParties",
	"ApplyManualRefreshUnlocks",
	"GetApplicationState",
	"CancelExpiredApplications",
	"HasApplication",
	"IsDeclinedApplication",
	"HasActiveApplication",
	"GetActiveApplicationCount",
	"ShouldPinApplication",
	"ClearRejectionFeedback",
	"HasRejectionFeedback",
	"PinApplicationsToTop",
	"GetBlizzardApplyBlockReason",
	"GetSelectedRoleFlags",
	"IsLfgListRoleCheckActive",
}) do
	exposeServiceMethod(methodName)
end

local VALID_MODES = {
	manual = true,
	click_confirm = true,
	dblclick_auto = true,
}

function AP:NormalizeMode(mode)
	return VALID_MODES[mode] and mode or "manual"
end

function AP:GetMode()
	local db = GF.GetDB and GF.GetDB() or {}
	return self:NormalizeMode(db.applyMode)
end

function AP:SetMode(mode)
	local db = GF.GetDB and GF.GetDB() or nil
	if type(db) ~= "table" then
		return nil
	end
	db.applyMode = self:NormalizeMode(mode)
	return db.applyMode
end

function AP:MarkApplicationCancelled(resultID)
	return ApplicationService:MarkApplicationCancelled(resultID)
end

function AP:QueueCurrentGroupRefresh()
	if self._currentGroupRefreshQueued then
		return false
	end
	self._currentGroupRefreshQueued = true
	local queuedPanel = GF.BrowsePanel
	local queuedSearchToken = queuedPanel and queuedPanel._searchToken
	local queuedSearchKey = queuedPanel and queuedPanel.activeSearchKey
	local function flush()
		AP._currentGroupRefreshQueued = nil
		local currentPanel = GF.BrowsePanel
		if queuedPanel and (
			currentPanel ~= queuedPanel
			or currentPanel._searchToken ~= queuedSearchToken
			or currentPanel.activeSearchKey ~= queuedSearchKey
			or currentPanel.awaitingGFSearch == true
		) then
			return
		end
		AP:RefreshApplicationDisplays(true, true)
	end
	if C_Timer and type(C_Timer.After) == "function" then
		C_Timer.After(0, flush)
	else
		flush()
	end
	return true
end

function AP:OnJoinedGroup(resultID)
	local changed = ApplicationService:OnJoinedGroup(resultID)
	ApplicationService:ReconcileApplications(changed == true)
	self:QueueCurrentGroupRefresh()
	return changed
end

function AP:OnGroupJoined(category, partyGUID)
	local changed = ApplicationService:OnGroupJoined(category, partyGUID)
	ApplicationService:ReconcileApplications(changed == true)
	if changed then
		self:QueueCurrentGroupRefresh()
	end
	return changed
end

function AP:OnGroupLeft(category, partyGUID)
	local changed = ApplicationService:OnGroupLeft(category, partyGUID)
	ApplicationService:ReconcileApplications(changed == true)
	if changed then
		self:QueueCurrentGroupRefresh()
	end
	return changed
end

function AP:OnApplicationStatusObserved(resultID, newStatus, outcome)
	if outcome and outcome.needsInviteHook then self:InitInviteDialogHooks() end
	if newStatus == "applied" then self:EnsureExpiryTicker() end
	return outcome and outcome.changed == true or false
end

function AP:OnApplicationStatusUpdated(resultID, newStatus, oldStatus)
	local outcome = ApplicationService:OnApplicationStatusUpdated(resultID, newStatus, oldStatus)
	return self:OnApplicationStatusObserved(resultID, newStatus, outcome)
end

function AP:OnGroupRosterChanged()
	local changed = ApplicationService:OnGroupRosterChanged()
	ApplicationService:ReconcileApplications(changed == true)
	if changed then self:QueueCurrentGroupRefresh() end
	return changed
end

function AP:CancelApplication(resultID)
	return ApplicationService:CancelApplication(resultID)
end

function AP:RefreshApplicationDisplays(resort, reapplyFilters)
	local function refreshControls()
		if GF.SubtitleBar
			and type(GF.SubtitleBar.UpdateSignUpButtonState) == "function"
		then
			GF.SubtitleBar:UpdateSignUpButtonState()
		end
		if GF.FloatButton and type(GF.FloatButton.RefreshAlert) == "function" then
			GF.FloatButton:RefreshAlert()
		end
	end

	local tab = GF.FindGroupTab
	if reapplyFilters and tab
		and type(tab.ApplyClientFilters) == "function"
	then
		tab:ApplyClientFilters({
			preserveOrder = true,
			promoteCurrent = resort == true,
		})
		refreshControls()
		return
	end

	if resort and GF.Result and GF.Result.resultIDs and tab
		and type(tab.RefreshList) == "function"
	then
		if type(GF.Result.StablePromoteCurrentGroup) == "function" then
			GF.Result:StablePromoteCurrentGroup()
		end
		tab:RefreshList({ preserveScroll = true })
		refreshControls()
		return
	end

	if tab and type(tab.ForEachVisibleRow) == "function" and GF.ListRow then
		tab:ForEachVisibleRow(function(row)
			if row and row.resultID then
				GF.ListRow:ApplyApplicationState(row, row.resultID)
				GF.ListRow:UpdateRowBackgrounds(row)
			end
		end)
	end
	refreshControls()
end

function AP:StopExpiryTicker()
	local ticker = self._expiryTicker
	self._expiryTicker = nil
	if ticker and type(ticker.Cancel) == "function" then
		ticker:Cancel()
	end
end

-- This timer only paints visible countdowns. Core owns native reconciliation.
function AP:EnsureExpiryTicker()
	if self._expiryTicker or not C_Timer or not C_Timer.NewTicker then return end
	self._expiryTicker = C_Timer.NewTicker(1, function()
		local anyVisible = false
		local tab, rows = GF.FindGroupTab, GF.ListRow
		if tab and tab.ForEachVisibleRow and rows and rows.TickExpiry then
			tab:ForEachVisibleRow(function(row)
				if row and row._appExpiryShown then
					rows:TickExpiry(row)
					anyVisible = anyVisible or row._appExpiryShown == true
				end
			end)
		end
		if not anyVisible then AP:StopExpiryTicker() end
	end)
end

function AP:IsAutoAcceptInviteEnabled()
	local db = GF.GetDB and GF.GetDB() or {}
	return db.autoAcceptInvite == true
end

function AP:SetAutoAcceptInviteEnabled(enabled)
	local db = GF.GetDB and GF.GetDB() or nil
	if type(db) ~= "table" then
		return nil
	end
	db.autoAcceptInvite = enabled == true
	return db.autoAcceptInvite
end

function AP:IsAutoConfirmLfgListRoleEnabled()
	return self:IsAutoAcceptInviteEnabled()
end

function AP:InitInviteDialogHooks()
	if self._inviteDialogHooked == true then
		return true
	end
	if not LFGListInviteDialog
		and type(GF.EnsureBlizzardAddons) == "function"
	then
		GF.EnsureBlizzardAddons()
	end
	local dialog = LFGListInviteDialog
	local button = dialog and dialog.AcceptButton
	if button == nil or type(button.HookScript) ~= "function" then
		return false
	end
	local function trackAcceptedInvite()
		local resultID = dialog.resultID
		if resultID ~= nil then
			AP:TrackJoinedApplication(resultID, "invited", false, true)
		end
	end
	pcall(button.HookScript, button, "PreClick", trackAcceptedInvite)
	pcall(button.HookScript, button, "OnMouseDown", trackAcceptedInvite)
	self._inviteDialogHooked = true
	return true
end

function AP:TryAutoAcceptInvite()
	return ApplicationService:TryAutoAcceptInvite(
		self:IsAutoAcceptInviteEnabled(),
		function(applicationID, status)
			self:TrackJoinedApplication(
				applicationID, status, false, true)
		end)
end

function AP:QueueAutoAcceptInvite()
	if not self:IsAutoAcceptInviteEnabled() then
		return false
	end
	self._autoAcceptInviteToken = (self._autoAcceptInviteToken or 0) + 1
	local token = self._autoAcceptInviteToken
	local function scan()
		if AP._autoAcceptInviteToken == token then
			AP:TryAutoAcceptInvite()
		end
	end
	if C_Timer and type(C_Timer.After) == "function" then
		C_Timer.After(0, scan)
	else
		scan()
	end
	return true
end

function AP:TryAutoConfirmLfgListRoleCheck()
	return self:TryAutoConfirmRoleCheck()
end

function AP:TryAutoConfirmRoleCheck()
	if not self:IsAutoAcceptInviteEnabled() then return false end
	local popup = LFDRoleCheckPopup
	if not popup or type(popup.IsShown) ~= "function"
		or type(LFDRoleCheckPopup_GetRolesChecked) ~= "function" then
		return false
	end
	local shownOK, shown = pcall(popup.IsShown, popup)
	if not shownOK or shown ~= true then return false end
	local rolesOK, tank, healer, damage = pcall(LFDRoleCheckPopup_GetRolesChecked)
	if not rolesOK then return false end
	local confirmed, closePopup = ApplicationService:TryAutoConfirmRoleCheck(
		self:IsAutoAcceptInviteEnabled(), tank, healer, damage)
	if closePopup and popup == LFDRoleCheckPopup
		and type(StaticPopupSpecial_Hide) == "function" then
		pcall(StaticPopupSpecial_Hide, popup)
	end
	return confirmed
end

function AP:OnRoleCheckHidden()
	self._roleCheckConfirmToken = (self._roleCheckConfirmToken or 0) + 1
	ApplicationService:ResetRoleCheckConfirmation()
end

function AP:QueueAutoConfirmLfgListRoleCheck()
	if not self:IsAutoConfirmLfgListRoleEnabled() then
		return
	end
	self._roleCheckConfirmToken = (self._roleCheckConfirmToken or 0) + 1
	local token = self._roleCheckConfirmToken
	local function confirm()
		if AP._roleCheckConfirmToken == token then
			AP:TryAutoConfirmLfgListRoleCheck()
		end
	end
	if C_Timer and type(C_Timer.After) == "function" then
		C_Timer.After(0, confirm)
	else
		confirm()
	end
end

function AP:ReportError(message)
	if type(GF.ShowWarningMessage) == "function" then
		GF.ShowWarningMessage(message)
	end
end

function AP:ReportMissingRole()
	local locale = GF.L or {}
	local title = locale.APPLY_ROLE_MISSING_TITLE or "Role missing"
	local body = locale.APPLY_ROLE_MISSING_BODY
		or "Select Tank, Healer or Damage at the top right to apply"
	if type(GF.ShowTopNotice) == "function" then
		GF.ShowTopNotice(title, {
			source = "warning", subtitle = body, wideSubtitle = true,
		})
	else
		self:ReportError(body)
	end
end

function AP:IsChatRestricted()
	return C_ChatInfo
		and type(C_ChatInfo.InChatMessagingLockdown) == "function"
		and C_ChatInfo.InChatMessagingLockdown()
end

function AP:ShouldRememberApplicationNote()
	local db = GF.GetDB and GF.GetDB()
	return db and db.rememberApplicationNote == true
end

function AP:GetApplyNoteBox()
	local description = LFGListApplicationDialogDescription
	return description and description.EditBox or nil
end

function AP:IsSuppressingApplyNoteClear()
	local untilTime = tonumber(self._suppressApplyNoteClearUntil)
	if not untilTime then
		return false
	end
	if untilTime > GetTime() then
		return true
	end
	self._suppressApplyNoteClearUntil = nil
	return false
end

function AP:SuppressApplyNoteClear(seconds)
	self._suppressApplyNoteClearUntil =
		GetTime() + (tonumber(seconds) or 0.5)
end

function AP:CaptureApplyNoteText(text)
	if not self:ShouldRememberApplicationNote() then
		self._cachedNote = ""
		return
	end
	if text == nil then
		local box = self:GetApplyNoteBox()
		if not box or type(box.GetText) ~= "function" then
			return
		end
		text = box:GetText() or ""
	end
	if type(issecretvalue) == "function" and issecretvalue(text) then
		return
	end
	if text == "" and self:IsSuppressingApplyNoteClear()
		and self._cachedNote and self._cachedNote ~= ""
	then
		return
	end
	self._cachedNote = text
end

function AP:ClearNativeApplyNote()
	ApplicationService:ClearApplicationTextFields()
	local box = self:GetApplyNoteBox()
	if box and type(box.SetText) == "function" then
		pcall(box.SetText, box, "")
	end
end

function AP:ClearApplyNoteState()
	self._cachedNote = ""
	self._suppressApplyNoteClearUntil = nil
	local timer = self._restoreNoteTimer
	self._restoreNoteTimer = nil
	if timer and type(timer.Cancel) == "function" then
		timer:Cancel()
	end
	self:ClearNativeApplyNote()
end

function AP:SaveCachedNote()
	if self:ShouldRememberApplicationNote() ~= true then
		self._cachedNote = ""
		return
	end
	if self._gfDialog == true then
		self:CaptureApplyNoteText()
	end
end

function AP:RestoreCachedNote()
	local text = self._cachedNote
	if self:ShouldRememberApplicationNote() ~= true
		or type(text) ~= "string"
		or text == ""
		or self:IsChatRestricted()
	then
		return
	end
	local box = self:GetApplyNoteBox()
	if not box or type(box.SetText) ~= "function" then
		return
	end
	if type(box.IsEnabled) == "function" and box:IsEnabled() ~= true then
		return
	end
	if type(issecretvalue) == "function" and issecretvalue(text) then
		return
	end
	pcall(box.SetText, box, text)
end

function AP:ScheduleRestoreCachedNote()
	if self:ShouldRememberApplicationNote() ~= true
		or type(self._cachedNote) ~= "string"
		or self._cachedNote == ""
	then
		return
	end
	if not C_Timer or type(C_Timer.NewTimer) ~= "function" then
		self:RestoreCachedNote()
		return
	end
	local previousTimer = self._restoreNoteTimer
	if previousTimer and type(previousTimer.Cancel) == "function" then
		previousTimer:Cancel()
	end
	self._restoreNoteTimer = C_Timer.NewTimer(0, function()
		self._restoreNoteTimer = nil
		local dialog = LFGListApplicationDialog
		if self._gfDialog == true and dialog
			and type(dialog.IsShown) == "function" and dialog:IsShown()
		then
			self:RestoreCachedNote()
		end
	end)
end

function AP:PrepareApplyNoteFields()
	if self:ShouldRememberApplicationNote() ~= true then
		self:ClearApplyNoteState()
		return
	end
	self:RestoreCachedNote()
end

function AP:GetResultPrimaryActivityID(resultID)
	if resultID == nil then
		return nil
	end
	local info = ApplicationService:GetAuthoritativeResultInfo(resultID)
	local snapshot = GF.SearchResultSnapshot
	if snapshot and type(snapshot.GetPrimaryActivityID) == "function" then
		return snapshot.GetPrimaryActivityID(info)
	end
	if type(info) ~= "table" then
		return nil
	end
	if type(issecretvaluekey) == "function" then
		local secretOK, secret = pcall(
			issecretvaluekey, info, "activityIDs")
		if secretOK and secret == true then
			return nil
		end
	end
	local ok, activityIDs = pcall(function()
		return info.activityIDs
	end)
	if not ok or type(activityIDs) ~= "table" then
		return nil
	end
	if type(issecretvaluekey) == "function" then
		local secretOK, secret = pcall(issecretvaluekey, activityIDs, 1)
		if secretOK and secret == true then
			return nil
		end
	end
	local firstOK, first = pcall(function()
		return activityIDs[1]
	end)
	if not firstOK then
		return nil
	end
	if type(issecretvalue) == "function" then
		local secretOK, secret = pcall(issecretvalue, first)
		if secretOK and secret == true then
			return nil
		end
	end
	local numberOK, activityID = pcall(tonumber, first)
	return numberOK and activityID or nil
end

function AP:PrepareDialogApplyNote(resultID)
	if self:ShouldRememberApplicationNote() ~= true then
		self:ClearApplyNoteState()
		return
	end
	if type(self._cachedNote) ~= "string" or self._cachedNote == "" then
		return
	end
	local activityID = self:GetResultPrimaryActivityID(resultID)
	if activityID ~= nil and LFGListApplicationDialog then
		LFGListApplicationDialog.activityID = activityID
	end
	self:SuppressApplyNoteClear(0.5)
end

function AP:Init()
	if self._inited == true then
		return
	end
	self._inited = true
	self._cachedNote = ""
	local dialog = LFGListApplicationDialog
	if dialog == nil then
		return
	end
	local box = self:GetApplyNoteBox()
	if box and type(box.HookScript) == "function" then
		box:HookScript("OnTextChanged", function(editBox)
			if AP._gfDialog == true then
				local text = editBox and editBox.GetText
					and editBox:GetText() or ""
				AP:CaptureApplyNoteText(text)
			end
		end)
	end
	local signUpButton = dialog.SignUpButton
	if signUpButton and type(signUpButton.HookScript) == "function" then
		local function captureBeforeNativeApply()
			if AP._gfDialog ~= true then
				return
			end
			AP:CaptureApplyNoteText()
			AP:SuppressApplyNoteClear(0.5)
		end
		pcall(signUpButton.HookScript, signUpButton,
			"PreClick", captureBeforeNativeApply)
		pcall(signUpButton.HookScript, signUpButton,
			"OnMouseDown", captureBeforeNativeApply)
	end
	dialog:HookScript("OnShow", function()
		if AP._gfDialog == true then
			AP:ScheduleRestoreCachedNote()
		end
	end)
	dialog:HookScript("OnHide", function()
		if AP._gfDialog == true then
			AP:SaveCachedNote()
		end
		AP._gfDialog = nil
	end)
end

function AP:ReleaseSlotForTarget(index, resultID, mode)
	local _, targetID = self:ResolveApplyTarget(index, resultID)
	local handled, reason = ApplicationService:StartReplacement(targetID,
		self:CaptureRowInteraction(nil, targetID), mode)
	if reason and ApplicationService:GetReplacementState(targetID) ~= "cancel_failed" then self:ReportError(reason) end
	return handled
end

function AP:RetryApplication(resultID, expected)
	local intent = ApplicationService:ConsumeReplacement(resultID, expected)
	if not intent then
		self:ReportError((GF.L or {}).APPLY_TARGET_UNAVAILABLE)
		return false
	end
	if intent.mode == "auto" then return self:TryAutoApply(nil, resultID, intent.context) end
	return self:ShowDialogForIndex(nil, resultID, intent.context)
end

local function currentBrowseInteractionContext()
	local panel = GF.BrowsePanel
	return panel and panel._searchToken or nil,
		panel and panel.activeSearchKey or nil
end

function AP:CaptureRowInteraction(row, resultID)
	resultID = ApplicationService:NormalizeResultID(
		resultID or (row and row.resultID))
	if not resultID then
		return nil
	end
	local searchToken, searchKey = currentBrowseInteractionContext()
	return {
		resultID = resultID,
		partyGUID = ApplicationService:GetResultPartyGUID(
			ApplicationService:GetNativeResultInfo(resultID)),
		searchToken = searchToken,
		searchKey = searchKey,
		bindingGeneration = row and row._gfBindingGeneration or nil,
	}
end

function AP:InteractionMatches(expected, row, resultID)
	if type(expected) ~= "table"
		or ApplicationService:NormalizeResultID(resultID) ~= expected.resultID
	then
		return false
	end
	local searchToken, searchKey = currentBrowseInteractionContext()
	if searchToken ~= expected.searchToken or searchKey ~= expected.searchKey then
		return false
	end
	if row and row._gfBindingGeneration ~= expected.bindingGeneration then
		return false
	end
	local info = ApplicationService:GetNativeResultInfo(expected.resultID)
	if not info then
		return false
	end
	local partyGUID = ApplicationService:GetResultPartyGUID(info)
	return expected.partyGUID == nil or partyGUID == expected.partyGUID
end

local function resolveUsableApplyTarget(facade, index, resultID, expected)
	local resolvedIndex, resolvedID, reason =
		facade:ResolveApplyTarget(index, resultID)
	if resolvedIndex == nil or resolvedID == nil then
		if reason == "stale" then
			facade:ReportError((GF.L or {}).APPLY_TARGET_UNAVAILABLE
				or "This listing is no longer available")
		end
		return nil, nil
	end
	if facade:CanSelectRow(resolvedIndex, resolvedID) ~= true then
		facade:ReportError((GF.L or {}).APPLY_TARGET_UNAVAILABLE
			or "This listing is no longer available")
		return nil, nil
	end
	if expected and not facade:InteractionMatches(expected, nil, resolvedID) then
		facade:ReportError((GF.L or {}).APPLY_TARGET_UNAVAILABLE
			or "This listing is no longer available")
		return nil, nil
	end
	return resolvedIndex, resolvedID
end

function AP:ShowDialogForIndex(index, resultID, expected)
	local resolvedIndex, resolvedID = resolveUsableApplyTarget(
		self, index, resultID, expected)
	if resolvedID == nil then
		return false
	end
	if self:ReleaseSlotForTarget(resolvedIndex, resolvedID, "dialog") then
		return false
	end
	local blockReason = self:GetBlizzardApplyBlockReason()
	if blockReason then self:ReportError(blockReason); return false end
	if type(LFGListApplicationDialog_Show) ~= "function"
		or LFGListApplicationDialog == nil
	then
		return false
	end
	if type(GF.EnsureBlizzardAddons) == "function" then
		GF.EnsureBlizzardAddons()
	end
	self:Init()
	self:PrepareDialogApplyNote(resolvedID)
	-- The native application dialog submits through Blizzard's own mutation
	-- path, so our ApplicationService never sees that
	-- mutation. Preserve the seasonal Mythic+ identity while the search result
	-- is still readable; later invite/join events can then survive the native
	-- result disappearing before the roster reaches five.
	local readyTeleport = GF.MythicPlusGroupReadyTeleportService
	if readyTeleport and readyTeleport.OnApplicationSubmitted then
		readyTeleport:OnApplicationSubmitted(resolvedID)
	end
	self._gfDialog = true
	LFGListApplicationDialog_Show(LFGListApplicationDialog, resolvedID)
	return true
end

function AP:TryAutoApply(index, resultID, expected)
	local resolvedIndex, resolvedID = resolveUsableApplyTarget(
		self, index, resultID, expected)
	if resolvedID == nil then
		return false
	end
	if self:ReleaseSlotForTarget(resolvedIndex, resolvedID, "auto") then
		return false
	end
	local blockReason = self:GetBlizzardApplyBlockReason()
	if blockReason then
		self:ReportError(blockReason)
		return false
	end
	local tank, healer, damage = self:GetSelectedRoleFlags()
	if not (tank or healer or damage) then
		self:ReportMissingRole()
		return false
	end
	self:PrepareApplyNoteFields()
	return ApplicationService:ApplyToGroup(
		resolvedID, tank, healer, damage)
end

function AP:OnRowLeftClick(row)
	if not row or not row.resultIndex then
		return
	end
	local index, resultID = self:ResolveApplyTarget(
		row.resultIndex, row.resultID)
	if not index or not resultID or not self:CanSelectRow(index, resultID) then
		return
	end
	local tab = GF.FindGroupTab
	if not tab then
		return
	end
	local mode = self:GetMode()
	local now = GetTime()
	local interaction = self:CaptureRowInteraction(row, resultID)
	local isDouble = interaction ~= nil
		and self._lastClickInteraction ~= nil
		and self:InteractionMatches(
			self._lastClickInteraction, row, resultID)
		and (now - (self._lastClickTime or 0)) <= self.DBLCLICK_SEC
	self._lastClickTime = now
	self._lastClickRow = row
	self._lastClickResultID = resultID
	self._lastClickInteraction = interaction

	if mode == "dblclick_auto" then
		if isDouble then
			self._lastClickRow = nil
			self._lastClickResultID = nil
			self._lastClickInteraction = nil
			self._lastClickTime = 0
			tab:SetSelectedRow(row)
			self:TryAutoApply(index, resultID, interaction)
		else
			tab:SetSelectedRow(row)
		end
		return
	end

	if mode == "click_confirm" then
		tab:SetSelectedRow(row)
		if not isDouble then
			self:ShowDialogForIndex(index, resultID, interaction)
		end
		return
	end

	tab:SetSelectedRow(row)
end
