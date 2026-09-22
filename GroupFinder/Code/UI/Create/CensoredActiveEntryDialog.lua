local _, GF = ...

GF.CensoredActiveEntryDialog = GF.CensoredActiveEntryDialog or {}
local Dialog = GF.CensoredActiveEntryDialog

local NATIVE_POPUPS = {
	LFG_LIST_CREATE_CENSOR_WARNING = true,
	LFG_LIST_CENSOR_WARNING = true,
}

local DIALOG_WIDTH = 520
local DIALOG_MIN_HEIGHT = 136
local DIALOG_ICON_SIZE = 64
local DIALOG_CONTENT_LEFT = 126
local DIALOG_CONTENT_RIGHT = 44
local DIALOG_TITLE_SIDE_INSET = 44
local DIALOG_ICON_CENTER_X = DIALOG_CONTENT_LEFT / 2
local DIALOG_CONTENT_TOP = 20
local DIALOG_TITLE_MIN_HEIGHT = 28
local DIALOG_DESCRIPTION_TOP_GAP = 6
local DIALOG_DESCRIPTION_MIN_HEIGHT = 24
local DIALOG_DESCRIPTION_MEASURE_HEIGHT = 160
local DIALOG_BUTTON_TOP_GAP = 8
local DIALOG_BOTTOM_INSET = 16
local DIALOG_BUTTON_WIDTH = 96
local DIALOG_BUTTON_HEIGHT = 26
local DIALOG_BUTTON_GAP = 20
local DIALOG_BUTTON_FONT_SIZE = GF.PANEL_CONFIRM_BUTTON_FONT_SIZE or 14
local DIALOG_MAIN_WINDOW_ALPHA = 0.64

local function getPresentationState()
	local listing = GF.RecruitmentSession
	if listing and listing.GetActiveCensoredPresentationState then
		return listing:GetActiveCensoredPresentationState()
	end
	return nil
end

local function canPublish()
	local listing = GF.RecruitmentSession
	return listing ~= nil
		and type(listing.CanPublish) == "function"
		and listing:CanPublish() == true
end

local function isRealUnresolved()
	local listing = GF.RecruitmentSession
	local state = listing and listing.GetActiveCensoredState
		and listing:GetActiveCensoredState()
	return state ~= nil
		and state.state == listing.ACTIVE_CENSOR_STATE_UNRESOLVED
end

local function hideNativePopup(which)
	if type(StaticPopup_Hide) == "function" then
		StaticPopup_Hide(which)
	end
end

local function refreshSurfaces()
	if GF.ApplicantsPanel and GF.ApplicantsPanel.UpdateManageState then
		GF.ApplicantsPanel:UpdateManageState()
	end
	if GF.CreatePanel then
		if GF.CreatePanel.UpdateListButtonLabel then
			GF.CreatePanel:UpdateListButtonLabel()
		end
		if GF.CreatePanel.UpdateManageState then
			GF.CreatePanel:UpdateManageState()
		end
	end
	if GF.MainFrame and GF.MainFrame.UpdateCreateTab then
		GF.MainFrame:UpdateCreateTab({ suppressCreateAutoOpen = true })
	end
end

local function notify(message)
	if type(GF.ShowWarningMessage) == "function" then
		GF.ShowWarningMessage(message)
	end
end

local function applyFontSize(fontString, template, size)
	if not fontString then
		return
	end
	fontString._gfFontSizeOverride = size
	if GF.Font and GF.Font.ApplyToFontString then
		GF.Font.ApplyToFontString(fontString, template)
		return
	end
	if not fontString or not fontString.GetFont or not fontString.SetFont then
		return
	end
	local path, _, flags = fontString:GetFont()
	if path then
		fontString:SetFont(path, size or 12, flags or "")
	end
end

local function applyButtonFontSize(button, size)
	local fontString = button and button.GetFontString
		and button:GetFontString()
	applyFontSize(fontString, "GameFontNormal", size)
end

local function setMainWindowAlpha(dialog, transparent)
	local mainFrame = GF.MainFrame and GF.MainFrame.frame
	if not (mainFrame and mainFrame.SetAlpha) then
		return
	end
	if transparent then
		local mainController = GF.MainFrame
		if mainController and mainController.CanApplyPresentationAlpha
			and not mainController:CanApplyPresentationAlpha()
		then
			return
		end
		if dialog._previousMainAlpha == nil then
			dialog._previousMainAlpha = mainFrame.GetAlpha
				and mainFrame:GetAlpha() or 1
		end
		mainFrame:SetAlpha(DIALOG_MAIN_WINDOW_ALPHA)
	elseif dialog._previousMainAlpha ~= nil then
		local previous = tonumber(dialog._previousMainAlpha) or 1
		dialog._previousMainAlpha = nil
		mainFrame:SetAlpha(previous)
	end
