local _, GF = ...

-- Installs CreatePanel's form construction, submission, and visible lifecycle.
-- The installer keeps the public GF.CreatePanel surface stable while allowing
-- the large implementation to compile in a separate Lua chunk.
GF.CreatePanelLifecycle = GF.CreatePanelLifecycle or {}
local Lifecycle = GF.CreatePanelLifecycle

function Lifecycle.Install(CP, dependencies)
	assert(type(CP) == "table", "CreatePanel table is required")
	dependencies = dependencies or {}
	local BB = dependencies.BB
	local NativeCreation = dependencies.NativeCreation
	local FormPresenter = dependencies.FormPresenter
	local DEFAULT_PLAYSTYLE = dependencies.DEFAULT_PLAYSTYLE
	local DEFAULT_REQUIRED_DUNGEON_SCORE = dependencies.DEFAULT_REQUIRED_DUNGEON_SCORE
	local PLAYSTYLE_OPTIONS = dependencies.PLAYSTYLE_OPTIONS
	local playstyleText = dependencies.playstyleText
	local selectedPlaystyleText = dependencies.selectedPlaystyleText
	local trimName = dependencies.trimName
	local NATIVE_FIELD_SIZE = dependencies.NATIVE_FIELD_SIZE
	local FIELD_EDGE_PAD = dependencies.FIELD_EDGE_PAD
	local REQ_EDIT_W = dependencies.REQ_EDIT_W
	local REQ_EDIT_H = dependencies.REQ_EDIT_H
	local FIELD_GAP = dependencies.FIELD_GAP
	local LABEL_FIELD_GAP = dependencies.LABEL_FIELD_GAP
	local DESC_FIELD_GAP = dependencies.DESC_FIELD_GAP
	local CREATE_PAD = dependencies.CREATE_PAD
	local FORM_LEFT_INSET = dependencies.FORM_LEFT_INSET
	local CREATE_FORM_INSET_X = dependencies.CREATE_FORM_INSET_X
	local CREATE_FORM_INSET_TOP = dependencies.CREATE_FORM_INSET_TOP
	local CREATE_MANAGER_DISABLED_VISUAL = dependencies.CREATE_MANAGER_DISABLED_VISUAL
	local MPLUS_LFG_SIDEBAR_CONTROL_W = dependencies.MPLUS_LFG_SIDEBAR_CONTROL_W
	local CREATE_FORM_INPUT_H = dependencies.CREATE_FORM_INPUT_H
	local CREATE_FORM_DESC_ATLAS_PAD_Y = dependencies.CREATE_FORM_DESC_ATLAS_PAD_Y
	local CREATE_FORM_DESC_ATLAS_H = dependencies.CREATE_FORM_DESC_ATLAS_H
	local BUTTON_BAR_H = dependencies.BUTTON_BAR_H
	local LIST_BTN_BOTTOM = dependencies.LIST_BTN_BOTTOM
	local LIST_BTN_W = dependencies.LIST_BTN_W
	local LIST_BTN_GAP = dependencies.LIST_BTN_GAP
	local DROPDOWN_H = dependencies.DROPDOWN_H
	local DROPDOWN_LEFT_NUDGE = dependencies.DROPDOWN_LEFT_NUDGE
	local REQ_FIELD_LEFT_NUDGE = dependencies.REQ_FIELD_LEFT_NUDGE
	local CREATE_CHECK_SIZE = dependencies.CREATE_CHECK_SIZE
	local CREATE_CHECK_LABEL_GAP = dependencies.CREATE_CHECK_LABEL_GAP
	local CREATE_FIELD_OWNER = dependencies.CREATE_FIELD_OWNER
	local getFactionRestrictionLabel = dependencies.getFactionRestrictionLabel
	local getFactionRestrictionTip = dependencies.getFactionRestrictionTip
	local getDefaultRequiredItemLevel = dependencies.getDefaultRequiredItemLevel
	local clampRequiredItemLevel = assert(
		type(dependencies.clampRequiredItemLevel) == "function"
			and dependencies.clampRequiredItemLevel,
		"CreatePanel clampRequiredItemLevel dependency is required"
	)
	local showCreateOptionTooltip = dependencies.showCreateOptionTooltip
	local setCheckHitRectToLabel = dependencies.setCheckHitRectToLabel
	local applyProtectedCreationGate = dependencies.applyProtectedCreationGate
	local updateCreateInputBox = dependencies.updateCreateInputBox
	local updateCreateInputAtlasFrame = dependencies.updateCreateInputAtlasFrame
	local updateCreateDescriptionAtlasFrame = dependencies.updateCreateDescriptionAtlasFrame
	local styleCreateInputAtlasFrame = dependencies.styleCreateInputAtlasFrame
	local styleCreateDescriptionAtlasFrame = dependencies.styleCreateDescriptionAtlasFrame
	local updateBorrowedDescriptionAtlas = dependencies.updateBorrowedDescriptionAtlas
	local styleCreateInputBox = dependencies.styleCreateInputBox
	local applyCreateTitleTextStyle = dependencies.applyCreateTitleTextStyle
	local getCreateDrawerFooter = dependencies.getCreateDrawerFooter
	local resolveActivityID = dependencies.resolveActivityID
	local getEntryCreation = dependencies.getEntryCreation
	local isCreateFieldSurfaceActive = dependencies.isCreateFieldSurfaceActive
	local isCreateChannelBlocked = dependencies.isCreateChannelBlocked
	local updateBorrowedVoiceAtlas = dependencies.updateBorrowedVoiceAtlas
	local blurCreationControls = assert(
		type(dependencies.blurCreationControls) == "function"
			and dependencies.blurCreationControls,
		"CreatePanel blurCreationControls dependency is required"
	)

	local function selectionRequiresProtectedPrebuiltTitle(panel)
		return FormPresenter:SelectionRequiresProtectedPrebuiltTitle(panel)
	end

	local function isCreateableSelection(node)
		return FormPresenter:IsSelectionCreateable(CP, node)
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

	local function refreshNativeProtectedFieldInteraction(creation)
		if creation == nil or creation.selectedActivity == nil then
			return false
		end
		if type(LFGListEntryCreation_UpdateAuthenticatedState) == "function" then
			pcall(LFGListEntryCreation_UpdateAuthenticatedState, creation)
		end
		if creation.Name and creation.Name.UpdateEnabledState then
			pcall(creation.Name.UpdateEnabledState, creation.Name)
		end
		if creation.Description and creation.Description.UpdateEnabledState then
			pcall(
				creation.Description.UpdateEnabledState,
				creation.Description
			)
		end
		return true
	end

	local function showCreateError(msg)
		if GF.ShowWarningMessage then
			GF.ShowWarningMessage(msg)
		end
	end

	local function createSizedFrame(parent, width, height)
		local frame = CreateFrame("Frame", nil, parent)
		frame:SetSize(width, height)
		return frame
	end

	local function createFormTitle(parent, text)
		local label = GF.UI.CreateFontString(parent, "OVERLAY", "GameFontNormal")
		label:SetText(text)
		applyCreateTitleTextStyle(label)
		return label
	end

	local function createPlaceholder(parent, verticalAlignment)
		local placeholder = GF.UI.CreateFontString(
			parent,
			"OVERLAY",
			"GameFontDisableSmall"
		)
		placeholder._gfCreatePlaceholder = true
		placeholder:SetJustifyH("LEFT")
		placeholder:SetWordWrap(verticalAlignment == "TOP")
		if verticalAlignment == "TOP" and placeholder.SetNonSpaceWrap then
			placeholder:SetNonSpaceWrap(true)
		end
		placeholder:SetTextColor(0.55, 0.55, 0.55, 1)
		if verticalAlignment ~= nil then
			placeholder:SetJustifyV(verticalAlignment)
		end
		placeholder:Hide()
		return placeholder
	end

	local function createRequirementEdit(parent, anchor, numeric)
		local editBox = CreateFrame("EditBox", nil, parent, "LFGListEditBoxTemplate")
		editBox:SetPoint("TOPLEFT", anchor, "TOPLEFT")
		editBox:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT")
		GF.UI.TrackEditBox(editBox, "GameFontHighlightSmall")
		if numeric == true then
			editBox:SetNumeric(true)
		end
		styleCreateInputBox(editBox)
		return editBox
	end

	local function normalizeRequiredItemLevelInput(panel, canonicalize)
		local editBox = panel and panel.ilvlEdit
		if not editBox or panel._normalizingRequiredItemLevel then
			return nil
		end
		-- Read-only members display the published threshold. Check live permission
		-- before focus loss can run while the old field is still enabled.
		local listing = GF.RecruitmentSession
		if listing and type(listing.CanPublish) == "function"
			and listing:CanPublish() ~= true
		then
			return nil
		end
		local rawText = editBox:GetText()
		local rawNumber = tonumber(rawText)
		if canonicalize ~= true and rawNumber == nil then
			return nil
		end
		local normalized = clampRequiredItemLevel(rawText)
		if type(normalized) ~= "number" then
			return nil
		end
		normalized = math.max(0, math.floor(normalized))
		if canonicalize == true or rawNumber > normalized then
			local normalizedText = tostring(normalized)
			if rawText ~= normalizedText then
				panel._normalizingRequiredItemLevel = true
				editBox:SetText(normalizedText)
				panel._normalizingRequiredItemLevel = nil
			end
		end
		return normalized
	end

	local function addOptionHover(check, titleProvider, tipProvider)
		check:SetScript("OnEnter", function(button)
			GF.UI.SetFilterCheckButtonHovered(button, true)
			showCreateOptionTooltip(button, titleProvider(), tipProvider())
		end)
		check:SetScript("OnLeave", function(button)
			GF.UI.SetFilterCheckButtonHovered(button, false)
			GameTooltip_Hide()
		end)
	end

	local function createFormOption(parent, text, titleProvider, tipProvider)
		local check = GF.UI.CreateFilterCheckButton(parent, {
			size = CREATE_CHECK_SIZE,
			markSize = 16,
		})
		local label = GF.UI.CreateFontString(parent, "OVERLAY", "GameFontNormal")
		label:SetPoint("LEFT", check, "RIGHT", CREATE_CHECK_LABEL_GAP, 0)
		label:SetJustifyH("LEFT")
		label:SetText(text)
		setCheckHitRectToLabel(check, label)
		addOptionHover(check, titleProvider, tipProvider)
		return check, label
	end

	local function createFormScroll(panel, parent)
		local footer = getCreateDrawerFooter(parent)
		local scroll = GF.UI.CreateScrollFrame(parent, {
			rowHeight = GF.CREATE_WHEEL_ROW_H or 24,
		})
		if footer ~= nil then
			scroll:SetPoint(
				"TOPLEFT",
				parent,
				"TOPLEFT",
				CREATE_FORM_INSET_X,
				-CREATE_FORM_INSET_TOP
			)
			scroll:SetPoint(
				"BOTTOMRIGHT",
				parent,
				"BOTTOMRIGHT",
				-CREATE_FORM_INSET_X,
				0
			)
			if scroll.ScrollBar ~= nil then
				scroll.ScrollBar:Hide()
			end
		else
			scroll:SetPoint("TOPLEFT", parent, "TOPLEFT", CREATE_PAD, -4)
			scroll:SetPoint(
				"BOTTOMRIGHT",
				parent,
				"BOTTOMRIGHT",
				-(GF.CONTENT_SCROLL_INSET_R or 18),
				BUTTON_BAR_H
			)
			panel.scrollBar = GF.UI.CreateContentScrollBar(scroll, parent)
		end
		scroll:SetFrameLevel(parent:GetFrameLevel() + 2)
		if GF.UI.BindSmoothWheelScrolling then
			GF.UI.BindSmoothWheelScrolling(scroll)
		end
		return scroll, footer
	end

	local function createFormActions(panel, parent, footer, labels)
		local host = footer or parent
		local bottom = footer and (GF.FILTER_FOOTER_BUTTON_OFFSET_Y or 12)
			or LIST_BTN_BOTTOM
		local halfSpan = math.floor((LIST_BTN_W + LIST_BTN_GAP) / 2)
		panel.listBtn = GF.UI.CreatePanelButton(
			host,
			labels.CREATE_LISTING or "List Group",
			LIST_BTN_W
		)
		panel.removeBtn = GF.UI.CreatePanelButton(
			host,
			labels.REMOVE_LISTING or "Remove",
			LIST_BTN_W
		)
		panel.favoriteBtn = GF.UI.CreatePanelButton(
			host,
			labels.FAVORITE_ACTIVITY_ADD_BUTTON or "Add Favorite",
			LIST_BTN_W
		)
		panel.listBtn:SetPoint("BOTTOM", host, "BOTTOM", -halfSpan, bottom)
		panel.removeBtn:SetPoint("BOTTOM", host, "BOTTOM", halfSpan, bottom)
		panel.favoriteBtn:SetPoint(
			"BOTTOMLEFT", host, "BOTTOMLEFT", 16, bottom)
		panel.favoriteBtn:SetScript("OnClick", function()
			CP:OpenFavoriteActivityDialog()
		end)
		GF.UI.AttachActionGuard(panel.listBtn, {
			capability = "listing_leader",
			tooltipPlacement = "aboveLeft",
			onClick = function()
				CP:SubmitListing()
			end,
		})
		GF.UI.AttachActionGuard(panel.removeBtn, {
			capability = "listing_leader",
			tooltipPlacement = "aboveLeft",
			onClick = function()
				local listing = GF.RecruitmentSession
				if listing ~= nil and type(listing.HasActive) == "function"
					and listing:HasActive()
				then
					listing:Remove()
				end
			end,
		})
		panel._normalListButtonScripts = {
			onClick = panel.listBtn:GetScript("OnClick"),
			onEnter = panel.listBtn:GetScript("OnEnter"),
			onLeave = panel.listBtn:GetScript("OnLeave"),
		}
	end

	local function prepareFormRoot(panel, parent, labels)
		panel.title = GF.UI.CreateFontString(parent, "OVERLAY", "QuestFont_Huge")
		panel.title:SetPoint("TOPLEFT", parent, "TOPLEFT", CREATE_PAD, -8)
		panel.title:Hide()
		local footer
		panel.scroll, footer = createFormScroll(panel, parent)
		local body = createSizedFrame(panel.scroll, 1, 1)
		panel.formBody = body
		body:SetClipsChildren(true)
		panel.scroll:SetScrollChild(body)
		panel.formColumn = createSizedFrame(body, 1, 1)
		panel.formColumn:SetPoint("TOPLEFT", body, "TOPLEFT")
		panel.formColumn:Hide()
		return body, footer
	end

	local function populateNativeFieldSlots(panel, form, labels)
		panel.nameLabel = createFormTitle(form, labels.NAME or "Name")
		panel.nameLabel:SetPoint(
			"TOPLEFT",
			form,
			"TOPLEFT",
			FORM_LEFT_INSET,
			0
		)
		panel.nameAtlasAnchor = createSizedFrame(
			form,
			NATIVE_FIELD_SIZE.name.width + FIELD_EDGE_PAD * 2,
			CREATE_FORM_INPUT_H
		)
		panel.nameAtlasAnchor:SetPoint(
			"TOP",
			panel.nameLabel,
			"BOTTOM",
			0,
			-LABEL_FIELD_GAP
		)
		panel.nameAtlasAnchor:SetPoint("LEFT", panel.formColumn, "LEFT")
		styleCreateInputAtlasFrame(panel.nameAtlasAnchor)
		panel.nameAnchor = createSizedFrame(
			form,
			NATIVE_FIELD_SIZE.name.width,
			NATIVE_FIELD_SIZE.name.height
		)
		panel.nameAnchor:SetPoint(
			"TOPLEFT",
			panel.nameAtlasAnchor,
			"TOPLEFT",
			FIELD_EDGE_PAD,
			0
		)
		panel.namePlaceholder = createPlaceholder(form)

		panel.commentLabel = createFormTitle(
			form,
			labels.COMMENT or "Description"
		)
		panel.commentLabel:SetPoint(
			"TOP",
			panel.nameAtlasAnchor,
			"BOTTOM",
			0,
			-FIELD_GAP
		)
		panel.commentLabel:SetPoint("LEFT", panel.formColumn, "LEFT")
		panel.descAtlasAnchor = createSizedFrame(
			form,
			NATIVE_FIELD_SIZE.description.width + FIELD_EDGE_PAD * 2,
			CREATE_FORM_DESC_ATLAS_H
		)
		panel.descAtlasAnchor:SetPoint(
			"TOP",
			panel.commentLabel,
			"BOTTOM",
			0,
			-DESC_FIELD_GAP
		)
		panel.descAtlasAnchor:SetPoint("LEFT", panel.formColumn, "LEFT")
		styleCreateDescriptionAtlasFrame(panel.descAtlasAnchor)
		panel.descAnchor = createSizedFrame(
			form,
			NATIVE_FIELD_SIZE.description.width,
			NATIVE_FIELD_SIZE.description.height
		)
		panel.descAnchor:SetPoint(
			"TOPLEFT",
			panel.descAtlasAnchor,
			"TOPLEFT",
			FIELD_EDGE_PAD,
			-CREATE_FORM_DESC_ATLAS_PAD_Y
		)
		panel.descPlaceholder = createPlaceholder(form, "TOP")
	end

	function CP:RefreshCensoredDebugNameVisual(editBox)
		local enabled = editBox ~= nil
			and (not editBox.IsEnabled or editBox:IsEnabled())
		local active = enabled and (
			editBox:HasFocus()
			or editBox._gfCreateNameHovered == true
		)
		updateCreateInputAtlasFrame(CP.nameAtlasAnchor, active, enabled)
	end

	function CP:RefreshCensoredDebugDescriptionVisual(editBox)
		local holder = CP._debugCensoredDescriptionFrame
		local enabled = editBox ~= nil
			and (not editBox.IsEnabled or editBox:IsEnabled())
		local active = enabled and (
			editBox:HasFocus()
			or editBox._gfCreateDescriptionHovered == true
		)
		if holder ~= nil then
			holder._gfCreateDescHovered = active
		end
		updateCreateDescriptionAtlasFrame(CP.descAtlasAnchor, active, enabled)
	end

	function CP:CreateCensoredDebugFields()
		local panel = self
		local nameEdit = CreateFrame("EditBox", nil, panel.nameAnchor)
		nameEdit:SetAllPoints(panel.nameAnchor)
		nameEdit:SetAutoFocus(false)
		nameEdit:SetMaxLetters(63)
		nameEdit:SetTextInsets(6, 6, 0, 0)
		nameEdit:SetTextColor(1, 0.96, 0.86, 1)
		nameEdit:SetShadowColor(0, 0, 0, 0.85)
		nameEdit:SetShadowOffset(1, -1)
		GF.UI.TrackEditBox(nameEdit, "GameFontHighlightSmall")
		nameEdit:SetScript("OnEditFocusGained", function(self)
			CP:RefreshCensoredDebugNameVisual(self)
		end)
		nameEdit:SetScript("OnEditFocusLost", function(self)
			CP:RefreshCensoredDebugNameVisual(self)
		end)
		nameEdit:SetScript("OnEnter", function(self)
			self._gfCreateNameHovered = true
			CP:RefreshCensoredDebugNameVisual(self)
		end)
		nameEdit:SetScript("OnLeave", function(self)
			self._gfCreateNameHovered = nil
			CP:RefreshCensoredDebugNameVisual(self)
		end)
		nameEdit:SetScript("OnTextChanged", function()
			panel:UpdateCustomPlaceholders()
			panel:UpdateManageState()
		end)
		nameEdit:SetScript("OnEscapePressed", function(self)
			self:ClearFocus()
		end)
		nameEdit:Hide()

		local descriptionFrame = CreateFrame("Frame", nil, panel.descAnchor)
		descriptionFrame:SetAllPoints(panel.descAnchor)
		if descriptionFrame.SetClipsChildren then
			descriptionFrame:SetClipsChildren(true)
		end
		local descriptionEdit = CreateFrame("EditBox", nil, descriptionFrame)
		descriptionEdit:SetPoint("TOPLEFT", descriptionFrame, "TOPLEFT", 0, -5)
		descriptionEdit:SetPoint("BOTTOMRIGHT", descriptionFrame, "BOTTOMRIGHT", 0, 5)
		descriptionEdit:SetAutoFocus(false)
		descriptionEdit:SetMultiLine(true)
		descriptionEdit:SetMaxLetters(255)
		descriptionEdit:SetTextInsets(6, 6, 0, 0)
		descriptionEdit:SetJustifyH("LEFT")
		descriptionEdit:SetJustifyV("TOP")
		descriptionEdit:SetTextColor(1, 0.96, 0.86, 1)
		descriptionEdit:SetShadowColor(0, 0, 0, 0.85)
		descriptionEdit:SetShadowOffset(1, -1)
		GF.UI.TrackEditBox(descriptionEdit, "GameFontHighlightSmall")
		descriptionEdit:SetScript("OnEditFocusGained", function(self)
			CP:RefreshCensoredDebugDescriptionVisual(self)
		end)
		descriptionEdit:SetScript("OnEditFocusLost", function(self)
			CP:RefreshCensoredDebugDescriptionVisual(self)
		end)
		descriptionEdit:SetScript("OnEnter", function(self)
			self._gfCreateDescriptionHovered = true
			CP:RefreshCensoredDebugDescriptionVisual(self)
		end)
		descriptionEdit:SetScript("OnLeave", function(self)
			self._gfCreateDescriptionHovered = nil
			CP:RefreshCensoredDebugDescriptionVisual(self)
		end)
		descriptionEdit:SetScript("OnTextChanged", function()
			panel:UpdateCustomPlaceholders()
		end)
		descriptionEdit:SetScript("OnEscapePressed", function(self)
			self:ClearFocus()
		end)
		descriptionFrame.EditBox = descriptionEdit
		descriptionFrame:Hide()

		panel._debugCensoredNameEdit = nameEdit
		panel._debugCensoredDescriptionFrame = descriptionFrame
		panel._debugCensoredDescriptionEdit = descriptionEdit
	end

	local function populatePreferenceControls(panel, form, labels)
		panel.playLabel = createFormTitle(
			form,
			labels.PLAYSTYLE or "Playstyle"
		)
		panel.playLabel:SetPoint(
			"TOP",
			panel.descAtlasAnchor,
			"BOTTOM",
			0,
			-FIELD_GAP
		)
		panel.playLabel:SetPoint("LEFT", panel.formColumn, "LEFT")
		panel.playDropdownAnchor = createSizedFrame(
			form,
			NATIVE_FIELD_SIZE.description.width + 10,
			DROPDOWN_H
		)
		panel.playDropdownAnchor:SetPoint(
			"TOP",
			panel.playLabel,
			"BOTTOM",
			0,
			-LABEL_FIELD_GAP
		)
		panel.playDropdownAnchor:SetPoint(
			"LEFT",
			panel.formColumn,
			"LEFT",
			DROPDOWN_LEFT_NUDGE,
			0
		)
		panel.playDropdown = GF.UI.CreateDropdownButton(form)
		panel:ApplyPlaystyleDropdownLayout()
		panel:SetupPlaystyleDropdown()

		panel.ilvlLabel = createFormTitle(
			form,
			labels.ITEM_LEVEL or "Item level"
		)
		panel.ilvlLabel:SetPoint(
			"TOP",
			panel.playDropdownAnchor,
			"BOTTOM",
			0,
			-FIELD_GAP
		)
		panel.ilvlLabel:SetPoint("LEFT", panel.formColumn, "LEFT")
		panel.ilvlAnchor = createSizedFrame(form, REQ_EDIT_W, REQ_EDIT_H)
		panel.ilvlAnchor:SetPoint(
			"TOP",
			panel.ilvlLabel,
			"BOTTOM",
			0,
			-LABEL_FIELD_GAP
		)
		panel.ilvlAnchor:SetPoint(
			"LEFT",
			panel.formColumn,
			"LEFT",
			REQ_FIELD_LEFT_NUDGE,
			0
		)
		panel.ilvlEdit = createRequirementEdit(form, panel.ilvlAnchor, true)
		panel.ilvlEdit:HookScript("OnTextChanged", function(_, userInput)
			-- SetText also fires this hook when projecting the leader's listing.
			if userInput == true then
				normalizeRequiredItemLevelInput(panel, false)
			end
		end)
		panel.ilvlEdit:HookScript("OnEditFocusLost", function()
			normalizeRequiredItemLevelInput(panel, true)
		end)
		panel.ilvlEdit:HookScript("OnEnterPressed", function(editBox)
			editBox:ClearFocus()
		end)

		panel.mplusLabel = createFormTitle(
			form,
			labels.MYTHIC_SCORE or "M+ score"
		)
		panel.mplusAnchor = createSizedFrame(form, REQ_EDIT_W, REQ_EDIT_H)
		panel.mplusEdit = createRequirementEdit(form, panel.mplusAnchor, true)
		panel.voiceLabel = createFormTitle(
			form,
			labels.VOICE_CHAT or LFG_LIST_VOICE_CHAT or "Voice chat"
		)
		panel.voiceAnchor = styleCreateInputAtlasFrame(
			createSizedFrame(form, REQ_EDIT_W, REQ_EDIT_H)
		)
		panel:UpdateRequirementLayout()
	end

	local function populateListingOptions(panel, form, labels)
		panel.crossFactionCheck, panel.crossFactionLabel = createFormOption(
			form,
			getFactionRestrictionLabel(),
			getFactionRestrictionLabel,
			getFactionRestrictionTip
		)
		panel.crossFactionCheck:SetPoint(
			"TOP",
			panel.voiceAnchor,
			"BOTTOM",
			0,
			-8
		)
		panel.crossFactionCheck:SetPoint("LEFT", panel.formColumn, "LEFT")
		panel.crossFactionLabel:SetTextColor(1, 0.82, 0)
		local function privateTitle()
			return (GF.L and GF.L.PRIVATE) or "Private"
		end
		local function privateTip()
			return (GF.L and GF.L.PRIVATE_TIP) or ""
		end
		panel.privateCheck, panel.privateLabel = createFormOption(
			form,
			labels.PRIVATE or "Private",
			privateTitle,
			privateTip
		)
		panel.privateCheck:SetPoint(
			"TOP",
			panel.crossFactionCheck,
			"BOTTOM",
			0,
			-8
		)
		panel.privateCheck:SetPoint("LEFT", panel.formColumn, "LEFT")
		panel:UpdateRequirementLayout()
	end

	local function handleCreatePanelSizeChanged()
		if CP._frameResizing ~= true then
			CP:ScheduleUpdateScrollLayout()
		end
	end

	local function initializeCreatePanelLifecycle(panel, parent)
		FormPresenter:Bind(panel)
		panel:UpdatePlaystyleDropdown()
		panel:InstallEntryCreationHooks()
		parent:SetScript("OnSizeChanged", handleCreatePanelSizeChanged)
		panel:UpdateScrollLayout()
	end

	function CP:Init(parent)
		if self.scroll ~= nil then
			return false
		end
		self.parent = parent
		FormPresenter:Bind(self)
		FormPresenter:Reset(self)
		self.generalPlaystyle = DEFAULT_PLAYSTYLE
		local labels = GF.L or {}
		local form, footer = prepareFormRoot(self, parent, labels)
		populateNativeFieldSlots(self, form, labels)
		self:CreateCensoredDebugFields()
		populatePreferenceControls(self, form, labels)
		populateListingOptions(self, form, labels)
		createFormActions(self, parent, footer, labels)
		initializeCreatePanelLifecycle(self, parent)
		return true
	end



	function CP:ApplyPlaystyleDropdownLayout()
		local button, anchor = self.playDropdown, self.playDropdownAnchor
		if button == nil or anchor == nil then
			return false
		end
		local anchorWidth = type(anchor.GetWidth) == "function"
			and tonumber(anchor:GetWidth()) or nil
		local _, descriptionWidth = self:GetCreateFieldWidths()
		local width = descriptionWidth
		if self:IsMythicPlusSidebarMode() then
			width = MPLUS_LFG_SIDEBAR_CONTROL_W
		elseif anchorWidth ~= nil and anchorWidth > 1 then
			width = anchorWidth
		end
		anchor:SetSize(width, DROPDOWN_H)
		button:SetSize(width, DROPDOWN_H)
		button:ClearAllPoints()
		button:SetPoint("TOPLEFT", anchor, "TOPLEFT")
		return true
	end

	function CP:SetupPlaystyleDropdown()
		local dropdown = self.playDropdown
		if dropdown == nil or type(dropdown.SetupMenu) ~= "function" then
			return false
		end
		dropdown:SetupMenu(function(_, menu)
			menu:SetTag("MENU_GF_PLAYSTYLE")
			for optionIndex = 1, #PLAYSTYLE_OPTIONS do
				local option = PLAYSTYLE_OPTIONS[optionIndex]
				menu:CreateRadio(
					playstyleText(option),
					function(styleID)
						return CP.generalPlaystyle == styleID
					end,
					function(styleID)
						CP.generalPlaystyle = styleID
						CP:UpdatePlaystyleDropdown()
						local selected = CP.selection
						local activityID = selected and resolveActivityID(selected)
						if activityID ~= nil then
							CP:SyncEntryCreationState(selected, activityID)
						end
					end,
					option.id
				)
			end
		end)
		return true
	end



	function CP:UpdatePlaystyleDropdown()
		local dropdown = self.playDropdown
		if dropdown == nil then
			return false
		end
		local label = selectedPlaystyleText(self.generalPlaystyle)
		if self.generalPlaystyle == Enum.LFGEntryGeneralPlaystyle.None then
			label = GROUP_FINDER_PLAYSTYLE_REQUIRED
				or (GF.L and GF.L.PLAYSTYLE_REQUIRED)
				or "Select playstyle"
			local color = DISABLED_FONT_COLOR
			if color ~= nil and type(color.WrapTextInColorCode) == "function" then
				label = color:WrapTextInColorCode(label)
			end
		end
		dropdown:SetDefaultText(label)
		if type(dropdown.GenerateMenu) == "function" then
			dropdown:GenerateMenu()
		end
		self:ApplyPlaystyleDropdownLayout()
		return true
	end



	function CP:UpdateCrossFactionOption()
		local check, label = self.crossFactionCheck, self.crossFactionLabel
		if check == nil then
			return false
		end
		if self:IsMythicPlusSidebarMode() then
			check:Hide()
			if label ~= nil then
				label:Hide()
			end
			return true
		end

		if self._showCompleteDisabledForm == true then
			check._gfActivityDisabled = true
			check:SetEnabled(false)
			check:Show()
			if label ~= nil then
				label:SetText(getFactionRestrictionLabel())
				label:SetTextColor(1, 0.82, 0)
				label:Show()
			end
			self:ApplyCompactRowLayout()
			self:UpdateScrollLayout()
			return true
		end

		local selected = self.selection
		local activityID = selected and resolveActivityID(selected)
		local category = selected and selected.categoryID
			and NativeCreation:GetLfgCategoryInfo(selected.categoryID) or nil
		local activity = selected and selected.activityInfo
		if activity == nil and activityID ~= nil then
			activity = NativeCreation:GetActivityInfoTable(activityID)
		end
		local available = activityID ~= nil and category ~= nil
			and category.allowCrossFaction == true
			and activity ~= nil and activity.allowCrossFaction == true
		if available then
			check._gfActivityDisabled = nil
		else
			check._gfActivityDisabled = true
		end
		check:SetEnabled(available)
		check:SetShown(available)
		if label ~= nil then
			label:SetShown(available)
			if available then
				label:SetTextColor(1, 0.82, 0)
			end
		end
		self:ApplyCompactRowLayout()
		self:UpdateScrollLayout()
		return true
	end



	function CP:UpdateScoreRequirementVisibility(activityInfo)
		if not self.mplusLabel then
			return
		end
		local show = self:IsMythicPlusSidebarMode()
			or self._showCompleteDisabledForm
			or (activityInfo and activityInfo.isMythicPlusActivity)
		self.mplusLabel:SetShown(show)
		self.mplusEdit:SetShown(show)
		if self.mplusAnchor then
			self.mplusAnchor:SetShown(show)
		end
	end



	function CP:ResetAfterListingRemoved()
		self:CancelEditFieldReveal()
		self._pendingOpenMode = nil
		self._protectedCreationTextDraftPrepared = nil
		self._protectedCreateDraftPresented = nil
		self._syncedActivityID = nil
		self._syncedNodeKey = nil
		FormPresenter:Reset(self)
		self:UpdateListButtonLabel()
		self:UpdateManageState()
	end

	function CP:SetSelection(node, opts)
		local projection = FormPresenter:Select(self, node, opts)
		if type(node) ~= "table" then
			self:UpdateManageState()
			return false
		end
		if isCreateFieldSurfaceActive() then
			self:TryAttachIfNeeded()
		else
			self:ReleaseCreateFields("tab")
		end
		local activityID = projection.activityID
		if activityID ~= nil then
			self:SyncEntryCreationStateIfNeeded(node, activityID)
		end
		local info = projection.activityInfo
		local drawer = GF.CreateDrawer
		if drawer ~= nil and type(drawer.SyncActivityTitle) == "function" then
			drawer:SyncActivityTitle()
		end
		self:UpdateScoreRequirementVisibility(info)
		self:UpdateRequirementLayout()
		self:UpdateCrossFactionOption()
		self:UpdateScrollLayout()
		self:UpdateManageState()
		return true
	end

	function CP:SetWorkspaceContext(context)
		FormPresenter:SetWorkspaceContext(self, context)
		if self.listBtn then
			self:UpdateManageState()
		end
	end



	local function listingProblemText(problem)
		return FormPresenter:DescribeProblem(problem, GF.L)
	end

	function CP:NormalizeRequiredItemLevelInput(canonicalize)
		return normalizeRequiredItemLevelInput(self, canonicalize)
	end

	function CP:CaptureListingDraft(opts)
		self:NormalizeRequiredItemLevelInput(true)
		return FormPresenter:CaptureDraft(self, opts)
	end

	function CP:GetFavoriteActivityName()
		local node = self.selection
		local activityID = node and resolveActivityID(node)
		if not activityID then
			return nil
		end
		local info = node.activityInfo
		if info == nil then
			local ok, value = pcall(
				NativeCreation.GetActivityInfoTable,
				NativeCreation,
				activityID
			)
			info = ok and value or nil
		end
		for _, value in ipairs({
			info and info.fullName,
			info and info.shortName,
			node.label,
		}) do
			if type(value) == "string" and value ~= "" then
				return value
			end
		end
		return nil
	end

	function CP:ApplyFavoritePreset(identity)
		local favorites = GF.FavoriteInstances
		local record = favorites and favorites.GetRecord
			and favorites:GetRecord(identity) or nil
		local preset = record and record.preset
		if type(preset) ~= "table" then
			return false
		end
		local style = tonumber(preset.generalPlaystyle)
		if style ~= nil then
			self.generalPlaystyle = style
		end
		if self.ilvlEdit then
			self.ilvlEdit:SetText(tostring(
				math.max(0, tonumber(preset.requiredItemLevel) or 0)))
			self._defaultRequiredItemLevelText = nil
		end
		if self.mplusEdit then
			self.mplusEdit:SetText(tostring(
				math.max(0, tonumber(preset.requiredDungeonScore) or 0)))
		end
		if self.privateCheck then
			self.privateCheck:SetChecked(preset.privateGroup == true)
		end
		if self.crossFactionCheck then
			self.crossFactionCheck:SetChecked(
				preset.factionRestricted == true)
		end
		self:UpdatePlaystyleDropdown()
		self:UpdateCrossFactionOption()
		self:UpdateRequirementLayout()
		self:UpdateManageState()
		return true
	end

	function CP:OpenFavoriteActivityDialog()
		local dialog = GF.FavoriteActivityDialog
		local favorites = GF.FavoriteInstances
		local activityName = self:GetFavoriteActivityName()
		if not (dialog and dialog.Show and favorites and favorites.SavePreset
			and activityName and isCreateableSelection(self.selection))
		then
			return false
		end
		local recordIdentity = self._favoriteSourceIdentity
		local record = recordIdentity and favorites.GetRecord
			and favorites:GetRecord(recordIdentity) or nil
		if recordIdentity and not record then
			recordIdentity = nil
			self._favoriteSourceIdentity = nil
		end
		local node = self.selection
		local draft = self:CaptureListingDraft()
		return dialog:Show({
			activityName = activityName,
			recordIdentity = recordIdentity,
			customName = record and record.customName or nil,
			onSelectScope = function(scope, customName)
				local saved, identity, action = favorites:SavePreset(
					recordIdentity,
					node,
					draft,
					customName,
					scope
				)
				if saved ~= true then
					return false
				end
				CP._favoriteSourceIdentity = identity
				CP._pendingFavoritePresetIdentity = nil
				CP:UpdateFavoriteButtonState()
				if GF.ShowTopNotice then
					local L = GF.L or {}
					GF.ShowTopNotice(
						action == "updated"
							and (L.FAVORITE_ACTIVITY_UPDATED
								or "Favorite updated")
							or (L.FAVORITE_ACTIVITY_ADDED
								or "Added to Activity Favorites"),
						{ source = "favorite_activity", playSound = false })
				end
				return true
			end,
		})
	end

	function CP:UpdateFavoriteButtonState()
		local button = self.favoriteBtn
		if not button then
			return false
		end
		local listing = GF.RecruitmentSession
		local hasActive = listing and listing.HasActive and listing:HasActive() or false
		local busy = listing and listing.IsBusy and listing:IsBusy() or false
		local canLead = listing and listing.CanPublish and listing:CanPublish() or false
		local context = self.workspaceContext
		local meetingStone = context == nil
			or context.workspaceID == (GF.WORKSPACE_MEETING_STONE or "standard")
		local visible = meetingStone
			and not self:IsMythicPlusSidebarMode()
			and self.debugCensoredPreviewMode ~= true
			and self.editMode ~= true
			and not hasActive
			and isCreateableSelection(self.selection)
		button:SetShown(visible)
		if not visible then
			return false
		end
		local favorites = GF.FavoriteInstances
		local record = self._favoriteSourceIdentity
			and favorites and favorites.GetRecord
			and favorites:GetRecord(self._favoriteSourceIdentity) or nil
		if self._favoriteSourceIdentity and not record then
			self._favoriteSourceIdentity = nil
		end
		local L = GF.L or {}
		if record then
			button:SetText(type(record.preset) == "table"
				and (L.FAVORITE_ACTIVITY_UPDATE_BUTTON or "Update Favorite")
				or (L.FAVORITE_ACTIVITY_SAVE_SETTINGS_BUTTON or "Save Settings"))
		else
			button:SetText(L.FAVORITE_ACTIVITY_ADD_BUTTON or "Add Favorite")
		end
		local label = button.Label
			or (button.GetFontString and button:GetFontString())
		if label and GF.Font and GF.Font.SetFitWidth then
			GF.Font.SetFitWidth(label, math.max(1, LIST_BTN_W - 10), 8)
		end
		local blocked = isCreateChannelBlocked()
		button:SetEnabled(canLead and not busy and not blocked)
		button:EnableMouse(canLead and not busy and not blocked)
		return true
	end

	function CP:ValidateListing(opts)
		self:NormalizeRequiredItemLevelInput(true)
		local valid, draftOrProblem = FormPresenter:ValidateDraft(self, opts)
		if valid == true then
			return true, draftOrProblem
		end
		showCreateError(listingProblemText(draftOrProblem))
		return false
	end

	function CP:BuildListingParams(draft)
		return FormPresenter:BuildParameters(self, draft)
	end



	function CP:UpdateListButtonLabel()
		local button = self.listBtn
		if button == nil then
			return false
		end
		button:SetText(FormPresenter:GetListButtonText(self, GF.L))
		return true
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

	function CP:ApplyDefaultRequiredDungeonScore(force)
		if self.editMode or force ~= true or not self.mplusEdit then
			return
		end
		self.mplusEdit:SetText(tostring(DEFAULT_REQUIRED_DUNGEON_SCORE))
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
		self:UpdateFavoriteButtonState()
		self:UpdateOwnershipUI()
		if GF.CreateDrawer and GF.CreateDrawer.SyncActivityTitle then
			GF.CreateDrawer:SyncActivityTitle()
		end
		self:FitMythicPlusSidebarLabels()
	end

	function CP:UpdateFormInteractionState(formEnabled)
		formEnabled = formEnabled == true
		self._protectedFieldsFormEnabled = formEnabled
		self._createManagerFormDisabled =
			self:IsCreateManagerSurface() and not formEnabled
		self._showCompleteDisabledForm = (not formEnabled) and (not isCreateChannelBlocked())
		local activityID = resolveActivityID(self.selection)
		local activityInfo = activityID and (
			self.selection.activityInfo
				or NativeCreation:GetActivityInfoTable(activityID)
		)
		self:UpdateScoreRequirementVisibility(activityInfo)
		self:UpdateCrossFactionOption()
		self:ApplyMythicPlusSidebarTitleStyle()
		if self.formBody then
			self.formBody:SetAlpha(
				(formEnabled or self:IsMythicPlusSidebarMode())
					and 1
					or 0.45
			)
		end
		if not formEnabled then
			blurCreationControls(self)
		end
		if not formEnabled and self:IsMythicPlusSidebarMode() then
			self:CaptureCreateManagerBorrowedFieldTextColors()
		end
		local creation = getEntryCreation()
		local borrowedCreation = self._attached == true
			and self:IsBorrowingBlizzardFields()
			and creation or nil
		refreshNativeProtectedFieldInteraction(borrowedCreation)
		applyProtectedCreationGate(borrowedCreation, formEnabled)
		self:ApplyCreateManagerBorrowedFieldTextVisual(
			not formEnabled and self:IsMythicPlusSidebarMode()
		)
		setWidgetEnabled(self.playDropdown, formEnabled)
		self:ApplyCreateManagerDropdownDisabledVisual(
			self.playDropdown,
			not formEnabled
		)
		setWidgetEnabled(self.ilvlEdit, formEnabled)
		setWidgetEnabled(self.mplusEdit, formEnabled)
		setWidgetEnabled(self.privateCheck, formEnabled)
		if self.crossFactionCheck and (not self.crossFactionCheck._gfActivityDisabled) then
			setWidgetEnabled(self.crossFactionCheck, formEnabled)
		end
		if self.censoredResolutionMode == true then
			-- The pending-content path only owns Blizzard's native name and
			-- description fields. Keep every unrelated listing option unchanged.
			setWidgetEnabled(self.playDropdown, false)
			setWidgetEnabled(self.ilvlEdit, false)
			setWidgetEnabled(self.mplusEdit, false)
			setWidgetEnabled(self.voiceFrame, false)
			setWidgetEnabled(self.voiceEdit, false)
			setWidgetEnabled(self.privateCheck, false)
			setWidgetEnabled(self.crossFactionCheck, false)
			if self.debugCensoredPreviewMode == true then
				updateCreateInputAtlasFrame(self.voiceAnchor, false, false)
			end
		end
		local nameEnabled = self.nameEdit
			and (not self.nameEdit.IsEnabled or self.nameEdit:IsEnabled())
			or false
		updateCreateInputAtlasFrame(
			self.nameAtlasAnchor,
			nameEnabled
				and self.nameEdit
				and (
					self.nameEdit:HasFocus()
					or self.nameEdit._gfCreateNameHovered
				),
			nameEnabled
		)
		updateBorrowedDescriptionAtlas(self.commentScroll)
		updateCreateInputBox(self.ilvlEdit)
		updateCreateInputBox(self.mplusEdit)
		updateBorrowedVoiceAtlas(self, self.voiceFrame)
		-- The Mythic+ unavailable projection intentionally has no concrete activity,
		-- so Blizzard's protected fields cannot be borrowed. Keep the addon-owned
		-- empty-field hints anchored to the inert visual slots in that state.
		self:LayoutCustomPlaceholders()
		self:UpdateCustomPlaceholders()
		if self.raidNeedsUI then self.raidNeedsUI:RefreshSelection() end
	end

	function CP:HasRequiredCreateFields()
		return FormPresenter:HasRequiredCreateFields(self)
	end

	function CP:UpdateManageState()
		if not self.listBtn then
			return
		end
		local blocked = isCreateChannelBlocked()
		local projection = FormPresenter:ProjectManageState(self, {
			channelBlocked = blocked,
			requiredComplete = self:HasRequiredCreateFields(),
		})
		self._mythicPlusSidebarReadOnly = projection.mythicPlusReadOnly
		self._showCompleteDisabledForm = projection.showCompleteDisabledForm
		self.listBtn:SetText(projection.listButtonText)
		local preserveDisabledButtonAlpha =
			projection.preserveDisabledButtonAlpha
			and CREATE_MANAGER_DISABLED_VISUAL.preserveButtonAlpha ~= false
		if GF.UI and GF.UI.SetCommonPanelButtonPreserveDisabledAlpha then
			GF.UI.SetCommonPanelButtonPreserveDisabledAlpha(
				self.listBtn,
				preserveDisabledButtonAlpha
			)
			GF.UI.SetCommonPanelButtonPreserveDisabledAlpha(
				self.removeBtn,
				preserveDisabledButtonAlpha
			)
		end
		setWidgetEnabled(
			self._debugCensoredNameEdit,
			projection.debugNameEnabled == true
		)
		setWidgetEnabled(
			self._debugCensoredDescriptionEdit,
			projection.debugDescriptionEnabled == true
		)
		self:UpdateFormInteractionState(projection.formEnabled)
		self.listBtn:SetEnabled(projection.submitEnabled)
		if self.debugCensoredPreviewMode == true then
			self.listBtn:EnableMouse(projection.submitMouseEnabled == true)
		end
		if self.removeBtn then
			self.removeBtn:SetEnabled(projection.removeEnabled)
			if self.debugCensoredPreviewMode == true then
				self.removeBtn:EnableMouse(false)
			end
		end
		self:UpdateFavoriteButtonState()
	end

	function CP:SetCensoredDebugButtonScripts(enabled)
		local panel = self
		local button = panel.listBtn
		local normal = panel._normalListButtonScripts
		if button == nil or normal == nil then
			return
		end
		if enabled then
			button:SetScript("OnClick", function()
				if panel.censoredResolutionMode == true then
					CP:SubmitListing()
				elseif GF.CensoredActiveEntryDialog
					and GF.CensoredActiveEntryDialog.Show
				then
					GF.CensoredActiveEntryDialog:Show({
						debugPreview = true,
					})
				end
			end)
			button:SetScript("OnEnter", function(self)
				if GF.UI.SetCommonPanelButtonHovered then
					GF.UI.SetCommonPanelButtonHovered(self, true)
				end
			end)
			button:SetScript("OnLeave", function(self)
				if GF.UI.SetCommonPanelButtonHovered then
					GF.UI.SetCommonPanelButtonHovered(self, false)
				end
				if GameTooltip then
					GameTooltip:Hide()
				end
			end)
			return
		end
		button:SetScript("OnClick", normal.onClick)
		button:SetScript("OnEnter", normal.onEnter)
		button:SetScript("OnLeave", normal.onLeave)
	end

	function CP:SetCensoredDebugLockedVisual(locked)
		local alpha = locked and 0.45 or 1
		for _, widget in ipairs({
			self.playLabel,
			self.playDropdownAnchor,
			self.playDropdown,
			self.ilvlLabel,
			self.ilvlAnchor,
			self.ilvlEdit,
			self.mplusLabel,
			self.mplusAnchor,
			self.mplusEdit,
			self.voiceLabel,
			self.voiceAnchor,
			self.voiceFrame,
			self.crossFactionCheck,
			self.crossFactionLabel,
			self.privateCheck,
			self.privateLabel,
		}) do
			if widget and widget.SetAlpha then
				widget:SetAlpha(alpha)
			end
		end
	end

	function CP:CanUseCensoredDebugPreview()
		local debugService = GF.Debug
		if debugService == nil
			or type(debugService.IsDebugModeEnabled) ~= "function"
			or debugService:IsDebugModeEnabled() ~= true
			or type(debugService.GetActiveCensoredDemoState) ~= "function"
			or debugService:GetActiveCensoredDemoState() == nil
		then
			return false
		end
		local listing = GF.RecruitmentSession
		return not (listing ~= nil
			and type(listing.HasActive) == "function"
			and listing:HasActive() == true)
	end

	function CP:ExitCensoredDebugPreview()
		if self.debugCensoredPreviewMode ~= true then
			return false
		end
		blurCreationControls(self)
		self:SetCensoredDebugButtonScripts(false)
		self:SetCensoredDebugLockedVisual(false)
		if self._debugCensoredNameEdit then
			self._debugCensoredNameEdit:Hide()
		end
		if self._debugCensoredDescriptionFrame then
			self._debugCensoredDescriptionFrame:Hide()
		end
		self.nameEdit = nil
		self.commentScroll = nil
		FormPresenter:Transition(self, FormPresenter.MODE_CREATE)
		self._debugCensoredOriginalName = nil
		self._debugCensoredOriginalComment = nil
		setWidgetEnabled(self._debugCensoredNameEdit, true)
		setWidgetEnabled(self._debugCensoredDescriptionEdit, true)
		if self.removeBtn then
			self.removeBtn:EnableMouse(true)
		end
		updateCreateInputAtlasFrame(self.nameAtlasAnchor, false, true)
		updateCreateDescriptionAtlasFrame(self.descAtlasAnchor, false, true)
		updateCreateInputAtlasFrame(self.voiceAnchor, false, true)
		return true
	end

	function CP:PrepareForCensoredDebugPreview(opts)
		opts = opts or {}
		if not self:CanUseCensoredDebugPreview() then
			return false
		end
		local resolving = opts.censoredResolution ~= false
		if self.debugCensoredPreviewMode == true then
			FormPresenter:Transition(
				self,
				FormPresenter.MODE_DEBUG_CENSORED,
				{ censoredResolution = resolving }
			)
			if opts.resetText == true then
				self._debugCensoredNameEdit:SetText(
					self._debugCensoredOriginalName or ""
				)
				self._debugCensoredDescriptionEdit:SetText(
					self._debugCensoredOriginalComment or ""
				)
			end
			self:UpdateListButtonLabel()
			self:UpdateManageState()
			self:SetCensoredDebugLockedVisual(true)
			self:RefreshCensoredDebugNameVisual(
				self._debugCensoredNameEdit
			)
			self:RefreshCensoredDebugDescriptionVisual(
				self._debugCensoredDescriptionEdit
			)
			return true
		else
			self:ReleaseCreateFields("tab")
		end
		local L = GF.L or {}
		self._pendingOpenMode = nil
		FormPresenter:Transition(
			self,
			FormPresenter.MODE_DEBUG_CENSORED,
			{ censoredResolution = resolving }
		)
		self.nameEdit = self._debugCensoredNameEdit
		self.commentScroll = self._debugCensoredDescriptionFrame
		self.voiceFrame = nil
		self.voiceEdit = nil
		self._debugCensoredOriginalName =
			L.DEBUG_CENSORED_EDIT_PREVIEW_SAMPLE_NAME
			or "Example recruitment group"
		self._debugCensoredOriginalComment =
			L.DEBUG_CENSORED_EDIT_PREVIEW_SAMPLE_COMMENT
			or "Change the recruitment name or description before submitting"
		self._debugCensoredNameEdit:SetText(self._debugCensoredOriginalName)
		self._debugCensoredDescriptionEdit:SetText(
			self._debugCensoredOriginalComment
		)
		self._debugCensoredNameEdit:Show()
		self._debugCensoredDescriptionFrame:Show()
		self.generalPlaystyle = DEFAULT_PLAYSTYLE
		self.ilvlEdit:SetText("0")
		self.mplusEdit:SetText("0")
		self.privateCheck:SetChecked(false)
		self.crossFactionCheck:SetChecked(false)
		self:SetCensoredDebugButtonScripts(true)
		self:UpdatePlaystyleDropdown()
		self:UpdateRequirementLayout()
		self:UpdateFieldLayout()
		self:LayoutCustomPlaceholders()
		self:UpdateCustomPlaceholders()
		self:UpdateListButtonLabel()
		self:UpdateManageState()
		self:SetCensoredDebugLockedVisual(true)
		self:RefreshCensoredDebugNameVisual(self._debugCensoredNameEdit)
		self:RefreshCensoredDebugDescriptionVisual(
			self._debugCensoredDescriptionEdit
		)
		self:UpdateScrollLayout()
		return true
	end

	local function resolveActiveListingEditSelection(activityID)
		return FormPresenter:ResolveActiveListingSelection(activityID)
	end

	function CP:PrepareForOccupiedEdit()
		self:CancelEditFieldReveal()
		if not GF.RecruitmentSession or not GF.RecruitmentSession:HasActive() then
			self._pendingOpenMode = nil
			FormPresenter:Transition(self, FormPresenter.MODE_CREATE)
			FormPresenter:Select(self, nil)
			self:UpdateManageState()
			return false
		end
		self._pendingOpenMode = "edit"
		FormPresenter:Transition(self, FormPresenter.MODE_EDIT)
		self._protectedCreationTextDraftPrepared = nil
		self._protectedCreateDraftPresented = nil
		FormPresenter:Select(
			self,
			resolveActiveListingEditSelection(
				GF.RecruitmentSession:GetActiveActivityID()
			)
		)
		self:UpdateListButtonLabel()
		self:UpdateManageState()
		if GF.CreateDrawer then
			GF.CreateDrawer:SyncActivityTitle()
		end
		return self.selection ~= nil
	end

	function CP:ResumePendingOpenMode()
		if self._pendingOpenMode ~= "edit" or isCreateChannelBlocked() then
			return false
		end
		self._pendingOpenMode = nil
		if BB and BB.SetActiveOwner then
			BB.SetActiveOwner(CREATE_FIELD_OWNER)
		end
		self:PrepareForEdit()
		return true
	end

	local function applyActiveListingDraft(panel, activeInfo)
		if type(activeInfo) ~= "table" then
			return
		end
		local style = activeInfo.generalPlaystyle
		if style ~= nil and style ~= Enum.LFGEntryGeneralPlaystyle.None then
			panel.generalPlaystyle = style
		end
		if panel.privateCheck ~= nil then
			panel.privateCheck:SetChecked(activeInfo.privateGroup == true)
		end
		if panel.crossFactionCheck ~= nil then
			local crossFaction = activeInfo.isCrossFactionListing == true
				or activeInfo.isCrossFaction == true
			panel.crossFactionCheck:SetChecked(not crossFaction)
		end
		if panel.ilvlEdit ~= nil then
			panel.ilvlEdit:SetText(tostring(activeInfo.requiredItemLevel or 0))
		end
		if panel.mplusEdit ~= nil then
			panel.mplusEdit:SetText(tostring(activeInfo.requiredDungeonScore or 0))
		end
	end

	local function repaintPreparedEdit(panel)
		panel:AttachBlizzardFields()
		panel:UpdatePlaystyleDropdown()
		panel:UpdateCrossFactionOption()
		panel:UpdateRequirementLayout()
		panel:UpdateListButtonLabel()
		panel:UpdateManageState()
		panel:RefreshCreateFieldHandoff()
		panel:SyncEmbeddedFieldChrome()
		panel:UpdateScrollLayout()
		local drawer = GF.CreateDrawer
		if drawer ~= nil and type(drawer.SyncActivityTitle) == "function" then
			drawer:SyncActivityTitle()
		end
	end

	function CP:PrepareForEdit(opts)
		opts = opts or {}
		self:CancelEditFieldReveal()
		if self.debugCensoredPreviewMode == true then
			self:ExitCensoredDebugPreview()
		end
		local listing = GF.RecruitmentSession
		if listing == nil or type(listing.HasActive) ~= "function"
			or not listing:HasActive()
		then
			self._pendingOpenMode = nil
			FormPresenter:Select(self, nil)
			self:UpdateManageState()
			return false
		end
		local censorState = listing.GetActiveCensoredState
			and listing:GetActiveCensoredState()
		local unresolved = censorState
			and censorState.state == listing.ACTIVE_CENSOR_STATE_UNRESOLVED
		if unresolved and opts.censoredResolution ~= true
			and opts.censoredReadOnly ~= true
		then
			if GF.CensoredActiveEntryDialog and GF.CensoredActiveEntryDialog.Show then
				GF.CensoredActiveEntryDialog:Show()
			end
			return false
		end
		if opts.censoredResolution == true and not unresolved then
			return false
		end
		if isCreateChannelBlocked() then
			if opts.censoredResolution == true then
				local L = GF.L or {}
				showCreateError(L.CENSORED_ACTIVE_ENTRY_CREATE_CHANNEL_BUSY
					or "Close Blizzard's group creation window before modifying this content")
				return false
			end
			return self:PrepareForOccupiedEdit()
		end

		self._pendingOpenMode = nil
		self._favoriteSourceIdentity = nil
		self._pendingFavoritePresetIdentity = nil
		FormPresenter:Transition(self, FormPresenter.MODE_EDIT, opts)
		self._protectedCreationTextDraftPrepared = nil
		self._protectedCreateDraftPresented = nil
		self._defaultRequiredItemLevelText = nil
		if NativeCreation:CanCopyActiveEntryInfoToCreationFields() then
			NativeCreation:CopyActiveEntryInfoToCreationFields()
		end
		local activeInfo = listing:GetActive()
		local originalActivityID = listing:GetActiveActivityID()
		local editSelection = resolveActiveListingEditSelection(
			originalActivityID
		)
		FormPresenter:Select(self, editSelection)
		applyActiveListingDraft(self, activeInfo)
		if editSelection ~= nil and originalActivityID ~= nil then
			self:SyncEntryCreationStateIfNeeded(
				editSelection,
				originalActivityID
			)
		end
		repaintPreparedEdit(self)
		return editSelection ~= nil
	end

	function CP:PrepareForCreate(opts)
		opts = opts or {}
		self:CancelEditFieldReveal()
		if self.debugCensoredPreviewMode == true then
			self:ExitCensoredDebugPreview()
		end
		self._pendingOpenMode = nil
		local wasEditMode = self.editMode == true
		FormPresenter:Transition(self, FormPresenter.MODE_CREATE)
		-- The native EntryCreation controls are the draft owner.  A nil prepared
		-- marker means an actual first/new draft; panel visibility and surface mode
		-- never do.  Explicit resets and edit -> create transitions still advance
		-- the draft boundary.
		local resetNewDraft = opts.resetDefaults == true
			or wasEditMode
			or self._protectedCreationTextDraftPrepared ~= true
		if resetNewDraft then
			-- Each explicit reset starts a distinct draft.  The prepared marker only
			-- suppresses duplicate clears while that same draft remains open.
			self._protectedCreationTextDraftPrepared = nil
			self._protectedCreateDraftPresented = nil
			self.raidRequiredSpecIDs = nil
		end
		self:ClearProtectedCreationTextFieldsForNewDraft(resetNewDraft)
		self:ApplyDefaultRequiredItemLevel(resetNewDraft)
		self:ApplyDefaultRequiredDungeonScore(resetNewDraft)
		self:ApplyMythicPlusHiddenCreateDefaults(resetNewDraft)
		local favoriteIdentity = self._pendingFavoritePresetIdentity
		self._pendingFavoritePresetIdentity = nil
		if favoriteIdentity then
			self:ApplyFavoritePreset(favoriteIdentity)
		end
		self:UpdateListButtonLabel()
		self:UpdateManageState()
		if GF.CreateDrawer then
			GF.CreateDrawer:SyncActivityTitle()
		end
	end

	function CP:ClearFocus()
		blurCreationControls(self)
	end

	local function creationAvailabilityProblem(panel, labels)
		if panel.editMode == true then
			return nil
		end
		local availability = GF.Availability
		local reader = availability and availability.GetPremadeBlockMessage
		if type(reader) ~= "function" then
			return nil
		end
		return availability:GetPremadeBlockMessage()
	end

	local function closeCreateDrawerAfterSubmit(panel)
		local drawer = GF.CreateDrawer
		if drawer ~= nil and not panel:IsMythicPlusSidebarMode()
			and type(drawer.Close) == "function"
		then
			drawer:Close()
		end
	end

	local function performListingSubmission(panel, params)
		local listing = GF.RecruitmentSession
		if listing == nil or type(listing.CanPublish) ~= "function" then
			return false, "missing"
		end
		if not listing:CanPublish() then
			if type(listing.NotifyLeaderOnly) == "function" then
				listing:NotifyLeaderOnly()
			end
			return false, "leader"
		end
		local operation
		if panel.editMode == true then
			operation = listing.UpdateFromDraft
		else
			operation = listing.Create
		end
		if type(operation) ~= "function" then
			return false, "missing"
		end
		local accepted, reason
		if panel.editMode == true then
			accepted, reason = operation(listing, params, {
				censoredResolution = panel.censoredResolutionMode == true,
			})
		else
			accepted, reason = operation(listing, params)
		end
		return accepted == true, reason or "submit"
	end

	local function refreshProtectedPrebuiltTitleForSubmission()
		local creation = getEntryCreation()
		local updateTitle = LFGListEntryCreation_SetTitleFromActivityInfo
		if creation == nil or creation.selectedActivity == nil
			or creation.selectedGroup == nil
			or creation.selectedCategory == nil
			or type(updateTitle) ~= "function"
		then
			return false
		end
		-- The native helper may call the restricted SetEntryTitle API. This
		-- function is only reached from SubmitListing's hardware-event stack.
		local updated = pcall(updateTitle, creation)
		if not updated then
			return false
		end
		local matched, result = pcall(
			NativeCreation.DoesEntryTitleMatchPrebuiltTitle,
			NativeCreation,
			creation.selectedActivity,
			creation.selectedGroup,
			creation.selectedPlaystyle,
			creation.generalPlaystyle
		)
		return matched and result == true
	end

	local function closeCensoredDebugEditor(panel, returnToReadOnly)
		local inline = GF.MythicPlusCreateManagerPanel
		if panel:IsMythicPlusSidebarMode() and inline then
			if returnToReadOnly == true
				and inline.ReturnToCensoredDebugReadOnly
				and inline:ReturnToCensoredDebugReadOnly()
			then
				return true
			end
			if inline.ClearCensoredDebugPreview then
				inline:ClearCensoredDebugPreview()
			end
			if GF.MainFrame and GF.MainFrame.UpdateCreateTab then
				GF.MainFrame:UpdateCreateTab({
					suppressCreateAutoOpen = true,
				})
			end
			return true
		end
		if GF.CreateDrawer and GF.CreateDrawer.Close then
			GF.CreateDrawer:Close(returnToReadOnly ~= true)
			return true
		end
		return false
	end

	function CP:SubmitListing()
		local labels = GF.L or {}
		if self.debugCensoredPreviewMode == true then
			if not self:CanUseCensoredDebugPreview() then
				closeCensoredDebugEditor(self, false)
				return false
			end
			local name = trimName(self._debugCensoredNameEdit:GetText())
			local comment = trimName(
				self._debugCensoredDescriptionEdit:GetText()
			)
			if name == "" then
				showCreateError(labels.CREATE_NEED_NAME
					or LFG_LIST_MUST_HAVE_NAME
					or "A recruitment name is required.")
				return false
			end
			if name == trimName(self._debugCensoredOriginalName)
				and comment == trimName(self._debugCensoredOriginalComment)
			then
				showCreateError(labels.CENSORED_ACTIVE_ENTRY_TEXT_UNCHANGED
					or "Change the recruitment name or description before submitting")
				return false
			end
			showCreateError(labels.DEBUG_CENSORED_EDIT_PREVIEW_SUBMITTED
				or "Debug mode: the changes were simulated without changing the real recruitment.")
			closeCensoredDebugEditor(self, true)
			return true
		end
		local availabilityProblem = creationAvailabilityProblem(self, labels)
		if availabilityProblem ~= nil then
			showCreateError(availabilityProblem)
			return false
		end
		if self.editMode == true and self.censoredResolutionMode ~= true
			and GF.RecruitmentSession
			and GF.RecruitmentSession.GetActiveCensoredState
		then
			local state = GF.RecruitmentSession:GetActiveCensoredState()
			if state.state == GF.RecruitmentSession.ACTIVE_CENSOR_STATE_UNRESOLVED then
				if GF.CensoredActiveEntryDialog and GF.CensoredActiveEntryDialog.Show then
					GF.CensoredActiveEntryDialog:Show()
				end
				return false
			end
			if state.state == GF.RecruitmentSession.ACTIVE_CENSOR_STATE_UNKNOWN then
				showCreateError(labels.CENSORED_ACTIVE_ENTRY_UNKNOWN
					or "The pending state cannot be confirmed yet")
				return false
			end
		end
		if isCreateChannelBlocked() then
			showCreateError(
				labels.CREATE_BLIZZARD_OWNS
					or "Premade group creation is open in the game UI"
			)
			return false
		end
		if self:AttachBlizzardFields() ~= true then
			showCreateError(
				labels.CREATE_BLIZZARD_UI_MISSING
					or "Premade group UI is not loaded"
			)
			return false
		end

		local selected = self.selection
		local activityID = selected and resolveActivityID(selected)
		if activityID ~= nil then
			self:SyncEntryCreationState(selected, activityID)
		end
		local prebuiltTitleReady = false
		if selectionRequiresProtectedPrebuiltTitle(self) then
			prebuiltTitleReady = refreshProtectedPrebuiltTitleForSubmission()
			if not prebuiltTitleReady then
				showCreateError(
					labels.CREATE_FAILED
						or "Listing failed. Please try again"
				)
				return false
			end
		end
		local valid, draft = self:ValidateListing({
			prebuiltTitleReady = prebuiltTitleReady,
		})
		if not valid then
			return false
		end
		local params = self:BuildListingParams(draft)
		if params == nil then
			return false
		end

		-- CreateListing/UpdateListing are protected. Keep this direct dispatch in
		-- 必须保持在拥有发布权限的按钮同步硬件事件栈内。
		local succeeded, outcome = performListingSubmission(self, params)
		if not succeeded then
			if outcome == "censored_text_unchanged" then
				showCreateError(labels.CENSORED_ACTIVE_ENTRY_TEXT_UNCHANGED
					or "Change the recruitment name or description before submitting")
			elseif outcome == "censored_state_changed" then
				showCreateError(labels.CENSORED_ACTIVE_ENTRY_STATE_CHANGED
					or "The pending state has changed. Reopen the recruitment manager")
			elseif outcome == "censored_validation_unavailable" then
				showCreateError(labels.CENSORED_ACTIVE_ENTRY_VALIDATION_UNAVAILABLE
					or "The recruitment text could not be validated. Try again")
			elseif outcome == "censored_pending" then
				if GF.CensoredActiveEntryDialog and GF.CensoredActiveEntryDialog.Show then
					GF.CensoredActiveEntryDialog:Show()
				end
			elseif outcome == "submit" or outcome == "missing" or outcome == "rejected" then
				showCreateError(
					labels.CREATE_FAILED
						or "Listing failed. Please try again"
				)
			end
			return false
		end
		-- Match Blizzard's native order: protected CreateListing/UpdateListing must
		-- consume the prepared title before clearing focus can commit field state.
		blurCreationControls(self)
		closeCreateDrawerAfterSubmit(self)
		return true
	end

	local function repaintVisibleCreateSurface(panel)
		if not isCreateFieldSurfaceActive() then
			return false
		end
		panel:RefreshCreateFieldHandoff()
		panel:UpdateRequirementLayout()
		panel:SyncEmbeddedFieldChrome()
		panel:UpdateManageState()
		panel:UpdateScrollLayout()
		return true
	end

	function CP:Show(options)
		options = options or {}
		local host = self.parent
		if host == nil or self.scroll == nil then
			return false
		end
		self._showGeneration = (tonumber(self._showGeneration) or 0) + 1
		local showGeneration = self._showGeneration
		if options.atomicReveal == true then
			self:CancelUpdateScrollLayoutDebounce()
		end
		if self.debugCensoredPreviewMode == true then
			self:CancelEditFieldReveal()
			host:Show()
			self:SetCreateChannelBlocked(false)
			self:UpdateRequirementLayout()
			self:UpdateManageState()
			self:UpdateScrollLayout()
			return true
		end
		self:StartCreateFieldOwnershipWatch()
		self:RefreshCreateFieldHandoff()
		self:UpdateRequirementLayout()
		local selected = self.selection
		local activityID = selected and resolveActivityID(selected)
		if activityID ~= nil then
			self:SyncEntryCreationStateIfNeeded(selected, activityID)
		end
		self:SyncEmbeddedFieldChrome()
		host:Show()
		self:UpdateManageState()
		local defer = C_Timer and C_Timer.After
		if options.atomicReveal ~= true and type(defer) == "function" then
			defer(0, function()
				if CP._showGeneration ~= showGeneration or CP.parent ~= host
					or (type(host.IsShown) == "function" and not host:IsShown())
				then
					return
				end
				repaintVisibleCreateSurface(CP)
			end)
		end
		self:UpdateScrollLayout()
		if options.atomicReveal == true and (self.editMode == true
			or options.resumeCreateDraft == true)
			and self._createChannelBlocked ~= true
			and not self:IsMythicPlusSidebarMode()
		then
			self:StageEditFieldReveal({
				resumeCreateDraft = options.resumeCreateDraft == true,
			})
		else
			self:CancelEditFieldReveal()
		end
		return true
	end



	function CP:Hide(reason)
		if not self.parent then
			return
		end
		self._showGeneration = (tonumber(self._showGeneration) or 0) + 1
		self:CancelEditFieldReveal()
		self:CancelUpdateScrollLayoutDebounce()
		self:StopCreateFieldOwnershipWatch()
		self._pendingOpenMode = nil
		if self.debugCensoredPreviewMode == true then
			self:ExitCensoredDebugPreview()
		else
			self.censoredResolutionMode = nil
		end
		self:ReleaseCreateFields(reason or "panel")
		self:SetCreateChannelBlocked(false)
		self.parent:Hide()
	end

	function CP:LeaveTab()
		self:Hide("tab")
	end

	if GF.QuestRecruitmentBridge
		and type(GF.QuestRecruitmentBridge.SetFieldBridge) == "function"
	then
		GF.QuestRecruitmentBridge:SetFieldBridge({
			CanAcquire = function()
				return CP:CanAcquireQuestRecruitmentFieldLease()
			end,
			Acquire = function(_, resolved)
				return CP:AcquireQuestRecruitmentFieldLease(resolved)
			end,
			Release = function(_, lease)
				return CP:ReleaseQuestRecruitmentFieldLease(lease)
			end,
		})
	end
	return CP
end
