-- ⛔⛔ 2026-09-02 已下线，不在 GearInsight.toc 的载入清单里。
--    用户原话：「不要附着其他的」「所有的都挂到我自己的上面」——
--    以后一律不往暴雪原生框体上贴东西，情报只在我们自己面板的「大秘境情报」页看。
--    ⭐ 下线**零功能损失**：这个贴片显示的内容与那一页完全同源（GearInsight.MplusMeta），
--      差别只是触达路径。文件留着是为了留住下面那段「逐副本使用率不做」的实测结论。
--    要恢复：把 `ui\MetaAttach.lua` 加回 toc 即可，代码本身没动。

-- 大秘境情报「贴片」：挂在暴雪原生大秘境查找器（ChallengesFrame）右侧。
--
-- ⭐ 为什么要它：主面板的「大秘境情报」页要玩家**主动点开**才看得到，触达率很低。
--    玩家真正想知道「我这个专精现在吃不吃香」的时刻，恰恰是打开大秘境界面排本的时候。
--    竞品（Keystone Cutoffs / KeystoneMeta，13.8 万 / 新上线）都是这么做的，
--    卖点就一句 "less alt-tabbing"。
--
-- ⛔ 只显示**全局**占比，不做逐副本。2026-09-02 用 6400 场快照验过：
--    各副本之间的专精占比差异，坦克最大 3.9pp、治疗 7.6pp、**DPS 全在噪声内**，
--    而且第一名从来不变 —— 本赛季高层是「一套通吃」，逐副本没有决策价值。
--
-- ⛔ Blizzard_ChallengesUI 是**按需加载**的：登录时 ChallengesFrame 根本不存在，
--    必须等 ADDON_LOADED，否则挂载点是 nil，整段静默失效（不报错）。
GearInsight = GearInsight or {}
local _LOCALE = GearInsight and GearInsight.LOCALE or (GetLocale and GetLocale()) or "enUS"
local function T(key, zh)
    if _LOCALE == "zhCN" then return zh end
    -- 逐级回退：当前语言 -> enUS -> 内联中文。与 GearInsight.lua 里的实现保持一致。
    -- ⛔别写回 `LOC[_LOCALE] or LOC["enUS"]`（选表不选值）。
    local L = GearInsight.LOC or {}
    local cur = L[_LOCALE]
    if cur and cur[key] then return cur[key] end
    if _LOCALE ~= "zhTW" then
        local en = L["enUS"]
        if en and en[key] then return en[key] end
    end
    return zh
end

local W, H = 208, 176
local panel

-- 数据行 → "DEATHKNIGHT/BLOOD" 形式的 key（cls="Death Knight", spec="Blood"）
local function RowKey(r)
    if not (r and r.cls and r.spec) then return nil end
    return (r.cls:gsub("%s+", "")):upper() .. "/" .. r.spec:upper()
end

-- 当前专精的 key。
-- ⛔⛔ 别用 GetSpecializationInfo 的**名字**去比：中文客户端返回的是「鲜血」，
--    而数据里烘的是英文 "Blood" —— 一比就永远匹配不上，且只在中文客户端出问题。
--    ✅ 用 specID（数字，跨语言恒定），借 GearInsightRotation 现成的
--    ["DEATHKNIGHT/BLOOD"]={specID=250} 映射反查（40 个专精全有）。
local function MySpecKey()
    local idx = GetSpecialization and GetSpecialization()
    if not idx then return nil end
    local id = GetSpecializationInfo and GetSpecializationInfo(idx)
    if id and type(GearInsightRotation) == "table" then
        for k, v in pairs(GearInsightRotation) do
            if v and v.specID == id then return k end
        end
    end
    -- 兜底：RotationData 缺失时退回英文名匹配（英文客户端仍可用）
    if GetSpecializationInfo then
        local _, name = GetSpecializationInfo(idx)
        local _, cls = UnitClass("player")
        if name and cls then return cls:upper() .. "/" .. name:upper() end
    end
    return nil
end

local function RoleRows(M, role)
    if role == "TANK" then return M.pushTank, T("MA_ROLE_TANK", "坦克位") end
    if role == "HEALER" then return M.pushHealer, T("MA_ROLE_HEAL", "治疗位") end
    return M.pushDps, T("MA_ROLE_DPS", "输出位")
end

