-- ui/MdtRoute.lua -- 主面板「高手路线」页签（2026-09-30 立项；10-01 用户：「路线不属于大米攻略范围」「路线单独在外面弄一栏」「插件页签也做成按专精前2」）。
-- 页签本身在 GearInsight/ui/MainTabs.lua（pgRoutes），点开时加载本子插件，再调 GearInsight:BuildMdtRoutePage(page)。
-- 数据 core/MdtRoutes.lua（generate_mdt_routes_lua.py）：WCL 高层真实对局 → MDT 怪物组 → 每本几条不同路线的 MDT 导入串。
-- 「一键导入」走 MDT 自己的路线分享通道：MythicDungeonToolsAPI:SendCommMessage 把串发给自己，
-- MDT 收到后缓存（和队友分享路线完全一样），再触发 MDT 的聊天链接 garrmission:mdt-名字+服务器 → MDT 自己走导入流程。
-- 插件不直接写 MDT 的存档；通道不通（没装 MDT / 战斗中 / 超时）时退回复制框，玩家在 MDT 里点「导入」粘贴。
-- ⛔ 插件功能必须全免费（暴雪插件政策），这里不放任何收费 / 赞助引导。
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

local function norm(s) return ((s or ""):lower():gsub("[^a-z0-9]", "")) end
local function dname(d) return d and ((_LOCALE == "zhCN" and d.cn) or (_LOCALE == "zhTW" and d.tw) or d.en) or "?" end

-- 由副本条目（en 名）找高手路线（大米攻略进本自动定位等场景也能用）
function GearInsight.MdtRouteFor(entry)
    local t = GearInsightMdtRoutes
    if not (t and entry) then return nil end
    return t[norm(entry.en)]
end

-- ── 一键导入 ──────────────────────────────────────────────
local pending        -- { prefix, link, text, timer }
local listener = CreateFrame("Frame")

local function mdtAPI()
    local api = _G.MythicDungeonToolsAPI
    if api and api.SendCommMessage and api.GetPresetCommPrefix and api.GetDungeonName then return api end
end

local function myFullName()
    local n, r = UnitFullName("player")
    if not r or r == "" then r = GetNormalizedRealmName and GetNormalizedRealmName() or "" end
    return n, r
end

local function finishImport()
    local p = pending
    pending = nil
    listener:UnregisterEvent("CHAT_MSG_ADDON")
    if not p then return end
    if p.timer then p.timer:Cancel() end
    -- MDT 的导入入口：聊天链接点击（Bootstrap 里 hooksecurefunc("SetItemRef")）
    SetItemRef(p.link, p.text, "LeftButton", DEFAULT_CHAT_FRAME)
    GearInsight:Print(T("MR_IMPORTED", "已发送到 MDT。没弹出来的话点这里：") .. " |cffe6cc80|H" .. p.link .. "|h" .. p.text .. "|h|r")
end

listener:SetScript("OnEvent", function(_, _, prefix, msg, _, sender)
    if not pending or prefix ~= pending.prefix then return end
    local me = UnitName("player")
    if Ambiguate(sender or "", "none") ~= me then return end
    -- AceComm 分片：\001 首片 \002 中间 \003 末片；不分片的消息没有标记
    local b = msg:byte(1)
    if b == 1 or b == 2 then return end
    C_Timer.After(0.2, finishImport)
end)

function GearInsight:ImportMdtRoute(r, v)
    local api = mdtAPI()
    if not api then self:Print(T("MR_NO_MDT", "没检测到 Mythic Dungeon Tools，请先安装 MDT，或用下面的复制串导入")); return false end
    if InCombatLockdown() then self:Print(T("MR_COMBAT", "战斗中不能导入，脱战后再点")); return false end
    if pending then return false end
    local dungeon = api:GetDungeonName(r.idx, true)
    if not dungeon then self:Print(T("MR_OLD_MDT", "你的 MDT 版本里没有这个副本，请更新 MDT")); return false end
    local name, realm = myFullName()
    pending = {
        prefix = api:GetPresetCommPrefix(),
        link = "garrmission:mdt-" .. name .. "+" .. realm,
        text = "[" .. dungeon .. ": " .. v.name .. "]",
    }
    listener:RegisterEvent("CHAT_MSG_ADDON")
    pending.timer = C_Timer.NewTimer(12, function()
        pending = nil
        listener:UnregisterEvent("CHAT_MSG_ADDON")
        GearInsight:Print(T("MR_TIMEOUT", "MDT 没收到路线（副本里插件通信可能受限），请复制下面的串到 MDT 里点「导入」"))
    end)
    api:SendCommMessage(pending.prefix, v.code, "WHISPER", name .. "-" .. realm, "BULK")
    self:Print(T("MR_SENDING", "正在把路线发给 MDT…"))
    return true
end

-- ── 页签内容 ──────────────────────────────────────────────
-- 10-01 用户「插件页签也做成按专精前2」：默认 = 你当前专精在这个副本的 WCL 前 2 名（和天赋库冲分前 5 是同一份名单），
-- 每一波列出这位玩家按的大招 / 打断 / 驱散 / 嗜血；这本没有本专精数据时退回「统计路线」（多数高手走的路线）。
local function variantText(r, v)
    return string.format(T("MR_INFO", "+%d %s %s · %d 波 · 计数 %.1f%%\n统计 %d 局高层真实对局，其中 %d 局走的是这条路线"),
        v.key, v.timed and T("MR_TIMED", "限时") or T("MR_OVER", "超时"), v.time, v.pulls, v.pct, r.runs, v.followers)
end

local function curSpecID()
    if GearInsight_CurrentSpecID then
        local ok, id = pcall(GearInsight_CurrentSpecID)
        if ok and id and id > 0 then return id end
    end
    local i = GetSpecialization and GetSpecialization()
    return i and GetSpecializationInfo and (GetSpecializationInfo(i)) or nil
end

local function specName(id)
    if not (id and GetSpecializationInfoByID) then return "" end
    local _, name = GetSpecializationInfoByID(id)
    return name or ""
end

local function heroName(e)
    if _LOCALE == "zhCN" and e.heroCn and e.heroCn ~= "" then return e.heroCn end
    if _LOCALE == "zhTW" and e.heroTw and e.heroTw ~= "" then return e.heroTw end
    return e.hero or ""
end

-- 技能：客户端自带本地化名字和图标
local function spell(id)
    local name, icon
    if C_Spell and C_Spell.GetSpellName then name = C_Spell.GetSpellName(id) end
    if C_Spell and C_Spell.GetSpellTexture then icon = C_Spell.GetSpellTexture(id) end
    if not name and GetSpellInfo then local n, _, ic = GetSpellInfo(id); name, icon = n, icon or ic end
    return name or ("#" .. tostring(id)), icon
end

