local _, GF = ...

local CP = {}
GF.CreatePanel = CP

local BB = GF.BlizzardBorrow
local NativeCreation = assert(
	GF.NativeCreationGateway,
	"NativeCreationGateway must load before CreatePanel"
)
local FormPresenter = assert(
	GF.RecruitmentFormPresenter,
	"RecruitmentFormPresenter must load before CreatePanel"
)
local DEFAULT_PLAYSTYLE = Enum.LFGEntryGeneralPlaystyle.Learning
local DEFAULT_REQUIRED_DUNGEON_SCORE = 0

local PLAYSTYLE_OPTIONS = {
	{ id = Enum.LFGEntryGeneralPlaystyle.Learning, textKey = "GROUP_FINDER_GENERAL_PLAYSTYLE1" },
	{ id = Enum.LFGEntryGeneralPlaystyle.FunRelaxed, textKey = "GROUP_FINDER_GENERAL_PLAYSTYLE2" },
	{ id = Enum.LFGEntryGeneralPlaystyle.FunSerious, textKey = "GROUP_FINDER_GENERAL_PLAYSTYLE3" },
	{ id = Enum.LFGEntryGeneralPlaystyle.Expert, textKey = "GROUP_FINDER_GENERAL_PLAYSTYLE4" },
}

local function playstyleText(option)
	local translated = option and _G[option.textKey]
	return translated or tostring(option and option.id or "")
end

local function selectedPlaystyleText(styleID)
	for optionIndex = 1, #PLAYSTYLE_OPTIONS do
		local option = PLAYSTYLE_OPTIONS[optionIndex]
		if option.id == styleID then
			return playstyleText(option)
		end
	end
	return ""
end

local function trimName(text)
	local value = type(text) == "string" and text or ""
	return value:match("^%s*(.-)%s*$") or ""
end

-- Blizzard LFGList EntryCreation (LFGList.xml): Name 288×22, Description 283×46
local NATIVE_FIELD_SIZE = {
	name = { width = 288, height = 22 },
	description = { width = 283, height = 46 },
}
-- 保留原生多行输入框的 5px 外沿，以便 GF 表单对齐可见边框。
local FIELD_EDGE_PAD = 6
local REQ_EDIT_W = 125
local REQ_EDIT_H = 26
local FIELD_GAP = 0
local LABEL_FIELD_GAP = 4
local DESC_FIELD_GAP = 0
local CONTENT_PAD = 4
local CREATE_PAD = 4
local FORM_LEFT_INSET = 4
local CREATE_FORM_INSET_X = 16
local CREATE_FORM_INSET_TOP =
	GF.MPLUS_LFG_SIDEBAR_FORM_TOP_INSET or 8
local CREATE_FORM_ROW_H = 36
local CREATE_FORM_STACK_LABEL_GAP = 5
local CREATE_FORM_STACK_ROW_GAP = 10
local CREATE_FORM_TITLE_SIZE = GF.CREATE_MANAGER_TITLE_TEXT_SIZE
	or GF.SECTION_HEADER_TEXT_SIZE
	or 14
local CREATE_FORM_TITLE_COLOR = GF.CREATE_MANAGER_TITLE_TEXT_COLOR
	or GF.BROWSE_HEADER_TEXT_COLOR
	or { 1, 0.82, 0, 1 }
local CREATE_MANAGER_DISABLED_VISUAL =
	GF.CREATE_MANAGER_DISABLED_VISUAL or {}
local CREATE_FORM_DISABLED_TITLE_COLOR =
	CREATE_MANAGER_DISABLED_VISUAL.labelTextColor
	or { 0.72, 0.70, 0.64, 1 }
local CREATE_FORM_INPUT_TEXT_COLOR = { 1, 0.92, 0.64, 1 }
local CREATE_FORM_DISABLED_INPUT_TEXT_COLOR =
	CREATE_MANAGER_DISABLED_VISUAL.inputTextColor
	or { 0.78, 0.77, 0.72, 1 }
local CREATE_FORM_DISABLED_ATLAS_TINT =
	CREATE_MANAGER_DISABLED_VISUAL.atlasTint
	or GF.FILTER_DISABLED_ICON_TINT
	or 0.58
local CREATE_FORM_DISABLED_ATLAS_DESATURATED =
	CREATE_MANAGER_DISABLED_VISUAL.desaturated ~= false
local CREATE_FORM_DISABLED_ALPHA =
	tonumber(CREATE_MANAGER_DISABLED_VISUAL.alpha) or 1
local MPLUS_LFG_SIDEBAR_CONTROL_W =
	GF.MPLUS_LFG_SIDEBAR_CONTROL_W
	or ((GF.NAV_WIDTH or 180) - 16)
local CREATE_FORM_INPUT_H = 26
local CREATE_FORM_DESC_H = NATIVE_FIELD_SIZE.description.height
local CREATE_FORM_DESC_ATLAS_PAD_Y = 4
local CREATE_FORM_DESC_ATLAS_H = CREATE_FORM_DESC_H + (CREATE_FORM_DESC_ATLAS_PAD_Y * 2)
local CREATE_DESCRIPTION_PLACEHOLDER_SPACING = -2
local CREATE_SIDEBAR_SECTION_TITLE_H =
	GF.MPLUS_LFG_SIDEBAR_SECTION_TITLE_H or 16
local CREATE_SIDEBAR_LABEL_CONTROL_GAP =
	GF.MPLUS_LFG_SIDEBAR_TITLE_CONTROL_GAP or 4
local CREATE_SIDEBAR_BLOCK_GAP =
	GF.MPLUS_LFG_SIDEBAR_BLOCK_GAP or 10
local CREATE_SIDEBAR_BLOCK_GAPS = {
	CREATE_SIDEBAR_BLOCK_GAP,
	CREATE_SIDEBAR_BLOCK_GAP,
	CREATE_SIDEBAR_BLOCK_GAP,
	CREATE_SIDEBAR_BLOCK_GAP,
}
local MPLUS_SIDEBAR_SPACING = GF.MPLUS_LFG_SIDEBAR_SPACING
local CREATE_PLACEHOLDER_LEFT_INSET = 4
local BUTTON_BAR_H = 70
local LIST_BTN_BOTTOM = BUTTON_BAR_H - 5 - 22
local LIST_BTN_W = GF.PANEL_BUTTON_STANDARD_W or 72
local LIST_BTN_GAP = GF.FILTER_FOOTER_BUTTON_GAP or 10
local DROPDOWN_H = 26
local DROPDOWN_LEFT_NUDGE = 0
local REQ_FIELD_LEFT_NUDGE = 3
local CREATE_CHECK_SIZE = 20
local CREATE_CHECK_LABEL_GAP = 8
local CREATE_DESC_ATLAS_BORDER_KEYS = {
	"topLeft",
	"top",
	"topRight",
	"left",
	"right",
	"bottomLeft",
	"bottom",
	"bottomRight",
}
local GREEN = "|cff00ff00"
local COLOR_END = "|r"
local CREATE_FIELD_OWNER = "groupfinder"
local CREATE_FIELD_CHANNEL = "entryCreation"
local CREATE_BLOCKED_TEXT_INSET_X = 14

local function formatGreen(text)
	return GREEN .. tostring(text or "") .. COLOR_END
end

local function getLoadingCycleSeconds()
	return ((GF.BROWSE_LOADING_STEP_SECONDS or 0.28) * (GF.BROWSE_LOADING_ICON_COUNT or 3))
		+ (GF.BROWSE_LOADING_HOLD_SECONDS or 0.4)
		+ (GF.BROWSE_LOADING_FADE_OUT_SECONDS or 0.45)
end

local function getLoadingIconAlpha(elapsed, iconIndex)
	local stepSeconds = GF.BROWSE_LOADING_STEP_SECONDS or 0.28
	local fadeInSeconds = GF.BROWSE_LOADING_FADE_IN_SECONDS or 0.16
	local iconCount = GF.BROWSE_LOADING_ICON_COUNT or 3
	local holdSeconds = GF.BROWSE_LOADING_HOLD_SECONDS or 0.4
	local fadeOutSeconds = GF.BROWSE_LOADING_FADE_OUT_SECONDS or 0.45
	local appearAt = (iconIndex - 1) * stepSeconds
	if elapsed < appearAt then
		return 0
	end
	local fadeInEnd = appearAt + fadeInSeconds
	if elapsed < fadeInEnd then
		return math.max(0, math.min(1, (elapsed - appearAt) / fadeInSeconds))
	end
	local fadeOutStart = (stepSeconds * iconCount) + holdSeconds
	if elapsed < fadeOutStart then
		return 1
	end
	local fadeOutEnd = fadeOutStart + fadeOutSeconds
	if elapsed < fadeOutEnd then
		return math.max(0, math.min(1, 1 - ((elapsed - fadeOutStart) / fadeOutSeconds)))
	end
	return 0
end

local function refreshLoadingAnimation(animation)
	if not (animation and animation.icons) then
		return
	end
	local elapsed = animation.elapsed or 0
	for index, icon in ipairs(animation.icons) do
		local alpha = getLoadingIconAlpha(elapsed, index)
		icon:SetAlpha(alpha)
		if alpha > 0.02 then
			icon:Show()
		else
			icon:Hide()
		end
	end
end

local function getPlayerFactionName()
	local factionTag, localizedFaction = UnitFactionGroup("player")
	if localizedFaction and localizedFaction ~= "" then
		return localizedFaction
	end
	local L = GF.L or {}
	if factionTag == "Horde" then
		return L.FACTION_HORDE or "部落"
	end
	return L.FACTION_ALLIANCE or "联盟"
end

local function getFactionRestrictionLabel()
	local L = GF.L or {}
	return (L.CROSS_FACTION_FMT or "仅限%s"):format(getPlayerFactionName())
end

local function getFactionRestrictionTip()
	local L = GF.L or {}
	local faction = getPlayerFactionName()
	return (L.CROSS_FACTION_TIP_FMT or "仅%s玩家可以看到你的招募队伍，可能会减少申请数量。"):format(formatGreen(faction))
end

local function getDefaultRequiredItemLevel()
	if GF.GetDefaultRequiredItemLevel then
		return GF.GetDefaultRequiredItemLevel()
	end
	return GF.DEFAULT_REQUIRED_ITEM_LEVEL_DEFAULT or 0
end

local function clampRequiredItemLevel(value)
	if GF.ClampDefaultRequiredItemLevel then
		return GF.ClampDefaultRequiredItemLevel(value)
	end
	return math.max(0, math.floor(tonumber(value) or 0))
end

local function showCreateOptionTooltip(owner, title, text)
	if not owner or not text or text == "" or not GameTooltip then
		return
	end
	GF.UI.BeginGameTooltip(owner, "ANCHOR_RIGHT")
	GameTooltip:ClearLines()
	if title and title ~= "" then
		GameTooltip:AddLine(title, 1, 0.82, 0, true)
	end
	GameTooltip:AddLine(text, 1, 1, 1, true)
	GF.UI.ShowGameTooltip()
end

local Fields = GF.CreatePanelFields.Install(CP, {
	BB = BB,
	NativeCreation = NativeCreation,
	FormPresenter = FormPresenter,
	trimName = trimName,
	FIELD_EDGE_PAD = FIELD_EDGE_PAD,
	CREATE_FORM_TITLE_SIZE = CREATE_FORM_TITLE_SIZE,
	CREATE_FORM_TITLE_COLOR = CREATE_FORM_TITLE_COLOR,
	CREATE_FORM_INPUT_TEXT_COLOR = CREATE_FORM_INPUT_TEXT_COLOR,
	CREATE_FORM_DISABLED_INPUT_TEXT_COLOR = CREATE_FORM_DISABLED_INPUT_TEXT_COLOR,
	CREATE_FORM_DISABLED_ATLAS_TINT = CREATE_FORM_DISABLED_ATLAS_TINT,
	CREATE_FORM_DISABLED_ATLAS_DESATURATED = CREATE_FORM_DISABLED_ATLAS_DESATURATED,
	CREATE_FORM_DISABLED_ALPHA = CREATE_FORM_DISABLED_ALPHA,
	CREATE_CHECK_LABEL_GAP = CREATE_CHECK_LABEL_GAP,
	CREATE_DESC_ATLAS_BORDER_KEYS = CREATE_DESC_ATLAS_BORDER_KEYS,
	CREATE_FIELD_OWNER = CREATE_FIELD_OWNER,
	CREATE_FIELD_CHANNEL = CREATE_FIELD_CHANNEL,
})
function CP:GetCreateSurfaceWidth()
	-- The create drawer has a fixed width, but WoW can report zero or the
	-- previous surface's width while its hidden anchors are being resolved.
	-- At the 560px column breakpoint that briefly selects the stacked layout,
	-- then switches to the 564px drawer layout after the first visible frame.
	-- Derive the drawer width from its fixed shell so the initial projection is
	-- identical to every later pass.
	if Fields.getCreateDrawerFooter(self.parent) ~= nil
		and self._mythicPlusSidebarMode ~= true
	then
		local drawer = GF.CreateDrawer and GF.CreateDrawer.frame
		local drawerWidth
		if GF.CreateDrawer and type(GF.CreateDrawer.GetPreferredSize) == "function" then
			drawerWidth = GF.CreateDrawer:GetPreferredSize()
		elseif drawer ~= nil and type(drawer.GetWidth) == "function" then
			drawerWidth = tonumber(drawer:GetWidth())
		end
		if drawerWidth == nil or drawerWidth <= 0 then
			drawerWidth = tonumber(GF.CREATE_DRAWER_W)
		end
		local fixedWidth = drawerWidth ~= nil
			and math.floor(
				drawerWidth - CREATE_PAD - (CREATE_FORM_INSET_X * 2)
			)
			or nil
		if fixedWidth ~= nil and fixedWidth > 0 then
			return fixedWidth
		end
	end
	local measured
	if self.scroll ~= nil and type(self.scroll.GetWidth) == "function" then
		measured = tonumber(self.scroll:GetWidth())
	end
	return measured ~= nil and measured > 0
		and math.floor(measured) or nil
