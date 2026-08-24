------------------------------------------------------------
-- Main.lua  (Optimized for WoW 12.1)
--
-- Changes:
-- 1. Fixed fake_icon2 __index leak (no longer writes keys)
-- 2. Replaced GetUnitAuras with GetAuraDataByIndex in FindAura
-- 3. Removed unnecessary pcall overhead
------------------------------------------------------------

local ICON_SIZE = 45
local floor = floor
local GetTime = GetTime
local type = type
local GameTooltip = GameTooltip
local pairs = pairs
local ipairs = ipairs
local strtrim = strtrim
local strupper = strupper
local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local tinsert = tinsert
local C_UnitAuras = C_UnitAuras

local _, addon = ...
local L = addon.L
local templates = {}
addon.templates = templates

local function Button_Call(self, method, ...)
	local func = self[method]
	if type(func) == "function" then
		return func(self, ...)
	end
end

local function Button_UpdateText(self)
	local font, expires, duration = self.text, self.expires, self.duration
	if not duration or duration < 1 then
		return
	end

	local timeLeft
	if expires then
		timeLeft = floor(expires - GetTime() + 0.5)
		if timeLeft <= 0 then
			timeLeft = nil
		end
	end

	if font.timeLeft ~= timeLeft then
		font.timeLeft = timeLeft
		if timeLeft then
			local r, g, b = addon:GetGradientColor(timeLeft, duration)
			font:SetTextColor(r, g, b)
			font:SetFormattedText("%d:%02d", timeLeft / 60, timeLeft % 60)
		else
			font:SetText()
		end
	end
end

local function Button_InvokeMethod(self, method, ...)
	local hook = self.prehookList[method]
	if hook then
		for func in next, hook do
			pcall(func, self, ...)
		end
	end
	Button_Call(self, method, ...)
end

local function Button_OnTooltipTitle(self, tooltip, spell1, spell2)
	local title
	if spell1 and spell2 then
		title = spell1.." / "..spell2
	elseif spell1 or spell2 then
		title = spell1 or spell2
	else
		title = self.title
	end
	tooltip:AddLine(title)
end

local function Button_OnTooltipLeftText(self, tooltip, spell)
	if spell then
		tooltip:AddLine(L["left click"]..(spell or self.title), 1, 1, 1, 1)
	end
end

local function Button_UpdateTooltip(self)
	if not GameTooltip:IsOwned(self) then
		return
	end

	GameTooltip:ClearLines()
	local spell1, spell2 = self.spell, self.spell2

	Button_Call(self, "OnTooltipTitle", GameTooltip, spell1, spell2)
	Button_Call(self, "OnTooltipText", GameTooltip, spell1, spell2)

	if not addon:LoadData("db", "simpletip") then
		Button_Call(self, "OnTooltipLeftText", GameTooltip, spell1, spell2)
		if self:HasFlag("DUAL") then
			Button_Call(self, "OnTooltipRightText", GameTooltip, spell1, spell2)
		end
		Button_Call(self, "OnTooltipScrollText", GameTooltip, spell1, spell2)
	end

	Button_Call(self, "OnTooltipBottomText", GameTooltip, spell1, spell2)
	GameTooltip:Show()
end

local function Button_UpdateStatus(self)
	self.icon.border:Show()
	self.icon.icon:SetVertexColor(1,1,1)
	if self.status == "Y" then
		self.icon.border:SetVertexColor(1, 1, 0)
	elseif self.status == "G" then
		self.icon.border:SetVertexColor(0, .9, 0)
	elseif self.status == "R" then
		self.icon.icon:SetVertexColor(1, 0.3, 0.1)
		self.icon.border:Hide()
	else
		self.icon.border:Hide()
	end
end

local function Button_OnDragStart(self)
	if not addon:LoadData("chardb", "lock") then
		addon.frame:StartMoving()
	end
end

local function Button_OnDragStop(self)
	addon.frame:StopMovingOrSizing()
end

local function Button_OnEnter(self)
	GameTooltip:SetOwner(self, "ANCHOR_LEFT")
	self:UpdateTooltip()
end

local function Button_OnLeave(self)
	GameTooltip:Hide()
end

local function Button_UpdateTimer(self)
	self.status, self.expires = Button_Call(self, "OnUpdateTimer", self.spell, self.spell2)
	self:UpdateStatus()
	self:UpdateText()
