-- GearInsight/main/TalentPicker.lua — 天赋选择器
-- 2026-09-22 从 GearInsight.lua 拆出（纯搬家，逻辑未动）。共用 helper 见 GearInsight.lua 末尾的 GearInsight.Helpers。
local H = GearInsight.Helpers
local T, _LOCALE = H.T, H.LOCALE

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
            -- 2026-09-20：⛔ 不再替玩家 EnableAddOn（用户「模块我没加载为啥一点就开了」）。禁用的就告诉他去插件列表勾 / 面板「天赋」页点按钮。
            if tostring(reason) == "DISABLED" then
                self:Print(T("TALENT_LOD_DISABLED", "天赋库模块（GearInsight_Talents）在插件列表里是禁用的；要用请在插件列表勾上后 /reload，或到面板「天赋」页点「启用并加载」。"))
                return
            end
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
        -- 「清理导入档」：删掉本插件导入的全部 GI- 载入档（玩家 2026-09-10 反馈导多了清不干净）
        local clr = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        clr:SetSize(132, 20); clr:SetPoint("TOPRIGHT", -30, -10)
        clr:SetScript("OnClick", function() GearInsight:ConfirmClearImportedLoadouts() end)
        clr:SetScript("OnEnter", function(s)
            GameTooltip:SetOwner(s, "ANCHOR_LEFT")
            GameTooltip:SetText(T("TAL_CLEAR_TIP", "删除本插件导入的全部载入档（名字以 GI- 开头）。\n你自己建的档和正在用的档不动。"), 1, 0.82, 0, 1, true)
            GameTooltip:Show()
        end)
        clr:SetScript("OnLeave", function() GameTooltip:Hide() end)
        f._clearBtn = clr
        f._rows = {}
        self._talentPickerFrame = f
    end
    -- ⛔ ESC 归属（2026-09-10 用户：「关闭窗口再打开第一下是空的」）：
    --    嵌入模式下这个框不能留在 UISpecialFrames 里 —— 按 ESC 时 WoW 会把它单独藏掉，
    --    主面板还开着/再开时页签仍是「天赋」，页身却是空的。嵌入时把全局名摘掉让
    --    CloseSpecialWindows 找不到它，ESC 交给主面板统一处理；弹窗模式再登记回去。
    if embed then
        _G["GearInsightTalentPicker"] = nil
    else
        GearInsight:RegisterEscClose(f, "GearInsightTalentPicker")
    end
    -- 嵌入模式：寄宿到主面板「天赋」标签页里（去边框/关闭钮/拖动，铺满页身）
    if embed and self._talentHost then
        -- ⛔ 每次嵌入都重新锚定 + 显示（用户 2026-09-18 截图：天赋页整页空白）——
        --   之前只在「父级不同」时才做，弹窗模式 Hide 过 / Esc 关过之后再回到页签，父级没变但帧是 Hide 的，就一片黑。
        if f:GetParent() ~= self._talentHost then f:SetParent(self._talentHost) end
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", 0, -34)
        f:SetPoint("BOTTOMRIGHT", 0, 0)
        f:SetFrameStrata("HIGH")
        f:SetFrameLevel(self._talentHost:GetFrameLevel() + 1)
        f:SetBackdrop(nil)
        f:SetMovable(false)
        if f._giClose then f._giClose:Hide() end
        f:Show()
    end
    f._title:SetText(T("TALENT_PICK_TITLE", "WCL 顶尖天赋库"))
    f._hint:SetText(T("TALENT_PICK_HINT", "点标题切 boss/副本 · 点一行复制该套导入串"))
    self:RefreshClearLoadoutsButton()

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
    -- 三档各自的取样基准写在标题上（2026-09-01 用户：「团本冲分跟割草标一下当前的基准层数」）。
    -- ⛔ 冲分是 WCL bracket=0（不限层的最高层榜），**没有固定层数**，不许编一个数字上去；
    --    割草是 bracket=11 = 恰好 +12，这个可以写死。团本按难度取样（史诗优先，不足退英雄）。
    -- 层数从 WCL 原始榜单的 bracketData 现算（generate 时烤进 PopularTalentsMeta），
    -- ⛔ 不许写死一个估计值：冲分是不限层的榜，实际层数每周都在动。
    local tmeta = _G.GearInsightPopularTalentsMeta or {}
    local function levelTag(key, fallback)
        local m = tmeta[key]
        if not m or not m.median then return fallback end
        if m.min and m.max and m.min ~= m.max then
            return string.format(T("MLEVEL_FMT", "+%d 层（本周 +%d~+%d）"), m.median, m.min, m.max)
        end
        return string.format(T("MLEVEL_FMT_ONE", "+%d 层"), m.median)
    end
    local CONTENT = {
        { "raid", T("CONTENT_RAID", "团本"), T("MLEVEL_RAID2", "M 史诗 · H 英雄") },
        { "mplusHigh", T("CONTENT_PUSH", "冲分"), levelTag("mplusHigh", T("MLEVEL_HIGH", "不限层·当周最高层榜")) },
        { "mplusFarm", T("CONTENT_FARM", "割草"), levelTag("mplusFarm", T("MLEVEL_FARM", "+12 层")) },
        -- 常规（打次数）：+12 排名 300~500 附近 5 人，多为 +2，贴近集合石野队（09-25 玩家 耐奥祖兔兔 建议）
    }
    -- 每内容当前选中的 boss/副本下标（按专精记忆）
    self._talentSel = self._talentSel or {}
    if f._specID ~= specID then self._talentSel = {}; f._specID = specID end
    local sel = self._talentSel

    local render
    render = function()
        for _, r in ipairs(f._rows) do r:Hide() end
        -- 滚动区（09-25 用户截图「天赋页没修好？」：加了「常规」档后 PvP 画到面板外）：
        --   行全放进滚动子帧，内容再长也关在面板里，超出就滚。老会话里已建的行一并挪进来。
        if not f._sc then
            local sc = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
            sc:SetPoint("TOPLEFT", 0, -46); sc:SetPoint("BOTTOMRIGHT", -26, 8)
            local ct = CreateFrame("Frame", nil, sc); ct:SetSize(440, 10); sc:SetScrollChild(ct)
            f._sc, f._ct = sc, ct
            for _, r in ipairs(f._rows) do r:SetParent(ct) end
        end
        local y, ri = -50, 0
        -- 两栏（09-25 用户截图「UI优化」：加了「常规」一档后 PvP 画出面板外、右半边整块空着）：
        --   嵌在主面板里且够宽 → 左栏 团本 + 冲分、右栏 割草 + 常规，PvP 通栏放下面；窄（弹窗）照旧单栏
        -- 宽度优先读宿主（嵌入时刚锚定完，f 自己的宽度有时还没算出来 = 0 → 两栏永远不触发）；再扣掉滚动条
        local W = f:GetWidth() or 0
        if embed and self._talentHost and (self._talentHost:GetWidth() or 0) > W then W = self._talentHost:GetWidth() end
        local fullW = math.max(438, math.floor((W > 100 and W or 460) - 22 - 26))
        local twoCol = embed and fullW >= 860
        local colW = twoCol and math.floor((fullW - 16) / 2) or 438
        local rowX, rowW, yTop, yCol1 = 11, colW, y, nil
        local function getRow(h)
            ri = ri + 1
            local row = f._rows[ri]
            if not row then
                row = CreateFrame("Button", nil, f._ct)
                local hl = row:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints()
                hl:SetColorTexture(1, 0.82, 0, 0.16)
                row.txt = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                row.txt:SetPoint("LEFT", 10, 0); row.txt:SetPoint("RIGHT", -8, 0); row.txt:SetJustifyH("LEFT")
                -- ⛔ 行高是写死的（18/22），文字一换行就压到下一行上（2026-09-10 PvP 档截图）。
                --    装不下宁可截断；真正长的信息放悬浮。
                if row.txt.SetWordWrap then row.txt:SetWordWrap(false) end
                if row.txt.SetMaxLines then row.txt:SetMaxLines(1) end
                -- 美化（用户 2026-09-10「整个页面可以更美观不」）：档标题一条色带 + 左侧金色竖条，
                -- 数据行浅斑马纹。⛔ 都是 BACKGROUND 层的纯色块，不动任何文字/行高/点击逻辑。
                row.bg = row:CreateTexture(nil, "BACKGROUND"); row.bg:SetAllPoints(); row.bg:Hide()
                row.accent = row:CreateTexture(nil, "BORDER"); row.accent:SetWidth(3)
                row.accent:SetPoint("TOPLEFT", 0, -2); row.accent:SetPoint("BOTTOMLEFT", 0, 2)
                row.accent:SetColorTexture(1, 0.82, 0, 0.9); row.accent:Hide()
                f._rows[ri] = row
            end
            row:SetSize(rowW, h or 18)
            if row._giSep then row._giSep:Hide() end   -- 上一轮可能是分隔行，复用时先藏线
            row.bg:Hide(); row.accent:Hide()            -- 行会被复用：样式每次重设
            row:ClearAllPoints(); row:SetPoint("TOPLEFT", f._ct, "TOPLEFT", rowX, y + 46); row:Show(); y = y - (h or 18) - 1
            return row
        end
        -- kind: "hdr" = 档标题（色带+竖条）；数字 = 第几条数据行（偶数行铺浅底）
        local function styleRow(row, kind)
            if kind == "hdr" then
                row.bg:SetColorTexture(1, 0.82, 0, 0.07); row.bg:Show(); row.accent:Show()
                row.txt:ClearAllPoints(); row.txt:SetPoint("LEFT", 12, 0); row.txt:SetPoint("RIGHT", -8, 0)
            else
                row.txt:ClearAllPoints(); row.txt:SetPoint("LEFT", 10, 0); row.txt:SetPoint("RIGHT", -8, 0)
                if type(kind) == "number" and kind % 2 == 0 then
                    row.bg:SetColorTexture(1, 1, 1, 0.035); row.bg:Show()
                end
            end
        end
        local drawnGroups = 0
        local nGroups = 0
        for _, cc in ipairs(CONTENT) do if d.content[cc[1]] and #d.content[cc[1]] > 0 then nGroups = nGroups + 1 end end
        local half = math.ceil(nGroups / 2)
        for _, cc in ipairs(CONTENT) do
            local encs = d.content[cc[1]]
            if encs and #encs > 0 then
                local colStart = false
                if twoCol and drawnGroups == half and not yCol1 then
                    yCol1 = y; y = yTop; rowX = 11 + colW + 16; colStart = true   -- 换到右栏，从顶上重新排
                end
                -- 区块之间来一条分隔线：三档挤在一起时根本看不出哪行属于哪档
                if drawnGroups > 0 and not colStart then
                    local spacer = getRow(9)
                    spacer.txt:SetText("")
                    spacer:EnableMouse(false)
                    spacer:SetScript("OnClick", nil)
                    spacer:SetScript("OnEnter", nil)
                    spacer:SetScript("OnLeave", nil)
                    if not spacer._giSep then
                        spacer._giSep = spacer:CreateTexture(nil, "ARTWORK")
                        spacer._giSep:SetColorTexture(0.35, 0.35, 0.35, 0.55)
                        spacer._giSep:SetHeight(1)
                        spacer._giSep:SetPoint("LEFT", 6, 0)
                        spacer._giSep:SetPoint("RIGHT", -6, 0)
                    end
                    spacer._giSep:SetColorTexture(0.35, 0.35, 0.35, 0.55)   -- 行会被复用，颜色每次重设
                    spacer._giSep:Show()
                end
                drawnGroups = drawnGroups + 1
                local idx = sel[cc[1]] or 1
                if idx > #encs then idx = 1 end
                sel[cc[1]] = idx
                local ec = encs[idx]
                -- 英雄天赋一律**每行常驻**。
                -- ⛔ 原来是条件式：全队相同→只在标题显示一次、行里不重复；有人不同→标题不显示、
                --    每行各标。信息其实一条没少，但**表头有时有、有时没有**，读的人得先反推出这条
                --    规则才看得懂，于是直接读成「有些 build 没标英雄天赋」
                --    （Telegram doctorase 2026-09-07 报，两张截图正好是这两种情况：
                --     Den of Nalorakk 五条全 Deathstalker 收在标题里，Murder Row 混编则每行都有）。
                -- ⭐ 判据不是「信息在不在」，是「不用想就能看懂」——
                --    同一个词重复五次的代价，远小于让人先想明白规则。
                -- 分组标题（可点切 boss/副本）
                local hdr = getRow(22); styleRow(hdr, "hdr")
                local mtag = cc[3] ~= "" and (" |cFF66BBFF[" .. cc[3] .. "]|r") or ""
                local nav = (#encs > 1) and string.format("  |cFF999999(%d/%d)|r", idx, #encs) or ""
                local heroStr = ""   -- ⛔标题不再挂英雄天赋：它已经常驻在每一行上了
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
                    local row = getRow(18); styleRow(row, i)
                    row:EnableMouse(true); row:RegisterForClicks("LeftButtonUp")
                    local who = (b.player and b.player ~= "" and (b.player .. (b.server ~= "" and ("-" .. b.server) or ""))) or "?"
                    local reg = regionLabel(b.region)
                    local regStr = reg ~= "" and ("  |cFF888888[" .. reg .. "]|r") or ""
                    local heroExtra = (b.hero and b.hero ~= "")
                        and ("  |cFF7FB0FF" .. heroCN(b.hero) .. "|r") or ""
                    if b.alt then
                        -- 前 5 全是同一个英雄天赋时补上的另一分支第一（build_popular_talents.py alt=1）
                        row.txt:SetText(string.format("    |cFF7FB0FF%s|r · %s  %s%s  |cFF7FB0FF%s|r",
                            T("TP_ALT_BRANCH", "另一分支第一"),
                            (b.rk and b.rk > 0) and string.format(T("TP_WORLD_RANK", "世界 #%d"), b.rk) or "",
                            who, regStr, heroCN(b.hero)))
                    elseif cc[1] == "mplusCommon" and b.rk and b.rk > 0 then
                        -- 常规档：名次是 +12 全球榜的真实名次（300~500），不是 #1~#5
                        row.txt:SetText(string.format("    |cFFFFD100%s|r  %s%s%s", string.format(T("TP_RANK_N", "第 %d 名"), b.rk), who, regStr, heroExtra))
                    else
                        row.txt:SetText(string.format("    |cFFFFD100#%d|r  %s%s%s", i, who, regStr, heroExtra))
                    end
                    row._b = b.b
                    row._entry = b
                    row._copyTitle = string.format(T("TALENT_COPY_TITLE", "WCL %s · %s #%d"), cc[2], encDisplay(ec), i)
                    -- 载入档命名：大秘境使用稳定简称，如「GI-冲分-虚空-1」，避免
                    -- 「GI-冲分-虚空之痕竞技场-#1」在天赋面板里被截断。GI- 前缀由
                    -- GearInsight_TryImportTalents 统一添加；团本仍保留 M/H 首领代号。
                    local lbase = encName(ec)
                    local isMplus = cc[1] == "mplusHigh" or cc[1] == "mplusFarm" or cc[1] == "mplusCommon"
                    if isMplus and GearInsight.DungeonShortName then
                        lbase = GearInsight.DungeonShortName(lbase, _zhClient)
                    elseif not _zhClient then
                        lbase = lbase:match("^(%S+)") or lbase
                    end
                    row._lname = string.format("%s-%s-%d", mcode(ec) or cc[2], lbase, i)
                    -- 用户 2026-09-24「先出这个吧，然后可以多个按钮查看装备」：点一行照旧先弹天赋码窗口，
                    -- 窗口里多一个「查看装备」按钮（有装备数据时），整套装备面板贴在它右侧展开
                    row:SetScript("OnClick", function(s)
                        local str, err = GearInsight_ExportTalentBuild(specID, d.pool[s._b], d.dict)
                        if not str then GearInsight:Print(T("TALENT_FAIL", "失败：") .. (err or "?")); return end
                        local entry, ct, ln = s._entry, s._copyTitle, s._lname
                        local showGear = (d.gear and entry and entry.g) and function(host)
                            GearInsight:ShowTopPlayerGear(specID, d, entry, ct, ln, host)
                        end or nil
                        GearInsight:ShowCopyText(str, T("TALENT_COPY_HINT", "Ctrl+C 复制 → 天赋面板「导入」粘贴"), s._copyTitle, s._lname,
                            { specID = specID, flat = d.pool[s._b], dict = d.dict, showGear = showGear })
                    end)
                    row:SetScript("OnEnter", nil); row:SetScript("OnLeave", nil)
                end
            end
        end
        if twoCol then   -- PvP 通栏，从两栏里较矮那栏的下面接着排
            if yCol1 then y = math.min(y, yCol1) end
            rowX, rowW = 11, fullW
        end
        -- ── 第四档：PvP ──────────────────────────────────────────────────
        -- 用户 2026-09-10：情报页整页下线（榜单去网站看），但「一键导入 PvP 天赋串」和
        -- 「当前专精的 PvP 专属天赋」要留在游戏里 —— 这两样只有在游戏里才有用。
        -- 数据 GearInsight_Talents/PvpTalents.lua（与 WCL 库同一个 LoD 子插件，上面已加载）。
        -- ⛔ 数据源不是 WCL，是暴雪官方 PvP 榜逐人查档案得来；串是暴雪现成的
        --    talent_loadout_code，⛔不走 GearInsight_ExportTalentBuild。
        -- ⛔ 串里**没有** PvP 专属那 3 个（暴雪分两样存）：所以专属天赋单独一块画出来，
        --    并拿 GetAllSelectedPvpTalentIDs 对身上的 —— 打勾的是已选，橙字是「多数人选了你没选」。
        -- ⛔⛔ 按 specID 查（与 WCL 库同一把 key）。别拿 GetSpecializationInfo 的名字拼
        --    "MONK/MISTWEAVER"：中文客户端返回的是「织雾」，拼出来永远查不到
        --    （2026-09-10 用户截图：第四档整块没画出来，一个错都没报）。
        local PT = _G.GearInsightPvpTalents
        local mine = (PT and specID) and PT[specID] or nil
        local function pvpIcon(id)
            if not (id and id > 0) then return nil end
            local fn = (C_SpecializationInfo and C_SpecializationInfo.GetPvpTalentInfo) or GetPvpTalentInfoByID
            if not fn then return nil end
            -- 返回形态两种都见过：多值 (talentID, name, icon, …) 或一张 PvpTalentInfo 表
            local ok, a, _, c = pcall(fn, id)
            if not ok then return nil end
            if type(a) == "table" then
                if a.icon then return a.icon end
                if a.spellID and C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(a.spellID) end
                return nil
            end
            return c
        end
        local function iconTag(icon, size)
            return icon and ("|T" .. icon .. ":" .. (size or 14) .. ":" .. (size or 14) .. ":0:0:64:64:4:60:4:60|t ") or ""
        end
        if mine and ((mine.pvp and #mine.pvp > 0) or (mine.builds and #mine.builds > 0)) then
            if drawnGroups > 0 then
                local spacer = getRow(9)
                spacer.txt:SetText("")
                spacer:EnableMouse(false)
                spacer:SetScript("OnClick", nil); spacer:SetScript("OnEnter", nil); spacer:SetScript("OnLeave", nil)
                if not spacer._giSep then
                    spacer._giSep = spacer:CreateTexture(nil, "ARTWORK")
                    spacer._giSep:SetColorTexture(0.35, 0.35, 0.35, 0.55)
                    spacer._giSep:SetHeight(1)
                    spacer._giSep:SetPoint("LEFT", 6, 0)
                    spacer._giSep:SetPoint("RIGHT", -6, 0)
                end
                spacer._giSep:SetColorTexture(0.35, 0.35, 0.35, 0.55)
                spacer._giSep:Show()
            end
            drawnGroups = drawnGroups + 1
            local modeCN = (PT.mode == "shuffle") and T("PVP_MODE_SHUFFLE", "单人成队") or T("PVP_MODE_BLITZ", "战场突袭")
            -- 标题：PvP [单人成队 · 榜前30名]  样本 30 人  (暴雪官方榜)
            local hdr = getRow(22); styleRow(hdr, "hdr")
            hdr.txt:SetText(string.format("|cFFFFD100%s|r |cFF66BBFF[%s · %s]|r  |cFFE6E0C8%s|r  |cFF999999(%s)|r",
                T("CONTENT_PVP", "PvP"), modeCN,
                string.format(T("PVP_TOP_N", "榜前 %d 名"), PT.top or 0),
                string.format(T("PVP_SAMPLE_N", "样本 %d 人"), mine.n or 0),
                T("PVP_TAL_SRC", "暴雪官方榜")))
            hdr:EnableMouse(true)
            hdr:SetScript("OnClick", nil)
            hdr:SetScript("OnEnter", function(s)
                GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
                GameTooltip:SetText(T("PVP_TAL_TIP",
                    "数据来自暴雪官方 PvP 排行榜，逐人查档案得来（不是 WCL）。这是上榜玩家实际点的，不是「最优解」。"),
                    1, 0.82, 0, 1, true)
                GameTooltip:Show()
            end)
            hdr:SetScript("OnLeave", function() GameTooltip:Hide() end)

            -- 专属天赋块：身上已选的打勾；≥50% 的人选了而你没选 → 橙字提醒
            if mine.pvp and #mine.pvp > 0 then
                local selected = {}
                if C_SpecializationInfo and C_SpecializationInfo.GetAllSelectedPvpTalentIDs then
                    local ok, ids = pcall(C_SpecializationInfo.GetAllSelectedPvpTalentIDs)
                    if ok and type(ids) == "table" then
                        for _, id in ipairs(ids) do selected[id] = true end
                    end
                end
                local sub = getRow(16)
                sub.txt:SetText("    |cFFB060FF" .. T("PVP_OWN_TAL", "专属天赋 · 上榜玩家选择率") .. "|r  |cFF808080"
                    .. T("PVP_OWN_LEGEND2", "√ 已选") .. "|r")
                sub:EnableMouse(true); sub:SetScript("OnClick", nil)
                sub:SetScript("OnEnter", function(s2)
                    GameTooltip:SetOwner(s2, "ANCHOR_RIGHT")
                    GameTooltip:SetText(T("PVP_OWN_LEGEND", "PvP 专属天赋（战场/竞技场里额外的 3 个）。\n绿字√ = 你身上已选；橙字 = 半数以上上榜玩家选了、你没选。"), 1, 0.82, 0, 1, true)
                    GameTooltip:Show()
                end)
                sub:SetScript("OnLeave", function() GameTooltip:Hide() end)
                local PER_ROW = 3
                local items = {}
                for i, t in ipairs(mine.pvp) do
                    local nm = (_zhClient and t.cn or t.name) or "?"
                    local ic = iconTag(pvpIcon(t.id), 14)
                    local col, mark = "|cFFE6E0C8", ""
                    if selected[t.id] then
                        col, mark = "|cFF40FF40", " |cFF40FF40√|r"
                    elseif (t.pct or 0) >= 50 then
                        col = "|cFFFF9933"
                    end
                    items[#items + 1] = string.format("%s%s%s|r |cFF8a93a6%.0f%%|r%s", ic, col, nm, t.pct or 0, mark)
                    if #items == PER_ROW or i == #mine.pvp then
                        local row = getRow(18)
                        row.txt:SetText("    " .. table.concat(items, "    "))
                        row:EnableMouse(false); row:SetScript("OnClick", nil); row:SetScript("OnEnter", nil); row:SetScript("OnLeave", nil)
                        items = {}
                    end
                end
            end

            -- 专属天赋 与 榜首配置 之间一条细分割线（用户 2026-09-10：「两个部分加分割线，更美观」）
            if mine.pvp and #mine.pvp > 0 and mine.builds and #mine.builds > 0 then
                local sp = getRow(7)
                sp.txt:SetText("")
                sp:EnableMouse(false)
                sp:SetScript("OnClick", nil); sp:SetScript("OnEnter", nil); sp:SetScript("OnLeave", nil)
                if not sp._giSep then
                    sp._giSep = sp:CreateTexture(nil, "ARTWORK")
                    sp._giSep:SetHeight(1)
                    sp._giSep:SetPoint("LEFT", 6, 0)
                    sp._giSep:SetPoint("RIGHT", -6, 0)
                end
                sp._giSep:SetColorTexture(0.35, 0.35, 0.35, 0.35)   -- 比档间线淡：同一档里的次级分隔
                sp._giSep:Show()
            end
            -- 榜首 3 套：点一行弹复制窗 + 一键导入（串里不含专属 3 个，提示里列出来）
            local nb = 0
            for i, b in ipairs(mine.builds or {}) do
                if b.code and b.code ~= "" then
                    nb = nb + 1
                    local row = getRow(18); styleRow(row, nb)
                    row:EnableMouse(true); row:RegisterForClicks("LeftButtonUp")
                    local who = (b.player and b.player ~= "" and (b.player .. ((b.realm and b.realm ~= "") and ("-" .. b.realm) or ""))) or "?"
                    local reg = regionLabel(PT.region)
                    local regStr = reg ~= "" and ("  |cFF888888[" .. reg .. "]|r") or ""
                    local heroStr = (b.hero and b.hero ~= "") and ("  |cFF7FB0FF" .. (_zhClient and (b.heroCn or b.hero) or b.hero) .. "|r") or ""
                    local pvpNames = {}
                    for _, t in ipairs(b.pvp or {}) do
                        pvpNames[#pvpNames + 1] = (_zhClient and t.cn or t.name) or "?"
                    end
                    -- ⛔ 三个专属名不上行（一行装不下，2026-09-10 截图压成一团）：悬浮和复制窗里给
                    row.txt:SetText(string.format("    |cFFFFD100#%d|r  %s%s%s", b.rank or i, who, regStr, heroStr))
                    row._code = b.code
                    row._rating = b.rating
                    row._copyTitle = string.format(T("PVP_COPY_TITLE", "PvP %s #%d"), modeCN, b.rank or i)
                    row._lname = string.format("PvP-%s-#%d", _zhClient and modeCN or (PT.mode or "pvp"), b.rank or i)
                    row._pvpStr = table.concat(pvpNames, "、")
                    row._pvp = b.pvp; row._who = who; row._hero = heroStr; row._modeCN = modeCN
                    row:SetScript("OnClick", function(s)
                        GearInsight:ShowCopyText(s._code,
                            T("PVP_COPY_HINT", "Ctrl+C 复制 → 天赋面板「导入」粘贴。串里不含 PvP 专属 3 个，导完去 PvP 天赋界面选：")
                                .. (s._pvpStr or ""),
                            s._copyTitle, s._lname, nil)
                    end)
                    row:SetScript("OnEnter", function(s)
                        -- 用户 2026-09-10「这里能带图标吗，更美观一点」：一行一个专属天赋，带图标
                        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
                        GameTooltip:SetText(s._who or "?", 1, 0.82, 0)
                        GameTooltip:AddLine(string.format("%s · %s", s._modeCN or "PvP",
                            string.format(T("PVP_RATING_FMT", "%d 分"), s._rating or 0)), 0.8, 0.8, 0.8)
                        if s._hero and s._hero ~= "" then
                            GameTooltip:AddLine(T("PVP_TIP_HERO", "英雄天赋：") .. s._hero, 0.9, 0.9, 0.9)
                        end
                        if s._pvp and #s._pvp > 0 then
                            GameTooltip:AddLine(" ")
                            GameTooltip:AddLine(T("PVP_TIP_OWN", "他的 PvP 专属天赋") .. " |cFF808080" .. T("PVP_TIP_NOTIN", "（串里不含，导完自己选）") .. "|r", 1, 0.82, 0)
                            for _, t in ipairs(s._pvp) do
                                GameTooltip:AddLine("  " .. iconTag(pvpIcon(t.id), 16) .. ((_zhClient and t.cn or t.name) or "?"), 0.9, 0.9, 0.9)
                            end
                        end
                        GameTooltip:AddLine(" ")
                        GameTooltip:AddLine(T("PVP_TIP_CLICK", "点击：复制导入串 / 一键导入天赋树"), 0.6, 0.8, 1)
                        GameTooltip:Show()
                    end)
                    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
                end
            end
            if nb > 0 then
                local note = getRow(14)
                note.txt:SetText("    |cFF808080" .. T("PVP_IMPORT_NOTE2", "点一行复制导入串 · 专属 3 个需在 PvP 天赋界面自选") .. "|r")
                note:EnableMouse(false); note:SetScript("OnClick", nil); note:SetScript("OnEnter", nil); note:SetScript("OnLeave", nil)
            end
        end
        f._ct:SetSize(fullW + 22, math.max(10, -(y + 46) + 14))
        -- 弹窗模式按内容定高，但封顶到屏幕 85%，再长就靠滚动
        f:SetHeight(math.min(math.max(140, -y + 14), math.floor((UIParent:GetHeight() or 900) * 0.85)))
    end
    render()
    if GearInsight.Skin then GearInsight.Skin.Sweep(f) end
    f:Show()
end

-- 「清理导入档」按钮文字带计数；一个都没有时禁用
function GearInsight:RefreshClearLoadoutsButton()
    local f = self._talentPickerFrame
    if not (f and f._clearBtn) then return end
    local list = GearInsight_ListImportedLoadouts and GearInsight_ListImportedLoadouts() or {}
    local n = 0
    for _, lo in ipairs(list) do if not lo.active then n = n + 1 end end
    f._clearBtn:SetText(string.format(T("TAL_CLEAR_BTN", "清理导入档 (%d)"), n))
    f._clearBtn:SetEnabled(n > 0)
end

function GearInsight:ConfirmClearImportedLoadouts()
    local list = GearInsight_ListImportedLoadouts and GearInsight_ListImportedLoadouts() or {}
    local names, n = {}, 0
    for _, lo in ipairs(list) do
        if not lo.active then n = n + 1; if #names < 6 then names[#names + 1] = lo.name end end
    end
    if n == 0 then
        self:Print(T("TAL_CLEAR_NONE", "没有本插件导入的载入档可清理。")); return
    end
    local more = (n > #names) and string.format(T("TAL_CLEAR_MORE", " …等 %d 个"), n) or ""
    StaticPopupDialogs["GEARINSIGHT_CLEAR_LOADOUTS"] = StaticPopupDialogs["GEARINSIGHT_CLEAR_LOADOUTS"] or {
        button1 = T("TAL_CLEAR_OK", "删除"), button2 = CANCEL,
        timeout = 0, whileDead = true, hideOnEscape = true, showAlert = true,
        OnAccept = function()
            GearInsight_ClearImportedLoadouts(nil, function(del, skip, refused, err)
                if err then GearInsight:Print(T("TAL_CLEAR_FAIL", "清理失败：") .. err); return end
                local msg = string.format(T("TAL_CLEAR_DONE", "已删除 %d 个导入的载入档"), del)
                if skip > 0 then msg = msg .. T("TAL_CLEAR_SKIP", "（正在用的那份没动）") end
                GearInsight:Print(msg)
                if refused and #refused > 0 then
                    GearInsight:Print(string.format(T("TAL_CLEAR_REFUSED2", "游戏拒绝删除 %d 个：%s —— 服务器一次只处理一个，稍等几秒再点一次清理即可。"),
                        #refused, table.concat(refused, "、")))
                end
                GearInsight:RefreshClearLoadoutsButton()
            end)
        end,
    }
    StaticPopupDialogs["GEARINSIGHT_CLEAR_LOADOUTS"].text =
        string.format(T("TAL_CLEAR_ASK", "删除本插件导入的 %d 个天赋载入档？\n%s%s\n\n你自己建的档和正在用的档不会动。"),
            n, table.concat(names, "、"), more)
    StaticPopup_Show("GEARINSIGHT_CLEAR_LOADOUTS")
end

-- ── 顶尖玩家整套装备（用户 2026-09-24「点名字，直接看装备附魔等全套」）─────────────────────
-- 数据 = GearInsightPopularTalents[spec].items / gear / bonus（build_popular_talents.py 从 WCL rankings 自带的 gear 烤进来）：
--   list[i].g → gear[g] = "k,k,…"；items[k] = "部位:物品:装等:附魔:宝石.宝石:bonus池索引"；bonus[j] = "id.id…"
-- 每件用 bonusID + 附魔 + 宝石拼出真实物品链接：悬浮就是那件装备本身（属性 / 轨道 / 附魔 / 宝石都对）。
-- 底部保留原来点一行的两件事：复制天赋码、一键应用。
local TP_SLOTS = { 1, 2, 3, 15, 5, 9, 10, 6, 7, 8, 11, 12, 13, 14, 16, 17 }
local TP_SLOT_G = { [1] = "HEADSLOT", [2] = "NECKSLOT", [3] = "SHOULDERSLOT", [15] = "BACKSLOT", [5] = "CHESTSLOT",
    [9] = "WRISTSLOT", [10] = "HANDSSLOT", [6] = "WAISTSLOT", [7] = "LEGSSLOT", [8] = "FEETSLOT", [11] = "FINGER0SLOT",
    [12] = "FINGER1SLOT", [13] = "TRINKET0SLOT", [14] = "TRINKET1SLOT", [16] = "MAINHANDSLOT", [17] = "SECONDARYHANDSLOT" }

-- 解一名玩家的整套装备：slot → { id, ilvl, ench, gems = {..}, link }
function GearInsight.TopPlayerGear(d, g, specID)
    if not (d and g and d.gear and d.items and d.gear[g]) then return nil end
    local out = {}
    for k in string.gmatch(d.gear[g], "%d+") do
        local tok = d.items[tonumber(k)]
        if tok then
            local slot, id, ilvl, ench, gemStr, bi = string.match(tok, "^(%d+):(%d+):(%d*):(%d*):([%d%.]*):(%d*)$")
            slot, id, ilvl, ench, bi = tonumber(slot), tonumber(id), tonumber(ilvl) or 0, tonumber(ench) or 0, tonumber(bi)
            local gems = {}
            for gm in string.gmatch(gemStr or "", "%d+") do gems[#gems + 1] = tonumber(gm) end
            local bon = {}
            if bi and bi > 0 and d.bonus and d.bonus[bi] then
                for b in string.gmatch(d.bonus[bi], "%d+") do bon[#bon + 1] = b end
            end
            if slot and id then
                -- item:id:附魔:宝石1:宝石2:宝石3:宝石4:后缀:唯一:等级:专精:修饰掩码:情境:bonus数:bonus…
                local link = string.format("item:%d:%s:%s:%s:%s:%s:::%d:%d:::%d%s", id,
                    ench > 0 and tostring(ench) or "", tostring(gems[1] or ""), tostring(gems[2] or ""),
                    tostring(gems[3] or ""), tostring(gems[4] or ""),
                    (UnitLevel and UnitLevel("player")) or 80, specID or 0, #bon,
                    #bon > 0 and (":" .. table.concat(bon, ":")) or "")
                out[slot] = { id = id, ilvl = ilvl, ench = ench, gems = gems, link = link }
            end
        end
    end
    return out
end

-- 附魔名：读这件物品悬浮里的「永久附魔」行（多语言都对，不维护附魔表）
-- 附魔名按链接缓存：一件只读一次悬浮（重画时不再重复扫）
local _tpEnchCache = {}
local function tpEnchantText(link)
    if _tpEnchCache[link] ~= nil then return _tpEnchCache[link] or nil end
    if not (C_TooltipInfo and C_TooltipInfo.GetHyperlink) then return nil end
    local ok, data = pcall(C_TooltipInfo.GetHyperlink, link)
    if not (ok and data and data.lines) then return nil end
    local want = Enum and Enum.TooltipDataLineType and Enum.TooltipDataLineType.ItemEnchantmentPermanent
    for _, line in ipairs(data.lines) do
        if want and line.type == want and line.leftText then
            -- ⛔ 用户 2026-09-24 截图：附魔名前面两个「□□」——这行开头带内嵌图标 / 特殊符号，面板字体显示不了。
            --   去掉 |A..|a、|T..|t 内嵌图标和颜色码，再去掉「附魔：」前缀，最后把开头非字母数字汉字的符号剥掉
            local txt = tostring(line.leftText)
            txt = txt:gsub("|A.-|a", ""):gsub("|T.-|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
            txt = txt:gsub("^[^:：]+[:：]%s*", "")
            -- 开头的非 ASCII 字母数字、非汉字（UTF-8 3 字节 E4-E9 开头）字符逐个剥掉
            local guard = 0
            while #txt > 0 and guard < 12 do
                guard = guard + 1
                local c = txt:byte(1)
                if (c >= 48 and c <= 57) or (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or c == 43 or (c >= 0xE4 and c <= 0xE9) then break end
                local len = (c >= 0xF0 and 4) or (c >= 0xE0 and 3) or (c >= 0xC0 and 2) or 1
                txt = txt:sub(len + 1)
            end
            _tpEnchCache[link] = txt
            return txt
        end
    end
    -- 物品数据还没到时悬浮里没有附魔行：先不缓存，等数据到了再读
    return nil
end

function GearInsight:ShowTopPlayerGear(specID, d, b, copyTitle, lname, anchor)
    -- 2026-09-24 用户（经「客户端」会话转交）：「下面的按钮可以取消，然后展示模式不要这样，用主面板的展示模式」
    --   「附上战斗时间，和WCL连接」「点击弹出可以复制」「转换成北京时间（简体中文），其他语言UTC时间」
    --   → 每行 = 左：你身上（图标 + 部位: 名称 [装等]）→ 右：他身上（图标 + 品质色名称 [装等] (+差)），下面小字 = 附魔 + 宝石；
    --     标题下 = 战斗时间（zhCN 北京时间 / 其它 UTC）+ 时长 + 「WCL 链接」按钮（弹可复制框）；底部按钮去掉。
    local gear = GearInsight.TopPlayerGear(d, b and b.g, specID)
    local f = self._topGearFrame
    local ROW_H = 54
    if not f then
        f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        GearInsight:RegisterEscClose(f, "GearInsightTopGear")
        f:SetSize(640, 620)
        f:SetFrameStrata("FULLSCREEN_DIALOG"); f:SetFrameLevel(70)
        f:SetBackdrop({ edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize = 32,
            insets = { left = 8, right = 8, top = 8, bottom = 8 } })
        f:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.95)
        local bg = f:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(0.04, 0.04, 0.07, 0.98)
        f:EnableMouse(true); f:SetMovable(true); f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", function() f:StartMoving() end)
        f:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)
        f._title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); f._title:SetPoint("TOP", 0, -14)
        f._sub = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); f._sub:SetPoint("TOP", f._title, "BOTTOM", -40, -5)
        f._link = CreateFrame("Button", nil, f, "UIPanelButtonTemplate"); f._link:SetSize(86, 20)
        f._link:SetPoint("LEFT", f._sub, "RIGHT", 8, 0); f._link:SetText(T("TPG_WCL", "WCL 链接"))
        local cb = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        cb:SetPoint("TOPRIGHT", -4, -4); cb:SetScript("OnClick", function() f:Hide() end)
        local hL = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); hL:SetPoint("TOPLEFT", 26, -64); hL:SetText(T("TPG_MINE", "你身上"))
        local hR = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); hR:SetPoint("TOPLEFT", 342, -64); hR:SetText(T("TPG_HIS", "他身上"))
        local sf = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
        sf:SetPoint("TOPLEFT", 16, -80); sf:SetPoint("BOTTOMRIGHT", -34, 30)
        local sc = CreateFrame("Frame", nil, sf); sc:SetSize(586, #TP_SLOTS * ROW_H); sf:SetScrollChild(sc)
        f._foot = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); f._foot:SetPoint("BOTTOM", 0, 12)
        f._foot:SetText(T("TPG_FOOT2", "悬停看完整属性 · Shift+点击发到聊天"))
        f.rows = {}
        local function itemBtn(parent, x)
            local ib = CreateFrame("Button", nil, parent); ib:SetSize(40, 40); ib:SetPoint("TOPLEFT", x, -4)
            ib.tex = ib:CreateTexture(nil, "ARTWORK"); ib.tex:SetAllPoints(); ib.tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            ib:SetScript("OnEnter", function(s)
                if not s._link then return end
                GameTooltip:SetOwner(s, "ANCHOR_RIGHT"); GameTooltip:SetHyperlink(s._link); GameTooltip:Show()
            end)
            ib:SetScript("OnLeave", function() GameTooltip:Hide() end)
            ib:SetScript("OnClick", function(s)
                if s._link and IsModifiedClick("CHATLINK") then
                    local _, full = C_Item.GetItemInfo(s._link)
                    ChatEdit_InsertLink(full or s._link)
                end
            end)
            return ib
        end
        for i = 1, #TP_SLOTS do
            local r = CreateFrame("Frame", nil, sc)
            r:SetSize(586, ROW_H - 2); r:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
            r.bg = r:CreateTexture(nil, "BACKGROUND"); r.bg:SetAllPoints(); r.bg:SetColorTexture(1, 1, 1, (i % 2 == 0) and 0.045 or 0.015)
            r.mine = itemBtn(r, 6)
            r.mineTxt = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); r.mineTxt:SetPoint("TOPLEFT", 52, -8)
            r.mineTxt:SetWidth(222); r.mineTxt:SetJustifyH("LEFT"); r.mineTxt:SetWordWrap(true)
            r.arrow = r:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); r.arrow:SetPoint("TOPLEFT", 280, -12); r.arrow:SetWidth(40); r.arrow:SetJustifyH("CENTER")
            r.his = itemBtn(r, 322)
            r.hisTxt = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); r.hisTxt:SetPoint("TOPLEFT", 368, -8)
            r.hisTxt:SetWidth(214); r.hisTxt:SetJustifyH("LEFT"); r.hisTxt:SetWordWrap(false)
            r.ench = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); r.ench:SetPoint("TOPLEFT", 368, -28)
            r.ench:SetWidth(170); r.ench:SetJustifyH("LEFT"); r.ench:SetWordWrap(false)
            r.gems = {}
            for k = 1, 3 do
                local gi = r:CreateTexture(nil, "ARTWORK"); gi:SetSize(14, 14); gi:SetPoint("TOPLEFT", 540 + (k - 1) * 15, -29); r.gems[k] = gi
            end
            f.rows[i] = r
        end
        self._topGearFrame = f
    end

    -- 位置：贴在调用方所在顶层窗口右侧，放不下就放左侧（用户「第二个窗口放到右侧展开」）
    f:ClearAllPoints()
    local top = anchor
    while top and top.GetParent and top:GetParent() and top:GetParent() ~= UIParent do top = top:GetParent() end
    if top and top ~= UIParent and top.GetRight and top:GetRight() then
        local sw = UIParent:GetWidth() or 1920
        local scale = (top:GetEffectiveScale() or 1) / (f:GetEffectiveScale() or 1)
        if (top:GetRight() * scale + f:GetWidth()) <= sw then
            f:SetPoint("TOPLEFT", top, "TOPRIGHT", 4, 0)
        else
            f:SetPoint("TOPRIGHT", top, "TOPLEFT", -4, 0)
        end
    else
        GearInsight:AnchorPopup(f)
    end

    local reg = (b and b.region and b.region ~= "") and ("  [" .. b.region .. "]") or ""
    f._title:SetText((b and b.player or "?") .. ((b and b.server and b.server ~= "") and ("-" .. b.server) or "") .. reg)
    -- 战斗时间：简体中文按北京时间，其它语言 UTC；时长 mm:ss
    local st, du = b and tonumber(b.st) or 0, b and tonumber(b.du) or 0
    local whenTxt
    if st > 0 then
        if _LOCALE == "zhCN" then
            whenTxt = date("!%Y-%m-%d %H:%M", st + 8 * 3600) .. " " .. T("TPG_BJT", "北京时间")
        else
            whenTxt = date("!%Y-%m-%d %H:%M", st) .. " UTC"
        end
        if du > 0 then whenTxt = whenTxt .. string.format("  ·  " .. T("TPG_DUR", "时长 %d:%02d"), math.floor(du / 60), du % 60) end
    else
        whenTxt = gear and T("TPG_SUB", "WCL 上榜时身上的整套装备 · 附魔 · 宝石") or T("TPG_NONE", "这条记录没有装备数据（等下次数据更新）")
    end
    f._sub:SetText(whenTxt)
    local url = (b and b.rc and b.rc ~= "") and ("https://www.warcraftlogs.com/reports/" .. b.rc .. ((b.fi and b.fi > 0) and ("#fight=" .. b.fi) or "")) or nil
    f._link:SetShown(url ~= nil)
    f._link:SetScript("OnClick", function()
        if url then GearInsight:ShowCopyText(url, T("TPG_WCL_HINT", "Ctrl+C 复制，到浏览器打开这场战斗的 WCL 日志"), T("TPG_WCL_TITLE", "WCL · 这场战斗")) end
    end)

    local function paint()
        for i, slot in ipairs(TP_SLOTS) do
            local r, it = f.rows[i], gear and gear[slot]
            local slotName = _G[TP_SLOT_G[slot]] or tostring(slot)
            -- 左：你身上
            local myLink = GetInventoryItemLink and GetInventoryItemLink("player", slot)
            local myId = GetInventoryItemID and GetInventoryItemID("player", slot)
            local myLv = myLink and C_Item.GetDetailedItemLevelInfo and C_Item.GetDetailedItemLevelInfo(myLink)
            r.mine._link = myLink
            if myLink then
                local nm, _, q, _, _, _, _, _, _, ic = C_Item.GetItemInfo(myLink)
                r.mine.tex:SetTexture(ic or (myId and C_Item.GetItemIconByID and C_Item.GetItemIconByID(myId)) or 134400)
                local qc = q and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
                r.mineTxt:SetText(slotName .. ": " .. ((qc and qc.hex) or "|cFFFFFFFF") .. (nm or "?") .. "|r  [" .. (myLv or "?") .. "]")
            else
                r.mine.tex:SetTexture(nil)
                r.mineTxt:SetText(slotName .. ": |cFF777777" .. T("SLOT_EMPTY", "(空槽)") .. "|r")
            end
            -- 右：他身上
            r.his._link = it and it.link or nil
            for k = 1, 3 do r.gems[k]:Hide() end
            if it then
                local nm, _, q, _, _, _, _, _, _, ic = C_Item.GetItemInfo(it.link)
                r.his.tex:SetTexture(ic or (C_Item.GetItemIconByID and C_Item.GetItemIconByID(it.id)) or 134400)
                local qc = q and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
                local diff = (myLv and it.ilvl > 0) and (it.ilvl - myLv) or nil
                local dTxt = diff and (diff > 0 and ("  |cFF33FF66(+" .. diff .. ")|r") or (diff < 0 and ("  |cFFFF7777(" .. diff .. ")|r") or "")) or ""
                r.hisTxt:SetText(((qc and qc.hex) or "|cFFFFFFFF") .. (nm or ("item:" .. it.id)) .. "|r  [" .. (it.ilvl > 0 and it.ilvl or "?") .. "]" .. dTxt)
                r.ench:SetText(it.ench > 0 and ("|cFF33FF66" .. (tpEnchantText(it.link) or T("TPG_ENCH", "已附魔")) .. "|r") or "")
                for k, gid in ipairs(it.gems) do
                    if k <= 3 then
                        r.gems[k]:SetTexture((C_Item.GetItemIconByID and C_Item.GetItemIconByID(gid)) or 134400); r.gems[k]:Show()
                    end
                end
                if myId and myId == it.id then
                    r.arrow:SetText("|cFF33FF66" .. T("TPG_SAME", "同款") .. "|r")
                else
                    r.arrow:SetText("|cFFFFD100→|r")
                end
            else
                r.his.tex:SetTexture(nil); r.hisTxt:SetText("|cFF666666-|r"); r.ench:SetText(""); r.arrow:SetText("")
            end
        end
    end
    paint()
    -- 物品没缓存时名字 / 图标 / 附魔行是空的：到货后合并成 0.1 秒一次重画
    f._paintGen = (f._paintGen or 0) + 1
    local gen, pending = f._paintGen, false
    local function schedule()
        if pending then return end
        pending = true
        C_Timer.After(0.1, function()
            pending = false
            if f:IsShown() and f._paintGen == gen then paint() end
        end)
    end
    if gear and Item and Item.CreateFromItemID then
        for _, it in pairs(gear) do
            local itm = Item:CreateFromItemID(it.id)
            if itm and not itm:IsItemEmpty() and not itm:IsItemDataCached() then itm:ContinueOnItemLoad(schedule) end
        end
    end
    f:Show()
end
