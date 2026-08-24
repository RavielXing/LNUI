local ADDON_NAME, ItemInfoOverlay = ...

local Module = ItemInfoOverlay:NewModule("characterFrame")
local Utils = ItemInfoOverlay:GetModule("utils")
local L = ItemInfoOverlay.Locale

local CONFIG_ITEM_LEVEL = "itemLevel.enable"
local CONFIG_ITEM_LEVEL_FONT = "itemLevel.font"
local CONFIG_ITEM_LEVEL_FONT_SIZE = "itemLevel.fontSize"
local CONFIG_ITEM_LEVEL_POINT = "itemLevel.point"
local CONFIG_ITEM_LEVEL_ANCHOR_TO_ICON = "itemLevel.anchorToIcon"
local CONFIG_PVP_ITEM_LEVEL = "pvpItemLevel.enable"
local CONFIG_PVP_ITEM_LEVEL_FONT = "pvpItemLevel.font"
local CONFIG_PVP_ITEM_LEVEL_FONT_SIZE = "pvpItemLevel.fontSize"
local CONFIG_PVP_ITEM_LEVEL_POINT = "pvpItemLevel.point"
local CONFIG_PVP_ITEM_LEVEL_ANCHOR_TO_ICON = "pvpItemLevel.customAnchor"
local CONFIG_SOCKET = "socket.enable"
local CONFIG_SOCKET_ICON_SIZE = "socket.iconSize"
local CONFIG_SOCKET_DISPLAY_MAX_SOCKETS = "socket.displayMaxSockets"
local CONFIG_ENCHANT = "enchant.enable"
local CONFIG_ENCHANT_DISPLAY_MISSING = "enchant.displayMissing"
local CONFIG_ENCHANT_FONT = "enchant.font"
local CONFIG_ENCHANT_FONT_SIZE = "enchant.fontSize"
local CONFIG_DURABILITY = "durability.enable"
local CONFIG_DURABILITY_POINT = "durability.point"
local CONFIG_DURABILITY_FONT = "durability.font"
local CONFIG_DURABILITY_FONT_SIZE = "durability.fontSize"

local CHARACTER_PREFIX = "Character"
local INSPECT_PREFIX = "Inspect"
local SLOT_SUFFIX = "Slot"

local ENCHANT_PATTERN = ENCHANTED_TOOLTIP_LINE:gsub("%%s", "(.*)")
local ENCHANT_QUALITY_PATTERN = "(.*)|A:(.*):20:20|a"

local EQUIPMENT_SLOTS = {
    [1] = {id = 1, side = "LEFT", name = "Head"},
    [2] = {id = 2, side = "LEFT", name = "Neck"},
    [3] = {id = 3, side = "LEFT", name = "Shoulder"},
    [4] = {id = 4, side = "LEFT", name = "Shirt"},
    [5] = {id = 5, side = "LEFT", name = "Chest"},
    [6] = {id = 6, side = "RIGHT", name = "Waist"},
    [7] = {id = 7, side = "RIGHT", name = "Legs"},
    [8] = {id = 8, side = "RIGHT", name = "Feet"},
    [9] = {id = 9, side = "LEFT", name = "Wrist"},
    [10] = {id = 10, side = "RIGHT", name = "Hands"},
    [11] = {id = 11, side = "RIGHT", name = "Finger0"},
    [12] = {id = 12, side = "RIGHT", name = "Finger1"},
    [13] = {id = 13, side = "RIGHT", name = "Trinket0"},
    [14] = {id = 14, side = "RIGHT", name = "Trinket1"},
    [15] = {id = 15, side = "LEFT", name = "Back"},
    [16] = {id = 16, side = "RIGHT", name = "MainHand", offsetY = -8},
    [17] = {id = 17, side = "LEFT", name = "SecondaryHand", offsetY = -8},
    [19] = {id = 19, side = "LEFT", name = "Tabard"}
}

local POINTS = {
    "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT"
}

local POINTS_PVP_ITEM_LEVEL_ANCHOR_TO_ITEMLEVEL = {
    {"TOPLEFT", "BOTTOMLEFT", -1}, {"TOP", "BOTTOM", -1}, {"TOPRIGHT", "BOTTOMRIGHT", -1},
    {"TOPLEFT", "BOTTOMLEFT", -1}, {"TOP", "BOTTOM", -1}, {"TOPRIGHT", "BOTTOMRIGHT", -1},
    {"BOTTOMLEFT", "TOPLEFT", 1}, {"BOTTOM", "TOP", -1}, {"BOTTOMRIGHT", "TOPRIGHT", -1},
}

