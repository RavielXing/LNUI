local _, GF = ...



GF.CreatePanel = {}

local CP = GF.CreatePanel

local BB = GF.BlizzardBorrow
local DEFAULT_PLAYSTYLE = Enum.LFGEntryGeneralPlaystyle.Learning

local PLAYSTYLES = {

	{ Enum.LFGEntryGeneralPlaystyle.Learning, "GROUP_FINDER_GENERAL_PLAYSTYLE1" },

	{ Enum.LFGEntryGeneralPlaystyle.FunRelaxed, "GROUP_FINDER_GENERAL_PLAYSTYLE2" },

	{ Enum.LFGEntryGeneralPlaystyle.FunSerious, "GROUP_FINDER_GENERAL_PLAYSTYLE3" },

	{ Enum.LFGEntryGeneralPlaystyle.Expert, "GROUP_FINDER_GENERAL_PLAYSTYLE4" },

}



local function playstyleLabel(styleEnum, globalKey)

	if _G[globalKey] then

		return _G[globalKey]

	end

	return tostring(styleEnum)

end



local function getPlaystyleLabel(styleEnum)

	for _, entry in ipairs(PLAYSTYLES) do

		if entry[1] == styleEnum then

			return playstyleLabel(styleEnum, entry[2])

		end

	end

	return ""

end



local function trimName(text)
	return string.match(text or "", "^%s*(.-)%s*$") or ""
end

-- Blizzard LFGList EntryCreation (LFGList.xml): Name 288×22, Description 283×46
local BLIZZ_NAME_W = 288
local BLIZZ_DESC_W = 283
local BLIZZ_NAME_H = 22
local BLIZZ_DESC_H = 46
-- InputScrollFrame border textures extend 5px outside the frame bounds
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
local CREATE_FORM_INSET_TOP = 8
local CREATE_FORM_ROW_H = 36
local CREATE_FORM_LABEL_W = 76
local CREATE_FORM_LABEL_GAP = 6
local CREATE_FORM_STACK_LABEL_GAP = 5
local CREATE_FORM_STACK_ROW_GAP = 10
local CREATE_FORM_TITLE_SIZE = 14
local CREATE_FORM_INPUT_H = 26
local CREATE_FORM_DESC_H = BLIZZ_DESC_H
local CREATE_FORM_DESC_ATLAS_PAD_Y = 4
local CREATE_FORM_DESC_ATLAS_H = CREATE_FORM_DESC_H + (CREATE_FORM_DESC_ATLAS_PAD_Y * 2)
local CREATE_PLACEHOLDER_LEFT_INSET = 4
local BUTTON_BAR_H = 70
local LIST_BTN_BOTTOM = BUTTON_BAR_H - 5 - 22
local LIST_BTN_RIGHT = GF.CONTENT_SCROLL_INSET_R or 18
local LIST_BTN_W = GF.APPLICANT_MANAGE_BUTTON_W or GF.PANEL_BUTTON_TWO_CHAR_W or 72
local LIST_BTN_GAP = GF.FILTER_FOOTER_BUTTON_GAP or 10
local DROPDOWN_H = 26
local DROPDOWN_LEFT_NUDGE = 0
local REQ_FIELD_LEFT_NUDGE = 3
local CREATE_CHECK_SIZE = 20
local CREATE_CHECK_MARK_SIZE = 16
local CREATE_CHECK_LABEL_GAP = 8
local CREATE_CHECK_ATLAS_TEXTURE = GF.FILTER_CHECK_ATLAS_TEXTURE or "Interface\\AddOns\\GroupFinder\\Art\\UI\\FilterCheckAtlas.png"
local CREATE_DESC_ATLAS_TEXTURE = "Interface\\AddOns\\GroupFinder\\Art\\UI\\InputBoxAtlas.png"
local CREATE_CHECK_ATLAS_INSET_X = 0.5 / 128
local CREATE_CHECK_ATLAS_INSET_Y = 0.5 / 64
local CREATE_DESC_ATLAS_TEXTURE_W = 108
local CREATE_DESC_ATLAS_TEXTURE_H = 216
local CREATE_DESC_ATLAS_STATE_H = 108
local CREATE_DESC_ATLAS_CAP_W = 8
local CREATE_DESC_ATLAS_CAP_SOURCE_W = CREATE_DESC_ATLAS_CAP_W * 2
local CREATE_CHECK_ATLAS_COORDS = {
	checked = { CREATE_CHECK_ATLAS_INSET_X, 0.5 - CREATE_CHECK_ATLAS_INSET_X, CREATE_CHECK_ATLAS_INSET_Y, 1 - CREATE_CHECK_ATLAS_INSET_Y },
	normal = { 0.5 + CREATE_CHECK_ATLAS_INSET_X, 1 - CREATE_CHECK_ATLAS_INSET_X, CREATE_CHECK_ATLAS_INSET_Y, 1 - CREATE_CHECK_ATLAS_INSET_Y },
}
CREATE_CHECK_ATLAS_COORDS.hover = CREATE_CHECK_ATLAS_COORDS.checked
local CREATE_INPUT_ATLAS_COORDS = {
	hover = CREATE_CHECK_ATLAS_COORDS.checked,
	normal = CREATE_CHECK_ATLAS_COORDS.normal,
}
-- Normal state has wider transparent gutters in InputBoxAtlas; crop them to avoid a width jump on hover.
local CREATE_DESC_ATLAS_COORDS = {
	hover = { top = 0, bottom = CREATE_DESC_ATLAS_STATE_H, left = 0, right = CREATE_DESC_ATLAS_TEXTURE_W },
	normal = { top = CREATE_DESC_ATLAS_STATE_H, bottom = CREATE_DESC_ATLAS_TEXTURE_H, left = 3, right = 107 },
}
local CREATE_INPUT_CAP_W = 9
local CREATE_INPUT_LEFT_RATIO = 0.45
local CREATE_INPUT_RIGHT_RATIO = 0.55
local GREEN = "|cff00ff00"
local COLOR_END = "|r"
local CREATE_FIELD_OWNER = "groupfinder"
local CREATE_FIELD_CHANNEL = "entryCreation"

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

local function setCheckHitRectToLabel(check, label)
	if not check or not label or not check.SetHitRectInsets then
		return
	end
	local width = label.GetStringWidth and label:GetStringWidth() or 0
	check:SetHitRectInsets(0, -math.ceil(width + CREATE_CHECK_LABEL_GAP + 4), 0, 0)
end

local function hideRegion(region)
	if not region then
		return
	end
	if region.Hide then
		region:Hide()
	end
	if region.SetAlpha then
		region:SetAlpha(0)
	end
end

local function snapTexture(texture)
	if not texture then
		return
	end
	if texture.SetSnapToPixelGrid then
		texture:SetSnapToPixelGrid(true)
	end
	if texture.SetTexelSnappingBias then
		texture:SetTexelSnappingBias(0)
	end
end

local function hideInputBoxChrome(editBox)
	if not editBox then
		return
	end
	local name = editBox.GetName and editBox:GetName()
	if name then
		for _, region in ipairs({
			_G[name .. "Left"],
			_G[name .. "Middle"],
			_G[name .. "Right"],
			_G[name .. "LeftTexture"],
			_G[name .. "MiddleTexture"],
			_G[name .. "RightTexture"],
		}) do
			hideRegion(region)
		end
	end
	hideRegion(editBox.Left)
	hideRegion(editBox.Middle)
	hideRegion(editBox.Right)
	hideRegion(editBox.LeftTexture)
	hideRegion(editBox.MiddleTexture)
	hideRegion(editBox.RightTexture)
end

