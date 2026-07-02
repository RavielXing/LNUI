local _, GF = ...

GF.Apply = {}
local AP = GF.Apply

AP.DBLCLICK_SEC = 0.3

local VALID_MODES = {
	manual = true,
	click_confirm = true,
	dblclick_auto = true,
}

function AP:NormalizeMode(mode)
	if mode and VALID_MODES[mode] then
		return mode
	end
	return "manual"
end

function AP:GetMode()
	return self:NormalizeMode(GF.GetDB().applyMode)
end

function AP:ResolveApplyTarget(index, resultID)
	if resultID ~= nil then
		resultID = tonumber(resultID)
		if resultID and resultID > 0 and GF.Result and GF.Result.GetIndexForResultID then
			local currentIndex = GF.Result:GetIndexForResultID(resultID)
			if currentIndex then
				return currentIndex, resultID
			end
			return nil, resultID, "stale"
		end
	end
	index = tonumber(index)
	if index and GF.Result and GF.Result.GetResultID then
		resultID = GF.Result:GetResultID(index)
		if resultID then
			return index, resultID
		end
	end
	return nil, nil, "missing"
end

function AP:IsDelisted(index, resultID)
	local resolvedIndex, resolvedID = self:ResolveApplyTarget(index, resultID)
	resultID = resolvedID
	if not resultID then
		return true
	end
	local cached = GF.Result and GF.Result.entryCache and GF.Result.entryCache[resultID]
	if cached and cached.info and GF.Result.IsSoftUnavailable and GF.Result:IsSoftUnavailable(cached.info) then
		return true
	end
	local info = C_LFGList.GetSearchResultInfo(resultID)
	if not info then
		return true
	end
	if GF.Result and GF.Result.ShouldHideUnavailableResult
		and GF.Result:ShouldHideUnavailableResult(resultID, info) then
		return true
	end
	return info.isDelisted == true
end

function AP:CanSelectRow(index, resultID)
	local resolvedIndex, resolvedID = self:ResolveApplyTarget(index, resultID)
	if not resolvedIndex or self:IsDelisted(resolvedIndex, resolvedID) then
		return false
	end
	if resolvedID and self:HasApplication(resolvedID) then
		return false
	end
	return true
end

-- =============================================================================
-- 申请状态：GetApplicationInfo 包装、declines/freshRejects、列表置顶、共享 1s 倒计时
-- 消费方：ListRow.ApplyApplicationState、BrowsePanel、Result 排序、ListFilter.notDeclined
-- =============================================================================

local INACTIVE_APP = { cancelled = true, failed = true, declined = true, timedout = true, invitedeclined = true, inviteaccepted = true }
local LOCAL_CANCELLED_DISPLAY_SECONDS = 2

local function isDeclinedStatus(status)
	return status == "declined" or status == "declined_delisted" or status == "declined_full"
end

local function isInactiveStatus(status)
	if LFGListUtil_IsStatusInactive then
		return LFGListUtil_IsStatusInactive(status)
	end
	return status and INACTIVE_APP[status]
end

local function isApplicationStatus(appStatus, pendingStatus)
	return (appStatus ~= nil and appStatus ~= "none") or pendingStatus ~= nil
end

function AP:MarkApplicationCancelled(resultID)
	if not resultID then
		return
	end
	self.localCancelled = self.localCancelled or {}
	self.localCancelled[resultID] = GetTime() + LOCAL_CANCELLED_DISPLAY_SECONDS
	self.localCancelledTokens = self.localCancelledTokens or {}
	local token = (self.localCancelledTokens[resultID] or 0) + 1
	self.localCancelledTokens[resultID] = token
	if C_Timer and C_Timer.After then
		C_Timer.After(LOCAL_CANCELLED_DISPLAY_SECONDS, function()
			if not AP.localCancelledTokens or AP.localCancelledTokens[resultID] ~= token then
				return
			end
			AP.localCancelledTokens[resultID] = nil
			if AP.localCancelled then
				AP.localCancelled[resultID] = nil
			end
			if GF.FindGroupTab and GF.FindGroupTab.UpdateRowByResultID then
				GF.FindGroupTab:UpdateRowByResultID(resultID)
			end
		end)
	end
end