local itemInfoOverlayPool = {}

-- 12.1优化: 预创建可复用的脚本函数，避免每次SetItemData创建新闭包
local function GemSocket_OnEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if self.gemLink then
        GameTooltip:SetHyperlink(self.gemLink)
    elseif self.socketText then
        GameTooltip:SetText(self.socketText)
    end
    GameTooltip:Show()
end

local function GemSocket_OnLeave(self)
    GameTooltip:Hide()
end

local function AddSocket_OnEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
    GameTooltip:SetText(L["characterFrame.socket.displayMaxSockets.message"])
    if self.addSocketItemLink then
        IIOTooltip:SetOwner(GameTooltip, "ANCHOR_NONE")
        IIOTooltip:SetPoint("TOPLEFT", GameTooltip, "BOTTOMLEFT", 0, -2)
        IIOTooltip:SetHyperlink(self.addSocketItemLink)
        if self.addSocketItemSource then
            IIOTooltip:AddLine(" ")
            IIOTooltip:AddLine(L["characterFrame.socket.displayMaxSockets.itemSource."..self.addSocketItemSource])
        end
        IIOTooltip:Show()
    end
    GameTooltip:Show()
end

local function AddSocket_OnLeave(self)
    GameTooltip:Hide()
    IIOTooltip:Hide()
end

--------------------
-- Mixin
--------------------
IIOCharacterFrameItemInfoOverlayMixin = {}

function IIOCharacterFrameItemInfoOverlayMixin:SetSide(isLeft)
    self.side = isLeft and "LEFT" or "RIGHT"
    self.EnchantQuality:ClearAllPoints()
    self.EnchantQuality:SetPoint(isLeft and "LEFT" or "RIGHT", self.Enchant, isLeft and "RIGHT" or "LEFT", isLeft and -4 or 4, 0)
    self.GemSocket2:ClearAllPoints()
    self.GemSocket2:SetPoint(isLeft and "LEFT" or "RIGHT", self.GemSocket1, isLeft and "RIGHT" or "LEFT", 0, 0)
    self.GemSocket3:ClearAllPoints()
    self.GemSocket3:SetPoint(isLeft and "LEFT" or "RIGHT", self.GemSocket2, isLeft and "RIGHT" or "LEFT", 0, 0)
end

