local ADDON_NAME, TeleportAnnouncer = ...

local L = TeleportAnnouncer.Locale

function TeleportAnnouncer:prepareDBAndSettings()
    TeleportAnnouncerDB = (type(TeleportAnnouncerDB) == "table" and TeleportAnnouncerDB) or {}

    local LibBlzSettings = LibStub("LibBlzSettings-1.0")
    local CONTROL_TYPE = LibBlzSettings.CONTROL_TYPE
    local SETTING_TYPE = LibBlzSettings.SETTING_TYPE
    local settings = {
        name = L["addonName"],
        settings = {
            {
                controlType = CONTROL_TYPE.DROPDOWN,
                settingType = SETTING_TYPE.ADDON_VARIABLE,
                name = L["AnnounceTimingName"],
                tooltip = L["AnnounceTimingTooltip"],
                key = "AnnounceTiming",
                default = 1,
                options = {
                    {L["AnnounceTimingO1Name"], L["AnnounceTimingO1Tooltip"]},
                    {L["AnnounceTimingO2Name"], L["AnnounceTimingO2Tooltip"]},
                }
            },
            {
                controlType = CONTROL_TYPE.DROPDOWN,
                settingType = SETTING_TYPE.ADDON_VARIABLE,
                name = L["AnnounceChannelName"],
                tooltip = L["AnnounceChannelTooltip"],
                key = "AnnounceChannel",
                default = 1,
                options = {
                    {L["AnnounceChannelO1Name"], L["AnnounceChannelO1Tooltip"]},
                    {L["AnnounceChannelO2Name"], L["AnnounceChannelO2Tooltip"]},
                }
            },
            {
                controlType = CONTROL_TYPE.CHECKBOX,
                settingType = SETTING_TYPE.ADDON_VARIABLE,
                name = L["DoNotShowItemName"],
                tooltip = L["DoNotShowItemTooltip"],
                key = "DoNotShowItem",
                default = false
            },
            {
                controlType = CONTROL_TYPE.CHECKBOX,
                settingType = SETTING_TYPE.ADDON_VARIABLE,
                name = L["AnnouncePortalName"],
                tooltip = L["AnnouncePortalTooltip"],
                key = "AnnouncePortal",
                default = true
            },
            {
                controlType = CONTROL_TYPE.CHECKBOX,
                settingType = SETTING_TYPE.ADDON_VARIABLE,
                name = L["OnlyKeystoneName"],
                tooltip = L["OnlyKeystoneTooltip"],
                key = "OnlyKeystone",
                default = true--lnui
            },
            {
                controlType = CONTROL_TYPE.CHECKBOX,
                settingType = SETTING_TYPE.ADDON_VARIABLE,
                name = L["IgnoreHeartstoneName"],
                tooltip = L["IgnoreHeartstoneTooltip"],
                key = "IgnoreHeartstone",
                default = false
            },
        }
    }
    local category, _ = LibBlzSettings:RegisterVerticalSettingsTable(ADDON_NAME, settings, TeleportAnnouncerDB, true)

    _G.SLASH_TELEPORTANNOUNCER1 = "/ta";
    _G.SlashCmdList["TELEPORTANNOUNCER"] = function()
        Settings.OpenToCategory(category:GetID())
    end
end

