------------------------------------------------------------
-- ConsumableButton.lua
-- 通用“物品+滚轮切换”按钮：显示/隐藏、点击使用、tooltip、扫描分发
------------------------------------------------------------

local _, addon = ...
local L = addon.L

local InCombatLockdown = InCombatLockdown
local GetItemCount = C_Item and C_Item.GetItemCount or GetItemCount
local GetItemName = C_Item and C_Item.GetItemNameByID or GetItemInfo
local GetItemIcon = C_Item and C_Item.GetItemIconByID or GetItemInfo

local function CurrentEntry(btn)
    local list = btn.availableEntries
    return list and list[btn.index] or nil
end

local function RefreshAvailable(btn, counts)
    if counts then
        btn._lastCounts = counts
    end
    local newList = {}
    for _, entry in ipairs(btn.allEntries) do
        local n
        if counts then
            n = counts[entry.id] or 0
        else
            n = GetItemCount(entry.id) or 0
        end
        if n > 0 then
            tinsert(newList, entry)
        end
    end
    btn.availableEntries = newList
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

local function UpdateCurrentItem(btn)
    local entry = CurrentEntry(btn)
    if not entry then
        return
    end

    local itemID = entry.id
    local name = GetItemName and GetItemName(itemID) or ("item:" .. itemID)
    local icon = GetItemIcon and GetItemIcon(itemID)

    if icon then
        btn.icon:SetIcon(icon)
    end
    if not InCombatLockdown() then
        btn:SetAttribute("type", "item")
        btn:SetAttribute("item", "item:" .. itemID)
    end

    btn.currentName = name
    btn.currentItemID = itemID

    if btn._onUpdateEntry then
        btn._onUpdateEntry(btn, entry)
    end

    local count
    if btn._lastCounts then
        count = btn._lastCounts[entry.id] or 0
    else
        count = GetItemCount(itemID) or 0
    end
    UpdateCountText(btn, count)

    btn:UpdateTooltip()
end

local function CycleButton(btn, delta)
    local list = btn.availableEntries
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

local createdButtons = {}

local itemEventFrame = CreateFrame("Frame")
itemEventFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
itemEventFrame:SetScript("OnEvent", function(self, event, id)
    for _, btn in ipairs(createdButtons) do
        local entry = CurrentEntry(btn)
        if entry and entry.id == id then
            UpdateCurrentItem(btn)
        end
    end
end)

function addon.CreateConsumableWheelButton(key, title, allEntries, onUpdateEntry, onTooltip)
    local btn = addon:CreateActionButton(key, title, nil, nil, "ITEM")
    if not btn then
        return nil
    end

    btn.allEntries = allEntries
    btn.availableEntries = {}
    btn.index = 1
    btn._onUpdateEntry = onUpdateEntry
    btn._onTooltip = onTooltip

    btn:SetFlyProtect("type", "item")
    btn:SetAttribute("type", "item")

    btn:SetScript("OnMouseWheel", function(self, delta)
        if InCombatLockdown() then
            return
        end
        CycleButton(self, delta)
    end)

    btn.OnTooltipLeftText = function() end

    function btn:OnTooltipText(tooltip)
        if self.currentName then
            tooltip:AddLine(self.currentName, 1, 1, 1, 1)
        end
        tooltip:AddLine(L["left click"] .. L["use"], 1, 1, 1, 1)
        tooltip:AddLine(L["mouse wheel choose"] .. self.title, 1, 1, 1, 1)
        if self._onTooltip then
            self._onTooltip(self, tooltip)
        end
    end

    function btn:OnEnable()
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
    for _, entry in ipairs(allEntries) do
        if C_Item and C_Item.RequestLoadItemDataByID then
            C_Item.RequestLoadItemDataByID(entry.id)
        end
    end

    -- 注册到公共扫描器
    local scan = addon.ConsumableScan
    if scan then
        local ids = {}
        for _, e in ipairs(allEntries) do
            tinsert(ids, e.id)
        end
        scan:AddItems(ids)
        scan:AddCallback(function(counts)
            if not btn or btn:GetAttribute("disabled") then
                return
            end
            if RefreshAvailable(btn, counts) then
                if not CurrentEntry(btn) then
                    btn.index = 1
                end
                UpdateCurrentItem(btn)
            end
        end)
    end

    -- 初始直接检查一次，避免等待扫描器首个周期
    RefreshAvailable(btn)
    UpdateCurrentItem(btn)
    tinsert(createdButtons, btn)
    return btn
end
