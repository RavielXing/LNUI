-- =========================================================================
-- 1. SLASH COMMAND SETUP
-- =========================================================================
local ADDON_NAME = "MidnightRatings"
local CATEGORY_ID = nil
local L = MidnightRatingsLocale
local InitializeDB

-- Cached standard Lua libraries and WoW APIs for performance
local type = type
local pcall = pcall
local tonumber = tonumber
local tostring = tostring
local ipairs = ipairs
local pairs = pairs
local wipe = wipe
local string_find = string.find
local string_gsub = string.gsub
local string_format = string.format
local string_sub = string.sub
local string_match = string.match
local string_lower = string.lower
local string_len = string.len
local string_rep = string.rep
local string_trim = string.trim or function(s) return (s:gsub("^%s*(.-)%s*$", "%1")) end
local math_floor = math.floor
local math_min = math.min
local GetTime = GetTime
local InCombatLockdown = InCombatLockdown
local CreateFrame = CreateFrame

SLASH_MIDNIGHTRATINGS1 = "/mr"
SLASH_MIDNIGHTRATINGS2 = "/midnightratings"
SLASH_MIDNIGHTRATINGS3 = "/pr"
SLASH_MIDNIGHTRATINGS4 = "/percentageratings"

SlashCmdList["MIDNIGHTRATINGS"] = function(msg)
    msg = msg and string_lower(string_trim(msg)) or ""
    
    if msg == "debug" then
        print("|cffFFFC03[Percentage Ratings]|r Active Conversion Rates:")
        local temp = ACTIVE_RATES_LAST_UPDATE
        ACTIVE_RATES_LAST_UPDATE = 0 
        UpdateActiveRates()
        for _, config in ipairs(STAT_CONFIG) do
            local rate = ACTIVE_RATES[config.ID]
            if rate then
                local statName = config.Name or tostring(config.ID)
                print(string_format("  - %s: %.2f rating per 1%%", statName, rate))
            end
        end
        return
    end

    if msg == "reset" then
        MidnightRatingsDB = nil
        InitializeDB()
        ACTIVE_RATES_LAST_UPDATE = 0
        UpdateActiveRates()
        print("|cffFFFC03[Percentage Ratings]|r " .. L["RESET_SUCCESS"])
        return
    end

    if CATEGORY_ID then
        Settings.OpenToCategory(CATEGORY_ID)
    else
        print(L["ERROR_MENU_FAILED"])
        print(L["ERROR_RELOAD_SUGGEST"])
    end
end

-- =========================================================================
-- 2. CONSTANTS & DEFAULTS
-- =========================================================================
STAT_CONFIG = {
    { ID = CR_CRIT_MELEE,              Name = ITEM_MOD_CRIT_RATING_SHORT, Type="CRIT",     Rel = 1.0 },
    { ID = CR_HASTE_MELEE,             Name = ITEM_MOD_HASTE_RATING_SHORT, Type="HASTE",    Rel = 1.0 },
    { ID = CR_MASTERY,                 Name = ITEM_MOD_MASTERY_RATING_SHORT, Type="MASTERY",  Rel = 1.0 },
    { ID = CR_VERSATILITY_DAMAGE_DONE, Name = ITEM_MOD_VERSATILITY,       Type="VERS",     Rel = 1.2058 },
    { ID = CR_LIFESTEAL,               Name = STAT_LIFESTEAL,             Type="TERTIARY", Rel = 1.5000 }, 
    { ID = CR_AVOIDANCE,               Name = STAT_AVOIDANCE,             Type="TERTIARY", Rel = 0.8000 }, 
    { ID = CR_SPEED,                   Name = STAT_SPEED,                 Type="TERTIARY", Rel = 0.2500 }, 
    
    { ID = "FINESSE",                  Name = ITEM_MOD_FINESSE_SHORT,      Type="TERTIARY", StaticRate = 10 },
    { ID = "PERCEPTION",               Name = ITEM_MOD_PERCEPTION_SHORT,   Type="TERTIARY", StaticRate = 10 },
    { ID = "DEFTNESS",                 Name = ITEM_MOD_DEFTNESS_SHORT,     Type="TERTIARY", StaticRate = 3 },
    { ID = "RESOURCEFULNESS",          Name = ITEM_MOD_RESOURCEFULNESS_SHORT, Type="TERTIARY", StaticRate = 10 },
    { ID = "MULTICRAFT",               Name = ITEM_MOD_MULTICRAFT_SHORT,      Type="TERTIARY", StaticRate = 10 },
    { ID = "INGENUITY",                Name = ITEM_MOD_INGENUITY_SHORT,       Type="TERTIARY", StaticRate = 10 },
    { ID = "CRAFTING_SPEED",           Name = ITEM_MOD_CRAFTING_SPEED_SHORT,  Type="TERTIARY", StaticRate = 10 },
}

local DEFAULTS = {
    displayMode = "APPEND", 
    showRating  = false, 
    splitVersatility = false,
    enableEnchants = true,
    enableGems = true,
    enableComparison = true, 
    enableProfessions = true, 
    enableAuras = false, 
    colorMode   = "MAINTAIN", 
    customColor = {r=1, g=0.99, b=0.01, hex="fffc03"},
    statColors  = {
        CRIT    = {r=1, g=0.99, b=0.01, hex="fffc03"},
        HASTE   = {r=0.18, g=0.76, b=0.49, hex="2ec27e"},
        MASTERY = {r=0.76, g=0.18, b=0.18, hex="c22e2e"},
        VERS    = {r=0.18, g=0.55, b=0.76, hex="2e8cc2"},
        TERTIARY= {r=1, g=1, b=1, hex="ffffff"},
    },
    savedRates  = {}
}

ACTIVE_RATES = {}
local STAT_PATTERNS = {}

local SECONDARY_TERMS = {
    "maximum", "maximal", "massimo", "máximo", "max", "최대", "最大", "максимум", "limite",
    "increased", "erhöht", "augmenté", "aumentado", "aumentato", "увеличивается", "증가", "增加",
    "up to", "bis zu", "jusqu'à", "hasta", "fino a", "до"
}
local SECONDARY_PATTERNS = {}

local ENCHANT_TERMS = { "enchant", "verzaubert", "enchanté", "encantamiento", "incantamento", "чары", "마법부여", "附魔" }
local CI_SPEED = (STAT_SPEED or "Speed"):gsub("%a", function(c) return string_format("[%s%s]", string.upper(c), string.lower(c)) end)

local TIME_MASKS = {}
local MASK_IDX = 0
local STATE = {}
local PROCESSED_STATE = {}
ACTIVE_RATES_LAST_UPDATE = 0

-- PRE-COMPILED LOCALE PATTERNS (Eliminates string.lower garbage)
local CI_COMP_CHANGES, CI_COMP_REPLACE, CI_COMP_EQUIPPED
local CI_ENCHANT_MATCH, CI_AND
local CI_ENCHANT_TERMS = {}
local CI_PRIMARY_STATS = {}

