local ADDON_NAME, ItemInfoOverlay = ...

local Module = ItemInfoOverlay:NewModule("tooltip")
local L = ItemInfoOverlay.Locale

local issecretvalue = issecretvalue or function(unit)
    return false
end

local CONFIG_ITEM_LEVEL = "itemLevel.enable"

local playerItemLevelCache = { }

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
            -- 3秒内已尝试观察的单位不再覆盖
            return
        elseif playerItemLevelCache[guid] and playerItemLevelCache[guid][1] + 60 > GetTime() then
            -- 装等有效时间在1分钟内的 不再尝试更新
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
    -- print("InspectUnit:", unit, UnitGUID(unit))
    isBlzInspecting = true
    isIIOInspecting = false
end)

hooksecurefunc("NotifyInspect", function(unit)
    -- print("NotifyInspect:", unit, UnitGUID(unit))
    lastInspectTime = GetTime()
    lastInspectGuid = UnitGUID(unit)

    RefreshItemLevelTooltip()
end)

hooksecurefunc("ClearInspectPlayer", function()
    -- print("ClearInspectPlayer")
    lastInspectTime = nil
    lastInspectGuid = nil
    isBlzInspecting = false
end)

-- 观察装等缓存: 数据仅在写入后 1 分钟内有效, 这里在条目超过上限时清理过期项,
-- 防止长时间游戏(尤其团本/战场反复观察不同玩家)导致缓存无界增长
local PLAYER_ITEM_LEVEL_CACHE_MAX = 64

local function PrunePlayerItemLevelCache()
    local count = 0
    for _ in pairs(playerItemLevelCache) do
        count = count + 1
    end

    if count > PLAYER_ITEM_LEVEL_CACHE_MAX then
        local now = GetTime()
        for guid, data in pairs(playerItemLevelCache) do
            if data[1] + 120 < now then
                playerItemLevelCache[guid] = nil
            end
        end
    end
end

function Module:INSPECT_READY(guid)
    lastInspectTime = nil
    lastInspectGuid = nil

    if Module:GetConfig(CONFIG_ITEM_LEVEL) then
        local unit = UnitTokenFromGUID(guid)
        -- print("INSPECT_READY:", guid, unit)
        if unit then
            -- print(C_PaperDollInfo.GetInspectItemLevel(unit))
            local itemLevel = C_PaperDollInfo.GetInspectItemLevel(unit)
            playerItemLevelCache[guid] = { GetTime(), itemLevel }

            PrunePlayerItemLevelCache()

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
