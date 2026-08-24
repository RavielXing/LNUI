local ADDON_NAME, ItemInfoOverlay = ...

local Utils = ItemInfoOverlay:NewModule("utils")

--------------------
--- 数据库
--------------------

local BONUS_ID_DATABASE = {
    [13653] = { trackStringID = TRACK_STRING_ID_HERO, season = 34 },
    [13654] = { trackStringID = TRACK_STRING_ID_MYTH, season = 34 },
}

local DOUBLE_UNIQUENESS_DATABASE = {
    [215133] = {2, 512},
    [241140] = {2, 512},
    [251513] = {2, 512},
}

local EQUIP_LOC_CAN_ENCHANT = {
    INVTYPE_HEAD = {120, 999},
    INVTYPE_NECK = {0, 120},
    INVTYPE_SHOULDER = true,
    INVTYPE_CLOAK = {0, 170},
    INVTYPE_CHEST = true,
    INVTYPE_ROBE = true,
    INVTYPE_WRIST = {0, 170},
    INVTYPE_HAND = {0, 120},
    INVTYPE_WAIST = false,
    INVTYPE_LEGS = true,
    INVTYPE_FEET = true,
    INVTYPE_FINGER = true,
    INVTYPE_WEAPON = true,
    INVTYPE_RANGED = true,
    INVTYPE_2HWEAPON = true,
    INVTYPE_WEAPONMAINHAND = true,
    INVTYPE_WEAPONOFFHAND = true,
    INVTYPE_RANGEDRIGHT = true,
    INVTYPE_SHIELD = {0, 120},
    INVTYPE_HOLDABLE = {0, 120},
}

local SOCKET_SETTING_ITEMS = {
    [213777] = {213777, "professions"},
    [275707] = {275707, "greatVault"},
    [263897] = {263897, "greatVault"},
    [257535] = {257535, "pvp"},
}

local EQUIP_LOC_MAX_SOCKETS = {
    expansion = {
        [LE_EXPANSION_WAR_WITHIN] = {
            INVTYPE_NECK = { 2, SOCKET_SETTING_ITEMS[213777], false },
            INVTYPE_FINGER = { 2, SOCKET_SETTING_ITEMS[213777], false }
        },
    },
    season = {
        [37] = {
            minItemLevel = 266,
            INVTYPE_HEAD = { 1, SOCKET_SETTING_ITEMS[275707], SOCKET_SETTING_ITEMS[257535] },
            INVTYPE_WAIST = { 1, SOCKET_SETTING_ITEMS[275707], SOCKET_SETTING_ITEMS[257535] },
            INVTYPE_WRIST = { 1, SOCKET_SETTING_ITEMS[275707], SOCKET_SETTING_ITEMS[257535] },
        },
        [34] = {
            minItemLevel = 220,
            INVTYPE_HEAD = { 1, SOCKET_SETTING_ITEMS[263897], SOCKET_SETTING_ITEMS[257535] },
            INVTYPE_WAIST = { 1, SOCKET_SETTING_ITEMS[263897], SOCKET_SETTING_ITEMS[257535] },
            INVTYPE_WRIST = { 1, SOCKET_SETTING_ITEMS[263897], SOCKET_SETTING_ITEMS[257535] },
        }
    }
}

--------------------
--- 框体
--------------------
local INVAILD_OVERLAY = {
    SetItemFromLocation = function() end,
    SetItemFromLink = function() end
}

function Utils.GetItemInfoOverlay(frame, type)
    if type == false then
        if frame.ItemInfoOverlay then
            ItemInfoOverlay:GetModule("itemInfoOverlay"):ReleaseItemInfoOverlay(frame)
        end
        frame.ItemInfoOverlay = false
        return INVAILD_OVERLAY
    elseif frame.ItemInfoOverlay then
        if type and not frame.ItemInfoOverlay.type then
            frame.ItemInfoOverlay.type = type
        end
        if frame.ItemInfoOverlay.type == type then
            return frame.ItemInfoOverlay
        else
            return INVAILD_OVERLAY
        end
    elseif type == nil and frame.ItemInfoOverlay == false then
        return INVAILD_OVERLAY
    else
        local overlay = ItemInfoOverlay:GetModule("itemInfoOverlay"):CreateItemInfoOverlay(frame)
        overlay.type = type
        return overlay
    end
