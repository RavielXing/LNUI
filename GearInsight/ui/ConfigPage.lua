-- ConfigPage.lua — 设置总表：插件所有开关一屏列齐（2026-09-06 玩家反馈「能否做一个总的配置表」，
-- 用户：「所有开关配置放到一个页面，不要散落在各个页面里，难找」）。
--
-- 同一份内容挂两处：① 主面板「设置」页（MainTabs 的 pgSet）② ESC → 选项 → 插件 → GearInsight。
-- ⛔ 这里只读写 GearInsightDB 并调各模块已暴露的刷新入口，不复制任何业务逻辑；
--    某个开关的语义变了，改它自己的模块，这页只是遥控器。
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

local function db()
    GearInsightDB = GearInsightDB or {}
    return GearInsightDB
end

-- ── 开关定义：get() 返回 true=开；set(on) 落盘并刷新 ─────────────────────────
local function pdbCfg()
    local c = db().paperDollBis
    if not c then c = {}; db().paperDollBis = c end
    if c.enabled == nil then c.enabled = false end--lnui
    return c
end
local function ttCfg()
    if GearInsight._tooltipBisCfg then return GearInsight._tooltipBisCfg() end
    local c = db().tooltipBis
    if not c then c = {}; db().tooltipBis = c end
    if c.enabled == nil then c.enabled = true end
    return c
end
local function refreshPdb() if GearInsight.RefreshPaperDollBis then pcall(GearInsight.RefreshPaperDollBis) end end
local function refreshKt() if GearInsight.KeyTimelineRefresh then pcall(GearInsight.KeyTimelineRefresh, GearInsight) end end

local POS_ORDER = { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }
local POS_LABEL = {
    TOPLEFT = { "CFG_POS_TL", "左上" }, TOPRIGHT = { "CFG_POS_TR", "右上" },
    BOTTOMLEFT = { "CFG_POS_BL", "左下" }, BOTTOMRIGHT = { "CFG_POS_BR", "右下" },
}

