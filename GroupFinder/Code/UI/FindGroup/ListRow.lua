local _, GF = ...

local APPLICATION_TIMEOUT_SECONDS = 5 * 60
local APPLICATION_PENDING_TEXT_COLOR = { r = 0.12, g = 1, b = 0.25, a = 1 }
local APPLICATION_DECLINED_TEXT_COLOR = { r = 1, g = 0.18, b = 0.12, a = 1 }
local APPLICATION_CANCELLED_TEXT_COLOR = { r = 0.55, g = 0.55, b = 0.55, a = 1 }
local APPLICATION_ALERT_ICON_TEXTURE = "Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew.blp"
local APPLICATION_CANCEL_BUTTON_SIZE = 24
local APPLICATION_CANCEL_BUTTON_DISPLAY_SIZE = APPLICATION_CANCEL_BUTTON_SIZE
local APPLICATION_CANCEL_BUTTON_ICON_SIZE = 16
local APPLICATION_CANCEL_BUTTON_GAP = 4
local APPLICATION_CANCEL_BUTTON_ATLAS = "UI-LFG-DeclineMark"
local BUTTON_VISUAL_STATE = GF.BUTTON_VISUAL_STATE
local APPLICATION_STATUS_ICON_SIZE = 16
local APPLICATION_STATUS_ICON_GAP = 3
local APPLICATION_STATUS_TEXT_OFFSET_X = -6
local APPLICATION_PENDING_SPINNER_SIZE = 18
local lastTooltipResultID
local cancelHoverTooltipHide

local function trySetTextureAtlas(texture, atlas)
	if not texture or not texture.SetAtlas or not atlas then
		return false
	end
	local ok = pcall(texture.SetAtlas, texture, atlas)
	return ok == true
end

local function CreateApplicationPendingSpinner(parent)
	if GF.UI and GF.UI.CreatePendingSpinner then
		return GF.UI.CreatePendingSpinner(parent, APPLICATION_PENDING_SPINNER_SIZE)
	end
end

local function StopApplicationPendingSpinner(spinner)
	if GF.UI and GF.UI.StopPendingSpinner then
		GF.UI.StopPendingSpinner(spinner)
	end
end

local function StartApplicationPendingSpinner(spinner)
	if GF.UI and GF.UI.StartPendingSpinner then
		GF.UI.StartPendingSpinner(spinner, APPLICATION_PENDING_SPINNER_SIZE)
	end
end

local function AnchorApplicationCancelButtonIcon(button, x, y)
	local icon = button and button._gfCancelIcon
	if not icon then
		return
	end
	icon:ClearAllPoints()
	icon:SetPoint("CENTER", button, "CENTER", x or 0, y or 0)
end

local function SetApplicationCancelButtonTexture(button, state)
	local bg = button and button._gfCancelBg
	if not bg then
		return
	end
	GF.UI.SetCommonButtonTextureState(
		bg,
		state or BUTTON_VISUAL_STATE.NORMAL,
		"square")
end

local function UpdateApplicationCancelButtonState(button)
	if not button then
		return
	end
	local enabled = not button.IsEnabled or button:IsEnabled()
	local state = BUTTON_VISUAL_STATE.NORMAL
	if not enabled then
		state = BUTTON_VISUAL_STATE.DISABLED
	elseif button._gfCancelPressed then
		state = BUTTON_VISUAL_STATE.PRESSED
	elseif enabled and button._gfCancelHovered then
		state = BUTTON_VISUAL_STATE.HOVER
	end
	local visual = GF.UI.GetCommonButtonVisual(state)
	SetApplicationCancelButtonTexture(button, state)
	if button._gfCancelBg then
		if button._gfCancelBg.SetDesaturated then
			button._gfCancelBg:SetDesaturated(visual.desaturated == true)
		end
		button._gfCancelBg:SetVertexColor(
			visual.textureColor[1],
			visual.textureColor[2],
			visual.textureColor[3],
			visual.textureColor[4])
	end
	if button._gfCancelIcon then
		button._gfCancelIcon:SetVertexColor(
			visual.iconColor[1],
			visual.iconColor[2],
			visual.iconColor[3],
			visual.iconColor[4])
	end
end

local function CreateApplicationCancelButton(parent)
	local button = CreateFrame("Button", nil, parent)
	button:SetSize(APPLICATION_CANCEL_BUTTON_SIZE, APPLICATION_CANCEL_BUTTON_SIZE)
	button:SetFrameLevel((parent:GetFrameLevel() or 1) + 4)
	button:SetPoint("CENTER", parent, "CENTER", 0, 0)
	button:RegisterForClicks("LeftButtonUp")
	button:SetText("")
	button:Hide()
	local label = button.Text or (button.GetFontString and button:GetFontString())
	if label then
		label:SetText("")
		label:Hide()
	end
	local bg = button:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints(button)
	bg:SetVertexColor(1, 1, 1, 1)
	bg:SetAlpha(1)
	bg:Show()
	button._gfCancelBg = bg
	SetApplicationCancelButtonTexture(button, BUTTON_VISUAL_STATE.NORMAL)

	local icon = button:CreateTexture(nil, "OVERLAY", nil, 2)
	icon:SetSize(APPLICATION_CANCEL_BUTTON_ICON_SIZE, APPLICATION_CANCEL_BUTTON_ICON_SIZE)
	icon:SetVertexColor(1, 1, 1, 1)
	if not trySetTextureAtlas(icon, APPLICATION_CANCEL_BUTTON_ATLAS) then
		icon:SetTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
		icon:SetTexCoord(0, 1, 0, 1)
	end
	button._gfCancelIcon = icon
	AnchorApplicationCancelButtonIcon(button, 0, 0)
	button:SetScript("OnEnter", function(self)
		self._gfCancelHovered = true
		UpdateApplicationCancelButtonState(self)
		if GF.ListRow and GF.ListRow.ClearHoverTooltip then
			GF.ListRow:ClearHoverTooltip()
		end
		local L = GF.L or {}
		if GameTooltip then
			GameTooltip:Hide()
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(L.APPLY_CANCEL_APPLICATION or LFG_LIST_CANCEL_APPLICATION or "取消申请")
			GameTooltip:Show()
		end
	end)
	button:SetScript("OnLeave", function(self)
		self._gfCancelHovered = nil
		self._gfCancelPressed = nil
		UpdateApplicationCancelButtonState(self)
		AnchorApplicationCancelButtonIcon(self, 0, 0)
		if GameTooltip and GameTooltip.GetOwner then
			if GameTooltip:GetOwner() == self then
				GameTooltip:Hide()
			end
		elseif GameTooltip_Hide then
			GameTooltip_Hide()
		end
	end)
	button:SetScript("OnMouseDown", function(self, mouseButton)
		if mouseButton == "LeftButton" then
			self._gfCancelPressed = true
			UpdateApplicationCancelButtonState(self)
			local offset = GF.UI.GetCommonButtonVisual(
				BUTTON_VISUAL_STATE.PRESSED).textOffset
			AnchorApplicationCancelButtonIcon(self, offset[1], offset[2])
		end
	end)
	button:SetScript("OnMouseUp", function(self)
		self._gfCancelPressed = nil
		UpdateApplicationCancelButtonState(self)
		AnchorApplicationCancelButtonIcon(self, 0, 0)
	end)
	button:SetScript("OnEnable", UpdateApplicationCancelButtonState)
	button:SetScript("OnDisable", UpdateApplicationCancelButtonState)
	button:SetScript("OnClick", function(self)
		local row = self._gfRow
		local resultID = tonumber(self.resultID or (row and row.resultID))
		if not resultID then
			return
		end
		local ok, reason
		if GF.Apply and GF.Apply.CancelApplication then
			ok, reason = GF.Apply:CancelApplication(resultID)
		elseif C_LFGList and C_LFGList.CancelApplication then
			ok, reason = pcall(C_LFGList.CancelApplication, resultID)
		end
		if ok == false and reason and GF.ShowWarningMessage then
			GF.ShowWarningMessage(tostring(reason))
		end
	end)
	UpdateApplicationCancelButtonState(button)
	return button
end


GF.ListRow = {}
local LR = GF.ListRow

-- [ListRow] 2/5 ListRow 模块与固定行视觉
local ROW_BACKGROUND_FALLBACK_TEXTURE = GF.ROW_BACKGROUND_FALLBACK_TEXTURE
local ROW_BACKGROUND_ALPHA = GF.BROWSE_ROW_BACKGROUND_ALPHA or 0.92
local ROW_BACKGROUND_FADE_SECONDS = GF.BROWSE_ROW_BACKGROUND_FADE_SECONDS or 0.16
local ROW_HOVER_COLOR = GF.BROWSE_ROW_HOVER_COLOR or { 1, 0.74, 0.18, 0.13 }
local ROW_HOVER_RED_COLOR = GF.BROWSE_ROW_HOVER_RED_COLOR or { 1, 0.12, 0.08, 0.18 }
local ROW_HOVER_BLUE_COLOR = GF.BROWSE_ROW_HOVER_BLUE_COLOR or { 0.35, 0.75, 1, 0.16 }
local ROW_HOVER_GREY_COLOR = GF.BROWSE_ROW_HOVER_GREY_COLOR or { 0.65, 0.65, 0.65, 0.18 }
local ROW_SELECTED_ALPHA = GF.BROWSE_ROW_SELECTED_ALPHA or 1
local TYPE_ICON_GAP = 3
local TYPE_ICON_TEXTURE = {
	blacklist = GF.BLACKLIST_ICON_TEXTURE,
	leaver = GF.LEAVER_ICON_TEXTURE,
}
for socialType, texture in pairs(GF.SOCIAL_TYPE_ICON_TEXTURE or {}) do
	TYPE_ICON_TEXTURE[socialType] = texture
