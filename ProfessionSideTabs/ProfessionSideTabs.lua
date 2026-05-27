local addonName = ...
local addon = CreateFrame("Frame")

local container
local buttons = {}
local initialized = false

local defaults = {
    showArchaeology = false,
    showFishing = true,
    showCooking = true,
}

local function EnsureDB()
    if type(ProfessionSideTabsDB) ~= "table" then
        ProfessionSideTabsDB = {}
    end

    for key, value in pairs(defaults) do
        if ProfessionSideTabsDB[key] == nil then
            ProfessionSideTabsDB[key] = value
        end
    end
end

local BUTTON_SIZE = 48
local BUTTON_GAP = 6
local GROUP_SPACER = 14

local function IsSecondaryShown(slot)
    EnsureDB()

    if slot == 3 then
        return ProfessionSideTabsDB.showArchaeology ~= false
    elseif slot == 4 then
        return ProfessionSideTabsDB.showFishing ~= false
    elseif slot == 5 then
        return ProfessionSideTabsDB.showCooking ~= false
    end

    return true
end

local function SetSecondaryShown(slot, value)
    EnsureDB()

    if slot == 3 then
        ProfessionSideTabsDB.showArchaeology = value and true or false
    elseif slot == 4 then
        ProfessionSideTabsDB.showFishing = value and true or false
    elseif slot == 5 then
        ProfessionSideTabsDB.showCooking = value and true or false
    end
end

local function OpenProfessionBySlot(slotNumber)
    local professionIndex = select(slotNumber, GetProfessions())
    if not professionIndex then
        return
    end

    local skillLine = select(7, GetProfessionInfo(professionIndex))
    if not skillLine then
        return
    end

    C_TradeSkillUI.OpenTradeSkill(skillLine)
end

local function GetProfessionDataBySlot(slotNumber)
    local professionIndex = select(slotNumber, GetProfessions())
    if not professionIndex then
        return nil
    end

    local name, icon, skillLevel, maxSkillLevel, numAbilities, spellOffset, skillLine, skillModifier =
        GetProfessionInfo(professionIndex)

    if not skillLine then
        return nil
    end

    return {
        slotNumber = slotNumber,
        professionIndex = professionIndex,
        name = name,
        icon = icon,
        skillLevel = skillLevel,
        maxSkillLevel = maxSkillLevel,
        skillLine = skillLine,
        skillModifier = skillModifier or 0,
    }
end

local function GetCurrentOpenSkillLine()
    if not C_TradeSkillUI or not C_TradeSkillUI.GetBaseProfessionInfo then
        return nil
    end

    local info = C_TradeSkillUI.GetBaseProfessionInfo()
    if info and info.professionID then
        return info.professionID
    end

    return nil
end

local function UpdateButtonTooltip(self)
    if not self.professionData then
        return
    end

    GameTooltip:SetOwner(self, "ANCHOR_NONE")
    GameTooltip:SetPoint("LEFT", self, "RIGHT", 12, 0)
    GameTooltip:AddLine(self.professionData.name or UNKNOWN, 1, 0.82, 0)

    local bonusText = ""
    if self.professionData.skillModifier and self.professionData.skillModifier ~= 0 then
        if self.professionData.skillModifier > 0 then
            bonusText = string.format(" |cff20ff20(+%d)|r", self.professionData.skillModifier)
        else
            bonusText = string.format(" |cffff4040(%d)|r", self.professionData.skillModifier)
        end
    end

    if self.professionData.skillLevel and self.professionData.maxSkillLevel then
        GameTooltip:AddLine(
            string.format(
                "Skill: %d/%d%s",
                self.professionData.skillLevel,
                self.professionData.maxSkillLevel,
                bonusText
            ),
            1, 1, 1
        )
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("点击打开", 0, 1, 0)
    GameTooltip:Show()
end

