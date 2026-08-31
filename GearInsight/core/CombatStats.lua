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

local stats = { time = 0, fights = 0, casts = {}, aura = {} }
local active = {}        -- spellID -> 本段起点(GetTime)
local instMap = {}       -- auraInstanceID -> spellID（仅 HELPFUL，玩家自己）
local inCombat = false
local combatStart = 0

-- 12.0 secret values：他人施加的光环 spellId 是 secret number，不能做 table key/比较。
-- 这类光环不属于"自己的循环"统计范围，直接跳过。
local function isSecret(v)
    return issecretvalue and issecretvalue(v) or false
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
    if isSecret(updateInfo) then return end
    if not updateInfo or isSecret(updateInfo.isFullUpdate) or updateInfo.isFullUpdate then
        -- 全量更新：重建实例映射；战斗中给新出现的增益补记起点
        local prev = {}
        if inCombat then for id in pairs(active) do prev[id] = true end end
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
            if not isSecret(a) and not isSecret(a.isHelpful) and a.isHelpful
                and not isSecret(a.spellId) and not isSecret(a.auraInstanceID)
                and a.spellId and a.auraInstanceID then
                instMap[a.auraInstanceID] = a.spellId
                if inCombat and not active[a.spellId] then
                    active[a.spellId] = GetTime()
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
        combatStart = GetTime()
        snapshotAuras(combatStart)
    elseif event == "PLAYER_REGEN_ENABLED" then
        if inCombat then
            local now = GetTime()
            stats.time = stats.time + (now - combatStart)
            stats.fights = stats.fights + 1
            closeAuras(now)
        end
        inCombat = false
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        -- unit 固定 "player"；arg3 = spellID
        if inCombat and arg3 and not isSecret(arg3) then
            stats.casts[arg3] = (stats.casts[arg3] or 0) + 1
        end
    elseif event == "UNIT_AURA" then
        -- 兜底：12.1 保密期 payload 形态随上下文变化，逐字段守卫之外再包一层，
        -- 保证统计模块任何情况下都不把错误抛给玩家（丢几条统计无所谓）。
        pcall(onUnitAura, arg2)   -- arg2 = updateInfo
    end
end)

-- 读数（战斗中也能读：把进行中的时间/光环算到当前时刻）
function GearInsight_GetCombatStats()
    local t, aura = stats.time, {}
    for id, v in pairs(stats.aura) do aura[id] = v end
    if inCombat then
        local now = GetTime()
        t = t + (now - combatStart)
        for id, t0 in pairs(active) do aura[id] = (aura[id] or 0) + (now - t0) end
    end
    return { time = t, fights = stats.fights + (inCombat and 1 or 0),
             casts = stats.casts, aura = aura }
end

function GearInsight_CombatStatsReset()
    stats = { time = 0, fights = 0, casts = {}, aura = {} }
    wipe(active)
    if inCombat then
        combatStart = GetTime()
        snapshotAuras(combatStart)
    end
end