end

local function Button_OnUpdateTimer(self, spell)
	local expires = addon:GetUnitBuffTimer("player", spell)
	if not expires and self.auraMap and self.auraMap[spell] then
		expires = addon:GetUnitBuffTimer("player", self.auraMap[spell])
	end
	return expires and "G" or "NONE", expires
end

local function Button_OnEvent(self, event, ...)
	local func = self[event]
	if func then
		func(self, ...)
	end
end

local function Button_OnUpdate(self, elapsed)
	self.updateElapsed = (self.updateElapsed or 0) + elapsed
	if self.updateElapsed > 0.5 then
		self.updateElapsed = 0
		Button_UpdateText(self)
		Button_Call(self, "OnTick")
	end
end

local function GetSpellData(self, data, ...)
	if type(data) == "number" then
		local id = data
		data = self.spellCache[id]
		if not data then
			data = addon:BuildSpellList(nil, id, ...)
			self.spellCache[id] = data
		end
	end
	return type(data) == "table" and data or nil
end

local function Button_SetSpell(self, data, ...)
	data = GetSpellData(self, data, ...)
	self.spell = data and data.spell
	self.conflicts = data and data.conflicts
	self.conflictsById = data and data.conflictsById
	self.icon:SetSpell(data)
	self:UpdateTooltip()
	self:UpdateTimer()
end

local function Button_SetSpell2(self, data, ...)
	data = GetSpellData(self, data, ...)
	self.spell2 = data and data.spell
	self.icon2:SetSpell(data)
	self:UpdateTooltip()
	self:UpdateTimer()
end

local function Button_UpdateSpell(self)
	Button_SetSpell(self, self.icon.data)
end

local function Button_UpdateSpell2(self)
	Button_SetSpell2(self, self.icon2.data)
end

local function Button_IsConflict(self, spell)
	return self.conflicts and self.conflicts[spell]
end

local function Button_HasFlag(self, flag)
	return self.flagList[flag]
end

local function Button_CompareAura(self, aura)
	return aura and (aura == self.auraName or aura == self.spell or Button_IsConflict(self, aura))
end

-- MEMORY OPTIMIZED: Uses GetAuraDataByIndex instead of GetUnitAuras
local function Button_FindAura(self, unit, mine)
	if not unit then return end

	local aura = self.auraName or self.spell
	local expires, count = addon:GetUnitBuffTimer(unit, aura, mine)
	if expires then
		return expires, count
	end

	local conflictsById = self.conflictsById
	if not conflictsById then return end

	for i = 1, 40 do
		local auraData = C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL")
		if not auraData then break end
		if conflictsById[auraData.spellId] then
			if not mine or auraData.sourceUnit == "player" then
				return auraData.expirationTime or 0, auraData.applications or 1, auraData.spellId, auraData.icon
			end
		end
	end
end

local function Button_OnEnable(self)
	self:SetAttribute("disabled", nil)
	if type(self.OnValidate) ~= "function" or self:OnValidate() then
		self:Show()
	end
	Button_InvokeMethod(self, "OnEnable", InCombatLockdown())
end

local function Button_OnDisable(self)
	self:SetAttribute("disabled", 1)
	self:UnregisterAllEvents()
	self:Hide()
	Button_InvokeMethod(self, "OnDisable", InCombatLockdown())
end

local function Button_HookMethod(self, method, func)
	if type(method) == "string" and type(func) == "function" then
		local hook = self.prehookList[method]
		if not hook then
			hook = {}
			self.prehookList[method] = hook
		end
		hook[func] = true
	end
end

local function Button_SetConflictIcon(self, icon)
	self.icon2:SetIcon(icon)
	if icon then
		self.icon2:SetAlpha(0.4)
	end
end

local function Button_UpdateButton_163(self)
	local growth = U1GetCfgValue and (U1GetCfgValue('LiteBuff', 'growh') and 'RIGHT' or 'DOWN') or 'RIGHT'
	local iconsize = 45
	local gap = U1GetCfgValue and U1GetCfgValue('LiteBuff', 'gap') or 6

	self:SetAttribute('x-growth', growth)
	self:SetAttribute('x-gap', gap)

	self.icon:SetSize(iconsize, iconsize)
	self.icon.border:SetSize(iconsize * 62 / 36, iconsize * 62 / 36)
	self.icon.icon:SetSize(iconsize, iconsize)
	self:SetSize(iconsize, iconsize)

	return self:Execute(string.format([[ self:RunAttribute(%q) ]], self:IsShown() and '_onshow' or '_onhide'))
