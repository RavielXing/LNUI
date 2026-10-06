-- GearInsight/main/Init.lua — 初始化 + 事件
-- 2026-09-22 从 GearInsight.lua 拆出（纯搬家，逻辑未动）。共用 helper 见 GearInsight.lua 末尾的 GearInsight.Helpers。
local H = GearInsight.Helpers
local T, _LOCALE = H.T, H.LOCALE

-- ── Init ─────────────────────────────────────────────────────────────
if not GearInsightDB then GearInsightDB = {} end

-- ── 默认值初始化（2026-10-05 用户需求：以下功能默认关闭）─────────────────
-- 只在键为 nil 时写默认；玩家之后在设置页手动改过的保留。
-- _defaultsV2 标记保证 A 类老存档只迁移一次：旧版本把它们默认写成 true，
-- 升级后第一次登录统一改为关闭，之后不再覆盖。
do
    local db = GearInsightDB
    -- B 类：代码里从未显式赋值（老存档里是 nil），直接给默认关闭值
    if db.dungeonAutoPopupOff == nil then db.dungeonAutoPopupOff = true end   -- 进本自动弹大米攻略：关
    if db.liveGuideOff         == nil then db.liveGuideOff         = true end -- 临场提示：关
    if db.keyTimelineOff       == nil then db.keyTimelineOff       = true end -- 钥匙时间轴：关
    if db.rollAdvice           == nil then db.rollAdvice           = false end -- Roll 币提醒：关
    if db.vaultPanelOff        == nil then db.vaultPanelOff        = true end -- 打开宏伟宝库时显示：关
    if db.wishAlertOff         == nil then db.wishAlertOff         = true end -- 心愿单掉落提醒：关
    -- A 类：老存档已被旧默认值写成 true，一次性纠正为关闭
    if not db._defaultsV2 then
        db._defaultsV2 = true
        if db.paperDollBis then db.paperDollBis.enabled = false end           -- 角色面板 BiS 图标：关
        if db.tooltipBis then
            db.tooltipBis.enabled   = false                                    -- 悬浮提示 BiS 行：关
            db.tooltipBis.showSource = false                                   -- 悬浮提示来源行：关
        end
    end
end
GearInsight.GearReader  = GearInsight.GearReader
GearInsight.StatReader  = GearInsight.StatReader
GearInsight.BisData     = GearInsight.BisData
GearInsight.SavedVars   = GearInsight.SavedVars
GearInsight.RecsReader  = GearInsight.RecsReader
-- 2026-09-04：这里原本有一段「同一 itemId 统一抬到全数据最高装等版本」的归一化，
-- 在**登录时**遍历全部 40 个专精的 bisBySlot。它已经挪到打包期做完
-- （services/wow-agent/bisdata_pack.py 的 normalize_raid_pool），BisData.lua 里存的就是归一后的值。
-- ⛔ 别在运行时恢复这段：它是全量遍历，一跑就把 core/BisPack.lua 的按需解码打穿，
--    40 个专精会在登录瞬间全部建表 —— 正是这次优化要消灭的东西。

if GearInsight.MinimapButton then
    pcall(GearInsight.MinimapButton.Create, GearInsight.MinimapButton, GearInsight)
end
if GearInsight.RegisterConfigCategory then
    pcall(GearInsight.RegisterConfigCategory, GearInsight)   -- ESC → 选项 → 插件 → GearInsight（设置总表）
end
if GearInsight.TooltipHook then
    pcall(GearInsight.TooltipHook.Create, GearInsight.TooltipHook, GearInsight)
end
if GearInsight.InspectBis then
    pcall(GearInsight.InspectBis.Create, GearInsight.InspectBis)
end
if GearInsight.GroupBisPanel then
    pcall(GearInsight.GroupBisPanel.Create, GearInsight.GroupBisPanel)
end
if GearInsight.GuildRosterPanel then
    pcall(GearInsight.GuildRosterPanel.Create, GearInsight.GuildRosterPanel)
end

