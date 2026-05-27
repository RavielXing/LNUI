------------------------------------------------------------
-- OptionFrame.lua
--
-- Abin
-- 2010-9-28
------------------------------------------------------------

local IsShiftKeyDown = IsShiftKeyDown
local tostring = tostring
local tonumber = tonumber
local format = format
local min = min
local max = max
local floor = floor
local strtrim = strtrim
local strlower = strlower
local gmatch = string.gmatch
local CreateFrame = CreateFrame
local GameTooltip = GameTooltip
local SETTINGS = SETTINGS

local addon = WhisperPop
local L = addon.L

local NGA_FEEDBACK_URL = "https://nga.178.com/read.php?tid=46740208"

--- 中繁 NGA 文案仅写在 zhCN/zhTW 语言包；有键即显示，不区分正式服/怀旧/其它 Interface。
local function WhisperPop_ShowNgaFeedback()
	local nga = L["desc nga feedback"]
	return nga ~= nil and nga ~= ""
end

local ngaFeedbackLabel
local ngaCopyBtn

local Y_GAP = -23
-- Sliders add low/high labels under the track; need more vertical room than checkbox rows.
local SLIDER_Y_GAP = -42
-- Dropdown bottom to next main-line checkbox.
local COMBO_Y_TIGHT = -12
local NGA_BLOCK_Y_GAP = Y_GAP
-- Same horizontal indent as "锁定按钮位置" (InterfaceOptionsCheckButtonTemplate width).
local function CheckIndentOffset(check)
	return check and check.GetWidth and check:GetWidth() or 26
end

-- Key binding stuff
BINDING_HEADER_WHISPERPOP_TITLE = "WhisperPop"
BINDING_NAME_WHISPERPOP_TOGGLE = L["toggle frame"]

local popFrame = addon.frame

--- Match MainFrame message preview heuristic: when the header sits toward the right side of the screen,
--- anchor tooltips so they grow leftward and stay on-screen.
local function WhisperPop_SetHeaderIconTooltipOwner(self)
	local left = self:GetLeft()
	if left and left > 500 then
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
	else
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	end
end

local function CreateHeaderIconButton(parent, name, tex, size)
	local b = CreateFrame("Button", name, parent)
	b:SetSize(size, size)
	b:SetNormalTexture(tex)
	b:SetHighlightTexture(tex, "ADD")
	return b
end

local SEARCH_ICON_FALLBACK = "Interface\\Icons\\INV_Misc_SearchLens"

local function CreateHeaderAtlasButton(parent, name, atlasName, size)
	local b = CreateFrame("Button", name, parent)
	b:SetSize(size, size)
	local nt = b:CreateTexture(nil, "ARTWORK")
	nt:SetSize(size, size)
	nt:SetPoint("CENTER")
	local okAtlas = atlasName and nt.SetAtlas and pcall(nt.SetAtlas, nt, atlasName)
	if not okAtlas then
		nt:SetTexture(SEARCH_ICON_FALLBACK)
	end
	b:SetNormalTexture(nt)
	local ht = b:CreateTexture(nil, "HIGHLIGHT")
	ht:SetBlendMode("ADD")
	ht:SetSize(size, size)
	ht:SetPoint("CENTER")
	if not (atlasName and ht.SetAtlas and pcall(ht.SetAtlas, ht, atlasName)) then
		ht:SetTexture(SEARCH_ICON_FALLBACK)
	end
	b:SetHighlightTexture(ht)
	return b
end

local configButton = CreateHeaderIconButton(popFrame, popFrame:GetName().."Config", "Interface\\Buttons\\UI-OptionsButton", 16)
configButton:SetPoint("TOPLEFT", 7, -9)
--- NDui_Plus Skins/WhisperPop.lua calls B.ReskinIcon(config.icon); we only use SetNormalTexture(path), so expose the region.
configButton.icon = configButton:GetNormalTexture()

local searchToggleBtn = CreateHeaderAtlasButton(popFrame, popFrame:GetName().."SearchToggle", "common-search-magnifyingglass", 14)
searchToggleBtn:SetPoint("LEFT", configButton, "RIGHT", 4, 0)
searchToggleBtn.icon = searchToggleBtn:GetNormalTexture()

local searchStrip = CreateFrame("Frame", popFrame:GetName().."SearchStrip", popFrame, "BackdropTemplate")
addon.searchStrip = searchStrip
searchStrip:SetBackdrop({ bgFile = addon.BACKGROUND, tile = true, tileSize = 16, edgeFile = addon.BORDER, edgeSize = 16, insets = { left = 5, right = 5, top = 5, bottom = 5 } })
searchStrip:SetHeight(30)
searchStrip:SetPoint("BOTTOMLEFT", popFrame, "TOPLEFT", 0, 2)
searchStrip:SetPoint("BOTTOMRIGHT", popFrame, "TOPRIGHT", 0, 2)
searchStrip:Hide()

