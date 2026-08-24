local ADDON_NAME, ItemInfoOverlay = ...

local Module = ItemInfoOverlay:NewModule("tooltip")
local L = ItemInfoOverlay.Locale

local issecretvalue = issecretvalue or function(unit)
    return false
end

local CONFIG_ITEM_LEVEL = "itemLevel.enable"

-- 12.1优化: 限制缓存大小为50条，防止长时间游戏内存无限增长
local MAX_CACHE_SIZE = 50
local playerItemLevelCache = {}
local cacheOrder = {}

local itemLevelLine
local isBlzInspecting
local isIIOInspecting
local lastInspectTime
local lastInspectGuid

local function GetTooltipUnitInfo(self)
    local info = self:GetPrimaryTooltipInfo()
    if info and info.tooltipData and info.tooltipData.type then
        if issecretvalue(info.tooltipData.type) then
            return
        end
        if self:IsTooltipType(Enum.TooltipDataType.Unit) then
            local guid = info.tooltipData.guid
            if issecretvalue(guid) then
                return
            end
            local unit = guid and UnitTokenFromGUID(guid)
            if issecretvalue(unit) then
                return
            end
            return unit, guid
        end
    end
end

local function RefreshItemLevelTooltip()
    local unit, guid = GetTooltipUnitInfo(GameTooltip)
    if unit and guid and itemLevelLine then
        if playerItemLevelCache[guid] then
            itemLevelLine:SetText(playerItemLevelCache[guid][2])
        elseif guid == lastInspectGuid then
            itemLevelLine:SetText("...")
        else
            itemLevelLine:SetText("N/A")
        end
    end
end

local function TryNotifyInspect(unit)
    if not UnitIsUnit("player", unit) and CanInspect(unit) then
        local guid = UnitGUID(unit)
        if issecretvalue(guid) then
            return
        end

        if lastInspectGuid == guid and lastInspectTime + 3 <= GetTime() then
            return
        elseif playerItemLevelCache[guid] and playerItemLevelCache[guid][1] + 60 > GetTime() then
            return
        end

        if (
            not isBlzInspecting and
            (
                not lastInspectTime or
                (lastInspectTime and isIIOInspecting) or
                (lastInspectTime + 3 > GetTime())
            )
        ) then
            ClearInspectPlayer()
            NotifyInspect(unit)
            isIIOInspecting = true
        end
    end
end

TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(self, data)
    if Module:GetConfig(CONFIG_ITEM_LEVEL) then
        local unit, guid = GetTooltipUnitInfo(self)
        if unit and UnitIsPlayer(unit) then
            if not UnitIsUnit("player", unit) then
                self:AddDoubleLine(STAT_AVERAGE_ITEM_LEVEL..":", "...", nil, nil, nil, 1, 1, 1)
                itemLevelLine = _G[self:GetName() .. "TextRight"..self:NumLines()]
                RefreshItemLevelTooltip()
            end
        end
    end
end)

hooksecurefunc("InspectUnit", function (unit)
    isBlzInspecting = true
    isIIOInspecting = false
end)

hooksecurefunc("NotifyInspect", function(unit)
    lastInspectTime = GetTime()
    lastInspectGuid = UnitGUID(unit)
    RefreshItemLevelTooltip()
end)

hooksecurefunc("ClearInspectPlayer", function()
    lastInspectTime = nil
    lastInspectGuid = nil
    isBlzInspecting = false
end)

function Module:INSPECT_READY(guid)
    lastInspectTime = nil
    lastInspectGuid = nil

    if Module:GetConfig(CONFIG_ITEM_LEVEL) then
        local unit = UnitTokenFromGUID(guid)
        if unit then
            local itemLevel = C_PaperDollInfo.GetInspectItemLevel(unit)
            
            -- 12.1优化: LRU缓存，限制大小防止无限增长
            if not playerItemLevelCache[guid] then
                if #cacheOrder >= MAX_CACHE_SIZE then
                    local oldest = table.remove(cacheOrder, 1)
                    playerItemLevelCache[oldest] = nil
                end
                table.insert(cacheOrder, guid)
            else
                -- 移动到最新
                for i, g in ipairs(cacheOrder) do
                    if g == guid then
                        table.remove(cacheOrder, i)
                        table.insert(cacheOrder, guid)
                        break
                    end
                end
            end
            
            playerItemLevelCache[guid] = { GetTime(), itemLevel }
            RefreshItemLevelTooltip()
        end

        if isIIOInspecting then
            isIIOInspecting = false
            ClearInspectPlayer()
        end

        TryNotifyInspect("mouseover")
    end
end
Module:RegisterEvent("INSPECT_READY")

function Module:UPDATE_MOUSEOVER_UNIT()
    if Module:GetConfig(CONFIG_ITEM_LEVEL) then
        TryNotifyInspect("mouseover")
    end
end
Module:RegisterEvent("UPDATE_MOUSEOVER_UNIT")