local function MakeCIPattern(str)
    if not str then return "" end
    return (str:gsub("%a", function(c) return string_format("[%s%s]", string.upper(c), string.lower(c)) end))
end

-- =========================================================================
-- 3. HELPER FUNCTIONS
-- =========================================================================
local function RGBToHex(r, g, b)
    return string_format("%02x%02x%02x", math_floor(r*255+0.5), math_floor(g*255+0.5), math_floor(b*255+0.5))
end

function InitializeDB()
    if not MidnightRatingsDB then MidnightRatingsDB = CopyTable(DEFAULTS) end
    if not MidnightRatingsDB.statColors then MidnightRatingsDB.statColors = CopyTable(DEFAULTS.statColors) end
    if not MidnightRatingsDB.customColor then MidnightRatingsDB.customColor = CopyTable(DEFAULTS.customColor) end
    if not MidnightRatingsDB.savedRates then MidnightRatingsDB.savedRates = {} end
    
    for k, v in pairs(DEFAULTS) do
        if MidnightRatingsDB[k] == nil then
            MidnightRatingsDB[k] = v
        end
    end
end

-- =========================================================================
-- 3.5. SAFE COMBAT EVALUATORS (Zero-Garbage Taint Protection)
-- =========================================================================
local function SafeGetMastery()
    local _, coef = GetMasteryEffect()
    if coef and coef > 0 then return coef end
    return nil
end

local function SafeGetHaste()
    local hBonus = GetCombatRatingBonus(CR_HASTE_MELEE)
    if hBonus and hBonus > 0 then
        local sheetHaste = nil
        if GetHaste then sheetHaste = GetHaste()
        elseif GetMeleeHaste then sheetHaste = GetMeleeHaste()
        elseif UnitSpellHaste then sheetHaste = UnitSpellHaste("player") end
        
        if sheetHaste then return (100 + sheetHaste) / (100 + hBonus) end
    end
    return nil
end

local function CalcStatSafe(id, masteryCoef, hasteMult)
    local r = GetCombatRating(id)
    local b = GetCombatRatingBonus(id)
    if id == CR_MASTERY and b then b = b * masteryCoef end
    if r and b and r > 0 and b > 0 then
        local rawRate = r / b
        local effectiveRate = rawRate
        if id == CR_HASTE_MELEE then effectiveRate = rawRate / hasteMult end
        return effectiveRate, rawRate
    end
    return nil, nil
end

function UpdateActiveRates()
    local now = GetTime()
    if now - ACTIVE_RATES_LAST_UPDATE < 1.0 then return end
    ACTIVE_RATES_LAST_UPDATE = now

    local baseRate = nil
    local masteryCoefficient = 1
    local hasteMultiplier = 1
    
    local okM, mCoef = pcall(SafeGetMastery)
    if okM and mCoef then masteryCoefficient = mCoef end
    
    local okH, hMult = pcall(SafeGetHaste)
    if okH and hMult then hasteMultiplier = hMult end
    
    for _, config in ipairs(STAT_CONFIG) do
        if config.StaticRate then
            ACTIVE_RATES[config.ID] = config.StaticRate
        else
            local ok, effRate, rRate = pcall(CalcStatSafe, config.ID, masteryCoefficient, hasteMultiplier)
            
            if ok and effRate then
                ACTIVE_RATES[config.ID] = effRate
                MidnightRatingsDB.savedRates[config.ID] = effRate 
                if not baseRate and config.Rel == 1.0 and config.ID == CR_CRIT_MELEE then
                    baseRate = rRate
                end
            elseif MidnightRatingsDB.savedRates[config.ID] then
                ACTIVE_RATES[config.ID] = MidnightRatingsDB.savedRates[config.ID]
            end
        end
    end
    
    if not baseRate then 
        if ACTIVE_RATES[CR_HASTE_MELEE] then baseRate = ACTIVE_RATES[CR_HASTE_MELEE] * hasteMultiplier
        elseif ACTIVE_RATES[CR_MASTERY] then baseRate = ACTIVE_RATES[CR_MASTERY] * masteryCoefficient
        elseif ACTIVE_RATES[CR_VERSATILITY_DAMAGE_DONE] then baseRate = ACTIVE_RATES[CR_VERSATILITY_DAMAGE_DONE] / 1.2058
        else baseRate = 350 end 
    end 
    
    for _, config in ipairs(STAT_CONFIG) do
        if not config.StaticRate and not ACTIVE_RATES[config.ID] and config.Rel then
            local calcRate = baseRate * config.Rel
            if config.ID == CR_MASTERY then calcRate = calcRate / masteryCoefficient
            elseif config.ID == CR_HASTE_MELEE then calcRate = calcRate / hasteMultiplier end
            ACTIVE_RATES[config.ID] = calcRate
        end
    end
end

local function GetColorHex(statType, db, inComparisonBlock)
    if inComparisonBlock then return nil end 
    if db.colorMode == "MAINTAIN" then return nil
    elseif db.colorMode == "STAT" and db.statColors and db.statColors[statType] then return db.statColors[statType].hex
    elseif db.colorMode == "CUSTOM" and db.customColor then return db.customColor.hex
    elseif db.colorMode == "UNIFIED" then return "fffc03"
    elseif db.statColors and db.statColors.CRIT then return db.statColors.CRIT.hex
    else return "fffc03" end
end

-- =========================================================================
-- 4. TEXT INTERCEPTION LOGIC
-- =========================================================================
local function ProcessMatch(valStr, sign, prefix, suffix, space)
    local extraPunc = ""
    local lastChar = string_sub(valStr, -1)
    if lastChar == "." or lastChar == "," then
        valStr = string_sub(valStr, 1, -2)
        extraPunc = lastChar
    end

    local cleanValue = string_gsub(valStr, "[,%.]", "")
    local value = tonumber(cleanValue)
    if not value then return nil end

    local percent = value / STATE.rate
    local colorHex = GetColorHex(STATE.type, STATE.db, STATE.inComp)
    local valContent = (STATE.type == "VERS" and STATE.db.splitVersatility) and string_format("%.2f%%/%.2f%%", percent, percent / 2) or string_format("%.2f%%", percent)
    
    local rPer, aPer = "", ""

    if colorHex then
        rPer = string_format("|cff%s%s%s|r", colorHex, sign or "", valContent)
        aPer = string_format("|cff%s%s%s|r", colorHex, sign == "-" and "-" or "", valContent)
        prefix, suffix = "", ""
    else
        rPer = (sign or "") .. valContent
        aPer = (sign == "-" and "-" or "") .. valContent
    end

    if STATE.db.displayMode == "REPLACE" then
        local rSuf = STATE.db.showRating and string_format(" (%s)", valStr) or ""
        return string_format("%s%s%s%s%s%s%s", prefix or "", rPer, suffix or "", space or " ", STATE.name, rSuf, extraPunc)
    else
        return string_format("%s%s%s%s%s%s (%s)%s", prefix or "", sign or "", valStr, suffix or "", space or " ", STATE.name, aPer, extraPunc)
    end