local clearSearchBtn = CreateFrame("Button", nil, searchStrip)
clearSearchBtn:SetSize(23, 23)
clearSearchBtn:SetPoint("RIGHT", -8, 0)
clearSearchBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
local clearLbl = clearSearchBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
clearLbl:SetPoint("CENTER", 0, 0)
local cfFont, cfSize = clearLbl:GetFont()
if cfFont and cfSize then
	clearLbl:SetFont(cfFont, cfSize + 5, "")
end
clearLbl:SetText("×")

local searchEdit = CreateFrame("EditBox", searchStrip:GetName().."Edit", searchStrip)
searchEdit:SetMultiLine(false)
searchEdit:SetMaxLetters(200)
searchEdit:SetAutoFocus(false)
searchEdit:SetFontObject("ChatFontNormal")
searchEdit:SetHeight(20)
searchEdit:SetPoint("LEFT", 10, 0)
searchEdit:SetPoint("RIGHT", clearSearchBtn, "LEFT", -6, 0)

searchEdit:SetScript("OnEnterPressed", function(self)
	local raw = strtrim(self:GetText() or "")
	if raw == "" then
		addon._searchNeedleLower = nil
	else
		addon._searchNeedleLower = strlower(raw)
	end
	addon:RefreshSearchListBinding()
	self:ClearFocus()
end)

searchEdit:SetScript("OnEscapePressed", function(self)
	self:ClearFocus()
end)

clearSearchBtn:SetScript("OnClick", function()
	searchEdit:SetText("")
	addon._searchNeedleLower = nil
	addon:RefreshSearchListBinding()
	local mf = addon.messageFrame
	if mf and mf:IsShown() and mf.GetCurrentConversationData and mf.CommitConversationMessages then
		local data = mf:GetCurrentConversationData()
		if data then
			mf:CommitConversationMessages(data)
		end
	end
end)

searchToggleBtn:SetScript("OnClick", function()
	if searchStrip:IsShown() then
		searchStrip:Hide()
	else
		searchStrip:Show()
		searchEdit:SetFocus()
	end
end)

searchToggleBtn:SetScript("OnEnter", function(self)
	WhisperPop_SetHeaderIconTooltipOwner(self)
	GameTooltip:ClearLines()
	GameTooltip:AddLine(L["search title"])
	for line in gmatch(L["search toggle tooltip"] or "", "[^\r\n]+") do
		GameTooltip:AddLine(line, 1, 1, 1, true)
	end
	GameTooltip:Show()
end)

searchToggleBtn:SetScript("OnLeave", function(self)
	GameTooltip:Hide()
end)

popFrame:HookScript("OnHide", function()
	searchStrip:Hide()
end)

configButton:SetScript("OnEnter", function(self)
	WhisperPop_SetHeaderIconTooltipOwner(self)
	GameTooltip:ClearLines()
	GameTooltip:AddLine(SETTINGS)
	GameTooltip:AddLine(L["settings tooltip 1"], 1, 1, 1, 1)
	GameTooltip:AddLine(L["settings tooltip 2"], 1, 1, 1, 1)
	GameTooltip:Show()
end)

configButton:SetScript("OnLeave", function(self)
	GameTooltip:Hide()
end)

configButton:SetScript("OnClick", function(self)
	if IsShiftKeyDown() then
		addon:PopupShowConfirm(L["clear all confirm"], addon.Clear, addon)
	else
		addon.optionFrame:Open()
	end
end)

local frame = UICreateInterfaceOptionPage("WhisperPopOptionFrame", L["title"], L["desc"])
addon.optionFrame = frame

local generalGroup = frame:CreateMultiSelectionGroup(L["general options"])
frame:AnchorToTopLeft(generalGroup, 0, -10)

local notifyCheck = generalGroup:AddButton(L["show notify button"], "notifyButton")

local notifyFlashCheck = generalGroup:AddButton(L["notify icon flash"], "notifyIconFlash")

local lockCheck = generalGroup:AddButton(L["lock button position"], "locked")
lockCheck:ClearAllPoints()
lockCheck:SetPoint("TOPLEFT", notifyFlashCheck, "BOTTOMLEFT", lockCheck:GetWidth(), 0)

local receiveCheck = generalGroup:AddButton(L["receive only"], "receiveOnly")
receiveCheck:ClearAllPoints()
receiveCheck:SetPoint("TOPLEFT", lockCheck, "BOTTOMLEFT", -lockCheck:GetWidth(), 0)

local clearUnreadOutgoingCheck = generalGroup:AddButton(L["clear unread on outgoing whisper"], "clearUnreadOnOutgoingWhisper")
clearUnreadOutgoingCheck.OnTooltipRequest = function(self, tooltip)
	tooltip:AddLine(L["clear unread on outgoing whisper"], 1, 0.82, 0, false)
	for line in gmatch(L["clear unread on outgoing whisper tooltip"] or "", "[^\r\n]+") do
		tooltip:AddLine(line, 1, 1, 1, true)
	end
end

