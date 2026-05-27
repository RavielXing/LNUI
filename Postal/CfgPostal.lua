U1RegisterAddon("Postal", {
    title = LOCALE_zhCN and "邮件增强" or "郵件增強",
    defaultEnable = 1,
    tags = { TAG_MANAGEMENT },
    icon = [[Interface\Icons\INV_Letter_06]],
    desc = LOCALE_zhCN and "强化邮箱面板功能，支持批量收取全部邮件、计算所有邮件的金币收入总和、自动填写收件人等等功能。``在邮箱面板的右上角有设置菜单。" or "強化郵箱面板功能，支持批量收取全部郵件、計算所有郵件的金幣收入總和、自動填寫收件人等等功能。``在郵箱面板的右上角有設置菜單。",

    {
        text = LOCALE_zhCN and "配置选项" or "配置選項",
        callback = function(cfg, v, loading)
            if Postal_DropDownMenu.initialize ~= Postal.Menu then
                CloseDropDownMenus()
                Postal_DropDownMenu.initialize = Postal.Menu
            end
            ToggleDropDownMenu(1, nil, Postal_DropDownMenu, Minimap:GetName(), 0, 0)
        end,
    },
    --]]
});
