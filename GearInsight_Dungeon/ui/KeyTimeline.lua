-- 钥匙时间轴（KeyTimeline）：大米攻略的「这把钥匙怎么打」层。
--   一根细横条 = 钥匙限时；打点 = boss 到达（顶尖局中位）/ 共识嗜血点 / 当前光标。
--   光标上一行字永远只说「下一件事」：下个嗜血点在哪、顶尖局几成在那开、还有多久、你的嗜血来不来得及。
--   角色分流：有嗜血技能的人看「来得及/来不及」，其他人看「留爆发」。
--   证据口径红线：每句提示都带 WCL 数字（几成局 / 中位分钟），不说没来由的「该开了」。
-- 数据：core/DungeonData.lua 的 lust2（按 boss 段位归因）与 bosses（高层局到达/击杀中位）。
-- 12.0 secret：钥匙用时 GetWorldElapsedTime 在完成后可能是 secret → 一律 issecretvalue 防护；
--   嗜血/疲惫只查自己身上的已知 ID 光环（GetPlayerAuraBySpellID），不枚举。
GearInsight = GearInsight or {}
-- ⭐ 语言只能从 GearInsight.LOCALE 取（locales/zhCN.lua 里定的唯一真相源）。⛔别写 GetLocale()。
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

local function LG() return GearInsight.LG end
local function isSecret(v) return issecretvalue and issecretvalue(v) or false end

-- 嗜血职业判定：已学任一嗜血系技能（萨满/法师/猎人/唤魔师）
local LUST_SPELLS = { 2825, 32182, 80353, 264667, 390386 }
local function myLustSpell()
    for _, sid in ipairs(LUST_SPELLS) do
        if IsPlayerSpell and IsPlayerSpell(sid) then return sid end
    end
    -- 猎人的嗜血在宠物身上（原始狂怒 264667），IsPlayerSpell 查不到 → 按职业算嗜血职业
    local _, cls = UnitClass("player")
    if cls == "HUNTER" then return 264667 end
end

local function fmtMMSS(sec)
    sec = math.max(0, math.floor(sec + 0.5))
    return ("%d:%02d"):format(math.floor(sec / 60), sec % 60)
end

-- ── 状态 ──────────────────────────────────────────────────────────────
local d                     -- DungeonData 条目（含 lust2 / bosses）
local timeLimit = 0         -- 钥匙限时（秒）
local bossByGid = {}        -- npcID -> d.bosses 下标
local plan = {}             -- lust2 展开：{kind,gid,cn,en,pct,medMin,ord,idx,key}
local killed = 0            -- 已完成的 boss 条件数
local killTimes = {}        -- 第 k 个 boss 击杀时的钥匙用时
local seenDone = {}         -- 条件下标 -> 已记录完成（重载进本时不给旧完成项记时间）
local primed = false
local paceOffset = 0        -- 你 - 顶尖（秒），正数=慢
local lustOn, lustExpire = false, 0
local called = {}           -- 预告只发一次：point.key -> true
local done = {}             -- 嗜血已在这一轮开过：point.key -> true（同一次的备选一并算过）
local ticker
local curName               -- 当前已解析的副本名（子区域切换不重置进度/预告）

local function segName(p)
    local lg = LG()
    local nm = lg and lg.spellName(0, p.cn, p.en) or p.cn
    local bossTag = "|cffff8000" .. T("DG_BOSS", "[BOSS]") .. "|r"
    if p.kind == 0 then return T("KT_SEG_OPEN", "开门波") end
    if p.kind == 1 then return T("KT_SEG_PRE", "%s前一波"):format(bossTag .. nm) end
    if p.kind == 3 then return T("KT_SEG_POST", "尾王后") end
    return bossTag .. nm
end
GearInsight.KeyTimelineSegName = function(_, p) return segName(p) end

