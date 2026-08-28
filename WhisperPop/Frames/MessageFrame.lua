------------------------------------------------------------
-- MessageFrame.lua
--
-- Abin
-- 2010-9-28
------------------------------------------------------------

local IsShiftKeyDown = IsShiftKeyDown
local min = min
local max = max
local floor = floor
local strlower = strlower
local strfind = strfind
local gmatch = gmatch
local gsub = gsub
local ChatTypeInfo = ChatTypeInfo
local ICON_LIST = ICON_LIST
local ICON_TAG_LIST = ICON_TAG_LIST

local GetMouseFocus = GetMouseFocus or function()
	local frames = _G.GetMouseFoci()
	return frames and frames[1]
  end

local GameTooltip = GameTooltip

local addon = WhisperPop
local L = addon.L

local FRAME_WIDTH = 400
local INDENT_LEFT = 8
local INDENT_RIGHT = 28
local LIST_WIDTH = FRAME_WIDTH - INDENT_LEFT - INDENT_RIGHT
local MESSAGE_MIN_HEIGHT = 48
local MESSAGE_MAX_HEIGHT = 400
local MESSAGE_ADD_HEIGHT = 35

local curButton, curData, curName

-- Forward declarations (assigned after `endButton` exists). Without this, `SetData` above would see a global `MessageList_*` = nil.
local MessageList_UpdateEndFlash, MessageList_StopEndFlashTicker, MessageList_StartEndFlashTicker
local endFlashTicker

-- Message frame
local frame = addon.templates.CreateFrame("WhisperPopMessageFrame", addon.frame)
addon.messageFrame = frame
addon.templates.RegisterDelayHideFrame(frame)
frame.topLine:Hide()
frame:SetWidth(FRAME_WIDTH)

frame.icon = frame:CreateTexture(frame:GetName().."Icon", "ARTWORK")
frame.icon:SetSize(16, 16)
frame.icon:SetPoint("TOPLEFT", 12, -12)

frame.text:ClearAllPoints()
frame.text:SetPoint("LEFT", frame.icon, "RIGHT", 6, 0)
frame.text:SetTextColor(1, 1, 1)

frame:SetScript("OnHide", function(self)
	self:Hide()
	if GetMouseFocus() ~= curButton then
		addon.frame.list:TextureButton("highlightTexture")
	end
	curButton, curData, curName = nil
end)

local protectCheck = CreateFrame("CheckButton", frame:GetName().."ProtectCheck", frame, "InterfaceOptionsCheckButtonTemplate")
frame.protectCheck = protectCheck
protectCheck:SetPoint("LEFT", frame.icon, "RIGHT", 230, 0)
local checkText = _G[protectCheck:GetName().."Text"]
frame.protectCheckText = checkText

--- Only call from: (1) switching conversation PrepareConversation (2) protect checkbox OnClick (3) Core ApplyContentFontStyle after font change.
local function MessageFrame_RefreshProtectLabel()
	if protectCheck:GetChecked() then
		checkText:SetText(L["protected"])
		checkText:SetTextColor(1, 0, 0)
	else
		checkText:SetText(L["protect"])
		checkText:SetTextColor(1, 1, 1)
	end
	protectCheck:SetHitRectInsets(0, -checkText:GetWidth(), 0, 0)
end

frame.RefreshProtectCheckLabel = MessageFrame_RefreshProtectLabel
checkText:SetText(L["protect"])
checkText:SetTextColor(1, 1, 1)
protectCheck:SetHitRectInsets(0, -checkText:GetWidth(), 0, 0)

protectCheck:SetScript("OnClick", function(self)
	if not curData then
		return
	end

	if self:GetChecked() then
		curData.protected = 1
	else
		curData.protected = nil
	end
	MessageFrame_RefreshProtectLabel()

	local index = curData and addon:FindPlayerData(curData.name)
	if index then
		addon.frame.list:UpdateData(index)
	end
end)

-- The ScrollingMessageFrame that displays message text lines
local list = CreateFrame("ScrollingMessageFrame", "WhisperPopScrollingMessageFrame", frame, "ChatFrameTemplate")
list:SetPoint("TOPLEFT", frame.icon, "BOTTOMLEFT", 0, -6)
list:SetWidth(LIST_WIDTH)
list:SetFading(false)
list:SetMaxLines(addon.MAX_MESSAGES)
list:SetJustifyH("LEFT")
-- Indented wrap keys off the first glyph; proportional fonts make wrapped lines look staggered.
list:SetIndentedWordWrap(false)
list:SetHyperlinksEnabled(true)

-- Get rid of junks from "ChatFrameTemplate"
list:SetScript("OnUpdate", nil)
list:SetScript("OnEvent", nil)
list:UnregisterAllEvents()
list:Show()