local soundCheck = generalGroup:AddButton(L["sound notify"], "sound")

local realmCheck = generalGroup:AddButton(L["show realms"], "showRealm")

local foreignCheck = generalGroup:AddButton(L["foreign realms"], "foreignOnly")
foreignCheck:ClearAllPoints()
foreignCheck:SetPoint("TOPLEFT", realmCheck, "BOTTOMLEFT", foreignCheck:GetWidth(), 0)

local ignoreCheck = generalGroup:AddButton(L["ignore tag messages"], "ignoreTags")
ignoreCheck:ClearAllPoints()
ignoreCheck:SetPoint("TOPLEFT", foreignCheck, "BOTTOMLEFT", -foreignCheck:GetWidth(), 0)

generalGroup:AddButton(L["apply third-party filters"], "applyFilters")
local messageHoverLinksCheck = generalGroup:AddButton(L["message hover links"], "messageHoverLinks")

local saveDaysRowLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
saveDaysRowLabel:SetText(L["save history days label"])
saveDaysRowLabel:SetJustifyH("LEFT")
saveDaysRowLabel:SetPoint("TOPLEFT", messageHoverLinksCheck, "BOTTOMLEFT", 0, COMBO_Y_TIGHT)

local saveDaysEdit = frame:CreateEditBox("")
if saveDaysEdit.text then
	saveDaysEdit.text:Hide()
end
saveDaysEdit:SetNumeric(true)
saveDaysEdit:SetMaxLetters(4)
saveDaysEdit.autoCommit = true
saveDaysEdit:SetWidth(100)
saveDaysEdit:SetPoint("TOPLEFT", saveDaysRowLabel, "BOTTOMLEFT", 0, -6)

local saveDaysHint = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
saveDaysHint:SetText(L["save days hint"])
saveDaysHint:SetPoint("LEFT", saveDaysEdit, "RIGHT", 8, 0)
saveDaysHint:SetJustifyH("LEFT")

function saveDaysEdit:OnTextValidate(text)
	local s = strtrim(text or "")
	local n = tonumber(s)
	if not n then
		n = tonumber(addon.db.saveDays) or addon.DB_DEFAULTS.saveDays.default
	end
	n = max(1, min(9999, floor(n + 0.5)))
	return nil, tostring(n)
end

function saveDaysEdit:OnTextCommit(text)
	local n = tonumber(text) or addon.DB_DEFAULTS.saveDays.default
	addon.db.saveDays = max(1, min(9999, floor(n + 0.5)))
	addon:PruneExpiredHistory()
end

function saveDaysEdit:OnTextCancel()
	return tostring(addon.db.saveDays or addon.DB_DEFAULTS.saveDays.default)
end

function saveDaysEdit:OnInitShow()
	self:SetText(tostring(addon.db.saveDays or addon.DB_DEFAULTS.saveDays.default))
end

local deleteConfirmCheck = generalGroup:AddButton(L["confirm before delete conversation"], "deleteConfirm")
deleteConfirmCheck:ClearAllPoints()
deleteConfirmCheck:SetPoint("TOPLEFT", saveDaysEdit, "BOTTOMLEFT", -CheckIndentOffset(messageHoverLinksCheck), COMBO_Y_TIGHT)

local timeCheck = generalGroup:AddButton(L["timestamp"], "time")

function generalGroup:OnCheckInit(value)
	if addon.db[value] then
		return 1
	end
	return nil
end

function generalGroup:OnCheckChanged(value, checked)
	addon.db[value] = (checked == 1 or checked == true) and true or false
	addon:BroadcastOptionEvent(value, addon.db[value])

	if value == "sound" and checked then
		addon:PlaySound()
	end
end

addon:RegisterOptionCallback("notifyButton", function(value)
	if value then
		lockCheck:Enable()
		notifyFlashCheck:Enable()
	else
		lockCheck:Disable()
		notifyFlashCheck:Disable()
	end
end)

addon:RegisterOptionCallback("showRealm", function(value)
	if value then
		foreignCheck:Enable()
	else
		foreignCheck:Disable()
	end
end)

local soundCombo = frame:CreateComboBox()
soundCombo:SetPoint("TOPLEFT", soundCheck, "BOTTOMLEFT", CheckIndentOffset(soundCheck), 0)
soundCombo:SetWidth(200)
for i = 1, 5 do
	soundCombo:AddLine(L["notify sound preset " .. i], i)
end

local soundChannelLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
soundChannelLabel:SetText(L["sound output channel"])
soundChannelLabel:SetPoint("TOPLEFT", soundCombo, "BOTTOMLEFT", 0, -6)

local soundChannelCombo = frame:CreateComboBox()
soundChannelCombo:SetPoint("TOPLEFT", soundChannelLabel, "BOTTOMLEFT", CheckIndentOffset(soundCheck), -4)
soundChannelCombo:SetWidth(200)
for _, ch in ipairs(addon.SOUND_OUTPUT_CHANNELS) do
	soundChannelCombo:AddLine(L["sound channel_" .. ch], ch)
