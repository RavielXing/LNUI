-- GearInsight/main/Export.lua — 导出串（网页伴侣）+ 天赋导出
-- 2026-09-22 从 GearInsight.lua 拆出（纯搬家，逻辑未动）。共用 helper 见 GearInsight.lua 末尾的 GearInsight.Helpers。
local H = GearInsight.Helpers
local T, TSite, _LOCALE, _SITE = H.T, H.TSite, H.LOCALE, H.SITE

-- ── Export to web companion ───────────────────────────────────────────
-- The addon can't make HTTP requests (WoW sandbox), so the web/mini-program
-- companion is fed via a copy-paste import string. Format: GI1.<base64>.<checksum>
-- where the base64 payload is pipe-delimited:
--   ver | class | specId | heroTalent | itemLevel | crit,haste,mastery,vers | slot:item:ilvl,...
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
local function b64encode(data)
    local out, len, i = {}, #data, 1
    while i <= len do
        local b1 = data:byte(i)
        local b2 = data:byte(i + 1)
        local b3 = data:byte(i + 2)
        local n = b1 * 65536 + (b2 or 0) * 256 + (b3 or 0)
        local c1 = math.floor(n / 262144) % 64
        local c2 = math.floor(n / 4096) % 64
        local c3 = math.floor(n / 64) % 64
        local c4 = n % 64
        out[#out + 1] = B64:sub(c1 + 1, c1 + 1)
        out[#out + 1] = B64:sub(c2 + 1, c2 + 1)
        out[#out + 1] = b2 and B64:sub(c3 + 1, c3 + 1) or "="
        out[#out + 1] = b3 and B64:sub(c4 + 1, c4 + 1) or "="
        i = i + 3
    end
    return table.concat(out)
end

-- djb2-style rolling hash → 6 hex chars; lets the web side reject a truncated paste.
local function checksum(s)
    local h = 5381
    for i = 1, #s do
        h = (h * 33 + s:byte(i)) % 16777216
    end
    return string.format("%06x", h)
end

function GearInsight:BuildExportString()
    -- ⛔ 同一个坑，第三处：老代码只在**完全没有**snapshot 时才现存一份，有旧的就直接用——
    -- 升级轨道原地涨装等后，导出串（网站/小程序解析用）里的总装等和逐槽 ilvl 全是升级前的。
    -- 导出是明确的「现在就要」操作，一律现存。
    local snap = self.SavedVars and self.SavedVars:Save()
    if not snap or not snap.class then return nil end

    local sec = snap.secondaryRating or {}
    local stats = string.format("%d,%d,%d,%d",
        sec.crit or 0, sec.haste or 0, sec.mastery or 0, sec.versatility or 0)

    local eqParts = {}
    for slotId, slot in pairs(snap.equipped or {}) do
        if type(slot) == "table" and slot.itemId and not slot.empty then
            local sid = slot.slotId or slotId
            -- 0.90.5：第 4~6 段 = 升级轨道 档:上限:名（网站/小程序判「这份升满到不到 BiS 装等」，
            --   与主面板同口径）。读不到（非升级件/制造）就只有前 3 段，后端兼容。
            --   ⛔ 名字不许含 : , | —— 客户端轨道名（英雄/Hero）本身不含。
            local okT, cur, mx, nm = pcall(GearInsight.SlotUpgradeTrack, GearInsight, sid)
            if okT and cur and mx and mx > 0 then
                nm = tostring(nm or ""):gsub("[:,|]", "")
                eqParts[#eqParts + 1] = string.format("%d:%d:%d:%d:%d:%s", sid, slot.itemId, slot.ilvl or 0, cur, mx, nm)
            else
                eqParts[#eqParts + 1] = string.format("%d:%d:%d", sid, slot.itemId, slot.ilvl or 0)
            end
        end
    end
    table.sort(eqParts)

    -- 第 8 字段：角色名（展示+分享，旧版无，后端兼容）
    local charName = (snap and snap.charName) or UnitName("player") or ""
    -- 第 9/10 字段：服务器名 + 区服 —— 让小程序"插件串一键鉴定 parse 战力"零输入。
    -- region 用 WCL 编码(US/KR/EU/TW/CN)；GetCurrentRegion: 1=US,2=KR,3=EU,4=TW,5=CN。
    local realm = (GetNormalizedRealmName and GetNormalizedRealmName())
        or (GetRealmName and GetRealmName()) or ""
    local regionMap = { "US", "KR", "EU", "TW", "CN" }
    local region = regionMap[(GetCurrentRegion and GetCurrentRegion()) or 0] or ""
    local payload = table.concat({
        "1",
        snap.class or "",
        snap.specId or 0,
        snap.heroTalent or "",
        snap.itemLevel or snap.averageItemLevel or 0,
        stats,
        table.concat(eqParts, ","),
        charName,
        realm,
        region,
        -- 第 11 字段：客户端语言（GetLocale）——网站分析页据此切成同一种语言（用户 2026-09-17）
        (GetLocale and GetLocale()) or "",
        -- 第 12 字段：账号串（/gi account 贴的 GIA1-…，2026-09-20）——网站据此把角色确权给这个账号；没贴就空
        (GearInsightDB and GearInsightDB.account) or "",
        -- 第 13 字段：角色面板上的四项副属性百分比（暴击几率 / 急速 / 精通效果 / 全能，与人物界面同一数值），
        --   网站副属性诊断在「评级占比」旁边显示「面板 x%」（09-21 用户「网站可以展示游戏里的那个数值标准吗」）。旧串无 → 空
        (function() local p = snap.secondary or {}; return string.format("%.2f,%.2f,%.2f,%.2f", p.crit or 0, p.haste or 0, p.mastery or 0, p.versatility or 0) end)(),
    }, "|")

    local b64 = b64encode(payload)
    return "GI1." .. b64 .. "." .. checksum(b64)
end

function GearInsight:ShowExportDialog()
    local str = self:BuildExportString()
    if not str then
        self:Print(T("EXPORT_NODATA", "无法导出：请先打开面板或 /gi refresh 刷新装备数据"))
        return
    end

    local dimmer = CreateFrame("Frame", nil, UIParent)
    dimmer:SetAllPoints()
    dimmer:SetFrameStrata("FULLSCREEN_DIALOG")
    dimmer:EnableMouse(true)
    local dbg = dimmer:CreateTexture(nil, "BACKGROUND")
    dbg:SetAllPoints()
    dbg:SetColorTexture(0, 0, 0, 0.6)
    dimmer:SetScript("OnMouseDown", function(d) d:Hide() end)
    self:RegisterEscClose(dimmer, "GearInsightExportDimmer")

    -- 小程序引流仅对简体中文客户端开放（海外玩家用不了微信小程序；英文 web 版上线后再放开）。
    local guideMini = (_LOCALE == "zhCN")

    local box = CreateFrame("Frame", nil, dimmer, "BackdropTemplate")
    box:SetSize(460, guideMini and 328 or 278)
    box:SetPoint("CENTER")
    box:EnableMouse(true)
    box:SetScript("OnMouseDown", nil)
    box:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        edgeSize = 24,
        insets = { left = 6, right = 6, top = 6, bottom = 6 },
    })
    box:SetBackdropColor(0.08, 0.08, 0.12, 0.97)
    box:SetBackdropBorderColor(0.4, 0.4, 0.5, 0.9)

    local title = box:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -14)
    title:SetText(guideMini and "导出装备 · 网页查缺件" or TSite("EXPORT_TITLE", "Export Gear · gearinsight.app"))

    local hint = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOP", title, "BOTTOM", 0, -8)
    hint:SetWidth(420)
    hint:SetJustifyH("CENTER")
    hint:SetText(guideMini and T("EXPORT_HINT", "Ctrl+C 复制下面的字符串，粘贴到网页即可查看你的缺件清单")
        or TSite("EXPORT_HINT_EN", "Copy the string below (Ctrl+C) and paste it on gearinsight.app"))
    hint:SetTextColor(0.7, 0.7, 0.7)

    local sf = CreateFrame("ScrollFrame", nil, box, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 16, -62)
    sf:SetPoint("BOTTOMRIGHT", -34, guideMini and 124 or 112)
    local edit = CreateFrame("EditBox", nil, sf)
    edit:SetMultiLine(true)
    edit:SetFontObject("GameFontHighlightSmall")
    edit:SetWidth(396)
    -- ⛔ 不再抢焦点：主路径已改成下面那条**带装备串的深链**。
    --    这个框只做傅底：网页已经开着、或者网址被聊天软件切坏时用。
    edit:SetAutoFocus(false)
    edit:SetText(str)
    edit:HighlightText()
    edit:SetScript("OnEscapePressed", function() dimmer:Hide() end)
    edit:SetScript("OnEnterPressed", function(s) s:HighlightText() end)
    -- Keep it effectively read-only: any edit snaps back to the canonical string.
    edit:SetScript("OnTextChanged", function(s, userInput)
        if userInput and s:GetText() ~= str then
            s:SetText(str)
            s:HighlightText()
        end
    end)
    sf:SetScrollChild(edit)

    -- ⛔ 小程序已搁置（用户 2026-08-28）：导出功能保留，但引导一律指向网站的
    --    「装备分析器」页面，不再提微信小程序 —— 让人去搜一个不再维护的入口是纯流失。
    local webHint = box:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    webHint:SetPoint("TOP", sf, "BOTTOM", 0, -10)
    webHint:SetWidth(424)
    webHint:SetJustifyH("CENTER")
    -- ⛔ 这里原来按 `guideMini`（只认 zhCN）二选一写死中/英两句，
    --   **繁体客户端走 else 分支看到英文**，而且两句给的网址还不一样
    --   （中文给完整路径、英文只给域名）。用户 2026-08-28:「确保中外语都更新」。
    -- ✅ 改走 T()：zhCN 用默认中文，zhTW/enUS 从 locales 取，网址统一。
    webHint:SetText(T("EXPORT_WEB_HINT3",
        "下面这条网址已经带上你的装备 —— 复制它，粘贴到浏览器，直接出缺件清单"))
    webHint:SetTextColor(0.87, 0.87, 0.87)

    -- 网址也要能复制（2026-08-31 用户）：单行只读 EditBox，点击全选，Ctrl+C 拿走。
    -- ⭐ 深链：网址直接带上装备串，浏览器打开就自动出结果。
    -- 实测 2026-09-07：落地分析页的人里只有 63% 真的跑出了结果，
    --   37% 卡在「再粘贴一次串」这一步（常见原因：剪贴板被覆盖了）。
    -- ⛔ 用 `#` 不能用 `?`：井号后面的内容浏览器不会发给服务器，
    --   既不会把整套配装写进 access log，也不会随 Referer 泄给第三方。
    -- ⛔ 网站端必须先上线（读井号的那段 JS），这个插件版本才能发，
    --   否则旧页面会直接忽略井号 → 用户拿到一个空输入框，反而更差。
    -- ?lang= 按客户端语言：站上 ?lang= 优先级最高并写回本地，英文客户端打开就是英文站（用户 2026-09-17）
    local _LM = { enUS = "en", enGB = "en", zhCN = "zh-CN", zhTW = "zh-TW", deDE = "de", frFR = "fr", esES = "es", esMX = "es", itIT = "it", koKR = "ko", ptBR = "pt", ruRU = "ru" }
    local _lang = _LM[(GetLocale and GetLocale()) or ""] or "en"
    local URL = "https://" .. _SITE .. "/wow/en/analyze?lang=" .. _lang .. "#" .. str
    local urlBox = CreateFrame("EditBox", nil, box, "InputBoxTemplate")
    urlBox:SetSize(320, 22)
    urlBox:SetPoint("TOP", webHint, "BOTTOM", 0, -6)
    urlBox:SetFontObject("GameFontHighlightSmall")
    urlBox:SetAutoFocus(true)
    urlBox:SetText(URL)
    urlBox:SetJustifyH("CENTER")
    urlBox:SetScript("OnMouseUp", function(u) u:SetFocus(); u:HighlightText() end)
    urlBox:SetScript("OnEditFocusGained", function(u) u:HighlightText() end)
    urlBox:SetScript("OnEscapePressed", function(u) u:ClearFocus() end)
    urlBox:SetScript("OnTextChanged", function(u, userInput)
        if userInput and u:GetText() ~= URL then u:SetText(URL); u:HighlightText() end
    end)
    local urlTip = box:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    urlTip:SetPoint("TOP", urlBox, "BOTTOM", 0, -2)
    urlTip:SetText(T("EXPORT_URL_TIP2",
        "已选中，Ctrl+C 复制整条 · 不用再粘贴上面那串"))

    local closeBtn = CreateFrame("Button", nil, box, "UIPanelButtonTemplate")
    closeBtn:SetSize(90, 24)
    closeBtn:SetPoint("BOTTOM", 0, 12)
    closeBtn:SetText(T("CLOSE_SHORT", "关闭"))
    closeBtn:SetScript("OnClick", function() dimmer:Hide() end)
    if GearInsight.Skin then GearInsight.Skin.Sweep(dimmer) end
end

-- One-shot diagnostic: dump the selected hero-talent nodes with every id flavor
-- (node / entry / definition / spell) so we can find which one matches WCL's
-- talentID namespace. /gi dumptalents — paste the output to the developer.
function GearInsight:DumpTalents()
    if not C_ClassTalents or not C_Traits then self:Print("Traits API 不可用") return end
    local cfg = C_ClassTalents.GetActiveConfigID and C_ClassTalents.GetActiveConfigID()
    if not cfg then self:Print("无激活天赋配置") return end
    local info = C_Traits.GetConfigInfo(cfg)
    if not info or not info.treeIDs then self:Print("无天赋树") return end
    self:Print("=== GI dumptalents (整段贴给开发) ===")
    -- Enumerate ALL entries of ALL hero subtree nodes (selected or not), so one
    -- dump per spec captures both of that spec's hero trees in full.
    for _, treeID in ipairs(info.treeIDs) do
        local nodes = C_Traits.GetTreeNodes(treeID)
        for _, nodeID in ipairs(nodes or {}) do
            local ni = C_Traits.GetNodeInfo(cfg, nodeID)
            if ni and ni.subTreeID then
                local si = C_Traits.GetSubTreeInfo(cfg, ni.subTreeID)
                local subName = si and si.name or ("sub" .. tostring(ni.subTreeID))
                for _, entryID in ipairs(ni.entryIDs or {}) do
                    local defID, spellID, name = 0, 0, "?"
                    local ei = C_Traits.GetEntryInfo(cfg, entryID)
                    if ei and ei.definitionID then
                        defID = ei.definitionID
                        local di = C_Traits.GetDefinitionInfo(defID)
                        if di then
                            spellID = di.spellID or 0
                            if di.overrideName and di.overrideName ~= "" then
                                name = di.overrideName
                            elseif spellID > 0 then
                                if C_Spell and C_Spell.GetSpellName then name = C_Spell.GetSpellName(spellID) or "?"
                                elseif GetSpellInfo then name = (GetSpellInfo(spellID)) or "?" end
                            end
                        end
                    end
                    self:Print(string.format("entry=%d def=%d spell=%d hero=%s | %s",
                        entryID, defID, spellID, subName, tostring(name)))
                end
            end
        end
    end
    self:Print("=== end ===")
end