function AP:GetApplicationState(resultID)
	if not resultID or not C_LFGList.GetApplicationInfo then
		return nil
	end
	local _, appStatus, pendingStatus, appDuration = C_LFGList.GetApplicationInfo(resultID)
	local localCancelledUntil = self.localCancelled and self.localCancelled[resultID]
	local hasLocalCancelled = localCancelledUntil and localCancelledUntil > GetTime()
	if localCancelledUntil and not hasLocalCancelled then
		self.localCancelled[resultID] = nil
	end
	local info = C_LFGList.GetSearchResultInfo and C_LFGList.GetSearchResultInfo(resultID)
	local isDeclined = isDeclinedStatus(appStatus)
	if info and self.declines and not isDeclined and self.declines[info.partyGUID] then
		isDeclined = true
		appStatus = self.declines[info.partyGUID]
	end
	local isApplication = isApplicationStatus(appStatus, pendingStatus)
	if hasLocalCancelled and not isApplication then
		appStatus = "cancelled"
		isApplication = true
	end
	local isAppFinished = isInactiveStatus(appStatus) or isInactiveStatus(pendingStatus) or isDeclined
	return {
		appStatus = appStatus,
		pendingStatus = pendingStatus,
		appDuration = appDuration,
		isDeclined = isDeclined,
		isApplication = isApplication,
		isActiveApp = isApplication and not isAppFinished,
	}
end

function AP:HasApplication(resultID)
	local state = self:GetApplicationState(resultID)
	return state and state.isApplication or false
end

function AP:HasActiveApplication()
	if not (C_LFGList and C_LFGList.GetApplications and C_LFGList.GetApplicationInfo) then
		return false
	end
	local apps = C_LFGList.GetApplications() or {}
	for i = 1, #apps do
		local state = self:GetApplicationState(apps[i])
		if state and state.isActiveApp then
			return true
		end
	end
	return false
end

function AP:GetActiveApplicationCount()
	if not (C_LFGList and C_LFGList.GetApplications and C_LFGList.GetApplicationInfo) then
		return 0
	end
	local count = 0
	local apps = C_LFGList.GetApplications() or {}
	for i = 1, #apps do
		local state = self:GetApplicationState(apps[i])
		if state and state.isActiveApp then
			count = count + 1
		end
	end
	return count
end

function AP:ShouldPinApplication(resultID)
	local state = self:GetApplicationState(resultID)
	if not state or not state.isApplication then
		return false
	end
	if isInactiveStatus(state.appStatus) and not state.isDeclined then
		return false
	end
	return true
end

function AP:IsFreshReject(resultID)
	return resultID and self.freshRejects and self.freshRejects[resultID] or false
end

function AP:ClearFreshRejects()
	self.freshRejects = nil
end

function AP:OnApplicationStatusUpdated(resultID, newStatus)
	if not resultID then
		return
	end
	if newStatus == "invited" then
		self:TryAutoAcceptInvite()
	end
	if isInactiveStatus(newStatus) and not isDeclinedStatus(newStatus) then
		self:MarkApplicationCancelled(resultID)
	end
	if not isDeclinedStatus(newStatus) then
		return
	end
	local info = C_LFGList.GetSearchResultInfo and C_LFGList.GetSearchResultInfo(resultID)
	if info and info.partyGUID then
		self.declines = self.declines or {}
		self.declines[info.partyGUID] = newStatus
	end
	self.freshRejects = self.freshRejects or {}
	self.freshRejects[resultID] = true
end

function AP:CancelApplication(resultID)
	local cancelApplication = C_LFGList and (C_LFGList.CancelApplication or C_LFGList.WithdrawApplication)
	if not resultID or not cancelApplication then
		local L = GF.L or {}
		return false, L.APPLY_CANCEL_UNAVAILABLE or "取消申请接口不可用。"
	end
	local ok, reason = pcall(cancelApplication, resultID)
	if not ok then
		return false, tostring(reason or ((GF.L or {}).APPLY_CANCEL_FAILED or "取消申请失败。"))
	end
	self:MarkApplicationCancelled(resultID)
	if GF.FindGroupTab and GF.FindGroupTab.OnApplicationStatusUpdated then
		GF.FindGroupTab:OnApplicationStatusUpdated(resultID, "cancelled")
	end
	return true
end