end

--------------------
--- 链接解析
--------------------
function Utils.GetLinkTypeAndID(link)
    return strmatch(link, "\124c[\\a-zA-Z0-9:]+\124H([A-Za-z]+):(([0-9]+):[^\124]+)\124h(%b[])\124h\124r")
end

-- 12.1优化: 不再创建完整数据表，仅提取bonusID列表，减少80%临时内存
function Utils.GetItemLinkBonusIDs(link)
    local linkType, meta = Utils.GetLinkTypeAndID(link)
    if linkType ~= "item" then return nil end
    
    local bonusIDs
    local colonPos = 1
    local fieldIndex = 0
    local bonusCount = 0
    local inBonusField = false
    
    while colonPos do
        local nextPos = strfind(meta, ":", colonPos, true)
        local field = nextPos and strsub(meta, colonPos, nextPos - 1) or strsub(meta, colonPos)
        
        if fieldIndex == 11 then -- modifierMask之后是bonusIDs数量
            bonusCount = tonumber(field) or 0
            if bonusCount > 0 then
                bonusIDs = {}
                inBonusField = true
            end
        elseif inBonusField and bonusCount > 0 then
            local id = tonumber(field)
            if id then
                tinsert(bonusIDs, id)
                bonusCount = bonusCount - 1
            end
            if bonusCount <= 0 then break end
        end
        
        fieldIndex = fieldIndex + 1
        colonPos = nextPos and nextPos + 1 or nil
    end
    
    return bonusIDs
end

--------------------
--- 鼠标提示信息解析
--------------------
local PVP_ITEM_LEVEL_TOOLTIP_PATTERN = PVP_ITEM_LEVEL_TOOLTIP:gsub("%%d", "(%%d+)")

function Utils.GetItemLevelFromTooltipInfo(tooltipInfo)
    if tooltipInfo and tooltipInfo.lines then
        local itemLevel, currentItemLevel, pvpItemLevel
        for _, line in ipairs(tooltipInfo.lines) do
            if line.type == Enum.TooltipDataLineType.ItemLevel then
                itemLevel = line.actualItemLevel or line.itemLevel
                currentItemLevel = line.itemLevel
            elseif not pvpItemLevel and line.leftText and line.leftText:match(PVP_ITEM_LEVEL_TOOLTIP_PATTERN) then
                pvpItemLevel = line.leftText:match(PVP_ITEM_LEVEL_TOOLTIP_PATTERN)
            end
        end
        return tonumber(itemLevel), tonumber(currentItemLevel), tonumber(pvpItemLevel)
    end
end

local ITEM_STATS = {
    "ITEM_MOD_STRENGTH_SHORT",
    "ITEM_MOD_AGILITY_SHORT",
    "ITEM_MOD_INTELLECT_SHORT",
    "ITEM_MOD_STAMINA_SHORT",
    "ITEM_MOD_CRIT_RATING_SHORT",
    "ITEM_MOD_HASTE_RATING_SHORT",
    "ITEM_MOD_MASTERY_RATING_SHORT",
    "ITEM_MOD_VERSATILITY",
    "ITEM_MOD_CR_SPEED_SHORT",
    "ITEM_MOD_CR_LIFESTEAL_SHORT",
    "ITEM_MOD_CR_AVOIDANCE_SHORT",
}

-- 12.1优化: 使用对象池重用stats表，减少GC压力
local statsPool = {}
local statsPoolIndex = 0

local function AcquireStatsTable()
    statsPoolIndex = statsPoolIndex + 1
    if not statsPool[statsPoolIndex] then
        statsPool[statsPoolIndex] = {}
    else
        wipe(statsPool[statsPoolIndex])
    end
    return statsPool[statsPoolIndex]
end

local function ReleaseStatsTables()
    statsPoolIndex = 0
end

