local ADDON_NAME, ItemInfoOverlay = ...

local Module = ItemInfoOverlay:NewModule("equipmentSummary")
local Utils = ItemInfoOverlay:GetModule("utils")
local L = ItemInfoOverlay.Locale
local SharedMedia = LibStub("LibSharedMedia-3.0")

local CONFIG_PLAYER_ENABLE = "player.enable"
local CONFIG_INSPECT_ENABLE = "inspect.enable"
local CONFIG_SLOT_NAME = "slotName.enable"
local CONFIG_STAT_ICON = "statIcon.enable"
local CONFIG_STAT_ICON_STYLE = "statIcon.style"
local CONFIG_FONT_SIZE = "fontSize"
local CONFIG_TITLE_FONT_SIZE = "title.fontSize"
local CONFIG_ITEM_SETS = "itemSets.enable"
local CONFIG_ITEM_SETS_UNIQUE = "itemSets.unique"
local CONFIG_ITEM_STATS = "itemStats.enable"
local CONFIG_ITEM_LEVEL_COLOR = "itemLevel.color"

local ITEM_LEVEL_AND_SPEC_FORMAT = "|cffffd200"..ITEM_LEVEL:gsub("%%d", "%%.1f").."|r %s%s%s|r\n "
local ITEM_LEVEL_AND_SPEC_WITH_PVP_FORMAT = "|cffffd200"..ITEM_LEVEL:gsub("%%d", "%%.1f").."|r %s%s%s|r\n|cffffd200"..ITEM_UPGRADE_PVP_ITEM_LEVEL_STAT_FORMAT:gsub("%%d", "%%.1f").."|r\n "
local ITEM_SET_BONUS_PATTERN = ITEM_SET_BONUS:gsub("%%s", "(.+)")
local ITEM_SET_BONUS_GRAY_PATTERN = ITEM_SET_BONUS_GRAY:gsub("%(%%d%)", "%%(%%d+%%)"):gsub("%%s", "(.+)")

local STAT_ICONS_STYLE = {
    ["Armory"] = {
        { type = "texture", r = 224/255, g =  28/255, b =  28/255, texture = "Interface\\AddOns\\ItemInfoOverlay\\Media\\icon\\stats_Armory\\crit.png" },
        { type = "texture", r =  14/255, g = 213/255, b = 155/255, texture = "Interface\\AddOns\\ItemInfoOverlay\\Media\\icon\\stats_Armory\\haste.png" },
        { type = "texture", r = 146/255, g =  86/255, b = 255/255, texture = "Interface\\AddOns\\ItemInfoOverlay\\Media\\icon\\stats_Armory\\mastery.png" },
        { type = "texture", r = 191/255, g = 191/255, b = 191/255, texture = "Interface\\AddOns\\ItemInfoOverlay\\Media\\icon\\stats_Armory\\versatility.png" }
    },
    ["GearStatSummary"] = {
        { type = "text", r = 1, g = 0, b = 0, text = "爆" },
        { type = "text", r = 1, g = 1, b = 0, text = "急" },
        { type = "text", r = 1, g = 0, b = 1, text = "精" },
        { type = "text", r = 0, g = 0, b = 1, text = "全" }
    },
    ["GearStatSummaryEn"] = {
        { type = "text", r = 1, g = 0, b = 0, text = "C" },
        { type = "text", r = 1, g = 1, b = 0, text = "H" },
        { type = "text", r = 1, g = 0, b = 1, text = "M" },
        { type = "text", r = 0, g = 0, b = 1, text = "V" }
    },
}

local WIDTH_BY_LOCALE = {
    enUS = {20, 16, 9, 6.5, 3},
    zhCN = {14, 12, 6.5, 4.5, 3},
    zhTW = {14, 12, 6.5, 4.5, 3},
}

local WIDTH_RATE = WIDTH_BY_LOCALE[GetLocale()] or WIDTH_BY_LOCALE.enUS

local EQUIPMENT_SLOTS = {
    {slotId = 1, name = HEADSLOT},
    {slotId = 2, name = NECKSLOT},
    {slotId = 3, name = SHOULDERSLOT},
    {slotId = 15, name = BACKSLOT},
    {slotId = 5, name = CHESTSLOT},
    {slotId = 9, name = WRISTSLOT},
    {slotId = 10, name = HANDSSLOT},
    {slotId = 6, name = WAISTSLOT},
    {slotId = 7, name = LEGSSLOT},
    {slotId = 8, name = FEETSLOT},
    {slotId = 11, name = FINGER0SLOT},
    {slotId = 12, name = FINGER1SLOT},
    {slotId = 13, name = TRINKET0SLOT},
    {slotId = 14, name = TRINKET1SLOT},
    {slotId = 16, name = MAINHANDSLOT},
    {slotId = 17, name = SECONDARYHANDSLOT}
}

local preview = false

--------------------
-- Mixin
--------------------
IIOEquipmentSummaryEntryMixin = {}