local function resolve()
    d, timeLimit, killed, paceOffset, primed = nil, 0, 0, 0, false
    wipe(bossByGid); wipe(plan); wipe(killTimes); wipe(seenDone); wipe(called); wipe(done)
    if GearInsightDB and GearInsightDB.keyTimelineOff then return end
    local data = GearInsightDungeonData
    if not data then return end
    local name, instanceType, difficultyID = GetInstanceInfo()
    if instanceType ~= "party" or not name or difficultyID ~= 8 then return end
    if not (C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive
        and C_ChallengeMode.IsChallengeModeActive()) then return end
    for _, x in ipairs(data) do
        if x.cn == name or x.en == name then d = x break end
    end
    if not d or not d.bosses or #d.bosses == 0 then d = nil return end
    for i, b in ipairs(d.bosses) do
        bossByGid[b[1]] = i
        for _, g in ipairs(b[7] or {}) do bossByGid[g] = i end
    end
    local mapID = C_ChallengeMode.GetActiveChallengeMapID and C_ChallengeMode.GetActiveChallengeMapID()
    local tl = mapID and select(3, C_ChallengeMode.GetMapUIInfo(mapID))
    timeLimit = (tl and not isSecret(tl) and tl > 0) and tl or (d.bosses[#d.bosses][5] * 60 * 1.2)
    for _, p in ipairs(d.lust2 or {}) do
        plan[#plan + 1] = {
            kind = p[1], gid = p[2], cn = p[3], en = p[4], pct = p[5], medMin = p[6], ord = p[7],
            idx = bossByGid[p[2]], key = p[1] .. ":" .. p[2],
        }
    end
    table.sort(plan, function(a, b) return a.medMin < b.medMin end)
end

local function elapsedSec()
    if not d then return nil end
    local _, e = GetWorldElapsedTime(1)
    if e == nil or isSecret(e) or e < 0 then return nil end
    return e
end

local function refreshKills(elapsed)
    if not d then return end
    local n = select(3, C_Scenario.GetStepInfo()) or 0
    local k = 0
    for i = 1, n do
        local info = C_ScenarioInfo.GetCriteriaInfo(i)
        if info and not info.isWeightedProgress then
            if info.completed then
                k = k + 1
                if not seenDone[i] then
                    seenDone[i] = true
                    if primed and elapsed then killTimes[k] = elapsed end
                end
            end
        end
    end
    primed = true
    killed = k
    if k > 0 and killTimes[k] and d.bosses[k] then
        paceOffset = killTimes[k] - d.bosses[k][5] * 60
    end
end

local function pointPassed(p, elapsed)
    if done[p.key] then return true end
    if p.kind == 0 then return killed > 0 or (elapsed or 0) > 150 end
    if p.idx then return killed >= p.idx end
    return elapsed ~= nil and elapsed > p.medMin * 60 + paceOffset + 120
end

-- 下一个共识点（≥40%）与同一次嗜血的备选（30~39% 或同轮其他段位）
local function nextPoint(elapsed)
    local nxt
    for _, p in ipairs(plan) do
        if not pointPassed(p, elapsed) and p.pct >= 40 then nxt = p break end
    end
    if not nxt then
        for _, p in ipairs(plan) do
            if not pointPassed(p, elapsed) then nxt = p break end
        end
    end
    local alt
    if nxt then
        for _, p in ipairs(plan) do
            if p ~= nxt and p.ord == nxt.ord and not pointPassed(p, elapsed)
                and (not alt or p.pct > alt.pct) then alt = p end
        end
    end
    return nxt, alt
end

-- 你这边下次能嗜血还要多久：自己身上的疲惫剩余（=全队约束）∨ 自己嗜血技能 CD
-- ⛔ bug #109（QQ 群 幽默「我术士有，换到奥法就没了」/ 叶不灵「三个号都没有」，2026-09-05）：
--    12.x 在副本里 C_Spell.GetSpellCooldown 返回的 startTime/duration **可能是 secret**，
--    直接 `cd.duration > 2` 就是「attempt to compare a secret value」→ update() 每秒炸一次、
--    时间轴永远画不出来。术士没有嗜血技能、不走这条路，所以"术士有"。
--    所有冷却读取统一走这里：任一字段 secret 就当"读不到"（返回 nil），绝不参与算术。
-- ⛔⛔ 整段读取必须在**同一个 pcall 里**，包括对返回表的索引。
--   2026-09-08 玩家「策马奔腾」「密哥」报：法师进本没有嗜血条，同环境骑士正常；
--   出本的一瞬间条会闪一下又没了。判据是他们自己总结的那句 ——
--   「有嗜血的都没有，没有嗜血技能的就可以看到」。
--
--   根因：原来 pcall 只包住了**调用**，`cd.startTime` 这一行在 pcall 外面。
--   12.0 的 secret value 机制下，钥石里读自己技能的冷却可能拿到 secret 表，
--   **索引它本身就抛错** —— 而 sid 只有嗜血职业才非 nil，没嗜血的职业在第一行
--   就 return 了，根本走不到这行。于是「有嗜血 = 看不到条」。
--   出本那一瞬间不再是 secret，读取成功、条闪一下，随即 resolve() 判定不在钥石里再隐藏。
--
-- ⛔ 别只加 isSecret 判断：判断本身也要先索引到那个字段，一样会炸。
local function cdRemaining(sid)
    if not (sid and C_Spell and C_Spell.GetSpellCooldown) then return nil end
    local ok, st, du = pcall(function()
        local cd = C_Spell.GetSpellCooldown(sid)
        if not cd then return nil, nil end
        return cd.startTime, cd.duration
    end)
    if not ok then return nil end
    if isSecret(st) or isSecret(du) or type(du) ~= "number" then return nil end
    if du <= 2 then return 0 end
    local rem = (type(st) == "number" and st or 0) + du - GetTime()
    return rem > 0 and rem or 0
end

local function lustReadyIn()
    local lg = LG()
    local r = 0
    local sated = lg and lg.hasAnyAura(lg.SATED)
    if sated and sated.expirationTime and not isSecret(sated.expirationTime) then
        r = math.max(r, sated.expirationTime - GetTime())
    end
    local sid = myLustSpell()
    local rem = cdRemaining(sid)
    if rem then r = math.max(r, rem) end
    return r, sid
end

-- ── HUD ───────────────────────────────────────────────────────────────
local hud
local unlocked = false     -- 位置解锁状态（定义见文件末尾的锁定/解锁段）
local BAR_W = 300

local function ensureHud()
    if hud then return hud end
    local f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    f:SetSize(BAR_W + 20, 62)
    f:SetFrameStrata("HIGH")
    -- bug #123：群友「有点小，能不能自己设置大小」——整框缩放，0.8～2.0，设置总表 / /gi kt scale 可调
    f:SetScale(tonumber(GearInsightDB and GearInsightDB.keyTimelineScale) or 1)
    f:SetClampedToScreen(true)
    local pos = GearInsightDB and GearInsightDB.keyTimelinePos
    if pos and pos.point then
        f:SetPoint(pos.point, UIParent, pos.point, pos.x or 0, pos.y or 0)
    else
        f:SetPoint("TOP", UIParent, "TOP", 0, -244)   -- 读条高亮(-170)下方，不打架
    end
    f:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background" })
    f:SetBackdropColor(0.04, 0.04, 0.07, 0.72)
    -- ⛔ bug #108（抖音评论 豪大大 2026-09-05「这个轴要怎么解锁移动啊，放在姓名板那里好碍事」）：
    --    这条 320×62 的框默认 EnableMouse(true) 常年压在屏幕中上 —— 正是姓名板堆着的地方，
    --    它会**吃掉底下姓名板的点击**（这就是"碍事"），而"可拖动"只写在悬停 tooltip 里，
    --    打钥匙时没人会去悬停它。现在默认**锁定 = 完全不接鼠标**（点击穿透到姓名板），
    --    要挪位置走 /gi kt unlock（或大米攻略窗口的勾选框），解锁时高亮并允许拖动，
    --    锁回去再放开鼠标。位置照旧记在 GearInsightDB.keyTimelinePos，/gi kt reset 复位。
    f:EnableMouse(false)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(s) s:StartMoving() end)
    f:SetScript("OnDragStop", function(s)
        s:StopMovingOrSizing()
        local point, _, _, x, y = s:GetPoint()
        GearInsightDB = GearInsightDB or {}
        GearInsightDB.keyTimelinePos = { point = point, x = x, y = y }
    end)

    f.line1 = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.line1:SetPoint("TOPLEFT", 10, -6)
    f.line1:SetWidth(BAR_W)
    f.line1:SetJustifyH("LEFT")
    f.line1:SetWordWrap(false)

    f.bar = f:CreateTexture(nil, "ARTWORK")
    f.bar:SetSize(BAR_W, 6)
    f.bar:SetPoint("TOPLEFT", 10, -30)
    f.bar:SetColorTexture(0.25, 0.25, 0.3, 0.9)

    f.marks = {}
    local function mark(kind)
        local t = f:CreateTexture(nil, "OVERLAY")
        if kind == "boss" then
            t:SetSize(2, 12)
            t:SetColorTexture(1, 0.5, 0, 1)
        elseif kind == "lust" then
            t:SetSize(7, 7)
            t:SetColorTexture(0, 0.8, 1, 1)
        else
            t:SetSize(2, 14)
            t:SetColorTexture(1, 1, 1, 1)
        end
        t:Hide()
        return t
    end
    f.bossMarks, f.lustMarks = {}, {}
    for i = 1, 8 do f.bossMarks[i] = mark("boss") end
    for i = 1, 8 do f.lustMarks[i] = mark("lust") end
    f.cursor = mark("cursor")

    f.line2 = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.line2:SetPoint("TOPLEFT", 10, -42)
    f.line2:SetWidth(BAR_W)
    f.line2:SetJustifyH("LEFT")
    f.line2:SetWordWrap(false)
    f.line2:SetTextColor(0.75, 0.75, 0.75)

    -- 悬停：整把钥匙的计划（静态预习同款）
    f:SetScript("OnEnter", function(s)
        if not d then return end
        local lg = LG()
        GameTooltip:SetOwner(s, "ANCHOR_BOTTOM")
        GameTooltip:AddLine(T("KT_TIP_TITLE", "钥匙时间轴 · 顶尖局怎么打"), 1, 0.82, 0)
        GameTooltip:AddLine(T("KT_TIP_BOSSES", "boss 到达（高层局中位）"), 1, 0.5, 0)
        for i, b in ipairs(d.bosses) do
            local you = killTimes[i] and ("  |cffffffff" .. T("KT_TIP_YOU", "你 %s"):format(fmtMMSS(killTimes[i])) .. "|r") or ""
            GameTooltip:AddLine(("  %d. %s  |cffaaaaaa%s|r%s"):format(i, lg and lg.spellName(0, b[2], b[3]) or b[2],
                fmtMMSS(b[4] * 60), you), 0.9, 0.9, 0.9)
        end
        GameTooltip:AddLine(T("KT_TIP_LUST", "嗜血点（几成顶尖局在此开）"), 0, 0.8, 1)
        for _, p in ipairs(plan) do
            GameTooltip:AddLine(("  %s %s  |cffaaaaaa%d%% · %s|r"):format(
                T("KT_NTH", "第%d次"):format(p.ord), segName(p), p.pct, fmtMMSS(p.medMin * 60)),
                pointPassed(p, elapsedSec()) and 0.5 or 0.9, 0.9, 0.9)
        end
        GameTooltip:AddLine(T("KT_TIP_DRAG", "拖动可移动"), 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f:Hide()
    hud = f
    return f
end

-- ── 位置锁定 / 解锁 / 复位（bug #108）──────────────────────────────────
local function applyLock(f)
    f:EnableMouse(unlocked)
    if unlocked then
        f:SetBackdropColor(0.10, 0.35, 0.16, 0.85)      -- 绿：解锁中，可拖
    else
        f:SetBackdropColor(0.04, 0.04, 0.07, 0.72)
    end
end

function GearInsight:KeyTimelineIsUnlocked() return unlocked end

function GearInsight:KeyTimelineSetUnlocked(on)
    unlocked = on and true or false
    local f = ensureHud()
    applyLock(f)
    if unlocked then
        -- 不在钥匙里也把框摆出来，让人能在城里先摆好位置
        if not d then
            f.line1:SetText("|cff7cff9a" .. T("KT_UNLOCK_HINT", "钥匙时间轴 · 拖动我到合适位置") .. "|r")
            f.line2:SetText(T("KT_UNLOCK_HINT2", "摆好后 /gi kt lock 锁定（锁定后不挡姓名板点击）"))
            for _, t in ipairs(f.bossMarks) do t:Hide() end
            for _, t in ipairs(f.lustMarks) do t:Hide() end
            f.cursor:Hide()
        end
        f:Show()
        GearInsight:Print(T("KT_UNLOCKED", "钥匙时间轴已解锁：拖动移动，/gi kt lock 锁定。"))
    else
        if not d then f:Hide() end
        GearInsight:Print(T("KT_LOCKED", "钥匙时间轴已锁定（不再拦截鼠标）。"))
    end
end

function GearInsight:KeyTimelineSetScale(v)
    v = tonumber(v) or 1
    if v < 0.8 then v = 0.8 elseif v > 2 then v = 2 end
    GearInsightDB = GearInsightDB or {}
    GearInsightDB.keyTimelineScale = v
    local f = ensureHud()
    f:SetScale(v)
    return v
end

function GearInsight:KeyTimelineResetPos()
    if GearInsightDB then GearInsightDB.keyTimelinePos = nil end
    local f = ensureHud()
    f:ClearAllPoints()
    f:SetPoint("TOP", UIParent, "TOP", 0, -244)
    GearInsight:Print(T("KT_POS_RESET", "钥匙时间轴位置已复位。"))
end

local function placeMark(tex, sec, dy)
    if not tex then return end
    if not sec or timeLimit <= 0 then tex:Hide() return end
    local x = math.max(0, math.min(1, sec / timeLimit)) * BAR_W
    tex:ClearAllPoints()
    tex:SetPoint("CENTER", hud.bar, "LEFT", x, dy or 0)
    tex:Show()
end

local function burstsText()
    local lg = LG()
    if not lg then return "" end
    local parts = {}
    for i, sid in ipairs(lg.bursts) do
        if i > 6 then break end
        local rem = cdRemaining(sid) or 0        -- secret 安全（bug #109）
        local tex = C_Spell.GetSpellTexture(sid)
        local icon = tex and ("|T%s:16:16:0:0|t"):format(tex) or ""
        parts[#parts + 1] = icon .. (rem > 1.5 and ("|cffff7070%d|r"):format(math.ceil(rem)) or "|cff40ff40✓|r")
    end
    return table.concat(parts, " ")
end

local function maybeCall(nxt, alt, eta, readyIn, sid)
    if not nxt or lustOn or called[nxt.key] then return end
    local lg = LG()
    local plates = lg and lg.plates or {}
    local atBoss = false
    if nxt.idx and d.bosses[nxt.idx] then
        for _, npcID in pairs(plates) do
            if bossByGid[npcID] == nxt.idx then atBoss = true break end
        end
    end
    local near = (eta ~= nil and eta <= 60 and eta >= -90) or (nxt.kind == 2 and atBoss)
    if not near then return end
    called[nxt.key] = true
    if not (lg and lg.showAlert) then return end
    local where = segName(nxt)
    local ev = T("KT_EVIDENCE", "顶尖局 %d%% 在此开"):format(nxt.pct)
    if sid then
        if readyIn <= math.max(eta or 0, 0) + 20 then
            lg.showAlert(("|cff00ccff%s|r%s"):format(T("KT_ALERT_CASTER", "嗜血点："), where),
                ("|cffaaaaaa%s|r · %s"):format(ev, readyIn <= 1
                    and ("|cff40ff40" .. T("KT_READY", "你的嗜血已就绪") .. "|r")
                    or T("KT_READY_IN", "你的嗜血 %s 后转好"):format(fmtMMSS(readyIn))), 3)
        else
            local altTxt = alt and (" · " .. T("KT_ALT", "备选：%s %d%%"):format(segName(alt), alt.pct)) or ""
            lg.showAlert(("|cffff9926%s|r%s"):format(T("KT_ALERT_LATE", "嗜血点到了，嗜血未转好："), where),
                ("|cffaaaaaa%s · %s|r%s"):format(ev, T("KT_READY_IN", "你的嗜血 %s 后转好"):format(fmtMMSS(readyIn)), altTxt), 3)
        end
    else
        lg.showAlert(("|cff00ccff%s|r%s"):format(T("KT_ALERT_HOLD", "留爆发 · 嗜血点："), where),
            ("|cffaaaaaa%s|r"):format(ev), 3)
    end
end

local function update()
    if not d then
        if hud then hud:Hide() end
        if ticker then ticker:Cancel(); ticker = nil end
        return
    end
    local f = ensureHud()
    local elapsed = elapsedSec()
    refreshKills(elapsed)
    local lg = LG()
    local readyIn, sid = lustReadyIn()
    local nxt, alt = nextPoint(elapsed)

    -- 第一行：下一件事
    if lustOn then
        local rem = math.max(0, lustExpire - GetTime())
        f.line1:SetText(("|cffff5050%s|r |cffffd100%ds|r  %s"):format(
            T("KT_LUST_ON", "嗜血中·压满爆发"), math.ceil(rem), burstsText()))
    elseif nxt then
        local eta = elapsed and (nxt.medMin * 60 + paceOffset - elapsed) or nil
        local etaTxt = eta and (eta > 0 and T("KT_ETA", "≈%s后"):format(fmtMMSS(eta)) or T("KT_NOW", "≈现在")) or ""
        local ev = ("|cffaaaaaa%d%%|r"):format(nxt.pct)
        if sid then
            local ok
            if readyIn <= 1 then ok = "|cff40ff40✓" .. T("KT_READY_SHORT", "嗜血就绪") .. "|r"
            elseif eta and readyIn > eta + 20 then ok = "|cffff7070✗" .. T("KT_LATE_SHORT", "嗜血 %s 后转好"):format(fmtMMSS(readyIn)) .. "|r"
            else ok = "|cffffd100" .. T("KT_LATE_SHORT", "嗜血 %s 后转好"):format(fmtMMSS(readyIn)) .. "|r" end
            f.line1:SetText(("|cff00ccff%s|r %s %s %s %s"):format(
                T("KT_NEXT", "下个嗜血点"), segName(nxt), ev, etaTxt, ok))
        else
            f.line1:SetText(("|cff00ccff%s|r %s %s %s"):format(
                T("KT_HOLD", "留爆发·嗜血点"), segName(nxt), ev, etaTxt))
        end
        maybeCall(nxt, alt, eta, readyIn, sid)
    else
        f.line1:SetText("|cffaaaaaa" .. T("KT_NO_MORE", "顶尖局共识嗜血点已全部走过") .. "|r")
    end

    -- 时间轴打点
    for i, b in ipairs(d.bosses) do placeMark(f.bossMarks[i], b[4] * 60, 0) end
    for i = #d.bosses + 1, #f.bossMarks do f.bossMarks[i]:Hide() end
    local li = 0
    for _, p in ipairs(plan) do
        if p.pct >= 40 then
            li = li + 1
            local m = f.lustMarks[li]
            if m then
                placeMark(m, p.medMin * 60, 8)
                m:SetAlpha(pointPassed(p, elapsed) and 0.35 or 1)
            end
        end
    end
    for i = li + 1, #f.lustMarks do f.lustMarks[i]:Hide() end
    placeMark(f.cursor, elapsed, 0)

    -- 第二行：进度 vs 顶尖
    if killed > 0 and d.bosses[killed] and killTimes[killed] then
        local b = d.bosses[killed]
        local diff = killTimes[killed] - b[5] * 60
        local col = diff > 0 and "|cffff7070+" or "|cff40ff40-"
        f.line2:SetText(T("KT_PACE", "%s：你 %s · 顶尖 %s（%s%s|r）"):format(
            lg and lg.spellName(0, b[2], b[3]) or b[2], fmtMMSS(killTimes[killed]), fmtMMSS(b[5] * 60),
            col, fmtMMSS(math.abs(diff))))
    elseif d.bosses[killed + 1] then
        local b = d.bosses[killed + 1]
        f.line2:SetText(T("KT_PACE_FIRST", "顶尖局 %s 到 %s"):format(
            fmtMMSS(b[4] * 60), lg and lg.spellName(0, b[2], b[3]) or b[2]))
    else
        f.line2:SetText("")
    end
    f:Show()
    -- 第一次在钥匙里露面时说一句怎么关 / 怎么挪（bug #114：玩家「进本以后那个嗜血进度条怎么关闭啊」，
    -- 开关藏在实用工具→副本攻略里，没人找得到）。只说一次，记进 DB。
    if GearInsightDB and not GearInsightDB.ktHintShown then
        GearInsightDB.ktHintShown = true
        GearInsight:Print(T("KT_FIRST_HINT", "钥匙时间轴已显示。关闭：/gi kt off；挪位置：/gi kt unlock；也可在 实用工具 → 副本攻略 里取消勾选。"))
    end
end

-- 出错要看得见（bug #109 之前是每秒静默炸一次，玩家只看到"没有那个爆发轴"）
local _updErr = false
local function safeUpdate()
    local ok, err = pcall(update)
    if not ok and not _updErr then
        _updErr = true
        GearInsight:Print("|cffff5555" .. T("KT_ERR", "钥匙时间轴出错（已停止刷新，请把这行发给作者）：") .. "|r " .. tostring(err))
    end
end

-- /gi kt debug：一键诊断（群里排查用）
function GearInsight:KeyTimelineDebug()
    local name, itype, diff = GetInstanceInfo()
    local active = C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive and C_ChallengeMode.IsChallengeModeActive()
    local sid = myLustSpell()
    local secretCd = "-"
    if sid and C_Spell and C_Spell.GetSpellCooldown then
        local ok, cd = pcall(C_Spell.GetSpellCooldown, sid)
        secretCd = (not ok) and "call-error" or (cd and ((isSecret(cd.startTime) or isSecret(cd.duration)) and "SECRET" or "ok") or "nil")
    end
    local lines = {
        ("kt: instance=%s type=%s diff=%s keyActive=%s"):format(tostring(name), tostring(itype), tostring(diff), tostring(active)),
        ("kt: data=%s resolved=%s off=%s unlocked=%s hudShown=%s"):format(
            tostring(GearInsightDungeonData ~= nil), tostring(d ~= nil),
            tostring(GearInsightDB and GearInsightDB.keyTimelineOff or false), tostring(unlocked),
            tostring(hud and hud:IsShown() or false)),
        ("kt: lustSpell=%s cooldownRead=%s lastError=%s"):format(tostring(sid), secretCd, tostring(_updErr)),
    }
    for _, l in ipairs(lines) do GearInsight:Print(l) end
end

local function start()
    -- 同一把钥匙里的子区域切换（ZONE_CHANGED_NEW_AREA）不许重置：否则 killTimes/预告全丢
    local name = GetInstanceInfo()
    local stillActive = C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive
        and C_ChallengeMode.IsChallengeModeActive()
    if d and name == curName and stillActive then
        update()
        return
    end
    resolve()
    curName = d and name or nil
    if d then
        ensureHud()
        if not ticker then ticker = C_Timer.NewTicker(1, safeUpdate) end
        -- ⛔ 这里必须走 safeUpdate：直接调 update() 出错会**静默**（多数玩家关着脚本错误），
        --   玩家只看到「没有那个条」，而报错早就发生在进本第一帧。
        safeUpdate()
    else
        if hud then hud:Hide() end
        if ticker then ticker:Cancel(); ticker = nil end
    end
end

-- ── 对外 ──────────────────────────────────────────────────────────────
function GearInsight:KeyTimelineLust(on, expire)
    lustOn = on and true or false
    lustExpire = expire or 0
    if not d then return end
    if on then
        -- 嗜血亮了 = 这一轮的点位已经用掉：把「下一个」和它同一次的备选都记为已过，
        -- 否则开门开完还会显示「下个嗜血点 开门波 ✗嗜血 9:18 后转好」
        local nxt = nextPoint(elapsedSec())
        if nxt then
            for _, p in ipairs(plan) do
                if p.ord == nxt.ord then done[p.key] = true end
            end
        end
    end
    update()
end

function GearInsight:KeyTimelineRefresh()
    start()
    local lg = LG()
    if lg and lg.recheckLust then lg.recheckLust() end
end

-- ── 事件 ──────────────────────────────────────────────────────────────
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
f:RegisterEvent("CHALLENGE_MODE_START")
f:RegisterEvent("CHALLENGE_MODE_COMPLETED")
f:RegisterEvent("CHALLENGE_MODE_RESET")
f:RegisterEvent("SCENARIO_CRITERIA_UPDATE")
f:SetScript("OnEvent", function(_, event)
    if event == "SCENARIO_CRITERIA_UPDATE" then
        if d then refreshKills(elapsedSec()); update() end
        return
    end
    if event == "CHALLENGE_MODE_COMPLETED" or event == "CHALLENGE_MODE_RESET" then
        d = nil
        update()
        return
    end
    -- 进本瞬间 IsChallengeModeActive 可能还没翻真，延迟一拍再判
    C_Timer.After(1.5, start)
end)

-- 按需加载补跑（见 core/DungeonModule.lua 的 runBootHooks）：
-- 本模块按需加载，加载时进本事件已过，光注册事件要等到下一次进本才起作用。
if GearInsight._dgBootHooks then
    GearInsight._dgBootHooks[#GearInsight._dgBootHooks + 1] = function()
        C_Timer.After(1.5, start)
    end
end
