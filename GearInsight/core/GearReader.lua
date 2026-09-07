-- GearReader.lua
-- Reads the player's currently equipped items across the 16 standard slots.

GearInsight = GearInsight or {}

local GearReader = {}

-- 洗数：12.0.5+ 暴雪部分 API 在插件(污染)执行链里返回 secret number——存起来不炸，
-- 之后任何算术/比较才炸(线上 0.34.0 RefreshPanel 崩溃实证)。所有要进 snapshot 的
-- 数字一律过这道：secret/nil/非数 → fallback。pcall(v+0) 是唯一安全的探测方式。
local function scrubNum(v, fallback)
    local ok, n = pcall(function() return v + 0 end)
    if ok then return n end
    return fallback
end
GearInsight.SafeNum = scrubNum

local SLOT_IDS = {
    1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17,
}

local SLOT_NAME_KEYS = {
    [1]  = "SLOT_HEAD",
    [2]  = "SLOT_NECK",
    [3]  = "SLOT_SHOULDER",
    [5]  = "SLOT_CHEST",
    [6]  = "SLOT_WAIST",
    [7]  = "SLOT_LEGS",
    [8]  = "SLOT_FEET",
    [9]  = "SLOT_WRIST",
    [10] = "SLOT_HANDS",
    [11] = "SLOT_FINGER1",
    [12] = "SLOT_FINGER2",
    [13] = "SLOT_TRINKET1",
    [14] = "SLOT_TRINKET2",
    [15] = "SLOT_BACK",
    [16] = "SLOT_MAINHAND",
    [17] = "SLOT_OFFHAND",
}

local STAT_KEY_MAP = {
    ITEM_MOD_CRIT_RATING_SHORT          = "crit",
    ITEM_MOD_HASTE_RATING_SHORT         = "haste",
    ITEM_MOD_MASTERY_RATING_SHORT       = "mastery",
    ITEM_MOD_VERSATILITY                = "versatility",
    ITEM_MOD_STRENGTH_SHORT             = "strength",
    ITEM_MOD_AGILITY_SHORT              = "agility",
    ITEM_MOD_INTELLECT_SHORT            = "intellect",
    ITEM_MOD_STAMINA_SHORT              = "stamina",
}

local function extractStats(itemLink)
    if not itemLink then return {} end
    -- 12.0.5 起部分属性 API 在插件执行链中可能返回 secret value，对其做
    -- tonumber/算术会直接抛错（同 StatReader 的坑）。GetItemStats 目前没中招，
    -- 但整段调用+算术放进 pcall，哪天暴雪扩大保护范围也只是该件回退空表，不崩刷新。
    local ok, normalized = pcall(function()
        local raw
        if C_Item and C_Item.GetItemStats then
            raw = C_Item.GetItemStats(itemLink)
        elseif GetItemStats then
            raw = GetItemStats(itemLink)
        end
        local out = {}
        if type(raw) == "table" then
            for k, v in pairs(raw) do
                local mapped = STAT_KEY_MAP[k]
                if mapped then
                    out[mapped] = (out[mapped] or 0) + (tonumber(v) or 0)
                end
            end
        end
        return out
    end)
    if ok and type(normalized) == "table" then return normalized end
    return {}
end

local function safeGetItemInfo(itemLink)
    if not itemLink then return nil end
    local name, _, quality, ilvl = GetItemInfo(itemLink)
    return name, scrubNum(quality, quality and 1 or nil), scrubNum(ilvl, nil)
end

local function extractItemId(itemLink)
    if not itemLink then return nil end
    local id = itemLink:match("item:(%d+):")
    return id and tonumber(id) or nil
end

function GearReader:ReadSlot(slotId)
    local link = GetInventoryItemLink("player", slotId)
    if not link then
        return {
            slotId = slotId,
            slotKey = SLOT_NAME_KEYS[slotId] or "SLOT_UNKNOWN",
            empty = true,
        }
    end
    local name, quality, ilvl = safeGetItemInfo(link)
    if not name and Item and Item.CreateFromItemLink then
        local item = Item:CreateFromItemLink(link)
        if item and not item:IsItemEmpty() then
            item:ContinueOnItemLoad(function()
                if GearInsight and GearInsight.OnItemDataLoaded then
                    GearInsight:OnItemDataLoaded(slotId, link)
                end
            end)
        end
    end
    local effectiveIlvl = scrubNum(GetDetailedItemLevelInfo and select(1, GetDetailedItemLevelInfo(link)), nil) or ilvl
    return {
        slotId = slotId,
        slotKey = SLOT_NAME_KEYS[slotId] or "SLOT_UNKNOWN",
        itemId = extractItemId(link),
        itemLink = link,
        itemName = name,
        quality = quality,
        ilvl = effectiveIlvl or ilvl,
        stats = extractStats(link),
        empty = false,
    }
end

function GearReader:ReadAll()
    local equipped = {}
    for _, slotId in ipairs(SLOT_IDS) do
        equipped[slotId] = self:ReadSlot(slotId)
    end
    local avgIlvl, equippedIlvl
    if GetAverageItemLevel then
        avgIlvl, equippedIlvl = GetAverageItemLevel()
        avgIlvl, equippedIlvl = scrubNum(avgIlvl, 0), scrubNum(equippedIlvl, 0)
    end
    return {
        equipped = equipped,
        averageItemLevel = avgIlvl,
        equippedItemLevel = equippedIlvl,
    }
end

function GearReader:GetSlotKey(slotId)
    return SLOT_NAME_KEYS[slotId]
end

function GearReader:GetAllSlotIds()
    return SLOT_IDS
end

GearInsight.GearReader = GearReader
