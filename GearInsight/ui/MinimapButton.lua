-- MinimapButton.lua
-- Adds a minimap button to toggle the GearInsight panel.
-- 0.35.1 重写：旧版用固定 TOPLEFT 偏移钉死位置（12.0 小地图尺寸变化后飘出圆边），
-- 且 tracking 边框 SetAllPoints 后再设 53x53 被忽略（边框被压进 31x31，图标层错位）。
-- 现改为标准做法：按角度沿小地图圆边定位 + 可拖动 + 位置存 GearInsightDB.minimapPos。

GearInsight = GearInsight or {}
local MinimapButton = {}

-- 本文件原来没有本地化函数（只有几个 tooltip 走 addon.L）。新加的提示要能翻译，
-- ⛔ 但别引 addon.L —— 那张表是主插件的运行时表，这里 Create 之前就可能用到。
local _MB_LOCALE = GearInsight and GearInsight.LOCALE or (GetLocale and GetLocale()) or "enUS"
local function MB_T(key, zh)
    if _MB_LOCALE == "zhCN" then return zh end
    local L = GearInsight.LOC or {}
    local cur = L[_MB_LOCALE]
    if cur and cur[key] then return cur[key] end
    if _MB_LOCALE ~= "zhTW" then
        local en = L["enUS"]
        if en and en[key] then return en[key] end
    end
    return zh
end

local BUTTON_NAME = "GearInsightMinimapButton"
-- 用插件自己的图标（icon.tga，与插件列表里那张同一份），⛔别用暴雪通用小玩意图标——
-- 十几个插件的小地图按钮挤在一起时认不出哪个是 GearInsight（用户 2026-09-10 截图）。
local ICON_TEXTURE = "Interface\\AddOns\\GearInsight\\icon"
local DEFAULT_ANGLE = 200   -- 度；左下方，避开默认追踪/日历按钮

local function GetAngle()
    GearInsightDB = GearInsightDB or {}
    return GearInsightDB.minimapPos or DEFAULT_ANGLE
end

local function SetAngle(deg)
    GearInsightDB = GearInsightDB or {}
    GearInsightDB.minimapPos = deg
end

-- 小地图形状 → 四象限是否为圆角（LibDBIcon 约定，象限序：右下/左下/右上/左上）
-- 方形小地图插件(ElvUI/SexyMap等)会暴露全局 GetMinimapShape() 返回 "SQUARE" 等
local MINIMAP_SHAPES = {
    ["ROUND"]                 = { true,  true,  true,  true  },
    ["SQUARE"]                = { false, false, false, false },
    ["CORNER-TOPLEFT"]        = { false, false, false, true  },
    ["CORNER-TOPRIGHT"]       = { false, false, true,  false },
    ["CORNER-BOTTOMLEFT"]     = { false, true,  false, false },
    ["CORNER-BOTTOMRIGHT"]    = { true,  false, false, false },
    ["SIDE-LEFT"]             = { false, true,  false, true  },
    ["SIDE-RIGHT"]            = { true,  false, true,  false },
    ["SIDE-TOP"]              = { false, false, true,  true  },
    ["SIDE-BOTTOM"]           = { true,  true,  false, false },
    ["TRICORNER-TOPLEFT"]     = { false, true,  true,  true  },
    ["TRICORNER-TOPRIGHT"]    = { true,  false, true,  true  },
    ["TRICORNER-BOTTOMLEFT"]  = { true,  true,  false, true  },
    ["TRICORNER-BOTTOMRIGHT"] = { true,  true,  true,  false },
}

-- 按角度贴小地图边缘；支持方形/混合形状小地图（玩家反馈：方形图上拖动轨迹仍是圆）
local function UpdatePosition(btn)
    local rad = math.rad(GetAngle())
    local x, y = math.cos(rad), math.sin(rad)
    local q = 1
    if x < 0 then q = q + 1 end
    if y > 0 then q = q + 2 end

    local shape = (GetMinimapShape and GetMinimapShape()) or "ROUND"
    local quads = MINIMAP_SHAPES[shape] or MINIMAP_SHAPES["ROUND"]
    local w = (Minimap:GetWidth() / 2) + 5
    local h = (Minimap:GetHeight() / 2) + 5

    if quads[q] then
        -- 该象限是圆角：沿椭圆边
        x, y = x * w, y * h
    else
        -- 该象限是直角：沿对角线半径外推后钳回矩形边界
        local diagW = math.sqrt(2 * w * w) - 10
        local diagH = math.sqrt(2 * h * h) - 10
        x = math.max(-w, math.min(x * diagW, w))
        y = math.max(-h, math.min(y * diagH, h))
    end

    -- ⛔ 被收纳插件接管后不再自己摆（见 Create 里的 SetPoint 钩子）。
    --    拖动例外：玩家亲手拖，说明就是想让我们来摆。
    if btn._takenOver and not btn._dragging then return end
    btn._selfPlacing = true
    btn:ClearAllPoints()
    btn:SetPoint("CENTER", Minimap, "CENTER", x, y)
    btn._selfPlacing = false