function IIOEquipmentSummaryEntryMixin:OnLoad()
    self.SlotNameBackdrop:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile     = true,
        tileSize = 8,
        edgeSize = 1,
        insets   = {left = 1, right = 1, top = 1, bottom = 1}
    })
    self.SlotNameBackdrop:SetBackdropBorderColor(0, 0.9, 0.9, 0.2)
    self.SlotNameBackdrop:SetBackdropColor(0, 0.9, 0.9, 0.2)
    self:UpdateAppearance()
end

function IIOEquipmentSummaryEntryMixin:UpdateAppearance()
    local _, _, style = GameTooltipText:GetFont()
    local font = Module:GetConfig("font")
    if not font then return end

    self.SlotName:SetFont(font, Module:GetConfig(CONFIG_FONT_SIZE), style)
    self.ItemLevel:SetFont(font, Module:GetConfig(CONFIG_FONT_SIZE), style)
    self.ItemLink:SetFont(font, Module:GetConfig(CONFIG_FONT_SIZE), style)
    self.ItemUpgrade:SetFont(font, Module:GetConfig(CONFIG_FONT_SIZE), style)

    local iconStyle = STAT_ICONS_STYLE[Module:GetConfig(CONFIG_STAT_ICON_STYLE)]
    for i = 1, 4 do
        local icon = self[({"CritIcon","HasteIcon","MasteryIcon","VersatilityIcon"})[i]]
        local data = iconStyle[i]
        icon:SetSize(Module:GetConfig(CONFIG_FONT_SIZE), Module:GetConfig(CONFIG_FONT_SIZE))
        icon.Backdrop:SetVertexColor(data.r, data.g, data.b, 1)
        if data.type == "texture" then
            icon.Icon:SetTexture(data.texture)
            icon.Icon:Show()
            icon.Text:Hide()
        else
            icon.Icon:Hide()
            icon.Text:SetFont(font, Module:GetConfig(CONFIG_FONT_SIZE) - 1, style)
            icon.Text:SetText(data.text)
            icon.Text:SetTextColor(data.r, data.g, data.b)
            icon.Text:Show()
        end
    end

    self:SetHeight(Module:GetConfig(CONFIG_FONT_SIZE) + 2)

    if Module:GetConfig(CONFIG_SLOT_NAME) then
        self.CritIcon:ClearAllPoints()
        self.CritIcon:SetPoint("TOPLEFT", self.SlotName, "TOPRIGHT", 2, 0)
        self.SlotName:SetWidth(Module:GetConfig(CONFIG_FONT_SIZE) * 3)
        self.SlotNameBackdrop:Show()
        self.SlotName:Show()
    else
        self.CritIcon:ClearAllPoints()
        self.CritIcon:SetPoint("TOPLEFT", self)
        self.SlotName:Hide()
        self.SlotNameBackdrop:Hide()
    end

    if Module:GetConfig(CONFIG_STAT_ICON) then
        self.ItemLevel:ClearAllPoints()
        self.ItemLevel:SetPoint("TOPLEFT", self.VersatilityIcon, "TOPRIGHT", 4, 0)
    else
        self.ItemLevel:ClearAllPoints()
        self.ItemLevel:SetPoint(
            "TOPLEFT",
            (Module:GetConfig(CONFIG_SLOT_NAME) and self.SlotName) or self,
            (Module:GetConfig(CONFIG_SLOT_NAME) and "TOPRIGHT") or "TOPLEFT",
            (Module:GetConfig(CONFIG_SLOT_NAME) and 2) or 0,
            0
        )
        self:ToggleStats()
    end

    local temp = self.ItemLevel:GetText()
    self.ItemLevel:SetText("1000")
    local itemLevelWidth = self.ItemLevel:GetUnboundedStringWidth()
    self.ItemLevel:SetWidth(itemLevelWidth)
    self.ItemLevel:SetText(temp)

    self.ItemLink:SetWidth((Module:GetConfig(CONFIG_FONT_SIZE) * (Module:GetConfig("itemUpgradeTrack.enable") and WIDTH_RATE[2] or WIDTH_RATE[1])) - itemLevelWidth)
    self.ItemUpgrade:SetWidth(Module:GetConfig("itemUpgradeTrack.enable") and (WIDTH_RATE[Module:GetConfig("itemUpgradeTrack.style") + 2] * Module:GetConfig(CONFIG_FONT_SIZE)) or 0)
end

