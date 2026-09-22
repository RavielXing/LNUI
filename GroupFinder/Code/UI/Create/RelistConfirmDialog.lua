local _, GF = ...

GF.RelistConfirmDialog = GF.RelistConfirmDialog or {}
local Dialog = GF.RelistConfirmDialog

local STYLE = GF.PLAYER_CONTEXT_DIALOG_STYLE or {}
local DIALOG_NAME = "GroupFinderAddonRelistConfirmDialog"
local DIALOG_MIN_WIDTH = STYLE.WIDTH or 420
local DIALOG_HEIGHT = STYLE.HEIGHT or 176
local CONTENT_INSET_X = STYLE.CONTENT_INSET_X or 36
local TEXT_WIDTH_TOLERANCE = 4
local DIALOG_BUTTON_WIDTH = 110
local DIALOG_BUTTON_GAP = 12
local DIALOG_BOTTOM_INSET = STYLE.CONTENT_BOTTOM_INSET or 18
local DIALOG_MAIN_WINDOW_ALPHA = 0.64
local DIALOG_FRAME_LEVEL = 1000
local DIALOG_SPINNER_SIZE = 32

local function localeText(key, fallback)
	local locale = GF.L or {}
	return locale[key] or fallback
end

local function getListing()
	return GF.RecruitmentSession
end

local function fitButtonLabel(fontString, width)
	if fontString and GF.Font and GF.Font.SetFitWidth then
		GF.Font.SetFitWidth(fontString, math.max(1, width), 10)
	end
end

local function measureUnboundedWidth(fontString)
	local method = fontString
		and (fontString.GetUnboundedStringWidth or fontString.GetStringWidth)
	if type(method) ~= "function" then
		return nil
	end
	local ok, rawWidth = pcall(method, fontString)
	local width = ok and tonumber(rawWidth) or nil
	return width and width >= 0 and width or nil
end

local function resizeForText(frame)
	local desiredWidth = DIALOG_MIN_WIDTH
	if frame and frame._repostReady == true then
		local line1Width = measureUnboundedWidth(frame.line1) or 0
		local line2Width = measureUnboundedWidth(frame.line2) or 0
		desiredWidth = math.max(
			DIALOG_MIN_WIDTH,
			math.ceil(math.max(line1Width, line2Width)
				+ CONTENT_INSET_X * 2
				+ TEXT_WIDTH_TOLERANCE)
		)
	end
	if frame and type(frame.SetWidth) == "function" then
		frame:SetWidth(desiredWidth)
	end
	return desiredWidth
end

local function setMainWindowAlpha(frame, transparent)
	local mainFrame = GF.MainFrame and GF.MainFrame.frame
	if not (mainFrame and type(mainFrame.SetAlpha) == "function") then
		return
	end
	if transparent then
		if frame._previousMainAlpha == nil then
			frame._previousMainAlpha = type(mainFrame.GetAlpha) == "function"
				and mainFrame:GetAlpha() or 1
		end
		mainFrame:SetAlpha(DIALOG_MAIN_WINDOW_ALPHA)
	elseif frame._previousMainAlpha ~= nil then
		local previous = tonumber(frame._previousMainAlpha) or 1
		frame._previousMainAlpha = nil
		mainFrame:SetAlpha(previous)
	end
end

local function applyTopLayer(frame)
	if type(frame.SetFrameStrata) == "function" then
		frame:SetFrameStrata("DIALOG")
	end
	if type(frame.SetFrameLevel) == "function" then
		frame:SetFrameLevel(DIALOG_FRAME_LEVEL)
	end
	local closeButton = frame.ClosePanelButton
	if closeButton and type(closeButton.SetFrameLevel) == "function" then
		closeButton:SetFrameLevel(DIALOG_FRAME_LEVEL + 20)
	end
	if type(frame.Raise) == "function" then
		frame:Raise()
	end
end

local function setPendingPresentation(frame, pending)
	local UI = GF.UI
	if frame.line1 and frame.line1.SetShown then
		frame.line1:SetShown(not pending)
	end
	if frame.line2 and frame.line2.SetShown then
		frame.line2:SetShown(not pending)
	end
	if not frame.pendingSpinner then
		return
	end
	if pending then
		if UI and UI.StartPendingSpinner then
			UI.StartPendingSpinner(frame.pendingSpinner, DIALOG_SPINNER_SIZE)
		else
			frame.pendingSpinner:Show()
		end
	elseif UI and UI.StopPendingSpinner then
		UI.StopPendingSpinner(frame.pendingSpinner)
	else
		frame.pendingSpinner:Hide()
	end
end