end

local function layoutDialog(dialog)
	if not dialog then
		return
	end
	local contentWidth = DIALOG_WIDTH
		- DIALOG_CONTENT_LEFT - DIALOG_CONTENT_RIGHT
	dialog:SetWidth(DIALOG_WIDTH)
	dialog.Title:ClearAllPoints()
	dialog.Title:SetPoint("TOPLEFT", dialog, "TOPLEFT",
		DIALOG_TITLE_SIDE_INSET, -DIALOG_CONTENT_TOP)
	dialog.Title:SetPoint("TOPRIGHT", dialog, "TOPRIGHT",
		-DIALOG_TITLE_SIDE_INSET, -DIALOG_CONTENT_TOP)
	dialog.Title:SetHeight(DIALOG_DESCRIPTION_MEASURE_HEIGHT)
	local titleHeight = DIALOG_TITLE_MIN_HEIGHT
	if dialog.Title.GetStringHeight then
		titleHeight = math.max(titleHeight,
			math.ceil(dialog.Title:GetStringHeight() or 0))
	end
	dialog.Title:SetHeight(titleHeight)
	dialog.Description:ClearAllPoints()
	dialog.Description:SetWidth(contentWidth)
	dialog.Description:SetHeight(DIALOG_DESCRIPTION_MEASURE_HEIGHT)
	local descriptionHeight = DIALOG_DESCRIPTION_MIN_HEIGHT
	if dialog.Description.GetStringHeight then
		descriptionHeight = math.max(descriptionHeight,
			math.ceil(dialog.Description:GetStringHeight() or 0))
	end
	local bodyTop = DIALOG_CONTENT_TOP + titleHeight
		+ DIALOG_DESCRIPTION_TOP_GAP
	local actionBlockHeight = descriptionHeight
		+ DIALOG_BUTTON_TOP_GAP + DIALOG_BUTTON_HEIGHT
	local bodyHeight = math.max(DIALOG_ICON_SIZE, actionBlockHeight)
	dialog.Description:SetPoint("TOPLEFT", dialog, "TOPLEFT",
		DIALOG_CONTENT_LEFT, -bodyTop)
	dialog.Description:SetPoint("TOPRIGHT", dialog, "TOPRIGHT",
		-DIALOG_CONTENT_RIGHT, -bodyTop)
	dialog.Description:SetHeight(descriptionHeight)
	local buttonTop = bodyTop + descriptionHeight + DIALOG_BUTTON_TOP_GAP
	local dialogHeight = bodyTop + bodyHeight + DIALOG_BOTTOM_INSET
	dialog:SetHeight(math.max(DIALOG_MIN_HEIGHT, dialogHeight))
	dialog.Icon:ClearAllPoints()
	dialog.Icon:SetPoint("CENTER", dialog, "TOPLEFT",
		DIALOG_ICON_CENTER_X, -(bodyTop + descriptionHeight / 2))
	dialog.ModifyButton:ClearAllPoints()
	dialog.ModifyButton:SetPoint("TOP", dialog, "TOP",
		-((DIALOG_BUTTON_WIDTH + DIALOG_BUTTON_GAP) / 2),
		-buttonTop)
	dialog.KeepButton:ClearAllPoints()
	dialog.KeepButton:SetPoint("TOP", dialog, "TOP",
		((DIALOG_BUTTON_WIDTH + DIALOG_BUTTON_GAP) / 2),
		-buttonTop)
end

local function refreshDialogLocale(dialog)
	if not dialog then
		return
	end
	local L = GF.L or {}
	dialog.Title:SetText(L.CENSORED_ACTIVE_ENTRY_DIALOG_TITLE
		or "Current recruitment information requires attention")
	dialog.Description:SetText(L.CENSORED_ACTIVE_ENTRY_DIALOG_DESCRIPTION
		or "Blizzard requires this recruitment information to be modified. Until then, updates and relisting are unavailable, and the group listing remains hidden.")
	dialog.ModifyButton:SetText(L.CENSORED_ACTIVE_ENTRY_MODIFY
		or "Modify info")
	dialog.KeepButton:SetText(L.CENSORED_ACTIVE_ENTRY_KEEP
		or "Keep info")
	layoutDialog(dialog)