local function UpdateButtonState(button, isSelected)
    if isSelected then
        button.selectedGlow:Show()
        button.leftFlair:SetAlpha(1)
        button.icon:SetAlpha(1)
    else
        button.selectedGlow:Hide()
        button.leftFlair:SetAlpha(0.35)
        button.icon:SetAlpha(0.95)
    end
end

local function CreateTabButton(parent, index)
    local button = CreateFrame("Button", addonName .. "Tab" .. index, parent)
    button:SetSize(BUTTON_SIZE, BUTTON_SIZE)

    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.10, 0.09, 0.08, 0.95)
    button.bg = bg

    local border = button:CreateTexture(nil, "BORDER")
    border:SetAllPoints()
    border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
    button.border = border

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 5, -5)
    icon:SetPoint("BOTTOMRIGHT", -5, 5)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    button.icon = icon

    local hoverGlow = button:CreateTexture(nil, "OVERLAY")
    hoverGlow:SetAllPoints()
    hoverGlow:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    hoverGlow:SetBlendMode("ADD")
    hoverGlow:SetAlpha(0.55)
    hoverGlow:Hide()
    button.hoverGlow = hoverGlow

    local selectedGlow = button:CreateTexture(nil, "OVERLAY")
    selectedGlow:SetTexture("Interface\\Buttons\\CheckButtonGlow")
    selectedGlow:SetBlendMode("ADD")
    selectedGlow:SetAlpha(0.85)
    selectedGlow:SetPoint("TOPLEFT", icon, -20, 20)
    selectedGlow:SetPoint("BOTTOMRIGHT", icon, 20, -20)
    selectedGlow:Hide()
    button.selectedGlow = selectedGlow

    local leftFlair = button:CreateTexture(nil, "OVERLAY")
    leftFlair:SetWidth(10)
    leftFlair:SetPoint("TOPLEFT", -4, 0)
    leftFlair:SetPoint("BOTTOMLEFT", -4, 0)
    leftFlair:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    leftFlair:SetTexCoord(0.05, 0.18, 0.2, 0.8)
    leftFlair:SetBlendMode("ADD")
    leftFlair:SetAlpha(0.35)
    button.leftFlair = leftFlair

    local pushedShade = button:CreateTexture(nil, "OVERLAY")
    pushedShade:SetAllPoints()
    pushedShade:SetColorTexture(0, 0, 0, 0.2)
    pushedShade:Hide()
    button.pushedShade = pushedShade

    button:SetScript("OnClick", function(self)
        if self.slotNumber then
            OpenProfessionBySlot(self.slotNumber)
        end
    end)

    button:SetScript("OnEnter", function(self)
        self.hoverGlow:Show()
        UpdateButtonTooltip(self)
    end)

    button:SetScript("OnLeave", function(self)
        self.hoverGlow:Hide()
        GameTooltip_Hide()
    end)

    button:SetScript("OnMouseDown", function(self)
        self.pushedShade:Show()
        self.icon:ClearAllPoints()
        self.icon:SetPoint("TOPLEFT", 6, -6)
        self.icon:SetPoint("BOTTOMRIGHT", -4, 4)
    end)

    button:SetScript("OnMouseUp", function(self)
        self.pushedShade:Hide()
        self.icon:ClearAllPoints()
        self.icon:SetPoint("TOPLEFT", 5, -5)
        self.icon:SetPoint("BOTTOMRIGHT", -5, 5)
    end)

    return button
end

