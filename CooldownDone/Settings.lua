local ADDON_NAME, CooldownDone = ...

local L = CooldownDone.Locale

local LibBlzSettings = LibStub("LibBlzSettings-1.0")
local CONTROL_TYPE = LibBlzSettings.CONTROL_TYPE
local SETTING_TYPE = LibBlzSettings.SETTING_TYPE

CooldownDone.category = nil
local CATEGORY_NAME_AURA = L["BuffList"]
local CATEGORY_NAME_ABILITIES = L["AbilityList"]
local CONTROL_AURA_EXPIRED = L["AuraExpired"]
local CONTROL_AURA_GAINED = L["AuraGained"]

-- Matches a similar function reused in multiple places
local function EnumerateTaintedKeysTable(tableToIterate)
    local pairsIterator, enumerateTable, initialIteratorKey = securecallfunction(pairs, tableToIterate);
    local function IteratorFunction(tbl, key)
        return securecallfunction(pairsIterator, tbl, key);
    end

    return IteratorFunction, enumerateTable, initialIteratorKey;
end

local function formatNameIdTexture(name, id, texture)
    local ret = name .. "(" .. tostring(id) .. ")"
    if texture and texture ~= "" then
        ret = ret .. "|T" .. texture .. ":14:14:1:0|t"
    end
    return ret
end

function CooldownDone:addAura(control)
    local auraID = tonumber(control.Editbox:GetText())
    if not auraID then
        print("|cffff0000" .. L["PleaseEnterID"] .. "|r")
        return
    end
    local showAuraID = self.specialSpellIdGroups[auraID] and self.specialSpellIdGroups[auraID][1] or auraID
    local auraName = C_Spell.GetSpellName(showAuraID)
    if not auraName then
        print("|cffff0000" .. L["IDNotFound"] .. "|r")
        return
    end
    if self.auras[auraID] then
        print(string.format("|cffff0000%s-%s " .. L["IDExists"] .. "|r", auraID, auraName))
        return
    end
    local key = string.format("CooldownDone.aura.%s.name", auraID)
    CooldownDoneCharDB[key] = ""
    -- self.auras[auraID] = {
        -- id = auraID,
        -- name = auraName,
        -- texture = C_Spell.GetSpellTexture(showAuraID)
    -- }
    self:getAuras()
    local name = formatNameIdTexture(self.auras[auraID].name, self.auras[auraID].id, self.auras[auraID].texture)
    local dataTbl = {
        controlType = "CDD_EDITBOX_AND_BUTTON",
        settingType = SETTING_TYPE.ADDON_VARIABLE,
        name = name,
        key = key,
        default = "",
        editboxTooltip = L["CustomName2"],
        OnEditboxValueChanged = function(...) self:getAuras() end,
        button = {
            buttonText = REMOVE,
            OnButtonClick = function(control)
                self:removeAura(control)
            end,
        },
    }
    for _, subCategory in ipairs(CooldownDone.category:GetSubcategories()) do
        if subCategory:GetName() == CATEGORY_NAME_AURA then
            local layout = SettingsPanel:GetLayout(subCategory)
            local _, initializer = CDDSettingsEditboxAndButtonBuildFunction(ADDON_NAME, subCategory, layout, dataTbl, CooldownDoneCharDB)
            initializer.LibBlzSettingsData = {}
            local newInitializers = {}
            for k, v in EnumerateTaintedKeysTable(layout:GetInitializers()) do
                if v.data.name == CONTROL_AURA_GAINED then
                    table.insert(newInitializers, initializer)
                end
                if v ~= initializer then
                    table.insert(newInitializers, v)
                end
            end
            layout.initializers = newInitializers
            SettingsPanel:DisplayLayout(layout)
            break
        end
    end
end

