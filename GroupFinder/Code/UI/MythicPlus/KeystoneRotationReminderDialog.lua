local _, GF = ...

GF.MythicPlusKeystoneRotationReminderDialog =
	GF.MythicPlusKeystoneRotationReminderDialog or {}
local Dialog = GF.MythicPlusKeystoneRotationReminderDialog

local STYLE = GF.PLAYER_CONTEXT_DIALOG_STYLE or {}
local DIALOG_NAME = "GroupFinderAddonKeystoneRotationReminderDialog"
local DIALOG_MIN_WIDTH = STYLE.WIDTH or 420
local CONTENT_INSET_X = STYLE.CONTENT_INSET_X or 36
local TEXT_WIDTH_TOLERANCE = 4

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
	local line1Width = measureUnboundedWidth(frame and frame.line1) or 0
	local line2Width = measureUnboundedWidth(frame and frame.line2) or 0
	local desiredWidth = math.max(
		DIALOG_MIN_WIDTH,
		math.ceil(math.max(line1Width, line2Width)
			+ CONTENT_INSET_X * 2
			+ TEXT_WIDTH_TOLERANCE)
	)
	if frame and frame.SetWidth then
		frame:SetWidth(desiredWidth)
	end
	return desiredWidth
end

local function playNoticeSound()
	local soundPath = GF.TOP_NOTICE_TOAST_SOUND
	if PlaySoundFile and type(soundPath) == "string" and soundPath ~= "" then
		pcall(PlaySoundFile, soundPath, "Master")
	end
end

local function formatText(template, ...)
	local ok, text = pcall(string.format, template, ...)
	return ok and text or template
end

local function colorGoldText(value)
	local text = tostring(value or "")
	local color = _G.NORMAL_FONT_COLOR
	if color and type(color.WrapTextInColorCode) == "function" then
		return color:WrapTextInColorCode(text)
	end
	return text
end

local function getServiceProjection(token)
	local service = GF.MythicPlusKeystoneRotationReminderService
	local projection = service and service.GetProjection
		and service:GetProjection() or nil
	if not projection or token and projection.token ~= token then
		return nil
	end
	return projection
end

local function dismissFromUI(frame)
	local service = GF.MythicPlusKeystoneRotationReminderService
	if service and service.DismissPresentation then
		service:DismissPresentation(frame and frame._projectionToken)
	elseif frame then
		frame:Hide()
	end
end

local function ensureFrame()
	if Dialog.frame then
		return Dialog.frame
	end
	local UI = GF.UI
	if not (UI and UI.CreateSatelliteSettingsFrame
		and UI.CreatePlayerContextDialogContentHost
		and UI.CreatePanelButton)
	then
		return nil
	end
	local L = GF.L or {}
	local frame = UI.CreateSatelliteSettingsFrame({
		name = DIALOG_NAME,
		width = DIALOG_MIN_WIDTH,
		height = STYLE.HEIGHT or 176,
		title = L.MPLUS_KEYSTONE_ROTATION_DIALOG_TITLE
			or "钥石置换提醒",
		levelOffset = STYLE.LEVEL_OFFSET or 18,
		backgroundColor = STYLE.BACKGROUND_COLOR
			or GF.PLAYER_CONTEXT_DIALOG_BACKGROUND_COLOR,
	})
	if frame.SetToplevel then
		frame:SetToplevel(true)
	end
	frame.contentHost = UI.CreatePlayerContextDialogContentHost(frame)

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
		"TOP", frame.line1, "BOTTOM", 0, -(STYLE.TEXT_LINE_GAP or 5))

	frame.ackButton = UI.CreatePanelButton(
		frame,
		L.MPLUS_KEYSTONE_ROTATION_DIALOG_ACK or "知道了",
		GF.PANEL_BUTTON_STANDARD_W or 72)
	if UI.ApplyPlayerContextDialogButtonFont then
		UI.ApplyPlayerContextDialogButtonFont(frame.ackButton)
	end
	frame.ackButton:SetPoint(
		"BOTTOM", frame, "BOTTOM", 0, STYLE.CONTENT_BOTTOM_INSET or 18)
	frame.ackButton:SetScript("OnClick", function()
		dismissFromUI(frame)
	end)
	if frame.ClosePanelButton then
		frame.ClosePanelButton:SetScript("OnClick", function()
			dismissFromUI(frame)
		end)
	end
	frame:HookScript("OnHide", function(self)
		if self._serviceHide then
			self._serviceHide = nil
			return
		end
		if self._projectionToken then
			dismissFromUI(self)
		end
	end)
	Dialog.frame = frame
	return frame
