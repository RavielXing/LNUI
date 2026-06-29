local addon = ...
local GetTime = GetTime

-- 职业颜色表
local CLASS_COLORS = {
    ["WARRIOR"]     = { r = 0.78, g = 0.61, b = 0.43 },
    ["PALADIN"]     = { r = 0.96, g = 0.55, b = 0.73 },
    ["HUNTER"]      = { r = 0.67, g = 0.83, b = 0.45 },
    ["ROGUE"]       = { r = 1.00, g = 0.96, b = 0.41 },
    ["PRIEST"]      = { r = 1.00, g = 1.00, b = 1.00 },
    ["DEATHKNIGHT"] = { r = 0.77, g = 0.12, b = 0.23 },
    ["SHAMAN"]      = { r = 0.00, g = 0.44, b = 0.87 },
    ["MAGE"]        = { r = 0.41, g = 0.80, b = 0.94 },
    ["WARLOCK"]     = { r = 0.58, g = 0.51, b = 0.79 },
    ["MONK"]        = { r = 0.00, g = 1.00, b = 0.59 },
    ["DRUID"]       = { r = 1.00, g = 0.49, b = 0.04 },
    ["DEMONHUNTER"] = { r = 0.64, g = 0.19, b = 0.79 },
    ["EVOKER"]      = { r = 0.20, g = 0.58, b = 0.50 },
}

-- 职业图标坐标表
local CLASS_ICON_COORDS = {
    WARRIOR     = {0, 0.125, 0, 0.125},
    MAGE        = {0.125, 0.25, 0, 0.125},
    ROGUE       = {0.25, 0.375, 0, 0.125},
    DRUID       = {0.375, 0.5, 0, 0.125},
    EVOKER      = {0.5, 0.625, 0, 0.125},
    HUNTER      = {0, 0.125, 0.125, 0.25},
    SHAMAN      = {0.125, 0.25, 0.125, 0.25},
    PRIEST      = {0.25, 0.375, 0.125, 0.25},
    WARLOCK     = {0.375, 0.5, 0.125, 0.25},
    PALADIN     = {0, 0.125, 0.25, 0.375},
    DEATHKNIGHT = {0.125, 0.25, 0.25, 0.375},
    MONK        = {0.25, 0.375, 0.25, 0.375},
    DEMONHUNTER = {0.375, 0.5, 0.25, 0.375},
}

-- 阵营图标路径
local FACTION_ICONS = {
    Alliance = "Interface\\FriendsFrame\\PlusManz-Alliance",
    Horde = "Interface\\FriendsFrame\\PlusManz-Horde",
}

-- 阵营背景材质路径
local FACTION_BACKGROUNDS = {
    Horde = "Interface\\AddOns\\163UI_CombatTimer\\CombatIndicator1.tga",
    Alliance = "Interface\\AddOns\\163UI_CombatTimer\\CombatIndicator2.tga",
}

-- 安全获取字体信息（12.0兼容）
local function SafeGetFont(fontObject)
    local fontFile, fontHeight, fontFlags = fontObject:GetFont()
    if not fontHeight or fontHeight <= 0 then
        fontHeight = 13
    end
    if not fontFile or fontFile == "" then
        fontFile = "Fonts\\FRIZQT__.ttf"
    end
    return fontFile, fontHeight, fontFlags or ""
end

-- 获取职业颜色
local function GetClassColor()
    local _, class = UnitClass("player")
    return CLASS_COLORS[class] or { r = 1, g = 1, b = 0 }
end

-- 获取职业图标坐标
local function GetClassIconCoords()
    local _, class = UnitClass("player")
    return CLASS_ICON_COORDS[class] or CLASS_ICON_COORDS.WARRIOR
end

-- 获取玩家阵营
local function GetPlayerFaction()
    local faction = UnitFactionGroup("player")
    return faction or "Alliance" -- 默认联盟
end

-- 安全获取字体文件和大小
local safeFontFile, safeFontHeight = SafeGetFont(ChatFontNormal)

