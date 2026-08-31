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

-- Localized item name: client API (correct per-locale) first; on a zhTW client
-- fall back to S2T(baked Simplified) so an uncached item never leaks Simplified.
local function locName(id, baked)
    if id then
        local n = getCN(id)
        if n and n ~= "" then return n end
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
                link = "|Hitem:" .. itemID .. ":0" .. "::::::::0:::" .. bonusPart .. "|h"
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

-- ── Slash ────────────────────────────────────────────────────────────
SLASH_GEARINSIGHT1 = "/gi"
SLASH_GEARINSIGHT2 = "/gearinsight"
SlashCmdList["GEARINSIGHT"] = function(msg)
    -- pcall 保命但不吞错：报错时告诉用户出了什么，否则反馈只会是"点了没反应"。
    local ok, err = pcall(GearInsight.SlashCommand, GearInsight, msg)
    if not ok then
        GearInsight:Print("|cFFFF4444" .. T("CMD_ERROR", "命令执行出错: ") .. tostring(err) .. "|r")
    end
end

function GearInsight:SlashCommand(input)
    local cmd = strtrim(input or "")
    if cmd == "" or cmd == "panel" or cmd == "show" then
        self:TogglePanel()
    elseif cmd == "refresh" or cmd == "reload" then
        self:RefreshData()
    elseif cmd == "status" then
        self:PrintStatus()
    elseif cmd == "meta" or cmd == "mplus" then
        -- 大秘境情报（2026-08-31：视频/网站/插件三端同源的每周强势职业榜）
        self:ToggleMplusMeta()
    elseif cmd == "help" then
        self:PrintHelp()
    elseif cmd == "farming" then
        local c, s, h
        if self.StatReader then
            local st = self.StatReader:ReadAll()
            c = st.class; s = st.spec; h = st.heroTalent
        end
        if c and s then
            self:ShowFarmingGuide(c, s, h)
        else
            self:Print(T("PRINT_OPEN_FIRST", "请先打开面板或刷新数据"))
        end
    elseif cmd == "multi" or cmd == "multispec" then
        local c
        if self.StatReader then c = self.StatReader:ReadAll().class end
        if c then
            self:ShowMultiSpecPlan(c)
        else
            self:Print(T("PRINT_OPEN_FIRST", "请先打开面板或刷新数据"))
        end
    elseif cmd == "mode" or cmd:match("^mode%s") then
        local arg = cmd:match("^mode%s+(%S+)") or ""
        local cur = (GearInsightDB and GearInsightDB.usageMode) or "raid"
        local mode
        if arg == "raid" or arg == "团本" then mode = "raid"
        elseif arg == "mplus" or arg == "大秘境" or arg == "mythic" then mode = "mplus"
        else mode = (cur == "mplus") and "raid" or "mplus" end -- 无参 = 切换
        self:SetUsageMode(mode)
    elseif cmd == "raid" or cmd == "mplus" or cmd == "mythic" then
        -- 直觉快捷方式：/gi raid = 使用率参照切团本（等价 /gi mode raid）。
        -- 旧版曾把 /gi raid 路由到"排除团本"开关——字面意思相反，已纠正；
        -- 排除团本只认 /gi noraid。
        self:SetUsageMode(cmd == "raid" and "raid" or "mplus")
    elseif cmd == "noraid" or cmd:match("^noraid%s") then
        local arg = cmd:match("%s+(%S+)") or ""
        local cur = (GearInsightDB and GearInsightDB.excludeRaid) and true or false
        local on
        if arg == "on" or arg == "排除" then on = true
        elseif arg == "off" or arg == "含" then on = false
        else on = not cur end
        self:SetExcludeRaid(on)
    elseif cmd == "export" or cmd == "share" then
        self:ShowExportDialog()
    elseif cmd == "need" or cmd == "需求" or cmd == "需求单" then
        self:ShowNeedSheet()
    elseif cmd == "dumpids" then
        if self.BisData and self.BisData.DumpEncounterJournal then
            self.BisData:DumpEncounterJournal()
        else
            self:Print(T("DUMP_UNAVAILABLE", "BisData.DumpEncounterJournal 不可用"))
        end
    elseif cmd == "dumptalents" then
        self:DumpTalents()
    elseif cmd == "cbis" or cmd:match("^cbis%s") then
        local arg = cmd:match("^cbis%s+(.+)") or ""
        local c = self._paperDollBisCfg and self._paperDollBisCfg()
        if c then
            -- 大小写不敏感；裸数字也当 size（玩家照 changelog 试新命令常打成
            -- "/gi cbis 16"、"size16"、"Size 16"——0.43.0 旧逻辑把这些全当
            -- 未知参数静默切换开关，把角色面板图标整个关掉，看着像功能消失）
            local low = arg:lower()
            local sz = low:match("^size%s*(%d+)$") or low:match("^(%d+)$")
            local posKey = low:match("^pos%s*(%a+)$")
            local POS_MAP = { tl = "TOPLEFT", tr = "TOPRIGHT", bl = "BOTTOMLEFT", br = "BOTTOMRIGHT" }
            if sz then
                c.iconSize = math.max(10, math.min(30, tonumber(sz)))
                self:Print(string.format(T("PDB_SIZE_SET", "角色面板 BiS 图标大小：%dpx"), c.iconSize))
            elseif posKey and POS_MAP[posKey] then
                c.iconPos = POS_MAP[posKey]
                self:Print(T("PDB_POS_SET", "角色面板 BiS 图标位置：") .. posKey)
            elseif low == "off" then
                c.enabled = false
                self:Print(T("PDB_TOGGLE_OFF", "角色面板 BiS 图标：已关闭"))
            elseif low == "on" then
                c.enabled = true
                self:Print(T("PDB_TOGGLE_ON", "角色面板 BiS 图标：已开启"))
            elseif low == "" then
                -- 仅裸 /gi cbis 保留开关切换（0.39 起的文档行为）
                c.enabled = not c.enabled
                self:Print(c.enabled and T("PDB_TOGGLE_ON", "角色面板 BiS 图标：已开启")
                    or T("PDB_TOGGLE_OFF", "角色面板 BiS 图标：已关闭"))
            else
                -- 未识别参数：只报用法+当前状态，绝不动开关
                self:Print(T("PDB_CFG_HELP", "用法：/gi cbis on|off | size 10-30 | pos tl|tr|bl|br")
                    .. " | " .. (c.enabled and T("PDB_TOGGLE_ON", "角色面板 BiS 图标：已开启")
                        or T("PDB_TOGGLE_OFF", "角色面板 BiS 图标：已关闭")))
            end
            if self.RefreshPaperDollBis then self.RefreshPaperDollBis() end
        end
    elseif cmd == "web" then
        self:ShowWebProfileDialog()
    elseif cmd == "tier" or cmd:match("^tier%s") then
        local arg = cmd:match("^tier%s+(%S+)") or ""
        local map = { m = "mythic", mythic = "mythic", h = "heroic", heroic = "heroic",
            n = "normal", normal = "normal",
            ["史诗"] = "mythic", ["英雄"] = "heroic", ["普通"] = "normal" }
        local t = map[arg]
        if t then
            self:SetGearTier(t)
        else
            self:Print(T("TIER_HELP", "用法：/gi tier m|h|n（史诗/英雄/普通）；当前：")
                .. self:GearTierLabel())
        end
    elseif cmd == "groupbis" or cmd:match("^groupbis%s") then
        local arg = cmd:match("^groupbis%s+(%S+)") or ""
        GearInsightDB = GearInsightDB or {}
        if arg == "off" then GearInsightDB.inspectBisOn = nil
        elseif arg == "on" then GearInsightDB.inspectBisOn = true
        else GearInsightDB.inspectBisOn = (not GearInsightDB.inspectBisOn) or nil end
        self:Print(GearInsightDB.inspectBisOn
            and T("IB_TOGGLE_ON", "组队悬停 BiS 毕业度：已开启")
            or T("IB_TOGGLE_OFF", "组队悬停 BiS 毕业度：已关闭"))
    elseif cmd == "team" or cmd == "队伍" or cmd == "体检" then
        if GearInsight.GroupBisPanel then
            GearInsight.GroupBisPanel:Toggle()
        else
            self:Print(T("GB_UNAVAIL", "团队 BiS 体检面板未加载"))
        end
    elseif cmd == "guild" or cmd == "公会" or cmd == "花名册" then
        if GearInsight.GuildRosterPanel then
            GearInsight.GuildRosterPanel:Toggle()
        else
            self:Print(T("GLD_UNAVAIL", "公会花名册面板未加载"))
        end
    elseif cmd == "tooltip" or cmd:match("^tooltip%s") then
        local arg = cmd:match("^tooltip%s+(%S+)") or ""
        local getCfg = GearInsight._tooltipBisCfg
        local c = getCfg and getCfg() or nil
        if not c then
            self:Print(T("TTBIS_TOGGLE_OFF", "物品 tooltip BiS 排名：已关闭"))
        elseif arg == "off" then
            c.enabled = false
            self:Print(T("TTBIS_TOGGLE_OFF", "物品 tooltip BiS 排名：已关闭"))
        elseif arg == "on" or arg == "" then
            c.enabled = true
            if c.mode == "off" then c.mode = "all" end
            self:Print(T("TTBIS_TOGGLE_ON", "物品 tooltip BiS 排名：已开启"))
        elseif arg == "current" then
            c.enabled = true
            c.mode = "current"
            self:Print(T("TTBIS_TOGGLE_CURRENT", "物品 tooltip：仅显示当前专精"))
        elseif arg == "all" then
            c.enabled = true
            c.mode = "all"
            self:Print(T("TTBIS_TOGGLE_ALL", "物品 tooltip：显示全部专精"))
        elseif arg == "others" then
            c.showOthers = not c.showOthers
            self:Print(c.showOthers and T("TTBIS_TOGGLE_OTHERS_ON", "物品 tooltip：显示其它职业")
                or T("TTBIS_TOGGLE_OTHERS_OFF", "物品 tooltip：隐藏其它职业"))
        else
            self:Print(T("TTBIS_TOGGLE_USAGE", "用法: /gi tooltip on|off|current|all|others（专精勾选请用面板「悬浮提示」按钮）"))
        end
    elseif cmd:match("^scale%s") then
        local scale = tonumber(cmd:match("^scale%s+(%d+%.?%d*)"))
        if scale and scale >= 0.5 and scale <= 2.0 then
            GearInsightDB.panelScale = scale
            if self._panelFrame then self._panelFrame:SetScale(scale) end
            if self._scaleLabel then self._scaleLabel:SetText(string.format("%.0f%%", scale * 100)) end
            self:Print(T("SCALE_SET", "面板缩放已设置为 ") .. scale)
        else
            self:Print(T("SCALE_USAGE", "用法: /gi scale <0.5-2.0>  当前: ") .. (GearInsightDB.panelScale or 1.0))
        end
    else
        self:Print("Unknown command. /gi help")
    end
