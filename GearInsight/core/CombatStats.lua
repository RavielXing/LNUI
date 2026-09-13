-- CombatStats：本地统计玩家自己的实战数据，供「循环参考」做"你 vs 顶尖"对比。
-- 只在战斗中累计（PLAYER_REGEN_DISABLED→ENABLED）：
--   casts[spellID] = 施法次数（UNIT_SPELLCAST_SUCCEEDED，仅玩家自己）
--   aura[spellID]  = 自己身上增益的累计秒数（UNIT_AURA 增量 added/removed 配对；
--                    进战斗时已有的光环用 C_UnitAuras 快照补记起点；战斗结束统一收口）
--   time = 累计战斗秒数, fights = 场次
-- 会话级（不落盘）；GearInsight_CombatStatsReset() 手动清零（换内容场景时该清）。
-- 注：12.0 (Midnight) 起 CLEU 对插件关闭（注册即 ADDON_ACTION_FORBIDDEN），
--     故全部改用 unit 事件。开怪前的预读条施法不在战斗内，统计不到——
--     对 CPM/覆盖率这种比率指标影响可忽略。

local stats = { time = 0, fights = 0, casts = {}, aura = {}, auraEst = {}, secretTime = 0 }
local active = {}        -- spellID -> 本段起点(GetTime)
local instMap = {}       -- auraInstanceID -> spellID（仅 HELPFUL，玩家自己）
local inCombat = false
local combatStart = 0

-- 12.0 secret values：他人施加的光环 spellId 是 secret number，不能做 table key/比较。
-- 这类光环不属于"自己的循环"统计范围，直接跳过。
local function isSecret(v)
    return issecretvalue and issecretvalue(v) or false
end

-- ── 保密期兜底（2026-09-13，炎寒：副本里 BUFF 盯防全 0%）──
-- 12.1 副本/团本/大秘境里 UNIT_AURA payload 整体 secret，战斗中新出现的增益记不到。
-- 对策：平时（非保密期）从光环数据学每个增益的持续时间（按名字，落 SavedVars），
-- 保密期里按「施法 → 挂一段持续时间」推算覆盖，UI 标 ≈；学不到持续时间的显示 —。
local secretMode = false          -- 本场战斗里 UNIT_AURA 是否出现过 secret payload
local estActive = {}              -- name -> { t0, t1 } 推算中的一段
local function durCache()
    GearInsightDB = GearInsightDB or {}
    GearInsightDB.auraDur = GearInsightDB.auraDur or {}
    return GearInsightDB.auraDur
end
local function spellName(id)
    if not id or isSecret(id) then return nil end
    local ok, n = pcall(function() return C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id) or (GetSpellInfo and GetSpellInfo(id)) end)
    return ok and n or nil
end
local function estClose(name, now)
    local seg = estActive[name]
    if not seg then return end
    local t1 = math.min(seg[2], now)
    if t1 > seg[1] then stats.auraEst[name] = (stats.auraEst[name] or 0) + (t1 - seg[1]) end
    estActive[name] = nil
end
-- 从技能说明解析持续时间（多语言常见写法）；解析到就写进缓存
local DUR_PATTERNS = {
    "持续%s*(%d+%.?%d*)%s*秒", "持續%s*(%d+%.?%d*)%s*秒",           -- zh
    "for%s+(%d+%.?%d*)%s+sec", "lasts%s+(%d+%.?%d*)%s+sec",         -- en
    "(%d+%.?%d*)%s*Sek", "pendant%s+(%d+%.?%d*)%s*s", "durante%s+(%d+%.?%d*)%s*s",
    "(%d+%.?%d*)%s*сек", "(%d+%.?%d*)초",
}
local function durFromDesc(spellID, name)
    if not (C_Spell and C_Spell.GetSpellDescription) then return nil end
    local ok, desc = pcall(C_Spell.GetSpellDescription, spellID)
    if not ok or type(desc) ~= "string" or desc == "" then
        if C_Spell.RequestLoadSpellData then pcall(C_Spell.RequestLoadSpellData, spellID) end
        return nil
    end
    for _, pat in ipairs(DUR_PATTERNS) do
        local v = desc:match(pat)
        if v then
            local d = tonumber(v)
            if d and d > 0 and d < 120 then durCache()[name] = d; return d end
        end
    end
    return nil
