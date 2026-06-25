U1RegisterAddon("Masque", {
    title = "按钮美化",
    defaultEnable = 0,
    minimap = "LibDBIcon10_Masque",
    load = "NORMAL", --支持其他第三方插件

    tags = { TAG_INTERFACE },
    icon = [[Interface\AddOns\Masque\Textures\Icon]],
    desc = "为动作条按钮提供样式切换，拥有众多的皮肤类扩展，是此类美化插件的第一选择。`在原版的基础上整合了玩家增益美化，并精选了几种有代表性的皮肤样式，可以用控制台轻松选择。当然，您也可以下载任意皮肤包放到插件目录里，对此提供良好的兼容。",

-- 手动勾选启用插件，重载插件按钮闪烁
    runAfterLoad = function(info, name)
        if U1IsAddonEnabled(name) then
            if not U1DB.MasqueLastEnableState then
                U1ChangeReloadList("Masque", false, 0, 1)
                if UUI and UUI.ReloadFlashRefresh then
                    UUI.ReloadFlashRefresh()
                end
                U1DB.MasqueLastEnableState = true
            end
        end
    end,

    toggle = function(name, info, enable, justload)
        if not justload then
            if enable then
                U1ChangeReloadList("Masque", false, 0, 1)
                if UUI and UUI.ReloadFlashRefresh then
                    UUI.ReloadFlashRefresh()
                end
                U1DB.MasqueLastEnableState = true
            else
                U1DB.MasqueLastEnableState = false
            end
        end
    end,
-- 手动勾选启用插件，重载插件按钮闪烁

    {
        type = "text",
        text = "|cffFF2D2D勾选启用插件后，请“重载界面”。|r",       
    },

    {
        text = "配置选项",
        callback = function() SlashCmdList["MASQUE"]() end,
    },
    {
        text = "重置皮肤",
        confirm = "会把所有皮肤的设置（比如颜色，光泽等）恢复到默认值，您确定吗？",
        callback = function() getGlobal():__Reset() end,
    },
    {
        text = "设置动作条布局",
        tip = "说明`打开多米诺动作条的设置面板。",
        callback = function() UUI.OpenToAddon("Dominos") end,

    },

    -- {
        -- text = "隐藏主动作条两侧材质",
        -- var = "hidecap",
        -- default = false,
        -- callback = function(cfg, v, loading)
            -- RunOnNextFrame(function()
                -- CoreUIShowOrHide(MainActionBar.EndCaps, not v)
            -- end)
        -- end
    -- },
    -- {
        -- text = "隐藏主动作条背景材质",
        -- var = "hidebg",
        -- default = false,
        -- callback = function(cfg, v, loading)
            -- RunOnNextFrame(function()
                -- CoreUIShowOrHide(MainActionBar.Background, not v)
                -- CoreUIShowOrHide(MainActionBar.BorderArt, not v)
                -- for i=1, 11 do CoreUIShowOrHide(_G["ActionButton"..i].RightDivider, not v) end
            -- end)
        -- end
	-- },

    {
        text = "隐藏经验声望条",
        var = "hiderepexp",
        default = false,
        callback = function(cfg, v, loading)
            CoreUIShowOrHide(StatusTrackingBarManager, not v and not IsAddOnLoaded("Dominos"));
        end
    },
    {
        text = "隐藏地区按钮和额外按钮材质",
        var = "hidezoneabil",
        default = false,
        callback = function(cfg, v, loading)
            CoreUIShowOrHide(ZoneAbilityFrame.Style, not v)
            CoreUIShowOrHide(ExtraActionButton1.style, not v)
        end
    }
 });

--皮肤必须是load=NORMAL的，否则在启用设置之前，Skin还没有加载上
U1RegisterAddon("Masque_Cainyx", { load = "NORMAL", protected = 1, hide = 1, });
U1RegisterAddon("Masque_CleanUI", { load = "NORMAL", protected = 1, hide = 1, });
U1RegisterAddon("Masque_Goldpaw", { load = "NORMAL", protected = 1, hide = 1, });
U1RegisterAddon("Masque_Kenzo", { load = "NORMAL", protected = 1, hide = 1, });
U1RegisterAddon("Masque_Parabole", { load = "NORMAL", protected = 1, hide = 1, });
U1RegisterAddon("Masque_Shadow", { load = "NORMAL", protected = 1, hide = 1, });

--支持暴雪默认动作条
CoreDependCall("Masque", function()
    CoreLeaveCombatCall("cfgmasque_blizz", nil, function()
        local Masque, GroupName = LibStub('Masque'), '暴雪动作条按钮'
        local AddButtonToGroup = function(btnname, index, subgroup, func)
            local Group = Masque:Group(GroupName, subgroup)
            for i = 1, index do
                local btn = _G[format(btnname, i)]
                if(btn) then
                    Group:AddButton(btn)
                    if(func) then pcall(func, btn) end
                end
            end
        end
        local AddButtonToGroupForPool = function(group, pool)
            CoreUIHookPool(pool, function(obj)
                group:AddButton(obj)
            end)
        end

        local group = '主动作条'
        AddButtonToGroup('ActionButton%d', NUM_ACTIONBAR_BUTTONS, group, function(btn)
            if not InCombatLockdown() then btn:SetFrameStrata'HIGH' end
        end)

        AddButtonToGroup('PetActionButton%d', PetActionBar.numButtons, '宠物动作条')
        AddButtonToGroup('MultiBarLeftButton%d', MultiBarLeft.numButtons, '右侧动作条1')
        AddButtonToGroup('MultiBarRightButton%d', MultiBarRight.numButtons, '右侧动作条2')
        AddButtonToGroup('MultiBarBottomLeftButton%d', MultiBarBottomLeft.numButtons, '左下动作条')
        AddButtonToGroup('MultiBarBottomRightButton%d', MultiBarBottomRight.numButtons, '右下动作条')
        for i = 5, 7 do
            AddButtonToGroup('MultiBar' .. i .. 'Button%d', _G['MultiBar'..i].numButtons, '动作条' .. (i+1))
        end
        AddButtonToGroup('PossessButton%d', PossessActionBar.numButtons, '控制动作条')
        AddButtonToGroup('StanceButton%d', StanceBar.numButtons, '姿态动作条')

    end)
end)