end

function Dialog:Hide(reason)
	local dialog = self.frame
	if not (dialog and dialog:IsShown()) then
		return false
	end
	dialog._hideReason = reason
	dialog:Hide()
	return true
end

function Dialog:Dismiss()
	-- Closing is always the local "handle later" action.  Suppress automatic
	-- redisplay even if the authoritative query becomes transiently unreadable
	-- between the popup opening and the user's close action.
	self._automaticSuppressed = true
	return self:Hide("deferred")
end

function Dialog:BeginModify()
	local state = getPresentationState()
	local L = GF.L or {}
	if state and state.preview == true then
		local function openDebugEditor()
			local inline = GF.MythicPlusCreateManagerPanel
			if inline and inline.BeginCensoredDebugResolution
				and inline:BeginCensoredDebugResolution()
			then
				return
			end
			if GF.MainFrame and GF.MainFrame.OpenCreateTab then
				GF.MainFrame:OpenCreateTab()
			end
			if GF.CreateDrawer and GF.CreateDrawer.Open
				and GF.CreateDrawer:Open({
					mode = "debug-censored",
					debugCensoredPreview = true,
					resetPosition = true,
				})
			then
				return
			end
			notify(L.DEBUG_CENSORED_MODIFY_PREVIEW_NOTICE
				or "Debug preview is unavailable; the real recruitment was not changed.")
		end
		if C_Timer and C_Timer.After then
			C_Timer.After(0, openDebugEditor)
		else
			openDebugEditor()
		end
		return true
	end
	if not isRealUnresolved() or not canPublish() then
		self:Hide("permission")
		return false
	end
	if GF.MainFrame and GF.MainFrame.OpenCreateTab then
		GF.MainFrame:OpenCreateTab()
	end
	local function openEditor()
		if not isRealUnresolved() or not canPublish() then
			return
		end
		local inline = GF.MythicPlusCreateManagerPanel
		if inline and inline.IsSurfaceActive and inline:IsSurfaceActive()
			and GF.CreatePanel and GF.CreatePanel.PrepareForEdit
		then
			if GF.CreatePanel:PrepareForEdit({
				censoredResolution = true,
			}) then
				GF.CreatePanel:Show()
				if inline.Refresh then
					inline:Refresh()
				end
			end
			return
		end
		if GF.CreateDrawer and GF.CreateDrawer.Open then
			GF.CreateDrawer:Open({
				mode = "edit",
				allowOccupiedPrompt = true,
				censoredResolution = true,
			})
		end
	end
	if C_Timer and C_Timer.After then
		C_Timer.After(0, openEditor)
	else
		openEditor()
	end
	return true
end

function Dialog:KeepOriginal()
	local state = getPresentationState()
	if state and state.preview == true then
		if GF.Debug and GF.Debug.SetActiveCensoredDemoState then
			GF.Debug:SetActiveCensoredDemoState("off", {
				openCreateTab = true,
				silent = true,
			})
		end
		return true
	end
	if not isRealUnresolved() or not canPublish() then
		self:Hide("permission")
		return false
	end
	local listing = GF.RecruitmentSession
	return listing and listing.ConfirmCensoredActiveEntry
		and listing:ConfirmCensoredActiveEntry() == true
end

function Dialog:Reveal()
	local state = getPresentationState()
	if state and state.preview == true then
		if state.hidden and GF.Debug and GF.Debug.SetActiveCensoredDemoState then
			GF.Debug:SetActiveCensoredDemoState("revealed", {
				openCreateTab = true,
				silent = true,
			})
			return true
		end
		return self:Show()
	end
	local listing = GF.RecruitmentSession
	if state and state.hidden and canPublish() and listing
		and listing.RevealCensoredActiveEntry
	then
		local revealed = listing:RevealCensoredActiveEntry() == true
		if revealed then
			refreshSurfaces()
		end
		return revealed
	end
	return self:Show()
end