local function sections()
    return {
        {
            title = T("CFG_SEC_PANEL", "角色面板与悬浮提示"),
            rows = {
                { kind = "check", label = T("CFG_PDB", "角色面板 BiS 图标"),
                  desc = T("CFG_PDB_D", "打开角色面板时，每个部位角上显示该部位的毕业件小图标，悬停看来源。"),
                  get = function() return pdbCfg().enabled end,
                  set = function(on) pdbCfg().enabled = on; refreshPdb() end },
                { kind = "slider", label = T("CFG_PDB_SIZE", "图标大小"), min = 10, max = 30, step = 1,
                  get = function() return pdbCfg().iconSize or 16 end,
                  set = function(v) pdbCfg().iconSize = v; refreshPdb() end },
                { kind = "cycle", label = T("CFG_PDB_POS", "图标位置"),
                  desc = T("CFG_PDB_POS_D", "挡住别的插件的装等数字时换个角。"),
                  options = POS_ORDER,
                  text = function(v) local p = POS_LABEL[v]; return p and T(p[1], p[2]) or v end,
                  get = function() return pdbCfg().iconPos or "TOPRIGHT" end,
                  set = function(v) pdbCfg().iconPos = v; refreshPdb() end },
                { kind = "check", label = T("CFG_TT", "物品悬浮提示里的 BiS 行"),
                  desc = T("CFG_TT_D", "鼠标放到任何装备上，提示里多出「GearInsight」段：本职业各专精排名、来源、最火附魔。"),
                  get = function() return ttCfg().enabled ~= false end,
                  set = function(on) ttCfg().enabled = on end },
                { kind = "check", label = T("CFG_TT_OTHERS", "悬浮提示也显示其它职业"), indent = true,
                  get = function() return ttCfg().showOthers == true end,
                  set = function(on) ttCfg().showOthers = on end },
                { kind = "check", label = T("CFG_TT_SRC", "悬浮提示显示来源行"), indent = true,
                  get = function() return ttCfg().showSource ~= false end,
                  set = function(on) ttCfg().showSource = on end },
                { kind = "check", label = T("CFG_INSPECT", "检视队友时显示对方的 BiS 差距"),
                  desc = T("CFG_INSPECT_D", "检视窗口旁多一个小面板，看队友还缺哪几件。"),
                  get = function() return db().inspectBisOn == true end,
                  set = function(on) db().inspectBisOn = on or nil end },
                { kind = "check", label = T("CFG_GEARVIEW", "装备总览默认用「装备图」"),
                  desc = T("CFG_GEARVIEW_D", "关掉则用旧的列表视图。面板右上角随时可切。"),
                  get = function() return db().gearView ~= "list" end,
                  set = function(on) db().gearView = on and "map" or "list"; if GearInsight.RefreshPanel then pcall(GearInsight.RefreshPanel, GearInsight) end end },
            },
        },
        {
            title = T("CFG_SEC_DM", "副本助手（大米攻略 / 临场提示 / 钥匙时间轴）"),
            rows = {
                { kind = "check", label = T("CFG_DM", "进大秘境自动加载副本助手"),
                  desc = T("CFG_DM_D", "默认关。开了才会在进本时加载下面三样；关掉后模块不加载、不占内存。"),
                  get = function() return db().dungeonModule == "on" end,
                  set = function(on)
                      db().dungeonModule = on and "on" or "off"
                      if on and GearInsight.LoadDungeonModule then pcall(GearInsight.LoadDungeonModule, GearInsight, false) end
                  end },
                { kind = "check", label = T("CFG_DM_POPUP", "进本自动弹出大米攻略"), indent = true,
                  desc = T("CFG_DM_POPUP_D", "打断优先级 / 致死技能 / 承伤构成。关掉后仍可点面板「大米攻略」手动看。"),
                  get = function() return not db().dungeonAutoPopupOff end,
                  set = function(on) db().dungeonAutoPopupOff = (not on) or nil end },
                { kind = "check", label = T("CFG_LG", "临场提示（必断 / 致死技能高亮）"), indent = true,
                  get = function() return not db().liveGuideOff end,
                  set = function(on) db().liveGuideOff = (not on) or nil end },
                { kind = "check", label = T("CFG_KT", "钥匙时间轴（嗜血点预告 + Boss 节奏对比顶尖局）"), indent = true,
                  desc = T("CFG_KT_D", "就是进本后屏幕中上那条进度条。命令：/gi kt off 关、/gi kt on 开。"),
                  get = function() return not db().keyTimelineOff end,
                  set = function(on) db().keyTimelineOff = (not on) or nil; refreshKt() end },
                { kind = "slider", label = T("CFG_KT_SCALE", "时间轴大小"), indent = true, min = 80, max = 200, step = 10, pct = true, deferred = true,
                  get = function() return math.floor((tonumber(db().keyTimelineScale) or 1) * 100 + 0.5) end,
                  set = function(pctv)
                      db().keyTimelineScale = pctv / 100
                      if GearInsight.KeyTimelineSetScale then pcall(GearInsight.KeyTimelineSetScale, GearInsight, pctv / 100)
                      elseif GearInsight.LoadDungeonModule and GearInsight:LoadDungeonModule(false) and GearInsight.KeyTimelineSetScale then pcall(GearInsight.KeyTimelineSetScale, GearInsight, pctv / 100) end
                  end },
                { kind = "buttons", label = T("CFG_KT_POS", "时间轴位置"), indent = true,
                  buttons = {
                      { T("CFG_KT_UNLOCK", "解锁拖动"), function() if GearInsight.LoadDungeonModule and GearInsight:LoadDungeonModule(false) and GearInsight.KeyTimelineSetUnlocked then GearInsight:KeyTimelineSetUnlocked(true) end end },
                      { T("CFG_KT_LOCK", "锁定"), function() if GearInsight.KeyTimelineSetUnlocked then GearInsight:KeyTimelineSetUnlocked(false) end end },
                      { T("CFG_KT_RESET", "复位"), function() if GearInsight.LoadDungeonModule and GearInsight:LoadDungeonModule(false) and GearInsight.KeyTimelineResetPos then GearInsight:KeyTimelineResetPos() end end },
                  } },
            },
        },
        {
            title = T("CFG_SEC_ALERT", "提醒与附加"),
            rows = {
                { kind = "check", label = T("CFG_WISH", "心愿单掉落提醒"),
                  desc = T("CFG_WISH_D", "队伍里掉了你心愿单上的件时弹窗提醒。"),
                  get = function() return not db().wishAlertOff end,
                  set = function(on) db().wishAlertOff = (not on) or nil end },
                { kind = "buttons", label = T("CFG_WHISPER", "私聊要装备的话术"), indent = true,
                  desc = T("CFG_WHISPER_D",
                           "弹窗里点「私聊」时预填的内容。可用 {item} 那件装备、{cur} 你当前这件、{gain} 提升装等、{slot} 部位、{me} 你的名字。留空用默认。"),
                  -- ⛔ 字段名必须是 `buttons`，元素形态必须是 {文案, 回调} 的数组对：
                  --    渲染器读的是 `row.buttons` 和 `bt[1]`/`bt[2]`。
                  --    写成 items={{text=,click=}} 时 ipairs(nil) 当场抛错，
                  --    整个设置页从这一行往下全部不再渲染，且结尾的 sync() 永不执行
                  --    → 所有勾选框显示成未勾（2026-09-08 用户报「刚进来没有预读取当前的状态」）。
                  buttons = {
                      { T("CFG_WHISPER_EDIT", "编辑"), function()
                            if GearInsight.ShowWhisperEditor then
                                GearInsight:ShowWhisperEditor()
                            end
                        end },
                      { T("CFG_WHISPER_RESET", "恢复默认"), function()
                            db().whisperTpl = nil
                            if GearInsight.Print then
                                GearInsight:Print(T("CFG_WHISPER_RESET_OK", "私聊话术已恢复默认。"))
                            end
                        end },
                  } },
                { kind = "slider", label = T("CFG_TGT_ILVL", "心愿单目标装等"), indent = true,
                  min = 0, max = 350, step = 1, deferred = true,
                  desc = T("CFG_TGT_ILVL_D", "只按你自己的目标算差距：到了这个装等的部位就从心愿单里消失。0 = 跟顶尖玩家口径（默认）。赛季初只打大秘境的话，设成你这周实际拿得到的上限最有用。"),
                  get = function() return math.floor(tonumber(db().targetIlvl) or 0) end,
                  set = function(v)
                      v = math.floor(tonumber(v) or 0)
                      db().targetIlvl = (v > 0) and v or nil
                  end },
                -- （「钥石窗口旁附带大秘境情报」开关 2026-09-10 撤掉：贴片 09-02 就已下线，
                --   情报页 09-10 整页下线，插件里已经没有这份数据。）
            },
        },
        {
            title = T("CFG_SEC_MAIN", "主面板"),
            rows = {
                -- ⛔ 缩放滑条必须 deferred：这页就在主面板里，拖动中实时 SetScale 会把滑条本身从鼠标底下缩走，
                --    鼠标位置立刻映射到两端 —— 用户 2026-09-06 截图「点了只能从 60 跳到 150」。松手再应用。
                --    数值也改成整数百分比（60~150 步进 5），WoW 的滑条对小数步进不稳。
                { kind = "slider", label = T("CFG_SCALE", "面板缩放"), min = 60, max = 150, step = 5, pct = true, deferred = true,
                  get = function() return math.floor((db().panelScale or 1.0) * 100 + 0.5) end,
                  set = function(pctv)
                      local v = pctv / 100
                      db().panelScale = v
                      if GearInsight._panelFrame then GearInsight._panelFrame:SetScale(v) end
                      if GearInsight._scaleLabel then GearInsight._scaleLabel:SetText(string.format("%.0f%%", v * 100)) end
                  end },
                { kind = "cycle", label = T("CFG_USAGE", "使用率参照"),
                  desc = T("CFG_USAGE_D", "毕业件排序、使用率、刷取规划都跟着这个口径走。"),
                  options = { "raid", "mplus" },
                  text = function(v) return v == "mplus" and T("CFG_USAGE_MPLUS", "大秘境顶尖玩家") or T("CFG_USAGE_RAID", "团本顶尖玩家") end,
                  get = function() return db().usageMode or "raid" end,
                  set = function(v) db().usageMode = v; if GearInsight.RefreshPanel then pcall(GearInsight.RefreshPanel, GearInsight) end end },
                { kind = "check", label = T("CFG_EXRAID", "团本装备：排除（只推大秘境能拿的）"),
                  get = function() return db().excludeRaid == true end,
                  set = function(on) if GearInsight.SetExcludeRaid then pcall(GearInsight.SetExcludeRaid, GearInsight, on) else db().excludeRaid = on end end },
                { kind = "buttons", label = T("CFG_RESETPOS", "复位所有窗口位置"),
                  buttons = {
                      { T("CFG_RESETPOS_BTN", "复位"), function()
                          local d = db()
                          d.keyTimelinePos, d.wishPopupPos, d.liveGuidePos, d.parseCardPos, d.panelPosition, d.minimapPos = nil, nil, nil, nil, nil, nil
                          if GearInsight.Print then GearInsight:Print(T("CFG_RESETPOS_DONE", "窗口位置已复位，/reload 后生效。")) end
                      end },
                  } },
            },
        },
    }
