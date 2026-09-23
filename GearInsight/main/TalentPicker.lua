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
            row:SetSize(438, h or 18)
            if row._giSep then row._giSep:Hide() end   -- 上一轮可能是分隔行，复用时先藏线
            row.bg:Hide(); row.accent:Hide()            -- 行会被复用：样式每次重设
            row:ClearAllPoints(); row:SetPoint("TOPLEFT", 11, y); row:Show(); y = y - (h or 18) - 1
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
        for _, cc in ipairs(CONTENT) do
            local encs = d.content[cc[1]]
            if encs and #encs > 0 then
                -- 区块之间来一条分隔线：三档挤在一起时根本看不出哪行属于哪档
                if drawnGroups > 0 then
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
        f:SetHeight(math.max(140, -y + 14))
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
