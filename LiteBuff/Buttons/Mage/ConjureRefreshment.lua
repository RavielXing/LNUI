if select(2, UnitClass("player")) ~= "MAGE" then return end
local _, addon = ...
local L = addon.L

local createSpell = addon:BuildSpellList(nil, 190336)

local button = addon:CreateActionButton("MageConjureRefreshment", 190336, nil, nil, 'DUAL', 'ITEM')
button:SetFlyProtect("type1", "spell", "type2", "item")
button:SetSpell(190336)
button:SetItem(113509)
button:RequireSpell(190336)

button:SetAttribute("spell", createSpell.spell)

local itemId = 113509
local itemName = GetItemInfo(itemId)
if itemName then
    button:SetAttribute("item", itemName)
else
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    eventFrame:SetScript("OnEvent", function(self, event, id)
        if id == itemId then
            button:SetAttribute("item", GetItemInfo(itemId))
            self:UnregisterEvent("GET_ITEM_INFO_RECEIVED")
            self:SetScript("OnEvent", nil)
        end
    end)
    C_Item.RequestLoadItemDataByID(itemId)
end

function button:OnTooltipRightText(tooltip)
    tooltip:AddLine(L["right click"]..(GetItemInfo(113509) or ""), 1, 1, 1, 1)
end