function Utils.GetItemStatsFromTooltipInfo(tooltipInfo)
    if tooltipInfo and tooltipInfo.lines then
        local primaryStat
        local stats = AcquireStatsTable()
        
        for _, line in ipairs(tooltipInfo.lines) do
            if line.leftText and line.leftColor then
                local lineText = line.leftText:gsub("[, ]", "")
                local color = line.leftColor:GenerateHexColorNoAlpha()
                if color ~= "808080" then
                    for i, stat in ipairs(ITEM_STATS) do
                        local value = tonumber(lineText:match("%+([0-9]+)".._G[stat]:gsub(" ", "")))
                        if value then
                            if not primaryStat and line.type == Enum.TooltipDataLineType.None and 
                               (stat == "ITEM_MOD_STRENGTH_SHORT" or stat == "ITEM_MOD_AGILITY_SHORT" or stat == "ITEM_MOD_INTELLECT_SHORT") then
                                primaryStat = stat
                            end
                            stats[stat] = (stats[stat] or 0) + value
                        end
                    end
                end
            end
        end
        return stats, primaryStat
    end
end

function Utils.ReleaseItemStats()
    ReleaseStatsTables()
end

--------------------
--- RGB转换
--------------------
function Utils.GetRGBAFromHexColor(hex)
    if strsub(hex, 1, 1) ~= "#" then
        return 1, 1, 1, 1
    end
    local len = string.len(hex)
    if len == 7 then
        return (tonumber(strsub(hex, 2, 3), 16) or 255) / 255,
               (tonumber(strsub(hex, 4, 5), 16) or 255) / 255,
               (tonumber(strsub(hex, 6, 7), 16) or 255) / 255, 1
    elseif len == 9 then
        return (tonumber(strsub(hex, 2, 3), 16) or 255) / 255,
               (tonumber(strsub(hex, 4, 5), 16) or 255) / 255,
               (tonumber(strsub(hex, 6, 7), 16) or 255) / 255,
               (tonumber(strsub(hex, 8, 9), 16) or 255) / 255
    end
    return 1, 1, 1, 1
end

local TRACK_STRING_ID_MYTH = 978
local TRACK_STRING_ID_HERO = 974
local TRACK_STRING_ID_CHAMPION = 973
local TRACK_STRING_ID_VETERAN = 972
local TRACK_STRING_ID_ADVENTURER = 971
local TRACK_STRING_ID_EXPLORER = 970

