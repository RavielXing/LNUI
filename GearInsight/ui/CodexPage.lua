-- 万奥宝典页（用户 2026-09-14「插件增加个新功能，指导所有职业专精，配万奥宝典」）。
-- 12.1 加点系统：C_Traits 树 1186，5 行选择节点（110275→110274→110273→110272→110271），货币 4230 万奥洞悉微粒。
-- 数据 core/CodexData.lua（GearInsightCodex）：WCL 顶尖玩家团本/大秘境各行选法占比；
-- 现选：C_Traits.GetNodeInfo(cfg, node).activeEntry；一键换：SetSelection + CommitConfig（能不能改由客户端说了算）。
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

local GOLD = { 1, 0.82, 0 }
local ROW_H, CELL_H = 22, 44
local ICON, GAP, ROW_GAP = 44, 10, 26   -- 树形排版：图标边长 / 同行间距 / 行距（画连线用）

-- 打开游戏自带的宝典界面（用户 2026-09-14 实测 `/gi codexui` 这条路有效）：通用天赋框架按树 1186 打开
function GearInsight:OpenCodexUI()
    local D = _G.GearInsightCodex
    local ok, err = pcall(function()
        if GenericTraitUI_LoadUI then GenericTraitUI_LoadUI() end
        local f = _G.GenericTraitFrame
        if not f then error("GenericTraitFrame 不存在") end
        if f:IsShown() then HideUIPanel(f); return end
        local sys = C_Traits.GetTraitSystemFromTree and C_Traits.GetTraitSystemFromTree(D and D.tree or 1186)
        if sys and f.SetSystemID then f:SetSystemID(sys) elseif f.SetTreeID then f:SetTreeID(D and D.tree or 1186) end
        if ShowUIPanel then ShowUIPanel(f) else f:Show() end
    end)
    if not ok then self:Print("[codex] " .. T("CX_OPEN_FAIL", "打不开宝典界面：") .. tostring(err)) end
end

local function codexConfig()
    local D = _G.GearInsightCodex
    if not (D and C_Traits and C_Traits.GetConfigIDByTreeID) then return nil end
    local ok, cfg = pcall(C_Traits.GetConfigIDByTreeID, D.tree)
    if ok and cfg and cfg > 0 then return cfg end
    return nil
end

-- 行 → 当前激活的 spellID（读活树；读不到返回 nil）
local function currentPicks(cfg)
    local D = _G.GearInsightCodex
    local out, ent2spell = {}, {}
    for sp, eid in pairs(D.entries) do ent2spell[eid] = sp end
    if not cfg then return out end
    for row, nid in pairs(D.nodes) do
        local ok, n = pcall(C_Traits.GetNodeInfo, cfg, nid)
        if ok and n and n.activeEntry and n.activeEntry.entryID and (n.activeRank or 0) > 0 then
            out[row] = ent2spell[n.activeEntry.entryID]
        end
    end
    return out
end

local function specData()
    local D = _G.GearInsightCodex
    local specID = GearInsight_CurrentSpecID and GearInsight_CurrentSpecID()
    if not (D and specID) then return nil end
    for key, v in pairs(D.specs) do
        if v.specID == specID then return v, key end
    end
    return nil
end

local function spellName(sp)
    local n = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(sp)
    if not n and GetSpellInfo then n = GetSpellInfo(sp) end
    local D = _G.GearInsightCodex
    return n or (D and D.names and D.names[sp]) or ("#" .. tostring(sp))
end
local function spellIcon(sp)
    local t = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(sp)
    if not t and GetSpellTexture then t = GetSpellTexture(sp) end
    return t or 134400
end