end

local function ProcessMatchReverse(valStr, sign, cStart, cEnd, statMatched, bySpace, afterChar, space)
    if type(afterChar) == "string" and (string_sub(afterChar, 1, 1) == "%" or string_sub(afterChar, 1, 1) == "(") then
        return statMatched .. bySpace .. (cStart or "") .. (sign or "") .. valStr .. (cEnd or "") .. (space or "") .. afterChar
    end

    local lSpace = string_lower(bySpace)
    if string_len(lSpace) > 40 or string_find(lSpace, ",") or string_find(lSpace, "/") or string_find(lSpace, " or ") or string_find(lSpace, " and ") or string_find(lSpace, " oder ") or string_find(lSpace, " und ") or string_find(lSpace, " ou ") or string_find(lSpace, " o ") then
        return statMatched .. bySpace .. (cStart or "") .. (sign or "") .. valStr .. (cEnd or "") .. (space or "") .. afterChar
    end

    local extraPunc = ""
    local lastChar = string_sub(valStr, -1)
    if lastChar == "." or lastChar == "," then
        valStr = string_sub(valStr, 1, -2)
        extraPunc = lastChar
    end

    local cleanValue = string_gsub(valStr, "[,%.]", "")
    local value = tonumber(cleanValue)
    if not value then return statMatched .. bySpace .. (cStart or "") .. (sign or "") .. valStr .. extraPunc .. (cEnd or "") .. (space or "") .. afterChar end

    local percent = value / STATE.rate
    local colorHex = GetColorHex(STATE.type, STATE.db, STATE.inComp)
    local valContent = (STATE.type == "VERS" and STATE.db.splitVersatility) and string_format("%.2f%%/%.2f%%", percent, percent / 2) or string_format("%.2f%%", percent)
    
    local rPer, aPer = "", ""

    if colorHex then
        rPer = string_format("|cff%s%s%s|r", colorHex, sign or "", valContent)
        aPer = string_format("|cff%s%s%s|r", colorHex, sign == "-" and "-" or "", valContent)
        cStart, cEnd = "", ""
    else
        rPer = (sign or "") .. valContent
        aPer = (sign == "-" and "-" or "") .. valContent
    end

    if STATE.db.displayMode == "REPLACE" then
        local rSuf = STATE.db.showRating and string_format(" (%s)", valStr) or ""
        return string_format("%s%s%s%s%s%s%s%s%s", statMatched, bySpace, cStart or "", rPer, cEnd or "", rSuf, extraPunc, space or "", afterChar or "")
    else
        return string_format("%s%s%s%s%s%s (%s)%s%s%s", statMatched, bySpace, cStart or "", sign or "", valStr, cEnd or "", aPer, extraPunc, space or "", afterChar or "")
    end
end

-- Static Pattern Replacers
local function repPat1(leadSpace, cStart, sign, valStr, cEnd, space) STATE.changed = true; return leadSpace .. ProcessMatch(valStr, sign, cStart, cEnd, space) end
local function repPat2(leadSpace, sign, cStart, valStr, cEnd, space) STATE.changed = true; return leadSpace .. ProcessMatch(valStr, sign, cStart, cEnd, space) end
local function repPat3(leadSpace, sign, valStr, space) STATE.changed = true; return leadSpace .. ProcessMatch(valStr, sign, "", "", space) end
local function repPat4(statMatched, bySpace, sign, valStr, space, afterChar) STATE.changed = true; return ProcessMatchReverse(valStr, sign, "", "", statMatched, bySpace, afterChar, space) end
local function repPat5(statMatched, bySpace, cStart, sign, valStr, cEnd, space, afterChar) STATE.changed = true; return ProcessMatchReverse(valStr, sign, cStart, cEnd, statMatched, bySpace, afterChar, space) end
local function repPat6(statMatched, bySpace, sign, cStart, valStr, cEnd, space, afterChar) STATE.changed = true; return ProcessMatchReverse(valStr, sign, cStart, cEnd, statMatched, bySpace, afterChar, space) end
local function repPat7(leadSpace, cStart, sign, valStr, space1, space2, cEnd)
    STATE.changed = true
    
    local extraPunc = ""
    local lastChar = string_sub(valStr, -1)
    if lastChar == "." or lastChar == "," then
        valStr = string_sub(valStr, 1, -2)
        extraPunc = lastChar
    end
    
    local cleanValue = string_gsub(valStr, "[,%.]", "")
    local value = tonumber(cleanValue)
    if not value then return nil end
    local percent = value / STATE.rate
    local colorHex = GetColorHex(STATE.type, STATE.db, STATE.inComp)
    local valContent = (STATE.type == "VERS" and STATE.db.splitVersatility) and string_format("%.2f%%/%.2f%%", percent, percent / 2) or string_format("%.2f%%", percent)
    
    if STATE.db.displayMode == "REPLACE" then
        local rSuf = STATE.db.showRating and string_format(" (%s)", valStr) or ""
        if colorHex then return string_format("%s|cff%s%s%s%s%s%s|r%s%s", leadSpace, colorHex, sign or "", valContent, space1, STATE.name, rSuf, extraPunc, space2)
        else return string_format("%s%s%s%s%s%s%s%s%s%s", leadSpace, cStart, sign or "", valContent, space1, STATE.name, rSuf, extraPunc, space2, cEnd) end
    else
        local aPer = colorHex and string_format("|cff%s%s%s|r", colorHex, sign == "-" and "-" or "", valContent) or ((sign == "-" and "-" or "") .. valContent)
        return string_format("%s%s%s%s%s%s%s (%s)%s%s", leadSpace, cStart, sign or "", valStr, space1, STATE.name, space2, aPer, extraPunc, cEnd)
    end
end

-- Secondary Pass Replacer (For Scaling & Trinket Texts)
local function repSecondaryPat(term, space1, valStr, space2, trailingChar)
    if trailingChar == "%" or trailingChar == "|" or trailingChar == "(" or trailingChar == ")" then 
        return term .. space1 .. valStr .. space2 .. trailingChar 
    end
    
    local extraPunc = ""
    local lastChar = string_sub(valStr, -1)
    if lastChar == "." or lastChar == "," then
        valStr = string_sub(valStr, 1, -2)
        extraPunc = lastChar
    end
    
    local cleanValue = string_gsub(valStr, "[,%.]", "")
    local value = tonumber(cleanValue)
    if not value then return term .. space1 .. valStr .. extraPunc .. space2 .. trailingChar end
    
    STATE.changed = true
    local percent = value / STATE.rate
    local colorHex = GetColorHex(STATE.type, STATE.db, STATE.inComp)
    local valContent = (STATE.type == "VERS" and STATE.db.splitVersatility) and string_format("%.2f%%/%.2f%%", percent, percent / 2) or string_format("%.2f%%", percent)
    
    local aPer
    if colorHex then
        aPer = string_format("|cff%s%s|r", colorHex, valContent)
    else
        aPer = valContent
    end

    if STATE.db.displayMode == "REPLACE" then
        local rSuf = STATE.db.showRating and string_format(" (%s)", valStr) or ""
        return term .. space1 .. aPer .. rSuf .. extraPunc .. space2 .. trailingChar
    else
        return string_format("%s%s%s (%s)%s%s%s", term, space1, valStr, aPer, extraPunc, space2, trailingChar)
    end
