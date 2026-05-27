local hideNameplateDebuff

local L = U1.L

local function untex(text)
    return text and text:gsub("\124T.*\124t", "")
end

U1RegisterAddon("163UI_MoreOptions", {
    title = LOCALE_zhCN and "额外设置" or "額外設置",
    tags = { TAG_MANAGEMENT },
    icon = [[Interface\Icons\Achievement_BG_overcome500disadvantage]],
    desc = LOCALE_zhCN and "额外设置" or "額外設置",
    nopic = 1,
    protected = 1,
    author = "warbaby(爱不易)",
    defaultEnable = 1,

    U1CfgMakeCVarOption(LOCALE_zhCN and U1_NEW_ICON.."简易原汁原味" or U1_NEW_ICON.."簡易原汁原味", "overrideArchive", 1, {
        tip = LOCALE_zhCN and "说明`通过设置变量达到简易反和谐的目的，没有任何风险。可以和谐大部分模型，比如坟包会替换成白骨，技能图标似乎不会变化。``\n如果开启后卡蓝条或无法进入游戏，请删除WTF\\Config.wtf``|cffff0000设置后必须重启游戏才能生效。|r" or "說明`通過設置變量達到簡易反和諧的目的，沒有任何風險。可以和諧大部分模型，比如墳包會替換成白骨，技能圖標似乎不會變化。``\n如果開啟後卡藍條或無法進入遊戲，請刪除WTF\\Config.wtf``|cffff0000設置後必須重啟遊戲才能生效。|r",
        confirm = LOCALE_zhCN and "注意：如果开启后|cffff7777无法进入游戏|r，请删除WTF\\Config.wtf文件即可恢复（或只移除其中的overrideArchive条目）\n\n请确认，然后关闭游戏重新进入。" or "註意：如果開啟後|cffff7777無法進入遊戲|r，請刪除WTF\\Config.wtf文件即可恢復（或只移除其中的overrideArchive條目）\n\n請確認，然後關閉遊戲重新進入。",
        getvalue = function() return not GetCVarBool("overrideArchive") end,
        callback = function(cfg, v, loading) SetCVar("overrideArchive", v and "0" or "1") end,
    }),

    { text = LOCALE_zhCN and "伤害数字大小" or "傷害數字大小", tip = LOCALE_zhCN and "说明`数字越大，字体越大" or "說明`數字越大，字體越大",  var = "WorldTextScale_v2", type = "spin", range = {1, 4, 0.5}, default = 1, callback = function(cfg, v, loading) SetCVar("WorldTextScale_v2", v or 1.0) end, },

    { text = LOCALE_zhCN and "伤害数字跳跃范围" or "傷害數字跳躍範圍", tip = LOCALE_zhCN and "说明`数字越大，跳跃越快、范围越大" or "說明`數字越大，跳躍越快、範圍越大", var = "floatingCombatTextCombatDamage_v2DirectionalScale", type = "spin", range = {0, 5}, default = 1, callback = function(cfg, v, loading) SetCVar("floatingCombatTextCombatDamage_v2DirectionalScale", v or 1.0) end, },

    U1CfgMakeCVarOption(LOCALE_zhCN and "伤害数字千分符" or "傷害數字千分符", "breakUpLargeNumbers_v2", 1, {
        tip = LOCALE_zhCN and "说明`是否伤害数字显示千分符" or "說明`是否傷害數字顯示千分符",
        reload = 1,
    }),

    U1CfgMakeCVarOption(LOCALE_zhCN and "鼠标观察速度" or "鼠標觀察速度", "rawMouseEnable", 1, {
        tip = LOCALE_zhCN and "说明`鼠标自动帮你重置到屏幕中心" or "說明`鼠標自動幫你重置到屏幕中心",
        reload = 1,
    }),

    U1CfgMakeCVarOption(LOCALE_zhCN and "是否全屏幕泛光" or "是否全屏幕泛光", "ffxGlow", 1, {
        tip = LOCALE_zhCN and "说明`打钩为开启全屏泛光，不打钩为关闭" or "說明`打鉤為開啟全屏泛光，不打鉤為關閉",
        reload = 1,
    }),

    U1CfgMakeCVarOption(LOCALE_zhCN and "24小时制" or "24小時制", "timeMgrUseMilitaryTime", 1, {
        tip = LOCALE_zhCN and "说明`24小时时间制" or "說明`24小時時間制",
        reload = 1,
    }),

    U1CfgMakeCVarOption(LOCALE_zhCN and "按下按键时施法" or "按下按鍵時施法", "ActionButtonUseKeyDown", nil, {
        tip = LOCALE_zhCN and "说明`按下按键时，就施放技能;反之，就是在松开按键后施放" or "说明`按下按键时，就施放技能;反之，就是在松开按键后施放",
        reload = 1,
    }),

	U1CfgMakeCVarOption(LOCALE_zhCN and "移动时大地图透明" or "移動時大地圖透明", "mapFade", 0, {
        tip = LOCALE_zhCN and "说明`移动时大地图透明" or "說明`移動時大地圖透明",
        reload = 1,
    }),

    -- U1CfgMakeCVarOption(LOCALE_zhCN and "自动解除离开状态" or "自動解除離開狀態", "autoClearAFK", 1, {
        -- tip = LOCALE_zhCN and "说明`自动解除离开状态" or "說明`自動解除離開狀態",
        -- reload = 1,
    -- }),

    U1CfgMakeCVarOption(LOCALE_zhCN and "自动显示装备对比" or "自動顯示裝備對比", "alwaysCompareItems", 1, {
        tip = LOCALE_zhCN and "说明`自动显示装备对比" or "說明`自動顯示裝備對比",
        reload = 1,
    }),

    U1CfgMakeCVarOption(LOCALE_zhCN and "鼠标位置打开拾取框" or "鼠標位置打開拾取框", "lootUnderMouse", 1, {
        tip = LOCALE_zhCN and "说明`鼠标位置打开拾取框" or "說明`鼠標位置打開拾取框",
        reload = 1,
    }),

    U1CfgMakeCVarOption(LOCALE_zhCN and "自动取消飞行" or "自動取消飛行", "autoDismountFlying", 1, {
        tip = LOCALE_zhCN and "说明`自动取消飞行" or "說明`自動取消飛行",
        reload = 1,
    }),

    U1CfgMakeCVarOption(LOCALE_zhCN and "姓名板的最大显示距离" or "姓名板的最大顯示距離", "nameplateMaxDistance", 60, {
        tip = LOCALE_zhCN and "说明`8.2后已被固定为60码，无法修改" or "說明`8.2後已被固定為60碼，無法修改",
        disableOnLoad = true,
        type = "spin",
        range = {59, 60, 5},
    }),

    U1CfgMakeCVarOption(LOCALE_zhCN and "显示目标所有DEBUFF" or "顯示目標所有DEBUFF", "noBuffDebuffFilterOnTarget", 0, {
        tip = LOCALE_zhCN and "说明`在目标头像上是否显示所有DEBUFF" or "說明`在目標頭像上是否顯示所有DEBUFF",
    }),

    U1CfgMakeCVarOption(LOCALE_zhCN and "显示目标施法条" or "顯示目標施法條", "showTargetCastbar", 1, {
        tip = LOCALE_zhCN and "说明`是否在目标头像下方显示施法条`7.0以后暴雪将此选项精简掉了" or "說明`是否在目標頭像下方顯示施法條`7.0以後暴雪將此選項精簡掉了",
        reload = 1,
    }),

    U1CfgMakeCVarOption(LOCALE_zhCN and "显示目标仇恨值" or "顯示目標仇恨值", "threatShowNumeric", 1, {
        tip = LOCALE_zhCN and "说明`在目标头像上方显示当前仇恨百分比" or "說明`在目標頭像上方顯示當前仇恨百分比",
    }),

    U1CfgMakeCVarOption(LOCALE_zhCN and "自动追踪任务" or "自動追蹤任務", "autoQuestWatch", 1, {
        tip = LOCALE_zhCN and "说明`接受任务后自动添加到追踪列表里`7.0以后暴雪将此选项精简掉了" or "說明`接受任務後自動添加到追蹤列表裏`7.0以後暴雪將此選項精簡掉了",
        reload = 1,
    }),

    U1CfgMakeCVarOption(LOCALE_zhCN and "连击点界面位置" or "連擊點界面位置", "comboPointLocation", nil, {
        type = "radio",
        options = { LOCALE_zhCN and "玩家头像下" or "玩家頭像下", "2", LOCALE_zhCN and "经典:目标头像" or "經典:目標頭像", "1", },
        reload = 1,
    }),

    {
        var = "checkAddonVersion",
        text = L["允许加载过期插件"],
        tip = L["说明`和人物选择功能插件界面上的选项一致"],
        default = "1",
        getvalue = function() return GetCVar("checkAddonVersion")=="0" end,
        callback = function(cfg, v, loading)
            SetCVar("checkAddonVersion", v and "0" or "1")
        end,
    },

    {
        var = "cameraDistanceMaxZoomFactor",
        text = L["设置最远镜头距离"],
        tip = L["说明`这个值是修改\"界面-镜头-最大镜头距离\"绝对值, 比如, 系统默认为15, 界面设置里调到最大是15，调到中间是7.5。当设置此选项为25时，调到最大是25，调到中间是12.5"],
        type = "spin",
        range = {1, 2.6, 0.1},
        cols = 3,
        default = "2.6",
        getvalue = function() return ceil(GetCVar("cameraDistanceMaxZoomFactor")*10)/10 end,
        callback = function(cfg, v, loading) SetCVar("cameraDistanceMaxZoomFactor", v) end,
    },

    --[[------------------------------------------------------------
    -- 姓名板设置
    ---------------------------------------------------------------]]
    {
        text = LOCALE_zhCN and "姓名板设置" or "姓名板設置", type = "text",
        U1CfgMakeCVarOption(LOCALE_zhCN and U1_NEW_ICON.."友方玩家姓名板职业颜色" or U1_NEW_ICON.."友方玩家姓名板職業顏色", "ShowClassColorInFriendlyNameplate", nil, {
            reload = 1,
            tip = LOCALE_zhCN and "说明`7.2.5新增变量，无法通过界面设置" or "說明`7.2.5新增變量，無法通過界面設置",
        }),
        U1CfgMakeCVarOption(LOCALE_zhCN and "敌方玩家职业颜色" or "敵方玩家職業顏色", "ShowClassColorInNameplate", nil, { reload = 1 }),

        U1CfgMakeCVarOption(LOCALE_zhCN and "显示友方NPC的姓名板" or "顯示友方NPC的姓名板", "nameplateShowFriendlyNPCs", nil, {
            tip = LOCALE_zhCN and "说明`7.1之后，友方NPC的姓名板无法通过界面设置" or "說明`7.1之後，友方NPC的姓名板無法通過界面設置",
        }),

        U1CfgMakeCVarOption(untex(DISPLAY_PERSONAL_RESOURCE) or LOCALE_zhCN and "显示个人资源" or "顯示個人資源", "nameplateShowSelf", 0, { tip = OPTION_TOOLTIP_DISPLAY_PERSONAL_RESOURCE, secure = 1 }),

        --U1CfgMakeCVarOption("总是显示姓名板", "nameplateShowAll", { tip = OPTION_TOOLTIP_UNIT_NAMEPLATES_AUTOMODE, secure = 1 }),

        --makeCVarOption("能量点位于目标姓名板", "nameplateResourceOnTarget", { tip = '连击点等框体显示在目标姓名板上而不是自己脚下', secure = 1 }),

        U1CfgMakeCVarOption(LOCALE_zhCN and "姓名板分散不重叠" or "姓名板分散不重疊", "nameplateMotion", 1, { tip = UNIT_NAMEPLATES_TYPE_TOOLTIP_2, callback = function(cfg, v, loading)
            if not loading then
                local function f()
                    SetCVar(cfg.var:gsub("^cvar_", ""), v)
                    local d = InterfaceOptionsNamesPanelUnitNameplatesMotionDropDown
                    if d then
                        local v --= v and 1 or 0 will taint
                        d.value = v
                        d.selectedValue = v
                    end
                end
                CoreLeaveCombatCall("nameplateMotion", LOCALE_zhCN and "脱战后会自动更新设置" or "脫戰後會自動更新設置", f)
            end
        end}),

        U1CfgMakeCVarOption(LOCALE_zhCN and "允许姓名板移到屏幕之外" or "允許姓名板移到屏幕之外", "nameplateOtherTopInset", nil, {
            tip = LOCALE_zhCN and "说明`7.0之后，姓名板默认会收缩到屏幕之内挤在一起``此选项可以恢复到7.0之前的方式" or "說明`7.0之後，姓名板默認會收縮到屏幕之內擠在一起``此選項可以恢復到7.0之前的方式",
            secure = 1,
            getvalue = function() if GetCVar("nameplateOtherTopInset") == "-1" then return true else return false end end,
            callback = function(cfg, v, loading)
                if v then
                    SetCVar("nameplateTargetRadialPosition", 2)
                    SetCVar("nameplateOtherTopInset", 0.08)
                    SetCVar("nameplateOtherBottomInset", 0.1)
                    --C.NamePlate.SetTargetClampingInsets
                else
                    SetCVar("nameplateTargetRadialPosition", GetCVarDefault("nameplateTargetRadialPosition"))
                    SetCVar("nameplateOtherTopInset", GetCVarDefault("nameplateOtherTopInset"))
                    SetCVar("nameplateOtherBottomInset", GetCVarDefault("nameplateOtherBottomInset"))
                end
            end
        }),

        U1CfgMakeCVarOption(LOCALE_zhCN and "切换友方姓名板显示" or "切換友方姓名板顯示", "nameplateShowFriends", nil, { secure = 1, callback = function(cfg, v, loading)
            if not loading then SetCVar(cfg.var:gsub("^cvar_", ""), v) end
        end}),
    },

    --[[------------------------------------------------------------
    -- 浮动战斗信息设置
    ---------------------------------------------------------------]]
    {
        text = LOCALE_zhCN and "暴雪伤害数字设置" or "暴雪傷害數字設置", type = "text",
        U1CfgMakeCVarOption(LOCALE_zhCN and "人物伤害" or "人物傷害", "floatingCombatTextCombatDamage_v2", 1),
        U1CfgMakeCVarOption(LOCALE_zhCN and "人物治疗" or "人物治療", "floatingCombatTextCombatHealing_v2", 1),
        U1CfgMakeCVarOption(LOCALE_zhCN and "人物持续伤害" or "人物持續傷害", "floatingCombatTextCombatLogPeriodicSpells_v2", 1),
        U1CfgMakeCVarOption(LOCALE_zhCN and "宠物普攻" or "寵物普攻", "floatingCombatTextPetMeleeDamage_v2", 0),
        U1CfgMakeCVarOption(LOCALE_zhCN and "宠物技能" or "寵物技能", "floatingCombatTextPetSpellDamage_v2", 0),
        --fctSpellMechanics floatingCombatTextAllSpellMechanics floatingCombatTextSpellMechanics floatingCombatTextSpellMechanicsOther
    }

})
