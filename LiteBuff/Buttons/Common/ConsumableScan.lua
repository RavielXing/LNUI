------------------------------------------------------------
-- ConsumableScan.lua
-- 公共消耗品统一扫描：所有按钮注册物品后，共享一次背包扫描再分发
------------------------------------------------------------



local _, addon = ...
local GetItemCount = (C_Item and C_Item.GetItemCount) or GetItemCount

local scanner = {
    ids = {},
    idSet = {},
    callbacks = {},
    counts = {},
    pending = false,
}
addon.ConsumableScan = scanner

function scanner:AddItems(list)
    for _, id in ipairs(list) do
        if not self.idSet[id] then
            self.idSet[id] = true
            tinsert(self.ids, id)
        end
    end
end

function scanner:AddCallback(fn)
    tinsert(self.callbacks, fn)
end

function scanner:Scan()
    if InCombatLockdown() then
        return
    end
    -- 只写变化的项, 数量没变化就不派发回调:
    -- 每秒/每事件都重建可用列表+刷新按钮, 白白制造垃圾和CPU开销
    local counts = self.counts
    local changed = false
    for _, id in ipairs(self.ids) do
        local n = GetItemCount(id)
        if issecretvalue and issecretvalue(n) then
            n = 0
        end
        if n and n > 0 then
            if counts[id] ~= n then
                counts[id] = n
                changed = true
            end
        elseif counts[id] ~= nil then
            counts[id] = nil
            changed = true
        end
    end
    if not changed then
        return
    end
    for _, fn in ipairs(self.callbacks) do
        fn(counts)
    end
end

function scanner:RequestScan()
    if self.pending then
        return
    end
    self.pending = true
    C_Timer.After(0.1, function()
        self.pending = false
        self:Scan()
    end)
end

local bagsReady = false
local f = CreateFrame("Frame")
f:RegisterEvent("BAG_UPDATE")
f:RegisterEvent("BAG_UPDATE_COOLDOWN")
f:SetScript("OnEvent", function()
    -- BAG_UPDATE 来过说明背包数据已开始下发, 登录兜底ticker可以退了
    bagsReady = true
    scanner:RequestScan()
end)

-- 登录初期背包未就绪时的兜底: 每秒扫一次直到首个BAG_UPDATE到来, 之后只靠事件驱动
local ticker
ticker = C_Timer.NewTicker(1, function()
    scanner:Scan()
    if bagsReady and ticker then
        ticker:Cancel()
        ticker = nil
    end
end)