end

-- Static Masks: Non-Numeric Infinite Placeholder Logic
local function applyTimeMask(res)
    MASK_IDX = MASK_IDX + 1
    local t = "{M" .. string_rep("X", MASK_IDX) .. "}"
    TIME_MASKS[t] = res
    return t
end

local function speedRep(l, w, s, n, r) return applyTimeMask(l .. w .. s .. n .. r) end
local function tRep1(c1, num, c2, space, word) return applyTimeMask(c1 .. num .. c2 .. space .. word) end
local function tRep2(c1, num, space, word, c2) return applyTimeMask(c1 .. num .. space .. word .. c2) end
local function tRep3(num, space, word) return applyTimeMask(num .. space .. word) end
local function tRepSingle(num, space, word, trail) return applyTimeMask(num .. space .. word) .. trail end

local function pStatRep1(s, space, num) return applyTimeMask(s .. space .. num) end
local function pStatRep2(num, space, s) return applyTimeMask(num .. space .. s) end

local maskPatterns = {
    "[Ss][Ee][KkCcGg][A-Za-z]*%.?", 
    "[Mm][Ii][Nn][A-Za-z]*%.?", 
    "[Hh][Rr][Ss]?[A-Za-z]*%.?", 
    "[Hh][Oo][A-Za-z]*%.?", 
    "[Ss][Tt][Uu][Nn][A-Za-z]*%.?", 
    "[Ss][Tt][Dd][A-Za-z]*%.?", 
    "[Dd][Aa][Yy][Ss]?%.?", 
    "[Tt][Aa][Gg][Ee]?%.?", 
    "[Tt][Ii][Mm][Ee][Ss]?", 
    "[Mm][Aa][Ll]%.?", 
    "[Ss][Tt][Aa][Cc][Kk][Ss]?", 
    "[Aa][Uu][Ff][Ll][Aa][Dd][A-Za-z]*%.?", 
    "[Ss][Tt][Aa][Pp][Ee][Ll][Nn]?%.?",
}

local function ProcessText(text, isGreen, db, inComparisonBlock, isAura)
    local isEnchant = false
    
    if CI_ENCHANT_MATCH and string_find(text, CI_ENCHANT_MATCH) then
        isEnchant = true
    else
        for _, term in ipairs(CI_ENCHANT_TERMS) do
            if string_find(text, term) then
                isEnchant = true
                break
            end
        end
    end

    local isDualStat = string_find(text, CI_AND) and string_find(text, "%+")
    local isGemLine = ((not isGreen and string_find(text, "%+")) or isDualStat) and (not isEnchant)
    local isProfession = string_find(text, ITEM_MOD_FINESSE_SHORT) or string_find(text, ITEM_MOD_PERCEPTION_SHORT) or string_find(text, ITEM_MOD_DEFTNESS_SHORT) or string_find(text, ITEM_MOD_RESOURCEFULNESS_SHORT) or string_find(text, ITEM_MOD_MULTICRAFT_SHORT) or string_find(text, ITEM_MOD_INGENUITY_SHORT) or string_find(text, ITEM_MOD_CRAFTING_SPEED_SHORT)
    
    if isEnchant and not db.enableEnchants then return text, false end
    if isGemLine and not db.enableGems then return text, false end
    if inComparisonBlock and not db.enableComparison then return text, false end
    if isProfession and not db.enableProfessions then return text, false end

    local newText = text
    
    STATE.changed = false
    STATE.db = db
    STATE.inComp = inComparisonBlock
    MASK_IDX = 0
    wipe(TIME_MASKS)

    -- WEAPON SPEED MASK
    newText = string_gsub(newText, "^([%s\194\160]*)(" .. CI_SPEED .. ")([:%s\194\160]+)(%d+[%.,]%d+)([%s\194\160]*)$", speedRep)

    -- SINGLE LETTER TIME MASK
    newText = string_gsub(newText, "(%d+)([%s\194\160]*)([sSmMhHdD])([%s%p])", tRepSingle)
    newText = string_gsub(newText, "(%d+)([%s\194\160]*)([sSmMhHdD])$", function(n, s, w) 
        return applyTimeMask(n .. s .. w) 
    end)

    -- STANDARD TIME & STACK MASKS
    for _, tWord in ipairs(maskPatterns) do
        newText = string_gsub(newText, "(|c%x%x%x%x%x%x%x%x)(%d+)(|r)([%s\194\160]*)(" .. tWord .. ")", tRep1)
        newText = string_gsub(newText, "(|c%x%x%x%x%x%x%x%x)(%d+)([%s\194\160]*)(" .. tWord .. ")(|r)", tRep2)
        newText = string_gsub(newText, "(%d+)([%s\194\160]*)(" .. tWord .. ")", tRep3)
    end

    -- PRIMARY STAT MASKS (Protects base stats from promiscuous secondary term regexes)
    for _, pStat in ipairs(CI_PRIMARY_STATS) do
        newText = string_gsub(newText, "(" .. pStat .. ")([^%d%.%,|%+%-%%]-)(%d[%d,%.]*)", pStatRep1)
        newText = string_gsub(newText, "(%d[%d,%.]*)([^%d%.%,|%+%-%%]-)(" .. pStat .. ")", pStatRep2)
    end

    for _, config in ipairs(STAT_CONFIG) do
        local rate = ACTIVE_RATES[config.ID]
        local pats = STAT_PATTERNS[config.ID]

        if rate and pats and config.ciSafe and string_find(newText, config.ciSafe) then
            local alreadyDone = string_find(newText, config.ciSafe .. " %(") or string_find(newText, "%%|r " .. config.ciSafe) or string_find(newText, "%% " .. config.ciSafe)
            
            STATE.rate = rate
            STATE.type = config.Type
            STATE.name = config.Name
            
            if not alreadyDone then
                local preText = newText
                newText = string_gsub(newText, pats.pat1, repPat1)
                if newText == preText then newText = string_gsub(newText, pats.pat2, repPat2) end
                if newText == preText then newText = string_gsub(newText, pats.pat3, repPat3) end
                if newText == preText then newText = string_gsub(newText, pats.pat4, repPat4) end
                if newText == preText then newText = string_gsub(newText, pats.pat5, repPat5) end
                if newText == preText then newText = string_gsub(newText, pats.pat6, repPat6) end
                if newText == preText then newText = string_gsub(newText, pats.pat7, repPat7) end
            end
            
            for _, secPat in ipairs(SECONDARY_PATTERNS) do
                newText = string_gsub(newText, secPat, repSecondaryPat)
            end
        end
    end
    
    if MASK_IDX > 0 then
        newText = string_gsub(newText, "%{MX+%}", TIME_MASKS)
    end
    
    return newText, STATE.changed