local function Refresh()
    if not panel then return end
    local M = GearInsight.MplusMeta
    if not (M and M.pushTank) then
        panel.body:SetText("|cff888888" .. T("MA_NODATA", "数据未加载") .. "|r")
        return
    end

    panel.sub:SetText(("%s+ · %s%s"):format(M.pushLevel or 0,
        T("MM_DATA_TO", "数据截至"), " " .. (M.date or "")))
    panel.stale:SetText(GearInsight.MplusMetaStaleText and GearInsight:MplusMetaStaleText(M) or "")

    local specIdx = GetSpecialization and GetSpecialization()
    local role = specIdx and GetSpecializationRole and GetSpecializationRole(specIdx) or "DAMAGER"
    local rows, roleName = RoleRows(M, role)

    local myKey = MySpecKey()
    local myIdx, myRow
    if rows and myKey then
        for i, r in ipairs(rows) do
            if RowKey(r) == myKey then myIdx, myRow = i, r; break end
        end
    end

    local lines = {}
    if myIdx then
        local pct = myRow.pct and ("%.1f%%"):format(myRow.pct) or "-"
        lines[#lines + 1] = ("|cffffd100%s|r  %s %s · %s"):format(
            myRow.cn or "?", roleName,
            T("MA_RANK_N", "第%d名"):format(myIdx), pct)
    else
        lines[#lines + 1] = "|cff888888" ..
            T("MA_NOT_ON_BOARD", "你的专精不在该位置榜上（样本太少）") .. "|r"
    end
    lines[#lines + 1] = " "
    lines[#lines + 1] = "|cffaaaaaa" .. roleName .. T("MA_TOP3", "前三") .. "|r"
    for i = 1, math.min(3, rows and #rows or 0) do
        local r = rows[i]
        local mark = (myIdx == i) and "|cffffd100" or "|cffdddddd"
        lines[#lines + 1] = ("%s%d %s|r  %s"):format(mark, i, r.cn or "?",
            r.pct and ("%.1f%%"):format(r.pct) or "-")
    end
    panel.body:SetText(table.concat(lines, "\n"))
end

local function Build(parent)
    if panel then return panel end
    panel = CreateFrame("Frame", "GearInsightMetaAttach", parent, "BackdropTemplate")
    panel:SetSize(W, H)
    -- 贴在原生框右侧；⛔别盖在上面，玩家要同时看两边
    panel:SetPoint("TOPLEFT", parent, "TOPRIGHT", 2, -8)
    panel:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
                        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize = 20,
                        insets = { left = 5, right = 5, top = 5, bottom = 5 } })
    panel:SetBackdropColor(0.05, 0.06, 0.09, 0.95)

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOPLEFT", 12, -11)
    title:SetText("|cffffd100GearInsight|r " .. T("MM_TITLE", "大秘境情报"))

    panel.sub = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    panel.sub:SetPoint("TOPLEFT", 12, -27)

    panel.stale = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    panel.stale:SetPoint("TOPLEFT", 12, -40)
    panel.stale:SetWidth(W - 24)
    panel.stale:SetJustifyH("LEFT")
    if panel.stale.SetWordWrap then panel.stale:SetWordWrap(true) end

    panel.body = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    panel.body:SetPoint("TOPLEFT", 12, -56)
    panel.body:SetWidth(W - 24)
    panel.body:SetJustifyH("LEFT")
    panel.body:SetSpacing(2)

    local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("BOTTOMLEFT", 12, 10)
    hint:SetText(T("MA_HINT", "/gi 看完整榜"))
    return panel
end

-- ⛔ 事件驱动，别在文件加载时直接找 ChallengesFrame —— 那时它还不存在。
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
ev:SetScript("OnEvent", function(_, event, arg1)
    if event == "PLAYER_SPECIALIZATION_CHANGED" then
        Refresh()
        return
    end
    if arg1 ~= "Blizzard_ChallengesUI" then return end
    local host = _G.ChallengesFrame
    if not host then return end
    Build(host)
    -- 跟着原生框显示/隐藏；用 HookScript 不覆盖暴雪自己的处理
    host:HookScript("OnShow", function()
        if GearInsightDB and GearInsightDB.metaAttachOff then
            if panel then panel:Hide() end
            return
        end
        Refresh()
        if panel then panel:Show() end
    end)
    host:HookScript("OnHide", function() if panel then panel:Hide() end end)
    if host:IsShown() then Refresh(); panel:Show() end
end)

-- 开关（设置页可接）：/gi metaattach
-- ⛔ 开关必须落 **GearInsightDB**（toc 里 ## SavedVariables 声明的那个全局），
--    `GearInsight.db` 只是内存表，重登就丢 —— 玩家关掉它、下次登录又冒出来。
function GearInsight:ToggleMetaAttach()
    GearInsightDB = GearInsightDB or {}
    GearInsightDB.metaAttachOff = not GearInsightDB.metaAttachOff
    if panel then
        if GearInsightDB.metaAttachOff then panel:Hide()
        elseif _G.ChallengesFrame and _G.ChallengesFrame:IsShown() then Refresh(); panel:Show() end
    end
    return not GearInsightDB.metaAttachOff
end