end
local TYPE_TEXT_COLOR = {
	blacklist = { r = 1, g = 0.08, b = 0.05 },
	leaver = { r = 1, g = 0.08, b = 0.05 },
}
for socialType in pairs(GF.SOCIAL_TYPE_ICON_TEXTURE or {}) do
	TYPE_TEXT_COLOR[socialType] = (GF.GetSocialTypeTextColor and GF.GetSocialTypeTextColor(socialType))
		or GF.SOCIAL_TEXT_COLOR
end
local SOCIAL_SEARCH_RESULT_LABEL_FALLBACK = GF.SOCIAL_SEARCH_RESULT_LABEL_FALLBACK
local TYPE_ICON_ALIGNMENT_TYPES = {
	"blacklist",
	"leaver",
	GF.SOCIAL_TYPE_BNET,
	GF.SOCIAL_TYPE_GUILD,
	GF.SOCIAL_TYPE_FRIEND,
	GF.SOCIAL_TYPE_LAONONG,
	GF.RESULT_TYPE_CURRENT_GROUP,
}
local TYPE_LABEL_SLOT_WIDTH_CACHE = {}

local function getTypeIconSize()
	return (GF.GetNonRoleListIconSize and GF.GetNonRoleListIconSize()) or GF.NON_ROLE_ICON_SIZE or 18
end

function LR:ApplyDivider(row)
	if not row or not row.divider then
		return
	end
	row.divider:Hide()
end

local ROW_SELECTED_COLOR =
	GF.BROWSE_ROW_SELECTED_COLOR or { 1, 0.9, 0.08, 0.82 }
local ROW_SELECTED_BLUE_COLOR = { 0.18, 0.86, 1, 0.78 }
local ROW_SELECTED_RED_COLOR = { 1, 0.05, 0.03, 0.86 }
local ROW_SELECTED_GREY_COLOR = { 0.82, 0.82, 0.82, 0.68 }
local function getAppLineY(row)
	return 0
end
local VOICE_W = 16
local LC = GF.ListColumns

local function entryHasVoice(voiceChat)
	return (voiceChat or "") ~= ""
end

local function isSecretLfgText(text)
	if GF.Result and GF.Result.IsSecretLfgText then
		return GF.Result:IsSecretLfgText(text)
	end
	if type(issecretvalue) ~= "function" then
		return false
	end
	local ok, secret = pcall(issecretvalue, text)
	return ok and secret == true
end

local function hasRenderableListingComment(comment)
	if GF.Result and GF.Result.HasRenderableListingComment then
		return GF.Result:HasRenderableListingComment(comment)
	end
	if isSecretLfgText(comment) then
		return true
	end
	return comment ~= nil and comment ~= ""
end

local function clearCommentText(fontString)
	if not fontString then
		return
	end
	if fontString.ClearText then
		fontString:ClearText()
	else
		fontString:SetText("")
	end
end

local function setRowEllipsis(fontString, text, width)
	if not fontString then
		return
	end
	if isSecretLfgText(text) then
		fontString:SetWordWrap(false)
		fontString:SetMaxLines(1)
		if width and width > 0 then
			fontString:SetWidth(width)
		end
		fontString:SetText(text)
	elseif GF.UI and GF.UI.SetEllipsisText then
		GF.UI.SetEllipsisText(fontString, text, width)
	else
		fontString:SetText(text or "")
	end
end

local function isRenderedBadListingText(text)
	if isSecretLfgText(text) then
		return true
	end
	if text == nil or text == "" then
		return true
	end
	local textType = type(text)
	if textType ~= "string" and textType ~= "number" then
		return true
	end
	if GF.Result and GF.Result.IsRenderedUnreadableLfgText and GF.Result:IsRenderedUnreadableLfgText(text) then
		return true
	end
	text = tostring(text)
	text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
	text = text:gsub("|r", "")
	if strtrim then
		text = strtrim(text)
	end
	if text == "" then
		return true
	end
	if text == "|Kr0|k" or text == "?" or text == "未知目标" or text == "未知目標" or text == "Unknown Target" then
		return true
	end
	if _G.UNKNOWNOBJECT and text == _G.UNKNOWNOBJECT then
		return true
	end
	if _G.UNKNOWNBEING and text == _G.UNKNOWNBEING then
		return true
	end
	return false
end

local function rowHasRenderedBadListingText(row)
	if not row then
		return false
	end
	if row.title and isRenderedBadListingText(row.title:GetText()) then
		return true
	end
	if row.title and row.resultID and GF.Result and GF.Result.IsLiveSearchResultInfoAuthoritative then
		local text = row.title:GetText()
		if type(text) == "string" and text:find("|K", 1, true)
			and not GF.Result:IsLiveSearchResultInfoAuthoritative(row.resultID) then
			return true
		end
	end
	return false
end

local function dropRenderedBadResult(panel, resultID)
	if not panel or not resultID then
		return
	end
	panel._dropRenderedBadResultPending = panel._dropRenderedBadResultPending or {}
	if panel._dropRenderedBadResultPending[resultID] then
		return
	end
	panel._dropRenderedBadResultPending[resultID] = true
	local function drop()
		if panel._dropRenderedBadResultPending then
			panel._dropRenderedBadResultPending[resultID] = nil
		end
		if panel.DropFrozenResult and panel:DropFrozenResult(resultID) then
			if panel.RefreshList then
				panel:RefreshList({ preserveScroll = true })
			end
		end
	end
	if C_Timer and C_Timer.After then
		C_Timer.After(0, drop)
	else
		drop()
	end
end

-- [ListRow] 3/5 九列布局与单元格绘制（依赖 ListColumns）

local function resolveBrowseLayout(rowW)
	local tab = GF.FindGroupTab
	local selection = tab and tab.GetSelection and tab:GetSelection() or nil
	local profile = LC:GetBrowseProfile(selection)
	return LC:ResolveLayout(rowW, profile)
end

local function rowCol(row, colID)
	local columns = row and row._columnLayout and row._columnLayout.byId
	return columns and columns[colID] or nil
end

local COLUMN_JUSTIFY = { CENTER = true, RIGHT = true }

local function applyColumnJustify(fontString, col)
	if fontString then
		local requested = col and col.align
		fontString:SetJustifyH(COLUMN_JUSTIFY[requested] and requested or "LEFT")
	end
end

local BROWSE_TEXT_INSET_COLS = { title = true, activity = true, leader = true, comment = true }

local function getTextCellInset(colID)
	if BROWSE_TEXT_INSET_COLS[colID] then
		return GF.BROWSE_TEXT_CELL_INSET_X or 0
	end
	return 0
end

local function getTextCellWidth(row, colID, col)
	local cached = row and row._colWidths and row._colWidths[colID]
	if cached then
		return cached
	end
	local column = col or rowCol(row, colID)
	if not column then
		return 1
	end
	return math.max(1, (column.width or 1) - (2 * getTextCellInset(colID)))
end

local function paintColText(row, colID, fontString, text)
	local col = rowCol(row, colID)
	if not (col and fontString) then
		return false
	end
	setRowEllipsis(fontString, text, getTextCellWidth(row, colID, col))
	applyColumnJustify(fontString, col)
	return true
end

local layoutCommentCell

local function hideComment(row)
	if row and row.comment then
		clearCommentText(row.comment)
		row.comment:Hide()
	end
end

local function displayComment(row, text, width, color)
	if not (row and row.comment and width and hasRenderableListingComment(text)) then
		hideComment(row)
		return false
	end
	clearCommentText(row.comment)
	setRowEllipsis(row.comment, text, width)
	local tint = color or { r = 1, g = 1, b = 1 }
	row.comment:SetTextColor(tint.r, tint.g, tint.b)
	row.comment:Show()
	return true
end

local function relayoutCommentText(row, dc)
	local width = rowCol(row, "comment") and layoutCommentCell(row) or nil
	local tint = dc
	if not tint and row and row._isDelisted then
		tint = LFG_LIST_DELISTED_FONT_COLOR or GRAY
	end
	displayComment(row, row and row._commentText, width, tint)
end

local function refreshCommentCell(row, comment, dc)
	local width = rowCol(row, "comment") and layoutCommentCell(row) or nil
	displayComment(row, comment, width, dc)
end

local function placeTextCell(row, fontString, colID, y)
	local col = rowCol(row, colID)
	if not (col and fontString) then
		if fontString then
			fontString:Hide()
		end
		if row and row._colWidths then
			row._colWidths[colID] = nil
		end
		return nil
	end
	row._colWidths = row._colWidths or {}
	local inset = getTextCellInset(colID)
	local width = math.max(1, col.width - 2 * inset)
	fontString:ClearAllPoints()
	fontString:SetPoint("LEFT", row, "LEFT", col.x + inset, tonumber(y) or 0)
	fontString:SetWidth(width)
	applyColumnJustify(fontString, col)
	fontString:Show()
	row._colWidths[colID] = width
	return width
end

layoutCommentCell = function(row, y)
	local col = rowCol(row, "comment")
	if not (col and row and row.comment) then
		hideComment(row)
		if row.voiceIcon then
			row.voiceIcon:Hide()
		end
		return nil
	end
	row._colWidths = row._colWidths or {}
	local inset = getTextCellInset("comment")
	local left = col.x + inset
	local width = col.width - (row._appReservedW or 0) - 2 * inset
	local lineY = tonumber(y) or 0
	local voice = row.voiceIcon
	if voice and row._hasVoice then
		voice:ClearAllPoints()
		voice:SetPoint("LEFT", row, "LEFT", left, lineY)
		voice:Show()
		row.comment:ClearAllPoints()
		row.comment:SetPoint("LEFT", voice, "RIGHT", 2, 0)
		width = width - VOICE_W - 2
	else
		if voice then
			voice:Hide()
		end
		row.comment:ClearAllPoints()
		row.comment:SetPoint("LEFT", row, "LEFT", left, lineY)
	end
	width = math.max(1, width)
	row.comment:SetWidth(width)
	row.comment:Show()
	row._colWidths.comment = width
	return width