end

-- =========================================================================
-- 5. OPTIONS PANEL (LAZY-LOADED)
-- =========================================================================
local function BuildOptionsUI(panel)
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(L["PANEL_TITLE"])

    local function SafeSetText(cb, text)
        if not cb.Text then
            cb.Text = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            cb.Text:SetPoint("LEFT", cb, "RIGHT", 5, 0)
        end
        cb.Text:SetText(text)
    end

    local function MakeCheckbox(label, key, parent, anchor, xOffset, yOffset)
        local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", xOffset or 0, yOffset or -5)
        SafeSetText(cb, label)
        cb:SetChecked(MidnightRatingsDB[key])
        cb:SetScript("OnClick", function(self) MidnightRatingsDB[key] = self:GetChecked() end)
        return cb
    end

    local function MakeColorSwatch(parent, dbKey, subKey, defR, defG, defB)
        local frame = CreateFrame("Button", nil, parent)
        frame:SetSize(20, 20)
        frame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        
        local tex = frame:CreateTexture(nil, "OVERLAY")
        tex:SetAllPoints()
        local cData = subKey and MidnightRatingsDB[dbKey][subKey] or MidnightRatingsDB[dbKey]
        tex:SetColorTexture(cData.r, cData.g, cData.b)
        frame:SetNormalTexture(tex)

        local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("LEFT", frame, "RIGHT", 5, 0)

        frame:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(L["COLOR_TOOLTIP_TITLE"])
            GameTooltip:AddLine(L["COLOR_TOOLTIP_LEFT"], 1, 1, 1)
            GameTooltip:AddLine(L["COLOR_TOOLTIP_RIGHT"], 1, 0.82, 0)
            GameTooltip:Show()
        end)
        
        frame:SetScript("OnLeave", function() GameTooltip:Hide() end)

        frame:SetScript("OnClick", function(self, button)
            local targetData = subKey and MidnightRatingsDB[dbKey][subKey] or MidnightRatingsDB[dbKey]
            if button == "RightButton" then
                targetData.r, targetData.g, targetData.b = defR, defG, defB
                targetData.hex = RGBToHex(defR, defG, defB)
                tex:SetColorTexture(defR, defG, defB)
            else
                local info = {}
                info.r, info.g, info.b = targetData.r, targetData.g, targetData.b
                info.swatchFunc = function()
                    local r, g, b = ColorPickerFrame:GetColorRGB()
                    targetData.r, targetData.g, targetData.b = r, g, b
                    targetData.hex = RGBToHex(r, g, b)
                    tex:SetColorTexture(r, g, b)
                end
                info.cancelFunc = function(prev)
                    targetData.r, targetData.g, targetData.b = prev.r, prev.g, prev.b
                    targetData.hex = RGBToHex(prev.r, prev.g, prev.b)
                    tex:SetColorTexture(prev.r, prev.g, prev.b)
                end
                ColorPickerFrame:SetupColorPickerAndShow(info)
            end
        end)
        return frame, text
    end

    local lblDisplay = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    lblDisplay:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -20)
    lblDisplay:SetText(L["DISPLAY_OPTIONS"])

    local cbAppend = CreateFrame("CheckButton", nil, panel, "UIRadioButtonTemplate")
    cbAppend:SetPoint("TOPLEFT", lblDisplay, "BOTTOMLEFT", 10, -10)
    SafeSetText(cbAppend, L["APPEND_MODE"])
    
    local cbReplace = CreateFrame("CheckButton", nil, panel, "UIRadioButtonTemplate")
    cbReplace:SetPoint("TOPLEFT", cbAppend, "BOTTOMLEFT", 0, -5)
    SafeSetText(cbReplace, L["REPLACE_MODE"])

    local function RefreshRadios()
        cbAppend:SetChecked(MidnightRatingsDB.displayMode == "APPEND")
        cbReplace:SetChecked(MidnightRatingsDB.displayMode == "REPLACE")
    end

    cbAppend:SetScript("OnClick", function() MidnightRatingsDB.displayMode = "APPEND"; RefreshRadios() end)
    cbReplace:SetScript("OnClick", function() MidnightRatingsDB.displayMode = "REPLACE"; RefreshRadios() end)
    RefreshRadios()

    local cbShowRating = MakeCheckbox(L["SHOW_RATING"], "showRating", panel, cbReplace, 0, -5)
    local cbVers = MakeCheckbox(L["SPLIT_VERS"], "splitVersatility", panel, cbShowRating, 0, -5)

    local lblConv = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    lblConv:SetPoint("TOPLEFT", cbVers, "BOTTOMLEFT", -10, -20)
    lblConv:SetText(L["CONVERSION_FILTERS"])

    local cbEnchants = MakeCheckbox(L["ENABLE_ENCHANTS"], "enableEnchants", panel, lblConv, 10, -10)
    local cbGems = MakeCheckbox(L["ENABLE_GEMS"], "enableGems", panel, cbEnchants, 0, -5)
    local cbCompare = MakeCheckbox(L["ENABLE_COMPARISON"], "enableComparison", panel, cbGems, 0, -5)
    local cbProfs = MakeCheckbox(L["ENABLE_PROFESSIONS"], "enableProfessions", panel, cbCompare, 0, -5)
    local cbAuras = MakeCheckbox(L["ENABLE_AURAS"], "enableAuras", panel, cbProfs, 0, -5)

    local lblColor = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    lblColor:SetPoint("TOPLEFT", cbAuras, "BOTTOMLEFT", -10, -20)
    lblColor:SetText(L["COLOR_SETTINGS"])

    local cbColorMaintain = CreateFrame("CheckButton", nil, panel, "UIRadioButtonTemplate")
    cbColorMaintain:SetPoint("TOPLEFT", lblColor, "BOTTOMLEFT", 10, -10)
    SafeSetText(cbColorMaintain, L["COLOR_MAINTAIN"])

    local cbColorUnified = CreateFrame("CheckButton", nil, panel, "UIRadioButtonTemplate")
    cbColorUnified:SetPoint("TOPLEFT", cbColorMaintain, "BOTTOMLEFT", 0, -5)
    SafeSetText(cbColorUnified, L["COLOR_UNIFIED"])

    local cbColorCustom = CreateFrame("CheckButton", nil, panel, "UIRadioButtonTemplate")
    cbColorCustom:SetPoint("TOPLEFT", cbColorUnified, "BOTTOMLEFT", 0, -5)
    SafeSetText(cbColorCustom, L["COLOR_CUSTOM"])

    local sCustom, tCustom = MakeColorSwatch(panel, "customColor", nil, DEFAULTS.customColor.r, DEFAULTS.customColor.g, DEFAULTS.customColor.b)
    tCustom:SetText("")
    sCustom:SetPoint("LEFT", cbColorCustom, "RIGHT", 100, 0)

    local cbColorStat = CreateFrame("CheckButton", nil, panel, "UIRadioButtonTemplate")
    cbColorStat:SetPoint("TOPLEFT", cbColorCustom, "BOTTOMLEFT", 0, -5)
    SafeSetText(cbColorStat, L["COLOR_STAT"])

    local sCrit, tCrit = MakeColorSwatch(panel, "statColors", "CRIT", DEFAULTS.statColors.CRIT.r, DEFAULTS.statColors.CRIT.g, DEFAULTS.statColors.CRIT.b)
    tCrit:SetText(STAT_CRITICAL_STRIKE)
    sCrit:SetPoint("TOPLEFT", cbColorStat, "BOTTOMLEFT", 20, -5)

    local sHaste, tHaste = MakeColorSwatch(panel, "statColors", "HASTE", DEFAULTS.statColors.HASTE.r, DEFAULTS.statColors.HASTE.g, DEFAULTS.statColors.HASTE.b)
    tHaste:SetText(STAT_HASTE)
    sHaste:SetPoint("LEFT", tCrit, "RIGHT", 15, 0)

    local sMastery, tMastery = MakeColorSwatch(panel, "statColors", "MASTERY", DEFAULTS.statColors.MASTERY.r, DEFAULTS.statColors.MASTERY.g, DEFAULTS.statColors.MASTERY.b)
    tMastery:SetText(STAT_MASTERY)
    sMastery:SetPoint("LEFT", tHaste, "RIGHT", 15, 0)

    local sVers, tVers = MakeColorSwatch(panel, "statColors", "VERS", DEFAULTS.statColors.VERS.r, DEFAULTS.statColors.VERS.g, DEFAULTS.statColors.VERS.b)
    tVers:SetText(STAT_VERSATILITY)
    sVers:SetPoint("TOPLEFT", sCrit, "BOTTOMLEFT", 0, -10)

    local sTert, tTert = MakeColorSwatch(panel, "statColors", "TERTIARY", DEFAULTS.statColors.TERTIARY.r, DEFAULTS.statColors.TERTIARY.g, DEFAULTS.statColors.TERTIARY.b)
    tTert:SetText(L["STAT_TERTIARY"])
    sTert:SetPoint("LEFT", tVers, "RIGHT", 15, 0)

    local function RefreshColorRadios()
        local mode = MidnightRatingsDB.colorMode
        cbColorMaintain:SetChecked(mode == "MAINTAIN")
        cbColorStat:SetChecked(mode == "STAT")
        cbColorUnified:SetChecked(mode == "UNIFIED")
        cbColorCustom:SetChecked(mode == "CUSTOM")
        
        if mode == "STAT" then
            sCrit:Show(); sHaste:Show(); sMastery:Show(); sVers:Show(); sTert:Show()
        else
            sCrit:Hide(); sHaste:Hide(); sMastery:Hide(); sVers:Hide(); sTert:Hide()
        end
        if mode == "CUSTOM" then sCustom:Show() else sCustom:Hide() end
    end

    cbColorMaintain:SetScript("OnClick", function() MidnightRatingsDB.colorMode = "MAINTAIN"; RefreshColorRadios() end)
    cbColorStat:SetScript("OnClick", function() MidnightRatingsDB.colorMode = "STAT"; RefreshColorRadios() end)
    cbColorUnified:SetScript("OnClick", function() MidnightRatingsDB.colorMode = "UNIFIED"; RefreshColorRadios() end)
    cbColorCustom:SetScript("OnClick", function() MidnightRatingsDB.colorMode = "CUSTOM"; RefreshColorRadios() end)
    RefreshColorRadios()