local function EnsureUI()
    if initialized then
        return
    end

    if not ProfessionsFrame then
        return
    end

    container = CreateFrame("Frame", addonName .. "Container", ProfessionsFrame)
    container:SetWidth(BUTTON_SIZE + 20)
    container:SetPoint("TOPLEFT", ProfessionsFrame, "TOPRIGHT", -1, -74)

    container.bg = container:CreateTexture(nil, "BACKGROUND")
    container.bg:SetAllPoints()
    container.bg:SetColorTexture(0.14, 0.12, 0.10, 0.94)

    container.top = container:CreateTexture(nil, "BORDER")
    container.top:SetPoint("TOPLEFT")
    container.top:SetPoint("TOPRIGHT")
    container.top:SetHeight(2)
    container.top:SetColorTexture(0.6, 0.6, 0.6, 0.8)

    container.right = container:CreateTexture(nil, "BORDER")
    container.right:SetPoint("TOPRIGHT")
    container.right:SetPoint("BOTTOMRIGHT")
    container.right:SetWidth(2)
    container.right:SetColorTexture(0.6, 0.6, 0.6, 0.8)

    container.bottom = container:CreateTexture(nil, "BORDER")
    container.bottom:SetPoint("BOTTOMLEFT")
    container.bottom:SetPoint("BOTTOMRIGHT")
    container.bottom:SetHeight(2)
    container.bottom:SetColorTexture(0.6, 0.6, 0.6, 0.8)

    container.divider = container:CreateTexture(nil, "ARTWORK")
    container.divider:SetHeight(8)
    container.divider:SetTexture("Interface\\Common\\UI-TooltipDivider-Transparent")
    container.divider:SetAlpha(0.9)
    container.divider:Hide()

    container:Hide()

    for i = 1, 5 do
        buttons[i] = CreateTabButton(container, i)
    end

    initialized = true
end

local function LayoutButtons()
    if not container then
        return
    end

    container.divider:Hide()

    local y = 0
    local anyPrimaryShown = false
    local anySecondaryShown = false
    local lastVisiblePrimarySlot = nil

    for slot = 1, 2 do
        if buttons[slot] and buttons[slot]:IsShown() then
            anyPrimaryShown = true
            lastVisiblePrimarySlot = slot
        end
    end

    for slot = 3, 5 do
        if buttons[slot] and buttons[slot]:IsShown() then
            anySecondaryShown = true
            break
        end
    end

    for slot = 1, 5 do
        local button = buttons[slot]
        if button and button:IsShown() then
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", container, "TOPLEFT", 9, -7 - y)
            y = y + BUTTON_SIZE + BUTTON_GAP

            if slot == lastVisiblePrimarySlot and anyPrimaryShown and anySecondaryShown then
                container.divider:Show()
                container.divider:ClearAllPoints()
                container.divider:SetPoint("TOPLEFT", container, "TOPLEFT", 8, -y - 4)
                container.divider:SetPoint("TOPRIGHT", container, "TOPRIGHT", -16, -y - 4)

                y = y + GROUP_SPACER
            end
        end
    end

    container:SetHeight(math.max(y + 10, BUTTON_SIZE))
end

local function UpdateButtons()
    EnsureUI()
    if not initialized then
        return
    end

    local currentSkillLine = GetCurrentOpenSkillLine()
    local visibleSlots = {}

    for slot = 1, 5 do
        if slot < 3 or IsSecondaryShown(slot) then
            local data = GetProfessionDataBySlot(slot)
            if data then
                visibleSlots[#visibleSlots + 1] = slot
            end
        end
    end

    local shouldShowAnyButtons = #visibleSlots > 1

    for slot = 1, 5 do
        local button = buttons[slot]

        if not shouldShowAnyButtons then
            button.slotNumber = nil
            button.professionData = nil
            button:Hide()
            button.hoverGlow:Hide()
            button.selectedGlow:Hide()
        else
            if slot >= 3 and not IsSecondaryShown(slot) then
                button.slotNumber = nil
                button.professionData = nil
                button:Hide()
                button.hoverGlow:Hide()
                button.selectedGlow:Hide()
            else
                local data = GetProfessionDataBySlot(slot)

                if data then
                    button.slotNumber = slot
                    button.professionData = data
                    button.icon:SetTexture(data.icon or 134400)
                    button:Show()

                    UpdateButtonState(button, currentSkillLine and currentSkillLine == data.skillLine)
                else
                    button.slotNumber = nil
                    button.professionData = nil
                    button:Hide()
                    button.hoverGlow:Hide()
                    button.selectedGlow:Hide()
                end
            end
        end
    end

    LayoutButtons()

    if ProfessionsFrame and ProfessionsFrame:IsShown() and shouldShowAnyButtons then
        container:Show()
    else
        container:Hide()
    end
end

local function OnProfessionWindowShown()
    UpdateButtons()
end

local function OnProfessionWindowHidden()
    if container then
        container:Hide()
    end
end

local function TryHookProfessionFrame()
    if not ProfessionsFrame then
        return
    end

    EnsureUI()

    if not ProfessionsFrame.__ProfessionSideTabsHooked then
        ProfessionsFrame:HookScript("OnShow", OnProfessionWindowShown)
        ProfessionsFrame:HookScript("OnHide", OnProfessionWindowHidden)
        ProfessionsFrame.__ProfessionSideTabsHooked = true
    end
end

addon:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        EnsureDB()
        TryHookProfessionFrame()
        return
    end

    if event == "TRADE_SKILL_SHOW" then
        TryHookProfessionFrame()
        OnProfessionWindowShown()
        return
    end

    if event == "TRADE_SKILL_CLOSE" then
        OnProfessionWindowHidden()
        return
    end

    if event == "SKILL_LINES_CHANGED"
        or event == "SPELLS_CHANGED"
        or event == "CHAT_MSG_SKILL"
        or event == "TRADE_SKILL_LIST_UPDATE"
        or event == "TRADE_SKILL_NAME_UPDATE"
    then
        UpdateButtons()
        return
    end
end)

