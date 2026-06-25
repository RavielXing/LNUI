U1RegisterAddon("Coolinator", {
    title = LOCALE_zhCN and "冷却管理器" or "冷卻管理器",
    defaultEnable = 0,
    load = "NORMAL",
    tags = { TAG_COMBATINFO },
    icon = [[Interface\AddOns\Coolinator\Assets\logo.tga]],
    desc = LOCALE_zhCN and "多功能源生血条增强插件。" or "多功能源生血條增強插件。",

-- 手动勾选启用插件，重载插件按钮闪烁
    runAfterLoad = function(info, name)
        if U1IsAddonEnabled(name) then
            if not U1DB.CoolinatorLastEnableState then
                U1ChangeReloadList("Coolinator", false, 0, 1)
                if UUI and UUI.ReloadFlashRefresh then
                    UUI.ReloadFlashRefresh()
                end
                U1DB.CoolinatorLastEnableState = true
            end
        end
    end,

    toggle = function(name, info, enable, justload)
        if not justload then
            if enable then
                U1ChangeReloadList("Coolinator", false, 0, 1)
                if UUI and UUI.ReloadFlashRefresh then
                    UUI.ReloadFlashRefresh()
                end
                U1DB.CoolinatorLastEnableState = true
            else
                U1DB.CoolinatorLastEnableState = false
            end
        end
    end,
-- 手动勾选启用插件，重载插件按钮闪烁

    {
        type = "button",
        text = LOCALE_zhCN and "配置选项" or "配置選項",
        callback = function(cfg, v, loading)
            Settings.OpenToCategory(U1GetSettingCategoryIDByName("Coolinator"))
        end
    },

    {
        type = "button",
        text = LOCALE_zhCN and "进入/关闭编辑模式" or "進入/關閉編輯模式",
        callback = function(cfg, v, loading)
            local cmd = "/cooli d"
            local editBox = ChatEdit_GetLastActiveWindow()
            if not editBox then
                ChatFrame_OpenChat(cmd)
                editBox = ChatEdit_GetLastActiveWindow()
            end
            if editBox then
                editBox:SetText(cmd)
                ChatEdit_SendText(editBox)
            end
        end
    },

    {
        type = "text",
        text = "|cffFF2D2D勾选启用插件后，请“重载界面”。|r",
    },
})