end

function LR:LayoutRow(row, layoutW)
	if not row or not row.title then
		return
	end
	local requestedWidth = tonumber(layoutW) or row:GetWidth() or 0
	local rowW = requestedWidth > 0 and requestedWidth or 400
	row._columnLayout = resolveBrowseLayout(rowW)
	local textCells = {
		{ row.title, "title" },
		{ row.activity, "activity" },
		{ row.typeText, "type" },
		{ row.metaLeader, "leader" },
		{ row.metaIL, "ilvl" },
		{ row.metaScore, "score" },
	}
	for _, cell in ipairs(textCells) do
		placeTextCell(row, cell[1], cell[2])
	end
	layoutCommentCell(row)

	local roleColumn = rowCol(row, "roles")
	if row.roles and roleColumn then
		GF.RoleDisplay:Layout(row.roles)
		row.roles:ClearAllPoints()
		row.roles:SetPoint("CENTER", row, "LEFT", roleColumn.x + roleColumn.width * 0.5, 0)
		row.roles:Show()
	elseif row.roles then
		row.roles:Hide()
	end
end

-- [ListRow] 4/5 悬停提示、高亮、标题绘制与行池（Detach/Release）

function LR:IsHoverTooltipEnabled()
	return true
end

function LR:IsHoverHighlightEnabled()
	return true
end

local GOLD, GRAY, IL_GREEN =
	{ r = 1, g = 0.82, b = 0 },
	{ r = 0.5, g = 0.5, b = 0.5 },
	{ r = 0.1, g = 1, b = 0.1 }

function LR:ClearApplicantHighlights()
	local ap = GF.ApplicantsPanel
	if ap and ap.ForEachVisibleRow then
		ap:ForEachVisibleRow(function(card)
			local members = card and card.members or {}
			for index = 1, #members do
				local highlight = members[index] and members[index].highlight
				if highlight then
					highlight:Hide()
				end
			end
		end)
	end
end

local hoverTooltipHideSeq = 0
local HOVER_TOOLTIP_HIDE_DELAY = GF.LIST_HOVER_TOOLTIP_HIDE_DELAY or 0.1

local function isListHoverTooltipEnabled()
	return LR:IsHoverTooltipEnabled()
end

local function isListHoverHighlightEnabled()
	return LR:IsHoverHighlightEnabled()
end

cancelHoverTooltipHide = function()
	hoverTooltipHideSeq = hoverTooltipHideSeq + 1
end

local function hideHoverTooltipNow()
	cancelHoverTooltipHide()
	lastTooltipResultID = nil
	if GameTooltip then
		GameTooltip:Hide()
	end
end

local function scheduleHoverTooltipHide(owner)
	cancelHoverTooltipHide()
	local scheduled = hoverTooltipHideSeq
	C_Timer.After(HOVER_TOOLTIP_HIDE_DELAY, function()
		if scheduled ~= hoverTooltipHideSeq then
			return
		end
		local tooltipOwner = GameTooltip and GameTooltip.GetOwner and GameTooltip:GetOwner()
		if owner and tooltipOwner ~= owner then
			return
		end
		lastTooltipResultID = nil
		if GameTooltip then
			GameTooltip:Hide()
		end
	end)
end

function LR:ClearHoverTooltip()
	hideHoverTooltipNow()
end

-- Row reuse must clear the native tooltip before GroupFinder's delayed tooltip can claim it.
local setRowHoverShown

function LR:ClearHoverHighlight()
	local tab = GF.FindGroupTab
	if tab and tab.ForEachVisibleRow then
		tab:ForEachVisibleRow(function(row)
			setRowHoverShown(row, false)
		end)
	end
	self:ClearApplicantHighlights()
end

local function FormatLeaderName(fullName, showRealm)
	if type(fullName) ~= "string" or fullName == "" then
		return "?"
	end
	if not showRealm then
		local shortName = fullName:match("^([^-]+)")
		return shortName or fullName
	end
	return fullName
end

local LEADER_RETRY_MAX = 2

local function canRetryLeaderForRow(row, index, token)
	if row._leaderRetrySeq ~= token or row.resultIndex ~= index then
		return false
	end
	if not row:IsShown() then
		return false
	end
	local currentText = row._metaLeaderText
	return not currentText or currentText == "?"
end

local function resolveLeaderPresentation(index, fallbackEntry)
	local loaded = index and GF.Result:GetEntry(index, { loadLeader = true }) or nil
	local entry = loaded or fallbackEntry
	local info = entry and entry.info
	local leader = entry and entry.leader
	local rawName = info and (info.leaderName or (leader and leader.name))
	local db = GF.GetDB()
	local classColor = leader and RAID_CLASS_COLORS[leader.classFilename or ""]
	return {
		text = FormatLeaderName(rawName, db and db.showLeaderRealm == true),
		color = classColor or { r = 1, g = 1, b = 1 },
		entry = entry,
	}
end

function LR:RefreshLeaderColumn(row, index, entry)
	if not row or not index then
		return false
	end
	local presentation = resolveLeaderPresentation(index, entry)
	if presentation.text == "?" then
		return false
	end
	row._metaLeaderText = presentation.text
	if paintColText(row, "leader", row.metaLeader, row._metaLeaderText) then
		local delisted = row._titleInfo and row._titleInfo.isDelisted
		local tint = delisted and (LFG_LIST_DELISTED_FONT_COLOR or GRAY) or presentation.color
		row.metaLeader:SetTextColor(tint.r, tint.g, tint.b)
	end
	return true, presentation.entry
end

function LR:ScheduleLeaderRetry(row, index)
	if not row or not index or not C_Timer or not C_Timer.After then
		return
	end
	row._leaderRetrySeq = (row._leaderRetrySeq or 0) + 1
	local token = row._leaderRetrySeq
	local attemptsRemaining = LEADER_RETRY_MAX
	local function retry()
		if not canRetryLeaderForRow(row, index, token) then
			return
		end
		if self:RefreshLeaderColumn(row, index) then
			return
		end
		attemptsRemaining = attemptsRemaining - 1
		if attemptsRemaining > 0 then
			C_Timer.After(0, retry)
		end
	end
	C_Timer.After(0, retry)
end

local function setDelistedOrColor(fontString, dc, r, g, b)
	local tint = dc or { r = r, g = g, b = b }
	fontString:SetTextColor(tint.r, tint.g, tint.b)
end

local function applyCancelledRowTextColor(row)
	local fields = { "title", "activity", "typeText", "metaIL", "metaLeader", "metaScore" }
	for _, field in ipairs(fields) do
		local fontString = row and row[field]
		if fontString then
			local color = APPLICATION_CANCELLED_TEXT_COLOR
			fontString:SetTextColor(color.r, color.g, color.b, color.a or 1)
		end
	end
end

local function createRowOverlayPieces(row, subLevel)
	local pieces = GF.UI and GF.UI.CreateRowBackgroundPieces
		and GF.UI.CreateRowBackgroundPieces(row, "BORDER", subLevel or -1)
		or nil
	if not (pieces and pieces.left and pieces.middle and pieces.right) then
		pieces = {}
		for _, key in ipairs({ "left", "middle", "right" }) do
			pieces[key] = row:CreateTexture(nil, "BORDER", nil, subLevel or -1)
		end
	end
	return pieces
end

local function setRowOverlayShown(pieces, shown)
	if GF.UI and GF.UI.SetRowBackgroundPiecesShown then
		GF.UI.SetRowBackgroundPiecesShown(pieces, shown == true)
		return
	end
	for _, piece in pairs(pieces or {}) do
		if piece.SetShown then
			piece:SetShown(shown == true)
		end
	end
end

local function applyRowOverlayPieces(row, pieces, color)
	if not (row and pieces and GF.UI and GF.UI.ApplyRowBackgroundPieces) then
		return false
	end
	return GF.UI.ApplyRowBackgroundPieces(row, pieces, {
		state = "normal",
		mode = "full",
		alpha = ROW_SELECTED_ALPHA,
		vertexColor = color or ROW_HOVER_COLOR,
		desaturated = true,
		fallbackTexture = ROW_BACKGROUND_FALLBACK_TEXTURE,
		defaultHeight = row and row.GetHeight and row:GetHeight() or (GF.GetListRowH and GF.GetListRowH() or GF.LIST_ROW_H or 32),
	})
end

local function setRowHoverTextureColor(row, color)
	if not row then
		return
	end
	color = color or ROW_HOVER_COLOR
	row._gfHoverColor = color
	applyRowOverlayPieces(row, row.hoverPieces, color)
	setRowOverlayShown(row.hoverPieces, row._gfHoverShown == true)
end

local function getRowSelectedColorForState(state)
	if GF.GetListBackgroundOverlayColor then
		return GF.GetListBackgroundOverlayColor(state, "selected")
	end
	if state == "blue" then
		return ROW_SELECTED_BLUE_COLOR
	end
	if state == "red" then
		return ROW_SELECTED_RED_COLOR
	end
	if state == "grey" then
		return ROW_SELECTED_GREY_COLOR
	end
	return ROW_SELECTED_COLOR
end

local function setRowSelectedTextureState(row, state)
	if not row then
		return
	end
	row._gfSelectedState = state or "normal"
	applyRowOverlayPieces(row, row.selectedHighlightPieces, getRowSelectedColorForState(state))
	setRowOverlayShown(row.selectedHighlightPieces, row._gfSelectedShown == true)