end

function CP:GetCreateFieldWidths()
	if self:IsRaidDrawerMode() then
		local leftWidth = self:GetRaidDrawerColumns()
		return leftWidth, leftWidth
	end
	local usable = self:GetCreateSurfaceWidth()
	if usable ~= nil and usable > 0 then
		return usable, usable
	end
	return NATIVE_FIELD_SIZE.name.width,
		NATIVE_FIELD_SIZE.description.width
end

function CP:IsRaidDrawerMode()
	return self.workspaceContext ~= nil
		and self.workspaceContext.workspaceID == GF.WORKSPACE_RAID
		and not self:IsMythicPlusSidebarMode()
		and Fields.getCreateDrawerFooter(self.parent) ~= nil
end

function CP:GetRaidDrawerColumns()
	local style = GF.RAID_CREATE_DRAWER_STYLE
	local fullWidth = self:GetCreateSurfaceWidth() or (style.width - 36)
	local gap = style.columnGap
	local leftWidth = math.min(style.leftWidth, math.max(1, fullWidth - gap - 1))
	return leftWidth, gap, math.max(1, fullWidth - gap - leftWidth), fullWidth
end

function CP:GetCreateColumnWidth()
	local scrollW = self:GetCreateSurfaceWidth() or 0
	if not scrollW or scrollW <= 0 then
		return nil
	end
	local fullW = math.floor(scrollW)
	local minW = GF.CREATE_DRAWER_HORIZONTAL_MIN_W or 560
	if fullW < minW then
		return nil
	end
	local gap = GF.CREATE_FORM_COLUMN_GAP or 16
	return math.max(math.floor((fullW - gap) / 2), 1), gap, fullW
end

function CP:IsMythicPlusSidebarMode()
	return self._mythicPlusSidebarMode == true
end

function CP:IsMythicPlusSidebarReadOnly()
	return self:IsMythicPlusSidebarMode()
		and self._mythicPlusSidebarReadOnly == true
end

function CP:IsMythicPlusCreateManagerSurface()
	local panel = GF.MythicPlusCreateManagerPanel
	return self:IsMythicPlusSidebarMode()
		and panel
		and panel.IsMythicPlusSurface
		and panel:IsMythicPlusSurface()
		or false
end

function CP:IsMeetingStoneCreateManagerReadOnlySurface()
	local panel = GF.MythicPlusCreateManagerPanel
	return self:IsMythicPlusSidebarMode()
		and panel
		and panel.IsMeetingStoneReadOnlyMode
		and panel:IsMeetingStoneReadOnlyMode()
		or false
end

function CP:IsCreateManagerSurface()
	return self:IsMythicPlusCreateManagerSurface()
		or self:IsMeetingStoneCreateManagerReadOnlySurface()
end

function CP:ApplyCreateManagerDropdownDisabledVisual(dropdown, disabled)
	if not dropdown then
		return
	end
	local hadManagerOverride =
		dropdown._gfCreateManagerDisabledVisual == true
	if dropdown.OnButtonStateChanged then
		dropdown:OnButtonStateChanged()
	end
	local createManagerSurface = self:IsCreateManagerSurface()
	if disabled ~= true
		or not createManagerSurface
	then
		if hadManagerOverride
			or createManagerSurface
		then
			for _, texture in ipairs({
				dropdown.Background,
				dropdown.Arrow,
			}) do
				if texture then
					if texture.SetDesaturated then
						texture:SetDesaturated(false)
					end
					texture:SetVertexColor(1, 1, 1, 1)
					texture:SetAlpha(1)
				end
			end
			if dropdown.Text then
				dropdown.Text:SetAlpha(1)
			end
		end
		dropdown._gfCreateManagerDisabledVisual = nil
		return
	end
	local tint = CREATE_FORM_DISABLED_ATLAS_TINT
	if dropdown.Arrow and dropdown.Arrow.SetAtlas then
		dropdown.Arrow:SetAtlas(
			GF.CREATE_MANAGER_DROPDOWN_ARROW_ATLAS
				or "common-dropdown-a-button",
			true
		)
	end
	for _, texture in ipairs({
		dropdown.Background,
		dropdown.Arrow,
	}) do
		if texture then
			if texture.SetDesaturated then
				texture:SetDesaturated(
					CREATE_FORM_DISABLED_ATLAS_DESATURATED
				)
			end
			texture:SetVertexColor(
				tint,
				tint,
				tint,
				CREATE_FORM_DISABLED_ALPHA
			)
			texture:SetAlpha(CREATE_FORM_DISABLED_ALPHA)
		end
	end
	if dropdown.Text then
		dropdown.Text:SetTextColor(
			CREATE_FORM_DISABLED_INPUT_TEXT_COLOR[1],
			CREATE_FORM_DISABLED_INPUT_TEXT_COLOR[2],
			CREATE_FORM_DISABLED_INPUT_TEXT_COLOR[3],
			CREATE_FORM_DISABLED_INPUT_TEXT_COLOR[4]
		)
		dropdown.Text:SetAlpha(CREATE_FORM_DISABLED_ALPHA)
	end
	dropdown._gfCreateManagerDisabledVisual = true
end

-- Compatibility entry point for code loaded against the previous helper name.
function CP:ApplyCreateManagerDropdownReadOnlyVisual(dropdown, readOnly)
	self:ApplyCreateManagerDropdownDisabledVisual(dropdown, readOnly)
end

local function captureBorrowedCreateManagerTextColor(editBox)
	if not (
		editBox
		and editBox.GetTextColor
		and not editBox._gfCreateManagerEnabledTextColor
	) then
		return
	end
	editBox._gfCreateManagerEnabledTextColor = {
		editBox:GetTextColor(),
	}
end

local function setBorrowedCreateManagerTextDisabled(editBox, disabled)
	if not (editBox and editBox.SetTextColor) then
		return
	end
	if disabled then
		captureBorrowedCreateManagerTextColor(editBox)
		editBox:SetTextColor(
			CREATE_FORM_DISABLED_INPUT_TEXT_COLOR[1],
			CREATE_FORM_DISABLED_INPUT_TEXT_COLOR[2],
			CREATE_FORM_DISABLED_INPUT_TEXT_COLOR[3],
			CREATE_FORM_DISABLED_INPUT_TEXT_COLOR[4]
		)
		return
	end
	local color = editBox._gfCreateManagerEnabledTextColor
	if color then
		editBox:SetTextColor(
			color[1] or 1,
			color[2] or 1,
			color[3] or 1,
			color[4] or 1
		)
		editBox._gfCreateManagerEnabledTextColor = nil
	end
end

function CP:CaptureCreateManagerBorrowedFieldTextColors()
	captureBorrowedCreateManagerTextColor(self.nameEdit)
	captureBorrowedCreateManagerTextColor(
		self.commentScroll and self.commentScroll.EditBox
	)
end

function CP:ApplyCreateManagerBorrowedFieldTextVisual(disabled)
	setBorrowedCreateManagerTextDisabled(self.nameEdit, disabled == true)
	setBorrowedCreateManagerTextDisabled(
		self.commentScroll and self.commentScroll.EditBox,
		disabled == true
	)
end

function CP:ApplyMythicPlusSidebarTitleStyle()
	local color = self:IsCreateManagerSurface()
		and self._createManagerFormDisabled == true
		and CREATE_FORM_DISABLED_TITLE_COLOR
		or CREATE_FORM_TITLE_COLOR
	for _, label in ipairs({
		self.nameLabel,
		self.commentLabel,
		self.playLabel,
		self.ilvlLabel,
		self.mplusLabel,
		self.voiceLabel,
	}) do
		Fields.applyCreateTitleTextStyle(label, color)
	end
end

function CP:FitMythicPlusSidebarLabels()
	if not self:IsMythicPlusSidebarMode()
		or not (GF.Font and GF.Font.SetFitWidth) then
		return
	end
	local _, fieldW = self:GetCreateFieldWidths()
	for _, label in ipairs({
		self.nameLabel,
		self.commentLabel,
		self.playLabel,
		self.ilvlLabel,
		self.mplusLabel,
	}) do
		if label then
			GF.Font.SetFitWidth(label, fieldW, 8)
		end
	end
end

function CP:SetMythicPlusSidebarMode(enabled)
	enabled = enabled == true
	if self._mythicPlusSidebarMode == enabled then
		return
	end
	self._mythicPlusSidebarMode = enabled
	self._mythicPlusSidebarReadOnly = nil
	self._createManagerFormDisabled = nil
	self._mythicPlusHiddenDefaultsApplied = nil
	if self.favoriteBtn then
		self.favoriteBtn:SetShown(not enabled)
	end
	if not enabled then
		self:ApplyCreateManagerBorrowedFieldTextVisual(false)
		self:ApplyCreateManagerDropdownDisabledVisual(
			self.playDropdown,
			false
		)
		if GF.UI and GF.UI.SetCommonPanelButtonPreserveDisabledAlpha then
			GF.UI.SetCommonPanelButtonPreserveDisabledAlpha(
				self.listBtn,
				false
			)
			GF.UI.SetCommonPanelButtonPreserveDisabledAlpha(
				self.removeBtn,
				false
			)
		end
	end
	for _, widget in ipairs({
		self.voiceLabel,
		self.voiceAnchor,
		self.voiceFrame,
		self.voiceEdit,
		self.crossFactionCheck,
		self.crossFactionLabel,
		self.privateCheck,
		self.privateLabel,
	}) do
		if widget then
			widget:SetShown(not enabled)
		end
	end
	if not enabled then
		local activityID = Fields.resolveActivityID(self.selection)
		local activityInfo = activityID
			and NativeCreation:GetActivityInfoTable(activityID)
		self:UpdateScoreRequirementVisibility(activityInfo)
		self:UpdateCrossFactionOption()
	end
	self:UpdateRequirementLayout()
	self:ApplyMythicPlusSidebarTitleStyle()
	self:FitMythicPlusSidebarLabels()
end

function CP:IsResumingProtectedCreateDraft(opts)
	opts = opts or {}
	-- Prepared records that this draft consumed its one clear attempt;
	-- presented proves a user-visible create surface completed successfully.
	-- Keeping both avoids classifying a failed first open as restoration.
	return opts.resetDefaults ~= true
		and self.debugCensoredPreviewMode ~= true
		and self.editMode ~= true
		and self._protectedCreationTextDraftPrepared == true
		and self._protectedCreateDraftPresented == true
end

function CP:MarkProtectedCreateDraftPresented()
	if self.debugCensoredPreviewMode == true or self.editMode == true
		or self._protectedCreationTextDraftPrepared ~= true
	then
		return false
	end
	self._protectedCreateDraftPresented = true
	return true
end