local function getInputBoxChromeRegions(editBox)
	if not editBox then
		return {}
	end
	local regions = {}
	local function add(region)
		if region then
			regions[#regions + 1] = region
		end
	end
	local name = editBox.GetName and editBox:GetName()
	if name then
		add(_G[name .. "Left"])
		add(_G[name .. "Middle"])
		add(_G[name .. "Right"])
		add(_G[name .. "LeftTexture"])
		add(_G[name .. "MiddleTexture"])
		add(_G[name .. "RightTexture"])
	end
	add(editBox.Left)
	add(editBox.Middle)
	add(editBox.Right)
	add(editBox.LeftTexture)
	add(editBox.MiddleTexture)
	add(editBox.RightTexture)
	return regions
end

local function hideBorrowedNameChrome(editBox)
	if not editBox then
		return
	end
	if not editBox._gfNameChromeState then
		editBox._gfNameChromeState = {}
		for _, region in ipairs(getInputBoxChromeRegions(editBox)) do
			editBox._gfNameChromeState[region] = {
				shown = not region.IsShown or region:IsShown(),
				alpha = region.GetAlpha and region:GetAlpha() or nil,
			}
		end
	end
	for region in pairs(editBox._gfNameChromeState) do
		hideRegion(region)
	end
end

local function restoreBorrowedNameChrome(editBox)
	local state = editBox and editBox._gfNameChromeState
	if not state then
		return
	end
	for region, info in pairs(state) do
		if info.alpha ~= nil and region.SetAlpha then
			region:SetAlpha(info.alpha)
		end
		if info.shown and region.Show then
			region:Show()
		elseif region.Hide then
			region:Hide()
		end
	end
	editBox._gfNameChromeState = nil
end

local function hideBorrowedWidgetChrome(widget, stateKey)
	if not widget then
		return
	end
	stateKey = stateKey or "_gfBorrowedChromeState"
	if not widget[stateKey] then
		widget[stateKey] = {}
		for _, region in ipairs({ widget:GetRegions() }) do
			if region then
				widget[stateKey][region] = {
					shown = not region.IsShown or region:IsShown(),
					alpha = region.GetAlpha and region:GetAlpha() or nil,
				}
			end
		end
	end
	for region in pairs(widget[stateKey]) do
		hideRegion(region)
	end
end

local function restoreBorrowedWidgetChrome(widget, stateKey)
	stateKey = stateKey or "_gfBorrowedChromeState"
	local state = widget and widget[stateKey]
	if not state then
		return
	end
	for region, info in pairs(state) do
		if info.alpha ~= nil and region.SetAlpha then
			region:SetAlpha(info.alpha)
		end
		if info.shown and region.Show then
			region:Show()
		elseif region.Hide then
			region:Hide()
		end
	end
	widget[stateKey] = nil
end

local function updateCreateInputBox(box)
	if not box or not box._gfCreateInputStyled then
		return
	end
	local enabled = not box.IsEnabled or box:IsEnabled()
	local active = enabled and (box:HasFocus() or box._gfCreateInputHovered)
	local coords = active and CREATE_INPUT_ATLAS_COORDS.hover or CREATE_INPUT_ATLAS_COORDS.normal
	local pieces = box._gfCreateInputAtlas
	if pieces then
		local left, right, top, bottom = coords[1], coords[2], coords[3], coords[4]
		local width = right - left
		local leftU = left + width * CREATE_INPUT_LEFT_RATIO
		local rightU = left + width * CREATE_INPUT_RIGHT_RATIO
		pieces.left:SetTexCoord(left, leftU, top, bottom)
		pieces.middle:SetTexCoord(leftU, rightU, top, bottom)
		pieces.right:SetTexCoord(rightU, right, top, bottom)
		pieces.left:SetVertexColor(1, 1, 1, enabled and 1 or 0.45)
		pieces.middle:SetVertexColor(1, 1, 1, enabled and 1 or 0.45)
		pieces.right:SetVertexColor(1, 1, 1, enabled and 1 or 0.45)
	end
end

local function updateCreateInputAtlasFrame(frame, active, enabled)
	local pieces = frame and frame._gfCreateInputAtlas
	if not pieces then
		return
	end
	enabled = enabled ~= false
	local coords = active and CREATE_INPUT_ATLAS_COORDS.hover or CREATE_INPUT_ATLAS_COORDS.normal
	local left, right, top, bottom = coords[1], coords[2], coords[3], coords[4]
	local width = right - left
	local leftU = left + width * CREATE_INPUT_LEFT_RATIO
	local rightU = left + width * CREATE_INPUT_RIGHT_RATIO
	pieces.left:SetTexCoord(left, leftU, top, bottom)
	pieces.middle:SetTexCoord(leftU, rightU, top, bottom)
	pieces.right:SetTexCoord(rightU, right, top, bottom)
	pieces.left:SetVertexColor(1, 1, 1, enabled and 1 or 0.45)
	pieces.middle:SetVertexColor(1, 1, 1, enabled and 1 or 0.45)
	pieces.right:SetVertexColor(1, 1, 1, enabled and 1 or 0.45)
end

local function updateCreateDescriptionAtlasFrame(frame, active, enabled)
	local pieces = frame and frame._gfCreateDescAtlas
	if not pieces then
		return
	end
	enabled = enabled ~= false
	local state = active and CREATE_DESC_ATLAS_COORDS.hover or CREATE_DESC_ATLAS_COORDS.normal
	local capPx = CREATE_DESC_ATLAS_CAP_SOURCE_W
	local alpha = enabled and 1 or 0.45
	local leftPx = state.left or 0
	local rightPx = state.right or CREATE_DESC_ATLAS_TEXTURE_W
	local leftInnerPx = math.min(leftPx + capPx, rightPx)
	local rightInnerPx = math.max(rightPx - capPx, leftInnerPx)
	local top = state.top / CREATE_DESC_ATLAS_TEXTURE_H
	local bottom = state.bottom / CREATE_DESC_ATLAS_TEXTURE_H
	local leftOuter = leftPx / CREATE_DESC_ATLAS_TEXTURE_W
	local leftInner = leftInnerPx / CREATE_DESC_ATLAS_TEXTURE_W
	local rightInner = rightInnerPx / CREATE_DESC_ATLAS_TEXTURE_W
	local rightOuter = rightPx / CREATE_DESC_ATLAS_TEXTURE_W

	pieces.left:SetTexCoord(leftOuter, leftInner, top, bottom)
	pieces.middle:SetTexCoord(leftInner, rightInner, top, bottom)
	pieces.right:SetTexCoord(rightInner, rightOuter, top, bottom)
	pieces.left:SetVertexColor(1, 1, 1, alpha)
	pieces.middle:SetVertexColor(1, 1, 1, alpha)
	pieces.right:SetVertexColor(1, 1, 1, alpha)
end

local function styleCreateInputAtlasFrame(frame)
	if not frame then
		return frame
	end
	if not frame._gfCreateInputAtlas then
		local left = frame:CreateTexture(nil, "BACKGROUND", nil, -6)
		left:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
		left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
		left:SetWidth(CREATE_INPUT_CAP_W)
		left:SetTexture(CREATE_CHECK_ATLAS_TEXTURE)
		snapTexture(left)

		local right = frame:CreateTexture(nil, "BACKGROUND", nil, -6)
		right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
		right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
		right:SetWidth(CREATE_INPUT_CAP_W)
		right:SetTexture(CREATE_CHECK_ATLAS_TEXTURE)
		snapTexture(right)

		local middle = frame:CreateTexture(nil, "BACKGROUND", nil, -6)
		middle:SetPoint("TOPLEFT", left, "TOPRIGHT", 0, 0)
		middle:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT", 0, 0)
		middle:SetTexture(CREATE_CHECK_ATLAS_TEXTURE)
		snapTexture(middle)

		frame._gfCreateInputAtlas = {
			left = left,
			middle = middle,
			right = right,
		}
	end
	updateCreateInputAtlasFrame(frame, false, true)
	return frame
end

local function styleCreateDescriptionAtlasFrame(frame)
	if not frame then
		return frame
	end
	if not frame._gfCreateDescAtlas then
		local left = frame:CreateTexture(nil, "BACKGROUND", nil, -6)
		left:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
		left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
		left:SetWidth(CREATE_DESC_ATLAS_CAP_W)
		left:SetTexture(CREATE_DESC_ATLAS_TEXTURE)
		snapTexture(left)

		local right = frame:CreateTexture(nil, "BACKGROUND", nil, -6)
		right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
		right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
		right:SetWidth(CREATE_DESC_ATLAS_CAP_W)
		right:SetTexture(CREATE_DESC_ATLAS_TEXTURE)
		snapTexture(right)

		local middle = frame:CreateTexture(nil, "BACKGROUND", nil, -6)
		middle:SetPoint("TOPLEFT", left, "TOPRIGHT", 0, 0)
		middle:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT", 0, 0)
		middle:SetTexture(CREATE_DESC_ATLAS_TEXTURE)
		snapTexture(middle)

		frame._gfCreateDescAtlas = {
			left = left,
			middle = middle,
			right = right,
		}
	end
	updateCreateDescriptionAtlasFrame(frame, false, true)
	return frame
end

local function isDescriptionEnabled(descFrame)
	if not descFrame then
		return false
	end
	if descFrame.IsEnabled and not descFrame:IsEnabled() then
		return false
	end
	local editBox = descFrame.EditBox
	if editBox and editBox.IsEnabled and not editBox:IsEnabled() then
		return false
	end
	return true
end

local function updateBorrowedDescriptionAtlas(descFrame)
	local enabled = isDescriptionEnabled(descFrame)
	local editBox = descFrame and descFrame.EditBox
	local active = enabled and ((editBox and editBox.HasFocus and editBox:HasFocus()) or descFrame._gfCreateDescHovered)
	updateCreateDescriptionAtlasFrame(CP.descAtlasAnchor, active, enabled)
end

local function setCreateInputHovered(box, hovered)
	if not box then
		return
	end
	box._gfCreateInputHovered = hovered
	updateCreateInputBox(box)
end

local function styleCreateInputBox(box)
	if not box then
		return box
	end
	if box.SetTextInsets then
		box:SetTextInsets(6, 6, 0, 0)
	end
	box:SetTextColor(1, 0.92, 0.64, 1)
	box:SetShadowColor(0, 0, 0, 0.85)
	box:SetShadowOffset(1, -1)
	hideInputBoxChrome(box)
	if not box._gfCreateInputStyled then
		local left = box:CreateTexture(nil, "BACKGROUND", nil, -6)
		left:SetPoint("TOPLEFT", box, "TOPLEFT", 0, 0)
		left:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", 0, 0)
		left:SetWidth(CREATE_INPUT_CAP_W)
		left:SetTexture(CREATE_CHECK_ATLAS_TEXTURE)
		snapTexture(left)

		local right = box:CreateTexture(nil, "BACKGROUND", nil, -6)
		right:SetPoint("TOPRIGHT", box, "TOPRIGHT", 0, 0)
		right:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", 0, 0)
		right:SetWidth(CREATE_INPUT_CAP_W)
		right:SetTexture(CREATE_CHECK_ATLAS_TEXTURE)
		snapTexture(right)

		local middle = box:CreateTexture(nil, "BACKGROUND", nil, -6)
		middle:SetPoint("TOPLEFT", left, "TOPRIGHT", 0, 0)
		middle:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT", 0, 0)
		middle:SetTexture(CREATE_CHECK_ATLAS_TEXTURE)
		snapTexture(middle)

		box._gfCreateInputAtlas = {
			left = left,
			middle = middle,
			right = right,
		}
		box:HookScript("OnEditFocusGained", updateCreateInputBox)
		box:HookScript("OnEditFocusLost", updateCreateInputBox)
		box:HookScript("OnShow", updateCreateInputBox)
		box:HookScript("OnEnable", updateCreateInputBox)
		box:HookScript("OnDisable", updateCreateInputBox)
		box:HookScript("OnEnter", function(self)
			setCreateInputHovered(self, true)
		end)
		box:HookScript("OnLeave", function(self)
			setCreateInputHovered(self, false)
		end)
		box._gfCreateInputStyled = true
	end
	updateCreateInputBox(box)
	return box
end

local function hideCheckButtonChrome(cb)
	hideRegion(cb and cb.GetNormalTexture and cb:GetNormalTexture())
	hideRegion(cb and cb.GetPushedTexture and cb:GetPushedTexture())
	hideRegion(cb and cb.GetHighlightTexture and cb:GetHighlightTexture())
	hideRegion(cb and cb.GetCheckedTexture and cb:GetCheckedTexture())
	hideRegion(cb and cb.GetDisabledTexture and cb:GetDisabledTexture())
	hideRegion(cb and cb.GetDisabledCheckedTexture and cb:GetDisabledCheckedTexture())
end

local function updateCreateCheckButton(cb)
	if not cb or not cb._gfCreateCheckStyled then
		return
	end
	local enabled = not cb.IsEnabled or cb:IsEnabled()
	local checked = cb:GetChecked()
	local coords = CREATE_CHECK_ATLAS_COORDS.normal
	if checked then
		coords = CREATE_CHECK_ATLAS_COORDS.checked
	elseif cb._gfCreateCheckHovered then
		coords = CREATE_CHECK_ATLAS_COORDS.hover
	end
	if cb._gfCreateCheckAtlas then
		cb._gfCreateCheckAtlas:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
		cb._gfCreateCheckAtlas:SetVertexColor(1, 1, 1, enabled and 1 or 0.45)
	end
	if cb._gfCreateCheckMark then
		cb._gfCreateCheckMark:SetShown(checked == true)
		cb._gfCreateCheckMark:SetVertexColor(1, 0.86, 0.28, enabled and 1 or 0.45)
	end
end

local function setCreateCheckHovered(cb, hovered)
	if not cb then
		return
	end
	cb._gfCreateCheckHovered = hovered
	updateCreateCheckButton(cb)
end

local function styleCreateCheckButton(cb)
	if not cb then
		return cb
	end
	cb:SetSize(CREATE_CHECK_SIZE, CREATE_CHECK_SIZE)
	hideCheckButtonChrome(cb)
	if not cb._gfCreateCheckStyled then
		local atlas = cb:CreateTexture(nil, "BORDER", nil, -6)
		atlas:SetAllPoints(cb)
		atlas:SetTexture(CREATE_CHECK_ATLAS_TEXTURE)
		snapTexture(atlas)
		cb._gfCreateCheckAtlas = atlas

		local mark = cb:CreateTexture(nil, "ARTWORK")
		mark:SetPoint("CENTER", cb, "CENTER", 0, 0)
		mark:SetSize(CREATE_CHECK_MARK_SIZE, CREATE_CHECK_MARK_SIZE)
		mark:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
		snapTexture(mark)
		cb._gfCreateCheckMark = mark

		cb._gfOrigSetChecked = cb.SetChecked
		cb.SetChecked = function(self, checked, ...)
			self:_gfOrigSetChecked(checked, ...)
			updateCreateCheckButton(self)
		end
		cb:HookScript("OnClick", updateCreateCheckButton)
		cb:HookScript("OnShow", updateCreateCheckButton)
		cb:HookScript("OnEnable", updateCreateCheckButton)
		cb:HookScript("OnDisable", updateCreateCheckButton)
		cb:HookScript("OnEnter", function(self)
			setCreateCheckHovered(self, true)
		end)
		cb:HookScript("OnLeave", function(self)
			setCreateCheckHovered(self, false)
		end)
		cb._gfCreateCheckStyled = true
	end
	updateCreateCheckButton(cb)
	return cb
end

local function applyCreateTitleTextStyle(fs)
	if not fs then
		return
	end
	fs._gfFontSizeOverride = CREATE_FORM_TITLE_SIZE
	if GF.Font and GF.Font.ApplyToFontString then
		GF.Font.ApplyToFontString(fs, fs._gfFontTemplate or "GameFontNormal")
	end
end

local function getCreateDrawerFooter(parent)
	return parent and parent._gfCreateDrawerFooter
end

local function createDrawerScrollInsetR()
	return (GF.CONTENT_SCROLL_INSET_R or 18) + 2
end

local function createDrawerScrollBarOffsetX(scrollInsetR)
	return math.max(
		0,
		(scrollInsetR or createDrawerScrollInsetR())
			- (GF.FILTER_SCROLLBAR_RIGHT_INSET or 4)
			- (GF.FILTER_SCROLLBAR_WIDTH or 8)
	)
end

local function anchorCreateDrawerScrollBar(scroll, bar, offsetX)
	if not scroll or not bar then
		return
	end
	if bar.SetWidth then
		bar:SetWidth(GF.FILTER_SCROLLBAR_WIDTH or 8)
	end
	bar:ClearAllPoints()
	bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", offsetX, -(GF.FILTER_SCROLLBAR_TOP_INSET or 4))
	bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", offsetX, GF.FILTER_SCROLLBAR_BOTTOM_INSET or 4)
end

local function restoreNativeInstructions(editBox)
	local ins = editBox and editBox.Instructions
	if not ins then
		return
	end
	if ins._gfOriginalShow then
		ins.Show = ins._gfOriginalShow
		ins._gfOriginalShow = nil
	end
	editBox._gfUseCreatePlaceholder = nil
end

local function suppressNativeInstructions(editBox)
	local ins = editBox and editBox.Instructions
	if not ins then
		return
	end
	if not ins._gfOriginalShow then
		ins._gfOriginalShow = ins.Show
	end
	ins:Hide()
	ins.Show = function() end
	editBox._gfUseCreatePlaceholder = true
end

local function resolveActivityID(node)
	if GF.NavData and GF.NavData.ResolveCreateActivityID then
		return GF.NavData.ResolveCreateActivityID(node)
	end
	return nil
end

local function getEntryCreation()
	return LFGListFrame and LFGListFrame.EntryCreation
end

local function isLfgFrameVisible()
	return LFGListFrame and LFGListFrame.IsVisible and LFGListFrame:IsVisible()
end

local function isCreateDrawerFieldSurfaceActive()
	local drawer = GF.CreateDrawer
	return drawer and drawer.open == true
end

local function isBlizzardEntryCreationPanelActive()
	local lfg = LFGListFrame
	if not lfg or not lfg.IsVisible or not lfg:IsVisible() then
		return false
	end
	local ec = lfg.EntryCreation
	return ec and lfg.activePanel == ec
end

-- 兼容旧名：以 activePanel 为准，不要求 ec:IsShown()（ec 被 Hide 时仍算占用）
local function isBlizzardCreateActive()
	return isBlizzardEntryCreationPanelActive()
end

local function areCreateFieldsExternallyOwned()
	local ec = getEntryCreation()
	if not ec then
		return false
	end
	local embedParent = CP and CP.GetEmbedParent and CP:GetEmbedParent()
	local sink = BB and BB.GetHideSink and BB.GetHideSink()
	local function externallyOwned(widget)
		if not widget or not widget.GetParent then
			return false
		end
		local parent = widget:GetParent()
		if parent == ec or parent == embedParent or parent == sink then
			return false
		end
		return parent ~= nil
	end
	return externallyOwned(ec.Name) or externallyOwned(ec.Description)
end

local function isCreateChannelBlocked()
	if not isCreateDrawerFieldSurfaceActive() then
		return false
	end
	if isLfgFrameVisible() then
		return true
	end
	if isBlizzardCreateActive() then
		return true
	end
	return areCreateFieldsExternallyOwned()
end

local function isCreateChannelOccupiedForAutoOpen()
	return isLfgFrameVisible() or isBlizzardCreateActive() or areCreateFieldsExternallyOwned()
end

function CP:IsCreateChannelAutoOpenBlocked()
	return isCreateChannelOccupiedForAutoOpen()
end

local function syncEditInstructions(editBox)
	if not editBox then
		return
	end
	if editBox._gfUseCreatePlaceholder then
		suppressNativeInstructions(editBox)
		return
	end
	if InputBoxInstructions_OnTextChanged then
		InputBoxInstructions_OnTextChanged(editBox)
		return
	end
	local ins = editBox.Instructions
	if not ins then
		return
	end
	if ins._gfOriginalShow then
		ins.Show = ins._gfOriginalShow
		ins._gfOriginalShow = nil
	end
	local text = editBox:GetText()
	if issecretvalue and issecretvalue(text) then
		ins:Hide()
	elseif text and trimName(text) ~= "" then
		ins:Hide()
	else
		ins:Show()
	end
end

local function restoreNameInstructions(nameEdit)
	if not nameEdit then
		return
	end
	restoreNativeInstructions(nameEdit)
	local ins = nameEdit.Instructions
	if ins then
		ins:ClearAllPoints()
		ins:SetPoint("LEFT", nameEdit, "LEFT", 8, 0)
		ins:SetPoint("RIGHT", nameEdit, "RIGHT", -4, 0)
	end
	syncEditInstructions(nameEdit)
end

local function ensureScrollingEditInitialized(editBox)
	if not editBox or not ScrollingEdit_SetCursorOffsets then
		return
	end
	if editBox.cursorOffset == nil or editBox.cursorHeight == nil then
		ScrollingEdit_SetCursorOffsets(editBox, 0, editBox.cursorHeight or 15)
	end
end

local function syncDescriptionEditBoxWidth(descFrame)
	local editBox = descFrame and descFrame.EditBox
	if not editBox or not descFrame.GetWidth then
		return
	end
	local width = descFrame:GetWidth() or 0
	if width <= 0 then
		return
	end
	local scrollBarReserve = descFrame.ScrollBar and descFrame.ScrollBar:IsShown() and 16 or 10
	editBox:SetWidth(math.max(width - scrollBarReserve, 1))
	if InputScrollFrame_OnTextChanged then
		pcall(InputScrollFrame_OnTextChanged, editBox, false)
	end
end

local function syncDescriptionInstructions(descFrame)
	if not descFrame or not descFrame.EditBox then
		return
	end
	syncEditInstructions(descFrame.EditBox)
end

local function safeDescriptionTextChanged(descEdit, isUserInput)
	if not descEdit then
		return
	end
	ensureScrollingEditInitialized(descEdit)
	if InputScrollFrame_OnTextChanged then
		pcall(InputScrollFrame_OnTextChanged, descEdit, isUserInput)
	end
	syncEditInstructions(descEdit)
	if CP and CP.UpdateCustomPlaceholders then
		CP:UpdateCustomPlaceholders()
	end
end

function CP:SyncEmbeddedFieldChrome(ec)
	ec = ec or getEntryCreation()
	if not ec then
		return
	end
	syncEditInstructions(ec.Name)
	syncDescriptionInstructions(ec.Description)
	syncEditInstructions(self.voiceEdit)
	self:UpdateCustomPlaceholders()
end

local function syncVoiceToBlizzard(voiceEdit)
	local ec = getEntryCreation()
	local vc = ec and ec.VoiceChat
	local blizzEdit = vc and vc.EditBox
	if not voiceEdit or not blizzEdit or not blizzEdit.SetText then
		return
	end
	local text = voiceEdit:GetText()
	if issecretvalue and issecretvalue(text) then
		return
	end
	text = text or ""
	pcall(blizzEdit.SetText, blizzEdit, text)
	if vc.CheckButton and vc.CheckButton.SetChecked then
		vc.CheckButton:SetChecked(text ~= "")
	end
end

local function neutralizeWidget(widget, suppressedList)
	if not widget or widget._gfSuppressed then
		return
	end
	BB.CacheLayout(widget)
	widget:SetParent(BB.GetHideSink())
	widget:ClearAllPoints()
	widget:Hide()
	widget._gfOriginalShow = widget.Show
	widget.Show = nop
	widget._gfSuppressed = true
	if suppressedList then
		suppressedList[#suppressedList + 1] = widget
	end
end

local function restoreSuppressedWidgets(suppressedList, revealWidgets)
	for _, widget in ipairs(suppressedList or {}) do
		if widget._gfSuppressed then
			widget.Show = widget._gfOriginalShow or widget.Show
			widget._gfOriginalShow = nil
			widget._gfSuppressed = nil
			BB.RestoreLayout(widget)
			if revealWidgets then
				widget:Show()
			else
				widget:Hide()
			end
		end
	end
end

local BLIZZARD_DUPLICATE_KEYS = {
	"PlayStyleDropdown",
	"ItemLevel",
	"MythicPlusRating",
	"PvpItemLevel",
	"PVPRating",
	"VoiceChat",
	"PrivateGroup",
	"CrossFactionGroup",
	"GroupDropdown",
	"ActivityDropdown",
	"ActivityFinder",
}

local function suppressBlizzardDuplicateWidgets(ec, suppressedList)
	if not ec then
		return
	end
	for _, key in ipairs(BLIZZARD_DUPLICATE_KEYS) do
		neutralizeWidget(ec[key], suppressedList)
	end
end

local function suppressEntryCreationChrome(ec, suppressedList)
	if not ec then
		return
	end
	if ec.NameLabel then
		ec.NameLabel:Hide()
	end
	if ec.DescriptionLabel then
		ec.DescriptionLabel:Hide()
	end
	suppressBlizzardDuplicateWidgets(ec, suppressedList)
	ec:Hide()
end

local function restoreEntryCreationLabels(ec)
	if not ec then
		return
	end
	if ec.NameLabel then
		ec.NameLabel:Show()
	end
	if ec.DescriptionLabel then
		ec.DescriptionLabel:Show()
	end
end

local function shouldRevealEntryCreationAfterRelease()
	if not isLfgFrameVisible() then
		return false
	end
	local lfg = LFGListFrame
	local ec = getEntryCreation()
	return ec and lfg.activePanel == ec
end

local function normalizeEntryCreationVisibility()
	local lfg = LFGListFrame
	local ec = getEntryCreation()
	if not lfg or not ec then
		return
	end
	if lfg.activePanel ~= ec then
		ec:Hide()
	end
end

local function revealWidgetsForRelease(reason)
	if reason == "blizzard" or reason == "addon" then
		return true
	end
	return false
end

local function finishEntryCreationVisibility(ec, reason)
	if not ec then
		return
	end
	if reason == "addon" or reason == "blizzard" then
		if shouldRevealEntryCreationAfterRelease() then
			ec:Show()
		else
			ec:Hide()
		end
	else
		ec:Hide()
	end
end

local function restoreBlizzardEntryCreationShell(ec, panel, revealWidgets)
	if not ec then
		return
	end
	if panel then
		restoreSuppressedWidgets(panel._suppressedWidgets, revealWidgets)
		panel._suppressedWidgets = {}
	end
	if revealWidgets then
		restoreEntryCreationLabels(ec)
		if ec.Name and ec.Name:GetParent() == ec then
			restoreNameInstructions(ec.Name)
			ec.Name:Show()
		end
		if ec.Description and ec.Description:GetParent() == ec then
			ec.Description:Show()
		end
	else
		if ec.NameLabel then
			ec.NameLabel:Hide()
		end
		if ec.DescriptionLabel then
			ec.DescriptionLabel:Hide()
		end
		if ec.Name and ec.Name:GetParent() == ec then
			ec.Name:Hide()
		end
		if ec.Description and ec.Description:GetParent() == ec then
			ec.Description:Hide()
		end
	end
end

local function restoreEntryCreationToBlizzard(ec, panel)
	if not ec then
		return
	end
	local embedParent = panel and panel.GetEmbedParent and panel:GetEmbedParent()
	if ec.Name then
		if embedParent and ec.Name:GetParent() == embedParent then
			restoreBorrowedNameChrome(ec.Name)
			BB.RestoreLayout(ec.Name)
			BB.ClearBorrowed(ec.Name, CREATE_FIELD_OWNER, CREATE_FIELD_CHANNEL)
		end
		if ec.Name:GetParent() == ec then
			restoreBorrowedNameChrome(ec.Name)
			restoreNameInstructions(ec.Name)
			ec.Name:Show()
		end
	end
	if ec.Description then
		if embedParent and ec.Description:GetParent() == embedParent then
			if ec.Description.EditBox then
				restoreNativeInstructions(ec.Description.EditBox)
			end
			restoreBorrowedWidgetChrome(ec.Description, "_gfDescriptionChromeState")
			BB.RestoreLayout(ec.Description)
			BB.ClearBorrowed(ec.Description, CREATE_FIELD_OWNER, CREATE_FIELD_CHANNEL)
		end
		if ec.Description:GetParent() == ec then
			ec.Description:Show()
		end
	end
	restoreBlizzardEntryCreationShell(ec, panel, true)
end

local function precacheEntryCreationLayouts()
	local ec = getEntryCreation()
	if not ec then
		return
	end
	if ec.Name then
		BB.CacheLayout(ec.Name)
	end
	if ec.Description then
		BB.CacheLayout(ec.Description)
	end
	if ec.VoiceChat then
		BB.CacheLayout(ec.VoiceChat)
	end
	for _, key in ipairs(BLIZZARD_DUPLICATE_KEYS) do
		if ec[key] then
			BB.CacheLayout(ec[key])
		end
	end
end

function CP:GetCreateFieldWidths()
	local scrollW = self.scroll and self.scroll:GetWidth() or 0
	if not scrollW or scrollW <= 0 then
		return BLIZZ_NAME_W, BLIZZ_DESC_W
	end
	local avail = math.floor(scrollW)
	if avail <= 0 then
		return BLIZZ_NAME_W, BLIZZ_DESC_W
	end
	return avail, avail
end

function CP:GetCreateColumnWidth()
	local scrollW = self.scroll and self.scroll:GetWidth() or 0
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

local function isEmptyEditText(editBox)
	if not editBox or not editBox.GetText then
		return true
	end
	local text = editBox:GetText()
	if issecretvalue and issecretvalue(text) then
		return false
	end
	return trimName(text) == ""
end

function CP:LayoutCustomPlaceholders()
	if self.namePlaceholder and (self.nameEdit or self.nameAnchor) then
		if self.nameEdit and self.namePlaceholder.SetParent then
			self.namePlaceholder:SetParent(self.nameEdit)
		end
		local anchor = self.nameEdit or self.nameAnchor
		self.namePlaceholder:ClearAllPoints()
		self.namePlaceholder:SetPoint("LEFT", anchor, "LEFT", CREATE_PLACEHOLDER_LEFT_INSET, 0)
		self.namePlaceholder:SetPoint("RIGHT", anchor, "RIGHT", -6, 0)
	end
	if self.descPlaceholder and (self.commentScroll or self.descAnchor) then
		if self.commentScroll and self.descPlaceholder.SetParent then
			self.descPlaceholder:SetParent(self.commentScroll)
		end
		local anchor = self.commentScroll or self.descAnchor
		self.descPlaceholder:ClearAllPoints()
		self.descPlaceholder:SetPoint("TOPLEFT", anchor, "TOPLEFT", CREATE_PLACEHOLDER_LEFT_INSET, -6)
		self.descPlaceholder:SetPoint("RIGHT", anchor, "RIGHT", -6, 0)
	end
end

function CP:UpdateCustomPlaceholders()
	local L = GF.L or {}
	if self.namePlaceholder then
		self.namePlaceholder:SetText(L.CREATE_NAME_PLACEHOLDER or "请输入队伍名称")
		self.namePlaceholder:SetShown(self.nameEdit ~= nil and isEmptyEditText(self.nameEdit))
	end
	local descEdit = self.commentScroll and self.commentScroll.EditBox
	if self.descPlaceholder then
		self.descPlaceholder:SetText(L.CREATE_COMMENT_PLACEHOLDER or "请输入关于你的队伍的更多细节（可选）")
		self.descPlaceholder:SetShown(descEdit ~= nil and isEmptyEditText(descEdit))
	end
end

function CP:UpdateFieldLayout()
	local nameW, descW = self:GetCreateFieldWidths()
	local nativeNameW = math.max(nameW - (FIELD_EDGE_PAD * 2), 1)
	local nativeDescW = math.max(descW - (FIELD_EDGE_PAD * 2), 1)

	if self.nameAnchor then
		self.nameAnchor:SetSize(nativeNameW, CREATE_FORM_INPUT_H)
	end
	if self.nameAtlasAnchor then
		self.nameAtlasAnchor:SetSize(nameW, CREATE_FORM_INPUT_H)
		styleCreateInputAtlasFrame(self.nameAtlasAnchor)
	end
	if self.descAnchor then
		self.descAnchor:SetSize(nativeDescW, CREATE_FORM_DESC_H)
	end
	if self.descAtlasAnchor then
		self.descAtlasAnchor:SetSize(descW, CREATE_FORM_DESC_ATLAS_H)
		styleCreateDescriptionAtlasFrame(self.descAtlasAnchor)
	end

	self:ApplyPlaystyleDropdownLayout()

	if self._attached and self:IsBorrowingBlizzardFields() then
		local ec = getEntryCreation()
		local embedParent = self:GetEmbedParent()
		if ec and embedParent then
			if ec.Name and self.nameAnchor then
				BB.EmbedFill(ec.Name, embedParent, self.nameAnchor, nativeNameW, CREATE_FORM_INPUT_H)
				BB.MarkBorrowed(ec.Name, CREATE_FIELD_OWNER, CREATE_FIELD_CHANNEL)
				hideBorrowedNameChrome(ec.Name)
				if not ec.Name._gfCreateNameAtlasHooked then
					ec.Name:HookScript("OnEditFocusGained", function()
						local enabled = not ec.Name.IsEnabled or ec.Name:IsEnabled()
						updateCreateInputAtlasFrame(CP.nameAtlasAnchor, enabled, enabled)
					end)
					ec.Name:HookScript("OnEditFocusLost", function()
						local enabled = not ec.Name.IsEnabled or ec.Name:IsEnabled()
						updateCreateInputAtlasFrame(CP.nameAtlasAnchor, ec.Name._gfCreateNameHovered and enabled, enabled)
					end)
					ec.Name:HookScript("OnEnter", function()
						ec.Name._gfCreateNameHovered = true
						local enabled = not ec.Name.IsEnabled or ec.Name:IsEnabled()
						updateCreateInputAtlasFrame(CP.nameAtlasAnchor, enabled, enabled)
					end)
					ec.Name:HookScript("OnLeave", function()
						ec.Name._gfCreateNameHovered = false
						local enabled = not ec.Name.IsEnabled or ec.Name:IsEnabled()
						updateCreateInputAtlasFrame(CP.nameAtlasAnchor, ec.Name:HasFocus() and enabled, enabled)
					end)
					ec.Name:HookScript("OnEnable", function()
						updateCreateInputAtlasFrame(CP.nameAtlasAnchor, ec.Name:HasFocus() or ec.Name._gfCreateNameHovered, true)
					end)
					ec.Name:HookScript("OnDisable", function()
						updateCreateInputAtlasFrame(CP.nameAtlasAnchor, false, false)
					end)
					ec.Name._gfCreateNameAtlasHooked = true
				end
				local enabled = not ec.Name.IsEnabled or ec.Name:IsEnabled()
				updateCreateInputAtlasFrame(self.nameAtlasAnchor, enabled and (ec.Name:HasFocus() or ec.Name._gfCreateNameHovered), enabled)
				suppressNativeInstructions(ec.Name)
			end
			if ec.Description and self.descAnchor then
				BB.EmbedFill(ec.Description, embedParent, self.descAnchor, nativeDescW, CREATE_FORM_DESC_H)
				BB.MarkBorrowed(ec.Description, CREATE_FIELD_OWNER, CREATE_FIELD_CHANNEL)
				hideBorrowedWidgetChrome(ec.Description, "_gfDescriptionChromeState")
				if not ec.Description._gfCreateDescAtlasHooked then
					ec.Description:HookScript("OnEnter", function()
						ec.Description._gfCreateDescHovered = true
						updateBorrowedDescriptionAtlas(ec.Description)
					end)
					ec.Description:HookScript("OnLeave", function()
						ec.Description._gfCreateDescHovered = false
						updateBorrowedDescriptionAtlas(ec.Description)
					end)
					if ec.Description.EditBox then
						ec.Description.EditBox:HookScript("OnEditFocusGained", function()
							updateBorrowedDescriptionAtlas(ec.Description)
						end)
						ec.Description.EditBox:HookScript("OnEditFocusLost", function()
							updateBorrowedDescriptionAtlas(ec.Description)
						end)
						ec.Description.EditBox:HookScript("OnEnable", function()
							updateBorrowedDescriptionAtlas(ec.Description)
						end)
						ec.Description.EditBox:HookScript("OnDisable", function()
							updateBorrowedDescriptionAtlas(ec.Description)
						end)
					end
					ec.Description._gfCreateDescAtlasHooked = true
				end
				if ec.Description.EditBox then
					ensureScrollingEditInitialized(ec.Description.EditBox)
					syncDescriptionEditBoxWidth(ec.Description)
					suppressNativeInstructions(ec.Description.EditBox)
				end
				updateBorrowedDescriptionAtlas(ec.Description)
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
	if not getCreateDrawerFooter(self.parent) then
		return false
	end
	local colW, colGap, fullW = self:GetCreateColumnWidth()
	if not colW then
		return false
	end
	local rowY = 0
	local rowH = CREATE_FORM_TITLE_SIZE + CREATE_FORM_STACK_LABEL_GAP + CREATE_FORM_INPUT_H + CREATE_FORM_STACK_ROW_GAP
	local rightX = colW + colGap

	local function placeField(label, anchor, x, y, w, controlHeight, sideInset)
		if not label or not anchor then
			return
		end
		sideInset = sideInset or 0
		controlHeight = controlHeight or CREATE_FORM_INPUT_H
		label:ClearAllPoints()
		label:SetPoint("TOPLEFT", self.formColumn, "TOPLEFT", x, -y)
		label:SetWidth(w)
		label:SetJustifyH("LEFT")
		anchor:ClearAllPoints()
		anchor:SetSize(math.max(w - (sideInset * 2), 1), controlHeight)
		anchor:SetPoint("TOPLEFT", self.formColumn, "TOPLEFT", x + sideInset, -y - CREATE_FORM_TITLE_SIZE - CREATE_FORM_STACK_LABEL_GAP)
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

	placeField(self.nameLabel, self.nameAtlasAnchor, 0, rowY, fullW, CREATE_FORM_INPUT_H)
	if self.nameAnchor and self.nameAtlasAnchor then
		self.nameAnchor:ClearAllPoints()
		self.nameAnchor:SetPoint("TOPLEFT", self.nameAtlasAnchor, "TOPLEFT", FIELD_EDGE_PAD, 0)
		self.nameAnchor:SetSize(math.max(fullW - (FIELD_EDGE_PAD * 2), 1), CREATE_FORM_INPUT_H)
	end
	rowY = rowY + CREATE_FORM_TITLE_SIZE + CREATE_FORM_STACK_LABEL_GAP + CREATE_FORM_INPUT_H + CREATE_FORM_STACK_ROW_GAP

	placeField(self.commentLabel, self.descAtlasAnchor, 0, rowY, fullW, CREATE_FORM_DESC_ATLAS_H)
	if self.descAnchor and self.descAtlasAnchor then
		self.descAnchor:ClearAllPoints()
		self.descAnchor:SetPoint("TOPLEFT", self.descAtlasAnchor, "TOPLEFT", FIELD_EDGE_PAD, -CREATE_FORM_DESC_ATLAS_PAD_Y)
		self.descAnchor:SetSize(math.max(fullW - (FIELD_EDGE_PAD * 2), 1), CREATE_FORM_DESC_H)
	end
	rowY = rowY + CREATE_FORM_TITLE_SIZE + CREATE_FORM_STACK_LABEL_GAP + CREATE_FORM_DESC_ATLAS_H + CREATE_FORM_STACK_ROW_GAP

	placeField(self.playLabel, self.playDropdownAnchor, 0, rowY, colW, CREATE_FORM_INPUT_H)
	placeField(self.ilvlLabel, self.ilvlAnchor, rightX, rowY, colW, CREATE_FORM_INPUT_H)
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
	local leftCheckUsed = placeCheckbox(self.crossFactionCheck, self.crossFactionLabel, 0, rowY, colW)
	if leftCheckUsed then
		hasCheck = true
	end
	local privateX = leftCheckUsed and rightX or 0
	if placeCheckbox(self.privateCheck, self.privateLabel, privateX, rowY, colW) then
		hasCheck = true
	end
	if hasCheck then
		rowY = rowY + CREATE_FORM_ROW_H
	end

	self._compactFormHeight = rowY
	self:ApplyPlaystyleDropdownLayout()
	self:LayoutCustomPlaceholders()
	return true
end

function CP:ApplyCompactRowLayout()
	if not self.formColumn then
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
	if not self.ilvlAnchor or not self.voiceLabel or not self.voiceAnchor or not self.formColumn then
		return
	end
	self:ApplyCompactRowLayout()
	self:UpdateScrollLayout()
end

function CP:GetEmbedParent()
	return self.formBody or self.parent
end

function CP:MeasureFormBodyHeight()
	if self._compactFormHeight and self._compactFormHeight > 0 then
		return math.max(self._compactFormHeight + CONTENT_PAD, 100)
	end
	local head = self.nameLabel
	local foot = self.privateCheck or self.privateLabel or self.voiceAnchor
	if not self.formBody or not head or not foot then
		return 100
	end
	local _, headBottom, _, headH = head:GetRect()
	local _, footBottom = foot:GetRect()
	if not headBottom or not footBottom or not headH or headH <= 0 then
		return 100
	end
	local contentH = (headBottom + headH) - footBottom
	if contentH <= 0 then
		return 100
	end
	return math.max(contentH + CONTENT_PAD, 100)
end

function CP:CancelUpdateScrollLayoutDebounce()
	if self._scrollLayoutDebounce and self._scrollLayoutDebounce.Cancel then
		self._scrollLayoutDebounce:Cancel()
	end
	self._scrollLayoutDebounce = nil
end

function CP:ScheduleUpdateScrollLayout()
	if self.parent and not self.parent:IsShown() then
		return
	end
	self:CancelUpdateScrollLayoutDebounce()
	if not C_Timer or not C_Timer.After then
		self:UpdateScrollLayout()
		return
	end
	self._scrollLayoutDebounce = C_Timer.After(GF.LAYOUT_RESIZE_DEBOUNCE or 0.1, function()
		self._scrollLayoutDebounce = nil
		CP:UpdateScrollLayout()
	end)
end

function CP:UpdateScrollLayout()
	if not self.scroll or not self.formBody or not self.parent then
		return
	end
	if not self.parent:IsShown() then
		return
	end
	local scrollW = self.scroll:GetWidth()
	if scrollW and scrollW > 0 then
		self.formBody:SetWidth(scrollW)
	end
	if self._frameResizing or GF._frameResizing then
		return
	end
	self:ApplyCompactRowLayout()
	self:UpdateFieldLayout()
	local formH = self:MeasureFormBodyHeight()
	self.formBody:SetHeight(formH)
	GF.UI.UpdateScrollFrame(self.scroll)
	if getCreateDrawerFooter(self.parent) and self.scrollBar then
		local scrollInsetR = createDrawerScrollInsetR()
		anchorCreateDrawerScrollBar(self.scroll, self.scrollBar, createDrawerScrollBarOffsetX(scrollInsetR))
	end
	if math.abs((self.formBody:GetHeight() or 0) - formH) > 0.5 then
		self.formBody:SetHeight(formH)
		GF.UI.UpdateScrollFrame(self.scroll)
		if getCreateDrawerFooter(self.parent) and self.scrollBar then
			local scrollInsetR = createDrawerScrollInsetR()
			anchorCreateDrawerScrollBar(self.scroll, self.scrollBar, createDrawerScrollBarOffsetX(scrollInsetR))
		end
	end
	local viewH = self.scroll:GetHeight() or 0
	if viewH > 0 and formH <= viewH then
		self.scroll:SetVerticalScroll(0)
	else
		local range = self.scroll:GetVerticalScrollRange() or 0
		local cur = self.scroll:GetVerticalScroll() or 0
		if cur > range then
			self.scroll:SetVerticalScroll(range)
		end
	end
end

local clearCreationFocus

function CP:EnsureBlockedOverlay()
	if self.blockedOverlay or not self.parent then
		return self.blockedOverlay
	end
	local L = GF.L or {}
	local overlay = CreateFrame("Frame", nil, self.parent)
	overlay:SetAllPoints(self.parent)
	overlay:SetFrameLevel((self.parent.GetFrameLevel and self.parent:GetFrameLevel() or 0) + 30)
	overlay:EnableMouse(false)

	local text = GF.UI.CreateFontString(overlay, "OVERLAY", "GameFontNormalLarge")
	text:SetPoint("CENTER", overlay, "CENTER", 0, 18)
	text:SetJustifyH("CENTER")
	text:SetWordWrap(true)
	text:SetWidth(math.max((self.parent:GetWidth() or 260) - 28, 120))
	text:SetTextColor(1, 0.82, 0, 1)
	text:SetText(L.CREATE_CHANNEL_OCCUPIED or "系统预创建队伍正在占用招募通道")
	overlay.text = text

	local iconCount = GF.BROWSE_LOADING_ICON_COUNT or 3
	local iconWidth = GF.BROWSE_LOADING_ICON_WIDTH or 27
	local iconHeight = GF.BROWSE_LOADING_ICON_HEIGHT or 25
	local iconGap = GF.BROWSE_LOADING_ICON_GAP or 6
	local width = (iconWidth * iconCount) + (iconGap * math.max(0, iconCount - 1))
	local animation = CreateFrame("Frame", nil, overlay)
	animation:SetSize(width, iconHeight)
	animation:SetPoint("TOP", text, "BOTTOM", 0, -(GF.BROWSE_LOADING_TEXT_GAP or 7))
	animation.icons = {}
	for index = 1, iconCount do
		local icon = animation:CreateTexture(nil, "ARTWORK")
		icon:SetTexture(GF.BROWSE_LOADING_TEAMUP_TEXTURE or "Interface\\AddOns\\GroupFinder\\Art\\UI\\TeamUp.png")
		icon:SetTexCoord((index - 1) / iconCount, index / iconCount, 0, 1)
		icon:SetSize(iconWidth, iconHeight)
		icon:SetPoint("LEFT", animation, "LEFT", (index - 1) * (iconWidth + iconGap), 0)
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
	return overlay
end

function CP:SetCreateChannelBlocked(blocked)
	blocked = blocked == true
	if self._createChannelBlocked == blocked then
		return
	end
	self._createChannelBlocked = blocked
	if blocked then
		clearCreationFocus(self)
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
end

function CP:UpdateOwnershipUI()
	local blocked = isCreateChannelBlocked()
	self:SetCreateChannelBlocked(blocked)
	self:UpdateManageState()
end

function CP:IsBorrowingBlizzardFields()
	local ec = getEntryCreation()
	local embedParent = self:GetEmbedParent()
	if not ec or not embedParent then
		return false
	end
	if self._attached then
		return true
	end
	if ec.Name and ec.Name:GetParent() == embedParent then
		return true
	end
	if ec.Description and ec.Description:GetParent() == embedParent then
		return true
	end
	return false
end

function CP:ReleaseCreateFields(reason)
	reason = reason or "tab"
	if self:IsBorrowingBlizzardFields() then
		if not self._attached then
			self._attached = true
		end
		self:ReleaseBlizzardFields(reason)
		return
	end
	if reason == "addon" or reason == "blizzard" then
		restoreEntryCreationToBlizzard(getEntryCreation(), self)
		GF.entryCreationOwner = (reason == "blizzard") and "blizzard" or nil
		self._attached = false
		self.nameEdit = nil
		self.commentScroll = nil
		self:UpdateOwnershipUI()
		return
	end
	GF.entryCreationOwner = nil
	self._attached = false
end

function CP:ReleaseBlizzardFields(reason)
	reason = reason or "tab"
	local borrowing = self:IsBorrowingBlizzardFields()
	if not self._attached and not borrowing then
		GF.entryCreationOwner = (reason == "blizzard") and "blizzard" or nil
		self:UpdateOwnershipUI()
		return
	end
	if not self._attached and borrowing then
		self._attached = true
	end
	local ec = getEntryCreation()
	if not ec then
		self._attached = false
		GF.entryCreationOwner = (reason == "blizzard") and "blizzard" or nil
		self.nameEdit = nil
		self.commentScroll = nil
		self:UpdateOwnershipUI()
		return
	end

	self._fieldDraft = {
		name = BB.ReadEditText(ec.Name),
		voice = BB.ReadEditText(self.voiceEdit),
	}
	if ec.Description and ec.Description.EditBox then
		self._fieldDraft.desc = BB.ReadEditText(ec.Description.EditBox)
	end

	local revealWidgets = revealWidgetsForRelease(reason)

	if ec.Name and ec.Name:GetParent() == self:GetEmbedParent() then
		restoreBorrowedNameChrome(ec.Name)
		BB.RestoreLayout(ec.Name)
		BB.ClearBorrowed(ec.Name, CREATE_FIELD_OWNER, CREATE_FIELD_CHANNEL)
		restoreNameInstructions(ec.Name)
		if revealWidgets then
			ec.Name:Show()
		else
			ec.Name:Hide()
		end
	end
	if ec.Description and ec.Description:GetParent() == self:GetEmbedParent() then
		if ec.Description.EditBox then
			restoreNativeInstructions(ec.Description.EditBox)
		end
		restoreBorrowedWidgetChrome(ec.Description, "_gfDescriptionChromeState")
		BB.RestoreLayout(ec.Description)
		BB.ClearBorrowed(ec.Description, CREATE_FIELD_OWNER, CREATE_FIELD_CHANNEL)
		if revealWidgets then
			ec.Description:Show()
		else
			ec.Description:Hide()
		end
	end

	restoreBlizzardEntryCreationShell(ec, self, revealWidgets)

	finishEntryCreationVisibility(ec, reason)
	self._attached = false
	GF.entryCreationOwner = (reason == "blizzard") and "blizzard" or nil
	self.nameEdit = nil
	self.commentScroll = nil
	self:UpdateCustomPlaceholders()
	self:UpdateOwnershipUI()
end

function CP:AttachBlizzardFields()
	local ec = getEntryCreation()
	if not ec or not self.parent then
		return false
	end
	if isCreateChannelBlocked() then
		self:UpdateOwnershipUI()
		return false
	end
	if self._attached and GF.entryCreationOwner == "gf" then
		self._suppressedWidgets = self._suppressedWidgets or {}
		suppressEntryCreationChrome(ec, self._suppressedWidgets)
		self:UpdateFieldLayout()
		syncEditInstructions(self.voiceEdit)
		self:UpdateOwnershipUI()
		return true
	end

	self._suppressedWidgets = self._suppressedWidgets or {}

	if self.selection then
		local activityID = resolveActivityID(self.selection)
		if activityID then
			self:SyncEntryCreationStateIfNeeded(self.selection, activityID)
		end
	end

	if ec.Name then
		BB.CacheLayout(ec.Name)
	end
	if ec.Description then
		BB.CacheLayout(ec.Description)
	end

	suppressEntryCreationChrome(ec, self._suppressedWidgets)
	syncEditInstructions(self.voiceEdit)

	self.nameEdit = ec.Name
	self.commentScroll = ec.Description
	if self.nameEdit then
		suppressNativeInstructions(self.nameEdit)
	end
	if self.commentScroll and self.commentScroll.EditBox then
		suppressNativeInstructions(self.commentScroll.EditBox)
	end
	self.entryCreation = ec
	self._attached = true
	GF.entryCreationOwner = "gf"
	self:UpdateFieldLayout()
	self:UpdateRequirementLayout()
	self:InstallBlizzardFieldScripts(ec)
	self:SyncEmbeddedFieldChrome(ec)
	self:LayoutCustomPlaceholders()
	self:UpdateCustomPlaceholders()
	self:UpdateOwnershipUI()
	return true
end

function CP:RefreshCreateFieldHandoff()
	self:InstallEntryCreationHooks()
	if not isCreateDrawerFieldSurfaceActive() then
		return
	end

	if isLfgFrameVisible() then
		if self:IsBorrowingBlizzardFields() then
			self:ReleaseBlizzardFields("blizzard")
		else
			self:UpdateOwnershipUI()
		end
		return
	end
	-- LFG 已关但仍停在 EntryCreation：控件在 ec 上，继续 Attach 收回 GF

	if isCreateChannelBlocked() then
		if self:IsBorrowingBlizzardFields() then
			self:ReleaseBlizzardFields("blizzard")
		else
			self:UpdateOwnershipUI()
		end
		return
	end

	self:AttachBlizzardFields()
	if self.selection then
		local activityID = resolveActivityID(self.selection)
		if activityID then
			self:SyncEntryCreationStateIfNeeded(self.selection, activityID)
		end
	end
end

function CP:TryAttachIfNeeded()
	self:RefreshCreateFieldHandoff()
end

function CP:ActivateCreateChannel()
	if BB and BB.SetActiveOwner then
		BB.SetActiveOwner(CREATE_FIELD_OWNER)
	end
	if isCreateDrawerFieldSurfaceActive() then
		self:RefreshCreateFieldHandoff()
	end
end

function CP:StartCreateFieldOwnershipWatch()
	if self._createFieldOwnershipTicker or not C_Timer or not C_Timer.NewTicker then
		return
	end
	local interval = GF.CREATE_FIELD_OWNERSHIP_POLL_SEC or 0.35
	self._createFieldOwnershipTicker = C_Timer.NewTicker(interval, function()
		if not isCreateDrawerFieldSurfaceActive() then
			CP:StopCreateFieldOwnershipWatch()
			return
		end
		if isCreateChannelBlocked() then
			CP:UpdateOwnershipUI()
			return
		end
		CP:AttachBlizzardFields()
	end)
end

function CP:StopCreateFieldOwnershipWatch()
	if self._createFieldOwnershipTicker and self._createFieldOwnershipTicker.Cancel then
		self._createFieldOwnershipTicker:Cancel()
	end
	self._createFieldOwnershipTicker = nil
end

function CP:InstallEntryCreationHooks()
	if self._ecHooksInstalled then
		return
	end

	local function releaseForBlizzard()
		if BB and BB.SetActiveOwner then
			BB.SetActiveOwner("blizzard")
		end
		CP:ReleaseCreateFields("blizzard")
	end

	local lfg = LFGListFrame
	local ec = getEntryCreation()
	if not lfg or not ec then
		return
	end
	if ec and ec.HookScript then
		ec:HookScript("OnShow", function()
			if isCreateDrawerFieldSurfaceActive() then
				releaseForBlizzard()
			end
		end)
	end
	if hooksecurefunc and LFGListFrame_SetActivePanel then
		hooksecurefunc("LFGListFrame_SetActivePanel", function(lfgFrame, panel)
			if not isCreateDrawerFieldSurfaceActive() then
				return
			end
			CP:UpdateOwnershipUI()
			if not (lfgFrame and panel == lfgFrame.EntryCreation) then
				CP:RefreshCreateFieldHandoff()
			end
		end)
	end
	if lfg and lfg.HookScript then
		lfg:HookScript("OnHide", function()
			if not isCreateDrawerFieldSurfaceActive() then
				return
			end
			local function reclaimAfterHide()
				if not isCreateDrawerFieldSurfaceActive() then
					return
				end
				if BB and BB.SetActiveOwner then
					BB.SetActiveOwner(CREATE_FIELD_OWNER)
				end
				CP:RefreshCreateFieldHandoff()
				CP:SyncEmbeddedFieldChrome()
			end
			if C_Timer and C_Timer.After then
				C_Timer.After(0, reclaimAfterHide)
			else
				reclaimAfterHide()
			end
		end)
		lfg:HookScript("OnShow", function()
			normalizeEntryCreationVisibility()
			if isCreateDrawerFieldSurfaceActive() then
				CP:RefreshCreateFieldHandoff()
			end
		end)
	end
	local editButton = lfg and lfg.ApplicationViewer and lfg.ApplicationViewer.EditButton
	if editButton and editButton.HookScript and not editButton._gfReleaseCreateFieldsBeforeNativeEdit then
		editButton:HookScript("OnMouseDown", function()
			if isCreateDrawerFieldSurfaceActive() then
				releaseForBlizzard()
			end
		end)
		editButton._gfReleaseCreateFieldsBeforeNativeEdit = true
	end

	self._ecHooksInstalled = true
	precacheEntryCreationLayouts()
end

local function safeUpdateEntryCreationValidState(ec)
	if ec and ec.selectedActivity and LFGListEntryCreation_UpdateValidState then
		LFGListEntryCreation_UpdateValidState(ec)
	end
end

function CP:InstallBlizzardFieldScripts(ec)
	if not ec or self._fieldScriptsInstalled then
		return
	end

	if ec.Name then
		GF.UI.TrackEditBox(ec.Name, "GameFontHighlightSmall")
		ec.Name:SetScript("OnTextChanged", function(editBox)
			syncEditInstructions(editBox)
			safeUpdateEntryCreationValidState(ec)
			CP:UpdateCustomPlaceholders()
			CP:UpdateManageState()
		end)
	end

	if ec.Description and ec.Description.EditBox then
		local descEdit = ec.Description.EditBox
		GF.UI.TrackEditBox(descEdit, "GameFontHighlightSmall")
		descEdit:SetScript("OnTextChanged", function(editBox, isUserInput)
			safeDescriptionTextChanged(editBox, isUserInput)
			CP:UpdateCustomPlaceholders()
			CP:UpdateManageState()
		end)
	end

	self._fieldScriptsInstalled = true
end

function CP:SyncEntryCreationState(node, activityID)
	local ec = getEntryCreation()
	if not ec or not node or not activityID or not node.categoryID then
		return
	end
	if LFGListEntryCreation_SetBaseFilters then
		LFGListEntryCreation_SetBaseFilters(ec, node.preferredFilters or Enum.LFGListFilter.PvE)
	end
	local groupID = node.groupID
	if not groupID then
		local info = C_LFGList.GetActivityInfoTable(activityID)
		groupID = info and info.groupFinderActivityGroupID
	end
	ec.selectedActivity = activityID
	ec.selectedCategory = node.categoryID
	ec.selectedGroup = groupID
	ec.selectedFilters = node.filters or 0
	if self.generalPlaystyle ~= Enum.LFGEntryGeneralPlaystyle.None then
		ec.generalPlaystyle = self.generalPlaystyle
	end
end

function CP:SyncEntryCreationStateIfNeeded(node, activityID)
	if not node or not activityID then
		return
	end
	if self._syncedActivityID == activityID and self._syncedNodeKey == node.key then
		return
	end
	self:SyncEntryCreationState(node, activityID)
	self._syncedActivityID = activityID
	self._syncedNodeKey = node.key
end

local function hasCreationName(nameEdit, ec)
	if not nameEdit then
		return false
	end
	local text = nameEdit:GetText()
	if issecretvalue and issecretvalue(text) then
		return true
	end
	local trimmed = trimName(text)
	if trimmed ~= "" then
		return true
	end
	if ec and LFGListEntryCreation_GetSanitizedName then
		text = LFGListEntryCreation_GetSanitizedName(ec)
		if issecretvalue and issecretvalue(text) then
			return true
		end
		return trimName(text) ~= ""
	end
	return false
end

local function hasDescriptionText(commentScroll)
	local editBox = commentScroll and commentScroll.EditBox
	if not editBox then
		return false
	end
	local text = editBox:GetText()
	if issecretvalue and issecretvalue(text) then
		return true
	end
	return trimName(text) ~= ""
end

local function isCreateableSelection(node)
	if GF.NavData and GF.NavData.IsCreateable then
		return GF.NavData.IsCreateable(node)
	end
	return resolveActivityID(node) ~= nil
end

local function setWidgetEnabled(widget, enabled)
	if not widget then
		return
	end
	if widget.SetEnabled then
		widget:SetEnabled(enabled)
	end
	if widget.EnableMouse then
		widget:EnableMouse(enabled)
	end
end

function clearCreationFocus(panel)
	local ec = getEntryCreation()
	if ec and LFGListEntryCreation_ClearFocus then
		LFGListEntryCreation_ClearFocus(ec)
		return
	end
	if panel.nameEdit then
		panel.nameEdit:ClearFocus()
	end
	if panel.commentScroll and panel.commentScroll.EditBox then
		panel.commentScroll.EditBox:ClearFocus()
	end
	if panel.voiceEdit then
		panel.voiceEdit:ClearFocus()
	end
	if panel.ilvlEdit then
		panel.ilvlEdit:ClearFocus()
	end
	if panel.mplusEdit then
		panel.mplusEdit:ClearFocus()
	end
end

local function showCreateError(msg)
	if GF.ShowWarningMessage then
		GF.ShowWarningMessage(msg)
	end
end

function CP:Init(parent)

	if self.scroll then
		return
	end

	self.parent = parent

	self.selection = nil

	self.generalPlaystyle = DEFAULT_PLAYSTYLE

	local L = GF.L or {}

	self.title = GF.UI.CreateFontString(parent, "OVERLAY", "QuestFont_Huge")
	self.title:SetPoint("TOPLEFT", parent, "TOPLEFT", CREATE_PAD, -8)
	self.title:Hide()

	local drawerFooter = getCreateDrawerFooter(parent)
	self.scroll = GF.UI.CreateScrollFrame(parent, { rowHeight = GF.CREATE_WHEEL_ROW_H or 24 })
	if drawerFooter then
		self.scroll:SetPoint("TOPLEFT", parent, "TOPLEFT", CREATE_FORM_INSET_X, -CREATE_FORM_INSET_TOP)
		self.scroll:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -CREATE_FORM_INSET_X, 0)
	else
		self.scroll:SetPoint("TOPLEFT", parent, "TOPLEFT", CREATE_PAD, -4)
		self.scroll:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -(GF.CONTENT_SCROLL_INSET_R or 18), BUTTON_BAR_H)
	end
	self.scroll:SetFrameLevel(parent:GetFrameLevel() + 2)
	if drawerFooter then
		self.scrollBar = nil
		if self.scroll.ScrollBar then
			self.scroll.ScrollBar:Hide()
		end
	else
		self.scrollBar = GF.UI.AttachContentScrollBar(self.scroll, parent)
	end

	self.formBody = CreateFrame("Frame", nil, self.scroll)
	self.formBody:SetSize(1, 1)
	self.formBody:SetClipsChildren(true)
	self.scroll:SetScrollChild(self.formBody)

	local form = self.formBody

	self.formColumn = CreateFrame("Frame", nil, form)
	self.formColumn:SetSize(1, 1)
	self.formColumn:SetPoint("TOPLEFT", form, "TOPLEFT", 0, 0)
	self.formColumn:Hide()

	self.nameLabel = GF.UI.CreateFontString(form, "OVERLAY", "GameFontNormal")
	self.nameLabel:SetPoint("TOPLEFT", form, "TOPLEFT", FORM_LEFT_INSET, 0)
	self.nameLabel:SetText(L.NAME or "Name")
	applyCreateTitleTextStyle(self.nameLabel)

	self.nameAtlasAnchor = CreateFrame("Frame", nil, form)
	self.nameAtlasAnchor:SetSize(BLIZZ_NAME_W + (FIELD_EDGE_PAD * 2), CREATE_FORM_INPUT_H)
	self.nameAtlasAnchor:SetPoint("TOP", self.nameLabel, "BOTTOM", 0, -LABEL_FIELD_GAP)
	self.nameAtlasAnchor:SetPoint("LEFT", self.formColumn, "LEFT", 0, 0)
	styleCreateInputAtlasFrame(self.nameAtlasAnchor)

	self.nameAnchor = CreateFrame("Frame", nil, form)
	self.nameAnchor:SetSize(BLIZZ_NAME_W, BLIZZ_NAME_H)
	self.nameAnchor:SetPoint("TOPLEFT", self.nameAtlasAnchor, "TOPLEFT", FIELD_EDGE_PAD, 0)
	self.namePlaceholder = GF.UI.CreateFontString(form, "OVERLAY", "GameFontDisableSmall")
	self.namePlaceholder:SetJustifyH("LEFT")
	self.namePlaceholder:SetWordWrap(false)
	self.namePlaceholder:SetTextColor(0.55, 0.55, 0.55, 1)
	self.namePlaceholder:Hide()

	self.commentLabel = GF.UI.CreateFontString(form, "OVERLAY", "GameFontNormal")
	self.commentLabel:SetPoint("TOP", self.nameAtlasAnchor, "BOTTOM", 0, -FIELD_GAP)
	self.commentLabel:SetPoint("LEFT", self.formColumn, "LEFT", 0, 0)
	self.commentLabel:SetText(L.COMMENT or "Description")
	applyCreateTitleTextStyle(self.commentLabel)

	self.descAtlasAnchor = CreateFrame("Frame", nil, form)
	self.descAtlasAnchor:SetSize(BLIZZ_DESC_W + (FIELD_EDGE_PAD * 2), CREATE_FORM_DESC_ATLAS_H)
	self.descAtlasAnchor:SetPoint("TOP", self.commentLabel, "BOTTOM", 0, -DESC_FIELD_GAP)
	self.descAtlasAnchor:SetPoint("LEFT", self.formColumn, "LEFT", 0, 0)
	styleCreateDescriptionAtlasFrame(self.descAtlasAnchor)

	self.descAnchor = CreateFrame("Frame", nil, form)
	self.descAnchor:SetSize(BLIZZ_DESC_W, BLIZZ_DESC_H)
	self.descAnchor:SetPoint("TOPLEFT", self.descAtlasAnchor, "TOPLEFT", FIELD_EDGE_PAD, -CREATE_FORM_DESC_ATLAS_PAD_Y)
	self.descPlaceholder = GF.UI.CreateFontString(form, "OVERLAY", "GameFontDisableSmall")
	self.descPlaceholder:SetJustifyH("LEFT")
	self.descPlaceholder:SetJustifyV("TOP")
	self.descPlaceholder:SetWordWrap(true)
	self.descPlaceholder:SetTextColor(0.55, 0.55, 0.55, 1)
	self.descPlaceholder:Hide()

	self.playLabel = GF.UI.CreateFontString(form, "OVERLAY", "GameFontNormal")
	self.playLabel:SetPoint("TOP", self.descAtlasAnchor, "BOTTOM", 0, -FIELD_GAP)
	self.playLabel:SetPoint("LEFT", self.formColumn, "LEFT", 0, 0)
	self.playLabel:SetText(L.PLAYSTYLE or "Playstyle")
	applyCreateTitleTextStyle(self.playLabel)

	self.playDropdownAnchor = CreateFrame("Frame", nil, form)
	self.playDropdownAnchor:SetSize(BLIZZ_DESC_W + 10, DROPDOWN_H)
	self.playDropdownAnchor:SetPoint("TOP", self.playLabel, "BOTTOM", 0, -LABEL_FIELD_GAP)
	self.playDropdownAnchor:SetPoint("LEFT", self.formColumn, "LEFT", DROPDOWN_LEFT_NUDGE, 0)

	self.playDropdown = GF.UI.CreateDropdownButton(form)
	self:ApplyPlaystyleDropdownLayout()
	self:SetupPlaystyleDropdown()

	self.ilvlLabel = GF.UI.CreateFontString(form, "OVERLAY", "GameFontNormal")
	self.ilvlLabel:SetPoint("TOP", self.playDropdownAnchor, "BOTTOM", 0, -FIELD_GAP)
	self.ilvlLabel:SetPoint("LEFT", self.formColumn, "LEFT", 0, 0)
	self.ilvlLabel:SetText(L.ITEM_LEVEL or "Item level")
	applyCreateTitleTextStyle(self.ilvlLabel)

	self.ilvlAnchor = CreateFrame("Frame", nil, form)
	self.ilvlAnchor:SetSize(REQ_EDIT_W, REQ_EDIT_H)
	self.ilvlAnchor:SetPoint("TOP", self.ilvlLabel, "BOTTOM", 0, -LABEL_FIELD_GAP)
	self.ilvlAnchor:SetPoint("LEFT", self.formColumn, "LEFT", REQ_FIELD_LEFT_NUDGE, 0)

	self.ilvlEdit = CreateFrame("EditBox", nil, form, "LFGListEditBoxTemplate")
	self.ilvlEdit:SetPoint("TOPLEFT", self.ilvlAnchor, "TOPLEFT", 0, 0)
	self.ilvlEdit:SetPoint("BOTTOMRIGHT", self.ilvlAnchor, "BOTTOMRIGHT", 0, 0)
	GF.UI.TrackEditBox(self.ilvlEdit, "GameFontHighlightSmall")
	self.ilvlEdit:SetNumeric(true)
	styleCreateInputBox(self.ilvlEdit)

	self.mplusLabel = GF.UI.CreateFontString(form, "OVERLAY", "GameFontNormal")
	self.mplusLabel:SetText(L.MYTHIC_SCORE or "M+ score")
	applyCreateTitleTextStyle(self.mplusLabel)

	self.mplusAnchor = CreateFrame("Frame", nil, form)
	self.mplusAnchor:SetSize(REQ_EDIT_W, REQ_EDIT_H)

	self.mplusEdit = CreateFrame("EditBox", nil, form, "LFGListEditBoxTemplate")
	self.mplusEdit:SetPoint("TOPLEFT", self.mplusAnchor, "TOPLEFT", 0, 0)
	self.mplusEdit:SetPoint("BOTTOMRIGHT", self.mplusAnchor, "BOTTOMRIGHT", 0, 0)
	GF.UI.TrackEditBox(self.mplusEdit, "GameFontHighlightSmall")
	self.mplusEdit:SetNumeric(true)
	styleCreateInputBox(self.mplusEdit)

	self.voiceLabel = GF.UI.CreateFontString(form, "OVERLAY", "GameFontNormal")
	self.voiceLabel:SetText(L.VOICE_CHAT or LFG_LIST_VOICE_CHAT or "Voice chat")
	applyCreateTitleTextStyle(self.voiceLabel)

	self.voiceAnchor = CreateFrame("Frame", nil, form)
	self.voiceAnchor:SetSize(REQ_EDIT_W, REQ_EDIT_H)

	self.voiceEdit = CreateFrame("EditBox", nil, form, "LFGListEditBoxTemplate")
	self.voiceEdit:SetPoint("TOPLEFT", self.voiceAnchor, "TOPLEFT", 0, 0)
	self.voiceEdit:SetPoint("BOTTOMRIGHT", self.voiceAnchor, "BOTTOMRIGHT", 0, 0)
	GF.UI.TrackEditBox(self.voiceEdit, "GameFontHighlightSmall")
	styleCreateInputBox(self.voiceEdit)
	if self.voiceEdit.SetMaxLetters then
		self.voiceEdit:SetMaxLetters(31)
	end
	if self.voiceEdit.Instructions and LFG_LIST_VOICE_CHAT_INSTR then
		self.voiceEdit.Instructions:Hide()
	end

	self:UpdateRequirementLayout()

	self.crossFactionCheck = CreateFrame("CheckButton", nil, form, "UICheckButtonTemplate")
	self.crossFactionCheck:SetPoint("TOP", self.voiceAnchor, "BOTTOM", 0, -8)
	self.crossFactionCheck:SetPoint("LEFT", self.formColumn, "LEFT", 0, 0)
	styleCreateCheckButton(self.crossFactionCheck)

	self.crossFactionLabel = GF.UI.CreateFontString(form, "OVERLAY", "GameFontNormal")

	self.crossFactionLabel:SetPoint("LEFT", self.crossFactionCheck, "RIGHT", CREATE_CHECK_LABEL_GAP, 0)
	self.crossFactionLabel:SetTextColor(1, 0.82, 0)
	self.crossFactionLabel:SetJustifyH("LEFT")

	self.crossFactionLabel:SetText(getFactionRestrictionLabel())
	setCheckHitRectToLabel(self.crossFactionCheck, self.crossFactionLabel)
	self.crossFactionCheck:SetScript("OnEnter", function(btn)
		showCreateOptionTooltip(btn, getFactionRestrictionLabel(), getFactionRestrictionTip())
	end)
	self.crossFactionCheck:SetScript("OnLeave", GameTooltip_Hide)



	self.privateCheck = CreateFrame("CheckButton", nil, form, "UICheckButtonTemplate")
	self.privateCheck:SetPoint("TOP", self.crossFactionCheck, "BOTTOM", 0, -8)
	self.privateCheck:SetPoint("LEFT", self.formColumn, "LEFT", 0, 0)
	styleCreateCheckButton(self.privateCheck)

	self.privateLabel = GF.UI.CreateFontString(form, "OVERLAY", "GameFontNormal")

	self.privateLabel:SetPoint("LEFT", self.privateCheck, "RIGHT", CREATE_CHECK_LABEL_GAP, 0)
	self.privateLabel:SetJustifyH("LEFT")

	self.privateLabel:SetText(L.PRIVATE or "Private")
	setCheckHitRectToLabel(self.privateCheck, self.privateLabel)
	self.privateCheck:SetScript("OnEnter", function(btn)
		local LL = GF.L or {}
		showCreateOptionTooltip(btn, LL.PRIVATE or "Private", LL.PRIVATE_TIP or "")
	end)
	self.privateCheck:SetScript("OnLeave", GameTooltip_Hide)

	self:UpdateRequirementLayout()


	local buttonParent = drawerFooter or parent
	local buttonBottom = drawerFooter and (GF.FILTER_FOOTER_BUTTON_OFFSET_Y or 12) or LIST_BTN_BOTTOM
	local buttonCenterOffset = math.floor((LIST_BTN_W + LIST_BTN_GAP) / 2)
	self.listBtn = GF.UI.CreatePanelButton(buttonParent, L.CREATE_LISTING or "List Group", LIST_BTN_W, true)

	self.removeBtn = GF.UI.CreatePanelButton(buttonParent, L.REMOVE_LISTING or "Remove", LIST_BTN_W, true)

	self.listBtn:SetPoint("BOTTOM", buttonParent, "BOTTOM", -buttonCenterOffset, buttonBottom)
	self.removeBtn:SetPoint("BOTTOM", buttonParent, "BOTTOM", buttonCenterOffset, buttonBottom)

	GF.UI.BindLeaderOnlyButton(self.listBtn, function()
		CP:SubmitListing()
	end, nil, "aboveLeft")
	GF.UI.BindLeaderOnlyButton(self.removeBtn, function()
		if not (GF.Listing and GF.Listing.HasActive and GF.Listing:HasActive()) then
			return
		end
		GF.Listing:Remove()
		if GF.MainFrame then
			GF.MainFrame:OnActiveEntryUpdate()
		end
		if GF.CreateDrawer then
			GF.CreateDrawer:Close()
		end
	end, nil, "aboveLeft")

	self.editMode = false

	self:UpdatePlaystyleDropdown()

	self:InstallEntryCreationHooks()

	parent:SetScript("OnSizeChanged", function()
		if CP._frameResizing then
			return
		end
		CP:ScheduleUpdateScrollLayout()
	end)
	self:UpdateScrollLayout()

