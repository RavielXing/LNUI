-- ========================================================================================================================
-- 地图标记开关
-- ========================================================================================================================
local addonName, ns = ...

local MapButton = {
    button = nil,
    isEnabled = false,
    text = nil,
}

local COLOR_ENABLED = { r = 1, g = 0.82, b = 0 }
local COLOR_DISABLED = { r = 0.5, g = 0.5, b = 0.5 }

-- 更新按钮状态
function MapButton:UpdateButtonState()
    if not self.button or not self.text then return end

    local mode = RoyMapGuideDB and RoyMapGuideDB.mapMarkerType or "TEXT"
    self.text:SetText(mode == "TEXT" and "文" or "图")

    local enabled = RoyMapGuideDB and RoyMapGuideDB.enableMapMarkers
    if enabled then
        self.button:SetAlpha(1.0)
        self.text:SetTextColor(COLOR_ENABLED.r, COLOR_ENABLED.g, COLOR_ENABLED.b)
    else
        self.button:SetAlpha(0.5)
        self.text:SetTextColor(COLOR_DISABLED.r, COLOR_DISABLED.g, COLOR_DISABLED.b)
    end

    self.isEnabled = enabled
end

-- 创建按钮
function MapButton:CreateButton()
    if self.button then return end

    -- 按钮框架
    self.button = CreateFrame("Button", "RoyMapGuideMapButton", WorldMapFrame.BorderFrame, "BackdropTemplate")
    self.button:SetSize(28, 28)

    self.button:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    if WorldMapFrame.overlayFrames and WorldMapFrame.overlayFrames[2] then
        self.button:SetPoint("RIGHT", WorldMapFrame.overlayFrames[2], "LEFT", -20, 0)
    else
        self.button:SetPoint("TOPRIGHT", WorldMapFrame.BorderFrame, "TOPRIGHT", -10, -10)
    end

    -- 按钮背景
    self.button:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    self.button:SetBackdropColor(0, 0, 0, 0.8)
    self.button:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)

    self.text = self.button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.text:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE")
    self.text:SetPoint("CENTER")
    self.text:SetText("文")

    self.button:SetScript("OnClick", function(_, btn)
        if btn == "LeftButton" then
            if RoyMapGuideDB then
                RoyMapGuideDB.enableMapMarkers = not RoyMapGuideDB.enableMapMarkers
                self:UpdateButtonState()
                ns:ToggleMapMarkers()
            end
        elseif btn == "RightButton" then
            if RoyMapGuideDB then
                if RoyMapGuideDB.mapMarkerType == "TEXT" then
                    RoyMapGuideDB.mapMarkerType = "ICON"
                else
                    RoyMapGuideDB.mapMarkerType = "TEXT"
                end
                self:UpdateButtonState()
                ns:ToggleMapMarkers()
            end
        end
    end)

    -- 鼠标悬停
    self.button:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
        if MapButton.text then
            MapButton.text:SetTextColor(1, 1, 0.7)
        end

        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("地图标记开关", 1, 0.82, 0)
        GameTooltip:AddLine("左键：标记开关", 1, 1, 1)
        GameTooltip:AddLine("右键：切换模式", 1, 1, 1)
        GameTooltip:Show()
    end)

    self.button:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0, 0, 0, 0.8)

        local enabled = RoyMapGuideDB and RoyMapGuideDB.enableMapMarkers
        if enabled then
            MapButton.text:SetTextColor(COLOR_ENABLED.r, COLOR_ENABLED.g, COLOR_ENABLED.b)
        else
            MapButton.text:SetTextColor(COLOR_DISABLED.r, COLOR_DISABLED.g, COLOR_DISABLED.b)
        end

        GameTooltip:Hide()
    end)

    self:UpdateButtonState()
end

function MapButton:ToggleVisibility(show)
    if not self.button then return end
    self.button:SetShown(show)
end


-- 事件钩子
local function SetupMapHooks()
    MapButton:CreateButton()

    WorldMapFrame:HookScript("OnShow", function()
        MapButton:ToggleVisibility(true)
    end)

    WorldMapFrame:HookScript("OnHide", function()
        MapButton:ToggleVisibility(false)
    end)
end

local function SetupConfigWatch()
    local watchFrame = CreateFrame("Frame")
    local lastEnabled, lastMode

    watchFrame:SetScript("OnUpdate", function()
        if not WorldMapFrame or not WorldMapFrame:IsShown() then return end
        if not RoyMapGuideDB then return end

        local currentEnabled = RoyMapGuideDB.enableMapMarkers
        local currentMode = RoyMapGuideDB.mapMarkerType

        if lastEnabled == nil then
            lastEnabled = currentEnabled
            lastMode = currentMode
            return
        end

        if currentEnabled ~= lastEnabled or currentMode ~= lastMode then
            lastEnabled = currentEnabled
            lastMode = currentMode
            MapButton:UpdateButtonState()
        end
    end)
end

local function Initialize()
    SetupMapHooks()
    SetupConfigWatch()
end

ns.RegisterEventHandler("ADDON_LOADED", function(addon)
    if addon == addonName then
        Initialize()
    end
end)