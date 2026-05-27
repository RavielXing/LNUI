local ADDON_NAME, CooldownDone = ...

CooldownDone.spellBookSpells = {}
CooldownDone.equippedItemSpells = {}
CooldownDone.auras = {}
CooldownDone.addedAuras = {}
CooldownDone.auraStateCache = {}
CooldownDone.cooldownFrames = {}
CooldownDone.Locale = {}
CooldownDone.specialSpellIdGroups = {
    [-1] = {
        80353, -- Time Warp
        2825, -- Bloodlust
        32182, -- Heroism
        264667, -- Primal Rage
        466904,
        390386, -- Fury of the Aspects
        444257,
    },
    [-2] = {
        80354, -- Temporal Displacement
        57724, -- Sated
        57723, -- Exhaustion
        264689,
        390435,
    },
}
local L = CooldownDone.Locale

local GetTime, PlaySoundFile = GetTime, PlaySoundFile
local string_sub, tonumber = string.sub, tonumber
local C_Item_GetItemCooldown, C_VoiceChat_SpeakText = C_Item.GetItemCooldown, C_VoiceChat.SpeakText
local C_Spell_GetSpellName, C_Spell_GetSpellCooldownDuration = C_Spell.GetSpellName, C_Spell.GetSpellCooldownDuration
local C_Spell_GetSpellTexture, C_Spell_GetSpellChargeDuration = C_Spell.GetSpellTexture, C_Spell.GetSpellChargeDuration
-- local C_UnitAuras_GetPlayerAuraBySpellID = C_UnitAuras.GetPlayerAuraBySpellID
local AuraUtil_ForEachAura = AuraUtil.ForEachAura
local C_DurationUtil_CreateDuration = C_DurationUtil.CreateDuration

local function prepareDB()
    CooldownDoneDB = (type(CooldownDoneDB) == "table" and CooldownDoneDB) or {}
    CooldownDoneCharDB = (type(CooldownDoneCharDB) == "table" and CooldownDoneCharDB) or {}
end

local function CDD_IsAuraExists(auraID)
    local currentState = false
    AuraUtil_ForEachAura("player", "HELPFUL|HARMFUL", nil, function(...)
        local auraDataSpellId = select(10, ...)
        if auraDataSpellId == auraID then
            currentState = true
            return true
        end
    end)
    return currentState
end

function CooldownDone:debug(val)
    if not CooldownDoneDB or not CooldownDoneDB["CooldownDone.debug"] then return end
    print("CDD(" .. GetTime() .. "): " .. val)
end

function CooldownDone:getPlayerSpellBookSpells()
    table.wipe(self.spellBookSpells)
    local numSkillLines = C_SpellBook.GetNumSpellBookSkillLines()
    for i = 1, numSkillLines do
        local skillLineInfo = C_SpellBook.GetSpellBookSkillLineInfo(i)
        local offset, numSlots = skillLineInfo.itemIndexOffset, skillLineInfo.numSpellBookItems
        for j = offset+1, offset+numSlots do
            local info = C_SpellBook.GetSpellBookItemInfo(j, Enum.SpellBookSpellBank.Player)
            if info and not info.isPassive and not info.isOffSpec and info.itemType == Enum.SpellBookItemType.Spell and info.name then
                local spellID = info.spellID or info.actionID
                if spellID and spellID > 0 and not self.spellBookSpells[spellID] then
                    self.spellBookSpells[spellID] = {
                        id = spellID,
                        name = C_Spell_GetSpellName(spellID) or L["UnknownSpell"],
                        texture = C_Spell_GetSpellTexture(spellID)
                    }
                end
            end
        end
    end
    table.sort(self.spellBookSpells, function(a, b) return a.name:lower() < b.name:lower() end)
end

