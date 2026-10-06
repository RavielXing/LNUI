-- GearInsight/main/RollVault.lua — Roll 币三选 + 低保（每周宝库）推荐 + 装备 vs BiS 四档
-- 2026-09-22 按交接稿 docs/retail-gear-addon-handover.md 实现。打分口径与服务端 wow_retail_gear.py **同一套**（§2），
-- ⛔ 别各算各的：改公式两边一起改。
--   score = (新装等 − 当前槽装等) × 槽位权重 + BiS(+25，低一档同名 +12) + 套装(1→2 +15；3→4 +30；≥4 0) + 轨道(英雄→神话 +8)
--   不能装备 = 0（用暴雪自己的地下城手册职业/专精筛选判）；本周该难度已杀的 boss 不进三选；
--   大米无 CD：非套装、非饰品/武器，且大米池同槽同档 → ×0.5；判词只表示个人收益，不涉及交易或让装。
--   概率：一枚币必出一件 → 单件 = 1 ÷ 该 boss 池子里本专精能用的件数；
--   单 boss 中有用件 = 15% × 有用/能用；3 币至少中一件 = 1 − Π(1 − p_i)。
-- 数据全部本地：掉落 = 地下城手册（EJ_* 按难度取装等），BiS = BisData，套装 = TierSets，锁定 = GetSavedInstanceEncounterInfo，
-- 一个 boss 一个 CD 只能 roll 一次（rollUsed，按周清）；roll 币池子 = 每个 boss 独立且**跨周保留**：只有用币 roll 到的件出池（正常拾取不出池），出池后剩余件概率上升。
-- ⛔ 只提示不自动用币。
local H = GearInsight.Helpers
local T, _LOCALE = H.T, H.LOCALE

local RV = {}
GearInsight.RollVault = RV

-- ── 口径常量（与服务端同步）────────────────────────────────────────────
local SLOT_W = { [16] = 2.0, [17] = 1.2, [13] = 1.6, [14] = 1.6, [11] = 0.8, [12] = 0.8, [2] = 0.8, [15] = 0.9 }
local BIS_PT, BIS_LOW_PT, TRACK_PT = 25, 12, 8
-- ⛔⛔ 宝库专用口径（用户 2026-09-24「推荐的都不在 BiS 名单，是不是应该考虑 BiS 排名，套装部位考虑坯子排名」）：
--   截图里推荐了一件不在 BiS 名单的饰品（纯装等 +21），压过了 BiS #2、催化后 = 套装 BiS #1 的胸甲。
--   只作用于宝库（ctx.vault）；roll 币仍与服务端 score_item 同口径。网站宝库页直接用插件送来的结果，不重算。
--   ① BiS 分按名次分档 #1 +30 / #2 +18 / #3 +10（低一档同名减半）；
--   ② 套装部位的坯子按「催化后」再算：套装件名次的 BiS 分 + 套装进度分，比自身 BiS 分高就换成它，
--      并写出「转换优先级 #i/n」（与悬浮提示同一个排序器 BuildFillerList）；
--   ③ 既不在本专精 BiS 前 3、也不是坯子 → 总分 ×0.5。
local VAULT_BIS_PT = { 30, 18, 10 }
local TIER_SLOT = { [1] = true, [3] = true, [5] = true, [7] = true, [10] = true }
-- ⛔⛔ 2026-09-22 返修：roll 币**必出一件**，单件概率 = 1/池子件数，没有「出货率」这个系数。
--    原来按 15% 建模是错的 —— 玩家的例子「池子剩 2 件 → 无底袋 50%」就是 1/2。
--    留这个常量只是为了公式好读；真要有出货率再把它调回去，全套算法不用改。
local ROLL_COIN_P = 1.0
local DIFF_NAME = { [16] = "M", [15] = "H", [14] = "N", [17] = "LFR" }
-- ⛔⛔ roll 币固定出**高一档**（用户 2026-09-22 确认）：随机→普通→英雄→史诗，史诗封顶。
--    所以「这枚币值不值」要按币档装等算，不是按你正在打的难度算。
local DIFF_UP = { [17] = 14, [14] = 15, [15] = 16, [16] = 16 }
local DIFF_STEP_ILVL = 13   -- 手册读不到币档时的兜底偏移（交接稿 §2：M 档，H −13 / N −26 / LFR −39）
-- 2026-09-22 /gi roll api 扫出来：暴雪**没有**「本 CD 是否 roll 过 / 池子剩什么」的接口
--（C_Loot.* 是队伍需求贪婪掷骰，C_ActionBar.GetBonusBar* 是变形条，全都同名不同事）。
-- 但留了 GetBonusRollEncounterJournalLinkDifficulty —— 奖励掷骰界面用它「按币档显示掉落」。
-- 优先问它拿币档，拿不到再用 DIFF_UP 兜底，这样规则变了插件也跟得上。
local VALID_DIFF = { [14] = true, [15] = true, [16] = true, [17] = true }
local function coinDifficultyFor(diff)
    if GetBonusRollEncounterJournalLinkDifficulty then
        local ok, d = pcall(GetBonusRollEncounterJournalLinkDifficulty, diff)
        if ok and type(d) == "number" and VALID_DIFF[d] then return d, "api" end
    end
    return DIFF_UP[diff] or diff, "table"
end
-- 12.1 S2 Roll 币的团本奖励装等不是“把手册掉落升满后显示”。
-- 官方 12.1 RAID REWARDS / NEBULOUS VOIDCORES：币与宝库同装等。
-- 英雄统一神话 1/6（318）；史诗普通件神话 6/6（334），稀有件/末两王神话 9（344）。
-- it.ilvl 始终保留实际到手装等；scoreIlvl 才用于和已升满装备公平比较。
local MYTH_RANK_BY_ILVL = { [318] = 1, [321] = 2, [324] = 3, [328] = 4, [331] = 5, [334] = 6 }
local RAID_COIN_SCORE_ILVL = { [318] = 334, [321] = 334, [324] = 334, [328] = 334, [331] = 334, [334] = 334, [344] = 344 }
local function raidCoinIlvl(diff, bossOrd, item, bossCount)
    if diff == 15 then return 318 end
    if diff == 16 then
        local rare = item and (item.displayAsVeryRare or item.displayAsExtremelyRare)
        local lastTwo = bossCount and bossCount >= 2 and bossOrd > bossCount - 2
        return (rare or lastTwo) and 344 or 334
    end
end
local function raidCoinScoreIlvl(ilvl)
    return RAID_COIN_SCORE_ILVL[ilvl] or ilvl
end
-- ⛔ 用户 2026-09-24「这个不能算必ROLL，因为在奥法BIS里面没有排名」「不能只看装等」：
--   Roll 币池子（团本 / 大秘境）改用宝库同一把尺子（神话轨：BiS 排名差 + 轨道 + 套装 + 其它专精，不看装等差），
--   判定线随之换成这把尺子的量级：必 roll ≥45（本专精 BiS #1 + 身上非神话轨 = 30+15）、值得要 ≥30、小提升 ≥15。
local MUST_PT, WANT_PT = 45, 30
local VERDICT = {
    { MUST_PT, "must", "|cFFFF4444", "必 roll" }, { WANT_PT, "want", "|cFFFFAA33", "值得要" }, { 15, "minor", "|cFFFFFF66", "小提升" }, { -1e9, "pass", "|cFF999999", "提升有限" },
}
local function verdictOf(score)
    if score <= 0 then return "pass", "|cFF999999", T("RV_PERSONAL_NO_GAIN", "无提升") end
    if score < 15 then return "pass", "|cFF999999", T("RV_PERSONAL_LIMITED", "提升有限") end
    for _, v in ipairs(VERDICT) do if score >= v[1] then local k = "RV_V_" .. v[2]:upper(); return v[2], v[3], T(k, v[4]) end end
end
-- ⛔ 用户 2026-09-24「必ROLL只考虑1 bis，项链和饰品TOP 2」「不用看提升幅度」：
--   Roll 币池子里「必 roll」= 本专精 BiS 第 1（项链 / 饰品 = 前 2），与分数、提升幅度无关；
--   其余件照常按分数判，但最高到「值得要」。身上已有 / 已 roll 到的件本来就不在池子里。
local MUST_TOP2 = { [2] = true, [13] = true, [14] = true }
local function rollVerdict(it, ctx, score, v)
    local b = ctx.bis and ctx.bis[it.id]
    local slot = it.slot or (it.slots and it.slots[1])
    local limit = MUST_TOP2[slot] and 2 or 1
    if b and b.rank and b.rank <= limit then return "must" end
    if v == "must" then return "want" end
    return v
end
RV.RollVerdict = rollVerdict
local VERDICT_BY_KEY = {}
function RV.VerdictInfo(key)
    if not next(VERDICT_BY_KEY) then for _, e in ipairs(VERDICT) do VERDICT_BY_KEY[e[2]] = e end end
    local e = VERDICT_BY_KEY[key]
    if not e or key == "pass" then return "|cFF999999", T("RV_PERSONAL_LIMITED", "提升有限") end
    return e[3], T("RV_V_" .. key:upper(), e[4])
end
local function vaultVerdictOf(score)
    if score >= MUST_PT then return T("RV_VAULT_LARGE_GAIN", "大提升") end
    if score >= WANT_PT then return T("RV_VAULT_CLEAR_GAIN", "明显提升") end
    local _, _, label = verdictOf(score)
    return label
end
local PAIR = { [11] = 12, [12] = 11, [13] = 14, [14] = 13, [16] = 17, [17] = 16 }
-- Enum.InventoryType → 槽位（成对槽给两个，取当前较差的那只）
local INV2SLOT = {
    [1] = { 1 }, [2] = { 2 }, [3] = { 3 }, [4] = { 5 }, [5] = { 5 }, [20] = { 5 }, [6] = { 6 }, [7] = { 7 }, [8] = { 8 }, [9] = { 9 }, [10] = { 10 },
    [11] = { 11, 12 }, [12] = { 13, 14 }, [16] = { 15 }, [13] = { 16, 17 }, [17] = { 16 }, [21] = { 16 }, [22] = { 17 }, [23] = { 17 }, [14] = { 17 }, [15] = { 16 }, [26] = { 16 },
}
-- Intrinsic item type is distinct from the inventory slot chosen for comparison.
-- Unknown class/subclass uses -1: zero is a valid item class/subclass.
local function itemMetadata(link, id)
    local key = link or id
    if not key then return 0, "", -1, -1 end
    local itemId, _, _, equipLoc, _, classID, subClassID = C_Item.GetItemInfoInstant(key)
    local invType = C_Item.GetItemInventoryTypeByID and C_Item.GetItemInventoryTypeByID(itemId or id or key)
    return invType or 0, equipLoc or "", classID or -1, subClassID or -1
end
local function currentSpecID()
    local index = GetSpecialization and GetSpecialization()
    return index and GetSpecializationInfo and GetSpecializationInfo(index) or 0
end
local SLOT_CN = { [1] = "头部", [2] = "颈部", [3] = "肩部", [5] = "胸部", [6] = "腰部", [7] = "腿部", [8] = "脚", [9] = "手腕", [10] = "手", [11] = "戒指", [12] = "戒指", [13] = "饰品", [14] = "饰品", [15] = "披风", [16] = "主手", [17] = "副手" }
-- 键在 locale 里逐个列了 RV_SLOT_1–17（动态拼，本地化审计看不到）
local function slotName(s) local k = "RV_SLOT_" .. s; return T(k, SLOT_CN[s] or tostring(s)) end

-- 装饰品（外观件）：⛔ 不会被 roll 到，扫描时就丢（用户 2026-09-22）
local function isCosmetic(itemId)
    if not itemId then return false end
    if C_Item and C_Item.IsCosmeticItem then
        local ok, v = pcall(C_Item.IsCosmeticItem, itemId)
        if ok and v then return true end
    end
    local _, _, _, _, _, classID, subClassID = C_Item.GetItemInfoInstant(itemId)
    return classID == 4 and subClassID == 5   -- 护甲 / 装饰品
end

-- ── 本周窗口（周四 0 点重置，用暴雪自己的倒计时算，各区服都对）────────
local function weekStart()
    local left = C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset and C_DateAndTime.GetSecondsUntilWeeklyReset()
    if not left then return 0 end
    return math.floor(GetServerTime() + left - 7 * 86400)
end
-- ⛔⛔ Roll 币池子机制（玩家 ChromaticaX 2026-09-22 确认，原来实现是反的）：
--   · roll 币池子和正常掉落**是两个池子**。你正常打本拾取到某件，它**不会**从 roll 币池子里移除，
--     下次用币照样能 roll 到它（重复件而已）。⛔ 所以拾取事件不能拿来缩池子。
--   · **只有用 roll 币 roll 出来的件**才从这个 boss 的 roll 币池子里移除，而且**跨周保留**
--     （他的例子：第一周 roll 到套装肩，池子只剩鞋子和无底袋 → 下周无底袋就是 50%）。
--   · 所以池子越 roll 越小，剩下件的概率越高 —— 这正是「该砸哪个 boss」的关键变量。
--   记在 GearInsightDB.rollGotBy[角色][专精][encounterID][itemID]，**不按周清**（09-24 起按角色 + 专精分开，见 perSpec）。
--   ⚠ 12.1 有没有可直接监听的「roll 币出货」事件还没确认：先挂 BONUS_ROLL_RESULT（有就用），
--     同时允许在面板上**右键**某一行手动标记 / 取消。
-- ⛔⛔ 玩家 Epiphany 2026-09-24：「当切换专精后 ROLL 币池子是重置的」「三个专精的 ROLL 池子是独立的」。
--   另外 GearInsightDB 是**账号共用**的（toc: SavedVariables），原来 rollGot / rollUsed / rollExclude 全账号一份：
--   小号 roll 到的件会从大号池子里消失、小号用过币的 boss 大号也显示「本周已用币」。现在：
--     · 已 roll 到 / 手动排除：按「角色 → 专精」分开（每个专精一个池子）；
--     · 本周已用币：按角色分开（一个 boss 一个 CD 用一次，跟专精无关）。
--   旧数据（没记角色和专精）第一次加载时整份归给当时登录的角色和专精。
local function charKey()
    return (UnitGUID and UnitGUID("player")) or ((UnitName and UnitName("player") or "?") .. "-" .. ((GetRealmName and GetRealmName()) or "?"))
end
local function specKey()
    local idx = GetSpecialization and GetSpecialization()
    return tostring(idx and GetSpecializationInfo and GetSpecializationInfo(idx) or 0)
end
local function migrateRollDB()
    local db = GearInsightDB
    if db.rollPoolV2 then return end
    local ck, sk = charKey(), specKey()
    db.rollGotBy, db.rollExcludeBy, db.rollUsedBy = db.rollGotBy or {}, db.rollExcludeBy or {}, db.rollUsedBy or {}
    if type(db.rollGot) == "table" and next(db.rollGot) then
        db.rollGotBy[ck] = db.rollGotBy[ck] or {}; db.rollGotBy[ck][sk] = db.rollGot
    end
    if type(db.rollExclude) == "table" and next(db.rollExclude) then
        db.rollExcludeBy[ck] = db.rollExcludeBy[ck] or {}; db.rollExcludeBy[ck][sk] = db.rollExclude
    end
    if type(db.rollUsed) == "table" then db.rollUsedBy[ck] = db.rollUsed end
    db.rollGot, db.rollExclude, db.rollUsed = nil, nil, nil
    db.rollPoolV2 = true
end
local function perSpec(field, encId)
    GearInsightDB = GearInsightDB or {}
    migrateRollDB()
    local root = GearInsightDB[field]
    local ck, sk = charKey(), specKey()
    root[ck] = root[ck] or {}
    root[ck][sk] = root[ck][sk] or {}
    local t = root[ck][sk]
    if not encId then return t end
    t[encId] = t[encId] or {}
    return t[encId]
end
local function rolledSet(encId) return perSpec("rollGotBy", encId) end
-- ⛔ 10-03 用户视频：「H 团本 roll 到两件、打了已 roll 到标记，切到史诗也显示 roll 到了；史诗里取消，英雄也跟着取消」。
--   英雄 / 史诗是两个 roll 币池子，标记要按难度分开存：键 = "boss#难度"。以前不分难度的老标记（键 = boss）两个难度都算，
--   在某个难度取消老标记时，把它转成「只属于另一个难度」，不丢用户原来的记录。大秘境（本 id、无难度）照旧。
local function rolledKey(encId, diff) return diff and (tostring(encId) .. "#" .. diff) or encId end
local function rolledView(encId, diff)
    local legacy = rolledSet(encId)
    if not diff then return legacy end
    local own, view = rolledSet(rolledKey(encId, diff)), {}
    for id, v in pairs(legacy) do if v then view[id] = true end end
    for id, v in pairs(own) do if v then view[id] = true end end
    return view
end
function RV.MarkRolled(encId, itemId, on, diff)
    if not (encId and itemId) then return end
    if diff then
        rolledSet(rolledKey(encId, diff))[itemId] = on and true or nil
        local legacy = rolledSet(encId)
        if not on and legacy[itemId] then
            legacy[itemId] = nil
            local other = (diff == 16) and 15 or 16
            rolledSet(rolledKey(encId, other))[itemId] = true
        end
    else
        rolledSet(encId)[itemId] = on and true or nil
    end
    _lastTop = nil
end
-- ⛔ 一个 boss 一个 CD 内只能 roll 一次 → 本周用过币的 boss 不进三选。按周清，按角色存。
local function coinedSet()
    GearInsightDB = GearInsightDB or {}
    migrateRollDB()
    local ck = charKey()
    local t = GearInsightDB.rollUsedBy[ck]
    local ws = weekStart()
    if not t or t.week ~= ws then t = { week = ws, bosses = {} }; GearInsightDB.rollUsedBy[ck] = t end
    return t.bosses
end
RV.CoinedSet = coinedSet
function RV.MarkCoined(encId, on)
    if not encId then return end
    coinedSet()[encId] = on and true or nil
    _lastTop = nil
end
-- 手动「这件不算在池子里」（用户 2026-09-22：妖术领主那两件）。跨周保留，按角色 + 专精 + boss 存。
local function excludedSet(encId) return perSpec("rollExcludeBy", encId) end
function RV.MarkExcluded(encId, itemId, on)
    if not (encId and itemId) then return end
    excludedSet(encId)[itemId] = on and true or nil
    _lastTop = nil
end
function RV.IsRolled(encId, itemId, diff)
    return rolledView(encId, diff)[itemId] or false
end

-- ── 参考价值过滤（用户 2026-09-22：「小提升比率应该不那么高」「主要看值得要以上的装备」）──
-- ⛔ 这条**只改口径，不改池子**：分母永远是整个 roll 币池子（能 roll 到的件数），
--    变的是「多少件算数」—— 一个本里 8 件全是 +23 的小提升，按小提升算就是 8/9 ★★☆，
--    看着很值，实际砸下去全是鸡肋。默认「值得要以上」。
RV.MIN_LEVELS = {
    { key = "all",   score = 0,  label = "全部装备" },
    { key = "minor", score = 15, label = "小提升以上" },
    { key = "want",  score = 30, label = "值得要以上" },
    { key = "must",  score = 45, label = "必 roll" },   -- ⛔ 别写「只看必 roll」：按钮前缀已经是「只看：」
}
local MIN_DEFAULT = "want"
function RV.MinKey()
    local k = GearInsightDB and GearInsightDB.rollMinKey
    for _, v in ipairs(RV.MIN_LEVELS) do if v.key == k then return k end end
    return MIN_DEFAULT
end
local function minScore()
    local k = RV.MinKey()
    for _, v in ipairs(RV.MIN_LEVELS) do if v.key == k then return v.score end end
    return WANT_PT
end
function RV.SetMinKey(k)
    GearInsightDB = GearInsightDB or {}
    GearInsightDB.rollMinKey = k
    _lastTop = nil
end
function RV.MinLabel()
    local k = RV.MinKey()
    if k == "all" then return T("RV_PERSONAL_ALL", "全部装备") end
    for _, v in ipairs(RV.MIN_LEVELS) do
        if v.key == k then return T("RV_MIN_" .. string.upper(v.key), v.label) end
    end
    return ""
end

-- 身上已经穿着的件：itemID → 身上那只的装等（同 id 占两格就留高的那只）。
-- ⛔⛔ 只按 itemID 判「已拥有」是错的（用户 2026-09-22 截图）：
--    同一件装备英雄档和史诗档**是同一个 itemID**，你穿着 H 318 的祖尔金处斩技法，
--    史诗 344 那件是 +33 的真提升，却被判成「已拥有」、0%、还被踢出了池子。
--    判据必须是「身上这只的装等 >= 这次要 roll 出来的装等」才算重复件。
local function equippedIds()
    local ids = {}
    for slot = 1, 17 do
        if slot ~= 4 then
            local link = GetInventoryItemLink and GetInventoryItemLink("player", slot)
            local id = link and C_Item.GetItemInfoInstant(link)
            if id then
                local ilvl = (C_Item.GetDetailedItemLevelInfo and C_Item.GetDetailedItemLevelInfo(link)) or 0
                if not ids[id] or ilvl > ids[id] then ids[id] = ilvl end
            end
        end
    end
    return ids
end

-- 「这件我已经有了（同档或更高）」。⛔ 别写成 owned[it.id] —— 那会把低一档的当成已拥有。
local function ownedAtLeast(owned, it)
    local have = owned and owned[it.id]
    if not have then return false end
    return have >= (it.ilvl or 0)
end

