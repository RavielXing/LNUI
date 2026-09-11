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
    wipe(self.counts)
    for _, id in ipairs(self.ids) do
        local n = GetItemCount(id)
        if n and n > 0 then
            self.counts[id] = n
        end
    end
    for _, fn in ipairs(self.callbacks) do
        fn(self.counts)
    end
end

function scanner:RequestScan()
    if self.pending then
        return
    end
    self.pending = true
    C_Timer.After(0, function()
        self.pending = false
        self:Scan()
    end)
end

local f = CreateFrame("Frame")
f:RegisterEvent("BAG_UPDATE")
f:RegisterEvent("BAG_UPDATE_COOLDOWN")
f:SetScript("OnEvent", function()
    scanner:RequestScan()
end)

-- 登录初期背包未就绪时的兜底
C_Timer.NewTicker(1, function()
    scanner:Scan()
end)