function IIOEquipmentSummaryEntryMixin:SetItemFromUnitInventory(unit, slot, itemLink, itemLevel)
    self.unit = unit
    self.slot = slot
    itemLink = itemLink or GetInventoryItemLink(unit, slot)
    if itemLink then
        itemLevel = itemLevel or Utils.GetItemLevelFromTooltipInfo(C_TooltipInfo.GetInventoryItem(unit, slot))

        if itemLevel and Module:GetConfig(CONFIG_ITEM_LEVEL_COLOR) then
            itemLevel = Utils.GetColoredItemLevelText(itemLevel, itemLink)
        end
        
        local stats = C_Item.GetItemStats(itemLink)
        if Module:GetConfig(CONFIG_STAT_ICON) and stats then
            self:ToggleStats(
                stats.ITEM_MOD_CRIT_RATING_SHORT and stats.ITEM_MOD_CRIT_RATING_SHORT > 0,
                stats.ITEM_MOD_HASTE_RATING_SHORT and stats.ITEM_MOD_HASTE_RATING_SHORT > 0,
                stats.ITEM_MOD_MASTERY_RATING_SHORT and stats.ITEM_MOD_MASTERY_RATING_SHORT > 0,
                stats.ITEM_MOD_VERSATILITY and stats.ITEM_MOD_VERSATILITY > 0
            )
        else
            self:ToggleStats()
        end

        self.ItemLevel:SetText(itemLevel)

        if Module:GetConfig("itemUpgradeTrack.enable") then
            local itemUpgradeInfo = C_Item.GetItemUpgradeInfo(itemLink)
            if itemUpgradeInfo and itemUpgradeInfo.trackString then
                local level = itemUpgradeInfo.currentLevel.."/"..itemUpgradeInfo.maxLevel
                if itemUpgradeInfo.maxLevel == 0 then
                    level = "-/-"
                end
                if Module:GetConfig("itemUpgradeTrack.style") == 1 then
                    self.ItemUpgrade:SetText(Utils.GetColoredItemLevelText(" ["..itemUpgradeInfo.trackString.." "..level.."]", itemLink))
                elseif Module:GetConfig("itemUpgradeTrack.style") == 2 then
                    self.ItemUpgrade:SetText(Utils.GetColoredItemLevelText(" ["..itemUpgradeInfo.trackString.."]", itemLink))
                elseif Module:GetConfig("itemUpgradeTrack.style") == 3 then
                    self.ItemUpgrade:SetText(Utils.GetColoredItemLevelText(" ["..level.."]", itemLink))
                end
            elseif string.find(itemLink, "|A:") then
                local level = string.match(itemLink, "|A:.+|a")
                itemLink = itemLink:gsub("|A:.+|a", "")
                self.ItemUpgrade:SetText(level)
            else
                self.ItemUpgrade:SetText()
            end
        else
            self.ItemUpgrade:SetText()
        end

        self.ItemLink:SetText(itemLink:gsub("[%[%]]", ""))
    else
        self:Clear()
    end
end

function IIOEquipmentSummaryEntryMixin:Clear()
    self:ToggleStats()
    self.ItemLevel:SetText("|cff7f7f7f-|r")
    self.ItemLink:SetText("|cff7f7f7f"..(self.slotName or "-").."|r")
    self.ItemUpgrade:SetText()
end

function IIOEquipmentSummaryEntryMixin:ToggleStats(crit, haste, mastery, versatility)
    self.CritIcon:SetShown(crit)
    self.HasteIcon:SetShown(haste)
    self.MasteryIcon:SetShown(mastery)
    self.VersatilityIcon:SetShown(versatility)
end

function IIOEquipmentSummaryEntryMixin:OnEnter()
    if self.unit and self.slot then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetInventoryItem(self.unit, self.slot)
        GameTooltip:Show()
    end
end

function IIOEquipmentSummaryEntryMixin:OnLeave()
    GameTooltip:Hide()
end

IIOEquipmentSummaryFrameMixin = {}

