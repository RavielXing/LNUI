
if select(2, UnitClass("player")) ~= "MAGE" then return end
local _, addon = ...
local L = addon.L


local button = addon:CreateActionButton("MageConjureRefreshment", 190336, nil, nil, 'DUAL', 'ITEM')
button:SetSpell(190336)
button:SetItem(113509)

-- 左键：释放造餐术
button:SetAttribute("type", "spell")
button:SetAttribute("spell", 190336)


button:SetFlyProtect("type", "spell")