end

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
    local snap = self.SavedVars and self.SavedVars:GetLastSnapshot()
    if (not snap or not snap.class) and self.SavedVars then
        snap = self.SavedVars:Save()   -- take a fresh snapshot if none stored yet
    end
    if not snap or not snap.class then return nil end

    local sec = snap.secondaryRating or {}
    local stats = string.format("%d,%d,%d,%d",
        sec.crit or 0, sec.haste or 0, sec.mastery or 0, sec.versatility or 0)

    local eqParts = {}
    for slotId, slot in pairs(snap.equipped or {}) do
        if type(slot) == "table" and slot.itemId and not slot.empty then
            eqParts[#eqParts + 1] = string.format("%d:%d:%d", slot.slotId or slotId, slot.itemId, slot.ilvl or 0)
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
    title:SetText(guideMini and "导出装备 · 网页查缺件" or T("EXPORT_TITLE", "Export Gear · gearinsight.app"))

    local hint = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOP", title, "BOTTOM", 0, -8)
    hint:SetWidth(420)
    hint:SetJustifyH("CENTER")
    hint:SetText(guideMini and T("EXPORT_HINT", "Ctrl+C 复制下面的字符串，粘贴到网页即可查看你的缺件清单")
        or T("EXPORT_HINT_EN", "Copy the string below (Ctrl+C) and paste it on gearinsight.app"))
    hint:SetTextColor(0.7, 0.7, 0.7)

    local sf = CreateFrame("ScrollFrame", nil, box, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 16, -62)
    sf:SetPoint("BOTTOMRIGHT", -34, guideMini and 124 or 112)
    local edit = CreateFrame("EditBox", nil, sf)
    edit:SetMultiLine(true)
    edit:SetFontObject("GameFontHighlightSmall")
    edit:SetWidth(396)
    edit:SetAutoFocus(true)
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
    webHint:SetText(T("EXPORT_WEB_HINT2",
        "点击下面网址复制，粘贴到浏览器打开 → 再粘贴此串，即出缺件清单 + 刷取顺序"))
    webHint:SetTextColor(0.87, 0.87, 0.87)

    -- 网址也要能复制（2026-08-31 用户）：单行只读 EditBox，点击全选，Ctrl+C 拿走。
    local URL = "https://gearinsight.app/wow/en/analyze"
    local urlBox = CreateFrame("EditBox", nil, box, "InputBoxTemplate")
    urlBox:SetSize(320, 22)
    urlBox:SetPoint("TOP", webHint, "BOTTOM", 0, -6)
    urlBox:SetFontObject("GameFontHighlightSmall")
    urlBox:SetAutoFocus(false)
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
    urlTip:SetText(T("EXPORT_URL_TIP", "点击这里复制网址（Ctrl+C）· 粘贴到浏览器"))

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

-- ── Panel: ensure / toggle ───────────────────────────────────────────
function GearInsight:TogglePanel()
    if self._panelVisible then
        self._panelFrame:Hide()
    else
        local ok, err = pcall(self._ensurePanel, self)
        if not ok then
            self:Print(T("PANEL_INIT_FAIL", "面板初始化失败: ") .. tostring(err))
            return
        end
        if not self._panelFrame or not self._upgradeRows then return end
        self:RefreshData()
        if self._panelFrame then
            self._panelFrame:Show()
            self._panelVisible = true
        end
    end
end

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
    if not instId then return baked end
    if not EJ_GetInstanceInfo then return baked end
    local inst = EJ_GetInstanceInfo(instId)
    if not inst then return baked end
    if bossId and EJ_GetEncounterInfo then
        local boss = EJ_GetEncounterInfo(bossId)
        if boss then return inst .. " - " .. boss end
    end
    return inst
end

function GearInsight:_ensurePanel()
    if self._panelFrame then return end

    -- Main frame with solid bg texture (prevents scene bleed)
    local f = CreateFrame("Frame", "GearInsightPanelFrame", UIParent, "BackdropTemplate")
    self:RegisterEscClose(f)
    f:SetSize(520, 720)
    f:SetPoint("CENTER")
    -- Restore saved panel position
    local pos = GearInsightDB and GearInsightDB.panelPosition
    if pos and pos.point then
        f:ClearAllPoints()
        f:SetPoint(pos.point, UIParent, pos.relativePoint, pos.xOfs, pos.yOfs)
    end
    -- Border via BackdropTemplate
    f:SetBackdrop({
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 },
    })
    f:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.9)
    -- Solid background texture (layer BACKGROUND ensures full coverage)
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.05, 0.05, 0.08, 0.95)
    f:SetScale(GearInsightDB.panelScale or 1.0)
    f:SetMovable(true); f:SetClampedToScreen(true)
    f:EnableMouse(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function() f:StartMoving() end)
    f:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        local point, _, relativePoint, xOfs, yOfs = f:GetPoint(1)
        if point then
            GearInsightDB = GearInsightDB or {}
            GearInsightDB.panelPosition = {
                point = point,
                relativePoint = relativePoint,
                xOfs = xOfs,
                yOfs = yOfs,
            }
        end
    end)
    f:SetScript("OnHide", function()
        GearInsight._panelVisible = false
    end)
    -- Ctrl+MouseWheel to scale the panel
    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel", function(_, delta)
        if not IsControlKeyDown() then return end
        local cur = GearInsightDB.panelScale or 1.0
        local s = cur + delta * 0.05
        if s < 0.5 then s = 0.5 elseif s > 2.0 then s = 2.0 end
        GearInsightDB.panelScale = s
        f:SetScale(s)
        if self._scaleLabel then self._scaleLabel:SetText(string.format("%.0f%%", s * 100)) end
    end)
    f:SetFrameStrata("HIGH"); f:SetFrameLevel(10)
    f:Hide()

    -- Scale control on the title bar (just left of the close X): "- 100% +".
    -- Sits in the empty chrome gap beside the title, clear of both the button row and body content.
    local scaleLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    scaleLabel:SetText(string.format("%.0f%%", (GearInsightDB.panelScale or 1.0) * 100))
    scaleLabel:SetTextColor(0.5, 0.5, 0.5)
    self._scaleLabel = scaleLabel

    local function _applyScale(newScale)
        if newScale < 0.5 then newScale = 0.5 elseif newScale > 2.0 then newScale = 2.0 end
        GearInsightDB.panelScale = newScale
        f:SetScale(newScale)
        scaleLabel:SetText(string.format("%.0f%%", newScale * 100))
    end

    local zoomIn = CreateFrame("Button", nil, f)
    zoomIn:SetSize(18, 18); zoomIn:SetPoint("TOPRIGHT", -40, -11)
    zoomIn:SetNormalFontObject("GameFontHighlight")
    zoomIn:SetText("+"); zoomIn:SetScript("OnClick", function()
        _applyScale((GearInsightDB.panelScale or 1.0) + 0.05)
    end)

    scaleLabel:SetPoint("RIGHT", zoomIn, "LEFT", -4, 0)

    local zoomOut = CreateFrame("Button", nil, f)
    zoomOut:SetSize(18, 18); zoomOut:SetPoint("RIGHT", scaleLabel, "LEFT", -4, 0)
    zoomOut:SetNormalFontObject("GameFontHighlight")
    zoomOut:SetText("-"); zoomOut:SetScript("OnClick", function()
        _applyScale((GearInsightDB.panelScale or 1.0) - 0.05)
    end)

    -- Close button (top-right X)
    local cb = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    cb:SetPoint("TOPRIGHT", -4, -4)
    cb:SetScript("OnClick", function() f:Hide(); GearInsight._panelVisible = false end)

    -- Title
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    title:SetPoint("TOP", 0, -12)
    title:SetText(T("PANEL_TITLE", "GearInsight"))

    -- Export-to-web button (right side of the overview, clear of the title bar)
    local exportBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    exportBtn:SetSize(100, 24)
    exportBtn:SetPoint("TOPRIGHT", -16, -56)
    exportBtn:SetText(T("EXPORT_BTN", "导出装备"))
    exportBtn:SetScript("OnClick", function() GearInsight:ShowExportDialog() end)
    exportBtn:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_LEFT")
        GameTooltip:SetText(T("EXPORT_TIP", "导出装备串，粘贴到网页版查看缺件清单"), 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    exportBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- 复制主流天赋：WCL 顶尖玩家最主流 build → 一键复制导入串（粘进天赋面板「导入」）。
    local talentBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    talentBtn:SetSize(100, 24)
    talentBtn:SetPoint("TOPRIGHT", -16, -82)
    talentBtn:SetText(T("TALENT_BTN", "WCL天赋库"))
    talentBtn:SetSize(110, 24)
    if talentBtn:GetFontString() then talentBtn:GetFontString():SetTextColor(1, 0.85, 0.1) end
    -- 金色发光描边 + 轻脉冲，让"抄天赋"入口跳出来
    local tglow = talentBtn:CreateTexture(nil, "OVERLAY")
    tglow:SetPoint("TOPLEFT", -7, 7); tglow:SetPoint("BOTTOMRIGHT", 7, -7)
    tglow:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    tglow:SetBlendMode("ADD"); tglow:SetVertexColor(1, 0.82, 0)
    local tag = tglow:CreateAnimationGroup(); tag:SetLooping("BOUNCE")
    local ta = tag:CreateAnimation("Alpha"); ta:SetFromAlpha(0.2); ta:SetToAlpha(0.65); ta:SetDuration(0.9)
    tag:Play()
    talentBtn:SetScript("OnClick", function() GearInsight:ShowTalentPicker() end)
    talentBtn:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_LEFT")
        GameTooltip:SetText(T("TALENT_TIP", "WCL 顶尖玩家天赋(团本/冲分/割草 各前5名)，选一套复制导入串"), 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    talentBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- 循环参考：WCL 顶尖玩家真实起手序列 + 技能频率 + buff盯防（团本/大秘境两套）。
    local rotBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    rotBtn:SetSize(110, 24)
    rotBtn:SetPoint("TOPRIGHT", -16, -108)
    rotBtn:SetText(T("ROT_BTN", "AI技术指导"))
    -- AI 蓝发光描边 + 轻脉冲（与天赋库的金色区分开，避免两个金色互抢）
    if rotBtn:GetFontString() then rotBtn:GetFontString():SetTextColor(0.4, 0.73, 1) end
    local rglow = rotBtn:CreateTexture(nil, "OVERLAY")
    rglow:SetPoint("TOPLEFT", -7, 7); rglow:SetPoint("BOTTOMRIGHT", 7, -7)
    rglow:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    rglow:SetBlendMode("ADD"); rglow:SetVertexColor(0.3, 0.65, 1)
    local rag = rglow:CreateAnimationGroup(); rag:SetLooping("BOUNCE")
    local ra = rag:CreateAnimation("Alpha"); ra:SetFromAlpha(0.2); ra:SetToAlpha(0.65); ra:SetDuration(0.9)
    rag:Play()
    rotBtn:SetScript("OnClick", function() GearInsight:ShowRotationRef() end)
    rotBtn:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_LEFT")
        GameTooltip:SetText(T("ROT_TIP", "WCL 顶尖玩家的真实起手序列、技能使用频率、关键BUFF覆盖率（团本/大秘境两套参照）"), 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    rotBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- 大米攻略：WCL 真实数据的 M+ 攻略（打断优先级/致死技能榜/重伤来源）
    local dgBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    dgBtn:SetSize(110, 24)
    dgBtn:SetPoint("TOPRIGHT", -16, -134)
    dgBtn:SetText(T("DG_BTN", "大米攻略"))
    -- 绿色描边脉冲（与金色天赋库/蓝色AI指导区分）
    if dgBtn:GetFontString() then dgBtn:GetFontString():SetTextColor(0.4, 1, 0.5) end
    local dglow = dgBtn:CreateTexture(nil, "OVERLAY")
    dglow:SetPoint("TOPLEFT", -7, 7); dglow:SetPoint("BOTTOMRIGHT", 7, -7)
    dglow:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    dglow:SetBlendMode("ADD"); dglow:SetVertexColor(0.3, 1, 0.45)
    local dag = dglow:CreateAnimationGroup(); dag:SetLooping("BOUNCE")
    local da = dag:CreateAnimation("Alpha"); da:SetFromAlpha(0.2); da:SetToAlpha(0.6); da:SetDuration(0.9)
    dag:Play()
    dgBtn:SetScript("OnClick", function() GearInsight:ShowDungeonGuide() end)
    dgBtn:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_LEFT")
        GameTooltip:SetText(T("DG_TIP", "大米攻略：WCL 真实数据聚合 — 每个本谁在杀人、顶尖玩家断什么不断什么、死亡前承伤构成。进本自动弹出对应本图。"), 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    dgBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- 使用率参照系切换：团本 / 大秘境（与小程序一致）
    -- 职责名词「使用率参照」明确这是"排行/使用率% 参照谁的数据"，与右侧"装备过滤"区分开。
    local modeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    modeBtn:SetSize(150, 24)
    modeBtn:SetPoint("TOPLEFT", 16, -56)
    local function modeBtnRefresh()
        local m = (GearInsightDB and GearInsightDB.usageMode) or "raid"
        local val = (m == "mplus") and T("USAGE_MPLUS", "大秘境") or T("USAGE_RAID", "团本")
        modeBtn:SetText(T("USAGE_BTN", "使用率参照: ") .. val)
    end
    modeBtnRefresh()
    modeBtn:SetScript("OnClick", function()
        local m = (GearInsightDB and GearInsightDB.usageMode) or "raid"
        GearInsight:SetUsageMode((m == "mplus") and "raid" or "mplus")
        modeBtnRefresh()
    end)
    modeBtn:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        GameTooltip:SetText(T("USAGE_TIP", "使用率% = 顶尖玩家实战配装的集成统计\n\n团本 — 统计团本顶尖玩家的装备\n大秘境 — 统计大秘境顶尖玩家的装备\n\n点击切换（毕业件首选顺序、使用率%、刷取规划随之联动）"), 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    modeBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    GearInsight._modeBtn = modeBtn
    GearInsight._modeBtnRefresh = modeBtnRefresh

    -- 团本装备 包含/排除 开关（独狼/不打团本玩家）
    -- 职责名词「团本装备」明确这是"是否把团本掉落纳入推荐"；排除生效时按钮变橙色提示过滤已开。
    local exRaidBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    exRaidBtn:SetSize(130, 24)
    exRaidBtn:SetPoint("TOPLEFT", 16, -82)
    local function exRaidRefresh()
        local on = (GearInsightDB and GearInsightDB.excludeRaid) and true or false
        exRaidBtn:SetText(on and T("EXRAID_BTN_ON", "团本装备: 排除") or T("EXRAID_BTN_OFF", "团本装备: 包含"))
        local fs = exRaidBtn:GetFontString()
        if fs then
            -- 排除 = 橙色（过滤生效中）；包含 = 默认金色
            if on then fs:SetTextColor(1, 0.5, 0.1) else fs:SetTextColor(1, 0.82, 0) end
        end
    end
    exRaidRefresh()
    exRaidBtn:SetScript("OnClick", function()
        local on = (GearInsightDB and GearInsightDB.excludeRaid) and true or false
        GearInsight:SetExcludeRaid(not on)
        exRaidRefresh()
    end)
    exRaidBtn:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        GameTooltip:SetText(T("EXRAID_TIP", "是否把团本掉落纳入推荐。\n排除 = 只推荐大秘境/制造等非团本来源（不打团本的独狼玩家用，套装坯子仍保留）\n包含 = 推荐含团本掉落"), 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    exRaidBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    GearInsight._exRaidBtn = exRaidBtn
    GearInsight._exRaidRefresh = exRaidRefresh

    -- 悬浮提示设置：物品 tooltip BiS 排名行的显示范围
    -- （本职业各专精逐个勾选 / 其它职业开关），点开勾选菜单。
    local tipBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    tipBtn:SetSize(110, 24)
    tipBtn:SetPoint("TOPLEFT", 150, -82)
    tipBtn:SetText(T("TTBIS_BTN", "显示设置"))
    tipBtn:SetScript("OnClick", function(s) GearInsight:ShowTooltipBisMenu(s) end)
    tipBtn:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        GameTooltip:SetText(T("TTBIS_BTN_TIP", "显示相关设置：\n· 物品悬浮提示 BiS 排名行的显示范围\n  （勾选要显示的本职业专精，其它职业默认隐藏）\n· 角色面板(C键) BiS 图标开关"), 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    tipBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- ── Overview ──────────────────────────────────────────────────
    self._ovSpec = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self._ovSpec:SetPoint("TOPLEFT", 20, -40)
    self._ovIlvl = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self._ovIlvl:SetPoint("TOPLEFT", 20, -64)
    self._ovGap  = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self._ovGap:SetPoint("TOPLEFT", 20, -84)

    -- Stat priority
    self._ovStatPri = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self._ovStatPri:SetPoint("TOPLEFT", 20, -104)

    -- Separator
    local sep1 = f:CreateTexture(nil, "ARTWORK")
    sep1:SetColorTexture(0.3, 0.3, 0.3, 0.6)
    sep1:SetPoint("TOPLEFT", 16, -128); sep1:SetPoint("TOPRIGHT", -16, -128)
    sep1:SetHeight(1)

    -- ── Stat bars (StatusBar widgets) ─────────────────────────────
    local stHdr = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    stHdr:SetPoint("TOPLEFT", 20, -138)
    stHdr:SetText(T("SECTION_STATS", "属性达成度"))
    stHdr:SetTextColor(1, 0.82, 0)

    -- Hover info: explain the target is the WCL top-player AVERAGE rating (fully buffed).
    local stInfo = CreateFrame("Frame", nil, f)
    stInfo:SetSize(20, 18)
    stInfo:SetPoint("LEFT", stHdr, "RIGHT", 4, 0)
    local stInfoFs = stInfo:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    stInfoFs:SetPoint("LEFT", 0, 0)
    stInfoFs:SetText("|cFF66BBFF(?)|r")
    stInfo:EnableMouse(true)
    stInfo:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        GameTooltip:SetText(T("STAT_BASIS_TITLE", "属性目标 = 学 WCL 顶尖玩家的属性配比"), 1, 0.82, 0)
        GameTooltip:AddLine(T("STAT_BASIS_BODY",
            "目标占比 = WCL 顶尖玩家把副属性按什么比例分配（暴击/急速/精通/全能，按当前场景：团本/高层/割草），\n" ..
            "取自他们实战面板(含宝石/附魔/取舍)——这就是该专精的属性主次。\n\n" ..
            "|cFFFFD100目标评级 = 该占比 × 你自己的副属性总量|r，所以是你【当前装等可达】的目标，告诉你该把属性往哪个方向调(宝石/附魔/换件)。\n\n" ..
            "不跨装等比绝对评级：顶尖玩家装等更高，绝对暴击天然更高、你永远追不上——只比配比才有意义。"),
            0.9, 0.9, 0.9, true)
        GameTooltip:Show()
    end)
    stInfo:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- 团本 / 高层 / 割草 属性目标来源切换 (只影响属性达成度的目标值)
    -- 3 段式按钮组：选中段 LockHighlight 高亮。
    self._statMode = self._statMode or "raid"
    if self._statMode == "mplus" then self._statMode = "mplusHigh" end  -- 迁移旧值
    local _modes = {
        { key = "raid",      label = T("MODE_RAID", "团本"),  tip = T("MODE_TIP_RAID", "团本属性目标") },
        { key = "mplusHigh", label = T("MODE_MHIGH", "高层"), tip = T("MODE_TIP_HIGH", "大秘境高层（冲分）属性目标") },
        { key = "mplusFarm", label = T("MODE_MFARM", "割草"), tip = T("MODE_TIP_FARM", "大秘境割草（+12）属性目标") },
    }
    self._statModeBtns = {}
    local _prevModeBtn = nil
    local function _updMode()
        for _, b in ipairs(self._statModeBtns) do
            if b._mode == self._statMode then b:LockHighlight() else b:UnlockHighlight() end
        end
    end
    for _, m in ipairs(_modes) do
        local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        b:SetText(m.label)
        -- ⛔ 宽度不能写死：原来是 SetSize(42,18)，那是**两个汉字**的宽度。
        -- 英文 "High Keys" / 德文 "Hohe Schlüssel" 都放不下，溢出后三个按钮撞在一起。
        -- 按实际文字宽度自适应，42 只当**最小值**（短标签不至于瘦成一条）。
        local _fs = b:GetFontString()
        local _w = (_fs and _fs:GetStringWidth() or 0) + 16
        b:SetSize(math.max(42, math.ceil(_w)), 18)
        b._mode = m.key
        if _prevModeBtn then b:SetPoint("LEFT", _prevModeBtn, "RIGHT", 2, 0)
        else b:SetPoint("LEFT", stHdr, "LEFT", 108, 1) end
        b:SetScript("OnClick", function() self._statMode = m.key; _updMode(); self:RefreshData() end)
        b:SetScript("OnEnter", function(s) GameTooltip:SetOwner(s, "ANCHOR_TOP"); GameTooltip:SetText(m.tip, 1, 0.82, 0); GameTooltip:Show() end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        self._statModeBtns[#self._statModeBtns + 1] = b
        _prevModeBtn = b
    end
    _updMode()

    self._statRows = {}
    local sKeys  = {"crit", "haste", "mastery", "versatility"}
    local sNames = {T("STAT_CRIT", "暴击"), T("STAT_HASTE", "急速"), T("STAT_MASTERY", "精通"), T("STAT_VERS", "全能")}
    local sbW, sbH = 150, 13  -- bar shortened (180→150) so the value text never truncates
    for i, sk in ipairs(sKeys) do
        local ry = -160 - (i - 1) * 26
        local rowFrame = CreateFrame("Frame", nil, f)
        rowFrame:SetPoint("TOPLEFT", 20, ry)
        rowFrame:SetPoint("TOPRIGHT", -20, ry)
        rowFrame:SetHeight(sbH)

        -- Label
        local lbl = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        lbl:SetPoint("LEFT")
        lbl:SetWidth(40)
        lbl:SetText(sNames[i])
        lbl:SetJustifyH("LEFT")

        -- StatusBar (proper widget, not hacked texture)
        local bar = CreateFrame("StatusBar", nil, rowFrame)
        bar:SetSize(sbW, sbH)
        bar:SetPoint("LEFT", lbl, "RIGHT", 4, 0)
        bar:SetStatusBarTexture("Interface\\RaidFrame\\Raid-Bar-Hp-Fill")
        bar:SetMinMaxValues(0, 1.25)
        bar:SetValue(0)
        -- Bar background
        local barBg = bar:CreateTexture(nil, "BACKGROUND")
        barBg:SetAllPoints()
        barBg:SetColorTexture(0.12, 0.12, 0.12, 0.9)
        -- Target goal line: bar is scaled to 1.25× target, so the target sits at 80% width.
        local tick = bar:CreateTexture(nil, "OVERLAY")
        tick:SetColorTexture(1, 1, 1, 0.8)
        tick:SetWidth(2)
        tick:SetPoint("TOP", bar, "TOPLEFT", sbW * (1 / 1.25), 0)
        tick:SetPoint("BOTTOM", bar, "BOTTOMLEFT", sbW * (1 / 1.25), 0)

        -- Value text
        local val = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        val:SetPoint("LEFT", bar, "RIGHT", 8, 0)
        val:SetPoint("RIGHT", rowFrame, "RIGHT", 0, 0)  -- clamp: never paint past the window edge
        val:SetWordWrap(false)
        val:SetJustifyH("LEFT")

        self._statRows[sk] = { bar = bar, val = val }
    end

    -- Separator 2
    local sep2 = f:CreateTexture(nil, "ARTWORK")
    sep2:SetColorTexture(0.3, 0.3, 0.3, 0.6)
    sep2:SetPoint("TOPLEFT", 16, -276); sep2:SetPoint("TOPRIGHT", -16, -276)
    sep2:SetHeight(1)

    -- ── Upgrade section ───────────────────────────────────────────
    local upHdr = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    upHdr:SetPoint("TOPLEFT", 20, -286)
    upHdr:SetText(T("SECTION_NEXT", "下一步建议"))
    upHdr:SetTextColor(1, 0.82, 0)

    -- ScrollFrame
    local scroll = CreateFrame("ScrollFrame", "GearInsightScrollFrame", f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 16, -308)
    scroll:SetPoint("BOTTOMRIGHT", -28, 46)
    self._scroll = scroll

    local sc = CreateFrame("Frame", nil, scroll)
    sc:SetWidth(470)
    scroll:SetScrollChild(sc)
    self._scrollChild = sc

    -- Dark scrollbar thumb styling
    local sbName = scroll:GetName() .. "ScrollBar"
    local sb = _G[sbName]
    if sb then
        local tb = sb:GetThumbTexture()
        if tb then tb:SetVertexColor(0.40, 0.40, 0.48, 0.85) end
    end

    -- Pre-create 16 upgrade row frames (parented to scroll child)
    self._upgradeRows = {}
    for i = 1, 16 do
        local row = CreateFrame("Frame", nil, sc)
        row:SetSize(456, 56)
        row:EnableMouse(true)

        -- Current item icon BUTTON (not bare Texture — enables mouse events)
        local curIconBtn = CreateFrame("Button", nil, row)
        curIconBtn:SetSize(48, 48)
        curIconBtn:SetPoint("TOPLEFT", 2, -2)
        curIconBtn.texture = curIconBtn:CreateTexture(nil, "ARTWORK")
        curIconBtn.texture:SetAllPoints()
        curIconBtn.itemID = nil
        curIconBtn.itemLink = nil
        curIconBtn.currentItemID = nil
        curIconBtn:SetScript("OnEnter", function(self)
            if not self.itemID then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if self.itemLink then GameTooltip:SetHyperlink(self.itemLink)
            else GameTooltip:SetItemByID(self.itemID) end
            GameTooltip:Show()
        end)
        curIconBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

        -- Current item text
        local curText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        curText:SetPoint("LEFT", curIconBtn, "RIGHT", 4, 0)
        curText:SetWidth(150)
        curText:SetJustifyH("LEFT")
        curText:SetWordWrap(true)

        -- Arrow
        local arrow = row:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        arrow:SetPoint("LEFT", curText, "RIGHT", 2, 0)
        arrow:SetText("→")
        arrow:SetWidth(20)
        arrow:SetJustifyH("CENTER")

        -- Target item icon BUTTON
        local tgtIconBtn = CreateFrame("Button", nil, row)
        tgtIconBtn:SetSize(48, 48)
        tgtIconBtn:SetPoint("LEFT", arrow, "RIGHT", 2, -2)
        tgtIconBtn.texture = tgtIconBtn:CreateTexture(nil, "ARTWORK")
        tgtIconBtn.texture:SetAllPoints()
        tgtIconBtn.itemID = nil
        tgtIconBtn.itemLink = nil
        tgtIconBtn.currentItemID = nil
        tgtIconBtn._tgtIlvl = 0
        tgtIconBtn._tgtName = nil
        tgtIconBtn._tgtSrc  = nil
        tgtIconBtn._fromLiveRecs   = false
        tgtIconBtn._improvementPct = nil
        tgtIconBtn._tgtStats       = nil
        tgtIconBtn:SetScript("OnEnter", function(self)
            if not self.itemID then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:ClearLines()
            -- Show full real item tooltip from game data
            if self.itemLink then
                GameTooltip:SetHyperlink(self.itemLink)
            else
                GameTooltip:SetItemByID(self.itemID)
            end
            -- Append custom annotations below the item data
            if self._tgtIlvl and self._tgtIlvl > 0 then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("|cFFFFFF00" .. T("TT_BIS_ILVL", "BiS 装等: ") .. self._tgtIlvl .. "|r", 1, 1, 1)
            end
            if self._improvementPct and self._improvementPct > 0 then
                GameTooltip:AddLine(string.format(T("TT_IMPROVE", "提升幅度: +%.1f%%"), self._improvementPct), 0.2, 1, 0.2)
            end
            if self._tgtSrc and self._tgtSrc ~= "" then
                GameTooltip:AddLine(T("TT_DROP", "掉落: ") .. self._tgtSrc, 0.8, 0.8, 0.8)
            end
            GameTooltip:AddLine(" ")
            if self._fromLiveRecs then
                GameTooltip:AddLine("|cFF00CC00" .. T("TT_COMPANION", "GearInsight Companion 实时推荐") .. "|r", 0.5, 0.5, 0.5)
            else
                GameTooltip:AddLine("|cFF888888" .. T("TT_BIS_REC", "GearInsight BiS 推荐") .. "|r", 0.5, 0.5, 0.5)
            end
            if self._slotCands and #self._slotCands > 0 then
                GameTooltip:AddLine("|cFFFFD100" .. T("TOP5_CLICK_HINT", "点击查看该部位使用率前5") .. "|r", 1, 0.82, 0)
            end
            GameTooltip:Show()
        end)
        tgtIconBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        tgtIconBtn:RegisterForClicks("LeftButtonUp")
        tgtIconBtn:SetScript("OnClick", function(self)
            if self._slotCands and #self._slotCands > 0 then
                GearInsight:ShowSlotTop5(self._slotLabel, self._slotId, self._slotCands)
            end
        end)

        -- Top-5 button: an always-visible affordance to open the slot's usage
        -- top-5 (more discoverable than the clickable BiS icon alone).
        local top5Btn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        top5Btn:SetSize(48, 22)
        top5Btn:SetPoint("TOPRIGHT", row, "TOPRIGHT", -6, -6)
        top5Btn:SetText(T("TOP5_BTN", "前5"))
        top5Btn:SetFrameLevel(60)
        top5Btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(T("TOP5_BTN_TT", "查看该部位使用率前5"), 1, 0.82, 0)
            GameTooltip:Show()
        end)
        top5Btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        top5Btn:SetScript("OnClick", function(self)
            local ic = self:GetParent()._tgtIcon
            if ic and ic._slotCands and #ic._slotCands > 0 then
                GearInsight:ShowSlotTop5(ic._slotLabel, ic._slotId, ic._slotCands)
            end
        end)

        -- Target item text
        local tgtText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        tgtText:SetPoint("LEFT", tgtIconBtn, "RIGHT", 4, 0)
        tgtText:SetPoint("RIGHT", top5Btn, "LEFT", -6, 0)
        tgtText:SetJustifyH("LEFT")
        tgtText:SetWordWrap(true)
        -- Allow breaking long no-space CJK runs so a long target name (notably the
        -- longer zhTW strings) wraps inside the row instead of spilling past the
        -- panel edge. Layout-neutral for enUS/zhCN (only adds break opportunities
        -- when the line already exceeds the box).
        if tgtText.SetNonSpaceWrap then tgtText:SetNonSpaceWrap(true) end

        -- Drop info (clickable to open Encounter Journal) — sits under the BiS
        -- target item, since the source describes where the target drops.
        local drop = CreateFrame("Button", nil, row)
        drop:SetPoint("TOPLEFT", tgtIconBtn, "BOTTOMLEFT", 0, 2)
        drop:SetPoint("RIGHT", -4, 0)
        drop:SetHeight(16)
        drop:EnableMouse(true)
        drop:RegisterForClicks("LeftButtonUp")
        drop:SetFrameLevel(50)
        local dropText = drop:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        dropText:SetAllPoints()
        dropText:SetJustifyH("LEFT")
        dropText:SetWordWrap(false)
        dropText:SetMaxLines(1)
        dropText:SetTextColor(0.55, 0.55, 0.55)
        drop._text = dropText
        drop._instId = nil
        drop._bossId = nil
        drop._itemId = nil
        drop._tierSlot = nil
        drop._tierSrcs = nil
        drop:SetScript("OnEnter", function(self)
            if self._tierSlot then
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetText(T("TT_TIER_CLICK", "点击查看可催化的同部位装备"), 0.8, 0.8, 0.8)
                GameTooltip:Show()
            elseif self._instId then
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetText(T("TT_JOURNAL_CLICK", "点击打开地下城手册"), 0.8, 0.8, 0.8)
                GameTooltip:Show()
            end
        end)
        drop:SetScript("OnLeave", function() GameTooltip:Hide() end)
        drop:SetScript("OnClick", function(self)
            if self._tierSlot then
                GearInsight:ShowTierFiller(self._tierArmor, self._tierSlot, self._tierLabel, self._tierSrcs, self._tierBonus)
            else
                _openSourceJournal(self._instId, self._bossId, self._itemId)
            end
        end)

        row._curIcon = curIconBtn
        row._curText = curText
        row._arrow   = arrow
        row._tgtIcon = tgtIconBtn
        row._tgtText = tgtText
        row._drop    = drop
        row._top5Btn = top5Btn
        row:Hide()
        self._upgradeRows[i] = row
    end

    -- ── Bottom buttons ────────────────────────────────────────────
    -- Four buttons centered in one row: 刷本优先级 | 多专精拾取 | 刷新数据 | 关闭面板
    local btnW, btnH = 112, 26
    local gap = 6
    local unit = btnW + gap        -- center-to-center spacing
    local btnF = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    btnF:SetPoint("BOTTOM", -1.5 * unit, 14)
    btnF:SetSize(btnW, btnH)
    btnF:SetText(T("BTN_FARMING", "刷本优先级"))
    btnF:SetScript("OnClick", function()
        local snap = GearInsight.SavedVars and GearInsight.SavedVars:GetLastSnapshot()
        local c, s, h
        if snap then c = snap.class; s = snap.spec; h = snap.heroTalent end
        if not c or not s then
            local sr = GearInsight.StatReader
            if sr then
                local st = sr:ReadAll()
                c = st.class; s = st.spec; h = st.heroTalent
            end
        end
        GearInsight:ShowFarmingGuide(c, s, h)
    end)

    -- Multi-spec loot planner entry (moved here from the farming guide panel)
    local btnMS = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    btnMS:SetPoint("BOTTOM", -0.5 * unit, 14)
    btnMS:SetSize(btnW, btnH)
    btnMS:SetText(T("MS_BTN_OPEN", "多专精拾取"))
    btnMS:SetScript("OnClick", function()
        local cc
        if GearInsight.StatReader then cc = GearInsight.StatReader:ReadAll().class end
        if cc then GearInsight:ShowMultiSpecPlan(cc) end
    end)

    local btnR = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    btnR:SetPoint("BOTTOM", 0.5 * unit, 14)
    btnR:SetSize(btnW, btnH)
    btnR:SetText(T("BTN_REFRESH", "刷新数据"))
    btnR:SetScript("OnClick", function() GearInsight:RefreshData(true) end)

    local btnC = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    btnC:SetPoint("BOTTOMRIGHT", -16, 12)
    btnC:SetSize(btnW, btnH)
    btnC:SetText(T("BTN_CLOSE", "关闭面板"))
    btnC:SetScript("OnClick", function() f:Hide(); GearInsight._panelVisible = false end)

    -- 网页版角色主页（gearinsight.app SSR 角色页：战力评分/AI教练/BiS缺件）。
    -- 插件沙箱开不了浏览器，点击弹复制框；与右侧 QQ/TG 按钮同行。
    local webBtn = CreateFrame("Button", nil, f)
    webBtn:SetPoint("BOTTOM", -115, 68)
    webBtn:SetSize(200, 18)
    local webBtnText = webBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    webBtnText:SetAllPoints()
    webBtnText:SetJustifyH("CENTER")
    webBtnText:SetText(T("WEB_BTN", "网页版角色主页（点击复制）"))
    webBtnText:SetTextColor(0.45, 0.85, 0.65)
    webBtn:SetScript("OnClick", function() GearInsight:ShowWebProfileDialog() end)
    webBtn:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_TOP")
        GameTooltip:SetText(T("WEB_TOOLTIP", "复制你的专属网页：战力评分 / AI 教练 / BiS 缺件\n也可发给队友看你的战绩"), 0.8, 0.8, 1, 1, true)
        GameTooltip:Show()
    end)
    webBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- QQ group clickable button
    local qqBtn = CreateFrame("Button", nil, f)
    qqBtn:SetPoint("BOTTOM", 115, 68)
    qqBtn:SetSize(220, 18)
    -- 简中客户端→QQ群；其他语言客户端→Telegram 群(面向海外)。
    local isCN = (_LOCALE == "zhCN")
    local TG_LINK = "t.me/gearInsight"
    -- 2026-08-28：1 群人数上限开到 2000 后只留这一个群，2 群不再在插件里露出
    -- （用户指示）。⛔ 一个入口最省事：两个群号并列会让人纠结加哪个，还得维护两处。
    local QQ_NUM = "954673901"
    local qqBtnText = qqBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    qqBtnText:SetAllPoints()
    qqBtnText:SetJustifyH("CENTER")
    qqBtnText:SetText(isCN and T("QQ_LABEL", "QQ群 " .. QQ_NUM .. "（点击复制）")
        or T("TG_LABEL", "Telegram: " .. TG_LINK .. " (click to copy)"))
    qqBtnText:SetTextColor(0.45, 0.70, 1.0)
    qqBtn:SetScript("OnClick", function()
        local dimmer = CreateFrame("Frame", nil, UIParent)
        dimmer:SetAllPoints()
        dimmer:SetFrameStrata("DIALOG")
        dimmer:EnableMouse(true)
        local dbg = dimmer:CreateTexture(nil, "BACKGROUND")
        dbg:SetAllPoints()
        dbg:SetColorTexture(0, 0, 0, 0.6)
        -- Click outside the box to close
        dimmer:SetScript("OnMouseDown", function(d)
            d:Hide()
        end)
        GearInsight:RegisterEscClose(dimmer, "GearInsightContactDimmer")

        local box = CreateFrame("Frame", nil, dimmer)
        box:SetSize(280, 140)
        box:SetPoint("CENTER")
        box:EnableMouse(true)
        -- Box consumes clicks so they don't reach the dimmer
        box:SetScript("OnMouseDown", nil)
        local boxBg = box:CreateTexture(nil, "BACKGROUND")
        boxBg:SetAllPoints()
        boxBg:SetColorTexture(0.08, 0.08, 0.12, 0.95)
        local boxBorder = box:CreateTexture(nil, "BORDER")
        boxBorder:SetAllPoints()
        boxBorder:SetColorTexture(0.3, 0.3, 0.5, 0.8)
        -- Inner area slightly smaller for border effect
        local boxInner = box:CreateTexture(nil, "ARTWORK")
        boxInner:SetPoint("TOPLEFT", 2, -2)
        boxInner:SetPoint("BOTTOMRIGHT", -2, 2)
        boxInner:SetColorTexture(0.12, 0.12, 0.18, 0.95)

        local title = box:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", 0, -14)
        title:SetText(isCN and T("QQ_TITLE", "QQ交流群") or T("TG_TITLE", "Telegram Group"))

        local qqEdit = CreateFrame("EditBox", nil, box, "InputBoxTemplate")
        qqEdit:SetSize(220, 28)
        qqEdit:SetPoint("TOP", title, "BOTTOM", 0, -10)
        qqEdit:SetFontObject("GameFontHighlightLarge")
        qqEdit:SetTextInsets(8, 8, 4, 4)
        qqEdit:SetText(isCN and QQ_NUM or TG_LINK)
        qqEdit:SetCursorPosition(0); qqEdit:HighlightText()
        qqEdit:SetScript("OnEscapePressed", function() dimmer:Hide() end)
        qqEdit:SetScript("OnEnterPressed", function() dimmer:Hide() end)

        local hint = box:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        hint:SetPoint("TOP", qqEdit, "BOTTOM", 0, -4)
        hint:SetText(isCN and T("QQ_HINT", "按 Ctrl+C 即可复制群号") or T("TG_HINT", "Ctrl+C to copy, open in browser to join"))
        hint:SetTextColor(0.6, 0.6, 0.6)

        local closeBtn = CreateFrame("Button", nil, box, "UIPanelButtonTemplate")
        closeBtn:SetSize(80, 24)
        closeBtn:SetPoint("BOTTOM", 0, 12)
        closeBtn:SetText(T("CLOSE_SHORT", "关闭"))
        closeBtn:SetScript("OnClick", function() dimmer:Hide() end)
        if GearInsight.Skin then GearInsight.Skin.Sweep(dimmer) end
    end)
    qqBtn:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_TOP")
        GameTooltip:SetText(isCN and T("QQ_TOOLTIP", "点击复制QQ群号 " .. QQ_NUM .. "")
            or T("TG_TOOLTIP", "Click to copy Telegram group link"), 0.8, 0.8, 1)
        GameTooltip:Show()
    end)
    qqBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    self._srcLabel = qqBtnText

    -- Data source footer
    local verDate = "2026-05-22"
    if GearInsight.BisData and GearInsight.BisData.updatedAt then
        verDate = GearInsight.BisData.updatedAt
    end
    local srcText = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    srcText:SetPoint("BOTTOM", 0, 14)
    srcText:SetText(T("DATA_FOOTER", "至暗之夜 S2 · WCL · 更新 ") .. verDate)
    srcText:SetTextColor(0.45, 0.45, 0.45)

    -- Version / author (centered, tiny — top of the footer stack)
    local author = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    author:SetPoint("BOTTOM", 0, 28)
    local verStr = (C_AddOns and C_AddOns.GetAddOnMetadata
        and C_AddOns.GetAddOnMetadata("GearInsight", "Version"))
        or (GetAddOnMetadata and GetAddOnMetadata("GearInsight", "Version"))
        or "0.17.1"
    author:SetText("v" .. verStr .. " · " .. T("AUTHOR_BY", "作者") .. " 枫叶大象-格瑞姆巴托/yinpeng")
    author:SetTextColor(0.35, 0.35, 0.35)

    -- 左侧标签页（ui/MainTabs.lua）：功能按钮归拢成翻页，总览只留装备内容。
    -- 引用在这里存一份，MainTabs 把它们 SetParent 到各自的页上（点击逻辑不动）。
    self._tabRefs = { export = exportBtn, talent = talentBtn, rot = rotBtn, dg = dgBtn,
        mode = modeBtn, exRaid = exRaidBtn, tip = tipBtn, farm = btnF, ms = btnMS,
        refresh = btnR, web = webBtn, qq = qqBtn }
    self._panelFrame = f
    if self.BuildMainTabs then self:BuildMainTabs(f) end
end

-- Paired slots share one BiS pool: rings (11/12), trinkets (13/14). The data
-- splits them per slot, but slot 2 only logs whatever players happen to keep in
-- the off slot (sparse, low usage). So we merge both slots into one pool ranked
-- by usage: slot 1 recommends #1, slot 2 recommends #2, and both show the same
-- top-5 list.
local PAIR_SLOT = { [11] = 12, [12] = 11, [13] = 14, [14] = 13 }

-- ── 武器形态(weapon config) ──────────────────────────────────────────────
-- WoW 武器槽多模态：主手(16)/副手(17)被"形态"耦合，不能当独立槽各推一件。
-- 形态: 2h(双手,副手空) / titansGrip(双2H狂怒) / dualWield(双持) / 1hShield(单手+盾)
--       / 1hOff(单手+法器) / ranged(远程,副手空)。
-- 客户端 INVTYPE 枚举 -> 与 BisData 候选 handedness 一致的标签。
local INVTYPE_HAND = {
    [17] = "2h",        -- INVTYPE_2HWEAPON
    [13] = "1h", [21] = "1h",            -- WEAPON / WEAPONMAINHAND
    [22] = "offWeapon", -- WEAPONOFFHAND
    [23] = "frill",     -- HOLDABLE
    [14] = "shield",    -- SHIELD
    [15] = "ranged", [26] = "ranged", [25] = "ranged",  -- RANGED / RANGEDRIGHT / THROWN
}
local function _itemHand(itemId)
    if not itemId or not (C_Item and C_Item.GetItemInventoryTypeByID) then return nil end
    return INVTYPE_HAND[C_Item.GetItemInventoryTypeByID(itemId)]
end
-- 从实戴主手/副手判定玩家当前武器形态；判不出返回 nil（让调用方回退 meta 主流）。
local function _playerWeaponConfig(snapshot)
    if not (snapshot and snapshot.equipped) then return nil end
    local mh, oh = snapshot.equipped[16], snapshot.equipped[17]
    local mhH = (mh and not mh.empty) and _itemHand(mh.itemId) or nil
    local ohH = (oh and not oh.empty) and _itemHand(oh.itemId) or nil
    if mhH == "ranged" then return "ranged" end
    if mhH == "2h" then return (ohH == "2h") and "titansGrip" or "2h" end
    if mhH == "1h" then
        if ohH == "shield" then return "1hShield" end
        if ohH == "frill" then return "1hOff" end
        if ohH == "offWeapon" or ohH == "1h" then return "dualWield" end
    end
    return nil
end
-- 形态 -> 该形态有无副手 / 主手该是什么手数 / 副手该是什么手数。
local WCONF_HASOFF = { ["2h"] = false, ranged = false, titansGrip = true,
    dualWield = true, ["1hShield"] = true, ["1hOff"] = true }
local WCONF_MAINHAND = { ["2h"] = "2h", titansGrip = "2h", ranged = "ranged",
    dualWield = "1h", ["1hShield"] = "1h", ["1hOff"] = "1h" }
local WCONF_OFFHAND = { titansGrip = "2h", dualWield = "offWeapon",
    ["1hShield"] = "shield", ["1hOff"] = "frill" }
-- 按 handedness 过滤候选池(主手/副手各取符合形态的)。候选无 handedness 标签时保留(容错)。
local function _filterByHand(cand, wantHand, altHand)
    if not cand or not wantHand then return cand end
    local out = {}
    for _, e in ipairs(cand) do
        local h = e.handedness
        if (not h) or h == wantHand or (altHand and h == altHand) then out[#out + 1] = e end
    end
    return (#out > 0) and out or cand
end

local function _mergePairPool(a, b)
    local byId, order = {}, {}
    local function add(list)
        if type(list) ~= "table" then return end
        for _, e in ipairs(list) do
            local id = e.itemId
            local prev = byId[id]
            if not prev then
                byId[id] = e
                order[#order + 1] = e
            elseif (e.usagePct or 0) > (prev.usagePct or 0) then
                byId[id] = e
                for i, o in ipairs(order) do
                    if o.itemId == id then order[i] = e break end
                end
            end
        end
    end
    add(a); add(b)
    table.sort(order, function(x, y) return (x.usagePct or 0) > (y.usagePct or 0) end)
    return order
end

-- ── 子窗口默认停靠 ──────────────────────────────────────────────
-- 按钮弹出的子窗口默认停靠在主面板右侧，不再叠在主面板正中（省得每次手动拖开）。
-- 只在创建时调用：玩家拖动过(StartMoving 会重锚到 UIParent)后，本次会话保持拖动位置。
-- 主面板隐藏/不存在时回退屏幕居中。SetClampedToScreen 防止主面板靠屏幕右缘时弹出屏外。
function GearInsight:AnchorPopup(f)
    f:SetClampedToScreen(true)
    -- ⛔ 玩家自己拖过就不再接管，否则每次弹出都把他摆好的位置拽回去。
    if f._giUserMoved then return end
    f:ClearAllPoints()
    local p = _G["GearInsightPanelFrame"]
    if p and p:IsShown() then
        f:SetPoint("TOPLEFT", p, "TOPRIGHT", 6, 0)
    else
        f:SetPoint("CENTER")
    end
end

-- ⭐ 2026-08-29：子窗口是**复用**的 frame，AnchorPopup 原来只在创建时跑一次，
-- 于是两种情况下它会永久压在主面板上：
--   ① 第一次弹出时主面板没开 → 落屏幕正中 → 之后一直在那；
--   ② 玩家拖过一次（StartMoving 重锚到 UIParent）→ 脱离面板。
-- 现在改成每次 Show 重新停靠；玩家真拖过的用 _giUserMoved 记住，不再动它。
function GearInsight:HookPopupReanchor(f)
    if f._giReanchorHooked then return end
    f._giReanchorHooked = true
    f:HookScript("OnShow", function(self) GearInsight:AnchorPopup(self) end)
end

-- ── ESC 关闭窗口 ────────────────────────────────────────────────
-- 走 WoW 标准 UISpecialFrames 机制：ESC 按下时游戏自动 Hide 最上层已显示的注册窗口
-- （多层弹窗按 ESC 逐层关闭，全关完才弹游戏菜单）。
-- 匿名 frame 注册到 _G 起全局名；同名重复注册只覆盖 _G 引用不重复进表
-- （ShowExportDialog 等每次新建 frame 的场景靠固定 name 防 UISpecialFrames 无限膨胀）。
-- 注意：战斗 HUD（LiveGuide 卡片/读条高亮/嗜血条）不要注册，ESC 不应关 HUD。
local _escRegistered = {}
function GearInsight:RegisterEscClose(frame, name)
    if not frame then return end
    local gname = frame:GetName() or name
    if not gname then return end
    _G[gname] = frame
    if not _escRegistered[gname] then
        _escRegistered[gname] = true
        tinsert(UISpecialFrames, gname)
    end
end

-- ── Copy popup (consumable name → paste into Auction House search) ───
-- WoW addons can't write the OS clipboard directly; the standard pattern is a
-- highlighted EditBox the player copies with Ctrl+C, then pastes into the AH.
-- ⭐ 提示文字换行后多出来的高度。中文提示基本就一行，英文/德文常常两三行；
-- 弹窗高度写死 130/210 就会把文字顶出去。这里把超出一行的部分补回去。
function GearInsight:_HintExtra(f)
    local h = f and f._hint
    if not h or not h:IsShown() then return 0 end
    local _, size = h:GetFont()
    local one = size or 12
    local extra = (h:GetStringHeight() or one) - one
    return math.max(0, math.floor(extra + 0.5))
end

function GearInsight:ShowCopyText(text, hint, title, name, build)
    -- 同内容再点一次 = 关闭（导出装备等按钮第二次点击收起）；内容变了则原位刷新。
    local fc = self._copyFrame
    if fc and fc:IsShown() and fc._txt == text then fc:Hide(); return end
    local f = self._copyFrame
    if not f then
        f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        GearInsight:RegisterEscClose(f, "GearInsightCopyFrame")
        f:SetSize(600, 130); GearInsight:AnchorPopup(f); GearInsight:HookPopupReanchor(f)
        f:SetFrameStrata("FULLSCREEN_DIALOG"); f:SetFrameLevel(50)
        f:SetBackdrop({
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize = 32,
            insets = { left = 8, right = 8, top = 8, bottom = 8 },
        })
        f:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.95)
        local bg = f:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints()
        bg:SetColorTexture(0.05, 0.05, 0.08, 0.97)
        f:EnableMouse(true); f:SetMovable(true); f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", function() f:StartMoving() end)
        f:SetScript("OnDragStop", function() f:StopMovingOrSizing(); f._giUserMoved = true end)
        local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", 0, -14)
        f._title = title
        local cb = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        cb:SetPoint("TOPRIGHT", -4, -4); cb:SetScript("OnClick", function() f:Hide() end)
        local edit = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
        edit:SetSize(540, 24); edit:SetPoint("TOP", 0, -46); edit:SetAutoFocus(true)
        edit:SetFontObject("GameFontHighlightSmall")
        edit:SetScript("OnEscapePressed", function(s) s:ClearFocus(); f:Hide() end)
        edit:SetScript("OnEnterPressed", function(s) s:HighlightText() end)
        -- Keep it read-only-ish: restore the text if the user edits it.
        edit:SetScript("OnTextChanged", function(s, userInput)
            if userInput and s:GetText() ~= f._txt then s:SetText(f._txt); s:HighlightText() end
        end)
        f._edit = edit
        -- 第二个可复制框：载入档命名(导入后给天赋配置命名用)
        local nlbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        nlbl:SetPoint("TOPLEFT", edit, "BOTTOMLEFT", 0, -12); nlbl:SetText(T("COPY_NAME_LABEL", "命名"))
        f._nameLbl = nlbl
        local nedit = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
        nedit:SetSize(540, 24); nedit:SetPoint("TOPLEFT", nlbl, "BOTTOMLEFT", 4, -6); nedit:SetAutoFocus(false)
        nedit:SetFontObject("GameFontHighlightSmall")
        nedit:SetScript("OnEscapePressed", function(s) s:ClearFocus(); f:Hide() end)
        nedit:SetScript("OnEnterPressed", function(s) s:HighlightText() end)
        nedit:SetScript("OnEditFocusGained", function(s) s:SetCursorPosition(0); s:HighlightText() end)
        nedit:SetScript("OnTextChanged", function(s, userInput)
            if userInput and s:GetText() ~= f._name then s:SetText(f._name); s:HighlightText() end
        end)
        f._nameEdit = nedit
        local h = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        h:SetWidth(540); h:SetJustifyH("CENTER")
        h:SetWordWrap(true); h:SetMaxLines(3)   -- ⛔ 英文/德文提示比中文长很多，不开换行会顶出弹窗
        f._hint = h
        -- 一键导入按钮(仅天赋模式显示)：走 UI 级 ImportLoadout(用户拍板恢复,
        -- 见 TalentExport.lua 风险注释)，失败降级为"打开面板手动粘贴导入"。
        local imp = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        imp:SetSize(170, 24); imp:SetText(T("TALENT_IMPORT_BTN", "一键导入天赋"))
        imp:SetScript("OnClick", function()
            local ok, msg = GearInsight_TryImportTalents(f._txt, f._name)
            if ok then
                GearInsight:Print(string.format(T("TALENT_IMPORT_OK2", "已导入「%s」→ 天赋面板点「应用更改」生效"), msg or "?"))
                f:Hide(); return
            end
            GearInsight:Print(T("TALENT_IMPORT_FAIL", "导入失败：") .. (msg or "?")
                .. T("TALENT_APPLY_FALLBACK", "，已转手动导入"))
            -- 降级：打开天赋面板，玩家 Ctrl+V 手动导入
            local ok2 = GearInsight_OpenTalentImport(f._txt)
            if ok2 then
                GearInsight:Print(T("TALENT_IMPORT_OK", "天赋面板已打开：左下「载入档」→「导入」→ Ctrl+V 粘贴（串没复制就回本窗口 Ctrl+C）"))
            end
        end)
        f._impBtn = imp
        self._copyFrame = f
    end
    f._txt = text
    f._build = build
    f._title:SetText(title or T("COPY_TITLE", "去拍卖行购买"))
    f._edit:SetText(text); f._edit:SetCursorPosition(0); f._edit:HighlightText(); f._edit:SetFocus()
    -- ⛔ 提示文字必须在算高度**之前**设好：_HintExtra 靠 GetStringHeight 量行数，
    --    原来这行写在两个 SetHeight 后面，量到的是上一次弹窗的旧文字。
    f._hint:SetText(hint or T("COPY_HINT", "Ctrl+C 复制，到拍卖行搜索框粘贴购买"))
    if name and name ~= "" then
        f._name = name
        f._nameLbl:Show(); f._nameEdit:Show(); f._nameEdit:SetText(name); f._nameEdit:SetCursorPosition(0)
        f._hint:ClearAllPoints(); f._hint:SetPoint("TOP", f._nameEdit, "BOTTOM", 0, -10)
        f._impBtn:Show(); f._impBtn:ClearAllPoints(); f._impBtn:SetPoint("TOP", f._hint, "BOTTOM", 0, -8)
        f:SetHeight(210 + GearInsight:_HintExtra(f))
    else
        f._name = nil
        f._nameLbl:Hide(); f._nameEdit:Hide(); f._impBtn:Hide()
        f._hint:ClearAllPoints(); f._hint:SetPoint("TOP", f._edit, "BOTTOM", 0, -10)
        f:SetHeight(130 + GearInsight:_HintExtra(f))
    end
    if GearInsight.Skin then GearInsight.Skin.Sweep(f) end
    f:Show()
end

-- WCL 顶尖天赋选择弹窗：团本/冲分/割草 各前5名，点一行复制该套导入串。
function GearInsight:ShowTalentPicker(embed)
    -- 第二次点击「WCL天赋库」= 收起（⛔只对弹窗模式；主面板「天赋」标签页嵌入时
    -- 显隐由标签切换管，2026-08-31 用户「天赋单独弄一个标签」）
    if not embed and self._talentPickerFrame and self._talentPickerFrame:IsShown() then
        self._talentPickerFrame:Hide(); return
    end
    -- 天赋库数据(~6.5MB Lua 内存,占插件 70%)拆为 LoadOnDemand 子插件
    -- GearInsight_Talents：首次点「WCL天赋库」才加载，平时不占内存。
    if not GearInsightPopularTalents then
        local reason
        if C_AddOns and C_AddOns.LoadAddOn then
            local _, r = C_AddOns.LoadAddOn("GearInsight_Talents"); reason = r
        elseif LoadAddOn then
            local _, r = LoadAddOn("GearInsight_Talents"); reason = r
        end
        if not GearInsightPopularTalents then
            self:Print(T("TALENT_LOD_FAIL", "天赋库模块(GearInsight_Talents)加载失败：")
                .. tostring(reason or "?")
                .. T("TALENT_LOD_HINT", "  请到角色选择界面「插件」列表确认它已启用"))
            return
        end
    end
    local specID = GearInsight_CurrentSpecID and GearInsight_CurrentSpecID()
    local d = specID and GearInsight_GetTalentData and GearInsight_GetTalentData(specID)
    if not d or not d.content then
        self:Print(T("TALENT_NODATA", "当前专精暂无天赋数据(切到对应专精了吗？)")); return
    end
    local f = self._talentPickerFrame
    if not f then
        f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        GearInsight:RegisterEscClose(f, "GearInsightTalentPicker")
        f:SetSize(460, 440); GearInsight:AnchorPopup(f)
        f:SetFrameStrata("FULLSCREEN_DIALOG"); f:SetFrameLevel(60)
        f:SetBackdrop({ edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize = 32,
            insets = { left = 8, right = 8, top = 8, bottom = 8 } })
        f:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.95)
        local bg = f:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(0.04, 0.04, 0.07, 0.98)
        f:EnableMouse(true); f:SetMovable(true); f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", function() f:StartMoving() end)
        f:SetScript("OnDragStop", function() f:StopMovingOrSizing(); f._giUserMoved = true end)
        f._title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); f._title:SetPoint("TOP", 0, -12)
        f._hint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        f._hint:SetPoint("TOP", f._title, "BOTTOM", 0, -3)
        local cb = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        cb:SetPoint("TOPRIGHT", -4, -4); cb:SetScript("OnClick", function() f:Hide() end)
        f._giClose = cb
        f._rows = {}
        self._talentPickerFrame = f
    end
    -- 嵌入模式：寄宿到主面板「天赋」标签页里（去边框/关闭钮/拖动，铺满页身）
    if embed and self._talentHost and f:GetParent() ~= self._talentHost then
        f:SetParent(self._talentHost)
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", 0, -34)
        f:SetPoint("BOTTOMRIGHT", 0, 0)
        f:SetFrameStrata("HIGH")
        f:SetFrameLevel(self._talentHost:GetFrameLevel() + 1)
        f:SetBackdrop(nil)
        f:SetMovable(false)
        if f._giClose then f._giClose:Hide() end
    end
    f._title:SetText(T("TALENT_PICK_TITLE", "WCL 顶尖天赋库"))
    f._hint:SetText(T("TALENT_PICK_HINT", "点标题切 boss/副本 · 点一行复制该套导入串"))

    local _loc = _LOCALE
    local _zhClient = (_loc == "zhCN" or _loc == "zhTW")
    local function heroCN(en)
        if not _zhClient then return en or "" end  -- 英文等客户端显示英文英雄天赋名
        local info = GearInsightHeroInfo and GearInsightHeroInfo[en]
        return (info and info.cn) or en or ""
    end
    local REGION_LABEL = {
        US = T("REGION_US", "美服"), EU = T("REGION_EU", "欧服"), KR = T("REGION_KR", "韩服"),
        TW = T("REGION_TW", "台服"), CN = T("REGION_CN", "国服"), RU = T("REGION_RU", "俄服"),
    }
    local function regionLabel(code) return (code and code ~= "" and (REGION_LABEL[code] or code)) or "" end
    local function encName(ec) return (_zhClient and ec.enc or ec.encEn) or ec.enc or "" end
    -- 团本 boss 有 M 代号(M1=第1个boss…)：标题前缀显示，命名里也带上。
    -- m 可能是数字(旧团本史诗, 显示 M1/M2…)，也可能已经带难度前缀的字符串
    -- (新团本英雄难度天赋库写的是 "H2")。⛔ 别无脑拼 "M"，否则会显示成 "MH2"。
    local function mcode(ec)
        if not ec.m then return nil end
        if type(ec.m) == "number" then return "M" .. ec.m end
        return tostring(ec.m)
    end
    local function encDisplay(ec) local m = mcode(ec); return (m and (m .. " ") or "") .. encName(ec) end
    -- 内容: key / 中文 / 强度标(M几)
    local CONTENT = {
        { "raid", T("CONTENT_RAID", "团本"), "" },
        { "mplusHigh", T("CONTENT_PUSH", "冲分"), T("MLEVEL_HIGH", "高层") },
        { "mplusFarm", T("CONTENT_FARM", "割草"), T("MLEVEL_FARM", "+12") },
    }
    -- 每内容当前选中的 boss/副本下标（按专精记忆）
    self._talentSel = self._talentSel or {}
    if f._specID ~= specID then self._talentSel = {}; f._specID = specID end
    local sel = self._talentSel

    local render
    render = function()
        for _, r in ipairs(f._rows) do r:Hide() end
        local y, ri = -50, 0
        local function getRow(h)
            ri = ri + 1
            local row = f._rows[ri]
            if not row then
                row = CreateFrame("Button", nil, f)
                local hl = row:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints()
                hl:SetColorTexture(1, 0.82, 0, 0.16)
                row.txt = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                row.txt:SetPoint("LEFT", 10, 0); row.txt:SetPoint("RIGHT", -8, 0); row.txt:SetJustifyH("LEFT")
                f._rows[ri] = row
            end
            row:SetSize(438, h or 18)
            row:ClearAllPoints(); row:SetPoint("TOPLEFT", 11, y); row:Show(); y = y - (h or 18) - 1
            return row
        end
        for _, cc in ipairs(CONTENT) do
            local encs = d.content[cc[1]]
            if encs and #encs > 0 then
                local idx = sel[cc[1]] or 1
                if idx > #encs then idx = 1 end
                sel[cc[1]] = idx
                local ec = encs[idx]
                -- 全队是否同一英雄天赋：是→标题显示一次，行不重复；否→每行各标。
                local allSame, firstHero = true, ec.list[1] and ec.list[1].hero
                for _, b in ipairs(ec.list) do if b.hero ~= firstHero then allSame = false; break end end
                -- 分组标题（可点切 boss/副本）
                local hdr = getRow(22)
                local mtag = cc[3] ~= "" and (" |cFF66BBFF[" .. cc[3] .. "]|r") or ""
                local nav = (#encs > 1) and string.format("  |cFF999999(%d/%d)|r", idx, #encs) or ""
                local heroStr = (allSame and firstHero) and (" |cFF7FB0FF· " .. heroCN(firstHero) .. "|r") or ""
                hdr.txt:SetText(string.format("|cFFFFD100%s|r%s  |cFFE6E0C8%s|r%s%s",
                    cc[2], mtag, encDisplay(ec), heroStr, nav))
                if #encs > 1 then
                    hdr:EnableMouse(true)
                    hdr:RegisterForClicks("LeftButtonUp", "RightButtonUp")
                    hdr:SetScript("OnClick", function(s, button)
                        if button == "RightButton" then sel[cc[1]] = ((idx - 2) % #encs) + 1
                        else sel[cc[1]] = (idx % #encs) + 1 end
                        render()
                    end)
                    hdr:SetScript("OnEnter", function(s)
                        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
                        GameTooltip:SetText(T("TALENT_SWITCH_TIP", "左键下一个 / 右键上一个 boss·副本"), 1, 0.82, 0); GameTooltip:Show()
                    end)
                    hdr:SetScript("OnLeave", function() GameTooltip:Hide() end)
                else
                    hdr:EnableMouse(false); hdr:SetScript("OnClick", nil); hdr:SetScript("OnEnter", nil); hdr:SetScript("OnLeave", nil)
                end
                -- 前5名行：名次 + 玩家-服务器 + [地区]（英雄天赋仅与主流不同时标注）
                for i, b in ipairs(ec.list) do
                    local row = getRow(18)
                    row:EnableMouse(true); row:RegisterForClicks("LeftButtonUp")
                    local who = (b.player and b.player ~= "" and (b.player .. (b.server ~= "" and ("-" .. b.server) or ""))) or "?"
                    local reg = regionLabel(b.region)
                    local regStr = reg ~= "" and ("  |cFF888888[" .. reg .. "]|r") or ""
                    local heroExtra = (not allSame) and ("  |cFF7FB0FF" .. heroCN(b.hero) .. "|r") or ""
                    row.txt:SetText(string.format("    |cFFFFD100#%d|r  %s%s%s", i, who, regStr, heroExtra))
                    row._b = b.b
                    row._copyTitle = string.format(T("TALENT_COPY_TITLE", "WCL %s · %s #%d"), cc[2], encDisplay(ec), i)
                    -- 载入档命名：中文用全名(团本"M1-元首阿福扎恩-#1"/秘境"割草-通天-#5")，
                    -- 英文等客户端名字长,取首词("M1-Imperator-#1"/"Farm-Pit-#4")。
                    local lbase = encName(ec)
                    if not _zhClient then lbase = lbase:match("^(%S+)") or lbase end
                    row._lname = string.format("%s-%s-#%d", mcode(ec) or cc[2], lbase, i)
                    row:SetScript("OnClick", function(s)
                        local str, err = GearInsight_ExportTalentBuild(specID, d.pool[s._b], d.dict)
                        if not str then GearInsight:Print(T("TALENT_FAIL", "失败：") .. (err or "?")); return end
                        GearInsight:ShowCopyText(str, T("TALENT_COPY_HINT", "Ctrl+C 复制 → 天赋面板「导入」粘贴"), s._copyTitle, s._lname,
                            { specID = specID, flat = d.pool[s._b], dict = d.dict })
                    end)
                    row:SetScript("OnEnter", nil); row:SetScript("OnLeave", nil)
                end
            end
        end
        f:SetHeight(math.max(140, -y + 14))
    end
    render()
    if GearInsight.Skin then GearInsight.Skin.Sweep(f) end
    f:Show()
end

-- 循环参考弹窗：WCL 顶尖玩家「真实起手序列 + 核心技能频率 + BUFF盯防」，团本(M1)/大秘境切换。
-- 数据 core/RotationData.lua(spellID 主键)；技能名/图标由客户端 C_Spell 本地化；
-- IsPlayerSpell 过滤你未习得的技能(饰品/异族种族技能/未选天赋)。
function GearInsight:ShowRotationRef()
    -- 第二次点击「AI技术指导」= 收起
    if self._rotRefFrame and self._rotRefFrame:IsShown() then
        self._rotRefFrame:Hide(); return
    end
    local specID = GearInsight_CurrentSpecID and GearInsight_CurrentSpecID()
    local d
    if specID then
        for _, v in pairs(GearInsightRotation or {}) do
            if v.specID == specID then d = v; break end
        end
    end
    if not (d and (d.raid or d.mplus)) then
        self:Print(T("ROT_NODATA", "当前专精暂无循环数据(切到对应专精了吗？)")); return
    end

    local function spellInfo(id)
        if C_Spell and C_Spell.GetSpellInfo then
            local si = C_Spell.GetSpellInfo(id)
            if si then return si.name, si.iconID end
        elseif GetSpellInfo then
            local name, _, icon = GetSpellInfo(id)
            return name, icon
        end
    end
    local function known(id)
        if IsPlayerSpell and IsPlayerSpell(id) then return true end
        -- 二阶段/override 技能(虚空盾等)：IsPlayerSpell 可能只认基础形态，反查 base 再判
        local b = FindBaseSpellByID and FindBaseSpellByID(id)
        return (b and b ~= id and IsPlayerSpell and IsPlayerSpell(b)) or false
    end
    -- 被动天赋/装备proc：IsPlayerSpell 对已选天赋的被动也返回 true，需再判被动
    local function passive(id)
        if C_Spell and C_Spell.IsSpellPassive then return C_Spell.IsSpellPassive(id) end
        if IsPassiveSpell then return IsPassiveSpell(id) end
        return false
    end
    local _loc = _LOCALE
    local _zhC = (_loc == "zhCN" or _loc == "zhTW")
    -- buff 一行解释（离线烘焙，基于暴雪官方描述压缩）
    local function noteOf(id)
        local n = GearInsightRotation and GearInsightRotation.notes and GearInsightRotation.notes[id]
        if not n then return nil end
        return _zhC and n.cn or (n.en or n.cn)
    end

    local f = self._rotRefFrame
    if not f then
        f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        GearInsight:RegisterEscClose(f, "GearInsightRotRef")
        f:SetSize(470, 520); GearInsight:AnchorPopup(f)
        f:SetFrameStrata("FULLSCREEN_DIALOG"); f:SetFrameLevel(60)
        f:SetBackdrop({ edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize = 32,
            insets = { left = 8, right = 8, top = 8, bottom = 8 } })
        f:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.95)
        local bg = f:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(0.04, 0.04, 0.07, 0.98)
        f:EnableMouse(true); f:SetMovable(true); f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", function() f:StartMoving() end)
        f:SetScript("OnDragStop", function() f:StopMovingOrSizing(); f._giUserMoved = true end)
        f._title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); f._title:SetPoint("TOP", 0, -12)
        f._hint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        f._hint:SetPoint("TOP", f._title, "BOTTOM", 0, -3)
        local cb = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        cb:SetPoint("TOPRIGHT", -4, -4); cb:SetScript("OnClick", function() f:Hide() end)
        -- 场景切换按钮（团本/大秘境）+ 切换引导（用户不知道红按钮可点）
        f._modeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        f._modeBtn:SetSize(170, 22); f._modeBtn:SetPoint("TOPLEFT", 14, -56)
        f._modeHint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        f._modeHint:SetPoint("LEFT", f._modeBtn, "RIGHT", 8, 0)
        -- AI 教练解读：多行折行文本（高度按内容量），技能名转超链接可悬停
        f._coachFS = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        f._coachFS:SetWidth(432); f._coachFS:SetJustifyH("LEFT"); f._coachFS:SetSpacing(3)
        f:SetHyperlinksEnabled(true)
        f:SetScript("OnHyperlinkEnter", function(_, link)
            GameTooltip:SetOwner(f, "ANCHOR_CURSOR")
            GameTooltip:SetHyperlink(link)
            GameTooltip:SetFrameStrata("TOOLTIP")
            GameTooltip:Show()
        end)
        f:SetScript("OnHyperlinkLeave", function() GameTooltip:Hide() end)
        f._rows, f._opBtns = {}, {}
        self._rotRefFrame = f
    end
    f._title:SetText(T("ROT_TITLE", "AI 技术指导"))
    f._hint:SetText(T("ROT_HINT", "AI 解读 WCL 顶尖玩家实战数据 · 鼠标悬停看技能说明"))

    if f._specID ~= specID then
        f._mode = (GearInsightDB and GearInsightDB.usageMode) or "raid"
        f._openIdx = 1
        f._specID = specID
    end
    if not d[f._mode] then f._mode = d.raid and "raid" or "mplus" end

    local render
    render = function()
        local blk = d[f._mode]
        for _, r in ipairs(f._rows) do r:Hide() end
        for _, b in ipairs(f._opBtns) do b:Hide() end

        -- 你的实战数据（CombatStats 会话累计；≥60s 才开对比，太短没统计意义）
        local my = GearInsight_GetCombatStats and GearInsight_GetCombatStats() or nil
        local myOn = (my and my.time >= 60) and true or false
        -- 二阶段/变体技能归并：英雄天赋会把技能改成新ID新名字(真言术：盾→虚空盾、
        -- 愈合→虚空愈合等)，玩家两种形态都放过时次数会拆在两个ID下。
        -- 用 FindBaseSpellByID 官方 override→base 映射归并到基础技能，同名合并兜底。
        local function isVariantOf(cid, id, name)
            -- override→base：二阶段技能反查基础技能
            if FindBaseSpellByID and FindBaseSpellByID(cid) == id then return true end
            if C_Spell and C_Spell.GetBaseSpell and C_Spell.GetBaseSpell(cid) == id then return true end
            -- base→override：基础技能查当前替换形态（双向兜底）
            if FindSpellOverrideByID and FindSpellOverrideByID(id) == cid then return true end
            -- 同名不同ID（英雄天赋改版但名字没变）
            return spellInfo(cid) == name
        end
        local function myCpm(id, name)
            if not myOn then return nil end
            local c = my.casts[id] or 0
            for cid, n in pairs(my.casts) do
                if cid ~= id and isVariantOf(cid, id, name) then c = c + n end
            end
            return c / (my.time / 60)
        end
        local function myUp(id, name)
            if not myOn then return nil end
            local s = my.aura[id] or 0
            for aid, sec in pairs(my.aura) do
                if aid ~= id and isVariantOf(aid, id, name) then s = s + sec end
            end
            return s / my.time * 100
        end
        local function ratioColor(mine, top)
            if not top or top <= 0 then return "FFFFFF" end
            local r = mine / top
            if r >= 0.8 then return "55E055" elseif r >= 0.5 then return "FFD100" else return "FF5555" end
        end

        -- 场景按钮
        local raidLabel = d.raid and string.format("%s M%d·%s", T("ROT_MODE_RAID", "团本"),
            d.raid.mNum or 1, d.raid.encCn or "") or nil
        f._modeBtn:SetText(f._mode == "raid" and (raidLabel or "") or T("ROT_MODE_MPLUS", "大秘境(冲分)"))
        if d.raid and d.mplus then
            f._modeBtn:Enable()
            f._modeBtn:SetScript("OnClick", function()
                f._mode = (f._mode == "raid") and "mplus" or "raid"; render()
            end)
            f._modeHint:SetText(T("ROT_MODE_HINT", "← 点击切换场景（两套循环差异很大）"))
        else
            f._modeBtn:Disable()
            f._modeHint:SetText("")
        end

        local y, ri = -86, 0
        local function getRow(h)
            ri = ri + 1
            local row = f._rows[ri]
            if not row then
                row = CreateFrame("Button", nil, f)
                local hl = row:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints()
                hl:SetColorTexture(1, 0.82, 0, 0.12)
                row.txt = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                row.txt:SetPoint("LEFT", 10, 0); row.txt:SetPoint("RIGHT", -8, 0); row.txt:SetJustifyH("LEFT")
                f._rows[ri] = row
            end
            row:SetSize(446, h or 18)
            row:ClearAllPoints(); row:SetPoint("TOPLEFT", 12, y); row:Show(); y = y - (h or 18) - 1
            row._spell, row._tipLine = nil, nil
            row:EnableMouse(true)
            row:SetScript("OnClick", nil)
            row:SetScript("OnEnter", function(s)
                if s._spell then
                    GameTooltip:SetOwner(s, "ANCHOR_RIGHT"); GameTooltip:SetSpellByID(s._spell)
                    if s._tipLine then
                        GameTooltip:AddLine(" ")
                        GameTooltip:AddLine(s._tipLine, 0.4, 0.73, 1, true)
                    end
                    GameTooltip:SetFrameStrata("TOOLTIP")  -- 防止被 FULLSCREEN_DIALOG 弹窗盖住
                    GameTooltip:Show()
                end
            end)
            row:SetScript("OnLeave", function() GameTooltip:Hide() end)
            return row
        end
        -- 长文本行折行后会超出固定行高压到下一行：按实际文本高度撑大行并顺延 y
        local function grow(row)
            local h = math.max(18, math.ceil(row.txt:GetStringHeight()) + 6)
            if h > row:GetHeight() then
                y = y - (h - row:GetHeight())
                row:SetHeight(h)
            end
        end

        -- 实战对照状态行：开启=显示累计时长(点击清零)；未开启=引导先打一架
        local st = getRow(18)
        if myOn then
            st.txt:SetText(string.format("|cFF55E055%s|r  |cFF999999%s|r",
                string.format(T("ROT_MY_ON", "实战对照已开启：累计战斗 %.1f 分钟 / %d 场"), my.time / 60, my.fights),
                T("ROT_MY_RESET", "点击清零（换团本/大秘境场景时建议清）")))
            st:SetScript("OnClick", function()
                if GearInsight_CombatStatsReset then GearInsight_CombatStatsReset() end
                render()
            end)
        else
            st.txt:SetText("|cFF999999" .. T("ROT_MY_OFF", "实战对照：进战斗累计满 1 分钟后，下方自动出现「你 vs 顶尖」") .. "|r")
        end
        st:SetScript("OnEnter", nil)
        grow(st)

        -- ── 0. AI 教练解读（离线烘焙：DeepSeek 把下方确定性数据翻成话术，出厂前人工可审）──
        f._coachFS:Hide()
        if blk.coach then
            local hdr = getRow(20)
            hdr.txt:SetText("|cFF66BBFF" .. T("ROT_COACH", "AI 教练解读") .. "|r  |cFF777777"
                .. T("ROT_COACH_BY", "AI 大模型离线生成 · 非实时") .. "|r")
            hdr:SetScript("OnEnter", function(s)
                GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
                GameTooltip:SetText(T("ROT_COACH_TIP", "由 AI 大模型在数据更新时离线生成（游戏内不联网）。AI 只把下方的确定性统计翻译成人话——技能与数字全部来自 WCL 顶尖玩家日志，不添加任何数据之外的内容。"), 1, 1, 1, 1, true)
                GameTooltip:Show()
            end)
            local ctxt = _zhC and blk.coach.cn or (blk.coach.en or blk.coach.cn)
            -- 文案里出现的技能名 → 超链接（映射来自本块 core/watch/起手的 spellID，悬停看说明）
            do
                local ids, seenNm = {}, {}
                for _, c in ipairs(blk.core or {}) do ids[#ids + 1] = c[1] end
                for _, w in ipairs(blk.watch or {}) do ids[#ids + 1] = w[1] end
                for _, o in ipairs(blk.opener or {}) do
                    for _, id in ipairs(o.seq) do ids[#ids + 1] = id end
                end
                -- 名字长的先替换，避免"裂伤"抢了"撕裂伤口"这类子串
                local names = {}
                for _, id in ipairs(ids) do
                    local nm = spellInfo(id)
                    if nm and #nm >= 4 and not seenNm[nm] then
                        seenNm[nm] = true
                        names[#names + 1] = { nm, id }
                    end
                end
                table.sort(names, function(a, b) return #a[1] > #b[1] end)
                local done = {}
                for _, e in ipairs(names) do
                    -- 短名是已替换长名的子串时跳过，否则会改坏已插入的链接文本
                    local sub = false
                    for _, dn in ipairs(done) do
                        if dn:find(e[1], 1, true) then sub = true; break end
                    end
                    if not sub then
                        local pat = e[1]:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")
                        ctxt = ctxt:gsub(pat, "|Hspell:" .. e[2] .. "|h|cFF71D5FF" .. e[1] .. "|r|h")
                        done[#done + 1] = e[1]
                    end
                end
            end
            f._coachFS:SetText("|cFFD8E8FF" .. (ctxt or "") .. "|r")
            f._coachFS:ClearAllPoints(); f._coachFS:SetPoint("TOPLEFT", 22, y)
            f._coachFS:Show()
            y = y - f._coachFS:GetStringHeight() - 8
        end

        -- ── 1. 起手序列（仅团本；前3名真实起手，点标题换人）──
        if f._mode == "raid" and blk.opener and #blk.opener > 0 then
            if f._openIdx > #blk.opener then f._openIdx = 1 end
            local op = blk.opener[f._openIdx]
            local hdr = getRow(20)
            -- 玩家标识与天赋库一致：名字-服务器 [地区]
            local REGION_LABEL = {
                US = T("REGION_US", "美服"), EU = T("REGION_EU", "欧服"), KR = T("REGION_KR", "韩服"),
                TW = T("REGION_TW", "台服"), CN = T("REGION_CN", "国服"), RU = T("REGION_RU", "俄服"),
            }
            local who = op.player or "?"
            if op.server and op.server ~= "" then who = who .. "-" .. op.server end
            local regStr = (op.region and op.region ~= "")
                and ("  |cFF888888[" .. (REGION_LABEL[op.region] or op.region) .. "]|r") or ""
            hdr.txt:SetText(string.format("|cFFFFD100%s|r  |cFFE6E0C8#%d %s|r%s  |cFF999999(%d/%d %s)|r",
                T("ROT_OPENER", "起手序列"), f._openIdx, who, regStr,
                f._openIdx, #blk.opener, T("ROT_OPENER_SWITCH", "点击换人")))
            hdr:SetScript("OnClick", function() f._openIdx = f._openIdx % #blk.opener + 1; render() end)
            hdr:SetScript("OnEnter", nil)
            -- 图标条：全部显示（开场按饰品本身就是教学点）；你未习得的(饰品/种族/未选天赋)灰显
            local bx, bi = 12, 0
            for _, id in ipairs(op.seq) do
                local _, icon = spellInfo(id)
                if icon then
                    bi = bi + 1
                    local b = f._opBtns[bi]
                    if not b then
                        b = CreateFrame("Button", nil, f)
                        b:SetSize(28, 28)
                        b._tex = b:CreateTexture(nil, "ARTWORK"); b._tex:SetAllPoints()
                        b._num = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                        b._num:SetPoint("BOTTOMRIGHT", 1, 0)
                        b:SetScript("OnEnter", function(s)
                            GameTooltip:SetOwner(s, "ANCHOR_RIGHT"); GameTooltip:SetSpellByID(s._spell)
                            GameTooltip:SetFrameStrata("TOOLTIP")
                            GameTooltip:Show()
                        end)
                        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
                        f._opBtns[bi] = b
                    end
                    b._tex:SetTexture(icon)
                    local have = known(id)
                    b._tex:SetDesaturated(not have)
                    b._tex:SetAlpha(have and 1 or 0.55)
                    b._num:SetText((have and "|cFFFFD100" or "|cFF888888") .. bi .. "|r")
                    b._spell = id
                    b:ClearAllPoints(); b:SetPoint("TOPLEFT", bx, y); b:Show()
                    bx = bx + 31
                    if bx > 446 - 28 then bx = 12; y = y - 31 end
                end
            end
            if bi > 0 then y = y - 33 else
                local r = getRow(18); r.txt:SetText("|cFF999999" .. T("ROT_OPENER_EMPTY", "（起手技能均未习得——先抄该玩家天赋）") .. "|r")
            end
        end

        -- M+ 整本无固定开场，起手序列只在团本视图：给一行可点的指路
        if f._mode == "mplus" and d.raid and d.raid.opener and #d.raid.opener > 0 then
            local tip = getRow(18)
            tip.txt:SetText("|cFF66BBFF" .. T("ROT_OPENER_SEE_RAID", "起手序列在「团本」视图（大秘境整本无固定开场）· 点此切换") .. "|r")
            tip:SetScript("OnClick", function() f._mode = "raid"; render() end)
            tip:SetScript("OnEnter", nil)
            grow(tip)
        end

        -- ── 2. 核心技能（次/分钟，中位数）──
        if blk.core and #blk.core > 0 then
            local hdr = getRow(20)
            hdr.txt:SetText(string.format("|cFFFFD100%s|r  |cFF999999%s|r",
                T("ROT_CORE", "技能使用频率"), T("ROT_CORE_SUB", "次/分钟·顶尖玩家中位数")))
            hdr:SetScript("OnEnter", nil)
            local shown = 0
            for _, c in ipairs(blk.core) do
                local id, cpm = c[1], c[2]
                local name, icon = spellInfo(id)
                -- 未习得的不再隐藏(AI 解读会提到它们,藏了对不上)：灰显+「未习得」标注。
                -- 但 CD/情景档(<1/分)的未习得多是饰品/种族杂讯,仍隐藏。
                local have = known(id)
                if name and icon and (have or cpm >= 1) and shown < 10 then
                    shown = shown + 1
                    local row = getRow(19)
                    row._spell = id
                    if have then
                        local color = cpm >= 2 and "FFD100" or (cpm >= 1 and "FFFFFF" or "999999")
                        local tag = cpm >= 2 and T("ROT_TIER_CORE", "核心") or (cpm >= 1 and T("ROT_TIER_OFTEN", "常用") or T("ROT_TIER_CD", "CD/情景"))
                        local mine = myCpm(id, name)
                        local myStr = mine and string.format("   |cFF%s%s %.1f%s|r",
                            ratioColor(mine, cpm), T("ROT_MY", "你:"), mine, T("ROT_PERMIN", "次/分钟")) or ""
                        row.txt:SetText(string.format("  |T%d:16|t %s  |cFF%s%.1f%s · %s|r%s",
                            icon, name, color, cpm, T("ROT_PERMIN", "次/分钟"), tag, myStr))
                    else
                        row._tipLine = T("ROT_TT_NOT_KNOWN", "顶尖玩家在用、但你未习得——多半是没选这个天赋（可用「WCL天赋库」一键抄）；也可能是饰品技能。")
                        row.txt:SetText(string.format("  |T%d:16|t |cFF777777%s  %.1f%s · %s|r",
                            icon, name, cpm, T("ROT_PERMIN", "次/分钟"), T("ROT_NOT_KNOWN", "未习得")))
                    end
                end
            end
        end

        -- ── 3. BUFF 盯防：主动维持(你按出来的,低了=操作短板) / 被动触发(装备/天赋proc,参考即可) ──
        if blk.watch and #blk.watch > 0 then
            local act, pas = {}, {}
            for _, w in ipairs(blk.watch) do
                local name, icon = spellInfo(w[1])
                if name and icon then
                    local grp = (known(w[1]) and not passive(w[1])) and act or pas
                    grp[#grp + 1] = { w[1], w[2], name, icon }
                end
            end
            if #act > 0 then
                local hdr = getRow(20)
                hdr.txt:SetText(string.format("|cFFFFD100%s|r  |cFF999999%s|r",
                    T("ROT_WATCH", "BUFF 盯防"), T("ROT_WATCH_SUB", "主动维持·顶尖玩家的覆盖率，你低于它=操作短板")))
                hdr:SetScript("OnEnter", nil)
                for i, w in ipairs(act) do
                    if i > 6 then break end
                    local row = getRow(19)
                    row._spell = w[1]
                    -- 主动技能游戏 tooltip 已有完整说明，不加 AI note（避免重复+基础等级数值误导）
                    row._tipLine = string.format(T("ROT_TT_ACTIVE", "主动维持：顶尖玩家覆盖率 %d%%。你的覆盖率低于这个 = 操作短板，优先练。"), w[2])
                    local color = w[2] >= 70 and "FFD100" or "FFFFFF"
                    local mine = myUp(w[1], w[3])
                    local myStr = mine and string.format("   |cFF%s%s %.0f%%|r",
                        ratioColor(mine, w[2]), T("ROT_MY", "你:"), mine) or ""
                    row.txt:SetText(string.format("  |T%d:16|t %s  |cFF%s%.0f%%|r%s", w[4], w[3], color, w[2], myStr))
                end
            end
            if #pas > 0 then
                -- 被动组默认折叠：自动生效无需操作，唯一有用的信息是"你有没有"——展开后逐行标记。
                GearInsightDB = GearInsightDB or {}
                local folded = GearInsightDB.rotPassiveOpen ~= true
                local hdr = getRow(20)
                hdr.txt:SetText(string.format("|cFF999999%s %s · %s · %s|r",
                    folded and "+" or "-",
                    T("ROT_WATCH_PASSIVE", "被动触发（自动生效，无需操作）"),
                    string.format(T("ROT_PASSIVE_COUNT", "%d 项"), #pas),
                    folded and T("ROT_FOLD_OPEN", "点击展开") or T("ROT_FOLD_CLOSE", "点击收起")))
                hdr:SetScript("OnClick", function()
                    GearInsightDB.rotPassiveOpen = folded; render()
                end)
                hdr:SetScript("OnEnter", nil)
                if not folded then
                    for i, w in ipairs(pas) do
                        local row = getRow(19)
                        row._spell = w[1]
                        -- "已有"判定：天赋已知 或 实战中在你身上触发过（buff 光环 ID 常 ≠ 天赋技能 ID，
                        -- IsPlayerSpell 会漏判——用 CombatStats 实测兜底）
                        local seen = myOn and (myUp(w[1], w[3]) or 0) > 0
                        local have = known(w[1]) or seen
                        local mark
                        if have then
                            mark = "|TInterface\\RaidFrame\\ReadyCheck-Ready:12|t|cFF55E055" .. T("ROT_HAVE", "已有") .. "|r"
                        elseif myOn then
                            mark = "|cFF888888" .. T("ROT_HAVE_NOT", "未检测到") .. "|r"
                        else
                            mark = ""
                        end
                        local note = noteOf(w[1])
                        -- 来源优先用确定性反查结果（天赋「X」/装备「Y」），查不到才用通用文案
                        local srcT = GearInsightRotation and GearInsightRotation.sources
                            and GearInsightRotation.sources[w[1]]
                        local srcLine
                        if srcT then
                            local srcName
                            if srcT.t == "talent" then
                                -- 同名天赋：用客户端本地化的技能名，避免英文天赋名
                                srcName = string.format(T("ROT_SRC_TALENT", "天赋「%s」"), (spellInfo(w[1])) or "?")
                            else
                                srcName = _zhC and srcT.cn or (srcT.en or srcT.cn)
                            end
                            srcLine = string.format(T("ROT_TT_SOURCE", "来源：%s · 自动生效，无需操作"), srcName)
                        else
                            srcLine = have
                                and T("ROT_TT_PASSIVE_TALENT", "来源：天赋/装备被动 · 你已拥有，自动生效，无需操作")
                                or T("ROT_TT_PASSIVE_GEAR", "来源：装备/饰品特效或未选天赋 · 顶尖玩家有对应装备/天赋才触发")
                        end
                        row._tipLine = (note and (note .. "\n") or "") .. srcLine
                        row.txt:SetText(string.format("  |T%d:16|t |cFFAAAAAA%s  %.0f%%|r  %s", w[4], w[3], w[2], mark))
                    end
                end
            end
        end

        -- AI 教练引流：游戏内是群体基准，"对照你个人实战数据"的 AI 在小程序/网站
        -- ⚠️ 暂时隐藏：等小程序完成备案后取消注释恢复（2026-06-05 用户指示）
        --[[
        local funnel = getRow(18)
        funnel.txt:SetText("|cFFE8A23D" .. T("ROT_AI_FUNNEL",
            "想让 AI 对照你的实战数据？「导出装备」→ gearinsight.app/wow/en/analyze → AI 教练") .. "|r")
        funnel:SetScript("OnEnter", nil)
        grow(funnel)
        ]]

        -- 脚注
        local foot = getRow(18)
        foot.txt:SetText("|cFF888888" .. string.format(T("ROT_FOOT", "样本：%d 名 WCL 顶尖玩家 · 灰色=你未习得（饰品/异族种族技能/未选天赋）"), blk.n or 0) .. "|r")
        foot:SetScript("OnEnter", nil)
        grow(foot)

        f:SetHeight(math.max(180, -y + 20))
    end
    render()
    if GearInsight.Skin then GearInsight.Skin.Sweep(f) end
    f:Show()
end

-- ── Gems & enchants section ─────────────────────────────────────────
-- Renders recommended gems (item IDs → live icon+name) and enchants
-- (enchant IDs → usage only; the client has no name API for enchants, so we
-- show the baked Chinese name when present, else a "(见攻略)" placeholder).
-- Appends into self._scrollChild starting at yOff; returns the new yOff.
function GearInsight:_renderGemsEnchants(data, yOff)
    local sc = self._scrollChild
    if not sc then return yOff end

    -- Always hide previously-shown gem/enchant widgets first, so a spec with no
    -- data (or fewer rows) doesn't leave stale text behind.
    local function hideAll()
        if self._geRows then for _, fs in pairs(self._geRows) do fs:Hide() end end
        if self._geGemBtns then for _, b in ipairs(self._geGemBtns) do b:Hide() end end
        if self._geConsBtns then for _, b in pairs(self._geConsBtns) do b:Hide() end end
        if self._geEnchBtns then for _, b in pairs(self._geEnchBtns) do b:Hide() end end
    end
    hideAll()

    local gems = data and data.gems
    local enchants = data and data.enchants
    if (not gems or #gems == 0) and (not enchants or next(enchants) == nil) then
        return yOff
    end

    local L = self.L or {}
    local gr = self.GearReader
    self._geRows = self._geRows or {}
    self._geGemBtns = self._geGemBtns or {}
    self._geConsBtns = self._geConsBtns or {}
    self._geEnchBtns = self._geEnchBtns or {}
    local rows = self._geRows

    -- Reusable single-line FontString row helper.
    local function fsRow(key, template)
        local fs = rows[key]
        if not fs then
            fs = sc:CreateFontString(nil, "OVERLAY", template or "GameFontNormal")
            rows[key] = fs
        end
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", 6, yOff)
        fs:SetWidth(456)
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(false)  -- these are fixed-height single-line rows; wrapping overlaps the next row
        fs:Show()
        return fs
    end

    -- Preload gem item data so icons/names resolve.
    if gems then
        for _, g in ipairs(gems) do preloadItem(g.id) end
    end

    -- Section header.
    do
        local hdr = fsRow("_geHeader", "GameFontNormalLarge")
        hdr:SetText(T("SECTION_GEMS_ENCH", "推荐宝石与附魔"))
        hdr:SetTextColor(0.6, 0.85, 1)
        yOff = yOff - 24
    end

    -- ── Gems ──
    if gems and #gems > 0 then
        local lbl = fsRow("_geGemLabel", "GameFontHighlightSmall")
        lbl:SetText(T("GEMS_LABEL", "宝石（按使用率）："))
        lbl:SetTextColor(0.8, 0.8, 0.8)
        yOff = yOff - 18

        -- Horizontal strip of icon buttons; up to 6.
        local MAX_GEMS = 6
        local x = 14
        local rowTop = yOff
        local maxShown = math.min(#gems, MAX_GEMS)
        for i = 1, maxShown do
            local g = gems[i]
            local btn = self._geGemBtns[i]
            if not btn then
                btn = CreateFrame("Button", nil, sc)
                btn:SetSize(24, 24)
                btn.texture = btn:CreateTexture(nil, "ARTWORK")
                btn.texture:SetAllPoints()
                btn.itemID = nil; btn.itemLink = nil; btn.currentItemID = nil
                btn._pct = btn:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
                btn._pct:SetPoint("LEFT", btn, "RIGHT", 2, 0)
                btn._pct:SetJustifyH("LEFT")
                btn:SetScript("OnEnter", function(s)
                    if not s.itemID then return end
                    GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
                    if s.itemLink then GameTooltip:SetHyperlink(s.itemLink)
                    else GameTooltip:SetItemByID(s.itemID) end
                    if s._usage then
                        GameTooltip:AddLine(T("GE_USAGE_PREFIX", "顶尖使用率: ") .. s._usage .. "%", 0.2, 1, 0.2)
                    end
                    GameTooltip:Show()
                end)
                btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
                self._geGemBtns[i] = btn
            end
            setItemForIcon(btn, g.id, nil)
            btn._usage = g.usagePct
            -- Gem name shows in the hover tooltip (via item link); the strip itself
            -- only needs the usage %. Baked nameCn is the offline fallback.
            btn._pct:SetText(string.format("%.0f%%", g.usagePct or 0))
            btn._pct:SetTextColor(0.55, 0.85, 0.55)
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", sc, "TOPLEFT", x, rowTop)
            btn:Show()
            -- Advance x by icon + pct text width estimate.
            local pctW = btn._pct:GetStringWidth() or 26
            x = x + 24 + 4 + pctW + 14
            -- Wrap to a new line if running past panel width.
            if x > 440 and i < maxShown then
                x = 14
                rowTop = rowTop - 28
            end
        end
        -- Hide unused gem buttons.
        for i = maxShown + 1, #self._geGemBtns do
            self._geGemBtns[i]:Hide()
        end
        yOff = rowTop - 30
    end

    -- ── Enchants ──
    if enchants and next(enchants) ~= nil then
        local lbl = fsRow("_geEnchLabel", "GameFontHighlightSmall")
        lbl:SetText(T("ENCH_LABEL", "附魔（按部位）："))
        lbl:SetTextColor(0.8, 0.8, 0.8)
        yOff = yOff - 18

        -- Live icon for an enchant: prefer its spell texture (most accurate), then a
        -- recipe itemId, then the baked icon name; "" if none resolves.
        local function enchIcon(e)
            if e.spell and C_Spell and C_Spell.GetSpellTexture then
                local t = C_Spell.GetSpellTexture(e.spell)
                if t and t ~= 0 then return "|T" .. t .. ":14:14|t " end
            end
            if e.item and C_Item and C_Item.GetItemIconByID then
                local t = C_Item.GetItemIconByID(e.item)
                if t and t ~= 0 then return "|T" .. t .. ":14:14|t " end
            end
            if e.icon and e.icon ~= "" then return "|TInterface\\Icons\\" .. e.icon .. ":14:14|t " end
            return ""
        end
        -- Push one enchant's real tooltip (spell or recipe item) into GameTooltip.
        local function enchTip(e)
            if e.spell and GameTooltip.SetSpellByID then GameTooltip:SetSpellByID(e.spell); return true end
            if e.item and GameTooltip.SetItemByID then GameTooltip:SetItemByID(e.item); return true end
            return false
        end

        -- Stable slot order.
        local SLOT_ORDER = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17 }
        local idx = 0
        for _, slotId in ipairs(SLOT_ORDER) do
            local choices = enchants[slotId]
            if choices and #choices > 0 then
                idx = idx + 1
                local fs = fsRow("_geEnch" .. idx, "GameFontNormalSmall")
                local slotKey = gr and gr:GetSlotKey(slotId) or nil
                local slotName = (slotKey and L[slotKey]) or ("SLOT#" .. slotId)
                -- Top choice + its usage; the baked Chinese name is usually empty,
                -- so fall back to a "(see guide)" placeholder rather than fabricating.
                local top = choices[1]
                local ename = (top.nameCn and top.nameCn ~= "" and top.nameCn) or T("ENCH_SEE_GUIDE", "(见攻略)")
                local pct = string.format("%.0f%%", top.usagePct or 0)
                local line = "· " .. slotName .. " — " .. enchIcon(top) .. ename .. "  |cFF8CD98C" .. pct .. "|r"
                -- Show a runner-up if a clearly distinct second option exists.
                local alt = (choices[2] and (choices[2].usagePct or 0) >= 15) and choices[2] or nil
                if alt then
                    local altName = (alt.nameCn and alt.nameCn ~= "" and alt.nameCn) or T("ENCH_SEE_GUIDE", "(见攻略)")
                    line = line .. "  |cFF888888/ " .. enchIcon(alt) .. altName .. " " .. string.format("%.0f%%", alt.usagePct or 0) .. "|r"
                end
                fs:SetText(line)
                fs:SetTextColor(0.85, 0.85, 0.85)

                -- Transparent overlay for hover tooltips (top, and alt if shown).
                local eb = self._geEnchBtns[idx]
                if not eb then
                    eb = CreateFrame("Button", nil, sc)
                    self._geEnchBtns[idx] = eb
                end
                eb._top, eb._alt, eb._ename = top, alt, ename
                eb:RegisterForClicks("LeftButtonUp")
                eb:SetScript("OnEnter", function(s)
                    GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
                    if s._top and (s._top.spell or s._top.item) then
                        enchTip(s._top)
                        if s._alt and (s._alt.spell or s._alt.item) then
                            GameTooltip:AddLine(" ")
                            GameTooltip:AddLine(T("ENCH_ALT_TT", "次选："), 0.6, 0.6, 0.6)
                            local an = (s._alt.nameCn and s._alt.nameCn ~= "" and s._alt.nameCn) or ""
                            if an ~= "" then GameTooltip:AddLine(an, 0.8, 0.8, 0.8) end
                        end
                        GameTooltip:AddLine(" ")
                    end
                    GameTooltip:AddLine(T("ENCH_COPY_TT", "点击复制名字 → 到拍卖行搜索购买"), 1, 0.82, 0)
                    GameTooltip:Show()
                end)
                eb:SetScript("OnLeave", function() GameTooltip:Hide() end)
                eb:SetScript("OnClick", function(s)
                    local n = s._ename or ""
                    if n ~= "" then
                        GearInsight:ShowCopyText(n, string.format(T("CONS_COPY_HINT", "Ctrl+C 复制「%s」，到拍卖行搜索框粘贴购买"), n))
                    end
                end)
                eb:ClearAllPoints(); eb:SetPoint("TOPLEFT", 6, yOff); eb:SetSize(456, 15); eb:Show()
                yOff = yOff - 16
            end
        end
        -- Hide stale enchant rows from a previous (longer) spec render.
        local n = idx + 1
        while rows["_geEnch" .. n] do
            rows["_geEnch" .. n]:Hide()
            if self._geEnchBtns[n] then self._geEnchBtns[n]:Hide() end
            n = n + 1
        end
    end

    -- ── Consumables (shared across specs; from BisData.consumables) ──
    local cons = self.BisData and self.BisData.consumables
    if cons and #cons > 0 then
        local STAT_CN = { crit = "暴击", haste = "急速", mastery = "精通", versatility = "全能" }
        local worstKey = self._worstStatKey

        -- Per-spec / per-scenario flask usage (from WCL top logs; BisData.consumableUsage,
        -- keyed by 2-part CLASS/SPEC). Lets us rank flasks by real meta usage and show %.
        local scen = (self._statMode == "mplusHigh" and "mplusHigh")
            or (self._statMode == "mplusFarm" and "mplusFarm") or "raid"
        local SCEN_CN = { raid = T("SCEN_RAID", "团本"), mplusHigh = T("SCEN_MH", "大秘境高层"), mplusFarm = T("SCEN_MF", "大秘境割草") }
        local usageKey = (data and data.className and data.specName)
            and (data.className .. "/" .. data.specName) or nil
        local cu = self.BisData and self.BisData.consumableUsage
        local urow = (cu and usageKey and cu[usageKey] and cu[usageKey][scen]) or nil
        local pu = self.BisData and self.BisData.potionUsage
        local purow = (pu and usageKey and pu[usageKey] and pu[usageKey][scen]) or nil
        -- Per-row usage%: flasks by stat (urow), food by tier (urow.foodHearty/WellFed),
        -- potions by name (purow). 食物单道菜无法区分(共用 buff)，仅分高级/普通两档。
        local function rowPct(c)
            if c.stat and urow then return urow[c.stat] end
            if c.category == "食物" and urow then
                return (c.tier == "hearty") and urow.foodHearty or urow.foodWellFed
            end
            if purow then return purow[c.name] end
            return nil
        end

        local lbl = fsRow("_geConsLabel", "GameFontHighlightSmall")
        -- Single line only: a wrapping label would overlap the rows below it (only one
        -- line's height is reserved), hiding the first flasks' icons. Keep text short.
        lbl:SetWordWrap(false)
        if urow and (urow.n or 0) > 0 then
            lbl:SetText(string.format(T("CONS_LABEL_USAGE", "消耗品（合剂/药水使用率：%s·%d样本 · 点击复制名）"),
                SCEN_CN[scen] or scen, urow.n or 0))
        else
            lbl:SetText(T("CONS_LABEL", "消耗品（点击行复制名字去AH买）"))
        end
        lbl:SetTextColor(0.8, 0.8, 0.8)
        yOff = yOff - 18

        -- Group by category, preserving first-seen order.
        local order, byCat = {}, {}
        for _, c in ipairs(cons) do
            if not byCat[c.category] then byCat[c.category] = {}; order[#order + 1] = c.category end
            table.insert(byCat[c.category], c)
        end
        -- Rank flasks/potions by the current spec/scenario usage so the meta pick floats up.
        if urow or purow then
            for _, cat in ipairs(order) do
                table.sort(byCat[cat], function(a, b)
                    return (rowPct(a) or -1) > (rowPct(b) or -1)
                end)
            end
        end
        -- 药水低使用率兜底：最高使用率 <10% 时按行百分比不具参考性（多为 0% 凑数），
        -- 隐藏百分比并在分类头下注一行灰字说明，避免「最高才5%」式误导。
        local potionLow = false
        if byCat["药水"] then
            local maxp = 0
            for _, c in ipairs(byCat["药水"]) do
                local p = purow and purow[c.name]
                if p and p > maxp then maxp = p end
            end
            potionLow = (maxp < 10)
        end
        local ci = 0   -- FontString row index (category headers + item rows)
        local bi = 0   -- clickable copy-button index (item rows only)
        for _, cat in ipairs(order) do
            -- 食物按 tier 分组：盛宴 → 大师级单人(single_main) → 高级单人(single)
            local feast, single_main, single_items = {}, {}, {}
            if cat == "食物" then
                for _, c in ipairs(byCat[cat]) do
                    if c.tier == "single_main" then single_main[#single_main+1] = c
                    elseif c.tier == "single" then single_items[#single_items+1] = c
                    else feast[#feast+1] = c end
                end
            end
            local subgroups = (cat == "食物")
                and { { T("FOOD_GRP_FEAST","盛宴"), feast, urow and urow.food },
                      { T("FOOD_GRP_MAIN","大师级单人"), single_main, nil },
                      { T("FOOD_GRP_SINGLE","高级单人"), single_items, nil } }
                or { { cat, byCat[cat], (cat=="符文" and urow and urow.rune) } }

            -- Category header.
            ci = ci + 1
            local hfs = fsRow("_geCons" .. ci, "GameFontNormalSmall")
            local catExtra = ""
            if urow then
                if cat == "食物" and urow.food then catExtra = string.format("  |cFF888888(%.0f%% 上Buff)|r", urow.food)
                elseif cat == "符文" and urow.rune then catExtra = string.format("  |cFF888888(%.0f%%)|r", urow.rune) end
            end
            hfs:SetText("|cFFE8A23D【" .. cat .. "】|r" .. catExtra)
            hfs:SetTextColor(0.9, 0.64, 0.24)
            yOff = yOff - 16

            -- 药水低使用率说明行（潜伏条件见 potionLow 计算处）
            if cat == "药水" and potionLow then
                ci = ci + 1
                local nfs = fsRow("_geCons" .. ci, "GameFontHighlightSmall")
                nfs:SetText("  |cFF888888" .. T("POTION_LOW_NOTE", "该专精顶尖玩家战斗药水使用率低，按属性/需求自选即可") .. "|r")
                nfs:SetTextColor(0.55, 0.55, 0.55)
                yOff = yOff - 14
            end

            for _, sg in ipairs(subgroups) do
                local sgLabel, sgItems, sgPct = sg[1], sg[2], sg[3]
                if #sgItems > 0 then
                -- sub-header (盛宴/大师级单人/高级单人) only when food has multiple sub-groups
                if cat == "食物" then
                    ci = ci + 1
                    local shfs = fsRow("_geCons" .. ci, "GameFontNormalSmall")
                    local sgExtra = sgPct and string.format("  |cFF888888(%.0f%% 上Buff)|r", sgPct) or ""
                    shfs:SetText("  |cFFB0B0B0" .. sgLabel .. sgExtra .. "|r")
                    shfs:SetTextColor(0.7, 0.7, 0.7); yOff = yOff - 14
                end
                for _, c in ipairs(sgItems) do
                ci = ci + 1
                local fs = fsRow("_geCons" .. ci, "GameFontNormalSmall")
                -- Prefer the live item icon by itemId (always valid); some baked icon NAMES
                -- don't exist on this client and render blank. Fall back to the icon name.
                local iconTex = c.itemId and C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(c.itemId)
                local ic
                if iconTex and iconTex ~= 0 then ic = "|T" .. iconTex .. ":14:14|t "
                elseif c.icon and c.icon ~= "" then ic = "|TInterface\\Icons\\" .. c.icon .. ":14:14|t "
                else ic = "" end
                -- Usage% — flasks by stat, potions by name (see rowPct).
                -- 药水低使用率时按行%不显示（多为 0%/5% 凑数，见 potionLow 说明行）。
                local pct = rowPct(c)
                if cat == "药水" and potionLow then pct = nil end
                local useTag = pct and string.format("  |cFFFFD100%.0f%%|r", pct) or ""
                -- Flag the flask matching the most-needed core stat: bright gold text + green
                -- "(补X)" tag (no leading glyph, so every row's icon stays column-aligned).
                local isMatch = (worstKey and c.stat == worstKey)
                local statTag = (c.stat and STAT_CN[c.stat]) and (" |cFF66BBFF[" .. STAT_CN[c.stat] .. "]|r") or ""
                if isMatch then statTag = statTag .. " |cFF33FF66(补" .. STAT_CN[c.stat] .. ")|r" end
                -- 食物高级档(Hearty/丰盛)= meta：金色高亮 + "(主流)"，与合剂"(补X)"一致。
                local isHeartyMeta = (c.category == "食物" and c.tier == "hearty")
                if isHeartyMeta then statTag = statTag .. " |cFF33FF66" .. T("CONS_FOOD_META", "(主流)") .. "|r" end
                fs:SetText("    " .. ic .. (c.name or "") .. statTag .. useTag)
                if isMatch or isHeartyMeta then fs:SetTextColor(1, 0.95, 0.4) else fs:SetTextColor(0.85, 0.85, 0.85) end

                -- Clickable overlay: copy the consumable name to paste into the Auction House.
                bi = bi + 1
                local cb = self._geConsBtns[bi]
                if not cb then
                    cb = CreateFrame("Button", nil, sc)
                    cb:RegisterForClicks("LeftButtonUp")
                    cb:SetScript("OnEnter", function(s)
                        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
                        -- With an itemId, show the real item tooltip (effect/stats); otherwise
                        -- just the copy hint. Always append the click-to-copy line.
                        if s._itemId then
                            GameTooltip:SetItemByID(s._itemId)
                            GameTooltip:AddLine(" ")
                            GameTooltip:AddLine(T("CONS_COPY_TT", "点击复制名字 → 到拍卖行搜索购买"), 1, 0.82, 0)
                        else
                            GameTooltip:SetText(T("CONS_COPY_TT", "点击复制名字 → 到拍卖行搜索购买"), 1, 0.82, 0)
                        end
                        GameTooltip:Show()
                    end)
                    cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
                    cb:SetScript("OnClick", function(s)
                        GearInsight:ShowCopyText(s._cname,
                            string.format(T("CONS_COPY_HINT", "Ctrl+C 复制「%s」，到拍卖行搜索框粘贴购买"), s._cname or ""))
                    end)
                    self._geConsBtns[bi] = cb
                end
                cb._cname = c.name
                cb._itemId = c.itemId
                cb:ClearAllPoints()
                cb:SetPoint("TOPLEFT", 6, yOff)
                cb:SetSize(456, 15)
                cb:Show()
                yOff = yOff - 16
                end  -- for _, c in ipairs(sgItems)
                end  -- if #sgItems > 0
            end  -- for _, sg in ipairs(subgroups)
        end  -- for _, cat in ipairs(order)
        -- Hide stale consumable rows.
        local n = ci + 1
        while rows["_geCons" .. n] do
            rows["_geCons" .. n]:Hide()
            n = n + 1
        end
    end

    yOff = yOff - 6
    return yOff
end

-- Main-panel mini section: the 2 crafted-gear slots most worth making, ranked
-- by each item's own WCL usage % in its slot (结合 BiS：只有槶位真是制造件当
-- BiS 时才会出现，不是"随便挑2件制造装"). Same ranking as the farming guide's
-- crafted group (GetTopCraftedPicks), just surfaced without opening a popup.
function GearInsight:_renderCraftedPicks(class, spec, heroTalent, yOff)
    local sc = self._scrollChild
    if not sc then return yOff end

    self._cpRows = self._cpRows or {}
    local function hideAll()
        for _, r in ipairs(self._cpRows) do r:Hide() end
        if self._cpHeader then self._cpHeader:Hide() end
    end

    local is2H = self:_detectIs2H()
    local picks = self:GetTopCraftedPicks(class, spec, heroTalent, is2H, 2)
    if not picks or #picks == 0 then
        hideAll()
        return yOff
    end

    local L = self.L or {}
    local gr = self.GearReader

    if not self._cpHeader then
        self._cpHeader = sc:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        self._cpHeader:SetWidth(456)
        self._cpHeader:SetJustifyH("LEFT")
    end
    self._cpHeader:ClearAllPoints()
    self._cpHeader:SetPoint("TOPLEFT", 6, yOff)
    self._cpHeader:SetText(T("SECTION_CRAFTED_PICKS", "制造推荐（结合BiS）"))
    self._cpHeader:SetTextColor(0.2, 1, 0.2)
    self._cpHeader:Show()
    yOff = yOff - 24

    for i, pick in ipairs(picks) do
        local row = self._cpRows[i]
        if not row then
            row = CreateFrame("Button", nil, sc)
            row:SetSize(456, 24)
            row:RegisterForClicks("LeftButtonUp")
            row.icon = CreateFrame("Frame", nil, row)
            row.icon:SetSize(20, 20)
            row.icon:SetPoint("LEFT", 0, 0)
            row.icon.texture = row.icon:CreateTexture(nil, "ARTWORK")
            row.icon.texture:SetAllPoints()
            row.text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.text:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
            row.text:SetPoint("RIGHT", -4, 0)
            row.text:SetJustifyH("LEFT")
            row.text:SetWordWrap(false)
            row:SetScript("OnEnter", function(s)
                GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
                if s.icon.itemLink then GameTooltip:SetHyperlink(s.icon.itemLink)
                elseif s.icon.itemID then GameTooltip:SetItemByID(s.icon.itemID) end
                if s._usage then
                    GameTooltip:AddLine(T("GE_USAGE_PREFIX", "顶尖使用率: ") .. s._usage .. "%", 0.2, 1, 0.2)
                end
                GameTooltip:Show()
            end)
            row:SetScript("OnLeave", function() GameTooltip:Hide() end)
            row:SetScript("OnClick", function(s)
                if self._tryChatLink then self._tryChatLink(s.icon) end
            end)
            self._cpRows[i] = row
        end
        -- setItemForIcon expects a button-shaped widget (.texture + .itemID/.itemLink).
        setItemForIcon(row.icon, pick.item.itemId, pick.item.bonusIDs, pick.item.link)
        row._usage = pick.item.usagePct and string.format("%.0f", pick.item.usagePct) or nil
        local slotKey = gr and gr:GetSlotKey(pick.slotId) or nil
        local slotName = (slotKey and L[slotKey]) or ("SLOT#" .. pick.slotId)
        local iName = locName(pick.item.itemId, pick.item.itemName) or ("#" .. pick.item.itemId)
        local usageTxt = pick.item.usagePct and string.format("  |cFF55E055%.0f%%|r", pick.item.usagePct) or ""
        row.text:SetText(slotName .. ": " .. iName .. "  [" .. (pick.item.ilvl or 0) .. "]" .. usageTxt)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", sc, "TOPLEFT", 2, yOff)
        row:Show()
        yOff = yOff - 24
    end
    for i = #picks + 1, #self._cpRows do
        self._cpRows[i]:Hide()
    end

    yOff = yOff - 6
    return yOff
end

-- ── Panel: refresh ──────────────────────────────────────────────────
function GearInsight:RefreshPanel()
    if not self._panelFrame or not self._upgradeRows or not self._scrollChild then
        return
    end
    -- Lazy widget creation (CreateFrame calls for consumable buttons, gem buttons, etc.)
    -- is blocked in combat lockdown and would cause mass LUA errors. Skip the full
    -- re-render during combat; the data stays visible as-is until combat ends.
    if InCombatLockdown and InCombatLockdown() then return end

    local L = self.L or {}
    local snapshot = self.SavedVars and self.SavedVars:GetLastSnapshot() or nil
    local class, spec, htal, ilvl
    if snapshot then
        class = snapshot.class; spec = snapshot.spec; htal = snapshot.heroTalent
        ilvl = math.floor((snapshot.itemLevel or snapshot.averageItemLevel or 0) + 0.5)
    end
    if not class or not spec then
        if self.StatReader then
            local s = self.StatReader:ReadAll()
            class = s.class; spec = s.spec; htal = s.heroTalent
        end
    end

    local data = self.BisData and self.BisData:GetSpecData(class, spec, htal)
    local tIlvl = data and data.graduationItemLevel or 0

    -- Decide whether to use live Companion recommendations or static BiS data
    local usingLiveRecs = false
    local liveBisBySlot = nil
    if self.RecsReader and self.RecsReader:HasFreshRecs() then
        liveBisBySlot = self.RecsReader:GetBisBySlot()
        if liveBisBySlot then
            usingLiveRecs = true
        end
    end

    -- Choose the bisBySlot source for the upgrade panel
    local activeBisBySlot = usingLiveRecs and liveBisBySlot or (data and data.bisBySlot)

    -- Preload item icons/names for whichever source we'll display
    if activeBisBySlot then
        for _, items in pairs(activeBisBySlot) do
            for _, entry in ipairs(items) do
                preloadItem(entry.itemId)
            end
        end
    end

    -- ── Overview ──────────────────────────────────────────────────
    if self._ovSpec then
        local cn, sn = getLocalizedClassSpec()
        local sk = string.format("%s %s", cn or class or "?", sn or spec or "?")
        if htal then sk = sk .. " (" .. htal .. ")" end
        self._ovSpec:SetText(T("OV_SPEC", "专精: ") .. sk)
    end
    if self._ovIlvl then
        self._ovIlvl:SetText(T("OV_ILVL", "当前装等: ") .. ilvl)
    end
    if self._ovGap then
        if tIlvl > 0 then
            -- ⛔ 别用 math.max(0, …) 把负数压成 0：装等超过毕业线时会显示「差距: 0」，
            --    看起来像「刚好毕业」，其实是超了（2026-08-26 用户反馈）。超了就明说超了。
            local diff = tIlvl - ilvl
            local gap = math.max(0, diff)
            local c = diff <= 0 and "|cFF00FF00" or "|cFFFF6600"
            -- 难度档非史诗时标注（装等已按档换算，见 core/TierView.lua）
            local tierTag = (self.GearTierStep and self:GearTierStep() > 0)
                and (" |cFF55BBFF[" .. self:GearTierLabel() .. T("TIER_TAG", "档") .. "]|r") or ""
            local gapText = (diff < 0)
                and (T("OV_OVER", "已超毕业线: ") .. c .. "+" .. (-diff) .. "|r")
                or  (T("OV_GAP", "差距: ") .. c .. gap .. "|r")
            -- #22（2026-08-31 抖音 西野已无恶：「毕业装等321是不是不太对？」）——
            -- 321 没错：它是当季团本史诗**掉落基准**（数据现算的众数），拿到手还能走
            -- 升级轨道到更高。错的是措辞没把「基准 vs 满轨」说清，这里补上。
            self._ovGap:SetText(T("OV_GRAD", "毕业基准: ") .. c .. tIlvl .. "|r" .. tierTag
                .. " |cff8a93a6" .. T("OV_GRAD_NOTE", "(顶尖玩家实穿口径)") .. "|r"
                .. "  " .. gapText)
        else
            self._ovGap:SetText(T("OV_NODATA", "暂无该专精的BiS数据"))
        end
    end

    -- Stat targets follow the 团本/大秘境 toggle; fall back to raid when the M+ set is absent.
    -- 3-way stat target source: raid / 大秘境高层(Mplus) / 大秘境割草(MplusFarm).
    -- Each M+ mode falls back to high, then raid, when its data is absent.
    local statPct = data and data.targetStatPercents
    local statRat = data and data.targetStatRatings
    if data then
        if self._statMode == "mplusHigh" then
            statPct = data.targetStatPercentsMplus or statPct
            statRat = data.targetStatRatingsMplus or statRat
        elseif self._statMode == "mplusFarm" then
            statPct = data.targetStatPercentsMplusFarm or data.targetStatPercentsMplus or statPct
            statRat = data.targetStatRatingsMplusFarm or data.targetStatRatingsMplus or statRat
        end
    end

    -- Stat priority + most-needed stat summary — 以"WCL 顶尖玩家属性占比 × 你的副属性总量"为目标
    -- (可达、与装等无关；不用 WCL 绝对评级，那受 proc 污染且跨装等不可比)。
    self._worstStatKey = nil
    if self._ovStatPri and data and (statRat or statPct) then
        local sNames = { crit = T("STAT_CRIT", "暴击"), haste = T("STAT_HASTE", "急速"), mastery = T("STAT_MASTERY", "精通"), versatility = T("STAT_VERS", "全能") }
        local sec = (snapshot and snapshot.secondary) or {}
        local secRating = (snapshot and snapshot.secondaryRating) or {}
        local ratingTotal = 0
        for _, statKey in ipairs({ "crit", "haste", "mastery", "versatility" }) do
            ratingTotal = ratingTotal + (secRating[statKey] or 0)
        end
        -- 目标评级 = WCL 平均(statRat)，回退 占比×你的总量。
        local function targetRatingOf(sk)
            if statRat and statRat[sk] then return statRat[sk] end
            if statPct and statPct[sk] and ratingTotal > 0 then
                return math.floor(statPct[sk] / 100 * ratingTotal + 0.5)
            end
            return 0
        end
        local tgt = {}
        local maxTgt = 0
        for _, sk in ipairs({ "crit", "haste", "mastery", "versatility" }) do
            tgt[sk] = targetRatingOf(sk)
            if tgt[sk] > maxTgt then maxTgt = tgt[sk] end
        end
        -- 优先级排序：按 WCL 平均评级从高到低（这就是该专精的属性主次）。
        local sorted = {}
        for _, sk in ipairs({ "crit", "haste", "mastery", "versatility" }) do
            sorted[#sorted + 1] = { key = sk, val = tgt[sk] }
        end
        table.sort(sorted, function(a, b) return a.val > b.val end)
        -- 最缺：核心属性里，相对 WCL 均值缺口比例最大的那个（评级 < 均值90%）。
        local worstName, worstRatio, worstKey = nil, 1, nil
        for sk, t in pairs(tgt) do
            local isCore = not (maxTgt > 0 and t < maxTgt * 0.30)
            if isCore and t > 0 then
                local ratio = (secRating[sk] or 0) / t
                if ratio < 0.9 and ratio < worstRatio then
                    worstRatio = ratio
                    worstName = sNames[sk] or sk
                    worstKey = sk
                end
            end
        end
        self._worstStatKey = worstKey
        local parts = {}
        for _, s in ipairs(sorted) do
            if s.val > 0 then parts[#parts + 1] = sNames[s.key] or s.key end
        end
        local summary = T("STAT_PRIORITY", "属性优先级: ") .. table.concat(parts, " > ")
        if worstName then
            summary = summary .. string.format(T("STAT_WORST_R", "  |  最缺: %s(%.0f%%达标)"), worstName, worstRatio * 100)
        else
            summary = summary .. T("STAT_OK", "  |  属性已达 WCL 均值")
        end
        self._ovStatPri:SetText(summary)
    end

    -- ── Stats: 对齐 WCL 顶尖玩家的"属性配比"(占比×你的总量，可达) ──
    -- 目标 = 顶尖玩家该属性的平均评级(statRat)。直接对比你的评级 vs 平均值：
    --   低于平均=不足(补)、约等于=达标、高于=超标。这才是"学 WCL 平均数"。
    -- 没有 statRat 时回退旧的"占比×你的总量"法。
    if self._statRows and data and (statRat or statPct) then
        local sec = (snapshot and snapshot.secondary) or {}
        local secRating = (snapshot and snapshot.secondaryRating) or {}
        local ratingTotal = 0
        for _, statKey in ipairs({ "crit", "haste", "mastery", "versatility" }) do
            ratingTotal = ratingTotal + (secRating[statKey] or 0)
        end
        -- 目标评级表：优先 statRat(绝对均值)，否则用 占比×你的总量。
        local function targetRatingOf(sk)
            if statRat and statRat[sk] then return statRat[sk] end
            if statPct and statPct[sk] and ratingTotal > 0 then
                return math.floor((statPct[sk]) / 100 * ratingTotal + 0.5)
            end
            return 0
        end
        local maxTgt = 0
        for _, sk in ipairs({ "crit", "haste", "mastery", "versatility" }) do
            local t = targetRatingOf(sk)
            if t > maxTgt then maxTgt = t end
        end
        for sk, sr in pairs(self._statRows) do
            local cur = sec[sk] or 0                       -- 面板效果%(显示用)
            local currentRating = secRating[sk] or 0       -- 你的评级
            local targetRating = targetRatingOf(sk)        -- WCL 平均评级
            if targetRating == 0 then
                sr.bar:SetValue(0)
                sr.val:SetText("-")
            else
                -- 目标占比很小的属性(如多数 DPS 的全能)算"非核心"，不报红。
                local isCore = not (maxTgt > 0 and targetRating < maxTgt * 0.30)
                local ratio = currentRating / targetRating
                sr.bar:SetValue(math.min(ratio, 1.25))
                local r, g, b, tag, tc, showGap, isOver
                if not isCore then
                    r, g, b = 0.55, 0.55, 0.55
                    tag = T("TAG_NONCORE", "非核心"); tc = "|cFF999999"; showGap = false
                elseif ratio < 0.9 then
                    r, g, b = 1, 0.2, 0.1
                    tag = T("TAG_LOW", "不足"); tc = "|cFFFF0000"; showGap = true
                elseif ratio < 1.0 then
                    r, g, b = 0.95, 0.75, 0.1
                    tag = T("TAG_TOL", "容差内"); tc = "|cFFFFFF00"; showGap = true
                elseif ratio <= 1.1 then
                    r, g, b = 0.2, 1, 0.1
                    tag = T("TAG_OK", "达标"); tc = "|cFF00FF00"; showGap = false; isOver = true
                else
                    r, g, b = 1, 0.6, 0.1
                    tag = T("TAG_OVER", "超标"); tc = "|cFFFF8800"; showGap = false; isOver = true
                end
                sr.bar:SetStatusBarColor(r, g, b, 0.9)
                local gapR = targetRating - currentRating
                local detail = ""
                if showGap and gapR > 0 then
                    detail = string.format(T("TAG_GAP_R2", " 缺%d"), gapR)
                elseif isOver and gapR < 0 then
                    detail = string.format(T("TAG_OVER_R2", " 多%d"), -gapR)
                end
                local pctText = (cur and cur > 0) and string.format("|cFFAAAAAA(%.1f%%)|r", cur) or ""
                sr.val:SetText(string.format("%s%d|r%s |cFF888888→|r%s%d %s%s%s|r",
                    tc, currentRating, pctText, T("LBL_TGT", "目标"), targetRating, tc, tag, detail))
                sr.val:SetWordWrap(false)
            end
        end
    end

    -- ── Upgrades (only actionable rows; completed BiS is summarized) ──
    local rowIdx = 0
    local completedCount = 0
    -- Graduated slots stay perceivable: collected here, rendered as a compact
    -- green section below the upgrade rows (each row keeps its 前5 popup).
    local completedSlots = {}
    -- Track what each paired slot ends up recommending so its sibling won't
    -- recommend the SAME item (you can't equip two of the same trinket/ring).
    -- Slots are processed ascending (13 before 14, 11 before 12), so the sibling
    -- recommendation is already known when we reach the second slot of the pair.
    local recommendedBySlot = {}
    local yOff = -4
    self._lastSlot = nil
    -- Reuse slot headers; hide old ones before repopulating
    self._slotHeaders = self._slotHeaders or {}
    for _, hdr in pairs(self._slotHeaders) do
        hdr:Hide()
    end
    if self._completedSummary then self._completedSummary:Hide() end
    if self._emptyUpgradeLabel then self._emptyUpgradeLabel:Hide() end
    if self._gradHeader then self._gradHeader:Hide() end

    -- 武器形态：优先玩家实戴形态，回退该专精当前场景的 meta 主流形态。
    -- 据此让主手(16)/副手(17)按形态耦合：双手/远程隐藏副手；各槽候选按手数过滤。
    local effWConf
    do
        local wScen = (self._statMode == "mplusHigh" and "mplusHigh")
            or (self._statMode == "mplusFarm" and "mplusFarm") or "raid"
        local wTbl = self.BisData and self.BisData.weaponConfig
        local wKey = data and data.className and data.specName and (data.className .. "/" .. data.specName)
        local wMeta = wTbl and wKey and wTbl[wKey] and wTbl[wKey][wScen]
        effWConf = _playerWeaponConfig(snapshot)
        if not effWConf and wMeta then
            local best, bestP = nil, -1
            for cfg, p in pairs(wMeta) do if p > bestP then best, bestP = cfg, p end end
            effWConf = best
        end
    end

    if activeBisBySlot and snapshot and snapshot.equipped then
        for slotId = 1, 17 do
            if slotId ~= 4 then
                local pairOther = PAIR_SLOT[slotId]
                local desiredRank = 1
                local cand = activeBisBySlot[slotId]
                if pairOther then
                    cand = _mergePairPool(activeBisBySlot[slotId], activeBisBySlot[pairOther])
                    if slotId == 12 or slotId == 14 then desiredRank = 2 end
                end
                -- 武器槽按形态耦合：双手/远程不出副手；主手/副手候选按手数过滤。
                if (slotId == 16 or slotId == 17) and effWConf then
                    if slotId == 17 and not WCONF_HASOFF[effWConf] then
                        cand = nil
                    elseif slotId == 16 then
                        cand = _filterByHand(cand, WCONF_MAINHAND[effWConf])
                    else
                        local want = WCONF_OFFHAND[effWConf]
                        cand = _filterByHand(cand, want, want == "offWeapon" and "1h" or nil)
                    end
                end
                if cand and #cand > 0 then
                    local eq = snapshot.equipped[slotId]
                    local slotKey = self.GearReader and self.GearReader:GetSlotKey(slotId) or nil
                    local slotLabel = (slotKey and L[slotKey]) or ("SLOT" .. slotId)
                    local cName = (eq and not eq.empty and locName(eq.itemId, eq.itemName)) or T("SLOT_EMPTY", "(空槽)")
                    local cIlvl = eq and eq.ilvl or 0
                    local cId   = eq and eq.itemId
                    local top = cand[desiredRank] or cand[1]

                    -- Per-slot graduation ilvl. The spec-wide graduationItemLevel (tIlvl)
                    -- is the armor floor (289); trinkets/weapons cap higher (298). Derive
                    -- the floor from THIS slot's own BiS candidates so we never graduate a
                    -- piece below its slot's real target (e.g. a 289 trinket vs 298, or the
                    -- reported 250 trinket). Armor/rings stay at 289 since their max == 289.
                    local slotGrad = tIlvl or 0
                    for _, e in ipairs(cand) do
                        if (e.ilvl or 0) > slotGrad then slotGrad = e.ilvl end
                    end

                    -- Paired slots want the pool's top-2 distinct items across both
                    -- slots. This slot is done if it already holds a top-2 item.
                    -- Otherwise recommend a top-2 item NOT already worn in the sibling
                    -- slot (you can't stack two of the same unique item).
                    local skipAsComplete = false
                    if pairOther then
                        local p1, p2 = cand[1], cand[2]
                        local id1 = p1 and p1.itemId
                        local id2 = p2 and p2.itemId
                        local otherEq = snapshot.equipped[pairOther]
                        local eqO = (otherEq and not otherEq.empty) and otherEq.itemId or nil
                        if cId and (cId == id1 or cId == id2) then
                            -- Holding the BiS piece only counts as done if it also
                            -- meets the item's own ilvl (or the slot's graduation floor) —
                            -- a low-ilvl copy (e.g. a 250 trinket vs its 298 target) still
                            -- needs upgrading.
                            local matched = (cId == id1) and p1 or p2
                            local mIlvl = (matched and matched.ilvl) or 0
                            if mIlvl == 0 or cIlvl >= mIlvl or (slotGrad > 0 and cIlvl >= slotGrad) then
                                skipAsComplete = true
                            else
                                -- recommend upgrading the held piece to its full-ilvl version
                                top = matched
                            end
                        else
                            -- An item is unusable for this slot if the sibling slot
                            -- already wears it, or was just recommended it — otherwise
                            -- both slots would suggest the same single pool item (e.g.
                            -- when raid is excluded and only one m+ trinket remains).
                            local recO = recommendedBySlot[pairOther]
                            -- 戒指(11/12)价值≈装等(副属性总量)，和护甲一样禁止降级推荐
                            -- (实证：276 团本BOE 在 M+ 参照系盖过身上 289 #3)；
                            -- 饰品(13/14)价值在特效，保留按使用率推荐低装等件。
                            local ringGuard = (slotId == 11 or slotId == 12)
                            local function usable(e)
                                if not e or e.itemId == eqO or e.itemId == recO then return false end
                                if ringGuard and cIlvl > 0 and (e.ilvl or 0) < cIlvl then return false end
                                return true
                            end
                            -- primary slot prefers #1, secondary prefers #2
                            local a, b = p1, p2
                            if slotId == 12 or slotId == 14 then a, b = p2, p1 end

                            -- 饰品尽量凑「一主动一被动」（2026-08-27 用户实证：奥法被推荐
                            -- 了两个主动饰品）。两个主动会抢同一个爆发窗口，收益重叠；
                            -- 数据里 onUse=true 表示「使用：」类。只在**池子里真的有**
                            -- 互补件时才换，换不到就维持原来的使用率顺序，不硬凑。
                            if slotId == 13 or slotId == 14 then
                                local otherUse
                                for _, e in ipairs(cand) do
                                    if e.itemId == (recO or eqO) then otherUse = e.onUse break end
                                end
                                if otherUse ~= nil and a and a.onUse == otherUse then
                                    for _, e in ipairs(cand) do
                                        if e.onUse ~= nil and e.onUse ~= otherUse and usable(e) then
                                            a = e
                                            break
                                        end
                                    end
                                end
                            end
                            if usable(a) then top = a
                            elseif usable(b) then top = b
                            else
                                -- 严判：前2不可用不再直接算毕业，顺延池子里下一个可用候选；
                                -- 整个池子都不可用才视为无目标（真·毕业）。
                                top = nil
                                for ci = 3, #cand do
                                    if usable(cand[ci]) then top = cand[ci]; break end
                                end
                                if not top then top = p1 or p2; skipAsComplete = true end
                            end
                        end
                    end

                    -- 非配对槽(护甲/武器=属性载体)的目标选择：
                    --  ① 身上这件是池内候选且不低于其数据装等 → 毕业，但护甲槽严判（2026-06-07
                    --     用户拍板）：必须是 #1 本身；#2+ 同装等照样推荐 #1。武器槽保留池内即毕业
                    --     （双手/主副手组合多，实证回归：主手穿 #1@298 被闸门顺延去推荐 #2@298）
                    --  ② 否则禁止降级推荐（实证：M+参照系 263/276 BOE 盖过身上 289），
                    --     顺延首个 ≥身上装等 的候选；武器槽还要排除另一只手已穿的同件
                    --     （实证回归：副手推荐了主手正穿着的盲目裁决之刃）
                    --  ③ 全池不达标但身上这件未满级 → 推荐升级它本身
                    --  ④ 整池都低于身上 → 超越列表，毕业
                    -- 饰品/戒指(配对槽)价值在特效，由上面的 pair 分支处理。
                    if not pairOther and cand and #cand > 0 then
                        local otherWeapEq
                        if slotId == 16 or slotId == 17 then
                            local o = snapshot.equipped[slotId == 16 and 17 or 16]
                            otherWeapEq = (o and not o.empty) and o.itemId or nil
                        end
                        local own
                        if cId then
                            for _, e in ipairs(cand) do
                                if e.itemId == cId then own = e; break end
                            end
                        end
                        local isWeapon = (slotId == 16 or slotId == 17)
                        if own and cIlvl >= (own.ilvl or 0) and (isWeapon or own == cand[1]) then
                            skipAsComplete = true
                        else
                            local pick
                            for _, e in ipairs(cand) do
                                if e.itemId ~= otherWeapEq and (cIlvl == 0 or (e.ilvl or 0) >= cIlvl) then
                                    pick = e; break
                                end
                            end
                            if pick then top = pick
                            elseif own then top = own
                            else skipAsComplete = true end
                        end
                    end

                    local topName = locName(top.itemId, top.itemName) or ("Item#" .. top.itemId)
                    -- 参照装等取**顶格**而不是采样到的那一件（用户 2026-08-28：
                    -- 「大秘境装备就没必要英雄了，毕业直接神话算」）。
                    -- top.mx = 该件在全数据集里实测见过的最高装等（神话轨顶格）；
                    -- 没有更高版本时数据侧不写 mx，退回 top.ilvl，行为与从前一致。
                    -- ⛔ 不用「英雄6/6 +N」的阶梯算术推 —— 实测档位不是等差，推出来是编的。
                    local topIlvl = top.mx or top.ilvl or 0
                    local dropSrc = top.source or ""
                    if dropSrc == "钥石宝箱" then dropSrc = "钥石宝箱（大秘境）" end

                    -- Determine rank of equipped item in BiS candidates
                    local rank = nil
                    for ri, entry in ipairs(cand) do
                        if entry.itemId == cId then rank = ri; break end
                    end

                    -- 严判（2026-06-05 用户拍板）：只有真正持有 BiS 件（达到其目标装等或专精
                    -- 毕业装等）才算毕业。旧的"装等超过推荐件即毕业"条款已移除——饰品/戒指的
                    -- 价值在特效与使用率，高装等的非 BiS 件不等于毕业（旌旗298≠丝带289）。
                    -- ⛔ 同一件装备只是**升级轨道**进度不同，不是「要换一件」（2026-08-27
                    --    玩家 筱小飞 反馈）：他把这件升到神话 1/6(318)，而数据里顶尖玩家
                    --    那件是英雄 6/6(321)，装等暂时更低但上限更高，插件却把它列进
                    --    「待提升」，等于建议他去换一件天花板更低的。身上就是这件 → 算持有，
                    --    差的那点装等改在已毕业组里标成「可升级 318 → 321」。
                    local sameItem = cId and cId == top.itemId
                    local isComplete = skipAsComplete
                        or (sameItem and (topIlvl == 0 or cIlvl >= topIlvl or (slotGrad > 0 and cIlvl >= slotGrad)))
                        or (sameItem and cIlvl > 0 and topIlvl > 0 and cIlvl < topIlvl)
                    if not isComplete then
                        recommendedBySlot[slotId] = top.itemId
                    end
                    if isComplete then
                        completedCount = completedCount + 1
                        completedSlots[#completedSlots + 1] = {
                            slotId = slotId,
                            label = slotLabel,
                            -- Paired slots pool both lists; title the popup without the number.
                            popupLabel = pairOther and (slotLabel:gsub("%s*%d+$", "")) or slotLabel,
                            cand = cand,
                            eqId = cId,
                            eqLink = eq and eq.itemLink or nil,
                            eqName = cName,
                            eqIlvl = cIlvl,
                            rank = rank,
                            -- 同一件但装等还没追上参照件 → 已持有、可继续升级轨道
                            upgradeTo = (sameItem and topIlvl > 0 and cIlvl < topIlvl) and topIlvl or nil,
                        }
                    else
                    rowIdx = rowIdx + 1
                    local row = self._upgradeRows[rowIdx]
                    if not row then
                        -- safety: create on demand (Button icons, sync+async)
                        row = CreateFrame("Frame", nil, self._scrollChild)
                        row:SetSize(456, 56); row:EnableMouse(true)
                        local cIB = CreateFrame("Button",nil,row); cIB:SetSize(48,48); cIB:SetPoint("TOPLEFT",2,-2)
                        cIB.texture=cIB:CreateTexture(nil,"ARTWORK"); cIB.texture:SetAllPoints(); cIB.itemID=nil;cIB.itemLink=nil;cIB.currentItemID=nil
                        cIB:SetScript("OnEnter",function(s) if s.itemID then GameTooltip:SetOwner(s,"ANCHOR_RIGHT") if s.itemLink then GameTooltip:SetHyperlink(s.itemLink) else GameTooltip:SetItemByID(s.itemID) end GameTooltip:Show() end end)
                        cIB:SetScript("OnLeave",function() GameTooltip:Hide() end)
                        local cT=row:CreateFontString(nil,"OVERLAY","GameFontNormal"); cT:SetPoint("LEFT",cIB,"RIGHT",4,0); cT:SetWidth(150); cT:SetJustifyH("LEFT"); cT:SetWordWrap(true)
                        local ar=row:CreateFontString(nil,"OVERLAY","GameFontNormalLarge"); ar:SetPoint("LEFT",cT,"RIGHT",2,0); ar:SetText("→"); ar:SetWidth(20); ar:SetJustifyH("CENTER")
                        local tIB=CreateFrame("Button",nil,row); tIB:SetSize(48,48); tIB:SetPoint("LEFT",ar,"RIGHT",2,-2)
                        tIB.texture=tIB:CreateTexture(nil,"ARTWORK"); tIB.texture:SetAllPoints(); tIB.itemID=nil;tIB.itemLink=nil;tIB.currentItemID=nil;tIB._tgtIlvl=0;tIB._tgtName=nil;tIB._tgtSrc=nil;tIB._tgtStats=nil
                        tIB:SetScript("OnEnter",function(s) if s.itemID then GameTooltip:SetOwner(s,"ANCHOR_RIGHT") GameTooltip:ClearLines() if s.itemLink then GameTooltip:SetHyperlink(s.itemLink) else GameTooltip:SetItemByID(s.itemID) end if s._tgtIlvl and s._tgtIlvl>0 then GameTooltip:AddLine(" ") GameTooltip:AddLine("|cFFFFFF00"..T("TT_BIS_ILVL","BiS 装等: ")..s._tgtIlvl.."|r",1,1,1) end if s._improvementPct and s._improvementPct>0 then GameTooltip:AddLine(" ") GameTooltip:AddLine(string.format(T("TT_IMPROVE","提升幅度: +%.1f%%"),s._improvementPct),0.2,1,0.2) end if s._tgtSrc and s._tgtSrc~="" then GameTooltip:AddLine(T("SOURCE_PREFIX","来源: ")..s._tgtSrc,0.8,0.8,0.8) end GameTooltip:AddLine(" ") GameTooltip:AddLine("|cFF888888"..T("TT_BIS_REC","GearInsight BiS 推荐").."|r",0.5,0.5,0.5) GameTooltip:AddLine("|cFF66CCFF"..T("TT_SHIFT_CHAT","Shift+点击 发送到聊天").."|r",0.4,0.8,1) GameTooltip:Show() end end)
                        tIB:SetScript("OnLeave",function() GameTooltip:Hide() end)
                        tIB:RegisterForClicks("LeftButtonUp")
                        tIB:SetScript("OnClick",function(s) if GearInsight._tryChatLink(s) then return end if s._slotCands and #s._slotCands>0 then GearInsight:ShowSlotTop5(s._slotLabel,s._slotId,s._slotCands) end end)
                        local t5=CreateFrame("Button",nil,row,"UIPanelButtonTemplate"); t5:SetSize(48,22); t5:SetPoint("TOPRIGHT",row,"TOPRIGHT",-6,-6); t5:SetText(T("TOP5_BTN","前5")); t5:SetFrameLevel(60)
                        t5:SetScript("OnEnter",function(s) GameTooltip:SetOwner(s,"ANCHOR_TOP"); GameTooltip:SetText(T("TOP5_BTN_TT","查看该部位使用率前5"),1,0.82,0); GameTooltip:Show() end)
                        t5:SetScript("OnLeave",function() GameTooltip:Hide() end)
                        t5:SetScript("OnClick",function(s) local ic=s:GetParent()._tgtIcon if ic and ic._slotCands and #ic._slotCands>0 then GearInsight:ShowSlotTop5(ic._slotLabel,ic._slotId,ic._slotCands) end end)
                        local tT=row:CreateFontString(nil,"OVERLAY","GameFontNormal"); tT:SetPoint("LEFT",tIB,"RIGHT",4,0); tT:SetPoint("RIGHT",t5,"LEFT",-6,0); tT:SetJustifyH("LEFT"); tT:SetWordWrap(true)
                        local dp=CreateFrame("Button",nil,row); dp:SetPoint("TOPLEFT",tIB,"BOTTOMLEFT",0,2); dp:SetPoint("RIGHT",-4,0); dp:SetHeight(16)
                        dp:EnableMouse(true); dp:RegisterForClicks("LeftButtonUp"); dp:SetFrameLevel(50)
                        local dpt=dp:CreateFontString(nil,"OVERLAY","GameFontDisableSmall"); dpt:SetAllPoints(); dpt:SetJustifyH("LEFT"); dpt:SetWordWrap(false); dpt:SetMaxLines(1); dpt:SetTextColor(0.55,0.55,0.55)
                        dp._text=dpt; dp._instId=nil; dp._bossId=nil; dp._itemId=nil; dp._tierSlot=nil
                        dp:SetScript("OnEnter",function(s) if s._instId then GameTooltip:SetOwner(s,"ANCHOR_TOP"); GameTooltip:SetText(T("TT_JOURNAL_CLICK","点击打开地下城手册"),0.8,0.8,0.8); GameTooltip:Show() end end)
                        dp:SetScript("OnLeave",function() GameTooltip:Hide() end)
                        dp:SetScript("OnClick",function(s) if s._tierSlot then GearInsight:ShowTierFiller(s._tierArmor,s._tierSlot,s._tierLabel,s._tierSrcs,s._tierBonus) else _openSourceJournal(s._instId,s._bossId,s._itemId) end end)
                        row._curIcon=cIB; row._curText=cT; row._arrow=ar; row._tgtIcon=tIB; row._tgtText=tT; row._drop=dp; row._top5Btn=t5
                        self._upgradeRows[rowIdx] = row
                    end

                    -- Slot section header (yellow, above first actionable item of new slot)
                    local headerKey = slotKey or ("SLOT" .. slotId)
                    if not self._lastSlot or self._lastSlot ~= headerKey then
                        local hdr = self._slotHeaders[headerKey]
                        if not hdr then
                            hdr = self._scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
                            self._slotHeaders[headerKey] = hdr
                        end
                        hdr:ClearAllPoints()
                        hdr:SetPoint("TOPLEFT", 2, yOff)
                        hdr:SetWidth(470)
                        hdr:SetJustifyH("LEFT")
                        hdr:SetText(T("HDR_UPGRADE_SLOT", "待提升 - ") .. slotLabel)
                        hdr:SetTextColor(1, 0.82, 0)
                        hdr:Show()
                        yOff = yOff - 22
                        self._lastSlot = headerKey
                    end

                    row:ClearAllPoints()
                    row:SetPoint("TOPLEFT", self._scrollChild, "TOPLEFT", 2, yOff)
                    row:Show()

                    -- Current item icon (sync+async)
                    setItemForIcon(row._curIcon, (eq and not eq.empty and cId) or nil)
                    if eq and eq.itemLink then row._curIcon.itemLink = eq.itemLink end
                    -- Target BiS icon (after de-dup)
                    setItemForIcon(row._tgtIcon, top.itemId, top.bonusIDs)

                    -- Translate drop source to Chinese (after de-dup so src is final).
                    -- zhCN-only: on other clients these EN->CN swaps must not run.
                    local srcCN = dropSrc
                    if srcCN and _LOCALE == "zhCN" then
                        srcCN = srcCN:gsub("Midnight Falls", "午夜陨落")
                        srcCN = srcCN:gsub("Belo'ren", "贝洛伦")
                        srcCN = srcCN:gsub("Imperator Averzian", "阿维兹安大帝")
                        srcCN = srcCN:gsub("Fallen%-King Salhadaar", "陨落之王萨拉达尔")
                        srcCN = srcCN:gsub("Crown of the Cosmos", "宇宙之冠")
                        srcCN = srcCN:gsub("Chimaerus", "奇美拉")
                        srcCN = srcCN:gsub("Vaelgor & Ezzorak", "瓦尔格 & 埃佐拉克")
                        srcCN = srcCN:gsub("Lightblinded Vanguard", "光盲先锋")
                        srcCN = srcCN:gsub("Vorasius", "沃拉修斯")
                    end

                    -- Store data on target icon button for custom Tooltip
                    row._tgtIcon._tgtIlvl        = topIlvl
                    row._tgtIcon._tgtName        = topName
                    -- ⭐ 2026-08-29：这里原本是全插件**唯一**没走 localizedSource 的来源行，
                    -- 只特判了 zhTW（简转繁），enUS 等语言原样吐烤进去的中文。
                    -- localizedSource 内部已分别处理 zhCN(原样) / zhTW(S2T) / 其他(EJ 取本地化名)，
                    -- 交给它即可，三种语言都不会变差。⛔ 别再在这里手写语言分支。
                    row._tgtIcon._tgtSrc = localizedSource(srcCN or dropSrc or "",
                                                           top.instanceId, top.encounterId)
                    row._tgtIcon._fromLiveRecs   = top._fromLiveRecs or false
                    row._tgtIcon._improvementPct = top.improvementPct
                    row._tgtIcon._tgtStats       = top.stats or nil
                    -- Slot's full usage-ranked candidate list, for the top-5 popup
                    row._tgtIcon._slotId    = slotId
                    -- Paired slots show the pooled list, so title it without the
                    -- slot number (饰品1/饰品2 → 饰品, 戒指1/2 → 戒指).
                    row._tgtIcon._slotLabel = pairOther and (slotLabel:gsub("%s*%d+$", "")) or slotLabel
                    row._tgtIcon._slotCands = cand
                    -- Show the "前5" button whenever the slot has any candidate. (Don't
                    -- gate on >1: with 团本排除 a slot's pool can collapse to a single
                    -- non-raid item, and the button must still open its usage reference.)
                    if row._top5Btn then row._top5Btn:SetShown(cand and #cand > 0) end

                    -- Encounter Journal linking (click to open dungeon journal)
                    row._drop._instId = top.instanceId
                    row._drop._bossId = top.encounterId
                    row._drop._itemId = top.itemId

                    -- Build left/right text (unified actionable format)
                    local leftText, rightText, hasDrop = "", "", false

                    if not eq or eq.empty then
                        leftText = "|cFFFF0000" .. slotLabel .. " " .. T("SLOT_EMPTY", "(空)") .. "|r"
                        rightText = "|cFF00FF00" .. topName .. "|r  [" .. topIlvl .. "]"
                        hasDrop = (dropSrc ~= "")
                    elseif cId and cId == top.itemId then
                        leftText = slotLabel .. ": " .. cName .. "  [" .. cIlvl .. "]"
                        rightText = "|cFFFF6600→ " .. topName .. " [" .. topIlvl .. "]" .. T("NEED_HIGHER_ILVL", " 需更高装等版本") .. "|r"
                        hasDrop = (dropSrc ~= "")
                    elseif cIlvl < topIlvl then
                        leftText = slotLabel .. ": " .. cName .. "  [" .. cIlvl .. "]"
                        rightText = "|cFF00FF00" .. topName .. "|r [" .. topIlvl .. "] |cFFFF6600(+" .. (topIlvl - cIlvl) .. ")|r"
                        hasDrop = (dropSrc ~= "")
                    elseif rank and topIlvl > 0 then
                        leftText = slotLabel .. ": " .. cName .. "  |cFFFFFF00#" .. rank .. "|r  [" .. cIlvl .. "]"
                        rightText = "|cFF00FF00→ " .. topName .. " [" .. topIlvl .. "]|r"
                        hasDrop = (dropSrc ~= "")
                    else
                        leftText = slotLabel .. ": " .. cName .. "  [" .. cIlvl .. "]"
                        rightText = "|cFF00FF00→ " .. topName .. " [" .. topIlvl .. "]|r"
                        hasDrop = (dropSrc ~= "")
                    end
                    row._curText:SetText(leftText)
                    row._tgtText:SetText(rightText)

                    -- Drop info (consistent row height regardless of drop presence).
                    -- Tier pieces come only from the Catalyst (套装转换): show where to
                    -- farm a same-slot "坯子" to convert, instead of the useless "套装转换".
                    -- Tier pieces come only from the Catalyst (套装转换). Show one short
                    -- clickable line; clicking pops up the full list of farmable fillers.
                    local fillerSrcs, fillerArmor = nil, nil
                    if dropSrc == "套装转换" and self.BisData and self.BisData.tierFiller then
                        fillerArmor = self.BisData.classArmor and self.BisData.classArmor[class]
                        if fillerArmor and self.BisData.tierFiller[fillerArmor] then
                            fillerSrcs = self.BisData.tierFiller[fillerArmor][slotId]
                        end
                    end
                    row._drop:ClearAllPoints()
                    row._drop:SetPoint("TOPLEFT", row._tgtIcon, "BOTTOMLEFT", 0, 2)
                    row._drop:SetPoint("RIGHT", -4, 0)
                    -- 套装转换 slot with no curated filler list (e.g. a non-standard tier slot
                    -- on a new spec): derive the filler from the slot's own same-slot raid/mplus
                    -- drops — any can be Catalyst-converted. Shape matches the curated entries.
                    local derivedSrcs = nil
                    if not (fillerSrcs and #fillerSrcs > 0) and dropSrc == "套装转换" and cand then
                        derivedSrcs = {}
                        for _, c in ipairs(cand) do
                            -- Any same-slot piece except the tier item itself can be catalyzed.
                            -- Crafted (制造业) gear is NOT catalyzable, so exclude it.
                            if c.itemId and c.sourceCategory and c.sourceCategory ~= "tier"
                                and c.sourceCategory ~= "crafted" and c.source ~= "套装转换" then
                                derivedSrcs[#derivedSrcs + 1] = {
                                    itemId = c.itemId, bonusIDs = c.bonusIDs, type = c.sourceCategory,
                                    nameCn = (c.bossName and c.bossName ~= "" and c.bossName) or c.source,
                                    instanceId = c.instanceId, encounterId = c.encounterId,
                                }
                            end
                        end
                        if #derivedSrcs == 0 then derivedSrcs = nil end
                    end
                    if fillerSrcs and #fillerSrcs > 0 then
                        row._drop._text:SetText("|cFFB060FF" .. T("TIER_FILLER", "套装坯子") .. "|r |cFF808080" .. T("TIER_FILLER_CLICK", "· 点击查看可刷装备 (") .. #fillerSrcs .. ")|r")
                        row._drop._tierArmor = fillerArmor
                        row._drop._tierSlot = slotId
                        row._drop._tierLabel = slotLabel
                        row._drop._tierSrcs = nil
                        row._drop._tierBonus = top.bonusIDs
                        row._drop._instId = nil; row._drop._bossId = nil; row._drop._itemId = nil
                        row._drop:Show()
                    elseif derivedSrcs then
                        -- No count: the popup pulls the full Encounter Journal loot list, which is
                        -- usually larger than this WCL-derived stopgap, so a number would mislead.
                        row._drop._text:SetText("|cFFB060FF" .. T("TIER_FILLER", "套装坯子") .. "|r |cFF808080" .. T("TIER_FILLER_CLICK2", "· 点击查看可催化装备") .. "|r")
                        row._drop._tierArmor = nil
                        row._drop._tierSlot = slotId
                        row._drop._tierLabel = slotLabel
                        row._drop._tierSrcs = derivedSrcs
                        row._drop._tierBonus = top.bonusIDs
                        row._drop._instId = nil; row._drop._bossId = nil; row._drop._itemId = nil
                        row._drop:Show()
                    elseif hasDrop then
                        row._drop._tierSlot = nil
                        row._drop._tierSrcs = nil
                        row._drop._tierBonus = nil
                        local hint = top.instanceId and (" |cFFAAAAAA" .. T("JOURNAL_HINT", "(点击手册)") .. "|r") or ""
                        row._drop._text:SetText("|cFF808080" .. T("SOURCE_PREFIX", "来源: ") .. localizedSource(srcCN or dropSrc, top.instanceId, top.encounterId) .. "|r" .. hint)
                        row._drop:Show()
                    else
                        row._drop._tierSlot = nil
                        row._drop._tierSrcs = nil
                        row._drop._tierBonus = nil
                        row._drop._text:SetText("")
                        row._drop:Hide()
                    end
                    row:SetHeight(72)
                    yOff = yOff - 72 - 2
                    end
                end
            end
        end
    end

    -- Hide unused rows
    for i = rowIdx + 1, #self._upgradeRows do
        self._upgradeRows[i]:Hide()
    end

    -- Handle no actionable rows
    if rowIdx == 0 and self._scrollChild then
        if not self._emptyUpgradeLabel then
            self._emptyUpgradeLabel = self._scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            self._emptyUpgradeLabel:SetWidth(456)
            self._emptyUpgradeLabel:SetJustifyH("LEFT")
        end
        self._emptyUpgradeLabel:ClearAllPoints()
        self._emptyUpgradeLabel:SetPoint("TOPLEFT", 6, 0)
        if usingLiveRecs then
            self._emptyUpgradeLabel:SetText(T("EMPTY_COMPANION", "Companion 已连接，暂无待处理推荐"))
        elseif completedCount > 0 then
            self._emptyUpgradeLabel:SetText(T("EMPTY_KEY_DONE", "关键槽位已达成，建议查看刷本优先级核对完整清单"))
        else
            self._emptyUpgradeLabel:SetText(T("EMPTY_NONE", "暂无下一步建议"))
        end
        self._emptyUpgradeLabel:SetTextColor(1, 0.5, 0)
        self._emptyUpgradeLabel:Show()
        -- Keep the gems/enchants section below the empty-state label.
        yOff = math.min(yOff, -24)
    end

    -- ── Graduated slots (perceivable list; each row keeps its 前5 popup) ──
    self._gradRows = self._gradRows or {}
    local gradShown = 0
    if #completedSlots > 0 and self._scrollChild then
        GearInsightDB = GearInsightDB or {}
        local collapsed = GearInsightDB.gradCollapse and true or false
        if not self._gradHeader then
            local hb = CreateFrame("Button", nil, self._scrollChild)
            hb:SetHeight(20)
            local fs = hb:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            fs:SetAllPoints()
            fs:SetJustifyH("LEFT")
            hb._fs = fs
            hb:SetScript("OnClick", function()
                GearInsightDB.gradCollapse = not GearInsightDB.gradCollapse
                GearInsight:RefreshPanel()
            end)
            hb:SetScript("OnEnter", function(s)
                GameTooltip:SetOwner(s, "ANCHOR_TOP")
                GameTooltip:SetText(T("GRAD_HDR_TT", "点击展开/收起已毕业槽位"), 1, 0.82, 0)
                GameTooltip:Show()
            end)
            hb:SetScript("OnLeave", function() GameTooltip:Hide() end)
            self._gradHeader = hb
        end
        local hb = self._gradHeader
        hb:ClearAllPoints()
        hb:SetPoint("TOPLEFT", 2, yOff)
        hb:SetWidth(470)
        local arrow = collapsed and "+ " or "- "
        -- 对勾用游戏自带贴图：✓(U+2713) 在 zhCN 客户端字体里没有字形，渲染成 □
        hb._fs:SetText(arrow .. "|TInterface\\RaidFrame\\ReadyCheck-Ready:14|t " .. T("GRAD_HDR", "已毕业槽位") .. " (" .. completedCount .. ")")
        hb._fs:SetTextColor(0.35, 0.9, 0.35)
        hb:Show()
        yOff = yOff - 22

        if not collapsed then
            for _, gs in ipairs(completedSlots) do
                gradShown = gradShown + 1
                local row = self._gradRows[gradShown]
                if not row then
                    row = CreateFrame("Frame", nil, self._scrollChild)
                    row:SetSize(456, 26)
                    row:EnableMouse(true)
                    local ic = CreateFrame("Button", nil, row)
                    ic:SetSize(22, 22)
                    ic:SetPoint("TOPLEFT", 4, -2)
                    ic.texture = ic:CreateTexture(nil, "ARTWORK")
                    ic.texture:SetAllPoints()
                    ic.itemID = nil; ic.itemLink = nil; ic.currentItemID = nil
                    ic:SetScript("OnEnter", function(s) if s.itemID then GameTooltip:SetOwner(s, "ANCHOR_RIGHT") if s.itemLink then GameTooltip:SetHyperlink(s.itemLink) else GameTooltip:SetItemByID(s.itemID) end GameTooltip:Show() end end)
                    ic:SetScript("OnLeave", function() GameTooltip:Hide() end)
                    local t5 = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
                    t5:SetSize(44, 20)
                    t5:SetPoint("RIGHT", row, "RIGHT", -6, 0)
                    t5:SetText(T("TOP5_BTN", "前5"))
                    t5:SetFrameLevel(60)
                    t5:SetScript("OnEnter", function(s) GameTooltip:SetOwner(s, "ANCHOR_TOP"); GameTooltip:SetText(T("TOP5_BTN_TT", "查看该部位使用率前5"), 1, 0.82, 0); GameTooltip:Show() end)
                    t5:SetScript("OnLeave", function() GameTooltip:Hide() end)
                    t5:SetScript("OnClick", function(s) if s._slotCands and #s._slotCands > 0 then GearInsight:ShowSlotTop5(s._slotLabel, s._slotId, s._slotCands) end end)
                    local fs = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                    fs:SetPoint("LEFT", ic, "RIGHT", 6, 0)
                    fs:SetPoint("RIGHT", t5, "LEFT", -6, 0)
                    fs:SetJustifyH("LEFT")
                    fs:SetWordWrap(false)
                    fs:SetMaxLines(1)
                    row._icon = ic; row._text = fs; row._top5 = t5
                    self._gradRows[gradShown] = row
                end
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", self._scrollChild, "TOPLEFT", 2, yOff)
                setItemForIcon(row._icon, gs.eqId)
                if gs.eqLink then row._icon.itemLink = gs.eqLink end
                local rankTag = gs.rank and ("  |cFFFFFF00#" .. gs.rank .. "|r") or ""
                -- 已经是这件、只是轨道没升满：明说「可升级」，别让人误以为要换装备
                local upTag = gs.upgradeTo
                    and ("  |cFF66CCFF" .. T("GRAD_UPGRADABLE", "可升级") .. " "
                         .. (gs.eqIlvl or 0) .. " → " .. gs.upgradeTo .. "|r")
                    or ""
                row._text:SetText("|TInterface\\RaidFrame\\ReadyCheck-Ready:12|t " .. gs.label .. ": |cFF55E055" .. (gs.eqName or "") .. "|r  [" .. (gs.eqIlvl or 0) .. "]" .. rankTag .. upTag)
                row._top5._slotId = gs.slotId
                row._top5._slotLabel = gs.popupLabel
                row._top5._slotCands = gs.cand
                row._top5:SetShown(gs.cand and #gs.cand > 0)
                row:Show()
                yOff = yOff - 26
            end
        end
    elseif self._gradHeader then
        self._gradHeader:Hide()
    end
    for i = gradShown + 1, #self._gradRows do
        self._gradRows[i]:Hide()
    end

    -- ── Crafted-gear mini recommendation (2 slots most worth crafting) ──
    yOff = yOff - 8
    yOff = self:_renderCraftedPicks(class, spec, htal, yOff)

    -- ── Recommended gems & enchants (appended below the upgrade list) ──
    yOff = yOff - 8
    yOff = self:_renderGemsEnchants(data, yOff)

    self._scrollChild:SetHeight(math.max(24, math.abs(yOff) + 8))

    -- ElvUI 换肤：扫主面板子树(含本轮新建的行内按钮)；无 ElvUI 时为空操作
    if GearInsight.Skin then GearInsight.Skin.Sweep(self._panelFrame) end
end

-- ── Farming guide popup ─────────────────────────────────────────────
-- 复刻旧副本的坯子复用原版 itemId（如萨隆矿坑 50234），常不在客户端缓存里，
-- GetItemInfo 返 nil 只能显示 #ID。这里异步请求物品数据，到货后若刷本窗口仍开着
-- 就原地重渲染一次补上名字。每个 id 本次会话只请求一次 + 0.5s 去抖，不会循环重渲染。
local _fgNamePending = {}
local function _fgQueueNameLoad(itemId)
    if _fgNamePending[itemId] ~= nil then return end
    if not (Item and Item.CreateFromItemID and C_Timer and C_Timer.NewTimer) then return end
    _fgNamePending[itemId] = true
    local ok, it = pcall(Item.CreateFromItemID, Item, itemId)
    if not (ok and it) or (it.IsItemEmpty and it:IsItemEmpty()) then return end
    it:ContinueOnItemLoad(function()
        if GearInsight._fgNameTimer then return end
        GearInsight._fgNameTimer = C_Timer.NewTimer(0.5, function()
            GearInsight._fgNameTimer = nil
            local f = GearInsight._fgFrame
            if f and f:IsShown() then
                local a = GearInsight._fgArgs or {}
                GearInsight:ShowFarmingGuide(a[1], a[2], a[3], true)
            end
        end)
    end)
end

-- Detect 2H vs dual wield from the equipped main-hand weapon (shared by the
-- farming guide and the main-panel crafted-picks section).
function GearInsight:_detectIs2H()
    local snap = self.SavedVars and self.SavedVars:GetLastSnapshot()
    if snap and snap.equipped and snap.equipped[16] and not snap.equipped[16].empty then
        local mhId = snap.equipped[16].itemId
        if mhId and C_Item and C_Item.GetItemInventoryTypeByID then
            -- ENUM: INVTYPE_2HWEAPON = 17
            return C_Item.GetItemInventoryTypeByID(mhId) == 17
        end
    end
    return false
end

-- Top-N crafted-gear slot picks for the given spec, ranked by each item's own
-- WCL usage % in its slot (higher = more strongly agreed-upon BiS there).
-- Shared by the main panel's mini "制造推荐" section and the farming guide.
function GearInsight:GetTopCraftedPicks(class, spec, heroTalent, is2H, limit)
    local itemsBySource = self.BisData and self.BisData:GetItemsBySource(class, spec, heroTalent, is2H)
    local crafted = itemsBySource and itemsBySource.crafted
    if not crafted or #crafted == 0 then return nil end
    table.sort(crafted, function(a, b)
        return (a.item.usagePct or 0) > (b.item.usagePct or 0)
    end)
    local out = {}
    for i = 1, math.min(limit or 2, #crafted) do
        out[i] = crafted[i]
    end
    return out
end

function GearInsight:ShowFarmingGuide(class, spec, heroTalent, keepOpen)
    -- Toggle off if already showing（keepOpen=切换参照系时原地重建，不关闭）
    if self._fgFrame and self._fgFrame:IsShown() and not keepOpen then
        self._fgFrame:Hide()
        return
    end
    self._fgArgs = { class, spec, heroTalent }

    local is2H = self:_detectIs2H()

    local itemsBySource = self.BisData and self.BisData:GetItemsBySource(class, spec, heroTalent, is2H)
    local cn, sn = getLocalizedClassSpec()

    -- Dimmer: no longer blocks outside clicks — user can interact with other UI

    -- Popup frame (create once, reuse)
    if not self._fgFrame then
        local f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        GearInsight:RegisterEscClose(f, "GearInsightFGFrame")
        f:SetSize(500, 520)
        GearInsight:AnchorPopup(f)
        f:SetFrameStrata("DIALOG")
        f:SetFrameLevel(20)
        f:SetBackdrop({
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            edgeSize = 32,
            insets = { left = 8, right = 8, top = 8, bottom = 8 },
        })
        f:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.9)
        local bg = f:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.05, 0.05, 0.08, 0.95)
        f:EnableMouse(true)
        f:SetMovable(true); f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", function() f:StartMoving() end)
        f:SetScript("OnDragStop", function() f:StopMovingOrSizing(); f._giUserMoved = true end)

        -- Title
        self._fgTitle = f:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
        self._fgTitle:SetPoint("TOP", 0, -12)

        -- Close button
        local cb = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        cb:SetPoint("TOPRIGHT", -4, -4)
        cb:SetScript("OnClick", function()
            f:Hide()
        end)

        -- Scroll frame
        local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 12, -36)
        scroll:SetPoint("BOTTOMRIGHT", -28, 32)
        self._fgScroll = scroll

        local sc = CreateFrame("Frame", nil, scroll)
        sc:SetWidth(460)
        scroll:SetScrollChild(sc)
        self._fgScrollChild = sc

        self._fgFrame = f
    end

    -- Update title
    local titleStr = T("FG_TITLE", "刷本优先级")
    if cn or class then
        titleStr = titleStr .. " — " .. (cn or class or "")
        if sn or spec then titleStr = titleStr .. "/" .. (sn or spec or "") end
        if heroTalent then titleStr = titleStr .. "(" .. heroTalent .. ")" end
    end
    self._fgTitle:SetText(titleStr)

    -- Rebuild content rows. Headers/sub-headers are FontStrings; item rows are
    -- Frames. They MUST be pooled SEPARATELY — a single positional pool would,
    -- after a re-render with a different row composition (e.g. toggling 团本排除),
    -- hand back a Frame where a FontString is expected and error mid-render
    -- (leaving the popup half-blank). Type-stable pools keep each slot consistent.
    local sc = self._fgScrollChild
    sc.fsPool = sc.fsPool or {}
    sc.itemPool = sc.itemPool or {}
    sc.hdrPool = sc.hdrPool or {}
    if sc.rows then for _, w in ipairs(sc.rows) do w:Hide() end end  -- legacy mixed pool (older builds)
    for _, w in ipairs(sc.fsPool) do w:Hide() end
    for _, w in ipairs(sc.itemPool) do w:Hide() end
    for _, w in ipairs(sc.hdrPool) do w:Hide() end
    local fsIdx, itemIdx, hdrIdx = 0, 0, 0
    -- A pooled FontString for headers/sub-headers/fallback; font set per use.
    local function nextFS(fontObject)
        fsIdx = fsIdx + 1
        local fs = sc.fsPool[fsIdx]
        if not fs then
            fs = sc:CreateFontString(nil, "OVERLAY", fontObject or "GameFontNormal")
            sc.fsPool[fsIdx] = fs
        end
        fs:SetFontObject(fontObject or "GameFontNormal")
        return fs
    end
    -- A pooled item row (Frame with icon + text), built once.
    local function nextItemRow()
        itemIdx = itemIdx + 1
        local row = sc.itemPool[itemIdx]
        if not row then
            row = CreateFrame("Frame", nil, sc)
            row:SetSize(440, 26)
            local icon = CreateFrame("Button", nil, row)
            icon:SetSize(22, 22)
            icon:SetPoint("LEFT", 14, 0)
            icon.texture = icon:CreateTexture(nil, "ARTWORK")
            icon.texture:SetAllPoints()
            icon.itemID = nil; icon.itemLink = nil; icon.currentItemID = nil
            icon:SetScript("OnEnter", function(self)
                if not self.itemID then return end
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                if self.itemLink then GameTooltip:SetHyperlink(self.itemLink)
                else GameTooltip:SetItemByID(self.itemID) end
                if self._itemIlvl and self._itemIlvl > 0 then
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine("|cFFFFFF00" .. T("TT_BIS_ILVL", "BiS 装等: ") .. self._itemIlvl .. "|r", 1, 1, 1)
                end
                GameTooltip:Show()
            end)
            icon:SetScript("OnLeave", function() GameTooltip:Hide() end)
            icon:RegisterForClicks("LeftButtonUp")
            icon:SetScript("OnClick", function(self)
                if GearInsight._tryChatLink(self) then return end
                _openSourceJournal(self._instId, self._bossId, self.itemID, self._isRaid)
            end)
            icon._instId = nil
            icon._bossId = nil
            row._icon = icon
            local txt = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            txt:SetPoint("LEFT", icon, "RIGHT", 4, 0)
            txt:SetWidth(380)
            txt:SetJustifyH("LEFT")
            row._txt = txt
            sc.itemPool[itemIdx] = row
        end
        return row
    end
    -- A pooled CLICKABLE category header (Button + child FontString). Clicking it
    -- toggles the category's collapse state (stored in GearInsightDB.fgCollapse) and
    -- re-renders the popup in place. Used so 制造业 can be folded away by default.
    local function nextHeaderBtn()
        hdrIdx = hdrIdx + 1
        local btn = sc.hdrPool[hdrIdx]
        if not btn then
            btn = CreateFrame("Button", nil, sc)
            btn:SetHeight(20)
            btn:EnableMouse(true)
            btn:RegisterForClicks("LeftButtonUp")
            local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            fs:SetPoint("LEFT", 0, 0)
            fs:SetJustifyH("LEFT")
            btn._fs = fs
            sc.hdrPool[hdrIdx] = btn
        end
        return btn
    end
    local yOff = 0

    -- Get equipped item info (itemId → {ilvl}) for missing-item detection,
    -- plus the best equipped ilvl per slot (for tier-slot satisfaction below).
    local equippedItems = {}
    local equippedBySlot = {}
    local equippedIdBySlot = {}
    local snap = self.SavedVars and self.SavedVars:GetLastSnapshot()
    if snap and snap.equipped then
        for _, eq in pairs(snap.equipped) do
            if eq and not eq.empty and eq.itemId then
                equippedItems[eq.itemId] = { ilvl = eq.ilvl or 0, slotId = eq.slotId }
                if eq.slotId then
                    equippedBySlot[eq.slotId] = math.max(equippedBySlot[eq.slotId] or 0, eq.ilvl or 0)
                    equippedIdBySlot[eq.slotId] = eq.itemId
                end
            end
        end
    end

    -- 配对池前2候选的 itemId 集合（戒指/饰品/武器各一池），严判用。
    local function poolKeyOf(sid)
        if sid == 11 or sid == 12 then return "rings"
        elseif sid == 13 or sid == 14 then return "trinkets"
        elseif sid == 16 or sid == 17 then return "weapons" end
    end
    local poolTop = {}
    if itemsBySource then
        for _, items in pairs(itemsBySource) do
            for _, e in ipairs(items) do
                local pk = e.item and not e.item._filler and e.item.itemId and poolKeyOf(e.slotId)
                if pk then
                    poolTop[pk] = poolTop[pk] or {}
                    poolTop[pk][e.item.itemId] = true
                end
            end
        end
    end

    -- A tier piece counts as owned when you have any same-slot item at the tier ilvl
    -- (the Catalyst can convert it), not only the exact tier itemId.
    local function tierSlotSatisfied(slotId, ilvl)
        return (equippedBySlot[slotId] or 0) >= (ilvl or 0)
    end

    -- Dual-wield / paired-slot pools (weapons 16+17, rings 11+12, trinkets 13+14):
    -- 严判口径与主面板毕业判定一致——池子里每个槽必须装着「池子前2候选本身」且装等达标
    -- 才算齐。只看装等会与主面板打架：装等相同但使用率跌出前2的旧件，主面板报「待提升」，
    -- 这里却整行吞掉刷取目标（2026-06-06 幽影羽毛实证：双饰品都298但旌旗非前2候选）。
    local function poolSatisfied(slotId, ilvl)
        local slots
        if slotId == 11 or slotId == 12 then slots = { 11, 12 }
        elseif slotId == 13 or slotId == 14 then slots = { 13, 14 }
        elseif slotId == 16 or slotId == 17 then slots = is2H and { 16 } or { 16, 17 }
        else return false end
        local pset = poolTop[poolKeyOf(slotId)]
        for _, sid in ipairs(slots) do
            if (equippedBySlot[sid] or 0) < (ilvl or 0) then return false end
            local eqId = equippedIdBySlot[sid]
            if pset and not (eqId and pset[eqId]) then return false end
        end
        return true
    end

    -- Fold tier "坯子" (Catalyst filler) into raid/mplus groups: every same-slot drop you
    -- could Catalyst-convert. Prefer the complete Encounter Journal list, fall back to the
    -- curated tierFiller list. Only for tier slots you don't already have at the tier ilvl.
    if itemsBySource and itemsBySource.tier then
        local armor = self.BisData and self.BisData.classArmor and self.BisData.classArmor[class]
        -- When 团本排除 is on, the 坯子 itself stays (it can be catalyzed from a
        -- non-raid same-slot piece), but its RAID catalyst sources must be dropped —
        -- otherwise raid bosses (e.g. M6 虚影尖塔) reappear under the 团本 group.
        local exRaid = self.BisData and self.BisData:GetExcludeRaid()
        for _, te in ipairs(itemsBySource.tier) do
            -- 已穿着套装件本身（催化已完成）→ 不再列坯子：剩下的只是装等差距，
            -- 走纹章升级而非重刷坯子；「套装」分类的本体行仍会报「装等不足」。
            if not equippedItems[te.item.itemId]
                and (equippedBySlot[te.slotId] or 0) < (te.item.ilvl or 0) then
                local srcs = self:GetCatalystSources(te.slotId)
                if (not srcs or #srcs == 0) and armor and self.BisData and self.BisData.tierFiller
                    and self.BisData.tierFiller[armor] then
                    srcs = self.BisData.tierFiller[armor][te.slotId]
                end
                -- Show each 坯子 at the TARGET set ilvl: graft the set piece's bonusIDs
                -- (which encode the BiS ilvl) onto the filler's itemId so the tooltip reads
                -- the BiS ilvl, not the journal's base/Mythic-0 value.
                local tb = te.item.bonusIDs
                for _, s in ipairs(srcs or {}) do
                    local cat = s.type or "other"
                    -- Crafted gear isn't catalyzable into tier — never fold it in as a 坯子.
                    if not (exRaid and cat == "raid") and cat ~= "crafted" then
                    local link = (tb and #tb > 0)
                        and ("|Hitem:" .. s.itemId .. ":0::::::::0:::" .. #tb .. ":" .. table.concat(tb, ":") .. "|h[item]|h")
                        or s.link
                    itemsBySource[cat] = itemsBySource[cat] or {}
                    table.insert(itemsBySource[cat], {
                        slotId = te.slotId,
                        item = {
                            itemId = s.itemId,      -- the real same-slot drop to convert
                            bonusIDs = tb or s.bonusIDs,
                            link = link,
                            ilvl = te.item.ilvl,    -- TARGET set ilvl shown inline ([→289])
                            bossName = s.nameCn, sourceCategory = cat,
                            instanceId = s.instanceId, encounterId = s.encounterId,
                            _isRaid = (s.type == "raid"),
                            _filler = true,
                        },
                    })
                    end -- not (exRaid and raid)
                end
            end
        end
    end

    -- Farmable categories first (raid / mplus / world / tier); 制造业(crafted) is NOT
    -- obtainable by running content (needs profession crafting or AH), so it's pushed
    -- to the very end and rendered collapsed by default to stop it visually dominating.
    local CAT_ORDER = { "raid", "mplus", "world", "quest", "tier", "crafted" }
    -- Per-category collapse state (persisted). crafted defaults to collapsed.
    GearInsightDB = GearInsightDB or {}
    GearInsightDB.fgCollapse = GearInsightDB.fgCollapse or {}
    if GearInsightDB.fgCollapse.crafted == nil then
        GearInsightDB.fgCollapse.crafted = true
    end
    local CAT_LABELS = {
        raid = T("CAT_RAID", "团本"), mplus = T("CAT_MPLUS", "大秘境"), crafted = T("CAT_CRAFTED", "制造业"),
        world = T("CAT_WORLD", "世界掉落"), tier = T("CAT_TIER", "套装"), quest = T("CAT_QUEST", "任务/声望"),
    }
    local CAT_COLORS = {
        raid = { 1, 0.6, 0.2 }, mplus = { 0.3, 0.8, 1 },
        crafted = { 0.2, 1, 0.2 }, world = { 1, 0.8, 0 },
        tier = { 0.8, 0.4, 1 }, quest = { 1, 0.85, 0.3 },
    }
    local L = self.L or {}
    local gr = self.GearReader

    -- 制造业每个槽位只挂一件（GetItemsBySource 已去重），但一个专精常有 5-6 个
    -- 槽位的 #1 选择恰好是制造装，列出来太长。玩家反馈：只想看最值得做的 2 件。
    -- 按 WCL 数据里该件在自己槽位的使用率（usagePct）排序，取前 2 个槶位，
    -- 使用率越高＝顶尖玩家越公认该槽必须做，越值得优先制作。
    if itemsBySource and itemsBySource.crafted and #itemsBySource.crafted > 2 then
        table.sort(itemsBySource.crafted, function(a, b)
            return (a.item.usagePct or 0) > (b.item.usagePct or 0)
        end)
        for i = #itemsBySource.crafted, 3, -1 do
            table.remove(itemsBySource.crafted, i)
        end
    end

    if itemsBySource then
        for _, cat in ipairs(CAT_ORDER) do
            local items = itemsBySource[cat]
            if items and #items > 0 then
                -- Group items by boss/source sub-key
                local groups = {}
                for _, entry in ipairs(items) do
                    -- Skip higher-ranked paired-slot candidates you don't own once the pool
                    -- is already filled (e.g. two adequate weapons → don't list a 3rd BiS choice).
                    local poolDone = (not entry.item._filler)
                        and (not equippedItems[entry.item.itemId])
                        and poolSatisfied(entry.slotId, entry.item.ilvl)
                    if not poolDone then
                        local subKey = entry.item.bossName
                        if not subKey or subKey == "" then
                            subKey = cat
                        end
                        if not groups[subKey] then
                            groups[subKey] = { items = {}, missing = 0, obtained = 0 }
                        end
                        table.insert(groups[subKey].items, entry)
                        if not entry.item._filler and (equippedItems[entry.item.itemId] or (entry.item.sourceCategory == "tier" and tierSlotSatisfied(entry.slotId, entry.item.ilvl))) then
                            groups[subKey].obtained = groups[subKey].obtained + 1
                        else
                            groups[subKey].missing = groups[subKey].missing + 1
                        end
                    end
                end

                -- Sort groups by missing count (desc), then by name
                local groupOrder = {}
                for k, v in pairs(groups) do
                    table.insert(groupOrder, { key = k, missing = v.missing, obtained = v.obtained, items = v.items })
                end
                table.sort(groupOrder, function(a, b)
                    if a.missing ~= b.missing then return a.missing > b.missing end
                    return a.key < b.key
                end)

                local totalMissing = 0
                for _, g in ipairs(groupOrder) do totalMissing = totalMissing + g.missing end
                local catLabel = CAT_LABELS[cat] or cat
                if totalMissing > 0 then
                    catLabel = catLabel .. " (" .. T("FG_NEED", "缺 ") .. totalMissing .. T("FG_PCS", " 件") .. ")"
                else
                    catLabel = catLabel .. T("FG_COMPLETE", " (已齐全)")
                end
                local clr = CAT_COLORS[cat] or { 0.7, 0.7, 0.7 }

                -- 制造业不是刷本可掉的内容，做成可折叠分组（默认折叠），其余分类保持原样。
                local collapsible = (cat == "crafted")
                local collapsed = collapsible and GearInsightDB.fgCollapse[cat] and true or false

                if collapsible then
                    -- Clickable category header: arrow + label, toggles collapse on click.
                    local hbtn = nextHeaderBtn()
                    hbtn:ClearAllPoints()
                    hbtn:SetPoint("TOPLEFT", 4, yOff)
                    hbtn:SetWidth(440)
                    local arrow = collapsed and "+ " or "- "
                    hbtn._fs:SetText(arrow .. "● " .. catLabel)
                    hbtn._fs:SetTextColor(clr[1], clr[2], clr[3])
                    hbtn._cat = cat
                    hbtn:SetScript("OnClick", function(b)
                        GearInsightDB.fgCollapse = GearInsightDB.fgCollapse or {}
                        GearInsightDB.fgCollapse[b._cat] = not GearInsightDB.fgCollapse[b._cat]
                        -- Re-render in place (keepOpen) with the new collapse state.
                        local a = GearInsight._fgArgs or {}
                        GearInsight:ShowFarmingGuide(a[1], a[2], a[3], true)
                    end)
                    hbtn:Show()
                    yOff = yOff - 22

                    -- Gray explainer line: crafted gear can't be farmed from content.
                    local note = nextFS("GameFontHighlightSmall")
                    note:ClearAllPoints()
                    note:SetPoint("TOPLEFT", 18, yOff)
                    note:SetWidth(420)
                    note:SetJustifyH("LEFT")
                    note:SetText(T("FG_CRAFTED_NOTE", "制造业装备无法刷本获取，需专业制作或拍卖行购买（仅列最值得做的2个部位）"))
                    note:SetTextColor(0.55, 0.55, 0.55)
                    note:Show()
                    yOff = yOff - 16
                else
                    -- Category header with missing count (non-collapsible: plain FontString)
                    local hdr = nextFS("GameFontNormalLarge")
                    hdr:ClearAllPoints()
                    hdr:SetPoint("TOPLEFT", 4, yOff)
                    hdr:SetWidth(440)
                    hdr:SetJustifyH("LEFT")
                    hdr:SetText("● " .. catLabel)
                    hdr:SetTextColor(clr[1], clr[2], clr[3])
                    hdr:Show()
                    yOff = yOff - 22
                end

                -- Sub-groups (bosses/dungeons) sorted by missing count
                for _, group in ipairs(groupOrder) do
                  if not collapsed then
                    local showSubHeader = (cat == "raid" or cat == "mplus") and group.key ~= cat
                    if showSubHeader then
                        local subHdr = nextFS("GameFontHighlightSmall")
                        subHdr:ClearAllPoints()
                        subHdr:SetPoint("TOPLEFT", 18, yOff)
                        subHdr:SetWidth(420)
                        subHdr:SetJustifyH("LEFT")
                        local _gi = group.items[1] and group.items[1].item
                        local groupName = _gi and localizedSource(group.key, _gi.instanceId, _gi.encounterId) or group.key
                        -- 团本 BOSS 击杀顺序编号 M1-M10（按 encounterId 查，跨副本连续）
                        local RAID_BOSS_ORDER = { [2733]=1,[2734]=2,[2736]=3,[2735]=4,[2737]=5,[2738]=6,[2795]=7,[2739]=8,[2740]=9,[2711]=10 }
                        local _ord = _gi and RAID_BOSS_ORDER[_gi.encounterId]
                        if _ord then groupName = "M" .. _ord .. " " .. groupName end
                        local subText = "- " .. groupName
                        if group.missing > 0 then
                            subText = subText .. "  " .. T("FG_NEED", "缺 ") .. group.missing .. T("FG_PCS", " 件")
                        else
                            subText = subText .. T("FG_SUB_COMPLETE", "  已齐全")
                        end
                        subHdr:SetText(subText)
                        subHdr:SetTextColor(0.65, 0.65, 0.65)
                        subHdr:Show()
                        yOff = yOff - 18
                    end

                    -- Sort items: missing first, then by slotId
                    table.sort(group.items, function(a, b)
                        local aHas = equippedItems[a.item.itemId] and true or false
                        local bHas = equippedItems[b.item.itemId] and true or false
                        if aHas ~= bHas then return not aHas end
                        return (a.slotId or 0) < (b.slotId or 0)
                    end)

                    -- Items in sub-group
                    for _, entry in ipairs(group.items) do
                        local row = nextItemRow()

                        local item = entry.item
                        local slotKey = gr and gr:GetSlotKey(entry.slotId) or nil
                        local slotName = (slotKey and L[slotKey]) or ("SLOT#" .. entry.slotId)
                        local resolvedName = locName(item.itemId, item.itemName)
                        if not resolvedName and item.itemId then _fgQueueNameLoad(item.itemId) end
                        local iName = resolvedName or ("#" .. item.itemId)
                        setItemForIcon(row._icon, item.itemId, item.bonusIDs, item.link)
                        row._icon._itemIlvl = item.ilvl or 0
                        row._icon._instId   = item.instanceId
                        row._icon._bossId   = item.encounterId
                        row._icon._isRaid   = item._isRaid

                        local eqInfo = equippedItems[item.itemId]
                        local tierOwned = (not item._filler) and item.sourceCategory == "tier" and tierSlotSatisfied(entry.slotId, item.ilvl)
                        if item._filler then
                            local tgt = (item.ilvl and item.ilvl > 0) and (" |cFF888888[→" .. item.ilvl .. "]|r") or ""
                            row._txt:SetText("· " .. slotName .. " — " .. iName .. tgt .. "  |cFFB060FF" .. T("FILLER_TAG", "(坯子·催化)") .. "|r" .. T("MISSING_TAG", "  [缺]"))
                        elseif tierOwned or (eqInfo and item.ilvl and eqInfo.ilvl >= item.ilvl) then
                            row._txt:SetText("· " .. slotName .. " — " .. iName .. T("OBTAINED", "  (已获得)"))
                        elseif eqInfo then
                            row._txt:SetText("· " .. slotName .. " — " .. iName .. "  |cFFFF6600" .. T("ILVL_LOW_PRE", "(装等不足 ") .. eqInfo.ilvl .. "/" .. (item.ilvl or 0) .. ")|r")
                        else
                            row._txt:SetText("· " .. slotName .. " — " .. iName .. T("MISSING_TAG", "  [缺]"))
                        end
                        row:ClearAllPoints()
                        row:SetPoint("TOPLEFT", sc, "TOPLEFT", 0, yOff)
                        row:Show()
                        yOff = yOff - 26
                    end

                    yOff = yOff - 2  -- gap between sub-groups
                  end -- if not collapsed
                end

                yOff = yOff - 6  -- gap between categories
            end
        end
    end

    -- No data fallback
    if fsIdx == 0 and itemIdx == 0 then
        local hdr = nextFS("GameFontNormal")
        hdr:ClearAllPoints(); hdr:SetPoint("TOPLEFT", 4, 0)
        hdr:SetText(T("FG_NODATA", "暂无刷本优先级数据"))
        hdr:SetTextColor(1, 0.5, 0)
        hdr:Show()
        yOff = yOff - 20
    end
    -- Unused pooled widgets were already hidden up-front; only the ones we
    -- positioned above were Show()n, so nothing stale remains.

    sc:SetHeight(math.max(20, math.abs(yOff) + 8))

    -- Show
    if GearInsight.Skin then GearInsight.Skin.Sweep(self._fgFrame) end
    self._fgFrame:Show()
end

-- Popup listing every farmable "坯子" (Catalyst filler) for a tier slot: each row
-- is a real same-slot drop + its source, clickable to open the Encounter Journal.
-- Map an inventory slot to the Encounter Journal slot-filter enum.
local function _ejSlotFilter(slotId)
    local E = Enum and Enum.ItemSlotFilterType
    if not E then return nil end
    local m = {
        [1] = E.Head, [2] = E.Neck, [3] = E.Shoulder, [5] = E.Chest,
        [6] = E.Waist, [7] = E.Legs, [8] = E.Feet, [9] = E.Wrist,
        [10] = E.Hands, [15] = E.Cloak,
    }
    return m[slotId]
end

-- Complete same-slot drop list straight from the in-game Encounter Journal (current
-- tier dungeons + raid), filtered to the player's class. Every piece here can be
-- Catalyst-converted, so this covers items no logged player happened to wear — i.e.
-- it does NOT depend on WCL sample size. Result is cached per slot.
function GearInsight:GetCatalystSources(slotId)
    self._catalystCache = self._catalystCache or {}
    if self._catalystCache[slotId] then return self._catalystCache[slotId] end
    local slotFilter = _ejSlotFilter(slotId)
    if not slotFilter then return nil end
    local setSlot = C_EncounterJournal and C_EncounterJournal.SetSlotFilter
    local getLoot = C_EncounterJournal and C_EncounterJournal.GetLootInfoByIndex
    if not (slotFilter and setSlot and getLoot and EJ_GetInstanceByIndex and EJ_SelectInstance and EJ_GetNumLoot and EJ_SetLootFilter) then
        return nil
    end
    if C_AddOns and C_AddOns.LoadAddOn then pcall(C_AddOns.LoadAddOn, "Blizzard_EncounterJournal") end

    local _, _, classID = UnitClass("player")
    local prevClass, prevSpec = 0, 0
    if EJ_GetLootFilter then prevClass, prevSpec = EJ_GetLootFilter() end

    if EJ_SelectTier and EJ_GetNumTiers then pcall(EJ_SelectTier, EJ_GetNumTiers()) end
    pcall(EJ_SetLootFilter, classID or 0, 0)
    pcall(setSlot, slotFilter)

    local seen, out = {}, {}
    local function scan(isRaid)
        local idx = 1
        while true do
            local instanceID, instName = EJ_GetInstanceByIndex(idx, isRaid)
            if not instanceID then break end
            pcall(EJ_SelectInstance, instanceID)
            -- 只取史诗难度的掉落(团本16/地下城23),滤掉只普通/英雄难度掉的老件(如血羽皮靴)。
            -- 残缺结果不缓存(见下方),靠重试补全,所以难度过滤不会再把列表清空。
            if EJ_SetDifficulty then pcall(EJ_SetDifficulty, isRaid and 16 or 23) end
            local n = EJ_GetNumLoot() or 0
            for i = 1, n do
                local ok, info = pcall(getLoot, i)
                if ok and info and info.itemID and not seen[info.itemID] then
                    seen[info.itemID] = true
                    out[#out + 1] = {
                        itemId = info.itemID,
                        nameCn = instName,
                        link = info.link,   -- journal link w/ bonusIDs → real drop ilvl in tooltip
                        instanceId = instanceID,
                        encounterId = info.encounterID,
                        type = isRaid and "raid" or "mplus",
                    }
                end
            end
            idx = idx + 1
        end
    end
    pcall(scan, false)   -- dungeons (M+)
    pcall(scan, true)    -- raids

    -- Restore the journal's filters so we don't disturb a player who has it open.
    pcall(EJ_SetLootFilter, prevClass or 0, prevSpec or 0)
    if Enum and Enum.ItemSlotFilterType then pcall(setSlot, Enum.ItemSlotFilterType.NoFilter) end

    -- Don't cache a suspiciously short list — the journal loads loot asynchronously, so a
    -- cold first access can return only a partial list; allow a retry on the next open.
    if #out > 2 then self._catalystCache[slotId] = out end
    return out
end

function GearInsight:ShowTierFiller(armor, slotId, slotLabel, explicitSrcs, targetBonus)
    if self._tierFrame and self._tierFrame:IsShown() and self._tierFrame._slotId == slotId then
        self._tierFrame:Hide()
        return
    end
    -- Merge three sources deduped by itemId, so a cold/slow Encounter Journal (which can
    -- return only a partial list on first access) can't wipe out the stable bis-data list:
    --   explicitSrcs (bis-data same-slot drops) + curated tierFiller + EJ (complete-but-flaky).
    local curated = armor and self.BisData and self.BisData.tierFiller
        and self.BisData.tierFiller[armor] and self.BisData.tierFiller[armor][slotId]
    local srcs, seen = {}, {}
    local function _add(list)
        for _, s in ipairs(list or {}) do
            -- Crafted (制造业) gear can't be catalyzed into a tier piece — never list it as a 坯子.
            local isCrafted = (s.type == "crafted") or (s.sourceCategory == "crafted") or (s.source == "制造业")
            if s.itemId and not seen[s.itemId] and not isCrafted then
                seen[s.itemId] = true; srcs[#srcs + 1] = s
            end
        end
    end
    _add(explicitSrcs)
    _add(curated)
    _add(self:GetCatalystSources(slotId))
    if #srcs == 0 then return end

    if not self._tierFrame then
        local f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        GearInsight:RegisterEscClose(f, "GearInsightTierFrame")
        f:SetSize(420, 440)
        GearInsight:AnchorPopup(f)
        f:SetFrameStrata("DIALOG"); f:SetFrameLevel(30)
        f:SetBackdrop({
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            edgeSize = 32, insets = { left = 8, right = 8, top = 8, bottom = 8 },
        })
        f:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.9)
        local bg = f:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(); bg:SetColorTexture(0.05, 0.05, 0.08, 0.96)
        f:EnableMouse(true); f:SetMovable(true); f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", function() f:StartMoving() end)
        f:SetScript("OnDragStop", function() f:StopMovingOrSizing(); f._giUserMoved = true end)
        self._tierTitle = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        self._tierTitle:SetPoint("TOP", 0, -12)
        local hint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        hint:SetPoint("TOP", self._tierTitle, "BOTTOM", 0, -4)
        hint:SetText(T("TIER_POPUP_HINT", "催化引擎转换任意一件即可（同部位、同护甲）"))
        local cb = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        cb:SetPoint("TOPRIGHT", -4, -4); cb:SetScript("OnClick", function() f:Hide() end)
        local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 12, -50); scroll:SetPoint("BOTTOMRIGHT", -28, 14)
        local scc = CreateFrame("Frame", nil, scroll); scc:SetWidth(380)
        scroll:SetScrollChild(scc); self._tierScrollChild = scc
        self._tierFrame = f
    end
    self._tierFrame._slotId = slotId
    self._tierTitle:SetText((slotLabel or T("TIER_DEFAULT_SLOT", "套装")) .. T("TIER_POPUP_SUFFIX", " 套装坯子"))

    local sc = self._tierScrollChild
    sc.rows = sc.rows or {}
    for _, r in ipairs(sc.rows) do r:Hide() end
    local y = 0
    for i, s in ipairs(srcs) do
        local row = sc.rows[i]
        if not row then
            row = CreateFrame("Button", nil, sc); row:SetSize(370, 32)
            row.icon = row:CreateTexture(nil, "ARTWORK"); row.icon:SetSize(26, 26); row.icon:SetPoint("LEFT", 6, 0)
            row.txt = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.txt:SetPoint("LEFT", row.icon, "RIGHT", 8, 0); row.txt:SetPoint("RIGHT", -4, 0); row.txt:SetJustifyH("LEFT")
            row:SetScript("OnEnter", function(s2)
                if not s2._itemId then return end
                GameTooltip:SetOwner(s2, "ANCHOR_RIGHT")
                if s2._link then GameTooltip:SetHyperlink(s2._link)
                else GameTooltip:SetItemByID(s2._itemId) end
                GameTooltip:Show()
            end)
            row:SetScript("OnLeave", function() GameTooltip:Hide() end)
            row:RegisterForClicks("LeftButtonUp")
            row:SetScript("OnClick", function(s2) _openSourceJournal(s2._instId, s2._bossId, s2._itemId, s2._isRaid) end)
            sc.rows[i] = row
        end
        row._itemId = s.itemId; row._instId = s.instanceId; row._bossId = s.encounterId
        row._isRaid = (s.type == "raid")
        -- Show at the TARGET (BiS) ilvl: graft the set piece's bonusIDs onto the filler's
        -- itemId. Fall back to the journal link, then a bonusID link, then the base item.
        local tb = targetBonus
        if tb and #tb > 0 then
            row._link = "|Hitem:" .. s.itemId .. ":0::::::::0:::" .. #tb .. ":" .. table.concat(tb, ":") .. "|h[item]|h"
        elseif s.link then
            row._link = s.link
        elseif s.bonusIDs and #s.bonusIDs > 0 then
            row._link = "|Hitem:" .. s.itemId .. ":0::::::::0:::" .. #s.bonusIDs .. ":" .. table.concat(s.bonusIDs, ":") .. "|h[item]|h"
        else
            row._link = nil
        end
        local CATL = { raid = T("CAT_RAID", "团本"), mplus = T("CAT_MPLUS", "大秘境"), crafted = T("CAT_CRAFTED", "制造业"), world = T("CAT_WORLD", "世界掉落") }
        local srcTag = CATL[s.type] or T("CAT_MPLUS", "大秘境")
        local click = s.instanceId and ("  |cFFAAAAAA" .. T("JOURNAL_HINT", "(点击手册)") .. "|r") or ""
        local suffix = "  |cFF808080· " .. localizedSource(s.nameCn or "", s.instanceId, s.encounterId) .. " (" .. srcTag .. ")|r" .. click
        local function setRow(nm, icon)
            row.txt:SetText(nm .. suffix)
            row.icon:SetTexture(icon or 134400)
        end
        -- Names/icons load async from the client (localized zh_CN); show a placeholder
        -- until ready since uncached filler items have no name yet.
        local nm0 = getCN(s.itemId)
        setRow(nm0 or ("|cFF999999" .. T("LOADING", "加载中…") .. "|r"), C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(s.itemId))
        if not nm0 and Item and Item.CreateFromItemID then
            local it = Item:CreateFromItemID(s.itemId)
            local sid = s.itemId
            it:ContinueOnItemLoad(function()
                if row._itemId ~= sid then return end
                setRow(it:GetItemName() or ("#" .. sid), it:GetItemIcon())
            end)
        end
        row:ClearAllPoints(); row:SetPoint("TOPLEFT", 4, y); row:Show()
        y = y - 32
    end
    for i = #srcs + 1, #sc.rows do sc.rows[i]:Hide() end
    sc:SetHeight(math.max(20, math.abs(y) + 8))
    -- Size the popup to the content so few rows don't leave a big empty box.
    self._tierFrame:SetHeight(math.max(150, math.min(560, 64 + #srcs * 32 + 10)))
    if GearInsight.Skin then GearInsight.Skin.Sweep(self._tierFrame) end
    self._tierFrame:Show()
end

-- Popup: the top-5 highest-usage items for a single slot (current spec/hero
-- talent). Data comes straight from the slot's BiS candidate list, which is
-- already ordered by WCL usage. Mirrors ShowTierFiller's frame/row layout.
-- 某部位"使用率前5"参照池（始终不受团本排除影响，只随参照系变）。
-- 供前5弹窗首开与切换参照系/过滤后的原地刷新使用。
function GearInsight:_slotTop5Pool(slotId)
    local snapshot = self.SavedVars and self.SavedVars:GetLastSnapshot() or nil
    local class, spec, htal
    if snapshot then class = snapshot.class; spec = snapshot.spec; htal = snapshot.heroTalent end
    if (not class or not spec) and self.StatReader then
        local s = self.StatReader:ReadAll(); class = s.class; spec = s.spec; htal = s.heroTalent
    end
    if not (self.BisData and self.BisData.GetSlotUsagePool) then return nil end
    return self.BisData:GetSlotUsagePool(class, spec, htal, slotId)
end

function GearInsight:ShowSlotTop5(slotLabel, slotId, cands, keepOpen)
    -- 使用率前5 是"顶尖玩家使用率最高"的 meta 参照：始终展示真实前5（含团本件），
    -- 仅随 团本/大秘境 参照系变化，不受"团本装备:排除"影响。优先用未过滤池重建；
    -- 重建不可用时回退到调用方传入的 cands。
    local pool = self:_slotTop5Pool(slotId)
    if pool and #pool > 0 then cands = pool end
    if not cands or #cands == 0 then return end
    -- keepOpen=true 用于切换参照系/过滤后的原地刷新，跳过"再次点击同部位则关闭"的切换逻辑。
    if not keepOpen and self._slotTopFrame and self._slotTopFrame:IsShown() and self._slotTopFrame._slotId == slotId then
        self._slotTopFrame:Hide()
        return
    end

    if not self._slotTopFrame then
        local f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        GearInsight:RegisterEscClose(f, "GearInsightSlotTopFrame")
        f:SetSize(420, 320)
        f:SetPoint("CENTER")
        f:SetFrameStrata("DIALOG"); f:SetFrameLevel(30)
        f:SetBackdrop({
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            edgeSize = 32, insets = { left = 8, right = 8, top = 8, bottom = 8 },
        })
        f:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.9)
        local bg = f:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(); bg:SetColorTexture(0.05, 0.05, 0.08, 0.96)
        f:EnableMouse(true); f:SetMovable(true); f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", function() f:StartMoving() end)
        f:SetScript("OnDragStop", function() f:StopMovingOrSizing(); f._giUserMoved = true end)
        self._slotTopTitle = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        self._slotTopTitle:SetPoint("TOP", 0, -12)
        local hint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        hint:SetPoint("TOP", self._slotTopTitle, "BOTTOM", 0, -4)
        hint:SetText(T("TOP5_POPUP_HINT", "顶尖玩家该部位使用率最高的装备"))
        local cb = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        cb:SetPoint("TOPRIGHT", -4, -4); cb:SetScript("OnClick", function() f:Hide() end)
        -- 最多 5 行，不需要滚动，用普通 Frame 避免 UIPanelScrollFrameTemplate 自带的白圆滑块
        local scc = CreateFrame("Frame", nil, f); scc:SetPoint("TOPLEFT", 12, -50); scc:SetPoint("BOTTOMRIGHT", -8, 14)
        self._slotTopScrollChild = scc
        self._slotTopFrame = f
    end
    self._slotTopFrame._slotId = slotId
    self._slotTopFrame._slotLabel = slotLabel
    -- Title reflects the active usage reference (团本 / 大秘境) so the listed %
    -- are unambiguous and visibly track the 使用率参照 toggle.
    local modeLabel = ((GearInsightDB and GearInsightDB.usageMode) == "mplus")
        and T("USAGE_MPLUS", "大秘境") or T("USAGE_RAID", "团本")
    self._slotTopTitle:SetText((slotLabel or T("TOP5_DEFAULT_SLOT", "部位"))
        .. T("TOP5_TITLE_SUFFIX", " · 使用率前5") .. "  |cFFFFD100(" .. modeLabel .. ")|r")

    -- 数据侧回填的"备选"候选(usagePct=0,独狼模式兜底用)不属于"使用率前5"榜单，隐藏
    local nonzero = {}
    for _, e in ipairs(cands) do
        if (e.usagePct or 0) > 0 then nonzero[#nonzero + 1] = e end
    end
    if #nonzero > 0 then cands = nonzero end

    local sc = self._slotTopScrollChild
    sc.rows = sc.rows or {}
    for _, r in ipairs(sc.rows) do r:Hide() end
    local n = math.min(5, #cands)
    local y = 0
    for i = 1, n do
        local c = cands[i]
        local row = sc.rows[i]
        if not row then
            row = CreateFrame("Button", nil, sc); row:SetSize(370, 32)
            row.icon = row:CreateTexture(nil, "ARTWORK"); row.icon:SetSize(26, 26); row.icon:SetPoint("LEFT", 6, 0)
            row.txt = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.txt:SetPoint("LEFT", row.icon, "RIGHT", 8, 0); row.txt:SetPoint("RIGHT", -4, 0); row.txt:SetJustifyH("LEFT")
            row:SetScript("OnEnter", function(s2)
                if not s2._itemId then return end
                GameTooltip:SetOwner(s2, "ANCHOR_RIGHT")
                if s2._link then GameTooltip:SetHyperlink(s2._link)
                else GameTooltip:SetItemByID(s2._itemId) end
                GameTooltip:Show()
            end)
            row:SetScript("OnLeave", function() GameTooltip:Hide() end)
            row:RegisterForClicks("LeftButtonUp")
            row:SetScript("OnClick", function(s2) _openSourceJournal(s2._instId, s2._bossId, s2._itemId) end)
            sc.rows[i] = row
        end
        row._itemId = c.itemId; row._instId = c.instanceId; row._bossId = c.encounterId
        if c.bonusIDs and #c.bonusIDs > 0 then
            row._link = "|Hitem:" .. c.itemId .. ":0::::::::0:::" .. #c.bonusIDs .. ":" .. table.concat(c.bonusIDs, ":") .. "|h[item]|h"
        else
            row._link = nil
        end
        local rankColor = (i == 1) and "|cFFFFD100" or "|cFFBBBBBB"
        local pct = c.usagePct and string.format("  |cFF00FF00%.1f%%|r", c.usagePct) or ""
        local ilvl = (c.ilvl and c.ilvl > 0) and (" |cFF888888[" .. c.ilvl .. "]|r") or ""
        local click = c.instanceId and ("  |cFFAAAAAA" .. T("JOURNAL_HINT", "(点击手册)") .. "|r") or ""
        local srcStr = localizedSource(c.source or "", c.instanceId, c.encounterId)
        local suffix = (srcStr ~= "" and ("  |cFF808080· " .. srcStr .. "|r") or "") .. click
        local function setRow(nm, icon)
            row.txt:SetText(rankColor .. "#" .. i .. "|r " .. nm .. ilvl .. pct .. suffix)
            row.icon:SetTexture(icon or 134400)
        end
        local nm0 = locName(c.itemId, c.itemName)
        setRow(nm0 or ("|cFF999999" .. T("LOADING", "加载中…") .. "|r"), C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(c.itemId))
        if not nm0 and Item and Item.CreateFromItemID then
            local it = Item:CreateFromItemID(c.itemId)
            local cid = c.itemId
            it:ContinueOnItemLoad(function()
                if row._itemId ~= cid then return end
                setRow(it:GetItemName() or ("#" .. cid), it:GetItemIcon())
            end)
        end
        row:ClearAllPoints(); row:SetPoint("TOPLEFT", 4, y); row:Show()
        y = y - 32
    end
    for i = n + 1, #sc.rows do sc.rows[i]:Hide() end
    sc:SetHeight(math.max(20, math.abs(y) + 8))
    self._slotTopFrame:SetHeight(math.max(140, math.min(420, 64 + n * 32 + 10)))
    if GearInsight.Skin then GearInsight.Skin.Sweep(self._slotTopFrame) end
    self._slotTopFrame:Show()
end

-- ── Multi-spec farming planner ──────────────────────────────────────
-- Owned = equipped + bags (so off-spec items you already have don't show up).
local function _msOwnedSet()
    local owned = {}
    for slot = 1, 18 do
        local id = GetInventoryItemID and GetInventoryItemID("player", slot)
        if id then owned[id] = true end
    end
    if C_Container and C_Container.GetContainerNumSlots then
        for bag = 0, 5 do
            local n = C_Container.GetContainerNumSlots(bag) or 0
            for s = 1, n do
                local info = C_Container.GetContainerItemInfo(bag, s)
                if info and info.itemID then owned[info.itemID] = true end
            end
        end
    end
    return owned
end

-- Localized display names for internal spec codes the spec-ID API can't name yet
-- (e.g. brand-new 12.0 specs: GetSpecializationInfoByID returns empty off the active spec).
local SPEC_CODE_DISPLAY = {
    DEVAURER = T("SPEC_DEVAURER", "噬灭"),
}
local function _msSpecName(specId, fallback)
    if specId and GetSpecializationInfoByID then
        local _, nm = GetSpecializationInfoByID(specId)
        if nm and nm ~= "" then return nm end
    end
    -- specId 缺失/查不到时 fallback 是 HAVOC 这类内部大写码，不能直接示人：
    -- 先借 specIds 反查客户端本地化名（任意语言客户端都正确），再退 specRawToCN
    local raw = fallback or ""
    if SPEC_CODE_DISPLAY[raw] then return SPEC_CODE_DISPLAY[raw] end
    local bd = GearInsight.BisData
    if bd and bd.specIds and GetSpecializationInfoByID then
        local class = select(2, UnitClass("player")) or ""
        local sid = bd.specIds[class .. "/" .. raw]
        if sid then
            local ok, _, nm = pcall(GetSpecializationInfoByID, sid)
            if ok and nm and nm ~= "" then return nm end
        end
    end
    if bd and bd.specRawToCN and bd.specRawToCN[raw] then return bd.specRawToCN[raw] end
    return fallback or "?"
end

local function _msCurrentLootSpec()
    local ls = GetLootSpecialization and GetLootSpecialization() or 0
    if ls and ls > 0 then return ls end
    if GetSpecialization and GetSpecializationInfo then
        local idx = GetSpecialization()
        if idx then return (GetSpecializationInfo(idx)) end
    end
    return nil
end

function GearInsight:_msSelected()
    GearInsightDB = GearInsightDB or {}
    GearInsightDB.multiSpec = GearInsightDB.multiSpec or {}
    local key = (UnitName("player") or "?") .. "-" .. (GetRealmName and GetRealmName() or "")
    GearInsightDB.multiSpec[key] = GearInsightDB.multiSpec[key] or {}
    return GearInsightDB.multiSpec[key]
end

function GearInsight:_msRender()
    local sc = self._msScrollChild
    if not sc then return end
    sc.lines = sc.lines or {}
    sc.btns = sc.btns or {}
    sc.itemRows = sc.itemRows or {}
    for _, fs in ipairs(sc.lines) do fs:Hide() end
    for _, b in ipairs(sc.btns) do b:Hide() end
    for _, r in ipairs(sc.itemRows) do r:Hide() end
    local lineN, btnN, itemN = 0, 0, 0
    local y = -2
    local L = self.L or {}

    local function addLine(text, indent, r, g, b)
        lineN = lineN + 1
        local fs = sc.lines[lineN]
        if not fs then
            fs = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            fs:SetJustifyH("LEFT")
            sc.lines[lineN] = fs
        end
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", indent or 0, y)
        fs:SetWidth(505 - (indent or 0))
        fs:SetText(text)
        fs:SetTextColor(r or 1, g or 1, b or 1)
        fs:Show()
        y = y - 18
        return fs
    end

    -- Item row: icon + text, hover for tooltip, click opens the Adventure Guide.
    local function addItemRow(text, e, r, g, b)
        itemN = itemN + 1
        local row = sc.itemRows[itemN]
        if not row then
            row = CreateFrame("Button", nil, sc)
            row:SetHeight(18)
            row.icon = row:CreateTexture(nil, "ARTWORK")
            row.icon:SetSize(16, 16); row.icon:SetPoint("LEFT", 2, 0)
            row.txt = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.txt:SetPoint("LEFT", row.icon, "RIGHT", 4, 0); row.txt:SetJustifyH("LEFT")
            row:SetScript("OnEnter", function(s2)
                if not s2._itemId then return end
                GameTooltip:SetOwner(s2, "ANCHOR_RIGHT")
                if s2._link then GameTooltip:SetHyperlink(s2._link) else GameTooltip:SetItemByID(s2._itemId) end
                if s2._instId then
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine("|cFFAAAAAA" .. T("MS_CLICK_JOURNAL", "点击打开冒险指南") .. "|r", 0.7, 0.7, 0.7)
                end
                GameTooltip:Show()
            end)
            row:SetScript("OnLeave", function() GameTooltip:Hide() end)
            row:RegisterForClicks("LeftButtonUp")
            row:SetScript("OnClick", function(s2) _openSourceJournal(s2._instId, s2._bossId, s2._itemId, s2._isRaid) end)
            sc.itemRows[itemN] = row
        end
        local it = e.item or {}
        row._itemId = it.itemId; row._instId = it.instanceId; row._bossId = it.encounterId
        row._isRaid = e._isRaid
        if it.link then
            row._link = it.link
        elseif it.bonusIDs and #it.bonusIDs > 0 then
            row._link = "|Hitem:" .. it.itemId .. ":0::::::::0:::" .. #it.bonusIDs .. ":" .. table.concat(it.bonusIDs, ":") .. "|h[item]|h"
        else
            row._link = nil
        end
        local icon = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(it.itemId)
        row.icon:SetTexture(icon or 134400)
        if not icon and Item and Item.CreateFromItemID then
            local iid = it.itemId
            local itm = Item:CreateFromItemID(iid)
            itm:ContinueOnItemLoad(function()
                if row._itemId == iid then row.icon:SetTexture(itm:GetItemIcon() or 134400) end
            end)
        end
        row.txt:SetText(text)
        row.txt:SetTextColor(r or 0.8, g or 0.8, b or 0.8)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 10, y)
        row:SetPoint("RIGHT", sc, "RIGHT", -4, 0)
        row:Show()
        y = y - 18
        return row
    end

    local selected = self:_msSelected()
    local list = {}
    for sn, on in pairs(selected) do if on then list[#list + 1] = sn end end
    if #list == 0 then
        addLine(T("MS_PICK_HINT", "请在上方勾选你想一起刷的专精"), 4, 0.7, 0.7, 0.7)
        sc:SetHeight(40); return
    end

    local owned = _msOwnedSet()
    -- ilvl-aware ownership: if the item you own is the one equipped in this slot, it only
    -- counts as "done" when it meets the BiS ilvl — otherwise (e.g. a 套装件 below the
    -- target ilvl needing a higher 坯子) it stays a want, matching the single-spec view.
    local snap = self.SavedVars and self.SavedVars:GetLastSnapshot()
    local equippedBySlot = {}
    if snap and snap.equipped then
        for sid, eq in pairs(snap.equipped) do
            if type(eq) == "table" and not eq.empty then
                equippedBySlot[eq.slotId or sid] = eq
            end
        end
    end
    local function isOwned(id, wantIlvl, slotId)
        if not owned[id] then return false end
        local eq = slotId and equippedBySlot[slotId]
        if eq and eq.itemId == id then
            return (eq.ilvl or 0) >= (wantIlvl or 0)
        end
        return true
    end
    local plan = self.BisData and self.BisData:GetCrossSpecFarmPlan(self._msClass, list, isOwned)
    if not plan then addLine(T("MS_NODATA", "暂无数据"), 4, 0.7, 0.7, 0.7); sc:SetHeight(40); return end

    local arr = {}
    for _, g in pairs(plan) do if (g.missingCount or 0) > 0 then arr[#arr + 1] = g end end
    table.sort(arr, function(a, b) return (a.missingCount or 0) > (b.missingCount or 0) end)
    if #arr == 0 then
        addLine(T("MS_ALL_DONE", "所选专精在当前数据下都已毕业"), 4, 0.4, 1, 0.4)
        sc:SetHeight(40); return
    end

    local curLoot = _msCurrentLootSpec()

    -- Consolidate each boss's unowned wants by item; an item several selected
    -- specs want is merged into one line and flagged "多专精通用".
    local view = {}
    for _, g in ipairs(arr) do
        local byItem, order = {}, {}
        for _, w in ipairs(g.wants) do
            if not w.owned then
                local id = w.item.itemId
                if not byItem[id] then
                    local e = { item = w.item, slotId = w.slotId, specs = {} }
                    for _, u in ipairs(w.usedBy or {}) do
                        e.specs[#e.specs + 1] = _msSpecName(u.id, u.name)
                    end
                    if #e.specs == 0 then e.specs[1] = _msSpecName(w.specId, w.specName) end
                    byItem[id] = e; order[#order + 1] = id
                end
            end
        end
        if #order > 0 then
            view[#view + 1] = { g = g, order = order, byItem = byItem, missing = #order }
        end
    end
    -- Bosses/dungeons first (by missing count), 制造业/套装转换 pushed to the end.
    local CAT_RANK = { raid = 1, mplus = 2, world = 3, crafted = 4, tier = 5 }
    table.sort(view, function(a, b)
        local ra, rb = CAT_RANK[a.g.category] or 6, CAT_RANK[b.g.category] or 6
        if ra ~= rb then return ra < rb end
        return a.missing > b.missing
    end)

    for _, v in ipairs(view) do
        local g = v.g
        local recName = _msSpecName(g.recommendSpecId, g.recommendSpec)
        local RAID_BOSS_ORDER = { [2733]=1,[2734]=2,[2736]=3,[2735]=4,[2737]=5,[2738]=6,[2795]=7,[2739]=8,[2740]=9,[2711]=10 }
        local _msOrd = g.encounterId and RAID_BOSS_ORDER[g.encounterId]
        local _msName = (g.sourceName ~= "" and localizedSource(g.sourceName, g.instanceId, g.encounterId))
            or T("MS_OTHER", "其他来源")
        if _msOrd then _msName = "M" .. _msOrd .. " " .. _msName end
        addLine(string.format("%s  |cFFFF8800(缺 %d 件)|r", _msName, v.missing), 2, 1, 0.82, 0)
        if g.recommendSpecId and SetLootSpecialization then
            btnN = btnN + 1
            local btn = sc.btns[btnN]
            if not btn then
                btn = CreateFrame("Button", nil, sc, "UIPanelButtonTemplate")
                btn:SetSize(230, 20)
                btn:SetScript("OnClick", function(s2)
                    if InCombatLockdown() then GearInsight:Print(T("MS_COMBAT", "战斗中无法切换拾取专精")); return end
                    if not s2._specId then return end
                    SetLootSpecialization(s2._specId)
                    GearInsight:Print(string.format(T("MS_SET_OK", "拾取专精已设为 %s"), s2._specName or "?"))
                    -- Reflect the switch on every loot-spec button immediately. GetLootSpecialization()
                    -- only refreshes a frame later (PLAYER_LOOT_SPEC_UPDATED), so a delayed re-render
                    -- can read the stale value and leave this button enabled — making it look like the
                    -- first click did nothing. Update state optimistically so one click is enough.
                    local pool = s2:GetParent()
                    if pool and pool.btns then
                        for _, b in ipairs(pool.btns) do
                            if b._specId and b:IsShown() then
                                if b._specId == s2._specId then
                                    b:SetText(string.format(T("MS_BTN_CUR", "拾取专精: %s (当前)"), b._specName or "?")); b:Disable()
                                else
                                    b:SetText(string.format(T("MS_BTN_SET", "设为拾取专精: %s"), b._specName or "?")); b:Enable()
                                end
                            end
                        end
                    end
                end)
                sc.btns[btnN] = btn
            end
            btn._specId = g.recommendSpecId
            btn._specName = recName
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", 12, y)
            if curLoot == g.recommendSpecId then
                btn:SetText(string.format(T("MS_BTN_CUR", "拾取专精: %s (当前)"), recName)); btn:Disable()
            else
                btn:SetText(string.format(T("MS_BTN_SET", "设为拾取专精: %s"), recName)); btn:Enable()
            end
            btn:Show()
            y = y - 24
        end
        for _, id in ipairs(v.order) do
            local e = v.byItem[id]
            local slotKey = self.GearReader and self.GearReader:GetSlotKey(e.slotId) or nil
            local slotLabel = (slotKey and L[slotKey]) or ("槽" .. (e.slotId or "?"))
            local it = e.item or {}
            local nm = locName(it.itemId, it.itemNameCn or it.itemName) or ("#" .. (it.itemId or 0))
            local shared = #e.specs >= 2
            local tag = shared and ("  |cFFFFD100[" .. T("MS_SHARED", "多专精通用") .. "]|r") or ""
            local cr, cg, cb = 0.8, 0.8, 0.8
            if shared then cr, cg, cb = 1, 0.9, 0.4 end
            local isTier = it.sourceCategory == "tier" or it.source == "套装转换"
            if isTier then tag = tag .. "  |cFFB060FF" .. T("MS_TIER_NOTE", "[套装·下列坯子可催化]") .. "|r" end
            addItemRow(string.format("|cFF66CCFF[%s]|r %s — %s%s", table.concat(e.specs, "/"), slotLabel, nm, tag), e, cr, cg, cb)
            -- Inline all catalyzable 坯子 for tier slots (no click needed): full Encounter
            -- Journal list, falling back to the curated tierFiller list.
            if isTier then
                local fillers = self:GetCatalystSources(e.slotId)
                if not fillers or #fillers == 0 then
                    local armor = self.BisData and self.BisData.classArmor and self.BisData.classArmor[self._msClass]
                    fillers = armor and self.BisData.tierFiller and self.BisData.tierFiller[armor]
                        and self.BisData.tierFiller[armor][e.slotId]
                end
                local tgtIlvl = it.ilvl or 0
                local tb = it.bonusIDs   -- set piece bonusIDs → encode the BiS ilvl onto fillers
                for _, fs in ipairs(fillers or {}) do
                    if fs.type ~= "crafted" and fs.sourceCategory ~= "crafted" then
                    local flink = (tb and #tb > 0)
                        and ("|Hitem:" .. fs.itemId .. ":0::::::::0:::" .. #tb .. ":" .. table.concat(tb, ":") .. "|h[item]|h")
                        or fs.link
                    local fe = {
                        item = { itemId = fs.itemId, bonusIDs = tb or fs.bonusIDs, link = flink, ilvl = tgtIlvl,
                                 instanceId = fs.instanceId, encounterId = fs.encounterId },
                        slotId = e.slotId, specs = {}, _isRaid = (fs.type == "raid"),
                    }
                    local fname = locName(fs.itemId, fs.itemName) or ("#" .. (fs.itemId or 0))
                    local CATL = { raid = T("CAT_RAID", "团本"), mplus = T("CAT_MPLUS", "大秘境"), crafted = T("CAT_CRAFTED", "制造业"), world = T("CAT_WORLD", "世界掉落") }
                    local srcTag = CATL[fs.type] or T("CAT_MPLUS", "大秘境")
                    local tgt = tgtIlvl > 0 and string.format(" |cFF888888[→%d]|r", tgtIlvl) or ""
                    addItemRow(string.format("        |cFFB060FF└|r %s%s  |cFF808080· %s (%s)|r",
                        fname, tgt, localizedSource(fs.nameCn or "", fs.instanceId, fs.encounterId), srcTag), fe, 0.65, 0.65, 0.65)
                    end
                end
            end
        end
        y = y - 6
    end
    sc:SetHeight(math.max(40, math.abs(y) + 10))
end

function GearInsight:ShowMultiSpecPlan(class, keepOpen)
    if not class then return end
    if self._msFrame and self._msFrame:IsShown() and not keepOpen then self._msFrame:Hide(); return end
    self._msClass = class:upper()

    if not self._msFrame then
        local f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        GearInsight:RegisterEscClose(f, "GearInsightMSFrame")
        f:SetSize(560, 560); GearInsight:AnchorPopup(f)
        f:SetFrameStrata("DIALOG"); f:SetFrameLevel(25)
        f:SetBackdrop({ edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize = 32,
            insets = { left = 8, right = 8, top = 8, bottom = 8 } })
        f:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.9)
        local bg = f:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(0.05, 0.05, 0.08, 0.96)
        f:EnableMouse(true); f:SetMovable(true); f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", function() f:StartMoving() end)
        f:SetScript("OnDragStop", function() f:StopMovingOrSizing(); f._giUserMoved = true end)
        local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", 0, -12); title:SetText(T("MS_TITLE", "多专精拾取规划"))
        local hint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        hint:SetPoint("TOP", title, "BOTTOM", 0, -3)
        hint:SetText(T("MS_HINT", "勾选要一起刷的专精，每个 Boss 提示该设的拾取专精"))
        local cb = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        cb:SetPoint("TOPRIGHT", -4, -4); cb:SetScript("OnClick", function() f:Hide() end)
        self._msCheckRow = CreateFrame("Frame", nil, f)
        self._msCheckRow:SetPoint("TOPLEFT", 14, -52); self._msCheckRow:SetPoint("TOPRIGHT", -14, -52)
        self._msCheckRow:SetHeight(26)
        local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 14, -84); scroll:SetPoint("BOTTOMRIGHT", -30, 44)
        local scc = CreateFrame("Frame", nil, scroll); scc:SetWidth(510)
        scroll:SetScrollChild(scc); self._msScrollChild = scc
        -- 拾取需求单入口：按勾选的专精生成 M1–M9 逐 BOSS 文本（含掷币推荐），弹复制框
        local needBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        needBtn:SetSize(170, 24)
        needBtn:SetPoint("BOTTOM", 0, 12)
        needBtn:SetText(T("MS_NEED_BTN", "复制需求单文本"))
        needBtn:SetScript("OnClick", function() GearInsight:ShowNeedSheet() end)
        needBtn:SetScript("OnEnter", function(s2)
            GameTooltip:SetOwner(s2, "ANCHOR_TOP")
            GameTooltip:SetText(T("MS_NEED_TIP", "按上方勾选的专精生成逐BOSS需求单文本\n（拾取设置/需求装备/掷币推荐），复制后发给团长/队友"), 1, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        needBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        self._msChecks = {}
        self._msFrame = f
    end

    local specs = self.BisData and self.BisData:GetClassSpecs(self._msClass) or {}
    table.sort(specs, function(a, b) return _msSpecName(a.specId, a.specName) < _msSpecName(b.specId, b.specName) end)
    for _, ck in ipairs(self._msChecks) do ck:Hide() end
    local selected = self:_msSelected()
    local x = 0
    for i, sp in ipairs(specs) do
        local ck = self._msChecks[i]
        if not ck then
            ck = CreateFrame("CheckButton", nil, self._msCheckRow, "UICheckButtonTemplate")
            ck:SetSize(22, 22)
            ck.text = ck:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            ck.text:SetPoint("LEFT", ck, "RIGHT", 1, 0)
            ck:SetScript("OnClick", function(s2)
                local sel = GearInsight:_msSelected()
                sel[s2._specName] = s2:GetChecked() and true or nil
                GearInsight:_msRender()
            end)
            self._msChecks[i] = ck
        end
        ck._specName = sp.specName
        ck.text:SetText(_msSpecName(sp.specId, sp.specName))
        ck:SetChecked(selected[sp.specName] and true or false)
        ck:ClearAllPoints(); ck:SetPoint("LEFT", x, 0); ck:Show()
        x = x + 26 + (ck.text:GetStringWidth() or 40) + 16
    end

    self:_msRender()
    if GearInsight.Skin then GearInsight.Skin.Sweep(self._msFrame) end
    self._msFrame:Show()
end

-- 切换设置后，原地重建已打开的 刷本/多专精 弹窗（不关闭），使其同步反映新设置。
function GearInsight:_refreshOpenPopups()
    if self._fgFrame and self._fgFrame:IsShown() and self._fgArgs then
        self:ShowFarmingGuide(self._fgArgs[1], self._fgArgs[2], self._fgArgs[3], true)
    end
    if self._msFrame and self._msFrame:IsShown() and self._msClass then
        self:ShowMultiSpecPlan(self._msClass, true)
    end
    -- 使用率前5 弹窗：按当前参照系原地刷新（百分比与排序联动；池始终不受团本排除影响）。
    if self._slotTopFrame and self._slotTopFrame:IsShown() and self._slotTopFrame._slotId then
        self:ShowSlotTop5(self._slotTopFrame._slotLabel, self._slotTopFrame._slotId, nil, true)
    end
end

-- ── 拾取需求单（Loot Wishlist）────────────────────────────────────────
-- 进团前把需求一次说清：每个 BOSS 该设的专精拾取、要的装备、掷币（晦暗虚空核心，
-- 2 个 = 1 次额外拾取 roll）优先丢哪个 BOSS（BiS饰品 > 戒指/项链 > 其他按装等提升），
-- M1–M10 全列（含无需求 BOSS），生成纯文本发给团长/队友。/gi need
-- 复用 GetCrossSpecFarmPlan 的多专精合并与 ilvl-aware 归属判定（与多专精窗口同口径）。
-- 注意：对外文案（含本注释外的所有 UI 字符串）不得出现 boost/代练 等字样。

-- M1–M10 击杀顺序按副本分段（与 _msRender 的 RAID_BOSS_ORDER 一致）
local NEED_RAID_PLAN = {
    { instanceId = 1307, encounters = { 2733, 2734, 2736, 2735, 2737, 2738 } },
    { instanceId = 1314, encounters = { 2795 } },
    { instanceId = 1308, encounters = { 2739, 2740 } },
    { instanceId = 1305, encounters = { 2711 } },
}
local NEED_BOSS_ORDER = { [2733]=1, [2734]=2, [2736]=3, [2735]=4, [2737]=5,
                          [2738]=6, [2795]=7, [2739]=8, [2740]=9, [2711]=10 }

local function _needEncName(eid)
    if EJ_GetEncounterInfo then
        local n = EJ_GetEncounterInfo(eid)
        if n and n ~= "" then return n end
    end
    return "BOSS#" .. eid
end

local function _needInstName(iid)
    if EJ_GetInstanceInfo then
        local n = EJ_GetInstanceInfo(iid)
        if n and n ~= "" then return n end
    end
    return "#" .. iid
end

-- 晦暗虚空核心（额外拾取掷币）：2 个 = 在一个 BOSS 上多 roll 一次拾取。
-- wago CurrencyTypes 里同名两条（3418/3513），运行时探测取有效的那条。
local NEED_COIN_IDS = { 3418, 3513 }
local function _needCoinCount()
    if not (C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo) then return nil end
    local fallback
    for _, id in ipairs(NEED_COIN_IDS) do
        local ok, ci = pcall(C_CurrencyInfo.GetCurrencyInfo, id)
        if ok and ci and ci.name and ci.name ~= "" then
            if (ci.quantity or 0) > 0 then return ci.quantity, ci.name end
            if not fallback then fallback = { ci.quantity or 0, ci.name } end
        end
    end
    if fallback then return fallback[1], fallback[2] end
    return nil
end

function GearInsight:BuildNeedSheet()
    local st = self.StatReader and self.StatReader:ReadAll()
    local class = st and st.class and st.class:upper()
    if not class then return nil end

    -- 专精范围：沿用多专精拾取窗口的勾选；没勾过 → 当前专精
    local selected, list = self:_msSelected(), {}
    for sn, on in pairs(selected) do if on then list[#list + 1] = sn end end
    if #list == 0 and st.spec then list[1] = st.spec:upper() end
    if #list == 0 then return nil end
    table.sort(list)

    -- ownership 判定与多专精窗口完全一致（装备中的同款未到 BiS 装等 → 仍算缺）
    local owned = _msOwnedSet()
    local snap = self.SavedVars and self.SavedVars:GetLastSnapshot()
    local equippedBySlot = {}
    if snap and snap.equipped then
        for sid, eq in pairs(snap.equipped) do
            if type(eq) == "table" and not eq.empty then equippedBySlot[eq.slotId or sid] = eq end
        end
    end
    local function isOwned(id, wantIlvl, slotId)
        if not owned[id] then return false end
        local eq = slotId and equippedBySlot[slotId]
        if eq and eq.itemId == id then return (eq.ilvl or 0) >= (wantIlvl or 0) end
        return true
    end

    local plan = self.BisData and self.BisData:GetCrossSpecFarmPlan(class, list, isOwned)
    if not plan then return nil end

    local L = self.L or {}
    local gr = self.GearReader
    local function slotLabel(slotId)
        local k = gr and gr:GetSlotKey(slotId)
        return (k and L[k]) or (T("NEED_SLOT", "槽") .. tostring(slotId or "?"))
    end

    -- 团本组按 encounterId 索引；团本地区掉落（小怪，无 encounterId）按 instanceId
    -- 单独成行；其余非团本来源（含套装转换）→ 备注
    local multi = #list > 1
    local byEnc, byInstTrash, offRaid = {}, {}, {}
    local function mergeWants(ent, g)
        for _, w in ipairs(g.wants) do
            if not w.owned then
                local id = w.item.itemId
                local e = ent.byItem[id]
                if not e then
                    e = { item = w.item, slotId = w.slotId, specs = {}, _set = {} }
                    ent.byItem[id] = e; ent.order[#ent.order + 1] = id
                end
                for _, u in ipairs(w.usedBy or { { name = w.specName, id = w.specId } }) do
                    if not e._set[u.name] then
                        e._set[u.name] = true
                        e.specs[#e.specs + 1] = _msSpecName(u.id, u.name)
                    end
                end
            end
        end
    end
    for _, g in pairs(plan) do
        local hasMiss = false
        for _, w in ipairs(g.wants) do if not w.owned then hasMiss = true break end end
        if hasMiss then
            if g.encounterId then
                local ent = byEnc[g.encounterId]
                if not ent then ent = { g = g, byItem = {}, order = {} }; byEnc[g.encounterId] = ent end
                mergeWants(ent, g)
            elseif g.instanceId and g.category == "raid" then
                local ent = byInstTrash[g.instanceId]
                if not ent then ent = { g = g, byItem = {}, order = {} }; byInstTrash[g.instanceId] = ent end
                mergeWants(ent, g)
            else
                for _, w in ipairs(g.wants) do
                    if not w.owned then
                        offRaid[#offRaid + 1] = string.format("- %s(%s) · %s",
                            locName(w.item.itemId, w.item.itemNameCn or w.item.itemName) or ("#" .. w.item.itemId),
                            slotLabel(w.slotId),
                            (g.sourceName ~= "" and localizedSource(g.sourceName, g.instanceId, g.encounterId))
                                or T("NEED_SRC_OTHER", "其他来源"))
                    end
                end
            end
        end
    end

    -- ROLL币(晦暗虚空核心)推荐：按 BiS饰品 > 戒指/项链 > 其他部位(按装等提升)
    -- 给有需求的 BOSS 排掷币优先级，把当前可用次数(数量÷2)指到具体 BOSS。
    local coinQty, coinName = _needCoinCount()
    local rollRank = {}
    for eid, ent in pairs(byEnc) do
        local best
        for _, id in ipairs(ent.order) do
            local e = ent.byItem[id]
            local s = e.slotId or 0
            local prio = (s == 13 or s == 14) and 1
                or ((s == 11 or s == 12 or s == 2) and 2 or 3)
            local cur = equippedBySlot[s]
            local delta = (e.item.ilvl or 0) - ((cur and cur.ilvl) or 0)
            if not best or prio < best.prio
                or (prio == best.prio and delta > best.delta) then
                best = { prio = prio, delta = delta,
                         label = locName(id, e.item.itemNameCn or e.item.itemName) or ("#" .. id) }
            end
        end
        if best then
            rollRank[#rollRank + 1] = { eid = eid, prio = best.prio,
                                        delta = best.delta, label = best.label }
        end
    end
    table.sort(rollRank, function(a, b)
        if a.prio ~= b.prio then return a.prio < b.prio end
        if a.delta ~= b.delta then return a.delta > b.delta end
        return (NEED_BOSS_ORDER[a.eid] or 99) < (NEED_BOSS_ORDER[b.eid] or 99)
    end)
    local rolls = coinQty and math.floor(coinQty / 2) or 0
    local rollAt = {}
    for i, r in ipairs(rollRank) do
        if i <= rolls then rollAt[r.eid] = i end
    end

    -- 表头
    local name = UnitName("player") or "?"
    local realm = (GetRealmName and GetRealmName() or ""):gsub("%s+", "")
    local classLoc = UnitClass and (select(1, UnitClass("player"))) or class
    local ilvl = 0
    if GetAverageItemLevel then local _, eq = GetAverageItemLevel(); ilvl = math.floor(eq or 0) end
    local specNames = {}
    for _, sn in ipairs(list) do specNames[#specNames + 1] = _msSpecName(nil, sn) end

    local out = {}
    local function add(s) out[#out + 1] = s end
    add(string.format(T("NEED_HEADER", "【团本拾取需求单】%s-%s %s 装等%d"),
        name, realm, classLoc or class, ilvl))
    add(string.format(T("NEED_SPECLINE", "专精: %s | 难度: 史诗/英雄/普通(按所打难度保留)"),
        table.concat(specNames, "/")))
    if GearInsightDB and GearInsightDB.excludeRaid then
        add(T("NEED_NORAID_WARN", "※ 当前开启了「团本排除」，团本需求未列出——/gi noraid off 后重新生成"))
    end
    add("")

    local needCount = 0
    for _, seg in ipairs(NEED_RAID_PLAN) do
        add("◆ " .. _needInstName(seg.instanceId))
        local tr = byInstTrash[seg.instanceId]
        if tr then
            local lootSpec = _msSpecName(tr.g.recommendSpecId, tr.g.recommendSpec)
            local items = {}
            for _, id in ipairs(tr.order) do
                local e = tr.byItem[id]
                local nm = locName(id, e.item.itemNameCn or e.item.itemName) or ("#" .. id)
                local tag = slotLabel(e.slotId)
                if multi and #e.specs > 0 then tag = tag .. "," .. table.concat(e.specs, "/") end
                items[#items + 1] = string.format("%s(%s)", nm, tag)
                needCount = needCount + 1
            end
            add(string.format("%s | %s%s | %s%s",
                T("NEED_TRASH", "小怪(全程地区掉落)"),
                T("NEED_LOOTSET", "拾取设置:"), lootSpec,
                T("NEED_ITEMS", "需求: "), table.concat(items, "、")))
        end
        for _, eid in ipairs(seg.encounters) do
            local mOrd = NEED_BOSS_ORDER[eid] or 0
            local ent = byEnc[eid]
            local parts = {}
            if ent then
                local lootSpec = _msSpecName(ent.g.recommendSpecId, ent.g.recommendSpec)
                parts[#parts + 1] = T("NEED_LOOTSET", "拾取设置:") .. lootSpec
                local items = {}
                for _, id in ipairs(ent.order) do
                    local e = ent.byItem[id]
                    local nm = locName(id, e.item.itemNameCn or e.item.itemName) or ("#" .. id)
                    local tag = slotLabel(e.slotId)
                    if multi and #e.specs > 0 then tag = tag .. "," .. table.concat(e.specs, "/") end
                    items[#items + 1] = string.format("%s(%s)", nm, tag)
                    needCount = needCount + 1
                end
                parts[#parts + 1] = T("NEED_ITEMS", "需求: ") .. table.concat(items, "、")
            end
            if rollAt[eid] then
                parts[#parts + 1] = string.format(T("NEED_ROLLAT", "★ROLL币第%d优先"), rollAt[eid])
            end
            if #parts == 0 then parts[1] = T("NEED_FREE", "自由分配,无需求") end
            add(string.format("M%d %s | %s", mOrd, _needEncName(eid), table.concat(parts, " | ")))
        end
    end

    add("")
    add("————")
    add(string.format(T("NEED_TOTAL", "合计: 需求装备%d件"), needCount))
    if #rollRank > 0 then
        if coinQty then
            add(string.format(T("NEED_COIN_HAVE", "ROLL币(%s): 现有%d个 = 可额外掷%d次"),
                coinName or T("NEED_COIN_NAME", "晦暗虚空核心"), coinQty, rolls))
        else
            add(T("NEED_COIN_UNKNOWN", "ROLL币(晦暗虚空核心): 数量未读到,按下列顺序使用"))
        end
        local seq = {}
        for i, r in ipairs(rollRank) do
            if i > 4 then break end
            seq[#seq + 1] = string.format("%d.M%d(%s)", i, NEED_BOSS_ORDER[r.eid] or 0, r.label)
        end
        add(T("NEED_COIN_ORDER", "掷币优先: ") .. table.concat(seq, "  "))
    end
    if needCount > 0 then
        add(T("NEED_REMIND", "打前提醒: 有拾取设置的BOSS,开打前先切专精拾取(拾取选项→专精拾取)"))
    end
    if #offRaid > 0 then
        add(T("NEED_OFFRAID", "本团本拿不到,另行安排:"))
        for i, line in ipairs(offRaid) do
            if i > 8 then add(string.format(T("NEED_OFFRAID_MORE", "- (等%d件,见插件刷本优先级)"), #offRaid - 8)) break end
            add(line)
        end
    end
    add(T("NEED_FOOTER", "—— GearInsight 生成 · gearinsight.app"))
    return table.concat(out, "\n")
end

function GearInsight:ShowNeedSheet()
    local str = self:BuildNeedSheet()
    if not str then
        self:Print(T("NEED_NODATA", "无法生成需求单：请先打开面板或 /gi refresh 刷新装备数据"))
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
    self:RegisterEscClose(dimmer, "GearInsightNeedDimmer")

    local box = CreateFrame("Frame", nil, dimmer, "BackdropTemplate")
    box:SetSize(560, 520)
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
    title:SetText(T("NEED_TITLE", "拾取需求单 · 发给团长/队友"))

    local hint = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOP", title, "BOTTOM", 0, -8)
    hint:SetWidth(520)
    hint:SetJustifyH("CENTER")
    hint:SetText(T("NEED_HINT", "Ctrl+C 复制；可先在框内直接编辑（删难度、改措辞）再复制。专精范围跟随「多专精拾取」勾选。"))
    hint:SetTextColor(0.7, 0.7, 0.7)

    local sf = CreateFrame("ScrollFrame", nil, box, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 16, -62)
    sf:SetPoint("BOTTOMRIGHT", -34, 50)
    local edit = CreateFrame("EditBox", nil, sf)
    edit:SetMultiLine(true)
    edit:SetFontObject("GameFontHighlightSmall")
    edit:SetWidth(496)
    edit:SetAutoFocus(true)
    edit:SetText(str)
    edit:HighlightText()
    edit:SetScript("OnEscapePressed", function() dimmer:Hide() end)
    sf:SetScrollChild(edit)

    local closeBtn = CreateFrame("Button", nil, box, "UIPanelButtonTemplate")
    closeBtn:SetSize(90, 24)
    closeBtn:SetPoint("BOTTOM", 0, 12)
    closeBtn:SetText(T("CLOSE_SHORT", "关闭"))
    closeBtn:SetScript("OnClick", function() dimmer:Hide() end)
    if GearInsight.Skin then GearInsight.Skin.Sweep(dimmer) end
end

-- 使用率参考系：团本 / 大秘境。换算 BisData 内候选并刷新已开界面。
function GearInsight:SetUsageMode(mode)
    GearInsightDB = GearInsightDB or {}
    GearInsightDB.usageMode = mode
    if self.BisData and self.BisData.SetUsageMode then
        self.BisData:SetUsageMode(mode)
    end
    if self._panelFrame then self:RefreshPanel() end
    self:_refreshOpenPopups()
    if self._modeBtnRefresh then self._modeBtnRefresh() end
    local label = (mode == "mplus") and "大秘境" or "团本"
    self:Print(T("USAGE_MODE_SET", "使用率参照系已切换为：") .. label)
end

-- 排除团本装备：独狼/不打团本玩家只推荐大秘境/制造/坯子等非团本来源。
function GearInsight:SetExcludeRaid(on)
    GearInsightDB = GearInsightDB or {}
    GearInsightDB.excludeRaid = on and true or false
    if self.BisData then
        self.BisData._filterSig = nil
        if self.BisData.ApplyDataFilters then self.BisData:ApplyDataFilters() end
    end
    if self._panelFrame then self:RefreshPanel() end
    self:_refreshOpenPopups()
    if self._exRaidRefresh then self._exRaidRefresh() end
    self:Print(GearInsightDB.excludeRaid
        and T("EXRAID_ON", "已排除团本装备：只推荐大秘境/制造等非团本来源")
        or T("EXRAID_OFF", "已恢复：推荐含团本装备"))
end

-- 装备难度档（玩家需求：英雄 BiS / 普通 BiS）。装等换算在 core/TierView.lua，
-- 此处只做设置入口 + 已开界面刷新（流程对齐 SetExcludeRaid）。
function GearInsight:GearTierLabel(tier)
    tier = tier or (self.GetGearTier and self:GetGearTier()) or "mythic"
    if tier == "heroic" then return T("TIER_HEROIC", "英雄") end
    if tier == "normal" then return T("TIER_NORMAL", "普通") end
    return T("TIER_MYTHIC", "史诗")
end

function GearInsight:SetGearTier(tier)
    GearInsightDB = GearInsightDB or {}
    GearInsightDB.gearTier = (tier ~= "mythic") and tier or nil
    if self.InvalidateTierView then self:InvalidateTierView() end
    if self.BisData and self.BisData.ApplyDataFilters then self.BisData:ApplyDataFilters() end
    if self._panelFrame then self:RefreshPanel() end
    self:_refreshOpenPopups()
    if self.RefreshPaperDollBis then self.RefreshPaperDollBis() end
    self:Print(T("TIER_SET", "BiS 参照难度档：") .. self:GearTierLabel()
        .. (self:GearTierStep() > 0
            and T("TIER_SET_NOTE", "（装等按该档可获取数值换算；使用率仍为顶尖玩家参照）") or ""))
end

-- 网页版角色主页 URL：gearinsight.app SSR 角色页(战力评分/AI教练/BiS缺件)。
-- 路由契约 /wow/en/c/{region}/{server}/{name}：region 小写(us/kr/eu/tw/cn)，
-- server 空格转连字符(站点端再小写归一)，国服中文服务器名直接可用(WCL 同名)。
function GearInsight:CharProfileURL()
    local name = UnitName and UnitName("player")
    local realm = (GetRealmName and GetRealmName()) or ""
    local regionMap = { "us", "kr", "eu", "tw", "cn" }
    local region = regionMap[(GetCurrentRegion and GetCurrentRegion()) or 0]
    if not name or name == "" or realm == "" or not region then return nil end
    realm = realm:gsub("%s+", "-"):lower()
    return "https://gearinsight.app/wow/en/c/" .. region .. "/" .. realm .. "/" .. name
end

function GearInsight:ShowWebProfileDialog()
    local url = self:CharProfileURL()
    if not url then
        self:Print(T("WEB_URL_FAIL", "角色信息未就绪，稍后再试"))
        return
    end
    local dimmer = CreateFrame("Frame", nil, UIParent)
    dimmer:SetAllPoints()
    dimmer:SetFrameStrata("DIALOG")
    dimmer:EnableMouse(true)
    local dbg = dimmer:CreateTexture(nil, "BACKGROUND")
    dbg:SetAllPoints()
    dbg:SetColorTexture(0, 0, 0, 0.6)
    dimmer:SetScript("OnMouseDown", function(d) d:Hide() end)
    self:RegisterEscClose(dimmer, "GearInsightWebProfileDimmer")

    local box = CreateFrame("Frame", nil, dimmer)
    box:SetSize(380, 150)
    box:SetPoint("CENTER")
    box:EnableMouse(true)
    local boxBg = box:CreateTexture(nil, "BACKGROUND")
    boxBg:SetAllPoints()
    boxBg:SetColorTexture(0.08, 0.08, 0.12, 0.95)
    local boxBorder = box:CreateTexture(nil, "BORDER")
    boxBorder:SetAllPoints()
    boxBorder:SetColorTexture(0.3, 0.3, 0.5, 0.8)
    local boxInner = box:CreateTexture(nil, "ARTWORK")
    boxInner:SetPoint("TOPLEFT", 2, -2)
    boxInner:SetPoint("BOTTOMRIGHT", -2, 2)
    boxInner:SetColorTexture(0.12, 0.12, 0.18, 0.95)

    local title = box:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -14)
    title:SetText(T("WEB_TITLE", "网页版角色主页"))

    local edit = CreateFrame("EditBox", nil, box, "InputBoxTemplate")
    edit:SetSize(340, 28)
    edit:SetPoint("TOP", title, "BOTTOM", 0, -10)
    edit:SetFontObject("GameFontHighlightSmall")
    edit:SetTextInsets(8, 8, 4, 4)
    edit:SetText(url)
    edit:SetCursorPosition(0); edit:HighlightText()
    edit:SetScript("OnEscapePressed", function() dimmer:Hide() end)
    edit:SetScript("OnEnterPressed", function() dimmer:Hide() end)
    -- 防误改：点击重新全选（内容只读语义）
    edit:SetScript("OnTextChanged", function(e, user)
        if user then e:SetText(url); e:HighlightText() end
    end)

    local hint = box:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("TOP", edit, "BOTTOM", 0, -4)
    hint:SetText(T("WEB_HINT", "按 Ctrl+C 复制，浏览器打开：战力评分 / AI 教练 / BiS 缺件"))
    hint:SetTextColor(0.6, 0.6, 0.6)

    local closeBtn = CreateFrame("Button", nil, box, "UIPanelButtonTemplate")
    closeBtn:SetSize(80, 24)
    closeBtn:SetPoint("BOTTOM", 0, 12)
    closeBtn:SetText(T("CLOSE_SHORT", "关闭"))
    closeBtn:SetScript("OnClick", function() dimmer:Hide() end)
    if GearInsight.Skin then GearInsight.Skin.Sweep(dimmer) end
end

-- ── Data + events ───────────────────────────────────────────────────
function GearInsight:RefreshData(showMessage)
    if not self.GearReader or not self.StatReader then
        if showMessage then self:Print(T("REFRESH_FAIL", "刷新失败：数据模块未就绪")) end
        return false
    end
    if self.SavedVars then self.SavedVars:Save() end
    -- 装备/专精已变，失效 tooltip 的当前专精缓存（TooltipHook:Inject 用）。
    if self.TooltipHook then self.TooltipHook._specCache = nil end
    local panelUpdated = false
    if self._panelFrame then
        self:RefreshPanel()
        panelUpdated = true
    end
    if showMessage then
        if panelUpdated then
            self:Print(T("REFRESHED", "装备数据已刷新"))
        else
            self:Print(T("REFRESHED_NOPANEL", "装备数据已刷新；面板尚未打开，输入 /gi 查看"))
        end
    end
    return true
end

function GearInsight:PrintStatus()
    local snap = self.SavedVars and self.SavedVars:GetLastSnapshot() or nil
    if not snap then self:Print("No data yet."); return end
    local data = self.BisData and self.BisData:GetSpecData(snap.class, snap.spec, snap.heroTalent)
    local t = data and data.graduationItemLevel or 0
    self:Print(string.format("%s %s ilvl=%d target=%d", snap.class or "?", snap.spec or "?", snap.itemLevel or 0, t))
end

-- ── 悬浮提示设置菜单：本职业各专精逐个勾选 + 其它职业开关 ──────────────
-- 配置存 GearInsightDB.tooltipBis（cfg() 见 ui/TooltipHook.lua）：
--   hiddenSpecs["CLASS/SPEC"]=true → 该本职业专精不显示；showOthers → 其它职业行
function GearInsight:ShowTooltipBisMenu(anchor)
    local getCfg = GearInsight._tooltipBisCfg
    local c = getCfg and getCfg()
    if not c then return end
    if not (MenuUtil and MenuUtil.CreateContextMenu) then
        self:Print(T("TTBIS_MENU_NA", "当前客户端不支持菜单，请用命令: /gi tooltip others（其它职业开关）| on|off|current|all"))
        return
    end
    -- 当前职业/专精（与 TooltipHook 同源：StatReader）
    local class, spec
    if self.StatReader then
        local ok, st = pcall(function() return self.StatReader:ReadAll() end)
        if ok and st then class, spec = st.class, st.spec end
    end
    -- 本职业其它专精列表（从 BiS 数据键去重；含 12.x 新增第四专精）
    local bd = self.BisData
    local others, seen = {}, {}
    if class and bd and bd.specs then
        for key in pairs(bd.specs) do
            local kc, ks = key:match("^([^/]+)/([^/]+)/")
            if kc == class and ks and ks ~= spec and not seen[ks] then
                seen[ks] = true
                others[#others + 1] = ks
            end
        end
        table.sort(others)
    end
    local function specCN(raw)
        local sid = bd and bd.specIds and bd.specIds[(class or "") .. "/" .. raw]
        if sid and GetSpecializationInfoByID then
            local ok, _, nm = pcall(GetSpecializationInfoByID, sid)
            if ok and nm and nm ~= "" then return nm end
        end
        return (bd and bd.specRawToCN and bd.specRawToCN[raw]) or raw
    end
    MenuUtil.CreateContextMenu(anchor, function(_, root)
        root:CreateTitle(T("TTBIS_MENU_TITLE", "显示设置 · 物品悬浮提示 BiS 排名"))
        root:CreateCheckbox(T("TTBIS_MENU_ENABLE", "启用悬浮提示"),
            function() return c.enabled and c.mode ~= "off" end,
            function()
                c.enabled = not (c.enabled and c.mode ~= "off")
                if c.enabled and c.mode == "off" then c.mode = "all" end
            end)
        if #others > 0 then
            root:CreateDivider()
            root:CreateTitle(T("TTBIS_MENU_SAMECLASS", "本职业其它专精（勾选=显示）"))
            for _, raw in ipairs(others) do
                local k = class .. "/" .. raw
                root:CreateCheckbox(specCN(raw),
                    function() return not c.hiddenSpecs[k] end,
                    function() c.hiddenSpecs[k] = (not c.hiddenSpecs[k]) and true or nil end)
            end
        end
        root:CreateDivider()
        root:CreateCheckbox(T("TTBIS_MENU_OTHERS", "显示其它职业"),
            function() return c.showOthers and true or false end,
            function() c.showOthers = not c.showOthers end)
        -- 角色面板(C键) BiS 图标开关与 tooltip 配置共用本菜单（cfg 见 ui/PaperDollBis.lua）
        local pdbCfg = GearInsight._paperDollBisCfg and GearInsight._paperDollBisCfg()
        if pdbCfg then
            root:CreateDivider()
            root:CreateCheckbox(T("PDB_MENU_TOGGLE", "角色面板(C键)显示 BiS 图标"),
                function() return pdbCfg.enabled and true or false end,
                function()
                    pdbCfg.enabled = not pdbCfg.enabled
                    if GearInsight.RefreshPaperDollBis then GearInsight.RefreshPaperDollBis() end
                end)
            -- 大小/位置子菜单(玩家反馈：默认右上16px会挡住装等数字)。
            -- 选完返回 Refresh 保持菜单打开，开着角色面板即时看效果。
            local function reapply()
                if GearInsight.RefreshPaperDollBis then GearInsight.RefreshPaperDollBis() end
                return MenuResponse and MenuResponse.Refresh
            end
            local sizeMenu = root:CreateButton(T("PDB_MENU_SIZE", "BiS 图标大小"))
            for _, sz in ipairs({ 12, 14, 16, 20, 24 }) do
                sizeMenu:CreateRadio(sz .. "px",
                    function() return pdbCfg.iconSize == sz end,
                    function() pdbCfg.iconSize = sz; return reapply() end)
            end
            local posMenu = root:CreateButton(T("PDB_MENU_POS", "BiS 图标位置"))
            for _, p in ipairs({
                { "TOPLEFT",     T("PDB_POS_TL", "左上") },
                { "TOPRIGHT",    T("PDB_POS_TR", "右上") },
                { "BOTTOMLEFT",  T("PDB_POS_BL", "左下") },
                { "BOTTOMRIGHT", T("PDB_POS_BR", "右下") },
            }) do
                posMenu:CreateRadio(p[2],
                    function() return pdbCfg.iconPos == p[1] end,
                    function() pdbCfg.iconPos = p[1]; return reapply() end)
            end
        end
        -- 组队悬停看队友 BiS 毕业度开关（功能在 ui/InspectBis.lua，默认关闭，opt-in；
        -- 全局存 GearInsightDB.inspectBisOn；tooltip 下次悬停即生效，无需刷新）
        root:CreateDivider()
        root:CreateCheckbox(T("GROUPBIS_MENU_TOGGLE", "组队悬停显示队友 BiS 毕业度"),
            function() GearInsightDB = GearInsightDB or {}; return GearInsightDB.inspectBisOn and true or false end,
            function()
                GearInsightDB = GearInsightDB or {}
                GearInsightDB.inspectBisOn = (not GearInsightDB.inspectBisOn) or nil
            end)
        -- 装备难度档（数据全局）：英雄/普通玩家按所在档看装等与毕业判定
        root:CreateDivider()
        root:CreateTitle(T("TIER_MENU_TITLE", "BiS 参照难度档（装等/毕业判定按档换算）"))
        for _, t in ipairs({
            { "mythic", T("TIER_MYTHIC", "史诗") .. T("TIER_MYTHIC_SUFFIX", "（默认·顶尖原始数据）") },
            { "heroic", T("TIER_HEROIC", "英雄") },
            { "normal", T("TIER_NORMAL", "普通") },
        }) do
            root:CreateRadio(t[2],
                function() return GearInsight:GetGearTier() == t[1] end,
                function()
                    GearInsight:SetGearTier(t[1])
                    return MenuResponse and MenuResponse.Refresh
                end)
        end
    end)
end

function GearInsight:PrintHelp()
    self:Print(T("HELP_LINE", "/gi - 面板 | /gi farming - 刷装指南 | /gi need - 拾取需求单 | /gi team - 团队BiS体检 | /gi guild - 公会花名册 | /gi cbis - 角色面板BiS图标开关 | /gi status - 状态 | /gi refresh - 刷新 | /gi dumpids - 导出ID | /gi help"))
end

-- ── Init ─────────────────────────────────────────────────────────────
if not GearInsightDB then GearInsightDB = {} end
GearInsight.GearReader  = GearInsight.GearReader
GearInsight.StatReader  = GearInsight.StatReader
GearInsight.BisData     = GearInsight.BisData
GearInsight.SavedVars   = GearInsight.SavedVars
GearInsight.RecsReader  = GearInsight.RecsReader
-- 全局装等归一化（0.35.0 原修复在 0.35.1 数据重生成时丢失，现固化在本文件——
-- GearInsight.lua 非生成文件，不会再被管线覆盖）：同一 itemId 在不同专精数据里
-- 存的是该专精样本最常见档（如 强力姿态马裤 263/276/289 混存），统一抬到全数据
-- 最高装等版本，连同该版本的 bonusIDs/stats（二者必须同源，否则 tooltip 装等对不上）。
do
    local bd = GearInsight.BisData
    if bd and bd.specs then
        local best = {}
        for _, spec in pairs(bd.specs) do
            for _, cands in pairs(spec.bisBySlot or {}) do
                for _, c in ipairs(cands) do
                    local b = best[c.itemId]
                    if not b or (c.ilvl or 0) > (b.ilvl or 0) then best[c.itemId] = c end
                end
            end
        end
        for _, spec in pairs(bd.specs) do
            for _, cands in pairs(spec.bisBySlot or {}) do
                for _, c in ipairs(cands) do
                    local b = best[c.itemId]
                    if b and b ~= c and (b.ilvl or 0) > (c.ilvl or 0) then
                        c.ilvl = b.ilvl
                        c.bonusIDs = b.bonusIDs
                        c.stats = b.stats
                    end
                end
            end
        end
    end
end

if GearInsight.MinimapButton then
    pcall(GearInsight.MinimapButton.Create, GearInsight.MinimapButton, GearInsight)
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
        C_Timer.After(5, function()
            -- GearInsight:Print(T("QQ_JOIN", "加入QQ交流群获取最新数据更新：|cFFFFFF00954673901|r"))--lnui
        end)
    end
end)

-- GearInsight:Print(T("LOADED", "已加载 /gi 打开面板"))

