-- GuildRosterPanel.lua
-- 公会花名册面板：纯官方数据(C_GuildInfo.GuildRoster/GetGuildRosterInfo)，不受组队/
-- 检视范围限制，全公会随时可看。这是「公会联动」功能的第一块地基——之后的专精/制造业
-- 撮合会在这份花名册基础上叠加(专精数据需成员自报+插件互相同步，见 project memory
-- gearinsight-guild-crafting-plan，本文件只做花名册本身)。
GearInsight = GearInsight or {}
local GuildRosterPanel = {}
GearInsight.GuildRosterPanel = GuildRosterPanel

-- ⭐ 语言只能从 GearInsight.LOCALE 取（locales/zhCN.lua 里定的唯一真相源）。
-- ⛔别再写 GetLocale()：每个文件各抄一份就会出现“面板英文、大米攻略中文”这种分裂。
local _LOCALE = GearInsight and GearInsight.LOCALE or (GetLocale and GetLocale()) or "enUS"
local function T(key, zh)
    if _LOCALE == "zhCN" then return zh end
    local loc = GearInsight.LOC and (GearInsight.LOC[_LOCALE] or GearInsight.LOC["enUS"])
    return (loc and loc[key]) or zh
end

-- ── 数据读取 ──────────────────────────────────────────────────────────────
local _members = {}  -- 排序好的数组，每项 {name, rankName, rankIndex, level, classFile, zone, isOnline, status}

local function classColor(classFile)
    local c = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
    if c then return c.r, c.g, c.b end
    return 0.9, 0.9, 0.9
end

local function reload()
    wipe(_members)
    if not (IsInGuild and IsInGuild()) then return end
    local n = GetNumGuildMembers and GetNumGuildMembers() or 0
    for i = 1, n do
        -- name,rankName,rankIndex,level,classDisplayName,zone,publicNote,officerNote,
        -- isOnline,status,classFile,achPoints,achRank,isMobile,canSoR,repStanding,guid
        local name, rankName, rankIndex, level, _classDisplay, zone, _pubNote, _offNote,
            isOnline, status, classFile = GetGuildRosterInfo(i)
        if name then
            -- 名字自带 "-realm" 后缀时只显本服，跨服连接的公会保留后缀区分。
            local short = name:match("^([^%-]+)")
            _members[#_members + 1] = {
                name = short, fullName = name, rankName = rankName, rankIndex = rankIndex,
                level = level, classFile = classFile, zone = zone,
                isOnline = isOnline, status = status,
            }
        end
    end
    table.sort(_members, function(a, b)
        if a.isOnline ~= b.isOnline then return a.isOnline end
        if a.rankIndex ~= b.rankIndex then return a.rankIndex < b.rankIndex end
        return (a.name or "") < (b.name or "")
    end)
end

local function requestRefresh()
    if C_GuildInfo and C_GuildInfo.GuildRoster then
        C_GuildInfo.GuildRoster()
    elseif GuildRoster then
        GuildRoster()
    end
end

-- ── 面板 UI ───────────────────────────────────────────────────────────────
local panel, rows
local ROW_H = 18
local _filter = ""

local function statusIcon(m)
    if not m.isOnline then return "|cff888888" .. T("GLD_OFFLINE", "离线") .. "|r" end
    if m.status == 1 then return "|cffffd100" .. T("GLD_AFK", "暂离") .. "|r" end
    if m.status == 2 then return "|cffff6666" .. T("GLD_DND", "勿扰") .. "|r" end
    return "|cff40ff40" .. T("GLD_ONLINE", "在线") .. "|r"
end

local function ensureRow(i)
    rows = rows or {}
    if rows[i] then return rows[i] end
    local r = CreateFrame("Frame", nil, panel.scroll)
    r:SetSize(panel.scroll:GetWidth(), ROW_H)
    r.name = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    r.name:SetPoint("LEFT", 4, 0); r.name:SetWidth(110); r.name:SetJustifyH("LEFT")
    r.rank = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    r.rank:SetPoint("LEFT", r.name, "RIGHT", 4, 0); r.rank:SetWidth(90); r.rank:SetJustifyH("LEFT")
    r.lvl = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    r.lvl:SetPoint("LEFT", r.rank, "RIGHT", 4, 0); r.lvl:SetWidth(30); r.lvl:SetJustifyH("LEFT")
    r.status = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    r.status:SetPoint("LEFT", r.lvl, "RIGHT", 4, 0); r.status:SetWidth(48); r.status:SetJustifyH("LEFT")
    r.zone = r:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    r.zone:SetPoint("LEFT", r.status, "RIGHT", 4, 0); r.zone:SetJustifyH("LEFT")
    rows[i] = r
    return r