end

local function hideFrame()
	local frame = Dialog.frame
	if frame and frame:IsShown() then
		frame._serviceHide = true
		frame:Hide()
	end
	if frame then
		frame._projectionToken = nil
	end
end

local function present(projection)
	local current = getServiceProjection(projection and projection.token)
	if not current then
		return
	end
	local frame = ensureFrame()
	if not frame then
		return
	end
	local L = GF.L or {}
	local shouldCenter = not frame:IsShown()
		or frame._projectionToken ~= current.token
	GF.UI.ApplySettingsFrameChrome(
		frame,
		L.MPLUS_KEYSTONE_ROTATION_DIALOG_TITLE or "钥石置换提醒")
	local rawDungeonName = current.ownedDungeonName
	if (type(rawDungeonName) ~= "string" or rawDungeonName == "")
		and current.kind ~= "actual"
	then
		rawDungeonName = L.MPLUS_KEYSTONE_ROTATION_PREVIEW_DUNGEON
			or "艾杰斯亚学院"
	end
	local runLevel = colorGoldText(current.runLevel or 12)
	local ownedLevel = colorGoldText(current.ownedLevel or 10)
	if type(rawDungeonName) == "string" and rawDungeonName ~= "" then
		local dungeonName = colorGoldText(rawDungeonName)
		frame.line1:SetText(formatText(
			L.MPLUS_KEYSTONE_ROTATION_DIALOG_LINE1
				or "已完成 %s 层大秘境，你拥有 %s 层 %s 钥石",
			runLevel,
			ownedLevel,
			dungeonName))
	else
		frame.line1:SetText(formatText(
			L.MPLUS_KEYSTONE_ROTATION_DIALOG_LINE1_FALLBACK
				or "已完成 %s 层大秘境，你拥有 %s 层钥石",
			runLevel,
			ownedLevel))
	end
	frame.line2:SetText(
		L.MPLUS_KEYSTONE_ROTATION_DIALOG_LINE2
			or "可在副本重点置换钥石")
	frame.ackButton:SetText(
		L.MPLUS_KEYSTONE_ROTATION_DIALOG_ACK or "知道了")
	resizeForText(frame)
	fitButtonLabel(
		frame.ackButton:GetFontString(),
		(frame.ackButton:GetWidth() or 72) - 12)
	frame._projectionToken = current.token
	if shouldCenter then
		GF.UI.PresentSatelliteFrame(frame, {
			centerOnUIParent = true,
			offsetY = 20,
		})
	else
		if GF.UI.ApplyBodyBackground then
			GF.UI.ApplyBodyBackground(frame)
		end
		frame:Show()
	end
	if Dialog.soundToken ~= current.token then
		Dialog.soundToken = current.token
		playNoticeSound()
	end
end

function Dialog:Refresh()
	local projection = getServiceProjection()
	if not projection then
		hideFrame()
		return
	end
	local frame = self.frame
	if frame and frame:IsShown()
		and frame._projectionToken ~= projection.token
	then
		hideFrame()
	end
	present(projection)
end

function Dialog:RefreshLocale()
	local projection = getServiceProjection()
	if projection and self.frame and self.frame:IsShown() then
		present(projection)
	end
end

local service = GF.MythicPlusKeystoneRotationReminderService
if service and service.AddListener then
	service:AddListener(function()
		Dialog:Refresh()
	end)
end
