U1PLUG["touxiang"] = function()

-- 自定义血条材质路径
local CUSTOM_STATUS_BAR_TEXTURE = "Interface\\AddOns\\LNui\\Media\\123.tga"

-- 字体设置配置
local FONT_CONFIG = {
    font = STANDARD_TEXT_FONT,
    size = 13,
    shadow = "OUTLINE"
}

-- ==========================================
-- 辅助函数：获取各种框架引用
-- ==========================================

local function GetTargetHealthBar()
    if TargetFrameHealthBar then return TargetFrameHealthBar end
    if TargetFrame and TargetFrame.TargetFrameContent then
        local main = TargetFrame.TargetFrameContent.TargetFrameContentMain
        if main and main.HealthBarsContainer then
            return main.HealthBarsContainer.HealthBar
        end
    end
    return nil
end

local function GetTargetManaBar()
    if TargetFrameManaBar then return TargetFrameManaBar end
    if TargetFrame and TargetFrame.TargetFrameContent then
        local main = TargetFrame.TargetFrameContent.TargetFrameContentMain
        if main and main.HealthBarsContainer then
            return main.HealthBarsContainer.ManaBar or main.ManaBar
        end
    end
    return nil
end

local function GetFocusHealthBar()
    if FocusFrameHealthBar then return FocusFrameHealthBar end
    if FocusFrame and FocusFrame.TargetFrameContent then
        local main = FocusFrame.TargetFrameContent.TargetFrameContentMain
        if main and main.HealthBarsContainer then
            return main.HealthBarsContainer.HealthBar
        end
    end
    return nil
end

local function GetFocusManaBar()
    if FocusFrameManaBar then return FocusFrameManaBar end
    if FocusFrame and FocusFrame.TargetFrameContent then
        local main = FocusFrame.TargetFrameContent.TargetFrameContentMain
        if main and main.HealthBarsContainer then
            return main.HealthBarsContainer.ManaBar or main.ManaBar
        end
    end
    return nil
end

local function GetPlayerManaBar()
    if PlayerFrameManaBar then return PlayerFrameManaBar end
    if PlayerFrame and PlayerFrame.PlayerFrameContent then
        local main = PlayerFrame.PlayerFrameContent.PlayerFrameContentMain
        if main then
            if main.ManaBarArea and main.ManaBarArea.ManaBar then
                return main.ManaBarArea.ManaBar
            end
            if main.HealthBarsContainer and main.HealthBarsContainer.ManaBar then
                return main.HealthBarsContainer.ManaBar
            end
            if main.ManaBar then
                return main.ManaBar
            end
        end
    end
    return nil
end

local function GetTargetTargetHealthBar()
    if TargetFrameToTHealthBar then return TargetFrameToTHealthBar end
    if TargetFrame then
        local contextual = TargetFrame.TargetFrameContent and 
                          TargetFrame.TargetFrameContent.TargetFrameContentContextual
        if contextual and contextual.TargetTargetFrame then
            return contextual.TargetTargetFrame.HealthBar or 
                   contextual.TargetTargetFrame.healthbar
        end
        if TargetFrameToT then
            return TargetFrameToT.HealthBar or TargetFrameToT.healthbar
        end
    end
    return nil
end

-- 获取小队成员血条
local function GetPartyHealthBar(unit)
    if not unit then return nil end
    if PartyFrame and PartyFrame.PartyMemberFramePool then
        for frame in PartyFrame.PartyMemberFramePool:EnumerateActive() do
            if frame.unit == unit then
                return frame.HealthBar or frame.healthbar
            end
        end
    end
    local index = unit:match("party(%d)")
    if index then
        local partyFrame = _G["PartyMemberFrame"..index]
        if partyFrame then
            return partyFrame.HealthBar or partyFrame.healthbar
        end
    end
    return nil
end

-- ==========================================
-- 字体设置函数
-- ==========================================

local function SetStatusBarTextFont(statusBar)
    if not statusBar then return end
    if statusBar.TextString and statusBar.TextString:IsObjectType("FontString") then
        statusBar.TextString:SetFont(FONT_CONFIG.font, FONT_CONFIG.size, FONT_CONFIG.shadow)
    end
    if statusBar.RightText and statusBar.RightText:IsObjectType("FontString") then
        statusBar.RightText:SetFont(FONT_CONFIG.font, FONT_CONFIG.size, FONT_CONFIG.shadow)
    end
    if statusBar.LeftText and statusBar.LeftText:IsObjectType("FontString") then
        statusBar.LeftText:SetFont(FONT_CONFIG.font, FONT_CONFIG.size, FONT_CONFIG.shadow)
    end