function AP:PinApplicationsToTop(ids, topID)
	local apps = C_LFGList.GetApplications and C_LFGList.GetApplications() or {}
	local pinned, pinnedSet, rest = {}, {}, {}
	for i = 1, #apps do
		local appID = apps[i]
		if self:ShouldPinApplication(appID) then
			pinned[#pinned + 1] = appID
			pinnedSet[appID] = true
		end
	end
	if topID and self:ShouldPinApplication(topID) and not pinnedSet[topID] then
		pinned[#pinned + 1] = topID
		pinnedSet[topID] = true
	end
	if #pinned == 0 then
		return ids
	end
	ids = ids or {}
	for i = 1, #ids do
		local id = ids[i]
		if not pinnedSet[id] then
			rest[#rest + 1] = id
		end
	end
	local out = {}
	if topID and pinnedSet[topID] then
		out[#out + 1] = topID
	end
	for i = 1, #pinned do
		local id = pinned[i]
		if id ~= topID then
			out[#out + 1] = id
		end
	end
	for i = 1, #rest do
		out[#out + 1] = rest[i]
	end
	return out
end

function AP:StopExpiryTicker()
	if self._expiryTicker and self._expiryTicker.Cancel then
		self._expiryTicker:Cancel()
	end
	self._expiryTicker = nil
end

function AP:EnsureExpiryTicker()
	if self._expiryTicker or not C_Timer or not C_Timer.NewTicker then
		return
	end
	self._expiryTicker = C_Timer.NewTicker(1, function()
		local fg, lr = GF.FindGroupTab, GF.ListRow
		if not fg or not fg.ForEachVisibleRow or not lr or not lr.TickExpiry then
			AP:StopExpiryTicker()
			return
		end
		local any = false
		fg:ForEachVisibleRow(function(row)
			if row and row._appExpiryShown then
				any = true
				lr:TickExpiry(row)
			end
		end)
		if not any then
			AP:StopExpiryTicker()
		end
	end)
end

-- =============================================================================
-- 申请流程：申请模式、暴雪弹窗/自动申请、取消最旧、行点击、备注缓存、自动接受邀请
-- =============================================================================

function AP:IsAutoAcceptInviteEnabled()
	return GF.GetDB().autoAcceptInvite == true
end

function AP:TryAutoAcceptInvite()
	if not self:IsAutoAcceptInviteEnabled() then
		return
	end
	if self._acceptInFlight then
		return
	end
	if LFGListUtil_IsAppEmpowered and not LFGListUtil_IsAppEmpowered() then
		return
	end
	if not C_LFGList.GetApplications or not C_LFGList.GetApplicationInfo or not C_LFGList.AcceptInvite then
		return
	end
	self._acceptInFlight = true
	local apps = C_LFGList.GetApplications() or {}
	for i = 1, #apps do
		local id = apps[i]
		local _, status, pendingStatus = C_LFGList.GetApplicationInfo(id)
		if status == "invited" and not pendingStatus then
			C_LFGList.AcceptInvite(id)
			break
		end
	end
	self._acceptInFlight = false
end

function AP:IsLfgListRoleCheckActive()
	if not (C_LFGList and C_LFGList.GetRoleCheckInfo and CompleteLFGRoleCheck) then
		return false
	end
	if GetLFGRoleUpdate then
		local okUpdate, inProgress = pcall(GetLFGRoleUpdate)
		if not okUpdate or inProgress ~= true then
			return false
		end
	end
	local okInfo, isLFGList = pcall(C_LFGList.GetRoleCheckInfo)
	return okInfo and isLFGList == true
end

function AP:TryAutoConfirmLfgListRoleCheck()
	if not self:IsAutoAcceptInviteEnabled() then
		return false
	end
	if self._roleCheckConfirmInFlight then
		return false
	end
	if not self:IsLfgListRoleCheckActive() then
		return false
	end
	local tank, healer, dps = self:GetSelectedRoleFlags()
	if not (tank or healer or dps) then
		return false
	end
	if LFDPopupCheckRoleSelectionValid then
		local okValid, valid = pcall(LFDPopupCheckRoleSelectionValid, tank, healer, dps)
		if not okValid or valid ~= true then
			return false
		end
	end
	self._roleCheckConfirmInFlight = true
	local roleOk = true
	if SetLFGRoles and GetLFGRoles then
		local okLeader, leader = pcall(GetLFGRoles)
		roleOk = okLeader and pcall(SetLFGRoles, leader, tank, healer, dps)
	end
	local okComplete, completed = false, false
	if roleOk then
		okComplete, completed = pcall(CompleteLFGRoleCheck, true)
	end
	self._roleCheckConfirmInFlight = false
	if okComplete and completed then
		if StaticPopupSpecial_Hide and LFDRoleCheckPopup then
			StaticPopupSpecial_Hide(LFDRoleCheckPopup)
		end
		return true
	end
	return false
end

function AP:QueueAutoConfirmLfgListRoleCheck()
	if not self:IsAutoAcceptInviteEnabled() then
		return
	end
	self._roleCheckConfirmToken = (self._roleCheckConfirmToken or 0) + 1
	local token = self._roleCheckConfirmToken
	if C_Timer and C_Timer.After then
		C_Timer.After(0, function()
			if AP._roleCheckConfirmToken == token then
				AP:TryAutoConfirmLfgListRoleCheck()
			end
		end)
	else
		self:TryAutoConfirmLfgListRoleCheck()
	end
end

function AP:ReportError(msg)
	if GF.ShowWarningMessage then
		GF.ShowWarningMessage(msg)
	end
end

function AP:IsChatRestricted()
	return C_ChatInfo and C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown()
end

function AP:IsPersistApplyNoteEnabled()
	return GF.GetDB().persistApplyNote == true
end

function AP:GetApplyNoteBox()
	if LFGListApplicationDialogDescription and LFGListApplicationDialogDescription.EditBox then
		return LFGListApplicationDialogDescription.EditBox
	end
	return nil
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
	self._suppressApplyNoteClearUntil = GetTime() + (tonumber(seconds) or 0.5)
end

function AP:CaptureApplyNoteText(text)
	if not self:IsPersistApplyNoteEnabled() then
		self._cachedNote = ""
		return
	end
	if text == nil then
		local box = self:GetApplyNoteBox()
		if not box or not box.GetText then
			return
		end
		text = box:GetText() or ""
	end
	if issecretvalue and issecretvalue(text) then
		return
	end
	if text == "" and self:IsSuppressingApplyNoteClear() and self._cachedNote and self._cachedNote ~= "" then
		return
	end
	self._cachedNote = text
end

function AP:ClearNativeApplyNote()
	if C_LFGList and C_LFGList.ClearApplicationTextFields then
		pcall(C_LFGList.ClearApplicationTextFields)
	end
	local box = self:GetApplyNoteBox()
	if box and box.SetText then
		pcall(box.SetText, box, "")
	end
end

function AP:ClearApplyNoteState()
	self._cachedNote = ""
	self._suppressApplyNoteClearUntil = nil
	if self._restoreNoteTimer and self._restoreNoteTimer.Cancel then
		self._restoreNoteTimer:Cancel()
	end
	self._restoreNoteTimer = nil
	self:ClearNativeApplyNote()
end

function AP:SaveCachedNote()
	if not self:IsPersistApplyNoteEnabled() then
		self._cachedNote = ""
		return
	end
	if not self._gfDialog then
		return
	end
	self:CaptureApplyNoteText()
end

function AP:RestoreCachedNote()
	if not self:IsPersistApplyNoteEnabled() or not self._cachedNote or self._cachedNote == "" then
		return
	end
	if self:IsChatRestricted() then
		return
	end
	local box = self:GetApplyNoteBox()
	if not box or not box.SetText then
		return
	end
	if box.IsEnabled and not box:IsEnabled() then
		return
	end
	local text = self._cachedNote
	if issecretvalue and issecretvalue(text) then
		return
	end
	pcall(box.SetText, box, text)
end

function AP:ScheduleRestoreCachedNote()
	if not self:IsPersistApplyNoteEnabled() or not self._cachedNote or self._cachedNote == "" then
		return
	end
	if not C_Timer or not C_Timer.After then
		self:RestoreCachedNote()
		return
	end
	if self._restoreNoteTimer and self._restoreNoteTimer.Cancel then
		self._restoreNoteTimer:Cancel()
	end
	self._restoreNoteTimer = C_Timer.After(0, function()
		self._restoreNoteTimer = nil
		if self._gfDialog and LFGListApplicationDialog and LFGListApplicationDialog:IsShown() then
			self:RestoreCachedNote()
		end
	end)
end

function AP:PrepareApplyNoteFields()
	if self:IsPersistApplyNoteEnabled() then
		self:RestoreCachedNote()
	else
		self:ClearApplyNoteState()
	end
end

function AP:GetResultPrimaryActivityID(resultID)
	if not (resultID and C_LFGList and C_LFGList.GetSearchResultInfo) then
		return nil
	end
	local ok, info = pcall(C_LFGList.GetSearchResultInfo, resultID)
	if not ok or type(info) ~= "table" or type(info.activityIDs) ~= "table" then
		return nil
	end
	return tonumber(info.activityIDs[1])
end

function AP:PrepareDialogApplyNote(resultID)
	if not self:IsPersistApplyNoteEnabled() then
		self:ClearApplyNoteState()
		return
	end
	if self._cachedNote and self._cachedNote ~= "" then
		local activityID = self:GetResultPrimaryActivityID(resultID)
		if activityID and LFGListApplicationDialog then
			LFGListApplicationDialog.activityID = activityID
		end
		self:SuppressApplyNoteClear(0.5)
	end
end

function AP:Init()
	if self._inited then
		return
	end
	self._inited = true
	self._cachedNote = ""
	if not LFGListApplicationDialog then
		return
	end
	local box = self:GetApplyNoteBox()
	if box and box.HookScript then
		box:HookScript("OnTextChanged", function(editBox)
			if AP._gfDialog then
				local text = editBox and editBox.GetText and editBox:GetText() or ""
				AP:CaptureApplyNoteText(text)
			end
		end)
	end
	local signUpButton = LFGListApplicationDialog.SignUpButton
	if signUpButton and signUpButton.HookScript then
		local function captureBeforeNativeApply()
			if AP._gfDialog then
				AP:CaptureApplyNoteText()
				AP:SuppressApplyNoteClear(0.5)
			end
		end
		pcall(signUpButton.HookScript, signUpButton, "PreClick", captureBeforeNativeApply)
		pcall(signUpButton.HookScript, signUpButton, "OnMouseDown", captureBeforeNativeApply)
	end
	LFGListApplicationDialog:HookScript("OnShow", function()
		if not AP._gfDialog then
			return
		end
		AP:ScheduleRestoreCachedNote()
	end)
	LFGListApplicationDialog:HookScript("OnHide", function()
		if AP._gfDialog then
			AP:SaveCachedNote()
		end
		AP._gfDialog = nil
	end)
end

function AP:GetOldestApplicationResultID()
	local oldestResultID = 0
	local oldestDuration = 999
	local apps = C_LFGList.GetApplications and C_LFGList.GetApplications() or {}
	for i = 1, #apps do
		local appID = apps[i]
		local _, appStatus, pendingStatus, appDuration = C_LFGList.GetApplicationInfo(appID)
		appDuration = tonumber(appDuration)
		if appStatus == "applied" and not pendingStatus and appDuration and appDuration < oldestDuration then
			oldestResultID = appID
			oldestDuration = appDuration
		end
	end
	return oldestResultID
end

function AP:ShouldCancelOldest(resultID)
	if GF.GetDB().cancelOldestApply ~= true then
		return false
	end
	local _, numActive = C_LFGList.GetNumApplications()
	if not numActive or not MAX_LFG_LIST_APPLICATIONS or numActive < MAX_LFG_LIST_APPLICATIONS then
		return false
	end
	if not resultID then
		return false
	end
	local _, appStatus, pendingStatus = C_LFGList.GetApplicationInfo(resultID)
	if isApplicationStatus(appStatus, pendingStatus) then
		return false
	end
	local info = C_LFGList.GetSearchResultInfo(resultID)
	return info and not info.isDelisted
end

function AP:TryCancelOldestApplication(index, resultID)
	local _, resolvedID = self:ResolveApplyTarget(index, resultID)
	resultID = resolvedID
	if not self:ShouldCancelOldest(resultID) then
		return false
	end
	local oldest = self:GetOldestApplicationResultID()
	if not oldest or oldest <= 0 then
		return false
	end
	self:CancelApplication(oldest)
	local L = GF.L or {}
	self:ReportError(L.APPLY_CANCELLED_OLDEST or "Cancelled oldest pending application. Click again to apply.")
	return true
end

function AP:GetBlizzardApplyBlockReason()
	if LFGListUtil_GetActiveQueueMessage then
		local msg = LFGListUtil_GetActiveQueueMessage(true)
		if msg then
			return msg
		end
	end
	if LFGListUtil_IsAppEmpowered and not LFGListUtil_IsAppEmpowered() then
		return LFG_LIST_APP_UNEMPOWERED
	end
	if IsInGroup(LE_PARTY_CATEGORY_HOME) and C_LFGList.IsCurrentlyApplying and C_LFGList.IsCurrentlyApplying() then
		return LFG_LIST_APP_CURRENTLY_APPLYING
	end
	local _, numActive = C_LFGList.GetNumApplications()
	if numActive and MAX_LFG_LIST_APPLICATIONS and numActive >= MAX_LFG_LIST_APPLICATIONS then
		return string.format(LFG_LIST_HIT_MAX_APPLICATIONS, MAX_LFG_LIST_APPLICATIONS)
	end
	if GetNumGroupMembers(LE_PARTY_CATEGORY_HOME) > MAX_PARTY_MEMBERS + 1 then
		return LFG_LIST_MAX_MEMBERS
	end
	local availTank, availHealer, availDPS = C_LFGList.GetAvailableRoles()
	if not (availTank or availHealer or availDPS) then
		return LFG_LIST_MUST_CHOOSE_SPEC
	end
	if GroupHasOfflineMember and GroupHasOfflineMember(LE_PARTY_CATEGORY_HOME) then
		return LFG_LIST_OFFLINE_MEMBER
	end
	return nil
end

function AP:GetSelectedRoleFlags()
	if not GetLFGRoles then
		return nil
	end
	if not (C_LFGList and C_LFGList.GetAvailableRoles) then
		return nil
	end
	local okRoles, _, tank, healer, dps = pcall(GetLFGRoles)
	if not okRoles then
		return nil
	end
	local okAvailable, availTank, availHealer, availDPS = pcall(C_LFGList.GetAvailableRoles)
	if not okAvailable then
		return nil
	end
	tank = tank == true and availTank == true
	healer = healer == true and availHealer == true
	dps = dps == true and availDPS == true
	if not (tank or healer or dps) then
		return nil
	end
	return tank, healer, dps
end

function AP:ShowDialogForIndex(index, resultID)
	local resolvedIndex, resolvedID, reason = self:ResolveApplyTarget(index, resultID)
	if not resolvedIndex or not resolvedID then
		if reason == "stale" then
			self:ReportError((GF.L or {}).APPLY_TARGET_UNAVAILABLE or "This listing is no longer available.")
		end
		return false
	end
	if self:IsDelisted(resolvedIndex, resolvedID) then
		return false
	end
	if self:TryCancelOldestApplication(resolvedIndex, resolvedID) then
		return false
	end
	if not LFGListApplicationDialog_Show or not LFGListApplicationDialog then
		return false
	end
	if GF.EnsureBlizzardAddons then
		GF.EnsureBlizzardAddons()
	end
	self:Init()
	self:PrepareDialogApplyNote(resolvedID)
	self._gfDialog = true
	LFGListApplicationDialog_Show(LFGListApplicationDialog, resolvedID)
	return true
end

function AP:TryAutoApply(index, resultID)
	local resolvedIndex, resolvedID, reason = self:ResolveApplyTarget(index, resultID)
	if not resolvedIndex or not resolvedID then
		if reason == "stale" then
			self:ReportError((GF.L or {}).APPLY_TARGET_UNAVAILABLE or "This listing is no longer available.")
		end
		return false
	end
	if self:IsDelisted(resolvedIndex, resolvedID) then
		return false
	end
	if self:TryCancelOldestApplication(resolvedIndex, resolvedID) then
		return false
	end
	local blockReason = self:GetBlizzardApplyBlockReason()
	if blockReason then
		self:ReportError(blockReason)
		return false
	end
	local tank, healer, dps = self:GetSelectedRoleFlags()
	if not (tank or healer or dps) then
		self:ReportError(LFG_LIST_MUST_SELECT_ROLE or LFG_LIST_MUST_CHOOSE_SPEC)
		return false
	end
	self:PrepareApplyNoteFields()
	return C_LFGList.ApplyToGroup(resolvedID, tank, healer, dps)
end

function AP:OnRowLeftClick(row)
	if not row or not row.resultIndex then
		return
	end
	local index, resultID = self:ResolveApplyTarget(row.resultIndex, row.resultID)
	if not index or not resultID or not self:CanSelectRow(index, resultID) then
		return
	end
	local fg = GF.FindGroupTab
	if not fg then
		return
	end
	local mode = self:GetMode()
	local now = GetTime()
	local isDouble = self._lastClickResultID == resultID and (now - (self._lastClickTime or 0)) <= self.DBLCLICK_SEC
	self._lastClickTime = now
	self._lastClickRow = row
	self._lastClickResultID = resultID

	if mode == "dblclick_auto" then
		if isDouble then
			self._lastClickRow = nil
			self._lastClickResultID = nil
			self._lastClickTime = 0
			fg:SetSelectedRow(row)
			self:TryAutoApply(index, resultID)
		else
			fg:SetSelectedRow(row)
		end
		return
	end

	if mode == "click_confirm" then
		fg:SetSelectedRow(row)
		if isDouble then
			return
		end
		self:ShowDialogForIndex(index, resultID)
		return
	end

	fg:SetSelectedRow(row)
end