end

-- =========================================================================
-- 6. LOADER & NATIVE PROCESSOR
-- =========================================================================
local ALLOWED_TOOLTIPS = {
    ["GameTooltip"] = true,
    ["ItemRefTooltip"] = true,
    ["ShoppingTooltip1"] = true,
    ["ShoppingTooltip2"] = true,
    ["ItemRefShoppingTooltip1"] = true,
    ["ItemRefShoppingTooltip2"] = true,
    ["WorldMapTooltip"] = true,
    ["WorldMapCompareTooltip1"] = true,
    ["WorldMapCompareTooltip2"] = true,
    ["ItemSocketingDescription"] = true,
    ["ProfessionsRecipeTooltip"] = true, 
    ["EmbeddedItemTooltip"] = true,       
    ["RecipeTooltip"] = true,             
}

local function GetTooltipNameSafe(tooltip)
    if tooltip == GameTooltip then return "GameTooltip" end
    if tooltip == ItemRefTooltip then return "ItemRefTooltip" end
    if tooltip == ShoppingTooltip1 then return "ShoppingTooltip1" end
    if tooltip == ShoppingTooltip2 then return "ShoppingTooltip2" end
    if tooltip == ItemRefShoppingTooltip1 then return "ItemRefShoppingTooltip1" end
    if tooltip == ItemRefShoppingTooltip2 then return "ItemRefShoppingTooltip2" end
    if tooltip == EmbeddedItemTooltip then return "EmbeddedItemTooltip" end
    if tooltip == WorldMapTooltip then return "WorldMapTooltip" end
    if tooltip == WorldMapCompareTooltip1 then return "WorldMapCompareTooltip1" end
    if tooltip == WorldMapCompareTooltip2 then return "WorldMapCompareTooltip2" end
    if tooltip == ItemSocketingDescription then return "ItemSocketingDescription" end
    if tooltip == ProfessionsRecipeTooltip then return "ProfessionsRecipeTooltip" end
    if tooltip == RecipeTooltip then return "RecipeTooltip" end
    
    if tooltip.GetName then
        local ok, name = pcall(tooltip.GetName, tooltip)
        if ok and type(name) == "string" then return name end
    end
    return nil
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_LOGIN")