end

function setRowHoverShown(row, shown)
	if not row then
		return
	end
	row._gfHoverShown = shown == true
	setRowOverlayShown(row.hoverPieces, row._gfHoverShown)
end

local function setRowSelectedShown(row, shown)
	if row then
		row._gfSelectedShown = shown == true
	end
	setRowOverlayShown(row and row.selectedHighlightPieces, row and row._gfSelectedShown)
end

local function layoutRowSelectedTexture(row)
	if row and row.selectedHighlightPieces then
		applyRowOverlayPieces(row, row.selectedHighlightPieces, getRowSelectedColorForState(row._gfSelectedState))
		setRowOverlayShown(row.selectedHighlightPieces, row._gfSelectedShown == true)
	end
end

local function layoutRowHoverTextures(row)
	if row and row.hoverPieces then
		applyRowOverlayPieces(row, row.hoverPieces, row._gfHoverColor or ROW_HOVER_COLOR)
		setRowOverlayShown(row.hoverPieces, row._gfHoverShown == true)
	end
end

local function createRowSelectedTexture(row)
	local pieces = createRowOverlayPieces(row, 1)
	for _, piece in pairs(pieces) do
		if piece.SetBlendMode then
			piece:SetBlendMode("ADD")
		end
		piece:SetAlpha(ROW_SELECTED_ALPHA)
	end
	row.selectedHighlightPieces = pieces
	setRowSelectedTextureState(row, "normal")
	setRowSelectedShown(row, false)
	layoutRowSelectedTexture(row)
end

local function createRowHoverTextures(row)
	local pieces = createRowOverlayPieces(row, -1)
	for _, piece in pairs(pieces) do
		if piece.SetBlendMode then
			piece:SetBlendMode("ADD")
		end
	end
	row.hoverPieces = pieces
	layoutRowHoverTextures(row)
	setRowHoverTextureColor(row, ROW_HOVER_COLOR)
	setRowHoverShown(row, false)
end

local function getRowBackgroundAlpha(state)
	return GF.GetListBackgroundAlpha and GF.GetListBackgroundAlpha(state or "normal") or ROW_BACKGROUND_ALPHA
end

local function createBrowseRowBackgroundPieces(row, subLevel)
	local pieces = GF.UI and GF.UI.CreateRowBackgroundPieces
		and GF.UI.CreateRowBackgroundPieces(row, "BACKGROUND", subLevel or -2)
		or nil
	if not (pieces and pieces.left and pieces.middle and pieces.right) then
		pieces = {}
		for _, key in ipairs({ "left", "middle", "right" }) do
			pieces[key] = row:CreateTexture(nil, "BACKGROUND", nil, subLevel or -2)
		end
	end
	for _, piece in pairs(pieces) do
		piece:SetAlpha(getRowBackgroundAlpha("normal"))
	end
	return pieces
end

local function setBrowseRowBackgroundPiecesShown(pieces, shown)
	if GF.UI and GF.UI.SetRowBackgroundPiecesShown then
		GF.UI.SetRowBackgroundPiecesShown(pieces, shown)
		return
	end
	for _, piece in pairs(pieces or {}) do
		if piece.SetShown then
			piece:SetShown(shown == true)
		end
	end
end

local function stopBrowseBackgroundPieceFade(piece)
	if not piece then
		return
	end
	piece._gfBackgroundFadeToken = (piece._gfBackgroundFadeToken or 0) + 1
	if piece._gfBackgroundFade then
		piece._gfBackgroundFade:Stop()
	end
	piece:SetAlpha(0)
	piece:Hide()
end

local function ensureBrowseBackgroundPieceFade(piece)
	if not (piece and piece.CreateAnimationGroup) then
		return nil
	end
	if piece._gfBackgroundFade then
		return piece._gfBackgroundFade
	end
	local fade = piece:CreateAnimationGroup()
	local alpha = fade:CreateAnimation("Alpha")
	alpha:SetFromAlpha(getRowBackgroundAlpha())
	alpha:SetToAlpha(0)
	alpha:SetDuration(ROW_BACKGROUND_FADE_SECONDS)
	alpha:SetSmoothing("OUT")
	fade:SetScript("OnFinished", function(group)
		if piece._gfBackgroundFadeToken ~= group._gfToken then
			return
		end
		piece:SetAlpha(0)
		piece:Hide()
	end)
	piece._gfBackgroundFade = fade
	piece._gfBackgroundFadeAlpha = alpha
	return fade
end

local function playBrowseBackgroundPieceFade(piece, alphaValue)
	if not piece then
		return
	end
	piece._gfBackgroundFadeToken = (piece._gfBackgroundFadeToken or 0) + 1
	local token = piece._gfBackgroundFadeToken
	local fade = ensureBrowseBackgroundPieceFade(piece)
	if fade then
		fade:Stop()
	end
	piece:SetAlpha(alphaValue)
	piece:Show()
	if fade and piece._gfBackgroundFadeAlpha then
		piece._gfBackgroundFadeAlpha:SetFromAlpha(alphaValue)
		piece._gfBackgroundFadeAlpha:SetToAlpha(0)
		piece._gfBackgroundFadeAlpha:SetDuration(ROW_BACKGROUND_FADE_SECONDS)
		fade._gfToken = token
		fade:Play()
	else
		piece:SetAlpha(0)
		piece:Hide()
	end
end

local function stopBrowseRowBackgroundTransition(row)
	if not row then
		return
	end
	for _, piece in pairs(row.backgroundTransitionPieces or {}) do
		stopBrowseBackgroundPieceFade(piece)
	end
end

local function getBrowseRowBackgroundOptions(row, state)
	return {
		state = state or "normal",
		mode = "full",
		alpha = getRowBackgroundAlpha(state),
		fallbackTexture = ROW_BACKGROUND_FALLBACK_TEXTURE,
		defaultHeight = row and row.GetHeight and row:GetHeight() or (GF.GetListRowH and GF.GetListRowH() or GF.LIST_ROW_H or 32),
	}
end

local function applyBrowseRowBackgroundPieces(row, pieces, state)
	if GF.UI and GF.UI.ApplyRowBackgroundPieces then
		return GF.UI.ApplyRowBackgroundPieces(row, pieces, getBrowseRowBackgroundOptions(row, state))
	end
	local color = GF.GetListBackgroundColor and GF.GetListBackgroundColor(state) or nil
	for _, piece in pairs(pieces or {}) do
		piece:ClearAllPoints()
		piece:SetAllPoints(row)
		piece:SetTexture(ROW_BACKGROUND_FALLBACK_TEXTURE)
		piece:SetTexCoord(0, 1, 0, 1)
		if color then
			piece:SetVertexColor(color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1)
		else
			piece:SetVertexColor(1, 1, 1, 1)
		end
		piece:SetAlpha(getRowBackgroundAlpha(state))
		piece:Show()
	end
	return true
end

local function setBrowseRowBackground(row, state)
	if not row or not row.backgroundPieces then
		return
	end
	state = state or "normal"
	local transitionAlpha = getRowBackgroundAlpha(row._gfBrowseBackgroundState)
	local elementKey = row.resultID and tostring(row.resultID) or nil
	local shouldFade = not row._gfSuppressBackgroundTransition
		and elementKey
		and row._gfBrowseBackgroundElementKey == elementKey
		and row._gfBrowseBackgroundState
		and row._gfBrowseBackgroundState ~= state
	if shouldFade then
		applyBrowseRowBackgroundPieces(row, row.backgroundTransitionPieces, row._gfBrowseBackgroundState)
		for _, piece in pairs(row.backgroundTransitionPieces or {}) do
			if piece.IsShown and piece:IsShown() then
				playBrowseBackgroundPieceFade(piece, transitionAlpha)
			else
				stopBrowseBackgroundPieceFade(piece)
			end
		end
	else
		stopBrowseRowBackgroundTransition(row)
	end
	applyBrowseRowBackgroundPieces(row, row.backgroundPieces, state)
	row._gfBrowseBackgroundElementKey = elementKey
	row._gfBrowseBackgroundState = state
end

local function selectionSuppressesListRowHover(row)
	return row._isSelected == true and row._isAppActive ~= true
end

local function shouldShowListRowHover(row)
	return row ~= nil and not selectionSuppressesListRowHover(row)
end

local function shouldKeepListRowHover(_row)
	return false
end

local function shouldShowRowSelected(row)
	return row
		and row._isSelected == true
		and row._hasApplication ~= true
		and row._isDelisted ~= true
end

function LR:DetachRow(row)
	if not row then
		return
	end
	for _, field in ipairs({ "resultIndex", "resultID", "_hasVoice" }) do
		row[field] = nil
	end
	if row.voiceIcon then
		row.voiceIcon:Hide()
	end
	local managedByScrollBox = type(row.GetElementData) == "function"
	if not managedByScrollBox then
		row:Hide()
	end
	self:ReleaseRow(row)
end

function LR:ReleaseRow(row)
	if not row then
		return
	end
	local transientFields = {
		"_isSelected", "_isDelisted", "_isAppActive", "_hasApplication",
		"_applicationVisualState", "_resultType", "_resultDisplayType",
		"_commentText", "_listMouseOver",
	}
	for _, field in ipairs(transientFields) do
		row[field] = nil
	end
	hideComment(row)
	setRowHoverShown(row, false)
	setRowSelectedShown(row, false)
	row._gfSuppressBackgroundTransition = true
	self:UpdateRowBackgrounds(row)
	for _, field in ipairs({ "_gfSuppressBackgroundTransition", "_gfBrowseBackgroundElementKey", "_gfBrowseBackgroundState" }) do
		row[field] = nil
	end
