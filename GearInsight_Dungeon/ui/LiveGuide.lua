-- 临场提示（LiveGuide）：大米攻略的"到怪面前"层。
--   ① 姓名板出现 → 反查 npcID → 侧边卡片列出当前敌人的必断/致死/重伤技能（带真实数据标签）
--   ② 敌方开始读条且命中库 → 屏幕中上高亮：必断(≥75%)大字+你的打断CD状态 / 高优(≥40%) / 致死躲避
--   ③ 嗜血/疲惫光环与爆发技能识别在这里做，显示交给 ui/KeyTimeline.lua（钥匙时间轴）。
--      2026-09-04：旧的「嗜血窗口条」与卡片[嗜血点]行已移除——它们按姓名板触发（太晚）、
--      按 WCL pull 名匹配 NPC（全本反复出现的小怪 = 假阳性），玩家反馈后 0.55 已默认关。
-- 数据全部复用 core/DungeonData.lua（kicks/killers/heavy + npcs/bossNpcs，generate_dungeon_lua.py 生成）。
-- 12.0 (Midnight)：CLEU 对插件关闭 → 全走 nameplate unit 事件；
-- 所有事件入参 spellID 过 issecretvalue()（他人相关值可能是 secret，见 CombatStats 同款防护）。
GearInsight = GearInsight or {}
-- ⭐ 语言只能从 GearInsight.LOCALE 取（locales/zhCN.lua 里定的唯一真相源）。
-- ⛔别再写 GetLocale()：每个文件各抄一份就会出现“面板英文、大米攻略中文”这种分裂。
local _LOCALE = GearInsight and GearInsight.LOCALE or (GetLocale and GetLocale()) or "enUS"
local function T(key, zh)
    if _LOCALE == "zhCN" then return zh end
    -- 逐级回退：当前语言 -> enUS -> 内联中文。与 GearInsight.lua 里的实现保持一致。
    -- ⛔别写回 `LOC[_LOCALE] or LOC["enUS"]` —— 那是**选表不选值**：
    --   只要 deDE 表存在但缺某个 key，就直接掉回简体中文，而不会先试英文，
    --   德/法/韩客户端会看到「大部分本地语言 + 零星简体中文」。
    -- ⚠繁中例外：缺 key 时回退到**简体**而不是英文（繁简互通，比英文可用）。
    local L = GearInsight.LOC or {}
    local cur = L[_LOCALE]
    if cur and cur[key] then return cur[key] end
    if _LOCALE ~= "zhTW" then
        local en = L["enUS"]
        if en and en[key] then return en[key] end
    end
    return zh
end

local function isSecret(v)
    return issecretvalue and issecretvalue(v) or false
end

local function spellName(sid, cn, en)
    if sid and sid > 1 and C_Spell and C_Spell.GetSpellName then
        local n = C_Spell.GetSpellName(sid)
        if n and n ~= "" then return n end
    end
    if _LOCALE == "zhCN" or _LOCALE == "zhTW" then
        return (_LOCALE == "zhTW" and GearInsight.S2T) and GearInsight.S2T(cn) or cn
    end
    return (en ~= "" and en) or cn
end

local function spellIcon(sid, size)
    size = size or 14
    if sid and sid > 1 and C_Spell and C_Spell.GetSpellTexture then
        local tex = C_Spell.GetSpellTexture(sid)
        if tex then return ("|T%s:%d:%d:0:0|t "):format(tex, size, size) end
    end
    return ""
end

-- ── 各职业打断技能（IsPlayerSpell 取第一个已学的）─────────────────────
local CLASS_KICKS = {
    WARRIOR = { 6552 }, PALADIN = { 96231 }, HUNTER = { 147362, 187707 },
    ROGUE = { 1766 }, PRIEST = { 15487 }, DEATHKNIGHT = { 47528 },
    SHAMAN = { 57994 }, MAGE = { 2139 }, WARLOCK = { 19647, 119910 },
    MONK = { 116705 }, DRUID = { 106839 }, DEMONHUNTER = { 183752 },
    EVOKER = { 351338 },
}
local function myKickSpell()
    local _, cls = UnitClass("player")
    for _, sid in ipairs(CLASS_KICKS[cls] or {}) do
        if IsPlayerSpell and IsPlayerSpell(sid) then return sid end
    end