end
local function estCast(spellID, now)
    local name = spellName(spellID)
    if not name then return end
    local dur = durCache()[name] or durFromDesc(spellID, name)
    if not dur or dur <= 0 then return end
    local seg = estActive[name]
    if seg and seg[2] >= now then
        seg[2] = now + dur          -- 刷新：顺延到新的到期时刻
    else
        if seg then estClose(name, now) end
        estActive[name] = { now, now + dur }
    end
end
local function estCloseAll(now)
    for name in pairs(estActive) do estClose(name, now) end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_REGEN_DISABLED")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
f:RegisterUnitEvent("UNIT_AURA", "player")

-- 同一 spellID 是否还有其他实例挂着（叠刷/多来源时避免提前收口）
local function spellStillActive(spellID)
    for _, sid in pairs(instMap) do
        if sid == spellID then return true end
    end
    return false
end

-- 12.1：按 index/slot/instanceID 访问光环的 C_UnitAuras 接口，在「光环保密期」
-- （战斗中 / 团本 / 大秘境 / PvP）被调用会**直接 Lua 报错**——不是返回 nil。
-- 而 PLAYER_REGEN_DISABLED 恰好就是保密期的起点，旧写法每次进战斗必炸。
-- 对策：枚举只在能成功的时候做（非保密期），失败就沿用上一次成功的快照；
-- 进战斗不再重新枚举，直接拿已知 instMap 补记起点。
local function enumerateAuras()
    if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then return false end
    local fresh = {}
    local ok = pcall(function()
        for i = 1, 80 do
            local a = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
            if isSecret(a) or not a then break end
            local sid, inst = a.spellId, a.auraInstanceID
            -- isSecret 必须先于真值测试：secret 值连 `sid and ...` 都会抛错，
            -- 那样一个他人施加的光环就能让整轮枚举作废。
            if not isSecret(sid) and not isSecret(inst) and sid and inst then
                fresh[inst] = sid
            end
        end
    end)
    if not ok then return false end   -- 保密期：保留上一次快照，不清空
    wipe(instMap)
    for inst, sid in pairs(fresh) do instMap[inst] = sid end
    return true
end

local function snapshotAuras(now)
    -- 重建 instMap（保密期失败则沿用旧快照）；战斗中给已挂增益补记起点
    enumerateAuras()
    if now then
        for _, sid in pairs(instMap) do
            if not active[sid] then active[sid] = now end
        end
    end
end

local function closeAuras(now)
    for id, t0 in pairs(active) do
        stats.aura[id] = (stats.aura[id] or 0) + (now - t0)
    end
    wipe(active)
end

