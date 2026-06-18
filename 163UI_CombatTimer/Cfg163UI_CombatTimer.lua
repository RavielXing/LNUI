U1RegisterAddon("163UI_CombatTimer", {
    title = LOCALE_zhCN and "战斗计时" or "戰鬥計時",
    tags = { TAG_COMBATINFO },
    atlas = "Mobile-CombatIcon",
    desc = LOCALE_zhCN and "显示进入战斗和战斗结束的提示，同时显示当前战斗持续时间，更多功能还会逐渐完善。" or "顯示進入戰鬥和戰鬥結束的提示，同時顯示當前戰鬥持續時間，更多功能還會逐漸完善。",
    nopic = 1,
    author = "warbaby(爱不易)",
    defaultEnable = 1,

    frames = {"U1CT"},

    toggle = function(name, info, enable, justload)
        if enable then
            U1CT:RegisterEvent("PLAYER_REGEN_DISABLED")
            U1CT:RegisterEvent("PLAYER_REGEN_ENABLED")
            U1CT:RegisterEvent("ENCOUNTER_START")
            U1CT:RegisterEvent("ENCOUNTER_END")
            CoreUIShowOrHide(U1CT, U1GetCfgValue(name, "timer"))
        else
            U1CT:UnregisterAllEvents()
            U1CT:Hide()
        end
    end,

    {
        text = LOCALE_zhCN and "提示文字位置" or "提示文字位置",
        var = "yoffset",
        type = "spin",
        range = { -500, 500, 50 },
        default = 200,
        callback = function(cfg, v, loading)
            if CombatTimerEnterBanner then
                CombatTimerEnterBanner:SetPoint("CENTER", 0, v)
            end
            if CombatTimerLeaveBanner then
                CombatTimerLeaveBanner:SetPoint("CENTER", 0, v)
            end
            if loading then return end
            if U1CT_PlayBanner then
                U1CT_PlayBanner(true)
            end
        end
    },
    {
        text = LOCALE_zhCN and "提示文字停留时间" or "提示文字停留時間",
        var = "duration",
        type = "spin",
        range = { 0.5, 2.5, 0.1 },
        default = 1.5,
        callback = function(cfg, v, loading)
            if CombatTimerEnterBanner and CombatTimerEnterBanner.Anim then
                local anim = CombatTimerEnterBanner.Anim
                if anim.BG1Alpha then anim.BG1Alpha:SetStartDelay(v) end
                if anim.TitleAlpha then anim.TitleAlpha:SetStartDelay(v) end
                if anim.BLAlpha then anim.BLAlpha:SetStartDelay(v) end
                if anim.IconAlpha then anim.IconAlpha:SetStartDelay(v) end
                if anim.BG1Scale then anim.BG1Scale:SetStartDelay(v) end
                if anim.TitleScale then anim.TitleScale:SetStartDelay(v) end
                if anim.BLScale then anim.BLScale:SetStartDelay(v) end
                if anim.IconScale then anim.IconScale:SetStartDelay(v) end
                if anim.BG1Translation then anim.BG1Translation:SetStartDelay(v) end
                if anim.TitleTranslation then anim.TitleTranslation:SetStartDelay(v) end
                if anim.BonusLabelTranslation then anim.BonusLabelTranslation:SetStartDelay(v) end
                if anim.IconTranslation then anim.IconTranslation:SetStartDelay(v) end
                if anim.LeftFactionAlpha then anim.LeftFactionAlpha:SetStartDelay(v) end
                if anim.LeftFactionScale then anim.LeftFactionScale:SetStartDelay(v) end
                if anim.LeftFactionTranslation then anim.LeftFactionTranslation:SetStartDelay(v) end
                if anim.RightFactionAlpha then anim.RightFactionAlpha:SetStartDelay(v) end
                if anim.RightFactionScale then anim.RightFactionScale:SetStartDelay(v) end
                if anim.RightFactionTranslation then anim.RightFactionTranslation:SetStartDelay(v) end
            end

            if CombatTimerLeaveBanner and CombatTimerLeaveBanner.Anim then
                local anim = CombatTimerLeaveBanner.Anim
                if anim.BG1Alpha then anim.BG1Alpha:SetStartDelay(v) end
                if anim.TitleAlpha then anim.TitleAlpha:SetStartDelay(v) end
                if anim.BG1Scale then anim.BG1Scale:SetStartDelay(v) end
                if anim.TitleScale then anim.TitleScale:SetStartDelay(v) end
                if anim.BG1Translation then anim.BG1Translation:SetStartDelay(v) end
                if anim.TitleTranslation then anim.TitleTranslation:SetStartDelay(v) end
                if anim.LeftFactionAlpha then anim.LeftFactionAlpha:SetStartDelay(v) end
                if anim.LeftFactionScale then anim.LeftFactionScale:SetStartDelay(v) end
                if anim.LeftFactionTranslation then anim.LeftFactionTranslation:SetStartDelay(v) end
                if anim.RightFactionAlpha then anim.RightFactionAlpha:SetStartDelay(v) end
                if anim.RightFactionScale then anim.RightFactionScale:SetStartDelay(v) end
                if anim.RightFactionTranslation then anim.RightFactionTranslation:SetStartDelay(v) end
            end

            if loading then return end
            if U1CT_PlayBanner then
                U1CT_PlayBanner(true)
            end
        end
    },
    {
        text = LOCALE_zhCN and "进入战斗提示" or "進入戰鬥提示",
        var = "enter_anim",
        default = true,
        callback = function(cfg, v, loading) 
            if not v or loading then return end 
            if U1CT_PlayBanner then
                U1CT_PlayBanner(true) 
            end
        end,
        {
            type = "input",
            text = LOCALE_zhCN and "主要文字" or "主要文字",
            var = "title",
            default = LOCALE_zhCN and "进入战斗" or "進入戰鬥",
        },
        {
            type = "spin",
            text = LOCALE_zhCN and "主要文字大小" or "主要文字大小",
            var = "title_font_size",
            range = { 12, 36, 1 },
            default = 22,
            callback = function(cfg, v, loading)
                if CombatTimerEnterBanner and CombatTimerEnterBanner.Title then
                    local font = CombatTimerEnterBanner.Title:GetFont()
                    if font then
                        CombatTimerEnterBanner.Title:SetFont(font, v)
                    end
                end
                if CombatTimerEnterBanner and CombatTimerEnterBanner.TitleFlash then
                    local font = CombatTimerEnterBanner.TitleFlash:GetFont()
                    if font then
                        CombatTimerEnterBanner.TitleFlash:SetFont(font, v)
                    end
                end
                if not loading and U1CT_PlayBanner then
                    U1CT_PlayBanner(true)
                end
            end
        },
        {
            type = "input",
            text = LOCALE_zhCN and "次要文字" or "次要文字",
            var = "label",
            default = LOCALE_zhCN and "战斗计时" or "戰鬥計時",
        },
        {
            type = "spin",
            text = LOCALE_zhCN and "次要文字大小" or "次要文字大小",
            var = "label_font_size",
            range = { 10, 24, 1 },
            default = 14,
            callback = function(cfg, v, loading)
                if CombatTimerEnterBanner and CombatTimerEnterBanner.BonusLabel then
                    local font = CombatTimerEnterBanner.BonusLabel:GetFont()
                    if font then
                        CombatTimerEnterBanner.BonusLabel:SetFont(font, v)
                    end
                end
                if not loading and U1CT_PlayBanner then
                    U1CT_PlayBanner(true)
                end
            end
        },
    },

    {
        text = LOCALE_zhCN and "进入战斗音效" or "進入戰鬥音效",
        var = "enter_sound",
        default = true,
        callback = function(cfg, v, loading) 
            if not v or loading then return end 
            if U1CT_PlaySound then
                U1CT_PlaySound(true) 
            end
        end,

        {
            text = LOCALE_zhCN and "音效选择" or "音效選擇",
            var = "ogg",
            type = "drop",
            options = {
                LOCALE_zhCN and "女声开火" or "女聲開火", 9633,
                LOCALE_zhCN and "哐" or "哐", 17317,
                LOCALE_zhCN and "嘭" or "嘭", 962,
                LOCALE_zhCN and "咯噔" or "咯噔", "Interface/AddOns/163UI_CombatTimer/interface_ui_70_artifact_forge_colorchange_03.ogg",
            },
            default = "Interface/AddOns/163UI_CombatTimer/interface_ui_70_artifact_forge_colorchange_03.ogg",
            callback = function(cfg, v, loading) 
                if not v or loading then return end 
                if U1CT_PlaySound then
                    U1CT_PlaySound(true) 
                end
            end,
        }
    },

    {
        text = LOCALE_zhCN and "离开战斗提示" or "離開戰鬥提示",
        var = "leave_anim",
        default = true,
        callback = function(cfg, v, loading) 
            if not v or loading then return end 
            if U1CT_PlayBanner then
                U1CT_PlayBanner(false) 
            end
        end,
        {
            type = "input",
            text = LOCALE_zhCN and "提示文字" or "提示文字",
            var = "title",
            default = LOCALE_zhCN and "离开战斗" or "離開戰鬥",
        },
        {
            type = "spin",
            text = LOCALE_zhCN and "文字大小" or "文字大小",
            var = "leave_font_size",
            range = { 12, 36, 1 },
            default = 22,
            callback = function(cfg, v, loading)
                if CombatTimerLeaveBanner and CombatTimerLeaveBanner.Title then
                    local font = CombatTimerLeaveBanner.Title:GetFont()
                    if font then
                        CombatTimerLeaveBanner.Title:SetFont(font, v)
                    end
                end
                if CombatTimerLeaveBanner and CombatTimerLeaveBanner.TitleFlash then
                    local font = CombatTimerLeaveBanner.TitleFlash:GetFont()
                    if font then
                        CombatTimerLeaveBanner.TitleFlash:SetFont(font, v)
                    end
                end
                if not loading and U1CT_PlayBanner then
                    U1CT_PlayBanner(false)
                end
            end
        }
    },

    {
        text = LOCALE_zhCN and "离开战斗音效" or "離開戰鬥音效",
        var = "leave_sound",
        default = false,
        callback = function(cfg, v, loading) 
            if not v or loading then return end 
            if U1CT_PlaySound then
                U1CT_PlaySound(false) 
            end
        end,
    },

    {
        text = LOCALE_zhCN and "启用计时器" or "啟用計時器",
        var = "timer",
        default = true,
        callback = function(cfg, v, loading)
            CoreUIShowOrHide(U1CT, v)
        end,

        {
            text = LOCALE_zhCN and "计时数字字体" or "計時數字字體",
            var = "timer_font",
            type = "drop",
            default = ChatFontNormal:GetFont() or "Fonts\\FRIZQT__.ttf",
            options = CtlSharedMediaOptions("font"),
            callback = function(cfg, v, loading)
                local font, size, outline = U1CT.text:GetFont()
                -- 12.0兼容：确保size有效
                if not size or size <= 0 then size = 19 end
                if not outline then outline = "" end
                U1CT.text:SetFont(v, size, outline)
                if not loading and not InCombatLockdown() then
                    if U1CT_StartTimer then
                        U1CT_StartTimer(true)
                        CoreScheduleBucket("U1CT_CFG_STOP", 5.0, U1CT_StartTimer, false)
                    end
                end
            end,
        },
    },

	{
        text = LOCALE_zhCN and "显示职业图标" or "顯示職業圖標",
        var = "show_class_icon",
        default = true,
        callback = function(cfg, v, loading)
            if U1CT_SetFactionTexture then
                U1CT_SetFactionTexture()
            end
            if loading then return end
            if U1CT_PlayBanner then
                U1CT_PlayBanner(true)
            end
		end,
    },
})