function IIOEquipmentSummaryFrameMixin:OnLoad()
    BackdropTemplateMixin.OnBackdropLoaded(self)
    self:SetBackdrop({
        bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileEdge = true,
        tileSize = 0,
        edgeSize = 16,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })

    if ElvUI then
        self:SetTemplate("Transparent")
    end

    self.slots = {}
    self.slotNum = 0
    self.equipmentSets = {}

    local lastRegion = self.SubTitle
    for i, slot in ipairs(EQUIPMENT_SLOTS) do
        local slotId = slot.slotId
        if not self.slots[slotId] then
            self.slots[slotId] = CreateFrame("Frame", nil, self, "IIOEquipmentSummaryEntryTemplate")
        end
        self.slots[slotId]:SetPoint("TOPLEFT", lastRegion, "BOTTOMLEFT")
        self.slots[slotId]:SetPoint("TOPRIGHT", lastRegion, "BOTTOMRIGHT")
        self.slots[slotId]:Show()
        self.slots[slotId].slotName = slot.name
        self.slots[slotId].SlotName:SetText(slot.name)
        self.slots[slotId].SlotName:SetTextColor(0, 0.9, 0.9)
        self.slotNum = self.slotNum + 1
        lastRegion = self.slots[slotId]
    end

    self.InfoText:SetPoint("TOPLEFT", lastRegion, "BOTTOMLEFT", 0, -10)
    self.InfoText:SetPoint("TOPRIGHT", lastRegion, "BOTTOMRIGHT", 0, -10)

    self.ItemStatsTips:SetScript("OnEnter", function (button)
        GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["equipmentSummary.itemStats.tips.title"])
        GameTooltip:AddLine(L["equipmentSummary.itemStats.tips.line1"], 1, 1, 1)
        if self.level then
            GameTooltip:AddLine(" ")
            local critRating = Utils.GetCombatStatsRatings("ITEM_MOD_CRIT_RATING_SHORT", self.level)
            local hasteRating = Utils.GetCombatStatsRatings("ITEM_MOD_HASTE_RATING_SHORT", self.level)
            local masteryRating = Utils.GetCombatStatsRatings("ITEM_MOD_MASTERY_RATING_SHORT", self.level)
            local versRating = Utils.GetCombatStatsRatings("ITEM_MOD_VERSATILITY", self.level)
            local speedRating = Utils.GetCombatStatsRatings("ITEM_MOD_CR_SPEED_SHORT", self.level)
            local lifestealRating = Utils.GetCombatStatsRatings("ITEM_MOD_CR_LIFESTEAL_SHORT", self.level)
            local avoidRating = Utils.GetCombatStatsRatings("ITEM_MOD_CR_AVOIDANCE_SHORT", self.level)

            GameTooltip:AddLine(format(L["equipmentSummary.itemStats.tips.line2"], self.level))
            GameTooltip:AddDoubleLine(ITEM_MOD_CRIT_RATING_SHORT..": ", (critRating and format("%d", critRating + 0.5)) or L["equipmentSummary.itemStats.tips.unknown"], nil, nil, nil, 1, 1, 1)
            GameTooltip:AddDoubleLine(ITEM_MOD_HASTE_RATING_SHORT..": ", (hasteRating and format("%d", hasteRating + 0.5)) or L["equipmentSummary.itemStats.tips.unknown"], nil, nil, nil, 1, 1, 1)
            GameTooltip:AddDoubleLine(ITEM_MOD_MASTERY_RATING_SHORT..": ", (masteryRating and format("%d", masteryRating + 0.5)) or L["equipmentSummary.itemStats.tips.unknown"], nil, nil, nil, 1, 1, 1)
            GameTooltip:AddDoubleLine(ITEM_MOD_VERSATILITY..": ", (versRating and format("%d", versRating + 0.5)) or L["equipmentSummary.itemStats.tips.unknown"], nil, nil, nil, 1, 1, 1)
            GameTooltip:AddLine(" ")
            GameTooltip:AddDoubleLine(ITEM_MOD_CR_SPEED_SHORT..": ", (speedRating and format("%d", speedRating + 0.5)) or L["equipmentSummary.itemStats.tips.unknown"], nil, nil, nil, 1, 1, 1)
            GameTooltip:AddDoubleLine(ITEM_MOD_CR_LIFESTEAL_SHORT..": ", (lifestealRating and format("%d", lifestealRating + 0.5)) or L["equipmentSummary.itemStats.tips.unknown"], nil, nil, nil, 1, 1, 1)
            GameTooltip:AddDoubleLine(ITEM_MOD_CR_AVOIDANCE_SHORT..": ", (avoidRating and format("%d", avoidRating + 0.5)) or L["equipmentSummary.itemStats.tips.unknown"], nil, nil, nil, 1, 1, 1)
        end
        GameTooltip:Show()
    end)
    self.ItemStatsTips:SetScript("OnLeave", function (button)
        GameTooltip:Hide()
    end)
end

function IIOEquipmentSummaryFrameMixin:OnShow()
    self:Refresh()
end

function IIOEquipmentSummaryFrameMixin:UpdateAppearance()
    for i, entry in pairs(self.slots) do
        entry:UpdateAppearance()
    end
    local _, _, style = GameTooltipText:GetFont()
    local font = Module:GetConfig("font")
    self.SubTitle:SetFont(font, Module:GetConfig(CONFIG_FONT_SIZE), style)
    self.InfoText:SetFont(font, Module:GetConfig(CONFIG_FONT_SIZE), style)
    self.ItemStatsText1:SetFont(font, Module:GetConfig(CONFIG_FONT_SIZE), style)
    self.ItemStatsText2:SetFont(font, Module:GetConfig(CONFIG_FONT_SIZE), style)
    self.ItemStatsText3:SetFont(font, Module:GetConfig(CONFIG_FONT_SIZE), style)

    _, _, style = GameTooltipHeaderText:GetFont()
    font = Module:GetConfig("title.font")
    self.Title:SetFont(font, Module:GetConfig(CONFIG_TITLE_FONT_SIZE), style)

    self:SetBackdropColor(0, 0, 0, Module:GetConfig("backdrop.alpha") * 0.01)
    self:Refresh()
end

function IIOEquipmentSummaryFrameMixin:SetUnit(unit)
    self.unit = unit
    self:Refresh()
end

-- 12.1优化: 添加刷新令牌，防止宝石异步加载导致重复刷新
local refreshToken = 0

