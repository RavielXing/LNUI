-- StatReader.lua
-- Reads the player's current panel stats, primary stats, spec and hero talent.

GearInsight = GearInsight or {}

local StatReader = {}

local function safeCall(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if ok then return value end
    return nil
end

-- 洗数(同 GearReader.scrubNum/GearInsight.SafeNum)：safeCall 只保护"调用"，
-- 返回值本身仍可能是 secret number(如 computeCrit 兜底分支原样返回 melee)，
-- 存进 snapshot 后下游算术就崩。所有出口数字过这道。
local function scrubNum(v, fallback)
    local ok, n = pcall(function() return v + 0 end)
    if ok then return n end
    return fallback
end

local function readSecondaryStats()
    -- Mirror the character panel's own stat APIs so the displayed % matches the panel
    -- exactly for EVERY spec (caster / ranged / melee), not just one stat.
    -- Crit: the panel shows the highest of spell / ranged / melee crit (Murlok-style).
    --
    -- 12.0.5: 在被插件污染(tainted)的执行链里，部分暴击/属性 API（GetSpellCritChance
    -- 等）会返回 "secret value"（受保护数值）。对 secret 值做裸 < / > / math.max / +
    -- 都会抛 "attempt to compare/perform arithmetic on a secret value"。
    -- 旧 safeCall 只保护"调用"本身，保护不到调用之后的比较/算术，所以仍会崩。
    -- 修复：把所有"对 API 返回值做比较/算术"的逻辑整体放进内部函数，再用 safeCall
    -- 包它——这样函数内部的 < / > / math.max / + 全在 pcall 保护下；一旦遇到 secret
    -- 值，整个内部函数报错被吞掉，该项回退 0，绝不让上层 Save/RefreshData 崩溃。

    -- Crit: 多来源取最大值，整段比较/算术放进 safeCall 内。
    local function computeCrit()
        local melee  = (GetCritChance and GetCritChance()) or 0
        local ranged = (GetRangedCritChance and GetRangedCritChance()) or 0
        local spell  = melee
        if GetSpellCritChance and MAX_SPELL_SCHOOLS then
            spell = GetSpellCritChance(2) or 0   -- start at Holy school
            for i = 3, MAX_SPELL_SCHOOLS do
                -- On some custom servers GetSpellCritChance returns a "secret number"
                -- that is truthy but throws on any comparison — guard each compare.
                local sc = GetSpellCritChance(i)
                local ok, less = pcall(function() return sc and sc < spell end)
                if ok and less then spell = sc end
            end
        end
        local bestOk, best = pcall(function()
            local b = melee
            if ranged > b then b = ranged end
            if spell  > b then b = spell  end
            return b
        end)
        if not bestOk then best = melee end
        return best
    end
    local crit = safeCall(computeCrit) or 0

    local haste = safeCall(GetHaste) or 0

    -- GetMasteryEffect() = the spec-specific mastery effect % shown on the panel
    -- (e.g. 16.25%); GetMastery() is the generic coefficient and mismatches it.
    local mastery = safeCall(GetMasteryEffect) or safeCall(GetMastery) or 0

    -- Versatility panel % = rating-derived bonus + flat (talent/buff) versatility bonus.
    -- 加法 fromRating + fromBonus 若任一为 secret 也会抛，故整段放进 safeCall 内。
    local function computeVersatility()
        if not CR_VERSATILITY_DAMAGE_DONE then return 0 end
        local fromRating = GetCombatRatingBonus and (GetCombatRatingBonus(CR_VERSATILITY_DAMAGE_DONE) or 0) or 0
        local fromBonus  = GetVersatilityBonus and (GetVersatilityBonus(CR_VERSATILITY_DAMAGE_DONE) or 0) or 0
        return fromRating + fromBonus
    end
    local versatility = safeCall(computeVersatility) or 0

    return {
        crit        = scrubNum(crit, 0),
        haste       = scrubNum(haste, 0),
        mastery     = scrubNum(mastery, 0),
        versatility = scrubNum(versatility, 0),
    }
end

local function readSecondaryRatings()
    -- GetCombatRating 通常不返回 secret 值，但为稳妥起见，连同 v > 0 的比较一起放进
    -- safeCall 保护：即使某次返回 secret，整段比较被吞掉、该项回退 0，绝不崩溃。
    local function rating(...)
        if not GetCombatRating then return nil end
        local args = { ... }
        local function pick()
            for i = 1, #args do
                local ratingId = args[i]
                if ratingId then
                    local v = GetCombatRating(ratingId)
                    if v and v > 0 then return v end
                end
            end
            return 0
        end
        return scrubNum(safeCall(pick), 0)
    end

    return {
        crit = rating(CR_CRIT_MELEE, CR_CRIT_RANGED, CR_CRIT_SPELL, CR_CRIT_TAKEN_MELEE),
        haste = rating(CR_HASTE_MELEE, CR_HASTE_RANGED, CR_HASTE_SPELL, CR_HASTE),
        mastery = rating(CR_MASTERY),
        versatility = rating(CR_VERSATILITY_DAMAGE_DONE),
    }
end

local function readPrimaryStats()
    local stats = {}
    if UnitStat then
        local _, strength    = UnitStat("player", 1)
        local _, agility     = UnitStat("player", 2)
        local _, stamina     = UnitStat("player", 3)
        local _, intellect   = UnitStat("player", 4)
        stats.strength  = scrubNum(strength, 0)
        stats.agility   = scrubNum(agility, 0)
        stats.stamina   = scrubNum(stamina, 0)
        stats.intellect = scrubNum(intellect, 0)
    end
    return stats
end

local function readClass()
    local _, classFile = UnitClass("player")
    return classFile
end

local SPEC_ID_TO_KEY = {
    -- Death Knight
    [250] = "BLOOD", [251] = "FROST", [252] = "UNHOLY",
    -- Demon Hunter (1480 = 噬灭/Devourer, new 12.0 spec)
    -- 噬灭真实 specID=1480（1495 不存在——同一错误曾在数据管线修过 3ab5644，此处当时漏改，
    -- 后果：readSpec 走 name:upper() 兜底返回"噬灭"，与数据键 DEVAURER 对不上，
    -- tooltip 当前专精行消失、被归入"本职业其它专精"）
    [577] = "HAVOC", [581] = "VENGEANCE", [1480] = "DEVAURER",
    -- Druid
    [102] = "BALANCE", [103] = "FERAL", [104] = "GUARDIAN", [105] = "RESTORATION",
    -- Evoker
    [1467] = "DEVASTATION", [1468] = "PRESERVATION", [1473] = "AUGMENTATION",
    -- Hunter
    [253] = "BEASTMASTERY", [254] = "MARKSMANSHIP", [255] = "SURVIVAL",
    -- Mage
    [62] = "ARCANE", [63] = "FIRE", [64] = "FROST",
    -- Monk
    [268] = "BREWMASTER", [269] = "WINDWALKER", [270] = "MISTWEAVER",
    -- Paladin
    [65] = "HOLY", [66] = "PROTECTION", [70] = "RETRIBUTION",
    -- Priest
    [256] = "DISCIPLINE", [257] = "HOLY", [258] = "SHADOW",
    -- Rogue
    [259] = "ASSASSINATION", [260] = "OUTLAW", [261] = "SUBTLETY",
    -- Shaman
    [262] = "ELEMENTAL", [263] = "ENHANCEMENT", [264] = "RESTORATION",
    -- Warlock
    [265] = "AFFLICTION", [266] = "DEMONOLOGY", [267] = "DESTRUCTION",
    -- Warrior
    [71] = "ARMS", [72] = "FURY", [73] = "PROTECTION",
}

local function readSpec()
    local specIndex = safeCall(GetSpecialization)
    if not specIndex then return nil, nil end
    local id, name = GetSpecializationInfo(specIndex)
    return SPEC_ID_TO_KEY[id] or (name and name:upper() or nil), id
end

local function readHeroTalent()
    if not C_ClassTalents or not C_ClassTalents.GetActiveConfigID then return nil end
    local configID = C_ClassTalents.GetActiveConfigID()
    if not configID then return nil end
    if not C_Traits or not C_Traits.GetConfigInfo then return nil end
    local configInfo = safeCall(C_Traits.GetConfigInfo, configID)
    if not configInfo or not configInfo.treeIDs then return nil end
    for _, treeID in ipairs(configInfo.treeIDs) do
        local nodes = safeCall(C_Traits.GetTreeNodes, treeID)
        if nodes then
            for _, nodeID in ipairs(nodes) do
                local nodeInfo = safeCall(C_Traits.GetNodeInfo, configID, nodeID)
                if nodeInfo and nodeInfo.subTreeID and nodeInfo.activeEntry then
                    local subInfo = safeCall(C_Traits.GetSubTreeInfo, configID, nodeInfo.subTreeID)
                    if subInfo and subInfo.isActive and subInfo.name then
                        return subInfo.name
                    end
                end
            end
        end
    end
    return nil
end

function StatReader:ReadAll()
    local class = readClass()
    local specName, specId = readSpec()
    local heroTalent = readHeroTalent()
    return {
        class       = class,
        spec        = specName,
        specId      = specId,
        heroTalent  = heroTalent,
        secondary   = readSecondaryStats(),
        secondaryRating = readSecondaryRatings(),
        primary     = readPrimaryStats(),
    }
end

GearInsight.StatReader = StatReader