end

local noop = function() end
-- FIXED: __index no longer writes keys into the table, preventing infinite growth
local fake_icon2 = setmetatable({}, {
	__index = function(t, i)
		return noop
	end,
})

local lastButton
function templates.CreateActionButton(key, category, title, duration, ...)
	if type(key) ~= "string" or addon:GetButton(key) then
		return
	end

	if type(category) == "number" then
		local spell = C_Spell.GetSpellInfo(category)
		category = spell and spell.name
	end

	if type(category) ~= "string" then
		return
	end

	if type(title) ~= "string" then
		title = category
	end

	local button = CreateFrame("Button", addon.frame:GetName().."Button"..key, addon.frame,
		"SecureActionButtonTemplate,SecureHandlerMouseWheelTemplate,SecureHandlerStateTemplate,SecureHandlerShowHideTemplate,SecureHandlerMouseUpDownTemplate")
	button:RegisterForClicks("AnyDown", "AnyUp")
	button.key, button.category, button.title = key, category, title
	button.duration = type(duration) == "number" and duration > 0 and duration or nil
	button.triggerdList = {}
	button.prehookList = {}
	button.spellCache = {}

	if lastButton then
		button:SetFrameRef("anchorButton", lastButton)
		lastButton:SetFrameRef('banchorButton', button)
	end
	lastButton = button

	button:SetSize(ICON_SIZE, ICON_SIZE)
	button:SetScale(1)

	button:RegisterForDrag("LeftButton")
	button:SetScript("OnDragStart", Button_OnDragStart)
	button:SetScript("OnDragStop", Button_OnDragStop)

	button.icon = templates.CreateIconFrame(button)
	button.icon:SetPoint("LEFT", 4, 0)

	button.icon2 = fake_icon2

	button.text = button.icon:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmallRight")
	button.text:SetPoint('TOPLEFT', 0, -1)
	button.text:SetJustifyH'CENTER'
	button.text:SetFont(STANDARD_TEXT_FONT, 12, 'OUTLINE')

	button:SetScript("OnUpdate", Button_OnUpdate)
	button:SetScript("OnEnable", Button_OnEnable)
	button:SetScript("OnDisable", Button_OnDisable)
	button:SetScript("OnEvent", Button_OnEvent)
	button:SetScript("OnEnter", Button_OnEnter)
	button:SetScript("OnLeave", Button_OnLeave)
	button:HookScript("OnShow", Button_UpdateTimer)

	button:SetAttribute("_onshow", [[
		local anchor = self:GetFrameRef("anchorButton")
		local growth = self:GetAttribute("x-growth")
		local gap = self:GetAttribute("x-gap")
		self:ClearAllPoints()

		local has_anchor = false
		if anchor then
			while anchor and not anchor:IsShown() do
				anchor = anchor:GetFrameRef'anchorButton'
			end
			if anchor and anchor:IsShown() then
				if growth == 'RIGHT' then
					self:SetPoint('LEFT', anchor, 'RIGHT', gap, 0)
				else
					self:SetPoint("TOP", anchor, "BOTTOM", 0, -gap)
				end
				has_anchor = true
			end
		end

		if not has_anchor then
			self:SetPoint('CENTER', self:GetParent())
		end

		local b = self:GetFrameRef('banchorButton')
		while b and not b:IsShown() do
			b = b:GetFrameRef'banchorButton'
		end
		if b and b:IsShown() then
			b:ClearAllPoints()
			if growth == 'RIGHT' then
				b:SetPoint('LEFT', self, 'RIGHT', gap, 0)
			else
				b:SetPoint('TOP', self, 'BOTTOM', 0, -gap)
			end
		end
	]])

	button:SetAttribute("_onhide", [[
		local growth = self:GetAttribute'x-growth'
		local gap = self:GetAttribute'x-gap'
		local anchor = self:GetFrameRef("anchorButton")
		while anchor and not anchor:IsShown() do
			anchor = anchor:GetFrameRef'anchorButton'
		end

		local b = self:GetFrameRef'banchorButton'
		while b and not b:IsShown() do
			b = b:GetFrameRef'banchorButton'
		end

		if anchor and b then
			b:ClearAllPoints()
			if growth == 'RIGHT' then
				b:SetPoint('LEFT', anchor, 'RIGHT', gap, 0)
			else
				b:SetPoint('TOP', anchor, 'BOTTOM', 0, -gap)
			end
		elseif b then
			b:ClearAllPoints()
			b:SetPoint('CENTER', self:GetParent())
		end
	]])

	button.Call = Button_Call
	button.HookMethod = Button_HookMethod
	button.InvokeMethod = Button_InvokeMethod
	button.HasFlag = Button_HasFlag
	button.SetSpell = Button_SetSpell
	button.SetSpell2 = Button_SetSpell2
	button.UpdateSpell = Button_UpdateSpell
	button.SetConflictIcon = Button_SetConflictIcon
	button.UpdateSpell2 = Button_UpdateSpell2
	button.UpdateTimer = Button_UpdateTimer
	button.OnUpdateTimer = Button_OnUpdateTimer
	button.OnPlayerPet = Button_UpdateTimer
	button.IsConflict = Button_IsConflict
	button.CompareAura = Button_CompareAura
	button.FindAura = Button_FindAura
	button.UpdateStatus = Button_UpdateStatus
	button.UpdateText = Button_UpdateText
	button.UpdateTooltip = Button_UpdateTooltip
	button.OnTooltipTitle = Button_OnTooltipTitle
	button.OnTooltipLeftText = Button_OnTooltipLeftText
	button.OnEnterWorld = Button_UpdateTimer
	button.SetScrollable = templates.SetButtonScrollable
	button.SetFlyProtect = templates.SetButtonFlyProtect
	button.RequireSpell = templates.ButtonRequireSpell
	button.RequireItem = templates.ButtonRequireItem
	button.RequireGroup = templates.ButtonRequireGroup
	button.RequireGroupSpell = templates.ButtonRequireGroupSpell

	button.flagList = templates.ParseFlags(...)
	for flag in pairs(button.flagList) do
		local data = templates.GetRegisteredTemplate(flag)
		if data then
			data.func(button)
		end
	end

	button.__163_UpdateButton = Button_UpdateButton_163
	button:__163_UpdateButton()

	return button