local function onUnitAura(updateInfo)
    -- 12.1：保密期内 UNIT_AURA 的 payload 整体是 secret。issecretvalue 必须先于
    -- 一切真值测试跑——secret 值连 `not updateInfo` 都不保证安全（0.43.1 同款教训）。
    if isSecret(updateInfo) then
        if inCombat then secretMode = true end
        return
    end
    if not updateInfo or isSecret(updateInfo.isFullUpdate) or updateInfo.isFullUpdate then
        -- 全量更新：重建实例映射；战斗中给新出现的增益补记起点
        local prev = {}
        if inCombat then for id in pairs(active) do prev[id] = true end end
        -- 炎寒 2026-09-13 复测 0.81.0 仍 0%：副本里 UNIT_AURA 不是整包 secret，而是每次都 isFullUpdate=true，
        -- 走到这里枚举失败（保密期 C_UnitAuras 直接报错）→ 一条都记不上，且 secretMode 也没被置上。这里补判。
        if inCombat and not enumerateAuras() then secretMode = true end
        snapshotAuras(inCombat and GetTime() or nil)
        if inCombat then
            -- 快照后消失的增益收口
            local now = GetTime()
            for id, t0 in pairs(active) do
                if not spellStillActive(id) and not prev[id] then
                    -- 不应发生（snapshotAuras 只增不删 active），保险
                    stats.aura[id] = (stats.aura[id] or 0) + (now - t0)
                    active[id] = nil
                end
            end
        end
        return
    end
    if updateInfo.addedAuras and not isSecret(updateInfo.addedAuras) then
        for _, a in ipairs(updateInfo.addedAuras) do
            if inCombat and (isSecret(a) or isSecret(a.spellId)) then secretMode = true end
            if not isSecret(a) and not isSecret(a.isHelpful) and a.isHelpful
                and not isSecret(a.spellId) and not isSecret(a.auraInstanceID)
                and a.spellId and a.auraInstanceID then
                instMap[a.auraInstanceID] = a.spellId
                if inCombat and not active[a.spellId] then
                    active[a.spellId] = GetTime()
                end
                -- 非保密期：学持续时间（按名字缓存，保密期推算用）
                if not isSecret(a.duration) and a.duration and a.duration > 0 and a.duration < 120 then
                    local nm = spellName(a.spellId)
                    if nm then durCache()[nm] = a.duration end
                end
            end
        end
    end
    if updateInfo.removedAuraInstanceIDs and not isSecret(updateInfo.removedAuraInstanceIDs) then
        for _, instID in ipairs(updateInfo.removedAuraInstanceIDs) do
            local spellID = not isSecret(instID) and instMap[instID] or nil
            if spellID then
                instMap[instID] = nil
                local t0 = active[spellID]
                if t0 and not spellStillActive(spellID) then
                    stats.aura[spellID] = (stats.aura[spellID] or 0) + (GetTime() - t0)
                    active[spellID] = nil
                end
            end
        end
    end
end

f:SetScript("OnEvent", function(_, event, unit, arg2, arg3)
    if event == "PLAYER_LOGIN" then
        snapshotAuras(nil)
    elseif event == "PLAYER_REGEN_DISABLED" then
        inCombat = true
        secretMode = false
        combatStart = GetTime()
        snapshotAuras(combatStart)
    elseif event == "PLAYER_REGEN_ENABLED" then
        if inCombat then
            local now = GetTime()
            stats.time = stats.time + (now - combatStart)
            stats.fights = stats.fights + 1
            closeAuras(now)
            estCloseAll(now)
            if secretMode then stats.secretTime = stats.secretTime + (now - combatStart) end
        end
        inCombat = false
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        -- unit 固定 "player"；arg3 = spellID
        if inCombat and arg3 and not isSecret(arg3) then
            stats.casts[arg3] = (stats.casts[arg3] or 0) + 1
            estCast(arg3, GetTime())   -- 保密期兜底：按施法推算增益覆盖（非保密期也记，读数时按需取用）
        end
    elseif event == "UNIT_AURA" then
        -- 兜底：12.1 保密期 payload 形态随上下文变化，逐字段守卫之外再包一层，
        -- 保证统计模块任何情况下都不把错误抛给玩家（丢几条统计无所谓）。
        pcall(onUnitAura, arg2)   -- arg2 = updateInfo
    end
end)

-- 读数（战斗中也能读：把进行中的时间/光环算到当前时刻）
function GearInsight_GetCombatStats()
    local t, aura, est = stats.time, {}, {}
    for id, v in pairs(stats.aura) do aura[id] = v end
    for nm, v in pairs(stats.auraEst) do est[nm] = v end
    local secretT = stats.secretTime
    if inCombat then
        local now = GetTime()
        t = t + (now - combatStart)
        for id, t0 in pairs(active) do aura[id] = (aura[id] or 0) + (now - t0) end
        for nm, seg in pairs(estActive) do
            local t1 = math.min(seg[2], now)
            if t1 > seg[1] then est[nm] = (est[nm] or 0) + (t1 - seg[1]) end
        end
        if secretMode then secretT = secretT + (now - combatStart) end
    end
    return { time = t, fights = stats.fights + (inCombat and 1 or 0),
             casts = stats.casts, aura = aura, auraEst = est, secretTime = secretT }
end

function GearInsight_CombatStatsReset()
    stats = { time = 0, fights = 0, casts = {}, aura = {}, auraEst = {}, secretTime = 0 }
    wipe(active); wipe(estActive)
    if inCombat then
        combatStart = GetTime()
        snapshotAuras(combatStart)
    end
end