end



function CP:ApplyPlaystyleDropdownLayout()
	if not self.playDropdown then
		return
	end
	local _, descW = self:GetCreateFieldWidths()
	local anchorW = self.playDropdownAnchor and self.playDropdownAnchor.GetWidth and self.playDropdownAnchor:GetWidth() or 0
	local w, h = (anchorW and anchorW > 1) and anchorW or descW, DROPDOWN_H
	if self.playDropdownAnchor then
		self.playDropdownAnchor:SetSize(w, h)
	end
	self.playDropdown:SetSize(w, h)
	self.playDropdown:ClearAllPoints()
	self.playDropdown:SetPoint("TOPLEFT", self.playDropdownAnchor, "TOPLEFT", 0, 0)
end

function CP:SetupPlaystyleDropdown()

	if not self.playDropdown or not self.playDropdown.SetupMenu then

		return

	end

	self.playDropdown:SetupMenu(function(_, rootDescription)

		rootDescription:SetTag("MENU_GF_PLAYSTYLE")

		for _, entry in ipairs(PLAYSTYLES) do

			local styleEnum, globalKey = entry[1], entry[2]

			local label = playstyleLabel(styleEnum, globalKey)

			rootDescription:CreateRadio(label, function()

				return CP.generalPlaystyle == styleEnum

			end, function()

				CP.generalPlaystyle = styleEnum

				CP:UpdatePlaystyleDropdown()

				if CP.selection then
					local activityID = resolveActivityID(CP.selection)
					if activityID then
						CP:SyncEntryCreationState(CP.selection, activityID)
					end
				end

			end, styleEnum)

		end

	end)