end

-- ── 渲染 ────────────────────────────────────────────────────────────────────
local function build(parent, topOffset)
    local sf = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 8, topOffset or -8)
    sf:SetPoint("BOTTOMRIGHT", -28, 8)
    local content = CreateFrame("Frame", nil, sf)
    content:SetSize(1, 1)
    sf:SetScrollChild(content)
    sf:SetScript("OnSizeChanged", function(s, w) content:SetWidth(math.max(200, w)) end)
    content:SetWidth(math.max(200, sf:GetWidth() > 0 and sf:GetWidth() or 480))

    local widgets = {}
    local y = -4
    local function fs(template, x, yy, text, w)
        local f = content:CreateFontString(nil, "OVERLAY", template)
        f:SetPoint("TOPLEFT", x, yy)
        if w then f:SetPoint("RIGHT", content, "RIGHT", -8, 0) end
        f:SetJustifyH("LEFT"); f:SetWordWrap(true); f:SetText(text)
        return f
    end

    for _, sec in ipairs(sections()) do
        local h = fs("GameFontNormalLarge", 6, y, sec.title, true)
        h:SetTextColor(0.84, 0.70, 0.42)
        y = y - 26
        local line = content:CreateTexture(nil, "ARTWORK")
        line:SetPoint("TOPLEFT", 6, y + 4); line:SetPoint("RIGHT", content, "RIGHT", -8, 0)
        line:SetHeight(1); line:SetColorTexture(1, 1, 1, 0.08)
        for _, row in ipairs(sec.rows) do
          -- ⛔⛔ 单行渲染出错**绝不许掐断整页**。2026-09-08 一行的字段名写错
          --    （items 写成了 buttons 该有的名字），ipairs(nil) 抛错，
          --    于是这一行之后的所有设置项都不再渲染，**而且结尾的 sync() 永不执行**
          --    → 玩家看到的是「所有开关都没打勾」，看起来像状态没读到，
          --    真身却是页面构建在半路死了。一个字段名错，整页设置全废。
          --    错行跳过、其余照常渲染、sync() 照常跑，是这里唯一可接受的行为。
          local okRow = pcall(function()
            local x = row.indent and 26 or 8
            if row.kind == "check" then
                local cb = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
                cb:SetSize(24, 24); cb:SetPoint("TOPLEFT", x, y + 2)
                local lb = fs("GameFontHighlight", x + 26, y - 4, row.label, true)
                cb:SetScript("OnClick", function(s) row.set(s:GetChecked() and true or false) end)
                cb._row = row
                widgets[#widgets + 1] = cb
                y = y - 26
                if row.desc then
                    local d = fs("GameFontHighlightSmall", x + 26, y + 4, row.desc, true)
                    d:SetTextColor(0.6, 0.6, 0.66)
                    y = y - (d:GetStringHeight() > 14 and 30 or 18)
                end
            elseif row.kind == "slider" then
                local lb = fs("GameFontHighlight", x, y - 2, row.label)
                local sl = CreateFrame("Slider", nil, content, "OptionsSliderTemplate")
                sl:SetPoint("TOPLEFT", x + 150, y - 4); sl:SetSize(180, 16)
                sl:SetMinMaxValues(row.min, row.max); sl:SetValueStep(row.step); sl:SetObeyStepOnDrag(true)
                if sl.Low then sl.Low:SetText("") end
                if sl.High then sl.High:SetText("") end
                local val = fs("GameFontHighlight", x + 340, y - 2, "")
                local function show(v) val:SetText(row.pct and string.format("%d%%", math.floor(v + 0.5)) or tostring(math.floor(v + 0.5))) end
                sl:SetScript("OnValueChanged", function(s, v, user)
                    v = math.floor(v / row.step + 0.5) * row.step
                    show(v)
                    if user and not row.deferred then row.set(v) end
                end)
                if row.deferred then
                    -- 松手才应用（见 CFG_SCALE 注释）；键盘/滚轮改值没有 MouseUp，也在 OnValueChanged 里延后 0.2s 应用一次
                    sl:SetScript("OnMouseUp", function(s) local v = math.floor(s:GetValue() / row.step + 0.5) * row.step; row.set(v) end)
                end
                sl._row = row; sl._show = show
                widgets[#widgets + 1] = sl
                y = y - 32
            elseif row.kind == "cycle" then
                local lb = fs("GameFontHighlight", x, y - 6, row.label)
                local b = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
                b:SetSize(170, 22); b:SetPoint("TOPLEFT", x + 150, y - 2)
                b:SetScript("OnClick", function(s)
                    local cur, opts = row.get(), row.options
                    local idx = 1
                    for i, v in ipairs(opts) do if v == cur then idx = i end end
                    local nv = opts[idx % #opts + 1]
                    row.set(nv); s:SetText(row.text(nv))
                end)
                b._row = row
                widgets[#widgets + 1] = b
                y = y - 28
                if row.desc then
                    local d = fs("GameFontHighlightSmall", x, y + 2, row.desc, true)
                    d:SetTextColor(0.6, 0.6, 0.66)
                    y = y - 18
                end
            elseif row.kind == "buttons" then
                local lb = fs("GameFontHighlight", x, y - 6, row.label)
                local bx = x + 150
                -- ⛔ `or {}` 不是防御性冗余：字段名写错时这里会 ipairs(nil) 抛错，
                --    而这个错误会掐断整个设置页的构建（见上方 CFG_WHISPER 注释）。
                for _, bt in ipairs(row.buttons or {}) do
                    local b = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
                    b:SetSize(84, 22); b:SetPoint("TOPLEFT", bx, y - 2)
                    b:SetText(bt[1]); b:SetScript("OnClick", function() pcall(bt[2]) end)
                    bx = bx + 90
                end
                y = y - 30
                -- buttons 行原来不画 desc：传了也静默丢掉，说明文字凭空消失
                if row.desc then
                    local d = fs("GameFontHighlightSmall", x, y + 2, row.desc, true)
                    d:SetTextColor(0.6, 0.6, 0.66)
                    y = y - (d:GetStringHeight() > 14 and 26 or 14)
                end
            end
          end)
          if not okRow then
              -- ⛔ 别静默跳过：留一行占位，否则少了一个开关谁也不知道
              local w = fs("GameFontRedSmall", 8, y, "· " .. tostring(row.label or "?"), true)
              if w then w:SetTextColor(0.8, 0.4, 0.4) end
              y = y - 18
          end
        end
        y = y - 12
    end
    local tip = fs("GameFontHighlightSmall", 8, y, T("CFG_FOOT", "改动即时生效并自动保存。命令行：/gi config 打开本页。"), true)
    tip:SetTextColor(0.5, 0.5, 0.56)
    y = y - 24
    content:SetHeight(-y + 10)

    local function sync()
        for _, w in ipairs(widgets) do
            -- ⛔ 逐个 pcall：一个 get() 抛错会让它后面的控件全部不同步，
            --   症状同样是「开关没读到当前状态」，但只坏一半，更难查。
            pcall(function()
                local r = w._row
                if r.kind == "check" then w:SetChecked(r.get() and true or false)
                elseif r.kind == "slider" then local v = r.get(); w:SetValue(v); if w._show then w._show(v) end
                elseif r.kind == "cycle" then w:SetText(r.text(r.get())) end
            end)
        end
    end
    parent:HookScript("OnShow", sync)
    sync()
    if GearInsight.Skin and GearInsight.Skin.Sweep then pcall(GearInsight.Skin.Sweep, content) end
    return sf, sync
end
GearInsight.BuildConfigPage = build

-- ── ESC → 选项 → 插件 → GearInsight ──────────────────────────────────────────
function GearInsight:RegisterConfigCategory()
    if self._cfgCategory then return end
    if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then return end
    local canvas = CreateFrame("Frame")
    canvas.name = "GearInsight"
    canvas:SetScript("OnShow", function(s)
        if not s._built then
            s._built = true
            local title = s:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            title:SetPoint("TOPLEFT", 12, -12); title:SetText("GearInsight · " .. T("CFG_TITLE", "设置总表"))
            local open = CreateFrame("Button", nil, s, "UIPanelButtonTemplate")
            open:SetSize(150, 22); open:SetPoint("TOPRIGHT", -30, -10)
            open:SetText(T("CFG_OPEN_PANEL", "打开插件面板"))
            open:SetScript("OnClick", function() if GearInsight.TogglePanel then GearInsight:TogglePanel() end end)
            build(s, -40)
        end
    end)
    local ok, cat = pcall(Settings.RegisterCanvasLayoutCategory, canvas, "GearInsight")
    if ok and cat then
        pcall(Settings.RegisterAddOnCategory, cat)
        self._cfgCategory = cat
    end
end

-- /gi config：打开主面板并切到设置页
function GearInsight:OpenConfig()
    if not (self._panelFrame and self._panelFrame:IsShown()) and self.TogglePanel then self:TogglePanel() end
    if self._selectMainTab then pcall(self._selectMainTab, "settings") end
end