function IIOCharacterFrameItemInfoOverlayMixin:UpdateAppearance()
    self.ItemLevel:SetFont(Module:GetConfig(CONFIG_ITEM_LEVEL_FONT), Module:GetConfig(CONFIG_ITEM_LEVEL_FONT_SIZE), "OUTLINE")
    if Module:GetConfig(CONFIG_ITEM_LEVEL) and not Module:GetConfig(CONFIG_ITEM_LEVEL_ANCHOR_TO_ICON) then
        self.ItemLevel:SetJustifyH(self.side == "LEFT" and "LEFT" or "RIGHT")
        self.ItemLevel:SetWidth(Module:GetConfig(CONFIG_ITEM_LEVEL_FONT_SIZE) * 3)
        self.ItemLevel:ClearAllPoints()
        self.ItemLevel:SetPoint(
            self.side == "LEFT" and "LEFT" or "RIGHT",
            self,
            self.side == "LEFT" and "RIGHT" or "LEFT",
            (self.side == "LEFT" and 1 or -1) * (8 + Module:GetConfig("itemLevel.offsetX")),
            Module:GetConfig("itemLevel.offsetY")
        )
    else
        self.ItemLevel:SetWidth(0)
        self.ItemLevel:ClearAllPoints()
        self.ItemLevel:SetPoint(
            POINTS[Module:GetConfig(CONFIG_ITEM_LEVEL_POINT)],
            self, POINTS[Module:GetConfig(CONFIG_ITEM_LEVEL_POINT)],
            (self.side == "LEFT" and 1 or -1) * (Module:GetConfig("itemLevel.offsetX")),
            Module:GetConfig("itemLevel.offsetY")
        )
    end

    self.PvPItemLevel:SetFont(Module:GetConfig(CONFIG_PVP_ITEM_LEVEL_FONT), Module:GetConfig(CONFIG_PVP_ITEM_LEVEL_FONT_SIZE), "OUTLINE")
    if Module:GetConfig(CONFIG_PVP_ITEM_LEVEL_ANCHOR_TO_ICON) then
        self.PvPItemLevel:ClearAllPoints()
        self.PvPItemLevel:SetPoint(
            POINTS[Module:GetConfig(CONFIG_PVP_ITEM_LEVEL_POINT)],
            self, POINTS[Module:GetConfig(CONFIG_PVP_ITEM_LEVEL_POINT)],
            (self.side == "LEFT" and 1 or -1) * (Module:GetConfig("pvpItemLevel.offsetX")),
            Module:GetConfig("pvpItemLevel.offsetY")
        )
    elseif Module:GetConfig(CONFIG_ITEM_LEVEL) and Module:GetConfig(CONFIG_ITEM_LEVEL_ANCHOR_TO_ICON) then
        local anchor = POINTS_PVP_ITEM_LEVEL_ANCHOR_TO_ITEMLEVEL[Module:GetConfig(CONFIG_PVP_ITEM_LEVEL_POINT)]
        self.PvPItemLevel:ClearAllPoints()
        self.PvPItemLevel:SetPoint(anchor[1], self.ItemLevel, anchor[2],
            (self.side == "LEFT" and 1 or -1) * (Module:GetConfig("pvpItemLevel.offsetX")),
            anchor[3] + Module:GetConfig("pvpItemLevel.offsetY"))
    else
        self.PvPItemLevel:ClearAllPoints()
        self.PvPItemLevel:SetPoint("TOP", self, "TOP",
            (self.side == "LEFT" and 1 or -1) * (Module:GetConfig("pvpItemLevel.offsetX")),
            Module:GetConfig("pvpItemLevel.offsetY"))
    end

    self.Enchant:SetFont(Module:GetConfig(CONFIG_ENCHANT_FONT), Module:GetConfig(CONFIG_ENCHANT_FONT_SIZE), "OUTLINE")
    self.Enchant:ClearAllPoints()
    self.Enchant:SetPoint(
        self.side == "LEFT" and "LEFT" or "RIGHT",
        self,
        self.side == "LEFT" and "RIGHT" or "LEFT",
        (self.side == "LEFT" and 1 or -1) * (8 + Module:GetConfig("enchant.offsetX")),
        0
    )
    self.EnchantQuality:SetFont(Module:GetConfig(CONFIG_ENCHANT_FONT), Module:GetConfig(CONFIG_ENCHANT_FONT_SIZE), "OUTLINE")

    self.GemSocket1:SetSize(Module:GetConfig(CONFIG_SOCKET_ICON_SIZE), Module:GetConfig(CONFIG_SOCKET_ICON_SIZE))
    self.GemSocket1.Quality:SetFont(Module:GetConfig(CONFIG_ENCHANT_FONT), Module:GetConfig(CONFIG_SOCKET_ICON_SIZE) - 2, "OUTLINE")
    self.GemSocket2:SetSize(Module:GetConfig(CONFIG_SOCKET_ICON_SIZE), Module:GetConfig(CONFIG_SOCKET_ICON_SIZE))
    self.GemSocket2.Quality:SetFont(Module:GetConfig(CONFIG_ENCHANT_FONT), Module:GetConfig(CONFIG_SOCKET_ICON_SIZE) - 2, "OUTLINE")
    self.GemSocket3:SetSize(Module:GetConfig(CONFIG_SOCKET_ICON_SIZE), Module:GetConfig(CONFIG_SOCKET_ICON_SIZE))
    self.GemSocket3.Quality:SetFont(Module:GetConfig(CONFIG_ENCHANT_FONT), Module:GetConfig(CONFIG_SOCKET_ICON_SIZE) - 2, "OUTLINE")
    
    if Module:GetConfig(CONFIG_ITEM_LEVEL) and not Module:GetConfig(CONFIG_ITEM_LEVEL_ANCHOR_TO_ICON) then
        self.GemSocket1:ClearAllPoints()
        self.GemSocket1:SetPoint(
            self.side == "LEFT" and "LEFT" or "RIGHT",
            self.ItemLevel,
            self.side == "LEFT" and "RIGHT" or "LEFT",
            (self.side == "LEFT" and 1 or -1) * (-2 + Module:GetConfig("socket.offsetX")),
            0
        )
    else
        self.GemSocket1:ClearAllPoints()
        self.GemSocket1:SetPoint(
            (self.side == "LEFT" and "LEFT") or "RIGHT",
            self,
            (self.side == "LEFT" and "RIGHT") or "LEFT",
            (self.side == "LEFT" and 1 or -1) * (9 + Module:GetConfig("socket.offsetX")),
            0
        )
    end

    self.Durability:SetFont(Module:GetConfig(CONFIG_DURABILITY_FONT), Module:GetConfig(CONFIG_DURABILITY_FONT_SIZE), "OUTLINE")
    self.Durability:ClearAllPoints()
    self.Durability:SetPoint(
        POINTS[Module:GetConfig(CONFIG_DURABILITY_POINT)],
        self, POINTS[Module:GetConfig(CONFIG_DURABILITY_POINT)],
        (self.side == "LEFT" and 1 or -1) * Module:GetConfig("durability.offsetX"),
        Module:GetConfig("durability.offsetY")
    )
    self.Durability:SetShown(Module:GetConfig(CONFIG_DURABILITY))

    self:Refresh()
