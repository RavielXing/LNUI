-- SavedVars.lua
-- Persists the merged GearReader + StatReader snapshot to the GearInsightDB saved variable.

GearInsight = GearInsight or {}

local SavedVars = {}

local SCHEMA_VERSION = 1

local function characterKey()
    local name = UnitName("player") or "Unknown"
    local realm = GetRealmName and GetRealmName() or ""
    if realm and realm ~= "" then
        return name .. "-" .. realm
    end
    return name
end

local function serializeEquipped(equipped)
    if not equipped then return {} end
    local out = {}
    for slotId, slot in pairs(equipped) do
        if slot.empty then
            out[slotId] = { slotId = slotId, empty = true }
        else
            out[slotId] = {
                slotId   = slotId,
                itemId   = slot.itemId,
                itemLink = slot.itemLink,
                itemName = slot.itemName,
                ilvl     = slot.ilvl,
                quality  = slot.quality,
                stats    = slot.stats,
                catalystOf = slot.catalystOf,   -- 转换件原 id（bug #122），显示用
            }
        end
    end
    return out
end

function SavedVars:Save()
    GearInsightDB = GearInsightDB or {}
    GearInsightDB.characters = GearInsightDB.characters or {}

    local gear = GearInsight.GearReader and GearInsight.GearReader:ReadAll() or {}
    local stat = GearInsight.StatReader and GearInsight.StatReader:ReadAll() or {}
    -- bug #122：催化剂外观转换件（披风/护腕/腰带/靴子）按属性归一到原件 itemId，快照之后所有页面都认它已毕业
    if GearInsight.ResolveCatalyst and gear.equipped then
        pcall(GearInsight.ResolveCatalyst, gear.equipped, stat.class, stat.spec, stat.heroTalent)
    end

    local snapshot = {
        character     = characterKey(),
        class         = stat.class,
        spec          = stat.spec,
        specId        = stat.specId,
        heroTalent    = stat.heroTalent,
        itemLevel     = gear.equippedItemLevel or gear.averageItemLevel,
        averageItemLevel = gear.averageItemLevel,
        equipped      = serializeEquipped(gear.equipped),
        secondary     = stat.secondary,
        secondaryRating = stat.secondaryRating,
        primary       = stat.primary,
        timestamp     = time(),
        schemaVersion = SCHEMA_VERSION,
    }

    GearInsightDB.schemaVersion = SCHEMA_VERSION
    GearInsightDB.lastCharacter = snapshot.character
    GearInsightDB.characters[snapshot.character] = snapshot

    -- 历史版本曾把整个快照平铺到 DB 根部（SavedVariables 体积翻倍，且多角色
    -- 互相覆盖留下脏数据）。插件内没有任何代码读这些根键（全走 GetLastSnapshot），
    -- 这里顺手清掉老文件遗留的根键。
    for _, k in ipairs({
        "character", "class", "spec", "specId", "heroTalent",
        "itemLevel", "averageItemLevel", "equipped",
        "secondary", "secondaryRating", "primary", "timestamp",
    }) do
        GearInsightDB[k] = nil
    end

    return snapshot
end

function SavedVars:GetLastSnapshot()
    if not GearInsightDB then return nil end
    return GearInsightDB.characters and GearInsightDB.characters[GearInsightDB.lastCharacter] or nil
end

GearInsight.SavedVars = SavedVars
