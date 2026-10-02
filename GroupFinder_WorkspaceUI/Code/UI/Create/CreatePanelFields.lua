local _, GF = ...
GF = GF.GF or GF

-- Owns Blizzard EntryCreation field capture, styling, projection, and restore.
-- Install is invoked by CreatePanel so the existing GF.CreatePanel API remains
-- unchanged while these implementation locals compile in a separate chunk.
GF.CreatePanelFields = GF.CreatePanelFields or {}
local FieldModule = GF.CreatePanelFields

function FieldModule.Install(CP, dependencies)
	assert(type(CP) == "table", "CreatePanel table is required")
	dependencies = dependencies or {}
	local BB = dependencies.BB
	local NativeCreation = dependencies.NativeCreation
	local FormPresenter = dependencies.FormPresenter
	local trimName = dependencies.trimName
	local FIELD_EDGE_PAD = dependencies.FIELD_EDGE_PAD
	local CREATE_FORM_TITLE_SIZE = dependencies.CREATE_FORM_TITLE_SIZE
	local CREATE_FORM_TITLE_COLOR = dependencies.CREATE_FORM_TITLE_COLOR
	local CREATE_FORM_INPUT_TEXT_COLOR = dependencies.CREATE_FORM_INPUT_TEXT_COLOR
	local CREATE_FORM_DISABLED_INPUT_TEXT_COLOR = dependencies.CREATE_FORM_DISABLED_INPUT_TEXT_COLOR
	local CREATE_FORM_DISABLED_ATLAS_TINT = dependencies.CREATE_FORM_DISABLED_ATLAS_TINT
	local CREATE_FORM_DISABLED_ATLAS_DESATURATED = dependencies.CREATE_FORM_DISABLED_ATLAS_DESATURATED
	local CREATE_FORM_DISABLED_ALPHA = dependencies.CREATE_FORM_DISABLED_ALPHA
	local CREATE_CHECK_LABEL_GAP = dependencies.CREATE_CHECK_LABEL_GAP
	local CREATE_DESC_ATLAS_BORDER_KEYS = dependencies.CREATE_DESC_ATLAS_BORDER_KEYS
	local CREATE_FIELD_OWNER = dependencies.CREATE_FIELD_OWNER
	local CREATE_FIELD_CHANNEL = dependencies.CREATE_FIELD_CHANNEL
	local DESCRIPTION_EDIT_BOX_RIGHT_RESERVE = 12

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
		if GF.ElvUICompat then
			GF.ElvUICompat.BeginInputBorrow(editBox)
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
		if GF.ElvUICompat then
			GF.ElvUICompat.EndInputBorrow(editBox)
		end
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
		if GF.ElvUICompat then
			GF.ElvUICompat.BeginInputBorrow(widget)
		end
		stateKey = stateKey or "_gfBorrowedChromeState"
		if not widget[stateKey] then
			widget[stateKey] = {}
			for _, region in ipairs({ widget:GetRegions() }) do
				if region and region._gfCreatePlaceholder ~= true then
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
		if GF.ElvUICompat then
			GF.ElvUICompat.EndInputBorrow(widget)
		end
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

	local function captureBorrowedWidgetInteraction(widget)
		if not widget or widget._gfBorrowedInteractionState then
			return
		end
		local state = {}
		if widget.IsEnabled then
			state.enabled = widget:IsEnabled() == true
		end
		if widget.IsMouseEnabled then
			state.mouseEnabled = widget:IsMouseEnabled() == true
		end
		widget._gfBorrowedInteractionState = state
	end

	local function restoreBorrowedWidgetInteraction(widget)
		local state = widget and widget._gfBorrowedInteractionState
		if not state then
			return
		end
		if state.enabled ~= nil and widget.SetEnabled then
			widget:SetEnabled(state.enabled)
		end
		if state.mouseEnabled ~= nil and widget.EnableMouse then
			widget:EnableMouse(state.mouseEnabled)
		end
		widget._gfBorrowedInteractionState = nil
	end

	local function widgetShown(widget)
		return widget ~= nil and (
			type(widget.IsShown) ~= "function" or widget:IsShown() == true
		)
	end

	local function setWidgetShown(widget, shown)
		if widget ~= nil and type(widget.SetShown) == "function" then
			widget:SetShown(shown == true)
		end
	end

	local function applyGroupFinderProtectedFieldGate(widget, formEnabled)
		if widget ~= nil and formEnabled ~= true
			and type(widget.SetEnabled) == "function"
		then
			widget:SetEnabled(false)
		end
	end

	local function applyProtectedCreationGate(creation, formEnabled)
		if creation == nil then
			return
		end
		applyGroupFinderProtectedFieldGate(creation.Name, formEnabled)
		applyGroupFinderProtectedFieldGate(
			creation.Description and creation.Description.EditBox,
			formEnabled
		)
		applyGroupFinderProtectedFieldGate(
			creation.VoiceChat and creation.VoiceChat.EditBox,
			formEnabled
		)
	end

	local function captureFrameLayout(frame)
		if frame == nil or type(frame.GetParent) ~= "function" then
			return nil
		end
		local layout = {
			parent = frame:GetParent(),
			anchors = {},
		}
		local pointCount = type(frame.GetNumPoints) == "function"
			and frame:GetNumPoints() or 0
		for pointIndex = 1, pointCount do
			local point, relativeTo, relativePoint, offsetX, offsetY =
				frame:GetPoint(pointIndex)
			layout.anchors[pointIndex] = {
				point = point,
				relativeTo = relativeTo,
				relativePoint = relativePoint,
				offsetX = offsetX,
				offsetY = offsetY,
			}
		end
		if type(frame.GetSize) == "function" then
			layout.width, layout.height = frame:GetSize()
		end
		return layout
	end

	local function restoreFrameLayout(frame, layout, restoreParent)
		if frame == nil or layout == nil then
			return false
		end
		if restoreParent ~= false then
			frame:SetParent(layout.parent)
		elseif frame:GetParent() ~= layout.parent then
			return false
		end
		frame:ClearAllPoints()
		for pointIndex = 1, #layout.anchors do
			local anchor = layout.anchors[pointIndex]
			frame:SetPoint(
				anchor.point,
				anchor.relativeTo,
				anchor.relativePoint,
				anchor.offsetX,
				anchor.offsetY
			)
		end
		if type(layout.width) == "number" and layout.width > 0
			and type(layout.height) == "number" and layout.height > 0
		then
			frame:SetSize(layout.width, layout.height)
		end
		return true
	end

	local function getDescriptionScrollBarParts(description)
		local bar = description and description.ScrollBar
		if not bar then
			return nil
		end
		local track = bar.GetTrack and bar:GetTrack() or bar.Track
		local back = bar.GetBackStepper and bar:GetBackStepper() or bar.Back
		local forward = bar.GetForwardStepper
			and bar:GetForwardStepper() or bar.Forward
		return bar, track, back, forward
	end

	local function restoreDescriptionScrollBarProjection(description)
		local bar, track, back, forward =
			getDescriptionScrollBarParts(description)
		local state = bar and bar._gfCreateDescriptionScrollBarState
		if not state then
			return false
		end
		GF.UI.RestoreCommonScrollBarSkin(bar)
		restoreFrameLayout(track, state.trackLayout, false)
		restoreFrameLayout(bar, state.barLayout, false)
		setWidgetShown(back, state.backShown)
		setWidgetShown(forward, state.forwardShown)
		bar._gfCreateDescriptionScrollBarState = nil
		if bar.Update then
			bar:Update()
		end
		return true
	end

	local function projectDescriptionScrollBar(description, addonOwned)
		if addonOwned ~= true then
			return restoreDescriptionScrollBarProjection(description)
		end
		local bar, track, back, forward =
			getDescriptionScrollBarParts(description)
		if not (bar and track and back and forward) then
			return false
		end
		if not bar._gfCreateDescriptionScrollBarState then
			bar._gfCreateDescriptionScrollBarState = {
				barLayout = captureFrameLayout(bar),
				trackLayout = captureFrameLayout(track),
				backShown = widgetShown(back),
				forwardShown = widgetShown(forward),
			}
		end
		GF.UI.ApplyCommonScrollBarSkin(bar, { bodyOnly = true })
		bar:ClearAllPoints()
		bar:SetPoint(
			"TOPRIGHT",
			description,
			"TOPRIGHT",
			2,
			-7
		)
		bar:SetPoint(
			"BOTTOMRIGHT",
			description,
			"BOTTOMRIGHT",
			2,
			7
		)
		bar:SetWidth(GF.FILTER_SCROLLBAR_WIDTH or 8)
		track:ClearAllPoints()
		track:SetPoint("TOP", bar, "TOP", 0, 0)
		track:SetPoint("BOTTOM", bar, "BOTTOM", 0, 0)
		-- Both addon layouts use the same quiet, thumb-only projection. Keep
		-- native frames, 23px minimum, and drag/range semantics. The shared
		-- Common body skin is restored when returning the borrowed fields.
		back:Hide()
		forward:Hide()
		if bar.Update then
			bar:Update()
		end
		return true
	end

	local function captureProjectedField(field, stateKey)
		if field == nil or field[stateKey] ~= nil then
			return
		end
		field[stateKey] = {
			shown = widgetShown(field),
			layout = captureFrameLayout(field),
		}
	end

	local function restoreProjectedField(field, stateKey)
		local state = field and field[stateKey]
		if state == nil then
			return false
		end
		restoreFrameLayout(field, state.layout, false)
		setWidgetShown(field, state.shown)
		field[stateKey] = nil
		return true
	end

	local function captureEntryCreationProjection(creation)
		if creation == nil or creation._gfEntryCreationBorrowState ~= nil then
			return
		end
		local state = {
			shown = widgetShown(creation),
			layout = captureFrameLayout(creation),
		}
		if type(creation.GetFrameLevel) == "function" then
			state.frameLevel = creation:GetFrameLevel()
		end
		if type(creation.GetFrameStrata) == "function" then
			state.frameStrata = creation:GetFrameStrata()
		end
		creation._gfEntryCreationBorrowState = state
		captureProjectedField(creation.Name, "_gfCreateNameBorrowState")
		captureProjectedField(
			creation.Description,
			"_gfCreateDescriptionBorrowState"
		)
	end

	local function embedEntryCreationContainer(creation, host)
		if creation == nil or host == nil then
			return false
		end
		creation:SetParent(host)
		creation:ClearAllPoints()
		creation:SetPoint("TOPLEFT", host, "TOPLEFT")
		creation:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT")
		if type(creation.SetFrameLevel) == "function"
			and type(host.GetFrameLevel) == "function"
		then
			creation:SetFrameLevel(host:GetFrameLevel() + 2)
		end
		BB.MarkBorrowed(
			creation,
			CREATE_FIELD_OWNER,
			CREATE_FIELD_CHANNEL
		)
		return true
	end

	local function activitySelectionIsLive(activityID, categoryID, questID)
		if activityID == nil or categoryID == nil then
			return false
		end
		local activityOK, activityInfo = pcall(
			NativeCreation.GetActivityInfoTable,
			NativeCreation,
			activityID,
			questID
		)
		if not activityOK or type(activityInfo) ~= "table"
			or activityInfo.categoryID ~= categoryID
		then
			return false
		end
		if questID ~= nil then
			-- Blizzard's Name OnTextChanged path calls UpdateValidState, which reads
			-- selectedActivity without forwarding questID.  Refuse the temporary
			-- context unless that exact native validation lookup is also safe.
			local bareOK, bareActivity = pcall(
				NativeCreation.GetActivityInfoTable,
				NativeCreation,
				activityID
			)
			if not bareOK or type(bareActivity) ~= "table"
				or bareActivity.categoryID ~= categoryID
			then
				return false
			end
		end
		return true
	end

	local function showEntryCreationForAddon(creation)
		if creation == nil or creation.selectedActivity == nil
			or creation.selectedCategory == nil
			or type(creation.Show) ~= "function"
		then
			return false
		end
		if not activitySelectionIsLive(
			creation.selectedActivity,
			creation.selectedCategory
		) then
			return false
		end
		local lease = CP and CP._entryCreationLease
		if lease ~= nil and BB
			and type(BB.SetEntryCreationLeaseVisible) == "function"
			and type(BB.IsEntryCreationLeaseCurrent) == "function"
			and BB.IsEntryCreationLeaseCurrent(lease)
		then
			return BB.SetEntryCreationLeaseVisible(lease, true)
		end
		creation._gfShowingBorrowedEntryCreation = true
		local shown = pcall(creation.Show, creation)
		creation._gfShowingBorrowedEntryCreation = nil
		return shown
	end

	local function restoreEntryCreationContainer(creation)
		local state = creation and creation._gfEntryCreationBorrowState
		if state == nil then
			return nil
		end
		restoreFrameLayout(creation, state.layout)
		if state.frameStrata ~= nil
			and type(creation.SetFrameStrata) == "function"
		then
			creation:SetFrameStrata(state.frameStrata)
		end
		if state.frameLevel ~= nil
			and type(creation.SetFrameLevel) == "function"
		then
			creation:SetFrameLevel(state.frameLevel)
		end
		BB.ClearBorrowed(
			creation,
			CREATE_FIELD_OWNER,
			CREATE_FIELD_CHANNEL
		)
		creation._gfEntryCreationBorrowState = nil
		return state.shown
	end

	local function captureBorrowedVoiceProjection(voice)
		if voice == nil or voice._gfVoiceBorrowState ~= nil then
			return
		end
		local editBox = voice.EditBox
		local state = {
			shown = widgetShown(voice),
			editShown = widgetShown(editBox),
			checkShown = widgetShown(voice.CheckButton),
			labelShown = widgetShown(voice.Label),
			warningShown = widgetShown(voice.WarningFrame),
			layout = captureFrameLayout(voice),
			editLayout = captureFrameLayout(editBox),
		}
		if type(voice.GetFrameLevel) == "function" then
			state.frameLevel = voice:GetFrameLevel()
		end
		if type(voice.GetFrameStrata) == "function" then
			state.frameStrata = voice:GetFrameStrata()
		end
		voice._gfVoiceBorrowState = state
		captureBorrowedWidgetInteraction(voice)
		captureBorrowedWidgetInteraction(editBox)
		captureBorrowedWidgetInteraction(voice.CheckButton)
	end

	local function restoreBorrowedVoiceProjection(voice)
		local state = voice and voice._gfVoiceBorrowState
		if state == nil then
			return nil
		end
		local editBox = voice.EditBox
		restoreBorrowedNameChrome(editBox)
		restoreFrameLayout(editBox, state.editLayout, false)
		restoreBorrowedWidgetInteraction(editBox)
		restoreBorrowedWidgetInteraction(voice.CheckButton)
		restoreBorrowedWidgetInteraction(voice)
		setWidgetShown(editBox, state.editShown)
		setWidgetShown(voice.CheckButton, state.checkShown)
		setWidgetShown(voice.Label, state.labelShown)
		setWidgetShown(voice.WarningFrame, state.warningShown)
		if state.frameStrata ~= nil and type(voice.SetFrameStrata) == "function" then
			voice:SetFrameStrata(state.frameStrata)
		end
		if state.frameLevel ~= nil and type(voice.SetFrameLevel) == "function" then
			voice:SetFrameLevel(state.frameLevel)
		end
		restoreFrameLayout(voice, state.layout, false)
		voice._gfVoiceBorrowState = nil
		return state.shown
	end

	local function captureEntryCreationInteraction(ec)
		if not ec then
			return
		end
		captureBorrowedWidgetInteraction(ec.Name)
		captureBorrowedWidgetInteraction(ec.Description)
		captureBorrowedWidgetInteraction(
			ec.Description and ec.Description.EditBox
		)
		captureBorrowedWidgetInteraction(ec.VoiceChat)
		captureBorrowedWidgetInteraction(
			ec.VoiceChat and ec.VoiceChat.EditBox
		)
		captureBorrowedWidgetInteraction(
			ec.VoiceChat and ec.VoiceChat.CheckButton
		)
	end

	local function restoreEntryCreationInteraction(ec, refreshAuthentication)
		if not ec then
			return
		end
		restoreBorrowedWidgetInteraction(ec.Name)
		restoreBorrowedWidgetInteraction(ec.Description)
		restoreBorrowedWidgetInteraction(
			ec.Description and ec.Description.EditBox
		)
		restoreBorrowedWidgetInteraction(ec.VoiceChat)
		restoreBorrowedWidgetInteraction(
			ec.VoiceChat and ec.VoiceChat.EditBox
		)
		restoreBorrowedWidgetInteraction(
			ec.VoiceChat and ec.VoiceChat.CheckButton
		)
		if refreshAuthentication ~= false and ec.selectedActivity ~= nil
			and type(LFGListEntryCreation_UpdateAuthenticatedState) == "function"
		then
			pcall(LFGListEntryCreation_UpdateAuthenticatedState, ec)
		end
		if ec.Name and ec.Name.UpdateEnabledState then
			pcall(ec.Name.UpdateEnabledState, ec.Name)
		end
		if ec.Description and ec.Description.UpdateEnabledState then
			pcall(ec.Description.UpdateEnabledState, ec.Description)
		end
	end

	local function setCreateAtlasPieceVisual(piece, enabled)
		if not piece then
			return
		end
		local createManagerDisabled = not enabled
			and CP
			and CP.IsCreateManagerSurface
			and CP:IsCreateManagerSurface()
		if piece.SetDesaturated then
			piece:SetDesaturated(
				createManagerDisabled
					and CREATE_FORM_DISABLED_ATLAS_DESATURATED
					or false
			)
		end
		local tint = createManagerDisabled
			and CREATE_FORM_DISABLED_ATLAS_TINT
			or 1
		local alpha = createManagerDisabled
			and CREATE_FORM_DISABLED_ALPHA
			or (enabled and 1 or 0.45)
		piece:SetVertexColor(
			tint,
			tint,
			tint,
			alpha
		)
		if piece.SetAlpha then
			piece:SetAlpha(
				createManagerDisabled
					and CREATE_FORM_DISABLED_ALPHA
					or 1
			)
		end
	end

	local function setCreateControlChromeVisual(frame, chrome, enabled)
		if not chrome then
			return
		end
		local createManagerDisabled = not enabled
			and CP
			and CP.IsCreateManagerSurface
			and CP:IsCreateManagerSurface()
		if frame
			and GF.UI
			and GF.UI.SetControlCardChromeEnabledVisual
		then
			GF.UI.SetControlCardChromeEnabledVisual(frame, enabled, {
				disabledTint = createManagerDisabled
					and CREATE_FORM_DISABLED_ATLAS_TINT
					or 1,
				alpha = createManagerDisabled
					and CREATE_FORM_DISABLED_ALPHA
					or (enabled and 1 or 0.45),
				desaturated = createManagerDisabled
					and CREATE_FORM_DISABLED_ATLAS_DESATURATED
					or false,
				textureAlpha = createManagerDisabled
					and CREATE_FORM_DISABLED_ALPHA
					or 1,
			})
			return
		end
		for _, key in ipairs(CREATE_DESC_ATLAS_BORDER_KEYS) do
			setCreateAtlasPieceVisual(chrome.border and chrome.border[key], enabled)
		end
		setCreateAtlasPieceVisual(chrome.center, enabled)
	end

	local function updateCreateInputBox(box)
		if not box or not box._gfCreateInputStyled then
			return
		end
		local enabled = not box.IsEnabled or box:IsEnabled()
		local active = enabled and (box:HasFocus() or box._gfCreateInputHovered)
		local useDisabledText = not enabled
			and CP
			and CP.IsCreateManagerSurface
			and CP:IsCreateManagerSurface()
		local textColor = useDisabledText
			and CREATE_FORM_DISABLED_INPUT_TEXT_COLOR
			or CREATE_FORM_INPUT_TEXT_COLOR
		box:SetTextColor(
			textColor[1] or 1,
			textColor[2] or 1,
			textColor[3] or 1,
			textColor[4] or 1
		)
		local chrome = GF.UI.ApplyFilterInputChrome(
			box,
			active and "hover" or "normal"
		)
		setCreateControlChromeVisual(box, chrome, enabled)
	end

	local function updateCreateInputAtlasFrame(frame, active, enabled)
		if not frame then
			return
		end
		enabled = enabled ~= false
		local chrome = GF.UI.ApplyFilterInputChrome(
			frame,
			active and "hover" or "normal"
		)
		setCreateControlChromeVisual(frame, chrome, enabled)
	end

	local function updateCreateDescriptionAtlasFrame(frame, active, enabled)
		if not frame then
			return
		end
		enabled = enabled ~= false
		local chrome = GF.UI.ApplyFilterMultilineInputChrome(
			frame,
			active and "hover" or "normal",
			{
				layer = "BACKGROUND",
				subLevel = -6,
				centerLayer = "BACKGROUND",
				centerSubLevel = -7,
			}
		)
		if not chrome then
			return
		end
		frame._gfCreateDescAtlas = chrome
		setCreateControlChromeVisual(frame, chrome, enabled)
	end

	local function styleCreateInputAtlasFrame(frame)
		if not frame then
			return frame
		end
		updateCreateInputAtlasFrame(frame, false, true)
		return frame
	end

	local function styleCreateDescriptionAtlasFrame(frame)
		if not frame then
			return frame
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
		box:SetTextColor(
			CREATE_FORM_INPUT_TEXT_COLOR[1],
			CREATE_FORM_INPUT_TEXT_COLOR[2],
			CREATE_FORM_INPUT_TEXT_COLOR[3],
			CREATE_FORM_INPUT_TEXT_COLOR[4]
		)
		box:SetShadowColor(0, 0, 0, 0.85)
		box:SetShadowOffset(1, -1)
		hideInputBoxChrome(box)
		if not box._gfCreateInputStyled then
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

	local function applyCreateTitleTextStyle(fs, color)
		if not fs then
			return
		end
		fs._gfFontSizeOverride = CREATE_FORM_TITLE_SIZE
		if GF.Font and GF.Font.ApplyToFontString then
			GF.Font.ApplyToFontString(fs, fs._gfFontTemplate or "GameFontNormal")
		end
		color = color or CREATE_FORM_TITLE_COLOR
		fs:SetTextColor(
			color[1] or 1,
			color[2] or 1,
			color[3] or 1,
			color[4] or 1
		)
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

	local function editBoxIsEmptyByLetterCount(editBox)
		local getNumLetters = editBox and editBox.GetNumLetters
		if type(getNumLetters) ~= "function" then
			return nil
		end
		local ok, count = pcall(getNumLetters, editBox)
		if not ok or type(count) ~= "number" then
			return nil
		end
		return count == 0
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

	local function restoreDescriptionInstructions(editBox)
		restoreNativeInstructions(editBox)
		local instructions = editBox and editBox.Instructions
		if instructions == nil then
			return
		end
		local empty = editBoxIsEmptyByLetterCount(editBox)
		if empty ~= nil then
			instructions:SetShown(empty)
			return
		end
		if type(InputScrollFrame_OnTextChanged) == "function" then
			pcall(InputScrollFrame_OnTextChanged, editBox, false)
		end
	end

	local function resolveActivityID(node)
		return FormPresenter:ResolveActivityID(node)
	end

	local function getEntryCreation()
		local root = LFGListFrame
		return root and root.EntryCreation or nil
	end

	local function frameReportsVisible(frame)
		return frame ~= nil and type(frame.IsVisible) == "function"
			and frame:IsVisible() == true
	end

	local function contextStillCurrent(context)
		local view = GF.LFGWorkspaceView
		if context == nil or view == nil
			or type(view.IsContextCurrent) ~= "function"
		then
			return true
		end
		return view:IsContextCurrent(context) == true
	end

	local function isCreateFieldSurfaceActive()
		local sidebar = GF.MythicPlusCreateManagerPanel
		if sidebar ~= nil and type(sidebar.IsSurfaceActive) == "function"
			and sidebar:IsSurfaceActive() == true
		then
			return contextStillCurrent(sidebar.workspaceContext)
		end
		local drawer = GF.CreateDrawer
		return drawer ~= nil and drawer.open == true
			and contextStillCurrent(drawer.workspaceContext)
	end

	local function createFieldLeaseContextKey(panel)
		local context = panel and panel.workspaceContext
		local surface = FormPresenter:GetSurface(panel)
		return string.format(
			"%s:%s",
			tostring(surface or "unknown"),
			tostring(context and context.key or "none")
		)
	end

	local function hasCurrentEntryCreationLease(panel)
		local lease = panel and panel._entryCreationLease
		if lease == nil then
			return false
		end
		if BB and type(BB.IsEntryCreationLeaseCurrent) == "function" then
			return BB.IsEntryCreationLeaseCurrent(lease) == true
		end
		return false
	end

	local function entryCreationLeaseMatchesSurface(panel, creation, host)
		local lease = panel and panel._entryCreationLease
		if lease == nil or not (BB
			and type(BB.IsEntryCreationLeaseCurrent) == "function")
		then
			return false
		end
		return BB.IsEntryCreationLeaseCurrent(lease, {
			owner = CREATE_FIELD_OWNER,
			channel = CREATE_FIELD_CHANNEL,
			creation = creation,
			host = host,
			contextKey = createFieldLeaseContextKey(panel),
		}) == true
	end

	local function isLfgFrameVisible()
		return frameReportsVisible(LFGListFrame)
	end

	local function isBlizzardCreateActive()
		local root = LFGListFrame
		local nativePanel = root and root.EntryCreation
		return isLfgFrameVisible() and nativePanel ~= nil
			and root.activePanel == nativePanel
	end

	local function frameHasForeignParent(frame, nativeParent, groupFinderParent, sink)
		if frame == nil or type(frame.GetParent) ~= "function" then
			return false
		end
		local parent = frame:GetParent()
		return parent ~= nil and parent ~= nativeParent
			and parent ~= groupFinderParent and parent ~= sink
	end

	local function entryCreationFieldsKeepNativeParents(creation)
		if creation == nil then
			return false
		end
		for _, fieldKey in ipairs({ "Name", "Description", "VoiceChat" }) do
			local field = creation[fieldKey]
			if field ~= nil and type(field.GetParent) == "function"
				and field:GetParent() ~= creation
			then
				return false
			end
		end
		return true
	end

	local function areCreateFieldsExternallyOwned()
		local nativePanel = getEntryCreation()
		if nativePanel == nil then
			return false
		end
		local targetParent = CP.GetEmbedParent and CP:GetEmbedParent() or nil
		local sink = BB and BB.GetHideSink and BB.GetHideSink() or nil
		if frameHasForeignParent(
			nativePanel,
			LFGListFrame,
			targetParent,
			sink
		) then
			return true
		end
		return not entryCreationFieldsKeepNativeParents(nativePanel)
	end

	local function nativeChannelOccupied()
		return isLfgFrameVisible() or isBlizzardCreateActive()
			or areCreateFieldsExternallyOwned()
	end

	local function isCreateChannelBlocked()
		return isCreateFieldSurfaceActive() and nativeChannelOccupied()
	end

	function CP:IsCreateChannelAutoOpenBlocked()
		return nativeChannelOccupied()
	end

	local function secretText(value)
		if type(issecretvalue) ~= "function" then
			return false
		end
		local ok, secret = pcall(issecretvalue, value)
		return ok and secret == true
	end

	local function restoreInstructionShow(instructions)
		local original = instructions and instructions._gfOriginalShow
		if original ~= nil then
			instructions.Show = original
			instructions._gfOriginalShow = nil
		end
	end

	local function syncEditInstructions(editBox)
		if editBox == nil then
			return
		end
		if editBox._gfUseCreatePlaceholder == true then
			suppressNativeInstructions(editBox)
			return
		end
		local instructions = editBox.Instructions
		if instructions == nil then
			return
		end
		restoreInstructionShow(instructions)
		local empty = editBoxIsEmptyByLetterCount(editBox)
		if empty ~= nil then
			instructions:SetShown(empty)
			return
		end
		if type(InputBoxInstructions_OnTextChanged) == "function" then
			local ok = pcall(InputBoxInstructions_OnTextChanged, editBox)
			if ok then
				return
			end
		end
		local ok, text = false, nil
		if type(editBox.GetText) == "function" then
			ok, text = pcall(editBox.GetText, editBox)
		end
		local textIsSecret = secretText(text)
		if not ok or textIsSecret then
			instructions:Hide()
			return
		end
		local hasVisibleText = text ~= nil and trimName(text) ~= ""
		if hasVisibleText then
			instructions:Hide()
		else
			instructions:Show()
		end
	end

	local function restoreNameInstructions(editBox)
		if editBox == nil then
			return
		end
		restoreNativeInstructions(editBox)
		local instructions = editBox.Instructions
		if instructions ~= nil then
			instructions:ClearAllPoints()
			instructions:SetPoint("LEFT", editBox, "LEFT", 8, 0)
			instructions:SetPoint("RIGHT", editBox, "RIGHT", -4, 0)
		end
		syncEditInstructions(editBox)
	end

	local function ensureScrollingEditInitialized(editBox)
		if editBox == nil or type(ScrollingEdit_SetCursorOffsets) ~= "function" then
			return
		end
		local missingCursorState = editBox.cursorOffset == nil
			or editBox.cursorHeight == nil
		if missingCursorState then
			ScrollingEdit_SetCursorOffsets(editBox, 0, editBox.cursorHeight or 15)
		end
	end

	local function initializeDescriptionCursorState(nativePanel)
		local description = nativePanel and nativePanel.Description
		local editBox = description and description.EditBox
		if editBox == nil then
			return
		end
		ensureScrollingEditInitialized(editBox)
	end

	local function syncDescriptionEditBoxWidth(description)
		local editBox = description and description.EditBox
		if editBox == nil or type(description.GetWidth) ~= "function" then
			return
		end
		local frameWidth = tonumber(description:GetWidth()) or 0
		if frameWidth <= 0 then
			return
		end
		-- The addon projection owns a fixed right gutter even before the native
		-- hide-if-unscrollable bar appears. Tying wrap width to IsShown() makes
		-- identical text reflow after a reopen or an ownership/layout refresh.
		editBox:SetWidth(math.max(
			1,
			frameWidth - DESCRIPTION_EDIT_BOX_RIGHT_RESERVE
		))
		if type(InputScrollFrame_OnTextChanged) == "function" then
			pcall(InputScrollFrame_OnTextChanged, editBox, false)
		end
	end

	local function safeDescriptionTextChanged(editBox, userInput)
		if editBox == nil then
			return
		end
		ensureScrollingEditInitialized(editBox)
		if type(InputScrollFrame_OnTextChanged) == "function" then
			pcall(InputScrollFrame_OnTextChanged, editBox, userInput)
		end
		syncEditInstructions(editBox)
		if type(CP.UpdateCustomPlaceholders) == "function" then
			CP:UpdateCustomPlaceholders()
		end
	end

	function CP:SyncEmbeddedFieldChrome(nativePanel)
		local creation = nativePanel or getEntryCreation()
		if creation == nil then
			return
		end
		syncEditInstructions(creation.Name)
		local descriptionEdit = creation.Description and creation.Description.EditBox
		syncEditInstructions(descriptionEdit)
		self:UpdateCustomPlaceholders()
	end

	local NATIVE_DUPLICATE_FIELDS = {
		"Label", "NameLabel", "DescriptionLabel", "Inset", "WorkingCover",
		"GroupDropdown", "ActivityDropdown", "ActivityFinder",
		"PlayStyleDropdown", "ItemLevel", "PvpItemLevel", "PVPRating",
		"MythicPlusRating", "PrivateGroup", "CrossFactionGroup",
		"ListGroupButton", "LeaverBadge", "CancelButton",
	}

	local function ignoreWidgetShow()
	end

	local function ignoreWidgetSetShown()
	end

	local function parkNativeWidget(panel, widget)
		if widget == nil or widget._gfSuppressed == true then
			return
		end
		widget._gfSuppressedState = {
			shown = widgetShown(widget),
			originalShow = widget.Show,
			originalSetShown = widget.SetShown,
		}
		widget._gfSuppressed = true
		widget.Show = ignoreWidgetShow
		widget.SetShown = ignoreWidgetSetShown
		widget:Hide()
		panel._suppressedWidgets[#panel._suppressedWidgets + 1] = widget
	end

	local function restoreParkedWidget(widget)
		if widget == nil or widget._gfSuppressed ~= true then
			return
		end
		local state = widget._gfSuppressedState or {}
		local originalShow = state.originalShow
		local originalSetShown = state.originalSetShown
		widget._gfSuppressedState = nil
		widget._gfSuppressed = nil
		if type(originalShow) == "function" then
			widget.Show = originalShow
		end
		if type(originalSetShown) == "function" then
			widget.SetShown = originalSetShown
		end
		setWidgetShown(widget, state.shown)
	end

	local function restoreParkedWidgets(panel)
		local parked = panel and panel._suppressedWidgets or {}
		for index = #parked, 1, -1 do
			restoreParkedWidget(parked[index])
		end
		if panel then
			panel._suppressedWidgets = {}
		end
	end

	local function parkNativeEntryShell(panel, nativePanel)
		if nativePanel == nil then
			return
		end
		for index = 1, #NATIVE_DUPLICATE_FIELDS do
			parkNativeWidget(panel, nativePanel[NATIVE_DUPLICATE_FIELDS[index]])
		end
	end

	local function releaseShouldExposeNative(reason)
		return reason == "blizzard" or reason == "addon"
	end

	local function nativeEntryPageSelected()
		local root = LFGListFrame
		local creation = getEntryCreation()
		return creation ~= nil and frameReportsVisible(root)
			and root.activePanel == creation
	end

	local function settleUnselectedEntryPage()
		local root, creation = LFGListFrame, getEntryCreation()
		if root ~= nil and creation ~= nil and root.activePanel ~= creation then
			creation:Hide()
		end
	end

	local function settleReleasedVisibility(nativePanel, reason, originalShown)
		if nativePanel == nil then
			return
		end
		local show = originalShown == true
		if releaseShouldExposeNative(reason) then
			show = nativeEntryPageSelected()
		end
		nativePanel:SetShown(show == true)
	end

	local function updateBorrowedVoiceAtlas(panel, voice, skipUnchanged)
		local editBox = voice and voice.EditBox
		local enabled = editBox ~= nil
			and (not editBox.IsEnabled or editBox:IsEnabled())
		local active = enabled and (
			(type(editBox.HasFocus) == "function" and editBox:HasFocus())
			or (type(editBox.IsMouseMotionFocus) == "function" and editBox:IsMouseMotionFocus())
		)
		local anchor = panel and panel.voiceAnchor
		if not anchor or (skipUnchanged and anchor._gfVoiceAtlasActive == active
			and anchor._gfVoiceAtlasEnabled == enabled) then return end
		updateCreateInputAtlasFrame(anchor, active, enabled)
		anchor._gfVoiceAtlasActive, anchor._gfVoiceAtlasEnabled = active, enabled
	end

	local function stopBorrowedVoiceAtlas(voice)
		local anchor = voice and voice._gfVoiceAtlasAnchor
		if not anchor then return end
		anchor:SetScript("OnUpdate", nil)
		voice._gfVoiceAtlasAnchor = nil
		anchor._gfVoiceAtlasActive, anchor._gfVoiceAtlasEnabled = nil, nil
	end

	local function projectBorrowedVoiceField(panel, creation, voice)
		if panel == nil or creation == nil or voice == nil
			or panel.voiceAnchor == nil or voice.EditBox == nil
			or type(voice.GetParent) ~= "function"
			or voice:GetParent() ~= creation
		then
			return false
		end
		captureBorrowedVoiceProjection(voice)
		voice:ClearAllPoints()
		voice:SetPoint("TOPLEFT", panel.voiceAnchor, "TOPLEFT")
		voice:SetPoint("BOTTOMRIGHT", panel.voiceAnchor, "BOTTOMRIGHT")

		local editBox = voice.EditBox
		hideBorrowedNameChrome(editBox)
		editBox:ClearAllPoints()
		editBox:SetPoint("TOPLEFT", voice, "TOPLEFT", FIELD_EDGE_PAD, 0)
		editBox:SetPoint("BOTTOMRIGHT", voice, "BOTTOMRIGHT", -FIELD_EDGE_PAD, 0)
		setWidgetShown(voice.CheckButton, false)
		setWidgetShown(voice.Label, false)
		setWidgetShown(voice.WarningFrame, false)
		-- Keep the native VoiceChat and EditBox scripts untouched. Their secure
		-- text/change behavior remains Blizzard-owned across borrow and return.

		local visible = not panel:IsMythicPlusSidebarMode()
		setWidgetShown(voice, visible)
		setWidgetShown(editBox, visible)
		updateBorrowedVoiceAtlas(panel, voice)
		if visible and voice._gfVoiceAtlasAnchor ~= panel.voiceAnchor
			and type(panel.voiceAnchor.SetScript) == "function" then
			stopBorrowedVoiceAtlas(voice)
			local anchor, owner = panel.voiceAnchor, creation:GetParent()
			voice._gfVoiceAtlasAnchor = anchor
			-- Observe from our own visible atlas host; never leave hover/focus
			-- hooks on Blizzard's secure text field after the lease is returned.
			anchor:SetScript("OnUpdate", function()
				if voice._gfVoiceBorrowState == nil or creation:GetParent() ~= owner
					or voice:GetParent() ~= creation or voice.EditBox ~= editBox
					or editBox:GetParent() ~= voice then
					stopBorrowedVoiceAtlas(voice)
					updateCreateInputAtlasFrame(anchor, false, false)
					return
				end
				updateBorrowedVoiceAtlas(panel, voice, true)
			end)
		elseif not visible then
			stopBorrowedVoiceAtlas(voice)
		end
		return true
	end

	local function returnBorrowedVoiceField(voice)
		if voice == nil then
			return
		end
		stopBorrowedVoiceAtlas(voice)
		if voice._gfVoiceBorrowState == nil then
			return
		end
		local nativeShown = restoreBorrowedVoiceProjection(voice)
		setWidgetShown(voice, nativeShown == true)
	end

	local function returnOneBorrowedField(
		field,
		stateKey,
		restoreChrome,
		restoreInstructions
	)
		if field == nil then
			return
		end
		if restoreInstructions then
			restoreInstructions(field)
		end
		if restoreChrome then
			restoreChrome(field)
		end
		restoreProjectedField(field, stateKey)
	end

	local function restoreEntryCreationToBlizzard(nativePanel, panel, reason)
		if nativePanel == nil then
			return false
		end
		nativePanel:Hide()
		returnOneBorrowedField(
			nativePanel.Name,
			"_gfCreateNameBorrowState",
			restoreBorrowedNameChrome,
			restoreNameInstructions
		)
		local description = nativePanel.Description
		restoreDescriptionScrollBarProjection(description)
		returnOneBorrowedField(
			description,
			"_gfCreateDescriptionBorrowState",
			function(frame)
				restoreBorrowedWidgetChrome(frame, "_gfDescriptionChromeState")
			end,
			function(frame)
				restoreDescriptionInstructions(frame.EditBox)
			end
		)
		local lease = panel and panel._entryCreationLease
		local centralLease = lease ~= nil and BB
			and type(BB.IsEntryCreationLeaseCurrent) == "function"
			and BB.IsEntryCreationLeaseCurrent(lease)
		returnBorrowedVoiceField(nativePanel.VoiceChat)
		restoreEntryCreationInteraction(nativePanel, not centralLease)
		restoreParkedWidgets(panel)
		if centralLease and BB
			and type(BB.IsEntryCreationLeaseCurrent) == "function"
			and type(BB.ReleaseEntryCreationLease) == "function"
		then
			local projectionState = nativePanel._gfEntryCreationBorrowState
			local originalShown = projectionState and projectionState.shown
			nativePanel._gfEntryCreationBorrowState = nil
			local showNative = originalShown == true
			if releaseShouldExposeNative(reason) then
				showNative = nativeEntryPageSelected()
			end
			local released = BB.ReleaseEntryCreationLease(lease, {
				show = showNative,
				ownerAfterRelease = reason == "blizzard" and "blizzard" or nil,
			})
			if released then
				panel._entryCreationLease = nil
			end
			return released
		end
		local originalShown = restoreEntryCreationContainer(nativePanel)
		nativePanel._gfRestoringBorrowedEntryCreation = true
		local visibilityRestored, visibilityError = pcall(
			settleReleasedVisibility,
			nativePanel,
			reason,
			originalShown
		)
		nativePanel._gfRestoringBorrowedEntryCreation = nil
		if not visibilityRestored then
			error(visibilityError, 0)
		end
		return originalShown ~= nil
	end

	local function precacheEntryCreationLayouts()
		local creation = getEntryCreation()
		if creation == nil then
			return
		end
		BB.CacheLayout(creation)
		BB.CacheLayout(creation.Name)
		BB.CacheLayout(creation.Description)
		BB.CacheLayout(creation.VoiceChat)
		BB.CacheLayout(creation.VoiceChat and creation.VoiceChat.EditBox)
		for index = 1, #NATIVE_DUPLICATE_FIELDS do
			BB.CacheLayout(creation[NATIVE_DUPLICATE_FIELDS[index]])
		end
	end


	return {
		setCheckHitRectToLabel = setCheckHitRectToLabel,
		hideBorrowedNameChrome = hideBorrowedNameChrome,
		hideBorrowedWidgetChrome = hideBorrowedWidgetChrome,
		widgetShown = widgetShown,
		applyProtectedCreationGate = applyProtectedCreationGate,
		captureEntryCreationProjection = captureEntryCreationProjection,
		embedEntryCreationContainer = embedEntryCreationContainer,
		activitySelectionIsLive = activitySelectionIsLive,
		showEntryCreationForAddon = showEntryCreationForAddon,
		captureEntryCreationInteraction = captureEntryCreationInteraction,
		updateCreateInputBox = updateCreateInputBox,
		updateCreateInputAtlasFrame = updateCreateInputAtlasFrame,
		updateCreateDescriptionAtlasFrame = updateCreateDescriptionAtlasFrame,
		styleCreateInputAtlasFrame = styleCreateInputAtlasFrame,
		styleCreateDescriptionAtlasFrame = styleCreateDescriptionAtlasFrame,
		updateBorrowedDescriptionAtlas = updateBorrowedDescriptionAtlas,
		styleCreateInputBox = styleCreateInputBox,
		applyCreateTitleTextStyle = applyCreateTitleTextStyle,
		getCreateDrawerFooter = getCreateDrawerFooter,
		createDrawerScrollInsetR = createDrawerScrollInsetR,
		createDrawerScrollBarOffsetX = createDrawerScrollBarOffsetX,
		anchorCreateDrawerScrollBar = anchorCreateDrawerScrollBar,
		editBoxIsEmptyByLetterCount = editBoxIsEmptyByLetterCount,
		suppressNativeInstructions = suppressNativeInstructions,
		resolveActivityID = resolveActivityID,
		getEntryCreation = getEntryCreation,
		isCreateFieldSurfaceActive = isCreateFieldSurfaceActive,
		createFieldLeaseContextKey = createFieldLeaseContextKey,
		hasCurrentEntryCreationLease = hasCurrentEntryCreationLease,
		entryCreationLeaseMatchesSurface = entryCreationLeaseMatchesSurface,
		entryCreationFieldsKeepNativeParents = entryCreationFieldsKeepNativeParents,
		nativeChannelOccupied = nativeChannelOccupied,
		isCreateChannelBlocked = isCreateChannelBlocked,
		secretText = secretText,
		syncEditInstructions = syncEditInstructions,
		ensureScrollingEditInitialized = ensureScrollingEditInitialized,
		initializeDescriptionCursorState = initializeDescriptionCursorState,
		projectDescriptionScrollBar = projectDescriptionScrollBar,
		syncDescriptionEditBoxWidth = syncDescriptionEditBoxWidth,
		safeDescriptionTextChanged = safeDescriptionTextChanged,
		parkNativeEntryShell = parkNativeEntryShell,
		releaseShouldExposeNative = releaseShouldExposeNative,
		settleUnselectedEntryPage = settleUnselectedEntryPage,
		updateBorrowedVoiceAtlas = updateBorrowedVoiceAtlas,
		projectBorrowedVoiceField = projectBorrowedVoiceField,
		restoreEntryCreationToBlizzard = restoreEntryCreationToBlizzard,
		precacheEntryCreationLayouts = precacheEntryCreationLayouts,
	}
end
