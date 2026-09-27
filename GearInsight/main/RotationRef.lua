-- GearInsight/main/RotationRef.lua — 循环参考弹窗
-- 2026-09-22 从 GearInsight.lua 拆出（纯搬家，逻辑未动）。共用 helper 见 GearInsight.lua 末尾的 GearInsight.Helpers。
local H = GearInsight.Helpers
local T, _LOCALE = H.T, H.LOCALE

-- 循环参考弹窗：WCL 顶尖玩家「真实起手序列 + 核心技能频率 + BUFF盯防」，团本(M1)/大秘境切换。
-- 数据 core/RotationData.lua(spellID 主键)；技能名/图标由客户端 C_Spell 本地化；
-- IsPlayerSpell 过滤你未习得的技能(饰品/异族种族技能/未选天赋)。
function GearInsight:ShowRotationRef()
    if self.ShowHeroRotation and self:ShowHeroRotation() then return end
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
        f._modeHint:SetPoint("LEFT", f._modeBtn, "RIGHT", 8, 0); f._modeHint:SetPoint("RIGHT", f, "RIGHT", -16, 0)   -- 右沿封在窗口内，长了折行（09-21 用户「这里有文字出去了」）
        f._modeHint:SetJustifyH("LEFT"); f._modeHint:SetWordWrap(true); f._modeHint:SetMaxLines(2)
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
    -- 团本 BOSS 选择（用户 2026-09-17「把所有 M boss 都补充上」）：d.raids[mNum] 有哪只就能切哪只
    local bossList = {}
    if d.raids then for m in pairs(d.raids) do bossList[#bossList + 1] = m end; table.sort(bossList) end
    if #bossList == 0 and d.raid and d.raid.mNum then bossList[1] = d.raid.mNum end
    if not f._mBoss or not (d.raids and d.raids[f._mBoss]) then f._mBoss = (d.raid and d.raid.mNum) or bossList[1] end

    local render
    render = function()
        local blk = (f._mode == "raid" and d.raids and f._mBoss and d.raids[f._mBoss]) or d[f._mode]
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
        -- 返回 覆盖率%, 是否估算值；保密期（副本）里实测不到且没学到持续时间 → 返回 nil,"na"
        local function myUp(id, name)
            if not myOn then return nil end
            local s = my.aura[id] or 0
            for aid, sec in pairs(my.aura) do
                if aid ~= id and isVariantOf(aid, id, name) then s = s + sec end
            end
            local secretT = my.secretTime or 0
            if secretT > my.time * 0.5 then
                -- 大部分战斗在保密期：实测值基本是 0（只有开战前就挂着的能记到），改用施法推算
                local est = name and my.auraEst and my.auraEst[name]
                if est and est > 0 then return math.min(100, est / my.time * 100), "est" end
                if s <= 0 then return nil, "na" end
            end
            return s / my.time * 100
        end
        local function ratioColor(mine, top)
            if not top or top <= 0 then return "FFFFFF" end
            local r = mine / top
            if r >= 0.8 then return "55E055" elseif r >= 0.5 then return "FFD100" else return "FF5555" end
        end

        -- 场景按钮
        -- BOSS 名本地化：RotationData 只烘了中文 encCn（encId 是 WCL 的，不是手册的）；
        --   非中文客户端按 M 序反查 BisData.raidBossOrder 拿手册 encounterId → EJ 名（用户 2026-09-17 英文截图「Raid M2·陵寝哨兵」）
        local rb = (f._mode == "raid") and blk or d.raid
        local rotEncName = rb and (rb.encCn or "") or ""
        if rb and _LOCALE ~= "zhCN" and rb.mNum and EJ_GetEncounterInfo then
            local bo = self.BisData and self.BisData.raidBossOrder
            if bo then
                for eid, no in pairs(bo) do
                    if no == rb.mNum then
                        local okN, nm = pcall(EJ_GetEncounterInfo, eid)
                        if okN and nm and nm ~= "" then rotEncName = nm end
                        break
                    end
                end
            end
        end
        local raidLabel = rb and string.format("%s M%d·%s", T("ROT_MODE_RAID", "团本"),
            rb.mNum or 1, rotEncName) or nil
        f._modeBtn:SetText(f._mode == "raid" and (raidLabel or "") or T("ROT_MODE_MPLUS", "大秘境(冲分)"))
        -- 循环序列：M1 … M8 → 大秘境 → M1；右键反向
        local seq = {}
        for _, m in ipairs(bossList) do seq[#seq + 1] = { "raid", m } end
        if d.mplus then seq[#seq + 1] = { "mplus" } end
        if #seq > 1 then
            f._modeBtn:Enable()
            f._modeBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            f._modeBtn:SetScript("OnClick", function(_, button)
                local cur = 1
                for i, e in ipairs(seq) do
                    if e[1] == f._mode and (e[1] == "mplus" or e[2] == f._mBoss) then cur = i; break end
                end
                local nxt = (button == "RightButton") and ((cur - 2) % #seq + 1) or (cur % #seq + 1)
                f._mode = seq[nxt][1]
                if seq[nxt][2] then f._mBoss = seq[nxt][2] end
                render()
            end)
            f._modeHint:SetText((#bossList > 1) and T("ROT_MODE_HINT_BOSS", "← 左键下一只 BOSS / 大秘境，右键上一只（各 BOSS 循环差异很大）")
                                                  or T("ROT_MODE_HINT", "← 点击切换场景（两套循环差异很大）"))
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
                    local mine, kind = myUp(w[1], w[3])
                    local myStr
                    if mine then
                        myStr = string.format("   |cFF%s%s %s%.0f%%|r", ratioColor(mine, w[2]), T("ROT_MY", "你:"), (kind == "est") and "≈" or "", mine)
                    elseif kind == "na" then
                        myStr = "   |cFF888888" .. T("ROT_MY", "你:") .. " —|r"
                        row._tipLine = row._tipLine .. "\n|cFF888888" .. T("ROT_MY_NA_TIP", "副本里客户端不给增益数据，测不到；去木桩打一会儿学到持续时间后，副本里会按施法次数估算（标 ≈）。") .. "|r"
                    else
                        myStr = ""
                    end
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
