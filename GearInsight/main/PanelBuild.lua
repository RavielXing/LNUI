-- GearInsight/main/PanelBuild.lua — 主面板建帧 _ensurePanel
-- 2026-09-22 从 GearInsight.lua 拆出（纯搬家，逻辑未动）。共用 helper 见 GearInsight.lua 末尾的 GearInsight.Helpers。
local H = GearInsight.Helpers
local T, _LOCALE, _openSourceJournal = H.T, H.LOCALE, H.openSourceJournal

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

    -- 任何路径隐藏都把标志同步掉，别再出现「标志说开着、其实早关了」
    f:HookScript("OnHide", function() GearInsight._panelVisible = false end)

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
        GameTooltip:SetText(T("TALENT_TIP", "WCL 顶尖玩家天赋(团本/冲分/割草 各前5名) + PvP 榜首配置与专属天赋，选一套复制导入串"), 1, 1, 1, 1, true)
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
    -- ⛔ 参照系只有团本/大秘境两档。PvP 装备是独立页签（ui/PvpGearView.lua），⛔别再往这里塞第三档：
    --    0.80.0 试过，BisData 的参照系和它互相踩、盖层压住其它页签（2026-09-10 当天回滚）。
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

    -- 参照难度档 史诗/英雄/普通（用户 2026-09-14「英雄档怎么定的、怎么切」：原来只在小地图右键菜单和 /gi tier 里，
    -- 刷本助手的按钮 0.81.6 起又不再影响总览 → 总览页自己放一个）
    local tierBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    tierBtn:SetSize(130, 24)
    tierBtn:SetPoint("TOPLEFT", 16, -108)
    local function tierRefresh()
        tierBtn:SetText(T("TIER_BTN_LBL", "参照档: ") .. GearInsight:GearTierLabel())
        local fs = tierBtn:GetFontString()
        if fs then
            if GearInsight:GearTierStep() > 0 then fs:SetTextColor(0.35, 0.75, 1) else fs:SetTextColor(1, 0.82, 0) end
        end
    end
    tierRefresh()
    tierBtn:SetScript("OnClick", function()
        local cur = GearInsight:GetGearTier()
        local nxt = (cur == "mythic") and "heroic" or ((cur == "heroic") and "normal" or "mythic")
        GearInsight:SetGearTier(nxt)
        tierRefresh()
    end)
    tierBtn:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        GameTooltip:SetText(T("TIER_BTN_TIP", "BiS 参照难度档：史诗（默认，顶尖玩家原始数据）/ 英雄 / 普通。\n切到英雄或普通后，团本和套装件的目标装等按该档换算（每档 -13），毕业判定跟着变，大秘境件不变。\n也可用 /gi tier m|h|n。"), 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    tierBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    GearInsight._tierBtn = tierBtn
    GearInsight._tierBtnRefresh = tierRefresh

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
    self._stHdr = stHdr

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
    self._stInfo = stInfo

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

    -- 「查看专精」下拉（09-22 用户「要能把下面的属性达成度也切换」）：本职业任一专精 × 英雄天赋分支，
    -- 选中后属性优先级 + 四条达成度按那个专精的目标重算；「跟随当前专精」恢复。
    local sb = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    sb:SetPoint("LEFT", _prevModeBtn, "RIGHT", 8, 0); sb:SetHeight(18)
    self._statSpecBtn = sb
    function self:_updStatSpecBtn()
        local key = self._statSpecKey
        local txt = key and GearInsight.SpecKeyLabel(key) or T("STAT_SPEC_FOLLOW", "当前专精")
        sb:SetText(txt .. " |TInterface\\Buttons\\UI-SortArrow:8:10:0:0|t")   -- ⛔ 别用 ▾ 这类字符：游戏字体没有，画成方块（09-22 用户「特殊字符处理下」）；用暴雪表头排序小箭头贴图
        local fs = sb:GetFontString()
        sb:SetWidth(math.max(60, math.ceil((fs and fs:GetStringWidth() or 0) + 16)))
        if key then sb:LockHighlight() else sb:UnlockHighlight() end
    end
    sb:SetScript("OnClick", function(btn)
        if not (MenuUtil and MenuUtil.CreateContextMenu) then GearInsight:Print(T("LY_ROLE_MENU_NA", "这个客户端没有菜单接口")); return end
        local cur = self._curSpecData
        local class = cur and cur.className or select(2, UnitClass("player"))
        local keys = GearInsight.ClassSpecKeys(class)
        MenuUtil.CreateContextMenu(btn, function(_, root)
            root:CreateTitle(T("STAT_SPEC_MENU", "属性目标按哪个专精算"))
            root:CreateRadio(T("STAT_SPEC_FOLLOW", "当前专精"), function() return self._statSpecKey == nil end,
                function() self._statSpecKey = nil; self:RefreshData() end)
            root:CreateDivider()
            for _, k in ipairs(keys) do
                local d = GearInsight.BisData.specs[k]
                if d ~= cur then
                    root:CreateRadio(GearInsight.SpecKeyLabel(k), function() return self._statSpecKey == k end,
                        function() self._statSpecKey = k; self:RefreshData() end)
                end
            end
        end)
    end)
    sb:SetScript("OnEnter", function(x)
        GameTooltip:SetOwner(x, "ANCHOR_TOP")
        GameTooltip:SetText(T("STAT_SPEC_TIP", "查看专精"), 1, 0.82, 0)
        GameTooltip:AddLine(T("STAT_SPEC_TIP_BODY", "把下面的属性优先级和达成度切到本职业另一个专精的目标（用你现在的评级算）。只切属性区，BiS 列表和刷本规划仍按你的真实专精。"), 0.9, 0.9, 0.9, true)
        GameTooltip:Show()
    end)
    sb:SetScript("OnLeave", function() GameTooltip:Hide() end)
    self:_updStatSpecBtn()

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
    self._sep2 = sep2

    -- ── Upgrade section ───────────────────────────────────────────
    local upHdr = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    upHdr:SetPoint("TOPLEFT", 20, -286)
    upHdr:SetText(T("SECTION_NEXT", "下一步建议"))
    upHdr:SetTextColor(1, 0.82, 0)
    self._upHdr = upHdr

    -- ScrollFrame
    local scroll = CreateFrame("ScrollFrame", "GearInsightScrollFrame", f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 16, -308)
    scroll:SetPoint("BOTTOMRIGHT", -28, 70)
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
                if self._tgtMx then GameTooltip:AddLine(string.format(T("TT_BIS_TOPMX", "顶尖玩家最高见到 %d"), self._tgtMx), 0.7, 0.7, 0.7) end
            end
            if self._improvementPct and self._improvementPct > 0 then
                GameTooltip:AddLine(string.format(T("TT_IMPROVE", "提升幅度: +%.1f%%"), self._improvementPct), 0.2, 1, 0.2)
            end
            -- ⛔ 来源行不再自己加：TooltipHook 已给 BiS 件追加「掉落：大秘境 · 副本 · BOSS」，
            --    这里再加一条「掉落: 大秘境-副本」= 同一信息两遍（用户 2026-09-14「来源标注是不是重复了」）。
            --    只有 TooltipHook 没接管（非 BiS 件/钩子失效）时才补。
            if self._tgtSrc and self._tgtSrc ~= "" and not (GearInsight.TooltipHookActive and GearInsight.TooltipHookActive(self.itemID)) then
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
                -- 行里已经写出是哪件坯子了，那就让鼠标能看到它的完整属性
                -- （对齐网站「待刷装备」表的悬停行为）
                if self._fillerItemId then
                    if self._fillerLink then GameTooltip:SetHyperlink(self._fillerLink)
                    else GameTooltip:SetItemByID(self._fillerItemId) end
                    GameTooltip:AddLine(T("TT_TIER_CLICK", "点击查看可催化的同部位装备"), 0.8, 0.8, 0.8)
                else
                    GameTooltip:SetText(T("TT_TIER_CLICK", "点击查看可催化的同部位装备"), 0.8, 0.8, 0.8)
                end
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
                GearInsight:ShowTierFiller(self._tierArmor, self._tierSlot, self._tierLabel, self._tierSrcs, self._tierBonus, self._tierStats, self._tierStatPct, self._tierItem)
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
    -- 三个按钮居中一排：刷本优先级 | 多专精拾取 | 刷新数据
    -- （「关闭面板」2026-09-01 用户要求去掉——右上角已经有 X，重复了）
    local btnW, btnH = 112, 26
    local gap = 6
    local unit = btnW + gap        -- center-to-center spacing
    local btnF = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    btnF:SetPoint("BOTTOM", -unit, 14)
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
        -- 刷本优先级已并入「刷本助手」页签（2026-09-11）；按钮留着当入口
        if GearInsight._selectMainTab then pcall(GearInsight._selectMainTab, "wish"); return end
        GearInsight:ShowFarmingGuide(c, s, h)
    end)

    -- Multi-spec loot planner entry (moved here from the farming guide panel)
    local btnMS = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    btnMS:SetPoint("BOTTOM", 0, 14)
    btnMS:SetSize(btnW, btnH)
    btnMS:SetText(T("MS_BTN_OPEN", "多专精拾取"))
    btnMS:SetScript("OnClick", function()
        -- 多专精查看已并入「刷本助手」页的专精行（2026-09-12）；按钮留着当入口
        if GearInsight._selectMainTab then pcall(GearInsight._selectMainTab, "wish"); return end
        local cc
        if GearInsight.StatReader then cc = GearInsight.StatReader:ReadAll().class end
        if cc then GearInsight:ShowMultiSpecPlan(cc) end
    end)

    local btnR = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    btnR:SetPoint("BOTTOM", unit, 14)
    btnR:SetSize(btnW, btnH)
    btnR:SetText(T("BTN_REFRESH", "刷新数据"))
    btnR:SetScript("OnClick", function() GearInsight:RefreshData(true) end)

    -- 网页版角色主页（gearinsight.app SSR 角色页：战力评分/AI教练/BiS缺件）。
    -- 插件沙箱开不了浏览器，点击弹复制框；与右侧 QQ/TG 按钮同行。
    local webBtn = CreateFrame("Button", nil, f)
    webBtn:SetPoint("BOTTOM", -115, 48)
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
    qqBtn:SetPoint("BOTTOM", 115, 48)
    qqBtn:SetSize(220, 18)
    -- 简中客户端→QQ群；其他语言客户端→Telegram 群(面向海外)。
    local isCN = (_LOCALE == "zhCN")
    local TG_LINK = "t.me/gearInsight"
    -- 2026-08-28：1 群人数上限开到 2000 后只留这一个群，2 群不再在插件里露出
    -- （用户指示）。⛔ 一个入口最省事：两个群号并列会让人纠结加哪个，还得维护两处。
    local QQ_NUM = "954673901"
    local qqBtnText = qqBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    qqBtnText:SetAllPoints()
    qqBtnText:SetJustifyH("CENTER")  -- 摆位由 MainTabs 决定（当前：底部居中单独一行）
    qqBtn._giText = qqBtnText
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
    srcText:SetPoint("BOTTOMRIGHT", -14, 12)
    srcText:SetJustifyH("RIGHT")
    srcText:SetText(T("DATA_FOOTER", "至暗之夜 S2 · WCL · 更新 ") .. verDate)
    srcText:SetTextColor(0.45, 0.45, 0.45)

    -- Version / author (centered, tiny — top of the footer stack)
    local author = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    author:SetPoint("BOTTOMRIGHT", -14, 26)
    author:SetJustifyH("RIGHT")
    local verStr = (C_AddOns and C_AddOns.GetAddOnMetadata
        and C_AddOns.GetAddOnMetadata("GearInsight", "Version"))
        or (GetAddOnMetadata and GetAddOnMetadata("GearInsight", "Version"))
        or "0.17.1"
    author:SetText("v" .. verStr .. " · " .. T("AUTHOR_BY", "作者") .. (_LOCALE == "zhCN" and " 枫叶大象-格瑞姆巴托/yinpeng" or " MapleElephant-Grim Batol"))
    author:SetTextColor(0.35, 0.35, 0.35)

    -- 左侧标签页（ui/MainTabs.lua）：功能按钮归拢成翻页，总览只留装备内容。
    -- 引用在这里存一份，MainTabs 把它们 SetParent 到各自的页上（点击逻辑不动）。
    self._tabRefs = { export = exportBtn, talent = talentBtn, rot = rotBtn, dg = dgBtn,
        mode = modeBtn, exRaid = exRaidBtn, tier = tierBtn, tip = tipBtn, farm = btnF, ms = btnMS,
        refresh = btnR, web = webBtn, qq = qqBtn }
    self._panelFrame = f
    if self.BuildMainTabs then self:BuildMainTabs(f) end
end
