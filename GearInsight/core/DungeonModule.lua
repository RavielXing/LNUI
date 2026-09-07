-- core/DungeonModule.lua —— 「副本助手」按需加载器（2026-09-04）
--
-- 背景：玩家反馈「用不上嗜血提醒和大米指导」。翻代码发现原来的三个开关
--   （dungeonAutoPopupOff / liveGuideOff / keyTimelineOff）**只是不显示**——
--   代码照样随主插件加载、事件照样注册。其中 ui/LiveGuide.lua 用
--   RegisterEvent（不是 RegisterUnitEvent）注册了 UNIT_SPELLCAST_START /
--   UNIT_SPELLCAST_CHANNEL_START，这是全局广播：团本、战场、开放世界里
--   每个单位每次施法都会进它的 handler。也就是说**关了也还在付费**。
--
-- 现在：DungeonData + LiveGuide + KeyTimeline + DungeonGuide 四个文件搬进
--   LoadOnDemand 子插件 GearInsight_Dungeon。主插件只留这个加载器：
--     · 只注册 PLAYER_ENTERING_WORLD / ZONE_CHANGED_NEW_AREA 两个低频事件；
--     · 进到「有数据的 5 人本 + M0/M+ 难度」才动作；
--     · 从没表过态 → 弹一次提示条，让玩家自己选 [开启] / [不再提示]；
--     · 选了「不再提示」→ 记进 GearInsightDB，之后**永不加载、永不弹**，
--       彻底零内存零事件。想用时点面板「大米攻略」按钮即可重新开启。
--
-- ⛔ 开关状态必须存在主插件的 GearInsightDB 里：子插件不加载时也要读得到。
-- ⛔ 名字表在 core/DungeonNames.lua（也必须留主插件），别在这里引子插件的数据。

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

local ADDON = "GearInsight_Dungeon"

-- 子插件里的三个模块各自把「进本要跑的那一段」挂进来。
-- 为什么需要：按需加载发生在 PLAYER_ENTERING_WORLD **之后**，
-- 那些模块原本靠这个事件启动，加载完不补跑一次就是「装了但什么都不出」。
GearInsight._dgBootHooks = GearInsight._dgBootHooks or {}

-- ── 开关（GearInsightDB.dungeonModule: nil=未表态 / "on" / "off"）────────
local function state()
    return GearInsightDB and GearInsightDB.dungeonModule or "off"   -- 原来是 nil，lnui
end
local function setState(v)
    if GearInsightDB then GearInsightDB.dungeonModule = v end
end

function GearInsight:IsDungeonModuleOff() return state() == "off" end

-- ── 加载 ───────────────────────────────────────────────────────────────
local pendingBoot = false

local function isLoaded()
    if C_AddOns and C_AddOns.IsAddOnLoaded then return C_AddOns.IsAddOnLoaded(ADDON) end
    return IsAddOnLoaded and IsAddOnLoaded(ADDON)
end

-- ⛔ 只跑一次。补跑的目的是「弥补加载时错过的那一次进本事件」；
--    加载完成后子插件自己的事件帧已经注册好了，后续进本它们会正常收到。
--    这里再重复跑就变成同一次进本触发两遍（弹窗弹两次、卡片刷两遍）。
local booted = false
local function runBootHooks()
    if booted then return end
    booted = true
    for _, fn in ipairs(GearInsight._dgBootHooks) do
        local ok, err = pcall(fn)
        if not ok then
            GearInsight:Print("|cffff5555GearInsight_Dungeon boot: " .. tostring(err) .. "|r")
        end
    end
end