end

realmCheck:ClearAllPoints()
realmCheck:SetPoint("TOPLEFT", soundChannelCombo, "BOTTOMLEFT", -CheckIndentOffset(soundCheck), COMBO_Y_TIGHT)

function soundCombo:OnComboInit()
	return addon.db.soundPreset
end

function soundCombo:OnComboChanged(value)
	addon.db.soundPreset = value
	if addon.db.sound then
		addon:PlaySound()
	end
end

function soundChannelCombo:OnComboInit()
	return addon.db.soundChannel or "Master"
end

function soundChannelCombo:OnComboChanged(value)
	addon.db.soundChannel = value
	if addon.db.sound then
		addon:PlaySound()
	end
end

addon:RegisterOptionCallback("sound", function(value)
	if value then
		soundCombo:Enable()
		soundChannelCombo:Enable()
	else
		soundCombo:Disable()
		soundChannelCombo:Disable()
	end
end)

local timeCombo = frame:CreateComboBox()
timeCombo:SetPoint("TOPLEFT", timeCheck, "BOTTOMLEFT", CheckIndentOffset(timeCheck), 0)
timeCombo:SetWidth(200)

local timestamp = time()
for value, timeFormat in ipairs(addon.TimestampFormat) do
	timeCombo:AddLine(addon:FormatTimestamp(timeFormat, timestamp), value)
end

function timeCombo:OnComboInit()
	return addon.db.timeFormat
end

function timeCombo:OnComboChanged(value)
	addon.db.timeFormat = value
end

addon:RegisterOptionCallback("time", function(value)
	if value then
		timeCombo:Enable()
	else
		timeCombo:Disable()
	end
end)

addon:InitContentFontRegistry()

local fontStyleSectionLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
fontStyleSectionLabel:SetText(L["font style settings"])
fontStyleSectionLabel:SetPoint("TOPLEFT", timeCombo, "BOTTOMLEFT", -CheckIndentOffset(timeCheck), Y_GAP)

local fontStyleCombo = frame:CreateComboBox()
fontStyleCombo:SetPoint("TOPLEFT", fontStyleSectionLabel, "BOTTOMLEFT", CheckIndentOffset(timeCheck), COMBO_Y_TIGHT)
fontStyleCombo:SetWidth(200)
for _, name in ipairs(addon.CONTENT_FONT_KEYS) do
	fontStyleCombo:AddLine(L["fontobject_" .. name] or name, name)
end

function fontStyleCombo:OnComboInit()
	return addon.db.contentFontObject
end

function fontStyleCombo:OnComboChanged(value)
	addon.db.contentFontObject = value
	addon:ApplyContentFontStyle()
end

local function Slider_OnSliderInit(self)
	return addon.db[self.key]
end

local function Slider_OnSliderChanged(self, value)
	addon.db[self.key] = value
	addon:BroadcastOptionEvent(self.key, value)
end

local function CreateSlider(text, key, fmt)
	local config = addon.DB_DEFAULTS[key]
	local slider = frame:CreateSlider(text, config.min, config.max, config.step, fmt)
	slider.key = key
	slider.text:SetTextColor(1, 1, 1)
	slider.OnSliderInit = Slider_OnSliderInit
	slider.OnSliderChanged = Slider_OnSliderChanged
	return slider
end

local frameLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
frameLabel:SetText(L["frame settings"])
frameLabel:SetPoint("TOPLEFT", fontStyleCombo, "BOTTOMLEFT", -CheckIndentOffset(timeCheck), Y_GAP)

-- 分组标题下直接接带标签的下拉（同「声音通知」子项），避免再叠一行 GameFontNormalSmall 像第二个标题。
local frameStrataCombo = frame:CreateComboBox(L["frame strata label"])
frameStrataCombo:SetPoint("TOPLEFT", frameLabel, "BOTTOMLEFT", CheckIndentOffset(timeCheck), Y_GAP)
frameStrataCombo:SetWidth(200)
for _, st in ipairs(addon.FRAME_STRATA_CHOICES) do
	frameStrataCombo:AddLine(L["framestrata_" .. st] or st, st)
end

function frameStrataCombo:OnComboInit()
	return addon:GetFrameStrataSetting()
end

function frameStrataCombo:OnComboChanged(value)
	addon.db.frameStrata = value
	addon:BroadcastOptionEvent("frameStrata", value)
end

local notifySlider = CreateSlider(L["button scale"], "buttonScale", "%d%%")
	do
	local ind = CheckIndentOffset(timeCheck)
	notifySlider:SetPoint("TOPLEFT", frameStrataCombo, "BOTTOMLEFT", max(0, 8 - ind), Y_GAP)
end

local mainSlider = CreateSlider(L["list scale"], "listScale", "%d%%")
mainSlider:SetPoint("LEFT", notifySlider, "RIGHT", 24, 0)