function CooldownDone:addAddedAura(control)
    local auraID = tonumber(control.Editbox:GetText())
    if not auraID then
        print("|cffff0000" .. L["PleaseEnterID"] .. "|r")
        return
    end
    local showAuraID = self.specialSpellIdGroups[auraID] and self.specialSpellIdGroups[auraID][1] or auraID
    local auraName = C_Spell.GetSpellName(showAuraID)
    if not auraName then
        print("|cffff0000" .. L["IDNotFound"] .. "|r")
        return
    end
    if self.addedAuras[auraID] then
        print(string.format("|cffff0000%s-%s " .. L["IDExists"] .. "|r", auraID, auraName))
        return
    end
    local key = string.format("CooldownDone.addedaura.%s.name", auraID)
    CooldownDoneCharDB[key] = ""
    -- self.addedAuras[auraID] = {
        -- id = auraID,
        -- name = auraName,
        -- texture = C_Spell.GetSpellTexture(showAuraID)
    -- }
    self:getAuras()
    local name = formatNameIdTexture(self.addedAuras[auraID].name, self.addedAuras[auraID].id, self.addedAuras[auraID].texture)
    local dataTbl = {
        controlType = "CDD_EDITBOX_AND_BUTTON",
        settingType = SETTING_TYPE.ADDON_VARIABLE,
        name = name,
        key = key,
        default = "",
        editboxTooltip = L["CustomName2"],
        OnEditboxValueChanged = function(...) self:getAuras() end,
        button = {
            buttonText = REMOVE,
            OnButtonClick = function(control)
                self:removeAddedAura(control)
            end,
        },
    }
    for _, subCategory in ipairs(CooldownDone.category:GetSubcategories()) do
        if subCategory:GetName() == CATEGORY_NAME_AURA then
            local layout = SettingsPanel:GetLayout(subCategory)
            local _, initializer = CDDSettingsEditboxAndButtonBuildFunction(ADDON_NAME, subCategory, layout, dataTbl, CooldownDoneCharDB)
            initializer.LibBlzSettingsData = {}
            SettingsPanel:DisplayLayout(layout)
            break
        end
    end
end

function CooldownDone:removeAura(control)
    local initializer = control:GetElementData()
    local key = initializer.data.key
    local auraID = key:match("CooldownDone.aura.([-]?[%d]+).name")
    auraID = tonumber(auraID)
    if not auraID then
        print("|cffff0000" .. ERRORS .. "|r")
        return
    end
    local key = string.format("CooldownDone.aura.%s.name", auraID)
    CooldownDoneCharDB[key] = nil
    -- self.auras[auraID] = nil
    self:getAuras()
    for _, subCategory in ipairs(CooldownDone.category:GetSubcategories()) do
        if subCategory:GetName() == CATEGORY_NAME_AURA then
            local layout = SettingsPanel:GetLayout(subCategory)
            local newInitializers = {}
            for k, v in EnumerateTaintedKeysTable(layout:GetInitializers()) do
                if initializer ~= v then
                    table.insert(newInitializers, v)
                end
            end
            layout.initializers = newInitializers
            SettingsPanel:DisplayLayout(layout)
            break
        end
    end
end

function CooldownDone:removeAddedAura(control)
    local initializer = control:GetElementData()
    local key = initializer.data.key
    local auraID = key:match("CooldownDone.addedaura.([-]?[%d]+).name")
    auraID = tonumber(auraID)
    if not auraID then
        print("|cffff0000" .. ERRORS .. "|r")
        return
    end
    local key = string.format("CooldownDone.addedaura.%s.name", auraID)
    CooldownDoneCharDB[key] = nil
    -- self.addedAuras[auraID] = nil
    self:getAuras()
    for _, subCategory in ipairs(CooldownDone.category:GetSubcategories()) do
        if subCategory:GetName() == CATEGORY_NAME_AURA then
            local layout = SettingsPanel:GetLayout(subCategory)
            local newInitializers = {}
            for k, v in EnumerateTaintedKeysTable(layout:GetInitializers()) do
                if initializer ~= v then
                    table.insert(newInitializers, v)
                end
            end
            layout.initializers = newInitializers
            SettingsPanel:DisplayLayout(layout)
            break
        end
    end
end