function CP:ClearProtectedCreationTextFieldsForNewDraft(force)
	if self.editMode or force ~= true then
		return false
	end
	local listing = GF.RecruitmentSession
	if listing ~= nil and type(listing.HasActive) == "function"
		and listing:HasActive() == true
	then
		return false
	end
	if self._protectedCreationTextDraftPrepared == true then
		return false
	end
	-- A draft generation gets at most one destructive clear attempt.  Mark it
	-- before entering the native API so a failed/unavailable call cannot clear
	-- text later during an unrelated surface handoff.
	self._protectedCreationTextDraftPrepared = true
	if not NativeCreation:CanClearCreationTextFields() then
		return false
	end
	local callOK, cleared = pcall(
		NativeCreation.ClearCreationTextFields,
		NativeCreation
	)
	if not callOK or cleared ~= true then
		return false
	end
	local creation = Fields.getEntryCreation()
	local voiceToggle = creation and creation.VoiceChat
		and creation.VoiceChat.CheckButton
	if voiceToggle and type(voiceToggle.SetChecked) == "function" then
		voiceToggle:SetChecked(false)
	end
	return true
end

function CP:ApplyMythicPlusHiddenCreateDefaults(force)
	if not self:IsMythicPlusSidebarMode() or self.editMode then
		return
	end
	if self._mythicPlusHiddenDefaultsApplied and not force then
		return
	end
	local voiceToggle = self.voiceFrame and self.voiceFrame.CheckButton
	if voiceToggle and type(voiceToggle.SetChecked) == "function" then
		voiceToggle:SetChecked(false)
	end
	if self.privateCheck then
		self.privateCheck:SetChecked(false)
	end
	if self.crossFactionCheck then
		-- Unchecked maps to the normal cross-faction-enabled listing state.
		self.crossFactionCheck:SetChecked(false)
	end
	self._mythicPlusHiddenDefaultsApplied = true
end

local function isEmptyEditText(editBox)
	if not editBox then
		return true
	end
	local empty = Fields.editBoxIsEmptyByLetterCount(editBox)
	if empty ~= nil then
		return empty
	end
	if type(editBox.GetText) ~= "function" then
		return true
	end
	local ok, text = pcall(editBox.GetText, editBox)
	if not ok or Fields.secretText(text) then
		return false
	end
	return text == nil or text == ""
end

function CP:LayoutCustomPlaceholders()
	local showUnboundPlaceholders = self._showCompleteDisabledForm == true
		and self:IsMythicPlusSidebarMode()
	if self.namePlaceholder and (self.nameEdit or self.nameAnchor) then
		local placeholderParent = self.nameEdit
			or (showUnboundPlaceholders and (
				self.nameAtlasAnchor or self.nameAnchor
			))
			or self.formBody
		if placeholderParent and self.namePlaceholder.SetParent then
			self.namePlaceholder:SetParent(placeholderParent)
		end
		local anchor = self.nameEdit or self.nameAnchor
		self.namePlaceholder:ClearAllPoints()
		self.namePlaceholder:SetPoint("LEFT", anchor, "LEFT", CREATE_PLACEHOLDER_LEFT_INSET, 0)
		self.namePlaceholder:SetPoint("RIGHT", anchor, "RIGHT", -6, 0)
	end
	local descriptionEdit = self.commentScroll and self.commentScroll.EditBox
	local descriptionAnchor = descriptionEdit or self.commentScroll or self.descAnchor
	if self.descPlaceholder and descriptionAnchor then
		local placeholderParent = descriptionEdit
			or (showUnboundPlaceholders and (
				self.descAtlasAnchor or self.descAnchor
			))
			or self.formBody
		if placeholderParent and self.descPlaceholder.SetParent then
			self.descPlaceholder:SetParent(placeholderParent)
		end
		self.descPlaceholder:ClearAllPoints()
		self.descPlaceholder:SetPoint(
			"TOPLEFT",
			descriptionAnchor,
			"TOPLEFT",
			CREATE_PLACEHOLDER_LEFT_INSET,
			0
		)
		self.descPlaceholder:SetPoint(
			"TOPRIGHT",
			descriptionAnchor,
			"TOPRIGHT",
			0,
			0
		)
		if self.descPlaceholder.SetSpacing then
			self.descPlaceholder:SetSpacing(
				CREATE_DESCRIPTION_PLACEHOLDER_SPACING
			)
		end
	end
end

function CP:UpdateCustomPlaceholders()
	local L = GF.L or {}
	local showUnboundDisabledPlaceholders = self._showCompleteDisabledForm == true
		and self:IsMythicPlusSidebarMode()
	if self.namePlaceholder then
		self.namePlaceholder:SetAlpha(1)
		self.namePlaceholder:SetText(L.CREATE_NAME_PLACEHOLDER or "请输入队伍名称")
		self.namePlaceholder:SetShown(
			self.nameEdit ~= nil and isEmptyEditText(self.nameEdit)
				or self.nameEdit == nil and showUnboundDisabledPlaceholders
		)
	end
	local descEdit = self.commentScroll and self.commentScroll.EditBox
	if self.descPlaceholder then
		self.descPlaceholder:SetAlpha(1)
		self.descPlaceholder:SetText(L.CREATE_COMMENT_PLACEHOLDER or "请输入关于你的队伍的更多细节（可选）")
		self.descPlaceholder:SetShown(
			descEdit ~= nil and isEmptyEditText(descEdit)
				or descEdit == nil and showUnboundDisabledPlaceholders
		)
	end
end

function CP:GetCreateDescriptionHeight()
	if self:IsMythicPlusCreateManagerSurface() then
		return GF.MPLUS_CREATE_SIDEBAR_DESC_H
	end
	return self:IsMythicPlusSidebarMode() and (GF.CREATE_SIDEBAR_DESC_H or 72)
		or self:IsRaidDrawerMode() and GF.RAID_CREATE_DRAWER_STYLE.descriptionHeight
		or CREATE_FORM_DESC_H
end

function CP:UpdateFieldLayout()
	local nameW, descW = self:GetCreateFieldWidths()
	local nativeNameW = math.max(nameW - (FIELD_EDGE_PAD * 2), 1)
	local nativeDescW = math.max(descW - (FIELD_EDGE_PAD * 2), 1)
	local fieldLayoutEnabled = self._protectedFieldsFormEnabled ~= false
	local descriptionHeight = self:GetCreateDescriptionHeight()
	local descriptionChromeHeight = descriptionHeight + (CREATE_FORM_DESC_ATLAS_PAD_Y * 2)

	local nameSlot, nameChrome = self.nameAnchor, self.nameAtlasAnchor
	local descriptionSlot, descriptionChrome = self.descAnchor, self.descAtlasAnchor
	if nameSlot ~= nil then
		nameSlot:SetSize(nativeNameW, CREATE_FORM_INPUT_H)
	end
	if nameChrome ~= nil then
		nameChrome:SetSize(nameW, CREATE_FORM_INPUT_H)
		Fields.updateCreateInputAtlasFrame(nameChrome, false, fieldLayoutEnabled)
	end
	if descriptionSlot ~= nil then
		descriptionSlot:SetSize(nativeDescW, descriptionHeight)
	end
	if descriptionChrome ~= nil then
		descriptionChrome:SetSize(descW, descriptionChromeHeight)
		Fields.updateCreateDescriptionAtlasFrame(
			descriptionChrome,
			false,
			fieldLayoutEnabled
		)
	end

	self:ApplyPlaystyleDropdownLayout()

	local fieldsAreBorrowed = self._attached == true
		and self:IsBorrowingBlizzardFields()
	if fieldsAreBorrowed then
		local creation, host = Fields.getEntryCreation(), self:GetEmbedParent()
		if creation ~= nil and host ~= nil
			and creation:GetParent() == host
		then
			local ec = creation
			local borrowedName = creation.Name
			if borrowedName ~= nil and self.nameAnchor ~= nil
				and borrowedName:GetParent() == ec
			then
				borrowedName:ClearAllPoints()
				borrowedName:SetPoint(
					"TOPLEFT",
					self.nameAnchor,
					"TOPLEFT"
				)
				borrowedName:SetSize(nativeNameW, CREATE_FORM_INPUT_H)
				borrowedName:Show()
				Fields.hideBorrowedNameChrome(borrowedName)
				if not borrowedName._gfCreateNameAtlasHooked then
					borrowedName:HookScript("OnEditFocusGained", function()
						local enabled = not borrowedName.IsEnabled or borrowedName:IsEnabled()
						Fields.updateCreateInputAtlasFrame(CP.nameAtlasAnchor, enabled, enabled)
					end)
					borrowedName:HookScript("OnEditFocusLost", function()
						local enabled = not borrowedName.IsEnabled or borrowedName:IsEnabled()
						Fields.updateCreateInputAtlasFrame(CP.nameAtlasAnchor, borrowedName._gfCreateNameHovered and enabled, enabled)
					end)
					borrowedName:HookScript("OnEnter", function()
						borrowedName._gfCreateNameHovered = true
						local enabled = not borrowedName.IsEnabled or borrowedName:IsEnabled()
						Fields.updateCreateInputAtlasFrame(CP.nameAtlasAnchor, enabled, enabled)
					end)
					borrowedName:HookScript("OnLeave", function()
						borrowedName._gfCreateNameHovered = false
						local enabled = not borrowedName.IsEnabled or borrowedName:IsEnabled()
						Fields.updateCreateInputAtlasFrame(CP.nameAtlasAnchor, borrowedName:HasFocus() and enabled, enabled)
					end)
					borrowedName:HookScript("OnEnable", function()
						Fields.updateCreateInputAtlasFrame(CP.nameAtlasAnchor, borrowedName:HasFocus() or borrowedName._gfCreateNameHovered, true)
					end)
					borrowedName:HookScript("OnDisable", function()
						Fields.updateCreateInputAtlasFrame(CP.nameAtlasAnchor, false, false)
					end)
					borrowedName._gfCreateNameAtlasHooked = true
				end
				local enabled = not borrowedName.IsEnabled or borrowedName:IsEnabled()
				Fields.updateCreateInputAtlasFrame(self.nameAtlasAnchor, enabled and (borrowedName:HasFocus() or borrowedName._gfCreateNameHovered), enabled)
				Fields.suppressNativeInstructions(borrowedName)
			end
			if ec.Description and self.descAnchor
				and ec.Description:GetParent() == ec
			then
				-- Capture the native scrollbar before resizing its parent, then keep
				-- one projection across both addon-owned form layouts.
				Fields.projectDescriptionScrollBar(ec.Description, true)
				ec.Description:ClearAllPoints()
				ec.Description:SetPoint(
					"TOPLEFT",
					self.descAnchor,
					"TOPLEFT"
				)
				ec.Description:SetSize(nativeDescW, descriptionHeight)
				ec.Description:Show()
				Fields.hideBorrowedWidgetChrome(ec.Description, "_gfDescriptionChromeState")
				if not ec.Description._gfCreateDescAtlasHooked then
					ec.Description:HookScript("OnEnter", function()
						ec.Description._gfCreateDescHovered = true
						Fields.updateBorrowedDescriptionAtlas(ec.Description)
					end)
					ec.Description:HookScript("OnLeave", function()
						ec.Description._gfCreateDescHovered = false
						Fields.updateBorrowedDescriptionAtlas(ec.Description)
					end)
					if ec.Description.EditBox then
						ec.Description.EditBox:HookScript("OnEditFocusGained", function()
							Fields.updateBorrowedDescriptionAtlas(ec.Description)
						end)
						ec.Description.EditBox:HookScript("OnEditFocusLost", function()
							Fields.updateBorrowedDescriptionAtlas(ec.Description)
						end)
						ec.Description.EditBox:HookScript("OnEnable", function()
							Fields.updateBorrowedDescriptionAtlas(ec.Description)
						end)
						ec.Description.EditBox:HookScript("OnDisable", function()
							Fields.updateBorrowedDescriptionAtlas(ec.Description)
						end)
					end
					ec.Description._gfCreateDescAtlasHooked = true
				end
				if ec.Description.EditBox then
					Fields.ensureScrollingEditInitialized(ec.Description.EditBox)
					Fields.syncDescriptionEditBoxWidth(ec.Description)
					Fields.suppressNativeInstructions(ec.Description.EditBox)
				end
				Fields.updateBorrowedDescriptionAtlas(ec.Description)
			end
			if ec.VoiceChat and self.voiceAnchor then
				Fields.projectBorrowedVoiceField(self, ec, ec.VoiceChat)
			end
		end
	end

	self:LayoutCustomPlaceholders()
	self:UpdateCustomPlaceholders()
end