local widthSlider = CreateSlider(L["list width"], "listWidth")
widthSlider:SetPoint("TOPLEFT", notifySlider, "BOTTOMLEFT", 0, SLIDER_Y_GAP)

local heightSlider = CreateSlider(L["list height"], "listHeight")
heightSlider:SetPoint("LEFT", widthSlider, "RIGHT", 24, 0)

local listWheelSlider = CreateSlider(L["list wheel lines"], "listWheelLines", "%d")
listWheelSlider:SetPoint("TOPLEFT", widthSlider, "BOTTOMLEFT", 0, SLIDER_Y_GAP)

local messageWheelSlider = CreateSlider(L["message wheel lines"], "messageWheelLines", "%d")
messageWheelSlider:SetPoint("LEFT", listWheelSlider, "RIGHT", 24, 0)

local function OnResetFrames()
	notifySlider:SetValue(100)
	mainSlider:SetValue(100)
	widthSlider:SetValue(addon.DB_DEFAULTS.listWidth.default)
	heightSlider:SetValue(addon.DB_DEFAULTS.listHeight.default)
	listWheelSlider:SetValue(addon.DB_DEFAULTS.listWheelLines.default)
	messageWheelSlider:SetValue(addon.DB_DEFAULTS.messageWheelLines.default)
	addon:BroadcastEvent("OnResetFrames")
end

local resetButton = frame:CreatePressButton(L["reset frames"])
resetButton:SetWidth(120)

function resetButton:OnClick()
	addon:PopupShowConfirm(L["reset frames confirm"], OnResetFrames)
end

local clearButton = frame:CreatePressButton(L["clear all"])
clearButton:SetWidth(120)

function clearButton:OnClick()
	addon:PopupShowConfirm(L["clear all confirm"], addon.Clear, addon)
end

local resetAllSettingsButton = frame:CreatePressButton(L["reset all settings"])
resetAllSettingsButton:SetWidth(160)

function resetAllSettingsButton:OnClick()
	addon:PopupShowConfirm(L["reset all settings confirm"], addon.ResetAllSettingsExceptHistory, addon)
end

----------------------------------------------------------------
-- Appearance (bottom of scroll area)
----------------------------------------------------------------
local appearanceSectionLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
appearanceSectionLabel:SetText(L["appearance settings"])

local uiStyleCombo = frame:CreateComboBox()
uiStyleCombo:SetWidth(240)
uiStyleCombo:AddLine(L["appearance style classic"], addon.UI_STYLE_CLASSIC)
uiStyleCombo:AddLine(L["appearance style borderless"], addon.UI_STYLE_BORDERLESS)

function uiStyleCombo:OnComboInit()
	return addon.db.uiStyle
end

local WhisperPop_UpdateAppearanceBorderControls

function uiStyleCombo:OnComboChanged(value)
	addon.db.uiStyle = value
	addon:BroadcastOptionEvent("uiStyle", value)
	if WhisperPop_UpdateAppearanceBorderControls then
		WhisperPop_UpdateAppearanceBorderControls()
	end
end

local function CreateAppearanceSwatchButton(parent)
	local sw = CreateFrame("Button", nil, parent)
	sw:SetSize(36, 20)
	sw:SetMotionScriptsWhileDisabled(true)
	local sb = sw:CreateTexture(nil, "BACKGROUND", nil, -2)
	sb:SetAllPoints()
	sb:SetColorTexture(0, 0, 0, 1)
	local col = sw:CreateTexture(nil, "ARTWORK")
	col:SetPoint("TOPLEFT", 1, -1)
	col:SetPoint("BOTTOMRIGHT", -1, 1)
	col:SetColorTexture(1, 1, 1, 1)
	sw._colorTex = col
	return sw
end

local appearanceMainLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
appearanceMainLabel:SetText(L["appearance color main"])
appearanceMainLabel:SetJustifyH("LEFT")
local appearanceMainSwatch = CreateAppearanceSwatchButton(frame)
local appearanceMainPick = frame:CreatePressButton(L["appearance pick"])
appearanceMainPick:SetWidth(100)
function appearanceMainPick:OnClick()
	addon:ShowAppearanceColorPicker("appearanceMain")
end

local appearancePreviewLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
appearancePreviewLabel:SetText(L["appearance color preview"])
appearancePreviewLabel:SetJustifyH("LEFT")
local appearancePreviewSwatch = CreateAppearanceSwatchButton(frame)
local appearancePreviewPick = frame:CreatePressButton(L["appearance pick"])
appearancePreviewPick:SetWidth(100)
function appearancePreviewPick:OnClick()
	addon:ShowAppearanceColorPicker("appearancePreview")
end

local appearanceBorderLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
appearanceBorderLabel:SetText(L["appearance color border"])
appearanceBorderLabel:SetJustifyH("LEFT")
appearanceBorderLabel:EnableMouse(true)
appearanceBorderLabel:SetScript("OnEnter", function(self)
	GameTooltip:SetOwner(self, "ANCHOR_LEFT")
	GameTooltip:ClearLines()
	GameTooltip:AddLine(L["appearance color border"], 1, 0.82, 0)
	GameTooltip:AddLine(L["appearance border classic only"], 1, 1, 1, true)
	GameTooltip:Show()
end)
appearanceBorderLabel:SetScript("OnLeave", function()
	GameTooltip:Hide()
end)
local appearanceBorderSwatch = CreateAppearanceSwatchButton(frame)
local appearanceBorderPick = frame:CreatePressButton(L["appearance pick"])
appearanceBorderPick:SetWidth(100)
function appearanceBorderPick:OnClick()
	addon:ShowAppearanceColorPicker("appearanceBorder")
end

function WhisperPop_UpdateAppearanceBorderControls()
	local on = not addon:IsUIStyleBorderless()
	if on then
		appearanceBorderPick:Enable()
	else
		appearanceBorderPick:Disable()
	end
end

local resetAppearanceButton = frame:CreatePressButton(L["appearance reset colors"])
resetAppearanceButton:SetWidth(160)
function resetAppearanceButton:OnClick()
	addon:PopupShowConfirm(L["appearance reset colors confirm"], addon.ResetAppearanceColors, addon)
end

local function WhisperPop_SyncAppearanceSwatches()
	local function paint(tex, key)
		if tex then
			tex:SetColorTexture(addon:GetAppearanceRGBA(key))
		end
	end
	paint(appearanceMainSwatch._colorTex, "appearanceMain")
	paint(appearancePreviewSwatch._colorTex, "appearancePreview")
	paint(appearanceBorderSwatch._colorTex, "appearanceBorder")
end

addon:RegisterEventCallback("OnAppearanceChanged", function()
	WhisperPop_SyncAppearanceSwatches()
end)

----------------------------------------------------------------
-- Scrollable body (title + description stay fixed; rest scrolls)
----------------------------------------------------------------
local scrollFrame = CreateFrame("ScrollFrame", frame:GetName().."ScrollBody", frame, "UIPanelScrollFrameTemplate")
local scrollChild = CreateFrame("Frame", frame:GetName().."ScrollBodyChild", scrollFrame)
scrollFrame:SetScrollChild(scrollChild)

if WhisperPop_ShowNgaFeedback() and L["nga copy btn"] and L["nga copy btn"] ~= "" then
	local function chatNgaUrlHint()
		local msg = L["nga url chat hint"]
		if DEFAULT_CHAT_FRAME and msg and msg ~= "" then
			DEFAULT_CHAT_FRAME:AddMessage(msg)
		end
	end

	local function ensureNgaUrlPopupDialog()
		if StaticPopupDialogs and StaticPopupDialogs["WHISPERPOP_NGA_URL"] then
			return
		end
		local closeLabel = L["nga url popup close"]
		if not closeLabel or closeLabel == "" then
			closeLabel = (type(CLOSE) == "string" and CLOSE ~= "") and CLOSE or "OK"
		end
		StaticPopupDialogs["WHISPERPOP_NGA_URL"] = {
			text = L["nga url popup text"] or "",
			button1 = closeLabel,
			hasEditBox = 1,
			editBoxWidth = 380,
			maxLetters = 512,
			OnShow = function(self, data)
				local u = (type(data) == "string" and data ~= "") and data or NGA_FEEDBACK_URL
				local eb = self.EditBox
				if eb and eb.SetText then
					eb:SetText(u)
					if eb.HighlightText then
						pcall(eb.HighlightText, eb)
					end
					if eb.SetFocus then
						pcall(eb.SetFocus, eb)
					end
				end
			end,
			OnAccept = function(self)
				if self and self.Hide then
					self:Hide()
				end
			end,
			EditBoxOnEnterPressed = function(self)
				self:GetParent():Hide()
			end,
			EditBoxOnEscapePressed = function(self)
				self:GetParent():Hide()
			end,
			timeout = 0,
			whileDead = 1,
			hideOnEscape = 1,
			preferredIndex = 3,
		}
	end

	ngaFeedbackLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	ngaFeedbackLabel:SetJustifyH("LEFT")
	ngaFeedbackLabel:SetJustifyV("TOP")
	ngaFeedbackLabel:SetWordWrap(true)
	if ngaFeedbackLabel.SetSpacing then
		ngaFeedbackLabel:SetSpacing(2)
	end
	ngaFeedbackLabel:SetText(L["desc nga feedback"] or "")

	ngaCopyBtn = frame:CreatePressButton(L["nga copy btn"])
	ngaCopyBtn:SetParent(scrollChild)
	ngaCopyBtn:SetWidth(140)
	if L["nga copy tip"] and L["nga copy tip"] ~= "" then
		ngaCopyBtn.tooltipText = L["nga copy tip"]
	end
	function ngaCopyBtn:OnClick()
		if StaticPopup_Show then
			ensureNgaUrlPopupDialog()
			StaticPopup_Show("WHISPERPOP_NGA_URL", nil, nil, NGA_FEEDBACK_URL)
		end
		chatNgaUrlHint()
	end