-- A hidden FontString to determine height of every message text
local totalHeight = 0
local testFont = list:CreateFontString(nil, "ARTWORK", "ChatFontNormal")
frame.messageScrollList = list
frame.messageTestFont = testFont
testFont:SetPoint("TOPLEFT", list, "BOTTOMLEFT")
testFont:SetWidth(LIST_WIDTH)
testFont:SetJustifyH("LEFT")
testFont:SetNonSpaceWrap(true)
testFont:SetIndentedWordWrap(false)
testFont:Hide()
testFont:SetText("ABC")
local singleLineTestHeight = max(1, testFont:GetHeight())

function frame:RecalculateContentFontMetrics()
	testFont:SetText("ABC")
	singleLineTestHeight = max(1, testFont:GetHeight())
end

function frame:GetCurrentConversationData()
	return curData
end

frame:EnableMouseWheel(true)

function frame:IsReading()
	if self:IsShown() then
		return curName
	end
end

function frame:UpdateHeight()
	if totalHeight < singleLineTestHeight then
		totalHeight = singleLineTestHeight
	end

	if totalHeight > MESSAGE_MAX_HEIGHT then
		totalHeight = MESSAGE_MAX_HEIGHT
	end

	self:SetHeight(max(totalHeight, MESSAGE_MIN_HEIGHT) + MESSAGE_ADD_HEIGHT + 16)
	list:SetHeight(totalHeight + 2)
end

function frame:AddMessage(text, inform, timeStamp, update)
	if inform and addon.db.receiveOnly then
		return
	end

	local r, g, b
	if inform then
		r, g, b = 0.5, 0.5, 0.5
	else
		local color
		if curData and curData.class == "BN" then
			color = ChatTypeInfo["BN_WHISPER"]
		else
			color = ChatTypeInfo["WHISPER"]
		end
		r, g, b = color.r, color.g, color.b
	end

	if strfind(text, "{", 1, true) then
		local term
		for tag in gmatch(text, "%b{}") do
			term = strlower(gsub(tag, "[{}]", ""))
			local result = ICON_TAG_LIST[term]
			local icon = result and ICON_LIST[result]
			if icon then
				text = gsub(text, tag, icon.."0|t")
			end
		end
	end

	if addon.db.time then
		text = "|cffffd200"..timeStamp.."|r "..text
	end

	list:AddMessage(text, r, g, b)

	if totalHeight < MESSAGE_MAX_HEIGHT then
		testFont:SetText(text)
		totalHeight = totalHeight + testFont:GetHeight()
	end

	if update then
		self:UpdateHeight()
	end
end

-- Split load: header + empty body immediately; heavy AddMessage loop can be debounced from MainFrame when hovering the list.
function frame:PrepareConversation(button, data)
	if curData == data then
		return
	end

	list:Clear()

	curButton, curData, curName = button, data, data and data.name
	if not data then
		self:Hide()
		return
	end

	if data.protected then
		protectCheck:SetChecked(true)
	else
		protectCheck:SetChecked(false)
	end
	MessageFrame_RefreshProtectLabel()

	addon.templates.ShowPlayerInfo(data, self.icon, self.text, 1)
	totalHeight = 0
	self:Show()
	self:UpdateHeight()
end

function frame:CommitConversationMessages(data)
	if not data or curData ~= data then
		return
	end

	list:Clear()
	totalHeight = 0

	local needle = addon:GetActiveSearchNeedle()
	local text, inform, timeStamp
	for i = 1, #data.messages do
		text, inform, timeStamp = addon:DecodeMessage(data.messages[i])
		if needle then
			local low = strlower(text or "")
			if strfind(low, needle, 1, true) then
				self:AddMessage(text, inform, timeStamp)
			end
		else
			self:AddMessage(text, inform, timeStamp)
		end
	end

	self:UpdateHeight()
	list:ScrollToBottom()
	MessageList_UpdateEndFlash()
end

function frame:SetData(button, data)
	if curData == data then
		return
	end

	self:PrepareConversation(button, data)
	if data then
		self:CommitConversationMessages(data)
	end
end

local function StartCounting()
	frame:StartCounting()
end

local function StopCounting()
	frame:StopCounting()
	if curButton then
		addon.frame.list:TextureButton("highlightTexture", curButton)
	end
end

frame:SetScript("OnEnter", StopCounting)
frame:SetScript("OnLeave", StartCounting)

local function MessageFrame_ProtectCheck_AnchorTooltip(self)
	local left = self:GetLeft()
	if left and left > 500 then
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
	else
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	end
end