function CP:ApplyHorizontalDrawerLayout()
	if not self.formColumn then
		return false
	end
	if not Fields.getCreateDrawerFooter(self.parent) then
		return false
	end
	local raidLayout = self:IsRaidDrawerMode()
	local colW, colGap, fullW = self:GetCreateColumnWidth()
	local needsWidth
	if raidLayout then
		colW, colGap, needsWidth, fullW = self:GetRaidDrawerColumns()
	end
	if not colW then
		return false
	end
	local rowY = 0
	local rowH = CREATE_FORM_TITLE_SIZE + CREATE_FORM_STACK_LABEL_GAP + CREATE_FORM_INPUT_H + CREATE_FORM_STACK_ROW_GAP
	local rightX = colW + colGap
	local textFieldWidth = raidLayout and colW or fullW
	local descriptionHeight = raidLayout and GF.RAID_CREATE_DRAWER_STYLE.descriptionHeight or CREATE_FORM_DESC_H
	local descriptionChromeHeight = descriptionHeight + CREATE_FORM_DESC_ATLAS_PAD_Y * 2
	local nameHeaderHeight = raidLayout and GF.RAID_RECRUITMENT_NEEDS_STYLE.headerHeight or CREATE_FORM_TITLE_SIZE

	local function placeField(label, anchor, x, y, w, controlHeight, sideInset, titleHeight)
		if not label or not anchor then
			return
		end
		sideInset = sideInset or 0
		controlHeight = controlHeight or CREATE_FORM_INPUT_H
		titleHeight = titleHeight or CREATE_FORM_TITLE_SIZE
		label:ClearAllPoints()
		label:SetPoint("TOPLEFT", self.formColumn, "TOPLEFT", x, -y - (titleHeight - CREATE_FORM_TITLE_SIZE) / 2)
		label:SetWidth(w)
		label:SetJustifyH("LEFT")
		anchor:ClearAllPoints()
		anchor:SetSize(math.max(w - (sideInset * 2), 1), controlHeight)
		anchor:SetPoint("TOPLEFT", self.formColumn, "TOPLEFT", x + sideInset, -y - titleHeight - CREATE_FORM_STACK_LABEL_GAP)
	end

	local function placeCheckbox(check, label, x, y, w)
		if not check or not check:IsShown() then
			return false
		end
		check:ClearAllPoints()
		check:SetPoint("TOPLEFT", self.formColumn, "TOPLEFT", x, -y - math.floor((CREATE_FORM_ROW_H - CREATE_CHECK_SIZE) / 2))
		if label then
			label:ClearAllPoints()
			label:SetPoint("LEFT", check, "RIGHT", CREATE_CHECK_LABEL_GAP, 0)
			label:SetWidth(math.max(w - CREATE_CHECK_SIZE - CREATE_CHECK_LABEL_GAP - 4, 1))
			label:SetJustifyH("LEFT")
		end
		return true
	end

	self.formColumn:SetSize(fullW, 1)

	placeField(self.nameLabel, self.nameAtlasAnchor, 0, rowY, textFieldWidth, CREATE_FORM_INPUT_H, nil, nameHeaderHeight)
	if self.nameAnchor and self.nameAtlasAnchor then
		self.nameAnchor:ClearAllPoints()
		self.nameAnchor:SetPoint("TOPLEFT", self.nameAtlasAnchor, "TOPLEFT", FIELD_EDGE_PAD, 0)
		self.nameAnchor:SetSize(math.max(textFieldWidth - (FIELD_EDGE_PAD * 2), 1), CREATE_FORM_INPUT_H)
	end
	rowY = rowY + nameHeaderHeight + CREATE_FORM_STACK_LABEL_GAP + CREATE_FORM_INPUT_H + CREATE_FORM_STACK_ROW_GAP

	placeField(self.commentLabel, self.descAtlasAnchor, 0, rowY, textFieldWidth, descriptionChromeHeight)
	if self.descAnchor and self.descAtlasAnchor then
		self.descAnchor:ClearAllPoints()
		self.descAnchor:SetPoint("TOPLEFT", self.descAtlasAnchor, "TOPLEFT", FIELD_EDGE_PAD, -CREATE_FORM_DESC_ATLAS_PAD_Y)
		self.descAnchor:SetSize(math.max(textFieldWidth - (FIELD_EDGE_PAD * 2), 1), descriptionHeight)
	end
	rowY = rowY + CREATE_FORM_TITLE_SIZE + CREATE_FORM_STACK_LABEL_GAP + descriptionChromeHeight + CREATE_FORM_STACK_ROW_GAP

	placeField(self.playLabel, self.playDropdownAnchor, 0, rowY, colW, CREATE_FORM_INPUT_H)
	if raidLayout then rowY = rowY + rowH end
	placeField(self.ilvlLabel, self.ilvlAnchor, raidLayout and 0 or rightX, rowY, colW, CREATE_FORM_INPUT_H)
	rowY = rowY + rowH

	if self.mplusLabel and self.mplusLabel:IsShown() and self.mplusAnchor then
		placeField(self.voiceLabel, self.voiceAnchor, 0, rowY, colW, CREATE_FORM_INPUT_H)
		placeField(self.mplusLabel, self.mplusAnchor, rightX, rowY, colW, CREATE_FORM_INPUT_H)
		rowY = rowY + rowH
	else
		placeField(self.voiceLabel, self.voiceAnchor, 0, rowY, colW, CREATE_FORM_INPUT_H)
		rowY = rowY + rowH
	end

	local hasCheck = false
	local checkWidth = raidLayout and math.floor((colW - colGap) / 2) or colW
	local leftCheckUsed = placeCheckbox(self.crossFactionCheck, self.crossFactionLabel, 0, rowY, checkWidth)
	if leftCheckUsed then
		hasCheck = true
	end
	local privateX = leftCheckUsed and (raidLayout and (checkWidth + colGap) or rightX) or 0
	if placeCheckbox(self.privateCheck, self.privateLabel, privateX, rowY, checkWidth) then
		hasCheck = true
	end
	if hasCheck then
		rowY = rowY + CREATE_FORM_ROW_H
	end

	local needsHeight = 0
	if GF.RaidRecruitmentNeedsPanel then
		needsHeight = GF.RaidRecruitmentNeedsPanel:Place(self, needsWidth or fullW, 0, rightX)
	end
	self._compactFormHeight = math.max(rowY, needsHeight)
	self:ApplyPlaystyleDropdownLayout()
	self:LayoutCustomPlaceholders()
	return true
end

function CP:ApplyMythicPlusSidebarLayout()
	if not self.formColumn then
		return
	end
	local _, fieldW = self:GetCreateFieldWidths()
	local rowY = 0
	self.formColumn:SetSize(fieldW, 1)
	local blockGapIndex = 0
	local titleInset = GF.MPLUS_LFG_SIDEBAR_SECTION_TITLE_INSET_X or 2
	local spacing = self:IsMythicPlusCreateManagerSurface() and MPLUS_SIDEBAR_SPACING
	local titleHeight = spacing and spacing.sectionTitleHeight or CREATE_SIDEBAR_SECTION_TITLE_H
	local titleControlGap = spacing and spacing.titleControlGap or CREATE_SIDEBAR_LABEL_CONTROL_GAP
	local blockGaps = spacing and {
		spacing.sectionGap, spacing.sectionGap, spacing.sectionGap, spacing.sectionGap,
	} or CREATE_SIDEBAR_BLOCK_GAPS

	local function placeField(label, anchor, controlHeight, addGap)
		if not label or not anchor then
			return
		end
		controlHeight = controlHeight or CREATE_FORM_INPUT_H
		label:ClearAllPoints()
		label:SetPoint(
			"TOPLEFT",
			self.formColumn,
			"TOPLEFT",
			titleInset,
			-rowY
		)
		label:SetSize(
			math.max(fieldW - (titleInset * 2), 1),
			titleHeight
		)
		label:SetJustifyH("LEFT")
		label:SetJustifyV("MIDDLE")
		anchor:ClearAllPoints()
		anchor:SetPoint(
			"TOPLEFT",
			self.formColumn,
			"TOPLEFT",
			0,
			-rowY
				- titleHeight
				- titleControlGap
		)
		anchor:SetSize(fieldW, controlHeight)
		rowY = rowY
			+ titleHeight
			+ titleControlGap
			+ controlHeight
		if addGap then
			blockGapIndex = blockGapIndex + 1
			rowY = rowY + blockGaps[blockGapIndex]
		end
	end

	placeField(
		self.nameLabel,
		self.nameAtlasAnchor,
		CREATE_FORM_INPUT_H,
		true
	)
	if self.nameAnchor and self.nameAtlasAnchor then
		self.nameAnchor:ClearAllPoints()
		self.nameAnchor:SetPoint(
			"TOPLEFT",
			self.nameAtlasAnchor,
			"TOPLEFT",
			FIELD_EDGE_PAD,
			0
		)
		self.nameAnchor:SetSize(
			math.max(fieldW - (FIELD_EDGE_PAD * 2), 1),
			CREATE_FORM_INPUT_H
		)
	end

	placeField(
		self.commentLabel,
		self.descAtlasAnchor,
		self:GetCreateDescriptionHeight()
			+ (CREATE_FORM_DESC_ATLAS_PAD_Y * 2),
		true
	)
	if self.descAnchor and self.descAtlasAnchor then
		self.descAnchor:ClearAllPoints()
		self.descAnchor:SetPoint(
			"TOPLEFT",
			self.descAtlasAnchor,
			"TOPLEFT",
			FIELD_EDGE_PAD,
			-CREATE_FORM_DESC_ATLAS_PAD_Y
		)
		self.descAnchor:SetSize(
			math.max(fieldW - (FIELD_EDGE_PAD * 2), 1),
			self:GetCreateDescriptionHeight()
		)
	end

	placeField(
		self.playLabel,
		self.playDropdownAnchor,
		CREATE_FORM_INPUT_H,
		true
	)
	placeField(
		self.ilvlLabel,
		self.ilvlAnchor,
		CREATE_FORM_INPUT_H,
		true
	)
	if self.mplusLabel and self.mplusAnchor then
		placeField(
			self.mplusLabel,
			self.mplusAnchor,
			CREATE_FORM_INPUT_H,
			false
		)
	end

	for _, widget in ipairs({
		self.voiceLabel,
		self.voiceAnchor,
		self.voiceFrame,
		self.voiceEdit,
		self.crossFactionCheck,
		self.crossFactionLabel,
		self.privateCheck,
		self.privateLabel,
	}) do
		if widget then
			widget:Hide()
		end
	end
	self._compactFormHeight = rowY
	self._resolvedMythicPlusSidebarBlockGaps = blockGaps
	self:ApplyPlaystyleDropdownLayout()
	self:LayoutCustomPlaceholders()
	self:FitMythicPlusSidebarLabels()
end

