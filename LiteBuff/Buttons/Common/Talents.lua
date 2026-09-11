------------------------------------------------------------
-- Talents.lua
-- 12.1 内存优化版: 修复重复局部化，避免重复初始化
-- Abin 2011/11/13 / 2026 修订
------------------------------------------------------------

local InCombatLockdown = InCombatLockdown
local IsFlying = IsFlying
local GetSpecialization = GetSpecialization
local GetNumSpecializations = GetNumSpecializations
local GetSpecializationInfo = GetSpecializationInfo

local _, addon = ...
local L = addon.L

local talentList = {}
local initialized = false  -- 12.1 优化: 防止重复初始化

function InitSpecializationList()
    if initialized then return end  -- 已初始化则跳过

    local talentNum = GetNumSpecializations()
    for i = 1, talentNum do
        local specID, specName, specDescription, specIcon, specRole, specClass = GetSpecializationInfo(i)
        if specIcon == 132115 then specIcon = 132122	-- 猫德专精图标替换为斜掠，与猎豹形态图标区分
        elseif specIcon == 132276 then specIcon = 1378702 end	-- 熊德专精图标替换为铁鬃，与熊形态图标区分
        talentList[i] = { icon = specIcon, name = specName, desc = specDescription }
    end
    initialized = true
end

local button = addon:CreateActionButton("TalentSwitch", L["switch talents"])
C_Timer.After(0.2, function ()
	InitSpecializationList()
	button:SetScrollable(talentList, 'macro')
end)

button:SetFlyProtect(nil)
button:SetScript("OnClick", function(self)
	if not InCombatLockdown() and not IsFlying() and self.index ~= GetSpecialization() then
		C_SpecializationInfo.SetSpecialization(self.index)
	end
end)

function button:OnValidate()
	return GetNumSpecializations() > 1
end

local function ValidateButton()
	if button:IsEnabled() and button:OnValidate() then
		button:Show()
	else
		button:Hide()
	end
end

function button:OnTalentUpdate(combat)
	if not combat then
		ValidateButton()
	end

	if self:OnValidate() then
		self:UpdateTimer()
	end
end

function button:OnTooltipText(tooltip)
	-- 12.1 优化: 仅在未初始化时调用
	-- 战斗中SetScrollable会推迟, deferredScroll还在时也要重试
	if not initialized or button.deferredScroll then
		InitSpecializationList()
		button:SetScrollable(talentList, 'macro')
	end

	local currentSpec = GetSpecialization()
	local index = button.index
	if not talentList[index] then return end

	if index == currentSpec then
		tooltip:AddLine(talentList[index].name..": "..talentList[index].desc, 0, 1, 0, 1 )
	else
		tooltip:AddLine(talentList[index].name..": "..talentList[index].desc, 0.6, 0.6, 0.6, 1)
	end
end

function button:OnLeaveCombat()
	ValidateButton()
end