end

local function getTitleDelistedColor(info)
	if not info or not info.isDelisted then
		return nil
	end
	return LFG_LIST_DELISTED_FONT_COLOR or GRAY
end

local function resolveResultType(row, info, entry)
	local resultID = row and row.resultID or entry and entry.resultID
	return GF.FindGroup and GF.FindGroup:GetResultType(info, entry, resultID) or nil
end

local function resolveResultDisplayType(row, info, entry, resultType)
	local resultID = row and row.resultID or entry and entry.resultID
	if GF.FindGroup and GF.FindGroup.GetResultDisplayType then
		return GF.FindGroup:GetResultDisplayType(info, entry, resultID, resultType)
	end
	return resultType or resolveResultType(row, info, entry)
end

local function getResultTypeLabel(resultType)
	local L = GF.L or {}
	if resultType == "blacklist" then
		return L.TYPE_BLACKLIST or "黑名单"
	end
	if resultType == "leaver" then
		return L.TYPE_LEAVER or "大秘逃兵"
	end
	local socialLabelKey = GF.SOCIAL_SEARCH_RESULT_LABEL_KEY
		and GF.SOCIAL_SEARCH_RESULT_LABEL_KEY[resultType]
	if socialLabelKey then
		return L[socialLabelKey] or SOCIAL_SEARCH_RESULT_LABEL_FALLBACK[resultType] or ""
	end
	return ""
end

local function measureTypeLabel(fontString, text)
	if fontString.GetUnboundedStringWidthForText then
		return fontString:GetUnboundedStringWidthForText(text or "") or 0
	end

	local previousText = fontString:GetText()
	fontString:SetText(text or "")
	local width
	if fontString.GetUnboundedStringWidth then
		width = fontString:GetUnboundedStringWidth()
	else
		width = fontString:GetStringWidth()
	end
	fontString:SetText(previousText or "")
	return width or 0
end

