U1RegisterAddon("Rematch", {
    title = "宠物战队",
    defaultEnable = 0,
    load = "NORMAL",
    tags = { TAG_INTERFACE },
    icon = [[Interface\AddOns\Rematch\textures\icon]],
    desc = "可以记录跟每个宠物对战NPC对打所用的宠物组合并一键切换，规划宠物的升级顺序等",

    toggle = function(name, info, enable, justload)
        return true
    end,

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