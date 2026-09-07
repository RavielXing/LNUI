------------------------------------------------------------
-- Food.lua
-- 食物按钮：滚轮切食物类型
-- 左键吃普通版，右键吃丰盛版；图标优先显示普通版
------------------------------------------------------------

local _, addon = ...
local L = addon.L

local InCombatLockdown = InCombatLockdown
local GetItemCount = C_Item and C_Item.GetItemCount or GetItemCount
local GetItemName = C_Item and C_Item.GetItemNameByID or GetItemInfo
local GetItemIcon = C_Item and C_Item.GetItemIconByID or GetItemInfo

-- 普通食物
local NORMAL_FOODS = {
    255845, 255846, 242272, 242273, 242275, 255848, 242274,
    242277, 242286, 242278, 242283, 242287, 242276, 242280,
    242284, 242281, 242285, 242299, 242298, 242289, 255847,
}

-- 对应丰盛版
local HEARTY_FOODS = {
    [255845] = 266985,
    [255846] = 266996,
    [242272] = 266986,
    [242273] = 242745,
    [242274] = 242746,
    [242275] = 242747,
    [242276] = 242748,
    [242277] = 242749,
    [242278] = 242750,
    [242280] = 242752,
    [242281] = 242753,
    [242283] = 242755,
    [242284] = 242756,
    [242285] = 242757,
    [242286] = 242758,
    [242287] = 242759,
    [242289] = 242761,
    [255848] = 268680,
    [255847] = 268679,
}

local FOOD_GROUPS = {}
for _, id in ipairs(NORMAL_FOODS) do
    tinsert(FOOD_GROUPS, { normal = id, hearty = HEARTY_FOODS[id] })
end

local function GetCount(counts, id)
    if counts then
        return counts[id] or 0
    end
    return GetItemCount(id) or 0
end

local function UpdateCountText(btn, count)
    if not btn.icon.countText then
        btn.icon.countText = btn.icon:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        btn.icon.countText:SetPoint("BOTTOMRIGHT", btn.icon, "BOTTOMRIGHT", -1, 1)
        btn.icon.countText:SetJustifyH("RIGHT")
        btn.icon.countText:SetFont(STANDARD_TEXT_FONT, 15, "OUTLINE")
        btn.icon.countText:SetTextColor(0, 1, 0, 1)
    end
    if count and count > 0 then
        btn.icon.countText:SetText(count)
        btn.icon.countText:Show()
    else
        btn.icon.countText:Hide()
    end
end

local function RefreshAvailable(btn, counts)
    if counts then
        btn._lastCounts = counts
    end
    local newList = {}
    for _, group in ipairs(btn.allGroups) do
        local hasNormal = GetCount(counts, group.normal) > 0
        local hasHearty = group.hearty and GetCount(counts, group.hearty) > 0 or false
        if hasNormal or hasHearty then
            tinsert(newList, {
                normal = group.normal,
                hearty = group.hearty,
                hasNormal = hasNormal,
                hasHearty = hasHearty,
            })
        end
    end
    btn.availableGroups = newList
    if #newList == 0 then
        btn:Hide()
        return false
    end
    if not btn.index or btn.index > #newList then
        btn.index = 1
    end
    if not btn:IsShown() then
        btn:Show()
    end
    return true
end

local function CurrentGroup(btn)
    local list = btn.availableGroups
    return list and list[btn.index] or nil
end

local function UpdateHeartyMark(btn, showHearty)
    if not btn.icon.heartyText then
        btn.icon.heartyText = btn.icon:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        btn.icon.heartyText:SetPoint("CENTER", btn.icon, "CENTER", 0, 0)
        btn.icon.heartyText:SetJustifyH("CENTER")
        btn.icon.heartyText:SetFontObject("GameFontNormalLarge")
    end
    if showHearty then
        btn.icon.heartyText:SetText("丰盛")
        btn.icon.heartyText:SetTextColor(0.2, 0.6, 1, 1)
        btn.icon.heartyText:Show()
    else
        btn.icon.heartyText:Hide()
    end
end

