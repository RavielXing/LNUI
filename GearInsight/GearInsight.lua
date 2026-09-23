-- GearInsight.lua - Pure WoW API, zero dependencies.
-- Panel: StatusBar stats, icon+tooltip upgrades, anchor layout.

GearInsight = GearInsight or {}

-- ── Helpers ──────────────────────────────────────────────────────────
function GearInsight:Print(msg)
    if DEFAULT_CHAT_FRAME and type(msg) == "string" then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00BFFF[GearInsight]|r " .. msg)
    end
end

local function getCN(id)
    if C_Item and C_Item.GetItemNameByID then
        local n = C_Item.GetItemNameByID(id)
        if n and n ~= "" then return n end
    end
    return nil
end

-- Localization (additive, zhCN-safe): on a Chinese client T() returns the inline
-- Chinese text verbatim, so the zhCN build is byte-for-byte unchanged and does not
-- depend on any locale file loading. Other clients use GearInsight.LOC[locale]
-- overrides, falling back to enUS, then to the inline Chinese.
-- ⭐ 2026-08-29：录屏/本地化测试用的语言覆盖。不设则完全照旧行为，零影响。
-- 用法：装上 AddOns/!GearInsightForceEN 这个小插件（名字以 ! 开头故先加载）。⭔/run 设不住，重载即失。
local _LOCALE = GearInsight.LOCALE or GEARINSIGHT_FORCE_LOCALE or (GetLocale and GetLocale()) or "enUS"
GearInsight.LOC = GearInsight.LOC or {}
local function T(key, zh)
    if _LOCALE == "zhCN" then return zh end
    -- 逐级回退：当前语言 -> enUS -> 内联中文。
    -- 改前是 `LOC[_LOCALE] or LOC["enUS"]` —— 那是**选表不选值**：
    -- 只要 deDE 表存在但缺某个 key，就直接掉回中文，而不会先试英文。
    -- 结果是德/法/韩用户看到「大部分德语 + 零星简体中文」。
    local cur = GearInsight.LOC[_LOCALE]
    if cur and cur[key] then return cur[key] end
    -- ⚠ 繁中例外：繁中缺 key 时回退到**简体**而不是英文。
    -- 繁简互通，给简体比给英文可用得多；反之则是倒退。
    if _LOCALE ~= "zhTW" then
        local en = GearInsight.LOC["enUS"]
        if en and en[key] then return en[key] end
    end
    return zh
end

-- ⭐ 站点域名按客户端语言分流（2026-09-07）：
--   国服客户端走境内已备案镜像 gearinsight.cn，其余一律 gearinsight.app。
--   国内直连香港站慢，而且备案镜像本来就是为大陆访问建的。
-- ⛔ 只认 zhCN。台服 zhTW 走 .app —— .cn 是给大陆的备案镜像，
--    台服玩家访问境内站反而更绕。
-- ⛔ 判据用**语言**不用 GetCurrentRegion()：国服客户端只有 zhCN 语言包
--    （网易 CDN 不发英文包），而 region 会因为跨区/代理失准。
local _SITE = (_LOCALE == "zhCN") and "gearinsight.cn" or "gearinsight.app"
GearInsight.SITE = _SITE

-- 译文里到处散着写死的 gearinsight.app（enUS.lua / zhTW.lua 都有），
-- 与其逐个文件改，不如在 T() 的返回值上统一换掉：
-- 非 zhCN 时 _SITE 本来就是 gearinsight.app，这个 gsub 是空操作。
-- ⛔ 外层括号不能省：gsub 返回两个值，不裹住会把替换次数一起带出去。
local function TSite(key, zh)
    return (T(key, zh):gsub("gearinsight%.app", _SITE))
end

-- Localized item name: client API (correct per-locale) first; on a zhTW client
-- fall back to S2T(baked Simplified) so an uncached item never leaks Simplified.
local _nameRefreshQueued = false
local function locName(id, baked)
    if id then
        local n = getCN(id)
        if n and n ~= "" then return n end
        -- 冷缓存：客户端还没加载这个物品，只能先印烤制名。非中文客户端烤制名是中文 ——
        -- 土耳其玩家 2026-09-06 截图满屏中文就是这么来的。发起加载，物品到齐后整面板重画一次。
        if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
        if not _nameRefreshQueued and _LOCALE ~= "zhCN" and C_Timer and C_Timer.After then
            _nameRefreshQueued = true
            C_Timer.After(1.5, function()
                _nameRefreshQueued = false
                if GearInsight._panelFrame and GearInsight._panelFrame:IsShown() and GearInsight.RefreshPanel then
                    pcall(GearInsight.RefreshPanel, GearInsight)
                end
            end)
        end
    end
    if baked and baked ~= "" and _LOCALE == "zhTW" and GearInsight.S2T then
        return GearInsight.S2T(baked)
    end
    return baked