end

local function renderRows()
    if not panel or not panel:IsShown() then return end
    local q = _filter:lower()
    local i, onlineCount = 0, 0
    for _, m in ipairs(_members) do
        if m.isOnline then onlineCount = onlineCount + 1 end
        if q == "" or (m.name and m.name:lower():find(q, 1, true)) then
            i = i + 1
            local r = ensureRow(i)
            r:SetPoint("TOPLEFT", panel.scroll, "TOPLEFT", 0, -(i - 1) * ROW_H)
            r:Show()
            r.name:SetText(m.name or "?")
            r.name:SetTextColor(classColor(m.classFile))
            r.rank:SetText(m.rankName or "")
            r.lvl:SetText(m.level and tostring(m.level) or "")
            r.status:SetText(statusIcon(m))
            r.zone:SetText(m.isOnline and (m.zone or "") or "")
        end
    end
    for j = i + 1, #(rows or {}) do rows[j]:Hide() end
    panel.scroll:SetHeight(math.max(1, i * ROW_H))
    panel.subtitle:SetText(string.format(T("GLD_COUNT", "%d 在线 / %d 名成员"), onlineCount, #_members))
end

local function buildPanel()
    panel = CreateFrame("Frame", "GearInsightGuildRosterPanel", UIParent, "BackdropTemplate")
    panel:SetSize(420, 420)
    panel:SetPoint("CENTER")
    panel:SetFrameStrata("DIALOG")
    panel:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 24,
        insets = { left = 6, right = 6, top = 6, bottom = 6 },
    })
    panel:SetMovable(true); panel:EnableMouse(true); panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    panel:Hide()
    if GearInsight.RegisterEscClose then
        GearInsight:RegisterEscClose(panel, "GearInsightGuildRosterPanel")
    end

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 14, -14)
    title:SetText("GearInsight · " .. T("GLD_TITLE", "公会花名册"))

    panel.subtitle = panel:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    panel.subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)

    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)

    local refresh = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    refresh:SetSize(72, 20); refresh:SetPoint("TOPRIGHT", -28, -12)
    refresh:SetText(T("GLD_REFRESH", "刷新"))
    refresh:SetScript("OnClick", function() requestRefresh() end)

    local search = CreateFrame("EditBox", nil, panel, "SearchBoxTemplate")
    search:SetSize(180, 20)
    search:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -20)
    search:SetScript("OnTextChanged", function(self)
        SearchBoxTemplate_OnTextChanged(self)
        _filter = self:GetText() or ""
        renderRows()
    end)
    panel.search = search

    local sf = CreateFrame("ScrollFrame", "GearInsightGuildRosterScroll", panel, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", search, "BOTTOMLEFT", -6, -10)
    sf:SetPoint("BOTTOMRIGHT", -30, 14)
    local child = CreateFrame("Frame", nil, sf)
    child:SetSize(300, 1)
    sf:SetScrollChild(child)
    panel.scroll = child
    child:SetWidth(sf:GetWidth())

    panel:SetScript("OnShow", function()
        requestRefresh()
        reload()
        renderRows()
    end)
end

function GuildRosterPanel:Toggle()
    if not panel then buildPanel() end
    if panel:IsShown() then
        panel:Hide()
    else
        if not (IsInGuild and IsInGuild()) then
            GearInsight:Print(T("GLD_NOGUILD", "你还没有加入公会"))
            return
        end
        panel:Show()
    end
end

function GuildRosterPanel:Create()
    local ef = CreateFrame("Frame")
    ef:RegisterEvent("GUILD_ROSTER_UPDATE")
    ef:SetScript("OnEvent", function()
        if panel and panel:IsShown() then
            reload()
            renderRows()
        end
    end)
end