function CP:ApplyCompactRowLayout()
	if not self.formColumn then
		return
	end
	if self:IsMythicPlusSidebarMode() then
		if self.raidNeedsUI then self.raidNeedsUI.frame:Hide() end
		self:ApplyMythicPlusSidebarLayout()
		return
	end
	if self:ApplyHorizontalDrawerLayout() then
		return
	end
	local _, fieldW = self:GetCreateFieldWidths()
	local rowY = 0
	self.formColumn:SetSize(fieldW, 1)
	local function placeStackedField(label, anchor, controlHeight, sideInset)
		if not label or not anchor then
			return
		end
		sideInset = sideInset or 0
		controlHeight = controlHeight or CREATE_FORM_INPUT_H
		label:ClearAllPoints()
		label:SetPoint("TOPLEFT", self.formColumn, "TOPLEFT", 0, -rowY)
		label:SetWidth(fieldW)
		label:SetJustifyH("LEFT")
		anchor:ClearAllPoints()
		anchor:SetSize(math.max(fieldW - (sideInset * 2), 1), controlHeight)
		anchor:SetPoint("TOPLEFT", self.formColumn, "TOPLEFT", sideInset, -rowY - CREATE_FORM_TITLE_SIZE - CREATE_FORM_STACK_LABEL_GAP)
		rowY = rowY + CREATE_FORM_TITLE_SIZE + CREATE_FORM_STACK_LABEL_GAP + controlHeight + CREATE_FORM_STACK_ROW_GAP
	end
	placeStackedField(self.nameLabel, self.nameAtlasAnchor, CREATE_FORM_INPUT_H)
	if self.nameAnchor and self.nameAtlasAnchor then
		self.nameAnchor:ClearAllPoints()
		self.nameAnchor:SetPoint("TOPLEFT", self.nameAtlasAnchor, "TOPLEFT", FIELD_EDGE_PAD, 0)
		self.nameAnchor:SetSize(math.max(fieldW - (FIELD_EDGE_PAD * 2), 1), CREATE_FORM_INPUT_H)
	end
	if GF.RaidRecruitmentNeedsPanel then
		rowY = rowY + GF.RaidRecruitmentNeedsPanel:Place(self, fieldW, rowY)
	end
	placeStackedField(self.commentLabel, self.descAtlasAnchor, CREATE_FORM_DESC_ATLAS_H)
	if self.descAnchor and self.descAtlasAnchor then
		self.descAnchor:ClearAllPoints()
		self.descAnchor:SetPoint("TOPLEFT", self.descAtlasAnchor, "TOPLEFT", FIELD_EDGE_PAD, -CREATE_FORM_DESC_ATLAS_PAD_Y)
		self.descAnchor:SetSize(math.max(fieldW - (FIELD_EDGE_PAD * 2), 1), CREATE_FORM_DESC_H)
	end
	placeStackedField(self.playLabel, self.playDropdownAnchor, CREATE_FORM_INPUT_H)
	placeStackedField(self.ilvlLabel, self.ilvlAnchor, CREATE_FORM_INPUT_H)
	if self.mplusLabel and self.mplusLabel:IsShown() and self.mplusAnchor then
		placeStackedField(self.mplusLabel, self.mplusAnchor, CREATE_FORM_INPUT_H)
	end
	placeStackedField(self.voiceLabel, self.voiceAnchor, CREATE_FORM_INPUT_H)

	if self.crossFactionCheck and self.crossFactionCheck:IsShown() then
		self.crossFactionCheck:ClearAllPoints()
		self.crossFactionCheck:SetPoint("TOPLEFT", self.formColumn, "TOPLEFT", 0, -rowY - math.floor((CREATE_FORM_ROW_H - CREATE_CHECK_SIZE) / 2))
		if self.crossFactionLabel then
			self.crossFactionLabel:ClearAllPoints()
			self.crossFactionLabel:SetPoint("LEFT", self.crossFactionCheck, "RIGHT", CREATE_CHECK_LABEL_GAP, 0)
			self.crossFactionLabel:SetJustifyH("LEFT")
		end
		rowY = rowY + CREATE_FORM_ROW_H
	end
	if self.privateCheck and self.privateCheck:IsShown() then
		self.privateCheck:ClearAllPoints()
		self.privateCheck:SetPoint("TOPLEFT", self.formColumn, "TOPLEFT", 0, -rowY - math.floor((CREATE_FORM_ROW_H - CREATE_CHECK_SIZE) / 2))
		if self.privateLabel then
			self.privateLabel:ClearAllPoints()
			self.privateLabel:SetPoint("LEFT", self.privateCheck, "RIGHT", CREATE_CHECK_LABEL_GAP, 0)
			self.privateLabel:SetJustifyH("LEFT")
		end
		rowY = rowY + CREATE_FORM_ROW_H
	end
	self._compactFormHeight = rowY
	self:ApplyPlaystyleDropdownLayout()
	self:LayoutCustomPlaceholders()
end

function CP:UpdateRequirementLayout()
	local complete = self.ilvlAnchor ~= nil and self.voiceLabel ~= nil
		and self.voiceAnchor ~= nil and self.formColumn ~= nil
	if not complete then
		return false
	end
	self:ApplyCompactRowLayout()
	self:UpdateScrollLayout()
	return true
end

function CP:GetEmbedParent()
	return self.formBody or self.parent
end

function CP:MeasureFormBodyHeight()
	local minimum = 100
	local compactHeight = tonumber(self._compactFormHeight)
	if compactHeight ~= nil and compactHeight > 0 then
		return math.max(minimum, compactHeight + CONTENT_PAD)
	end
	local first = self.nameLabel
	local last = self.privateCheck or self.privateLabel or self.voiceAnchor
	if self.formBody == nil or first == nil or last == nil
		or type(first.GetRect) ~= "function"
		or type(last.GetRect) ~= "function"
	then
		return minimum
	end
	local _, firstBottom, _, firstHeight = first:GetRect()
	local _, lastBottom = last:GetRect()
	if type(firstBottom) ~= "number" or type(firstHeight) ~= "number"
		or type(lastBottom) ~= "number" or firstHeight <= 0
	then
		return minimum
	end
	local measured = firstBottom + firstHeight - lastBottom + CONTENT_PAD
	return measured > minimum and measured or minimum
end

function CP:CancelUpdateScrollLayoutDebounce()
	local pending = self._scrollLayoutDebounce
	self._scrollLayoutDebounce = nil
	if pending ~= nil and type(pending.Cancel) == "function" then
		pending:Cancel()
	end
end

function CP:ScheduleUpdateScrollLayout()
	local host = self.parent
	if host ~= nil and type(host.IsShown) == "function"
		and not host:IsShown()
	then
		return
	end
	self:CancelUpdateScrollLayoutDebounce()
	local schedule = C_Timer and C_Timer.NewTimer
	if type(schedule) ~= "function" then
		self:UpdateScrollLayout()
		return
	end
	local delay = GF.LAYOUT_RESIZE_DEBOUNCE or 0.1
	local showGeneration = self._showGeneration
	local pending
	pending = schedule(delay, function()
		if CP._scrollLayoutDebounce ~= pending then
			return
		end
		CP._scrollLayoutDebounce = nil
		if CP._showGeneration ~= showGeneration or CP.parent ~= host
			or (type(host.IsShown) == "function" and not host:IsShown())
		then
			return
		end
		CP:UpdateScrollLayout()
	end)
	self._scrollLayoutDebounce = pending
end

local function updateCreateScrollBar(panel)
	if Fields.getCreateDrawerFooter(panel.parent) == nil or panel.scrollBar == nil then
		return
	end
	local rightInset = Fields.createDrawerScrollInsetR()
	Fields.anchorCreateDrawerScrollBar(
		panel.scroll,
		panel.scrollBar,
		Fields.createDrawerScrollBarOffsetX(rightInset)
	)
end

function CP:UpdateScrollLayout()
	local scroll, body, host = self.scroll, self.formBody, self.parent
	if scroll == nil or body == nil or host == nil
		or (type(host.IsShown) == "function" and not host:IsShown())
	then
		return false
	end
	local availableWidth = tonumber(scroll:GetWidth())
	if availableWidth ~= nil and availableWidth > 0 then
		body:SetWidth(availableWidth)
	end
	if self._frameResizing == true or GF._frameResizing == true then
		return false
	end
	self:ApplyCompactRowLayout()
	self:UpdateFieldLayout()
	local contentHeight = self:MeasureFormBodyHeight()
	body:SetHeight(contentHeight)
	GF.UI.UpdateScrollFrame(scroll)
	updateCreateScrollBar(self)

	local viewportHeight = tonumber(scroll:GetHeight()) or 0
	local targetOffset = tonumber(scroll:GetVerticalScroll()) or 0
	if viewportHeight > 0 and contentHeight <= viewportHeight then
		targetOffset = 0
	else
		local maximum = tonumber(scroll:GetVerticalScrollRange()) or 0
		targetOffset = math.min(targetOffset, maximum)
	end
	if GF.UI.CancelSmoothWheelScrolling then
		GF.UI.CancelSmoothWheelScrolling(scroll)
	end
	scroll:SetVerticalScroll(math.max(0, targetOffset))
	return true
end

-- Blizzard keeps ownership of the protected text. This reveal only writes
-- constant/time-derived alpha to the three native inputs and our three chrome
-- anchors; it never reads protected text or changes field geometry.
function CP:SetEditFieldRevealAlpha(state, alpha)
	local targets = state and state.targets
	if type(targets) ~= "table" or #targets ~= 6 then
		return false
	end
	local succeeded = true
	for index = 1, #targets do
		local target = targets[index]
		if target == nil or type(target.SetAlpha) ~= "function"
			or not pcall(target.SetAlpha, target, alpha)
		then
			succeeded = false
		end
	end
	return succeeded
end

function CP:EnsureEditFieldRevealDriver()
	local driver = self._editFieldRevealDriver
	if driver ~= nil then
		return driver
	end
	if self.formBody == nil or type(CreateFrame) ~= "function" then
		return nil
	end
	local created, frame = pcall(CreateFrame, "Frame", nil, self.formBody)
	if not created or frame == nil or type(frame.SetScript) ~= "function"
		or type(frame.Show) ~= "function" or type(frame.Hide) ~= "function"
	then
		return nil
	end
	local scripted = pcall(frame.SetScript, frame, "OnUpdate", function(_, elapsed)
		CP:AdvanceEditFieldReveal(elapsed)
	end)
	if not scripted then
		return nil
	end
	if type(frame.SetSize) == "function" then
		pcall(frame.SetSize, frame, 1, 1)
	end
	if type(frame.SetPoint) == "function" then
		pcall(frame.SetPoint, frame, "TOPLEFT", self.formBody, "TOPLEFT")
	end
	pcall(frame.Hide, frame)
	self._editFieldRevealDriver = frame
	return frame
end

function CP:CancelEditFieldReveal()
	self._editFieldRevealGeneration =
		(tonumber(self._editFieldRevealGeneration) or 0) + 1
	local state = self._editFieldReveal
	self._editFieldReveal = nil
	local driver = self._editFieldRevealDriver
	if driver ~= nil and type(driver.Hide) == "function" then
		pcall(driver.Hide, driver)
	end
	if state ~= nil then
		self:SetEditFieldRevealAlpha(state, 1)
	end
	return state ~= nil
end

function CP:StageEditFieldReveal(options)
	options = options or {}
	self:CancelEditFieldReveal()
	local revealMode
	if self.editMode == true then
		revealMode = "edit"
	elseif options.resumeCreateDraft == true
		and self:IsResumingProtectedCreateDraft(options)
	then
		revealMode = "create-draft"
	else
		return false
	end
	if self._createChannelBlocked == true
		or self._protectedFieldsFormEnabled == false
		or self:IsMythicPlusSidebarMode()
		or self._attached ~= true
		or not self:IsBorrowingBlizzardFields()
	then
		return false
	end
	local descriptionEdit = self.commentScroll and self.commentScroll.EditBox
	local targets = {
		self.nameEdit,
		descriptionEdit,
		self.voiceEdit,
		self.nameAtlasAnchor,
		self.descAtlasAnchor,
		self.voiceAnchor,
	}
	for index = 1, #targets do
		if targets[index] == nil
			or type(targets[index].SetAlpha) ~= "function"
		then
			return false
		end
	end
	local driver = self:EnsureEditFieldRevealDriver()
	if driver == nil then
		return false
	end
	local generation =
		(tonumber(self._editFieldRevealGeneration) or 0) + 1
	self._editFieldRevealGeneration = generation
	local state = {
		generation = generation,
		mode = revealMode,
		targets = targets,
		driver = driver,
		duration = tonumber(GF.CREATE_EDIT_FIELD_REVEAL_DURATION) or 0.18,
		elapsed = 0,
		staged = true,
		playing = false,
	}
	self._editFieldReveal = state
	if not self:SetEditFieldRevealAlpha(state, 0) then
		self:CancelEditFieldReveal()
		return false
	end
	return true
end

function CP:PlayEditFieldReveal()
	local state = self._editFieldReveal
	if state == nil or state.staged ~= true
		or state.generation ~= self._editFieldRevealGeneration
	then
		return false
	end
	state.staged = false
	state.playing = true
	state.elapsed = 0
	if not pcall(state.driver.Show, state.driver) then
		self:CancelEditFieldReveal()
		return false
	end
	return true
end

function CP:AdvanceEditFieldReveal(elapsed)
	local state = self._editFieldReveal
	if state == nil or state.playing ~= true
		or state.generation ~= self._editFieldRevealGeneration
	then
		return false
	end
	local revealModeValid = state.mode == "edit" and self.editMode == true
		or state.mode == "create-draft"
			and self:IsResumingProtectedCreateDraft()
	if not revealModeValid or self._createChannelBlocked == true
		or self:IsMythicPlusSidebarMode()
		or self._attached ~= true
		or not self:IsBorrowingBlizzardFields()
		or self.nameEdit ~= state.targets[1]
		or not (self.commentScroll
			and self.commentScroll.EditBox == state.targets[2])
		or self.voiceEdit ~= state.targets[3]
		or self.nameAtlasAnchor ~= state.targets[4]
		or self.descAtlasAnchor ~= state.targets[5]
		or self.voiceAnchor ~= state.targets[6]
	then
		self:CancelEditFieldReveal()
		return false
	end
	state.elapsed = state.elapsed + math.max(0, tonumber(elapsed) or 0)
	local duration = math.max(0.01, tonumber(state.duration) or 0.18)
	local progress = math.min(1, state.elapsed / duration)
	local remaining = 1 - progress
	local alpha = 1 - (remaining * remaining * remaining)
	if not self:SetEditFieldRevealAlpha(state, alpha) then
		self:CancelEditFieldReveal()
		return false
	end
	if progress >= 1 then
		self:CancelEditFieldReveal()
	end
	return true
end

