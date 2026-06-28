-- ============================================================
-- 同步设置暴雪自带冷却管理器启用状态
-- 放在 U1RegisterAddon 外面，避免污染配置表
-- ============================================================
local function SetBlizzardCDM(enabled)
    local value = enabled and "1" or "0"
    local ok = pcall(function()
        C_CVar.SetCVar("cooldownViewerEnabled", value)
    end)
    if not ok then
        pcall(function()
            SetCVar("cooldownViewerEnabled", value)
        end)
    end
end

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
            -- ============================================================
            -- Coolinator 加载后，确保暴雪自带冷却管理器已启用
            -- 处理玩家手动在游戏设置里关闭 CDM 的情况
            -- ============================================================
            local currentCDM = C_CVar.GetCVar("cooldownViewerEnabled")
            if currentCDM ~= "1" then
                SetBlizzardCDM(true)
            end

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
                -- ============================================================
                -- 勾选启用 Coolinator 时，同步启用暴雪自带冷却管理器
                -- 设置 CVar，重载后生效
                -- ============================================================
                SetBlizzardCDM(true)

                U1ChangeReloadList("Coolinator", false, 0, 1)
                if UUI and UUI.ReloadFlashRefresh then
                    UUI.ReloadFlashRefresh()
                end
                U1DB.CoolinatorLastEnableState = true
            else
                -- ============================================================
                -- 取消勾选禁用 Coolinator 时，同步禁用暴雪自带冷却管理器
                -- 设置 CVar，重载后生效
                -- ============================================================
                SetBlizzardCDM(false)

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
        text = '|cffFF2D2D勾选启用插件后，请"重载界面"。|r',
    },
})