end

-- 应用字体到所有相关框架
local function ApplyFontToAllFrames()
    if PlayerFrameHealthBar then SetStatusBarTextFont(PlayerFrameHealthBar) end
    local playerMana = GetPlayerManaBar()
    if playerMana then SetStatusBarTextFont(playerMana) end
    
    local targetHealth = GetTargetHealthBar()
    local targetMana = GetTargetManaBar()
    if targetHealth then SetStatusBarTextFont(targetHealth) end
    if targetMana then SetStatusBarTextFont(targetMana) end
    
    local focusHealth = GetFocusHealthBar()
    local focusMana = GetFocusManaBar()
    if focusHealth then SetStatusBarTextFont(focusHealth) end
    if focusMana then SetStatusBarTextFont(focusMana) end
    
    local totBar = GetTargetTargetHealthBar()
    if totBar then SetStatusBarTextFont(totBar) end
    
    -- 小队框架
    if PartyFrame and PartyFrame.PartyMemberFramePool then
        for frame in PartyFrame.PartyMemberFramePool:EnumerateActive() do
            if frame then
                if frame.HealthBar then SetStatusBarTextFont(frame.HealthBar) end
                if frame.ManaBar then SetStatusBarTextFont(frame.ManaBar) end
            end
        end
    else
        for i = 1, 4 do
            local partyFrame = _G["PartyMemberFrame"..i]
            if partyFrame then
                if partyFrame.HealthBar then SetStatusBarTextFont(partyFrame.HealthBar) end
                if partyFrame.ManaBar then SetStatusBarTextFont(partyFrame.ManaBar) end
            end
        end
    end
end

if not AbbreviateNumbers then
    function AbbreviateNumbers(number, options)
        if type(number) ~= "number" then return tostring(number) end
        if number >= 100000000 then
            return string.format("%.2f亿", number / 100000000)
        elseif number >= 10000 then
            return string.format("%.1f万", number / 10000)
        else
            return tostring(number)
        end
    end
end

if not CreateAbbreviateConfig then
    function CreateAbbreviateConfig(config)
        return config
    end
end

local function IsSecretValue(text)
    if issecretvalue then
        return issecretvalue(text)
    end
    return text == "" or text == nil
end

local function GetSafeText(textObject)
    if not textObject then return nil end
    if not textObject.GetText then return nil end
    local success, text = pcall(textObject.GetText, textObject)
    if not success then return nil end
    if IsSecretValue(text) then return nil end
    return text
end

-- === 获取职业颜色 ===
local function GetClassColor(unit)
    if not UnitExists(unit) then return nil end
    if UnitIsPlayer(unit) then
        local _, class = UnitClass(unit)
        if class then
            -- 12.1 新 API，避免 RAID_CLASS_COLORS 被保护导致报错
            if C_ClassColor and C_ClassColor.GetClassColor then
                local color = C_ClassColor.GetClassColor(class)
                if color then
                    return color
                end
            -- 旧版本兼容
            elseif RAID_CLASS_COLORS and RAID_CLASS_COLORS[class] then
                return RAID_CLASS_COLORS[class]
            end
        end
    end
    return nil
end

-- === 着色血条（并应用自定义材质） ===
local targetBackgroundTexture = nil

local function UpdateTargetFrameSpecialEffects()
    local unit = "target"
    if not TargetFrame then return end
    local healthBar = TargetFrame.TargetFrameContent and 
                      TargetFrame.TargetFrameContent.TargetFrameContentMain and 
                      TargetFrame.TargetFrameContent.TargetFrameContentMain.HealthBarsContainer and 
                      TargetFrame.TargetFrameContent.TargetFrameContentMain.HealthBarsContainer.HealthBar
    if not healthBar then return end
    local bossPortrait = TargetFrame.TargetFrameContainer and 
                         TargetFrame.TargetFrameContainer.BossPortraitFrameTexture

    if UnitExists(unit) and UnitIsPlayer(unit) and UnitIsConnected(unit) and not UnitIsDeadOrGhost(unit) then
        local classColor = GetClassColor(unit)
        if classColor then
            local r, g, b = classColor.r, classColor.g, classColor.b
            if targetBackgroundTexture then
                targetBackgroundTexture:SetColorTexture(r, g, b, 1)
            end
            if bossPortrait then
                bossPortrait:SetAtlas("UI-HUD-UnitFrame-Target-PortraitOn-Boss-Gold", 
                                       TextureKitConstants and TextureKitConstants.UseAtlasSize)
                bossPortrait:SetPoint("TOPRIGHT", -11, -8)
                bossPortrait:Show()
                bossPortrait:SetDesaturated(true)
                bossPortrait:SetVertexColor(r, g, b, 1)
            end
        end
    else
        if bossPortrait then
            bossPortrait:SetDesaturated(false)
            bossPortrait:SetVertexColor(1, 1, 1, 1)
        end
    end