function GearInsight:BuildCodexPage(page)
    if not page then return end
    if not page._cxBuilt then
        page._cxBuilt = true
        local sub = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        local top = page._cxTop or 0
        sub:SetPoint("TOPLEFT", 14, -40 - top); sub:SetPoint("RIGHT", page, "RIGHT", -14, 0)
        sub:SetJustifyH("LEFT"); sub:SetWordWrap(true); sub:SetTextColor(0.72, 0.72, 0.78)
        page._cxSub = sub
        -- 场景切换：团本 / 大秘境
        local sc = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
        sc:SetSize(120, 22); sc:SetPoint("TOPRIGHT", -14, -6 - top)
        sc:SetScript("OnClick", function()
            GearInsightDB = GearInsightDB or {}
            GearInsightDB.codexScene = (GearInsightDB.codexScene == "mplus") and "raid" or "mplus"
            GearInsight:BuildCodexPage(page)
        end)
        page._cxScene = sc
        -- 打开万奥宝典（游戏自带界面）
        local op = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
        op:SetSize(120, 22); op:SetPoint("RIGHT", sc, "LEFT", -6, 0)
        op:SetText(T("CX_OPEN", "打开万奥宝典"))
        op:SetScript("OnClick", function() GearInsight:OpenCodexUI() end)
        op:SetScript("OnEnter", function(s)
            GameTooltip:SetOwner(s, "ANCHOR_BOTTOM")
            GameTooltip:SetText(T("CX_OPEN_TIP2", "打开游戏自带的万奥宝典界面，在那里换符文；再点一次关闭。"), 1, 0.82, 0, 1, true)
            GameTooltip:Show()
        end)
        op:SetScript("OnLeave", function() GameTooltip:Hide() end)
        page._cxOpen = op
        -- 怎么解锁？（攻略备注，用户 2026-09-14）
        local hb = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
        hb:SetSize(90, 22); hb:SetPoint("RIGHT", op, "LEFT", -6, 0)
        hb:SetText(T("CX_HOWTO", "怎么解锁?"))
        hb:SetScript("OnEnter", function(s)
            GameTooltip:SetOwner(s, "ANCHOR_BOTTOMLEFT")
            GameTooltip:SetText(T("CX_HOWTO_TITLE", "万奥宝典解锁与每周进度"), 1, 0.82, 0)
            GameTooltip:AddLine(T("CX_HOWTO_TXT", "解锁：80 级后到银月城「战场荣誉军需官」处买/接《魔导师的信》开启任务线，跟大法师罗曼斯、魔导师乌布里克在永歌森林修复逐日者万奥枢纽，做完《万奥苏醒》即拿到宝典并解锁第 1 行。\n之后每周在逐日者万奥枢纽（秘法殿）接周常「求知若渴」，做完得 1 颗万奥洞悉微粒，每颗解锁一行（共 5 周）：\n第 2 周 仪式奥术 ×8（仪式场所）· 第 3 周 暗影地脉凝结 ×5（虚空入侵）· 第 4 周 纯净原能 ×1（地下堡/地下城/团本/宝箱）· 第 5 周 异界魔法碎片（对决世界首领）+ 3 个世界任务。\n账号里一个角色做过，其他角色自动拿到微粒；12.1 起小号可跳过前置剧情。宝典界面从地图打开（或本页「打开万奥宝典」），脱战随时换。"), 0.9, 0.9, 0.9, true)
            GameTooltip:Show()
        end)
        hb:SetScript("OnLeave", function() GameTooltip:Hide() end)
        page._cxHow = hb
        -- 一键换成推荐
        local ap = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
        ap:SetSize(150, 24); ap:SetPoint("BOTTOMLEFT", 14, 12)
        ap:SetText(T("CX_APPLY", "一键换成推荐"))
        ap:SetScript("OnClick", function() GearInsight:ApplyCodexRecommend(page) end)
        ap:SetScript("OnEnter", function(s)
            GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
            GameTooltip:SetText(T("CX_APPLY_TIP", "把与推荐不同的行改成顶尖玩家最多选的那枚，然后提交。\n改不了（战斗中 / 客户端不允许）会在聊天框说明，请到万奥宝典界面手动改。"), 1, 0.82, 0, 1, true)
            GameTooltip:Show()
        end)
        ap:SetScript("OnLeave", function() GameTooltip:Hide() end)
        page._cxApply = ap
        local foot = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        foot:SetPoint("LEFT", ap, "RIGHT", 10, 0); foot:SetPoint("RIGHT", page, "RIGHT", -14, 0)
        foot:SetJustifyH("LEFT"); foot:SetWordWrap(true)
        page._cxFoot = foot
        page._cxRows, page._cxCells, page._cxLines = {}, {}, {}
    end
    self:_renderCodex(page)