addon:RegisterEvent("PLAYER_LOGIN")
addon:RegisterEvent("TRADE_SKILL_SHOW")
addon:RegisterEvent("TRADE_SKILL_CLOSE")
addon:RegisterEvent("SKILL_LINES_CHANGED")
addon:RegisterEvent("SPELLS_CHANGED")
addon:RegisterEvent("CHAT_MSG_SKILL")
addon:RegisterEvent("TRADE_SKILL_LIST_UPDATE")
addon:RegisterEvent("TRADE_SKILL_NAME_UPDATE")

SLASH_PROFESSIONSIDETABS1 = "/pst"

SlashCmdList["PROFESSIONSIDETABS"] = function(msg)
    EnsureDB()

    msg = (msg or ""):lower():match("^%s*(.-)%s*$")

    local cmd, arg = msg:match("^(%S+)%s*(%S*)$")

    local function Apply(slot, name)
        if arg == "hide" then
            SetSecondaryShown(slot, false)
            print("|cff00ff98PST|r: " .. name .. " hidden")
        elseif arg == "show" then
            SetSecondaryShown(slot, true)
            print("|cff00ff98PST|r: " .. name .. " shown")
        else
            print("|cff00ff98PST|r usage: /pst " .. name:lower() .. " show/hide")
            return
        end

        UpdateButtons()
    end

    if cmd == "archy" or cmd == "archaeology" then
        Apply(3, "Archaeology")
        return
    elseif cmd == "fishing" then
        Apply(4, "Fishing")
        return
    elseif cmd == "cooking" then
        Apply(5, "Cooking")
        return
    elseif cmd == "secondary" then
        if arg == "hide" then
            SetSecondaryShown(3, false)
            SetSecondaryShown(4, false)
            SetSecondaryShown(5, false)
            print("|cff00ff98PST|r: All secondary professions hidden")
        elseif arg == "show" then
            SetSecondaryShown(3, true)
            SetSecondaryShown(4, true)
            SetSecondaryShown(5, true)
            print("|cff00ff98PST|r: All secondary professions shown")
        else
            print("|cff00ff98PST|r usage: /pst secondary show/hide")
            return
        end

        UpdateButtons()
        return
    end

    print("|cff00ff98PST|r commands:")
    print("|cff00ff98PST|r /pst archy show/hide")
    print("|cff00ff98PST|r /pst fishing show/hide")
    print("|cff00ff98PST|r /pst cooking show/hide")
    print("|cff00ff98PST|r /pst secondary show/hide")
end