end

local function ColorUnitHealthBar(unit)
    if unit == "player" then
        local bar = PlayerFrame.healthbar or PlayerFrame.HealthBar
        local color = GetClassColor("player")
        if bar and color then
            bar:SetStatusBarColor(color.r, color.g, color.b)
            bar:SetStatusBarDesaturated(true)
            bar:SetStatusBarTexture(CUSTOM_STATUS_BAR_TEXTURE)
            SetStatusBarTextFont(bar)
        end
        
    elseif unit == "target" then
        local bar = TargetFrame.healthbar or TargetFrame.HealthBar
        local color = GetClassColor("target")
        if bar and color then
            bar:SetStatusBarColor(color.r, color.g, color.b)
            bar:SetStatusBarDesaturated(true)
            bar:SetStatusBarTexture(CUSTOM_STATUS_BAR_TEXTURE)
            SetStatusBarTextFont(bar)
        elseif bar and not color then
            local reaction = UnitReaction("target", "player")
            if reaction then
                if reaction >= 5 then bar:SetStatusBarColor(0, 1, 0)
                elseif reaction == 4 then bar:SetStatusBarColor(1, 1, 0)
                else bar:SetStatusBarColor(1, 0, 0) end
                bar:SetStatusBarDesaturated(true)
                bar:SetStatusBarTexture(CUSTOM_STATUS_BAR_TEXTURE)
                SetStatusBarTextFont(bar)
            end
        end
        UpdateTargetFrameSpecialEffects()
        
    elseif unit == "focus" then
        local bar = FocusFrame.healthbar or FocusFrame.HealthBar
        local color = GetClassColor("focus")
        if bar and color then
            bar:SetStatusBarColor(color.r, color.g, color.b)
            bar:SetStatusBarDesaturated(true)
            bar:SetStatusBarTexture(CUSTOM_STATUS_BAR_TEXTURE)
            SetStatusBarTextFont(bar)
        elseif bar and not color then
            local reaction = UnitReaction("focus", "player")
            if reaction then
                if reaction >= 5 then bar:SetStatusBarColor(0, 1, 0)
                elseif reaction == 4 then bar:SetStatusBarColor(1, 1, 0)
                else bar:SetStatusBarColor(1, 0, 0) end
                bar:SetStatusBarDesaturated(true)
                bar:SetStatusBarTexture(CUSTOM_STATUS_BAR_TEXTURE)
                SetStatusBarTextFont(bar)
            end
        end
        
    elseif unit == "targettarget" then
        local bar = GetTargetTargetHealthBar()
        if not bar then return end
        local color = GetClassColor("targettarget")
        if color then
            bar:SetStatusBarColor(color.r, color.g, color.b)
            bar:SetStatusBarDesaturated(true)
            bar:SetStatusBarTexture(CUSTOM_STATUS_BAR_TEXTURE)
            SetStatusBarTextFont(bar)
        else
            local reaction = UnitReaction("targettarget", "player")
            if reaction then
                if reaction >= 5 then bar:SetStatusBarColor(0, 1, 0)
                elseif reaction == 4 then bar:SetStatusBarColor(1, 1, 0)
                else bar:SetStatusBarColor(1, 0, 0) end
                bar:SetStatusBarDesaturated(true)
                bar:SetStatusBarTexture(CUSTOM_STATUS_BAR_TEXTURE)
                SetStatusBarTextFont(bar)
            end
        end
        
    elseif unit and unit:match("^party%d$") then
        local bar = GetPartyHealthBar(unit)
        if not bar then return end
        local color = GetClassColor(unit)
        if color then
            bar:SetStatusBarColor(color.r, color.g, color.b)
            bar:SetStatusBarDesaturated(true)
            bar:SetStatusBarTexture(CUSTOM_STATUS_BAR_TEXTURE)
            SetStatusBarTextFont(bar)
        else
            -- 职业数据未就绪时设为中性灰色，避免长期显示错误颜色
            -- 等待 UNIT_NAME_UPDATE 后再修正为真实职业颜色
            bar:SetStatusBarColor(0.5, 0.5, 0.5)
            bar:SetStatusBarDesaturated(true)
            bar:SetStatusBarTexture(CUSTOM_STATUS_BAR_TEXTURE)
            SetStatusBarTextFont(bar)
        end
    end
    
    local bar
    if unit == "player" then
        bar = PlayerFrame.healthbar
    elseif unit == "target" then
        bar = TargetFrame.healthbar
    elseif unit == "focus" then
        bar = FocusFrame.healthbar
    elseif unit == "targettarget" then
        bar = GetTargetTargetHealthBar()
    elseif unit and unit:match("^party%d$") then
        bar = GetPartyHealthBar(unit)
    end
    
    if bar and bar.TextString then
        local currentText = GetSafeText(bar.TextString)
        if currentText == nil then return end
        if (currentText == "" or currentText == nil) and TextStatusBar_UpdateTextString then
            pcall(TextStatusBar_UpdateTextString, bar)
        end
    end