end

function IIOCharacterFrameItemInfoOverlayMixin:UpdateLines()
    local line1, line2
    if (not Module:GetConfig(CONFIG_ITEM_LEVEL_ANCHOR_TO_ICON) and self.ItemLevel:IsShown()) or self.GemSocket1:IsShown() then
        line1 = true
    end
    if self.Enchant:IsShown() then
        line2 = true
    end

    local point, relativeTo, relativePoint, offsetX, offsetY
    if line1 and line2 then
        if (not Module:GetConfig(CONFIG_ITEM_LEVEL_ANCHOR_TO_ICON) and self.ItemLevel:IsShown()) then
            point, relativeTo, relativePoint, offsetX, offsetY = self.ItemLevel:GetPointByName(self.side)
            self.ItemLevel:SetPoint(point, relativeTo, relativePoint, offsetX, (Module:GetConfig(CONFIG_ITEM_LEVEL_FONT_SIZE) / 2) + 1 + (self.offsetY or 0))
        else
            point, relativeTo, relativePoint, offsetX, offsetY = self.GemSocket1:GetPointByName(self.side)
            self.GemSocket1:SetPoint(point, relativeTo, relativePoint, offsetX, (Module:GetConfig(CONFIG_SOCKET_ICON_SIZE) / 2) + (self.offsetY or 0))
        end
        point, relativeTo, relativePoint, offsetX, offsetY = self.Enchant:GetPointByName(self.side)
        self.Enchant:SetPoint(point, relativeTo, relativePoint, offsetX, - (Module:GetConfig(CONFIG_ITEM_LEVEL_FONT_SIZE) / 2) - 1 + (self.offsetY or 0))
    else
        if (not Module:GetConfig(CONFIG_ITEM_LEVEL_ANCHOR_TO_ICON) and self.ItemLevel:IsShown()) then
            point, relativeTo, relativePoint, offsetX, offsetY = self.ItemLevel:GetPointByName(self.side)
            self.ItemLevel:SetPoint(point, relativeTo, relativePoint, offsetX, self.offsetY or 0)
        else
            point, relativeTo, relativePoint, offsetX, offsetY = self.GemSocket1:GetPointByName(self.side)
            self.GemSocket1:SetPoint(point, relativeTo, relativePoint, offsetX, self.offsetY or 0)
        end
        point, relativeTo, relativePoint, offsetX, offsetY = self.Enchant:GetPointByName(self.side)
        self.Enchant:SetPoint(point, relativeTo, relativePoint, offsetX, self.offsetY or 0)
    end
end