loader:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then InitializeDB() end
    if event == "PLAYER_LOGIN" then
        InitializeDB()
        
        CI_COMP_CHANGES  = MakeCIPattern(L["COMPARISON_CHANGES"])
        CI_COMP_REPLACE  = MakeCIPattern(L["COMPARISON_REPLACE"])
        CI_COMP_EQUIPPED = MakeCIPattern(L["COMPARISON_EQUIPPED"])
        CI_ENCHANT_MATCH = MakeCIPattern(L["ENCHANT_MATCH"])
        CI_AND           = MakeCIPattern(L["AND"])

        for _, term in ipairs(ENCHANT_TERMS) do
            table.insert(CI_ENCHANT_TERMS, MakeCIPattern(term))
        end

        local pStats = {
            STAT_STAMINA, STAT_STRENGTH, STAT_AGILITY, STAT_INTELLECT, STAT_ARMOR, ARMOR, HEALTH, MANA,
            ITEM_MOD_STAMINA_SHORT, ITEM_MOD_STRENGTH_SHORT, ITEM_MOD_AGILITY_SHORT, ITEM_MOD_INTELLECT_SHORT
        }
        local seenStats = {}
        for _, p in ipairs(pStats) do
            if p and not seenStats[p] then
                seenStats[p] = true
                local safe = p:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
                local ciSafe = safe:gsub("%a", function(c) return string_format("[%s%s]", string.upper(c), string.lower(c)) end)
                table.insert(CI_PRIMARY_STATS, ciSafe)
            end
        end

        for _, config in ipairs(STAT_CONFIG) do
            local statName = config.Name
            if statName then
                local safe = statName:gsub("-", "%%-")
                local ciSafe = safe:gsub("%a", function(c) return string_format("[%s%s]", string.upper(c), string.lower(c)) end)
                
                ciSafe = ciSafe:gsub("%[Ee%]%[Rr%]([%s\194\160]+)", "[Ee][NnRrSsMm]*%1")
                ciSafe = ciSafe:gsub("%[Ee%]%[Rr%]$", "[Ee][NnRrSsMm]*")
                ciSafe = ciSafe:gsub("%[Ee%]%[Ss%]([%s\194\160]+)", "[Ee][NnRrSsMm]*%1")
                ciSafe = ciSafe:gsub("%[Ee%]%[Ss%]$", "[Ee][NnRrSsMm]*")

                config.ciSafe = ciSafe
                
                STAT_PATTERNS[config.ID] = {
                    pat1 = "([%s\194\160]*)(|c%x%x%x%x%x%x%x%x)[%s\194\160]*([%+%-]?)[%s\194\160]*(%d[%d,%.]*)[%s\194\160]*(|r)([%s\194\160]*)" .. ciSafe,
                    pat2 = "([%s\194\160]*)([%+%-]?)[%s\194\160]*(|c%x%x%x%x%x%x%x%x)[%s\194\160]*(%d[%d,%.]*)[%s\194\160]*(|r)([%s\194\160]*)" .. ciSafe,
                    pat3 = "([%s\194\160]*)([%+%-]?)[%s\194\160]*(%d[%d,%.]*)([%s\194\160]*)" .. ciSafe,
                    pat4 = "(" .. ciSafe .. ")([^%d%.%,|%+%-]+)([%+%-]?)(%d[%d,%.]*)([%s\194\160]*)(%S*)",
                    pat5 = "(" .. ciSafe .. ")([^%d%.%,|%+%-]+)(|c%x%x%x%x%x%x%x%x)[%s\194\160]*([%+%-]?)[%s\194\160]*(%d[%d,%.]*)[%s\194\160]*(|r)([%s\194\160]*)(%S*)",
                    pat6 = "(" .. ciSafe .. ")([^%d%.%,|%+%-]+)([%+%-]?)(|c%x%x%x%x%x%x%x%x)[%s\194\160]*(%d[%d,%.]*)[%s\194\160]*(|r)([%s\194\160]*)(%S*)",
                    pat7 = "([%s\194\160]*)(|c%x%x%x%x%x%x%x%x)[%s\194\160]*([%+%-]?)[%s\194\160]*(%d[%d,%.]*)([%s\194\160]*)" .. ciSafe .. "([%s\194\160]*)(|r)",
                }
            end
        end

        for _, term in ipairs(SECONDARY_TERMS) do
            local safe = term:gsub("%-", "%%-")
            local ciSafe = safe:gsub("%a", function(c) return string_format("[%s%s]", string.upper(c), string.lower(c)) end)
            table.insert(SECONDARY_PATTERNS, "(" .. ciSafe .. ")([^%d%.%,|%+%-%%]-)(%d[%d,%.]*)([%s\194\160]*)(.?)")
        end

        pcall(function()
            local panel = CreateFrame("Frame", "MidnightRatingsOptionsPanel", nil)
            panel.isLoaded = false
            panel:SetScript("OnShow", function(self)
                if not self.isLoaded then
                     BuildOptionsUI(self)
                     self.isLoaded = true
                end
            end)
            
            local category = Settings.RegisterCanvasLayoutCategory(panel, "Percentage Ratings")
            Settings.RegisterAddOnCategory(category)
            CATEGORY_ID = category.ID
        end)
    end
end)

local function SafeStringCheck(text, pattern)
    if type(text) ~= "string" or not pattern or pattern == "" or not pcall(string_len, text) then return false end
    return string_find(text, pattern) ~= nil
end

local function IsValidStatText(text)
    return type(text) == "string" and pcall(string_len, text) and string_find(text, "%d") ~= nil
end

local function _doIsGreen(fs)
    local r, g, b = fs:GetTextColor()
    return (r and g and b) and ((g > r + 0.2) and (g > b + 0.2)) or false
end

local function SafeIsGreen(fs)
    if not fs or not fs.GetTextColor then return false end
    local ok, result = pcall(_doIsGreen, fs)
    return ok and result
end

local function SafeGetText(fs, lineIndex, isRight, tooltipData, cachedText)
    if not fs or not fs.GetText then return nil end
    local text = fs:GetText()
    
    -- Verify it is a valid, manipulatable string BEFORE any comparisons to avoid taint
    local isRealString = false
    if type(text) == "string" then
        isRealString = pcall(string_len, text)
    end

    -- The 'not isRealString' causes Lua to short-circuit, safely skipping the 'text == ""' comparison if it's a secret string
    if not isRealString or text == "" then
        if tooltipData and tooltipData.lines and tooltipData.lines[lineIndex] then
            local lineData = tooltipData.lines[lineIndex]
            text = isRight and lineData.rightText or lineData.leftText
            
            -- Re-evaluate the new string retrieved from tooltipData
            isRealString = false
            if type(text) == "string" then
                isRealString = pcall(string_len, text)
            end
        end
    end
    
    -- Final check utilizing the same short-circuit logic
    if not isRealString or text == "" then
        return nil
    end
    
    -- If the text is identical to the cached string, return immediately to bypass validation
    if cachedText and text == cachedText then
        return text
    end
    
    return text
end

-- =========================================================================
-- FIREWALL: TALENT UI STRUCTURAL SCANNER
-- =========================================================================
local function SafeCheckTalentRank(text)
    if type(text) ~= "string" or not pcall(string_len, text) then return false end
    return string_find(text, "^Ran[gk]o? %d+/%d+") ~= nil or string_find(text, "^Grado %d+/%d+") ~= nil
end

