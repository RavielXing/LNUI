--if UnitLevel("player") > 119 then return end
------------------------------------------------------------
-- copy from CrystalOfInsanity.lua by 163ui 2017/10
-- modified for 8.3 by abyui 2020/03
------------------------------------------------------------


local _, addon = ...
local L = addon.L

local AURA_NAME
local CONFLICTS

local itemName, itemLink

-- 定义所有符文物品ID
local RUNE_ITEMS = {
    ETHEREAL = 243191,  -- 虚灵强化符文
    SOUL_EATING = 259085, -- 虚触强化符文
}

-- 定义符文对应的法术ID
local RUNE_SPELLS = {
    [RUNE_ITEMS.ETHEREAL] = 1234969,  -- 虚灵强化符文buff的id
    [RUNE_ITEMS.SOUL_EATING] = 1264426, -- 虚触强化符文buff的id
}

-- 跟踪当前使用的物品ID
local currentItemId = RUNE_ITEMS.ETHEREAL

-- 选择要使用的符文物品ID
local function GetPreferredRuneItem()
    -- 检查背包中是否有虚灵强化符文
    if GetItemCount(RUNE_ITEMS.ETHEREAL) > 0 then
        return RUNE_ITEMS.ETHEREAL
    -- 检查背包中是否有噬魂强化符文
    elseif GetItemCount(RUNE_ITEMS.SOUL_EATING) > 0 then
        return RUNE_ITEMS.SOUL_EATING
    -- 如果没有符文，默认使用虚灵强化符文（即使没有物品）
    else
        return RUNE_ITEMS.ETHEREAL
    end
end

-- 更新AURA_NAME和CONFLICTS基于当前选择的符文
local function UpdateRuneSpellInfo(itemId)
    local spellId = RUNE_SPELLS[itemId]
    if spellId then
        AURA_NAME = C_Spell.GetSpellInfo(spellId).name
        CONFLICTS = addon:BuildSpellList(nil, spellId, 347901).conflicts -- 隐晦强化
    end
end

local button = addon:CreateActionButton("LightforgedRune", L["Lightning-Forged Augment Rune"], nil, 3600, "PLAYER_AURA", "ITEM")

-- 初始化设置符文物品
local function SetupRuneItem()
    local preferredItem = GetPreferredRuneItem()
    currentItemId = preferredItem
    button:SetItem(preferredItem)
    button:RequireItem(preferredItem)
    LibItemQuery:QueryItem(preferredItem, button, 1)
    UpdateRuneSpellInfo(preferredItem)
end

SetupRuneItem()

button:SetFlyProtect("type", "item")

function button:OnItemInfoReceived(itemId, name, link, quality, iLevel, reqLevel, class, subclass, maxStack, equipSlot, texture)
    self:SetAttribute("item", name)
    itemName = name
    itemLink = "|cff0070dd"..name.."|r"
    self.icon:SetIcon(texture)
end

function button:OnTooltipTitle(tooltip)
    if itemLink then
        tooltip:AddLine(itemLink)
    end
end

function button:OnTooltipLeftText(tooltip)
    if itemLink then
        tooltip:AddLine(L["left click"]..L["use"].. itemLink, 1, 1, 1, 1)
    end
end

function button:OnUpdateTimer(spell)
    -- 每次更新时检查是否有更优先的符文可用
    local preferredItem = GetPreferredRuneItem()
    
    if currentItemId ~= preferredItem then
        SetupRuneItem()
    end
    
    -- 手动更新物品数量（PLAYER_AURA模式下不会自动更新）
    local count = GetItemCount(currentItemId)
    self.itemCount = count
    
    local conflict
    local expires = addon:GetUnitBuffTimer("player", AURA_NAME)
    if expires then
        self.icon.text:Hide()
        return 1, expires
    end

    if CONFLICTS then
        local other, icon
        for other, icon in pairs(CONFLICTS) do
            expires = addon:GetUnitBuffTimer("player", other)
            if expires then
                conflict = icon
                break
            end
        end
    end

    self:SetConflictIcon(conflict)
    
    if expires or conflict then
        self.icon.text:Hide()
        return "NONE", expires
    else
        if count > 0 then
            self.icon.text:Show()
            return "G", self.itemCooldownExpires
        else
            self.icon.text:Hide()
            return "R", self.itemCooldownExpires
        end
    end
end