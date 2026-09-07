------------------------------------------------------------
-- GroupAura.lua  (Optimized for WoW 12.1)
--
-- Changes:
-- 1. Store unit IDs instead of formatted colored names in missings table
--    (names are formatted only when rendering tooltip, reducing string alloc)
------------------------------------------------------------

local UnitExists = UnitExists
local UnitIsConnected = UnitIsConnected
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitIsVisible = UnitIsVisible
local type = type
local pairs = pairs
local wipe = wipe
local format = format
local GetTime = GetTime

local _, addon = ...
local templates = addon.templates
local L = addon.L

local function Button_VerifyUnit(unit)
	if unit == "player" then
		return 1
	end
	return unit and UnitExists(unit) and UnitIsConnected(unit) and not UnitIsDeadOrGhost(unit) and UnitIsVisible(unit)
end

-- OPTIMIZED: Store raw unit IDs, defer name formatting to tooltip
local function Button_GetBuffStatus(self, unit)
	if not Button_VerifyUnit(unit) or (type(self.OnGroupVerifyUnit) == "function" and not self:OnGroupVerifyUnit(unit)) then
		return
	end

	local cache = self.cache
	local expires, count, conflict, conflictIcon = self:FindAura(unit)
	if conflictIcon then
		cache.conflict = conflictIcon
	end

	if expires then
		cache.has = 1
		if not cache.expires or cache.expires > expires then
			cache.expires = expires
		end
	else
		cache.miss = 1
		self.missings[unit] = true  -- Store unit ID, not formatted string
	end
end

local function Button_OnUpdateTimer(self)
	local cache = self.cache
	wipe(cache)
	wipe(self.missings)

	Button_GetBuffStatus(self, "player")
	local key, count = addon:IsGrouped()
	if key then
		for i = 1, count do
			Button_GetBuffStatus(self, key..i)
		end
	end

	self:SetConflictIcon(cache.conflict)

	local status
	if cache.has and cache.miss then
		status = "Y"
	elseif cache.has then
		status = nil
	else
		status = "R"
	end

	return status, cache.expires
end

-- Names are formatted only here, on-demand
local function Button_AddGroupTooltip(self, tooltip)
	if not addon:IsGrouped() then
		return
	end

	local status = self.status
	if status == "Y" then
		local count = 0
		local list
		for unit in pairs(self.missings) do
			count = count + 1
			local name = addon:GetColoredUnitName(unit) or UNKNOWNOBJECT
			if list then
				list = list.." "..name
			else
				list = name
			end
		end
		tooltip:AddLine(format(L["misses"], count)..(list or ""), 1, 0, 0, 1)
	elseif status == "R" then
		tooltip:AddLine(L["none has"], 1, 0, 0, 1)
	else
		tooltip:AddLine(L["all have"], 0, 1, 0, 1)
	end
end

local function Button_OnTooltipLeftText(self, tooltip)
	tooltip:AddLine(L["left click"]..L["cast at player"], 1, 1, 1, 1)
end

local function Button_OnTooltipRightText(self, tooltip)
	tooltip:AddLine(L["right click"]..L["cast at target"], 1, 1, 1, 1)
end

templates.RegisterTemplate("GROUP_AURA", function(button)
	button.missings = {}
	button.cache = {}
	button.AddGroupTooltip = Button_AddGroupTooltip
	button.OnTooltipText = Button_AddGroupTooltip
	button.OnUpdateTimer = Button_OnUpdateTimer
	-- 队友光环变化时也刷新（死亡/补buff后能及时更新）
	-- 40人团里UNIT_AURA很频繁，这里节流到0.5秒一次，避免每次事件都全团扫描
	button.OnPlayerAura = function(self)
		local now = GetTime()
		if not self._nextGroupAuraRefresh or now >= self._nextGroupAuraRefresh then
			self._nextGroupAuraRefresh = now + 0.5
			self:UpdateTimer()
		end
	end

	-- 兜底定时刷新：战斗中可能因secret/事件缺失导致状态不更新，
	-- 出本/脱战后靠这个2秒一次的周期刷新自动纠正
	button.OnTick = function(self)
		if self:GetAttribute("disabled") then return end
		local now = GetTime()
		if not self._nextGroupAuraTick or now >= self._nextGroupAuraTick then
			self._nextGroupAuraTick = now + 2
			self:UpdateTimer()
		end
	end

	if button:HasFlag("DUAL") then
		button:SetAttribute("unit1", "player")
		button.OnTooltipLeftText = Button_OnTooltipLeftText
		button.OnTooltipRightText = Button_OnTooltipRightText
	end
end, "GROUP")