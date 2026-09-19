-- 「逃课」页（用户 2026-09-17：「把这个做到网站搞个逃课模块，小程序，插件都加上，插件内最好和一些定位插件能力联合」）。
-- 数据 core/CheeseData.lua（generate_cheese_lua.py ← cheese_tips.json，与网站 /wow/en/cheese、小程序同一份）。
-- 每一步带坐标的给「标记」按钮：
--   · 暴雪原生：C_Map.SetUserWaypoint + C_SuperTrack 超级追踪（不装任何插件也能用，小地图/屏幕上直接出箭头）
--   · 装了 TomTom 再加一个 TomTom 路点（它的箭头 + 距离更好用）
--   · 「复制 /way」= 贴到聊天框的 /way 命令，给用别的定位插件的人
-- ⛔ mapIds 是候选：12.x 同名地图有多个 uiMapID，按 C_Map.CanSetUserWaypointOnMap 挑第一个能打点的。
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

-- 逃课数据字段本地化：中文客户端用原文，其它语言优先 *En 字段（generate_cheese_lua.py 写入），缺则回退中文
local _ZH = (_LOCALE == "zhCN" or _LOCALE == "zhTW")
local function CL(o, k)
    if not o then return "" end
    if _ZH then return o[k] or "" end
    local v = o[k .. "En"]
    if v and v ~= "" then return v end
    return o[k] or ""
end
GearInsight.CheeseL = CL
local GOLD = { 1, 0.82, 0 }

-- 游戏日（北京时间 07:00 服务器更新为界，用户 2026-09-17）：GetServerTime 是 UTC 秒，+8h 到北京，-7h 让 07:00 归到新一天
function GearInsight.CheeseGameDay()
    local t = (GetServerTime and GetServerTime()) or time()
    return date("!%Y-%m-%d", t + 8 * 3600 - 7 * 3600)
end
function GearInsight.CheeseValid()
    local D = _G.GearInsightCheese
    return D and D.items and #D.items > 0 and D.forDate == GearInsight.CheeseGameDay()
end

local function pickMap(ids)
    for _, id in ipairs(ids or {}) do
        local info = C_Map.GetMapInfo and C_Map.GetMapInfo(id)
        if info and (not C_Map.CanSetUserWaypointOnMap or C_Map.CanSetUserWaypointOnMap(id)) then
            return id, info.name
        end
    end
    for _, id in ipairs(ids or {}) do
        local info = C_Map.GetMapInfo and C_Map.GetMapInfo(id)
        if info then return id, info.name end
    end
    return nil
end