end

function addon:RefreshLiteBuffs()
	if InCombatLockdown() then
		U1Message("戰鬥中不能應用此設置, 請脫戰後重試")
		return
	end
	for _, button in next, self.actionButtons do
		button:__163_UpdateButton()
	end
end

----------------------------------------------
-- Flag handlers
----------------------------------------------

local function NormalizeFlag(flag)
	if type(flag) == "string" then
		flag = strtrim(strupper(flag))
		if flag ~= "" then
			return flag
		end
	end
end

function templates.ParseFlags(...)
	local flagList = {}
	for i = 1, select("#", ...) do
		local flag = NormalizeFlag(select(i, ...))
		local data = templates.GetRegisteredTemplate(flag)
		if data then
			flagList[flag] = 1
			for other in pairs(data.others) do
				flagList[other] = 1
			end
		end
	end
	return flagList
end

local regTemplates = {}

function templates.RegisterTemplate(flag, func, ...)
	if type(flag) == "string" and type(func) == "function" then
		flag = NormalizeFlag(flag)
		if not flag then return end

		local data = { func = func, others = {} }
		regTemplates[flag] = data

		for i = 1, select("#", ...) do
			local other = NormalizeFlag(select(i, ...))
			if other then
				data.others[other] = 1
			end
		end
	end
end

function templates.GetRegisteredTemplate(flag)
	return regTemplates[NormalizeFlag(flag)]
end

----------------------------------------------
-- Embeds simple templates
----------------------------------------------

local function Button_OnTooltipRightText(self, tooltip, _, spell)
	if spell then
		tooltip:AddLine(L["right click"]..spell, 1, 1, 1, 1)
	end
end

templates.RegisterTemplate("DUAL", function(button)
	button:RegisterForClicks("AnyUp", "AnyDown")
	button.OnTooltipRightText = Button_OnTooltipRightText
end)

templates.RegisterTemplate("PLAYER_AURA", function(button)
	button.OnPlayerAura = Button_UpdateTimer
end)