function CooldownDone:getAuras()
    table.wipe(self.auras)
    table.wipe(self.addedAuras)
    table.wipe(self.auraStateCache)
    local auraID, showAuraID
    for k, v in pairs(CooldownDoneCharDB) do
        auraID = tonumber(k:match("CooldownDone.aura.([-]?[%d]+).name"))
        if auraID then
            if not self.auras[auraID] then
                showAuraID = self.specialSpellIdGroups[auraID] and self.specialSpellIdGroups[auraID][1] or auraID
                self.auras[auraID] = {
                    id = auraID,
                    name = C_Spell_GetSpellName(showAuraID) or L["UnknownAura"],
                    texture = C_Spell_GetSpellTexture(showAuraID)
                }
            end
            if self.specialSpellIdGroups[auraID] then
                for _, innerAuraID in pairs(self.specialSpellIdGroups[auraID]) do
                    -- self.auraStateCache[innerAuraID] = C_UnitAuras_GetPlayerAuraBySpellID(innerAuraID) ~= nil
                    self.auraStateCache[innerAuraID] = CDD_IsAuraExists(innerAuraID)
                end
            else
                -- self.auraStateCache[auraID] = C_UnitAuras_GetPlayerAuraBySpellID(auraID) ~= nil
                self.auraStateCache[auraID] = CDD_IsAuraExists(auraID)
            end
        end
        auraID = tonumber(k:match("CooldownDone.addedaura.([-]?[%d]+).name"))
        if auraID then
            if not self.addedAuras[auraID] then
                showAuraID = self.specialSpellIdGroups[auraID] and self.specialSpellIdGroups[auraID][1] or auraID
                self.addedAuras[auraID] = {
                    id = auraID,
                    name = C_Spell_GetSpellName(showAuraID) or L["UnknownAura"],
                    texture = C_Spell_GetSpellTexture(showAuraID)
                }
            end
            if self.specialSpellIdGroups[auraID] then
                for _, innerAuraID in pairs(self.specialSpellIdGroups[auraID]) do
                    -- self.auraStateCache[innerAuraID] = C_UnitAuras_GetPlayerAuraBySpellID(innerAuraID) ~= nil
                    self.auraStateCache[innerAuraID] = CDD_IsAuraExists(innerAuraID)
                end
            else
                -- self.auraStateCache[auraID] = C_UnitAuras_GetPlayerAuraBySpellID(auraID) ~= nil
                self.auraStateCache[auraID] = CDD_IsAuraExists(auraID)
            end
        end
    end
end

function CooldownDone:getEquippedItemSpells(prepareSettings)
    table.wipe(self.equippedItemSpells)
    local itemIDs = {}
    for slot = INVSLOT_FIRST_EQUIPPED, INVSLOT_LAST_EQUIPPED do
        local itemID = GetInventoryItemID("player", slot)
        if itemID then
            table.insert(itemIDs, {itemID = itemID, from = "equipped"})
        end
    end
    for containerIndex = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
        for slotIndex = 1, C_Container.GetContainerNumSlots(containerIndex) do
            itemID = C_Container.GetContainerItemID(containerIndex, slotIndex)
            if itemID then
                table.insert(itemIDs, {itemID = itemID, from = "container"})
            end
        end
    end
    local itemLoadCount = 0
    for _, itemID in ipairs(itemIDs) do
        local item = Item:CreateFromItemID(itemID.itemID)
        item:ContinueOnItemLoad(function()
            local spellName, spellID = C_Item.GetItemSpell(itemID.itemID)
            if spellID and spellName and not (itemID.from == "container" and not C_Item.IsEquippableItem(itemID.itemID)) and not self.equippedItemSpells[spellID] then
                local sName = C_Spell_GetSpellName(spellID) or spellName
                local iName = item:GetItemName()  or sName
                self.equippedItemSpells[spellID] = {
                    id = spellID,
                    name = sName,
                    texture = C_Spell_GetSpellTexture(spellID),
                    itemID = itemID.itemID,
                    itemName = iName,
                    itemTexture = item:GetItemIcon()
                }
            end
            itemLoadCount = itemLoadCount + 1
            if itemLoadCount >= #itemIDs then
                table.sort(self.equippedItemSpells, function(a, b) return a.name:lower() < b.name:lower() end)
                if prepareSettings then
                    self:prepareSettings()
                end
            end
        end)
    end
    if #itemIDs == 0 and prepareSettings then
        self:prepareSettings()
    end
end