-- 主框架
local U1CT = WW:Frame("U1CT", UIParent):Size(130, 27):TOP(0, 0)--计时器位置
:CreateTexture():Key("bg"):ALL():SetAtlas("search-select"):up()
:CreateFontString():Key("text"):CENTER():SetFont(safeFontFile, 19, "OUTLINE")
:SetText("0.00"):SetTextColor(1,1,0):up()
:CreateTexture():Key("LeftFaction"):Size(22,22):SetPoint("RIGHT", U1CT.text, "LEFT", -5, 0):up()
:CreateTexture():Key("RightFaction"):Size(22,22):SetPoint("LEFT", U1CT.text, "RIGHT", 5, 0):up()
:CreateAnimationGroup():Key("Anim"):SetLooping("BOUNCE")
:CreateAnimation("Scale"):SetChildKey("bg"):SetDuration(0.2):SetScaleFrom(0.8, 1):SetScaleTo(1, 1):up()
:CreateAnimation("Alpha"):SetChildKey("bg"):SetDuration(0.2):SetFromAlpha(0.5):SetToAlpha(1):up()
:up():un()

-- 职业图标设置函数
local function U1CT_SetClassIcon()
    local classCoords = GetClassIconCoords()
    local texturePath = "Interface\\AddOns\\163UI_CombatTimer\\fabledrealmv2.tga"
    local showClassIcon = U1GetCfgValue(addon, "show_class_icon", true)

    -- 获取玩家阵营
    local faction = GetPlayerFaction()

    -- 主计时器图标设置（使用阵营图标）
    if showClassIcon then
        local factionIcon = FACTION_ICONS[faction] or FACTION_ICONS.Alliance
        U1CT.LeftFaction:SetTexture(factionIcon)
        U1CT.RightFaction:SetTexture(factionIcon)
        U1CT.LeftFaction:SetTexCoord(0, 1, 0, 1) -- 完整图标
        U1CT.RightFaction:SetTexCoord(0, 1, 0, 1) -- 完整图标
        U1CT.LeftFaction:SetSize(22, 22)
        U1CT.RightFaction:SetSize(22, 22)
        U1CT.LeftFaction:Show()
        U1CT.RightFaction:Show()
    else
        U1CT.LeftFaction:SetTexture("")
        U1CT.RightFaction:SetTexture("")
        U1CT.LeftFaction:Hide()
        U1CT.RightFaction:Hide()
    end

    -- 横幅图标设置（使用职业图标）
    if showClassIcon then
        for _, banner in pairs({CombatTimerEnterBanner, CombatTimerLeaveBanner}) do
            if banner then
                -- 设置背景材质
                local bgTexture = FACTION_BACKGROUNDS[faction] or FACTION_BACKGROUNDS.Alliance
                if banner.BG1 then banner.BG1:SetTexture(bgTexture) end
                if banner.BG2 then banner.BG2:SetTexture(bgTexture) end
                -- 设置背景材质尺寸
                if banner.BG1 then banner.BG1:SetSize(345, 80) end
                if banner.BG2 then banner.BG2:SetSize(345, 80) end

                -- 设置职业图标
                if banner.LeftFaction then
                    banner.LeftFaction:SetTexture(texturePath)
                    local l, r, t, b = unpack(classCoords)
                    banner.LeftFaction:SetTexCoord(l, r, t, b)        -- 左侧正常
                    banner.LeftFaction:SetWidth(banner.LeftFaction:GetHeight())
                    banner.LeftFaction:Show()
                end
                if banner.RightFaction then
                    banner.RightFaction:SetTexture(texturePath)
                    local l, r, t, b = unpack(classCoords)
                    banner.RightFaction:SetTexCoord(r, l, t, b)       -- 右侧水平翻转
                    banner.RightFaction:SetWidth(banner.RightFaction:GetHeight())
                    banner.RightFaction:Show()
                end
            end
        end
    else
        for _, banner in pairs({CombatTimerEnterBanner, CombatTimerLeaveBanner}) do
            if banner then
                if banner.LeftFaction then
                    banner.LeftFaction:SetTexture("")
                    banner.LeftFaction:Hide()
                end
                if banner.RightFaction then
                    banner.RightFaction:SetTexture("")
                    banner.RightFaction:Hide()
                end
            end
        end
    end
end
U1CT_SetClassIcon()

CoreUIMakeMovable(U1CT)