-- Auto-refresh on events
local ef = CreateFrame("Frame")
ef:RegisterEvent("PLAYER_ENTERING_WORLD")
ef:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
ef:RegisterEvent("ACTIVE_PLAYER_SPECIALIZATION_CHANGED")
ef:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
ef:RegisterEvent("TRAIT_CONFIG_UPDATED")
ef:RegisterEvent("PLAYER_TALENT_UPDATE")
ef:RegisterEvent("TRAIT_CONFIG_LIST_UPDATED")
local _qqMsgShown = false
-- Deferred refresh used when an event fires in combat: CreateFrame and most UI
-- calls are blocked by combat lockdown. Schedule the update for after combat ends.
local _pendingRefresh = false
ef:RegisterEvent("PLAYER_REGEN_ENABLED")  -- fires when combat ends

-- 统一去抖：切专精时 5 个天赋事件会连环触发，一键换装时 PLAYER_EQUIPMENT_CHANGED
-- 每槽一发(最多16连发)——旧实现每发都跑完整 Save+RefreshPanel(天赋类还排两次)。
-- 现在所有事件只重置同一个 0.3s 计时器，风暴结束后刷一次；
-- 天赋类事件的 C_Traits 数据可能晚到，去抖刷新后再补一次跟刷。
local _refreshGen = 0
local _talentPending = false
local function scheduleRefresh(isTalent)
    if isTalent then _talentPending = true end
    _refreshGen = _refreshGen + 1
    local gen = _refreshGen
    C_Timer.After(0.3, function()
        if gen ~= _refreshGen then return end  -- 期间有新事件，让位给更晚的计时器
        local followup = _talentPending
        _talentPending = false
        GearInsight:RefreshData()
        if followup then
            C_Timer.After(0.7, function()
                if gen == _refreshGen then GearInsight:RefreshData() end
            end)
        end
    end)
end

local TALENT_EVENTS = {
    ACTIVE_PLAYER_SPECIALIZATION_CHANGED = true,
    PLAYER_SPECIALIZATION_CHANGED = true,
    TRAIT_CONFIG_UPDATED = true,
    PLAYER_TALENT_UPDATE = true,
    TRAIT_CONFIG_LIST_UPDATED = true,
}

ef:SetScript("OnEvent", function(_, event)
    -- PLAYER_REGEN_ENABLED = combat-end: flush any deferred refresh now.
    if event == "PLAYER_REGEN_ENABLED" then
        if _pendingRefresh then
            _pendingRefresh = false
            scheduleRefresh(false)
        end
        return
    end
    -- During combat lockdown CreateFrame (lazy widget creation) is forbidden.
    -- Queue the refresh and let it run once combat ends instead.
    if InCombatLockdown and InCombatLockdown() then
        _pendingRefresh = true
        return
    end
    scheduleRefresh(TALENT_EVENTS[event])
    if event == "PLAYER_ENTERING_WORLD" and not _qqMsgShown then
        _qqMsgShown = true
        -- ⭐ 预热坯子（地下城手册）缓存：悬浮提示只吃缓存、不许现扫（EJ 扫描会改全局筛选状态），
        --    以前要先打开主面板一次才有「转换优先级 #N/M」——玩家一 /reload 就只剩
        --    「催化转换成 X 后 = BiS #1」半截（用户 2026-09-17「坯子排名怎么没了？」）。
        --    手册冷启动首次常只回半截表（GetCatalystSources 里 #out<=2 不缓存），所以分三次错开重试；
        --    每次 5 个部位，脱战才跑。
        for _, delay in ipairs({ 8, 25, 60 }) do
            C_Timer.After(delay, function()
                if InCombatLockdown and InCombatLockdown() then return end
                if not (GearInsight.GetCatalystSources) then return end
                for _, slotId in ipairs({ 1, 3, 5, 7, 10 }) do
                    if not (GearInsight._catalystCache and GearInsight._catalystCache[slotId]) then
                        pcall(GearInsight.GetCatalystSources, GearInsight, slotId)
                    end
                end
            end)
        end
        C_Timer.After(5, function()
            if _LOCALE == "zhCN" then
                -- GearInsight:Print(T("QQ_JOIN", "加入QQ交流群获取最新数据更新：|cFFFFFF00954673901|r"))
            else
                -- GearInsight:Print(T("TG_JOIN", "Join the Telegram group for data updates & feedback: |cFFFFFF00t.me/gearInsight|r"))
            end
        end)
    end
end)

-- GearInsight:Print(T("LOADED", "已加载 /gi 打开面板"))