end

local function getLocalizedClassSpec()
    local cn = UnitClass("player")  -- returns className, classFile, classID
    if GetSpecialization then
        local si = GetSpecialization()
        if si then
            local _, sn = GetSpecializationInfo(si)
            return cn, sn  -- Chinese: "德鲁伊", "守护"
        end
    end
    return cn, ""
end

local function preloadItem(id)
    if id and C_Item and C_Item.RequestLoadItemDataByID then
        C_Item.RequestLoadItemDataByID(id)
    end
end

-- Reset icon button state (prevents row-reuse artifacts)
-- 手拼物品链接的中段：enchant:gem1..4:suffix:unique:linkLevel:**spec**:modMask:context:
-- ⛔ spec 位以前写死 0 → 多主属性装备（饰品/戒指等）提示里三种主属性全列出来
--    （用户 2026-09-12 血 DK 看到「+159 智力 / +159 敏捷 / +159 力量」）。填当前专精 id 后客户端只显示自己那条。
function GearInsight.LinkMid()
    local spec = (GearInsight_CurrentSpecID and GearInsight_CurrentSpecID()) or 0
    local lvl = (UnitLevel and UnitLevel("player")) or 0
    -- ⛔⛔ 0.80.4~0.80.7 这里少了一个冒号（7 个而不是 8 个）：linkLevel 落到 uniqueID、spec 落到 linkLevel、
    --    numBonusIDs 落到 itemContext → bonusID 全部错位 → BiS 链接装等读成白板基础值（19/48）、
    --    装备图悬浮 SetHyperlink 没属性、295 套装手因为 295 ≥ 19 被判「已毕业」（虔诚 / CHENYYZZZ / 截图 2026-09-12）。
    --    正确字段序：item:ID:enchant:gem1:gem2:gem3:gem4:suffix:unique:linkLevel:spec:modMask:context:numBonus:…
    --    ⛔ 老串 ":0::::::::0:::" 是 12 个冒号，这里必须也是 12 个。
    return ":0:::::::" .. (lvl > 0 and lvl or "") .. ":" .. spec .. ":::"
end

local function resetIconBtn(btn)
    btn.texture:SetTexture(nil)
    btn.itemID = nil
    btn.itemLink = nil
    btn.currentItemID = nil
end

-- Sync icon + async itemLink for a Button-based icon.
local function setItemForIcon(btn, itemID, bonusIDs, existingLink)
    resetIconBtn(btn)
    if not itemID then return end
    btn.itemID = itemID
    btn.currentItemID = itemID
    btn._bonusIDs = bonusIDs
    btn.itemLink = existingLink
    local icon = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(itemID)
    if icon and icon ~= "" then
        btn.texture:SetTexture(icon)
    end
    if Item and Item.CreateFromItemID then
        local item = Item:CreateFromItemID(itemID)
        item:ContinueOnItemLoad(function()
            if btn.currentItemID ~= itemID then return end
            local loadedIcon = item:GetItemIcon()
            if loadedIcon and loadedIcon ~= "" then
                btn.texture:SetTexture(loadedIcon)
            end
            -- Build correct item link: use bonusIDs if available for proper ilvl
            local link = nil
            if bonusIDs and #bonusIDs > 0 then
                -- MurlokExport format: |Hitem:ID:ENCHANT:(8 zeros):SPEC:(3 zeros):COUNT:BONUS1:...|h
                local bonusPart = #bonusIDs .. ":" .. table.concat(bonusIDs, ":")
                link = "|Hitem:" .. itemID .. GearInsight.LinkMid() .. bonusPart .. "|h"
            else
                link = item:GetItemLink()
                if not link and GetItemInfo then
                    link = select(2, GetItemInfo(itemID))
                end
            end
            btn.itemLink = btn.itemLink or link
        end)
    end