function CooldownDone:speakTTS(text, typeStr)
    if not text then return end
    if not CooldownDoneDB or not CooldownDoneDB["CooldownDone.enable"] then return end
    if tonumber(text) then
        local willPlay, _ = PlaySoundFile(tonumber(text), "Master")
        if not willPlay then
            print("|cffff0000CDD: " .. text .. " " .. L["ERR_PlaySoundFile"] .. "|r")
        end
        return
    elseif string_sub(text, 1, 17) == "Interface\\AddOns\\" then
        local willPlay, _ = PlaySoundFile(text, "Master")
        if not willPlay then
            print("|cffff0000CDD: " .. text .. " " .. L["ERR_PlaySoundFile"] .. "|r")
        end
        return
    end
    local ttsVoiceID = CooldownDoneDB and CooldownDoneDB["CooldownDone.ttsVoiceID"] or 0
    local ttsRate = CooldownDoneDB and CooldownDoneDB["CooldownDone.ttsRate"] or 0
    local ttsVolume = CooldownDoneDB and CooldownDoneDB["CooldownDone.ttsVolume"] or 100
    local textPrepend = ""
    local textAppend = CooldownDoneDB and CooldownDoneDB["CooldownDone.doneStr"] or L["Ready"]
    if typeStr == "over" then
        textAppend = CooldownDoneDB and CooldownDoneDB["CooldownDone.overStr"] or L["Expired"]
    end
    if typeStr == "added" then
        textPrepend = CooldownDoneDB and CooldownDoneDB["CooldownDone.addedStr"] or L["Gained"]
        textAppend = ""
    end
    self:debug("speakTTS: " .. text .. textAppend)
    C_VoiceChat_SpeakText(ttsVoiceID, textPrepend .. " " .. text .. " " .. textAppend, ttsRate, ttsVolume, true)
end

function CooldownDone:UNIT_SPELLCAST_SUCCEEDED(spellID, immediately)
    if not CooldownDoneDB or not CooldownDoneDB["CooldownDone.enable"] then return end
    local key = string.format("CooldownDone.spell.%s.enable", spellID)
    if not CooldownDoneCharDB or not CooldownDoneCharDB[key] then return end

    local function setCooldown(spellID)
        local isEquippedItemSpell, isChargedSpell = false, false
        local name = ""
        local spellCooldownDuration
        for _, spell in pairs(self.equippedItemSpells) do
            if tonumber(spellID) == tonumber(spell.id) then
                isEquippedItemSpell = true
                local startTime, duration = C_Item_GetItemCooldown(spell.itemID)
                spellCooldownDuration = C_DurationUtil_CreateDuration()
                spellCooldownDuration:SetTimeFromStart(startTime, duration)
                name = spell.itemName
                break
            end
        end
        if not isEquippedItemSpell then
            local spellChargeDuration = C_Spell_GetSpellChargeDuration(spellID)
            if spellChargeDuration then
                isChargedSpell = true
                spellCooldownDuration = spellChargeDuration
            else
                spellCooldownDuration = C_Spell_GetSpellCooldownDuration(spellID)
            end
            name = C_Spell_GetSpellName(spellID) or L["UnknownSpell"]
        end
        local keyName = string.format("CooldownDone.spell.%s.name", spellID)
        if CooldownDoneCharDB and CooldownDoneCharDB[keyName] and CooldownDoneCharDB[keyName] ~= "" then
            name = CooldownDoneCharDB[keyName]
        end
        if self.cooldownFrames[spellID] == nil then
            self.cooldownFrames[spellID] = CreateFrame("Cooldown", nil, UIParent, "CooldownFrameTemplate")
            self.cooldownFrames[spellID]:SetDrawBling(false)
            self.cooldownFrames[spellID]:SetDrawSwipe(false)
            self.cooldownFrames[spellID]:SetHideCountdownNumbers(true)
            self.cooldownFrames[spellID]:SetSize(1, 1)
            self.cooldownFrames[spellID]:SetAlpha(0)
            self.cooldownFrames[spellID]:Hide()
        end
        local cooldownFrame = self.cooldownFrames[spellID]
        cooldownFrame.isChargedSpell = isChargedSpell
        cooldownFrame.CooldownDoneTTSName = name
        cooldownFrame:Clear()
        cooldownFrame:SetCooldownFromDurationObject(spellCooldownDuration, true)
        if not cooldownFrame:IsVisible() and cooldownFrame:GetScript("OnCooldownDone") then
            self:speakTTS(cooldownFrame.CooldownDoneTTSName)
            cooldownFrame:SetScript("OnCooldownDone", nil)
        else
            cooldownFrame:SetScript("OnCooldownDone", function()
                self:speakTTS(cooldownFrame.CooldownDoneTTSName)
                cooldownFrame:SetScript("OnCooldownDone", nil)
            end)
        end
    end

    C_Timer.After(immediately and 0.01 or 0.5, function()
        setCooldown(spellID)
    end)
end

function CooldownDone:SPELL_UPDATE_COOLDOWN(spellID)
    if not CooldownDoneCharDB then return end
    if spellID then
        local key = string.format("CooldownDone.spell.%s.enable", spellID)
        if not CooldownDoneCharDB[key] then return end
        CooldownDone:debug("SUC " .. spellID)
        if self.cooldownFrames[spellID] then
            if self.cooldownFrames[spellID]:GetScript("OnCooldownDone") then
                self:UNIT_SPELLCAST_SUCCEEDED(spellID, true)
            end
        end
        return
    end
