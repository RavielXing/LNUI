U1EnableAddOn("!!!Libs") C_AddOns.LoadAddOn("!!!Libs") --不能在CoreLibs之前，不能在163UIUI之后。之后根据有没有软件用库来决定是否加载

--TODO aby8
GuildControlUIRankSettingsFrameRosterLabel = GuildControlUIRankSettingsFrameRosterLabel or CreateFrame("Frame")

---LibSharedMedia Options, { type = "drop", options = CtlSharedMediaOptions("statusbar"), }
local optionsFuncs, optionsLists;
function CtlSharedMediaOptions(type)
    optionsFuncs = optionsFuncs or {};
    optionsLists = optionsLists or {};
    local func = optionsFuncs[type]
    if not func then
        func = function()
            local LSM = LibStub and LibStub('LibSharedMedia-3.0', true);
            local list = optionsLists[type];
            if not list then list = {} optionsLists[type] = list; end
            table.wipe(list);
            if LSM then
                for _, v in ipairs(LSM:List(type)) do
                    table.insert(list, v)
                    table.insert(list, LSM:Fetch(type, v))
                end
            end
            return list;
        end
        optionsFuncs[type] = func;
    end
    return func;
end

--按ESC时, AceConfigDialog先关闭, 并阻止界面窗口和爱不易关闭
hooksecurefunc("StaticPopup_EscapePressed", function()
    if LibStub("AceConfigDialog-3.0"):CloseAll() then
        GameMenuFrame:Show()
    end
end)