end



function CP:UpdatePlaystyleDropdown()

	if not self.playDropdown then

		return

	end

	if self.generalPlaystyle == Enum.LFGEntryGeneralPlaystyle.None then

		local required = GROUP_FINDER_PLAYSTYLE_REQUIRED or (GF.L and GF.L.PLAYSTYLE_REQUIRED) or "Select playstyle"

		if DISABLED_FONT_COLOR and DISABLED_FONT_COLOR.WrapTextInColorCode then

			self.playDropdown:SetDefaultText(DISABLED_FONT_COLOR:WrapTextInColorCode(required))

		else

			self.playDropdown:SetDefaultText(required)

		end

	else

		self.playDropdown:SetDefaultText(getPlaystyleLabel(self.generalPlaystyle))

	end

	if self.playDropdown.GenerateMenu then

		self.playDropdown:GenerateMenu()

	end

	self:ApplyPlaystyleDropdownLayout()

end



function CP:UpdateCrossFactionOption()
	if not self.crossFactionCheck then
		return
	end
	if self._showCompleteDisabledForm then
		self.crossFactionCheck._gfActivityDisabled = true
		self.crossFactionCheck:SetEnabled(false)
		self.crossFactionCheck:SetChecked(false)
		self.crossFactionCheck:Show()
		if self.crossFactionLabel then
			self.crossFactionLabel:SetText(getFactionRestrictionLabel())
			self.crossFactionLabel:SetTextColor(1, 0.82, 0)
			self.crossFactionLabel:Show()
		end
		self:ApplyCompactRowLayout()
		self:UpdateScrollLayout()
		return
	end
	local node = self.selection
	local activityID = resolveActivityID(node)
	if not node or not activityID then
		self.crossFactionCheck._gfActivityDisabled = true
		self.crossFactionCheck:Hide()
		self.crossFactionLabel:Hide()
		self.crossFactionCheck:SetEnabled(false)
		self.crossFactionCheck:SetChecked(false)
		self:ApplyCompactRowLayout()
		self:UpdateScrollLayout()
		return
	end
	local categoryInfo = node.categoryID and C_LFGList.GetLfgCategoryInfo(node.categoryID)
	local activityInfo = node.activityInfo or C_LFGList.GetActivityInfoTable(activityID)

	local show = categoryInfo and categoryInfo.allowCrossFaction
	local disable = (not show) or (activityInfo and not activityInfo.allowCrossFaction)

	self.crossFactionCheck._gfActivityDisabled = disable and true or nil
	self.crossFactionCheck:SetEnabled(not disable)

	if disable then
		self.crossFactionCheck:Hide()
		self.crossFactionLabel:Hide()
		self.crossFactionCheck:SetChecked(false)
	else
		self.crossFactionCheck:Show()
		self.crossFactionLabel:Show()
		self.crossFactionCheck:SetChecked(false)
		self.crossFactionLabel:SetTextColor(1, 0.82, 0)
	end

	self:ApplyCompactRowLayout()
	self:UpdateScrollLayout()