local function refreshFrame(frame)
	if frame == nil then
		return
	end
	local UI = GF.UI
	if UI and UI.ApplySettingsFrameChrome then
		UI.ApplySettingsFrameChrome(
			frame,
			localeText("BUMP_LISTING_DIALOG_TITLE", "Republish"))
	end
	frame.line1:SetText(localeText(
		"BUMP_LISTING_REPOST_CONFIRM_LINE1",
		"The original listing has been removed. Click Publish Now to republish."))
	frame.line2:SetText(localeText(
		"BUMP_LISTING_REPOST_CONFIRM_LINE2",
		"Closing this window will leave the listing removed."))
	frame.repostButton:SetText(localeText(
		"BUMP_LISTING_REPOST_NOW",
		"Publish Now"))
	frame.cancelButton:SetText(localeText(
		"BUMP_LISTING_CANCEL",
		"Cancel Publishing"))
	frame.repostButton:SetEnabled(frame._repostReady == true)
	setPendingPresentation(
		frame,
		frame:IsShown() == true and frame._repostReady ~= true)
	resizeForText(frame)
	fitButtonLabel(
		frame.repostButton:GetFontString(),
		DIALOG_BUTTON_WIDTH - 12)
	fitButtonLabel(
		frame.cancelButton:GetFontString(),
		DIALOG_BUTTON_WIDTH - 12)
end

local function requestCancel(frame)
	local generation = tonumber(frame and frame._relistGeneration)
	local listing = getListing()
	local cancelled = listing
		and type(listing.CancelRelistAfterRemove) == "function"
		and listing:CancelRelistAfterRemove(generation) == true
	if frame and frame:IsShown() then
		Dialog:Hide(cancelled and "cancelled" or "cancel")
	end
end

