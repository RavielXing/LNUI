------------------------------------------------------------
-- Core.lua  (Optimized for WoW 12.1 - Memory reduction)
--
-- Changes:
-- 1. Removed pcall overhead for C_Spell.GetSpellInfo (safe API)
-- 2. Replaced C_UnitAuras.GetUnitAuras (large table alloc) with 
--    C_UnitAuras.GetAuraDataByIndex (iterative, zero-allocation)
-- 3. Added spellNameToIdCache hard limit (500) to prevent leak
------------------------------------------------------------

local type = type
local tinsert = tinsert
local select = select
local pairs = pairs
local ipairs = ipairs
local format = format
local tostring = tostring
local wipe = wipe
local GetNumShapeshiftForms = GetNumShapeshiftForms
local GetShapeshiftFormInfo = GetShapeshiftFormInfo
local UnitName = UnitName
local UnitClass = UnitClass
local GetActiveSpecGroup = GetActiveSpecGroup
local GetRealmName = GetRealmName
local GetNumGroupMembers = GetNumGroupMembers
local IsInRaid = IsInRaid
local RAID_CLASS_COLORS = RAID_CLASS_COLORS
local InCombatLockdown = InCombatLockdown
local C_Spell = C_Spell
local C_UnitAuras = C_UnitAuras

-- 12.1 secret值统一处理：secret值当nil/默认值，避免把secret数据泄漏给上层逻辑
local function SafeAuraValue(v, default)
	if issecretvalue and issecretvalue(v) then
		return default
	end
	return v ~= nil and v or default
end

local addonName, addon = ...
_G["LiteBuff"] = addon
addon.version = "2.1-opt"

local actionButtons = {}
local groupLastDead = {}
local InitCallbacks = {}
addon.actionButtons = actionButtons

-- Cache for spell name -> spell ID conversion
local spellNameToIdCache = {}
addon._spellNameToIdCache = spellNameToIdCache
local CACHE_MAX_SIZE = 500

local function TrimCacheIfNeeded()
	local count = 0
	for _ in pairs(spellNameToIdCache) do
		count = count + 1
		if count > CACHE_MAX_SIZE then
			wipe(spellNameToIdCache)
			return
		end
	end
end

function addon:CreateActionButton(key, category, title, duration, ...)
	local button = self.templates.CreateActionButton(key, category, title, duration, ...)
	if button then
		tinsert(actionButtons, button)
		if(self._163_AddToggleOption) then
			self:_163_AddToggleOption(button)
		end
		if(self.__initiated) then
			if(self:LoadData('disabledb', key)) then
				button:Disable()
			else
				button:InvokeMethod("OnEnable")
			end
		end
		return button
	end
end

function addon:GetNumButtons()
	return #actionButtons
end

function addon:GetButton(index)
	if type(index) == "string" then
		for _, button in ipairs(actionButtons) do
			if button.key == index then
				return button
			end
		end
	else
		return actionButtons[index]
	end
end

function addon:RegisterInitCallback(func, arg1)
	if InitCallbacks and type(func) == "function" then
		tinsert(InitCallbacks, { func = func, arg1 = arg1 })
		return 1
	end
end

-- Player spells
local LPS = _G["LibPlayerSpells-1.0"]
function addon:PlayerHasSpell(spell)
	return LPS:PlayerHasSpell(spell)
end

function addon:PlayerHasTalent(talent)
	return LPS:PlayerHasTalent(talent)
end

function addon:PlayerHasGlyph(glyph)
	return LPS:PlayerHasGlyph(glyph)
end