function IIOCharacterFrameItemInfoOverlayMixin:SetItemData(itemLevel, itemLink, tooltipInfo, pvpItemLevel)
    local itemName, _, itemQuality, _, itemMinLevel, itemType, itemSubType, 
    itemStackCount, itemEquipLoc, itemTexture, sellPrice, classID, subclassID, bindType,
    expacID, setID, isCraftingReagent = C_Item.GetItemInfo(itemLink)

    local itemEnchant, itemEnchantQuality
    local itemGemSocketCount = 0
    local itemGemSockets = {}
    local itemGemSocketsText = {}
    
    if tooltipInfo then
        for _, line in ipairs(tooltipInfo.lines) do
            local text = line.leftText
            if line.type == Enum.TooltipDataLineType.ItemEnchantmentPermanent then
                local enchant = string.match(text, ENCHANT_PATTERN)
                if enchant then
                    if string.find(enchant, "|A:") then
                        itemEnchant, itemEnchantQuality = string.match(enchant, ENCHANT_QUALITY_PATTERN)
                    else
                        itemEnchant = enchant
                    end
                    itemEnchant = itemEnchant:gsub(".+ %- ", ""):gsub("[ \\+]", "")
                end
            elseif line.type == Enum.TooltipDataLineType.GemSocket then
                itemGemSocketCount = itemGemSocketCount + 1
                if line.socketType then
                    itemGemSockets[itemGemSocketCount] = string.format("Interface\\ItemSocketingFrame\\UI-EmptySocket-%s", line.socketType)
                    itemGemSocketsText[itemGemSocketCount] = line.leftText
                end
            end
        end
    end

    if Module:GetConfig(CONFIG_ITEM_LEVEL) and itemLevel and itemLevel > 1 then
        self.ItemLevel:SetText(Utils.GetColoredItemLevelText(itemLevel, itemLink))
        self.ItemLevel:Show()
    else
        self.ItemLevel:Hide()
    end

    if Module:GetConfig(CONFIG_PVP_ITEM_LEVEL) then
        if not Module:GetConfig(CONFIG_ITEM_LEVEL) then
            if pvpItemLevel then
                self.PvPItemLevel:SetText(Utils.GetColoredItemLevelText(pvpItemLevel, itemLink, true))
            else
                self.PvPItemLevel:SetText(Utils.GetColoredItemLevelText(itemLevel, itemLink))
            end
            self.PvPItemLevel:Show()
        elseif pvpItemLevel and pvpItemLevel > itemLevel then
            self.PvPItemLevel:SetText(Utils.GetColoredItemLevelText("("..pvpItemLevel..")", itemLink, true))
            self.PvPItemLevel:Show()
        else
            self.PvPItemLevel:Hide()
        end
    else
        self.PvPItemLevel:Hide()
    end

    if Module:GetConfig(CONFIG_ENCHANT) and itemEnchant then
        self.Enchant:SetTextToFit(itemEnchant, "")
        self.Enchant:Show()
        if self.Enchant:GetUnboundedStringWidth() >= 80 then
            self.Enchant:SetWidth(80)
        end
        if itemEnchantQuality then
            self.EnchantQuality:SetText("|A:"..itemEnchantQuality..":20:20|a")
            self.EnchantQuality:Show()
        else
            self.EnchantQuality:Hide()
        end
    elseif Module:GetConfig(CONFIG_ENCHANT) and Module:GetConfig(CONFIG_ENCHANT_DISPLAY_MISSING) and Utils.ItemCanEnchant(itemLevel, itemEquipLoc) then
        self.Enchant:SetTextToFit("|cffff0000"..L["characterFrame.enchant.displayMissing.noenchant"].."|r")
        self.Enchant:Show()
        if self.Enchant:GetUnboundedStringWidth() >= 80 then
            self.Enchant:SetWidth(80)
        end
        self.EnchantQuality:Hide()
    else
        self.EnchantQuality:Hide()
        self.Enchant:Hide()
    end

    if Module:GetConfig(CONFIG_SOCKET) then
        local maxSocketsNum, addSocketItemInfo = Utils.ItemMaxSockets(itemLevel, itemLink, pvpItemLevel)
        
        -- 12.1优化: 使用loadToken取消过期宝石加载回调
        self.socketLoadToken = (self.socketLoadToken or 0) + 1
        local currentToken = self.socketLoadToken

        for i = 1, 3 do
            local socketIcon = self["GemSocket"..i]
            if socketIcon then
                local gemID = C_Item.GetItemGemID(itemLink, i)
                if gemID then
                    if not C_Item.IsItemDataCachedByID(gemID) then
                        socketIcon:SetNormalTexture("Interface\\ItemSocketingFrame\\UI-EmptySocket-Prismatic")
                        socketIcon:GetNormalTexture():SetVertexColor(1, 1, 1)
                        socketIcon:SetAlpha(1)
                    end
                    -- 12.1优化: 闭包中只捕获必要变量，减少闭包大小
                    local gemItem = Item:CreateFromItemID(gemID)
                    gemItem:ContinueOnItemLoad(function()
                        if self.socketLoadToken ~= currentToken then return end
                        local _, gemLink = C_Item.GetItemGem(itemLink, i)
                        if gemLink then
                            local _, _, _, _, _, _, _, _, _, gemIcon = C_Item.GetItemInfo(gemLink)
                            local professionQuality = C_TradeSkillUI.GetItemReagentQualityInfo(gemID)
                            
                            socketIcon:SetNormalTexture(gemIcon or "Interface\\ItemSocketingFrame\\UI-EmptySocket-Prismatic")
                            socketIcon:GetNormalTexture():SetVertexColor(1, 1, 1)
                            socketIcon:SetAlpha(1)
                            
                            -- 12.1优化: 使用预定义脚本函数，避免每次创建新闭包
                            socketIcon.gemLink = gemLink
                            socketIcon.socketText = nil
                            socketIcon:SetScript("OnEnter", GemSocket_OnEnter)
                            socketIcon:SetScript("OnLeave", GemSocket_OnLeave)
                            
                            if professionQuality then
                                socketIcon.Quality:SetText("|A:"..professionQuality.icon..":16:16|a")
                                socketIcon.Quality:Show()
                            else
                                socketIcon.Quality:Hide()
                            end
                            socketIcon:Show()
                        end
                    end)
                else
                    -- 没有宝石
                    if i <= itemGemSocketCount then
                        if itemGemSockets[i] then
                            socketIcon:SetNormalTexture(itemGemSockets[i])
                            socketIcon:GetNormalTexture():SetVertexColor(1, 1, 1)
                            socketIcon:SetAlpha(1)
                            socketIcon.gemLink = nil
                            socketIcon.socketText = itemGemSocketsText[i]
                            socketIcon:SetScript("OnEnter", GemSocket_OnEnter)
                            socketIcon:SetScript("OnLeave", GemSocket_OnLeave)
                            socketIcon:Show()
                            socketIcon.Quality:Hide()
                        else
                            socketIcon:Hide()
                            socketIcon.Quality:Hide()
                        end
                    elseif Module:GetConfig(CONFIG_SOCKET_DISPLAY_MAX_SOCKETS) and i <= maxSocketsNum then
                        if addSocketItemInfo then
                            local addSocketItem = Item:CreateFromItemID(addSocketItemInfo[1])
                            socketIcon.addSocketItemSource = addSocketItemInfo[2]
                            socketIcon.addSocketItemLink = C_Item.GetItemInfo(addSocketItemInfo[1]) or "[...]"
                            addSocketItem:ContinueOnItemLoad(function()
                                if self.socketLoadToken ~= currentToken then return end
                                local link = select(2, C_Item.GetItemInfo(addSocketItemInfo[1]))
                                if link then
                                    socketIcon.addSocketItemLink = link
                                end
                            end)
                        else
                            socketIcon.addSocketItemSource = nil
                            socketIcon.addSocketItemLink = nil
                        end

                        socketIcon:SetNormalTexture("Interface\\ItemSocketingFrame\\UI-EmptySocket-Prismatic")
                        socketIcon:GetNormalTexture():SetVertexColor(1, 0, 0)
                        socketIcon:SetAlpha(0.75)
                        socketIcon.gemLink = nil
                        socketIcon.socketText = nil
                        socketIcon:SetScript("OnEnter", AddSocket_OnEnter)
                        socketIcon:SetScript("OnLeave", AddSocket_OnLeave)
                        socketIcon:Show()
                        socketIcon.Quality:Hide()
                    else
                        socketIcon:Hide()
                        socketIcon.Quality:Hide()
                    end
                end
            end
        end
    else
        self.GemSocket1:Hide()
        self.GemSocket2:Hide()
        self.GemSocket3:Hide()
    end

    self:Show()
    self:UpdateLines()