local function blurCreationControls(panel)
	local nativePanel = Fields.getEntryCreation()
	if nativePanel ~= nil and type(LFGListEntryCreation_ClearFocus) == "function" then
		LFGListEntryCreation_ClearFocus(nativePanel)
		return
	end
	local controls = {
		panel.nameEdit,
		panel.commentScroll and panel.commentScroll.EditBox,
		panel.voiceEdit,
		panel.ilvlEdit,
		panel.mplusEdit,
	}
	for controlIndex = 1, #controls do
		local control = controls[controlIndex]
		if control ~= nil and type(control.ClearFocus) == "function" then
			control:ClearFocus()
		end
	end
end

function CP:UpdateBlockedOverlayLayout()
	local overlay = self.blockedOverlay
	local text = overlay and overlay.text
	if not text then
		return
	end
	local width = overlay.GetWidth and overlay:GetWidth() or 0
	if width <= 0 and self.parent and self.parent.GetWidth then
		width = self.parent:GetWidth() or 0
	end
	if width > 0 then
		text:SetWidth(math.max(
			width - (CREATE_BLOCKED_TEXT_INSET_X * 2),
			1
		))
		text:SetHeight(0)
	end
end

function CP:SyncBlockedOverlayFrameLevel()
	if self.blockedOverlay and self.parent then
		self.blockedOverlay:SetFrameLevel(
			(self.parent.GetFrameLevel
				and self.parent:GetFrameLevel() or 0) + 30
		)
	end
	self:UpdateBlockedOverlayLayout()
end

function CP:EnsureBlockedOverlay()
	if self.blockedOverlay then
		self:SyncBlockedOverlayFrameLevel()
		return self.blockedOverlay
	end
	if not self.parent then
		return self.blockedOverlay
	end
	local L = GF.L or {}
	local overlay = CreateFrame("Frame", nil, self.parent)
	overlay:SetAllPoints(self.parent)
	overlay:EnableMouse(false)

	local text = GF.UI.CreateFontString(overlay, "OVERLAY", "GameFontNormalLarge")
	text:SetPoint("CENTER", overlay, "CENTER", 0, 18)
	text:SetJustifyH("CENTER")
	text:SetWordWrap(true)
	text:SetNonSpaceWrap(true)
	text:SetMaxLines(0)
	text:SetHeight(0)
	text:SetTextColor(1, 0.82, 0, 1)
	text:SetText(L.CREATE_CHANNEL_OCCUPIED or "系统预创建队伍正在占用招募通道")
	overlay.text = text
	overlay:SetScript("OnSizeChanged", function()
		CP:UpdateBlockedOverlayLayout()
	end)

	local iconCount = GF.BROWSE_LOADING_ICON_COUNT or 3
	local iconWidth = GF.BROWSE_LOADING_ICON_WIDTH or 25
	local iconHeight = GF.BROWSE_LOADING_ICON_HEIGHT or 25
	local iconGap = GF.BROWSE_LOADING_ICON_GAP or 6
	local width = (iconWidth * iconCount) + (iconGap * math.max(0, iconCount - 1))
	local animation = CreateFrame("Frame", nil, overlay)
	animation:SetSize(width, iconHeight)
	animation:SetPoint("TOP", text, "BOTTOM", 0, -(GF.BROWSE_LOADING_TEXT_GAP or 7))
	animation.icons = {}
	for index = 1, iconCount do
		local icon = animation:CreateTexture(nil, "ARTWORK")
		local atlas = (GF.BROWSE_LOADING_TEAMUP_ATLASES or {})[index]
		if not GF.UI.SetAtlasFit(icon, atlas, iconWidth, iconHeight) then
			icon:SetAtlas(atlas)
			icon:SetSize(iconWidth, iconHeight)
		end
		icon:SetPoint(
			"CENTER",
			animation,
			"LEFT",
			(iconWidth / 2) + (index - 1) * (iconWidth + iconGap),
			0
		)
		icon:SetAlpha(0)
		icon:Hide()
		animation.icons[index] = icon
	end
	animation:SetScript("OnShow", function(frame)
		frame.elapsed = 0
		refreshLoadingAnimation(frame)
	end)
	animation:SetScript("OnUpdate", function(frame, elapsed)
		frame.elapsed = ((frame.elapsed or 0) + (elapsed or 0)) % getLoadingCycleSeconds()
		refreshLoadingAnimation(frame)
	end)
	overlay.animation = animation
	overlay:Hide()
	self.blockedOverlay = overlay
	self:SyncBlockedOverlayFrameLevel()
	return overlay
end

function CP:SetCreateChannelBlocked(blocked)
	blocked = blocked == true
	if blocked then
		self:CancelEditFieldReveal()
	end
	if self._createChannelBlocked == blocked then
		return false
	end
	self._createChannelBlocked = blocked
	if blocked then
		blurCreationControls(self)
	end
	local overlay = self:EnsureBlockedOverlay()
	if overlay then
		overlay:SetShown(blocked)
	end
	if self.scroll then
		self.scroll:SetShown(not blocked)
	end
	if self.scrollBar then
		self.scrollBar:SetShown(not blocked)
	end
	return true
end

function CP:UpdateOwnershipUI()
	if self.debugCensoredPreviewMode == true then
		self:SetCreateChannelBlocked(false)
		self:UpdateManageState()
		return
	end
	local channelUnavailable = Fields.isCreateChannelBlocked()
	local visibilityChanged = self:SetCreateChannelBlocked(channelUnavailable)
	self:UpdateManageState()
	local sidebar = GF.MythicPlusCreateManagerPanel
	if visibilityChanged and sidebar ~= nil
		and type(sidebar.IsSurfaceActive) == "function"
		and sidebar:IsSurfaceActive() == true
		and type(sidebar.RefreshDungeonControlState) == "function"
	then
		sidebar:RefreshDungeonControlState()
	end
end

function CP:IsBorrowingBlizzardFields()
	local creation = Fields.getEntryCreation()
	local host = self:GetEmbedParent()
	if creation == nil or host == nil then
		return false
	end
	if Fields.hasCurrentEntryCreationLease(self) then
		return Fields.entryCreationLeaseMatchesSurface(self, creation, host)
			and creation:GetParent() == host
			and Fields.entryCreationFieldsKeepNativeParents(creation)
	end
	local containerOwned = creation:GetParent() == host
		or (BB.IsBorrowedBy and BB.IsBorrowedBy(
			creation,
			CREATE_FIELD_OWNER,
			CREATE_FIELD_CHANNEL
		))
	if not containerOwned then
		return false
	end
	return true
end

local function ownerAfterRelease(reason)
	return reason == "blizzard" and "blizzard" or nil
end

local function parkCreatePlaceholder(placeholder, parent)
	if placeholder == nil or parent == nil then
		return
	end
	placeholder:Hide()
	placeholder:SetAlpha(1)
	if placeholder.SetParent then
		placeholder:SetParent(parent)
	end
	placeholder:ClearAllPoints()
end

local function parkCreatePlaceholders(panel)
	local placeholderParent = panel and panel.formBody
	if placeholderParent == nil then
		return
	end
	parkCreatePlaceholder(panel.namePlaceholder, placeholderParent)
	parkCreatePlaceholder(panel.descPlaceholder, placeholderParent)
end

local function clearBorrowedHandles(panel, reason)
	parkCreatePlaceholders(panel)
	if panel._entryCreationLease
		and panel._entryCreationLease.released == true
	then
		panel._entryCreationLease = nil
	end
	panel._attached = false
	panel.nameEdit = nil
	panel.commentScroll = nil
	panel.voiceFrame = nil
	panel.voiceEdit = nil
	GF.entryCreationOwner = ownerAfterRelease(reason)
end

function CP:ReleaseCreateFields(reason)
	local releaseReason = reason or "tab"
	self:CancelEditFieldReveal()
	self:ApplyCreateManagerBorrowedFieldTextVisual(false)
	parkCreatePlaceholders(self)
	if self:IsBorrowingBlizzardFields()
		or Fields.hasCurrentEntryCreationLease(self)
	then
		self._attached = true
		return self:ReleaseBlizzardFields(releaseReason)
	end
	clearBorrowedHandles(self, releaseReason)
	if Fields.releaseShouldExposeNative(releaseReason) then
		self:UpdateOwnershipUI()
	end
	return false
end

function CP:ReleaseBlizzardFields(reason)
	local releaseReason = reason or "tab"
	self:CancelEditFieldReveal()
	parkCreatePlaceholders(self)
	local currentlyBorrowed = self:IsBorrowingBlizzardFields()
		or Fields.hasCurrentEntryCreationLease(self)
	if not currentlyBorrowed then
		clearBorrowedHandles(self, releaseReason)
		self:UpdateOwnershipUI()
		return false
	end

	local creation = Fields.getEntryCreation()
		or (self._entryCreationLease and self._entryCreationLease.creation)
	if creation == nil then
		clearBorrowedHandles(self, releaseReason)
		self:UpdateOwnershipUI()
		return false
	end
	local restored = Fields.restoreEntryCreationToBlizzard(
		creation,
		self,
		releaseReason
	)
	if not restored and Fields.hasCurrentEntryCreationLease(self) then
		self:UpdateOwnershipUI()
		return false
	end
	clearBorrowedHandles(self, releaseReason)
	self:UpdateCustomPlaceholders()
	self:UpdateOwnershipUI()
	return true
end

function CP:AttachBlizzardFields()
	if self.debugCensoredPreviewMode == true then
		return false
	end
	local creation = Fields.getEntryCreation()
	if creation == nil or self.parent == nil then
		return false
	end
	local embedParent = self:GetEmbedParent()
	if Fields.hasCurrentEntryCreationLease(self)
		and not Fields.entryCreationLeaseMatchesSurface(
			self,
			creation,
			embedParent
		)
	then
		self:ReleaseBlizzardFields("surface")
		if Fields.hasCurrentEntryCreationLease(self) then
			return false
		end
	end
	if Fields.isCreateChannelBlocked() then
		self:UpdateOwnershipUI()
		return false
	end
	self._suppressedWidgets = self._suppressedWidgets or {}
	local activityID = self.selection and Fields.resolveActivityID(self.selection)
	if activityID == nil or type(self.selection) ~= "table"
		or self.selection.categoryID == nil
		or not Fields.activitySelectionIsLive(
			activityID,
			self.selection.categoryID
		)
	then
		self:UpdateOwnershipUI()
		return false
	end
	if not self:SyncEntryCreationStateIfNeeded(self.selection, activityID)
		or creation.selectedActivity ~= activityID
	then
		self:UpdateOwnershipUI()
		return false
	end
	if self._attached == true and GF.entryCreationOwner == "gf" then
		if not self:IsBorrowingBlizzardFields()
			or not Fields.entryCreationFieldsKeepNativeParents(creation)
		then
			self:UpdateOwnershipUI()
			return false
		end
		Fields.parkNativeEntryShell(self, creation)
		self.nameEdit = creation.Name
		self.commentScroll = creation.Description
		self.voiceFrame = creation.VoiceChat
		self.voiceEdit = creation.VoiceChat and creation.VoiceChat.EditBox
		-- A healthy, already-visible lease is a steady ownership check, not a
		-- layout event. Reapplying points and sizes here makes the native edit
		-- boxes recalculate their text/cursor scroll on every ownership poll.
		if not Fields.widgetShown(creation) then
			self:UpdateFieldLayout()
			if not Fields.showEntryCreationForAddon(creation) then
				return false
			end
			self:UpdateOwnershipUI()
		end
		return true
	end

	Fields.captureEntryCreationProjection(creation)
	Fields.captureEntryCreationInteraction(creation)
	local embedded = false
	if BB and type(BB.AcquireEntryCreationLease) == "function" then
		self._entryCreationLease = BB.AcquireEntryCreationLease({
			owner = CREATE_FIELD_OWNER,
			channel = CREATE_FIELD_CHANNEL,
			creation = creation,
			nativeParent = LFGListFrame,
			host = embedParent,
			contextKey = Fields.createFieldLeaseContextKey(self),
		})
		embedded = self._entryCreationLease ~= nil
	else
		creation:Hide()
		embedded = Fields.embedEntryCreationContainer(creation, embedParent)
	end
	if not embedded then
		Fields.restoreEntryCreationToBlizzard(creation, self, "tab")
		return false
	end
	Fields.parkNativeEntryShell(self, creation)
	BB.CacheLayout(creation.VoiceChat)
	BB.CacheLayout(creation.VoiceChat and creation.VoiceChat.EditBox)
	self.nameEdit = creation.Name
	self.commentScroll = creation.Description
	self.voiceFrame = creation.VoiceChat
	self.voiceEdit = creation.VoiceChat and creation.VoiceChat.EditBox
	if self.nameEdit then
		Fields.suppressNativeInstructions(self.nameEdit)
	end
	if self.commentScroll and self.commentScroll.EditBox then
		Fields.suppressNativeInstructions(self.commentScroll.EditBox)
	end
	self.entryCreation = creation
	self._attached = true
	GF.entryCreationOwner = "gf"
	self:UpdateFieldLayout()
	self:UpdateRequirementLayout()
	self:InstallBlizzardFieldScripts(creation)
	if not Fields.showEntryCreationForAddon(creation) then
		Fields.restoreEntryCreationToBlizzard(creation, self, "tab")
		clearBorrowedHandles(self, "tab")
		self:UpdateOwnershipUI()
		return false
	end
	self:SyncEmbeddedFieldChrome(creation)
	self:LayoutCustomPlaceholders()
	self:UpdateCustomPlaceholders()
	self:UpdateOwnershipUI()
	return true