-- Builds a spell list using given spell id and conflicts list
local LAG = _G["LibBuffGroups-1.0"]
function addon:BuildSpellList(spellList, spellId, group, ...)
	if not spellId then return end

	local spell = C_Spell.GetSpellInfo(spellId)
	if not spell then return end

	local icon = spell.iconID
	local spellName = spell.name
	if not spellName then return end

	local data = { id = spellId, spell = spellName, icon = icon }
	if type(spellList) == "table" then
		tinsert(spellList, data)
	end

	-- Cache name -> ID
	spellNameToIdCache[spellName] = spellId
	TrimCacheIfNeeded()

	-- Build conflicts list
	local conflicts = {}
	local conflictsById = {}
	local conflictsCount = 0

	if type(group) == "string" then
		local similars = LAG:GetGroupAuras(group)
		if similars then
			for _, cid in pairs(similars) do
				if cid and cid ~= spellId then
					local cspell = C_Spell.GetSpellInfo(cid)
					if cspell and cspell.name ~= spellName then
						conflicts[cspell.name] = cspell.iconID
						conflictsCount = conflictsCount + 1
					end
					if cspell and cspell.name then
						spellNameToIdCache[cspell.name] = cid
						TrimCacheIfNeeded()
					end
					conflictsById[cid] = true
				end
			end
		end
	elseif type(group) == "number" then
		for i = 1, select("#", group, ...) do
			local cid = select(i, group, ...)
			if type(cid) == "number" and cid ~= spellId then
				local cspell = C_Spell.GetSpellInfo(cid)
				if cspell and cspell.name ~= spellName then
					conflicts[cspell.name] = cspell.iconID
					conflictsCount = conflictsCount + 1
				end
				if cspell and cspell.name then
					spellNameToIdCache[cspell.name] = cid
					TrimCacheIfNeeded()
				end
				conflictsById[cid] = true
			end
		end
	end

	if conflictsCount > 0 then
		data.conflicts = conflicts
	end
	if next(conflictsById) then
		data.conflictsById = conflictsById
	end

	return data
end

function addon:UpdateSpellListIcons(spellList)
	for _, data in ipairs(spellList) do
		if data.id then
			local spell = C_Spell.GetSpellInfo(data.id)
			if spell then
				data.icon = spell.iconID
			end
		end
	end
end

-- Retrieves buff remain time - MEMORY OPTIMIZED for WoW 12.1
-- Uses GetAuraDataByIndex instead of GetUnitAuras to avoid allocating
-- massive aura tables on every single scan.
function addon:GetUnitBuffTimer(unit, buff, mine)
	if not unit or not buff then
		return
	end

	-- Resolve buff to spellID
	local spellID = buff
	if type(buff) == "string" then
		spellID = spellNameToIdCache[buff]
		if not spellID then
			local spell = C_Spell.GetSpellInfo(buff)
			if spell and spell.spellID then
				spellID = spell.spellID
				spellNameToIdCache[buff] = spellID
				TrimCacheIfNeeded()
			end
		end
	end

	if type(spellID) ~= "number" then
		return
	end

	-- Fast path: GetPlayerAuraBySpellID for player unit
	if unit == "player" then
		local aura = C_UnitAuras.GetPlayerAuraBySpellID(spellID)
		if aura then
			local sourceUnit = aura.sourceUnit
			if not mine or (type(sourceUnit) == "string" and not (issecretvalue and issecretvalue(sourceUnit)) and sourceUnit == "player") then
				return SafeAuraValue(aura.expirationTime, 0), SafeAuraValue(aura.applications, 1)
			end
		end
		return
	end

	-- Secret 状态下不要扫描其他单位的光环，避免报错
	if unit ~= "player" and C_Secrets and C_Secrets.ShouldAurasBeSecret and C_Secrets.ShouldAurasBeSecret() then
		return
	end

	-- Memory-efficient fallback: scan by index, zero table allocation
	for i = 1, 40 do
		local aura = C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL")
		if not aura then break end
		-- 解封 secret number，避免 taint 导致的比较错误
		local auraSpellId = aura.spellId
		if issecretvalue and issecretvalue(auraSpellId) then
			auraSpellId = nil
		else
			auraSpellId = tonumber(auraSpellId)
		end
		if auraSpellId and auraSpellId == spellID then
			if not mine then
				return SafeAuraValue(aura.expirationTime, 0), SafeAuraValue(aura.applications, 1)
			end
			local sourceUnit = aura.sourceUnit
			if type(sourceUnit) == "string" and not (issecretvalue and issecretvalue(sourceUnit)) and sourceUnit == "player" then
				return SafeAuraValue(aura.expirationTime, 0), SafeAuraValue(aura.applications, 1)
			end
		end
	end
end

function addon:GetGradientColor(number, threshold)
	local r, g = 1, 0
	if number and threshold and threshold > 0 then
		local percent = number / threshold
		if percent >= 0.5 then
			r, g = (1.0 - percent) * 2, 1
		else
			r, g = 1, percent * 2
		end
	end
	return r, g, 0