local function UpdateCurrentItem(btn)
    local g = CurrentGroup(btn)
    if not g then
        return
    end

    -- 左键：普通优先；右键：丰盛优先
    local leftId
    local rightId
    local iconId
    if g.hasNormal then
        leftId = g.normal
        iconId = g.normal
    else
        leftId = g.hearty
        iconId = g.hearty
    end
    if g.hasHearty then
        rightId = g.hearty
    else
        rightId = g.normal
    end

    local icon = GetItemIcon and GetItemIcon(iconId)
    if icon then
        btn.icon:SetIcon(icon)
    end

    if not InCombatLockdown() then
        btn:SetAttribute("type", "item")
        btn:SetAttribute("item", "item:" .. leftId)
        btn:SetAttribute("type2", "item")
        btn:SetAttribute("item2", "item:" .. rightId)
    end

    btn.currentName = GetItemName and GetItemName(iconId) or ("item:" .. iconId)
    btn.currentNormalName = GetItemName and GetItemName(leftId) or ("item:" .. leftId)
    btn.currentHeartyName = GetItemName and GetItemName(rightId) or ("item:" .. rightId)

    UpdateHeartyMark(btn, iconId == g.hearty)

    local count
    if btn._lastCounts then
        count = btn._lastCounts[iconId] or 0
    else
        count = GetItemCount(iconId) or 0
    end
    UpdateCountText(btn, count)

    btn:UpdateTooltip()
end

local function CycleButton(btn, delta)
    local list = btn.availableGroups
    if not list or #list <= 1 then
        return
    end
    btn.index = btn.index - delta
    if btn.index < 1 then
        btn.index = #list
    elseif btn.index > #list then
        btn.index = 1
    end
    UpdateCurrentItem(btn)
end

local button = addon:CreateActionButton("CommonFood", "食物", nil, nil, "DUAL", "ITEM")
if button then
    button.allGroups = FOOD_GROUPS
    button.availableGroups = {}
    button.index = 1

    button:SetFlyProtect("type", "item", "type2", "item")
    button:SetAttribute("type", "item")
    button:SetAttribute("type2", "item")

    button:SetScript("OnMouseWheel", function(self, delta)
        if InCombatLockdown() then
            return
        end
        CycleButton(self, delta)
    end)

    button.OnTooltipLeftText = function() end
    button.OnTooltipRightText = function() end

    button.OnTooltipText = function(self, tooltip)
        if self.currentName then
            tooltip:AddLine(self.currentName, 1, 1, 1, 1)
        end
        tooltip:AddLine(L["left click"] .. (self.currentNormalName or ""), 1, 1, 1, 1)
        tooltip:AddLine(L["right click"] .. (self.currentHeartyName or ""), 1, 1, 1, 1)
        tooltip:AddLine(L["mouse wheel choose"] .. self.title, 1, 1, 1, 1)
    end

    function button:OnEnable()
        if InCombatLockdown() then
            return
        end
        local scan = addon.ConsumableScan
        if scan then
            if next(scan.counts) then
                RefreshAvailable(self, scan.counts)
                UpdateCurrentItem(self)
            end
            scan:RequestScan()
        else
            RefreshAvailable(self)
            UpdateCurrentItem(self)
        end
    end

    -- 请求物品信息
    for _, group in ipairs(FOOD_GROUPS) do
        if C_Item and C_Item.RequestLoadItemDataByID then
            C_Item.RequestLoadItemDataByID(group.normal)
            if group.hearty then
                C_Item.RequestLoadItemDataByID(group.hearty)
            end
        end
    end

    -- 注册到公共扫描器
    local scan = addon.ConsumableScan
    if scan then
        local ids = {}
        for _, group in ipairs(FOOD_GROUPS) do
            tinsert(ids, group.normal)
            if group.hearty then
                tinsert(ids, group.hearty)
            end
        end
        scan:AddItems(ids)
        scan:AddCallback(function(counts)
            if not button or button:GetAttribute("disabled") then
                return
            end
            if RefreshAvailable(button, counts) then
                if not CurrentGroup(button) then
                    button.index = 1
                end
                UpdateCurrentItem(button)
            end
        end)
    end

    RefreshAvailable(button)
    UpdateCurrentItem(button)
end

-- 物品信息异步到达后刷新
local itemEventFrame = CreateFrame("Frame")
itemEventFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
itemEventFrame:SetScript("OnEvent", function(self, event, id)
    if button then
        local g = CurrentGroup(button)
        if g and (g.normal == id or g.hearty == id) then
            UpdateCurrentItem(button)
        end
    end
end)