end
local function kickRemaining(sid)
    if not (sid and C_Spell and C_Spell.GetSpellCooldown) then return nil end
    local ok, cd = pcall(C_Spell.GetSpellCooldown, sid)
    if not ok or not cd then return nil end
    -- 12.x 副本里 startTime/duration 可能是 secret（bug #109 同款），碰到就当读不到
    if isSecret(cd.startTime) or isSecret(cd.duration) or type(cd.duration) ~= "number" then return nil end
    local rem = (type(cd.startTime) == "number" and cd.startTime or 0) + cd.duration - GetTime()
    return rem > 0.5 and rem or 0
end

-- ── 嗜血/爆发协同 ──────────────────────────────────────────────────────
-- secret 安全：用 GetPlayerAuraBySpellID(已知ID) 查询，绝不枚举光环读 spellId。
local LUST_BUFFS = { 2825, 32182, 80353, 264667, 390386 }   -- 嗜血/英勇/时间扭曲/原始狂怒/飞龙振翅
local SATED = { 57724, 57723, 80354, 264689 }               -- 筋疲力尽/心满意足/时空错位/疲惫
local BURST_EXCLUDE = {                                      -- 非输出爆发的长CD（防误入图标排）
    [48707] = true,  -- 反魔法护罩
    [48792] = true,  -- 冰封之韧
    [871]   = true,  -- 盾墙
}

local function hasAnyAura(ids)
    if not (C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID) then return nil end
    for _, id in ipairs(ids) do
        local a = C_UnitAuras.GetPlayerAuraBySpellID(id)
        if a then return a end
    end
    return nil
end