end

local function WhisperPopOption_ViewportHeight()
	local uh = UIParent and UIParent.GetHeight and UIParent:GetHeight() or 800
	return max(260, min(520, floor(uh * 0.52)))
end

local function WhisperPopOption_ReanchorGeneralGroup()
	generalGroup:ClearAllPoints()
	generalGroup:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -10)
end

local function WhisperPopOption_ReparentIntoScroll()
	local child = scrollChild
	generalGroup:SetParent(child)
	for i = 1, #(generalGroup.buttons or {}) do
		generalGroup.buttons[i]:SetParent(child)
	end
	timeCombo:SetParent(child)
	soundCombo:SetParent(child)
	soundChannelLabel:SetParent(child)
	soundChannelCombo:SetParent(child)
	saveDaysRowLabel:SetParent(child)
	saveDaysEdit:SetParent(child)
	saveDaysHint:SetParent(child)
	fontStyleSectionLabel:SetParent(child)
	fontStyleCombo:SetParent(child)
	frameLabel:SetParent(child)
	frameStrataCombo:SetParent(child)
	notifySlider:SetParent(child)
	mainSlider:SetParent(child)
	widthSlider:SetParent(child)
	heightSlider:SetParent(child)
	listWheelSlider:SetParent(child)
	messageWheelSlider:SetParent(child)
	resetButton:SetParent(child)
	clearButton:SetParent(child)
	resetAllSettingsButton:SetParent(child)
	appearanceSectionLabel:SetParent(child)
	uiStyleCombo:SetParent(child)
	appearanceMainLabel:SetParent(child)
	appearanceMainSwatch:SetParent(child)
	appearanceMainPick:SetParent(child)
	appearancePreviewLabel:SetParent(child)
	appearancePreviewSwatch:SetParent(child)
	appearancePreviewPick:SetParent(child)
	appearanceBorderLabel:SetParent(child)
	appearanceBorderSwatch:SetParent(child)
	appearanceBorderPick:SetParent(child)
	resetAppearanceButton:SetParent(child)
	if ngaFeedbackLabel then
		ngaFeedbackLabel:SetParent(child)
	end
	if ngaCopyBtn then
		ngaCopyBtn:SetParent(child)
	end
	WhisperPopOption_ReanchorGeneralGroup()
end

local function WhisperPopOption_UpdateScrollMetrics()
	scrollFrame:ClearAllPoints()
	-- 左缘与页头说明同列（InterfaceOptionPage 默认 x=16），避免滚动视口偏右裁切控件左缘。
	scrollFrame:SetPoint("TOPLEFT", frame.subTitle, "BOTTOMLEFT", 0, -8)
	scrollFrame:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -32, -8)
	scrollFrame:SetHeight(WhisperPopOption_ViewportHeight())

	local sw = scrollFrame:GetWidth()
	if not sw or sw < 80 then
		sw = (frame:GetWidth() or 520) - 48
	end
	scrollChild:SetWidth(max(200, sw - 24))

	resetButton:ClearAllPoints()
	resetButton:SetPoint("TOPLEFT", listWheelSlider, "BOTTOMLEFT", 0, Y_GAP)
	clearButton:ClearAllPoints()
	clearButton:SetPoint("LEFT", resetButton, "RIGHT", 8, 0)
	resetAllSettingsButton:ClearAllPoints()
	resetAllSettingsButton:SetPoint("TOPLEFT", resetButton, "BOTTOMLEFT", 0, Y_GAP)

	-- Align with resetButton / slider column, not clearButton (which sits to the right).
	appearanceSectionLabel:ClearAllPoints()
	appearanceSectionLabel:SetPoint("TOPLEFT", resetAllSettingsButton, "BOTTOMLEFT", 0, Y_GAP)
	uiStyleCombo:ClearAllPoints()
	uiStyleCombo:SetPoint("TOPLEFT", appearanceSectionLabel, "BOTTOMLEFT", CheckIndentOffset(messageHoverLinksCheck), COMBO_Y_TIGHT)

	appearanceMainLabel:ClearAllPoints()
	appearanceMainLabel:SetPoint("TOPLEFT", uiStyleCombo, "BOTTOMLEFT", -CheckIndentOffset(messageHoverLinksCheck), Y_GAP)
	appearanceMainSwatch:ClearAllPoints()
	appearanceMainSwatch:SetPoint("TOPLEFT", appearanceMainLabel, "BOTTOMLEFT", 0, -6)
	appearanceMainPick:ClearAllPoints()
	appearanceMainPick:SetPoint("LEFT", appearanceMainSwatch, "RIGHT", 8, 0)

	appearancePreviewLabel:ClearAllPoints()
	appearancePreviewLabel:SetPoint("TOPLEFT", appearanceMainSwatch, "BOTTOMLEFT", 0, -10)
	appearancePreviewSwatch:ClearAllPoints()
	appearancePreviewSwatch:SetPoint("TOPLEFT", appearancePreviewLabel, "BOTTOMLEFT", 0, -6)
	appearancePreviewPick:ClearAllPoints()
	appearancePreviewPick:SetPoint("LEFT", appearancePreviewSwatch, "RIGHT", 8, 0)

	appearanceBorderLabel:ClearAllPoints()
	appearanceBorderLabel:SetPoint("TOPLEFT", appearancePreviewSwatch, "BOTTOMLEFT", 0, -10)
	appearanceBorderSwatch:ClearAllPoints()
	appearanceBorderSwatch:SetPoint("TOPLEFT", appearanceBorderLabel, "BOTTOMLEFT", 0, -6)
	appearanceBorderPick:ClearAllPoints()
	appearanceBorderPick:SetPoint("LEFT", appearanceBorderSwatch, "RIGHT", 8, 0)

	resetAppearanceButton:ClearAllPoints()
	resetAppearanceButton:SetPoint("TOPLEFT", appearanceBorderSwatch, "BOTTOMLEFT", 0, Y_GAP)

	local scrollBottom = resetAppearanceButton
	if ngaFeedbackLabel and ngaCopyBtn and WhisperPop_ShowNgaFeedback() then
		local wrapW = max(200, (scrollChild:GetWidth() or 400) - 32)
		ngaFeedbackLabel:SetWidth(wrapW)
		ngaFeedbackLabel:ClearAllPoints()
		ngaFeedbackLabel:SetPoint("TOPLEFT", resetAppearanceButton, "BOTTOMLEFT", 0, NGA_BLOCK_Y_GAP)
		ngaFeedbackLabel:Show()
		ngaCopyBtn:ClearAllPoints()
		ngaCopyBtn:SetPoint("TOPLEFT", ngaFeedbackLabel, "BOTTOMLEFT", 0, -14)
		ngaCopyBtn:Show()
		scrollBottom = ngaCopyBtn
	else
		if ngaFeedbackLabel then
			ngaFeedbackLabel:Hide()
		end
		if ngaCopyBtn then
			ngaCopyBtn:Hide()
		end
	end

	WhisperPop_UpdateAppearanceBorderControls()

	local pad = 28
	local span = (generalGroup:GetTop() or 0) - (scrollBottom:GetBottom() or resetAppearanceButton:GetBottom() or resetAllSettingsButton:GetBottom() or clearButton:GetBottom() or 0) + pad
	if span ~= span or span < 1 then
		span = scrollFrame:GetHeight()
	end
	if span < scrollFrame:GetHeight() then
		span = scrollFrame:GetHeight()
	end
	scrollChild:SetHeight(span)