end

function IIOCharacterFrameItemInfoOverlayMixin:SetItemFromLocation(itemLocation)
    self.itemLocation = itemLocation
    self.itemLink = nil

    if itemLocation and itemLocation:IsValid() then
        local itemLink = C_Item.GetItemLink(itemLocation)
        local tooltipInfo
        if itemLocation:IsBagAndSlot() then
            tooltipInfo = C_TooltipInfo.GetBagItem(itemLocation:GetBagAndSlot())
        elseif itemLocation:IsEquipmentSlot() then
            tooltipInfo = C_TooltipInfo.GetInventoryItem("player", itemLocation:GetEquipmentSlot())
        else
            tooltipInfo = C_TooltipInfo.GetHyperlink(itemLink)
        end

        local itemLevel, _, pvpItemLevel = Utils.GetItemLevelFromTooltipInfo(tooltipInfo)
        if not itemLevel then
            itemLevel = C_Item.GetCurrentItemLevel(itemLocation)
        end

        self:SetItemData(itemLevel, itemLink, tooltipInfo, pvpItemLevel)
        return itemLevel, itemLink, tooltipInfo
    else
        self:Hide()
    end
end

function IIOCharacterFrameItemInfoOverlayMixin:SetItemFromLink(itemLink)
    if itemLink then
        self.itemLocation = nil
        self.itemLink = itemLink

        local tooltipInfo = C_TooltipInfo.GetHyperlink(itemLink)
        local itemLevel, _, pvpItemLevel = Utils.GetItemLevelFromTooltipInfo(tooltipInfo)

        if not itemLevel then
            itemLevel = GetDetailedItemLevelInfo(itemLink)
        end

        self:SetItemData(itemLevel, itemLink, tooltipInfo, pvpItemLevel)
        return itemLevel, itemLink, tooltipInfo
    else
        self:Hide()
    end
end