function IIOEquipmentSummaryFrameMixin:Refresh()
    if not self:IsShown() then return end
    refreshToken = refreshToken + 1
    local currentToken = refreshToken
    
    if self.unit then
        local name = UnitNameUnmodified(self.unit)
        local level = UnitLevel(self.unit)
        self.level = level
        local className, classFilename = UnitClass(self.unit)
        local classColor = C_ClassColor.GetClassColor(classFilename)

        if classColor then
            self:SetBackdropBorderColor(classColor:GetRGBA())
            self.Title:SetTextColor(classColor:GetRGB())
        end
        self.Title:SetText(name)

        local primaryStat
        local totalStats = {}

        local numItemSets = 0
        local itemSets = {}
        local itemSetsBonus = {}
        local itemUnique = {}

        local totalItemLevel, totalPvpItemLevel = 0, 0
        local hasEnchantNum, maxEnchantNum = 0, 0
        local gemNum, socketNum = 0, 0

        for i, entry in pairs(self.slots) do
            local link = GetInventoryItemLink(self.unit, i)

            if link then
                local itemName, _, itemQuality, _, itemMinLevel, itemType, itemSubType, 
                itemStackCount, itemEquipLoc, itemTexture, sellPrice, classID, subclassID, bindType,
                expacID, setID, isCraftingReagent = C_Item.GetItemInfo(link)

                local tooltipInfo = C_TooltipInfo.GetInventoryItem(self.unit, i)
                local itemLevel, currentItemLevel, pvpItemLevel = Utils.GetItemLevelFromTooltipInfo(tooltipInfo)

                if itemLevel then
                    totalItemLevel = totalItemLevel + itemLevel
                    totalPvpItemLevel = totalPvpItemLevel + (pvpItemLevel or itemLevel)
                end

                -- 12.1优化: 使用tooltip解析的属性，并确保释放stats表
                local stats, pstat = Utils.GetItemStatsFromTooltipInfo(tooltipInfo)
                if stats then
                    for stat, value in pairs(stats) do
                        totalStats[stat] = (totalStats[stat] or 0) + value
                    end
                end
                if not primaryStat and pstat then
                    primaryStat = pstat
                end

                local canEnchant = Utils.ItemCanEnchant(itemLevel, itemEquipLoc)
                local hasEnchant
                local numItemSetBonus, maxItemSetBonus = 0, 0
                if tooltipInfo then
                    for _, line in ipairs(tooltipInfo.lines) do
                        if line.type == Enum.TooltipDataLineType.ItemEnchantmentPermanent then
                            hasEnchant = true
                        elseif line.type == Enum.TooltipDataLineType.GemSocket then
                            socketNum = socketNum + 1
                        elseif line.leftText and line.leftText:match(ITEM_SET_BONUS_PATTERN) then
                            if not line.leftText:match(ITEM_SET_BONUS_GRAY_PATTERN) then
                                numItemSetBonus = numItemSetBonus + 1
                            end
                            maxItemSetBonus = maxItemSetBonus + 1
                        end
                    end
                end

                if canEnchant then
                    maxEnchantNum = maxEnchantNum + 1
                    if hasEnchant then
                        hasEnchantNum = hasEnchantNum + 1
                    end
                end

                -- 12.1优化: 宝石加载使用令牌检查，避免过期回调刷新
                for j = 1, 3 do
                    local gemID = C_Item.GetItemGemID(link, j)
                    if gemID then
                        gemNum = gemNum + 1
                        local gemItem = Item:CreateFromItemID(gemID)
                        if not gemItem:IsItemDataCached() then
                            gemItem:ContinueOnItemLoad(function()
                                if currentToken == refreshToken then
                                    self:Refresh()
                                end
                            end)
                        end
                    end
                end

                if Module:GetConfig(CONFIG_ITEM_SETS) then
                    if setID then
                        if itemSets[setID] then
                            itemSets[setID] = itemSets[setID] + 1
                            itemSetsBonus[setID] = {numItemSetBonus, maxItemSetBonus}
                        else
                            itemSets[setID] = 1
                            itemSetsBonus[setID] = {numItemSetBonus, maxItemSetBonus}
                            numItemSets = numItemSets + 1
                        end
                    end
                    local isUnique, limitCategoryName, limitCategoryCount, limitCategoryID = Utils.GetItemUniquenessByID(link)
                    if Module:GetConfig(CONFIG_ITEM_SETS_UNIQUE) and isUnique and limitCategoryID then
                        if limitCategoryCount > 1 then
                            if itemUnique[limitCategoryID] then
                                itemUnique[limitCategoryID][1] = itemUnique[limitCategoryID][1] + 1
                            else
                                itemUnique[limitCategoryID] = { 1, limitCategoryName, limitCategoryCount}
                                numItemSets = numItemSets + 1
                            end
                        end
                    end
                end

                if Module:GetConfig("itemLevel.style") == 2 then
                    entry:SetItemFromUnitInventory(self.unit, i, link, pvpItemLevel)
                elseif Module:GetConfig("itemLevel.style") == 1 and currentItemLevel == pvpItemLevel then
                    entry:SetItemFromUnitInventory(self.unit, i, link, pvpItemLevel)
                else
                    entry:SetItemFromUnitInventory(self.unit, i, link, itemLevel)
                end
            else
                if i == 16 or i == 17 then
                    link = GetInventoryItemLink(self.unit, i== 17 and 16 or 17)
                    if link then
                        local loc = select(9, C_Item.GetItemInfo(link))
                        if loc == "INVTYPE_2HWEAPON" or loc == "INVTYPE_RANGED" or loc == "INVTYPE_RANGEDRIGHT" then
                            local itemLevel, _, pvpItemLevel = Utils.GetItemLevelFromTooltipInfo(C_TooltipInfo.GetInventoryItem(self.unit, i == 17 and 16 or 17))
                            if itemLevel then
                                totalItemLevel = totalItemLevel + itemLevel
                                totalPvpItemLevel = totalPvpItemLevel + (pvpItemLevel or itemLevel)
                            end
                        end
                    end
                end
                entry:Clear()
            end
        end

        -- 12.1优化: 释放stats对象池
        Utils.ReleaseItemStats()

        self:RefreshItemLevelAndSpec(totalItemLevel / 16, totalPvpItemLevel / 16)

        local text = ""

        if Module:GetConfig("enchantAndSockets.enable") then
            text = text..format("|cffffd200%s: |r|c%s%d|r / %d    |cffffd200%s: |r|c%s%d|r / %d\n",
            GetItemClassInfo(8), hasEnchantNum == maxEnchantNum and "ff00ff00" or "ffff0000", hasEnchantNum, maxEnchantNum,
            GetItemClassInfo(3), gemNum == socketNum and "ff00ff00" or "ffff0000", gemNum, socketNum)
            text = text.."\n"
        end

        if numItemSets > 0 then
            text = text..format("|cffffd200%s:|r\n", LOOT_JOURNAL_ITEM_SETS)
            for id, num in pairs(itemSets) do
                local setName = C_Item.GetItemSetInfo(id)
                local maxNum = #C_LootJournal.GetItemSetItems(id)
                local color = "ffffffff"
                if itemSetsBonus[id] then
                    if itemSetsBonus[id][1] == 0 then
                        color = "ffff0000"
                    elseif itemSetsBonus[id][1] == itemSetsBonus[id][2] then
                        color = "ff00ff00"
                    else
                        color = "ffffff00"
                    end
                end
                if setName then
                    text = text..format("    %s (|c%s%d|r/%d)\n", setName, color, num, maxNum)
                end
            end
            for id, data in pairs(itemUnique) do
                local num = data[1]
                local setName = data[2]
                local maxNum = data[3]
                if setName then
                    text = text..format("    %s (%s)\n", setName, (maxNum and num.."/"..maxNum) or num)
                end
            end
            text = text.."\n"
        end

        self.InfoText:SetText(text)

        if Module:GetConfig(CONFIG_ITEM_STATS) then
            local critBonus, critBonus2 = Utils.CalculateStatsRatings("ITEM_MOD_CRIT_RATING_SHORT", totalStats.ITEM_MOD_CRIT_RATING_SHORT, level)
            local hasteBonus, hasteBonus2 = Utils.CalculateStatsRatings("ITEM_MOD_HASTE_RATING_SHORT", totalStats.ITEM_MOD_HASTE_RATING_SHORT, level)
            local masteryBonus, masteryBonus2 = Utils.CalculateStatsRatings("ITEM_MOD_MASTERY_RATING_SHORT", totalStats.ITEM_MOD_MASTERY_RATING_SHORT, level)
            local versBonus, versBonus2 = Utils.CalculateStatsRatings("ITEM_MOD_VERSATILITY", totalStats.ITEM_MOD_VERSATILITY, level)
            local masteryCoefficient = (self.unit == "player" and select(2, GetMasteryEffect()))

            local text1 = (
                format("|cffffd200%s:|r\n", L["equipmentSummary.equipmentStats"])..
                format("    %s: \n", _G[primaryStat] or L["equipmentSummary.mainStat"])..
                format("    %s: \n", ITEM_MOD_STAMINA_SHORT.."")..
                format("    %s: \n", ITEM_MOD_CRIT_RATING_SHORT.."")..
                format("    %s: \n", ITEM_MOD_HASTE_RATING_SHORT)..
                format("    %s: \n", ITEM_MOD_MASTERY_RATING_SHORT)..
                format("    %s: \n", ITEM_MOD_VERSATILITY)
            )
            local text2 = (
                "\n"..
                format("|cffffffff%d|r\n", totalStats[primaryStat] or 0)..
                format("|cffffffff%d|r\n", totalStats.ITEM_MOD_STAMINA_SHORT or 0)..
                format("|cff00ff00%d|r\n", totalStats.ITEM_MOD_CRIT_RATING_SHORT or 0)..
                format("|cff00ff00%d|r\n", totalStats.ITEM_MOD_HASTE_RATING_SHORT or 0)..
                format("|cff00ff00%d|r\n", totalStats.ITEM_MOD_MASTERY_RATING_SHORT or 0)..
                format("|cff00ff00%d|r\n", totalStats.ITEM_MOD_VERSATILITY or 0)
            )
            local text3 = (
                "\n\n\n"..
                format(" |c%s%s|r\n", (critBonus2 and "ffffff00") or "ff00ff00", (critBonus and format("%.1f%%", critBonus)) or "")..
                format(" |c%s%s|r\n", (hasteBonus2 and "ffffff00") or "ff00ff00", (hasteBonus and format("%.1f%%", hasteBonus)) or "")..
                format(" |c%s%s|r%s\n", (masteryBonus2 and "ffffff00") or "ff00ff00", (masteryBonus and format("%.1f%%", masteryBonus)) or "", (masteryCoefficient and format(" (x%.2f)", masteryCoefficient) or ""))..
                format(" |c%s%s|r\n", (versBonus2 and "ffffff00") or "ff00ff00", (versBonus and format("%.1f%%|cff7f7f7f/|r%.1f%%", versBonus, versBonus / 2)) or "")
            )

            if totalStats.ITEM_MOD_CR_SPEED_SHORT and totalStats.ITEM_MOD_CR_SPEED_SHORT > 0 then
                local bonus, bonus2 = Utils.CalculateStatsRatings("ITEM_MOD_CR_SPEED_SHORT", totalStats.ITEM_MOD_CR_SPEED_SHORT, level)
                text1 = text1..format("    %s: \n", ITEM_MOD_CR_SPEED_SHORT)
                text2 = text2..format("|cff007fff%d|r\n", totalStats.ITEM_MOD_CR_SPEED_SHORT or 0)
                text3 = text3..format(" |c%s%s|r\n", (bonus2 and "ffffff00") or "ff007fff", (bonus and format("%.1f%%", bonus)) or "")
            end
            if totalStats.ITEM_MOD_CR_LIFESTEAL_SHORT and totalStats.ITEM_MOD_CR_LIFESTEAL_SHORT > 0 then
                local bonus, bonus2 = Utils.CalculateStatsRatings("ITEM_MOD_CR_LIFESTEAL_SHORT", totalStats.ITEM_MOD_CR_LIFESTEAL_SHORT, level)
                text1 = text1..format("    %s: \n", ITEM_MOD_CR_LIFESTEAL_SHORT)
                text2 = text2..format("|cff007fff%d|r\n", totalStats.ITEM_MOD_CR_LIFESTEAL_SHORT or 0)
                text3 = text3..format(" |c%s%s|r\n", (bonus2 and "ffffff00") or "ff007fff", (bonus and format("%.1f%%", bonus)) or "")
            end
            if totalStats.ITEM_MOD_CR_AVOIDANCE_SHORT and totalStats.ITEM_MOD_CR_AVOIDANCE_SHORT > 0 then
                local bonus, bonus2 = Utils.CalculateStatsRatings("ITEM_MOD_CR_AVOIDANCE_SHORT", totalStats.ITEM_MOD_CR_AVOIDANCE_SHORT, level)
                text1 = text1..format("    %s: \n", ITEM_MOD_CR_AVOIDANCE_SHORT)
                text2 = text2..format("|cff007fff%d|r\n", totalStats.ITEM_MOD_CR_AVOIDANCE_SHORT or 0)
                text3 = text3..format(" |c%s%s|r\n", (bonus2 and "ffffff00") or "ff007fff", (bonus and format("%.1f%%", bonus)) or "")
            end

            self.ItemStatsText1:SetText(text1)
            self.ItemStatsText2:SetText(text2)
            self.ItemStatsText3:SetText(text3)
            self.ItemStatsTips:Show()
        else
            self.ItemStatsText1:SetText()
            self.ItemStatsText2:SetText()
            self.ItemStatsText3:SetText()
            self.ItemStatsTips:Hide()
        end

        local height = 12
            + self.Title:GetStringHeight()
            + 10
            + self.SubTitle:GetStringHeight()
            + (self.slotNum * (Module:GetConfig(CONFIG_FONT_SIZE) + 2))
            + 10
            + self.InfoText:GetStringHeight()
            + self.ItemStatsText1:GetStringHeight()
            + 12
        local width = 12
            + (Module:GetConfig(CONFIG_SLOT_NAME) and 42 or 0)
            + (Module:GetConfig(CONFIG_STAT_ICON) and (Module:GetConfig(CONFIG_FONT_SIZE) * 4 + 8) or 0)
            + (Module:GetConfig(CONFIG_FONT_SIZE) * (Module:GetConfig("itemUpgradeTrack.enable") and WIDTH_RATE[2] or WIDTH_RATE[1]))
            + 12
            + (Module:GetConfig("itemUpgradeTrack.enable") and (WIDTH_RATE[Module:GetConfig("itemUpgradeTrack.style") + 2] * Module:GetConfig(CONFIG_FONT_SIZE)) or 0)
        self:SetSize(width, height)
    end
