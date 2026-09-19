local ADDON_NAME, ItemInfoOverlay = ...

local Module = ItemInfoOverlay:NewModule("tooltip")
local L = ItemInfoOverlay.Locale

local issecretvalue = issecretvalue or function(unit)
    return false
end

local CONFIG_ITEM_LEVEL = "itemLevel.enable"

local playerItemLevelCache = { }

-- 限制缓存大小: 防止长时间游戏、反复观察大量玩家后内存无限增长
local PLAYER_ITEM_LEVEL_CACHE_TTL = 600     -- 条目有效期(秒), 超过后清理
local PLAYER_ITEM_LEVEL_CACHE_MAX = 100     -- 条目数量上限, 超过后裁剪最旧的一半

local function CachePlayerItemLevel(guid, itemLevel)
    local now = GetTime()

    -- 清理过期条目
    local count = 0
    for cachedGuid, data in pairs(playerItemLevelCache) do
        count = count + 1
        if now - data[1] > PLAYER_ITEM_LEVEL_CACHE_TTL then
            playerItemLevelCache[cachedGuid] = nil
        end
    end

    -- 仍超过上限时, 删除时间最早的条目, 直到只剩一半
    if count >= PLAYER_ITEM_LEVEL_CACHE_MAX then
        local byTime = {}
        for cachedGuid, data in pairs(playerItemLevelCache) do
            tinsert(byTime, { data[1], cachedGuid })
        end
        sort(byTime, function(a, b) return a[1] < b[1] end)
        for i = 1, math.floor(#byTime / 2) do
            playerItemLevelCache[byTime[i][2]] = nil
        end
    end

    playerItemLevelCache[guid] = { now, itemLevel }
end

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

function Module:INSPECT_READY(guid)
    lastInspectTime = nil
    lastInspectGuid = nil

    if Module:GetConfig(CONFIG_ITEM_LEVEL) then
        local unit = UnitTokenFromGUID(guid)
        -- print("INSPECT_READY:", guid, unit)
        if unit then
            -- print(C_PaperDollInfo.GetInspectItemLevel(unit))
            local itemLevel = C_PaperDollInfo.GetInspectItemLevel(unit)
            CachePlayerItemLevel(guid, itemLevel)

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