function IIOCharacterFrameItemInfoOverlayMixin:SetItemFromUnitInventory(unit, slotID)
    local itemLink = GetInventoryItemLink(unit, slotID)

    if itemLink then
        local tooltipInfo = C_TooltipInfo.GetInventoryItem(unit, slotID)
        local itemLevel, _, pvpItemLevel = Utils.GetItemLevelFromTooltipInfo(tooltipInfo)

        if not itemLevel then
            itemLevel = GetDetailedItemLevelInfo(itemLink)
        end

        self:SetItemData(itemLevel, itemLink, tooltipInfo, pvpItemLevel)
        return itemLevel, itemLink, tooltipInfo
    else
        self:Hide()
    end
end

function IIOCharacterFrameItemInfoOverlayMixin:UpdateDurability()
    if self.itemLocation and self.itemLocation:IsEquipmentSlot() then
        local current, maximum = GetInventoryItemDurability(self.itemLocation:GetEquipmentSlot())
        if current and maximum then
            local percent = current / maximum * 100
            if percent > 50 then
                self.Durability:SetText(format("|cff00ff00%d%%|r", percent))
            elseif percent > 20 then
                self.Durability:SetText(format("|cffffff00%d%%|r", percent))
            else
                self.Durability:SetText(format("|cffff0000%d%%|r", percent))
            end
        else
            self.Durability:SetText()
        end
    end
end

function IIOCharacterFrameItemInfoOverlayMixin:Clear()
    self.itemLocation = nil
    self.itemLink = nil
    self.socketLoadToken = nil
    self:Hide()
end

function IIOCharacterFrameItemInfoOverlayMixin:Refresh()
    if self.itemLocation then
        self:SetItemFromLocation(self.itemLocation)
    elseif self.itemLink then
        self:SetItemFromLink(self.itemLink)
    else
        self:Hide()
    end
end

IIOCharacterFrameItemInfoOverlaySettingPreviewMixin = {}

function IIOCharacterFrameItemInfoOverlaySettingPreviewMixin:OnLoad()
    self.itemButton1:SetItemButtonTexture(6035288)
    self.itemButton1:SetItemButtonQuality(Enum.ItemQuality.Epic)
    local overlay = Module:CreateItemInfoOverlay(self.itemButton1, 1)
    overlay.Durability:SetText("|cff00ff00100%|r")
    local testItem1 = Item:CreateFromItemID(220202)
    testItem1:ContinueOnItemLoad(function()
        overlay:SetItemFromLink("|cffa335ee|Hitem:220202:7346:213746:213482:::::80:102::6:7:12030:6652:10356:10299:1540:10255:11215:1:28:2462:::|h[间谍大师裹网]|h|r")
    end)

    self.itemButton2:SetItemButtonTexture(6035288)
    self.itemButton2:SetItemButtonQuality(Enum.ItemQuality.Epic)
    local overlay2 = Module:CreateItemInfoOverlay(self.itemButton2, 6)
    overlay2.Durability:SetText("|cff00ff00100%|r")
    local testItem2 = Item:CreateFromItemID(220202)
    testItem2:ContinueOnItemLoad(function()
        overlay2:SetItemFromLink("|cffa335ee|Hitem:220202:7346:213746:213482:::::80:102::6:7:12030:6652:10356:10299:1540:10255:11215:1:28:2462:::|h[间谍大师裹网]|h|r")
    end)
end

--------------------
-- 
--------------------

function Module:CreateItemInfoOverlay(frame, slot)
    frame.ItemInfoOverlay = CreateFrame("Frame", nil, frame, "IIOCharacterFrameItemInfoOverlayTemplate")
    local overlay = frame.ItemInfoOverlay
    tinsert(itemInfoOverlayPool, overlay)

    if slot then
        overlay.slot = slot
        overlay.side = EQUIPMENT_SLOTS[slot].side
        overlay.offsetY = EQUIPMENT_SLOTS[slot].offsetY
        overlay:SetAllPoints(frame)
        overlay:SetSide(EQUIPMENT_SLOTS[slot].side == "LEFT")
        overlay:UpdateAppearance()
    end
    return overlay
end

local function GetItemInfoOverlayFromSlotID(slotID, isInspect)
    if slotID and EQUIPMENT_SLOTS[slotID] then
        if isInspect then
            if InspectFrame then
                return _G[INSPECT_PREFIX..EQUIPMENT_SLOTS[slotID].name..SLOT_SUFFIX].ItemInfoOverlay
            end
        else
            return _G[CHARACTER_PREFIX..EQUIPMENT_SLOTS[slotID].name..SLOT_SUFFIX].ItemInfoOverlay
        end
    end
end