end

function IIOEquipmentSummaryFrameMixin:RefreshItemLevelAndSpec(itemLevel, pvpItemLevel)
    local className, classFilename = UnitClass(self.unit)
    local classColor = C_ClassColor.GetClassColor(classFilename)
    local hexColorMarkup = classColor and classColor:GenerateHexColorMarkup() or "|cffffffff"

    local specName, specIcon
    if self.unit == "player" then
        if not itemLevel then
            _, itemLevel = GetAverageItemLevel()
        end
        _, specName, _, specIcon = GetSpecializationInfo(GetSpecialization())
    else
        if not itemLevel then
            itemLevel = C_PaperDollInfo.GetInspectItemLevel(self.unit)
        end
        _, specName, _, specIcon = GetSpecializationInfoForSpecID(GetInspectSpecialization(self.unit))
    end

    if pvpItemLevel and pvpItemLevel > itemLevel then
        self.SubTitle:SetFormattedText(ITEM_LEVEL_AND_SPEC_WITH_PVP_FORMAT, itemLevel, hexColorMarkup, specName or "", className, pvpItemLevel)
    else
        self.SubTitle:SetFormattedText(ITEM_LEVEL_AND_SPEC_FORMAT, itemLevel, hexColorMarkup, specName or "", className)
    end

    if specIcon then
        self.SpecIcon:SetTexture(specIcon)
        self.SpecIcon:Show()
    else
        self.SpecIcon:Hide()
    end