end



function CP:UpdateScoreRequirementVisibility(activityInfo)
	if not self.mplusLabel then
		return
	end
	local show = self._showCompleteDisabledForm or (activityInfo and activityInfo.isMythicPlusActivity)
	self.mplusLabel:SetShown(show)
	self.mplusEdit:SetShown(show)
	if self.mplusAnchor then
		self.mplusAnchor:SetShown(show)
	end
end



function CP:SetSelection(node)
	self.selection = node
	if not node then
		self:UpdateManageState()
		return
	end
	if isCreateDrawerFieldSurfaceActive() then
		self:TryAttachIfNeeded()
	else
		self:ReleaseCreateFields("tab")
	end
	local activityID = resolveActivityID(node)
	if activityID then
		self:SyncEntryCreationStateIfNeeded(node, activityID)
	end
	local info = activityID and C_LFGList.GetActivityInfoTable(activityID)
	if GF.CreateDrawer then
		GF.CreateDrawer:SyncActivityTitle()
	end
	self:UpdateScoreRequirementVisibility(info)
	self:UpdateRequirementLayout()
	self:UpdateCrossFactionOption()
	self:UpdateScrollLayout()
	self:UpdateManageState()
end



function CP:ValidateListing()
	local L = GF.L or {}
	if not self.selection or not self.selection.categoryID then
		showCreateError(L.NO_SELECTION or "Select an activity.")
		return false
	end
	if not self.editMode and GF.Listing and GF.Listing.HasActive and GF.Listing:HasActive() then
		showCreateError(L.CREATE_ALREADY_LISTED or LFG_LIST_CLEAR_ORPHANED_GROUP or "You already have an active listing.")
		return false
	end
	if GF.NavData and GF.NavData.IsCreateable and not GF.NavData.IsCreateable(self.selection) then
		showCreateError(L.CREATE_NEED_ACTIVITY or "Select a specific activity difficulty.")
		return false
	end
	if self.generalPlaystyle == Enum.LFGEntryGeneralPlaystyle.None then
		showCreateError(L.PLAYSTYLE_REQUIRED or GROUP_FINDER_PLAYSTYLE_REQUIRED or "Select playstyle.")
		return false
	end
	local activityID = resolveActivityID(self.selection)
	if not activityID then
		showCreateError(L.CREATE_NEED_ACTIVITY or "Select a specific activity difficulty.")
		return false
	end
	if LFGListUtil_GetActiveQueueMessage then
		local queueMsg = LFGListUtil_GetActiveQueueMessage(false)
		if queueMsg and queueMsg ~= "" then
			showCreateError(queueMsg)
			return false
		end
	end
	local activityInfo = self.selection.activityInfo or C_LFGList.GetActivityInfoTable(activityID)
	local maxNumPlayers = activityInfo and activityInfo.maxNumPlayers or 0
	if maxNumPlayers > 0 and GetNumGroupMembers(LE_PARTY_CATEGORY_HOME) >= maxNumPlayers then
		local fmt = LFG_LIST_TOO_MANY_FOR_ACTIVITY or "Too many members for this activity (%d)."
		showCreateError(string.format(fmt, maxNumPlayers))
		return false
	end
	if activityInfo and not C_LFGList.IsPlayerAuthenticatedForLFG(activityInfo.categoryID)
		and activityInfo.isMythicPlusActivity
		and C_LFGList.GetKeystoneForActivity
		and not C_LFGList.GetKeystoneForActivity(activityID) then
		showCreateError(LFG_AUTHENTICATOR_BUTTON_MYTHIC_PLUS_TOOLTIP or L.CREATE_NEED_KEYSTONE or "M+ keystone required.")
		return false
	end
	local ec = getEntryCreation()
	if not hasCreationName(self.nameEdit, ec) then
		showCreateError(LFG_LIST_MUST_HAVE_NAME or L.CREATE_NEED_NAME or "Name required.")
		return false
	end
	if self.editMode and GF.Listing and GF.Listing.CrossFactionChanged then
		local params = self:BuildListingParams()
		if params and GF.Listing:CrossFactionChanged(params.isCrossFactionListing) then
			showCreateError(L.EDIT_CROSS_FACTION_BLOCKED or "Remove listing before changing cross-faction.")
			return false
		end
	end
	return true