end

function addon:IsFormActive(form)
	for i = 1, GetNumShapeshiftForms() do
		local _, active, castable, spellId = GetShapeshiftFormInfo(i)
		if spellId and type(spellId) == "number" and not (issecretvalue and issecretvalue(spellId)) then
			local spell = C_Spell.GetSpellInfo(spellId)
			if spell and spell.name == form then
				return active
			end
		end
	end
end

function addon:GetColoredUnitName(unit)
	if not unit then return end
	local name = UnitName(unit)
	if not name then return end
	local color = RAID_CLASS_COLORS[select(2, UnitClass(unit))]
	if color then
		name = format("|cff%02x%02x%02x%s|r", color.r * 255, color.g * 255, color.b * 255, name)
	end
	return name
end

function addon:IsGrouped()
	local count = GetNumGroupMembers()
	local group
	if IsInRaid() then
		group = "raid"
	elseif count > 0 then
		group = "party"
	end
	return group, count
end

-- Data access
local DATA_TABLES = { db = 1, chardb = 1, specdb = 1, disabledb = 1 }
local function GetDataTable(dataType)
	return DATA_TABLES[dataType] and addon[dataType]
end

function addon:LoadData(dataType, key)
	local data = GetDataTable(dataType)
	return data and data[key]
end

function addon:SaveData(dataType, key, value)
	local data = GetDataTable(dataType)
	if data then
		data[key] = value
		return 1
	end
end

local EVENTS_DEF = {
	UNIT_AURA = { method = "OnPlayerAura", arg1 = "player" },
	UNIT_INVENTORY_CHANGED = { method = "OnInventoryUpdate", arg1 = "player" },
	PLAYER_EQUIPMENT_CHANGED = { method = "OnInventoryUpdate", arg1 = "player" },
	BAG_UPDATE = { method = "OnBagUpdate" },
	BAG_UPDATE_COOLDOWN = { method = "OnBagUpdate" },
	PLAYER_TALENT_UPDATE = { method = "OnTalentUpdate" },
	UNIT_STATS = { method = "OnStatsUpdate", arg1 = "player" },
	RAID_ROSTER_UPDATE = { method = "OnRosterUpdate" },
	UNIT_PET = { method = "OnPlayerPet", arg1 = "player" },
	PLAYER_TOTEM_UPDATE = { method = "OnPlayerPet" },
}

local inCombat
local methodPool = {}

local function FireAllEvents()
	for _, data in pairs(EVENTS_DEF) do
		methodPool[data.method] = 1
	end
end

local function NotifyButtons(method)
	for i = 1, #actionButtons do
		local button = actionButtons[i]
		-- 禁用状态只隐藏的话，内部仍会被NotifyButtons驱动；
		-- 这里跳过禁用按钮，让“禁用”真正关闭功能并省掉无效扫描
		if not button:GetAttribute("disabled") then
			button:InvokeMethod(method, inCombat)
		end
	end
end

local function OnTalentSwitch()
	local db = addon.chardb.talents
	if type(db) ~= "table" then
		db = {}
		addon.chardb.talents = db
	end
	local talent = GetActiveSpecGroup()
	if type(db[talent]) ~= "table" then
		db[talent] = {}
	end
	addon.specdb = db[talent]
	NotifyButtons("OnTalentSwitch")
end

local updateElapsed = 0
local function Frame_OnUpdate(self, elapsed)
	updateElapsed = updateElapsed + elapsed
	if updateElapsed > 0.2 then
		updateElapsed = 0
		for method in pairs(methodPool) do
			NotifyButtons(method)
			methodPool[method] = nil
		end
	end
end

local spellFire = {}
LPS:HookObject(spellFire)

function spellFire:OnSpellsChanged()
	NotifyButtons("OnSpellUpdate")
end

--------------------------------------------
-- Addon main frame
--------------------------------------------

local frame = CreateFrame("Frame", "LiteBuffFrame", UIParent, "SecureFrameTemplate")
addon.frame = frame
frame:SetSize(50, 50)
frame:SetPoint('BOTTOM', 600, 150)
frame:SetMovable(true)
frame:SetToplevel(true)
frame:SetClampedToScreen(true)
frame:SetUserPlaced(true)
frame:RegisterEvent("ADDON_LOADED")