end

local function UpdateSummaryPoints()
    local characterRelative = CharacterFrame
    if CCS_TOAST then
        characterRelative = CharacterFrameBg
    end

    if preview then
        IIOEquipmentSummaryPlayerFrame:Show()
        IIOEquipmentSummaryPlayerFrame:ClearAllPoints()
        IIOEquipmentSummaryPlayerFrame:SetParent(SettingsPanel)
        IIOEquipmentSummaryPlayerFrame:SetPoint("TOPLEFT", SettingsPanel, "TOPRIGHT")
    elseif Module:GetConfig(CONFIG_INSPECT_ENABLE) and InspectFrame and InspectFrame:IsVisible() then
        IIOEquipmentSummaryInspectFrame:Show()

        if Module:GetConfig(CONFIG_PLAYER_ENABLE) then
            IIOEquipmentSummaryPlayerFrame:Show()
            IIOEquipmentSummaryPlayerFrame:ClearAllPoints()
            IIOEquipmentSummaryPlayerFrame:SetParent(IIOEquipmentSummaryInspectFrame)
            IIOEquipmentSummaryPlayerFrame:SetPoint("TOPLEFT", IIOEquipmentSummaryInspectFrame, "TOPRIGHT")
        end

        if PaperDollFrame:IsVisible() then
            IIOEquipmentSummaryInspectFrame:ClearAllPoints()
            IIOEquipmentSummaryInspectFrame:SetParent(PaperDollFrame)
            IIOEquipmentSummaryInspectFrame:SetPoint("TOPLEFT", characterRelative, "TOPRIGHT")
        else
            IIOEquipmentSummaryInspectFrame:ClearAllPoints()
            IIOEquipmentSummaryInspectFrame:SetParent(InspectFrame)
            IIOEquipmentSummaryInspectFrame:SetPoint("TOPLEFT", InspectFrame, "TOPRIGHT")
        end
    elseif Module:GetConfig(CONFIG_PLAYER_ENABLE) and PaperDollFrame:IsVisible() then
        IIOEquipmentSummaryInspectFrame:Hide()
        IIOEquipmentSummaryPlayerFrame:Show()
        IIOEquipmentSummaryPlayerFrame:ClearAllPoints()
        IIOEquipmentSummaryPlayerFrame:SetParent(PaperDollFrame)
        IIOEquipmentSummaryPlayerFrame:SetPoint("TOPLEFT", characterRelative, "TOPRIGHT")
    else
        IIOEquipmentSummaryInspectFrame:Hide()
        IIOEquipmentSummaryPlayerFrame:Hide()
    end