local function createDialog()
	local dialog = CreateFrame("Frame",
		"GroupFinderAddonCensoredActiveEntryDialog",
		UIParent)
	dialog:SetSize(DIALOG_WIDTH, DIALOG_MIN_HEIGHT)
	dialog:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
	dialog:SetFrameStrata("DIALOG")
	dialog:SetFrameLevel(1000)
	dialog:SetToplevel(true)
	dialog:EnableMouse(true)
	if dialog.SetClipsChildren then
		dialog:SetClipsChildren(false)
	end
	dialog:Hide()
	if GF.UI and GF.UI.ApplyStaticPopupFrameArt then
		GF.UI.ApplyStaticPopupFrameArt(dialog)
	end
	dialog.Icon = dialog:CreateTexture(nil, "ARTWORK")
	dialog.Icon:SetSize(DIALOG_ICON_SIZE, DIALOG_ICON_SIZE)
	dialog.Icon:SetTexture(GF.CENSORED_RESULT_ICON_TEXTURE)
	dialog.Title = GF.UI.CreateFontString(
		dialog, "OVERLAY", "GameFontHighlightLarge")
	dialog.Title:SetJustifyH("CENTER")
	dialog.Title:SetJustifyV("MIDDLE")
	dialog.Title:SetWordWrap(false)
	dialog.Title:SetTextColor(1, 1, 1, 1)
	applyFontSize(dialog.Title, "GameFontHighlightLarge", 20)
	dialog.Description = GF.UI.CreateFontString(
		dialog, "OVERLAY", "GameFontNormal")
	dialog.Description:SetJustifyH("LEFT")
	dialog.Description:SetJustifyV("MIDDLE")
	dialog.Description:SetWordWrap(true)
	dialog.Description:SetNonSpaceWrap(true)
	dialog.Description:SetTextColor(0.82, 0.78, 0.68, 1)
	dialog.Description:SetHeight(DIALOG_DESCRIPTION_MEASURE_HEIGHT)
	applyFontSize(dialog.Description, "GameFontNormal", 14)
	dialog.ModifyButton = GF.UI.CreatePanelButton(
		dialog, "", DIALOG_BUTTON_WIDTH)
	dialog.ModifyButton:SetSize(DIALOG_BUTTON_WIDTH, DIALOG_BUTTON_HEIGHT)
	applyButtonFontSize(dialog.ModifyButton, DIALOG_BUTTON_FONT_SIZE)
	dialog.KeepButton = GF.UI.CreatePanelButton(
		dialog, "", DIALOG_BUTTON_WIDTH)
	dialog.KeepButton:SetSize(DIALOG_BUTTON_WIDTH, DIALOG_BUTTON_HEIGHT)
	applyButtonFontSize(dialog.KeepButton, DIALOG_BUTTON_FONT_SIZE)
	dialog.CloseButton = CreateFrame("Button", nil, dialog,
		"UIPanelCloseButtonNoScripts")
	dialog.CloseButton:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", -7, -7)
	dialog.CloseButton:SetFrameLevel(dialog:GetFrameLevel() + 20)
	dialog.CloseButton:RegisterForClicks("LeftButtonUp")
	if GF.UI and GF.UI.ApplyCommonCloseButtonSkin then
		GF.UI.ApplyCommonCloseButtonSkin(dialog.CloseButton)
	end
	dialog.ModifyButton:SetScript("OnClick", function()
		local state = getPresentationState()
		if not (state and state.preview == true)
			and (not isRealUnresolved() or not canPublish())
		then
			Dialog:Hide("permission")
			return
		end
		Dialog._automaticSuppressed = true
		Dialog:Hide("modify")
		if GF.UI and GF.UI.PlayUISound then
			GF.UI.PlayUISound("check")
		end
		Dialog:BeginModify()
	end)
	dialog.KeepButton:SetScript("OnClick", function()
		local state = getPresentationState()
		if not (state and state.preview == true)
			and (not isRealUnresolved() or not canPublish())
		then
			Dialog:Hide("permission")
			return
		end
		Dialog._automaticSuppressed = true
		Dialog:Hide("keep")
		if GF.UI and GF.UI.PlayUISound then
			GF.UI.PlayUISound("check")
		end
		Dialog:KeepOriginal()
	end)
	dialog.CloseButton:SetScript("OnClick", function()
		if GF.UI and GF.UI.PlayUISound then
			GF.UI.PlayUISound("check")
		end
		Dialog:Dismiss()
	end)
	dialog:SetScript("OnShow", function(self)
		layoutDialog(self)
		setMainWindowAlpha(self, true)
		if self.SetPropagateKeyboardInput then
			self:SetPropagateKeyboardInput(true)
		end
		if self.EnableKeyboard then
			self:EnableKeyboard(true)
		end
	end)
	dialog:SetScript("OnHide", function(self)
		setMainWindowAlpha(self, false)
		self._hideReason = nil
		if self.EnableKeyboard then
			self:EnableKeyboard(false)
		end
	end)
	dialog:SetScript("OnKeyDown", function(self, key)
		if key == "ESCAPE" then
			if self.SetPropagateKeyboardInput then
				self:SetPropagateKeyboardInput(false)
			end
			Dialog:Dismiss()
		elseif self.SetPropagateKeyboardInput then
			self:SetPropagateKeyboardInput(true)
		end
	end)
	if GF.UI and GF.UI.InstallPopupOpenAnimation then
		GF.UI.InstallPopupOpenAnimation(dialog, { preset = "dialog" })
	end
	refreshDialogLocale(dialog)
	return dialog
