U1RegisterAddon("StatDiminishing", {
    title = LOCALE_zhCN and "属性递减提示" or "屬性遞減提示",
    defaultEnable = 0,
    tags = { TAG_INTERFACE },
    icon = 135768,
    desc = LOCALE_zhCN and "在角色面板悬停属性时显示当前的递减档位与惩罚，覆盖全部7项副属性。" or "在角色屬性面板懸停屬性時顯示當前的遞減檔位與懲罰，覆蓋全部7項副屬性。",
    author = "heilongv",
    toggle = function(name, info, enable)
        if StatDiminishing_SetEnabled then StatDiminishing_SetEnabled(enable) end
    end,
})