end

IIOEquipmentSummarySettingPreviewMixin = {}

function IIOEquipmentSummarySettingPreviewMixin:OnLoad()
end

function IIOEquipmentSummarySettingPreviewMixin:OnShow()
    preview = true
    UpdateSummaryPoints()
end

function IIOEquipmentSummarySettingPreviewMixin:OnHide()
    preview = false
    UpdateSummaryPoints()
end

PaperDollFrame:HookScript("OnShow", function(self)
    IIOEquipmentSummaryPlayerFrame:Refresh()
    UpdateSummaryPoints()
end)

PaperDollFrame:HookScript("OnHide", function(self)
    UpdateSummaryPoints()
end)

function Module:AfterLogin()
    IIOEquipmentSummaryPlayerFrame:UpdateAppearance()
    IIOEquipmentSummaryPlayerFrame:SetUnit("player")
end

function Module:ADDON_LOADED(AddOnName)
    if AddOnName == "Blizzard_InspectUI" then
        IIOEquipmentSummaryInspectFrame:UpdateAppearance()

        hooksecurefunc("InspectPaperDollFrame_UpdateButtons", function ()
            IIOEquipmentSummaryInspectFrame:SetUnit(InspectFrame.unit)
            UpdateSummaryPoints()
        end)

        hooksecurefunc(InspectFrame, "Hide", function ()
            UpdateSummaryPoints()
        end)
    end
end
Module:RegisterEvent("ADDON_LOADED")

function Module:PLAYER_EQUIPMENT_CHANGED()
    IIOEquipmentSummaryPlayerFrame:Refresh()
end
Module:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")

function Module:UNIT_INVENTORY_CHANGED(unit)
    if unit == "player" then
        IIOEquipmentSummaryPlayerFrame:Refresh()
    end
end
Module:RegisterEvent("UNIT_INVENTORY_CHANGED")

function Module:PLAYER_AVG_ITEM_LEVEL_UPDATE()
    IIOEquipmentSummaryPlayerFrame:Refresh()
end
Module:RegisterEvent("PLAYER_AVG_ITEM_LEVEL_UPDATE")

function Module:ACTIVE_PLAYER_SPECIALIZATION_CHANGED()
    IIOEquipmentSummaryPlayerFrame:Refresh()
end
Module:RegisterEvent("ACTIVE_PLAYER_SPECIALIZATION_CHANGED")