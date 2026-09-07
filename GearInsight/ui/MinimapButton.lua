-- MinimapButton.lua
-- Adds a minimap button to toggle the GearInsight panel.
-- 0.35.1 重写：旧版用固定 TOPLEFT 偏移钉死位置（12.0 小地图尺寸变化后飘出圆边），
-- 且 tracking 边框 SetAllPoints 后再设 53x53 被忽略（边框被压进 31x31，图标层错位）。
-- 现改为标准做法：按角度沿小地图圆边定位 + 可拖动 + 位置存 GearInsightDB.minimapPos。

GearInsight = GearInsight or {}
local MinimapButton = {}

local BUTTON_NAME = "GearInsightMinimapButton"
local ICON_TEXTURE = "Interface\\AddOns\\GearInsight\\icon"--lnui
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

    btn:ClearAllPoints()
    btn:SetPoint("CENTER", Minimap, "CENTER", x, y)
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
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    local overlay = btn:CreateTexture(nil, "OVERLAY")
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    overlay:SetSize(53, 53)
    overlay:SetPoint("TOPLEFT")   -- 只锚一角，保住 53x53，边框才对得上图标

    btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    UpdatePosition(btn)

    -- Create 在主 chunk 里跑（早于 SavedVariables 加载），上面那次 UpdatePosition
    -- 读到的是空 DB 的默认角度；等 PLAYER_LOGIN（存档已加载、且每次 /reload 都触发）
    -- 再按存档位置摆一次，否则拖过的位置每次重载都跳回默认（玩家反馈）。
    btn:RegisterEvent("PLAYER_LOGIN")
    btn:SetScript("OnEvent", function(s)
        UpdatePosition(s)
    end)

    -- 拖动：跟随鼠标相对小地图中心的角度，松手存位置
    btn:SetScript("OnDragStart", function(s)
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

function MinimapButton:Hide()
    if _G[BUTTON_NAME] then
        _G[BUTTON_NAME]:Hide()
    end
end

GearInsight.MinimapButton = MinimapButton