function CooldownDone:prepareSettings()
    local voiceIDOptions = {}
    local voiceIDDefault = nil
    local ttsVoices = C_VoiceChat.GetTtsVoices()
    for index, voice in ipairs(ttsVoices) do
        if voiceIDDefault == nil then
            voiceIDDefault = voice.voiceID
        end
        table.insert(voiceIDOptions, {
            value = voice.voiceID,
            name = voice.name,
            tooltip = voice.name,
        })
    end
    local settings = {
        name = L["addonName"],
        settings = {
            {
                controlType = CONTROL_TYPE.CHECKBOX,
                settingType = SETTING_TYPE.ADDON_VARIABLE,
                name = ENABLE,
                tooltip = L["EnableTooltip"],
                key = "CooldownDone.enable",
                default = true,
            },
            {
                controlType = CONTROL_TYPE.CHECKBOX,
                settingType = SETTING_TYPE.ADDON_VARIABLE,
                name = L["Debug"],
                tooltip = L["DebugTooltip"],
                key = "CooldownDone.debug",
                default = false,
            },
            {
                controlType = CONTROL_TYPE.EDITBOX,
                settingType = SETTING_TYPE.ADDON_VARIABLE,
                name = L["Ready"],
                tooltip = L["ReadyTooltip"],
                key = "CooldownDone.doneStr",
                default = L["Ready"],
                template = "CDDSettingsEditboxControlTemplate",
            },
            {
                controlType = CONTROL_TYPE.DROPDOWN,
                settingType = SETTING_TYPE.ADDON_VARIABLE,
                name = VOICE,
                tooltip = L["VoiceTooltip"],
                key = "CooldownDone.ttsVoiceID",
                default = voiceIDDefault,
                options = voiceIDOptions,
            },
            {
                controlType = CONTROL_TYPE.SLIDER,
                settingType = SETTING_TYPE.ADDON_VARIABLE,
                name = L["VoiceSpeed"],
                key = "CooldownDone.ttsRate",
                minValue = TEXTTOSPEECH_RATE_MIN,
                maxValue = TEXTTOSPEECH_RATE_MAX,
                step = 1,
                default = 0,
            },
            {
                controlType = CONTROL_TYPE.SLIDER,
                settingType = SETTING_TYPE.ADDON_VARIABLE,
                name = VOLUME,
                key = "CooldownDone.ttsVolume",
                minValue = TEXTTOSPEECH_VOLUME_MIN,
                maxValue = TEXTTOSPEECH_VOLUME_MAX,
                step = 1,
                default = 100,
            },
            {
                controlType = CONTROL_TYPE.BUTTON,
                name = L["Test"],
                buttonText = L["ClickToTest"],
                execute = function()
                    CooldownDone:speakTTS(L["SpellName"])
                end,
            },
        },
        subCategorys = {
            {
                name = CATEGORY_NAME_ABILITIES,
                database = CooldownDoneCharDB,
                settings = {
                    {
                        controlType = "CDD_LABEL",
                        name = L["AbilityListTip"],
                    },
                },
            },
            {
                name = CATEGORY_NAME_AURA,
                database = CooldownDoneCharDB,
                settings = {
                    {
                        controlType = "CDD_LABEL",
                        name = L["BuffListTip"],
                    },
                    {
                        controlType = "CDD_LABEL3",
                        name = L["BuffListTip2"],
                    },
                },
            }
        }
    }

    table.insert(settings.subCategorys[1].settings, {
        controlType = CONTROL_TYPE.SECTION_HEADER,
        name = L["SpellList"],
    })
    for _, spell in pairs(self.spellBookSpells) do
        local keyCheckbox = string.format("CooldownDone.spell.%s.enable", spell.id)
        local keyEditbox = string.format("CooldownDone.spell.%s.name", spell.id)
        local name = formatNameIdTexture(spell.name, spell.id, spell.texture)
        table.insert(settings.subCategorys[1].settings, {
            controlType = CONTROL_TYPE.CHECKBOX_AND_EDITBOX,
            settingType = SETTING_TYPE.ADDON_VARIABLE,
            name = name,
            tooltip = ENABLE .. "/" .. DISABLE,
            key = keyCheckbox,
            default = false,
            template = "CDDSettingsCheckboxEditboxControlTemplate",
            editbox = {
                controlType = CONTROL_TYPE.EDITBOX,
                settingType = SETTING_TYPE.ADDON_VARIABLE,
                name = name,
                tooltip = L["CustomName"],
                key = keyEditbox,
                default = "",
            },
        })
    end
    table.insert(settings.subCategorys[1].settings, {
        controlType = CONTROL_TYPE.SECTION_HEADER,
        name = L["EquippedItemList"],
    })
    for _, spell in pairs(self.equippedItemSpells) do
        local keyCheckbox = string.format("CooldownDone.spell.%s.enable", spell.id)
        local keyEditbox = string.format("CooldownDone.spell.%s.name", spell.id)
        local itemName = formatNameIdTexture(spell.itemName, spell.itemID, spell.itemTexture)
        local spellName = formatNameIdTexture(spell.name, spell.id, spell.texture)
        table.insert(settings.subCategorys[1].settings, {
            controlType = CONTROL_TYPE.CHECKBOX_AND_EDITBOX,
            settingType = SETTING_TYPE.ADDON_VARIABLE,
            name = itemName,
            tooltip = spellName .. "\n" .. ENABLE .. "/" .. DISABLE,
            key = keyCheckbox,
            default = false,
            template = "CDDSettingsCheckboxEditboxControlTemplate",
            editbox = {
                controlType = CONTROL_TYPE.EDITBOX,
                settingType = SETTING_TYPE.ADDON_VARIABLE,
                name = itemName,
                tooltip = spellName .. "\n" .. L["CustomName"],
                key = keyEditbox,
                default = "",
            },
        })
    end

    table.insert(settings.subCategorys[2].settings, {
        controlType = CONTROL_TYPE.SECTION_HEADER,
        name = CONTROL_AURA_EXPIRED,
    })
    table.insert(settings.subCategorys[2].settings, {
        controlType = "CDD_EDITBOX_AND_BUTTON",
        name = L["AddBuff"],
        tooltip = L["AddBuffTooltip"],
        button = {
            buttonText = ADD,
            OnButtonClick = function(control)
                self:addAura(control)
            end,
        },
    })
    for _, aura in pairs(self.auras) do
        local keyEditbox = string.format("CooldownDone.aura.%s.name", aura.id)
        local name = formatNameIdTexture(aura.name, aura.id, aura.texture)
        table.insert(settings.subCategorys[2].settings, {
            controlType = "CDD_EDITBOX_AND_BUTTON",
            settingType = SETTING_TYPE.ADDON_VARIABLE,
            name = name,
            key = keyEditbox,
            default = "",
            editboxTooltip = L["CustomName2"],
            OnEditboxValueChanged = function(...) self:getAuras() end,
            button = {
                buttonText = REMOVE,
                OnButtonClick = function(control)
                    self:removeAura(control)
                end,
            },
        })
    end
    table.insert(settings.subCategorys[2].settings, {
        controlType = CONTROL_TYPE.SECTION_HEADER,
        name = CONTROL_AURA_GAINED,
    })
    table.insert(settings.subCategorys[2].settings, {
        controlType = "CDD_EDITBOX_AND_BUTTON",
        name = L["AddBuff"],
        tooltip = L["AddBuffTooltip"],
        button = {
            buttonText = ADD,
            OnButtonClick = function(control)
                self:addAddedAura(control)
            end,
        },
    })
    for _, aura in pairs(self.addedAuras) do
        local keyEditbox = string.format("CooldownDone.addedaura.%s.name", aura.id)
        local name = formatNameIdTexture(aura.name, aura.id, aura.texture)
        table.insert(settings.subCategorys[2].settings, {
            controlType = "CDD_EDITBOX_AND_BUTTON",
            settingType = SETTING_TYPE.ADDON_VARIABLE,
            name = name,
            key = keyEditbox,
            default = "",
            editboxTooltip = L["CustomName2"],
            OnEditboxValueChanged = function(...) self:getAuras() end,
            button = {
                buttonText = REMOVE,
                OnButtonClick = function(control)
                    self:removeAddedAura(control)
                end,
            },
        })
    end

    CooldownDone.category, _ = LibBlzSettings:RegisterVerticalSettingsTable(ADDON_NAME, settings, CooldownDoneDB, true)

    _G.SLASH_COOLDOWNDONE1 = "/cdd";
    _G.SlashCmdList["COOLDOWNDONE"] = function()
        if InCombatLockdown() then
            print("|cffff0000" .. L["ERR_InCombatSettings"] .. "|r")
            return
        end
        Settings.OpenToCategory(CooldownDone.category:GetID())
    end
end
