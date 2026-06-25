U1RegisterAddon("Rematch", {
    title = "宠物战队",
    defaultEnable = 0,
    load = "NORMAL",
    tags = { TAG_INTERFACE },
    icon = [[Interface\AddOns\Rematch\textures\icon]],
    desc = "可以记录跟每个宠物对战NPC对打所用的宠物组合并一键切换，规划宠物的升级顺序等",

-- 手动勾选启用插件，重载插件按钮闪烁
    runAfterLoad = function(info, name)
        if U1IsAddonEnabled(name) then
            if not U1DB.RematchLastEnableState then
                U1ChangeReloadList("Rematch", false, 0, 1)
                if UUI and UUI.ReloadFlashRefresh then
                    UUI.ReloadFlashRefresh()
                end
                U1DB.RematchLastEnableState = true
            end
        end
    end,

    toggle = function(name, info, enable, justload)
        if not justload then
            if enable then
                U1ChangeReloadList("Rematch", false, 0, 1)
                if UUI and UUI.ReloadFlashRefresh then
                    UUI.ReloadFlashRefresh()
                end
                U1DB.RematchLastEnableState = true
            else
                U1DB.RematchLastEnableState = false
            end
        end
    end,
-- 手动勾选启用插件，重载插件按钮闪烁

    {
        lower = true,
        text = "打开界面",
        callback = function()
            SlashCmdList["REMATCH"]("")
        end
    },

    {
        type = "text",
        text = "|cffFF2D2D勾选启用插件后，请“重载界面”。|r",       
    },
});