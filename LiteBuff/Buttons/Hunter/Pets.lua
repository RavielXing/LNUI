------------------------------------------------------------
-- Pets.lua
--
-- Abin
-- 2011/11/13
------------------------------------------------------------

if select(2, UnitClass("player")) ~= "HUNTER" then return end




-- 12.1 统一走 C_ 命名空间(旧全局API兜底)
local GetSpellTexture = (C_Spell and C_Spell.GetSpellTexture) or GetSpellTexture

local InCombatLockdown = InCombatLockdown
local GetStablePetInfo = GetStablePetInfo
local UnitName = UnitName
local UnitIsDead = UnitIsDead
local GetPetIcon = GetPetIcon

local _, addon = ...
local L = addon.L

-- WoW 12.0+ 安全值比较
-- 在 taint 环境下，API 返回的 secret string/number 无法通过 tostring/..""/format 清洗
-- 所有操作结果都会继承 secret 状态。只能使用 issecretvalue 检测或 pcall 保护比较。
local function SafeEqual(a, b)
	-- 优先使用 WoW 12.0 原生 API issecretvalue
	if issecretvalue then
		if issecretvalue(a) or issecretvalue(b) then
			return false  -- secret 值视为不相等，触发更新
		end
		return a == b
	end
	-- 旧版本兜底：pcall 保护
	local ok, result = pcall(function() return a == b end)
	return ok and result or false
end

-- 安全判断非空字符串（避免 secret string 与 "" 直接比较报错）
local function SafeNotEmpty(s)
	if not s then return false end
	if issecretvalue and issecretvalue(s) then
		return true  -- secret string 视为非空
	end
	return type(s) == "string" and s ~= ""
end

local spellList = {}
addon:BuildSpellList(spellList, 883)
addon:BuildSpellList(spellList, 83242)
addon:BuildSpellList(spellList, 83243)
addon:BuildSpellList(spellList, 83244)
addon:BuildSpellList(spellList, 83245)

local i
for i = 1, 5 do
	local data = spellList[i]
	data.rawName = data.spell
end

local DISMISS = addon:BuildSpellList(nil, 2641)
local REVIVE = addon:BuildSpellList(nil, 982)
local button = addon:CreateActionButton("HunterPets", L["pets"], nil, nil, "DUAL")
button:SetFlyProtect()
button:SetScrollable(spellList, "spell1")
button:RequireSpell(883)

button:SetAttribute("petalive", DISMISS.spell)
button:SetAttribute("petdead", REVIVE.spell)

function button:OnEnable()
	self:RegisterEvent("PET_STABLE_UPDATE")
	self:RegisterEvent("UNIT_NAME_UPDATE")
end

function button:OnPetAlive(alive)
	self:SetSpell2(alive and DISMISS or REVIVE)
	self:UpdateTimer()
end

-- FlyProtection会在进战/脱战/飞行时改图标亮度，这里按宠物是否存在覆盖回正确状态
function button:OnFlyStateChanged(flying)
	self.flying = flying
	self:OnTick()
end

button:SetAttribute("_onstate-petstate", [[
	local alive = newstate == 1
	local spell = self:GetAttribute(alive and "petalive" or "petdead")
	self:SetAttribute("spell2", spell)
	self:CallMethod("OnPetAlive", alive, spell)
]])

RegisterStateDriver(button, "petstate", "[@pet,exists,nodead] 1; 0")

function button:PET_STABLE_UPDATE()
	local maxIndex = 1
	local i
	for i = 1, 5 do
--163uiedit
		local icon, name --= GetStablePetInfo(i)
		local spellID, isKnown = GetFlyoutSlotInfo(9, i);
		if spellID and isKnown then
			icon = GetSpellTexture(spellID)
			local petIndex, petName = GetCallPetSpellInfo(spellID);
			if petIndex and petName then
				-- 修复：避免 secret string 与 "" 比较崩溃
				if SafeNotEmpty(petName) then
					name = petName
				end
			end
		end
		if icon and name then
			spellList[i].icon = icon
			spellList[i].spell = name
			maxIndex = i
		else
			spellList[i].icon = "Interface\\Icons\\Ability_Hunter_BeastCall"
			spellList[i].spell = spellList[i].rawName
		end
	end

	self:SetMaxIndex(maxIndex)
	self:UpdateSpell()
end

function button:UNIT_NAME_UPDATE(unit)
	if unit == "pet" then
		self:PET_STABLE_UPDATE()
	end
end

local petName, petIcon

local function UpdatePetIconDarkness()
	local petExists = UnitExists("pet")
	local petAlive = petExists and not UnitIsDead("pet")
	local data = spellList[button.index]
	local match = petAlive and petName and petIcon and data and SafeEqual(petName, data.spell) and SafeEqual(petIcon, data.icon)
	local dark
	if not petExists then
		dark = true
	elseif not petAlive then
		dark = false
	else
		dark = not match
	end
	if button.flying then dark = true end
	button.icon:SetDesaturated(dark)
	button.icon2:SetDesaturated(dark)
end

function button:OnUpdateTimer()
	UpdatePetIconDarkness()
	local petExists = UnitExists("pet")
	local alive = petExists and not UnitIsDead("pet")
	if not petExists then
		-- 没召唤宠物：暗色即可，不闪红
		return "NONE"
	elseif not alive then
		-- 宠物存在但死亡：红色
		return "R"
	else
		-- 宠物活着：亮暗由 UpdatePetIconDarkness 控制
		return "NONE"
	end
end

-- UpdateStatus会把顶点颜色重置回(1,1,1)，所以在它之后再应用一次宠物图标亮暗
local _HunterPetsUpdateStatus = button.UpdateStatus
function button:UpdateStatus(...)
	_HunterPetsUpdateStatus(self, ...)
	UpdatePetIconDarkness()
end

function button:OnTick()
	-- 12.1状态驱动petstate可能不更新，直接实时判断宠物状态
	local petExists = UnitExists("pet")
	UpdatePetIconDarkness()
	local name = UnitName("pet")
	local icon = GetPetIcon()
	-- 修复：所有来自API的返回值都可能是secret，使用SafeEqual比较
	if not SafeEqual(petName, name) or not SafeEqual(petIcon, icon) then
		petName, petIcon = name, icon
		self:UpdateTimer()
	end
end


function button:OnSpellUpdate()
	if GetSpecialization() == 2 and not IsPlayerSpell(1223323) then
		button:Hide()
	else 
		button:Show()
	end
end

button.OnEnterWorld = button.PET_STABLE_UPDATE
button.OnLeaveCombat = button.PET_STABLE_UPDATE