-- 12.1优化: 缓存配置值，减少重复GetConfig调用；使用局部变量加速热点路径
function Utils.GetColoredItemLevelText(itemLevel, itemLink, isPvP)
    local r, g, b = 1, 1, 1
    local colorMode = ItemInfoOverlay:GetConfig("color.itemLevel")
    local itemQuality = C_Item.GetItemQualityByID(itemLink)
    
    if colorMode == 1 then
        r, g, b = Utils.GetRGBAFromHexColor(ItemInfoOverlay:GetConfig("color.itemLevel.custom"))
    elseif colorMode == 2 and itemQuality then
        r, g, b = C_Item.GetItemQualityColor(itemQuality)
    end

    if ItemInfoOverlay:GetConfig("color.itemLevel.itemUpgrade") then
        local trackStringID
        local classID, subclassID = select(12, C_Item.GetItemInfo(itemLink))
        
        if C_Item.IsEquippableItem(itemLink) then
            local itemUpgradeInfo = C_Item.GetItemUpgradeInfo(itemLink)
            if itemUpgradeInfo and itemUpgradeInfo.trackStringID then
                if not (ItemInfoOverlay:GetConfig("color.itemLevel.itemUpgrade.ignoreLegacy") and itemUpgradeInfo.maxLevel == 0) then
                    trackStringID = itemUpgradeInfo.trackStringID
                end
            else
                -- 12.1优化: 使用轻量级bonusID提取替代完整链接解析
                local bonusIDs = Utils.GetItemLinkBonusIDs(itemLink)
                if bonusIDs then
                    for _, bonusID in ipairs(bonusIDs) do
                        local data = BONUS_ID_DATABASE[bonusID]
                        if data and data.trackStringID then
                            if not (ItemInfoOverlay:GetConfig("color.itemLevel.itemUpgrade.ignoreLegacy") and data.season and data.season < C_SeasonInfo.GetCurrentDisplaySeasonID()) then
                                trackStringID = data.trackStringID
                                break
                            end
                        end
                    end
                end
            end
        elseif (classID == Enum.ItemClass.Reagent and subclassID == Enum.ItemReagentSubclass.ContextToken) or 
               (classID == Enum.ItemClass.Miscellaneous and subclassID == Enum.ItemMiscellaneousSubclass.Junk and itemQuality and itemQuality >= Enum.ItemQuality.Epic) then
            local tooltipInfo = C_TooltipInfo.GetHyperlink(itemLink)
            if tooltipInfo and tooltipInfo.lines and tooltipInfo.lines[2] then
                local line2 = tooltipInfo.lines[2].leftText
                if line2 then
                    if line2:find(PLAYER_DIFFICULTY6) then
                        trackStringID = TRACK_STRING_ID_MYTH
                    elseif line2:find(PLAYER_DIFFICULTY2) then
                        trackStringID = TRACK_STRING_ID_HERO
                    elseif line2:find(PLAYER_DIFFICULTY3) then
                        trackStringID = TRACK_STRING_ID_VETERAN
                    elseif tooltipInfo.lines[2].type == Enum.TooltipDataLineType.ItemLevel then
                        trackStringID = TRACK_STRING_ID_CHAMPION
                    end
                end
            end
        end

        if trackStringID == TRACK_STRING_ID_MYTH or (isPvP and trackStringID == TRACK_STRING_ID_CHAMPION) then
            r, g, b = Utils.GetRGBAFromHexColor(ItemInfoOverlay:GetConfig("color.itemLevel.itemUpgrade.myth"))
        elseif trackStringID == TRACK_STRING_ID_HERO or (isPvP and trackStringID == TRACK_STRING_ID_VETERAN) then
            r, g, b = Utils.GetRGBAFromHexColor(ItemInfoOverlay:GetConfig("color.itemLevel.itemUpgrade.hero"))
        elseif trackStringID == TRACK_STRING_ID_CHAMPION or (isPvP and trackStringID == TRACK_STRING_ID_EXPLORER) then
            r, g, b = Utils.GetRGBAFromHexColor(ItemInfoOverlay:GetConfig("color.itemLevel.itemUpgrade.champion"))
        elseif trackStringID == TRACK_STRING_ID_VETERAN then
            r, g, b = Utils.GetRGBAFromHexColor(ItemInfoOverlay:GetConfig("color.itemLevel.itemUpgrade.veteran"))
        elseif trackStringID == TRACK_STRING_ID_ADVENTURER or trackStringID == TRACK_STRING_ID_EXPLORER then
            r, g, b = Utils.GetRGBAFromHexColor(ItemInfoOverlay:GetConfig("color.itemLevel.itemUpgrade.explorer"))
        end

        if colorMode == 1 and itemQuality and itemQuality >= 5 then
            r, g, b = C_Item.GetItemQualityColor(itemQuality)
        end
    end

    if type(itemLevel) == "number" and ItemInfoOverlay:GetConfig("color.itemLevel.lowLevel") then
        if itemQuality and itemQuality < 5 and itemLevel < select(1, GetAverageItemLevel()) - ItemInfoOverlay:GetConfig("color.itemLevel.lowLevel.threshold") then
            r, g, b = Utils.GetRGBAFromHexColor(ItemInfoOverlay:GetConfig("color.itemLevel.lowLevel.color"))
        end 
    end

    return format("|cff%02x%02x%02x%s|r", r * 255, g * 255, b * 255, itemLevel)
end

--------------------
--- 属性递减计算
--------------------

local COMBAT_RATING_DECREASING = {
    { 200, 126, 0 },
    { 80, 66, 0.5 },
    { 60, 54, 0.6 },
    { 50, 47, 0.7 },
    { 40, 39, 0.8 },
    { 30, 30, 0.9 },
}