-- 返回 true = 已经可用（本来就加载过，或这次加载成功）
-- silent = 静默失败（进本自动路径用，不打扰）；手动点按钮时要报错，
--          否则就是「点了没反应还不报错」——跟天赋库那次踩的是同一个坑。
function GearInsight:LoadDungeonModule(silent)
    if isLoaded() then return true end

    -- 战斗中加载 80KB Lua 会卡一下；挂到脱战后补
    if InCombatLockdown and InCombatLockdown() then
        if not pendingBoot then
            pendingBoot = true
            local cf = CreateFrame("Frame")
            cf:RegisterEvent("PLAYER_REGEN_ENABLED")
            cf:SetScript("OnEvent", function(s)
                s:UnregisterAllEvents()
                pendingBoot = false
                if GearInsight:LoadDungeonModule(true) then runBootHooks() end
            end)
            if not silent then
                GearInsight:Print(T("DM_COMBAT_WAIT", "战斗中，副本助手将在脱战后加载。"))
            end
        end
        return false
    end

    local function tryLoad()
        if C_AddOns and C_AddOns.LoadAddOn then
            local _, r = C_AddOns.LoadAddOn(ADDON); return r
        elseif LoadAddOn then
            local _, r = LoadAddOn(ADDON); return r
        end
        return "NO_API"
    end
    local reason = tryLoad()
    -- ⛔ bug #109 排查发现的坑：子插件是新加的文件夹，部分角色的插件列表里可能是**未勾选**状态
    --    （插件启用状态按角色存）→ LoadAddOn 返回 DISABLED。自动路径原来 silent=true 一声不吭，
    --    玩家只看到"进本没有那个轴"。现在：先 EnableAddOn 再试一次；还不行就**无论如何打一行**。
    if not isLoaded() and (reason == "DISABLED" or reason == "DISABLED_ADDON") then
        if C_AddOns and C_AddOns.EnableAddOn then pcall(C_AddOns.EnableAddOn, ADDON)
        elseif EnableAddOn then pcall(EnableAddOn, ADDON) end
        reason = tryLoad()
    end
    if not isLoaded() then
        if not self._dmFailShown or not silent then
            self._dmFailShown = true
            GearInsight:Print(T("DM_LOAD_FAIL", "副本助手模块(GearInsight_Dungeon)加载失败：")
                .. tostring(reason or "?")
                .. "  " .. T("DM_LOAD_FAIL_HINT", "（请在插件列表里勾选 GearInsight Dungeon 后 /reload）"))
        end
        return false
    end
    return true
end

-- ── 面板「大米攻略」按钮的入口 ────────────────────────────────────────
-- ⭐ 无论开关是不是 off，点按钮都要能用 —— 「永久关闭」关的是**自动弹出/自动加载**，
--    不是把功能阉割掉。这同时也是唯一的「重新开启」入口。
function GearInsight:ShowDungeonGuide(selectIdx, fromZone)
    if not self:LoadDungeonModule(false) then return end
    runBootHooks()
    -- 子插件加载后把真身挂在 ShowDungeonGuideImpl 上；这里转发
    if self.ShowDungeonGuideImpl then
        self:ShowDungeonGuideImpl(selectIdx, fromZone)
        if state() ~= "on" then setState("on") end   -- 原来是 if state() == nil，lnui
    end
end