protectCheck:SetScript("OnEnter", function(self)
	StopCounting()
	MessageFrame_ProtectCheck_AnchorTooltip(self)
	GameTooltip:ClearLines()
	local title = protectCheck:GetChecked() and L["protected"] or L["protect"]
	GameTooltip:AddLine(title, 1, 0.82, 0)
	for line in gmatch(L["protect tooltip"] or "", "[^\r\n]+") do
		GameTooltip:AddLine(line, 1, 1, 1, true)
	end
	GameTooltip:Show()
end)

protectCheck:SetScript("OnLeave", function(self)
	GameTooltip:Hide()
	StartCounting()
end)

frame.topClose:SetScript("OnEnter", StopCounting)
frame.topClose:SetScript("OnLeave", StartCounting)

-- Message link hover tooltips (item / enchant / spell / …).
local linkTypes = {
	item = true,
	enchant = true,
	spell = true,
	quest = true,
	unit = true,
	talent = true,
	achievement = true,
	glyph = true,
	instancelock = true,
	currency = true,
	keystone = true,
	azessence = true,
	mawpower = true,
	conduit = true,
	mount = true,
}

local function HyperLink_SetTypes(self, link)
	GameTooltip.__isHoverTip = true
	GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT")
	GameTooltip:SetHyperlink(link)
	GameTooltip:Show()
end

local function HyperLink_OnEnter(self, link, ...)
	local linkType = strmatch(link, "^([^:]+)")
	if addon.db.messageHoverLinks and linkType and linkTypes[linkType] then
		HyperLink_SetTypes(self, link)
	end

	StopCounting()
end

local function HyperLink_OnLeave(self)
	GameTooltip:Hide()
	GameTooltip.__isHoverTip = nil

	StartCounting()
end

list:SetScript("OnHyperlinkEnter", HyperLink_OnEnter)
list:SetScript("OnHyperlinkLeave", HyperLink_OnLeave)

local function CreateScrollButton(name, parentFuncName)
	local button = CreateFrame("Button", list:GetName().."Button"..name, list)
	button:SetWidth(24)
	button:SetHeight(24)
	button:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-Scroll"..name.."-Up")
	button:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-Scroll"..name.."-Down")
	button:SetDisabledTexture("Interface\\ChatFrame\\UI-ChatIcon-Scroll"..name.."-Disabled")
	button:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
	button.parentFuncName = parentFuncName
	button:SetScript("OnClick", function(self)
		list[self.parentFuncName](list)
		MessageList_UpdateEndFlash()
	end)
	button:SetScript("OnEnter", StopCounting)
	button:SetScript("OnLeave", StartCounting)
	return button
end

-- Scroll buttons
local endButton = CreateScrollButton("End", "ScrollToBottom")
endButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -3, 12)

local downButton = CreateScrollButton("Down", "ScrollDown")
downButton:SetPoint("BOTTOM", endButton, "TOP", 0, -6)

local upButton = CreateScrollButton("Up", "ScrollUp")
upButton:SetPoint("BOTTOM", downButton, "TOP", 0, -6)

addon.templates.CreateFlash(endButton)

-- Scroll-end flash: avoid per-frame OnUpdate on the ScrollingMessageFrame; poll at low frequency while the panel is open.
MessageList_UpdateEndFlash = function()
	if list:AtBottom() then
		endButton:StopFlash()
	else
		endButton:StartFlash()
	end
end

MessageList_StopEndFlashTicker = function()
	if endFlashTicker then
		endFlashTicker:Cancel()
		endFlashTicker = nil
	end
end

MessageList_StartEndFlashTicker = function()
	if endFlashTicker or not frame:IsShown() then
		return
	end
	endFlashTicker = C_Timer.NewTicker(0.25, function()
		if not frame:IsShown() then
			MessageList_StopEndFlashTicker()
			return
		end
		MessageList_UpdateEndFlash()
	end)
end

frame:HookScript("OnShow", function()
	MessageList_StartEndFlashTicker()
	MessageList_UpdateEndFlash()
end)

frame:HookScript("OnHide", MessageList_StopEndFlashTicker)

addon:RegisterEventCallback("OnNewMessage", function(name, class, text, inform, timeStamp)
	if frame:IsReading() == name then
		frame:AddMessage(text, inform, timeStamp, 1)
		MessageList_UpdateEndFlash()
	end
end)

frame:SetScript("OnMouseWheel", function(self, delta)
	local lines = tonumber(addon.db.messageWheelLines) or addon.DB_DEFAULTS.messageWheelLines.default
	lines = max(1, min(50, floor(lines)))
	if delta == 1 then
		if IsShiftKeyDown() then
			list:ScrollToTop()
		else
			for _ = 1, lines do
				list:ScrollUp()
			end
		end
	elseif delta == -1 then
		if IsShiftKeyDown() then
			list:ScrollToBottom()
		else
			for _ = 1, lines do
				list:ScrollDown()
			end
		end
	end
	MessageList_UpdateEndFlash()
end)