end

-- 树形排版（用户 2026-09-14「直接做成这个格式」= 游戏宝典界面那样：一列竖排，同行选项并排，
-- 选中绿框、推荐金框，行间连线）。叠加：★ 推荐、图标下占比、行左标签、行右状态。
function GearInsight:_renderCodex(page)
    local D = _G.GearInsightCodex
    for _, r in ipairs(page._cxRows) do r:Hide() end
    for _, c in ipairs(page._cxCells) do c:Hide() end
    for _, l in ipairs(page._cxLines) do l:Hide() end
    GearInsightDB = GearInsightDB or {}
    local scene = GearInsightDB.codexScene or "raid"
    page._cxScene:SetText(scene == "raid" and T("CX_SCENE_RAID", "样本: 团本") or T("CX_SCENE_MPLUS", "样本: 大秘境"))

    local sd = specData()
    local cfg = codexConfig()
    local cur = currentPicks(cfg)
    local data = sd and (sd[scene] or sd.raid or sd.mplus)
    if sd and not sd[scene] then scene = sd.raid and "raid" or "mplus" end
    if not D then
        page._cxSub:SetText(T("CX_NODATA_FILE", "缺少数据文件 core/CodexData.lua"))
        page._cxApply:Hide(); return
    end
    if not data then
        page._cxSub:SetText(T("CX_NODATA", "当前专精暂无顶尖玩家样本（数据每周随 WCL 刷新）。下面只显示你当前的选择。"))
    else
        local few = (data.n < 10) and ("  |cFFFF9900" .. T("CX_FEW", "样本少，仅供参考") .. "|r") or ""
        page._cxSub:SetText(string.format(T("CX_SUB", "WCL 顶尖玩家 %s 样本 %d 人各行怎么选。★ 推荐 = 选的人最多；√ = 你现在选的。悬浮看效果。"),
            scene == "raid" and T("CX_RAID", "团本") or T("CX_MPLUS", "大秘境"), data.n) .. few)
    end
    if cfg and C_Traits.GetTreeCurrencyInfo then
        local okc, curr = pcall(C_Traits.GetTreeCurrencyInfo, cfg, D.tree, false)
        local c = okc and curr and curr[1]
        if c then
            page._cxSub:SetText(page._cxSub:GetText() .. "\n|cFF8A93A6" .. string.format(T("CX_CURRENCY", "万奥洞悉微粒：已用 %d，手上 %d（每周 1 颗，脱战可随时换）"), c.spent or 0, c.quantity or 0) .. "|r")
        end
    elseif not cfg then
        page._cxSub:SetText(page._cxSub:GetText() .. "\n|cFFFF6666" .. T("CX_NOTREE", "（读不到宝典树：可能还没解锁，或需要先打开一次宝典界面）") .. "|r"
            .. "\n|cFFB8B8C8" .. T("CX_HOWTO_TXT", "解锁：80 级后到银月城「战场荣誉军需官」处买/接《魔导师的信》开启任务线，跟大法师罗曼斯、魔导师乌布里克在永歌森林修复逐日者万奥枢纽，做完《万奥苏醒》即拿到宝典并解锁第 1 行。\n之后每周在逐日者万奥枢纽（秘法殿）接周常「求知若渴」，做完得 1 颗万奥洞悉微粒，每颗解锁一行（共 5 周）：\n第 2 周 仪式奥术 ×8（仪式场所）· 第 3 周 暗影地脉凝结 ×5（虚空入侵）· 第 4 周 纯净原能 ×1（地下堡/地下城/团本/宝箱）· 第 5 周 异界魔法碎片（对决世界首领）+ 3 个世界任务。\n账号里一个角色做过，其他角色自动拿到微粒；12.1 起小号可跳过前置剧情。宝典界面从地图打开（或本页「打开万奥宝典」），脱战随时换。") .. "|r")
    end

    local ROW_LBL = { T("CX_R1", "核心 · 触发伤害/治疗"), T("CX_R2", "生存"), T("CX_R3", "萦绕"), T("CX_R4", "副属性"), T("CX_R5", "触发效果") }
    local pageW = page:GetWidth() or 500
    local cx = pageW / 2 + 10               -- 树的中轴（略右，给左侧行标签留位）
    local ri, ci, li = 0, 0, 0
    local function label(x, y, w, just, font)
        ri = ri + 1
        local r = page._cxRows[ri]
        if not r then
            r = page:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            page._cxRows[ri] = r
        end
        r:SetFontObject(font or "GameFontNormalSmall")
        r:ClearAllPoints(); r:SetPoint("TOPLEFT", x, y); r:SetWidth(w); r:SetJustifyH(just)
        r:SetWordWrap(true); r:Show()
        return r
    end
    local function line(x, y, w, h)
        li = li + 1
        local l = page._cxLines[li]
        if not l then l = page:CreateTexture(nil, "ARTWORK"); l:SetColorTexture(0.55, 0.55, 0.6, 0.8); page._cxLines[li] = l end
        l:ClearAllPoints(); l:SetPoint("TOPLEFT", x, y); l:SetSize(w, h); l:Show()
    end
    local function cell(x, y, sp, pct, isCur, isRec)
        ci = ci + 1
        local c = page._cxCells[ci]
        if not c then
            c = CreateFrame("Button", nil, page, "BackdropTemplate")
            c:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 2 })
            c.ic = c:CreateTexture(nil, "ARTWORK"); c.ic:SetPoint("TOPLEFT", 2, -2); c.ic:SetPoint("BOTTOMRIGHT", -2, 2); c.ic:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            c.star = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            c.star:SetPoint("TOPRIGHT", 2, 4); c.star:SetText("|cFFFFD100★|r")
            c.chk = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            c.chk:SetPoint("BOTTOMLEFT", 2, -2); c.chk:SetText("|cFF33FF33√|r")
            c.pct = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            c.pct:SetPoint("TOP", c, "BOTTOM", 0, -1); c.pct:SetJustifyH("CENTER")
            page._cxCells[ci] = c
        end
        c:ClearAllPoints(); c:SetPoint("TOPLEFT", x, y); c:SetSize(ICON, ICON)
        c.ic:SetTexture(spellIcon(sp))
        c.ic:SetDesaturated(not pct and not isCur)
        c.ic:SetAlpha((pct or isCur) and 1 or 0.45)
        c.star:SetShown(isRec and true or false)
        c.chk:SetShown(isCur and true or false)
        c.pct:SetText(pct and (string.format("%s%.0f%%", isRec and "|cFFFFD100" or "|cFFB8B8C8", pct) .. "|r") or "|cFF666666-|r")
        c:SetBackdropColor(0, 0, 0, 0.6)
        if isCur then c:SetBackdropBorderColor(0.2, 1, 0.2, 1)
        elseif isRec then c:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 1)
        else c:SetBackdropBorderColor(0.3, 0.3, 0.32, 1) end
        c:SetScript("OnEnter", function(s)
            GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
            GameTooltip:SetSpellByID(sp)
            if pct then GameTooltip:AddLine(string.format(T("CX_TIP_PCT", "顶尖玩家 %.0f%% 选它"), pct), 1, 0.82, 0) end
            if isRec then GameTooltip:AddLine("★ " .. T("CX_REC_IS", "推荐"), 1, 0.82, 0) end
            if isCur then GameTooltip:AddLine("√ " .. T("CX_TIP_CUR", "你当前选的"), 0.3, 1, 0.3) end
            GameTooltip:Show()
        end)
        c:SetScript("OnLeave", function() GameTooltip:Hide() end)
        c:Show()
    end

    local y = -(44 + (page._cxTop or 0) + math.max(28, (page._cxSub:GetStringHeight() or 28)) + 14)
    local diff, recs = 0, {}
    local prevBottom
    for row = 1, 5 do
        local cands = D.rows[row] or {}
        local pctBy = {}
        if data and data.rows[row] then for _, it in ipairs(data.rows[row]) do pctBy[it[1]] = it[2] end end
        local rec = data and data.rows[row] and data.rows[row][1] and data.rows[row][1][1]
        if rec then recs[row] = rec end
        if prevBottom then line(cx - 1, prevBottom, 2, prevBottom - y) end   -- 行间连线
        local n = #cands
        local x0 = cx - (n * ICON + (n - 1) * GAP) / 2
        for i, sp in ipairs(cands) do
            cell(x0 + (i - 1) * (ICON + GAP), y, sp, pctBy[sp], cur[row] == sp, sp == rec)
        end
        local lb = label(16, y + 2, x0 - 24, "LEFT", "GameFontNormal")
        lb:SetText(string.format("|cFFFFD100%s %d %s|r\n|cFF8A93A6%s|r", T("CX_ROW", "第"), row, T("CX_ROW_SUF", "行"), ROW_LBL[row] or ""))
        local state
        if not cur[row] then
            state = "|cFF999999" .. T("CX_UNPICKED", "未选") .. "|r" .. (rec and ("\n|cFFB8B8C8" .. T("CX_REC_IS", "推荐") .. " " .. spellName(rec) .. "|r") or "")
        elseif rec and cur[row] ~= rec then
            state = "|cFFFF8800" .. T("CX_SWITCH_TO", "建议换成") .. "\n" .. spellName(rec) .. "|r"; diff = diff + 1
        else
            state = "|cFF33FF33√ " .. (rec and T("CX_ON_REC", "已是推荐") or spellName(cur[row])) .. "|r"
        end
        local rx = x0 + n * ICON + (n - 1) * GAP + 12
        local st = label(rx, y + 2, pageW - rx - 14, "LEFT", "GameFontHighlightSmall")
        st:SetText(state)
        prevBottom = y - ICON - 14           -- 图标底 + 占比文字
        y = prevBottom - ROW_GAP
    end
    page._cxRecs = recs
    page._cxApply:SetShown(data ~= nil and cfg ~= nil)
    if data and cfg then
        if diff == 0 then page._cxFoot:SetText(T("CX_FOOT_SAME", "你的选择已与推荐一致。"))
        else page._cxFoot:SetText(string.format(T("CX_FOOT_DIFF", "有 %d 行与推荐不同（橙色）。"), diff)) end
    else
        page._cxFoot:SetText("")
    end