end

-- === 添加职业图标及点击交易功能 ===
local function AddTradeIconToTargetFrame()
    if not TargetFrame then return end
    
    local function CreateClassIcon(parent, scale, ap, rp, x, y)
        local icon = CreateFrame("Button", nil, parent)
        icon:Hide()
        icon:SetWidth(33*scale)
        icon:SetHeight(33*scale)
        icon:SetFrameLevel(parent:GetFrameLevel()+3)
        icon:SetPoint(ap, parent, rp, x, y)

        icon.tex = icon:CreateTexture(nil, "BACKGROUND")
        icon.tex:SetWidth(20*scale)
        icon.tex:SetHeight(20*scale)
        icon.tex:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
        icon.tex:SetPoint("CENTER")

        icon.lay = icon:CreateTexture(nil, "OVERLAY")
        icon.lay:SetWidth(54*scale)
        icon.lay:SetHeight(54*scale)
        icon.lay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
        icon.lay:SetPoint("TOPLEFT")

        return icon
    end
    
    TargetFrame.icon = CreateClassIcon(TargetFrame, 1, "TOPRIGHT", "TOPRIGHT", -14, -5)
    
    TargetFrame.icon:SetScript("OnClick", function()
        if InCombatLockdown() then return end
        if IsAltKeyDown() then
            InitiateTrade("target")
        else
            InspectUnit("target")
        end
    end)
    
    TargetFrame.icon:EnableMouse(true)
    TargetFrame.icon:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("点击观察目标")
        GameTooltip:AddLine("按住 Alt 点击交易", 1, 1, 0)
        GameTooltip:Show()
    end)
    TargetFrame.icon:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    hooksecurefunc(TargetFrame, "Update", function(self)
        if not self.icon then return end
        if UnitExists(self.unit) and UnitIsPlayer(self.unit) then
            local coord = CLASS_ICON_TCOORDS[select(2, UnitClass(self.unit))]
            if coord then
                self.icon.tex:SetTexCoord(unpack(coord))
                self.icon:Show()
            else
                self.icon:Hide()
            end
        else
            self.icon:Hide()
        end
    end)
end

-- ==========================================
-- Hook 函数（必须放在 mainFrame 之前定义）
-- ==========================================

local function HookPartyFrames()
    if PartyFrame and PartyFrame.PartyMemberFramePool then
        for frame in PartyFrame.PartyMemberFramePool:EnumerateActive() do
            if frame and not frame._touxiangPartyHooked then
                frame._touxiangPartyHooked = true
                frame:HookScript("OnShow", function(self)
                    if self.unit then
                        ColorUnitHealthBar(self.unit)
                    end
                end)
            end
        end
    else
        for i = 1, 4 do
            local partyFrame = _G["PartyMemberFrame"..i]
            if partyFrame and not partyFrame._touxiangPartyHooked then
                partyFrame._touxiangPartyHooked = true
                partyFrame:HookScript("OnShow", function()
                    ColorUnitHealthBar("party"..i)
                end)
            end
        end
    end
end

local function HookToTFrame()
    local totBar = GetTargetTargetHealthBar()
    if totBar and totBar:GetParent() then
        local totFrame = totBar:GetParent()
        totFrame:HookScript("OnShow", function()
            ColorUnitHealthBar("targettarget")
        end)
    end
    if TargetFrameToT then
        TargetFrameToT:HookScript("OnShow", function()
            ColorUnitHealthBar("targettarget")
        end)
    end
end

local function HookMouseEvents(frame)
    if not frame then return end
    frame:HookScript("OnEnter", function()
        local bar = frame.healthbar or frame.HealthBar
        if bar and bar.TextString then
            local currentText = GetSafeText(bar.TextString)
            if currentText == nil then return end
            if (currentText == "" or currentText == nil) and TextStatusBar_UpdateTextString then
                pcall(TextStatusBar_UpdateTextString, bar)
            end
        end
    end)
