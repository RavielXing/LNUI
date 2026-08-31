-- 临场提示（LiveGuide）：大米攻略的"到怪面前"层。
--   ① 姓名板出现 → 反查 npcID → 侧边卡片列出当前敌人的必断/致死/重伤技能（带真实数据标签）
--   ② 敌方开始读条且命中库 → 屏幕中上高亮：必断(≥75%)大字+你的打断CD状态 / 高优(≥40%) / 致死躲避
-- 数据全部复用 core/DungeonData.lua（kicks/killers/heavy + npcs/bossNpcs，generate_dungeon_lua.py 生成）。
-- 12.0 (Midnight)：CLEU 对插件关闭 → 全走 nameplate unit 事件；
-- 所有事件入参 spellID 过 issecretvalue()（他人相关值可能是 secret，见 CombatStats 同款防护）。
GearInsight = GearInsight or {}
-- ⭐ 语言只能从 GearInsight.LOCALE 取（locales/zhCN.lua 里定的唯一真相源）。
-- ⛔别再写 GetLocale()：每个文件各抄一份就会出现“面板英文、大米攻略中文”这种分裂。
local _LOCALE = GearInsight and GearInsight.LOCALE or (GetLocale and GetLocale()) or "enUS"
local function T(key, zh)
    if _LOCALE == "zhCN" then return zh end
    local t = GearInsight.LOC and (GearInsight.LOC[_LOCALE] or GearInsight.LOC["enUS"])
    return (t and t[key]) or zh
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
    local cd = C_Spell.GetSpellCooldown(sid)
    if not cd then return nil end
    local rem = (cd.startTime or 0) + (cd.duration or 0) - GetTime()
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
local lustNpc = {}          -- 嗜血点位 npcID -> {pct, boss}
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
    wipe(lustNpc)
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
            for _, k in ipairs(d.lust or {}) do
                if k[1] > 0 then lustNpc[k[1]] = { pct = k[5], boss = k[4] } end
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
    local seen, list, bossUnit, lustPct = {}, {}, nil, nil
    for unit, npcID in pairs(plates) do
        if (active.bossNpcs or {})[npcID] and not bossUnit then bossUnit = unit end
        local lp = lustNpc[npcID]
        if lp and (not lustPct or lp.pct > lustPct) then lustPct = lp.pct end
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
    -- [嗜血点]：嗜血监控开着 + 这波是顶尖局共识嗜血点 + 你没疲惫、嗜血未激活
    if lustPct and GearInsightDB and GearInsightDB.lustBarOn
        and not hasAnyAura(SATED) and not hasAnyAura(LUST_BUFFS) then
        list[#list + 1] = { w = 5000, kind = "lust", pct = lustPct }
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
            if it.kind == "lust" then
                r:SetText(("|cff00ccff[%s]|r %s"):format(T("LG_LUST_POINT", "嗜血点"),
                    T("LG_LUST_POINT_FMT", "顶尖局 %d%% 在这波开"):format(it.pct)))
            else
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

-- ── 嗜血窗口条：倒计时 + 你的爆发技能就绪状态 ─────────────────────────
-- lustBarOn 是嗜血监控总开关（默认关）：关着时 UNIT_AURA 嗜血监听、
-- 卡片[嗜血点]行、窗口条全部不生效，勾选后一并开启
local lustBar, lustExpire, lustTicker
local lustActive = false

local function ensureLustBar()
    if lustBar then return lustBar end
    local f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    f:SetSize(320, 64)
    f:SetPoint("TOP", UIParent, "TOP", 0, -244)   -- 在读条高亮(-170)下方，不打架
    f:SetFrameStrata("HIGH")
    f:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background" })
    f:SetBackdropColor(0.05, 0.02, 0.02, 0.6)
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.title:SetPoint("TOP", 0, -4)
    f.icons = {}
    for i = 1, 6 do
        local b = CreateFrame("Frame", nil, f)
        b:SetSize(28, 28)
        b:SetPoint("TOPLEFT", 14 + (i - 1) * 50, -28)
        b.tex = b:CreateTexture(nil, "ARTWORK")
        b.tex:SetAllPoints()
        b.cd = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        b.cd:SetPoint("TOP", b, "BOTTOM", 0, -1)
        f.icons[i] = b
    end
    f:Hide()
    lustBar = f
    return f
end

local function updateLustBar()
    if not lustBar or not lustBar:IsShown() then return end
    local rem = (lustExpire or 0) - GetTime()
    if rem <= 0 then
        lustBar:Hide()
        if lustTicker then lustTicker:Cancel(); lustTicker = nil end
        return
    end
    lustBar.title:SetText(("|cffff5050%s|r |cffffd100%ds|r"):format(
        T("LG_LUST_TITLE", "嗜血窗口·压满爆发"), math.ceil(rem)))
    for i, b in ipairs(lustBar.icons) do
        local sid = bursts[i]
        if sid then
            b.tex:SetTexture(C_Spell.GetSpellTexture(sid))
            local cd = C_Spell.GetSpellCooldown and C_Spell.GetSpellCooldown(sid)
            local cdRem = cd and ((cd.startTime or 0) + (cd.duration or 0) - GetTime()) or 0
            if cdRem > 1.5 then          -- GCD 不算 CD
                b.tex:SetDesaturated(true)
                b.cd:SetText(("|cffff7070%ds|r"):format(math.ceil(cdRem)))
            else
                b.tex:SetDesaturated(false)
                b.cd:SetText("|cff40ff40✓|r")
            end
            b:Show()
        else
            b:Hide()
        end
    end
end

local function onAuraMaybeLust()
    local a = hasAnyAura(LUST_BUFFS)
    if a and not lustActive then
        lustActive = true
        if GearInsightDB and GearInsightDB.lustBarOn then
            if #bursts == 0 then computeBursts() end
            lustExpire = a.expirationTime or (GetTime() + 40)
            ensureLustBar():Show()
            updateLustBar()
            if lustTicker then lustTicker:Cancel() end
            lustTicker = C_Timer.NewTicker(0.25, updateLustBar)
        end
        scheduleCard()   -- 嗜血激活后卡片上的[嗜血点]行该消失
    elseif not a and lustActive then
        lustActive = false
        if lustBar and lustBar:IsShown() then
            lustExpire = 0
            updateLustBar()
        end
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
f:SetScript("OnEvent", function(_, event, unit, arg2, arg3)
    if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        resolveDungeon()
        computeBursts()
        wipe(plates); wipe(npcCount); wipe(lastAlert)
        scheduleCard()
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        if unit == "player" or not unit then computeBursts() end
    elseif event == "UNIT_AURA" then
        -- 嗜血监控默认关闭，勾选 lustBarOn 后才在副本内生效
        if GearInsightDB and GearInsightDB.lustBarOn and not GearInsightDB.liveGuideOff then
            local _, instanceType = GetInstanceInfo()
            if instanceType == "party" or instanceType == "raid" then
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

-- 嗜血监控开关变化后由 DungeonGuide 的勾选框调用
function GearInsight:LustBarRefresh()
    if GearInsightDB and GearInsightDB.lustBarOn then
        lustActive = false      -- 若嗜血正进行中，让下一次检查立刻补显
        onAuraMaybeLust()
    else
        if lustTicker then lustTicker:Cancel(); lustTicker = nil end
        if lustBar then lustBar:Hide() end
        lustActive = false
    end
    scheduleCard()              -- 卡片[嗜血点]行随开关即时增删
end

-- 设置项变化后由 DungeonGuide 的勾选框调用
function GearInsight:LiveGuideRefresh()
    resolveDungeon()
    if not active then
        wipe(plates); wipe(npcCount)
    end
    scheduleCard()
end