end

function MinimapButton:Create(addon)
    self.addon = addon

    if _G[BUTTON_NAME] then
        _G[BUTTON_NAME]:Show()
        UpdatePosition(_G[BUTTON_NAME])
        return
    end

    local btn = CreateFrame("Button", BUTTON_NAME, Minimap)
    btn:SetSize(31, 31)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)
    btn:RegisterForDrag("LeftButton")
    btn:SetMovable(true)

    -- 标准三层结构（LibDBIcon 同款布局）：
    -- 背景圆片(中心) → 图标(中心偏移) → 53x53 tracking 边框(锚 TOPLEFT、只锚一角)
    local backdrop = btn:CreateTexture(nil, "BACKGROUND")
    backdrop:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    backdrop:SetSize(20, 20)
    backdrop:SetPoint("CENTER", 0, 1)
    backdrop:SetVertexColor(0, 0, 0, 0.5)

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetPoint("CENTER", 0, 1)
    icon:SetTexture(ICON_TEXTURE)
    icon:SetTexCoord(0.04, 0.96, 0.04, 0.96)   -- 自家图标四边本来就留了边，少裁一点

    local overlay = btn:CreateTexture(nil, "OVERLAY")
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    overlay:SetSize(53, 53)
    overlay:SetPoint("TOPLEFT")   -- 只锚一角，保住 53x53，边框才对得上图标

    btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    UpdatePosition(btn)

    -- ⛔⛔ 玩家 2026-09-21 报：「别的按钮登录后都自动吸附进小地图，只有你这个每次登录/RL
    --    都游离在外面，挪一下或左键点一下才吸进去」。根因是 SexyMap/ElvUI 一类
    --    「收纳小地图按钮」的插件登录时先把按钮抓走摆好，下面的 PLAYER_LOGIN 又按存档角度
    --    ClearAllPoints+SetPoint 盖了一次；玩家一点，收纳插件重排才又吸回去。
    --    LibDBIcon 的按钮没这毛病，因为它登录后不会再自己改位置。
    -- ⭐ 这里钩住自己的 SetPoint：凡不是我们自己发起的定位 → 标记「已被接管」，
    --    之后登录重摆 / 2 秒自救全部让位。拖动仍归我们（玩家亲手拖 = 想让我们摆）。
    hooksecurefunc(btn, "SetPoint", function(s)
        if not s._selfPlacing then s._takenOver = true end
    end)

    -- Create 在主 chunk 里跑（早于 SavedVariables 加载），上面那次 UpdatePosition
    -- 读到的是空 DB 的默认角度；等 PLAYER_LOGIN（存档已加载、且每次 /reload 都触发）
    -- 再按存档位置摆一次，否则拖过的位置每次重载都跳回默认（玩家反馈）。
    btn:RegisterEvent("PLAYER_LOGIN")
    btn:SetScript("OnEvent", function(s)
        UpdatePosition(s)
        -- ⛔⛔ 玩家「dfdyg6663」2026-09-09 报「更新以后小地图旁的图标不见了」。
        --    这个按钮的位置是**存在存档里的一个角度**，再乘上当时的小地图尺寸算坐标：
        --    小地图被别的插件换过形状/尺寸、或者布局还没完成时算出来的坐标，
        --    都可能把它甩到屏幕外或压在小地图底下 —— 表现就是「不见了」，
        --    而且**一声不吭**（Create 是被 pcall 包着调的）。
        -- ⭐ 所以登录后延迟一拍再自检一次：真的看不见就复位到默认角度重放，
        --    ⛔别指望玩家自己去找设置 —— 他能看见的只有「图标没了」。
        C_Timer.After(2, function()
            if s._takenOver then return end   -- 收纳插件在管它，别插手
            if not s:IsShown() then s:Show() end
            local ok = s:IsVisible()
            if ok then
                local l, b2 = s:GetLeft(), s:GetBottom()
                local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
                -- 完全落在屏幕外，或者算出来是 nil（没布局成功）
                if not l or not b2 or l < -40 or b2 < -40 or l > sw or b2 > sh then
                    ok = false
                end
            end
            if not ok then
                SetAngle(DEFAULT_ANGLE)
                UpdatePosition(s)
                s:Show()
                if GearInsight.Print then
                    -- GearInsight:Print(MB_T("MB_RESCUED",
                        -- "小地图按钮跑出屏幕了，已放回默认位置（左下）。想换地方直接拖它。"))--lnui
                end
            end
        end)
    end)

    -- 拖动：跟随鼠标相对小地图中心的角度，松手存位置
    btn:SetScript("OnDragStart", function(s)
        s._dragging = true
        s:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            cx, cy = cx / scale, cy / scale
            SetAngle(math.deg(math.atan2(cy - my, cx - mx)))
            UpdatePosition(s)
        end)
    end)
    btn:SetScript("OnDragStop", function(s)
        s:SetScript("OnUpdate", nil)
        s._dragging = false
    end)

    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:SetScript("OnClick", function(_, button)
        if button == "LeftButton" then
            if GearInsight.TogglePanel then
                GearInsight:TogglePanel()
            end
        elseif button == "RightButton" then
            if GearInsight.RefreshData then
                GearInsight:RefreshData(true)
            end
        end
    end)

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(addon.L["MINIMAP_TOOLTIP_TITLE"], 0, 0.75, 1)
        GameTooltip:AddLine(addon.L["MINIMAP_TOOLTIP_LEFT"], 1, 1, 1)
        GameTooltip:AddLine(addon.L["MINIMAP_TOOLTIP_RIGHT"], 1, 1, 1)
        GameTooltip:Show()
    end)

    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    btn:Show()
    self.button = btn