end

-- ==========================================
-- 主事件处理框架
-- ==========================================

local mainFrame = CreateFrame("Frame")
mainFrame:RegisterEvent("PLAYER_LOGIN")
mainFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
mainFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")
mainFrame:RegisterEvent("UNIT_HEALTH")
mainFrame:RegisterEvent("UNIT_MAXHEALTH")
mainFrame:RegisterEvent("UNIT_FACTION")
mainFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
mainFrame:RegisterEvent("PARTY_MEMBER_ENABLE")
mainFrame:RegisterEvent("UNIT_NAME_UPDATE")  -- 新增：职业数据同步后补刷颜色

mainFrame:SetScript("OnEvent", function(self, event, ...)
    local unit = ...
    
    if event == "PLAYER_LOGIN" then
        AddTradeIconToTargetFrame()
        
        if TargetFrame then
            local bgFrame = CreateFrame("Frame", nil, TargetFrame.TargetFrameContent.TargetFrameContentMain.HealthBarsContainer.HealthBar)
            targetBackgroundTexture = bgFrame:CreateTexture(nil, "BACKGROUND")
            bgFrame:SetAllPoints(TargetFrame.TargetFrameContent.TargetFrameContentMain.HealthBarsContainer.HealthBar.HealthBarTexture)
            targetBackgroundTexture:SetAllPoints(bgFrame)
            targetBackgroundTexture:SetColorTexture(1, 1, 1, 1)
            bgFrame:SetFrameLevel(TargetFrame:GetFrameLevel()-1)
        end
        
        C_Timer.After(1, function()
            ColorUnitHealthBar("player")
            if UnitExists("target") then ColorUnitHealthBar("target") end
            if UnitExists("focus") then ColorUnitHealthBar("focus") end
            if UnitExists("targettarget") then ColorUnitHealthBar("targettarget") end
            
            -- 小队血条职业染色
            for i = 1, 4 do
                if UnitExists("party"..i) then
                    ColorUnitHealthBar("party"..i)
                end
            end
            HookPartyFrames()
            
            ApplyFontToAllFrames()
        end)
        
    elseif event == "PLAYER_TARGET_CHANGED" then
        ColorUnitHealthBar("target")
        ColorUnitHealthBar("targettarget")
        local targetHealth = GetTargetHealthBar()
        local targetMana = GetTargetManaBar()
        if targetHealth then SetStatusBarTextFont(targetHealth) end
        if targetMana then SetStatusBarTextFont(targetMana) end
        local totBar = GetTargetTargetHealthBar()
        if totBar then SetStatusBarTextFont(totBar) end
        
    elseif event == "PLAYER_FOCUS_CHANGED" then
        ColorUnitHealthBar("focus")
        local focusHealth = GetFocusHealthBar()
        local focusMana = GetFocusManaBar()
        if focusHealth then SetStatusBarTextFont(focusHealth) end
        if focusMana then SetStatusBarTextFont(focusMana) end
        
    elseif event == "GROUP_ROSTER_UPDATE" or event == "PARTY_MEMBER_ENABLE" then
        -- 延迟执行，等待 PartyFrame 完成框架重建
        C_Timer.After(0.3, function()
            for i = 1, 4 do
                local pUnit = "party"..i
                if UnitExists(pUnit) then
                    ColorUnitHealthBar(pUnit)
                end
            end
            HookPartyFrames()
        end)
        
    elseif event == "UNIT_NAME_UPDATE" then
        -- 单位名称/职业数据同步后，补刷职业颜色
        if unit and unit:match("^party%d$") then
            ColorUnitHealthBar(unit)
        end
        
    elseif event == "UNIT_FACTION" then
        if unit == "target" or unit == "focus" or unit == "targettarget" or (unit and unit:match("^party%d$")) then
            ColorUnitHealthBar(unit)
        end
        
    elseif (event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH") then
        if unit == "player" or unit == "target" or unit == "focus" or unit == "targettarget" then
            local bar
            if unit == "player" then
                bar = PlayerFrame.healthbar
            elseif unit == "target" then
                bar = TargetFrame.healthbar
            elseif unit == "focus" then
                bar = FocusFrame.healthbar
            elseif unit == "targettarget" then
                bar = GetTargetTargetHealthBar()
            end
            
            -- 修复：避免提前 return 导致后续 ColorUnitHealthBar 和 party 逻辑被跳过
            if bar and bar.TextString then
                local currentText = GetSafeText(bar.TextString)
                if currentText ~= nil then
                    if currentText == "" and TextStatusBar_UpdateTextString then
                        pcall(TextStatusBar_UpdateTextString, bar)
                    end
                end
            end
            
            ColorUnitHealthBar(unit)
        end
        
        if unit and unit:match("^party%d$") then
            ColorUnitHealthBar(unit)
        end
    end
end)

-- === 框架显示事件 Hook ===
if TargetFrame then
    TargetFrame:HookScript("OnShow", function()
        ColorUnitHealthBar("target")
    end)
end

if FocusFrame then
    FocusFrame:HookScript("OnShow", function()
        ColorUnitHealthBar("focus")
    end)
end

C_Timer.After(1.5, HookToTFrame)

HookMouseEvents(PlayerFrame)
HookMouseEvents(TargetFrame)
HookMouseEvents(FocusFrame)

-- ==========================================
-- 血量/能量文字格式化（万/亿简写）
-- ==========================================

local numberFormatConfig = CreateAbbreviateConfig({
    {
        breakpoint = 1e10,
        abbreviation = LOCALE_zhCN and "亿" or "億",
        significandDivisor = 1e8,
        fractionDivisor = 1,
        abbreviationIsGlobal = false
    },
    {
        breakpoint = 1e9,
        abbreviation = LOCALE_zhCN and "億" or "億",
        significandDivisor = 1e7,
        fractionDivisor = 10,
        abbreviationIsGlobal = false
    },
    {
        breakpoint = 1e8,
        abbreviation = LOCALE_zhCN and "亿" or "億",
        significandDivisor = 1e6,
        fractionDivisor = 100,
        abbreviationIsGlobal = false
    },
    {
        breakpoint = 1e7,
        abbreviation = LOCALE_zhCN and "万" or "萬",
        significandDivisor = 1e4,
        fractionDivisor = 1,
        abbreviationIsGlobal = false
    },
    {
        breakpoint = 1e4,
        abbreviation = LOCALE_zhCN and "万" or "萬",
        significandDivisor = 1e3,
        fractionDivisor = 10,
        abbreviationIsGlobal = false
    },
    {
        breakpoint = 1,
        abbreviation = "",
        significandDivisor = 1,
        fractionDivisor = 1,
        abbreviationIsGlobal = false
    },
})

local numberAbbrevOptions = {config = numberFormatConfig}

local function FormatHealthValue(current, max)
    if not current or not max then return nil end
    local success1, currentStr = pcall(AbbreviateNumbers, current, numberAbbrevOptions)
    local success2, maxStr = pcall(AbbreviateNumbers, max, numberAbbrevOptions)
    if success1 and success2 then
        return currentStr .. "/" .. maxStr
    end
    return nil
end

local function FormatCurrentValue(current)
    if not current then return nil end
    local success, currentStr = pcall(AbbreviateNumbers, current, numberAbbrevOptions)
    return success and currentStr or tostring(current)
end

local function GetDisplayMode()
    return GetCVar("statusTextDisplay") or "NUMERIC"
end

local function GetHealthValues(unit)
    if not unit then return nil, nil end
    local current = UnitHealth(unit)
    local max = UnitHealthMax(unit)
    if type(current) == "number" and type(max) == "number" then
        return current, max
    end
    return nil, nil
end

local function GetPowerValues(unit)
    if not unit then return nil, nil, nil end
    local powerType = UnitPowerType(unit)
    local current = UnitPower(unit, powerType)
    local max = UnitPowerMax(unit, powerType)
    if type(current) == "number" and type(max) == "number" then
        return current, max, powerType
    end
    return nil, nil, powerType
end

local function UpdateHealthText(statusBar)
    if not statusBar or not statusBar.unit then return end
    local unit = statusBar.unit
    if UnitIsDead(unit) or UnitIsGhost(unit) then
        if statusBar.TextString then statusBar.TextString:SetText("") end
        if statusBar.RightText then statusBar.RightText:SetText("") end
        return
    end
    local mode = GetDisplayMode()
    if mode == "PERCENT" then return end
    local current, max = GetHealthValues(unit)
    if not current or not max then return end
    if mode == "BOTH" then
        local formattedCurrent = FormatCurrentValue(current)
        if statusBar.RightText then
            statusBar.RightText:SetText(formattedCurrent)
        end
    else
        local formattedValue = FormatHealthValue(current, max)
        if formattedValue then
            if statusBar.TextString then
                statusBar.TextString:SetText(formattedValue)
            end
            if statusBar.RightText then
                statusBar.RightText:SetText(formattedValue)
            end
        end
    end
end

local function UpdatePowerText(statusBar)
    if not statusBar or not statusBar.unit then return end
    local unit = statusBar.unit
    local mode = GetDisplayMode()
    if mode == "PERCENT" then return end
    local current, max, powerType = GetPowerValues(unit)
    if not current then return end
    local isMana = (powerType == 0)
    if mode == "BOTH" then
        if statusBar.RightText then
            local formattedCurrent = FormatCurrentValue(current)
            statusBar.RightText:SetText(formattedCurrent)
        end
        if statusBar.TextString then
            local text = GetSafeText(statusBar.TextString)
            if text and not text:find("%%") then
                local formattedCurrent = FormatCurrentValue(current)
                statusBar.TextString:SetText(formattedCurrent)
            end
        end
    else
        if isMana then
            local formattedValue = FormatHealthValue(current, max)
            local displayText = formattedValue or tostring(current)
            if statusBar.TextString then
                statusBar.TextString:SetText(displayText)
            end
            if statusBar.RightText then
                statusBar.RightText:SetText(displayText)
            end
        else
            local formattedCurrent = FormatCurrentValue(current)
            if statusBar.TextString then
                statusBar.TextString:SetText(formattedCurrent)
            end
            if statusBar.RightText then
                statusBar.RightText:SetText("")
            end
        end
    end
end

local function HookHealthBar(statusBar, unit)
    if not statusBar or statusBar._touxiangshuzhi_hooked then return end
    statusBar._touxiangshuzhi_hooked = true
    if not statusBar.unit and unit then
        statusBar.unit = unit
    end
    SetStatusBarTextFont(statusBar)
    statusBar:HookScript("OnUpdate", function(self)
        UpdateHealthText(self)
    end)
end

local function HookPowerBar(statusBar, unit)
    if not statusBar or statusBar._touxiangpower_hooked then return end
    statusBar._touxiangpower_hooked = true
    if not statusBar.unit and unit then
        statusBar.unit = unit
    end
    SetStatusBarTextFont(statusBar)
    statusBar:HookScript("OnUpdate", function(self)
        UpdatePowerText(self)
    end)
end

local function HookStatusBar(statusBar, unit)
    local name = statusBar:GetName() or ""
    if name:find("Mana") or name:find("Power") or statusBar.powerType then
        HookPowerBar(statusBar, unit)
    else
        HookHealthBar(statusBar, unit)
    end
end

local function UpdateTargetFrame()
    local healthBar = GetTargetHealthBar()
    local manaBar = GetTargetManaBar()
    if healthBar then UpdateHealthText(healthBar); SetStatusBarTextFont(healthBar) end
    if manaBar then UpdatePowerText(manaBar); SetStatusBarTextFont(manaBar) end
    
    local focusHealth = GetFocusHealthBar()
    local focusMana = GetFocusManaBar()
    if focusHealth then UpdateHealthText(focusHealth); SetStatusBarTextFont(focusHealth) end
    if focusMana then UpdatePowerText(focusMana); SetStatusBarTextFont(focusMana) end
    
    local totBar = GetTargetTargetHealthBar()
    if totBar then UpdateHealthText(totBar); SetStatusBarTextFont(totBar) end
end

if UnitFrameHealthBar_OnUpdate then
    hooksecurefunc("UnitFrameHealthBar_OnUpdate", UpdateHealthText)
end
if UnitFrameManaBar_OnUpdate then
    hooksecurefunc("UnitFrameManaBar_OnUpdate", UpdatePowerText)
end

-- === 血量/能量文字事件处理 ===
local healthTextFrame = CreateFrame("Frame")
healthTextFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
healthTextFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")
healthTextFrame:RegisterEvent("PLAYER_TALENT_UPDATE")
healthTextFrame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
healthTextFrame:RegisterEvent("UNIT_HEALTH")
healthTextFrame:RegisterEvent("UNIT_MAXHEALTH")
healthTextFrame:RegisterEvent("UNIT_POWER_UPDATE")
healthTextFrame:SetScript("OnEvent", function(self, event, unit)
    if event == "PLAYER_TARGET_CHANGED" then
        UpdateTargetFrame()
        local healthBar = GetTargetHealthBar()
        local manaBar = GetTargetManaBar()
        if healthBar then HookHealthBar(healthBar, "target") end
        if manaBar then HookPowerBar(manaBar, "target") end
        local totBar = GetTargetTargetHealthBar()
        if totBar then HookHealthBar(totBar, "targettarget") end
        
    elseif event == "PLAYER_FOCUS_CHANGED" then
        local healthBar = GetFocusHealthBar()
        local manaBar = GetFocusManaBar()
        if healthBar then HookHealthBar(healthBar, "focus") end
        if manaBar then HookPowerBar(manaBar, "focus") end
        
    elseif event == "PLAYER_TALENT_UPDATE" or event == "ACTIVE_TALENT_GROUP_CHANGED" then
        local playerManaBar = GetPlayerManaBar()
        if playerManaBar then 
            HookPowerBar(playerManaBar, "player")
            UpdatePowerText(playerManaBar)
        end
        
    elseif event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" or event == "UNIT_POWER_UPDATE" then
        if unit == "target" then
            local healthBar = GetTargetHealthBar()
            local manaBar = GetTargetManaBar()
            if healthBar then UpdateHealthText(healthBar) end
            if manaBar then UpdatePowerText(manaBar) end
            
        elseif unit == "focus" then
            local healthBar = GetFocusHealthBar()
            local manaBar = GetFocusManaBar()
            if healthBar then UpdateHealthText(healthBar) end
            if manaBar then UpdatePowerText(manaBar) end
            
        elseif unit == "targettarget" then
            local totBar = GetTargetTargetHealthBar()
            if totBar then UpdateHealthText(totBar) end
            
        elseif unit == "player" then
            if PlayerFrameHealthBar then 
                UpdateHealthText(PlayerFrameHealthBar) 
            end
            local playerManaBar = GetPlayerManaBar()
            if playerManaBar then 
                UpdatePowerText(playerManaBar) 
            end
        end
    end
end)

-- === 初始化时立即应用 ===
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
initFrame:SetScript("OnEvent", function(self, event)
    C_Timer.After(2, function()
        if PlayerFrameHealthBar then 
            HookHealthBar(PlayerFrameHealthBar, "player") 
        end
        
        local playerManaBar = GetPlayerManaBar()
        if playerManaBar then 
            HookPowerBar(playerManaBar, "player") 
            UpdatePowerText(playerManaBar)
        end
        
        UpdateTargetFrame()
        
        if UnitExists("target") then
            local healthBar = GetTargetHealthBar()
            local manaBar = GetTargetManaBar()
            if healthBar then HookHealthBar(healthBar, "target") end
            if manaBar then HookPowerBar(manaBar, "target") end
            local totBar = GetTargetTargetHealthBar()
            if totBar then HookHealthBar(totBar, "targettarget") end
        end
        
        if UnitExists("focus") then
            local healthBar = GetFocusHealthBar()
            local manaBar = GetFocusManaBar()
            if healthBar then HookHealthBar(healthBar, "focus") end
            if manaBar then HookPowerBar(manaBar, "focus") end
        end
        
        ApplyFontToAllFrames()
    end)
    
    initFrame:UnregisterEvent("PLAYER_ENTERING_WORLD")
end)

----------------------
------ 一些小修改 -------
----------------------

-- 隐藏玩家头像伤害治疗数字
if PlayerFrame and PlayerFrame.PlayerFrameContent and PlayerFrame.PlayerFrameContent.PlayerFrameContentMain then
    local hitIndicator = PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.HitIndicator
    if hitIndicator then
        hitIndicator:Hide()
        hitIndicator.Show = function() end
    end
end

if PetHitIndicator then
    PetHitIndicator:Hide()
    PetHitIndicator.Show = function() end
end

-- 隐藏休息区动画
if PlayerFrame_UpdateStatus then
    hooksecurefunc("PlayerFrame_UpdateStatus", function()
        if PlayerFrame and PlayerFrame.PlayerFrameContent and PlayerFrame.PlayerFrameContent.PlayerFrameContentMain then
            local statusTexture = PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.StatusTexture
            if statusTexture then
                statusTexture:Hide()
            end
        end
    end)
end

-- 隐藏目标框体名字下的蓝色背景颜色
if TargetFrame and TargetFrame.TargetFrameContent and TargetFrame.TargetFrameContent.TargetFrameContentMain then
    local repColor = TargetFrame.TargetFrameContent.TargetFrameContentMain.ReputationColor
    if repColor then
        repColor:Hide()
    end
end

-- 隐藏宠物头像血量数字
local petFrame = CreateFrame("Frame")
petFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
petFrame:RegisterEvent("CVAR_UPDATE")
petFrame:SetScript("OnEvent", function()
    C_Timer.After(0.1, function()
        local texts = {PetFrameHealthBarTextRight, PetFrameHealthBarText}
        for _, text in ipairs(texts) do
            if text and text:IsObjectType("FontString") then
                text:Hide()
                hooksecurefunc(text, "Show", function() text:Hide() end)
                hooksecurefunc(text, "SetShown", function(self, shown)
                    if shown then self:Hide() end
                end)
            end
        end
    end)
end)

end