local _, SELFAQ = ...

local debug = SELFAQ.debug
local clone = SELFAQ.clone
local diff = SELFAQ.diff
local L = SELFAQ.L
local GetItemLink = SELFAQ.GetItemLink
local player = SELFAQ.player

SELFAQ.color = function(color, text)
    return "|cFF"..color..text.."|r"
end

-- 设置菜单初始化
function SELFAQ.settingInit()

    if SELFAQ.f ~= nil then
        return
    end

    -- 主界面面板
    local top = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    SELFAQ.top = top
    top.name = "GearBar"

    -- 内容frame（用于放置所有控件）
    local f = CreateFrame("Frame", nil, top)
    f:SetAllPoints(top)
    SELFAQ.f = f

    -- 缓存单选框
    f.checkbox = {}

    -- ===== 标题 =====
    local yOffset = -15

    do
        local t = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        t:SetText(L["GearBar "]..SELFAQ.version.."  |cFFFF0000by MonZ |r")
        t:SetPoint("TOPLEFT", f, 16, yOffset)
    end

    yOffset = yOffset - 30

    -- ===== 分割线构建函数 =====
    local function buildLine(yPos, width)
        local line = f:CreateTexture(nil, "ARTWORK")
        line:SetHeight(1)
        line:SetWidth(width or 380)
        line:SetPoint("TOPLEFT", f, 16, yPos)
        line:SetColorTexture(0.3, 0.3, 0.3, 0.8)
    end

    -- ===== 通用checkbox构建函数 =====
    local function buildCheckbox(text, key, xPos, yPos)
        local b = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
        b:SetPoint("TOPLEFT", f, xPos, yPos)
        b:SetChecked(AQSV[key])

        b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        b.text:SetPoint("LEFT", b, "RIGHT", 0, 0)
        b.text:SetText(text)
        b:SetScript("OnClick", function()
            AQSV[key] = not AQSV[key]
            b:SetChecked(AQSV[key])

            if key == "enableItemBar" then
                if not AQSV.enableItemBar then
                    SELFAQ.bar:Hide()
                else
                    SELFAQ.bar:Show()
                end
            end

            if key == "locked" then
                AQSV.hideBackdrop = AQSV.locked
                f.checkbox["hideBackdrop"]:SetChecked(AQSV.hideBackdrop)
                SELFAQ.lockItemBar()
                SELFAQ.hideBackdrop()
            end

            if key == "hideBackdrop" then
                SELFAQ.hideBackdrop()
            end
        end)

        f.checkbox[key] = b
        return b
    end

    -- ===== 装备栏checkbox构建函数 =====
    local function buildSlotCheckbox(text, slot_id, xPos, yPos)
        local b = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
        b:SetPoint("TOPLEFT", f, xPos, yPos)
        b:SetChecked(AQSV.enableItemBarSlot[slot_id])

        b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        b.text:SetPoint("LEFT", b, "RIGHT", 0, 0)
        b.text:SetText(text)
        b:SetScript("OnClick", function()
            AQSV.enableItemBarSlot[slot_id] = not AQSV.enableItemBarSlot[slot_id]
            b:SetChecked(AQSV.enableItemBarSlot[slot_id])
        end)
    end

    -- ===== 区域标题构建函数 =====
    local function buildSectionTitle(text, yPos)
        local t = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        t:SetText("|cFFFFD100"..text.."|r")
        t:SetPoint("TOPLEFT", f, 16, yPos)
        return t
    end

    -- 输入框X位置（统一对齐）
    local editBoxX = 100

    -- =============================================
    -- 装备栏设置
    -- =============================================
    buildSectionTitle(L["Enable Equipment Bar"], yOffset)
    buildCheckbox(L["Enable Equipment Bar"], "enableItemBar", 16, yOffset - 20)
    buildCheckbox(L["Lock Equipment Bar"], "locked", 16, yOffset - 45)
    buildCheckbox(L["Hide Equipment Bar Background"], "hideBackdrop", 16, yOffset - 70)

    -- 按钮缩放（与启用装备栏同行）
    do
        local t = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        t:SetText(L["Button Zoom"])
        t:SetPoint("TOPLEFT", f, 250, yOffset - 30)

        local e = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
        e:SetFontObject("GameFontHighlight")
        e:SetWidth(50)
        e:SetHeight(30)
        e:SetJustifyH("CENTER")
        e:SetPoint("TOPLEFT", f, 340, yOffset - 20)
        e:SetAutoFocus(false)
        e:SetText(AQSV.barZoom)
        e:SetCursorPosition(0)
        e:SetScript("OnEnterPressed", function(self)
            self:ClearFocus()
            local v = tonumber(self:GetText())
            if not v then v = 1 end
            self:SetText(v)
            AQSV.barZoom = v
            SELFAQ.bar:SetScale(AQSV.barZoom)
        end)

        -- #回车后生效 紧跟按钮缩放输入框右侧
        local hint = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        hint:SetText("|cFFFF0000"..L["#Effective after ENTER"].."|r")
        hint:SetPoint("LEFT", e, "RIGHT", 10, 0)
    end

    -- 按钮间距（与锁定装备栏同行）
    do
        local t = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        t:SetText(L["Button Spacing"])
        t:SetPoint("TOPLEFT", f, 250, yOffset - 55)

        local e = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
        e:SetFontObject("GameFontHighlight")
        e:SetWidth(50)
        e:SetHeight(30)
        e:SetJustifyH("CENTER")
        e:SetPoint("TOPLEFT", f, 340, yOffset - 45)
        e:SetAutoFocus(false)
        e:SetText(AQSV.buttonSpacingNew)
        e:SetCursorPosition(0)
        e:SetScript("OnEnterPressed", function(self)
            self:ClearFocus()
            local v = tonumber(self:GetText())
            if not v then v = 3 end
            self:SetText(v)
            AQSV.buttonSpacingNew = v
            SELFAQ.relayoutBar()
        end)
    end

    -- 快捷键字体大小（与隐藏装备栏背景同行）
    do
        local t = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        t:SetText(L["Hotkey Font Size"])
        t:SetPoint("TOPLEFT", f, 250, yOffset - 80)

        local e = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
        e:SetFontObject("GameFontHighlight")
        e:SetWidth(50)
        e:SetHeight(30)
        e:SetJustifyH("CENTER")
        e:SetPoint("TOPLEFT", f, 340, yOffset - 70)
        e:SetAutoFocus(false)
        e:SetText(AQSV.hotkeyFontSize)
        e:SetCursorPosition(0)
        e:SetScript("OnEnterPressed", function(self)
            self:ClearFocus()
            local v = tonumber(self:GetText())
            if not v then v = 8 end
            self:SetText(v)
            AQSV.hotkeyFontSize = v
            -- 实时更新所有按钮的快捷键字体大小
            if SELFAQ.slotFrames then
                for _, button in pairs(SELFAQ.slotFrames) do
                    if button.shortcut then
                        local fontPath = AQSV.fontPath or [[Fonts\FRIZQT__.TTF]]
                        button.shortcut:SetFont(fontPath, v, "OUTLINE")
                    end
                end
            end
        end)
    end

    -- 字体路径
    do
        local t = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        t:SetText(L["Font Path"])
        t:SetPoint("TOPLEFT", f, 16, yOffset - 105)

        local e = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
        e:SetFontObject("GameFontHighlight")
        e:SetWidth(350)
        e:SetHeight(30)
        e:SetJustifyH("LEFT")
        e:SetPoint("TOPLEFT", f, 100, yOffset - 100)
        e:SetAutoFocus(false)
        e:SetText(AQSV.fontPath)
        e:SetCursorPosition(0)
        e:SetScript("OnEnterPressed", function(self)
            self:ClearFocus()
            local path = self:GetText()
            if path == "" then
                path = [[Fonts\FRIZQT__.TTF]]
            end
            self:SetText(path)
            AQSV.fontPath = path
            -- 实时更新所有按钮字体
            if SELFAQ.slotFrames then
                for _, button in pairs(SELFAQ.slotFrames) do
                    if button.shortcut then
                        button.shortcut:SetFont(path, AQSV.hotkeyFontSize or 8, "OUTLINE")
                    end
                    if button.text then
                        button.text:SetFont(path, 16, "OUTLINE")
                    end
                end
            end
            if SELFAQ.itemButtons then
                for _, button in pairs(SELFAQ.itemButtons) do
                    if button.text then
                        button.text:SetFont(path, 16, "OUTLINE")
                    end
                end
            end
        end)

        local hint = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        hint:SetText("|cFFFF0000"..L["#Effective after ENTER"].."|r")
        hint:SetPoint("LEFT", e, "RIGHT", 10, 0)
    end

    yOffset = yOffset - 130
    buildLine(yOffset)
    yOffset = yOffset - 10

    -- =============================================
    -- 装备栏槽位选择
    -- =============================================
    do
        local title = buildSectionTitle(L["Equipment Bar Button"], yOffset)

        local hint = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        hint:SetText("|cFFFF0000"..L["#Effective after Reload UI"].."|r")
        hint:SetPoint("LEFT", title, "RIGHT", 10, 0)
    end

    yOffset = yOffset - 22

    -- 每行4个
    local col4 = {16, 110, 210, 310}

    -- 第1行: 饰品1 饰品2 主手 副手
    buildSlotCheckbox(L["Trinket "]..1, 13, col4[1], yOffset)
    buildSlotCheckbox(L["Trinket "]..2, 14, col4[2], yOffset)
    buildSlotCheckbox(L["MainHand"], 16, col4[3], yOffset)
    buildSlotCheckbox(L["OffHand"], 17, col4[4], yOffset)

    yOffset = yOffset - 25

    -- 第2行: 远程 头部 颈部 肩部
    buildSlotCheckbox(L["Ranged"], 18, col4[1], yOffset)
    buildSlotCheckbox(L["Head"], 1, col4[2], yOffset)
    buildSlotCheckbox(L["Neck"], 2, col4[3], yOffset)
    buildSlotCheckbox(L["Shoulder"], 3, col4[4], yOffset)

    yOffset = yOffset - 25

    -- 第3行: 胸部 腰部 腿部 脚
    buildSlotCheckbox(L["Chest"], 5, col4[1], yOffset)
    buildSlotCheckbox(L["Waist"], 6, col4[2], yOffset)
    buildSlotCheckbox(L["Legs"], 7, col4[3], yOffset)
    buildSlotCheckbox(L["Feet"], 8, col4[4], yOffset)

    yOffset = yOffset - 25

    -- 第4行: 手腕 手 背部 戒指1
    buildSlotCheckbox(L["Wrist"], 9, col4[1], yOffset)
    buildSlotCheckbox(L["Hands"], 10, col4[2], yOffset)
    buildSlotCheckbox(L["Back"], 15, col4[3], yOffset)
    buildSlotCheckbox(L["Finger "]..1, 11, col4[4], yOffset)

    yOffset = yOffset - 25

    -- 第5行: 戒指2
    buildSlotCheckbox(L["Finger "]..2, 12, col4[1], yOffset)

    yOffset = yOffset - 35
    buildLine(yOffset)
    yOffset = yOffset - 15

    -- =============================================
    -- 重新加载UI按钮
    -- =============================================
    do
        local btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        btn:SetSize(120, 25)
        btn:SetPoint("TOPLEFT", f, 16, yOffset)
        btn:SetText(L["Reload UI"])
        btn:SetScript("OnClick", function()
            ReloadUI()
        end)
    end

    -- =============================================
    -- 计算界面尺寸
    -- =============================================
    yOffset = yOffset - 40
    local totalHeight = math.abs(yOffset) + 10
    local totalWidth = 600

    top:SetSize(totalWidth, totalHeight)

    InterfaceOptions_AddCategory(top)

end
