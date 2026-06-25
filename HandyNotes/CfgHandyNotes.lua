U1RegisterAddon("HandyNotes", {
    title = LOCALE_zhCN and "地图标记" or "地圖標記",
    tags = { TAG_MAPQUEST },
    defaultEnable = 1,
    load = "LATER",
    optionsAfterLogin = 1,
    bundleSim = true,
    modifier = "Vincero@NGA汉化",
    icon = [[Interface\WorldMap\gravepicker-selected]],
    desc = LOCALE_zhCN and "一个小巧且全能的地图标记注释功能类插件。" or "一個小巧且全能的地圖標記註釋功能類插件。",
    nopic = 1,

    toggle = function(name, info, enable, justload)
        if justload then
            local function hook(overlayFrame)
                local plugins = {
                    "HandyNotes_WorldMapButton",
                    "HandyNotes_Dragonflight",
                }
                if not overlayFrame or not overlayFrame.InitializeDropDown then return end
                hooksecurefunc(overlayFrame, 'InitializeDropDown', function(self)
                    local function OnSelection(button)
                        self:OnSelection(button.value, button.checked);
                    end

                    UIDropDownMenu_AddSeparator();
                    local info = UIDropDownMenu_CreateInfo();

                    info.notCheckable = nil;
                    info.isNotRadio = true;
                    info.keepShownOnClick = true;
                    info.func = OnSelection;

                    info.text = LOCALE_zhCN and "显示HandyNotes宝箱稀有" or "顯示HandyNotes寶箱稀有";
                    info.value = "ShowHandyNotesRares";
                    local db = HandyNotes.db.profile
                    db.enabledPlugins = db.enabledPlugins or {}
                    info.checked = true
                    for _, k in pairs(plugins) do
                        if db.enabledPlugins[k] == false then
                            info.checked = false
                        end
                    end
                    UIDropDownMenu_AddButton(info);
                end)

                local origOverlayFrame_onSelection = overlayFrame.OnSelection;
                overlayFrame.OnSelection = function(self, value, checked)
                    if (value == "ShowHandyNotesRares") then
                        if IsModifierKeyDown() then
                            LibStub("AceConfigDialog-3.0"):Open("HandyNotes")
                            LibStub("AceConfigDialog-3.0"):SelectGroup("HandyNotes", "plugins")
                        end
                        local db = HandyNotes.db.profile
                        db.enabledPlugins = db.enabledPlugins or {}
                        for _, k in pairs(plugins) do
                            local old = db.enabledPlugins[k]
                            if old == nil then old = true end
                            db.enabledPlugins[k] = checked
                            if (checked and true or false) ~= old then
                                HandyNotes:UpdatePluginMap(nil, k)
                            end
                        end
                    end
                    origOverlayFrame_onSelection(self, value, checked)
                end
            end

            for _, overlayFrame in next, WorldMapFrame.overlayFrames do
                if(overlayFrame.Border and overlayFrame.Border:GetTexture() == 'Interface\\Minimap\\MiniMap-TrackingBorder') then
                    hook(overlayFrame)
                    break
                end
            end
        end
    end,

    {
        text = LOCALE_zhCN and "配置选项" or "配置選項",
        callback = function()
            LibStub("AceConfigDialog-3.0"):Open("HandyNotes")
            LibStub("AceConfigDialog-3.0"):SelectGroup("HandyNotes", "plugins")
        end
    },
    {
        text = LOCALE_zhCN and "重置数据" or "重置數據",
        reload = 1,
        callback = function()
            HandyNotesDB._mapData = nil
            U1Message(LOCALE_zhCN and "数据已重置，请重载界面" or "數據已重置，請重載界面")
        end
    }
});

U1RegisterAddon("HandyNotes_Midnight", {
    title = "01-至暗之夜",
    defaultEnable = 1,
    load = "LATER",
    desc = "至暗之夜",
})

U1RegisterAddon("HandyNotes_TheWarWithin", {
    title = "02-地心之战",
    defaultEnable = 0,
    load = "LATER",
    desc = "在11.0新地图上显示宝藏和稀有精英的位置, 数据量很大, 可能会造成卡顿, 请在需要时开启.",
    modifier = "Vincero@NGA汉化",
})