end

function CP:BuildListingParams()
	if not self.selection or not self.selection.categoryID then
		return nil
	end
	if self.generalPlaystyle == Enum.LFGEntryGeneralPlaystyle.None then
		return nil
	end
	local activityID = resolveActivityID(self.selection)
	if not activityID then
		return nil
	end

	local categoryInfo = self.selection.categoryID and C_LFGList.GetLfgCategoryInfo(self.selection.categoryID)
	local activityInfo = self.selection.activityInfo or C_LFGList.GetActivityInfoTable(activityID)

	local showCross = categoryInfo and categoryInfo.allowCrossFaction

	local allowCrossActivity = activityInfo and activityInfo.allowCrossFaction

	local isCrossFaction = showCross and allowCrossActivity and not self.crossFactionCheck:GetChecked()



	return {

		activityID = activityID,

		groupID = self.selection.groupID,

		categoryID = self.selection.categoryID,

		questID = nil,

		isAutoAccept = false,

		isPrivateGroup = self.privateCheck:GetChecked(),

		isCrossFactionListing = isCrossFaction,

		generalPlaystyle = self.generalPlaystyle,

		requiredItemLevel = tonumber(self.ilvlEdit:GetText()) or 0,

		requiredDungeonScore = tonumber(self.mplusEdit:GetText()) or 0,

		requiredPvpRating = 0,

	}