end

-- Shift-click an item icon → 把物品链接发送到聊天输入框（与背包/角色面板 Shift 点击一致）。
-- 聊天框未打开时 HandleModifiedItemClick 自动无操作；链接未异步解析完成则用 itemID 兜底取链接。
-- 返回 true 表示已处理（调用方据此跳过默认左键行为）。
local function tryChatLink(btn)
    if not IsModifiedClick("CHATLINK") then return false end
    local link = btn and btn.itemLink
    if not link and btn and btn.itemID then
        link = select(2, C_Item.GetItemInfo(btn.itemID))
    end
    if link then HandleModifiedItemClick(link) end
    -- Shift 已被识别为发送到聊天意图：无论聊天框是否打开都吃掉这次点击，
    -- 避免回落到默认的"打开手册/前5"行为造成误触。
    return true
end
GearInsight._tryChatLink = tryChatLink


-- Open the Encounter Journal (Adventure Guide) straight to a specific instance /
-- boss and highlight the item, instead of just toggling the journal to its
-- default page. EncounterJournal_OpenJournal handles tier/instance/loot-tab
-- navigation; fall back to the lower-level EJ_Select* path if it's unavailable.
local function _openSourceJournal(instId, bossId, itemId, isRaid)
    if not instId then return end
    -- The Encounter Journal opens via protected functions (EncounterJournal_OpenJournal /
    -- ToggleEncounterJournal); the client blocks them in combat, so the click would fail
    -- silently. Tell the player instead of doing nothing.
    if InCombatLockdown and InCombatLockdown() then
        GearInsight:Print(T("EJ_COMBAT", "战斗中无法打开地下城手册（暴雪限制），脱战后再点"))
        return
    end
    -- ⚠️ 12.1 起 EncounterJournal_LoadUI 可能被移除（旧的 LoD 加载入口），
    --   要退到 C_AddOns.LoadAddOn；否则后面 OpenJournal 一路 nil，点了没反应还不报错
    --   （2026-08-31 用户：「手册打不开了」）。
    if EncounterJournal_LoadUI then EncounterJournal_LoadUI()
    elseif C_AddOns and C_AddOns.LoadAddOn then C_AddOns.LoadAddOn("Blizzard_EncounterJournal")
    elseif LoadAddOn then LoadAddOn("Blizzard_EncounterJournal") end
    -- 坯子弹窗在 FULLSCREEN_DIALOG 层，手册开在它后面等于没开 —— 先收起来
    if GearInsight._tierFrame and GearInsight._tierFrame:IsShown() then
        GearInsight._tierFrame:Hide()
    end
    -- Loot-tab difficulty: raid → Mythic(16), M+ dungeon → Mythic(23). Prefer the explicit
    -- isRaid flag (EJ-derived rows always carry an encounterID, so the bossId guess is unreliable).
    local diffID
    if isRaid ~= nil then diffID = isRaid and 16 or 23
    else diffID = bossId and 16 or 23 end
    if type(EncounterJournal_OpenJournal) == "function" then
        local ok = pcall(EncounterJournal_OpenJournal, diffID, instId, bossId, nil, nil, itemId)
        if ok then return end
    end
    if EJ_SelectInstance then EJ_SelectInstance(instId) end
    if bossId and EJ_SelectEncounter then EJ_SelectEncounter(bossId) end
    if not (EncounterJournal and EncounterJournal:IsShown()) and ToggleEncounterJournal then
        pcall(ToggleEncounterJournal)
    end
    -- 还是没开 = 客户端 API 变了，别再哑巴：把关键 API 的存活状态打出来，玩家截图就能定位
    if not (EncounterJournal and EncounterJournal:IsShown()) then
        GearInsight:Print(T("EJ_OPEN_FAIL", "手册没能打开（可能是客户端更新改了接口），请把这行截图反馈: ")
            .. ("OJ=%s LD=%s TG=%s"):format(
                type(EncounterJournal_OpenJournal), type(EncounterJournal_LoadUI),
                type(ToggleEncounterJournal)))
    end
end