U1RegisterAddon("HandyNotes_Dragonflight", {
    title = "03-巨龙时代",
    defaultEnable = 0,
    ignoreLoadAll = 1,
    load = "LATER",
    desc = "在10.0新地图上显示宝藏和稀有精英的位置, 数据量很大, 可能会造成卡顿, 请在需要时开启.",
    modifier = "Vincero@NGA汉化",
})

U1RegisterAddon("HandyNotes_Shadowlands", {
    title = "04-暗影国度",
    defaultEnable = 0,
    ignoreLoadAll = 1,
    load = "LATER",
    desc = "在9.0新地图上显示宝藏和稀有精英的位置, 数据量很大, 可能会造成卡顿, 请在需要时开启.",
    modifier = "Vincero@NGA汉化",
})

U1RegisterAddon("HandyNotes_BattleForAzeroth", {
    title = "05-争霸艾泽拉斯",
    defaultEnable = 0,
    ignoreLoadAll = 1,
    load = "LATER",
    desc = "争霸艾泽拉斯宝箱",
    modifier = "Vincero@NGA汉化",
})

U1RegisterAddon("HandyNotes_Legion", {
    title = "06-军团再临",
    defaultEnable = 0,
    ignoreLoadAll = 1,
    load = "LATER",
    desc = "在军团再临地图上显示宝藏和稀有精英的位置, 数据量很大, 可能会造成卡顿, 请在需要时开启.",
    modifier = "Vincero@NGA汉化",
})

U1RegisterAddon("HandyNotes_WarlordsOfDraenor", {
    title = "07-德拉诺之王",
    defaultEnable = 0,
    ignoreLoadAll = 1,
    load = "LATER",
    desc = "在德拉诺之王地图上显示宝藏和稀有精英的位置, 数据量很大, 可能会造成卡顿, 请在需要时开启.",
    modifier = "Vincero@NGA汉化",
})

U1RegisterAddon("HandyNotes_MistsOfPandaria", {
    title = "08-熊猫人之谜",
    defaultEnable = 0,
    ignoreLoadAll = 1,
    load = "LATER",
    desc = "在潘达利亚地图上显示宝藏和稀有精英的位置, 数据量很大, 可能会造成卡顿, 请在需要时开启.",
    modifier = "Vincero@NGA汉化",
})

U1RegisterAddon("HandyNotes_Cataclysm", {
    title = "09-大地的裂变",
    defaultEnable = 0,
    ignoreLoadAll = 1,
    load = "LATER",
    desc = "大灾变宝箱",
    modifier = "Vincero@NGA汉化",
})

U1RegisterAddon("HandyNotes_WrathOfTheLichKing", {
    title = "10-巫妖王之怒",
    defaultEnable = 0,
    ignoreLoadAll = 1,
    load = "LATER",
    desc = "巫妖王之怒宝箱",
    modifier = "Vincero@NGA汉化",
})

U1RegisterAddon("HandyNotes_TheBurningCrusade", {
    title = "11-燃烧的远征",
    defaultEnable = 0,
    ignoreLoadAll = 1,
    load = "LATER",
    desc = "燃烧的远征宝箱",
    modifier = "Vincero@NGA汉化",
})

U1RegisterAddon("HandyNotes_WorldOfWarcraft", {
    title = "12-经典旧世",
    defaultEnable = 0,
    ignoreLoadAll = 1,
    load = "LATER",
    desc = "旧世界宝箱",
    modifier = "Vincero@NGA汉化",
})

U1RegisterAddon("HandyNotes_WorldMapButton", {
    title = "13-标记一键开关",
    defaultEnable = 1,
    load = "LATER",
    desc = "地图标记图标开关",
    modifier = "Vincero@NGA汉化",
})

U1RegisterAddon("HandyNotes_DungeonLocations", {
    title = "14-副本入口",
    defaultEnable = 1,
    load = "LATER",
    desc = "副本入口",
})

U1RegisterAddon("HandyNotes_MFF", {
    title = "15-火焰节",
    defaultEnable = 0,
    load = "LATER",
    desc = "仲夏火焰节活动",
})