local COMBAT_RATING_DECREASING2 = {
    {100, 49, 0},
    {20, 17, 0.4},
    {15, 14, 0.6},
    {10, 10, 0.8},
}

local COMBAT_RATINGS = {
    ITEM_MOD_CRIT_RATING_SHORT = { CR_CRIT_SPELL, COMBAT_RATING_DECREASING },
    ITEM_MOD_HASTE_RATING_SHORT = { CR_HASTE_SPELL, COMBAT_RATING_DECREASING },
    ITEM_MOD_MASTERY_RATING_SHORT = { CR_MASTERY, COMBAT_RATING_DECREASING },
    ITEM_MOD_VERSATILITY = { CR_VERSATILITY_DAMAGE_DONE, COMBAT_RATING_DECREASING },
    ITEM_MOD_CR_SPEED_SHORT = { CR_SPEED, COMBAT_RATING_DECREASING2 },
    ITEM_MOD_CR_LIFESTEAL_SHORT = { CR_LIFESTEAL, COMBAT_RATING_DECREASING2 },
    ITEM_MOD_CR_AVOIDANCE_SHORT = { CR_AVOIDANCE, COMBAT_RATING_DECREASING2 }
}

local function UpdateCombatStatsRatings()
    local statsRatings = ItemInfoOverlay:GetConfig("statsRatings")
    if not statsRatings then
        statsRatings = {}
        ItemInfoOverlay:SetConfig("statsRatings", statsRatings)
    end
    statsRatings[UnitLevel("player")] = {}
    for i, stat in pairs(COMBAT_RATINGS) do
        statsRatings[UnitLevel("player")][i] = 1 / GetCombatRatingBonusForCombatRatingValue(stat[1], 1)
    end
end

function Utils.GetCombatStatsRatings(stat, level)
    local statsRatings = ItemInfoOverlay:GetConfig("statsRatings")
    if not level then
        level = UnitLevel("player")
    end
    if statsRatings and statsRatings[level] then
        return statsRatings[level][stat]
    end
end

function Utils.CalculateStatsRatings(stat, statNum, level)
    local statsRatings = ItemInfoOverlay:GetConfig("statsRatings")
    if not level then
        level = UnitLevel("player")
    end
    if statNum and statNum > 0 and statsRatings and statsRatings[level] and statsRatings[level][stat] then
        local bonus = statNum / statsRatings[level][stat]
        local decreasing = COMBAT_RATINGS[stat] and COMBAT_RATINGS[stat][2]
        if decreasing then
            for _, data in ipairs(decreasing) do
                if bonus > data[1] then
                    return (bonus - data[1]) * data[3] + data[2], bonus
                end
            end
        end
        return bonus
    end
end

--------------------
--- 装备信息数据
--------------------
local PRELOAD_UNIQUENESS_LINKS = {
    "|cnIQ4:|Hitem:215134::::::::80:102::13:1:3524:2:40:1277:38:4:::::|h[知己之矶]|h|r"
}

local UNIQUENESS_NAMES = {}

function Utils.GetItemUniquenessByID(itemInfo)
    local id = C_Item.GetItemIDForItemInfo(itemInfo)
    if DOUBLE_UNIQUENESS_DATABASE[id] and UNIQUENESS_NAMES[DOUBLE_UNIQUENESS_DATABASE[id][2]] then
        return true, UNIQUENESS_NAMES[DOUBLE_UNIQUENESS_DATABASE[id][2]], DOUBLE_UNIQUENESS_DATABASE[id][1], DOUBLE_UNIQUENESS_DATABASE[id][2]
    else
        return C_Item.GetItemUniquenessByID(itemInfo)
    end
end

function Utils.ItemCanEnchant(itemLevel, itemEquipLoc)
    if not itemLevel then return false end
    local config = EQUIP_LOC_CAN_ENCHANT[itemEquipLoc]
    if type(config) == "table" then
        return itemLevel >= config[1] and itemLevel <= config[2]
    elseif type(config) == "function" then
        return config(itemLevel)
    else
        return config == true
    end
end