-- 计时器更新
U1CT.onUpdate = function(self, elapsed)
    local now = GetTime()
    local combat = now - self.start
    if combat < 60 then
        self.text:SetFormattedText("%.2f", combat)
    else
        self.text:SetFormattedText("%d:%04.1f", combat / 60, combat % 60)
    end
    self.LeftFaction:Show()
    self.RightFaction:Show()
end

-- 横幅动画
function U1CT_PlayBanner(enter)
    local classColor = GetClassColor()
    local banner, title, label
    if enter then
        banner = CombatTimerEnterBanner
        if CombatTimerLeaveBanner then CombatTimerLeaveBanner:Hide() end
        title = U1GetCfgValue(addon, "enter_anim/title", true) or ""
        label = U1GetCfgValue(addon, "enter_anim/label", true) or LOCALE_zhCN and "进入战斗" or "進入戰鬥"
    else
        banner = CombatTimerLeaveBanner
        if CombatTimerEnterBanner then CombatTimerEnterBanner:Hide() end
        title = U1GetCfgValue(addon, "leave_anim/title", true) or LOCALE_zhCN and "离开战斗" or "離開戰鬥"
    end

    if not banner then return end

    banner:Show()
    if banner.Title then banner.Title:SetText(title) end
    if banner.TitleFlash then banner.TitleFlash:SetText(title) end
    if banner.Title then banner.Title:SetTextColor(classColor.r, classColor.g, classColor.b) end
    if banner.TitleFlash then banner.TitleFlash:SetTextColor(classColor.r, classColor.g, classColor.b) end

    -- 调整文字位置（稍微下降）
    if banner == CombatTimerEnterBanner then
        if banner.Title then
            banner.Title:ClearAllPoints()
            banner.Title:SetPoint("CENTER", banner.BG1, "CENTER", 0, 2)
        end
        if banner.TitleFlash then
            banner.TitleFlash:ClearAllPoints()
            banner.TitleFlash:SetPoint("CENTER", banner.BG1, "CENTER", 0, 2)
        end
    else
        if banner.Title then
            banner.Title:ClearAllPoints()
            banner.Title:SetPoint("CENTER", banner.BG1, "CENTER", 0, -5)
        end
        if banner.TitleFlash then
            banner.TitleFlash:ClearAllPoints()
            banner.TitleFlash:SetPoint("CENTER", banner.BG1, "CENTER", 0, -5)
        end
    end

    if label and banner.BonusLabel then 
        banner.BonusLabel:SetText(label)
        banner.BonusLabel:SetTextColor(classColor.r, classColor.g, classColor.b)
        -- 调整副标题位置（跟随主标题下降）
        banner.BonusLabel:ClearAllPoints()
        banner.BonusLabel:SetPoint("TOP", banner.Title, "BOTTOM", 0, 0)
    end

    local trackerFrame = U1CT:IsVisible() and U1CT or banner
    local x, y = trackerFrame:GetCenter()
    local xb, yb = banner:GetCenter()
    local xOffset = (x - xb) * 0.8
    local yOffset = (y - yb) * 0.8
    if banner.Anim then
        if banner.Anim.BG1Translation then banner.Anim.BG1Translation:SetOffset(xOffset, yOffset) end
        if banner.Anim.TitleTranslation then banner.Anim.TitleTranslation:SetOffset(xOffset, yOffset) end
        if banner.Anim.LeftFactionTranslation then banner.Anim.LeftFactionTranslation:SetOffset(xOffset, yOffset) end
        if banner.Anim.RightFactionTranslation then banner.Anim.RightFactionTranslation:SetOffset(xOffset, yOffset) end
        if label and banner.Anim.BonusLabelTranslation then
            banner.Anim.BonusLabelTranslation:SetOffset(xOffset, yOffset)
        end
        if label and banner.Anim.IconTranslation then
            banner.Anim.IconTranslation:SetOffset(xOffset, yOffset)
        end
        banner.Anim:Stop()
        banner.Anim:Play()
    end
end

-- 音效播放
function U1CT_PlaySound(enter)
    if enter then
        local ogg = U1GetCfgValue(addon, "enter_sound/ogg")
        if ogg then
            PlaySoundFile(ogg)
        end
    else
        PlaySound(7963)
    end