local function ensureFrame()
	if Dialog.frame then
		return Dialog.frame
	end
	local UI = GF.UI
	if not (UI
		and type(UI.CreateSatelliteSettingsFrame) == "function"
		and type(UI.CreatePlayerContextDialogContentHost) == "function"
		and type(UI.CreateFontString) == "function"
		and type(UI.CreatePanelButton) == "function"
		and type(UI.CreatePendingSpinner) == "function"
		and type(UI.PresentSatelliteFrame) == "function")
	then
		return nil
	end
	local frame = UI.CreateSatelliteSettingsFrame({
		name = DIALOG_NAME,
		width = DIALOG_MIN_WIDTH,
		height = DIALOG_HEIGHT,
		title = localeText("BUMP_LISTING_DIALOG_TITLE", "Republish"),
		levelOffset = STYLE.LEVEL_OFFSET or 18,
		backgroundColor = STYLE.BACKGROUND_COLOR
			or GF.PLAYER_CONTEXT_DIALOG_BACKGROUND_COLOR,
	})
	if frame == nil then
		return nil
	end
	-- The destructive two-click transaction must remain visually dominant even
	-- if the main window is clicked or its configured layers are reapplied.
	frame._gfFollowMainFrameRaise = true
	frame._gfOnSatelliteFrameLayersApplied = function(self)
		applyTopLayer(self)
	end
	applyTopLayer(frame)
	if frame.SetToplevel then
		frame:SetToplevel(true)
	end
	frame.contentHost = UI.CreatePlayerContextDialogContentHost(frame)

	-- Reuse the keystone-rotation reminder's two-line content hierarchy:
	-- centered 15px primary text followed by a centered 15px gold accent line.
	frame.line1 = UI.CreateFontString(
		frame, "OVERLAY", "GameFontHighlight")
	if UI.ApplyPlayerContextDialogTextStyle then
		UI.ApplyPlayerContextDialogTextStyle(frame.line1, "primary")
	end
	frame.line1:SetPoint("LEFT", frame.contentHost, "LEFT", 0, 0)
	frame.line1:SetPoint("RIGHT", frame.contentHost, "RIGHT", 0, 0)
	frame.line1:SetPoint(
		"BOTTOM",
		frame.contentHost,
		"CENTER",
		0,
		(STYLE.TEXT_LINE_GAP or 5) / 2)

	frame.line2 = UI.CreateFontString(
		frame, "OVERLAY", "GameFontHighlight")
	if UI.ApplyPlayerContextDialogTextStyle then
		UI.ApplyPlayerContextDialogTextStyle(frame.line2, "accent")
	end
	frame.line2:SetPoint("LEFT", frame.contentHost, "LEFT", 0, 0)
	frame.line2:SetPoint("RIGHT", frame.contentHost, "RIGHT", 0, 0)
	frame.line2:SetPoint(
		"TOP",
		frame.line1,
		"BOTTOM",
		0,
		-(STYLE.TEXT_LINE_GAP or 5))

	frame.pendingSpinner = UI.CreatePendingSpinner(
		frame.contentHost,
		DIALOG_SPINNER_SIZE)
	if frame.pendingSpinner == nil then
		frame:Hide()
		return nil
	end
	frame.pendingSpinner:SetPoint(
		"CENTER", frame.contentHost, "CENTER", 0, 0)
	frame.pendingSpinner:Hide()

	frame.repostButton = UI.CreatePanelButton(
		frame,
		"",
		DIALOG_BUTTON_WIDTH)
	frame.cancelButton = UI.CreatePanelButton(
		frame,
		"",
		DIALOG_BUTTON_WIDTH)
	if UI.ApplyPlayerContextDialogButtonFont then
		UI.ApplyPlayerContextDialogButtonFont(frame.repostButton)
		UI.ApplyPlayerContextDialogButtonFont(frame.cancelButton)
	end
	frame.repostButton:SetPoint(
		"BOTTOMRIGHT",
		frame,
		"BOTTOM",
		-(DIALOG_BUTTON_GAP / 2),
		DIALOG_BOTTOM_INSET)
	frame.cancelButton:SetPoint(
		"BOTTOMLEFT",
		frame,
		"BOTTOM",
		DIALOG_BUTTON_GAP / 2,
		DIALOG_BOTTOM_INSET)

	frame.repostButton:SetScript("OnClick", function()
		local generation = tonumber(frame._relistGeneration)
		local listing = getListing()
		local continued = false
		if listing and type(listing.ContinueRelist) == "function" then
			-- This direct button callback is the second 12.1 hardware click.
			-- Keep CreateListing synchronous inside ContinueRelist.
			continued = listing:ContinueRelist(generation) == true
		end
		if frame:IsShown() then
			if continued then
				Dialog:Hide("accepted")
			else
				requestCancel(frame)
			end
		end
	end)
	frame.cancelButton:SetScript("OnClick", function()
		requestCancel(frame)
	end)
	if frame.ClosePanelButton then
		frame.ClosePanelButton:SetScript("OnClick", function()
			requestCancel(frame)
		end)
	end
	frame:HookScript("OnHide", function(self)
		setMainWindowAlpha(self, false)
		if UI.StopPendingSpinner and self.pendingSpinner then
			UI.StopPendingSpinner(self.pendingSpinner)
		end
		local generation = tonumber(self._relistGeneration)
		self._relistGeneration = nil
		Dialog._shownGeneration = nil
		if Dialog._programmaticHide == true then
			return
		end
		local listing = getListing()
		if listing
			and type(listing.IsAwaitingRelistRepost) == "function"
			and listing:IsAwaitingRelistRepost(generation)
			and type(listing.CancelRelistAfterRemove) == "function"
		then
			listing:CancelRelistAfterRemove(generation)
		end
	end)
	frame:HookScript("OnShow", function(self)
		setMainWindowAlpha(self, true)
		applyTopLayer(self)
	end)
	Dialog.frame = frame
	refreshFrame(frame)
	return frame
end

function Dialog:Show(generation, ready)
	generation = tonumber(generation)
	local frame = generation ~= nil and ensureFrame() or nil
	if frame == nil then
		return false
	end
	local wasShown = frame:IsShown()
	frame._relistGeneration = generation
	frame._repostReady = ready == true
	self._shownGeneration = generation
	refreshFrame(frame)
	if not wasShown then
		GF.UI.PresentSatelliteFrame(frame, {
			centerOnUIParent = true,
			offsetY = 20,
			refreshBackground = true,
		})
	else
		frame:Show()
	end
	setPendingPresentation(frame, frame._repostReady ~= true)
	applyTopLayer(frame)
	return frame:IsShown() == true
end

function Dialog:SetReady(generation)
	generation = tonumber(generation)
	local frame = self.frame
	if frame == nil
		or frame:IsShown() ~= true
		or tonumber(frame._relistGeneration) ~= generation
	then
		return false
	end
	frame._repostReady = true
	refreshFrame(frame)
	applyTopLayer(frame)
	return true
end

function Dialog:IsAvailable()
	return ensureFrame() ~= nil
end

function Dialog:Hide()
	local frame = self.frame
	if frame and frame:IsShown() then
		self._programmaticHide = true
		frame:Hide()
		self._programmaticHide = nil
	end
	if frame then
		frame._relistGeneration = nil
		frame._repostReady = nil
	end
	self._shownGeneration = nil
end

function Dialog:RefreshLocale()
	if self.frame then
		refreshFrame(self.frame)
	end
end