end

function GearInsight:ApplyCodexRecommend(page)
    local D = _G.GearInsightCodex
    local cfg = codexConfig()
    if not (D and cfg and page and page._cxRecs) then return end
    if InCombatLockdown and InCombatLockdown() then self:Print(T("CX_INCOMBAT", "战斗中不能改万奥宝典。")); return end
    local cur = currentPicks(cfg)
    local changed, fails = 0, {}
    for row = 1, 5 do
        local rec = page._cxRecs[row]
        if rec and cur[row] ~= rec then
            local nid, eid = D.nodes[row], D.entries[rec]
            local ok, res = pcall(C_Traits.SetSelection, cfg, nid, eid)
            if ok and res then changed = changed + 1 else fails[#fails + 1] = row end
        end
    end
    if changed > 0 then
        local ok, res = pcall(C_Traits.CommitConfig, cfg)
        if ok and res then
            self:Print(string.format(T("CX_APPLIED", "万奥宝典已改 %d 行并提交。"), changed))
        else
            self:Print(T("CX_COMMIT_FAIL", "选择已改但提交失败：请打开万奥宝典界面确认/提交，或到宝典处再试。"))
        end
    end
    if #fails > 0 then
        self:Print(string.format(T("CX_SET_FAIL", "第 %s 行改不了（客户端不允许在此改，或行未解锁）。"), table.concat(fails, "/")))
    end
    if changed == 0 and #fails == 0 then self:Print(T("CX_FOOT_SAME", "你的选择已与推荐一致。")) end
    C_Timer.After(0.3, function() if page:IsShown() then GearInsight:BuildCodexPage(page) end end)
end
