-- main/WhatsNew.lua -- 更新后一次性弹窗（用户 2026-10-01「做一个强制一次性弹窗（只在更新好第一次弹出，点击记忆点过了，
-- 版本号每次更新再弹，告诉用户更新了什么）」）。
-- 内容 = core/NewsData.lua 里与当前插件版本号相同的那一条更新日志（generate_news_lua.py 发版时从更新日志生成，中 / 英 / 繁）。
-- 规则：
--   · 登录 / 重载后 4 秒弹（战斗中等脱战）；GearInsightDB.whatsNewSeen == 当前版本 → 不弹。
--   · 只有点「知道了」/「看完整更新日志」才记为看过（ESC 不记，下次登录还会弹 —— 用户要的是「强制」）。
--   · NewsData 里没有当前版本那条（本地开发版）→ 不弹，免得拿旧版本的日志糊弄人。
--   · /gi whatsnew 随时再看一次（不改看过的记录）。
GearInsight = GearInsight or {}
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

local function addonVersion()
    local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    return get and get("GearInsight", "Version") or nil
end

local function releaseFor(ver)
    for _, r in ipairs((GearInsightNews and GearInsightNews.releases) or {}) do
        if r.version == ver then return r end
    end
end

local KIND = {
    added = { "WN_K_ADDED", "新增", "|cFF55E055" }, new = { "WN_K_ADDED", "新增", "|cFF55E055" },
    changed = { "WN_K_CHANGED", "优化", "|cFF66CCFF" }, improved = { "WN_K_CHANGED", "优化", "|cFF66CCFF" },
    fixed = { "WN_K_FIXED", "修复", "|cFFFFB040" },
}

local frame
local function build()
    if frame then return frame end
    local f = CreateFrame("Frame", "GearInsightWhatsNew", UIParent, "BackdropTemplate")
    f:SetSize(520, 420)
    f:SetPoint("CENTER", 0, 40)
    f:SetFrameStrata("DIALOG"); f:SetToplevel(true); f:SetClampedToScreen(true)
    f:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        edgeSize = 24, insets = { left = 6, right = 6, top = 6, bottom = 6 } })
    f:EnableMouse(true); f:SetMovable(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
    if GearInsight.RegisterEscClose then GearInsight:RegisterEscClose(f, "GearInsightWhatsNew") end   -- ESC 只关不记
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.title:SetPoint("TOP", 0, -18)
    f.sub = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.sub:SetPoint("TOP", f.title, "BOTTOM", 0, -4)
    local sf = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 20, -62); sf:SetPoint("BOTTOMRIGHT", -36, 56)
    local child = CreateFrame("Frame", nil, sf); child:SetSize(450, 10); sf:SetScrollChild(child)
    local fs = child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fs:SetPoint("TOPLEFT", 2, -2); fs:SetWidth(446); fs:SetJustifyH("LEFT"); fs:SetSpacing(4)
    f.body, f.child, f.sf = fs, child, sf
    f.ok = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.ok:SetSize(140, 26); f.ok:SetPoint("BOTTOMRIGHT", -24, 18)
    f.ok:SetText(T("WN_OK", "知道了"))
    f.more = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.more:SetSize(180, 26); f.more:SetPoint("RIGHT", f.ok, "LEFT", -8, 0)
    f.more:SetText(T("WN_MORE", "看完整更新日志"))
    frame = f
    return f
end

local function markSeen(ver)
    GearInsightDB = GearInsightDB or {}
    GearInsightDB.whatsNewSeen = ver
end

function GearInsight:ShowWhatsNew(preview)
    local ver = addonVersion()
    local r = ver and releaseFor(ver)
    if not r then
        if preview then self:Print(string.format(T("WN_NONE", "当前版本 %s 还没有更新日志"), tostring(ver))) end
        return false
    end
    local f = build()
    f.title:SetText(string.format(T("WN_TITLE", "GearInsight 已更新到 %s"), ver))
    f.sub:SetText((r.date or "") .. "  ·  " .. T("WN_SUB", "这次更新了什么"))
    local lines = {}
    for _, it in ipairs(r.items or {}) do
        local text = (_LOCALE == "zhCN" and it.zh) or (_LOCALE == "zhTW" and (it.tw or it.zh)) or it.en or it.zh or ""
        local k = KIND[it.kind or ""]
        local tag = k and (k[3] .. "[" .. T(k[1], k[2]) .. "]|r ") or ""
        lines[#lines + 1] = "• " .. tag .. text
    end
    f.body:SetText(table.concat(lines, "\n\n"))
    f.child:SetHeight((f.body:GetStringHeight() or 10) + 8)
    f.sf:SetVerticalScroll(0)
    f.ok:SetScript("OnClick", function() markSeen(ver); f:Hide() end)
    f.more:SetScript("OnClick", function()
        markSeen(ver); f:Hide()
        if not (GearInsight._panelFrame and GearInsight._panelFrame:IsShown()) and GearInsight.TogglePanel then GearInsight:TogglePanel() end
        if GearInsight._selectMainTab then GearInsight._selectMainTab("news") end
    end)
    f:Show()
    return true
end

-- 登录 / 重载自动弹出已按用户要求关闭（2026-10-05）。/gi whatsnew 仍可手动查看。
local ev = CreateFrame("Frame")
ev:SetScript("OnEvent", function() end)