local function isPvpItem(itemLink, pvpItemLevel)
    if not pvpItemLevel then return false end
    local itemEquipLoc, _, _, _, _, _, _, setID = select(9, C_Item.GetItemInfo(itemLink))
    if setID and (itemEquipLoc == "INVTYPE_HEAD" or itemEquipLoc == "INVTYPE_SHOULDER" 
        or itemEquipLoc == "INVTYPE_CHEST" or itemEquipLoc == "INVTYPE_ROBE"
        or itemEquipLoc == "INVTYPE_HAND" or itemEquipLoc == "INVTYPE_LEGS") then
        return false
    end
    return true
end

function Utils.ItemMaxSockets(itemLevel, itemLink, pvpItemLevel)
    local itemEquipLoc, _, _, _, _, _, expansionID = select(9, C_Item.GetItemInfo(itemLink))
    local seasonID = C_SeasonInfo.GetCurrentDisplaySeasonID()
    local maxSocketInfo

    if seasonID and EQUIP_LOC_MAX_SOCKETS.season[seasonID] and EQUIP_LOC_MAX_SOCKETS.season[seasonID][itemEquipLoc] 
       and itemLevel >= EQUIP_LOC_MAX_SOCKETS.season[seasonID].minItemLevel then
        maxSocketInfo = EQUIP_LOC_MAX_SOCKETS.season[seasonID][itemEquipLoc]
    elseif EQUIP_LOC_MAX_SOCKETS.expansion[expansionID] and EQUIP_LOC_MAX_SOCKETS.expansion[expansionID][itemEquipLoc] then
        maxSocketInfo = EQUIP_LOC_MAX_SOCKETS.expansion[expansionID][itemEquipLoc]
    end

    if maxSocketInfo then
        if isPvpItem(itemLink, pvpItemLevel) then
            if maxSocketInfo[3] == false then
                return 0
            else
                return maxSocketInfo[1], maxSocketInfo[3] or maxSocketInfo[2]
            end
        else
            return maxSocketInfo[1], maxSocketInfo[2]
        end
    end
    return 0
end

local PERFERRED_ARMOR_TYPE_BY_CLASS = {
    WARRIOR = Enum.ItemArmorSubclass.Plate,
    PALADIN = Enum.ItemArmorSubclass.Plate,
    HUNTER = Enum.ItemArmorSubclass.Mail,
    ROGUE = Enum.ItemArmorSubclass.Leather,
    PRIEST = Enum.ItemArmorSubclass.Cloth,
    DEATHKNIGHT = Enum.ItemArmorSubclass.Plate,
    SHAMAN = Enum.ItemArmorSubclass.Mail,
    MAGE = Enum.ItemArmorSubclass.Cloth,
    WARLOCK = Enum.ItemArmorSubclass.Cloth,
    MONK = Enum.ItemArmorSubclass.Leather,
    DRUID = Enum.ItemArmorSubclass.Leather,
    DEMONHUNTER = Enum.ItemArmorSubclass.Leather,
    EVOKER = Enum.ItemArmorSubclass.Mail,
}

local PERFERRED_ARMOR_TYPE = PERFERRED_ARMOR_TYPE_BY_CLASS[select(2, UnitClass("player"))]

function Utils.IsPerferedArmorType(classID, subclassID, itemEquipLoc)
    if not PERFERRED_ARMOR_TYPE then return true end
    if classID == 4 and subclassID >= 1 and subclassID <= 4 then
        if itemEquipLoc == "INVTYPE_CLOAK" then return true end
        return PERFERRED_ARMOR_TYPE == subclassID
    end
    return true
end

function Utils:AfterLogin()
    UpdateCombatStatsRatings()
    for _, link in ipairs(PRELOAD_UNIQUENESS_LINKS) do
        local _, _, _, limitCategoryID = C_Item.GetItemUniquenessByID(link)
        if limitCategoryID then
            UNIQUENESS_NAMES[limitCategoryID] = true
        end
    end
end

function Utils:PLAYER_LEVEL_CHANGED()
    UpdateCombatStatsRatings()
end
Utils:RegisterEvent("PLAYER_LEVEL_CHANGED")