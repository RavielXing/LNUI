-- 美化材料 · 制造业装备制作顺序（用户 2026-09-16 按抖音「新赛季火花制造业装备，最正确的制作顺序」加）
--
-- 「美化」= 打造时塞进去的**可选材料**（Optional Reagent），不是装备本身；这些材料
-- **拍卖行能直接买**（跟制造件本身「拍卖行搜不到」正相反），买了再拿去下工艺订单。
-- 一个角色最多 2 件带美化的装备生效（core/Embellish.lua 数的就是这个）。
--
-- 12.1 材料（物品 id 来自 Wowhead / method.gg 美化总表；名字一律 GetItemInfo 取本地化，⛔别硬写中文）：
--   273059 猎人仪式石   Hunter's Ritual Stone   伤害技能几率 +101 随机次要属性 15s（追猎期间 +50%）→ 武器
--   240166 奥纹内衬     Arcanoweave Lining      几率吸引法力浮龙，你和一名盟友主属性提高          → 护腕 / 盾 / 披风
--   245875 黑暗符印:狩猎 Darkmoon Sigil: Hunt   按目标类型给次要属性；视频作者：「狩猎美化也可以，两者差距不大」→ 武器备选
--
-- 顺序（视频作者「勇敢牛牛」，2026-09）：
--   双手武器职业：①武器(仪式石) ②护腕(奥纹内衬) → 双美化达成 ③大米刷不到属性组合的戒指/项链
--                 ④披风(奥纹内衬；前提是开出神话武器把制造武器换掉，少了一个美化用披风补) ⑤大米刷不到的腰带/鞋子 ⑥随意
--   主手+盾职业：  ①主手(仪式石)+盾(奥纹内衬) → 双美化达成，②护腕跳过，其余同上
-- ⛔ 神话武器 > 制造武器；做装备前先看 H 团本后 2 个 BOSS 的掉落（尤其腰带/鞋子），别浪费火花。
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

local STONE, LINING, SIGIL = 273059, 240166, 245875

GearInsight.EMBELLISH_REAGENTS = {
    { itemId = STONE,  useKey = "EMB_USE_STONE",  useZh = "武器 / 主手" },
    { itemId = LINING, useKey = "EMB_USE_LINING", useZh = "护腕 · 盾 · 披风" },
    { itemId = SIGIL,  useKey = "EMB_USE_SIGIL",  useZh = "武器备选（与仪式石差距不大）", alt = true },
}

-- 本地化物品名：没缓存时先回 "#id"，并请求加载（FarmGrid 重绘时会拿到真名）
function GearInsight:EmbellishItemName(itemId)
    local nm = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(itemId)
    if nm and nm ~= "" then return nm end
    if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, itemId) end
    return "#" .. itemId
end

-- 玩家副手是不是盾（决定走「主手+盾」路线）；读不到一律按双手路线
local function usesShield()
    local id = GetInventoryItemID and GetInventoryItemID("player", 17)
    if not id then return false end
    local loc = select(9, GetItemInfo(id))
    return loc == "INVTYPE_SHIELD"
end

--- 返回 { shield = bool, steps = { "①…", "②…", ... } }（步骤已本地化、已带材料名）
function GearInsight:EmbellishPlan()
    local stone, lining = self:EmbellishItemName(STONE), self:EmbellishItemName(LINING)
    local shield = usesShield()
    local steps = {}
    if shield then
        steps[#steps + 1] = string.format(T("EMB_STEP_MH_SHIELD", "① 主手 → 「%s」；盾牌 → 「%s」，双美化达成（护腕跳过）"), stone, lining)
    else
        steps[#steps + 1] = string.format(T("EMB_STEP_2H", "① 武器 → 「%s」（狩猎符印也行，差距不大）"), stone)
        steps[#steps + 1] = string.format(T("EMB_STEP_WRIST", "② 护腕 → 「%s」，至此双美化达成"), lining)
    end
    steps[#steps + 1] = T("EMB_STEP_RING", "③ 大米刷不到那种属性组合的戒指 / 项链（先对照大米掉落表）")
    steps[#steps + 1] = string.format(T("EMB_STEP_CLOAK", "④ 披风 → 「%s」：开出神话武器换掉制造武器后少一个美化，用披风补回（神话武器 > 制造武器）"), lining)
    steps[#steps + 1] = T("EMB_STEP_BELT", "⑤ 大米刷不到那种属性组合的腰带 / 鞋子 —— 先看 H 团本后 2 个 BOSS 掉不掉，别浪费火花")
    steps[#steps + 1] = T("EMB_STEP_FREE", "⑥ 随意")
    return { shield = shield, steps = steps }
end

--- 材料名 → 拍卖行：AH 开着直接填搜索框并搜；没开发到聊天；右键弹复制框（与 GearMap 小格同一套手感）
function GearInsight:EmbellishReagentClick(itemId, btn)
    local name = self:EmbellishItemName(itemId)
    if not name or name:sub(1, 1) == "#" then return end
    if btn == "RightButton" then
        self:ShowCopyText(name, string.format(T("CONS_COPY_HINT", "Ctrl+C 复制「%s」，到拍卖行搜索框粘贴购买"), name))
        return
    end
    local ah = AuctionHouseFrame
    if ah and ah:IsShown() and ah.SearchBar and ah.SearchBar.SearchBox then
        ah.SearchBar.SearchBox:SetText(name)
        if ah.SearchBar.StartSearch then ah.SearchBar:StartSearch() end
        return
    end
    local link = select(2, GetItemInfo(itemId))
    if link and ChatEdit_InsertLink and ChatEdit_InsertLink(link) then return end
    if ChatFrame_OpenChat then ChatFrame_OpenChat(link or name) end
end