-- 身上装等中位数：空槽拿它当基准，⛔ 别拿 0 —— 否则一件 305 的件会算出 +305 的提升。
local function baselineIlvl(eq)
    local list = {}
    for _, e in pairs(eq or {}) do
        if e and (e.ilvl or 0) > 0 then list[#list + 1] = e.ilvl end
    end
    if #list == 0 then return 0 end
    table.sort(list)
    return list[math.floor(#list / 2) + 1]
end
-- 主手拿着双手武器时，副手**本来就该空**：这个槽不参与评分（用户 2026-09-22 截图：
-- 副手空着 → 深渊军刀算出 +305「必 roll」）。
local function offhandDisabled()
    local link = GetInventoryItemLink and GetInventoryItemLink("player", 16)
    if not link then return false end
    local _, _, _, equipLoc = C_Item.GetItemInfoInstant(link)
    return equipLoc == "INVTYPE_2HWEAPON" or equipLoc == "INVTYPE_RANGED" or equipLoc == "INVTYPE_RANGEDRIGHT"
end

-- ── 轨道升满装等 ────────────────────────────────────────────────────────
-- ⛔ 打分一律用「轨道内升满」的装等（用户 2026-09-22）：掉落件和身上的件都按升满比，
--    否则等于拿「升满的新件」去比「没升的旧件」，delta 虚高。
-- 12.1 S2 real item-level steps include +4 (311→315, 324→328).
-- Shared by the main panel and item tooltip; never approximate with rank * 3.
local UPGRADE_LEVELS = { 266, 269, 272, 276, 279, 282, 285, 289, 292, 295, 298, 302, 305, 308, 311, 315, 318, 321, 324, 328, 331, 334 }
local function maxedIlvl(ilvl, cur, mx)
    ilvl = ilvl or 0
    if not (cur and mx) or mx <= cur then return ilvl end
    for i, level in ipairs(UPGRADE_LEVELS) do
        if ilvl == level then return UPGRADE_LEVELS[i + mx - cur] or ilvl end
    end
    return ilvl -- Unknown seasonal/special level: do not invent an upgrade cap.
end
GearInsight.UpgradeTrackCeiling = maxedIlvl
-- 从物品链接的 tooltip 读「升级：神话 1/6」→ cur, max, name（读不到返回 nil）
local _LINK_UPG_PAT
local function linkTrack(link)
    if not (link and C_TooltipInfo and C_TooltipInfo.GetHyperlink) then return nil end
    local ok, data = pcall(C_TooltipInfo.GetHyperlink, link)
    if not (ok and data and data.lines) then return nil end
    if issecretvalue and issecretvalue(data.lines) then return nil end
    if _LINK_UPG_PAT == nil then
        local fmt = ITEM_UPGRADE_TOOLTIP_FORMAT
        if type(fmt) == "string" and fmt:find("%%d") then
            local esc = fmt:gsub("%p", "%%%0")
            esc = esc:gsub("%%%%s", "(.-)"):gsub("%%%%d", "(%%d+)")
            _LINK_UPG_PAT = "^%s*" .. esc .. "%s*$"
        else
            _LINK_UPG_PAT = false
        end
    end
    local dur = DURABILITY_TEMPLATE and DURABILITY_TEMPLATE:gsub("%%d", ""):gsub("%s", "") or nil
    for i = 2, 6 do
        local line = data.lines[i]
        if not line then break end
        local ok2, txt = pcall(function() return line.leftText end)
        if ok2 and type(txt) == "string" and not (issecretvalue and issecretvalue(txt)) then
            if _LINK_UPG_PAT then
                local nm, a, b = txt:match(_LINK_UPG_PAT)
                if a then return tonumber(a), tonumber(b), nm end
            end
            -- ⛔ 全角冒号 3 字节，用 plain find 定位；排除「耐久度 44/55」
            local c1, c2 = txt:find("：", 1, true), txt:find(":", 1, true)
            local cpos, clen = nil, 1
            if c1 and (not c2 or c1 < c2) then cpos, clen = c1, 3 elseif c2 then cpos, clen = c2, 1 end
            if cpos and not (dur and txt:gsub("%s", ""):find(dur, 1, true)) then
                local nm, a, b = txt:sub(cpos + clen):match("^%s*(.-)%s*(%d+)%s*/%s*(%d+)%s*$")
                if a then return tonumber(a), tonumber(b), nm end
            end
        end
    end
    return nil
end

-- ── 身上装备快照 ─────────────────────────────────────────────────────────
local function equipped()
    local eq, setCount, tierIds = {}, 0, {}
    local _, cls = UnitClass("player")
    for _, v in pairs((GearInsight.TierSets and GearInsight.TierSets[cls]) or {}) do tierIds[v[1]] = true end
    for slot = 1, 17 do
        if slot ~= 4 then
            local link = GetInventoryItemLink("player", slot)
            local id = link and C_Item.GetItemInfoInstant(link)
            local ilvl = link and C_Item.GetDetailedItemLevelInfo and C_Item.GetDetailedItemLevelInfo(link) or 0
            local okT, cur, mx, nm = pcall(GearInsight.SlotUpgradeTrack, GearInsight, slot)
            local _c, _m = okT and cur or nil, okT and mx or nil
            eq[slot] = { id = id, ilvl = maxedIlvl(ilvl or 0, _c, _m), wornIlvl = ilvl or 0, link = link, track = okT and nm or nil, trackCur = okT and cur or nil, trackMax = okT and mx or nil, isSet = id and tierIds[id] or false }
            if id and tierIds[id] then setCount = setCount + 1 end
        end
    end
    return eq, setCount, tierIds
end

-- 当前专精 BiS：itemId → 该槽第几候选 / 装等（团本参照系）
local function bisIndex()
    local s = GearInsight.StatReader and GearInsight.StatReader:ReadAll()
    local data = s and GearInsight.BisData and GearInsight.BisData:GetSpecData(s.class, s.spec, s.heroTalent)
    local idx = {}
    if data and data.bisBySlot then
        for slotId, cands in pairs(data.bisBySlot) do
            for i, c in ipairs(cands or {}) do
                if c.itemId and (not idx[c.itemId] or idx[c.itemId].rank > i) then idx[c.itemId] = { rank = i, ilvl = c.ilvl or 0, slot = slotId } end
            end
        end
    end
    return idx, data, s
end

-- 大米池：槽位 → 本专精 M+ 候选最高装等（同槽同档就打五折）
local function mplusCeil(data, key)
    local out = {}
    local bd = GearInsight.BisData
    local mp = bd and bd.mplusBySlot and key and bd.mplusBySlot[key]
    if type(mp) == "table" then
        for slotId, cands in pairs(mp) do
            for _, c in ipairs(cands or {}) do if c.ilvl and (not out[slotId] or c.ilvl > out[slotId]) then out[slotId] = c.ilvl end end
        end
    end
    return out
end

-- ⛔⛔ 用户 2026-09-24（网站会话转）：「只要轨道是神话，就不应该看装等，看轨道，看BIS排名，来打分」
--   截图：M+ 格神话轨胸甲被「311→318(+7)·升满 321→334(+13)」带成「小提升 19 分」。
--   宝库候选是神话轨 → 不比当前装等也不比升满装等（神话轨都能升到顶），只看：
--   ① BiS 排名差：名次分(新件) − 名次分(身上)，排名更低会扣分；没上榜 = 0 分；
--      排名取本专精当前英雄天赋 bisBySlot 的名次（网站「坯子 BiS 第 N / M 名」同一份数据）；
--      套装部位的坯子若催化后的套装件名次更高，按套装件名次算（+ 套装进度分）；
--   ② 轨道：身上不是神话轨 +15；③ 套装进度分照旧。非神话轨候选沿用装等逻辑。
local VAULT_RANK_PT = { 30, 22, 15, 10, 6, 3 }   -- 第 7 名以后 / 没上榜 = 0
local MYTH_TRACK_PT = 15
local function isMythTrack(name)
    return name ~= nil and tostring(name):find(T("RV_TRACK_MYTH", "神话"), 1, true) ~= nil
end
local function rankPt(r) return r and VAULT_RANK_PT[r] or 0 end
-- ⛔⛔ 用户 2026-09-24「一个是三系NO1，一个是坯子第三，不能一样的分吧，优化打分体系」：
--   骨匣（本专精 #1，冰霜/鲜血也 #1）和磐石马裤（坯子横评 #3/5，催化后 = 套装 #1）原来同分，因为
--   催化路线直接拿了套装件的 #1 分，而 4 件套时第 5 件不加套装分。现在：
--   ① 催化路线的名次分 × 坯子系数（转换优先级 #1 ×1.0 / #2 ×0.8 / #3 ×0.6 / #4 ×0.45 / 以后 ×0.3）——
--      催化出来的副属性是坯子自己的，只有排第一的坯子才能转出「BiS 那件」；
--   ② 本职业其它专精也上榜：每个专精 #1 +4、#2~3 +2（最多 +8），换专精也能用。
local FILLER_F = { 1.0, 0.8, 0.6, 0.45 }
local function fillerFactor(idx) return FILLER_F[idx or 99] or 0.3 end
local function otherSpecBonus(it, ctx)
    local pt, parts = 0, {}
    for _, o in ipairs(ctx.otherBis or {}) do
        local r = o.idx[it.id]
        if r and r <= 3 then
            pt = pt + (r == 1 and 4 or 2)
            parts[#parts + 1] = (o.label or "?") .. "#" .. r
        end
    end
    if pt > 8 then pt = 8 end
    return pt, table.concat(parts, " ")
end
local function mythVaultScore(it, ctx, slot, cur, newIlvl, reasons)
    reasons[#reasons + 1] = T("RV_R_MYTH_RULE", "神话轨：不比装等，按轨道 + BiS 排名打分")
    local b, wb = ctx.bis[it.id], cur.id and ctx.bis[cur.id] or nil
    local rank, wr = b and b.rank, wb and wb.rank
    if rank and rank <= 3 then it.bisRank = rank end
    it.catalystSwap = nil
    local c = ctx.setCount
    local nextSet = (c == 1 and 15) or (c == 3 and 30) or 0
    local setPt = (it.isSet and not cur.isSet) and nextSet or 0
    local catTxt, swapScore
    local hit = ctx.filler and TIER_SLOT[slot] and not it.isSet and ctx.filler(it.id)
    local rankTxt
    if hit and not hit.isTier and hit.tierRank then
        it.filler = hit
        rankTxt = string.format(T("RV_R_FILLER_RANK", "坯子转换优先级 #%d/%d"), hit.idx or 0, hit.total or 0)
    end
    local newPt = rankPt(rank)
    if hit and it.filler then
        local catPt = rankPt(hit.tierRank) * fillerFactor(hit.idx)
        if cur.isSet then
            -- ⛔ 用户 2026-09-24「这个坯子是#1，神话级别，评分是不是评低了？」：身上是英雄轨套装、新件是神话轨坯子 #1，
            --   原来一律「身上已是套装件，不按催化算」→ 只剩轨道分被排名差扣成 +2。
            --   现在：催化后替换身上那件套装（件数不变），比的是「新坯子 vs 身上套装当初的坯子」的质量差
            --   （身上那件按副属性反推，本体按本体在横评里的名次），轨道分下面照常算。
            local wf = ctx.wornFiller and ctx.wornFiller(cur)
            local wIdx = wf and wf.idx
            local base = rankPt(hit.tierRank)
            local diff = base * fillerFactor(hit.idx) - base * fillerFactor(wIdx or hit.idx)
            it.catalystSwap = true
            reasons[#reasons + 1] = string.format(T("RV_R_FILLER_SWAP", "催化后替换身上套装（%s）：身上 %s → 新件坯子 #%d（%+d）"),
                hit.tierName or "?", wIdx and ("#" .. wIdx) or T("RV_R_UNRANKED", "未上榜"), hit.idx or 0, math.floor(diff + 0.5))
            rank, setPt, swapScore = hit.tierRank, 0, diff
        elseif catPt + nextSet > newPt + setPt then
            rank, setPt, newPt = hit.tierRank, nextSet, catPt
            catTxt = string.format(T("RV_R_MYTH_CAT", "（催化成 %s）"), hit.tierName or "?") .. " · " .. rankTxt
                .. string.format(T("RV_R_FILLER_FACTOR", " ×%.2f"), fillerFactor(hit.idx))
        else
            reasons[#reasons + 1] = rankTxt
        end
    end
    local unranked = T("RV_R_UNRANKED", "未上榜")
    local score
    if it.catalystSwap then
        score = swapScore
    else
        local wTxt = cur.empty and T("RV_R_EMPTY_SLOT", "空槽") or (wr and ("#" .. wr) or unranked)
        local rp = newPt - (cur.empty and 0 or rankPt(wr))
        reasons[#reasons + 1] = string.format(T("RV_R_MYTH_RANK", "BiS 排名：身上 %s → 新件 %s（%+d）"), wTxt, rank and ("#" .. rank) or unranked, math.floor(rp + 0.5)) .. (catTxt or "")
        score = rp
    end
    if not catTxt and not it.catalystSwap then
        local ob, otxt = otherSpecBonus(it, ctx)
        if ob > 0 then score = score + ob; reasons[#reasons + 1] = string.format(T("RV_R_OTHER_SPECS", "本职业其它专精也上榜（%s）+%d"), otxt, ob) end
    end
    if isMythTrack(cur.track) then
        reasons[#reasons + 1] = T("RV_R_MYTH_SAME", "身上已是神话轨，轨道不加分")
    elseif cur.track or cur.empty or (cur.ilvl or 0) < newIlvl then
        score = score + MYTH_TRACK_PT
        reasons[#reasons + 1] = string.format(T("RV_R_TRACK", "轨道 %s→神话 +%d"), cur.track or (cur.empty and T("RV_R_EMPTY_SLOT", "空槽")) or T("RV_R_NO_TRACK", "无轨道"), MYTH_TRACK_PT)
    else
        reasons[#reasons + 1] = T("RV_R_MYTH_NOTRACK_HIGH", "身上无升级轨道且装等不低于新件升满，轨道不加分")
    end
    if setPt > 0 then score = score + setPt; reasons[#reasons + 1] = string.format(T("RV_R_SET", "套装 %d→%d 件 +%d"), c, c + 1, setPt) end
    if score < 0 then score = 0 end
    score = math.floor(score + 0.5)
    it.slot, it.delta, it.newIlvl = slot, newIlvl - (cur.ilvl or 0), newIlvl
    return score, verdictOf(score), reasons
end

-- ── 打分（服务端 score_item 同口径）──────────────────────────────────────
-- it = { id, ilvl, slots = {..}, isSet, name }；ctx = { eq, setCount, bis, mplus }
function RV.ScoreItem(it, ctx)
    local reasons = {}
    it.bisRank, it.filler = nil, nil
    if not it.slots or #it.slots == 0 then return 0, "pass", reasons end
    if (ctx.specId or currentSpecID()) == 71 then
        local invType, equipLoc = itemMetadata(it.link, it.id)
        if invType == 13 or invType == 21 or invType == 22 or equipLoc == "INVTYPE_WEAPON"
            or equipLoc == "INVTYPE_WEAPONMAINHAND" or equipLoc == "INVTYPE_WEAPONOFFHAND" then
            it.slot = it.slots[1]
            return 0, "pass", { T("RV_R_ARMS_ONEHAND", "武器战使用双手武器，这把单手武器不适合当前专精") }
        end
    end
    -- 成对槽：比当前较差的那只
    local slot, cur = it.slots[1], nil
    for _, s in ipairs(it.slots) do
        local e = ctx.eq[s]
        local eb = e and ctx.bis[e.id]
        local cb = cur and ctx.bis[cur.id]
        local weakerRank = e and cur and e.ilvl == cur.ilvl
            and (eb and eb.rank or math.huge) > (cb and cb.rank or math.huge)
        if not cur or (e and e.ilvl < cur.ilvl) or not e or weakerRank then slot, cur = s, e or { ilvl = 0 } end
    end
    cur = cur or { ilvl = 0 }
    it.slot = slot
    -- ⛔ 空槽不拿 0 当基准：副手空着时一件 305 会算出 +305「必 roll」（用户 2026-09-22）
    if (cur.ilvl or 0) <= 0 then
        if slot == 17 and ctx.noOffhand then
            return 0, "pass", { T("RV_R_2H", "你拿的是双手武器，副手用不上") }
        end
        cur = { ilvl = ctx.baseline or 0, empty = true }
        if (cur.ilvl or 0) > 0 then reasons[#reasons + 1] = T("RV_R_EMPTY", "这个槽是空的，按你身上装等中位数比") end
    end
    -- Vault links carry the current drop ilvl in it.ilvl and the fully-upgraded
    -- value in scoreIlvl. Equipped gear is already normalized to its track cap.
    -- Always compare cap vs cap; mixing raw new ilvl with capped equipped ilvl
    -- understated the 318 Myth 1/6 shoulder as +11, then ×0.5 => the bogus +6.
    local newIlvl = it.scoreIlvl or it.ilvl or 0
    if ctx.vault and isMythTrack(it.trackName) then return mythVaultScore(it, ctx, slot, cur, newIlvl, reasons) end
    local delta = newIlvl - (cur.ilvl or 0)
    if it.scoreIlvl and cur.wornIlvl then
        it.currentDelta = (it.ilvl or 0) - cur.wornIlvl
        reasons[#reasons + 1] = string.format(T("RV_R_CURRENT_COMPARE", "当前装等：身上 %d → 新件 %d（%+d）"), cur.wornIlvl, it.ilvl or 0, it.currentDelta)
    end
    if newIlvl ~= (it.ilvl or 0) or (cur.wornIlvl and cur.wornIlvl ~= cur.ilvl) then
        reasons[#reasons + 1] = string.format(T("RV_R_MAXED_COMPARE", "按轨道升满比较：新件 %d，身上 %d"), newIlvl, cur.ilvl or 0)
    end
    local score = delta * (SLOT_W[slot] or 1.0)
    if delta > 0 then reasons[#reasons + 1] = string.format(T("RV_R_ILVL", "装等 +%d（%s）"), delta, slotName(slot))
    elseif delta < 0 then reasons[#reasons + 1] = string.format(T("RV_R_ILVL_DOWN", "装等 %d，比身上低"), delta) end
    local b = ctx.bis[it.id]
    local currentBis = ctx.bis[cur.id]
    local alreadyBetter = b and currentBis and currentBis.rank <= b.rank and (cur.ilvl or 0) >= newIlvl
    -- Candidate-list membership alone is not BiS: match the server's top-three
    -- rule, and do not reward replacing equally capped, better-ranked gear.
    local bisPts = 0
    if b and b.rank <= 3 then it.bisRank = b.rank end
    if b and b.rank <= 3 and not alreadyBetter then
        local full = ctx.vault and VAULT_BIS_PT[b.rank] or BIS_PT
        if newIlvl >= (b.ilvl or 0) - 1 then bisPts = full; reasons[#reasons + 1] = string.format(T("RV_R_BIS", "BiS 第 %d 候选 +%d"), b.rank, bisPts)
        else bisPts = ctx.vault and math.floor(full / 2) or BIS_LOW_PT; reasons[#reasons + 1] = string.format(T("RV_R_BIS_LOW", "BiS 同款低一档 +%d"), bisPts) end
        score = score + bisPts
    elseif b and b.rank > 3 then
        reasons[#reasons + 1] = T("RV_R_NOT_TOP_BIS", "不在当前评分候选前 3 名，不加 BiS 分")
    elseif alreadyBetter then
        reasons[#reasons + 1] = T("RV_R_CURRENT_BIS", "身上装备排名不低于新件，升满装等也不低，不加 BiS 分")
    end
    if it.isSet and not cur.isSet then
        local c = ctx.setCount
        local pt = (c == 1 and 15) or (c == 3 and 30) or 0
        if pt > 0 then score = score + pt; reasons[#reasons + 1] = string.format(T("RV_R_SET", "套装 %d→%d 件 +%d"), c, c + 1, pt) end
    end
    -- 宝库：套装部位的坯子按催化后的套装件再算一遍（见文件头 VAULT_BIS_PT 注释）
    local hit = ctx.vault and ctx.filler and TIER_SLOT[slot] and not it.isSet and ctx.filler(it.id)
    if hit and not hit.isTier and hit.tierRank then
        it.filler = hit
        local rankTxt = string.format(T("RV_R_FILLER_RANK", "坯子转换优先级 #%d/%d"), hit.idx or 0, hit.total or 0)
        if cur.isSet then
            reasons[#reasons + 1] = rankTxt .. T("RV_R_FILLER_WORN", "；身上这格已是套装件，不按催化算")
        else
            local full = (VAULT_BIS_PT[hit.tierRank] or 0) * fillerFactor(hit.idx)
            local cat = math.floor(((newIlvl >= (hit.tierIlvl or 0) - 1) and full or full / 2) + 0.5)
            local c = ctx.setCount
            local setPt = (c == 1 and 15) or (c == 3 and 30) or 0
            if cat + setPt > bisPts then
                score = score - bisPts + cat + setPt
                reasons[#reasons + 1] = string.format(T("RV_R_FILLER", "催化成 %s 后 = BiS #%d +%d"), hit.tierName or "?", hit.tierRank, cat)
                    .. (setPt > 0 and string.format(T("RV_R_FILLER_SET", "，套装 %d→%d 件 +%d"), c, c + 1, setPt) or "")
                    .. " · " .. rankTxt
            else
                reasons[#reasons + 1] = rankTxt
            end
        end
    end
    if it.diff == 16 and cur.track and (cur.trackMax or 0) > 0 and not tostring(cur.track):find(T("RV_TRACK_MYTH", "神话"), 1, true) then
        score = score + TRACK_PT; reasons[#reasons + 1] = string.format(T("RV_R_TRACK", "轨道 %s→神话 +%d"), cur.track, TRACK_PT)
    end
    -- 大米无 CD：非套装、非饰品/武器，大米池同槽同档 → ×0.5
    if score > 0 and not it.isSet and slot ~= 13 and slot ~= 14 and slot ~= 16 and slot ~= 17 then
        local ceil = ctx.mplus[slot]
        if ceil and ceil >= newIlvl then score = score * 0.5; reasons[#reasons + 1] = T("RV_R_MPLUS", "大米也掉同槽同档 ×0.5"); it.farmable = true end
    end
    if ctx.vault and not it.filler then
        local ob, otxt = otherSpecBonus(it, ctx)
        if ob > 0 then score = score + ob; reasons[#reasons + 1] = string.format(T("RV_R_OTHER_SPECS", "本职业其它专精也上榜（%s）+%d"), otxt, ob) end
    end
    if ctx.vault and score > 0 and not it.bisRank and not it.filler then
        score = score * 0.5; reasons[#reasons + 1] = T("RV_R_VAULT_NOT_BIS", "不在本专精 BiS 前 3、也不是套装坯子 ×0.5")
    end
    -- ⛔ 用户 2026-09-24（奥法截图：剧毒狂怒之泉 装等 +36 ×1.6 + 轨道 = 66「必 roll」）：「这个不能算必ROLL，因为在奥法BIS里面没有排名」
    --   不在本专精 BiS 名单里（任何名次都没有）→ 最高只到「值得要」，分数封顶 59。宝库口径另有 ×0.5，不走这里。
    if not ctx.vault and score >= MUST_PT and not b then
        score = MUST_PT - 1
        reasons[#reasons + 1] = T("RV_R_NOT_BIS_CAP", "不在本专精 BiS 名单里，最高只算「值得要」")
    end
    if score < 0 then score = 0 end
    score = math.floor(score + 0.5)
    local v = verdictOf(score)
    it.slot, it.delta, it.newIlvl = slot, delta, newIlvl
    return score, v, reasons
end

-- ── 地下城手册：当前团本每个 boss 本专精能用的掉落（按难度）────────────
local _lootCache = {}   -- "diff:specID" → { inst = {id,name}, bosses = { {id,name,items={...}} } }
-- ⛔ 玩家 Epiphany 2026-09-24（QQ/微信群截图）：「切了专精…重扫点击无效果、列表不会变…现在还是默认是恢复的」。
--   ① 缓存原来只按难度存：换专精后仍吃旧专精的扫描结果 → 缓存键带上 specID；
--   ② 切专精事件（PLAYER_SPECIALIZATION_CHANGED）清缓存并刷新开着的面板；
--   ③ 手册筛选（EJ_SetLootFilter）换专精后，同一帧读到的掉落列表可能还是上一个专精的
--      （我们读完又把筛选还原成玩家原来的，于是每次重扫都读到同一份旧表）→
--      「这个专精第一次扫」的结果不进缓存、标 pending，面板 2 秒后自己再扫一次。
local _scannedSpec = {}   -- specID → true：这个专精已经完整扫过一次（第二次起才信、才缓存）
local function curSpecID()
    local idx = GetSpecialization and GetSpecialization()
    return idx and GetSpecializationInfo and GetSpecializationInfo(idx) or 0
end
local function lootKey(diff) return tostring(diff) .. ":" .. tostring(curSpecID()) end
-- ⛔⛔ 2026-09-22 返修（用户截图：选中「潮缠石窟」，只有 1 个 boss、装等 305）：
--   原来只扫**最后一个 tier** 的团本列表、**第一个**命中本赛季集合的就返回。
--   而「本赛季集合」= BisData 里出现过的全部 instanceId（**含大秘境地下城**），
--   于是随便一个小本就被当成本赛季团本收工了。
--   现在：从最新 tier 往回扫**每个** tier 的团本列表，要求 ① boss 数 ≥ 5（团本至少 6 个，
--   地下城最多 5 个）② 在本赛季集合里；命中里取 boss 数最多的。都不命中再退回
--   「最新 tier 里 boss 数最多的团本」。
local function encounterCount(instId)
    if not EJ_SelectInstance then return 0 end
    local ok = pcall(EJ_SelectInstance, instId)
    if not ok then return 0 end
    local n = 0
    while n < 30 do
        local nm = EJ_GetEncounterInfoByIndex(n + 1, instId)
        if not nm then break end
        n = n + 1
    end
    return n
end
local MIN_RAID_BOSS = 5
-- ⛔ 用户 2026-09-24「roll币池子有问题，ROLL币也能ROLL到本职业的兑换币」（毒织残骸 → 套装护肩）：
--   兑换物是「杂项」物品，没有装备部位，原来被部位过滤直接丢掉，池子里少了它，概率和币值都偏。
--   这里内置本赛季 20 个兑换物：itemID → { 套装部位, 能用的职业 }（由 services/wow-agent/data_cache/blizzard_items
--   的「使用：制造一件适合你职业的灵魂绑定套装X」生成；换季重跑同一段脚本）。扫团本时把本职业能用的兑换物
--   换成该部位的套装件（TierSets），按套装件的 BiS 排名 / 套装件数打分；「已 roll 到」也记到套装件上。
RV.TIER_TOKENS = {
    [270910] = { 10, { WARLOCK = true, MAGE = true, PRIEST = true } },
    [270911] = { 10, { DRUID = true, DEMONHUNTER = true, MONK = true, ROGUE = true } },
    [270912] = { 10, { HUNTER = true, SHAMAN = true, EVOKER = true } },
    [270913] = { 10, { DEATHKNIGHT = true, PALADIN = true, WARRIOR = true } },
    [270914] = { 1, { WARLOCK = true, MAGE = true, PRIEST = true } },
    [270915] = { 1, { DRUID = true, DEMONHUNTER = true, MONK = true, ROGUE = true } },
    [270916] = { 1, { HUNTER = true, SHAMAN = true, EVOKER = true } },
    [270917] = { 1, { DEATHKNIGHT = true, PALADIN = true, WARRIOR = true } },
    [270918] = { 7, { WARLOCK = true, MAGE = true, PRIEST = true } },
    [270919] = { 7, { DRUID = true, DEMONHUNTER = true, MONK = true, ROGUE = true } },
    [270920] = { 7, { HUNTER = true, SHAMAN = true, EVOKER = true } },
    [270921] = { 7, { DEATHKNIGHT = true, PALADIN = true, WARRIOR = true } },
    [270922] = { 3, { WARLOCK = true, MAGE = true, PRIEST = true } },
    [270923] = { 3, { DRUID = true, DEMONHUNTER = true, MONK = true, ROGUE = true } },
    [270924] = { 3, { HUNTER = true, SHAMAN = true, EVOKER = true } },
    [270925] = { 3, { DEATHKNIGHT = true, PALADIN = true, WARRIOR = true } },
    [270926] = { 5, { WARLOCK = true, MAGE = true, PRIEST = true } },
    [270927] = { 5, { DRUID = true, DEMONHUNTER = true, MONK = true, ROGUE = true } },
    [270928] = { 5, { HUNTER = true, SHAMAN = true, EVOKER = true } },
    [270929] = { 5, { DEATHKNIGHT = true, PALADIN = true, WARRIOR = true } },
}
function RV.TokenPiece(tokenId, cls)
    local t = RV.TIER_TOKENS[tokenId]
    if not (t and cls and t[2][cls]) then return nil end
    local piece = GearInsight.TierSets and GearInsight.TierSets[cls] and GearInsight.TierSets[cls][t[1]]
    if not piece then return nil end
    return piece[1], t[1], piece[2]
end

-- ⛔ 用户 2026-09-24（/gi roll 截图「本周 3 枚币砸哪三个 boss」）：「实时读取用户身上的B的数量，如果是0，就说假设拿一个币这样用」。
--   Roll 币 = 货币「星云虚空之核」Nebulous Voidcore（currencyID 3418，Wowhead 核过）。
--   身上有 N 枚 → 标题 / 「至少中一件」按 N 枚算（砸 N 个不同的 boss）；0 枚 → 按「假设拿一枚」算。
RV.COIN_CURRENCY = 3418
function RV.CoinCount()
    local ok, info = pcall(function() return C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo(RV.COIN_CURRENCY) end)
    if ok and type(info) == "table" and info.quantity then return info.quantity end
    return nil
end
-- 这次按几枚币算：有币按实际数（至少 1），读不到 / 0 枚按 1 枚
function RV.CoinK()
    local n = RV.CoinCount()
    if n and n > 0 then return n end
    return 1
end

local function currentRaidInstance()
    if not (EJ_GetInstanceByIndex and EJ_SelectInstance and EJ_SelectTier and EJ_GetNumTiers and EJ_GetEncounterInfoByIndex) then return nil end
    local season = GearInsight.CurrentSeasonInstances and GearInsight.CurrentSeasonInstances()
    local nTier = EJ_GetNumTiers() or 1
    local best, fallback
    for tier = nTier, 1, -1 do
        pcall(EJ_SelectTier, tier)
        local idx = 1
        while true do
            local id, name = EJ_GetInstanceByIndex(idx, true)   -- true = 团本
            if not id then break end
            local n = encounterCount(id)
            if n >= MIN_RAID_BOSS then
                if season and season[id] then
                    if not best or n > best[3] then best = { id, name, n } end
                elseif not fallback or n > fallback[3] then fallback = { id, name, n } end
            end
            idx = idx + 1
        end
        if best then break end          -- 从最新往回找，命中就停
    end
    local pick = best or fallback
    if pick then return pick[1], pick[2], pick[3] end
end

-- /gi roll debug：选本选错时把手册看到的东西全打出来（用户报「boss 数量不对」用）
function RV.DebugInstances()
    local season = GearInsight.CurrentSeasonInstances and GearInsight.CurrentSeasonInstances()
    local nSeason = 0
    for _ in pairs(season or {}) do nSeason = nSeason + 1 end
    GearInsight:Print(string.format("|cFFFFD100[roll debug]|r tier=%d · 本赛季集合 %d 个 id", EJ_GetNumTiers() or -1, nSeason))
    for tier = (EJ_GetNumTiers() or 1), 1, -1 do
        pcall(EJ_SelectTier, tier)
        local idx = 1
        while true do
            local id, name = EJ_GetInstanceByIndex(idx, true)
            if not id then break end
            GearInsight:Print(string.format("  tier%d #%d  id=%d  boss=%d  %s%s", tier, idx, id, encounterCount(id), name or "?", (season and season[id]) and "  |cFF66CC66[本赛季]|r" or ""))
            idx = idx + 1
        end
        if tier <= (EJ_GetNumTiers() or 1) - 2 then break end   -- 只打最近两个 tier，别刷屏
    end
    for _, d in ipairs({ 17, 14, 15, 16 }) do
        local cd, src = coinDifficultyFor(d)
        GearInsight:Print(string.format("  币档 %s → %s（%s）· 硬编码表 → %s", DIFF_NAME[d] or d, DIFF_NAME[cd] or cd, src, DIFF_NAME[DIFF_UP[d]] or "?"))
    end
    local id, name, n = currentRaidInstance()
    GearInsight:Print(string.format("|cFFFFD100[roll debug]|r 选中：%s (id=%s, boss=%s)", name or "nil", tostring(id), tostring(n)))
end

function RV.ScanRaid(diff, force)
    diff = diff or 16
    if _lootCache[lootKey(diff)] and not force then return _lootCache[lootKey(diff)] end
    local getLoot = C_EncounterJournal and C_EncounterJournal.GetLootInfoByIndex
    if not (getLoot and EJ_SelectInstance and EJ_GetNumLoot and EJ_SetLootFilter and EJ_GetEncounterInfoByIndex) then return nil, "noapi" end
    if EncounterJournal and EncounterJournal.IsShown and EncounterJournal:IsShown() then return nil, "ejopen" end
    local instId, instName = currentRaidInstance()
    if not instId then return nil, "noinst" end
    -- 10-03 玩家「我等了半天好像也没有加载成功」：手册模块没载入时掉落表一直是空的 → 先载入
    if not (EncounterJournal or (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Blizzard_EncounterJournal"))) then
        if C_AddOns and C_AddOns.LoadAddOn then pcall(C_AddOns.LoadAddOn, "Blizzard_EncounterJournal") end
    end
    local prevClass, prevSpec = 0, 0
    pcall(function() prevClass, prevSpec = EJ_GetLootFilter() end)
    local classID = select(3, UnitClass("player"))
    local specIdx = GetSpecialization and GetSpecialization()
    local specID = specIdx and GetSpecializationInfo(specIdx) or 0
    pcall(EJ_SelectInstance, instId)
    if EJ_SetDifficulty then pcall(EJ_SetDifficulty, diff) end
    pcall(EJ_SetLootFilter, classID or 0, specID or 0)   -- 暴雪自己判「本专精能用」
    if C_EncounterJournal.SetSlotFilter and Enum.ItemSlotFilterType then pcall(C_EncounterJournal.SetSlotFilter, Enum.ItemSlotFilterType.NoFilter) end
    local bosses, byId, order = {}, {}, {}
    local i = 1
    while true do
        local name, _, encId, _, _, _, dEncId = EJ_GetEncounterInfoByIndex(i, instId)   -- encId = 手册 ID（掉落表用）；dEncId = ENCOUNTER_START 给的那个
        if not name then break end
        bosses[#bosses + 1] = { id = encId, dId = dEncId, name = name, items = {} }; byId[encId] = bosses[#bosses]; order[encId] = i
        i = i + 1
    end
    local _, cls = UnitClass("player")
    local tierIds = {}
    for _, v in pairs((GearInsight.TierSets and GearInsight.TierSets[cls]) or {}) do tierIds[v[1]] = true end
    local n = EJ_GetNumLoot() or 0
    local got, pending = 0, false
    for k = 1, n do
        local ok, info = pcall(getLoot, k)
        if ok and info and info.itemID and byId[info.encounterID] then
            local invType = C_Item.GetItemInventoryTypeByID and C_Item.GetItemInventoryTypeByID(info.itemID)
            if not invType then pending = true end
            local slots = (not isCosmetic(info.itemID)) and invType and INV2SLOT[invType] or nil
            -- ⛔ 手册物品数据异步载入：link 没到位时装等是 0，算出来就是「装等 -317」这种鬼数
            --    （用户 2026-09-22 截图：妖术领主的凝视/面容）。先按 itemID 补读，仍失败就标记为未知。
            local ilvl = info.link and C_Item.GetDetailedItemLevelInfo and C_Item.GetDetailedItemLevelInfo(info.link) or 0
            -- ⛔ 别按 itemID 补读：那是不带 bonusID 的**基础装等**，比真实值低一截
            --    （用户截图：行里 321 / tooltip 328）。读不到就标未知，等数据到了自动重扫。
            if (ilvl or 0) <= 0 and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, info.itemID) end
            local pieceId, pieceSlot, pieceName = RV.TokenPiece(info.itemID, cls)
            if pieceId then
                -- 兑换物 → 本职业该部位的套装件（id 用套装件，BiS / 已拥有 / 已 roll 到都按它算）
                byId[info.encounterID].items[#byId[info.encounterID].items + 1] = { id = pieceId, token = info.itemID,
                    name = (info.name or "?") .. " → " .. (pieceName or "?"), icon = info.icon, link = info.link, ilvl = ilvl,
                    slots = { pieceSlot }, isSet = true, diff = diff, noIlvl = ((ilvl or 0) <= 0),
                    displayAsVeryRare = info.displayAsVeryRare, displayAsExtremelyRare = info.displayAsExtremelyRare }
                got = got + 1
                if (ilvl or 0) <= 0 then pending = true end
            elseif slots then
                byId[info.encounterID].items[#byId[info.encounterID].items + 1] = { id = info.itemID, name = info.name, icon = info.icon, link = info.link, ilvl = ilvl, slots = slots, isSet = tierIds[info.itemID] or false, diff = diff, noIlvl = ((ilvl or 0) <= 0),
                    displayAsVeryRare = info.displayAsVeryRare, displayAsExtremelyRare = info.displayAsExtremelyRare }
                got = got + 1
                if (ilvl or 0) <= 0 then pending = true end
            end
        elseif not ok or not info or not info.itemID then
            pending = true
        end
    end
    pcall(EJ_SetLootFilter, prevClass or 0, prevSpec or 0)
    RV._scanDiag = { inst = instName, instId = instId, diff = diff, total = n, got = got, bosses = #bosses, class = classID, spec = specID }
    if got < 3 then return nil, "loading" end   -- 手册掉落异步载入，冷启动第一次可能是空的
    local res = { inst = { id = instId, name = instName }, bosses = bosses, diff = diff, pending = pending }
    local sk = "r" .. tostring(specID) .. ":" .. tostring(diff)
    if _scannedSpec[sk] then
        _lootCache[lootKey(diff)] = res
    else
        -- 这个专精第一次扫：可能读到的是上一个专精的表，先给面板显示，但标 pending 让它 2 秒后再扫一次
        _scannedSpec[sk] = true
        res.pending = true; res.specWarmup = true
    end
    return res
end

-- 本周锁定：该团本该难度已杀的 boss 名集合
local function killedThisWeek(instName, diff)
    local killed = {}
    for i = 1, (GetNumSavedInstances and GetNumSavedInstances() or 0) do
        local name, _, _, difficulty, locked, _, _, isRaid, _, _, numEnc = GetSavedInstanceInfo(i)
        if isRaid and locked and name == instName and difficulty == diff then
            for j = 1, (numEnc or 0) do
                local bossName, _, isKilled = GetSavedInstanceEncounterInfo(i, j)
                if bossName and isKilled then killed[bossName] = true end
            end
        end
    end
    return killed
end

-- ── 三选：每个 boss 期望分 + 概率，取前三 ────────────────────────────────
function RV.Evaluate(diff, opts)
    opts = opts or {}
    local raid, why = RV.ScanRaid(diff)
    if not raid then return nil, why end
    local eq, setCount = equipped()
    local bis, data, s = bisIndex()
    local key = data and data.className and data.specName and (data.className .. "/" .. data.specName .. "/" .. (data.heroTalent or ""))
    -- 宝库同一把尺子（RV.VaultCtx）；币出神话轨 → 下面打分前把 trackName 设成神话
    local ctx = RV.VaultCtx(eq, setCount)
    local MYTH = T("RV_TRACK_MYTH", "神话")
    local killed = killedThisWeek(raid.inst.name, diff)
    local coined = coinedSet()
    local owned = equippedIds()
    local MIN = minScore()
    -- 币档掉落表：同一批物品、更高一档的装等。手册读不到（还在载入）就退回 +13 偏移。
    local coinDiff, coinSrc = coinDifficultyFor(diff)
    local coinIlvl = {}
    local coinStep = DIFF_STEP_ILVL
    local pending = raid.pending
    if coinDiff ~= diff then
        local cr = RV.ScanRaid(coinDiff)
        if not cr or cr.pending then pending = true end
        if cr then for _, cb in ipairs(cr.bosses) do for _, ci in ipairs(cb.items) do if (ci.ilvl or 0) > 0 then coinIlvl[ci.id] = { ilvl = ci.ilvl, link = ci.link } end end end end
        -- ⛔⛔ 2026-09-22：硬编码 +13 是错的（用户截图：本难度 315 → 币档 344，实际差 29，
        --    而且团本后段 boss 装等更高，档差不是常数）。改成拿**两档都读到的件**现算中位数档差，
        --    只给少数没读到的件兜底；实在一件都配不上才退回 DIFF_STEP_ILVL。
        local offs = {}
        for _, rb in ipairs(raid.bosses) do
            for _, ri in ipairs(rb.items) do
                local hi = coinIlvl[ri.id]
                if hi and (ri.ilvl or 0) > 0 then offs[#offs + 1] = hi.ilvl - ri.ilvl end
            end
        end
        if #offs > 0 then table.sort(offs); coinStep = offs[math.floor(#offs / 2) + 1] end
    end
    local out = { inst = raid.inst, diff = diff, coinDiff = coinDiff, coinSrc = coinSrc, bosses = {}, top3 = {}, pending = pending }
    for bi, b in ipairs(raid.bosses) do
        -- 先把「已经用币 roll 到过」的件挑出来：它们已经出池，**不进分母**
        local got, exc = rolledView(b.id, diff), excludedSet(b.id)
        -- 出池 = 已用币 roll 到 / 身上已经有了 / 手动排除 / 装等读不出来（数据没载入，算出来是假的）
        -- ⛔ 「已拥有」要拿**币档装等**比，不是手册那一档：身上 H 318 的件，史诗 344 那份仍是提升，
        --    不能算重复件（用户 2026-09-22 截图：祖尔金的处斩技法被判「已拥有 0%」）。
        local function coinLvl(it)
            local fixed = raidCoinIlvl(diff, bi, it, #raid.bosses)
            if fixed then return fixed end
            local level, link = it.ilvl or 0, it.link
            if coinDiff ~= diff and not it.noIlvl then
                local c = coinIlvl[it.id]
                level = c and c.ilvl or ((it.ilvl or 0) + coinStep)
                link = c and c.link or link
            end
            return level
        end
        -- ⛔⛔ 玩家 Epiphany 2026-09-24：「这个我是低保拿的，并不是 ROLL 的，而这里应该是 50% 并非 100%」「ROLL 出相同的装备，这样对插件的体感不太好」。
        --   身上已有（低保 / 正常拾取拿到的）**不出池**：用币照样可能 roll 到重复件 → 留在分母里、分数记 0。
        --   只有「用币 roll 到过」「手动排除」「装等读不出」才出池（和 ChromaticaX 09-22 确认的机制一致）。
        local function outOfPool(it, lvl)
            return got[it.id] or exc[it.id] or it.noIlvl
        end
        local nPool = 0
        for _, it0 in ipairs(b.items) do if not outOfPool(it0, coinLvl(it0)) then nPool = nPool + 1 end end
        local row = { id = b.id, dId = b.dId, name = b.name, ord = bi, done = killed[b.name] or false, coined = coined[b.id] or false, items = {},
            nEligible = nPool, nAll = #b.items, nRolled = #b.items - nPool, nUseful = 0, nGood = 0 }
        local sum = 0
        for _, it0 in ipairs(b.items) do
            local it = {}; for k, v in pairs(it0) do it[k] = v end
            it.rolled = got[it.id] or false
            it.excluded = exc[it.id] or false
            -- ⛔ it.owned 要在换成币档装等**之后**再判，见下面（先占位 false）
            it.owned = false
            -- 换成币档装等（it.diff 一起换：轨道 +8 判的是「币出的是不是史诗档」）
            it.dropIlvl = it.ilvl
            if coinDiff ~= diff and not it.noIlvl then
                local c = coinIlvl[it.id]
                it.ilvl = c and c.ilvl or ((it.ilvl or 0) + coinStep)
                -- ⛔ link 也换成币档那一份：否则 tooltip 显示的是本难度的件，和行里的装等对不上
                if c and c.link then it.link = c.link end
                it.coinGuess = (c == nil)
                it.diff = coinDiff
            end
            -- Roll 币实际装等由难度和 boss 档位决定；显示实际值，评分另用升满值。
            local fixed = raidCoinIlvl(diff, bi, it, #raid.bosses)
            if fixed then
                it.ilvl, it.coinGuess = fixed, false
                it.diff = 16
            end
            local _tc, _tm = linkTrack(it.link)
            it.rawIlvl = it.ilvl
            it.scoreIlvl = raidCoinScoreIlvl(it.ilvl)
            it.trackCur, it.trackMax = MYTH_RANK_BY_ILVL[it.ilvl] or _tc, 6
            if fixed == 344 then it.trackCur, it.trackMax = 9, 9 end
            if it.noIlvl or it.coinGuess then out.pending = true end
            it.owned = ownedAtLeast(owned, it)
            it.trackName = MYTH
            local score, v, reasons = RV.ScoreItem(it, ctx)
            if outOfPool(it) then
                -- 已出池：不算概率也不算期望，但留在列表里给玩家看（右键可取消标记）
                score, v, reasons = 0, "pass", { it.rolled and T("RV_R_ROLLED", "已经用币 roll 到过，已出池")
                    or it.owned and T("RV_R_OWNED2", "身上这件已经是同档或更高 → 不计入池子")
                    or it.excluded and T("RV_R_EXCLUDED", "你手动排除了这件（Shift+右键恢复）")
                    or T("RV_R_NOILVL", "装等读不出来（手册数据没载入）→ 不计入池子") }
                it.score, it.verdict, it.reasons, it.pRoll = score, v, reasons, 0
                row.items[#row.items + 1] = it
            elseif it.owned then
                -- 身上已有同档或更高：不算提升，但仍在池子里（可能 roll 到重复）
                it.score, it.verdict, it.pRoll = 0, "pass", nPool > 0 and (ROLL_COIN_P / nPool) or 0
                it.reasons = { T("RV_R_OWNED3", "身上已有同档或更高：不算提升，但仍在 Roll 币池子里，可能 roll 到重复件") }
                row.items[#row.items + 1] = it
            else
                v = rollVerdict(it, ctx, score, v)
                if v == "must" then reasons[#reasons + 1] = T("RV_R_MUST_BIS", "本专精 BiS 第 1（项链 / 饰品前 2）→ 必 roll") end
                it.score, it.verdict, it.reasons = score, v, reasons
                it.pRoll = nPool > 0 and (ROLL_COIN_P / nPool) or 0
                -- ⛔ 「有用」的门槛由参考价值过滤定（默认值得要以上），不是写死 15：
                --    八件 +23 小提升也能凑出 8/9 ★★☆，看着很值，砸下去全是鸡肋（用户 09-22）。
                if score >= MIN then row.nUseful = row.nUseful + 1 end
                if score >= WANT_PT then row.nGood = row.nGood + 1 end
                -- 期望值同口径：够不上门槛的件不往期望里加，否则排序还是被小提升堆出来
                if score >= MIN then sum = sum + score end
                row.items[#row.items + 1] = it
            end
        end
        table.sort(row.items, function(a, c) return a.score > c.score end)
        row.expected = row.nEligible > 0 and (sum / row.nEligible) or 0
        row.pUseful = row.nEligible > 0 and (ROLL_COIN_P * row.nUseful / row.nEligible) or 0
        row.pGood = row.nEligible > 0 and (ROLL_COIN_P * row.nGood / row.nEligible) or 0
        row.best = row.items[1]
        out.bosses[#out.bosses + 1] = row
    end
    local cand = {}
    -- ⛔ 三枚币砸三个不同 boss：已杀的（本 CD 机会没了）和本周已用过币的都不进三选
    for _, r in ipairs(out.bosses) do
        if (not r.done or opts.includeDone) and not r.coined and r.expected > 0 then cand[#cand + 1] = r end
    end
    table.sort(cand, function(a, c) return a.expected > c.expected end)
    local pu, pg = 1, 1
    for i = 1, math.min(RV.CoinK(), #cand) do out.top3[i] = cand[i]; pu = pu * (1 - cand[i].pUseful); pg = pg * (1 - cand[i].pGood) end
    out.pAnyUseful, out.pAnyGood = #out.top3 > 0 and (1 - pu) or 0, #out.top3 > 0 and (1 - pg) or 0
    out.nCand, out.nCoined = #cand, 0
    for _, r in ipairs(out.bosses) do if r.coined then out.nCoined = out.nCoined + 1 end end
    return out
end

-- ⚠ 2026-09-22：roll 币的「本 CD 用过没 / 哪些件已出池」目前**靠手动标记 + BONUS_ROLL_RESULT 兜底**。
--    12.1 到底有没有公开接口不知道（Blizzard UI 源码在 CASC 包里，本地 grep 不到），
--    所以给一个探测命令：进本后 /gi roll api，把输出发回来再决定挂哪个接口。
local PROBE_TOKENS = { "bonus", "coin", "rollloot", "lootroll", "encounterloot", "raidloot", "weeklyreward", "lockout" }
local function probeName(k)
    local lk = k:lower()
    for _, t in ipairs(PROBE_TOKENS) do if lk:find(t, 1, true) then return true end end
    return false
end
function RV.ProbeAPI()
    -- ⛔ 聊天框装不下也复制不出来（用户 2026-09-22）：结果全部收进可复制框，Ctrl+A / Ctrl+C 整段拷走。
    local buf = {}
    local function L(fmt, ...) buf[#buf + 1] = select("#", ...) > 0 and string.format(fmt, ...) or fmt end
    -- ① C_ 命名空间（最可能藏真接口）
    local ns = {}
    for k, v in pairs(_G) do
        if type(k) == "string" and k:sub(1, 2) == "C_" and type(v) == "table" then
            local fns = {}
            for fk in pairs(v) do if type(fk) == "string" and probeName(fk) then fns[#fns + 1] = fk end end
            if #fns > 0 then table.sort(fns); ns[#ns + 1] = k .. "." .. table.concat(fns, "/" .. k .. ".") end
        end
    end
    table.sort(ns)
    L("[1 C_命名空间] " .. (#ns > 0 and table.concat(ns, " , ") or "(无)"))
    -- ② 全局函数/表（⛔ 跳过字符串常量，WAR_MODE_BONUS 那一堆全是文案）
    local hits = {}
    for k, v in pairs(_G) do
        local tv = type(v)
        if type(k) == "string" and probeName(k) and (tv == "function" or tv == "table") then hits[#hits + 1] = k .. "(" .. tv .. ")" end
    end
    table.sort(hits)
    L("[2 全局函数/表] " .. (#hits > 0 and table.concat(hits, " , ") or "(无)"))
    -- ③ 本周锁定（看有没有 roll 相关字段）
    for i = 1, (GetNumSavedInstances and GetNumSavedInstances() or 0) do
        local t = { GetSavedInstanceInfo(i) }
        local parts = {}
        for j = 1, 20 do parts[#parts + 1] = tostring(t[j]) end
        L("[3 锁定#%d] %s", i, table.concat(parts, "|"))
    end
    -- ④ 背包里疑似 roll 币的物品
    local bagHit = 0
    for bag = 0, 5 do
        for slot = 1, (C_Container and C_Container.GetContainerNumSlots(bag) or 0) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            local nm = info and info.itemName
            if nm then
                local l = nm:lower()
                if nm:find("币") or nm:find("徽") or l:find("coin") or l:find("token") then
                    bagHit = bagHit + 1
                    L("[4 背包] %s x%s id=%s", nm, tostring(info.stackCount), tostring(info.itemID))
                end
            end
        end
    end
    if bagHit == 0 then L("[4 背包] (没找到疑似 roll 币的物品)") end
    -- ⑤ 货币
    if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyListSize then
        for i = 1, C_CurrencyInfo.GetCurrencyListSize() do
            local info = C_CurrencyInfo.GetCurrencyListInfo(i)
            if info and info.name and not info.isHeader then
                L("[5 货币] %s=%s id=%s", info.name, tostring(info.quantity), tostring(info.currencyID))
            end
        end
    end
    GearInsight:Print(string.format(T("RV_API_DONE", "roll 接口探测完成：C_ 命中 %d 个，全局 %d 个 —— 结果已放进可复制框（Ctrl+A → Ctrl+C）"), #ns, #hits))
    GearInsight:ShowCopyText(table.concat(buf, "  ‖  "),
        T("RV_API_HINT", "Ctrl+A 全选 → Ctrl+C 复制，粘贴给开发者"),
        T("RV_API_TITLE", "roll 币接口探测"), "GearInsightRollApi")
end


-- ── 大秘境：赛季本 + 每个 boss 本专精能用的掉落 ──────────────────────────
-- ⛔ 与团本两处不同（用户 2026-09-22 定）：
--   ① 出货档 = 神话级别（10 层以上），所以装等不按地下城手册给的，而是用
--      「大米池同槽最高装等」(BisData mplusBySlot，随赛季数据走)；
--   ② **每次通关都能 roll**，没有周 CD → 不做三选、不记「本 CD 已用」。
local _dungCache
local MPLUS_DIFF = 23   -- 神话地下城；取不到就退回英雄(2)
function RV.ScanDungeons(force)
    if _dungCache and _dungCache.spec == curSpecID() and not force then return _dungCache end
    local getLoot = C_EncounterJournal and C_EncounterJournal.GetLootInfoByIndex
    if not (getLoot and EJ_SelectInstance and EJ_GetNumLoot and EJ_SetLootFilter and EJ_GetEncounterInfoByIndex) then return nil, "noapi" end
    if EncounterJournal and EncounterJournal.IsShown and EncounterJournal:IsShown() then return nil, "ejopen" end
    local season = GearInsight.CurrentSeasonInstances and GearInsight.CurrentSeasonInstances()
    local prevClass, prevSpec = 0, 0
    pcall(function() prevClass, prevSpec = EJ_GetLootFilter() end)
    local classID = select(3, UnitClass("player"))
    local specIdx = GetSpecialization and GetSpecialization()
    local specID = specIdx and GetSpecializationInfo(specIdx) or 0
    local _, cls = UnitClass("player")
    local tierIds = {}
    for _, v in pairs((GearInsight.TierSets and GearInsight.TierSets[cls]) or {}) do tierIds[v[1]] = true end
    local out, got = {}, 0
    local pending = false
    for tier = (EJ_GetNumTiers() or 1), 1, -1 do
        pcall(EJ_SelectTier, tier)
        local idx = 1
        while true do
            local id, name = EJ_GetInstanceByIndex(idx, false)   -- false = 地下城
            if not id then break end
            if season and season[id] then
                pcall(EJ_SelectInstance, id)
                if EJ_SetDifficulty then if not pcall(EJ_SetDifficulty, MPLUS_DIFF) then pcall(EJ_SetDifficulty, 2) end end
                pcall(EJ_SetLootFilter, classID or 0, specID or 0)
                if C_EncounterJournal.SetSlotFilter and Enum.ItemSlotFilterType then pcall(C_EncounterJournal.SetSlotFilter, Enum.ItemSlotFilterType.NoFilter) end
                local bosses, byId = {}, {}
                local i = 1
                while true do
                    local bn, _, encId, _, _, _, dEncId = EJ_GetEncounterInfoByIndex(i, id)
                    if not bn then break end
                    bosses[#bosses + 1] = { id = encId, dId = dEncId, name = bn, ord = i, items = {} }
                    byId[encId] = bosses[#bosses]
                    i = i + 1
                end
                local lootCount = EJ_GetNumLoot() or 0
                if lootCount == 0 or #bosses == 0 then pending = true end
                for k = 1, lootCount do
                    local ok, info = pcall(getLoot, k)
                    if ok and info and info.itemID and byId[info.encounterID] then
                        local invType = C_Item.GetItemInventoryTypeByID and C_Item.GetItemInventoryTypeByID(info.itemID)
                        if not invType then pending = true end
                        local slots = (not isCosmetic(info.itemID)) and invType and INV2SLOT[invType] or nil
                        if slots then
                            local ilvl = info.link and C_Item.GetDetailedItemLevelInfo and C_Item.GetDetailedItemLevelInfo(info.link) or 0
                            if (ilvl or 0) <= 0 and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, info.itemID) end
                            local t = byId[info.encounterID]
                            t.items[#t.items + 1] = { id = info.itemID, name = info.name, icon = info.icon, link = info.link,
                                ilvl = ilvl, slots = slots, isSet = tierIds[info.itemID] or false, diff = 16, noIlvl = ((ilvl or 0) <= 0) }
                            got = got + 1
                            if (ilvl or 0) <= 0 then pending = true end
                        end
                    elseif not ok or not info or not info.itemID then
                        pending = true
                    end
                end
                -- ⛔ 用户 2026-09-24 截图：Roll 币 62 分来自「秋日恩赐腰带」—— 纳洛拉克的洞穴是重制副本，手册把
                --    祖阿曼旧版掉落（装等 28）和本赛季掉落列在一起，后面又按大米神话档把装等抬成 334 去比 → +57。
                --    本副本里手册装等比最高的低 40 以上 = 旧版遗留掉落，剔除（装等读不到的照旧等重试）。
                local top = 0
                for _, bo in ipairs(bosses) do for _, it in ipairs(bo.items) do if (it.ilvl or 0) > top then top = it.ilvl end end end
                if top > 0 then
                    for _, bo in ipairs(bosses) do
                        for n = #bo.items, 1, -1 do
                            local lv = bo.items[n].ilvl or 0
                            if lv > 0 and lv < top - 40 then table.remove(bo.items, n); got = got - 1 end
                        end
                    end
                end
                if #bosses > 0 then out[#out + 1] = { id = id, name = name, bosses = bosses } end
            end
            idx = idx + 1
        end
        if #out > 0 then break end   -- 只取最新 tier 的赛季本
    end
    pcall(EJ_SetLootFilter, prevClass or 0, prevSpec or 0)
    if got < 3 then return nil, "loading" end
    table.sort(out, function(a, b) return (a.name or "") < (b.name or "") end)
    out.pending = pending
    out.spec = curSpecID()
    local dk = "d" .. tostring(out.spec)
    if _scannedSpec[dk] then
        _dungCache = out
    else
        _scannedSpec[dk] = true
        out.pending = true
    end
    return out
end

-- 打分：⛔ 两条与团本不同
--   ① 装等用「大米池同槽最高装等」(= 神话档)，不用手册给的地下城装等；
--   ② ⛔⛔ 池子按**本**算，不按 boss（用户 2026-09-22）：一枚币的分母 = 整本能用的件数。
function RV.EvaluateMplus()
    local dungeons, why = RV.ScanDungeons()
    if not dungeons then return nil, why end
    local eq, setCount = equipped()
    local bis, data = bisIndex()
    local key = data and data.className and data.specName and (data.className .. "/" .. data.specName .. "/" .. (data.heroTalent or ""))
    local mplus = mplusCeil(data, key)
    local owned = equippedIds()
    local ctx = RV.VaultCtx(eq, setCount)
    ctx.mplus = {}   -- ⛔ 大米折扣对大米件本身不适用
    local MYTH = T("RV_TRACK_MYTH", "神话")
    local MIN = minScore()
    local out = { dungeons = {}, top = {}, minKey = RV.MinKey(), pending = dungeons.pending }
    for _, d in ipairs(dungeons) do
        local exc = excludedSet(d.id)     -- 排除标记按「本」存（池子就是本级的）
        -- 10-02 玩家「大米装备不能右键标记…团本的可以」：右键一直有写 rollGotBy[本]，但这里只读了排除标记 → 点了没反应。
        -- 与团本同一口径：roll 到过的件出池（不占分母），列表里高亮「已ROLL到」。
        local got = rolledSet(d.id)
        -- 先把全本掉落摊平、去重（同一件可能挂在多个 boss 下）
        local flat, seen = {}, {}
        for _, b in ipairs(d.bosses) do
            for _, it0 in ipairs(b.items) do
                if not seen[it0.id] then
                    seen[it0.id] = true
                    local it = {}; for k, v in pairs(it0) do it[k] = v end
                    it.bossName, it.bossOrd = b.name, b.ord
                    flat[#flat + 1] = it
                end
            end
        end
        -- ⛔ 同团本那条：「已拥有」拿**神话档**装等比，身上 292 的件不该挡住 344 那份
        local function mythLvl(it)
            local slot = it.slots and it.slots[1]
            local ceil = slot and mplus[slot]
            if ceil and ceil > 0 then return ceil end
            return it.ilvl or 0
        end
        -- 身上已有不出池（同团本那条，Epiphany 09-24）：留在分母里、分数记 0
        local function outOfPool(it, lvl)
            return got[it.id] or exc[it.id] or it.noIlvl
        end
        local nPool = 0
        for _, it in ipairs(flat) do if not outOfPool(it, mythLvl(it)) then nPool = nPool + 1 end end
        local drow = { id = d.id, name = d.name, items = {}, nEligible = nPool, nUseful = 0, nGood = 0 }
        local sum = 0
        for _, it in ipairs(flat) do
            it.excluded = exc[it.id] or false
            it.rolled = got[it.id] or false
            it.dropIlvl = it.ilvl
            -- 币出神话档 = **神话轨道升满**（用户 2026-09-22 拍板），即 BisData 里大米池同槽最高装等。
            -- ⛔ 不是团本史诗掉落那个数，也不是宝库到手的神话 1/6 起始装等。
            local slot = it.slots and it.slots[1]
            local target = slot and mplus[slot]
            if target and target > 0 then it.ilvl = target; it.mythIlvl = true end
            it.owned = ownedAtLeast(owned, it)   -- ⛔ 换成神话档之后再判
            if outOfPool(it) then
                it.score, it.verdict, it.pRoll = 0, "pass", 0
                it.reasons = { it.rolled and T("RV_R_ROLLED", "已经用币 roll 到过，已出池")
                    or it.owned and T("RV_R_OWNED2", "身上这件已经是同档或更高 → 不计入池子")
                    or it.excluded and T("RV_R_EXCLUDED", "你手动排除了这件（Shift+右键恢复）")
                    or T("RV_R_NOILVL", "装等读不出来（手册数据没载入）→ 不计入池子") }
            elseif it.owned then
                it.score, it.verdict, it.pRoll = 0, "pass", nPool > 0 and (ROLL_COIN_P / nPool) or 0
                it.reasons = { T("RV_R_OWNED3", "身上已有同档或更高：不算提升，但仍在 Roll 币池子里，可能 roll 到重复件") }
            else
                it.trackName, it.scoreIlvl = MYTH, it.ilvl
                local sc, v, rs = RV.ScoreItem(it, ctx)
                v = rollVerdict(it, ctx, sc, v)
                if v == "must" then rs[#rs + 1] = T("RV_R_MUST_BIS", "本专精 BiS 第 1（项链 / 饰品前 2）→ 必 roll") end
                it.score, it.verdict, it.reasons = sc, v, rs
                it.pRoll = nPool > 0 and (ROLL_COIN_P / nPool) or 0
                -- ⛔ 同团本那条：门槛由参考价值过滤定，期望值也只累加够门槛的件
                if sc >= MIN then drow.nUseful = drow.nUseful + 1 end
                if sc >= WANT_PT then drow.nGood = drow.nGood + 1 end
                if sc >= MIN then sum = sum + sc end
            end
            drow.items[#drow.items + 1] = it
        end
        table.sort(drow.items, function(a, c) return a.score > c.score end)
        drow.expected = nPool > 0 and (sum / nPool) or 0
        drow.pUseful = nPool > 0 and (ROLL_COIN_P * drow.nUseful / nPool) or 0
        drow.pGood = nPool > 0 and (ROLL_COIN_P * drow.nGood / nPool) or 0
        drow.best = drow.items[1]
        out.dungeons[#out.dungeons + 1] = drow
    end
    -- ⛔ 按「一枚币中达标件的概率」排，不按期望分（用户 2026-09-22：概率高的放前面）
    table.sort(out.dungeons, function(a, b)
        if (a.pUseful or 0) ~= (b.pUseful or 0) then return (a.pUseful or 0) > (b.pUseful or 0) end
        return (a.expected or 0) > (b.expected or 0)
    end)
    -- ⛔ 不截断成 3 个：大米每次通关都能砸，所有值得刷的本都该列出来（用户 09-22）
    for _, d in ipairs(out.dungeons) do
        -- ⛔ 门槛只决定排序权重，别拿它把榜单砍到剩 3 行（用户 09-22「多展示几个」）：
        --    只要这个本里还有你能用的件，就列出来，按概率高低排。
        if (d.nEligible or 0) > 0 then out.top[#out.top + 1] = d end
    end
    return out
end

-- ── 窗口 ──────────────────────────────────────────────────────────────────
-- 2026-09-22 UI 返修（用户「看不懂啥意思」）：
--   ① 副标题原来压在难度按钮上 → 分层；② 固定 560 高、内容三行底下一大片空 → 按内容收高；
--   ③ 一行挤成一长串「期望 16 · 中有用件 15.0% · 值得要 5.0%」→ 分列 + 换成人话：
--      boss 行说「一枚币 15% 中」，物品行直接给「装等 +13」而不是内部分数（分数进 tooltip）；
--   ④ 三选加金色徽章 + 分隔线；⑤ 空状态给可操作提示。
-- One combined ranking for the Roll UI and the exported recommendation.
function RV.EvaluateRoll(diff, opts)
    opts = opts or {}
    if opts.fresh then
        _lootCache = {}; _dungCache = nil
        if C_AddOns and C_AddOns.LoadAddOn then pcall(C_AddOns.LoadAddOn, "Blizzard_EncounterJournal") end
    end
    local res, why = RV.Evaluate(diff, { includeDone = opts.includeDone })
    if not res then return nil, why end
    local mp, mpWhy
    if opts.includeMplus then
        local ok, result, reason = pcall(RV.EvaluateMplus)
        if ok then mp, mpWhy = result, reason else mpWhy = "loading" end
    end
    local pool = {}
    for _, r in ipairs(res.bosses) do
        if (not r.done or opts.includeDone) and not r.coined and (r.pUseful or 0) > 0 then
            pool[#pool + 1] = { kind = "raid", name = r.name, ord = r.ord, p = r.pUseful or 0,
                exp = r.expected or 0, nU = r.nUseful or 0, nE = r.nEligible or 0, best = r.best, items = r.items,
                pGood = r.pGood or 0, nGood = r.nGood or 0, encounterId = r.dId or 0, journalEncounterId = r.id or 0, dungeonId = 0 }
        end
    end
    for _, d in ipairs(mp and mp.dungeons or {}) do
        if (d.pUseful or 0) > 0 then
            pool[#pool + 1] = { kind = "mp", name = d.name, p = d.pUseful or 0,
                exp = d.expected or 0, nU = d.nUseful or 0, nE = d.nEligible or 0, best = d.best, items = d.items,
                pGood = d.pGood or 0, nGood = d.nGood or 0, encounterId = 0, journalEncounterId = 0, dungeonId = d.id or 0 }
        end
    end
    for i, entry in ipairs(pool) do entry.order = i end
    table.sort(pool, function(a, b)
        if a.p ~= b.p then return a.p > b.p end
        if a.exp ~= b.exp then return a.exp > b.exp end
        return a.order < b.order
    end)
    local pu, pg = 1, 1
    for i = 1, math.min(RV.CoinK(), #pool) do pu = pu * (1 - pool[i].p); pg = pg * (1 - pool[i].pGood) end
    return { raid = res, mp = mp, pool = pool,
        pending = res.pending or (opts.includeMplus and (not mp or mp.pending)) or false,
        pendingReason = mpWhy or "loading", pAnyUseful = (1 - pu), pAnyGood = (1 - pg) }
end

local frame
local PAD, ROW_H = 16, 22
local W_NAME, W_SLOT, W_GAIN, W_VERD, W_PROB = 236, 104, 78, 74, 76
-- 团本内第几个 boss，社区口径写作 M1/H3/N5（用户 2026-09-22 要求）
local function bossTag(diff, ord)
    return string.format("|cFFAA9966%s%d|r", DIFF_NAME[diff] or "", ord or 0)
end
local function bossTip(b)
    local ne, nu = b.nEligible or 0, b.nUseful or 0
    local s = string.format(T("RV_BOSS_TIP6", "池子里本专精能用 %d 件 · 其中 %d 件对你有提升 · %d 件值得要\n一枚币必出其中一件 → 中有用件 = %d/%d = %s\n（已 roll 到的、手动排除的不算在分母里；身上已有的仍在池子里，可能 roll 到重复）"),
        ne, nu, b.nGood or 0, nu, ne, ne > 0 and string.format("%.0f%%", nu / ne * 100) or "-")
    if (b.nRolled or 0) > 0 then
        s = s .. string.format(T("RV_BOSS_TIP4", "\n已用币 roll 到过 %d 件，已出池 → 剩下的件概率更高\n右键这行 = 标记「本周在这个 boss 用过币了」（一个 boss 一个 CD 只能 roll 一次）"), b.nRolled)
    end
    return s
end
local function stars(exp)
    local k = (exp >= 40 and 3) or (exp >= 20 and 2) or (exp > 0 and 1) or 0
    return string.rep("★", k) .. string.rep("|cFF555555★|r", 3 - k)
end
local function ensureFrame()
    if frame then return frame end
    local f = CreateFrame("Frame", "GearInsightRollFrame", UIParent, "BackdropTemplate")
    -- 700 宽放不下副标题 / 底部说明（09-24 Rainice 截图全是「…」）
    -- ⛔ 注释别再插进这一行中间：0.93.13 把 SetFrameStrata 一起注释掉，窗口掉回 MEDIUM 被别的界面压住（Rainice 二报）
    f:SetSize(880, 560); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG"); f:SetFrameLevel(30); f:SetToplevel(true); f:SetClampedToScreen(true)
    f:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize = 24, insets = { left = 6, right = 6, top = 6, bottom = 6 } })
    f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
    if GearInsight.RegisterEscClose then GearInsight:RegisterEscClose(f, "GearInsightRollFrame") end
    local x = CreateFrame("Button", nil, f, "UIPanelCloseButton"); x:SetPoint("TOPRIGHT", -2, -2)
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); f.title:SetPoint("TOPLEFT", PAD + 4, -14); f.title:SetJustifyH("LEFT")
    -- ⛔ 两行分开摆，别让副标题换行压住下面的难度按钮（用户截图 09-22）
    f.sub = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); f.sub:SetPoint("TOPLEFT", PAD + 4, -38); f.sub:SetPoint("RIGHT", -38, 0); f.sub:SetJustifyH("LEFT"); f.sub:SetWordWrap(false); f.sub:SetTextColor(0.62, 0.68, 0.80)
    f.sub2 = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); f.sub2:SetPoint("TOPLEFT", PAD + 4, -56); f.sub2:SetPoint("RIGHT", -38, 0); f.sub2:SetJustifyH("LEFT"); f.sub2:SetWordWrap(false); f.sub2:SetTextColor(0.80, 0.68, 0.40)
    -- 难度三段（自绘 tab：选中 = 亮底 + 金色下划线）
    f.diffBtns = {}
    local prev
    -- ⛔ 只留史诗/英雄：普通本没人拿币砸（用户 2026-09-22「不考虑普通级别」）。
    for i, d in ipairs({ { 16, T("RV_DIFF_M", "史诗") }, { 15, T("RV_DIFF_H", "英雄") } }) do
        local b = CreateFrame("Button", nil, f); b:SetSize(58, 22)
        if prev then b:SetPoint("LEFT", prev, "RIGHT", 3, 0) else b:SetPoint("TOPLEFT", PAD + 4, -80) end
        b.bg = b:CreateTexture(nil, "BACKGROUND"); b.bg:SetAllPoints()
        b.hl = b:CreateTexture(nil, "HIGHLIGHT"); b.hl:SetAllPoints(); b.hl:SetColorTexture(1, 1, 1, 0.07)
        b.sel = b:CreateTexture(nil, "ARTWORK"); b.sel:SetPoint("BOTTOMLEFT"); b.sel:SetPoint("BOTTOMRIGHT"); b.sel:SetHeight(2); b.sel:SetColorTexture(1, 0.82, 0.15); b.sel:Hide()
        b.txt = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); b.txt:SetPoint("CENTER"); b.txt:SetText(d[2])
        b:SetScript("OnClick", function() f._diff = d[1]; GearInsightDB = GearInsightDB or {}; GearInsightDB.rollDifficulty = d[1]; RV.Refresh() end)
        b._diff = d[1]; f.diffBtns[i] = b; prev = b
    end
    -- 大秘境页签（出货固定神话档、每次通关都能砸，与团本三档并列）
    do
        local b = CreateFrame("Button", nil, f); b:SetSize(72, 22)
        b:SetPoint("LEFT", prev, "RIGHT", 10, 0)
        b.bg = b:CreateTexture(nil, "BACKGROUND"); b.bg:SetAllPoints()
        b.hl = b:CreateTexture(nil, "HIGHLIGHT"); b.hl:SetAllPoints(); b.hl:SetColorTexture(1, 1, 1, 0.07)
        b.sel = b:CreateTexture(nil, "ARTWORK"); b.sel:SetPoint("BOTTOMLEFT"); b.sel:SetPoint("BOTTOMRIGHT"); b.sel:SetHeight(2); b.sel:SetColorTexture(1, 0.82, 0.15); b.sel:Hide()
        b.txt = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); b.txt:SetPoint("CENTER"); b.txt:SetText(T("RV_TAB_MPLUS2", "含大秘境"))
        b:SetScript("OnClick", function()
            GearInsightDB = GearInsightDB or {}
            GearInsightDB.rollNoMplus = not GearInsightDB.rollNoMplus
            RV.Refresh()
        end)
        b:SetScript("OnEnter", function(sb)
            GameTooltip:SetOwner(sb, "ANCHOR_BOTTOM")
            GameTooltip:SetText(T("RV_TAB_MPLUS_TIP", "把大秘境也算进来一起排 —— 币是通用的，该砸团本还是刷大米放一张榜上比。\n大秘境每次通关都能砸，没有周 CD。"), 1, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        f.mplusBtn = b; prev = b
    end
    local cb = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate"); cb:SetSize(20, 20); cb:SetPoint("LEFT", prev, "RIGHT", 14, 0)
    cb.text:SetText(T("RV_INCL_DONE", "已杀的也算")); cb.text:SetFontObject("GameFontHighlightSmall"); cb.text:SetTextColor(0.72, 0.76, 0.85)
    f._inclDone = GearInsightDB and GearInsightDB.rollIncludeDone or false
    cb:SetChecked(f._inclDone)
    cb:SetScript("OnClick", function(b) f._inclDone = b:GetChecked(); GearInsightDB = GearInsightDB or {}; GearInsightDB.rollIncludeDone = f._inclDone; RV.Refresh() end); f.inclDone = cb
    -- 参考价值过滤（用户 2026-09-22：「设置参考价值过滤」「主要看值得要以上的装备」）。
    -- ⛔ 点一下轮换一档，别开菜单 —— 面板顶栏已经很挤，再塞一个 UIDropDownMenu 必然又重叠。
    local mv = CreateFrame("Button", nil, f); mv:SetSize(124, 22)
    mv:SetPoint("LEFT", cb.text, "RIGHT", 16, 0)
    mv.bg = mv:CreateTexture(nil, "BACKGROUND"); mv.bg:SetAllPoints(); mv.bg:SetColorTexture(1, 1, 1, 0.05)
    mv.hl = mv:CreateTexture(nil, "HIGHLIGHT"); mv.hl:SetAllPoints(); mv.hl:SetColorTexture(1, 1, 1, 0.07)
    mv.txt = mv:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); mv.txt:SetPoint("CENTER"); mv.txt:SetTextColor(0.82, 0.74, 0.50)
    mv:SetScript("OnClick", function()
        local cur, nxt = RV.MinKey(), nil
        for i, v in ipairs(RV.MIN_LEVELS) do
            if v.key == cur then nxt = RV.MIN_LEVELS[i % #RV.MIN_LEVELS + 1].key end
        end
        RV.SetMinKey(nxt or "want"); RV.Refresh()
    end)
    mv:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_LEFT")
        GameTooltip:SetText(T("RV_MIN_TIP2", "多好才算「达标」。低于这一档的件不算进概率，也不参与排序。\n池子的分母不变 —— 变的只是「多少件算数」，所以门槛越高，概率越低、榜越短。\n点一下换下一档。"), 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    mv:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f.minBtn = mv
    local rs = CreateFrame("Button", nil, f, "UIPanelButtonTemplate"); rs:SetSize(64, 22); rs:SetPoint("TOPRIGHT", -36, -80); rs:SetText(T("RV_RESCAN", "重扫"))
    rs:SetScript("OnClick", function()
        _lootCache = {}; _dungCache = nil; _scannedSpec = {}
        f._loadTries = nil                                   -- 点重扫 = 重新给 10 次机会
        RV.ScanDungeons(true); RV.Refresh()
        -- 手册筛选换专精后要一点时间，0.5 秒后再扫一次，确保读到的是当前专精
        C_Timer.After(0.5, function() _lootCache = {}; _dungCache = nil; if frame and frame:IsShown() then RV.Refresh() end end)
    end)
    rs:SetScript("OnEnter", function(s) GameTooltip:SetOwner(s, "ANCHOR_LEFT"); GameTooltip:SetText(T("RV_RESCAN_TIP", "重新读地下城手册的掉落（换专精 / 换装备后用）"), 1, 1, 1, 1, true); GameTooltip:Show() end)
    rs:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local sep = f:CreateTexture(nil, "ARTWORK"); sep:SetPoint("TOPLEFT", PAD, -110); sep:SetPoint("TOPRIGHT", -PAD, -110); sep:SetHeight(1); sep:SetColorTexture(1, 1, 1, 0.10)
    local sf = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate"); sf:SetPoint("TOPLEFT", PAD, -118); sf:SetPoint("BOTTOMRIGHT", -34, 36)
    -- 用户 2026-09-24「roll 到过的话可以从池子的分母排除……给一个可以设置的地方」：功能早有（右键标记，跨周保留），
    -- 但只写在悬浮里没人找得到 → 面板底部常驻一行操作说明
    f.hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); f.hint:SetPoint("BOTTOMLEFT", PAD + 4, 14); f.hint:SetPoint("RIGHT", -PAD, 0)
    f.hint:SetJustifyH("LEFT"); f.hint:SetWordWrap(false); f.hint:SetTextColor(0.55, 0.78, 1.00)
    f.hint:SetText(T("RV_HINT_MARK", "右键装备 = 标记「用币 roll 到过」（出池，其余件概率上升，一直保留） · Shift+右键 = 不算在池子里 · 右键 boss = 本周已用币"))
    local c = CreateFrame("Frame", nil, sf); c:SetSize(640, 10); sf:SetScrollChild(c); f.content = c; f.scroll = sf
    -- 能拖大 + 跟随 GI 面板缩放（09-24 玩家 Rainice：4K、0.53 UI 缩放、GI 设了 125%，这个窗口没跟着放大，副标题 / 底部说明被截成「…」）
    f:SetResizable(true)
    if f.SetResizeBounds then f:SetResizeBounds(700, 420, 1600, 1200) elseif f.SetMinResize then f:SetMinResize(700, 420) end
    local saved = GearInsightDB and GearInsightDB.rollFrameSize
    if saved and saved[1] and saved[2] then f:SetSize(math.max(700, saved[1]), math.max(420, saved[2])) end
    sf:SetScript("OnSizeChanged", function(self, w) if w and w > 0 then c:SetWidth(math.max(640, w)) end end)
    local grip = CreateFrame("Button", nil, f); grip:SetSize(16, 16); grip:SetPoint("BOTTOMRIGHT", -6, 6)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:SetScript("OnMouseDown", function() f:StartSizing("BOTTOMRIGHT") end)
    grip:SetScript("OnMouseUp", function()
        f:StopMovingOrSizing()
        GearInsightDB = GearInsightDB or {}; GearInsightDB.rollFrameSize = { math.floor(f:GetWidth() + 0.5), math.floor(f:GetHeight() + 0.5) }
    end)
    f.rows = {}
    f.note = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); f.note:SetPoint("TOPLEFT", PAD + 4, -130); f.note:SetPoint("RIGHT", -PAD, 0); f.note:SetJustifyH("LEFT"); f.note:SetSpacing(4); f.note:SetTextColor(0.75, 0.78, 0.85)
    -- ⛔ CreateFrame 出来的框默认是**显示**状态，而 ShowRollPlan 是「开着就关」的切换语义
    --    → 第一次点按钮会被当成「关」，什么都不出现，要点两次（用户 2026-09-22 报）。
    f:Hide()
    frame = f
    return f
end
-- 行：[图标] 名字 | 部位(装等) | 装等±N | 判词 | 概率 | 标记
local function row(f, i)
    local r = f.rows[i]
    if r then return r end
    r = CreateFrame("Button", nil, f.content); r:SetHeight(ROW_H); r:SetPoint("LEFT", 0, 0); r:SetPoint("RIGHT", 0, 0)
    r.zebra = r:CreateTexture(nil, "BACKGROUND"); r.zebra:SetAllPoints(); r.zebra:SetColorTexture(1, 1, 1, 0.03); r.zebra:Hide()
    r.rule = r:CreateTexture(nil, "BACKGROUND"); r.rule:SetPoint("BOTTOMLEFT", 2, 0); r.rule:SetPoint("BOTTOMRIGHT", -2, 0); r.rule:SetHeight(1); r.rule:SetColorTexture(1, 1, 1, 0.09); r.rule:Hide()
    r.icon = r:CreateTexture(nil, "ARTWORK"); r.icon:SetSize(18, 18); r.icon:SetPoint("LEFT", 16, 0); r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); r.name:SetWidth(W_NAME); r.name:SetJustifyH("LEFT"); r.name:SetWordWrap(false)
    r.slot = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); r.slot:SetPoint("LEFT", r.name, "RIGHT", 6, 0); r.slot:SetWidth(W_SLOT); r.slot:SetJustifyH("LEFT"); r.slot:SetWordWrap(false); r.slot:SetTextColor(0.60, 0.64, 0.72)
    r.gain = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); r.gain:SetPoint("LEFT", r.slot, "RIGHT", 6, 0); r.gain:SetWidth(W_GAIN); r.gain:SetJustifyH("LEFT"); r.gain:SetWordWrap(false)
    r.verd = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); r.verd:SetPoint("LEFT", r.gain, "RIGHT", 6, 0); r.verd:SetWidth(W_VERD); r.verd:SetJustifyH("LEFT"); r.verd:SetWordWrap(false)
    r.prob = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); r.prob:SetPoint("LEFT", r.verd, "RIGHT", 6, 0); r.prob:SetWidth(W_PROB); r.prob:SetJustifyH("RIGHT"); r.prob:SetWordWrap(false); r.prob:SetTextColor(0.56, 0.60, 0.68)
    r.tag = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); r.tag:SetPoint("LEFT", r.prob, "RIGHT", 8, 0); r.tag:SetPoint("RIGHT", -4, 0); r.tag:SetJustifyH("LEFT"); r.tag:SetWordWrap(false)
    r.hl = r:CreateTexture(nil, "HIGHLIGHT"); r.hl:SetAllPoints(); r.hl:SetColorTexture(1, 1, 1, 0.06)
    r:SetScript("OnEnter", function(b)
        if b._item then GameTooltip:SetOwner(b, "ANCHOR_RIGHT"); if b._item.link then GameTooltip:SetHyperlink(b._item.link) else GameTooltip:SetItemByID(b._item.id) end
            GameTooltip:AddLine(" ")
            for _, rs in ipairs(b._item.reasons or {}) do GameTooltip:AddLine("· " .. rs, 0.8, 0.8, 0.8, true) end
            GameTooltip:AddLine(string.format(T("RV_TT_SCORE", "综合得分 %d（装等差 × 部位权重 + BiS/套装/轨道）"), b._item.score or 0), 0.55, 0.6, 0.7, true)
            if b._item.dropIlvl and (b._boss or b._item.dropIlvl ~= b._item.ilvl) then
                -- ⛔ 大米和团本两套口径，别共用一句话（用户 2026-09-22「应该是神话级别，这些显示不对」）：
                --    团本 = roll 币固定出**高一档**；大米 10 层以上 = 直接出**神话档**，不是「高一档」。
                GameTooltip:AddLine(string.format(b._item.mythIlvl
                    and T("RV_TT_COIN_MYTH3", "上面那个装等(%d)是这个本直接掉的；roll 币 10 层以上出神话档，纹章升满是 %d，已按 %d 打分。\n（地下城手册给不出神话档的物品链接，所以上面的 tooltip 只能显示本档装等）")
                    or T("RV_TT_COIN_VAULT", "本难度直接掉落 %d；用币与宝库同装等：%d，升满比较按 %d。\n上方是手册原始物品链接，可能与用币奖励的装等不同。"),
                    b._item.dropIlvl, b._item.ilvl or 0, b._item.scoreIlvl or b._item.ilvl or 0), 0.55, 0.6, 0.7, true)
                if b._item.coinGuess then GameTooltip:AddLine(T("RV_TT_COIN_GUESS", "⚠ 这件的币档装等是按同团本的档差推算的（手册还没给出真实值），点「重扫」可刷新"), 0.85, 0.7, 0.35, true) end
            end
            if b._boss then GameTooltip:AddLine(b._item.rolled and T("RV_TT_ROLLED", "已用币 roll 到过 → 已从这个 boss 的 roll 币池子移除。右键取消标记。")
                or T("RV_TT_NOTROLLED2", "右键标记「我用币 roll 到过这件」→ 出池，剩下件的概率上升。\n（正常打本拾取到不算出池，还能再 roll 到）"), 0.55, 0.6, 0.7, true) end
            GameTooltip:Show()
        elseif b._tip then GameTooltip:SetOwner(b, "ANCHOR_RIGHT"); GameTooltip:SetText(b._tip, 1, 1, 1, 1, true); GameTooltip:Show() end
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    r:SetScript("OnClick", function(b, btn)
        if btn == "RightButton" and b._bossRow and not b._item then
            -- boss 行右键 = 标记 / 取消「本周在这个 boss 上用过币了」
            local used = RV.CoinedSet and RV.CoinedSet()
            RV.MarkCoined(b._bossRow, not (used and used[b._bossRow]))
            RV.Refresh()
            return
        end
        if btn == "RightButton" and b._item and b._boss and IsShiftKeyDown() then
            -- Shift+右键 = 「这件不算在池子里」/ 恢复
            RV.MarkExcluded(b._boss, b._item.id, not b._item.excluded)
            RV.Refresh()
            return
        end
        if btn == "RightButton" and b._item and b._boss then
            -- 右键 = 标记 / 取消「这件我用币 roll 到过」（池子少一件，其余件概率上升）
            RV.MarkRolled(b._boss, b._item.id, not b._item.rolled, b._diff)
            RV.Refresh()
            return
        end
        if b._item and b._item.link and IsModifiedClick("CHATLINK") then ChatEdit_InsertLink(b._item.link) end
    end)
    f.rows[i] = r
    return r
end
local function pct(p) return string.format("%.0f%%", (p or 0) * 100) end
-- 榜单行「最想要：…」列窄，长名字被截成「…」（用户 2026-09-30 截图）→ 悬浮把来源、概率、全部达标装备完整列出来
local function poolTip(title, p, nU, nE, items)
    local out = { title, string.format(T("RV_TT_POOL_P", "一枚币中 %s · 达标 %d / 池子 %d 件"), pct(p), nU or 0, nE or 0) }
    local MIN = minScore()
    local got = {}
    for _, it in ipairs(items or {}) do
        if (it.pRoll or 0) > 0 and (it.score or 0) >= MIN then
            local _, col, label = verdictOf(it.score or 0)
            got[#got + 1] = string.format("· %s  %s+%d %s|r", it.name or "?", col or "", it.score or 0, label or "")
        end
    end
    if #got > 0 then
        out[#out + 1] = " "
        out[#out + 1] = T("RV_TT_POOL_ITEMS", "达标装备（按分数从高到低）：")
        for _, l in ipairs(got) do out[#out + 1] = l end
    end
    return table.concat(out, "\n")
end

-- 「还在载入」有限次重试（10-03 玩家等了半天一直「1 秒后自动重试」）：
--   第 5 次起整套重扫（清缓存 + 重新载入手册），第 10 次停下，说清楚手册里读到了什么，让玩家发 /gi roll debug
local function loadingRetry(f, page)
    f._loadTries = (f._loadTries or 0) + 1
    if f._loadTries == 5 then _lootCache = {}; _dungCache = nil end
    if f._loadTries >= 10 then
        local d = RV._scanDiag or {}
        f.note:SetText(string.format(T("RV_LOAD_STUCK", "读不到地下城手册的掉落（%s · 难度 %s · 手册共 %d 件 · 你这个专精能用 %d 件）。\n点右上「重扫」再试；还不行请打 /gi roll debug，把聊天框里的结果截图发给我们。"),
            tostring(d.inst or "?"), tostring(d.diff or "?"), d.total or 0, d.got or 0))
        return
    end
    C_Timer.After(1, function() if f:IsShown() then RV.Refresh() end end)
end

function RV.Refresh()
    local f = ensureFrame()
    f._diff = f._diff or (GearInsightDB and GearInsightDB.rollDifficulty) or 16
    if f._diff ~= 16 and f._diff ~= 15 then f._diff = 16 end
    for _, b in ipairs(f.diffBtns) do
        local on = (b._diff == f._diff)
        b.sel:SetShown(on)
        if on then b.bg:SetColorTexture(0.22, 0.19, 0.10, 0.95); b.txt:SetTextColor(1, 0.82, 0.15)
        else b.bg:SetColorTexture(0.11, 0.12, 0.16, 0.9); b.txt:SetTextColor(0.72, 0.76, 0.82) end
    end
    if f.mplusBtn then
        local on = not (GearInsightDB and GearInsightDB.rollNoMplus)
        f.mplusBtn.sel:SetShown(on)
        f.mplusBtn.bg:SetColorTexture(on and 0.22 or 0.11, on and 0.19 or 0.12, on and 0.10 or 0.16, on and 0.95 or 0.9)
        f.mplusBtn.txt:SetTextColor(on and 1 or 0.72, on and 0.82 or 0.76, on and 0.15 or 0.82)
    end
    -- 过滤档位按钮的字跟着当前档走（大秘境页也走这里，所以放在分叉之前）
    if f.minBtn then f.minBtn.txt:SetText(T("RV_MIN_PREFIX", "只看：") .. RV.MinLabel()) end
    for _, r in ipairs(f.rows) do r:Hide() end
    local withMp = not (GearInsightDB and GearInsightDB.rollNoMplus)
    local summary, why = RV.EvaluateRoll(f._diff, { includeDone = f._inclDone, includeMplus = withMp })
    local res = summary and summary.raid
    local nCoin = RV.CoinCount()
    if nCoin and nCoin > 0 then
        f.title:SetText(string.format(T("RV_TITLE3", "Roll 币怎么花 · 你身上 %d 枚，砸哪 %d 个 boss"), nCoin, nCoin))
    else
        f.title:SetText(T("RV_TITLE_ZERO", "Roll 币怎么花 · 你身上 0 枚 · 假设拿一枚币这样用"))
    end
    if not res then
        f.note:Show(); f.scroll:Hide()
        f.note:SetText(why == "loading" and T("RV_LOADING", "地下城手册的掉落还在载入，1 秒后自动重试…")
            or why == "ejopen" and T("RV_EJ_OPEN", "先关掉地下城手册再看（扫描要借用它的筛选状态）")
            or why == "noinst" and T("RV_NO_INST", "找不到本赛季团本（BisData 没加载好？打 /gi roll debug 看手册里有什么）")
            or T("RV_NO_API", "这个客户端没有地下城手册接口"))
        f.sub:SetText(""); f.sub2:SetText(""); f:SetHeight(230)
        if why == "loading" then loadingRetry(f) end
        return
    end
    f._loadTries = nil
    f.note:Hide(); f.scroll:Show()
    local DIFF_CN = { [16] = T("RV_DIFF_M", "史诗"), [15] = T("RV_DIFF_H", "英雄"), [14] = T("RV_DIFF_N", "普通"), [17] = T("RV_DIFF_L", "随机") }
    f.sub:SetText(string.format(T("RV_SUB4", "%s · %s难度 · %d 枚币全砸下去，约 %s 中一件有用的（其中 %s 是真提升）"),
        res.inst.name or "?", DIFF_CN[res.diff] or DIFF_NAME[res.diff] or "", RV.CoinK(), pct(summary.pAnyUseful), pct(summary.pAnyGood)))
    f.sub2:SetText(res.diff == 15 and T("RV_COIN_H_VAULT", "英雄用币：神话 1/6 · 318 装等；评分按升满 334 比较")
        or res.diff == 16 and T("RV_COIN_M_VAULT", "史诗用币：普通件 334；非常稀有及末两首领 344（与宝库一致）")
        or (res.coinDiff and res.coinDiff ~= res.diff)
        and string.format(T("RV_COIN_UP2", "roll 币固定出高一档：%s本用币出%s档 —— 下面的装等和分数已按%s档算"), DIFF_CN[res.diff] or "", DIFF_CN[res.coinDiff] or "", DIFF_CN[res.coinDiff] or "")
        or T("RV_COIN_TOP", "史诗已封顶，用币还是史诗档"))
    local y, n = 0, 0
    local function line(o)
        n = n + 1; local r = row(f, n); r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, -y); r:SetPoint("RIGHT", 0, 0)
        r.name:ClearAllPoints(); r.name:SetPoint("LEFT", o.icon and 38 or (o.indent or 14), 0)
        r.name:SetWidth(o.wide and (W_NAME + W_SLOT + 6) or W_NAME)
        r.name:SetText(o.name or ""); r.slot:SetText(o.wide and "" or (o.slot or ""))
        r.gain:SetText(o.gain or ""); r.verd:SetText(o.verd or ""); r.prob:SetText(o.prob or ""); r.tag:SetText(o.tag or "")
        r._item, r._tip, r._boss, r._bossRow, r._diff = o.item, o.tip, o.boss, o.bossRow, o.diff
        if o.icon then r.icon:SetTexture(o.icon); r.icon:Show() else r.icon:Hide() end
        r.zebra:SetShown(o.zebra or false); r.rule:SetShown(o.rule or false)
        r:Show(); y = y + ROW_H + (o.gap or 0)
    end
    -- ① 合并榜：团本 boss + 大秘境本，一起按「一枚币中」排
    local mp, pool = summary.mp, summary.pool
    line({ name = "|cFFFFD100" .. T("RV_TOP_ALL", "这枚币砸哪里") .. "|r", wide = true, rule = true,
        verd = "|cFF888888" .. T("RV_COL_P", "一枚币中") .. "|r", prob = "|cFF888888" .. T("RV_COL_POOL", "达标/池子") .. "|r",
        tip = T("RV_TOP_TIP", "「一枚币中」= 在这里砸一枚币，中一件达标装备的概率。榜按它从高到低排。\n一枚币必出一件，所以概率 = 达标件数 ÷ 池子件数。达标的门槛由上面「只看」那个按钮定。\n不进榜的：本周已杀的 boss、本 CD 已经用过币的 boss、概率为 0 的。\n大秘境没有周 CD，每次通关都能砸，所以一直在榜上。\n插件只给建议，不会自动帮你用币。") })
    local SRC_RAID = T("RV_SRC_RAID", "团本")
    local SRC_MP = T("RV_SRC_MP", "大米")
    for i, e in ipairs(pool) do
        local badge = (i <= 3) and (({ "①", "②", "③" })[i] .. " ") or "   "
        local src = (e.kind == "raid")
            and string.format("|cFF9999CC[%s]|r %s", SRC_RAID, bossTag(res.diff, e.ord))
            or string.format("|cFF66CC99[%s]|r", SRC_MP)
        line({ name = string.format("|cFFFFD100%s|r%s %s", badge, src, e.name or "?"), wide = true, indent = 18,
            gain = stars(e.exp),
            verd = string.format("|cFFFFD100%s|r", pct(e.p)),
            prob = string.format("|cFF888888%d/%d|r", e.nU, e.nE),
            tag = e.best and string.format("|cFF9FD0FF%s %s|r", T("RV_BEST", "最想要："), e.best.name or "") or "",
            tip = poolTip((e.kind == "raid" and (bossTag(res.diff, e.ord) .. " ") or "") .. (e.name or "?"), e.p, e.nU, e.nE, e.items) })
    end
    if #pool == 0 then
        line({ name = "|cFF999999" .. T("RV_NONE_HINT", "本周没有值得砸币的 boss（都杀过了 / 都没提升）—— 勾上「已杀的也算」看全部") .. "|r", wide = true, indent = 22 })
    end
    y = y + 10
    -- ② 团本逐 boss
    line({ name = "|cFF99CCFF" .. string.format(T("RV_SEC_RAID", "团本 · %s（%s难度）"), res.inst.name or "?", (DIFF_CN and DIFF_CN[res.diff]) or "") .. "|r", wide = true, rule = true })
    for _, b in ipairs(res.bosses) do
        line({ name = bossTag(res.diff, b.ord) .. " " .. ((b.coined or b.done) and "|cFF777777" or "|cFF99CCFF") .. b.name .. "|r", wide = true, rule = true,
            gain = stars(b.expected), prob = pct(b.pUseful),
            verd = string.format("|cFF888888%d/%d|r", b.nUseful, b.nEligible),
            tipExtra = true,
            tag = (b.coined and ("|cFFCC8844" .. T("RV_COINED", "[本周已用币]") .. "|r"))
                or (b.done and ("|cFF777777" .. T("RV_DONE", "[本周已杀]") .. "|r")) or "",
            bossRow = b.id,
            tip = bossTip(b) })
        local z = 0
        for _, it in ipairs(b.items) do
            local col, vtxt = RV.VerdictInfo(it.verdict)
            -- 用户 2026-09-24「直接标记已ROLL到过醒目点，不要出池」：roll 到过的件不再灰掉写「已出池」，
            -- 高亮成「已ROLL到」（概率照旧按出池算 —— 这件不会再 roll 到，分母里本来就没有它）
            local out = it.owned or it.excluded or it.noIlvl
            if it.rolled then col, vtxt = "|cFF33FFCC", T("RV_ROLLED2", "已ROLL到")
            elseif out then col, vtxt = "|cFF777777", it.owned and T("RV_OWNED", "已拥有")
                or it.excluded and T("RV_EXCLUDED", "已排除")
                or T("RV_NOILVL", "装等未知") end
            local d = it.delta or 0
            local gain = it.noIlvl and ("|cFF777777" .. T("RV_ILVL_NA", "装等 ?") .. "|r")
                or d > 0 and string.format("|cFF66CC66%s +%d|r", T("RV_ILVL", "装等"), d)
                or (d == 0 and ("|cFF999999" .. T("RV_SAME", "同装等") .. "|r") or string.format("|cFF888888%s %d|r", T("RV_ILVL", "装等"), d))
            z = z + 1
            line({ icon = it.icon, item = it, zebra = (z % 2 == 0),
                -- roll 到过：名字置灰，右侧「已ROLL到」高亮（用户 2026-09-24「前面的装备名字置灰」）
                name = ((out or it.rolled) and "|cFF777777" or "") .. (it.name or tostring(it.id)) .. ((out or it.rolled) and "|r" or ""),
                boss = b.id, diff = res.diff,     -- 「已 roll 到」按难度存（10-03）
                slot = string.format("%s (%d)", slotName(it.slot or it.slots[1]), it.ilvl or 0),
                gain = gain, verd = col .. vtxt .. "|r", prob = pct(it.pRoll),
                tag = it.rolled and ("|cFF33FFCC" .. T("RV_ROLLED_TAG", "[已ROLL到 · 右键取消]") .. "|r")
                    or it.farmable and ("|cFF66CC66" .. T("RV_FARM2", "[大米也能刷]") .. "|r") or "" })
        end
        y = y + 6
    end
    -- ③ 大秘境明细（合并模式下接在团本后面）
    if mp then
        y = y + 8
        line({ name = "|cFF66CC99" .. T("RV_SEC_MP", "大秘境 · 每次通关都能砸，没有周 CD") .. "|r", wide = true, rule = true })
        for _, d in ipairs(mp.dungeons or {}) do
            line({ name = "|cFF99CCFF" .. (d.name or "?") .. "|r", wide = true, rule = true,
                gain = stars(d.expected),
                verd = string.format("|cFFFFD100%s|r", pct(d.pUseful)),
                prob = string.format("|cFF888888%d/%d|r", d.nUseful, d.nEligible) })
            local zz = 0
            for _, it in ipairs(d.items or {}) do
                local col2, vtxt2 = RV.VerdictInfo(it.verdict)
                local o2 = it.owned or it.excluded or it.noIlvl
                if it.rolled then col2, vtxt2 = "|cFF33FFCC", T("RV_ROLLED2", "已ROLL到")
                elseif o2 then col2, vtxt2 = "|cFF777777", it.owned and T("RV_OWNED", "已拥有")
                    or it.excluded and T("RV_EXCLUDED", "已排除") or T("RV_NOILVL", "装等未知") end
                local dl = it.delta or 0
                local g2 = it.noIlvl and ("|cFF777777" .. T("RV_ILVL_NA", "装等 ?") .. "|r")
                    or dl > 0 and string.format("|cFF66CC66%s +%d|r", T("RV_ILVL", "装等"), dl)
                    or (dl == 0 and ("|cFF999999" .. T("RV_SAME", "同装等") .. "|r") or string.format("|cFF888888%s %d|r", T("RV_ILVL", "装等"), dl))
                zz = zz + 1
                line({ icon = it.icon, item = it, boss = d.id, zebra = (zz % 2 == 0),
                    name = ((o2 or it.rolled) and "|cFF777777" or "") .. (it.name or tostring(it.id)) .. ((o2 or it.rolled) and "|r" or ""),
                    -- ⛔ 这一列就给币档一个数：→ 在游戏字体里是方块，两个数也挤（用户 2026-09-22）。
                    --    「本档直接掉多少」放 tooltip 里讲。
                    slot = string.format("%s (%d)", slotName(it.slot or it.slots[1]), it.ilvl or 0),
                    gain = g2, verd = col2 .. vtxt2 .. "|r", prob = pct(it.pRoll),
                    tag = it.rolled and ("|cFF33FFCC" .. T("RV_ROLLED_TAG", "[已ROLL到 · 右键取消]") .. "|r") or "" })
            end
            y = y + 6
        end
    end
    f.content:SetHeight(y + 10)
    f:SetHeight(math.min(640, math.max(250, 118 + y + 18)))
    -- 还有件没读出装等 → 数据是异步到的，2 秒后自己重扫一次，别让玩家看见「装等未知」不动
    local pending = res.specWarmup or false
    for _, b in ipairs(res.bosses) do for _, it in ipairs(b.items) do if it.noIlvl then pending = true break end end end
    if pending and not f._retried then
        f._retried = true
        C_Timer.After(2, function() _lootCache = {}; if f:IsShown() then f._retried = nil; RV.Refresh() end end)
    end
end

-- 大秘境页：没有「三选」，只排「最值得刷哪个本」——每次通关都能砸币
function RV.RefreshMplus(f)
    for _, r in ipairs(f.rows) do r:Hide() end
    local res, why = RV.EvaluateMplus()
    f.title:SetText(T("RV_TITLE_MP", "Roll 币怎么花 · 大秘境刷哪个本"))
    if not res then
        f.note:Show(); f.scroll:Hide()
        f.note:SetText(why == "loading" and T("RV_LOADING", "地下城手册的掉落还在载入，1 秒后自动重试…")
            or why == "ejopen" and T("RV_EJ_OPEN", "先关掉地下城手册再看（扫描要借用它的筛选状态）")
            or T("RV_NO_DUNG", "找不到本赛季大秘境（BisData 没加载好？）"))
        f.sub:SetText(""); f.sub2:SetText(""); f:SetHeight(230)
        if why == "loading" then loadingRetry(f) end
        return
    end
    f._loadTries = nil
    f.note:Hide(); f.scroll:Show()
    f.sub:SetText(T("RV_SUB_MP", "本赛季大秘境 · 按「这个本的掉落对你平均有多大提升」排序"))
    f.sub2:SetText(T("RV_MP_RULE", "10 层以上用币出神话档 · 每次通关都能砸，没有周 CD —— 所以挑本，不挑周"))
    local y, n = 0, 0
    local function line(o)
        n = n + 1; local r = row(f, n); r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, -y); r:SetPoint("RIGHT", 0, 0)
        r.name:ClearAllPoints(); r.name:SetPoint("LEFT", o.icon and 38 or (o.indent or 14), 0)
        r.name:SetWidth(o.wide and (W_NAME + W_SLOT + 6) or W_NAME)
        r.name:SetText(o.name or ""); r.slot:SetText(o.wide and "" or (o.slot or ""))
        r.gain:SetText(o.gain or ""); r.verd:SetText(o.verd or ""); r.prob:SetText(o.prob or ""); r.tag:SetText(o.tag or "")
        r._item, r._tip, r._boss, r._bossRow, r._diff = o.item, o.tip, o.boss, nil, nil
        if o.icon then r.icon:SetTexture(o.icon); r.icon:Show() else r.icon:Hide() end
        r.zebra:SetShown(o.zebra or false); r.rule:SetShown(o.rule or false)
        r:Show(); y = y + ROW_H + (o.gap or 0)
    end
    line({ name = "|cFFFFD100" .. T("RV_MP_TOP", "优先刷这几个本") .. "|r", wide = true, rule = true,
        verd = "|cFF888888" .. T("RV_COL_P", "一枚币中") .. "|r", prob = "|cFF888888" .. T("RV_COL_POOL", "达标/池子") .. "|r",
        tip = T("RV_MP_TIP2", "大秘境用币出神话档，而且每次通关都能砸 —— 所以这里排的是「刷哪个本最值」，不是「本周砸哪三个 boss」。\n一枚币必出一件，中某一件 = 1 ÷ 该 boss 能用的件数。") })
    for i, d in ipairs(res.top) do
        line({ name = string.format("|cFFFFD100%s|r %s", ({ "①", "②", "③", "④", "⑤", "⑥", "⑦", "⑧", "⑨", "⑩" })[i] or (tostring(i) .. "."), d.name or "?"), wide = true, indent = 22,
            gain = stars(d.expected),
            verd = string.format("|cFFFFD100%s|r", pct(d.pUseful)),
            prob = string.format("%d/%d", d.nUseful, d.nEligible),
            tag = d.best and string.format("|cFF9FD0FF%s %s|r", T("RV_BEST", "最想要："), d.best.name or "") or "",
            tip = poolTip(d.name or "?", d.pUseful, d.nUseful, d.nEligible, d.items) })
    end
    if #res.top == 0 then line({ name = "|cFF999999" .. T("RV_MP_NONE", "本赛季大秘境没有能给你提升的掉落了") .. "|r", wide = true, indent = 22 }) end
    y = y + 10
    for _, d in ipairs(res.dungeons) do
        line({ name = "|cFF99CCFF" .. (d.name or "?") .. "|r", wide = true, rule = true,
            gain = stars(d.expected),
            verd = string.format("|cFFFFD100%s|r", pct(d.pUseful)),
            prob = string.format("|cFF888888%d/%d|r", d.nUseful, d.nEligible),
            tip = string.format(T("RV_MP_DUNG_TIP", "整个本算一个池子（不分 boss）：能用 %d 件 · 其中 %d 件有提升 · %d 件值得要\n一枚币必出其中一件 → 中有用件 = %d/%d = %s\n（身上已有的、手动排除的、装等读不出来的都不占分母）"),
                d.nEligible, d.nUseful, d.nGood, d.nUseful, d.nEligible, d.nEligible > 0 and string.format("%.0f%%", d.nUseful / d.nEligible * 100) or "-") })
        local z = 0
        for _, it in ipairs(d.items) do
            local col, vtxt = RV.VerdictInfo(it.verdict)
            local out2 = it.owned or it.excluded or it.noIlvl
            if it.rolled then col, vtxt = "|cFF33FFCC", T("RV_ROLLED2", "已ROLL到")
            elseif out2 then col, vtxt = "|cFF777777", it.owned and T("RV_OWNED", "已拥有")
                or it.excluded and T("RV_EXCLUDED", "已排除") or T("RV_NOILVL", "装等未知") end
            local dlt = it.delta or 0
            local gain = it.noIlvl and ("|cFF777777" .. T("RV_ILVL_NA", "装等 ?") .. "|r")
                or dlt > 0 and string.format("|cFF66CC66%s +%d|r", T("RV_ILVL", "装等"), dlt)
                or (dlt == 0 and ("|cFF999999" .. T("RV_SAME", "同装等") .. "|r") or string.format("|cFF888888%s %d|r", T("RV_ILVL", "装等"), dlt))
            z = z + 1
            line({ icon = it.icon, item = it, boss = d.id, zebra = (z % 2 == 0),
                name = ((out2 or it.rolled) and "|cFF777777" or "") .. (it.name or tostring(it.id)) .. ((out2 or it.rolled) and "|r" or ""),
                slot = string.format("%s (%d)", slotName(it.slot or it.slots[1]), it.ilvl or 0),
                gain = gain, verd = col .. vtxt .. "|r", prob = pct(it.pRoll),
                tag = it.rolled and ("|cFF33FFCC" .. T("RV_ROLLED_TAG", "[已ROLL到 · 右键取消]") .. "|r") or "" })
        end
        y = y + 6
    end
    f.content:SetHeight(y + 10)
    f:SetHeight(math.min(640, math.max(250, 118 + y + 18)))
end

function GearInsight:ShowRollPlan()
    local f = ensureFrame()
    if f:IsShown() then f:Hide(); return end
    f:SetScale((GearInsightDB and GearInsightDB.panelScale) or 1.0)   -- 跟主面板同一个缩放
    -- 人在英雄 / 史诗团本里打开 → 先切到当前难度（10-02：在 H 本里打开却显示上次选的 M 标签的已杀），不改存档里的默认
    local _, itype, diffID = GetInstanceInfo()
    if itype == "raid" and (diffID == 15 or diffID == 16) then f._diff = diffID end
    f:Show(); f:Raise(); RV.Refresh()
end

-- ── 团本进度记录 + Roll 币价值（宝库「装备 vs Roll 币」）─────────────────
-- ⛔⛔ 用户 2026-09-24（玩家 salty：「加一条判断，能不能打h78」）→「在于 ROLL 币的权重，能打的话 ROLL 币权重
--   可以根据是否值得 ROLL 的系数提高」。原来宝库只看「最佳装备 ≥15 分？」，Roll 币本身值多少没进比较。
--   ① 进度：玩家在宝库面板手动选「打不了 H / 能打 H1-6 / 能打 H1-8」（RV.RaidPlan，默认 H1-6）。
--   ② 币值 = 你打得到的 boss（序号 ≤ 已打到的最远 boss、本周没砸过）里「一枚币的期望分」最高那个，
--      × 系数：能打 H7/8（或有 M 进度）×1.25，打不到后面 ×0.8。
--   ③ 币值 ≥15 且高于最佳装备 → 推荐 Roll 币；否则照旧。
local COIN_W_LATE, COIN_W_EARLY, LATE_ORD = 1.25, 0.8, 7
-- ⛔ 用户 2026-09-24「ROLL币现在只有低保这里可以选，其他没有地方可以选，所有ROLL币的价值是不是可以系数提高？」
--   Roll 币只能从宝库拿、一周最多一枚 → 稀缺，所有币值再 ×1.3（能打 H7/8 合计 ×1.63，打不到 ×1.04）
local COIN_SCARCITY = 1.3
-- 「Roll 币 N 分：砸 X，必 roll a/b 件（概率 P%），最好「Y」+S，期望 +E × f」（网站 advice 逐字同款）
function RV.CoinLine(cv)
    local where = cv.kind == "mp" and (T("RV_VAULT_COIN_MP", "大秘境·") .. (cv.boss or "?"))
        or ((cv.diff == 16 and "M" or "H") .. (cv.bossOrd or 0) .. " " .. (cv.boss or "?"))
    return string.format(T("RV_VAULT_COIN_LINE3", "Roll 币 %d 分：砸 %s，必 roll %d/%d 件（概率 %.1f%%），最好「%s」+%d，期望 %+.1f × %.2f"),
        cv.score, where, cv.nMust or 0, cv.n or 0, (cv.p or 0) * 100, cv.bestName or "?", cv.bestScore or 0, cv.exp or 0, cv.factor or 1)
end
-- 团本进度（用户 2026-09-24「能不能打H团也可以制约下，如果能打H团1-6就算1-6的史诗」）：
--   → 「打不了H，能打1-6，能打1-8」：手动三档 GearInsightDB.rollRaidProg = "none" / "h6" / "h8"（nil = 默认 h6）。
--   「H难度BOSS都是神话装备」：H 本用 Roll 币、开低保都出神话轨装备（币出高一档），所以「H1-6」= 前 6 个 boss 的神话轨掉落；
--   序号超出进度的 boss 不算。（「自动」档 = 击杀记录，用户说不需要，已删。）
-- 返回 diff（15/16/nil=不算团本）, far（能打到第几个）, canLate, 显示文字
-- 用户 2026-09-24「这个选项拿掉」「不需要」：去掉「自动（击杀记录）」，只留手动三档，默认「能打 H1-6」
local PLAN_ORDER = { "none", "h6", "h8" }
function RV.RaidPlan()
    local o = GearInsightDB and GearInsightDB.rollRaidProg or "h6"
    local diff, far, label
    if o == "none" then label = T("RV_PLAN_NONE2", "打不了 H")
    elseif o == "h8" then diff, far, label = 15, 99, T("RV_PLAN_H8B", "能打 H1-8")
    else diff, far, label = 15, LATE_ORD - 1, T("RV_PLAN_H6B", "能打 H1-6") end
    local canLate = diff and (diff == 16 or far >= LATE_ORD) or false
    return diff, far, canLate, label, o ~= nil
end
function RV.CycleRaidPlan()
    GearInsightDB = GearInsightDB or {}
    local cur = GearInsightDB.rollRaidProg or "h6"
    local idx = 1
    for i, v in ipairs(PLAN_ORDER) do if v == cur then idx = i end end
    GearInsightDB.rollRaidProg = PLAN_ORDER[idx % #PLAN_ORDER + 1]
end
function RV.CoinValue()
    local diff, far, canLate = RV.RaidPlan()
    local vctx = RV.VaultCtx()
    local myth = T("RV_TRACK_MYTH", "神话")
    local list = {}
    local function consider(kind, name, ord, items, nE, factor)
        if not items or (nE or 0) <= 0 then return end
        -- 只看 /gi roll 面板里判「必 roll」的件（用户 2026-09-24「概率只看必roll物品出的概率吧」）；
        -- 这几件再用宝库尺子打分，和宝库装备同尺比较
        local sum, best, bestS, nMust = 0, nil, 0, 0
        for _, it0 in ipairs(items) do
            if (it0.pRoll or 0) > 0 and it0.verdict == "must" then
                nMust = nMust + 1
                local it = {}; for k, v in pairs(it0) do it[k] = v end
                it.trackName, it.scoreIlvl, it.diff = myth, it0.ilvl, nil
                local sc = RV.ScoreItem(it, vctx) or 0
                if sc > 0 then sum = sum + sc end
                if not best or sc > bestS then best, bestS = it0, sc end
            end
        end
        if not best then return end
        local exp = sum / nE
        -- bestLink = 币档那份链接（团本已换成高一档；用户 2026-09-24 截图：按 itemID 显示成了 219 基础件）
        list[#list + 1] = { kind = kind, boss = name, bossOrd = ord, bestName = best.name, bestId = best.id, bestLink = best.link,
            bestScore = bestS, p = nMust / nE, n = nE, nMust = nMust, good = true, exp = exp, factor = factor,
            score = math.floor(exp * factor + 0.5) }
    end
    if diff then
        local ok, res = pcall(RV.Evaluate, diff)
        if ok and res and res.bosses and not res.pending then
            local f = (canLate and COIN_W_LATE or COIN_W_EARLY) * COIN_SCARCITY
            for _, bo in ipairs(res.bosses) do
                if (bo.ord or 99) <= far and not bo.done and not bo.coined then
                    consider("raid", bo.name, bo.ord, bo.items, bo.nEligible, f)
                end
            end
        end
    end
    if not (GearInsightDB and GearInsightDB.rollNoMplus) and RV.EvaluateMplus then
        local ok, mp = pcall(RV.EvaluateMplus)
        if ok and mp and mp.dungeons and not mp.pending then
            for _, d in ipairs(mp.dungeons) do consider("mp", d.name, 0, d.items, d.nEligible, COIN_SCARCITY) end
        end
    end
    table.sort(list, function(x, y) return x.score > y.score end)
    local top = list[1]
    if not top then return nil end
    top.diff, top.ord, top.canLate = diff or 16, (far and far < 99) and far or 0, canLate
    return top
end

-- 进本 / 开怪提示（一次登录每个难度只报一次；开怪命中三选就提醒）
local _promptedDiff, _lastTop, _lastEncounterId = {}, nil, nil
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD"); ev:RegisterEvent("ENCOUNTER_START"); ev:RegisterEvent("CHAT_MSG_LOOT"); ev:RegisterEvent("ADDON_LOADED")
pcall(ev.RegisterEvent, ev, "PLAYER_SPECIALIZATION_CHANGED")
pcall(ev.RegisterEvent, ev, "BONUS_ROLL_RESULT")   -- 没有这个事件的客户端就静默跳过
pcall(ev.RegisterEvent, ev, "EJ_LOOT_DATA_RECIEVED") -- 暴雪事件名称保留 RECIEVED 拼写。
ev:SetScript("OnEvent", function(_, event, a1, a2, a3)
    if event == "EJ_LOOT_DATA_RECIEVED" then
        -- 异步到齐后丢弃含旧稀有标记/旧链接的缓存；已有 pending 重试及下次刷新重新读手册。
        _lootCache = {}; _dungCache = nil; _lastTop = nil
        return
    end
    if event == "PLAYER_SPECIALIZATION_CHANGED" then
        if a1 and a1 ~= "player" then return end
        _lootCache = {}; _dungCache = nil; _lastTop = nil
        C_Timer.After(1, function()
            if frame and frame:IsShown() then RV.Refresh() end
            if WeeklyRewardsFrame and WeeklyRewardsFrame:IsShown() then RV.RefreshVault() end
        end)
        return
    end
    if event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(6, function()
            local _, itype, diffID = GetInstanceInfo()
            if itype ~= "raid" or not DIFF_NAME[diffID] or _promptedDiff[diffID] then return end
            if GearInsightDB and GearInsightDB.rollPrompt == false then return end
            local res = RV.Evaluate(diffID)
            if not res then return end
            _promptedDiff[diffID] = true; _lastTop = res
            local parts = {}
            for i, b in ipairs(res.top3) do parts[#parts + 1] = string.format("%s%s%d %s(%s)", ({ "①", "②", "③" })[i], DIFF_NAME[res.diff] or "", b.ord or 0, b.name, pct(b.pUseful)) end
            if #parts > 0 then GearInsight:Print(string.format(T("RV_ENTER2", "本周 roll 币砸：%s · %d 币至少中一件有用 %s · /gi roll 看明细"), table.concat(parts, " "), RV.CoinK(), pct(res.pAnyUseful)))
            else GearInsight:Print(T("RV_ENTER_NONE", "这本这个难度没有值得用 roll 币的 boss（/gi roll 看明细）")) end
        end)
    elseif event == "ENCOUNTER_START" then
        local encId, name, diffID = a1, a2, a3
        -- ⛔ 10-02 玩家「读取已经击杀的情况没有区分 H 和 M」：以前直接复用 _lastTop，不看它是哪个难度算的
        --    （同一次登录先 H 后 M、或进本提示关着），M 的首领战拿 H 的「已杀 / 三选」→ 只认同难度的缓存。
        local res = (_lastTop and _lastTop.diff == diffID and _lastTop) or (DIFF_NAME[diffID] and RV.Evaluate(diffID))
        if not res then return end
        for _, b in ipairs(res.bosses) do
            if b.dId == encId or b.name == name then _lastEncounterId = b.id end
        end
        for i, b in ipairs(res.top3) do
            if b.dId == encId or b.name == name then
                GearInsight:Print(string.format(T("RV_USE_COIN", "|cFFFFD100★ %s 是本周三选第 %d：这个 boss 用 roll 币|r（中有用件 %s）"), name, i, pct(b.pUseful)))
            end
        end
    elseif event == "CHAT_MSG_LOOT" then
        -- ⛔ 正常拾取**不**从 roll 币池子移除（ChromaticaX 2026-09-22）。这里只把缓存置脏，
        --    让下次刷新按新装备重算分数；池子本身不动。
        local msg, player = a1, a2
        local me = UnitName("player")
        if player and me and (player == me or player:match("^" .. me .. "%-")) then
            if msg and msg:match("item:(%d+)") then _lastTop = nil end
        end
    elseif event == "BONUS_ROLL_RESULT" then
        -- 有这个事件就自动记（12.1 是否仍触发待确认，没有就走面板右键手动标记）
        local encId = _lastEncounterId
        local id = a1 and tonumber(tostring(a1):match("item:(%d+)"))
        -- roll 到的是兑换物 → 记到本职业对应的套装件上（池子里用的是套装件 id）
        if id and RV.TokenPiece then
            local _, cls = UnitClass("player")
            local pieceId = RV.TokenPiece(id, cls)
            if pieceId then id = pieceId end
        end
        if encId and id then
            local _, _, diffID = GetInstanceInfo()
            RV.MarkRolled(encId, id, true, (diffID == 15 or diffID == 16) and diffID or nil)
            RV.MarkCoined(encId, true)      -- 这个 boss 本 CD 的机会用掉了
            GearInsight:Print(string.format(T("RV_ROLLED_AUTO", "已记下：这件用币 roll 到了，已从该 boss 的 roll 币池子移除（/gi roll 里右键可取消）")))
        end
    elseif event == "ADDON_LOADED" and a1 == "Blizzard_WeeklyRewards" then
        RV.HookVault()
    end
end)

-- ── 低保（每周宝库）：开箱界面 → 本地打分 + 导出串 ────────────────────
-- 导出串 GIV1.<b64>.<校验>，payload：1|class|specId|charName|realm|region|<type>:<itemID>:<ilvl>:<b1.b2>:<level>:<threshold>;…|<slot>:<item>:<ilvl>,…（身上装备）
-- GIV1 uses legacy wire types (1 raid, 2 dungeons, 3 world, 6 PvP).
-- Game activity enums are separate: never serialize their raw values as wire types.
local VT = Enum and Enum.WeeklyRewardChestThresholdType or {}
local V_RAID, V_DUNGEON, V_WORLD, V_PVP = VT.Raid or 3, VT.Activities or VT.MythicPlus or 1, VT.World or 6, VT.RankedPvP or 2
local V_WIRE = { [V_RAID] = 1, [V_DUNGEON] = 2, [V_WORLD] = 3, [V_PVP] = 6 }
local function vaultTypes()
    return { [V_RAID] = T("RV_VT_RAID", "团本"), [V_DUNGEON] = T("RV_VT_DUNGEONS", "地下城"),
        [V_WORLD] = T("RV_VT_WORLD_ROW", "世界"), [V_PVP] = T("RV_VT_PVP", "PvP") }
end
local function hasVaultReward(a)
    local itemType = Enum and Enum.CachedRewardType and Enum.CachedRewardType.Item or 1
    for _, r in ipairs(a.rewards or {}) do
        if r.type == itemType and r.itemDBID then return true end
    end
    return false
end
function RV.VaultRows(activities, claiming)
    local rows = {}
    for _, a in ipairs(activities) do
        if V_WIRE[a.type] then
            local row = rows[a.type] or { done = 0, total = 0 }
            rows[a.type] = row
            row.total = row.total + 1
            local unlocked = hasVaultReward(a)
            if not claiming then unlocked = (a.threshold or 0) > 0 and (a.progress or 0) >= a.threshold end
            if unlocked then row.done = row.done + 1
            elseif not claiming and (a.threshold or 0) > 0 then
                local need = math.max(0, a.threshold - (a.progress or 0))
                row.need = math.min(row.need or need, need)
            end
        end
    end
    return rows
end
-- item:ID:ench:gem1:gem2:gem3:gem4:suffix:unique:level:spec:mods:ctx:numBonus:b1:b2… → { b1, b2, … }
local function linkBonusIDs(link)
    local body = link and link:match("item:([%-%d:]+)")
    if not body then return {} end
    local f = {}
    for v in (body .. ":"):gmatch("([^:]*):") do f[#f + 1] = v end
    local n, out = tonumber(f[13]) or 0, {}
    for i = 1, n do if f[13 + i] and f[13 + i] ~= "" then out[#out + 1] = f[13 + i] end end
    return out
end
function RV.VaultCandidates(activities)
    if not (C_WeeklyRewards and C_WeeklyRewards.GetActivities) then return {} end
    local getReal = C_WeeklyRewards.GetItemHyperlink              -- 真实奖励（已解锁的格）
    local out, seenCand, pending = {}, {}, false
    local function add(link, a, unlocked)
        if not link then return end
        local itemId, _, _, _, _, classID = C_Item.GetItemInfoInstant(link)
        if not itemId then pending = true; return end
        -- ⛔ 只放行武器(2)/护甲(4)：宝库里还会混进史诗钥石、货币之类（用户 2026-09-22 截图「史诗钥石 (1)」）
        if classID ~= 2 and classID ~= 4 then return end
        if isCosmetic(itemId) then return end
        local ilvl = C_Item.GetDetailedItemLevelInfo and C_Item.GetDetailedItemLevelInfo(link) or 0
        if (ilvl or 0) <= 1 then
            pending = true
            if C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(itemId) end
            return
        end
        local invType, equipLoc, itemClassID, itemSubclassID = itemMetadata(link, itemId)
        if not (invType and INV2SLOT[invType]) then return end
        local name, _, quality, _, _, _, _, _, _, icon = C_Item.GetItemInfo(link)
        -- 同一件常常在多个档位重复出现：按 itemId+装等去重，来源档位合并进 sources
        local k = itemId .. ":" .. tostring(ilvl)
        local prev = seenCand[k]
        if prev then
            prev.sources[#prev.sources + 1] = { atype = a.type, level = a.level, threshold = a.threshold }
            if unlocked then prev.unlocked = true end
            return
        end
        local trackCur, trackMax, trackName = linkTrack(link)
        local scoreIlvl = maxedIlvl(ilvl, trackCur, trackMax)
        local c = { id = itemId, link = link, name = name or ("item:" .. itemId), icon = icon, quality = quality,
            ilvl = ilvl, bonus = linkBonusIDs(link), slots = invType and INV2SLOT[invType] or nil,
            inventoryType = invType, equipLoc = equipLoc, itemClassID = itemClassID, itemSubclassID = itemSubclassID,
            scoreIlvl = scoreIlvl, trackCur = trackCur, trackMax = trackMax, trackName = trackName,
            atype = a.type, level = a.level, threshold = a.threshold, index = a.index, unlocked = unlocked and true or false,
            sources = { { atype = a.type, level = a.level, threshold = a.threshold } } }
        seenCand[k] = c
        out[#out + 1] = c
    end
    for _, a in ipairs(activities or C_WeeklyRewards.GetActivities() or {}) do
        -- Actual reward records survive weekly progress reset. Preview items are never choices.
        if V_WIRE[a.type] and getReal and hasVaultReward(a) then
            local itemType = Enum and Enum.CachedRewardType and Enum.CachedRewardType.Item or 1
            for _, r in ipairs(a.rewards or {}) do
                if r.type == itemType and r.itemDBID then
                    local ok, link = pcall(getReal, r.itemDBID)
                    if ok and link then add(link, a, true) else pending = true end
                end
            end
        end
    end
    -- 已解锁的排前面（那才是真能拿走的）
    table.sort(out, function(x, y)
        if x.unlocked ~= y.unlocked then return x.unlocked end
        return (x.ilvl or 0) > (y.ilvl or 0)
    end)
    return out, pending
end
-- One evaluation supplies both the in-game panel and the exported web result.
-- 宝库打分上下文（宝库候选和 Roll 币池子共用同一把尺子）
function RV.VaultCtx(eq, setCount)
    if not eq then eq, setCount = equipped() end
    local bis, data, st = bisIndex()
    local key = data and data.className and data.specName and (data.className .. "/" .. data.specName .. "/" .. (data.heroTalent or ""))
    local ctx = { eq = eq, setCount = setCount or 0, bis = bis, mplus = mplusCeil(data, key), baseline = baselineIlvl(eq), noOffhand = offhandDisabled(), vault = true }
    -- 本职业其它专精的 BiS 名次（itemId → rank），同一英雄天赋口径取不到就用 GetClassSpecs 挑的那份
    local bd = GearInsight.BisData
    if st and bd and bd.GetClassSpecs then
        ctx.otherBis = {}
        for _, o in ipairs(bd:GetClassSpecs(st.class) or {}) do
            local sd = bd.specs and bd.specs[o.key]
            if sd and sd.bisBySlot and not (data and o.specName == data.specName) then
                local idx = {}
                for _, cands in pairs(sd.bisBySlot) do
                    for i, e in ipairs(cands or {}) do
                        if e.itemId and (not idx[e.itemId] or idx[e.itemId] > i) then idx[e.itemId] = i end
                    end
                end
                local label = o.specName
                if o.specId and GetSpecializationInfoByID then
                    local ok, _, nm = pcall(GetSpecializationInfoByID, o.specId)
                    if ok and nm and nm ~= "" then label = nm end
                end
                ctx.otherBis[#ctx.otherBis + 1] = { idx = idx, label = label }
            end
        end
    end
    local TH = GearInsight.TooltipHook
    if st and TH and TH.FillerRankByStats then
        -- 身上那件套装当初是用哪件坯子转的（按副属性反推；本体 = 本体在横评里的名次）
        ctx.wornFiller = function(e)
            if not (e and e.link and e.id) then return nil end
            local ok, r = pcall(TH.FillerRankByStats, TH, e.link, e.id, { class = st.class, spec = st.spec, hero = st.heroTalent })
            return ok and r or nil
        end
    end
    if st and TH and TH.FillerHit then
        -- 与悬浮「转换优先级 #i/n」同一个缓存；noScan，不去动地下城手册
        ctx.filler = function(id)
            local ok, hit = pcall(TH.FillerHit, TH, id, st.class, st.spec, st.heroTalent)
            return ok and hit or nil
        end
    end
    return ctx, data, st
end
function RV.EvaluateVault(cands, eq, setCount)
    if not eq then eq, setCount = equipped() end
    local ctx, data = RV.VaultCtx(eq, setCount)
    local order = {}
    for i, c in ipairs(cands) do
        order[c] = i
        c.score, c.verdict, c.reasons = RV.ScoreItem(c, ctx)
        c.vaultVerdict = vaultVerdictOf(c.score)
    end
    table.sort(cands, function(a, b)
        if a.score ~= b.score then return a.score > b.score end
        return order[a] < order[b]
    end)
    -- hero = 打分用的那份 BiS 的英雄天赋（英文 key，与网站 item_index 的 heroTalent 同一套），网站按它取排名
    local mode = cands[1] and cands[1].score >= 15 and "item" or "coin"
    local okC, coinV = pcall(RV.CoinValue)
    coinV = okC and coinV or nil
    if coinV and coinV.score >= 15 and coinV.score > (cands[1] and cands[1].score or 0) then mode = "coin" end
    return { rows = cands, mode = mode, hero = data and data.heroTalent or nil, coinValue = coinV }
end
function RV.BuildRollSnapshot()
    local db = GearInsightDB or {}
    local diff = (frame and frame._diff) or db.rollDifficulty or 16
    if diff ~= 15 and diff ~= 16 then diff = 16 end
    local includeDone = frame and frame._inclDone or db.rollIncludeDone or false
    local coin = { status = "pending", probabilityUnit = "percent", difficulty = diff,
        difficultyLabel = diff == 15 and T("RV_DIFF_H", "英雄") or T("RV_DIFF_M", "史诗"),
        coinDifficulty = coinDifficultyFor(diff), minKey = RV.MinKey(), minScore = minScore(),
        includeDone = includeDone and true or false, includeMplus = not db.rollNoMplus,
        reason = "", bosses = {}, top3 = {}, pAnyUseful = 0, pAnyGood = 0 }
    local ok, summary, why = pcall(RV.EvaluateRoll, diff, { includeDone = coin.includeDone, includeMplus = coin.includeMplus, fresh = true })
    if not ok then why = "loading"; summary = nil end
    if not summary or summary.pending then
        why = why or (summary and summary.pendingReason) or "loading"
        coin._retryable = why == "loading"
        coin.reason = why == "ejopen" and T("RV_ROLL_EXPORT_CLOSE_EJ", "请先关闭地下城手册，再点击导出以读取 Roll 币评估。")
            or why == "noinst" and T("RV_ROLL_EXPORT_NO_RAID", "未找到当前赛季团本，请更新插件数据后重新导出。")
            or why == "noapi" and T("RV_ROLL_EXPORT_NO_API", "Roll 币掉落接口尚不可用，请打开 /gi roll 后重新导出。")
            or T("RV_ROLL_EXPORT_LOADING", "Roll 币掉落数据仍在载入，请稍后重新导出。")
        return coin
    end
    local function percent(value) return math.floor((value or 0) * 1000000 + 0.5) / 10000 end
    for i = 1, math.min(3, #summary.pool) do
        local entry = summary.pool[i]
        coin.bosses[i] = { kind = entry.kind, name = entry.name or "?", encounterId = entry.encounterId,
            journalEncounterId = entry.journalEncounterId, dungeonId = entry.dungeonId,
            bossTag = entry.kind == "mp" and "M+" or ((DIFF_NAME[diff] or "") .. (entry.ord or 0)),
            pUseful = percent(entry.p), pGood = percent(entry.pGood), expected = entry.exp,
            nEligible = entry.nE, nUseful = entry.nU, nGood = entry.nGood }
        coin.top3[i] = entry.name or "?"
    end
    coin.status = "ready"; coin.coinDifficulty = summary.raid.coinDiff or coin.coinDifficulty
    coin.pAnyUseful, coin.pAnyGood = percent(summary.pAnyUseful), percent(summary.pAnyGood)
    return coin
end
local function jsonQuote(value)
    local text = tostring(value or ""):gsub('[%z\1-\31\\"]', function(char)
        if char == '"' then return '\\"' end
        if char == '\\' then return '\\\\' end
        return string.format('\\u%04x', string.byte(char))
    end)
    return '"' .. text .. '"'
end
local function rollSnapshotJSON(coin)
    local bosses, names = {}, {}
    for _, entry in ipairs(coin.bosses) do
        bosses[#bosses + 1] = string.format('{"kind":%s,"name":%s,"encounterId":%d,"journalEncounterId":%d,"dungeonId":%d,"bossTag":%s,"pUseful":%.4f,"pGood":%.4f,"expected":%.4f,"nEligible":%d,"nUseful":%d,"nGood":%d}',
            jsonQuote(entry.kind), jsonQuote(entry.name), entry.encounterId, entry.journalEncounterId, entry.dungeonId, jsonQuote(entry.bossTag),
            entry.pUseful, entry.pGood, entry.expected, entry.nEligible, entry.nUseful, entry.nGood)
    end
    for _, name in ipairs(coin.top3) do names[#names + 1] = jsonQuote(name) end
    return string.format('{"status":%s,"probabilityUnit":"percent","difficulty":%d,"difficultyLabel":%s,"coinDifficulty":%d,"minKey":%s,"minScore":%d,"includeDone":%s,"includeMplus":%s,"reason":%s,"bosses":[%s],"top3":[%s],"pAnyUseful":%.4f,"pAnyGood":%.4f}',
        jsonQuote(coin.status), coin.difficulty, jsonQuote(coin.difficultyLabel), coin.coinDifficulty, jsonQuote(coin.minKey), coin.minScore,
        tostring(coin.includeDone), tostring(coin.includeMplus), jsonQuote(coin.reason), table.concat(bosses, ','), table.concat(names, ','), coin.pAnyUseful, coin.pAnyGood)
end
local function vaultEvaluationJSON(evaluation, coin)
    local rows = {}
    for _, c in ipairs(evaluation.rows) do
        local reasons = {}
        for _, reason in ipairs(c.reasons or {}) do reasons[#reasons + 1] = jsonQuote(reason) end
        -- rv3 展示字段（三端同一套标签）：bisRank = 本专精 BiS 前 3 名次；
        -- filler = 套装部位坯子 {idx,total 转换优先级, tierRank 催化后套装名次, tierName}
        local extra = ""
        if c.bisRank then extra = extra .. string.format(',"bisRank":%d', c.bisRank) end
        local f = type(c.filler) == "table" and c.filler or nil
        if f and f.tierRank then
            extra = extra .. string.format(',"filler":{"idx":%d,"total":%d,"tierRank":%d,"tierName":%s}',
                f.idx or 0, f.total or 0, f.tierRank, jsonQuote(f.tierName or ""))
        end
        rows[#rows + 1] = string.format('{"id":%d,"ilvl":%d,"type":%d,"threshold":%d,"score":%d,"slot":%d,"verdict":%s,"reasons":[%s]%s}',
            c.id, c.ilvl or 0, V_WIRE[c.atype] or 0, c.threshold or 0, c.score, c.slot or 0,
            jsonQuote(c.vaultVerdict), table.concat(reasons, ','), extra)
    end
    return '{"version":"rv3","mode":' .. jsonQuote(evaluation.mode)
        .. (evaluation.hero and (',"hero":' .. jsonQuote(evaluation.hero)) or '')
        .. ',"raidPlan":' .. jsonQuote((GearInsightDB and GearInsightDB.rollRaidProg) or "h6")
        .. (evaluation.coinValue and string.format(',"coinValue":{"score":%d,"diff":%d,"ord":%d,"canLate":%s,"factor":%.2f,"boss":%s,"exp":%.1f,"kind":%s,"bossOrd":%d,"bestName":%s,"bestScore":%d,"p":%.4f,"good":%s,"nMust":%d,"n":%d}',
            evaluation.coinValue.score, evaluation.coinValue.diff, evaluation.coinValue.ord, evaluation.coinValue.canLate and "true" or "false",
            evaluation.coinValue.factor, jsonQuote(evaluation.coinValue.boss), evaluation.coinValue.exp or 0,
            jsonQuote(evaluation.coinValue.kind or "raid"), evaluation.coinValue.bossOrd or 0, jsonQuote(evaluation.coinValue.bestName or ""),
            evaluation.coinValue.bestScore or 0, evaluation.coinValue.p or 0, evaluation.coinValue.good and "true" or "false",
            evaluation.coinValue.nMust or 0, evaluation.coinValue.n or 0) or '')
        .. ',"rows":[' .. table.concat(rows, ',') .. '],"coin":' .. rollSnapshotJSON(coin) .. '}'
end
-- ⛔ 字符类写死 ASCII，别用 %w：%w 走 C 库 isalnum，随系统区域设置变，
--    在 cp1252 这类区域下 0xE5 等高位字节也算「字母」→ 汉字首字节不编码，导出串里混进坏字节。
local function pctEncode(v)
    return (tostring(v or ""):gsub("([^A-Za-z0-9%-_%.~])", function(char) return string.format("%%%02X", string.byte(char)) end))
end
function RV.BuildVaultExport(cands)
    local snap = GearInsight.SavedVars and GearInsight.SavedVars:Save()
    if not snap then return nil end
    local eq, setCount = equipped()
    local evaluation = RV.EvaluateVault(cands, eq, setCount)
    -- 候选：多带一个「轨道升满装等」——服务端读不到物品轨道，只能靠我们送（2026-09-22 口径）
    local parts = {}
    for _, c in ipairs(cands) do
        local tc, tm, tn = linkTrack(c.link)
        local mx = maxedIlvl(c.ilvl or 0, tc, tm)
        local invType, equipLoc, classID, subClassID = itemMetadata(c.link, c.id)
        -- 字段 12-14 = 升级轨道 当前档:总档:轨道名(百分号编码)，与装备段同口径
        -- （用户 2026-09-24：网站候选悬浮「升级进度：未导入」，要带上「神话 1/6」）
        parts[#parts + 1] = string.format("%d:%d:%d:%s:%d:%d:%d:%d:%s:%d:%d:%d:%d:%s",
            V_WIRE[c.atype] or 0, c.id, c.ilvl or 0, table.concat(c.bonus or {}, "."), c.level or 0, c.threshold or 0, mx,
            invType, equipLoc, classID, subClassID, tc or 0, tm or 0, pctEncode(tn))
    end
    -- GIV1 equipment: slot:id:worn:max:bonusIDs:trackRank:trackMax:trackName
    -- followed by inventoryType:equipLoc:classID:subClassID (also candidate fields 8-11).
    -- Keep the original four fields; optional metadata describes the real item,
    -- never an item-ID-only template. Percent-encode the localized track name.
    local eqp = {}
    for slotId, slot in pairs(snap.equipped or {}) do
        if type(slot) == "table" and slot.itemId and not slot.empty then
            local sid = slot.slotId or slotId
            local e = eq[sid]
            local live = e and e.id and e.link
            local link = live and e.link or slot.itemLink
            local itemId = live and e.id or slot.itemId
            local worn = live and e.wornIlvl or slot.ilvl or 0
            local tc, tm, tn
            if live then tc, tm, tn = e.trackCur, e.trackMax, e.track
            elseif link then tc, tm, tn = linkTrack(link) end
            local mx = maxedIlvl(worn, tc, tm)
            local trackName = pctEncode(tn)
            local invType, equipLoc, classID, subClassID = itemMetadata(link, itemId)
            eqp[#eqp + 1] = string.format("%d:%d:%d:%d:%s:%d:%d:%s:%d:%s:%d:%d", sid, itemId, worn, mx,
                table.concat(linkBonusIDs(link), "."), tc or 0, tm or 0, trackName, invType, equipLoc, classID, subClassID)
        end
    end
    table.sort(eqp)
    local regionMap = { "US", "KR", "EU", "TW", "CN" }
    local payload = table.concat({ "1", snap.class or "", snap.specId or 0, UnitName("player") or "",
        (GetNormalizedRealmName and GetNormalizedRealmName()) or "",
        regionMap[(GetCurrentRegion and GetCurrentRegion()) or 0] or "",
        table.concat(parts, ";"), table.concat(eqp, ","), tostring(setCount or 0) }, "|")
    if not (GearInsight._b64encode and GearInsight._checksum) then return nil end
    local coin = #cands > 0 and RV.BuildRollSnapshot() or nil
    payload = payload .. "|" .. (#cands > 0 and GearInsight._b64encode(vaultEvaluationJSON(evaluation, coin)) or "")
    -- The second API return is worn average, including the game's two-hand weighting.
    local wornAverage = ""
    if GetAverageItemLevel then
        local ok, _, value = pcall(GetAverageItemLevel)
        if ok and type(value) == "number" and value > 0 and value < math.huge then wornAverage = tostring(value) end
    end
    payload = payload .. "|" .. wornAverage
    local b = GearInsight._b64encode(payload)
    if #b > 32000 then error("宝库导出数据过长，请减少候选后重试") end
    return "GIV1." .. b .. "." .. GearInsight._checksum(b), coin
end
local vaultPanel
function RV.HookVault()
    if not (WeeklyRewardsFrame and not WeeklyRewardsFrame._giHooked) then return end
    WeeklyRewardsFrame._giHooked = true
    WeeklyRewardsFrame:HookScript("OnShow", function() C_Timer.After(0.5, RV.RefreshVault) end)
    WeeklyRewardsFrame:HookScript("OnHide", function() RV._vaultForce = nil; if vaultPanel then vaultPanel:Hide() end end)
    local updates = CreateFrame("Frame")
    updates:RegisterEvent("WEEKLY_REWARDS_UPDATE")
    updates:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    local queued = false
    updates:SetScript("OnEvent", function()
        if queued or not WeeklyRewardsFrame:IsShown() then return end
        queued = true
        C_Timer.After(0.2, function() queued = false; RV.RefreshVault() end)
    end)
    WeeklyRewardsFrame._giVaultUpdates = updates
    if WeeklyRewardsFrame:IsShown() then C_Timer.After(0.5, RV.RefreshVault) end
end
local VAULT_ROW_H = 46
local VAULT_SOURCE_COLOR = {
    [V_RAID] = { 1.00, 0.55, 0.18 }, [V_DUNGEON] = { 0.35, 0.75, 1.00 },
    [V_WORLD] = { 0.35, 0.90, 0.48 }, [V_PVP] = { 1.00, 0.35, 0.35 },
}
local function vaultSource(c, typeNames)
    local names, seen = {}, {}
    for _, sc in ipairs(c.sources or { { atype = c.atype } }) do
        local name = typeNames[sc.atype] or "?"
        if not seen[name] then seen[name] = true; names[#names + 1] = name end
    end
    return table.concat(names, "/")
end
-- The thresholded concession is the Voidcore option; the zero-threshold
-- concession is the separate Tokens of Merit bundle. Read its real texture.
function RV.VaultCoinReward(activities)
    local rewardTypes = Enum and Enum.CachedRewardType or {}
    for _, activity in ipairs(activities or {}) do
        if activity.type == (VT.Concession or 5) and (activity.threshold or 0) > 0 then
            local rewards = {}
            for _, reward in ipairs(activity.rewards or {}) do rewards[#rewards + 1] = reward end
            table.sort(rewards, function(a, b)
                if a.type ~= b.type then return a.type == (rewardTypes.Item or 1) end
                return (a.quantity or 0) > (b.quantity or 0)
            end)
            for _, reward in ipairs(rewards) do
                local icon
                if reward.type == (rewardTypes.Item or 1) and not (C_Item.IsItemKeystoneByID and C_Item.IsItemKeystoneByID(reward.id)) then
                    icon = select(5, C_Item.GetItemInfoInstant(reward.id))
                elseif reward.type == (rewardTypes.Currency or 2) and C_CurrencyInfo then
                    local currency = C_CurrencyInfo.GetCurrencyInfo(reward.id)
                    icon = currency and currency.iconFileID
                end
                if icon then return {id = reward.id, type = reward.type, itemDBID = reward.itemDBID, icon = icon} end
            end
        end
    end
end
local function vaultItemRow(p, index)
    local r = p.itemRows[index]
    if r then return r end
    r = CreateFrame("Button", nil, p, "BackdropTemplate")
    r:SetHeight(VAULT_ROW_H)
    r:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    r:SetBackdropColor(0.035, 0.045, 0.065, 0.92); r:SetBackdropBorderColor(0.18, 0.22, 0.30, 0.9)
    r.accent = r:CreateTexture(nil, "ARTWORK"); r.accent:SetPoint("TOPLEFT", 0, -1); r.accent:SetPoint("BOTTOMLEFT", 0, 1); r.accent:SetWidth(3)
    r.icon = r:CreateTexture(nil, "ARTWORK"); r.icon:SetSize(34, 34); r.icon:SetPoint("LEFT", 8, 0); r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    r.source = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); r.source:SetPoint("TOPLEFT", 50, -7); r.source:SetWidth(55); r.source:SetJustifyH("LEFT"); r.source:SetWordWrap(false)
    r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); r.name:SetPoint("TOPLEFT", 108, -7); r.name:SetWidth(205); r.name:SetJustifyH("LEFT"); r.name:SetWordWrap(false)
    r.ilvl = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); r.ilvl:SetPoint("BOTTOMLEFT", 108, 7); r.ilvl:SetPoint("BOTTOMRIGHT", -96, 7); r.ilvl:SetJustifyH("LEFT"); r.ilvl:SetWordWrap(false); r.ilvl:SetTextColor(0.58, 0.64, 0.73)
    r.score = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); r.score:SetPoint("TOPRIGHT", -10, -7); r.score:SetWidth(82); r.score:SetJustifyH("RIGHT")
    r.verdict = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); r.verdict:SetPoint("BOTTOMRIGHT", -10, 7); r.verdict:SetWidth(82); r.verdict:SetJustifyH("RIGHT")
    r.hl = r:CreateTexture(nil, "HIGHLIGHT"); r.hl:SetAllPoints(); r.hl:SetColorTexture(1, 0.82, 0.18, 0.08)
    r:SetScript("OnEnter", function(b)
        local c = b._item
        if not c then return end
        GameTooltip:SetOwner(b, "ANCHOR_LEFT")
        if c.link then GameTooltip:SetHyperlink(c.link) elseif c.id then GameTooltip:SetItemByID(c.id) else GameTooltip:SetText(c.name or "?") end
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine(T("RV_VAULT_TT_SOURCE", "宝库来源"), b._source or "?", 0.65, 0.70, 0.80, 1, 0.82, 0.20)
        GameTooltip:AddDoubleLine(T("RV_VAULT_TT_SCORE", "GearInsight 评分"), string.format("%+d", c.score or 0), 0.65, 0.70, 0.80, 1, 1, 1)
        for _, reason in ipairs(c.reasons or {}) do GameTooltip:AddLine("· " .. reason, 0.76, 0.80, 0.88, true) end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(T("RV_VAULT_TT_CHAT", "Shift+点击发送到聊天"), 0.35, 0.75, 1.00)
        GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    r:RegisterForClicks("LeftButtonUp")
    r:SetScript("OnClick", function(b)
        if b._item and b._item.link and IsModifiedClick("CHATLINK") then ChatEdit_InsertLink(b._item.link) end
    end)
    p.itemRows[index] = r
    return r
end

function RV.VaultExportURL(export)
    local region = GetCurrentRegion and GetCurrentRegion()
    local domestic = region == 5 or (not region and _LOCALE == "zhCN")
    return "https://" .. (domestic and "gearinsight.cn" or "gearinsight.app") .. "/wow/vault#v=" .. export
end

function RV.RefreshVault()
    if not (WeeklyRewardsFrame and WeeklyRewardsFrame:IsShown()) then return end
    -- 可关（09-23 玩家 Elvis J：「打开宏伟宝库，有个求助微信好友的弹窗」要能关）：
    --   GearInsightDB.vaultPanelOff = 不自动出现；/gi vault 仍可在本次开箱时手动叫出（_vaultForce，关宝库清掉）
    if GearInsightDB and GearInsightDB.vaultPanelOff and not RV._vaultForce then
        if vaultPanel then vaultPanel:Hide() end
        return
    end
    if not vaultPanel then
        local p = CreateFrame("Frame", "GearInsightVaultPanel", WeeklyRewardsFrame, "BackdropTemplate")
        p:SetSize(430, 300); p:SetMovable(true); p:SetClampedToScreen(true)
        local savedPos = GearInsightDB and GearInsightDB.vaultPanelPos
        if savedPos and savedPos.left and savedPos.top then
            p:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", savedPos.left, savedPos.top)
        else
            p:SetPoint("TOPLEFT", WeeklyRewardsFrame, "TOPRIGHT", 6, 0)
        end
        p:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize = 20, insets = { left = 5, right = 5, top = 5, bottom = 5 } })
        p:SetBackdropColor(0.015, 0.020, 0.030, 0.97)
        p.header = p:CreateTexture(nil, "BACKGROUND"); p.header:SetPoint("TOPLEFT", 7, -7); p.header:SetPoint("TOPRIGHT", -7, -7); p.header:SetHeight(31); p.header:SetColorTexture(0.08, 0.10, 0.15, 0.95)
        p.title = p:CreateFontString(nil, "OVERLAY", "GameFontNormal"); p.title:SetPoint("TOPLEFT", 16, -14); p.title:SetText(T("RV_VAULT_TITLE", "GearInsight · 低保怎么选")); p.title:SetTextColor(1, 0.82, 0.10)
        p.drag = CreateFrame("Button", nil, p); p.drag:SetPoint("TOPLEFT", 7, -7); p.drag:SetPoint("TOPRIGHT", -7, -7); p.drag:SetHeight(31); p.drag._vaultDrag = true
        p.drag:RegisterForDrag("LeftButton")
        p.drag:SetScript("OnDragStart", function() p:StartMoving() end)
        p.drag:SetScript("OnDragStop", function()
            p:StopMovingOrSizing()
            local left, top = p:GetLeft(), p:GetTop()
            if left and top then
                p:ClearAllPoints(); p:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
                GearInsightDB = GearInsightDB or {}; GearInsightDB.vaultPanelPos = { left = left, top = top }
            end
        end)
        -- 右上角：✕ = 本次关闭；「不再弹出」= 以后开宝库不自动出现（设置页 / /gi vault on 可恢复）
        p.close = CreateFrame("Button", nil, p, "UIPanelCloseButton"); p.close:SetSize(24, 24); p.close:SetPoint("TOPRIGHT", -8, -8)
        p.close:SetFrameLevel((p.drag:GetFrameLevel() or 1) + 2)
        p.close:SetScript("OnClick", function() RV._vaultForce = nil; p:Hide() end)
        p.never = CreateFrame("Button", nil, p); p.never:SetSize(70, 20); p.never:SetPoint("RIGHT", p.close, "LEFT", -2, 0)
        p.never:SetFrameLevel((p.drag:GetFrameLevel() or 1) + 2)
        p.never.text = p.never:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); p.never.text:SetPoint("RIGHT"); p.never.text:SetText(T("RV_VAULT_NEVER", "不再弹出"))
        p.never:SetScript("OnEnter", function(b) b.text:SetFontObject("GameFontHighlightSmall") end)
        p.never:SetScript("OnLeave", function(b) b.text:SetFontObject("GameFontDisableSmall") end)
        p.never:SetScript("OnClick", function()
            GearInsightDB = GearInsightDB or {}; GearInsightDB.vaultPanelOff = true; RV._vaultForce = nil; p:Hide()
            GearInsight:Print(T("RV_VAULT_OFF_MSG", "已关闭：以后打开宏伟宝库不再显示「低保怎么选」。想看时输入 /gi vault，恢复自动显示用 /gi vault on 或设置页。"))
        end)
        p.progressTitle = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); p.progressTitle:SetPoint("TOPLEFT", 16, -47); p.progressTitle:SetTextColor(0.55, 0.82, 1.00)
        p.progress = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); p.progress:SetPoint("TOPLEFT", 20, -66); p.progress:SetWidth(390); p.progress:SetJustifyH("LEFT"); p.progress:SetSpacing(3); p.progress:SetWordWrap(true)
        p.rec = CreateFrame("Frame", nil, p, "BackdropTemplate")
        p.rec:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        p.recIcon = CreateFrame("Button", nil, p.rec); p.recIcon:SetSize(34, 34); p.recIcon:SetPoint("TOPLEFT", 12, -6)
        p.recIcon.texture = p.recIcon:CreateTexture(nil, "ARTWORK"); p.recIcon.texture:SetAllPoints(); p.recIcon.texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        p.recIcon:SetScript("OnEnter", function(b)
            -- 推荐装备：图标悬浮 = 装备本身 + 评分理由（用户 2026-09-24「这里加上装备，装备可以tooltip」）
            local c = type(b._item) == "table" and b._item or nil
            if c then
                GameTooltip:SetOwner(b, "ANCHOR_LEFT")
                if c.link then GameTooltip:SetHyperlink(c.link) else GameTooltip:SetItemByID(c.id) end
                GameTooltip:AddLine(" ")
                GameTooltip:AddDoubleLine(T("RV_VAULT_TT_SCORE", "GearInsight 评分"), string.format("%+d", c.score or 0), 0.65, 0.70, 0.80, 1, 1, 1)
                for _, reason in ipairs(c.reasons or {}) do GameTooltip:AddLine("· " .. reason, 0.76, 0.80, 0.88, true) end
                GameTooltip:Show()
                return
            end
            local reward = b._reward
            if not reward then return end
            GameTooltip:SetOwner(b, "ANCHOR_LEFT")
            if reward.type == ((Enum and Enum.CachedRewardType and Enum.CachedRewardType.Currency) or 2) then
                GameTooltip:SetCurrencyByID(reward.id)
            else
                local link = reward.itemDBID and C_WeeklyRewards.GetItemHyperlink(reward.itemDBID)
                if link then GameTooltip:SetHyperlink(link) else GameTooltip:SetItemByID(reward.id) end
            end
            GameTooltip:Show()
        end)
        p.recIcon:SetScript("OnLeave", function() GameTooltip:Hide() end)
        p.recIcon:SetScript("OnClick", function(b)
            if type(b._item) == "table" and b._item.link and IsModifiedClick("CHATLINK") then ChatEdit_InsertLink(b._item.link) end
        end)
        p.recTitle = p.rec:CreateFontString(nil, "OVERLAY", "GameFontNormal"); p.recTitle:SetPoint("TOPLEFT", 12, -9); p.recTitle:SetPoint("RIGHT", -12, 0); p.recTitle:SetJustifyH("LEFT")
        p.recBody = p.rec:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); p.recBody:SetPoint("TOPLEFT", 12, -29); p.recBody:SetPoint("RIGHT", -12, 0); p.recBody:SetJustifyH("LEFT"); p.recBody:SetWordWrap(true); p.recBody:SetTextColor(0.72, 0.76, 0.84)
        p.listTitle = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); p.listTitle:SetTextColor(0.68, 0.72, 0.80); p.listTitle:SetJustifyH("LEFT")
        -- 用户 2026-09-24「能否打H78的选项在哪里」→「能不能打H团也可以制约下，如果能打H团1-6就算1-6的史诗」：
        -- 团本进度按钮，点一下换一档：自动 → 不打团 → H 1-6 → H 全通 → M
        p.planBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate"); p.planBtn:SetSize(150, 20)
        p.planBtn:SetScript("OnClick", function() RV.CycleRaidPlan(); RV.RefreshVault() end)
        p.planBtn:SetScript("OnEnter", function(b)
            GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
            GameTooltip:SetText(T("RV_PLAN_TT3", "团本进度决定 Roll 币能砸哪些 boss：H 难度 boss 用 Roll 币、开低保都出神话轨装备。\n点一下换一档：打不了 H（只算大秘境）/ 能打 H1-6（前 6 个 boss，×0.8）/ 能打 H1-8（全部 boss，×1.25），再 × 稀缺 1.3。"), 1, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        p.planBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        p.itemRows = {}
        p._exportRequest = 0
        p.btn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate"); p.btn:SetSize(260, 26); p.btn:SetPoint("BOTTOM", 0, 13); p.btn:SetText(T("RV_VAULT_WECHAT", "求助微信好友"))
        -- Roll 币池子设置入口：标记 roll 到过的装备 → 出池，Roll 币估值跟着变（用户 2026-09-24）
        p.rollBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate"); p.rollBtn:SetSize(260, 22); p.rollBtn:SetPoint("BOTTOM", 0, 43)
        p.rollBtn:SetText(T("RV_VAULT_ROLL_POOL", "Roll 币池子：标记 roll 到过的装备"))
        p.rollBtn:SetScript("OnClick", function() if GearInsight.ShowRollPlan then GearInsight:ShowRollPlan() end end)
        local function exportVault(attempt, requestId)
            attempt = attempt or 0
            if attempt == 0 then p._exportRequest = (p._exportRequest or 0) + 1; requestId = p._exportRequest end
            if requestId ~= p._exportRequest then return end
            local okC, cands, pending = pcall(RV.VaultCandidates)
            if not okC then GearInsight:Print("|cFFFF6666[低保] 读奖励出错：|r" .. tostring(cands)); return end
            if pending then GearInsight:Print(T("RV_VAULT_WAIT_EXPORT", "奖励仍在载入，请稍候再导出。")); return end
            if #cands == 0 then GearInsight:Print(T("RV_VAULT_ASK_EMPTY", "尚未读到可领取装备，请打开宝库领取界面，奖励载入后再求助好友。")); return end
            local okE, str, coin = pcall(RV.BuildVaultExport, cands)
            if not okE then GearInsight:Print("|cFFFF6666[低保] 生成导出串出错：|r" .. tostring(str)); return end
            if coin and coin.status == "pending" and coin._retryable and attempt < 5 then
                if attempt == 0 then GearInsight:Print(T("RV_ROLL_EXPORT_WAIT", "正在载入 Roll 币评估，完成后会自动生成导出链接…")) end
                C_Timer.After(1, function()
                    if p:IsShown() then exportVault(attempt + 1, requestId) end
                end)
                return
            end
            if str then
                local url = RV.VaultExportURL(str)
                local hint = T("RV_VAULT_ASK_HINT", "Ctrl+C 复制链接，到浏览器打开；当前装备和宝库候选会一起生成求助卡，微信扫码后可发给好友或群聊。")
                if coin and coin.status == "pending" then hint = hint .. "\n" .. coin.reason end
                GearInsight:ShowCopyText(url, hint,
                    T("RV_VAULT_WECHAT", "求助微信好友"), nil)
            else
                GearInsight:Print(T("RV_VAULT_EXPORT_FAIL2", "导出失败：装备快照没准备好（/gi refresh 后再试）。如果一直失败，把这句发给作者。"))
            end
        end
        p.btn:SetScript("OnClick", function() exportVault() end)
        -- 用户 2026-09-24「英文这里隐藏」「就是非简体中文都隐藏」：求助好友按钮只给简体中文客户端，
        -- 其它语言藏掉，Roll 币池子按钮落到它的位置
        if _LOCALE ~= "zhCN" then
            p.btn:Hide()
            p.rollBtn:ClearAllPoints(); p.rollBtn:SetPoint("BOTTOM", 0, 13)
        end
        vaultPanel = p
    end

    local p = vaultPanel
    for _, r in ipairs(p.itemRows) do r._item = nil; r:Hide() end
    local progressLines, cands, pending, claiming = {}, {}, false, false
    local recTitle, recBody, recMode, recItem = "", "", "info", nil
    local listCoin
    local coinReward
    local typeNames = vaultTypes()
    local okBuild, buildErr = pcall(function()
        local activities = C_WeeklyRewards.GetActivities() or {}
        coinReward = RV.VaultCoinReward(activities)
        claiming = C_WeeklyRewards.HasAvailableRewards and C_WeeklyRewards.HasAvailableRewards() or false
        for _, a in ipairs(activities) do if hasVaultReward(a) then claiming = true end end
        cands, pending = RV.VaultCandidates(activities)
        local rows = RV.VaultRows(activities, claiming)
        for _, typ in ipairs({ V_RAID, V_DUNGEON, V_WORLD, V_PVP }) do
            local r = rows[typ]
            if r then
                local color = r.done > 0 and "|cFF66CC66" or "|cFFAAAAAA"
                local line = string.format("%s%-8s %d/%d|r", color, typeNames[typ], r.done, r.total)
                if r.need and r.need > 0 then line = line .. string.format("  |cFF777777" .. T("RV_VAULT_NEED", "再 %d 次开一格") .. "|r", r.need) end
                progressLines[#progressLines + 1] = line
            end
        end
        if pending then
            recTitle = T("RV_VAULT_PENDING_TITLE", "奖励载入中")
            recBody = T("RV_VAULT_PENDING", "奖励仍在载入，暂不推荐；数据齐全后会自动刷新。")
        elseif #cands == 0 then
            recTitle = T("RV_VAULT_NO_PICK", "当前没有可选装备")
            recBody = claiming and T("RV_VAULT_LOADING", "奖励尚未读取完成，请在宝库处打开领取界面，稍候会自动刷新。")
                or T("RV_VAULT_NO_REWARDS", "当前没有可领取奖励；上方是本周累计进度，预览装备不参与推荐。")
        else
            if GearInsight.WarmCatalystCache then pcall(GearInsight.WarmCatalystCache) end
            local evaluation = RV.EvaluateVault(cands)
            local best = cands[1]
            local coinV = evaluation.coinValue
            listCoin = coinV
            if evaluation.mode == "item" then
                recMode = "item"; recItem = best
                recTitle = string.format(T("RV_VAULT_PICK_ITEM2", "推荐装备：%s"), best.name)
                recBody = string.format(T("RV_VAULT_PICK_REASON2", "%s · 物品等级 %d · 评分 %+d"), vaultSource(best, typeNames), best.ilvl or 0, best.score)
            else
                recMode = "coin"
                recTitle = T("RV_VAULT_PICK_COIN", "推荐：选择 Roll 币")
                recBody = string.format(T("RV_VAULT_PICK_COIN_REASON", "%d 件装备评分都低于 15，没有明显提升；直接拿宝库底部的 Roll 币。"), #cands)
                if coinV and coinV.score > (best and best.score or 0) then
                    recBody = RV.CoinLine(coinV) .. string.format(T("RV_VAULT_COIN_ABOVE", "，高于最佳装备 %d 分。"), best and best.score or 0)
                end
            end
        end
    end)
    if not okBuild then
        cands = {}; recMode = "error"; recTitle = T("RV_VAULT_ERR_TITLE", "推荐计算失败"); recBody = tostring(buildErr)
        GearInsight:Print("|cFFFF6666[低保] RefreshVault 出错：|r" .. tostring(buildErr))
    end

    p.progressTitle:SetText(claiming and T("RV_VAULT_CLAIM_ROWS", "本次可领取") or T("RV_VAULT_PROGRESS_ROWS", "本周进度（下次奖励）"))
    p.progress:SetText(#progressLines > 0 and table.concat(progressLines, "\n") or T("RV_VAULT_NO_PROGRESS", "暂无进度数据"))
    local y = 66 + math.max(15, p.progress:GetStringHeight() or 0) + 12
    p.rec:ClearAllPoints(); p.rec:SetPoint("TOPLEFT", 14, -y); p.rec:SetPoint("TOPRIGHT", -14, -y)
    p.recTitle:SetText(recTitle); p.recBody:SetText(recBody)
    local showCoinIcon = recMode == "coin" and coinReward ~= nil
    local showItemIcon = recMode == "item" and recItem ~= nil
    p.recIcon._reward = showCoinIcon and coinReward or nil
    p.recIcon._item = showItemIcon and recItem or nil
    if showCoinIcon then p.recIcon.texture:SetTexture(coinReward.icon); p.recIcon:Show()
    elseif showItemIcon then p.recIcon.texture:SetTexture(recItem.icon or 134400); p.recIcon:Show()
    else p.recIcon:Hide() end
    p.recTitle:ClearAllPoints(); p.recTitle:SetPoint("TOPLEFT", (showCoinIcon or showItemIcon) and 54 or 12, showCoinIcon and -16 or -10); p.recTitle:SetPoint("RIGHT", -12, 0)
    p.recBody:ClearAllPoints(); p.recBody:SetPoint("TOPLEFT", showItemIcon and 54 or 12, showCoinIcon and -47 or -29); p.recBody:SetPoint("RIGHT", -12, 0)
    local recH = (showCoinIcon and 58 or 40) + math.max(14, p.recBody:GetStringHeight() or 0)
    if showItemIcon then recH = math.max(recH, 48) end
    p.rec:SetHeight(recH)
    if recMode == "coin" then
        p.rec:SetBackdropColor(0.18, 0.12, 0.025, 0.96); p.rec:SetBackdropBorderColor(1.00, 0.70, 0.12, 0.95); p.recTitle:SetTextColor(1.00, 0.82, 0.18)
    elseif recMode == "item" then
        p.rec:SetBackdropColor(0.035, 0.14, 0.085, 0.96); p.rec:SetBackdropBorderColor(0.20, 0.85, 0.48, 0.95); p.recTitle:SetTextColor(0.35, 1.00, 0.60)
    elseif recMode == "error" then
        p.rec:SetBackdropColor(0.18, 0.035, 0.035, 0.96); p.rec:SetBackdropBorderColor(1.00, 0.25, 0.25, 0.95); p.recTitle:SetTextColor(1.00, 0.35, 0.35)
    else
        p.rec:SetBackdropColor(0.055, 0.070, 0.10, 0.96); p.rec:SetBackdropBorderColor(0.25, 0.35, 0.48, 0.95); p.recTitle:SetTextColor(0.65, 0.82, 1.00)
    end
    y = y + recH + 12
    p.listTitle:ClearAllPoints(); p.listTitle:SetPoint("TOPLEFT", 16, -y)
    do
        local _, _, _, label = RV.RaidPlan()
        p.planBtn:ClearAllPoints(); p.planBtn:SetPoint("TOPRIGHT", -12, -y + 3)
        p.planBtn:SetText(T("RV_PLAN_BTN", "团本：") .. label)
        p.planBtn:SetShown(#cands > 0)
    end
    -- ⛔ 用户 2026-09-24「这里可选装备要列出ROLL币的评分」「和排名」「跟着一起排，从高到下」：
    --   Roll 币作为一行和装备一起按分数排，每行带名次 #N。Roll 币行悬浮 = 最值得砸那处的最好装备 + 算法。
    local shown = {}
    for _, c in ipairs(cands) do shown[#shown + 1] = c end
    if not listCoin and #cands > 0 then
        -- 用户 2026-09-24「ROLL币呢」「ROLL币评分」：算不出币值（能砸的 boss / 大秘境里没有必 roll 件、或数据还在载入）也要列出这一行
        shown[#shown + 1] = { isCoin = true, name = T("RV_VAULT_COIN_ROW", "Roll 币"), score = 0, quality = 5,
            icon = type(coinReward) == "table" and coinReward.icon or 133784, coinNone = true,
            reasons = { T("RV_VAULT_COIN_NONE", "按当前团本进度，能砸的 boss 和大秘境里都没有「必 roll」装备（或掉落数据还在载入），Roll 币记 0 分。可以点「团本」按钮换进度。") } }
    end
    if listCoin and #cands > 0 then
        local coinIcon = coinReward
        shown[#shown + 1] = { isCoin = true, id = listCoin.bestId, link = listCoin.bestLink, name = T("RV_VAULT_COIN_ROW", "Roll 币"),
            icon = type(coinIcon) == "table" and coinIcon.icon or 133784, score = listCoin.score, quality = 5,
            reasons = { RV.CoinLine(listCoin) }, coin = listCoin }
        table.sort(shown, function(x, z)
            if (x.score or 0) ~= (z.score or 0) then return (x.score or 0) > (z.score or 0) end
            return not x.isCoin and z.isCoin     -- 同分装备在前（与推荐判定一致：同分选装备）
        end)
    end
    p.listTitle:SetText(#cands > 0 and string.format(T("RV_VAULT_LIST2", "可选装备 · %d 件（悬浮查看属性）"), #cands) or "")
    if #cands > 0 then y = y + 22 end
    for i, c in ipairs(shown) do
        if i > 9 then break end
        local r = vaultItemRow(p, i)
        local _, col = verdictOf(c.score)
        local verdict = c.vaultVerdict or vaultVerdictOf(c.score)
        local source = c.isCoin and T("RV_VAULT_COIN_SRC", "宝库币") or vaultSource(c, typeNames)
        local sc = c.isCoin and { 1.00, 0.82, 0.18 } or VAULT_SOURCE_COLOR[c.atype] or { 0.7, 0.7, 0.7 }
        r:ClearAllPoints(); r:SetPoint("TOPLEFT", 14, -y); r:SetPoint("TOPRIGHT", -14, -y)
        r._item, r._source = c, source
        r.icon:SetTexture(c.icon or 134400); r.source:SetText(source); r.source:SetTextColor(sc[1], sc[2], sc[3]); r.accent:SetColorTexture(sc[1], sc[2], sc[3], 0.95)
        r.name:SetText("|cFF8A93A6#" .. i .. "|r " .. (c.name or "?")); local qc = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[c.quality or 1]
        if qc then r.name:SetTextColor(qc.r, qc.g, qc.b) else r.name:SetTextColor(0.92, 0.92, 0.96) end
        r.ilvl:SetText((c.scoreIlvl or c.ilvl or 0) ~= (c.ilvl or 0)
            and string.format(T("RV_VAULT_ILVL_MAX", "物品等级 %d · 升满 %d"), c.ilvl or 0, c.scoreIlvl or 0)
            or string.format(T("RV_VAULT_ILVL", "物品等级 %d"), c.ilvl or 0))
        if c.isCoin and c.coinNone then
            r.ilvl:SetText(T("RV_VAULT_COIN_NONE_SUB", "没有必 roll 装备可砸"))
        elseif c.isCoin then
            local cv = c.coin
            r.ilvl:SetText(string.format(T("RV_VAULT_COIN_SUB2", "砸 %s · 必roll %s +%d · 概率 %.1f%%"),
                cv.kind == "mp" and (T("RV_VAULT_COIN_MP", "大秘境·") .. (cv.boss or "?")) or ((cv.diff == 16 and "M" or "H") .. (cv.bossOrd or 0) .. " " .. (cv.boss or "?")),
                cv.bestName or "?", cv.bestScore or 0, (cv.p or 0) * 100))
        elseif c.filler and c.filler.tierRank then
            r.ilvl:SetText(r.ilvl:GetText() .. string.format(T("RV_VAULT_TAG_FILLER2", " · |cFF8CC8FF坯子#%d/%d|r"), c.filler.idx or 0, c.filler.total or 0))
        elseif c.bisRank then
            r.ilvl:SetText(r.ilvl:GetText() .. string.format(T("RV_VAULT_TAG_BIS", " · |cFFFFD100BiS#%d|r"), c.bisRank))
        end
        r.score:SetText(col .. string.format(T("RV_VAULT_SCORE_LABEL", "评分 %d"), c.score or 0) .. "|r")
        r.verdict:SetTextColor(0.70, 0.73, 0.80)
        r.verdict:SetText(verdict)
        if i == 1 and (recMode == "item" or (recMode == "coin" and c.isCoin)) then r:SetBackdropBorderColor(1.00, 0.75, 0.16, 1) else r:SetBackdropBorderColor(0.18, 0.22, 0.30, 0.9) end
        r:Show(); y = y + VAULT_ROW_H + 4
    end
    p:SetHeight(math.max(260, y + ((_LOCALE == "zhCN") and 80 or 50))); p:Show()
end
-- 已经加载了就直接挂
if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Blizzard_WeeklyRewards") then RV.HookVault() end

-- ── P2 · 装备 vs BiS 四档（与网站 rows[].status 同口径）─────────────────
-- 在前 3 候选里 → bis；装等 ≥ 第一候选 → near；有装备但都不是 → gap；空 → empty
function GearInsight.SlotBisStatus(slotId)
    local bis, data = bisIndex()
    local link = GetInventoryItemLink("player", slotId)
    if not link then return "empty" end
    local id = C_Item.GetItemInfoInstant(link)
    local ilvl = C_Item.GetDetailedItemLevelInfo and C_Item.GetDetailedItemLevelInfo(link) or 0
    local b = bis[id]
    if b and b.rank <= 3 then return "bis" end
    local cands = data and data.bisBySlot and data.bisBySlot[slotId]
    local first = cands and cands[1]
    if first and ilvl >= (first.ilvl or 0) then return "near" end
    return "gap"
end

-- ── 用币前建议 + 二次确认（玩家 Epiphany 2026-09-24：「能加一个 ROLL 币前询问吗，如果可以的话，这个插件就可以卸载了」
--    —— 他装的是「真ROLL吗?」）。暴雪弹出 Roll 币窗口（BonusRollFrame）时：
--   ① 旁边一块建议：这个 boss / 这个大秘境本值不值得砸（必 roll 件数 / 概率 / 件名；已拥有的仍在池子里会重复）；
--   ② 确认后本次不再拦截；最多遮挡 4 秒，超时放行原生按钮，不自动用币。
--   ⛔ 不改暴雪按钮的 OnClick（insecure 代码替换暴雪脚本 = 污染），只盖自己的按钮；设置 rollConfirm=false 可关。
local function bonusTarget()
    -- 优先问暴雪：这个 Roll 币窗口对应哪个手册首领 / 副本
    local f = BonusRollFrame
    if f and f.spellID and GetJournalInfoForSpellConfirmation then
        local ok, jInst, jEnc = pcall(GetJournalInfoForSpellConfirmation, f.spellID)
        if ok and (jEnc or jInst) then return jInst, jEnc end
    end
    -- 团本：ENCOUNTER_START 时记下的手册 boss；大秘境：当前地图对应的手册副本
    local jInst
    if EJ_GetInstanceForMap and C_Map and C_Map.GetBestMapForUnit then
        local ok, v = pcall(EJ_GetInstanceForMap, C_Map.GetBestMapForUnit("player"))
        if ok then jInst = v end
    end
    return jInst, _lastEncounterId
end

function RV.BonusAdvice()
    local jInst, jEnc = bonusTarget()
    local _, itype, diffID = GetInstanceInfo()
    local row, kind
    if itype == "raid" and DIFF_NAME[diffID] then
        local ok, res = pcall(RV.Evaluate, diffID)
        if ok and res and res.bosses then
            for _, b in ipairs(res.bosses) do if jEnc and b.id == jEnc then row, kind = b, "raid" end end
        end
    else
        local ok, mp = pcall(RV.EvaluateMplus)
        if ok and mp and mp.dungeons then
            for _, d in ipairs(mp.dungeons) do if jInst and d.id == jInst then row, kind = d, "mp" end end
        end
    end
    if not row then return nil end
    local must, owned, names = 0, 0, {}
    for _, it in ipairs(row.items or {}) do
        if (it.pRoll or 0) > 0 then
            if it.verdict == "must" then must = must + 1; names[#names + 1] = it.name or ("#" .. tostring(it.id)) end
            if it.owned then owned = owned + 1 end
        end
    end
    local n = row.nEligible or 0
    return { name = row.name, kind = kind, n = n, must = must, useful = row.nUseful or 0, owned = owned, names = names,
             pMust = n > 0 and must / n or 0, pUseful = row.pUseful or 0 }
end

-- Both the live prompt and the coin-free simulator use this controller.
local function createBonusController(bf, advice, testSettings)
local function config() return testSettings or GearInsightDB or {} end
local bonusPanel, bonusGuard
local bonusSession = 0
local bonusReleased = true
local function releaseBonusGuard()
    bonusReleased = true
    if bonusGuard then bonusGuard:Hide() end
end
local function ensureBonusUI()
    if not bf then return nil end
    if not bonusPanel then
        local p = CreateFrame("Frame", nil, bf, "BackdropTemplate")
        p:SetSize(300, 96); p:SetPoint("BOTTOM", bf, "TOP", 0, 6)
        p:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        p:SetBackdropColor(0.04, 0.05, 0.08, 0.95); p:SetBackdropBorderColor(0.6, 0.5, 0.2, 0.9)
        p.title = p:CreateFontString(nil, "OVERLAY", "GameFontNormal"); p.title:SetPoint("TOPLEFT", 10, -8); p.title:SetPoint("RIGHT", -10, 0); p.title:SetJustifyH("LEFT")
        p.body = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); p.body:SetPoint("TOPLEFT", 10, -28); p.body:SetPoint("RIGHT", -10, 0)
        p.body:SetJustifyH("LEFT"); p.body:SetWordWrap(true); p.body:SetSpacing(2)
        bonusPanel = p
    end
    local prompt = bf.PromptFrame
    local btn = prompt and prompt.RollButton
    if btn and not bonusGuard then
        local g = CreateFrame("Button", nil, prompt)
        g:SetAllPoints(btn); g:SetFrameLevel(btn:GetFrameLevel() + 5)
        g:Hide()
        g.label = g:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        g.label:SetPoint("CENTER"); g.label:SetText("确认用币")
        g.hl = g:CreateTexture(nil, "OVERLAY"); g.hl:SetAllPoints(); g.hl:SetColorTexture(1, 0.8, 0.1, 0.18)
        g:SetScript("OnEnter", function(s)
            GameTooltip:SetOwner(s, "ANCHOR_TOP"); GameTooltip:SetText("先点确认，再点原生 ROLL 按钮用币", 1, 0.82, 0, true); GameTooltip:Show()
        end)
        g:SetScript("OnLeave", function() GameTooltip:Hide() end)
        g:SetScript("OnClick", function()
            releaseBonusGuard()
            GameTooltip:Hide()
            if bonusPanel then
                bonusPanel.title:SetText("|cFFFFD100已确认，请再点 ROLL 用币（尚未使用）|r")
            end
        end)
        -- Settings changes must never leave an invisible blocker over Blizzard's button.
        g:SetScript("OnUpdate", function()
            if bonusReleased or not bf:IsShown()
                or (config().rollAdvice == false or config().rollConfirm == false) then
                releaseBonusGuard()
            end
        end)
        bonusGuard = g
    end
    return bonusPanel
end

local function onShow()
    if not bf or not bf:IsShown()
        or (config().rollAdvice == false) then
        releaseBonusGuard()
        if bonusPanel then bonusPanel:Hide() end
        return
    end
    local p = ensureBonusUI()
    if not p then return end
    if bonusGuard then
        bonusGuard:SetShown(not bonusReleased and not (config().rollConfirm == false))
    end
    local ok, a = pcall(advice)
    a = ok and a or nil
    if testSettings then
        p.title:SetText("确认逻辑模拟 · 不会使用 Roll 币")
        p.body:SetText("4 秒内点确认，再点 ROLL：计数应为 1。\n确认后不会重新遮挡；未操作 4 秒会自动放行。")
    elseif not a then
        p.title:SetText("GearInsight · " .. T("RV_BONUS_NA", "这里算不出来"))
        p.body:SetText(T("RV_BONUS_NA_BODY", "没认出是哪个首领 / 副本（或掉落数据还在载入）。打开 /gi roll 看完整列表。"))
    else
        local col = a.must > 0 and "|cFF33FF66" or (a.useful > 0 and "|cFFFFD100" or "|cFFFF5555")
        local verdict = a.must > 0 and T("RV_BONUS_YES", "建议 ROLL") or (a.useful > 0 and T("RV_BONUS_MAYBE", "可以 ROLL（没有必 roll 件）") or T("RV_BONUS_NO", "不建议 ROLL"))
        p.title:SetText(col .. verdict .. "|r  ·  " .. (a.name or "?"))
        local lines = {}
        lines[#lines + 1] = string.format(T("RV_BONUS_MUST", "必 roll %d/%d 件（%.0f%%）· 有用 %d 件（%.0f%%）"), a.must, a.n, a.pMust * 100, a.useful, a.pUseful * 100)
        if #a.names > 0 then lines[#lines + 1] = "|cFFB0B8C8" .. table.concat(a.names, "、", 1, math.min(3, #a.names)) .. (#a.names > 3 and " …" or "") .. "|r" end
        if a.owned > 0 then lines[#lines + 1] = string.format("|cFFFF9933" .. T("RV_BONUS_OWNED", "身上已有 %d 件仍在池子里，可能 roll 到重复") .. "|r", a.owned) end
        p.body:SetText(table.concat(lines, "\n"))
    end
    p:SetHeight(36 + math.max(14, p.body:GetStringHeight() or 0))
    p:Show()
end

local function hook()
    if not bf or bf._giHooked then return end
    bf._giHooked = true
    bf:HookScript("OnShow", function()
        bonusSession = bonusSession + 1
        local session = bonusSession
        bonusReleased = false
        C_Timer.After(0.1, function()
            if session ~= bonusSession or not bf:IsShown() then return end
            local ok = pcall(onShow)
            if not ok then
                releaseBonusGuard()
                if bonusPanel then bonusPanel:Hide() end
            end
        end)
        -- Fail open. Never re-cover the Roll button after the user confirms.
        C_Timer.After(4, function()
            if session == bonusSession then releaseBonusGuard() end
        end)
    end)
    bf:HookScript("OnHide", function()
        bonusSession = bonusSession + 1
        releaseBonusGuard()
        if bonusPanel then bonusPanel:Hide() end
    end)
end
return { show = onShow, hook = hook }
end
local liveBonusController
function RV.HookBonusRoll()
    if not BonusRollFrame then return end
    liveBonusController = liveBonusController or createBonusController(BonusRollFrame, RV.BonusAdvice)
    liveBonusController.hook()
end
function RV.OnBonusRollShow()
    if liveBonusController then liveBonusController.show() end
end
C_Timer.After(1, function() pcall(RV.HookBonusRoll) end)

