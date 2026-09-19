local ADDON_NAME = "ChatTimestampCopy"
local LINK_NAME = 'chattscopy'
local LINK_LEN = #LINK_NAME

local pcall, type, print = pcall, type, print
local strsub, strfind, strgsub = string.sub, string.find, string.gsub
local format = string.format
local GetCVar, SetCVar = GetCVar, SetCVar
local CreateFrame = CreateFrame
local wipe = wipe

local function IsSecretString(str)
    if type(str) ~= "string" then return false end
    return not pcall(function() str:gsub("", "") end)
end

local function GetDB()
    if not _G.LNuiChatDB then _G.LNuiChatDB = {} end
    if not _G.LNuiChatDB.global then _G.LNuiChatDB.global = {} end
    local globalDB = _G.LNuiChatDB.global
    if globalDB.timestampCopyEnabled == nil then globalDB.timestampCopyEnabled = true end
    return globalDB
end

local function MigrateOldSettings()
    if _G.ChatTimestampCopyDB and _G.ChatTimestampCopyDB.enabled ~= nil then
        _G.LNuiChatDB = _G.LNuiChatDB or {}
        _G.LNuiChatDB.global = _G.LNuiChatDB.global or {}
        local globalDB = _G.LNuiChatDB.global
        if globalDB.timestampCopyEnabled == nil then
            globalDB.timestampCopyEnabled = _G.ChatTimestampCopyDB.enabled
        end
    end
end

local cleanPatterns = {
    {pattern = "|H.-|h", replace = ""},
    {pattern = "|c%x%x%x%x%x%x%x%x", replace = ""},
    {pattern = "|[Hhr]", replace = ""},
    {pattern = "||", replace = "\124"},
    {pattern = "|T.-|t", replace = ""},
    {pattern = "|K.-|k", replace = "*"},
    {pattern = "|c%x%x%x%x%x%x%x%x|H(item:.-)|h.-|h%s-|r", func = function(link)
        local name = GetItemInfo(link)
        return name or "[物品]"
    end},
    {pattern = "|c(%x%x%x%x%x%x%x%x)|H(spell:.-)|h(.-)|h%s-|r", replace = "%3"},
    {pattern = "|c(%x%x%x%x%x%x%x%x)|H(achievement:.-)|h(.-)|h%s-|r", replace = "%3"},
    {pattern = "|c(%x%x%x%x%x%x%x%x)|H(quest:.-)|h(.-)|h%s-|r", replace = "%3"},
    {pattern = "|c(%x%x%x%x%x%x%x%x)|H(trade:.-)|h(.-)|h%s-|r", replace = "%3"},
    {pattern = "|c(%x%x%x%x%x%x%x%x)|H(battlepet:.-)|h(.-)|h%s-|r", replace = "%3"},
    {pattern = "|c(%x%x%x%x%x%x%x%x)|H(worldmap:.-)|h(.-)|h%s-|r", replace = "%3"},
    {pattern = "|c(%x%x%x%x%x%x%x%x)|H(pvptal:.-)|h(.-)|h%s-|r", replace = "%3"},
    {pattern = "|c(%x%x%x%x%x%x%x%x)|H(talent:.-)|h(.-)|h%s-|r", replace = "%3"},
    {pattern = "|c(%x%x%x%x%x%x%x%x)|H(clubTicket:.-)|h(.-)|h%s-|r", replace = "%3"},
    {pattern = "|c%x%x%x%x%x%x%x%x(.-)|r", replace = "%1"},
    {pattern = "|H.-|h(.-)|h", replace = "%1"},
    {pattern = "|U.-|u", replace = ""},
    {pattern = "|u", replace = ""},
}

local function CleanTextForCopy(text)
    if not text or text == "" then return text end
    if IsSecretString(text) then return "[Protected]" end

    local clean = text
    for i = 1, #cleanPatterns do
        local p = cleanPatterns[i]
        if p.func then
            clean = strgsub(clean, p.pattern, p.func)
        elseif p.replace then
            clean = strgsub(clean, p.pattern, p.replace)
        end
    end
    return clean
end

local function IsAllowedEnvironment()
    return not IsInInstance()
end

local function IsEnabled()
    return GetDB().timestampCopyEnabled ~= false
end

local function ChatEdit_Insert(text)
    if not text or text == "" then return end
    local editBox = ChatEdit_GetActiveWindow()
    if not editBox then
        ChatFrame_OpenChat(text)
    else
        editBox:Insert(text)
    end
end

local function newSetItemRef(link, text, button, ...)
    if not link or strsub(link, 1, LINK_LEN) ~= LINK_NAME then return end
    if not IsAllowedEnvironment() then return end
    local foci = GetMouseFoci and GetMouseFoci()
    local focus = foci and foci[1]
    if not focus or not focus.IsObjectType then return end
    if not focus:IsObjectType("FontString") then
        focus = focus:GetParent()
        if not focus or not focus.IsObjectType or not focus:IsObjectType("FontString") then return end
    end
    local tx = focus:GetText()
    if tx == nil or tx == "" then return end
    ChatEdit_Insert(CleanTextForCopy(tx))
    return true
end

hooksecurefunc("SetItemRef", newSetItemRef)

hooksecurefunc(ItemRefTooltip, "SetHyperlink", function(self, link)
    if link and strsub(link, 1, LINK_LEN) == LINK_NAME then self:Hide() end
end)

local isUpdatingTimestamp = false
local showTimestampsOld
local cvarCallbackRegistered = false

local function showTimestampsCvar()
    if isUpdatingTimestamp then return end

    local db = GetDB()
    if not db.timestampCopyEnabled then
        if showTimestampsOld ~= nil then
            isUpdatingTimestamp = true
            SetCVar("showTimestamps", showTimestampsOld)
            showTimestampsOld = nil
            isUpdatingTimestamp = false
        end
        return
    end

    local cvalue = GetCVar("showTimestamps")
    cvalue = CleanTextForCopy(cvalue)
    if cvalue == showTimestampsOld then return end
    showTimestampsOld = cvalue

    if cvalue == "none" then
        isUpdatingTimestamp = true
        SetCVar("showTimestamps", "none")
        isUpdatingTimestamp = false
        return
    end

    isUpdatingTimestamp = true
    SetCVar("showTimestamps", format("|cff959697|H%s:-1|h%s|h|r", LINK_NAME, cvalue))
    isUpdatingTimestamp = false
end

local function Initialize()
    MigrateOldSettings()
    if not IsEnabled() then return end
    local db = GetDB()
    if db.timestampCopyEnabled then
        showTimestampsCvar()
        if not cvarCallbackRegistered and CVarCallbackRegistry and CVarCallbackRegistry.RegisterCallback then
            CVarCallbackRegistry:RegisterCallback("showTimestamps", showTimestampsCvar)
            cvarCallbackRegistered = true
        end
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        Initialize()
        self:UnregisterEvent("PLAYER_LOGIN")
        self:SetScript("OnEvent", nil)
    end
end)

_G.ChatTimestampCopy = {
    Enable = function()
        local db = GetDB()
        db.timestampCopyEnabled = true
        Initialize()
    end,
    Disable = function()
        local db = GetDB()
        db.timestampCopyEnabled = false
        if showTimestampsOld ~= nil then
            isUpdatingTimestamp = true
            SetCVar("showTimestamps", showTimestampsOld)
            isUpdatingTimestamp = false
            showTimestampsOld = nil
        end
    end,
    IsEnabled = function()
        return IsEnabled()
    end,
    SetAutoEnableTimestamp = function(value)
        GetDB().autoEnableTimestamp = value
    end,
}