end

local function ensureDialog()
	if not Dialog.frame then
		Dialog.frame = createDialog()
	end
	return Dialog.frame
end

function Dialog:Show(opts)
	opts = opts or {}
	if GF.CreatePanel
		and GF.CreatePanel.debugCensoredPreviewMode == true
		and GF.CreateDrawer
		and GF.CreateDrawer.Close
	then
		GF.CreateDrawer:Close(true)
	end
	local state = getPresentationState()
	local preview = state and state.preview == true
	local unresolved = state and (
		state.state == GF.RecruitmentSession.ACTIVE_CENSOR_STATE_UNRESOLVED
		or (preview
			and state.state == GF.RecruitmentSession.ACTIVE_CENSOR_STATE_UNKNOWN)
	)
	if not unresolved then
		return false
	end
	if not preview and not canPublish() then
		self:Hide("permission")
		return false
	end
	if opts.automatic == true and self._automaticSuppressed == true then
		return false
	end
	local dialog = ensureDialog()
	refreshDialogLocale(dialog)
	dialog:ClearAllPoints()
	dialog:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
	dialog:Show()
	if dialog.Raise then
		dialog:Raise()
	end
	return true
end

function Dialog:Refresh(reason, opts)
	opts = opts or {}
	local state = getPresentationState()
	local listing = GF.RecruitmentSession
	local preview = state and state.preview == true
	local unresolved = state and listing and (
		state.state == listing.ACTIVE_CENSOR_STATE_UNRESOLVED
		or (preview
			and state.state == listing.ACTIVE_CENSOR_STATE_UNKNOWN)
	)
	local presentationAllowed = preview or canPublish()
	local resolved = state and listing and (
		state.state == listing.ACTIVE_CENSOR_STATE_NORMAL
		or state.state == listing.ACTIVE_CENSOR_STATE_INACTIVE
	)
	if resolved then
		self._automaticSuppressed = nil
	end
	if not unresolved or not presentationAllowed then
		self:Hide(not unresolved and "resolved" or "permission")
		if not unresolved
			and GF.CreatePanel
			and (GF.CreatePanel.censoredResolutionMode == true
				or GF.CreatePanel.debugCensoredPreviewMode == true)
		then
			local inline = GF.MythicPlusCreateManagerPanel
			local inlineActive = inline and inline.IsSurfaceActive
				and inline:IsSurfaceActive()
			GF.CreatePanel.censoredResolutionMode = nil
			if inlineActive and inline.Open then
				inline:Open({ forceEdit = true })
			elseif GF.CreateDrawer and GF.CreateDrawer.Close then
				GF.CreateDrawer:Close(true)
			end
		end
	end
	refreshSurfaces()
	if unresolved and presentationAllowed and opts.showPopup == true then
		self:Show({
			reason = reason,
			automatic = true,
		})
	end
end

function Dialog:HandlePublishPermissionChanged()
	local dialog = self.frame
	if not (dialog and dialog:IsShown()) then
		return
	end
	local state = getPresentationState()
	if not (state and state.preview == true) and not canPublish() then
		self:Hide("permission")
	end
end

function Dialog:RefreshLocale()
	if self.frame then
		refreshDialogLocale(self.frame)
	end
end

function Dialog:Init()
	if self._initialized then
		return
	end
	self._initialized = true
	if type(hooksecurefunc) == "function" and type(StaticPopup_Show) == "function" then
		hooksecurefunc("StaticPopup_Show", function(which)
			if not NATIVE_POPUPS[which] or not isRealUnresolved() then
				return
			end
			if not canPublish() or Dialog._automaticSuppressed == true then
				hideNativePopup(which)
				return
			end
			if Dialog:Show({
				nativeReplacement = true,
				automatic = true,
			}) then
				hideNativePopup(which)
			end
		end)
	end
end