-- Source name shown to the player. zhCN keeps the baked Chinese string verbatim.
-- zhTW converts that baked Simplified string to Traditional Chinese (Taiwan terms)
-- via GearInsight.S2T, which is reliable and EJ-independent (the Encounter Journal
-- path returned English/untranslated names on zhTW when the EJ DB wasn't loaded).
-- Other (English) clients rebuild it from the Encounter Journal IDs so the
-- boss/instance names come out localized; falls back to the baked string when
-- IDs are missing.
-- ⭐ 2026-08-29：没有 Journal 条目的来源只能查表 —— EJ_GetInstanceInfo 救不了它们。
-- 干跑统计：3964 条 source 串里 574 条属于这一类（套装转换 292 / 制造业 282 /
-- 世界掉落 16 / 奇点声望任务 5 / 其它来源 1），此前一律原样吐中文。
-- ⛔ 这里的 key 必须同时补进 locales/enUS.lua 与 zhTW.lua，否则又是静默回退。
local _NON_JOURNAL_SRC = {
    ["制造业"]       = { "SRC_CRAFTED",  "制造业" },
    ["套装转换"]     = { "SRC_TIERCONV", "套装转换" },
    ["世界掉落"]     = { "SRC_WORLD",    "世界掉落" },
    ["奇点声望任务"] = { "SRC_REPQUEST", "奇点声望任务" },
    ["其它来源"]     = { "SRC_OTHER",    "其它来源" },
    ["其他来源"]     = { "SRC_OTHER",    "其它来源" },
    ["钥石宝箱"]     = { "SRC_KEYCHEST", "钥石宝箱" },
    ["钥石宝箱（大秘境）"] = { "SRC_KEYCHEST_M", "钥石宝箱（大秘境）" },
}

local function localizedSource(baked, instId, bossId)
    if _LOCALE == "zhCN" then return baked end
    local nj = _NON_JOURNAL_SRC[baked]
    if nj then return T(nj[1], nj[2]) end
    if _LOCALE == "zhTW" then
        return (GearInsight.S2T and GearInsight.S2T(baked)) or baked
    end
    -- ⛔ 数据里有一批条目只有副本名、没 instanceId（WCL 来源没带 BOSS）：英文客户端原样吐中文，
    --    同一个本被拆成「红玉新生法池」和「Ruby Life Pools - Kyrakka」两行（Kekliy. 2026-09-12 小红书私信）。
    --    用 core/DungeonNames.lua 的中↔英对照先回查手册 id；查不到至少给英文名。
    local enFallback
    if not instId and GearInsight.DUNGEON_NAMES then
        local head = baked:match("^(.-)%s+%-%s+") or baked
        for _, d in ipairs(GearInsight.DUNGEON_NAMES) do
            if d.cn == head then
                enFallback = d.en
                if GearInsight.InstanceIdByName then instId = GearInsight.InstanceIdByName(d.en) end
                break
            end
        end
    end
    if not instId then return enFallback or baked end
    if not EJ_GetInstanceInfo then return enFallback or baked end
    local inst = EJ_GetInstanceInfo(instId)
    if not inst then return enFallback or baked end
    if bossId and EJ_GetEncounterInfo then
        local boss = EJ_GetEncounterInfo(bossId)
        if boss then return inst .. " - " .. boss end
    end
    return inst
end
-- ⛔ 暴露给 ui/TooltipHook.lua 用：来源名的本地化只留这一份实现。
--    （抄第二份的下场见 dev-notes：面板一套、悬浮一套，迟早对不上。）
GearInsight.LocalizedSource = localizedSource

-- ── 共用 helper 导出 ─────────────────────────────────────────────────
-- 2026-09-22 主文件从 7840 行拆成 main/*.lua：原来这些 file-scope local 被各段共用，
-- 拆开后各模块文件开头从这张表取回（`local T = GearInsight.Helpers.T`），逻辑不变。
-- ⛔ 只给 main/ 下的模块用；ui/ 各页仍各自有一份 T()（它们加载在本文件之前）。
GearInsight.Helpers = {
    T = T, TSite = TSite, LOCALE = _LOCALE, SITE = _SITE,
    getCN = getCN, locName = locName, getLocalizedClassSpec = getLocalizedClassSpec,
    preloadItem = preloadItem, setItemForIcon = setItemForIcon, resetIconBtn = resetIconBtn,
    localizedSource = localizedSource, openSourceJournal = _openSourceJournal,
}
