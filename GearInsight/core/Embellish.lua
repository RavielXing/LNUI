-- 美化件数统计（台账 #142）
--
-- 玩家「灰色头像不会再跳动」2026-09-09 群里报：「这都三件美化了」——
-- 游戏里一个角色**最多装备 2 件带「美化」的装备**，三件是穿不上的一套。
--
-- ⛔⛔ 网站那边认不出哪件带美化：美化是**打造时用材料加的**，不在物品模板上，
--    暴雪 item API 和 Wowhead 都查不到，WCL 的 bonusIDs 里虽有痕迹但对照表没公开。
-- ⭐ 但**插件能做得准** —— 游戏内的物品提示里就写着「美化」，
--    直接扫自己身上这 16 件，数出来的是**事实**，不是推测。
--
-- ⛔ 用 C_TooltipInfo，⛔别再造隐藏 GameTooltip 扫行那一套（10.0 之后就不可靠了）。
--
-- ⛔⛔ 12.0「secret values」（玩家「Smile」2026-09-09 报「早上更新了…打个地下堡报错」）：
--    提示行文本在 12.0 起是 **secret**，而 secret 的规矩是
--      · `type(secret)` 照样返回 "string" —— 所以 `type(txt) ~= "string"` 这道守卫**根本挡不住**；
--      · 允许存、允许 concat / string.format；
--      · ⛔ 不许 index —— `txt:find(...)` 就是 index，**当场抛 Lua 错误**。
--    第一版把 pcall 包在「读 line.leftText」上（那一步本来就合法），
--    真正违规的 `find` 反而露在外面 —— 闸门盖错了那一步。
--    ⭐ 判据只有 `issecretvalue()`，⛔别再拿 type()/tostring() 去猜。
-- ⛔ 碰一次 secret 会把执行流标成 tainted，之后**暴雪自己的代码**会报
--    "tainted by 'GearInsight'"（那种 pcall 挡不住）。所以读到一次 secret 就**整个熔断**，
--    不再一遍遍去碰 —— 宁可这个提示永远不出，也不能把玩家的界面搞出错。
GearInsight = GearInsight or {}

local _LOCALE = GearInsight and GearInsight.LOCALE or (GetLocale and GetLocale()) or "enUS"
local function T(key, zh)
    if _LOCALE == "zhCN" then return zh end
    local L = GearInsight.LOC or {}
    local cur = L[_LOCALE]
    if cur and cur[key] then return cur[key] end
    if _LOCALE ~= "zhTW" then
        local en = L["enUS"]
        if en and en[key] then return en[key] end
    end
    return zh
end

-- 提示里表示「这件带美化」的字样。⛔ 各语言客户端写法不同，全列上；
--    ⛔ 别只写英文 —— 国服客户端根本不出现 "Embellished"。
local MARKS = {
    "美化",              -- zhCN
    "美化",              -- zhTW（同字）
    "Embellish",        -- enUS，涵盖 Embellished / Embellishment
    "Veredel",          -- deDE
    "Embelliss",        -- frFR
    "Embellec",         -- esES / esMX
    "Abbellim",         -- itIT
    "장식",              -- koKR
    "Adorno",           -- ptBR
    "Улучшен",          -- ruRU
}

local SLOTS = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17 }

-- 这个值碰不得吗？（12.0 secret；老客户端没有这个函数，返回 false）
local function isSecret(v)
    local f = _G.issecretvalue
    if not f then return false end
    local ok, r = pcall(f, v)
    return ok and r == true
end

-- 熔断：读到过 secret 就再也不扫了（见文件头）
local blocked = false

local function lineHasMark(txt)
    -- ⛔ 顺序不能反：secret 必须在 type() 之前判 —— type(secret) 也返回 "string"
    if isSecret(txt) then blocked = true return false end
    if type(txt) ~= "string" then return false end
    for _, m in ipairs(MARKS) do
        if txt:find(m, 1, true) then return true end
    end
    return false
end

--- 数玩家身上有几件带「美化」的装备。
-- @return count, list  件数与部位名列表（读不到时返回 0, {}，⛔不抛错）
-- 扫一个部位：带美化返回 true
local function slotHasEmbellish(slot)
    local ok, data = pcall(C_TooltipInfo.GetInventoryItem, "player", slot)
    if not ok or not data then return false end
    local lines = data.lines
    -- ⛔ lines 自己也可能是 secret：ipairs / # 都会当场炸，先判再遍历
    if not lines then return false end
    if isSecret(lines) then blocked = true return false end
    for _, line in ipairs(lines) do
        if blocked then return false end
        local ok2, txt = pcall(function() return line.leftText end)
        if ok2 and lineHasMark(txt) then return true end
    end
    return false
end

function GearInsight:CountEmbellished()
    local n, where = 0, {}
    if blocked then return 0, where end
    if not (C_TooltipInfo and C_TooltipInfo.GetInventoryItem) then
        return 0, where
    end
    for _, slot in ipairs(SLOTS) do
        -- ⛔ 这层 pcall 是**兜底**不是判据：只靠它的话错是不报了，
        --    但 secret 已经被碰过、执行流已经脏了 —— 判据在上面的 isSecret。
        local ok, hit = pcall(slotHasEmbellish, slot)
        if not ok then blocked = true return 0, {} end
        if blocked then return 0, {} end
        if hit then
            n = n + 1
            local nm = _G["INVTYPE_Slot"] and _G["INVTYPE_Slot"][slot]
            where[#where + 1] = nm or tostring(slot)
        end
    end
    return n, where
end

-- 给自检/测试用：这个功能是不是已经熔断了
function GearInsight:EmbellishBlocked() return blocked end

--- 一句给面板用的提示；没超上限返回 nil（⛔别在没问题时也占一行）。
function GearInsight:EmbellishNote()
    local n = self:CountEmbellished()
    if n <= 2 then return nil end
    return T("EMB_OVER", "你身上有 %d 件「美化」装备，游戏上限是 2 件 —— 多出来的那件不会生效。")
        :format(n), n
end