-- ── 进本提示条 ─────────────────────────────────────────────────────────
local prompt
local function ensurePrompt()
    if prompt then return prompt end
    local f = CreateFrame("Frame", "GearInsightDungeonPrompt", UIParent, "BackdropTemplate")
    f:SetSize(430, 84)
    f:SetPoint("TOP", UIParent, "TOP", 0, -150)
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    if f.SetBackdrop then
        f:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1,
        })
        f:SetBackdropColor(0.05, 0.06, 0.08, 0.94)
        f:SetBackdropBorderColor(0.3, 1, 0.45, 0.8)
    end

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 14, -11)
    title:SetTextColor(0.4, 1, 0.5)
    title:SetText("GearInsight · " .. T("DM_TITLE", "副本助手"))

    local body = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    body:SetPoint("TOPLEFT", 14, -31)
    body:SetWidth(402); body:SetJustifyH("LEFT")
    body:SetText(T("DM_BODY", "开启大米指导 + 嗜血提醒？（致死技能榜 / 打断优先级 / 钥匙时间轴）"))

    local ok = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    ok:SetSize(96, 22); ok:SetPoint("BOTTOMLEFT", 14, 10)
    ok:SetText(T("DM_BTN_ENABLE", "开启"))
    ok:SetScript("OnClick", function()
        f:Hide()
        setState("on")
        if GearInsight:LoadDungeonModule(false) then
            runBootHooks()
            GearInsight:Print(T("DM_ENABLED", "副本助手已开启：进大秘境自动加载。"))
        end
    end)

    local never = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    never:SetSize(110, 22); never:SetPoint("LEFT", ok, "RIGHT", 8, 0)
    never:SetText(T("DM_BTN_NEVER", "不再提示"))
    never:SetScript("OnClick", function()
        f:Hide()
        setState("off")
        GearInsight:Print(T("DM_DISABLED",
            "副本助手已关闭，之后不再加载、不占内存。想用时：/gi config 或 ESC → 选项 → 插件 → GearInsight 里打开。"))
    end)
    never:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        GameTooltip:SetText(T("DM_TIP_NEVER",
            "记到本地：以后进本不再弹这个提示，模块也不会加载（零内存、零事件）。"), 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    never:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local later = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    later:SetPoint("TOPRIGHT", 2, 2)
    later:SetScript("OnClick", function()
        -- 2026-09-06 用户拍板：默认不开，第一次进本问一次，点 × 也算答过 —— 之后只能去设置页开
        -- （ESC → 选项 → 插件 → GearInsight，或 /gi config）。原来 × 只关这一次，下个本又弹。
        f:Hide()
        setState("off")
        GearInsight:Print(T("DM_DISMISSED", "副本助手保持关闭。想用时：/gi config 或 ESC → 选项 → 插件 → GearInsight 里打开。"))
    end)

    if GearInsight.Skin then GearInsight.Skin.Sweep(f) end
    prompt = f
    return f
end

-- ⭐ 测试入口（/gi dmtest）：不进大秘境也能验提示条。
-- 存在的理由：真实触发要求「本赛季副本 + M0/钥石难度 + 满级」，
-- 练级号/追随者本都进不去，光靠真机验会卡住。⛔ 它只弹条，不改任何开关。
function GearInsight:DungeonPromptTest()
    local name, instanceType, difficultyID = GetInstanceInfo()
    self:Print(("|cff88ff88[dmtest]|r 当前：%s / %s / 难度ID=%s；本赛季数据=%s；开关=%s；已加载=%s")
        :format(tostring(name), tostring(instanceType), tostring(difficultyID),
                tostring(GearInsight.DungeonCnName and GearInsight.DungeonCnName(name) or nil),
                tostring(state()),
                tostring((C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(ADDON)) or false)))
    ensurePrompt():Show()
end

-- ── 事件：只有这两个，都是低频 ─────────────────────────────────────────
local zf = CreateFrame("Frame")
zf:RegisterEvent("PLAYER_ENTERING_WORLD")
zf:RegisterEvent("ZONE_CHANGED_NEW_AREA")
local _lastPrompted = nil
zf:SetScript("OnEvent", function()
    if state() == "off" then return end          -- 永久关闭：到此为止，一行都不再跑

    local name, instanceType, difficultyID = GetInstanceInfo()
    if instanceType ~= "party" or not name then
        _lastPrompted = nil
        if prompt then prompt:Hide() end
        return
    end
    -- 8 = 大秘境, 23 = 史诗 5 人；教学价值在 M0 同样成立（沿用 DungeonGuide 原判据）
    -- ⛔ 追随者地下城（难度 205）**故意不触发** —— 2026-09-04 用户拍板「不加」。
    --    理由：本模块的数据来自高层钥石的真实局（致死技能/打断率/嗜血点位），
    --    拿去教追随者本口径对不上；那又是练级流程，弹窗更像打扰。
    --    ⛔ 别再把 205 加进来当「bug 修复」——这是决定，不是遗漏。
    if difficultyID ~= 8 and difficultyID ~= 23 then return end
    -- 不是本赛季有数据的本就别打扰
    if not (GearInsight.DungeonCnName and GearInsight.DungeonCnName(name)) then return end

    if state() == "on" then
        -- 进本瞬间 IsChallengeModeActive 等状态还没翻真，跟 KeyTimeline 一样延一拍
        C_Timer.After(1.5, function()
            if GearInsight:LoadDungeonModule(true) then runBootHooks() end
        end)
        return
    end

    -- 未表态：每个本每次进入只弹一次
    if name == _lastPrompted then return end
    _lastPrompted = name
    C_Timer.After(1.5, function() ensurePrompt():Show() end)
end)