end



function CP:UpdateListButtonLabel()
	if not self.listBtn then
		return
	end
	local L = GF.L or {}
	local hasActive = GF.Listing and GF.Listing.HasActive and GF.Listing:HasActive()
	if self.editMode or hasActive then
		self.listBtn:SetText(L.SAVE_LISTING or "Save")
	else
		self.listBtn:SetText(L.CREATE_LISTING or "List Group")
	end
end

function CP:ApplyDefaultRequiredItemLevel(force)
	if self.editMode then
		return
	end
	if not self.ilvlEdit then
		return
	end
	local defaultItemLevel = getDefaultRequiredItemLevel()
	if not defaultItemLevel then
		return
	end
	local defaultText = tostring(defaultItemLevel)
	local currentText = trimName(self.ilvlEdit:GetText())
	if force or currentText == "" or currentText == "0" or currentText == self._defaultRequiredItemLevelText then
		self.ilvlEdit:SetText(defaultText)
		self._defaultRequiredItemLevelText = defaultText
	end
end

function CP:RefreshLocale()
	local L = GF.L or {}
	if self.nameLabel then
		self.nameLabel:SetText(L.NAME or "Name")
	end
	if self.commentLabel then
		self.commentLabel:SetText(L.COMMENT or "Description")
	end
	if self.playLabel then
		self.playLabel:SetText(L.PLAYSTYLE or "Playstyle")
	end
	if self.ilvlLabel then
		self.ilvlLabel:SetText(L.ITEM_LEVEL or "Item level")
	end
	if self.mplusLabel then
		self.mplusLabel:SetText(L.MYTHIC_SCORE or "M+ score")
	end
	if self.voiceLabel then
		self.voiceLabel:SetText(L.VOICE_CHAT or LFG_LIST_VOICE_CHAT or "Voice chat")
	end
	if self.privateLabel then
		self.privateLabel:SetText(L.PRIVATE or "Private")
	end
	self:UpdateCustomPlaceholders()
	self:SetupPlaystyleDropdown()
	self:UpdatePlaystyleDropdown()
	self:UpdateCrossFactionOption()
	setCheckHitRectToLabel(self.crossFactionCheck, self.crossFactionLabel)
	setCheckHitRectToLabel(self.privateCheck, self.privateLabel)
	self:UpdateRequirementLayout()
	self:UpdateListButtonLabel()
	if self.removeBtn then
		self.removeBtn:SetText(L.REMOVE_LISTING or "Remove")
	end
	self:UpdateOwnershipUI()
	if GF.CreateDrawer and GF.CreateDrawer.SyncActivityTitle then
		GF.CreateDrawer:SyncActivityTitle()
	end