end

function CP:RefreshCreateFieldHandoff()
	if self.debugCensoredPreviewMode == true then
		return true
	end
	self:InstallEntryCreationHooks()
	if not Fields.isCreateFieldSurfaceActive() then
		return false
	end
	local creation, host = Fields.getEntryCreation(), self:GetEmbedParent()
	if Fields.hasCurrentEntryCreationLease(self)
		and not Fields.entryCreationLeaseMatchesSurface(self, creation, host)
	then
		self:ReleaseBlizzardFields("surface")
		if Fields.hasCurrentEntryCreationLease(self) then
			return false
		end
	end
	local channelOwnedElsewhere = Fields.nativeChannelOccupied()
	if channelOwnedElsewhere then
		if self:IsBorrowingBlizzardFields()
			or Fields.hasCurrentEntryCreationLease(self)
		then
			self:ReleaseBlizzardFields("blizzard")
		else
			self:UpdateOwnershipUI()
		end
		return false
	end
	if type(self.ResumePendingOpenMode) == "function"
		and self:ResumePendingOpenMode() == true
	then
		return true
	end
	local attached = self:AttachBlizzardFields()
	local activityID = self.selection and Fields.resolveActivityID(self.selection)
	if attached and activityID ~= nil then
		self:SyncEntryCreationStateIfNeeded(self.selection, activityID)
	end
	return attached
end

function CP:_PresentationFrameReady(frame, requireShown)
	if frame == nil then
		return false
	end
	local function readDimension(methodName)
		local method = frame[methodName]
		if type(method) ~= "function" then
			return 0
		end
		local ok, value = pcall(method, frame)
		return ok and (tonumber(value) or 0) or 0
	end
	return (requireShown ~= true or Fields.widgetShown(frame))
		and readDimension("GetWidth") > 1
		and readDimension("GetHeight") > 1
end

function CP:_PresentationFrameVisible(frame)
	if frame == nil or type(frame.IsVisible) ~= "function" then
		return Fields.widgetShown(frame)
	end
	local ok, visible = pcall(frame.IsVisible, frame)
	return ok and visible == true
end

function CP:IsPresentationReady(opts)
	opts = opts or {}
	local shellReady = self.parent ~= nil
		and self:_PresentationFrameReady(self.scroll, false)
		and self:_PresentationFrameReady(self.formBody, false)
		and self:_PresentationFrameReady(self.nameAnchor, false)
		and self:_PresentationFrameReady(self.descAnchor, false)
	if not shellReady or opts.requireActiveFields ~= true then
		return shellReady
	end
	if not Fields.isCreateFieldSurfaceActive()
		or not self:_PresentationFrameVisible(self.parent)
	then
		return false
	end
	if self.debugCensoredPreviewMode == true then
		return self.nameEdit == self._debugCensoredNameEdit
			and self.commentScroll == self._debugCensoredDescriptionFrame
			and self:_PresentationFrameReady(self.nameEdit, true)
			and self:_PresentationFrameReady(self.commentScroll, true)
	end
	if self._createChannelBlocked == true then
		return self:_PresentationFrameVisible(self.blockedOverlay)
			and self:_PresentationFrameReady(self.blockedOverlay, true)
	end
	if self._showCompleteDisabledForm == true
		and self:IsMythicPlusSidebarMode()
	then
		return self:_PresentationFrameReady(self.namePlaceholder, true)
			and self:_PresentationFrameReady(self.descPlaceholder, true)
	end
	if self._attached ~= true
		or GF.entryCreationOwner ~= "gf"
		or not self:IsBorrowingBlizzardFields()
	then
		return false
	end
	local creation = Fields.getEntryCreation()
	local activityID = self.selection and Fields.resolveActivityID(self.selection)
	return creation ~= nil
		and self.nameEdit == creation.Name
		and self.commentScroll == creation.Description
		and creation.selectedActivity == activityID
		and (self.selection == nil
			or self.selection.categoryID == nil
			or creation.selectedCategory == self.selection.categoryID)
		and self:_PresentationFrameReady(creation, true)
		and self:_PresentationFrameReady(creation.Name, true)
		and self:_PresentationFrameReady(creation.Description, true)
		and self:_PresentationFrameReady(
			creation.Description and creation.Description.EditBox,
			true
		)
end

function CP:TryAttachIfNeeded()
	return self:RefreshCreateFieldHandoff()
end

function CP:IsCreateFieldProjectionStable()
	local creation = Fields.getEntryCreation()
	local selection = self.selection
	local activityID = selection and Fields.resolveActivityID(selection)
	return self._createChannelBlocked ~= true
		and self._attached == true
		and GF.entryCreationOwner == "gf"
		and creation ~= nil and Fields.widgetShown(creation)
		and self:IsBorrowingBlizzardFields()
		and self.nameEdit == creation.Name
		and self.commentScroll == creation.Description
		and self.voiceFrame == creation.VoiceChat
		and self.voiceEdit == (creation.VoiceChat
			and creation.VoiceChat.EditBox)
		and creation.selectedActivity == activityID
		and (selection == nil or selection.categoryID == nil
			or creation.selectedCategory == selection.categoryID)
end

function CP:ActivateCreateChannel()
	if BB and type(BB.SetActiveOwner) == "function" then
		BB.SetActiveOwner(CREATE_FIELD_OWNER)
	end
	if Fields.isCreateFieldSurfaceActive() then
		return self:RefreshCreateFieldHandoff()
	end
	return false
end

function CP:StartCreateFieldOwnershipWatch()
	if self.debugCensoredPreviewMode == true then
		return
	end
	if self._createFieldOwnershipTicker ~= nil
		or C_Timer == nil or type(C_Timer.NewTicker) ~= "function"
	then
		return
	end
	local interval = GF.CREATE_FIELD_OWNERSHIP_POLL_SEC or 0.35
	self._createFieldOwnershipTicker = C_Timer.NewTicker(interval, function()
		if not Fields.isCreateFieldSurfaceActive() then
			CP:StopCreateFieldOwnershipWatch()
			return
		end
		if Fields.nativeChannelOccupied() then
			if CP._createChannelBlocked ~= true then
				CP:UpdateOwnershipUI()
			end
			return
		end
		if type(CP.ResumePendingOpenMode) == "function"
			and CP:ResumePendingOpenMode() == true
		then
			return
		end
		-- Clear the occupied projection exactly once on the availability edge.
		-- UpdateOwnershipUI is intentionally skipped by healthy steady ticks
		-- because it also recalculates the complete form layout.
		if CP._createChannelBlocked == true then
			CP:UpdateOwnershipUI()
		end
		if CP:IsCreateFieldProjectionStable() then
			return
		end
		CP:AttachBlizzardFields()
	end)
end

function CP:StopCreateFieldOwnershipWatch()
	local ticker = self._createFieldOwnershipTicker
	self._createFieldOwnershipTicker = nil
	if ticker and type(ticker.Cancel) == "function" then
		ticker:Cancel()
	end
end

function CP:InstallEntryCreationHooks()
	if self._ecHooksInstalled == true then
		return true
	end
	local finder, nativePanel = LFGListFrame, Fields.getEntryCreation()
	if finder == nil or nativePanel == nil then
		return false
	end
	local function nativeFinderIsVisible()
		if type(finder.IsVisible) ~= "function" then
			return true
		end
		local ok, visible = pcall(finder.IsVisible, finder)
		return not ok or visible == true
	end

	local function suspendHiddenNativeLeadershipDispatch()
		if CP._nativeLeadershipEventSuspended == true then
			return true
		end
		if nativeFinderIsVisible()
			or type(finder.UnregisterEvent) ~= "function"
		then
			return false
		end
		local ok = pcall(
			finder.UnregisterEvent,
			finder,
			"PARTY_LEADER_CHANGED"
		)
		if ok then
			CP._nativeLeadershipEventSuspended = true
		end
		return ok
	end

	local function resumeNativeLeadershipDispatch()
		if CP._nativeLeadershipEventSuspended ~= true then
			return true
		end
		if type(finder.RegisterEvent) ~= "function" then
			return false
		end
		local ok = pcall(
			finder.RegisterEvent,
			finder,
			"PARTY_LEADER_CHANGED"
		)
		if ok then
			CP._nativeLeadershipEventSuspended = nil
		end
		return ok
	end

	local function yieldFieldsToNativeUI()
		if BB ~= nil and type(BB.SetActiveOwner) == "function" then
			BB.SetActiveOwner("blizzard")
		end
		if Fields.isCreateFieldSurfaceActive() then
			CP:ReleaseCreateFields("blizzard")
		end
	end

	local function reclaimFieldsForAddon()
		if not Fields.isCreateFieldSurfaceActive() then
			return
		end
		if BB ~= nil and type(BB.SetActiveOwner) == "function" then
			BB.SetActiveOwner(CREATE_FIELD_OWNER)
		end
		CP:RefreshCreateFieldHandoff()
		CP:SyncEmbeddedFieldChrome()
	end

	local function reapplyGroupFinderReadOnlyGate()
		if CP._protectedFieldsFormEnabled == false
			and CP._attached == true
			and CP:IsBorrowingBlizzardFields()
		then
			Fields.applyProtectedCreationGate(nativePanel, false)
		end
	end

	Fields.initializeDescriptionCursorState(nativePanel)
	if type(nativePanel.HookScript) == "function" then
		nativePanel:HookScript("OnShow", function()
			if nativePanel._gfShowingBorrowedEntryCreation == true then
				reapplyGroupFinderReadOnlyGate()
				return
			end
			if nativePanel._gfRestoringBorrowedEntryCreation == true then
				return
			end
			Fields.initializeDescriptionCursorState(nativePanel)
			yieldFieldsToNativeUI()
		end)
	end

	if type(hooksecurefunc) == "function"
		and type(LFGListFrame_SetActivePanel) == "function"
	then
		hooksecurefunc("LFGListFrame_SetActivePanel", function(frame, selectedPanel)
			if Fields.isCreateFieldSurfaceActive() then
				CP:UpdateOwnershipUI()
				if frame == nil or selectedPanel ~= frame.EntryCreation then
					CP:RefreshCreateFieldHandoff()
				end
			end
		end)
	end

	if type(finder.HookScript) == "function" then
		finder:HookScript("OnEvent", function()
			-- Blizzard registers LFG events on the root and directly dispatches
			-- the selected panel's original handler.  This root post-hook runs
			-- after that dispatch and reapplies only GF's disabling gate.
			reapplyGroupFinderReadOnlyGate()
		end)
		finder:HookScript("OnHide", function()
			-- Blizzard dispatches PARTY_LEADER_CHANGED to a hidden
			-- ApplicationViewer.  During the ownership transition its
			-- GetApplicants() provider may be nil, while Blizzard 12.1 sorts
			-- that value without a guard.  The native viewer refreshes on its
			-- next OnShow, so defer only this hidden-panel event.
			suspendHiddenNativeLeadershipDispatch()
			if not Fields.isCreateFieldSurfaceActive() then
				return
			end
			local timer = C_Timer and C_Timer.After
			if type(timer) == "function" then
				local showGeneration = CP._showGeneration
				timer(0, function()
					if CP._showGeneration == showGeneration then
						reclaimFieldsForAddon()
					end
				end)
			else
				reclaimFieldsForAddon()
			end
		end)
		finder:HookScript("OnShow", function()
			resumeNativeLeadershipDispatch()
			Fields.settleUnselectedEntryPage()
			if Fields.isCreateFieldSurfaceActive() then
				CP:RefreshCreateFieldHandoff()
			end
		end)
	end

	local viewer = finder.ApplicationViewer
	local editButton = viewer and viewer.EditButton
	if editButton ~= nil and type(editButton.HookScript) == "function"
		and editButton._gfReleaseCreateFieldsBeforeNativeEdit ~= true
	then
		editButton:HookScript("OnMouseDown", yieldFieldsToNativeUI)
		editButton._gfReleaseCreateFieldsBeforeNativeEdit = true
	end

	Fields.precacheEntryCreationLayouts()
	suspendHiddenNativeLeadershipDispatch()
	self._ecHooksInstalled = true
	return true