-- 同一技能合并成「名字 ×N」，按第一次出现的顺序
local function spellList(ids)
    local n, order = {}, {}
    for _, id in ipairs(ids or {}) do
        if not n[id] then n[id] = 0; order[#order + 1] = id end
        n[id] = n[id] + 1
    end
    local parts = {}
    for _, id in ipairs(order) do
        local name, icon = spell(id)
        parts[#parts + 1] = (icon and ("|T" .. icon .. ":14:14:0:0|t ") or "") .. name .. (n[id] > 1 and (" ×" .. n[id]) or "")
    end
    return table.concat(parts, "  ")
end

-- 每一波一段文字（大招 / 打断 / 驱散 / 嗜血）
-- 10-01 用户「UI优化」：每一波的技能做成一块块「图标 + 名字 ×N」，整块换行、续行对齐第一个技能（以前文字折行会把
-- 「亡者复生」「血魔之握」从中间断开，续行顶到最左边）。宽度跟着滚动区走，列表 / 装备图两种面板宽度都重排。
local function renderPulls(P, e, emptyText)
    local child = P.pullChild
    child._chips = child._chips or {}
    child._lbls = child._lbls or {}
    local W = math.max(200, ((P.pullSF.GetWidth and P.pullSF:GetWidth()) or 320) - 8)
    local nC, nL = 0, 0
    local function label(text, x, y, font)
        nL = nL + 1
        local l = child._lbls[nL]
        if not l then l = child:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); child._lbls[nL] = l end
        l:SetFontObject(font or "GameFontHighlightSmall")
        l:ClearAllPoints(); l:SetWidth(0); l:SetPoint("TOPLEFT", child, "TOPLEFT", x, y); l:SetText(text); l:Show()
        return l
    end
    local function chips(ids, x0, y)
        local n, order = {}, {}
        for _, id in ipairs(ids or {}) do
            if not n[id] then n[id] = 0; order[#order + 1] = id end
            n[id] = n[id] + 1
        end
        local x = x0
        for _, id in ipairs(order) do
            nC = nC + 1
            local c = child._chips[nC]
            if not c then
                c = CreateFrame("Button", nil, child)
                c:SetHeight(18)
                c.ic = c:CreateTexture(nil, "ARTWORK"); c.ic:SetSize(16, 16); c.ic:SetPoint("LEFT", 0, 0)
                c.tx = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); c.tx:SetPoint("LEFT", c.ic, "RIGHT", 3, 0)
                c:SetScript("OnEnter", function(b)
                    if b._id and GameTooltip.SetSpellByID then GameTooltip:SetOwner(b, "ANCHOR_RIGHT"); GameTooltip:SetSpellByID(b._id); GameTooltip:Show() end
                end)
                c:SetScript("OnLeave", function() GameTooltip:Hide() end)
                child._chips[nC] = c
            end
            local name, icon = spell(id)
            c._id = id
            c.ic:SetTexture(icon or 134400)
            c.tx:SetText(name .. (n[id] > 1 and (" ×" .. n[id]) or ""))
            local w = 19 + ((c.tx.GetStringWidth and c.tx:GetStringWidth()) or 0) + 10
            if x + w > W and x > x0 then x = x0; y = y - 20 end
            c:SetWidth(w); c:ClearAllPoints(); c:SetPoint("TOPLEFT", child, "TOPLEFT", x, y); c:Show()
            x = x + w
        end
        return y
    end
    local y = -2
    if not e then
        label(emptyText or "", 2, y, "GameFontHighlight")
        y = y - 20
    else
        -- 一次战斗 = 一波（10-03 用户「一次战斗算一波」「用一个序号」）：和领航条同一个合并、同一个序号
        if GearInsight.MdtWaves then e = GearInsight.MdtWaves(e) end
        local mobsTbl = GearInsightMdtMobs and GearInsightMdtMobs[P.key] or {}
        local acc = 0
        for i, p in ipairs(e.pulls or {}) do
            acc = acc + (p.f or 0)
            local head = string.format(T("MR_PULL", "|cFFFFD100第 %d 波|r  |cFF888888+%.1f%% · 累计 %.1f%%|r"), i, p.f or 0, acc)
            if p.g and #p.g > 1 then head = head .. "  |cFFFF9F40" .. string.format(T("RB_CHAIN", "连拉 %d 组"), #p.g) .. "|r" end
            if p.l then head = head .. "  |cFFFF7F3F" .. T("MR_LUST", "嗜血") .. "|r" end
            label(head, 2, y, "GameFontNormal")
            y = y - 20
            -- 这一波的怪（按名字合并只数）
            local order, cnt = {}, {}
            for j = 1, #(p.m or {}), 2 do
                local rec = mobsTbl[p.m[j]]
                local nm = rec and ((_LOCALE == "zhCN" and rec[2]) or (_LOCALE == "zhTW" and rec[4]) or rec[3])
                if nm and nm ~= "" then
                    if not cnt[nm] then order[#order + 1] = nm; cnt[nm] = 0 end
                    cnt[nm] = cnt[nm] + (p.m[j + 1] or 1)
                end
            end
            if #order > 0 then
                local parts = {}
                for _, nm in ipairs(order) do parts[#parts + 1] = nm .. (cnt[nm] > 1 and ("×" .. cnt[nm]) or "") end
                local l = label("|cFFCCCCCC" .. table.concat(parts, "  ") .. "|r", 18, y)
                l:SetWidth(W - 20); l:SetJustifyH("LEFT"); l:SetWordWrap(true)
                y = y - ((l.GetStringHeight and l:GetStringHeight()) or 14) - 4
            end
            -- 社区路线：作者在这一段写的提醒（10-04），和领航条右栏同一套样式
            for _, t in ipairs(p.nt or {}) do
                local l = label(GearInsight.MdtNoteText and GearInsight.MdtNoteText(t, true) or t, 18, y)
                l:SetWidth(W - 20); l:SetJustifyH("LEFT"); l:SetWordWrap(true); l:SetSpacing(2)
                y = y - ((l.GetStringHeight and l:GetStringHeight()) or 14) - 5
            end
            for _, row in ipairs({ { p.cd, "MR_EV_CD", "大招" }, { p.i, "MR_EV_INT", "打断" }, { p.d, "MR_EV_DISP", "驱散" } }) do
                if row[1] then
                    label("|cFF9FD0FF" .. T(row[2], row[3]) .. "|r", 18, y - 3)
                    y = chips(row[1], 54, y) - 21
                end
            end
            y = y - 4
        end
    end
    for i = nC + 1, #child._chips do child._chips[i]:Hide() end
    for i = nL + 1, #child._lbls do child._lbls[i]:Hide() end
    child:SetHeight(math.max(10, -y + 4))
    P._pullsE, P._pullsEmpty = e, emptyText
end

local function pullsText(e)
    local lines, acc = {}, 0
    for i, p in ipairs(e.pulls or {}) do
        acc = acc + (p.f or 0)
        local head = string.format(T("MR_PULL", "|cFFFFD100第 %d 波|r  |cFF888888+%.1f%% · 累计 %.1f%%|r"), i, p.f or 0, acc)
        if p.l then head = head .. "  |cFFFF7F3F" .. T("MR_LUST", "嗜血") .. "|r" end
        lines[#lines + 1] = head
        if p.cd then lines[#lines + 1] = "   |cFF9FD0FF" .. T("MR_EV_CD", "大招") .. "|r  " .. spellList(p.cd) end
        if p.i then lines[#lines + 1] = "   |cFF9FD0FF" .. T("MR_EV_INT", "打断") .. "|r  " .. spellList(p.i) end
        if p.d then lines[#lines + 1] = "   |cFF9FD0FF" .. T("MR_EV_DISP", "驱散") .. "|r  " .. spellList(p.d) end
    end
    return table.concat(lines, "\n")
end

-- 区服（10-01 用户：「带上服务器和区服（国服，eu等」）
local REGION_KEY = { CN = "MR_REG_CN", EU = "MR_REG_EU", US = "MR_REG_US", KR = "MR_REG_KR", TW = "MR_REG_TW" }
local REGION_ZH = { CN = "国服", EU = "欧服", US = "美服", KR = "韩服", TW = "台服" }
local function regionName(r)
    r = (r or ""):upper()
    return REGION_KEY[r] and T(REGION_KEY[r], REGION_ZH[r]) or r
end

local function urlenc(v)
    return (tostring(v or ""):gsub("[^%w%-_%.~]", function(c) return string.format("%%%02X", c:byte()) end))
end

-- 「更多路线攻略」网址（10-01 用户：「这里带上用户角色绑定信息，顺便绑定，也可以直接在页面锁定专精」）：
--   ?spec=<专精>&slug=<副本>&region=&realm=&name= → 网站 /wow/mdt 锁定这个专精、打开这个副本，并按「我的角色」流程绑定角色
--   （首次自动加为主角色；已绑了别的角色会先问一句，网站 wow_me.js 的老规矩）。只带公开信息（角色名 / 服务器 / 区服），不带任何账号凭据。
local function siteURL(key)
    local zh = (_LOCALE == "zhCN" or _LOCALE == "zhTW")
    local url = (zh and "https://gearinsight.cn" or "https://gearinsight.app") .. "/wow/mdt"
    local q = {}
    local sid = curSpecID()
    if sid then q[#q + 1] = "spec=" .. sid end
    for _, d in ipairs(GearInsightMdtRouteOrder or {}) do
        if d.key == key and d.slug then q[#q + 1] = "slug=" .. urlenc(d.slug) end
    end
    local regionMap = { "us", "kr", "eu", "tw", "cn" }
    local region = regionMap[(GetCurrentRegion and GetCurrentRegion()) or 0]
    local name = UnitName and UnitName("player")
    local realm = GetRealmName and GetRealmName()
    if region and name and name ~= "" and realm and realm ~= "" then
        q[#q + 1] = "region=" .. region
        q[#q + 1] = "realm=" .. urlenc((realm:gsub("%s+", "-"):lower()))
        q[#q + 1] = "name=" .. urlenc(name)
    end
    return #q > 0 and (url .. "?" .. table.concat(q, "&")) or url
end

-- 进页默认选中：上次看的 → 当前所在副本 → 第一个
local function defaultKey()
    local db = GearInsightDB or {}
    if db.mdtRouteKey then
        for _, d in ipairs(GearInsightMdtRouteOrder or {}) do if d.key == db.mdtRouteKey then return d.key end end
    end
    local zone = GetInstanceInfo and select(1, GetInstanceInfo())
    if zone then
        for _, d in ipairs(GearInsightMdtRouteOrder or {}) do
            if zone == d.cn or zone == d.tw or zone == d.en then return d.key end
        end
    end
    local first = (GearInsightMdtRouteOrder or {})[1]
    return first and first.key
end

-- 名次 / 路线切换卡片（10-03 用户截图「这里展示优化下」：原来是暴雪红色 UIPanelButton，刺眼、选中只是微亮）。
-- 深色扁平卡：选中 = 金边 + 左侧金条 + 暖底；未选 = 灰边，悬停提亮。两行：①名次 + 名字（职业色） ②服务器 · 大区 · 层数 时间。
-- ════════════════════════════════════════════════════════════════════════
-- 路线串 GIR1 导入（10-04 用户：插件只放第 1 名，「需要看更多请去网站，网站复制字符串进入插件导入」）
--   格式 = "GIR1:" + base64url(JSON)，字段见 services/dashboard/gir_codec.py；pulls 和内置路线完全同构。
--   ⛔ 只解析、不执行（不 loadstring）；字段逐个按类型拷，长度 / 个数都有上限。按账号存，每本最多 5 条。
-- ════════════════════════════════════════════════════════════════════════
local B64 = {}
do
    local a = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
    for i = 1, #a do B64[a:byte(i)] = i - 1 end
    B64[("+"):byte()] = 62; B64[("/"):byte()] = 63
end
local function b64dec(s)
    local out, acc, bits = {}, 0, 0
    for i = 1, #s do
        local v = B64[s:byte(i)]
        if v then
            acc = acc * 64 + v; bits = bits + 6
            if bits >= 8 then
                bits = bits - 8
                local p = 2 ^ bits
                out[#out + 1] = string.char(math.floor(acc / p) % 256)
                acc = acc % p
            end
        end
    end
    return table.concat(out)
end
local function utf8char(cp)
    if cp < 0x80 then return string.char(cp) end
    if cp < 0x800 then return string.char(0xC0 + math.floor(cp / 0x40), 0x80 + cp % 0x40) end
    if cp < 0x10000 then return string.char(0xE0 + math.floor(cp / 0x1000), 0x80 + math.floor(cp / 0x40) % 0x40, 0x80 + cp % 0x40) end
    return string.char(0xF0 + math.floor(cp / 0x40000), 0x80 + math.floor(cp / 0x1000) % 0x40, 0x80 + math.floor(cp / 0x40) % 0x40, 0x80 + cp % 0x40)
end
-- 最小 JSON 解析（对象 / 数组 / 字符串 / 数字 / true / false / null），深度 ≤ 8
local function jdecode(s)
    local i = 1
    local ESC = { b = "\b", f = "\f", n = "\n", r = "\r", t = "\t" }
    local function ws() i = s:find("[^ \t\r\n]", i) or (#s + 1) end
    local value
    local function str()
        i = i + 1
        local out = {}
        while true do
            local j = s:find('["\\]', i)
            if not j then error("eof") end
            out[#out + 1] = s:sub(i, j - 1)
            i = j
            if s:sub(i, i) == '"' then i = i + 1; break end
            local n = s:sub(i + 1, i + 1)
            if n == "u" then
                local cp = tonumber(s:sub(i + 2, i + 5), 16) or 63; i = i + 6
                if cp >= 0xD800 and cp <= 0xDBFF and s:sub(i, i + 1) == "\\u" then
                    local lo = tonumber(s:sub(i + 2, i + 5), 16) or 0xDC00; cp = 0x10000 + (cp - 0xD800) * 0x400 + (lo - 0xDC00); i = i + 6
                end
                out[#out + 1] = utf8char(cp)
            else
                out[#out + 1] = ESC[n] or n; i = i + 2
            end
        end
        return table.concat(out)
    end
    value = function(depth)
        if depth > 8 then error("deep") end
        ws()
        local c = s:sub(i, i)
        if c == "{" then
            local t = {}; i = i + 1; ws()
            if s:sub(i, i) == "}" then i = i + 1; return t end
            while true do
                ws(); if s:sub(i, i) ~= '"' then error("key") end
                local k = str(); ws()
                if s:sub(i, i) ~= ":" then error(":") end
                i = i + 1
                t[k] = value(depth + 1); ws()
                local d = s:sub(i, i); i = i + 1
                if d == "}" then return t elseif d ~= "," then error(",") end
            end
        elseif c == "[" then
            local t = {}; i = i + 1; ws()
            if s:sub(i, i) == "]" then i = i + 1; return t end
            while true do
                t[#t + 1] = value(depth + 1); ws()
                local d = s:sub(i, i); i = i + 1
                if d == "]" then return t elseif d ~= "," then error(",") end
            end
        elseif c == '"' then return str()
        elseif s:sub(i, i + 3) == "true" then i = i + 4; return true
        elseif s:sub(i, i + 4) == "false" then i = i + 5; return false
        elseif s:sub(i, i + 3) == "null" then i = i + 4; return nil
        else
            local num = s:match("^-?%d+%.?%d*[eE]?[-+]?%d*", i)
            if not num or num == "" then error("value") end
            i = i + #num
            return tonumber(num)
        end
    end
    return value(0)
end
local function numList(t, max)
    local out = {}
    if type(t) ~= "table" then return nil end
    for k = 1, math.min(#t, max or 400) do if type(t[k]) == "number" then out[#out + 1] = t[k] end end
    return #out > 0 and out or nil
end
local function str80(v, n) return type(v) == "string" and v:sub(1, n or 80) or "" end
-- → 干净的路线条目（和内置 GearInsightMdtSpecRoutes 的条目同构）或 nil, 原因
function GearInsight.DecodeRouteString(s)
    s = tostring(s or ""):gsub("%s", "")
    if s:sub(1, 5) ~= "GIR1:" then return nil, T("MR_GIR_BAD", "不是路线串（应以 GIR1: 开头）") end
    if #s > 200000 then return nil, T("MR_GIR_LONG", "路线串太长") end
    local ok, d = pcall(jdecode, b64dec(s:sub(6)))
    if not ok or type(d) ~= "table" or d.v ~= 1 then return nil, T("MR_GIR_BROKEN", "路线串不完整或已损坏，请重新复制") end
    if type(d.dg) ~= "string" or (d.tier ~= "spec" and d.tier ~= "s12") or type(d.pulls) ~= "table" then
        return nil, T("MR_GIR_BROKEN", "路线串不完整或已损坏，请重新复制")
    end
    local e = { imported = true, tier = d.tier, dg = d.dg:sub(1, 40), sid = tonumber(d.sid) or 0, pos = tonumber(d.pos) or 0,
        rank = tonumber(d.rank) or 0, player = str80(d.player, 40), server = str80(d.server, 40), region = str80(d.region, 8),
        hero = str80(d.hero, 40), heroCn = str80(d.heroCn, 40), heroTw = str80(d.heroTw, 40),
        key = tonumber(d.key) or 0, time = str80(d.time, 12), timed = d.timed == true,
        name = str80(d.name, 80), pct = tonumber(d.pct) or 0, pulls = {} }
    if type(d.code) == "string" and d.code:sub(1, 7) == "!~MDT2~" and #d.code < 60000 then e.code = d.code end
    for k = 1, math.min(#d.pulls, 60) do
        local p = d.pulls[k]
        if type(p) == "table" then
            e.pulls[#e.pulls + 1] = { f = tonumber(p.f) or 0, m = numList(p.m), c = numList(p.c), w = tonumber(p.w),
                l = p.l == true or nil, cd = numList(p.cd, 60), i = numList(p.i, 60), d = numList(p.d, 60) }
        end
    end
    if #e.pulls == 0 then return nil, T("MR_GIR_BROKEN", "路线串不完整或已损坏，请重新复制") end
    return e
end
-- 存进账号（GearInsightDB.mdtImported[副本] 最多 5 条，同一条再导入不重复）
function GearInsight.ImportRouteString(s)
    local e, why = GearInsight.DecodeRouteString(s)
    if not e then return nil, why end
    GearInsightDB = GearInsightDB or {}
    GearInsightDB.mdtImported = GearInsightDB.mdtImported or {}
    local l = GearInsightDB.mdtImported[e.dg] or {}
    for k = #l, 1, -1 do
        local x = l[k]
        if x.tier == e.tier and x.sid == e.sid and x.pos == e.pos and x.player == e.player and x.time == e.time then table.remove(l, k) end
    end
    l[#l + 1] = e
    while #l > 5 do table.remove(l, 1) end
    GearInsightDB.mdtImported[e.dg] = l
    return e
end
function GearInsight.DeleteImportedRoute(dg, e)
    local l = GearInsightDB and GearInsightDB.mdtImported and GearInsightDB.mdtImported[dg]
    if not l then return end
    for k = #l, 1, -1 do if l[k] == e or l[k] == (e and e._src) then table.remove(l, k) end end
end
-- 内置第 1 名 + 导入的（同一档）。导入的用副本（领航条会往条目上挂合波缓存，别写进存档）
local impCopy = setmetatable({}, { __mode = "k" })
function GearInsight.MdtSpecList(tier, sid, key)
    local T0 = (tier == "s12") and GearInsightMdtSpecRoutes12 or GearInsightMdtSpecRoutes
    local base = sid and T0 and T0[sid] and key and T0[sid][key]
    local imp = key and GearInsightDB and GearInsightDB.mdtImported and GearInsightDB.mdtImported[key]
    if not imp or #imp == 0 then return base end
    local out = {}
    for _, x in ipairs(base or {}) do out[#out + 1] = x end
    for _, x in ipairs(imp) do
        if x.tier == tier then
            local c = impCopy[x]
            if not c then c = {}; for k2, v in pairs(x) do c[k2] = v end; c._src = x; impCopy[x] = c end
            out[#out + 1] = c
        end
    end
    return #out > 0 and out or nil
end

-- 粘贴框（自建：StaticPopup 的输入框有长度上限，路线串几 KB）
function GearInsight:ShowRouteImport(page)
    local f = self._girFrame
    if not f then
        f = CreateFrame("Frame", "GearInsightRouteImport", UIParent, "BackdropTemplate")
        f:SetSize(560, 132); f:SetPoint("CENTER"); f:SetFrameStrata("FULLSCREEN_DIALOG"); f:SetFrameLevel(50)
        if f.SetBackdrop then
            f:SetBackdrop({ edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize = 32, insets = { left = 8, right = 8, top = 8, bottom = 8 } })
        end
        local bg = f:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(0.05, 0.05, 0.08, 0.97)
        f:EnableMouse(true); f:SetMovable(true); f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", function() f:StartMoving() end)
        f:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)
        local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); title:SetPoint("TOP", 0, -14)
        title:SetText(T("MR_GIR_BTN", "导入路线串"))
        local cb = CreateFrame("Button", nil, f, "UIPanelCloseButton"); cb:SetPoint("TOPRIGHT", -4, -4)
        cb:SetScript("OnClick", function() f:Hide() end)
        local edit = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
        edit:SetSize(500, 24); edit:SetPoint("TOP", 0, -44); edit:SetAutoFocus(true); edit:SetMaxLetters(0)
        edit:SetFontObject("GameFontHighlightSmall")
        edit:SetScript("OnEscapePressed", function(s) s:ClearFocus(); f:Hide() end)
        f._edit = edit
        local hint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        hint:SetPoint("TOP", edit, "BOTTOM", 0, -6); hint:SetWidth(500)
        hint:SetText(T("MR_GIR_HINT", "在网站路线详情点「复制到插件」，在这里 Ctrl+V 粘贴，再点「导入」。"))
        local ok = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        ok:SetSize(110, 24); ok:SetPoint("BOTTOM", 0, 14); ok:SetText(T("MR_GIR_DO", "导入"))
        local function doImport()
            local e, why = GearInsight.ImportRouteString(edit:GetText() or "")
            if not e then GearInsight:Print("|cFFFF7F3F" .. (why or "?") .. "|r"); return end
            f:Hide()
            GearInsight:Print(string.format(T("MR_GIR_OK", "已导入：%s #%d %s（%s）"),
                e.tier == "s12" and "+12" or T("MR_SRC_SPEC", "高手榜"), e.rank or e.pos or 0, e.player or "", e.dg))
            local pg = f._page
            local P = pg and pg._mr
            if P then
                P.src = (e.tier == "s12") and "mid" or "spec"
                GearInsightDB.mdtRouteSrc = P.src
                local base = 0
                local T0 = (e.tier == "s12") and GearInsightMdtSpecRoutes12 or GearInsightMdtSpecRoutes
                local sid = curSpecID and curSpecID()
                if sid and T0 and T0[sid] and T0[sid][e.dg] then base = #T0[sid][e.dg] end
                local n = 0
                for _, x in ipairs((GearInsightDB.mdtImported and GearInsightDB.mdtImported[e.dg]) or {}) do if x.tier == e.tier then n = n + 1 end end
                GearInsight:SelectMdtRoute(pg, e.dg, base + n)
            end
        end
        ok:SetScript("OnClick", doImport)
        edit:SetScript("OnEnterPressed", doImport)
        self._girFrame = f
    end
    f._page = page
    f._edit:SetText("")
    f:Show(); f._edit:SetFocus()
end

local function makeCard(parent)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    b.bar = b:CreateTexture(nil, "ARTWORK"); b.bar:SetWidth(3)
    b.bar:SetPoint("TOPLEFT", 1, -1); b.bar:SetPoint("BOTTOMLEFT", 1, 1); b.bar:SetColorTexture(1, 0.82, 0, 1)
    b.hl = b:CreateTexture(nil, "HIGHLIGHT"); b.hl:SetAllPoints(); b.hl:SetColorTexture(1, 1, 1, 0.06)
    b.t1 = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    b.t1:SetJustifyH("LEFT"); b.t1:SetWordWrap(false)
    b.t2 = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.t2:SetPoint("BOTTOMLEFT", 10, 5); b.t2:SetPoint("RIGHT", -6, 0); b.t2:SetJustifyH("LEFT"); b.t2:SetWordWrap(false)
    b.t2:SetTextColor(0.62, 0.65, 0.72)
    function b:SetSel(on)
        if on then
            self:SetBackdropColor(0.20, 0.16, 0.06, 0.95); self:SetBackdropBorderColor(1, 0.82, 0, 0.95); self.bar:Show()
        else
            self:SetBackdropColor(0.07, 0.08, 0.11, 0.92); self:SetBackdropBorderColor(0.32, 0.34, 0.40, 0.9); self.bar:Hide()
        end
    end
    function b:SetLines(a, c)
        self.t1:SetText(a or "")
        self.t2:SetText(c or ""); self.t2:SetShown(c ~= nil and c ~= "")
        self.t1:ClearAllPoints()
        if c and c ~= "" then self.t1:SetPoint("TOPLEFT", 10, -5) else self.t1:SetPoint("LEFT", 10, 0) end
        self.t1:SetPoint("RIGHT", -6, 0)
    end
    -- 第二行常被截成「…」（10-03 用户「省略信息要用 tooltip 补充展示」）：悬停把整条信息列出来
    b:SetScript("OnEnter", function(self)
        if not self._tip then return end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        for i, line in ipairs(self._tip) do
            if i == 1 then GameTooltip:AddLine(line, 1, 0.82, 0) else GameTooltip:AddLine(line, 0.9, 0.9, 0.9, true) end
        end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetSel(false)
    return b
end

local function classHex(sid)
    local cls = sid and GetSpecializationInfoByID and select(6, GetSpecializationInfoByID(sid))
    local c = cls and RAID_CLASS_COLORS and RAID_CLASS_COLORS[cls]
    return c and c.GenerateHexColor and c:GenerateHexColor() or "FFFFFFFF"
end

function GearInsight:BuildMdtRoutePage(page)
    if not page then return end
    local P = page._mr
    if not P then
        P = {}
        page._mr = P
        local order = GearInsightMdtRouteOrder or {}
        -- 左栏：副本列表
        P.dgBtns = {}
        for i, d in ipairs(order) do
            local b = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
            b:SetSize(140, 26)
            b:SetPoint("TOPLEFT", 14, -44 - (i - 1) * 30)
            b:SetText(dname(d))
            b:SetScript("OnClick", function() GearInsight:SelectMdtRoute(page, d.key, 1) end)
            b._key = d.key
            P.dgBtns[#P.dgBtns + 1] = b
        end
        -- 右栏
        local X = 166
        P.title = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        P.title:SetPoint("TOPLEFT", X, -46); P.title:SetPoint("RIGHT", page, "RIGHT", -340, 0); P.title:SetJustifyH("LEFT")
        -- 路线来源（10-03 用户「感觉高层的参考性不大，增加 12 层中段常规路线选项」）：高手榜（本专精前几名）/ +12 常规（多数 +12 玩家这么走）
        P.src = (GearInsightDB and GearInsightDB.mdtRouteSrc) or "spec"
        local function srcBtn(label, src, tip)
            local b = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
            b:SetSize(104, 22); b:SetText(label)
            b:SetScript("OnClick", function()
                P.src = src; GearInsightDB = GearInsightDB or {}; GearInsightDB.mdtRouteSrc = src
                GearInsight:SelectMdtRoute(page, P.key, 1)
            end)
            b:SetScript("OnEnter", function(s2) GameTooltip:SetOwner(s2, "ANCHOR_BOTTOM"); GameTooltip:SetText(tip, 1, 1, 1, 1, true); GameTooltip:Show() end)
            b:SetScript("OnLeave", function() GameTooltip:Hide() end)
            return b
        end
        P.srcMid = srcBtn(T("MR_SRC_MID", "+12 常规"), "mid", T("MR_SRC_MID_TT", "+12 常规路线：抽样几十局 +12 限时对局，按怪物组归成几条路线，按「走的人多」排序。适合中段钥石。"))
        -- 10-04 社区经典（keystone.guru / wago.io 热门路线，署名 + 原链接；免费）：用户「先加入一些现有的经典路线做兜底」
        P.srcComm = srcBtn(T("MR_SRC_COMM", "社区经典"), "comm", T("MR_SRC_COMM_TT", "社区经典：keystone.guru / wago.io 上最热门的路线（作者署名、原链接）。高手路线的日志拆不清时，也会自动换成这里的第一条。"))
        P.srcComm:SetPoint("TOPRIGHT", page, "TOPRIGHT", -14, -42)
        P.srcMid:SetPoint("RIGHT", P.srcComm, "LEFT", -4, 0)
        P.srcSpec = srcBtn(T("MR_SRC_SPEC", "高手榜"), "spec", T("MR_SRC_SPEC_TT", "高手榜：你这个专精冲分前几名的真实对局（高层），每一波带他按的大招 / 打断 / 驱散。"))
        P.srcSpec:SetPoint("RIGHT", P.srcMid, "LEFT", -4, 0)
        P.tabs = {}
        for i = 1, 6 do   -- 10-04 社区经典每本 5 条：4 张不够
            local b = makeCard(page)
            b:SetSize(120, 22)
            b:SetPoint("TOPLEFT", X + (i - 1) * 124, -68)
            b:SetScript("OnClick", function() GearInsight:SelectMdtRoute(page, P.key, i) end)
            P.tabs[i] = b
        end
        P.info = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        P.info:SetPoint("TOPLEFT", X, -110); P.info:SetPoint("RIGHT", page, "RIGHT", -14, 0)
        P.info:SetJustifyH("LEFT"); P.info:SetSpacing(3)
        P.imp = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
        P.imp:SetSize(150, 26); P.imp:SetPoint("TOPLEFT", P.info, "BOTTOMLEFT", 0, -8)   -- 10-04「UI 优化」：跟着说明走，说明多一行不再压住按钮
        P.imp:SetText(T("MR_BTN_IMPORT", "一键导入 MDT"))
        P.imp:SetScript("OnClick", function()
            if P.r and P.v then GearInsight:ImportMdtRoute(P.r, P.v) end
        end)
        P.imp:SetScript("OnEnter", function(b)
            GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
            GameTooltip:SetText(T("MR_BTN_IMPORT", "一键导入 MDT"))
            GameTooltip:AddLine(T("MR_IMPORT_TT", "用 MDT 自带的路线分享通道导入，和队友发路线给你一样；MDT 会新建一个路线，不会覆盖你已有的。"), 1, 1, 1, true)
            GameTooltip:Show()
        end)
        P.imp:SetScript("OnLeave", function() GameTooltip:Hide() end)
        -- 复制框（小，一行半）：MDT 串
        local box = CreateFrame("Frame", nil, page, "BackdropTemplate")
        box:SetPoint("LEFT", P.imp, "RIGHT", 10, 0); box:SetPoint("RIGHT", page, "RIGHT", -14, 0); box:SetHeight(30)
        P.box2 = box
        -- 社区经典的原链接：太长，不放说明里（10-04 截图：三行链接压住「一键导入」）→ 按钮点开可复制
        P.urlBtn = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
        P.urlBtn:SetSize(80, 26); P.urlBtn:SetPoint("LEFT", P.imp, "RIGHT", 8, 0)
        P.urlBtn:SetText(T("MR_URL_BTN", "原链接"))
        P.urlBtn:SetScript("OnClick", function()
            if P.url then GearInsight:ShowCopyText(P.url, T("MR_URL_COPY", "Ctrl+C 复制，到浏览器打开（路线版权归原作者）"), T("MR_URL_BTN", "原链接")) end
        end)
        P.urlBtn:Hide()
        box:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10,
            insets = { left = 2, right = 2, top = 2, bottom = 2 } })
        box:SetBackdropColor(0, 0, 0, 0.5); box:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)
        local eb = CreateFrame("EditBox", nil, box)
        eb:SetPoint("TOPLEFT", 6, -4); eb:SetPoint("BOTTOMRIGHT", -6, 4)
        eb:SetAutoFocus(false); eb:SetFontObject("ChatFontSmall")
        eb:SetScript("OnEscapePressed", function(e) e:ClearFocus() end)
        eb:SetScript("OnEditFocusGained", function(e) e:HighlightText() end)
        eb:SetScript("OnTextChanged", function(e, user) if user then e:SetText(P.code or ""); e:HighlightText() end end)
        P.box = eb
        P.hint = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        P.hint:SetPoint("TOPLEFT", P.imp, "BOTTOMLEFT", 0, -6); P.hint:SetPoint("RIGHT", page, "RIGHT", -14, 0); P.hint:SetJustifyH("LEFT")
        -- 每一波（只在「本专精前 2」时有内容）
        P.pullHd = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        -- 10-01「列表和装备图两个视图兼容」：列表模式只有 520 宽，上面那行提示会折成两行 → 下面几块跟着提示往下排，不写死高度
        P.pullHd:SetPoint("TOPLEFT", P.hint, "BOTTOMLEFT", 0, -8)
        P.pullHd:SetText(T("MR_PULLS_HD_FULL", "每一波（这位玩家这一波开的大招 / 打断 / 驱散）"))
        local sf = CreateFrame("ScrollFrame", nil, page, "UIPanelScrollFrameTemplate")
        sf:SetPoint("TOPLEFT", P.pullHd, "BOTTOMLEFT", 0, -6); sf:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -32, 96)
        local child = CreateFrame("Frame", nil, sf)
        child:SetSize(300, 10)
        sf:SetScrollChild(child)
        local fs = child:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("TOPLEFT", 2, -2); fs:SetJustifyH("LEFT"); fs:SetSpacing(4); fs:SetWidth(296)
        sf:SetScript("OnSizeChanged", function(_, w)
            child:SetWidth(math.max(120, (w or 300) - 6)); fs:SetWidth(math.max(120, (w or 300) - 10))
            if P._pullsE ~= nil or P._pullsEmpty then renderPulls(P, P._pullsE, P._pullsEmpty) end   -- 面板宽度变了（列表 / 装备图）重排
        end)
        fs:Hide()                                   -- 每一波改用技能块排版（renderPulls），这个文本只留作兜底
        P.pullSF, P.pullChild, P.pullFS = sf, child, fs
        -- 底部：数据说明 + 站外入口
        P.foot = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        P.foot:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", X, 64); P.foot:SetPoint("RIGHT", page, "RIGHT", -14, 0)
        P.foot:SetJustifyH("LEFT")
        -- 站外入口（用户 2026-10-01「直接导引到网站…点击弹出一个框，可以复制网址」；按钮文字定为「更多路线攻略」）。
        -- ⛔ 只写「更多路线攻略」，插件里不出现任何付费 / 解锁字样（暴雪插件政策：插件全免费、不招揽付费）。
        P.more = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
        P.more:SetSize(150, 24)
        P.more:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", X, 12)
        P.more:SetText(T("MR_MORE_BTN", "更多路线攻略"))
        P.more:SetScript("OnClick", function()
            GearInsight:ShowCopyText(siteURL(P.key), T("MR_MORE_COPY", "Ctrl+C 复制，到浏览器打开（会自动打开你这个专精，并绑定当前角色）"), T("MR_MORE_BTN", "更多路线攻略"))
        end)
        -- 钉到屏幕（ui/MdtRouteBar.lua；10-01 用户「要能够钉在战术板视角，战斗中，进本以后一步步查看」「默认关闭」）
        P.pin = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
        P.pin:SetSize(130, 24); P.pin:SetPoint("LEFT", P.more, "RIGHT", 8, 0)
        P.pin:SetScript("OnClick", function()
            if GearInsight:RouteBarShown() then GearInsight:HideRouteBar()
            else GearInsight:ShowRouteBar(P.key, P.barVi or P.vi or 1, P.barSrc or "spec") end
            P.pinSync()
        end)
        P.pin:SetScript("OnEnter", function(b)
            GameTooltip:SetOwner(b, "ANCHOR_TOP")
            GameTooltip:SetText(T("MR_PIN_TT", "把这条路线钉成屏幕上的半透明小条：进本后按钥石「敌方部队」进度自动翻到当前第几波，显示这一波这位高手开的大招 / 打断 / 驱散。战斗中也能看，可手动 < > 校正。"), 1, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        P.pin:SetScript("OnLeave", function() GameTooltip:Hide() end)
        -- 导入路线串（10-04）：网站路线详情「复制到插件」→ 这里粘贴；和内置第 1 名并排显示，也能钉到领航条
        P.girBtn = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
        P.girBtn:SetSize(110, 24); P.girBtn:SetPoint("LEFT", P.pin, "RIGHT", 8, 0)
        P.girBtn:SetText(T("MR_GIR_BTN", "导入路线串"))
        P.girBtn:SetScript("OnClick", function() GearInsight:ShowRouteImport(page) end)
        P.girBtn:SetScript("OnEnter", function(b)
            GameTooltip:SetOwner(b, "ANCHOR_TOP")
            GameTooltip:SetText(T("MR_GIR_TT", "在网站路线详情点「复制到插件」，把路线串粘贴进来：这条路线会出现在第 1 名旁边，每一波带技能，也能钉到屏幕。每本最多存 5 条。"), 1, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        P.girBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        P.girDel = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
        P.girDel:SetSize(90, 24); P.girDel:SetPoint("LEFT", P.girBtn, "RIGHT", 6, 0)
        P.girDel:SetText(T("MR_GIR_DEL", "删除这条"))
        P.girDel:SetScript("OnClick", function()
            if P.curImp then
                GearInsight.DeleteImportedRoute(P.key, P.curImp)
                GearInsight:Print(T("MR_GIR_DELETED", "已删除这条导入的路线"))
                GearInsight:SelectMdtRoute(page, P.key, 1)
            end
        end)
        P.girDel:Hide()
        P.auto = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
        P.auto:SetSize(22, 22); P.auto:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 162, 38)
        P.auto.text:SetText(T("MR_AUTO", "进大秘境自动显示")); P.auto.text:SetFontObject("GameFontHighlightSmall")
        P.auto:SetScript("OnClick", function(b) GearInsight:RouteBarAuto(b:GetChecked()) end)
        -- 名牌框（领航条并入原拉怪领航后的开关，默认关）：本波金框 / 下一波灰框 / 不在路线里红框
        P.plates = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
        P.plates:SetSize(22, 22); P.plates:SetPoint("LEFT", P.auto.text, "RIGHT", 16, 0)
        P.plates.text:SetText(T("MR_PLATES", "名牌框标记本波的怪")); P.plates.text:SetFontObject("GameFontHighlightSmall")
        -- 10-03：副本里暴雪把名牌的 GUID 和名字都设成保密值，认不出怪 → 用户定去掉这个选项（MdtRouteBar.lua _routePlatesEnabled）
        if not GearInsight._routePlatesEnabled then P.plates:Hide() end
        -- 10-03 名牌框的替代：领航条小地图 + 怪物头像（默认开，地图借 MDT 的图）/ 换波语音播报（默认关）
        local function optCb(anchor, key, label, tip)
            local cb = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
            cb:SetSize(22, 22); cb:SetPoint("LEFT", anchor, "RIGHT", 16, 0)
            cb.text:SetText(label); cb.text:SetFontObject("GameFontHighlightSmall")
            cb:SetScript("OnClick", function(b) GearInsight:RouteBarOpt(key, b:GetChecked()) end)
            cb:SetScript("OnEnter", function(b) GameTooltip:SetOwner(b, "ANCHOR_TOP"); GameTooltip:SetText(tip, 1, 1, 1, 1, true); GameTooltip:Show() end)
            cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
            return cb
        end
        P.mapCb = optCb(P.auto.text, "mapOn", T("MR_OPT_MAP", "小地图 + 怪物头像"),
            T("MR_OPT_MAP_TT", "领航条下面显示本波位置：金点 = 本波的怪，灰点 = 下一波，箭头指向下一波；上面一排是本波怪的 3D 头像。地图借用 Mythic Dungeon Tools 的图片，没装 MDT 时只显示头像。"))
        P.ttsCb = optCb(P.mapCb.text, "tts", T("MR_OPT_TTS", "语音播报"),
            T("MR_OPT_TTS_TT", "换到新的一波时，用游戏自带的文字转语音念出「第几波、几只什么、在哪」。声音和语速在 游戏设置 → 无障碍 → 文字转语音 里调。"))
        P.markCb = optCb(P.ttsCb.text, "mark", T("MR_OPT_MARK", "点头像打标记"),
            T("MR_OPT_MARK_TT", "点领航条上的怪物头像时，选中这种怪并打上团队标记（第 1 种骷髅、第 2 种叉、第 3 种方块…，头像左上角有同款图标）。单人或队长 / 助理才打得上。插件没法不点就自动标：暴雪在副本里把怪的身份加密了，插件认不出哪只是哪只。"))
        -- 10-04 截图「组件在窗体外面了」：四个勾选框写死排一行，列表视图（窄）时「点头像打标记」伸出窗口右边 →
        --   按文字实际宽度排，放不下就换到第二行；页脚说明和「每一波」列表跟着往上让
        function P.layoutOpts()
            local W = (page.GetWidth and page:GetWidth()) or 0
            if W < 300 then W = 740 end
            local x0, maxX = 162, W - 14
            local items = {}
            for _, cb in ipairs({ P.auto, P.plates, P.mapCb, P.ttsCb, P.markCb }) do
                if cb and cb:IsShown() then items[#items + 1] = cb end
            end
            local rows, x, place = 0, x0, {}
            for _, cb in ipairs(items) do
                local tw = (cb.text.GetStringWidth and cb.text:GetStringWidth()) or 80
                if type(tw) ~= "number" then tw = 80 end
                local w = 22 + 4 + tw + 16
                if x + w > maxX and x > x0 then rows = rows + 1; x = x0 end
                place[#place + 1] = { cb, x, rows }
                x = x + w
            end
            local extra = rows * 24
            for _, it in ipairs(place) do
                it[1]:ClearAllPoints()
                it[1]:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", it[2], 38 + (rows - it[3]) * 24)
            end
            P.foot:ClearAllPoints()
            P.foot:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", X, 64 + extra); P.foot:SetPoint("RIGHT", page, "RIGHT", -14, 0)
            if P.pullSF then
                P.pullSF:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -32, 96 + extra)
            end
        end
        if page.HookScript then page:HookScript("OnSizeChanged", function() P.layoutOpts() end) end
        P.plates:SetScript("OnClick", function(b) GearInsight:RouteBarPlates(b:GetChecked()) end)
        P.plates:SetScript("OnEnter", function(b)
            GameTooltip:SetOwner(b, "ANCHOR_TOP")
            GameTooltip:SetText(T("MR_PLATES_TT", "领航条钉着时，给怪物名牌加框：本波要拉的金框、下一波灰框、不在路线里的红框（按怪的种类认，不分具体哪一只）。"), 1, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        P.plates:SetScript("OnLeave", function() GameTooltip:Hide() end)
        function P.pinSync()
            P.pin:SetText(GearInsight:RouteBarShown() and T("MR_UNPIN", "取消钉屏") or T("MR_PIN", "钉到屏幕"))
            P.pin:SetEnabled((P.mode == "spec" or P.mode == "mid" or P.mode == "comm") and P.code ~= nil and P.code ~= "")
            P.auto:SetChecked(GearInsight:RouteBarAuto())
            P.plates:SetChecked(GearInsight:RouteBarPlates())
            if GearInsight.RouteBarOpt then P.mapCb:SetChecked(GearInsight:RouteBarOpt("mapOn")); P.ttsCb:SetChecked(GearInsight:RouteBarOpt("tts")); P.markCb:SetChecked(GearInsight:RouteBarOpt("mark")) end
        end
        GearInsight._routeBarHook = P.pinSync
    end
    self:SelectMdtRoute(page, P.key or defaultKey(), P.vi or 1)
end

-- 名次卡片自动排（10-04「UI 优化」：社区经典 5 张排一行伸出边框）：一行最多 3 张，卡宽按页面宽度算，多了换行
local function placeTab(P, page, b, i, n)
    local W = ((page.GetWidth and page:GetWidth()) or 0)
    if W < 300 then W = 740 end
    W = W - 166 - 14
    local per = math.min(n, 3)
    local cw = math.min(162, math.floor((W - (per - 1) * 4) / per))
    local row, col = math.floor((i - 1) / per), (i - 1) % per
    b:SetSize(cw, 38)
    b:ClearAllPoints(); b:SetPoint("TOPLEFT", 166 + col * (cw + 4), -64 - row * 42)
    P.tabRows = math.ceil(n / per)
end
-- 浏览量写短：中文「11.8 万」，其它「118k」
local function shortNum(n)
    n = n or 0
    if GearInsight.LOCALE == "zhCN" or GearInsight.LOCALE == "zhTW" then
        if n >= 10000 then return string.format("%.1f%s", n / 10000, GearInsight.LOCALE == "zhTW" and "萬" or "万") end
        return tostring(n)
    end
    if n >= 1000 then return string.format("%.0fk", n / 1000) end
    return tostring(n)
end

function GearInsight:SelectMdtRoute(page, key, vi)
    local P = page and page._mr
    if not P then return end
    P.key, P.vi = key, vi or 1
    P.curImp = nil
    GearInsightDB = GearInsightDB or {}
    GearInsightDB.mdtRouteKey = key
    for _, b in ipairs(P.dgBtns) do
        if b._key == key then b:LockHighlight() else b:UnlockHighlight() end
    end
    local d
    for _, x in ipairs(GearInsightMdtRouteOrder or {}) do if x.key == key then d = x end end
    local r = GearInsightMdtRoutes and GearInsightMdtRoutes[key]
    local sid = curSpecID()
    local list = GearInsight.MdtSpecList("spec", sid, key)   -- 内置第 1 名 + 网站复制来导入的（10-04）
    if list and #list == 0 then list = nil end
    local midList = GearInsightMdtMidRoutes and GearInsightMdtMidRoutes[key]
    if midList and #midList == 0 then midList = nil end
    -- +12 页（10-03「对齐高手层」）：先放本专精 +12 档前 2 名（天赋库「割草」，每波带他按的技能），再接常规路线统计卡片
    local list12 = GearInsight.MdtSpecList("s12", sid, key)
    local combo = {}
    for i, x in ipairs(list12 or {}) do combo[#combo + 1] = { kind = "s12", e = x, vi = i } end
    for i, x in ipairs(midList or {}) do if #combo < #P.tabs then combo[#combo + 1] = { kind = "mid", e = x, vi = i } end end
    if #combo == 0 then combo = nil end
    local commList = GearInsightMdtCommunityRoutes and GearInsightMdtCommunityRoutes[key]
    if commList and #commList == 0 then commList = nil end
    P.mode = list and "spec" or "stat"
    if P.src == "mid" and combo then P.mode = "mid" end
    if P.src == "comm" and commList then P.mode = "comm" end
    P.barSrc, P.barVi, P.url = nil, nil, nil
    if P.srcSpec then
        P.srcSpec:UnlockHighlight(); P.srcMid:UnlockHighlight(); P.srcComm:UnlockHighlight()
        if P.mode == "mid" then P.srcMid:LockHighlight() elseif P.mode == "comm" then P.srcComm:LockHighlight() else P.srcSpec:LockHighlight() end
        P.srcMid:SetEnabled(combo ~= nil); P.srcComm:SetEnabled(commList ~= nil)
    end
    -- 日志拆不清（一波连拉超过 12 组，生成时标 gateFail）→ 路线换成社区经典第一条，并写明（10-04 用户：日志拆得好就用，否则用经典路线填充）
    local function fallback(e)
        if not (e and e.gateFail and commList) then return nil end
        local c = commList[1]
        P.barSrc, P.barVi = "comm", 1
        P.url = c.url
        return c, "\n|cFFFF9F40" .. string.format(T("MR_FALLBACK", "这局日志拆不清（一波连拉超过 12 组），已改显示社区经典路线：%s（%s）"), c.author or "?", c.source or "") .. "|r"
    end
    local multi
    if P.mode == "comm" then
        local e = commList[P.vi] or commList[1]
        P.vi = (commList[P.vi] and P.vi) or 1
        P.barSrc, P.barVi = "comm", P.vi
        P.title:SetText(dname(d) .. " · " .. T("MR_TITLE_COMM", "社区经典路线"))
        multi = #commList > 1
        for i, b in ipairs(P.tabs) do
            local x = commList[i]
            b:SetShown(x ~= nil and multi)
            if x then
                placeTab(P, page, b, i, #commList)
                local nw = {}
                for _, p in ipairs(x.pulls or {}) do nw[p.w or #nw + 1] = true end
                local nwc = 0
                for _ in pairs(nw) do nwc = nwc + 1 end
                b:SetLines("|cFFFFD100" .. (x.author ~= "" and x.author or "?") .. "|r",
                    string.format(T("MR_COMM_CARD2S", "%d 波 · 浏览 %s"), nwc, shortNum(x.views)))
                b._tip = { x.title or "", string.format(T("MR_COMM_TIP1", "作者：%s · 来源：%s"), x.author or "?", x.source or ""),
                    x.url or "", "|cFF8A93A6" .. T("MR_TIP_CLICK_ROUTE", "点击在地图上看这条路线") .. "|r" }
                b:SetSel(i == P.vi)
            end
        end
        P.info:SetText(string.format(T("MR_INFO_COMM2", "%s\n作者 %s · %s · 浏览 %s"), e.title or "", e.author or "?", e.source or "", shortNum(e.views)))
        P.url = e.url
        P.r, P.v, P.code = { idx = r and r.idx or 0 }, { name = e.name, code = e.code }, e.code
        renderPulls(P, e)
        local nn = 0
        for _, p in ipairs(e.pulls or {}) do nn = nn + #(p.nt or {}) end
        P.pullHd:SetText(nn > 0 and string.format(T("MR_PULLS_HD_COMM_N", "每一波 · 作者解说 %d 条（便签图标）"), nn)
            or T("MR_PULLS_HD_COMM", "每一波（作者在 MDT 里排的拉怪）"))
        P.pullHd:Show(); P.pullSF:Show()
        P.foot:SetText(T("MR_FOOT_COMM", "社区经典路线来自 keystone.guru / wago.io，版权归原作者；按站内热度排序，每周更新。"))
    elseif P.mode == "mid" then
        local it = combo[P.vi] or combo[1]
        P.vi = (combo[P.vi] and P.vi) or 1
        local e = it.e
        P.curImp = (it.kind == "s12" and e.imported) and (e._src or e) or nil
        P.barSrc, P.barVi = it.kind, it.vi
        P.title:SetText(dname(d) .. " · " .. string.format(T("MR_TITLE_S12_1", "+12 · %s 第 1 名 + 常规路线"), specName(sid)))
        multi = #combo > 1
        for i, b in ipairs(P.tabs) do
            local c = combo[i]
            b:SetShown(c ~= nil and multi)
            if c then
                local x = c.e
                placeTab(P, page, b, i, #combo)
                if c.kind == "s12" then
                    b:SetLines((x.imported and ("|cFF66CCFF" .. T("MR_IMPORTED", "导入") .. "|r ") or "") .. "|cFFFFD100+12 #" .. (x.rank or c.vi) .. "|r  |c" .. classHex(x.sid or sid) .. (x.player or "") .. "|r",
                        (x.server or "") .. " · " .. regionName(x.region) .. ((x.key and x.key > 0) and (" · +" .. x.key .. " " .. (x.time or "")) or ""))
                    local tip = { "+12 #" .. (x.rank or c.vi) .. "  |c" .. classHex(sid) .. (x.player or "") .. "|r", (x.server or "") .. " · " .. regionName(x.region) }
                    if x.key and x.key > 0 then tip[#tip + 1] = string.format("+%d %s %s", x.key, x.timed and T("MR_TIMED", "限时") or T("MR_OVER", "超时"), x.time or "") end
                    if heroName(x) ~= "" then tip[#tip + 1] = T("MR_TIP_HERO", "英雄天赋：") .. heroName(x) end
                    tip[#tip + 1] = string.format(T("MR_TIP_RANK12", "天赋库 +12 第 %d 名（Warcraft Logs）"), x.rank or c.vi)
                    tip[#tip + 1] = "|cFF8A93A6" .. (x.code and T("MR_TIP_CLICK", "点击在地图上看他这一局的路线") or T("MR_NO_ROUTE", "这局的日志没有公开，暂无路线。")) .. "|r"
                    b._tip = tip
                else
                    local share = (x.runs and x.runs > 0) and math.floor(x.followers * 100 / x.runs + 0.5) or 0
                    b:SetLines(string.format(T("MR_MID_CARD1", "|cFFFFD100路线 %d|r  %d%% 的人这么走"), c.vi, share),
                        string.format(T("MR_MID_CARD2", "+12 %s · %d 波"), x.time or "", #(x.pulls or {})))
                    b._tip = { string.format(T("MR_MID_TIP1", "+12 常规路线 %d"), c.vi),
                        string.format(T("MR_MID_TIP2", "抽样 %d 局 +12 对局里，%d 局走这条（%d%%）"), x.runs or 0, x.followers or 0, share),
                        string.format(T("MR_MID_TIP3", "代表局：+12 %s %s · 计数 %.1f%%"), x.timed and T("MR_TIMED", "限时") or T("MR_OVER", "超时"), x.time or "", x.pct or 0),
                        T("MR_MID_TIP4", "统计路线没有个人技能"),
                        "|cFF8A93A6" .. T("MR_TIP_CLICK_ROUTE", "点击在地图上看这条路线") .. "|r" }
                end
                b:SetSel(i == P.vi)
            end
        end
        if it.kind == "s12" then
            local timed = e.timed and T("MR_TIMED", "限时") or T("MR_OVER", "超时")
            P.info:SetText(string.format(T("MR_INFO_S12", "+%d %s %s · %s\n%s · %s · 天赋库 +12 第 %d 名"),
                e.key or 0, timed, e.time or "", heroName(e), e.server or "", regionName(e.region), e.rank or 0))
            -- 10-04 用户「插件暂时都可以给看」：数据带每波技能时不再提「见网站 / 小程序」
            if e.noSpells then
                P.pullHd:SetText(T("MR_PULLS_HD_NS", "每一波（每波技能见网站 / 小程序）"))
                P.foot:SetText(T("MR_FOOT_S12_1", "插件显示本专精 +12 第 1 名的路线；第 2–10 名和每一波的大招 / 打断 / 驱散，在网站 / 小程序查看。"))
            else
                P.pullHd:SetText(T("MR_PULLS_HD_FULL", "每一波（这位玩家这一波开的大招 / 打断 / 驱散）"))
                P.foot:SetText(T("MR_FOOT_ONE", "插件受内存限制，每本只放第 1 名。第 2–3 名和更多路线请到网站查看，在网站复制路线串后可在这里导入。"))
            end
        else
            local share = (e.runs and e.runs > 0) and math.floor(e.followers * 100 / e.runs + 0.5) or 0
            P.info:SetText(string.format(T("MR_INFO_MID", "+12 常规路线 %d · 抽样 %d 局里 %d 局这么走（%d%%）\n代表局 +12 %s %s · 计数 %.1f%%"),
                it.vi, e.runs or 0, e.followers or 0, share, e.timed and T("MR_TIMED", "限时") or T("MR_OVER", "超时"), e.time or "", e.pct or 0))
            P.pullHd:SetText(T("MR_PULLS_HD_MID", "每一波（一次战斗算一波）"))
            P.foot:SetText(string.format(T("MR_FOOT_MID", "Warcraft Logs +12 限时对局抽样（%s）· 地图 / 怪物 / 计数来自 Mythic Dungeon Tools"), GearInsightMdtRoutesDate or "?"))
        end
        local fb, note = nil, nil
        if it.kind == "s12" then fb, note = fallback(e) end
        if note then P.info:SetText((P.info:GetText() or "") .. note) end
        local show = fb or e
        if show.code then
            P.r, P.v, P.code = { idx = r and r.idx or 0 }, { name = show.name, code = show.code }, show.code
            renderPulls(P, show)
        else
            P.r, P.v, P.code = nil, nil, ""
            renderPulls(P, nil, T("MR_NO_ROUTE", "这局的日志没有公开，暂无路线。"))
        end
        P.pullHd:Show(); P.pullSF:Show()
    elseif P.mode == "spec" then
        local full = list and list[1] and not list[1].noSpells
        P.pullHd:SetText(full and T("MR_PULLS_HD_FULL", "每一波（这位玩家这一波开的大招 / 打断 / 驱散）") or T("MR_PULLS_HD_NS", "每一波（每波技能见网站 / 小程序）"))
        -- 本专精前 2：r 只给导入用（idx = MDT 副本序号）
        local e = list[P.vi] or list[1]
        P.curImp = e.imported and (e._src or e) or nil
        P.vi = (list[P.vi] and P.vi) or 1
        local nImp = 0
        for _, x in ipairs(list) do if x.imported then nImp = nImp + 1 end end
        P.title:SetText(dname(d) .. " · " .. string.format(T("MR_TITLE_SPEC_1", "%s 第 1 名"), specName(sid))
            .. (nImp > 0 and string.format(T("MR_TITLE_IMP", " + 导入 %d 条"), nImp) or ""))
        multi = #list > 1
        for i, b in ipairs(P.tabs) do
            local x = list[i]
            b:SetShown(x ~= nil and multi)
            if x then
                placeTab(P, page, b, i, #list)
                b:SetLines((x.imported and ("|cFF66CCFF" .. T("MR_IMPORTED", "导入") .. "|r ") or "") .. "|cFFFFD100#" .. (x.rank or i) .. "|r  |c" .. classHex(x.sid or sid) .. (x.player or "") .. "|r",
                    (x.server or "") .. " · " .. regionName(x.region) .. ((x.key and x.key > 0) and (" · +" .. x.key .. " " .. (x.time or "")) or ""))
                local tip = { "#" .. (x.rank or i) .. "  |c" .. classHex(sid) .. (x.player or "") .. "|r",
                    (x.server or "") .. " · " .. regionName(x.region) }
                if x.key and x.key > 0 then
                    tip[#tip + 1] = string.format("+%d %s %s", x.key, x.timed and T("MR_TIMED", "限时") or T("MR_OVER", "超时"), x.time or "")
                end
                if heroName(x) ~= "" then tip[#tip + 1] = T("MR_TIP_HERO", "英雄天赋：") .. heroName(x) end
                tip[#tip + 1] = string.format(T("MR_TIP_RANK", "天赋库冲分第 %d 名（Warcraft Logs）"), x.rank or i)
                tip[#tip + 1] = "|cFF8A93A6" .. (x.code and T("MR_TIP_CLICK", "点击在地图上看他这一局的路线") or T("MR_NO_ROUTE", "这局的日志没有公开，暂无路线。")) .. "|r"
                b._tip = tip
                b:SetSel(i == P.vi)
            end
        end
        local timed = e.timed and T("MR_TIMED", "限时") or T("MR_OVER", "超时")
        local fb, note = fallback(e)
        P.info:SetText(string.format(T("MR_INFO_SPEC", "+%d %s %s · %s\n%s · %s · 天赋库冲分第 %d 名"),
            e.key or 0, timed, e.time or "", heroName(e), e.server or "", regionName(e.region), e.rank or 0) .. (note or ""))
        if fb then
            P.r, P.v, P.code = { idx = r and r.idx or 0 }, { name = fb.name, code = fb.code }, fb.code
            renderPulls(P, fb)
        elseif e.code then
            P.r, P.v, P.code = { idx = r and r.idx or 0 }, { name = e.name, code = e.code }, e.code
            renderPulls(P, e)
        else
            P.r, P.v, P.code = nil, nil, ""
            renderPulls(P, nil, T("MR_NO_ROUTE", "这局的日志没有公开，暂无路线。"))
        end
        P.pullHd:Show(); P.pullSF:Show()
        if full then
            P.foot:SetText(T("MR_FOOT_ONE", "插件受内存限制，每本只放第 1 名。第 2–3 名和更多路线请到网站查看，在网站复制路线串后可在这里导入。"))
        else
            P.foot:SetText(T("MR_FOOT_SPEC_1", "插件显示本专精高层第 1 名的路线；第 2–10 名和每一波的大招 / 打断 / 驱散，在网站 / 小程序查看。"))
        end
    else
        local v = r and r.routes and (r.routes[P.vi] or r.routes[1])
        P.title:SetText(dname(d) .. " · " .. T("MR_TITLE", "高手实战路线"))
        P.pullHd:Hide(); P.pullSF:Hide()
        P.foot:SetText((list == nil and sid and T("MR_NO_SPEC_DATA", "这个副本暂时没有你这个专精的前 2 名数据，先显示统计路线。  ") or "")
            .. string.format(T("MR_FOOT", "数据来自 Warcraft Logs 高层限时对局（%s）· 地图 / 怪物 / 计数来自 Mythic Dungeon Tools"), GearInsightMdtRoutesDate or "?"))
        if not v then
            P.r, P.v, P.code = nil, nil, ""
            for _, b in ipairs(P.tabs) do b:Hide() end
            P.info:SetText(T("MR_NONE", "这个副本还没有高手路线数据"))
            P.imp:Disable(); P.box:SetText(""); P.hint:SetText("")
            return
        end
        P.r, P.v, P.code = r, v, v.code
        multi = #r.routes > 1
        for i, b in ipairs(P.tabs) do
            local rv = r.routes[i]
            b:SetShown(rv ~= nil and multi)
            if rv then
                b:SetSize(120, 24)
                b:ClearAllPoints(); b:SetPoint("TOPLEFT", 166 + (i - 1) * 126, -67)
                b:SetLines(string.format("|cFFFFD100+%d|r  %s", rv.key, rv.time))
                b._tip = { string.format("+%d %s %s", rv.key, rv.timed and T("MR_TIMED", "限时") or T("MR_OVER", "超时"), rv.time or ""),
                    string.format(T("MR_TIP_VARIANT", "%d 波 · 计数 %.1f%% · %d 局高层对局走这条路线"), rv.pulls or 0, rv.pct or 0, rv.followers or 0),
                    "|cFF8A93A6" .. T("MR_TIP_CLICK_ROUTE", "点击在地图上看这条路线") .. "|r" }
                b:SetSel(i == P.vi)
            end
        end
        P.info:SetText(variantText(r, v))
    end
    P.info:ClearAllPoints()
    local infoY = -70
    if multi then infoY = (P.mode == "stat") and -110 or (-64 - (P.tabRows or 1) * 42 - 4) end
    P.info:SetPoint("TOPLEFT", 166, infoY); P.info:SetPoint("RIGHT", page, "RIGHT", -14, 0)
    P.urlBtn:SetShown(P.url ~= nil)
    if P.girDel then P.girDel:SetShown(P.curImp ~= nil and (P.mode == "spec" or P.mode == "mid")) end
    P.box2:ClearAllPoints()
    P.box2:SetPoint("LEFT", P.url and P.urlBtn or P.imp, "RIGHT", 10, 0); P.box2:SetPoint("RIGHT", page, "RIGHT", -14, 0)
    P.imp:SetEnabled(mdtAPI() ~= nil and P.code ~= nil and P.code ~= "")
    P.box:SetText(P.code or ""); P.box:SetCursorPosition(0)
    P.hint:SetText(mdtAPI() and T("MR_HINT2", "点「一键导入 MDT」即可；也可以 Ctrl+C 复制上面的串，在 MDT 里点「导入」粘贴。")
        or T("MR_HINT", "Ctrl+C 复制 → 打开 MDT → 点「导入」粘贴。"))
    if P.pullSF.SetVerticalScroll then P.pullSF:SetVerticalScroll(0) end
    if P.layoutOpts then P.layoutOpts() end
    if P.pinSync then P.pinSync() end
    -- 钉着的条跟着页签切换（换副本 / 换第几名）
    if (P.mode == "spec" or P.mode == "mid" or P.mode == "comm") and GearInsight.RouteBarShown and GearInsight:RouteBarShown() then
        GearInsight:ShowRouteBar(P.key, P.barVi or P.vi or 1, P.barSrc or "spec")
    end
    -- 每一波的高度由 renderPulls 按技能块排完后设置
end