function Module:UpdateAllAppearance()
    for _, overlay in ipairs(itemInfoOverlayPool) do
        overlay:UpdateAppearance()
    end
end

function Module:UpdateAllInspectSlot ()
    if InspectFrame and InspectFrame.unit then
        for slotID in pairs(EQUIPMENT_SLOTS) do
            local overlay = GetItemInfoOverlayFromSlotID(slotID, true)
            if overlay then
                overlay:SetItemFromUnitInventory(InspectFrame.unit, slotID)
            end
        end
    end
end

function Module:UpdateAllCharacterSlot()
    for slotID in pairs(EQUIPMENT_SLOTS) do
        local overlay = GetItemInfoOverlayFromSlotID(slotID)
        if overlay then
            overlay:SetItemFromLocation(ItemLocation:CreateFromEquipmentSlot(slotID))
        end
    end
end

function Module:UpdateAllCharacterSlotDurability()
    for slotID in pairs(EQUIPMENT_SLOTS) do
        local overlay = GetItemInfoOverlayFromSlotID(slotID)
        if overlay then
            overlay:UpdateDurability()
        end
    end
end

function Module:UpdateItemLocation(itemLocation)
    if itemLocation and itemLocation:IsValid() and itemLocation:IsEquipmentSlot() then
        local slotID = itemLocation:GetEquipmentSlot()
        local overlay = GetItemInfoOverlayFromSlotID(slotID)
        if overlay then
            overlay:SetItemFromLocation(itemLocation)
        end
    end
end

--------------------
-- 暴雪函数安全钩子
--------------------

hooksecurefunc(CharacterFrame, "Show", function(self)
    Module:UpdateAllCharacterSlot()
    Module:UpdateAllCharacterSlotDurability()
end)

--------------------
-- 事件处理
--------------------

local isLoaded = false

function Module:AfterLogin()
    for slotID in pairs(EQUIPMENT_SLOTS) do
        Module:CreateItemInfoOverlay(_G[CHARACTER_PREFIX..EQUIPMENT_SLOTS[slotID].name..SLOT_SUFFIX], slotID)
    end
    isLoaded = true
end

function Module:ADDON_LOADED(AddOnName)
    if AddOnName == "Blizzard_InspectUI" then
        for slotID in pairs(EQUIPMENT_SLOTS) do
            local overlay = Module:CreateItemInfoOverlay(_G[INSPECT_PREFIX..EQUIPMENT_SLOTS[slotID].name..SLOT_SUFFIX], slotID)
            function overlay:GetUnit()
                return InspectFrame.unit
            end
        end

        InspectModelFrame.ItemLevelOverlay = InspectModelFrame:CreateFontString(nil, "OVERLAY", "GameTooltipText")
        InspectModelFrame.ItemLevelOverlay:SetFont(Module:GetConfig(CONFIG_ITEM_LEVEL_FONT), Module:GetConfig(CONFIG_ITEM_LEVEL_FONT_SIZE), "OUTLINE")
        InspectModelFrame.ItemLevelOverlay:SetShadowOffset(1, -1)
        InspectModelFrame.ItemLevelOverlay:SetPoint("BOTTOM", InspectModelFrame, "BOTTOM", 0, 20)

        hooksecurefunc("InspectPaperDollFrame_UpdateButtons", function ()
            InspectModelFrame.ItemLevelOverlay:SetText(STAT_AVERAGE_ITEM_LEVEL..": "..C_PaperDollInfo.GetInspectItemLevel(InspectFrame.unit))
            Module:UpdateAllInspectSlot()
        end)
    end
end
Module:RegisterEvent("ADDON_LOADED")

-- 12.1优化: 添加刷新防抖，防止高频事件触发多次全量刷新
local refreshPending = false
local function DeferRefresh()
    if refreshPending then return end
    refreshPending = true
    C_Timer.After(0, function()
        refreshPending = false
        if isLoaded then
            Module:UpdateAllCharacterSlot()
        end
    end)
end

function Module:SOCKET_INFO_UPDATE()
    DeferRefresh()
end
Module:RegisterEvent("SOCKET_INFO_UPDATE")

function Module:UPDATE_INVENTORY_DURABILITY()
    if isLoaded then
        self:UpdateAllCharacterSlotDurability()
    end
end
Module:RegisterEvent("UPDATE_INVENTORY_DURABILITY")

function Module:PLAYER_EQUIPMENT_CHANGED()
    DeferRefresh()
end
Module:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")

function Module:UNIT_INVENTORY_CHANGED(unit)
    if unit == "player" then
        DeferRefresh()
    end
end
Module:RegisterEvent("UNIT_INVENTORY_CHANGED")