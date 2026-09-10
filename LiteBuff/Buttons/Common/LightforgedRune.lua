------------------------------------------------------------
-- copy from CrystalOfInsanity.lua by 163ui 2017/10
-- modified for 8.3 by abyui 2020/03
-- 12.1 内存优化版: 替换废弃 API，减少高频背包扫描
------------------------------------------------------------

local _, addon = ...
local L = addon.L

local AURA_NAME
local CONFLICTS

local itemName, itemLink

-- 定义所有符文物品ID
local RUNE_ITEMS = {
    TIDAL = 274797,     -- 潮誓强化符文
    SOUL_EATING = 259085, -- 虚触强化符文
}

-- 定义符文对应的法术ID
local RUNE_SPELLS = {
    [RUNE_ITEMS.TIDAL] = 1295329,     -- 潮誓强化符文buff的id
    [RUNE_ITEMS.SOUL_EATING] = 1264426, -- 虚触强化符文buff的id
}

-- 跟踪当前使用的物品ID
local currentItemId = RUNE_ITEMS.TIDAL

-- 12.1 优化: 使用 C_Item.GetItemCount 替代旧版 GetItemCount
local GetItemCount = C_Item and C_Item.GetItemCount or GetItemCount

-- 12.1 优化: 缓存背包扫描结果，限制扫描频率
local lastBagScan = 0
local cachedPreferredRune = nil

-- 选择要使用的符文物品ID（优先级：潮誓 > 虚触）
local function GetPreferredRuneItem()
    -- 限制扫描频率到每 3 秒一次，大幅减少内存和 CPU 占用
    local now = GetTime()
    if now - lastBagScan < 3 and cachedPreferredRune then
        return cachedPreferredRune
    end
    lastBagScan = now

    local preferred = RUNE_ITEMS.TIDAL
    if GetItemCount(RUNE_ITEMS.TIDAL) > 0 then
        preferred = RUNE_ITEMS.TIDAL
    elseif GetItemCount(RUNE_ITEMS.SOUL_EATING) > 0 then
        preferred = RUNE_ITEMS.SOUL_EATING	
    end

    cachedPreferredRune = preferred
    return preferred
end

-- 更新AURA_NAME和CONFLICTS基于当前选择的符文
local function UpdateRuneSpellInfo(itemId)
    local spellId = RUNE_SPELLS[itemId]
    if spellId then
        local spellInfo = C_Spell.GetSpellInfo(spellId)
        AURA_NAME = spellInfo and spellInfo.name
        local conflictsData = addon:BuildSpellList(nil, spellId, 347901)
        CONFLICTS = conflictsData and conflictsData.conflicts -- 隐晦强化
    end
end

local button = addon:CreateActionButton("LightforgedRune", "符文", nil, 3600, "PLAYER_AURA", "ITEM")

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
button.icon.text:Hide() -- 旧数量文字不再使用，避免和countText重复

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

-- 12.1 优化: 缓存物品数量，避免每次 OnUpdateTimer 都查询
local cachedItemCount = 0
local lastCountUpdate = 0

local function UpdateCountText(frame, count)
    if not frame.icon.countText then
        frame.icon.countText = frame.icon:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        frame.icon.countText:SetPoint("BOTTOMRIGHT", frame.icon, "BOTTOMRIGHT", -1, 1)
        frame.icon.countText:SetJustifyH("RIGHT")
        frame.icon.countText:SetFont(STANDARD_TEXT_FONT, 15, "OUTLINE")
        frame.icon.countText:SetTextColor(0, 1, 0, 1)
    end
    if count and count > 0 then
        frame.icon.countText:SetText(count)
        frame.icon.countText:Show()
    else
        frame.icon.countText:Hide()
    end
end

function button:OnUpdateTimer(spell)
    -- 每次更新时检查是否有更优先的符文可用（受 3 秒缓存限制）
    local preferredItem = GetPreferredRuneItem()

    if currentItemId ~= preferredItem then
        SetupRuneItem()
    end

    -- 手动更新物品数量（PLAYER_AURA模式下不会自动更新）
    -- 12.1 优化: 限制数量查询频率
    local now = GetTime()
    if now - lastCountUpdate >= 1 then
        cachedItemCount = GetItemCount(currentItemId)
        lastCountUpdate = now
    end
    self.itemCount = cachedItemCount
    UpdateCountText(self, cachedItemCount)

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
        if cachedItemCount > 0 then
            return "G", self.itemCooldownExpires
        else
            self.icon.text:Hide()
            return "R", self.itemCooldownExpires
        end
    end
end


-- 注册到公共消耗品扫描器，统一扫描后再分发
local scan = addon.ConsumableScan
if scan then
    local ids = { RUNE_ITEMS.TIDAL, RUNE_ITEMS.SOUL_EATING }
    scan:AddItems(ids)
    scan:AddCallback(function(counts)
        if not button or button:GetAttribute("disabled") then
            return
        end
        local hasAny = (counts[RUNE_ITEMS.TIDAL] or 0) > 0 or (counts[RUNE_ITEMS.SOUL_EATING] or 0) > 0
        if hasAny then
            if not button:IsShown() then
                button:Show()
            end
            local preferredItem = GetPreferredRuneItem()
            if currentItemId ~= preferredItem then
                SetupRuneItem()
            end
            button:UpdateTimer()
        else
            if button:IsShown() then
                button:Hide()
            end
        end
    end)
end