end

--- 找回按钮：复位角度 + 重建 + 显示。⛔ 不管根因是什么，这条都要能救回来。
function MinimapButton:Rescue()
    SetAngle(DEFAULT_ANGLE)
    if not _G[BUTTON_NAME] then
        self:Create(self.addon or GearInsight)
    end
    local btn = _G[BUTTON_NAME]
    if not btn then
        if GearInsight.Print then
            GearInsight:Print(MB_T("MB_FAIL", "小地图按钮创建失败，请 /reload 后再试一次。"))
        end
        return
    end
    btn._takenOver = nil   -- 玩家主动找回：解除「被接管」，重新由我们摆
    UpdatePosition(btn)
    btn:Show()
    if GearInsight.Print then
        GearInsight:Print(MB_T("MB_BACK", "小地图按钮已放回默认位置（小地图左下角）。"))
    end
end

function MinimapButton:Hide()
    if _G[BUTTON_NAME] then
        _G[BUTTON_NAME]:Hide()
    end
end

GearInsight.MinimapButton = MinimapButton


-- ── 兜底 ①：暴雪「插件抽屉」（小地图右上角那个下拉，12.x 常驻）——就算小地图按钮被别的插件收走 / 藏了 / 创建失败，这里也能点开面板
--    （玩家 2026-09-19 报「小地图按钮没了」）
function GearInsight_OnAddonCompartmentClick(_, buttonName)
    if buttonName == "RightButton" then
        if GearInsight and GearInsight.RefreshData then GearInsight:RefreshData(true) end
    else
        if GearInsight and GearInsight.TogglePanel then GearInsight:TogglePanel() end
    end
end
function GearInsight_OnAddonCompartmentEnter(_, menuButtonFrame)
    GameTooltip:SetOwner(menuButtonFrame, "ANCHOR_LEFT")
    GameTooltip:AddLine("GearInsight", 1, 0.82, 0)
    GameTooltip:AddLine(MB_T("MB_TT_LEFT", "左键：打开 / 关闭面板"), 1, 1, 1)
    GameTooltip:AddLine(MB_T("MB_TT_RIGHT", "右键：刷新数据"), 1, 1, 1)
    GameTooltip:AddLine(MB_T("MB_CMD_HINT", "小地图按钮不见了：/gi minimap"), 0.6, 0.6, 0.6)
    GameTooltip:Show()
end
function GearInsight_OnAddonCompartmentLeave() GameTooltip:Hide() end

-- ── 兜底 ②：不依赖 GearInsight.lua 主块跑到最后——主块里任何一处出错，后面的 MinimapButton:Create 就不会被调，按钮就「没了」。
--    这里自己在 PLAYER_LOGIN 再保证一次创建。
do
    local guard = CreateFrame("Frame")
    guard:RegisterEvent("PLAYER_LOGIN")
    guard:SetScript("OnEvent", function()
        C_Timer.After(1, function()
            if not _G[BUTTON_NAME] and GearInsight then
                local ok, err = pcall(MinimapButton.Create, MinimapButton, GearInsight)
                if not ok and GearInsight.Print then GearInsight:Print("minimap: " .. tostring(err)) end
            elseif _G[BUTTON_NAME] and not _G[BUTTON_NAME]:IsShown() and not (GearInsightDB and GearInsightDB.minimapHidden) then
                _G[BUTTON_NAME]:Show()
            end
        end)
    end)
end