end

function CooldownDone:SPELL_UPDATE_CHARGES()
    if not CooldownDoneCharDB then return end
    for k, v in pairs(CooldownDoneCharDB) do
        if v then
            local spellID = k:match("CooldownDone.spell.([%d]+).enable")
            if spellID and tonumber(spellID) > 0 then
                spellID = tonumber(spellID)
                if self.cooldownFrames[spellID] then
                    CooldownDone:debug("SUCH " .. spellID)
                    if self.cooldownFrames[spellID].isChargedSpell and self.cooldownFrames[spellID]:GetScript("OnCooldownDone") then
                        self:UNIT_SPELLCAST_SUCCEEDED(spellID, true)
                    end
                end
            end
        end
    end
end

function CooldownDone:getSpellIdInSpecialSpellIdGroupsID(spellId)
    for k, v in pairs(self.specialSpellIdGroups) do
        if tContains(v, spellId) then
            return k
        end
    end
    return nil
end

function CooldownDone:UNIT_AURA()
    if not CooldownDoneDB or not CooldownDoneDB["CooldownDone.enable"] then return end
    local key, specialSpellIdGroupId
    for auraID, lastState in pairs(self.auraStateCache) do
        -- local currentState = C_UnitAuras_GetPlayerAuraBySpellID(auraID) ~= nil
        local currentState = CDD_IsAuraExists(auraID)
        if lastState ~= currentState then
            if currentState then
                key = string.format("CooldownDone.addedaura.%s.name", auraID)
                if CooldownDoneCharDB and CooldownDoneCharDB[key] ~= nil then
                    local name = CooldownDoneCharDB[key] ~= "" and CooldownDoneCharDB[key] or self.addedAuras[auraID].name
                    self:speakTTS(name, "added")
                else
                    specialSpellIdGroupId = self:getSpellIdInSpecialSpellIdGroupsID(auraID)
                    if specialSpellIdGroupId then
                        key = string.format("CooldownDone.addedaura.%s.name", specialSpellIdGroupId)
                        if CooldownDoneCharDB and CooldownDoneCharDB[key] ~= nil then
                            local name = CooldownDoneCharDB[key] ~= "" and CooldownDoneCharDB[key] or (C_Spell_GetSpellName(auraID) or L["UnknownSpell"])
                            self:speakTTS(name, "added")
                        end
                    end
                end
            else
                key = string.format("CooldownDone.aura.%s.name", auraID)
                if CooldownDoneCharDB and CooldownDoneCharDB[key] ~= nil then
                    local name = CooldownDoneCharDB[key] ~= "" and CooldownDoneCharDB[key] or self.auras[auraID].name
                    self:speakTTS(name, "over")
                else
                    specialSpellIdGroupId = self:getSpellIdInSpecialSpellIdGroupsID(auraID)
                    if specialSpellIdGroupId then
                        key = string.format("CooldownDone.aura.%s.name", specialSpellIdGroupId)
                        if CooldownDoneCharDB and CooldownDoneCharDB[key] ~= nil then
                            local name = CooldownDoneCharDB[key] ~= "" and CooldownDoneCharDB[key] or (C_Spell_GetSpellName(auraID) or L["UnknownSpell"])
                            self:speakTTS(name, "over")
                        end
                    end
                end
            end
            self.auraStateCache[auraID] = currentState
        end
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
frame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
frame:RegisterEvent("SPELL_UPDATE_CHARGES")
frame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
-- frame:RegisterUnitEvent("UNIT_AURA", "player")
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addOnName = ...
        if addOnName == ADDON_NAME then
            prepareDB()
            self:UnregisterEvent("ADDON_LOADED")
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(1, function()
            CooldownDone:getPlayerSpellBookSpells()
            -- CooldownDone:getAuras()
            CooldownDone:getEquippedItemSpells(true)
        end)
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        CooldownDone:getEquippedItemSpells(false)
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local _, _, spellID = ...
        CooldownDone:UNIT_SPELLCAST_SUCCEEDED(spellID, false)
    elseif event == "SPELL_UPDATE_COOLDOWN" then
        local spellID = ...
        CooldownDone:SPELL_UPDATE_COOLDOWN(spellID)
    elseif event == "SPELL_UPDATE_CHARGES" then
        CooldownDone:SPELL_UPDATE_CHARGES()
    elseif event == "UNIT_AURA" then
        CooldownDone:UNIT_AURA()
    end
end)