local function IsTalentTooltip(tooltip, tooltipData)
    local currentDataType = tooltipData and tooltipData.type
    if currentDataType and Enum.TooltipDataType then
        if (Enum.TooltipDataType.Trait and currentDataType == Enum.TooltipDataType.Trait) or
           (Enum.TooltipDataType.PvpTrait and currentDataType == Enum.TooltipDataType.PvpTrait) then
            return true
        end
    end

    if tooltip and tooltip.GetOwner then
        local okOwner, owner = pcall(tooltip.GetOwner, tooltip)
        if okOwner and owner then
            local current = owner
            for i = 1, 15 do
                if not current then break end
                local okName, name = pcall(current.GetName, current)
                if okName and type(name) == "string" then
                    local okLower, lowerName = pcall(string_lower, name)
                    if okLower and type(lowerName) == "string" then
                        if string_find(lowerName, "talent") or 
                           string_find(lowerName, "trait") or 
                           string_find(lowerName, "herospec") or 
                           string_find(lowerName, "playerspell") then
                            return true
                        end
                    end
                end
                local okParent, parent = pcall(current.GetParent, current)
                if okParent then current = parent else break end
            end
        end
    end

    if tooltipData and tooltipData.lines then
        for i = 1, math_min(3, #tooltipData.lines) do
            local lineData = tooltipData.lines[i]
            if lineData and SafeCheckTalentRank(lineData.leftText) then
                return true
            end
        end
    end

    return false
end

local function ProcessTooltip(tooltip, tooltipDataType)
    if not tooltip or type(tooltip) ~= "table" then return end
    
    local tooltipName = GetTooltipNameSafe(tooltip)
    if not tooltipName or not ALLOWED_TOOLTIPS[tooltipName] then return end

    local tooltipData = tooltip.GetTooltipData and tooltip:GetTooltipData() or tooltip.tooltipData

    -- STATE LOCK: Calculate the talent firewall only once per tooltip showing
    if tooltip.MR_IsTalent == nil then
        tooltip.MR_IsTalent = IsTalentTooltip(tooltip, tooltipData)
    end
    if tooltip.MR_IsTalent then return end

    local db = MidnightRatingsDB or DEFAULTS
    local currentDataType = tooltipDataType or (tooltipData and tooltipData.type)
    
    local isAura = (currentDataType == Enum.TooltipDataType.UnitAura or currentDataType == Enum.TooltipDataType.Spell or currentDataType == Enum.TooltipDataType.Macro)
    if isAura and not db.enableAuras then return end

    UpdateActiveRates()

    -- SAFE NUMBER OF LINES CHECK
    local ok, numLines = pcall(tooltip.NumLines, tooltip)
    if not ok or type(numLines) ~= "number" or numLines == 0 then return end

    -- STATIC CACHE: Build the permanent cache architecture for this specific tooltip frame
    if not tooltip.MR_Cache then
        tooltip.MR_Cache = {
            fsL = {}, fsR = {}, textL = {}, textR = {}
        }
    end
    local cache = tooltip.MR_Cache

    -- PRE-POPULATE FONTSTRINGS: Completely eliminates string concatenation garbage
    -- LAZY POPULATION: Only loop when numLines has grown beyond what was already cached.
    local cachedCount = #cache.fsL
    if numLines > cachedCount then
        for i = cachedCount + 1, numLines do
            cache.fsL[i] = _G[tooltipName .. "TextLeft" .. i]
            cache.fsR[i] = _G[tooltipName .. "TextRight" .. i]
        end
    end

    local requiresUpdate = false
    
    -- ZERO-GARBAGE FAST ABORT: If absolutely no text has mutated on the entire tooltip, 
    -- instantly abort the execution before doing any heavy processing or compLine checks.
    for i = 1, numLines do
        local tL = SafeGetText(cache.fsL[i], i, false, tooltipData, cache.textL[i])
        if (tL or "") ~= (cache.textL[i] or "") then requiresUpdate = true; break end
        
        local tR = SafeGetText(cache.fsR[i], i, true, tooltipData, cache.textR[i])
        if (tR or "") ~= (cache.textR[i] or "") then requiresUpdate = true; break end
    end

    if not requiresUpdate then return end

    -- Only calculate the comparison block line if text has actively mutated
    local compLine = nil
    for i = 1, numLines do
        local text = SafeGetText(cache.fsL[i], i, false, tooltipData, cache.textL[i])
        if text then
            if SafeStringCheck(text, CI_COMP_CHANGES) or 
               SafeStringCheck(text, CI_COMP_REPLACE) or 
               SafeStringCheck(text, CI_COMP_EQUIPPED) then
                compLine = i
                break
            end
        end
    end

    for i = 1, numLines do
        local inComparisonBlock = compLine and (i > compLine)
        
        local textL = SafeGetText(cache.fsL[i], i, false, tooltipData, cache.textL[i])
        if textL and textL ~= cache.textL[i] then
            if IsValidStatText(textL) then
                local isGreen = SafeIsGreen(cache.fsL[i])
                local newText, changed = ProcessText(textL, isGreen, db, inComparisonBlock, isAura)
                if changed and newText then 
                    cache.fsL[i]:SetText(newText)
                    cache.textL[i] = newText
                else
                    cache.textL[i] = textL
                end
            else
                cache.textL[i] = textL
            end
        end
        
        local textR = SafeGetText(cache.fsR[i], i, true, tooltipData, cache.textR[i])
        if textR and textR ~= cache.textR[i] then
            if IsValidStatText(textR) then
                local isGreen = SafeIsGreen(cache.fsR[i])
                local newText, changed = ProcessText(textR, isGreen, db, inComparisonBlock, isAura)
                if changed and newText then 
                    cache.fsR[i]:SetText(newText)
                    cache.textR[i] = newText
                else
                    cache.textR[i] = textR
                end
            else
                cache.textR[i] = textR
            end
        end
    end
end

-- =========================================================================
-- 7. DYNAMIC RENDERING ENGINE
-- =========================================================================

local function ClearTooltipState(self)
    self.MR_IsTalent = nil
    if self.MR_Cache then
        wipe(self.MR_Cache.textL)
        wipe(self.MR_Cache.textR)
    end
end

if TooltipDataProcessor then
    local function ImmediateProcess(tt, dataType)
        if tt then ProcessTooltip(tt, dataType) end
    end
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tt) ImmediateProcess(tt, Enum.TooltipDataType.Item) end)
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Recipe, function(tt) ImmediateProcess(tt, Enum.TooltipDataType.Recipe) end)
    
    -- RESTORED: UnitAura hook to globally catch buffs outside of standard GameTooltip frames.
    -- Guarded by InCombatLockdown() to permanently prevent secure nameplate taint during encounters.
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.UnitAura, function(tt) 
        if not InCombatLockdown() then ImmediateProcess(tt, Enum.TooltipDataType.UnitAura) end 
    end)
    
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Spell, function(tt) ImmediateProcess(tt, Enum.TooltipDataType.Spell) end)
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Macro, function(tt) ImmediateProcess(tt, Enum.TooltipDataType.Macro) end)
end

pcall(function()
    local tooltips = {
        GameTooltip,
        ItemRefTooltip,
        ShoppingTooltip1,
        ShoppingTooltip2,
        ItemRefShoppingTooltip1,
        ItemRefShoppingTooltip2,
        EmbeddedItemTooltip
    }
    
    for _, tt in ipairs(tooltips) do
        if tt then
            tt:HookScript("OnHide", ClearTooltipState)
            tt:HookScript("OnTooltipCleared", ClearTooltipState)
        end
    end
end)