-- 当前专精的大爆发：顶尖玩家实际在用的技能(RotationData) × 基础CD≥2分钟 × 已学
local bursts = {}
local function computeBursts()
    wipe(bursts)
    local rot
    local specID = GetSpecialization and GetSpecializationInfo
        and select(1, GetSpecializationInfo(GetSpecialization() or 0))
    if specID and GearInsightRotation then
        for _, v in pairs(GearInsightRotation) do
            if v.specID == specID then rot = v break end
        end
    end
    local src = rot and ((rot.mplus and rot.mplus.core) or (rot.raid and rot.raid.core))
    for _, c in ipairs(src or {}) do
        local sid = c[1]
        if sid and not BURST_EXCLUDE[sid] and IsPlayerSpell and IsPlayerSpell(sid) then
            local cd = GetSpellBaseCooldown and (GetSpellBaseCooldown(sid)) or 0
            if cd and cd >= 120000 then bursts[#bursts + 1] = sid end
        end
        if #bursts >= 6 then break end
    end
end

-- ── 副本/数据状态 ──────────────────────────────────────────────────────
local active = nil          -- 当前副本的 DungeonData 条目
local kickBy, killerBy, heavyBy = {}, {}, {}
local plates = {}           -- nameplate unit -> npcID
local npcCount = {}         -- npcID -> 数量
local cardDirty = false

local function npcIDFromUnit(unit)
    local guid = UnitGUID(unit)
    if not guid or isSecret(guid) then return nil end
    local id = select(6, strsplit("-", guid))
    return id and tonumber(id) or nil
end

local function resolveDungeon()
    active, kickBy, killerBy, heavyBy = nil, {}, {}, {}
    if GearInsightDB and GearInsightDB.liveGuideOff then return end
    local data = GearInsightDungeonData
    if not data then return end
    local name, instanceType, difficultyID = GetInstanceInfo()
    if instanceType ~= "party" or not name then return end
    if difficultyID ~= 8 and difficultyID ~= 23 then return end
    for _, d in ipairs(data) do
        if d.cn == name or d.en == name then
            active = d
            for _, k in ipairs(d.kicks or {}) do
                if k[1] > 1 then kickBy[k[1]] = k end       -- {sid,cn,en,rate,begun,srcCn,srcEn,boss}
            end
            for _, k in ipairs(d.killers or {}) do
                if k[1] > 1 then killerBy[k[1]] = k end     -- {sid,cn,en,deaths}
            end
            for _, k in ipairs(d.heavy or {}) do
                if k[1] > 1 then heavyBy[k[1]] = k end      -- {sid,cn,en,share}
            end
            return
        end
    end
end

-- ── 关注点卡片 ─────────────────────────────────────────────────────────
local card
local CARD_MAX_ROWS = 7

local function ensureCard()
    if card then return card end
    card = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    card:SetSize(250, 40)
    card:SetFrameStrata("MEDIUM")
    card:SetClampedToScreen(true)
    local pos = GearInsightDB and GearInsightDB.liveGuidePos
    if pos and pos.point then
        card:SetPoint(pos.point, UIParent, pos.point, pos.x or 0, pos.y or 0)
    else
        card:SetPoint("RIGHT", UIParent, "RIGHT", -60, 120)
    end
    card:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background" })
    card:SetBackdropColor(0.04, 0.04, 0.07, 0.78)
    card:EnableMouse(true)
    card:SetMovable(true)
    card:RegisterForDrag("LeftButton")
    card:SetScript("OnDragStart", function(s) s:StartMoving() end)
    card:SetScript("OnDragStop", function(s)
        s:StopMovingOrSizing()
        local point, _, _, x, y = s:GetPoint()
        GearInsightDB = GearInsightDB or {}
        GearInsightDB.liveGuidePos = { point = point, x = x, y = y }
    end)
    card.title = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    card.title:SetPoint("TOPLEFT", 8, -6)
    card.rows = {}
    for i = 1, CARD_MAX_ROWS do
        local r = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        r:SetPoint("TOPLEFT", 8, -6 - 17 * i)
        r:SetJustifyH("LEFT")
        r:SetWidth(236)
        r:SetWordWrap(false)
        card.rows[i] = r
    end
    card:Hide()
    return card
end

local function refreshCard()
    cardDirty = false
    if not active then
        if card then card:Hide() end
        return
    end
    -- 视野内 npc → 关注技能集合；boss 在场则标题切 boss
    local seen, list, bossUnit = {}, {}, nil
    for unit, npcID in pairs(plates) do
        if (active.bossNpcs or {})[npcID] and not bossUnit then bossUnit = unit end
        for _, sid in ipairs((active.npcs or {})[npcID] or {}) do
            if not seen[sid] then
                seen[sid] = true
                local k = kickBy[sid]
                if k and k[4] >= 25 then
                    -- 排序权重：必断 3000+率，高优 2000+率
                    local w = (k[4] >= 75 and 3000 or (k[4] >= 40 and 2000 or 1000)) + k[4]
                    list[#list + 1] = { sid = sid, w = w, kind = "kick", d = k }
                elseif killerBy[sid] then
                    list[#list + 1] = { sid = sid, w = 500 + killerBy[sid][4], kind = "killer", d = killerBy[sid] }
                elseif heavyBy[sid] then
                    list[#list + 1] = { sid = sid, w = heavyBy[sid][4], kind = "heavy", d = heavyBy[sid] }
                end
            end
        end
    end
    if #list == 0 then
        if card then card:Hide() end
        return
    end
    table.sort(list, function(a, b) return a.w > b.w end)

    local c = ensureCard()
    if bossUnit then
        local bn = UnitName(bossUnit)
        c.title:SetText("|cffff8000" .. T("DG_BOSS", "[BOSS]") .. "|r " .. (not isSecret(bn) and bn or ""))
    else
        c.title:SetText("|cffffd100" .. T("LG_TITLE", "临场关注点") .. "|r")
    end
    local shown = 0
    for i = 1, CARD_MAX_ROWS do
        local it = list[i]
        local r = c.rows[i]
        if it then
            shown = shown + 1
            do
                local nm = spellIcon(it.sid) .. spellName(it.sid, it.d[2], it.d[3])
                if it.kind == "kick" then
                    local rate = it.d[4]
                    local tag, cr, cg, cb
                    if rate >= 75 then tag, cr, cg, cb = T("DG_KICK_MUST", "必断"), 1, 0.25, 0.25
                    elseif rate >= 40 then tag, cr, cg, cb = T("DG_KICK_HIGH", "高优"), 1, 0.6, 0.15
                    else tag, cr, cg, cb = T("DG_KICK_MED", "有余力断"), 1, 0.85, 0.3 end
                    r:SetText(("|cff%02x%02x%02x[%s]|r %s |cffaaaaaa%d%%|r"):format(
                        cr * 255, cg * 255, cb * 255, tag, nm, rate))
                elseif it.kind == "killer" then
                    r:SetText(("|cffff4040[%s]|r %s |cffaaaaaa%d%s|r"):format(
                        T("LG_KILLER", "致死"), nm, it.d[4], T("DG_DEATHS", "死")))
                else
                    r:SetText(("|cffffc040[%s]|r %s |cffaaaaaa%d%%|r"):format(
                        T("LG_HEAVY", "重伤"), nm, it.d[4]))
                end
            end
            r:Show()
        else
            r:Hide()
        end
    end
    c:SetHeight(14 + 17 * (shown + 1))
    c:Show()
end

local function scheduleCard()
    if cardDirty then return end
    cardDirty = true
    C_Timer.After(0.2, refreshCard)
end

-- ── 读条高亮 ───────────────────────────────────────────────────────────
local alertFrame, alertHideTimer
local lastAlert = {}        -- spellID -> GetTime()

local function ensureAlert()
    if alertFrame then return alertFrame end
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetSize(560, 64)
    f:SetPoint("TOP", UIParent, "TOP", 0, -170)
    f:SetFrameStrata("HIGH")
    f.main = f:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    f.main:SetPoint("TOP", 0, 0)
    f.sub = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.sub:SetPoint("TOP", f.main, "BOTTOM", 0, -4)
    f:Hide()
    alertFrame = f
    return f
end

local function showAlert(mainText, subText, dur)
    local f = ensureAlert()
    f.main:SetText(mainText)
    f.sub:SetText(subText or "")
    f:Show()
    f:SetAlpha(1)
    if alertHideTimer then alertHideTimer:Cancel() end
    alertHideTimer = C_Timer.NewTimer(dur or 2.5, function()
        UIFrameFadeOut(f, 0.4, 1, 0)
        C_Timer.After(0.45, function() f:Hide() end)
    end)
end

local function onEnemyCast(unit, spellID)
    if not active or not spellID or isSecret(spellID) then return end
    local now = GetTime()
    if lastAlert[spellID] and now - lastAlert[spellID] < 4 then return end

    local k = kickBy[spellID]
    if k and k[4] >= 75 then
        lastAlert[spellID] = now
        local sub
        local ks = myKickSpell()
        if ks then
            local rem = kickRemaining(ks)
            if rem and rem > 0 then
                sub = ("|cffff7070%s|r"):format(T("LG_KICK_CD", "你的打断还有 %.1f 秒"):format(rem))
            else
                sub = "|cff40ff40" .. T("LG_KICK_READY", "你的打断已就绪") .. "|r"
            end
        end
        showAlert(("|cffff3030%s%s%s|r"):format(
            T("LG_MUST", "必断："), spellIcon(spellID, 24), spellName(spellID, k[2], k[3])), sub)
        return
    end
    if k and k[4] >= 40 then
        lastAlert[spellID] = now
        showAlert(("|cffff9926%s%s%s|r |cffaaaaaa%d%%|r"):format(
            T("LG_HIGH", "高优打断："), spellIcon(spellID, 24), spellName(spellID, k[2], k[3]), k[4]), nil, 2)
        return
    end
    local kl = killerBy[spellID]
    if kl and kl[4] >= 2 then
        lastAlert[spellID] = now
        showAlert(("|cffff5050%s%s%s|r"):format(
            T("LG_DODGE", "躲/减伤："), spellIcon(spellID, 24), spellName(spellID, kl[2], kl[3])),
            ("|cffaaaaaa%s|r"):format(T("LG_KILLER_SUB", "顶尖局 %d 次死亡元凶"):format(kl[4])), 2.2)
    end
end

-- ── 嗜血光环监听（显示在 KeyTimeline）───────────────────────────────
local lustActive = false

local function onAuraMaybeLust()
    local a = hasAnyAura(LUST_BUFFS)
    if a and not lustActive then
        lustActive = true
        if #bursts == 0 then computeBursts() end
        if GearInsight.KeyTimelineLust then
            GearInsight:KeyTimelineLust(true, a.expirationTime or (GetTime() + 40))
        end
    elseif not a and lustActive then
        lustActive = false
        if GearInsight.KeyTimelineLust then GearInsight:KeyTimelineLust(false) end
    end
end

-- ── 事件 ───────────────────────────────────────────────────────────────
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
f:RegisterEvent("NAME_PLATE_UNIT_ADDED")
f:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
f:RegisterEvent("UNIT_SPELLCAST_START")
f:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
f:RegisterUnitEvent("UNIT_AURA", "player")
f:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
-- ⭐ 抽成具名函数：本模块按需加载，加载时 PLAYER_ENTERING_WORLD 已经过去了，
--    必须由 loader 在加载完成后补跑一次（见文件末尾的 boot hook），否则「装了但什么都不出」。
local function onEnterWorld()
    resolveDungeon()
    computeBursts()
    wipe(plates); wipe(npcCount); wipe(lastAlert)
    scheduleCard()
end

f:SetScript("OnEvent", function(_, event, unit, arg2, arg3)
    if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        onEnterWorld()
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        if unit == "player" or not unit then computeBursts() end
    elseif event == "UNIT_AURA" then
        -- 只在大秘境里看嗜血光环；钥匙时间轴关了就不看
        if not (GearInsightDB and GearInsightDB.keyTimelineOff) then
            local _, instanceType = GetInstanceInfo()
            if instanceType == "party" then
                onAuraMaybeLust()
            end
        end
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        if active and unit and UnitCanAttack("player", unit) then
            local id = npcIDFromUnit(unit)
            if id then
                plates[unit] = id
                npcCount[id] = (npcCount[id] or 0) + 1
                scheduleCard()
            end
        end
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        local id = unit and plates[unit]
        if id then
            plates[unit] = nil
            npcCount[id] = (npcCount[id] or 1) - 1
            if npcCount[id] <= 0 then npcCount[id] = nil end
            scheduleCard()
        end
    elseif event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
        -- arg3 = spellID；只看敌方姓名板单位
        if unit and type(unit) == "string" and unit:sub(1, 9) == "nameplate" and plates[unit] then
            onEnemyCast(unit, arg3)
        end
    end
end)

-- 给 KeyTimeline 复用的内部件（光环/爆发/提示/姓名板），避免两份拷贝各改各的
GearInsight.LG = {
    LUST_BUFFS = LUST_BUFFS, SATED = SATED,
    hasAnyAura = hasAnyAura, bursts = bursts, computeBursts = computeBursts,
    showAlert = showAlert, plates = plates,
    spellName = spellName, spellIcon = spellIcon, isSecret = isSecret,
    lustActive = function() return lustActive end,
    recheckLust = function()
        lustActive = false
        onAuraMaybeLust()
    end,
}

-- 设置项变化后由 DungeonGuide 的勾选框调用
function GearInsight:LiveGuideRefresh()
    resolveDungeon()
    if not active then
        wipe(plates); wipe(npcCount)
    end
    scheduleCard()
end

-- 按需加载补跑（见 core/DungeonModule.lua 的 runBootHooks）
if GearInsight._dgBootHooks then
    GearInsight._dgBootHooks[#GearInsight._dgBootHooks + 1] = onEnterWorld
end