end

local function safeUpdateEntryCreationValidState(ec)
	local updater = LFGListEntryCreation_UpdateValidState
	if ec == nil or ec.selectedActivity == nil or type(updater) ~= "function" then
		return false
	end
	updater(ec)
	return true
end

function CP:InstallBlizzardFieldScripts(ec)
	if ec == nil or self._fieldScriptsInstalled == true then
		return false
	end
	local nameBox = ec.Name
	if nameBox ~= nil then
		GF.UI.TrackEditBox(nameBox, "GameFontHighlightSmall")
		nameBox:HookScript("OnTextChanged", function(box)
			Fields.syncEditInstructions(box)
			safeUpdateEntryCreationValidState(ec)
			CP:UpdateCustomPlaceholders()
			CP:UpdateManageState()
		end)
	end

	local descriptionBox = ec.Description and ec.Description.EditBox
	if descriptionBox ~= nil then
		Fields.initializeDescriptionCursorState(ec)
		GF.UI.TrackEditBox(descriptionBox, "GameFontHighlightSmall")
		descriptionBox:HookScript("OnTextChanged", function(box, userTyped)
			Fields.safeDescriptionTextChanged(box, userTyped)
			CP:UpdateManageState()
		end)
	end
	self._fieldScriptsInstalled = true
	return true
end

local function projectSelectionToEntryCreation(panel, node, activityID)
	local ec = Fields.getEntryCreation()
	if ec == nil or type(node) ~= "table" or activityID == nil
		or node.categoryID == nil
	then
		return false
	end
	if node._editOnlyActiveListing ~= true
		and type(LFGListEntryCreation_SetBaseFilters) == "function"
	then
		local preferred = node.preferredFilters
			or Enum.LFGListFilter.PvE
		LFGListEntryCreation_SetBaseFilters(ec, preferred)
	end
	local groupID = node.groupID
	if groupID == nil then
		local activity = NativeCreation:GetActivityInfoTable(
			activityID,
			node.questID
		)
		groupID = activity and activity.groupFinderActivityGroupID or nil
	end
	ec.selectedActivity = activityID
	ec.selectedCategory = node.categoryID
	ec.selectedGroup = groupID
	ec.selectedFilters = node.filters or 0
	local style = panel.generalPlaystyle
	if style ~= Enum.LFGEntryGeneralPlaystyle.None then
		ec.generalPlaystyle = style
	end
	return true
end

function CP:SyncEntryCreationState(node, activityID)
	return projectSelectionToEntryCreation(self, node, activityID)
end

function CP:SyncEntryCreationStateIfNeeded(node, activityID)
	if self.debugCensoredPreviewMode == true then
		return false
	end
	if type(node) ~= "table" or activityID == nil
		or not Fields.isCreateFieldSurfaceActive() or Fields.isCreateChannelBlocked()
	then
		return false
	end
	local creation = Fields.getEntryCreation()
	local sameSelection = self._syncedActivityID == activityID
		and self._syncedNodeKey == node.key
		and creation ~= nil
		and creation.selectedActivity == activityID
		and creation.selectedCategory == node.categoryID
	if sameSelection then
		return true
	end
	local projected = projectSelectionToEntryCreation(self, node, activityID)
	if projected then
		self._syncedActivityID, self._syncedNodeKey = activityID, node.key
	end
	return projected
end

local QUEST_CREATE_CONTEXT_FIELDS = {
	"baseFilters",
	"selectedActivity",
	"selectedCategory",
	"selectedGroup",
	"selectedFilters",
	"selectedPlaystyle",
	"generalPlaystyle",
}

local function captureQuestCreateContext(creation)
	local state = {}
	for _, field in ipairs(QUEST_CREATE_CONTEXT_FIELDS) do
		state[field] = creation[field]
	end
	return state
end

local function restoreQuestCreateContext(creation, state)
	if creation == nil or type(state) ~= "table" then
		return false
	end
	for _, field in ipairs(QUEST_CREATE_CONTEXT_FIELDS) do
		creation[field] = state[field]
	end
	if creation.selectedActivity ~= nil then
		pcall(safeUpdateEntryCreationValidState, creation)
	end
	return true
end

function CP:CanAcquireQuestRecruitmentFieldLease()
	return not Fields.nativeChannelOccupied()
		and not self:IsBorrowingBlizzardFields()
end

function CP:CanAcquireQuestRelistFieldLease()
	-- Relisting is allowed to project a short-lived quest context through the
	-- fields already borrowed by this CreatePanel. Fields.nativeChannelOccupied still
	-- rejects Blizzard's visible creation UI and every foreign field owner.
	return not Fields.nativeChannelOccupied()
end

function CP:AcquireQuestRecruitmentFieldLeaseInternal(resolved, relist)
	local canAcquire
	if relist == true then
		canAcquire = self:CanAcquireQuestRelistFieldLease()
	else
		canAcquire = self:CanAcquireQuestRecruitmentFieldLease()
	end
	if type(resolved) ~= "table" or type(resolved.selection) ~= "table"
		or resolved.activityID == nil or resolved.categoryID == nil
		or not canAcquire
	then
		return nil
	end
	if type(GF.EnsureBlizzardAddons) == "function" then
		GF.EnsureBlizzardAddons()
	end
	local creation = Fields.getEntryCreation()
	if creation == nil
		or not Fields.activitySelectionIsLive(
			resolved.activityID,
			resolved.categoryID,
			resolved.questID
		)
	then
		return nil
	end
	if BB and type(BB.AcquireEntryCreationContextLease) == "function" then
		return BB.AcquireEntryCreationContextLease({
			owner = CREATE_FIELD_OWNER,
			channel = relist and "quest-relist" or "quest-create",
			creation = creation,
			entryLease = relist and self._entryCreationLease or nil,
			fields = QUEST_CREATE_CONTEXT_FIELDS,
			apply = function()
				if not projectSelectionToEntryCreation(
					self,
					resolved.selection,
					resolved.activityID
				) then
					return false
				end
				creation.selectedPlaystyle = nil
				local playstyles = Enum and Enum.LFGEntryGeneralPlaystyle
				creation.generalPlaystyle = playstyles and playstyles.None or 0
				local callOK, cleared = pcall(
					NativeCreation.ClearCreationTextFields,
					NativeCreation
				)
				return callOK and cleared == true
			end,
		})
	end
	local state = captureQuestCreateContext(creation)
	if not projectSelectionToEntryCreation(
		self,
		resolved.selection,
		resolved.activityID
	) then
		restoreQuestCreateContext(creation, state)
		return nil
	end
	creation.selectedPlaystyle = nil
	local playstyles = Enum and Enum.LFGEntryGeneralPlaystyle
	creation.generalPlaystyle = playstyles and playstyles.None or 0
	local clearCallOK, cleared = pcall(
		NativeCreation.ClearCreationTextFields,
		NativeCreation
	)
	cleared = clearCallOK and cleared == true
	if not cleared then
		restoreQuestCreateContext(creation, state)
		return nil
	end
	return {
		creation = creation,
		state = state,
	}
end

function CP:AcquireQuestRecruitmentFieldLease(resolved)
	return self:AcquireQuestRecruitmentFieldLeaseInternal(resolved, false)
end

function CP:AcquireQuestRelistFieldLease(resolved)
	return self:AcquireQuestRecruitmentFieldLeaseInternal(resolved, true)
end

function CP:ReleaseQuestRecruitmentFieldLease(lease)
	if type(lease) ~= "table" or lease.released == true then
		return false
	end
	if lease.kind == "entry-creation-context" and BB
		and type(BB.ReleaseEntryCreationContextLease) == "function"
	then
		return BB.ReleaseEntryCreationContextLease(lease, {
			validate = function(creation)
				if creation.selectedActivity ~= nil then
					pcall(safeUpdateEntryCreationValidState, creation)
				end
			end,
		})
	end
	lease.released = true
	return restoreQuestCreateContext(lease.creation, lease.state)
end

GF.CreatePanelLifecycle.Install(CP, {
	BB = BB,
	NativeCreation = NativeCreation,
	FormPresenter = FormPresenter,
	DEFAULT_PLAYSTYLE = DEFAULT_PLAYSTYLE,
	DEFAULT_REQUIRED_DUNGEON_SCORE = DEFAULT_REQUIRED_DUNGEON_SCORE,
	PLAYSTYLE_OPTIONS = PLAYSTYLE_OPTIONS,
	playstyleText = playstyleText,
	selectedPlaystyleText = selectedPlaystyleText,
	trimName = trimName,
	NATIVE_FIELD_SIZE = NATIVE_FIELD_SIZE,
	FIELD_EDGE_PAD = FIELD_EDGE_PAD,
	REQ_EDIT_W = REQ_EDIT_W,
	REQ_EDIT_H = REQ_EDIT_H,
	FIELD_GAP = FIELD_GAP,
	LABEL_FIELD_GAP = LABEL_FIELD_GAP,
	DESC_FIELD_GAP = DESC_FIELD_GAP,
	CREATE_PAD = CREATE_PAD,
	FORM_LEFT_INSET = FORM_LEFT_INSET,
	CREATE_FORM_INSET_X = CREATE_FORM_INSET_X,
	CREATE_FORM_INSET_TOP = CREATE_FORM_INSET_TOP,
	CREATE_MANAGER_DISABLED_VISUAL = CREATE_MANAGER_DISABLED_VISUAL,
	MPLUS_LFG_SIDEBAR_CONTROL_W = MPLUS_LFG_SIDEBAR_CONTROL_W,
	CREATE_FORM_INPUT_H = CREATE_FORM_INPUT_H,
	CREATE_FORM_DESC_ATLAS_PAD_Y = CREATE_FORM_DESC_ATLAS_PAD_Y,
	CREATE_FORM_DESC_ATLAS_H = CREATE_FORM_DESC_ATLAS_H,
	BUTTON_BAR_H = BUTTON_BAR_H,
	LIST_BTN_BOTTOM = LIST_BTN_BOTTOM,
	LIST_BTN_W = LIST_BTN_W,
	LIST_BTN_GAP = LIST_BTN_GAP,
	DROPDOWN_H = DROPDOWN_H,
	DROPDOWN_LEFT_NUDGE = DROPDOWN_LEFT_NUDGE,
	REQ_FIELD_LEFT_NUDGE = REQ_FIELD_LEFT_NUDGE,
	CREATE_CHECK_SIZE = CREATE_CHECK_SIZE,
	CREATE_CHECK_LABEL_GAP = CREATE_CHECK_LABEL_GAP,
	CREATE_FIELD_OWNER = CREATE_FIELD_OWNER,
	getFactionRestrictionLabel = getFactionRestrictionLabel,
	getFactionRestrictionTip = getFactionRestrictionTip,
	getDefaultRequiredItemLevel = getDefaultRequiredItemLevel,
	clampRequiredItemLevel = clampRequiredItemLevel,
	showCreateOptionTooltip = showCreateOptionTooltip,
	setCheckHitRectToLabel = Fields.setCheckHitRectToLabel,
	applyProtectedCreationGate = Fields.applyProtectedCreationGate,
	updateCreateInputBox = Fields.updateCreateInputBox,
	updateCreateInputAtlasFrame = Fields.updateCreateInputAtlasFrame,
	updateCreateDescriptionAtlasFrame = Fields.updateCreateDescriptionAtlasFrame,
	styleCreateInputAtlasFrame = Fields.styleCreateInputAtlasFrame,
	styleCreateDescriptionAtlasFrame = Fields.styleCreateDescriptionAtlasFrame,
	updateBorrowedDescriptionAtlas = Fields.updateBorrowedDescriptionAtlas,
	styleCreateInputBox = Fields.styleCreateInputBox,
	applyCreateTitleTextStyle = Fields.applyCreateTitleTextStyle,
	getCreateDrawerFooter = Fields.getCreateDrawerFooter,
	resolveActivityID = Fields.resolveActivityID,
	getEntryCreation = Fields.getEntryCreation,
	isCreateFieldSurfaceActive = Fields.isCreateFieldSurfaceActive,
	isCreateChannelBlocked = Fields.isCreateChannelBlocked,
	updateBorrowedVoiceAtlas = Fields.updateBorrowedVoiceAtlas,
	blurCreationControls = blurCreationControls,
})
