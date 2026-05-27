local _, EM = ...
local L = EM.L
local F = EM.funcs

local LRI = LibStub("LibRealmInfo")

-- function F:URLEncode(obj)
--     local currentIndex = 1
--     local charArray = {}
--     while currentIndex <= #obj do
--         local char = string.byte(obj, currentIndex)
--         charArray[currentIndex] = char
--         currentIndex = currentIndex + 1
--     end
--     local converchar = ""
--     for _, char in ipairs(charArray) do
--         converchar = converchar..string.format("%%%X", char)
--     end
--     return converchar
-- end

StaticPopupDialogs["ENHANCED_MENU_COPY_URL"] = {
    text = L["PRESS_TO_COPY"],
    button1 = CLOSE,
    whileDead = true,
    hideOnEscape = true,
    hasEditBox = true,
    editBoxWidth = 250,
    maxLetters = 0,
    EditBoxOnEscapePressed = function(self)
        self:GetParent():Hide()
    end,
    OnShow = function(self)
		local editBox = self.GetEditBox and self:GetEditBox() or self.editBox
		local text = self.GetTextFontString and self:GetTextFontString() or self.text
        editBox:SetText(text.text_arg2)
        editBox:HighlightText()
        editBox:SetScript("OnKeyDown", function(_, key)
            if key == "C" and IsControlKeyDown() then
                C_Timer.After(.1, function()
                    editBox:GetParent():Hide()
                    UIErrorsFrame:AddMessage(L["COPIED_TO_CLIP"])
                end)
            end
        end)
    end,
}

function F:ShowArmoryURL(characterName, realmName)
    local id, name, nameForAPI, rules, locale, battlegroup, region, timezone, connectedIDs, englishName, englishNameForAPI = LRI:GetRealmInfo(realmName)

    region = strlower(region)

    locale = strlower(strsub(locale, 1, 2).."-"..strsub(locale, 3, 4))
    realmName = string.gsub(englishName, "'", "")
    realmName = strlower(string.gsub(realmName, " ", "-"))

    local armory
    if LRI:GetCurrentRegion() == "CN" then
        armory = "https://wow.blizzard.cn/character/#/"..realmName.."/"..characterName
    else
        armory = "https://worldofwarcraft.com/"..locale.."/character/"..region.."/"..realmName.."/"..characterName
    end
    StaticPopup_Show("ENHANCED_MENU_COPY_URL", nil, armory)
end

function F:ShowWCLURL(characterName, realmName)
    local id, name, nameForAPI, rules, locale, battlegroup, region, timezone, connectedIDs, englishName, englishNameForAPI = LRI:GetRealmInfo(realmName)

    region = strlower(region)
    local wcl = "https://"..region..".warcraftlogs.com/character/"..region.."/"..realmName.."/"..characterName
    StaticPopup_Show("ENHANCED_MENU_COPY_URL", nil, wcl)
end

function F:ShowRaiderIO(characterName, realmName)
    local id, name, nameForAPI, rules, locale, battlegroup, region, timezone, connectedIDs, englishName, englishNameForAPI = LRI:GetRealmInfo(realmName)

    region = strlower(region)
    realmName = string.gsub(englishName, "'", "")
    realmName = strlower(string.gsub(realmName, " ", "-"))

    local rio = "https://raider.io/characters/"..region.."/"..realmName.."/"..characterName
    StaticPopup_Show("ENHANCED_MENU_COPY_URL", nil, rio)
end

function F:ShowName(characterName, realmName)
    local _, name, nameForAPI = LRI:GetRealmInfo(realmName)
    local fullName = characterName.."-"..nameForAPI

    if SendMailNameEditBox and SendMailNameEditBox:IsVisible() then
        SendMailNameEditBox:SetText(fullName)
        SendMailNameEditBox:HighlightText()
    else
        StaticPopup_Show("ENHANCED_MENU_COPY_URL", nil, fullName)
    end
end

-- ConfirmGuildInvitePopupDialog -- by q3fuba
StaticPopupDialogs["ENHANCED_MENU_CONFIRM_GUILD_INVITE"] = {
    text = "",
    button1 = YES,
    button2 = NO,
    OnAccept = function() end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
}
function F:ConfirmGuildInvite(characterName, realmName)
    local _, name, nameForAPI = LRI:GetRealmInfo(realmName)
    local fullName = characterName.."-"..nameForAPI

    StaticPopupDialogs["ENHANCED_MENU_CONFIRM_GUILD_INVITE"].text = CHAT_GUILD_INVITE_SEND .. "\n" .. fullName
    StaticPopupDialogs["ENHANCED_MENU_CONFIRM_GUILD_INVITE"].OnAccept = function() GuildInvite(fullName) end
    StaticPopup_Show("ENHANCED_MENU_CONFIRM_GUILD_INVITE")
end