end

-- 计时器控制
function U1CT_StartTimer(start)
    local classColor = GetClassColor()
    if start then
        U1CT.start = GetTime()
        U1CT:SetScript("OnUpdate", U1CT.onUpdate)
        U1CT.text:SetTextColor(classColor.r, classColor.g, classColor.b)
        U1CT.Anim:Play()
    else
        U1CT.start = nil
        U1CT.text:SetTextColor(1, 1, 0) -- 离开战斗恢复黄色
        U1CT:SetScript("OnUpdate", nil)
        U1CT.Anim:Stop()
        U1CT.LeftFaction:Show()
        U1CT.RightFaction:Show()
    end
end

-- 进入战斗逻辑
U1CT_Enter = function(encounter)
    if encounter then U1CT.encounter = true end
    if U1CT.start then return end

    U1CT_StartTimer(true)

    if U1GetCfgValue(addon, "enter_anim") then
        U1CT_PlayBanner(true)
    end

    if U1GetCfgValue(addon, "enter_sound") then
        U1CT_PlaySound(true)
    end
end

-- 单人状态检测
function U1CT_IsSolo()
    return not IsInGroup() or (GetNumGroupMembers() == 1 and not UnitExists("party1") and not UnitExists("raid1"))
end

-- 离开战斗逻辑
function U1CT_Leave(encounter)
    if not U1CT.start then return end

    -- 如果是首领战激活状态，但离开事件不是 ENCOUNTER_END，且不是单人
    if U1CT.encounter and not encounter and not U1CT_IsSolo() then
        -- 检查首领战是否真的还在进行（API 仅在副本内有效，但安全调用）
        local inProgress = C_EncounterInfo and C_EncounterInfo.IsEncounterInProgress and C_EncounterInfo.IsEncounterInProgress()
        if inProgress then
            -- 首领战仍在进行，不停止计时（符合预期）
            return
        else
            -- 首领战未进行，说明 ENCOUNTER_END 可能丢失，强制清除标记并继续停止
            U1CT.encounter = nil
        end
    end

    U1CT.encounter = nil
    U1CT_StartTimer(false)

    if U1GetCfgValue(addon, "leave_anim") then
        U1CT_PlayBanner(false)
    end

    if U1GetCfgValue(addon, "leave_sound") then
        U1CT_PlaySound(false)
    end
end

-- 事件处理
U1CT:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_DISABLED" or event == "ENCOUNTER_START" then
        U1CT_Enter(event == "ENCOUNTER_START")
    elseif event == "PLAYER_REGEN_ENABLED" or event == "ENCOUNTER_END" then
        U1CT_Leave(event == "ENCOUNTER_END")
    end
end)

-- 工具提示
U1CT.tooltipTitle = LOCALE_zhCN and "战斗计时" or "戰鬥計時"
U1CT.tooltipLines = LOCALE_zhCN and "战斗计时`进入/离开战斗提示`记录战斗持续时间`<右键点击>进行设置" or "戰鬥計時`進入/離開戰鬥提示`記錄戰鬥持續時間`<右鍵點擊>進行設置"
U1CT:SetScript("OnEnter", function()
    if InCombatLockdown() then return end
    CoreUIShowTooltip(U1CT, "ANCHOR_BOTTOM")
end)
U1CT:SetScript("OnLeave", function(self)
    if GameTooltip:GetOwner() == self then
        GameTooltip:Hide()
    end
end)

-- 右键设置
U1CT:HookScript("OnMouseUp", function(self, button)
    if button == "RightButton" and not InCombatLockdown() then
        UUI.OpenToAddon("163UI_CombatTimer", true)
    end
end)

-- 延迟初始化
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    GetClassColor() -- 确保职业信息加载
    U1CT_SetClassIcon() -- 刷新职业图标
    U1CT:RegisterEvent("PLAYER_REGEN_DISABLED")
    U1CT:RegisterEvent("PLAYER_REGEN_ENABLED")
    U1CT:RegisterEvent("ENCOUNTER_START")
    U1CT:RegisterEvent("ENCOUNTER_END")
end)

-- 兼容旧配置接口（新增部分）
U1CT_SetFactionTexture = U1CT_SetClassIcon