frame:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" and arg1 == addonName then
		self:UnregisterEvent(event)
		addon.__initiated = true

		if type(LiteBuffDB) ~= "table" then
			LiteBuffDB = {}
		end
		addon.db = LiteBuffDB

		if not addon.db.v21 then
			wipe(addon.db)
			addon.db.v21 = 1
		end

		if type(LiteBuffCharDB) ~= "table" then
			LiteBuffCharDB = {}
		end
		addon.chardb = LiteBuffCharDB

		if type(addon.chardb.disabled) ~= "table" then
			addon.chardb.disabled = {}
		end

		addon.disabledb = addon.chardb.disabled

		NotifyButtons("OnInitialize")

		for _, data in ipairs(InitCallbacks) do
			data.func(data.arg1)
		end
		InitCallbacks = nil

		self:RegisterEvent("PLAYER_ENTERING_WORLD")
		self:RegisterEvent("PLAYER_REGEN_DISABLED")
		self:RegisterEvent("PLAYER_REGEN_ENABLED")
		self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")

		for key in pairs(EVENTS_DEF) do
			self:RegisterEvent(key)
		end
		self:RegisterEvent("UNIT_HEALTH")

		OnTalentSwitch()
		self:SetScript("OnUpdate", Frame_OnUpdate)

	elseif event == "PLAYER_ENTERING_WORLD" then
		FireAllEvents()
		NotifyButtons("OnEnterWorld")

	elseif event == "PLAYER_REGEN_DISABLED" then
		inCombat = 1
		NotifyButtons("OnEnterCombat")

	elseif event == "PLAYER_REGEN_ENABLED" then
		inCombat = nil
		FireAllEvents()
		NotifyButtons("OnLeaveCombat")
		Frame_OnUpdate(self, 1000)

	elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
		if arg1 == 'player' then OnTalentSwitch() end

	else
		-- 队伍/团队变化时清理死亡状态缓存
		if event == "GROUP_ROSTER_UPDATE" or event == "RAID_ROSTER_UPDATE" then
			wipe(groupLastDead)
		end

		-- 监听队友/团队成员的UNIT_AURA，否则队友死亡/被补buff后
		-- GROUP_AURA按钮不会刷新，仍显示缺少增益
		if event == "UNIT_AURA" and arg1 and (arg1:match("^party%d+$") or arg1:match("^raid%d+$")) then
			methodPool.OnPlayerAura = 1
		end

		-- 死亡/复活边界：WoW死亡时不一定触发UNIT_AURA，
		-- 用UNIT_HEALTH的存活/死亡跳变强制刷新一次
		if event == "UNIT_HEALTH" and arg1 and (arg1:match("^party%d+$") or arg1:match("^raid%d+$")) then
			local dead = UnitIsDeadOrGhost(arg1)
			if groupLastDead[arg1] ~= dead then
				groupLastDead[arg1] = dead
				methodPool.OnPlayerAura = 1
			end
		end

		local data = EVENTS_DEF[event]
		if data then
			if not data.arg1 or data.arg1 == tostring(arg1) then
				methodPool[data.method] = 1
			end
		end
	end
end)

local _callbacks = {}
local _regen = 'PLAYER_REGEN_ENABLED'
local function onEvent(self, event, arg1)
	if InCombatLockdown() then return self:RegisterEvent(_regen) end
	if event == _regen then self:UnregisterEvent(_regen) end
	if event == 'PLAYER_SPECIALIZATION_CHANGED' and arg1 ~= 'player' then return end
	for f in next, _callbacks do
		pcall(f)
	end
end

local f = CreateFrame'Frame'
f:SetScript('OnEvent', onEvent)
f:RegisterEvent'LEARNED_SPELL_IN_SKILL_LINE'
f:RegisterEvent'PLAYER_SPECIALIZATION_CHANGED'

function addon:__163_OnSpellChanged(callback)
	_callbacks[callback] = true
	if IsLoggedIn() then
		pcall(callback)
	else
		f:RegisterEvent'PLAYER_LOGIN'
	end
end