end

WhisperPopOption_ReparentIntoScroll()

frame:HookScript("OnShow", function()
	if saveDaysEdit and saveDaysEdit.SetText then
		saveDaysEdit:SetText(tostring(addon.db.saveDays or addon.DB_DEFAULTS.saveDays.default))
	end
	if saveDaysHint then
		local c = RED_FONT_COLOR
		if c then
			saveDaysHint:SetTextColor(c.r, c.g, c.b)
		else
			saveDaysHint:SetTextColor(1, 0.2, 0.2)
		end
	end
	WhisperPop_SyncAppearanceSwatches()
	WhisperPop_UpdateAppearanceBorderControls()
	WhisperPopOption_UpdateScrollMetrics()
	if C_Timer and C_Timer.After then
		C_Timer.After(0, WhisperPopOption_UpdateScrollMetrics)
	end
end)
frame:HookScript("OnSizeChanged", WhisperPopOption_UpdateScrollMetrics)

local function WhisperPop_RefreshOptionPageControlsFromDB()
	local function runOnShow(w)
		if w and type(w.OnShow) == "function" then
			pcall(w.OnShow, w)
		end
	end
	if generalGroup and generalGroup.buttons then
		for _, btn in ipairs(generalGroup.buttons) do
			runOnShow(btn)
		end
	end
	runOnShow(soundCombo)
	runOnShow(soundChannelCombo)
	runOnShow(timeCombo)
	runOnShow(fontStyleCombo)
	runOnShow(frameStrataCombo)
	runOnShow(notifySlider)
	runOnShow(mainSlider)
	runOnShow(widthSlider)
	runOnShow(heightSlider)
	runOnShow(listWheelSlider)
	runOnShow(messageWheelSlider)
	runOnShow(uiStyleCombo)
	if saveDaysEdit and saveDaysEdit.SetText then
		saveDaysEdit:SetText(tostring(addon.db.saveDays or addon.DB_DEFAULTS.saveDays.default))
	end
	WhisperPop_SyncAppearanceSwatches()
	WhisperPop_UpdateAppearanceBorderControls()
end

addon:RegisterEventCallback("OnSettingsResetExceptHistory", function()
	if addon.optionFrame and addon.optionFrame:IsShown() then
		WhisperPop_RefreshOptionPageControlsFromDB()
		WhisperPopOption_UpdateScrollMetrics()
	end
end)