end

function CP:UpdateFormInteractionState(formEnabled)
	formEnabled = formEnabled == true
	self._showCompleteDisabledForm = (not formEnabled) and (not isCreateChannelBlocked())
	local activityID = resolveActivityID(self.selection)
	local activityInfo = activityID and (self.selection.activityInfo or C_LFGList.GetActivityInfoTable(activityID))
	self:UpdateScoreRequirementVisibility(activityInfo)
	self:UpdateCrossFactionOption()
	if self.formBody then
		self.formBody:SetAlpha(formEnabled and 1 or 0.45)
	end
	if not formEnabled then
		clearCreationFocus(self)
	end
	setWidgetEnabled(self.nameEdit, formEnabled)
	if self.commentScroll then
		setWidgetEnabled(self.commentScroll, formEnabled)
		setWidgetEnabled(self.commentScroll.EditBox, formEnabled)
	end
	setWidgetEnabled(self.playDropdown, formEnabled)
	setWidgetEnabled(self.ilvlEdit, formEnabled)
	setWidgetEnabled(self.mplusEdit, formEnabled)
	setWidgetEnabled(self.voiceEdit, formEnabled)
	setWidgetEnabled(self.privateCheck, formEnabled)
	if self.crossFactionCheck and (not self.crossFactionCheck._gfActivityDisabled) then
		setWidgetEnabled(self.crossFactionCheck, formEnabled)
	end
end

function CP:HasRequiredCreateFields()
	return hasCreationName(self.nameEdit, getEntryCreation())
end

function CP:UpdateManageState()
	if not self.listBtn then
		return
	end
	local blocked = isCreateChannelBlocked()
	local canLead = GF.Listing and GF.Listing.CanLeadListing and GF.Listing:CanLeadListing()
	local canManage = GF.Listing and GF.Listing.CanManageEntry and GF.Listing:CanManageEntry()
	local selectionCreateable = self.editMode or isCreateableSelection(self.selection)
	local requiredComplete = self:HasRequiredCreateFields()
	local formCanEdit = (not self.editMode) or canManage
	local submitCanManage = (not self.editMode) or canManage
	self:UpdateFormInteractionState(selectionCreateable and not blocked and formCanEdit)
	self.listBtn:SetEnabled(canLead and submitCanManage and not blocked and selectionCreateable and requiredComplete)
	if self.removeBtn then
		local hasActive = GF.Listing and GF.Listing.HasActive and GF.Listing:HasActive()
		self.removeBtn:SetEnabled(canLead and hasActive and not blocked)
	end
end

function CP:PrepareForEdit()
	if not GF.Listing or not GF.Listing:HasActive() then
		return
	end
	self.editMode = true
	self._defaultRequiredItemLevelText = nil
	if C_LFGList.CopyActiveEntryInfoToCreationFields then
		C_LFGList.CopyActiveEntryInfoToCreationFields()
	end
	local info = GF.Listing:GetActive()
	local activityID = GF.Listing:GetActiveActivityID()
	local node = activityID and GF.NavData.FindNodeByActivityID(activityID)
	if node then
		self.selection = node
	end
	if info then
		if info.generalPlaystyle and info.generalPlaystyle ~= Enum.LFGEntryGeneralPlaystyle.None then
			self.generalPlaystyle = info.generalPlaystyle
		end
		if self.privateCheck then
			self.privateCheck:SetChecked(info.privateGroup)
		end
		if self.crossFactionCheck then
			local cross = info.isCrossFactionListing or info.isCrossFaction
			self.crossFactionCheck:SetChecked(not cross)
		end
		if self.ilvlEdit then
			self.ilvlEdit:SetText(tostring(info.requiredItemLevel or 0))
		end
		if self.mplusEdit then
			self.mplusEdit:SetText(tostring(info.requiredDungeonScore or 0))
		end
	end
	if node and activityID then
		self:SyncEntryCreationStateIfNeeded(node, activityID)
	end
	self:AttachBlizzardFields()
	self:UpdatePlaystyleDropdown()
	self:UpdateCrossFactionOption()
	self:UpdateRequirementLayout()
	self:UpdateListButtonLabel()
	self:UpdateManageState()
	self:RefreshCreateFieldHandoff()
	self:SyncEmbeddedFieldChrome()
	self:UpdateScrollLayout()
	if GF.CreateDrawer then
		GF.CreateDrawer:SyncActivityTitle()
	end
end

function CP:PrepareForCreate(opts)
	opts = opts or {}
	local wasEditMode = self.editMode == true
	self.editMode = false
	self:ApplyDefaultRequiredItemLevel(opts.resetDefaults == true or wasEditMode)
	self:UpdateListButtonLabel()
	self:UpdateManageState()
	if GF.CreateDrawer then
		GF.CreateDrawer:SyncActivityTitle()
	end
end

function CP:ClearFocus()
	clearCreationFocus(self)
end

function CP:SubmitListing()
	local L = GF.L or {}
	if isCreateChannelBlocked() then
		showCreateError(L.CREATE_BLIZZARD_OWNS or "Premade group creation is open in the game UI.")
		return
	end
	if not self:AttachBlizzardFields() then
		showCreateError(L.CREATE_BLIZZARD_UI_MISSING or "Premade group UI is not loaded.")
		return
	end
	local activityID = self.selection and resolveActivityID(self.selection)
	if activityID and self.selection then
		self:SyncEntryCreationState(self.selection, activityID)
	end
	if not self:ValidateListing() then
		return
	end
	clearCreationFocus(self)
	syncVoiceToBlizzard(self.voiceEdit)
	local params = self:BuildListingParams()
	if not params then
		return
	end

	if self.editMode then
		if not GF.Listing:CanLeadListing() then
			GF.Listing:NotifyLeaderOnly()
			return
		end
		local ok = GF.Listing:UpdateFromParams(params)
		if not ok then
			showCreateError(L.CREATE_FAILED or "Listing failed. Please try again.")
			return
		end
		if GF.CreateDrawer then
			GF.CreateDrawer:Close()
		end
		return
	end

	if not GF.Listing:CanLeadListing() then
		GF.Listing:NotifyLeaderOnly()
		return
	end
	local ok = GF.Listing:Create(params)
	if not ok then
		showCreateError(L.CREATE_FAILED or "Listing failed. Please try again.")
		return
	end
	if GF.CreateDrawer then
		GF.CreateDrawer:Close()
	end
end



function CP:Show()
	if not self.parent or not self.scroll then
		return
	end
	self:StartCreateFieldOwnershipWatch()
	self:RefreshCreateFieldHandoff()
	self:UpdateRequirementLayout()
	if self.selection then
		local activityID = resolveActivityID(self.selection)
		if activityID then
			self:SyncEntryCreationStateIfNeeded(self.selection, activityID)
		end
	end
	self:SyncEmbeddedFieldChrome()
	if self.parent then
		self.parent:Show()
	end
	self:UpdateManageState()
	if C_Timer and C_Timer.After then
		C_Timer.After(0, function()
			if isCreateDrawerFieldSurfaceActive() then
				CP:RefreshCreateFieldHandoff()
				CP:UpdateRequirementLayout()
				CP:SyncEmbeddedFieldChrome()
				CP:UpdateManageState()
				CP:UpdateScrollLayout()
			end
		end)
	end
	self:UpdateScrollLayout()
end



function CP:Hide(reason)
	if not self.parent then
		return
	end
	self:StopCreateFieldOwnershipWatch()
	self:ReleaseCreateFields(reason or "panel")
	self:SetCreateChannelBlocked(false)
	self.parent:Hide()
end

function CP:LeaveTab()
	self:Hide("tab")
end