-- 打点：返回 ok, msg
function GearInsight:CheeseWaypoint(step, title)
    if not (step.x and step.y and step.mapIds and #step.mapIds > 0) then return false, "no coord" end
    -- ⛔ 2026-09-17 用户「点了标记不出箭头」：原来只试候选表里第一张能 GetMapInfo 的图，SetUserWaypoint 一 pcall 失败就静默。
    --    现在逐张候选试到成功为止，原生路点和 TomTom 各自记录结果，聊天框把用了哪张图、哪一步失败说清楚。
    local nativeOK, nativeMap, nativeErr = false, nil, nil
    local candidates = {}
    for _, id in ipairs(step.mapIds) do
        local info = C_Map.GetMapInfo and C_Map.GetMapInfo(id)
        if info then candidates[#candidates + 1] = { id = id, name = info.name } end
    end
    if #candidates == 0 then return false, T("CH_NO_MAP", "认不出这张地图（版本变了？）") end
    if C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates then
        for _, c in ipairs(candidates) do
            local canSet = (not C_Map.CanSetUserWaypointOnMap) or C_Map.CanSetUserWaypointOnMap(c.id)
            if canSet then
                local pt = UiMapPoint.CreateFromCoordinates(c.id, step.x / 100, step.y / 100)
                local okc, err = pcall(C_Map.SetUserWaypoint, pt)
                if okc then
                    nativeOK, nativeMap = true, c
                    -- ⛔ 路点是异步落地的：紧接着开超级追踪会被无视（用户 2026-09-17「已标记但没有箭头」）。
                    --    立刻开一次，再延迟 0.3s / 1s 各开一次，箭头才稳出。
                    local function track()
                        if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint and C_Map.HasUserWaypoint and C_Map.HasUserWaypoint() then
                            pcall(C_SuperTrack.SetSuperTrackedUserWaypoint, true)
                        end
                    end
                    track()
                    if C_Timer and C_Timer.After then C_Timer.After(0.3, track); C_Timer.After(1.0, track) end
                    break
                else
                    nativeErr = tostring(err)
                end
            else
                nativeErr = "map " .. c.id .. " 不允许打点"
            end
        end
    end
    local ttOK = false
    if _G.TomTom and _G.TomTom.AddWaypoint then
        local c = nativeMap or candidates[1]
        local okt, err = pcall(_G.TomTom.AddWaypoint, _G.TomTom, c.id, step.x / 100, step.y / 100,
              { title = title or CL(step, "text"), persistent = false, minimap = true, world = true, crazy = true, from = "GearInsight" })
        ttOK = okt and true or false
        -- 强制把 TomTom 的箭头指到这条路点上（它默认只指「最近的一条」，跨地图的点常常不接管）
        local uid = okt and err or nil
        local arrowMsg
        -- SetCrazyArrow(uid, arrivaldistance, title)：第三参不传，箭头上就写「未知路径点」
        if uid and _G.TomTom.SetCrazyArrow then
            -- ⛔ dist 绝不能是 nil：TomTom 箭头 OnUpdate 里每帧 `dist <= arrive_distance`，nil 就每帧报错 → 「界面错误太多」+ 箭头变成整张贴图
            local dist = tonumber(uid.arrivaldistance) or (_G.TomTom.profile and _G.TomTom.profile.arrow and tonumber(_G.TomTom.profile.arrow.arrival)) or 15
            local ttl = uid.title or title or CL(step, "text") or "GearInsight"
            local oka, ea = pcall(_G.TomTom.SetCrazyArrow, _G.TomTom, uid, dist, ttl)
            if not oka then GearInsight:Print("|cffff5555TomTom 箭头失败：" .. tostring(ea) .. "|r") end
        elseif not uid then
            GearInsight:Print("|cffff5555TomTom 没返回路点，可能地图 " .. tostring(c.id) .. " 不被支持|r")
        end
        if not okt then GearInsight:Print("|cffff5555TomTom 路点失败：" .. tostring(err) .. "|r") end
    end
    if nativeOK or ttOK then
        local c = nativeMap or candidates[1]
        return true, string.format(T("CH_WP_OK", "已标记 %s %.1f / %.1f（屏幕上跟着箭头走；Shift+点小地图图钉可取消）"), c.name or "", step.x, step.y)
            .. (nativeOK and "" or ("  |cffaaaaaa原生路点未成功：" .. tostring(nativeErr) .. "|r"))
    end
    return false, T("CH_WP_FAIL", "这个客户端不支持打点") .. (nativeErr and ("：" .. nativeErr) or "")
end

function GearInsight:CheeseWayCommand(step)
    local mapID = pickMap(step.mapIds or {})
    return string.format("/way #%s %.1f %.1f %s", tostring(mapID or "?"), step.x or 0, step.y or 0, CL(step, "text"))
end

function GearInsight:BuildCheesePage(page, onlyId)
    if not page then return end
    page._chOnly = onlyId
    if not page._chBuilt then
        page._chBuilt = true
        local sub = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        sub:SetPoint("TOPLEFT", 14, -40); sub:SetPoint("RIGHT", page, "RIGHT", -14, 0)
        sub:SetJustifyH("LEFT"); sub:SetWordWrap(true); sub:SetTextColor(0.72, 0.72, 0.78)
        page._chSub = sub
        local sf = CreateFrame("ScrollFrame", nil, page, "UIPanelScrollFrameTemplate")
        sf:SetPoint("TOPLEFT", 8, -96); sf:SetPoint("BOTTOMRIGHT", -28, 10)
        local sc = CreateFrame("Frame", nil, sf); sc:SetSize(460, 10); sf:SetScrollChild(sc)
        page._chSf, page._chSc, page._chRows, page._chBtns, page._chTex = sf, sc, {}, {}, {}
    end
    self:_renderCheese(page)
end

function GearInsight:_renderCheese(page)
    local D = _G.GearInsightCheese
    local sc = page._chSc
    for _, r in ipairs(page._chRows) do r:Hide() end
    for _, b in ipairs(page._chBtns) do b:Hide() end
    for _, t in ipairs(page._chTex) do t:Hide() end
    local W = math.max(300, (page._chSf:GetWidth() or 460)); sc:SetWidth(W)
    local tomtom = _G.TomTom and _G.TomTom.AddWaypoint
    local today = GearInsight.CheeseGameDay()
    local valid = GearInsight.CheeseValid()
    page._chSub:SetText("|cFFFFD100" .. T("CH_TODAY", "今日") .. " |r|cFFFFFFFF" .. today .. "|r  |cFF8A93A6" .. T("CH_RESET_RULE", "游戏日以北京时间 07:00 为界") .. "|r\n"
        .. T("CH_SUB", "今日省事清单：每条按步骤走，带坐标的点「标记」就在屏幕上出箭头（暴雪原生路点，不用装插件；装了 TomTom 会一起加）。")
        .. (tomtom and ("  |cFF44DD88" .. T("CH_TOMTOM_ON", "TomTom 已检测到") .. "|r") or ""))
    local ri, bi, ti, y = 0, 0, 0, -2
    local function label(x, yy, w, text, font, r, g, b)
        ri = ri + 1
        local fs = page._chRows[ri]
        if not fs then fs = sc:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); page._chRows[ri] = fs end
        fs:SetFontObject(font or "GameFontHighlightSmall")
        fs:ClearAllPoints(); fs:SetPoint("TOPLEFT", x, yy); fs:SetWidth(w); fs:SetJustifyH("LEFT"); fs:SetWordWrap(true)
        fs:SetText(text); fs:SetTextColor(r or 0.9, g or 0.9, b or 0.9); fs:Show()
        return fs
    end
    local function tex(x, yy, w, h, r, g, b, a)
        ti = ti + 1
        local t = page._chTex[ti]
        if not t then t = sc:CreateTexture(nil, "BACKGROUND"); page._chTex[ti] = t end
        t:ClearAllPoints(); t:SetPoint("TOPLEFT", x, yy); t:SetSize(w, h); t:SetColorTexture(r, g, b, a); t:Show()
    end
    local function button(x, yy, w, text, onClick, tip)
        bi = bi + 1
        local b = page._chBtns[bi]
        if not b then
            b = CreateFrame("Button", nil, sc, "UIPanelButtonTemplate"); page._chBtns[bi] = b
            b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        end
        b:ClearAllPoints(); b:SetPoint("TOPLEFT", x, yy); b:SetSize(w, 20); b:SetText(text)
        b:SetScript("OnClick", onClick)
        b:SetScript("OnEnter", function(s) if tip then GameTooltip:SetOwner(s, "ANCHOR_RIGHT"); GameTooltip:SetText(tip, 1, 0.82, 0, 1, true); GameTooltip:Show() end end)
        b:Show()
        return b
    end
    if not (D and D.items) then
        label(10, y, W - 20, T("CH_NODATA", "缺少数据文件 core/CheeseData.lua")); sc:SetHeight(40); return
    end
    if not valid then   -- 日期不对就不展示（用户 2026-09-17）
        label(10, y, W - 20, string.format(T("CH_STALE", "今天（%s）的还没整理 —— 每天 07:00 更新后写；旧的不展示，免得按旧坐标白跑。"), today), nil, 0.72, 0.72, 0.78)
        sc:SetHeight(60); return
    end
    for _, it in ipairs(D.items) do
      if not page._chOnly or it.id == page._chOnly then
        local top = y
        local tag, ttl, summ = CL(it, "tag"), CL(it, "title"), CL(it, "summary")
        local head = (tag ~= "" and ("|cFFFFD100[" .. tag .. "]|r ") or "") .. "|cFFFFFFFF" .. ttl .. "|r"
        local fs = label(14, y - 6, W - 28, head, "GameFontNormal"); y = y - (fs:GetStringHeight() or 16) - 12
        if summ ~= "" then
            local s2 = label(18, y, W - 36, summ, nil, 0.72, 0.72, 0.78); y = y - (s2:GetStringHeight() or 14) - 8
        end
        for i, st in ipairs(it.steps or {}) do
            local has = st.x and st.y and st.mapIds and #st.mapIds > 0
            local txt = "|cFFFFD100" .. i .. ".|r " .. CL(st, "text")
                .. (has and ("  |cFF7FB0FF" .. CL(st, "mapName") .. " " .. string.format("%.1f / %.1f", st.x, st.y) .. "|r") or "")
            local fw = W - 36 - (has and 150 or 0)
            local s3 = label(18, y, fw, txt); local h = s3:GetStringHeight() or 14
            if has then
                button(W - 146, y - 2, 60, T("CH_MARK", "标记"), function()
                    local ok, msg = GearInsight:CheeseWaypoint(st, ttl)
                    GearInsight:Print(msg)
                end, T("CH_MARK_TIP", "在地图上打点并开启超级追踪；装了 TomTom 会同时加 TomTom 路点"))
                button(W - 82, y - 2, 72, T("CH_WAY", "复制 /way"), function()
                    GearInsight:ShowCopyText(GearInsight:CheeseWayCommand(st), T("CH_WAY_HINT", "Ctrl+C 复制 → 聊天框粘贴回车（TomTom / 其它 /way 插件通用）"), ttl)
                end, T("CH_WAY_TIP", "给用别的定位插件的人：/way #地图ID x y"))
                h = math.max(h, 20)
            end
            y = y - h - 6
        end
        y = y - 4
        tex(6, top, W - 12, top - y, 1, 0.82, 0, 0.05)
        y = y - 10
      end
    end
    if false and D.sources and #D.sources > 0 then   -- 来源不展示（用户 2026-09-17「来源隐藏掉」）
        local s = D.sources[1]
        label(10, y, W - 20, "|cFF8A93A6" .. string.format(T("CH_SRC", "来源：%s @%s · %s"), s.platform or "", s.author or "", s.date or "") .. "|r"); y = y - 18
    end
    sc:SetHeight(-y + 10)
    if GearInsight.Skin then GearInsight.Skin.Sweep(page) end
end


-- ── 弹窗版（资讯页「逃课」行点击）：同一套渲染，只画一条 ─────────────────────────
-- 用户 2026-09-17「逃课做到资讯里面最上 … 点击弹窗来展示」
function GearInsight:ShowCheesePopup(itemId)
    local f = self._chPopup
    if not f then
        f = CreateFrame("Frame", "GearInsightCheesePopup", UIParent, "BackdropTemplate")
        f:SetSize(520, 420); f:SetFrameStrata("DIALOG"); f:SetToplevel(true)
        f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14,
                        insets = { left = 4, right = 4, top = 4, bottom = 4 } })
        f:SetBackdropColor(0.05, 0.05, 0.08, 0.97); f:SetBackdropBorderColor(0.6, 0.5, 0.2, 1)
        f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
        if GearInsight.AnchorPopup then GearInsight:AnchorPopup(f) else f:SetPoint("CENTER") end
        tinsert(UISpecialFrames, "GearInsightCheesePopup")
        local close = CreateFrame("Button", nil, f, "UIPanelCloseButton"); close:SetPoint("TOPRIGHT", -2, -2)
        f._hd = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); f._hd:SetPoint("TOPLEFT", 14, -12)
        f._hd:SetTextColor(GOLD[1], GOLD[2], GOLD[3]); f._hd:SetText(T("MT_TAB_CHEESE_TITLE", "逃课 · 本周省事清单"))
        -- 复用页面渲染：给它一个 page 形状的壳
        local sub = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        sub:SetPoint("TOPLEFT", 14, -40); sub:SetPoint("RIGHT", f, "RIGHT", -14, 0)
        sub:SetJustifyH("LEFT"); sub:SetWordWrap(true); sub:SetTextColor(0.72, 0.72, 0.78)
        local sf = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
        sf:SetPoint("TOPLEFT", 10, -100); sf:SetPoint("BOTTOMRIGHT", -30, 12)
        local sc = CreateFrame("Frame", nil, sf); sc:SetSize(460, 10); sf:SetScrollChild(sc)
        f._chBuilt, f._chSub, f._chSf, f._chSc, f._chRows, f._chBtns, f._chTex = true, sub, sf, sc, {}, {}, {}
        if GearInsight.Skin then GearInsight.Skin.Sweep(f) end
        self._chPopup = f
    end
    f._chOnly = itemId
    self:_renderCheese(f)
    f:Show()
end