local function getTypeLabelSlotWidth(fontString)
	local fontPath, fontSize, fontFlags = fontString:GetFont()
	local textScale = fontString.GetTextScale and fontString:GetTextScale() or 1
	local cacheKeyParts = {
		tostring(fontPath or ""),
		tostring(fontSize or ""),
		tostring(fontFlags or ""),
		tostring(textScale or ""),
	}
	local labels = {}
	for _, resultType in ipairs(TYPE_ICON_ALIGNMENT_TYPES) do
		local label = getResultTypeLabel(resultType)
		labels[#labels + 1] = label
		cacheKeyParts[#cacheKeyParts + 1] = tostring(resultType) .. "\030" .. label
	end
	local cacheKey = table.concat(cacheKeyParts, "\031")
	local cachedWidth = TYPE_LABEL_SLOT_WIDTH_CACHE[cacheKey]
	if cachedWidth then
		return cachedWidth
	end

	local widest = 1
	for _, label in ipairs(labels) do
		widest = math.max(widest, measureTypeLabel(fontString, label))
	end
	widest = math.ceil(widest)
	TYPE_LABEL_SLOT_WIDTH_CACHE[cacheKey] = widest
	return widest
end

local function getResultTypeVisualState(resultType)
	if resultType == "blacklist" or resultType == "leaver" then
		return "red"
	end
	local socialState = GF.GetSocialTypeVisualState and GF.GetSocialTypeVisualState(resultType)
	if socialState then
		return socialState
	end
	return nil
end

local function getBrowseRowVisualState(row)
	if not row then
		return "normal"
	end
	if row._resultType == GF.RESULT_TYPE_CURRENT_GROUP then
		return "blue"
	end
	if row._isDelisted == true or row._applicationVisualState == "cancelled" or row._applicationVisualState == "declined" then
		return "grey"
	end
	local typeState = getResultTypeVisualState(row._resultType)
	if typeState then
		return typeState
	end
	if row._applicationVisualState == "green" then
		return "green"
	end
	return "normal"
end

local function getBrowseRowHoverColorForState(state)
	if GF.GetListBackgroundOverlayColor then
		return GF.GetListBackgroundOverlayColor(state, "hover")
	end
	if state == "red" then
		return ROW_HOVER_RED_COLOR
	end
	if state == "blue" then
		return ROW_HOVER_BLUE_COLOR
	end
	if state == "grey" then
		return ROW_HOVER_GREY_COLOR
	end
	return ROW_HOVER_COLOR
end

local function paintTitleCol(row, text, dc, applyColors)
	local col = rowCol(row, "title")
	if not col or not row.title then
		return false
	end
	setRowEllipsis(row.title, text, getTextCellWidth(row, "title", col))
	if applyColors then
		setDelistedOrColor(row.title, dc, GOLD.r, GOLD.g, GOLD.b)
	end
	return true
end

local function paintTypeCol(row, col, dc)
	if not row or not col then
		return
	end
	local resultType = row._resultDisplayType or row._resultType
	local text = row._typeText or ""
	if not resultType or text == "" then
		if row.typeIcon then
			row.typeIcon:Hide()
		end
		if row.typeText then
			row.typeText:SetText("")
			row.typeText:Hide()
		end
		return
	end

	local icon = row.typeIcon
	local fontString = row.typeText
	if not fontString then
		return
	end
	fontString:Show()
	fontString:SetText(text)
	fontString:SetJustifyH("LEFT")
	local typeDisabledColor = dc
	if resultType == GF.RESULT_TYPE_CURRENT_GROUP then
		typeDisabledColor = nil
	end
	local color = typeDisabledColor or TYPE_TEXT_COLOR[resultType] or HIGHLIGHT_FONT_COLOR
	if color then
		fontString:SetTextColor(color.r or color[1] or 1, color.g or color[2] or 1, color.b or color[3] or 1, color.a or color[4] or 1)
	end

	local hasIcon = icon and TYPE_ICON_TEXTURE[resultType]
	local typeIconSize = getTypeIconSize()
	local iconW = hasIcon and typeIconSize or 0
	local gap = hasIcon and TYPE_ICON_GAP or 0
	local maxTextW = math.max(1, col.width - iconW - gap)
	local textW = hasIcon and getTypeLabelSlotWidth(fontString) or measureTypeLabel(fontString, text)
	textW = math.min(math.max(1, math.ceil(textW or 0)), maxTextW)
	local groupW = iconW + gap + textW
	local x = col.x + math.max(0, math.floor((col.width - groupW) / 2))

	if hasIcon then
		icon:ClearAllPoints()
		icon:SetPoint("LEFT", row, "LEFT", x, 0)
		icon:SetSize(typeIconSize, typeIconSize)
		icon:SetTexture(TYPE_ICON_TEXTURE[resultType])
		icon:SetTexCoord(0, 1, 0, 1)
		icon:SetDesaturated(typeDisabledColor ~= nil)
		icon:SetAlpha(typeDisabledColor and 0.5 or 1)
		icon:Show()
	elseif icon then
		icon:Hide()
	end

	fontString:ClearAllPoints()
	fontString:SetPoint("LEFT", row, "LEFT", x + iconW + gap, 0)
	setRowEllipsis(fontString, text, math.max(1, col.x + col.width - (x + iconW + gap)))
end

function LR:RefreshTitleFromEntry(row, entry)
	local info = entry and entry.info
	if not (row and info) then
		return
	end
	row._titleEntry = entry
	row._titleInfo = info
	row._resultType = resolveResultType(row, info, entry)
	row._resultDisplayType = resolveResultDisplayType(row, info, entry, row._resultType)
	row._typeText = getResultTypeLabel(row._resultDisplayType)
	local disabledColor = getTitleDelistedColor(info)
	paintTitleCol(row, row._titleText or "", disabledColor, true)
	paintTypeCol(row, rowCol(row, "type"), disabledColor)
	self:UpdateRowBackgrounds(row)
end

local function paintCachedCell(row, field, columnID, text, color)
	local fontString = row[field]
	if paintColText(row, columnID, fontString, text) and color then
		fontString:SetTextColor(color.r, color.g, color.b, color.a or 1)
	end
end

local function paintRowFromCache(row, opts)
	opts = opts or {}
	local dc = opts.dc
	paintTitleCol(row, row._titleText, dc, opts.applyColors)
	local typeCol = rowCol(row, "type")
	if typeCol then
		paintTypeCol(row, typeCol, dc)
	else
		row.typeText:SetText("")
		row.typeText:Hide()
		row.typeIcon:Hide()
	end

	local applicationPainted
	if opts.applyAppState and rowCol(row, "comment") and row.resultID then
		applicationPainted = LR:ApplyApplicationState(row, row.resultID, dc)
	end
	if rowCol(row, "comment") and not applicationPainted then
		refreshCommentCell(row, row._commentText, dc)
	end

	local colorize = opts.applyColors
	local activityTint = colorize and (dc or GOLD) or nil
	local itemLevelTint = colorize and (dc or IL_GREEN) or nil
	paintCachedCell(row, "activity", "activity", row._activityText, activityTint)
	paintCachedCell(row, "metaIL", "ilvl", row._metaILText, itemLevelTint)

	local scoreTint
	if colorize then
		scoreTint = dc or opts.scoreColor or GOLD
	end
	local scoreCol = rowCol(row, "score")
	if scoreCol and row._metaScoreText then
		setRowEllipsis(row.metaScore, row._metaScoreText, scoreCol.width)
		applyColumnJustify(row.metaScore, scoreCol)
		if scoreTint then
			row.metaScore:SetTextColor(scoreTint.r, scoreTint.g, scoreTint.b)
		end
		row.metaScore:Show()
	elseif row.metaScore then
		row.metaScore:SetText("")
		row.metaScore:Hide()
	end

	paintCachedCell(row, "metaLeader", "leader", row._metaLeaderText, colorize and (dc or opts.leaderColor) or nil)
	if colorize and (
		row._applicationDisplayState == "cancelled"
		or row._applicationDisplayState == "departed"
	) then
		applyCancelledRowTextColor(row)
	end
end

function LR:LayoutOnly(row, width)
	if not (row and row.title) then
		return
	end
	if tonumber(width) and width > 0 then
		row:SetWidth(width)
	end
	local height = GF.GetListRowH and GF.GetListRowH() or GF.LIST_ROW_H or 32
	row:SetHeight(height)
	layoutRowSelectedTexture(row)
	layoutRowHoverTextures(row)
	self:LayoutRow(row)
	paintRowFromCache(row, { applyAppState = row.resultID ~= nil })
end


-- [ListRow] 5/5 行框架创建、申请控件与 SetData 入口

local ROW_TEXT_FIELDS = {
	{ field = "title", template = "GameFontNormal" },
	{ field = "typeText", template = "GameFontHighlightSmall" },
	{ field = "metaIL", template = "GameFontDisableSmall" },
	{ field = "comment", template = "GameFontHighlightSmall" },
	{ field = "activity", template = "GameFontDisableSmall" },
	{ field = "metaScore", template = "GameFontDisableSmall" },
	{ field = "metaLeader", template = "GameFontDisableSmall" },
}

local function createOneLineText(row, template, justify)
	local fontString = GF.UI.CreateFontString(row, "OVERLAY", template)
	fontString:SetJustifyH(justify or "LEFT")
	fontString:SetMaxLines(1)
	fontString:SetWordWrap(false)
	return fontString
end

local function createHiddenTexture(owner, layer)
	local texture = owner:CreateTexture(nil, layer)
	texture:Hide()
	return texture
end

local function showFallbackListTooltip(row, resultID)
	local canUseNative = LFGListUtil_SetSearchEntryTooltip
		and (not GF.Result or not GF.Result.IsLiveSearchResultInfoAuthoritative
			or GF.Result:IsLiveSearchResultInfoAuthoritative(resultID))
		and C_LFGList and C_LFGList.GetSearchResultInfo(resultID)
	if not canUseNative then
		return false
	end
	GameTooltip:SetOwner(row, "ANCHOR_RIGHT", 25, 0)
	if GF.Font and GF.Font.BeginTooltipFont then
		GF.Font.BeginTooltipFont(GameTooltip)
	end
	LFGListUtil_SetSearchEntryTooltip(GameTooltip, resultID)
	if GF.Font and GF.Font.ApplyTooltipFont then
		GF.Font.ApplyTooltipFont(GameTooltip)
	end
	return true
end

local function listRowOnEnter(row)
	row._listMouseOver = true
	if isListHoverHighlightEnabled() and shouldShowListRowHover(row) then
		setRowHoverShown(row, true)
	end
	local resultID = row.resultID
	if not resultID then
		return
	end
	LR:SyncDelistedFromAPI(row)
	if not isListHoverTooltipEnabled() then
		return
	end
	cancelHoverTooltipHide()
	if lastTooltipResultID == resultID and GameTooltip:IsShown() then
		return
	end
	local shown = false
	if GF.ListTooltip and GF.ListTooltip.Show then
		GF.ListTooltip:Show(GameTooltip, resultID, row)
		shown = true
	else
		shown = showFallbackListTooltip(row, resultID)
	end
	if shown then
		lastTooltipResultID = resultID
	end
end

local function listRowOnLeave(row)
	row._listMouseOver = nil
	setRowHoverShown(row, shouldKeepListRowHover(row))
	if isListHoverTooltipEnabled() then
		scheduleHoverTooltipHide(row)
	end
end

function LR:Create(parent, index, existingRow)
	local row = existingRow or CreateFrame("Button", "GroupFinderAddonListRow" .. (index or 0), parent)
	if row._gfInited then
		return row
	end
	local measuredWidth = parent and parent:GetWidth() or row:GetWidth() or 0
	local initialWidth = measuredWidth > 0 and measuredWidth or 400
	local initialHeight = GF.GetListRowH and GF.GetListRowH() or GF.LIST_ROW_H or 32
	row:SetSize(initialWidth, initialHeight)

	row.backgroundPieces = createBrowseRowBackgroundPieces(row, -2)
	row.backgroundTransitionPieces = createBrowseRowBackgroundPieces(row, -1)
	setBrowseRowBackgroundPiecesShown(row.backgroundTransitionPieces, false)
	setBrowseRowBackground(row, "normal")

	createRowHoverTextures(row)
	createRowSelectedTexture(row)

	row.appPending = createOneLineText(row, "GameFontHighlight", "CENTER")
	row.appPending:SetJustifyH("CENTER")
	row.appPending:SetJustifyV("MIDDLE")
	row.appPending:Hide()
	if GF.Font and GF.Font.Track then
		GF.Font.Track(row.appPending, "GameFontHighlight")
	end
	row.appStatusIcon = row:CreateTexture(nil, "OVERLAY")
	row.appStatusIcon:SetSize(APPLICATION_STATUS_ICON_SIZE, APPLICATION_STATUS_ICON_SIZE)
	row.appStatusIcon:Hide()
	row.appSpinner = CreateApplicationPendingSpinner(row)
	row.appCancelHost = CreateFrame("Frame", nil, row)
	row.appCancelHost:SetSize(APPLICATION_CANCEL_BUTTON_DISPLAY_SIZE, APPLICATION_CANCEL_BUTTON_DISPLAY_SIZE)
	row.appCancelHost:SetFrameLevel(row:GetFrameLevel() + 4)
	row.appCancelHost:Hide()
	row.appCancel = CreateApplicationCancelButton(row.appCancelHost)
	row.appCancel._gfRow = row
	if row.appSpinner then
		row.appSpinner:Hide()
	end

	for _, definition in ipairs(ROW_TEXT_FIELDS) do
		row[definition.field] = createOneLineText(row, definition.template, definition.justify)
	end

	row.typeIcon = createHiddenTexture(row, "ARTWORK")
	local initialTypeIconSize = getTypeIconSize()
	row.typeIcon:SetSize(initialTypeIconSize, initialTypeIconSize)

	row.voiceIcon = createHiddenTexture(row, "ARTWORK")
	row.voiceIcon:SetSize(16, 14)
	row.voiceIcon:SetAtlas("groupfinder-icon-voice")

	row.roles = GF.RoleDisplay:Create(row)
	for _, field in ipairs({ "resultIndex", "resultID", "categoryID" }) do
		row[field] = nil
	end
	row:SetScript("OnEnter", listRowOnEnter)
	row:SetScript("OnLeave", listRowOnLeave)

	row._gfInited = true
	return row
end

function LR:EnsureRow(row)
	if row == nil or row._gfInited then
		return row
	end
	return self:Create(row:GetParent(), 0, row)
end

local function resolveBoundResult(elementData)
	local resultID = elementData.resultID
	local index = elementData.dataIndex
	if not index and resultID then
		index = GF.Result:GetIndexForResultID(resultID)
	elseif not resultID and index then
		resultID = GF.Result:GetResultID(index)
	end
	return resultID, index
end

local function loadBoundEntry(resultID, index, loadPlayers)
	local entry = index and GF.Result:GetEntry(index, { loadPlayers = loadPlayers }) or nil
	local needsFallback = resultID and not (entry and entry.info)
	if needsFallback then
		entry = GF.Result:GetEntryByResultID(resultID)
		if not index then
			index = GF.Result:GetIndexForResultID(resultID)
		end
	end
	return entry, index
end

function LR:BindElement(row, elementData, panel, opts)
	opts = opts or {}
	if not (row and elementData and panel) then
		return false
	end
	local resultID, index = resolveBoundResult(elementData)
	local measuredWidth = panel.scrollList and panel.scrollList:GetLayoutWidth() or panel._lastLayoutW or 0
	local layoutW = measuredWidth > 0 and measuredWidth or 400
	panel._lastLayoutW = layoutW
	row:SetWidth(layoutW)

	local loadPlayers = opts.loadPlayers == true and not opts.deferRoles
	local entry
	entry, index = loadBoundEntry(resultID, index, loadPlayers)
	if not entry or not entry.info or not index then
		return false
	end
	local fallbackCategory = panel.selection and panel.selection.categoryID
	local rowCat = GF.Result:ResolveRowCategory(index, fallbackCategory)
	local dataOptions = {
		deferRoles = opts.deferRoles ~= false,
		skipLayout = opts.skipLayout,
		layoutW = layoutW,
	}
	local wasBound = self:SetData(row, index, rowCat, entry, dataOptions)
	if wasBound ~= true then
		return false
	end
	if rowHasRenderedBadListingText(row) then
		row:Hide()
		dropRenderedBadResult(panel, resultID)
		return false
	end
	local selected = panel.selectedResultID ~= nil and row.resultID == panel.selectedResultID
	row._isSelected = selected or nil
	if selected then
		panel._selectedRow = row
		panel.selectedResult = row.resultIndex
	elseif panel._selectedRow == row then
		panel._selectedRow = nil
	end
	self:UpdateRowBackgrounds(row)
	row:SetWidth(layoutW)
	if panel.WireOneRow then
		panel:WireOneRow(row)
	end
	if row._deferRoles == true then
		self:UpdateRoles(row, entry, row.categoryID)
	end
	return true
end

local function isDeclinedApplicationStatus(status)
	return status == "declined" or status == "declined_delisted" or status == "declined_full"
end

local function isCancelledApplicationStatus(status)
	return status == "cancelled" or status == "failed" or status == "timedout" or status == "invitedeclined"
end

local function isJoinedApplicationStatus(status)
	return status == "invited" or status == "inviteaccepted"
end

local function getApplicationDisplayState(state)
	if not state or not state.isApplication then
		return nil
	end
	if state.isDepartedApplication == true then
		return "departed"
	end
	local a, p = state.appStatus, state.pendingStatus
	if isJoinedApplicationStatus(a) or isJoinedApplicationStatus(p) then
		return "joined"
	end
	if state.isActiveApp then
		return "pending"
	end
	if state.isDeclined or isDeclinedApplicationStatus(a) or isDeclinedApplicationStatus(p) then
		return "declined"
	end
	if isCancelledApplicationStatus(a) or isCancelledApplicationStatus(p) then
		return "cancelled"
	end
	return nil
end

local function FormatApplicationCountdown(seconds)
	seconds = math.max(0, math.floor(tonumber(seconds) or 0))
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

local function getApplicationRemainingSeconds(state)
	local duration = tonumber(state and state.appDuration)
	if duration and duration >= 0 and duration <= APPLICATION_TIMEOUT_SECONDS then
		return duration
	end
	return APPLICATION_TIMEOUT_SECONDS
end

local function getApplicationText(displayState, remainingSeconds)
	local L = GF.L or {}
	if displayState == "pending" then
		return string.format(L.APP_STATE_PENDING_FMT or "待定 %s", FormatApplicationCountdown(remainingSeconds))
	end
	if displayState == "declined" then
		return L.APP_STATE_DECLINED or "被拒绝"
	end
	if displayState == "cancelled" then
		return L.APP_STATE_CANCELLED or "已取消"
	end
	if displayState == "joined" then
		return L.APP_STATE_JOINED or "已加入"
	end
	if displayState == "departed" then
		return L.APP_STATE_LEFT_GROUP or "已离队"
	end
	return nil
end

local function getApplicationTextColor(displayState)
	if displayState == "pending" or displayState == "joined" then
		return APPLICATION_PENDING_TEXT_COLOR
	end
	if displayState == "declined" then
		return APPLICATION_DECLINED_TEXT_COLOR
	end
	if displayState == "cancelled" or displayState == "departed" then
		return APPLICATION_CANCELLED_TEXT_COLOR
	end
	return nil
end

local function LayoutApplicationComment(row, displayState)
	local col = rowCol(row, "comment")
	if not row or not row.appPending or not col then
		return
	end
	local showCancelButton = displayState == "pending"
	local buttonHost = row.appCancelHost or row.appCancel
	local button = row.appCancel
	local reservedWidth = showCancelButton and (APPLICATION_CANCEL_BUTTON_DISPLAY_SIZE + APPLICATION_CANCEL_BUTTON_GAP) or 0
	local availableWidth = math.max(1, col.width - 4 - reservedWidth)

	if row.comment then
		clearCommentText(row.comment)
		row.comment:Hide()
	end
	if row.voiceIcon then
		row.voiceIcon:Hide()
	end
	if buttonHost then
		buttonHost:ClearAllPoints()
		buttonHost:SetPoint("RIGHT", row, "LEFT", col.x + col.width - 2, getAppLineY(row))
		buttonHost:SetShown(showCancelButton)
	end
	if button then
		button.resultID = row.resultID
		button:SetShown(showCancelButton)
	end

	local statusIcon = row.appStatusIcon
	local pendingSpinner = row.appSpinner
	if not displayState then
		if statusIcon then
			statusIcon:Hide()
		end
		StopApplicationPendingSpinner(pendingSpinner)
		row.appPending:ClearAllPoints()
		row.appPending:SetPoint("LEFT", row, "LEFT", col.x + 2, getAppLineY(row))
		row.appPending:SetSize(availableWidth, 18)
		row.appPending:SetJustifyH("CENTER")
		return
	end

	local statusFrame
	if displayState == "pending" then
		statusFrame = pendingSpinner
		if statusIcon then
			statusIcon:Hide()
		end
	else
		StopApplicationPendingSpinner(pendingSpinner)
		if statusIcon and displayState ~= "joined" then
			statusIcon:SetTexture(APPLICATION_ALERT_ICON_TEXTURE)
			statusIcon:SetTexCoord(0, 1, 0, 1)
			statusIcon:SetSize(APPLICATION_STATUS_ICON_SIZE, APPLICATION_STATUS_ICON_SIZE)
			statusFrame = statusIcon
		elseif statusIcon then
			statusIcon:Hide()
		end
	end

	local measuredTextWidth = math.max(1, math.ceil(row.appPending:GetStringWidth() or 0))
	local statusSize = statusFrame and (displayState == "pending" and APPLICATION_PENDING_SPINNER_SIZE or APPLICATION_STATUS_ICON_SIZE) or 0
	local statusGap = statusFrame and APPLICATION_STATUS_ICON_GAP or 0
	local contentLeft = col.x + 2
	local maxTextWidth = math.max(1, availableWidth - statusSize - statusGap)
	local visualTextWidth = math.min(measuredTextWidth, maxTextWidth)
	local groupWidth = visualTextWidth + statusSize + statusGap
	local textLeftOffset = contentLeft
		+ math.floor((availableWidth - groupWidth) / 2)
		+ statusSize
		+ statusGap
		+ APPLICATION_STATUS_TEXT_OFFSET_X
	local minTextLeft = contentLeft + statusSize + statusGap
	local maxTextLeft = contentLeft + availableWidth - visualTextWidth
	textLeftOffset = math.max(minTextLeft, math.min(maxTextLeft, textLeftOffset))
	local textAreaWidth = math.max(1, contentLeft + availableWidth - textLeftOffset)

	row.appPending:ClearAllPoints()
	row.appPending:SetPoint("LEFT", row, "LEFT", textLeftOffset, getAppLineY(row))
	row.appPending:SetSize(textAreaWidth, 18)
	row.appPending:SetJustifyH("LEFT")
	if statusFrame then
		statusFrame:ClearAllPoints()
		statusFrame:SetPoint("RIGHT", row.appPending, "LEFT", -statusGap, 0)
		if displayState == "pending" then
			StartApplicationPendingSpinner(statusFrame)
		else
			statusFrame:Show()
		end
	end
end

local function hideAppCluster(row)
	if row.appPending then
		row.appPending:SetText("")
		row.appPending:Hide()
	end
	if row.appStatusIcon then
		row.appStatusIcon:Hide()
	end
	if row.appSpinner then
		StopApplicationPendingSpinner(row.appSpinner)
	end
	if row.appCancelHost then
		row.appCancelHost:Hide()
	end
	if row.appCancel then
		row.appCancel.resultID = nil
		row.appCancel:Hide()
	end
	row._isAppActive = nil
	row._hasApplication = nil
	row._applicationVisualState = nil
	row._applicationDisplayState = nil
	row._appExpiryShown = nil
	row._appExpiration = nil
	row._appReservedW = nil
end

local function resolveApplicationVisualState(state)
	local displayState = getApplicationDisplayState(state)
	if displayState == "declined" then
		return "declined"
	end
	if displayState == "cancelled" or displayState == "departed" then
		return "cancelled"
	end
	return nil
end

function LR:TickExpiry(row)
	if not (row and row._appExpiryShown and row.appPending) then
		return
	end
	local left = math.max(0, (row._appExpiration or 0) - GetTime())
	row.appPending:SetText(getApplicationText("pending", left))
	LayoutApplicationComment(row, "pending")
end

local function clearApplicationPresentation(row, delistedColor, restoreComment)
	if row and row.appPending then
		hideAppCluster(row)
		if restoreComment then
			relayoutCommentText(row, delistedColor)
		end
	end
	return false
end

function LR:ApplyApplicationState(row, resultID, delistedColor)
	if not (row and resultID and GF.Apply) then
		return clearApplicationPresentation(row, delistedColor, true)
	end
	local state = GF.Apply:GetApplicationState(resultID)
	if not state or not state.isApplication then
		return clearApplicationPresentation(row, delistedColor, true)
	end
	local displayState = getApplicationDisplayState(state)
	local remainingSeconds = displayState == "pending" and getApplicationRemainingSeconds(state) or nil
	local text = getApplicationText(displayState, remainingSeconds)
	local color = getApplicationTextColor(displayState)
	if not text then
		return clearApplicationPresentation(row, delistedColor, true)
	end
	local col = rowCol(row, "comment")
	if not col then
		return clearApplicationPresentation(row, delistedColor, false)
	end
	row.appPending:SetText(text)
	row.appPending:SetTextColor(color.r, color.g, color.b, color.a or 1)
	row.appPending:Show()
	LayoutApplicationComment(row, displayState)
	row._appReservedW = col.width
	row._appExpiryShown = displayState == "pending" or nil
	row._appExpiration = row._appExpiryShown and (GetTime() + (remainingSeconds or 0)) or nil
	if row._appExpiryShown and GF.Apply.EnsureExpiryTicker then
		GF.Apply:EnsureExpiryTicker()
	end
	if GF.EnsureBlizzardAddons then
		GF.EnsureBlizzardAddons()
	end
	if row.appCancel and row.appCancel:IsShown() and LFGListUtil_IsAppEmpowered then
		row.appCancel:SetEnabled(LFGListUtil_IsAppEmpowered())
	end
	row._isAppActive = displayState == "pending" or nil
	row._hasApplication = true
	row._applicationDisplayState = displayState
	row._applicationVisualState = resolveApplicationVisualState(state)
	if displayState == "cancelled" or displayState == "departed" then
		applyCancelledRowTextColor(row)
	end
	return true
end

function LR:UpdateRowBackgrounds(row)
	if not row then
		return
	end
	local visualState = getBrowseRowVisualState(row)
	setBrowseRowBackground(row, visualState)
	local overlayState = row._applicationVisualState == "declined" and "red" or visualState
	setRowHoverTextureColor(row, getBrowseRowHoverColorForState(overlayState))
	setRowSelectedTextureState(row, overlayState)
	local mouseHover = row._listMouseOver == true
		and isListHoverHighlightEnabled()
		and shouldShowListRowHover(row)
	setRowHoverShown(row, shouldKeepListRowHover(row) or mouseHover)
	setRowSelectedShown(row, shouldShowRowSelected(row))
end

function LR:SetDelistedState(row, isDelisted)
	if row then
		row._isDelisted = isDelisted == true and true or nil
		self:UpdateRowBackgrounds(row)
	end
end

local function dropResultAndRefresh(resultID)
	local tab = GF.FindGroupTab
	if not (tab and tab.DropFrozenResult and tab:DropFrozenResult(resultID)) then
		return false
	end
	if tab.RefreshList then
		tab:RefreshList({ preserveScroll = true })
	end
	return true
end

function LR:SyncDelistedFromAPI(row)
	if not (row and row.resultID) then
		return
	end
	local resultID = row.resultID
	local info, infoState
	if GF.Result and GF.Result.GetLiveSearchResultInfoForUpdate then
		info, infoState = GF.Result:GetLiveSearchResultInfoForUpdate(resultID)
	elseif C_LFGList and C_LFGList.GetSearchResultInfo then
		info = C_LFGList.GetSearchResultInfo(resultID)
	end
	if not info then
		local cached = GF.Result and GF.Result.GetCachedSearchResultInfo
			and GF.Result:GetCachedSearchResultInfo(resultID)
		if cached and GF.IsCurrentGroupSearchResult
			and GF.IsCurrentGroupSearchResult(cached, resultID)
		then
			return
		end
		if infoState ~= "not_current" then
			dropResultAndRefresh(resultID)
		end
		return
	end
	if GF.Result and GF.Result.GetSearchResultInvalidReason then
		local invalidReason = GF.Result:GetSearchResultInvalidReason(resultID, info)
		if invalidReason == "unavailable" then
			local unavailableEntry = GF.Result.MarkSoftUnavailable
				and GF.Result:MarkSoftUnavailable(resultID, info)
			if unavailableEntry then
				self:RepaintRowState(row, unavailableEntry, row.categoryID)
			end
			return
		elseif invalidReason then
			dropResultAndRefresh(resultID)
			return
		end
	end
	local entry = GF.Result and GF.Result.RefreshEntryInfo and GF.Result:RefreshEntryInfo(resultID, info)
	if not entry then
		dropResultAndRefresh(resultID)
		return
	end
	local isDelisted = entry.info and entry.info.isDelisted == true
	local stateChanged = isDelisted ~= (row._isDelisted == true)
	if not stateChanged or not row.resultIndex then
		return
	end
	self:RepaintRowState(row, entry, row.categoryID)
end

function LR:UpdateRoles(row, entry, categoryID)
	if not (row and row.roles and rowCol(row, "roles")) then
		return
	end
	local index = row.resultIndex
	local resolvedEntry = entry
	if not resolvedEntry and index then
		resolvedEntry = GF.Result:GetEntry(index)
	end
	if not (resolvedEntry and resolvedEntry.info) then
		return
	end
	local enumerate = GF.Result:IsEnumerateMode(GF.Result:GetRoleDisplayMode(resolvedEntry))
	if enumerate and index and not resolvedEntry.players then
		resolvedEntry = GF.Result:GetEntry(index, { loadPlayers = true }) or resolvedEntry
	end
	row._deferRoles = nil
	local resolvedCategory = categoryID or row.categoryID
	GF.RoleDisplay:Update(row.roles, resolvedEntry, resolvedCategory, { disabled = resolvedEntry.info.isDelisted })
	row._titleEntry = resolvedEntry
	row._titleInfo = resolvedEntry.info
	row._resultType = resolveResultType(row, resolvedEntry.info, resolvedEntry)
	row._resultDisplayType = resolveResultDisplayType(row, resolvedEntry.info, resolvedEntry, row._resultType)
	row._typeText = getResultTypeLabel(row._resultDisplayType)
	paintTypeCol(row, rowCol(row, "type"), getTitleDelistedColor(resolvedEntry.info))
	self:UpdateRowBackgrounds(row)
end

function LR:RepaintRowState(row, entry, categoryID)
	local info = entry and entry.info
	if not (row and info) then
		return
	end
	local index = row.resultIndex
	if index and row._metaLeaderText == "?" then
		self:RefreshLeaderColumn(row, index, entry)
	end
	local activityInfo = entry.activity
	local disabledColor = getTitleDelistedColor(info)
	row._titleText = GF.Result:GetListingTitle(info, entry.resultID)
	row._titleEntry = entry
	row._titleInfo = info
	row._resultType = resolveResultType(row, info, entry)
	row._resultDisplayType = resolveResultDisplayType(row, info, entry, row._resultType)
	row._typeText = getResultTypeLabel(row._resultDisplayType)
	row._commentText = GF.Result and GF.Result.GetListingComment
		and GF.Result:GetListingComment(info, entry.resultID) or ""
	local scoreText, scoreColor = GF.Result:GetBrowseScoreDisplay(info, activityInfo, disabledColor)
	row._metaScoreText = scoreText
	local paintOptions = {
		applyColors = true,
		dc = disabledColor,
		scoreColor = scoreColor,
		applyAppState = true,
	}
	paintRowFromCache(row, paintOptions)
	self:SetDelistedState(row, info.isDelisted)
	local roleCategory = categoryID or row.categoryID
	self:UpdateRoles(row, entry, roleCategory)
end

local function resolveActivityName(info, activityInfo)
	if activityInfo then
		return activityInfo.fullName or activityInfo.shortName or ""
	end
	local activityID = info and info.activityIDs and info.activityIDs[1]
	if activityID then
		return C_LFGList.GetActivityFullName(activityID) or ""
	end
	return ""
end

local function updateRolePresentation(row, entry, rowCategory, info, shouldDefer, wantsPlayers)
	local hasRoleColumn = row.roles and rowCol(row, "roles")
	local waitingForPlayers = shouldDefer and wantsPlayers and not entry.players
	row._deferRoles = waitingForPlayers or nil
	if hasRoleColumn and not waitingForPlayers then
		GF.RoleDisplay:Update(row.roles, entry, rowCategory, { disabled = info.isDelisted })
	end
end

local function loadRowEntry(index, suppliedEntry, deferRoles)
	local entry = suppliedEntry or GF.Result:GetEntry(index)
	local wantsPlayers = GF.Result:ShouldLoadPlayersForEntry(entry)
	local mustEnumerateNow = wantsPlayers and entry and not entry.players and not deferRoles
	if mustEnumerateNow then
		entry = GF.Result:GetEntry(index, { loadPlayers = true })
	end
	return entry, wantsPlayers
end

local function cacheListingIdentity(row, entry, info)
	local resultType = resolveResultType(row, info, entry)
	local displayType = resolveResultDisplayType(row, info, entry, resultType)
	row._titleText, row._titleEntry, row._titleInfo =
		GF.Result:GetListingTitle(info, entry.resultID), entry, info
	row._resultType = resultType
	row._resultDisplayType = displayType
	row._typeText = getResultTypeLabel(displayType)
end

function LR:SetData(row, index, categoryID, entry, opts)
	local options = opts or {}
	local rowCat = GF.Result:ResolveRowCategory(index, categoryID)
	local wantsPlayers
	entry, wantsPlayers = loadRowEntry(index, entry, options.deferRoles)
	local info = entry and entry.info
	if not info then
		self:DetachRow(row)
		return false
	end
	row.resultIndex = index
	row.resultID = entry.resultID
	row.categoryID = rowCat

	local tab = GF.FindGroupTab
	local selection = tab and tab.GetSelection and tab:GetSelection()
	local spec = selection and GF.FilterSpec and GF.FilterSpec:ResolveSpec(selection)
	local db = (GF.Filter and GF.Filter.GetGlobalFilters and GF.Filter:GetGlobalFilters(spec)) or GF.GetDB()
	row._hasVoice = (entryHasVoice(info.voiceChat) and db.hideVoice ~= true) or nil

	if not options.skipLayout then
		self:LayoutRow(row, options.layoutW)
	end

	local activityInfo = entry.activity
	local disabledColor = getTitleDelistedColor(info)
	cacheListingIdentity(row, entry, info)
	row._metaILText = tostring(math.floor(info.requiredItemLevel or 0))
	row._commentText = GF.Result and GF.Result.GetListingComment
		and GF.Result:GetListingComment(info, entry.resultID) or ""
	row._activityText = resolveActivityName(info, activityInfo)
	local scoreText, scoreColor = GF.Result:GetBrowseScoreDisplay(info, activityInfo, disabledColor)
	row._metaScoreText = scoreText

	local leader = resolveLeaderPresentation(index, entry)
	if leader.entry then
		entry = leader.entry
		info = entry.info or info
		activityInfo = entry.activity or activityInfo
	end
	row._metaLeaderText = leader.text

	paintRowFromCache(row, {
		applyColors = true,
		dc = disabledColor,
		scoreColor = scoreColor,
		leaderColor = leader.color,
		applyAppState = true,
	})

	if leader.text == "?" then
		self:ScheduleLeaderRetry(row, index)
	end
	updateRolePresentation(row, entry, rowCat, info, options.deferRoles, wantsPlayers)
	local delisted = info.isDelisted
	self:SetDelistedState(row, delisted)
	self:UpdateRowBackgrounds(row)
	local shouldShow = not options.skipShow
	if shouldShow then
		row:Show()
	end
	return true
end
