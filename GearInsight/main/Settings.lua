-- GearInsight/main/Settings.lua — 使用率模式 / 装备档位 / 网页档案 / 悬浮提示菜单 / 帮助
-- 2026-09-22 从 GearInsight.lua 拆出（纯搬家，逻辑未动）。共用 helper 见 GearInsight.lua 末尾的 GearInsight.Helpers。
local H = GearInsight.Helpers
local T, _SITE = H.T, H.SITE

function GearInsight:SetUsageMode(mode)
    GearInsightDB = GearInsightDB or {}
    -- ⛔ 只认 raid/mplus；0.80.0 存过 "pvp" 的老档案要纠回来，否则 BisData 池对不上
    if mode ~= "raid" and mode ~= "mplus" then mode = "raid" end
    GearInsightDB.usageMode = mode
    if self.BisData and self.BisData.SetUsageMode then
        self.BisData:SetUsageMode(mode)
    end
    if self._panelFrame then self:RefreshPanel() end
    self:_refreshOpenPopups()
    if self._modeBtnRefresh then self._modeBtnRefresh() end
    local label = (mode == "mplus") and T("USAGE_MPLUS", "大秘境") or T("USAGE_RAID", "团本")
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
    if self._tierBtnRefresh then self._tierBtnRefresh() end
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
    if self._tierBtnRefresh then self._tierBtnRefresh() end
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
    return "https://" .. _SITE .. "/wow/en/c/" .. region .. "/" .. realm .. "/" .. name
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
    self:Print(T("HELP_LINE", "/gi - 面板 | /gi config - 设置总表 | /gi farming - 刷装指南 | /gi need - 拾取需求单 | /gi team - 团队BiS体检 | /gi guild - 公会花名册 | /gi cbis - 角色面板BiS图标开关 | /gi minimap - 找回小地图图标 | /gi status - 状态 | /gi refresh - 刷新 | /gi dumpids - 导出ID | /gi help"))
end
