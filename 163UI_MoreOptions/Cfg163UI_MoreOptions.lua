local hideNameplateDebuff

local L = U1.L

local function untex(text)
	return text and text:gsub("\124T.*\124t", "")
end

--[[------------------------------------------------------------
单次复制共享配置到当前角色 - 弹框确认
"单次复制"按钮触发:把 sharedProfile.u1dbaddons 一次性复制到当前角色
不修改 U1DB.shareAddonEnable(本角色不会加入共享)
不修改 U1DBG.preSharedBackup(本按钮跟"开启共享"无关)
---------------------------------------------------------------]]
StaticPopupDialogs["U1_COPY_SHARED_CONFIRM"] = {
    preferredIndex = 3,
    text = LOCALE_zhCN
        and "确定要把[|cff00ff00全局通用配置|r]单次复制到当前角色吗?\n\n"
            .. "说明: 单次复制,本角色|cffff8800不会|r加入共享。复制后本角色独立修改不关联。`\n"
            .. "|cffff8800警告: 这会覆盖当前角色当前的插件启停配置!|r"
        or  "確定要把[|cff00ff00全帳號通用配置|r]單次複製到當前角色嗎?\n\n"
            .. "說明: 單次複製,本角色|cffff8800不會|r加入共用。複製後本角色獨立修改不關聯。`\n"
            .. "|cffff8800警告: 這會覆蓋當前角色當前的插件啟停配置!|r",
    button1 = YES,
    button2 = CANCEL,
    OnAccept = function(self)
        -- 单次复制:把 sharedProfile.u1dbaddons 拷贝到当前角色
        -- 注意:
        --   1. 不修改 U1DB.shareAddonEnable(本角色不会因此加入共享)
        --   2. 不修改 U1DBG.preSharedBackup(跟"开启共享"的 backup 无关)
        --   3. 复制后,本角色后续修改不会双写到 sharedProfile
        if not U1Profiles or not U1DB or not U1DB.addons then return end
        local prof = U1Profiles:EnsureSharedProfile()
        if not prof or not prof.u1dbaddons or next(prof.u1dbaddons) == nil then return end

        local applied = 0
        for k, v in pairs(prof.u1dbaddons) do
            if type(k) == "string" and (v == 0 or v == 1) then
                U1DB.addons[k] = v  -- 同步到角色级
                local curEnabled = C_AddOns.GetAddOnEnableState(k, U1PlayerGuid) >= 2
                local wantEnabled = v == 1
                if curEnabled ~= wantEnabled then
                    if wantEnabled then
                        U1EnableAddOn(k)
                    else
                        U1DisableAddOn(k)
                    end
                    applied = applied + 1
                end
            end
        end

        U1Message(format(LOCALE_zhCN and "[单次复制]已把[全局通用配置]复制到当前角色(%d 个插件)。本角色未加入共享,后续修改不关联。" or "[單次複製]已把[全帳號通用配置]複製到當前角色(%d 個插件)。本角色未加入共用,後續修改不關聯。", applied))
    end,
    hideOnEscape = 1,
    timeout = 0,
    exclusive = 1,
    whileDead = 1,
}

U1RegisterAddon("163UI_MoreOptions", {
    title = LOCALE_zhCN and "额外设置" or "額外設置",
    tags = { TAG_MANAGEMENT },
    icon = [[Interface\Icons\Achievement_BG_overcome500disadvantage]],
    desc = LOCALE_zhCN and "额外设置" or "額外設置",
    nopic = 1,
    protected = 1,
    author = "warbaby(爱不易)",
    defaultEnable = 1,

    --[[------------------------------------------------------------
    全账号共享插件启停(网易有爱模式)
    开关 = per-character(每个角色各自决定是否使用共享配置)
    配置 = shared(账号级 Profile 方案"全局通用配置",manual[1],受保护不可删)
    1. 开启时(本角色):
       - 备份 U1DB.addons → U1DBG.preSharedBackup[本角色]
       - 设 U1DB.shareAddonEnable = true
       - EnsureSharedProfile(不存在就用当前角色状态生成基线;存在就跳过)
       - ApplySharedToCurrent(立即把 sharedProfile 应用到本角色,无 reload)
    2. 启动 ADDON_LOADED:本角色开关已开时,自动 ApplySharedToCurrent(覆盖 U1DB.addons)
    3. 开启后本角色修改:双写到 U1DB.addons + sharedProfile.u1dbaddons + 暴雪 AddOns.txt
    4. "单次复制共享配置到当前角色"按钮(给未开启共享的角色用):
       - 一次性把 sharedProfile.u1dbaddons 复制到当前角色 U1DB + 暴雪 AddOns.txt
       - 不修改 U1DB.shareAddonEnable(本角色不会因此加入共享)
       - 不修改 preSharedBackup(跟"开启共享"无关)
       - 复制后独立修改不关联
    5. 关闭:从 backup 恢复 U1DB.addons(完全回到"开启前"状态),清 backup + 清开关
    ---------------------------------------------------------------]]
    {
        var = "shareAddonEnable",
        text = LOCALE_zhCN and U1_NEW_ICON.."全账号共享插件启停" or U1_NEW_ICON.."全帳號共用插件啟停",
        tip = LOCALE_zhCN
            and "说明`开启后,本角色将使用账号级[全局通用配置]共享方案。`\n"
                .. "|cffff8800每个角色单独开关:|r 开启时不影响其他角色,也不覆盖本角色当前配置。`\n"
                .. "如果[全局通用配置]是第一次被创建,会以当前角色状态为基线。`\n"
                .. "之后修改本角色插件开关,会同步到[全局通用配置](账号级共享)。`\n"
                .. "本角色下次登录时会自动应用[全局通用配置]的最新状态。`\n"
                .. "关闭后本角色恢复使用自己的配置,不影响其他角色。"
            or  "說明`開啟後,本角色將使用帳號級[全帳號通用配置]共用方案。`\n"
                .. "|cffff8800每個角色單獨開關:|r 開啟時不影響其他角色,也不覆蓋本角色當前配置。`\n"
                .. "如果[全帳號通用配置]是第一次被建立,會以當前角色狀態為基線。`\n"
                .. "之後修改本角色插件開關,會同步到[全帳號通用配置](帳號級共用)。`\n"
                .. "本角色下次登入時會自動套用[全帳號通用配置]的最新狀態。`\n"
                .. "關閉後本角色恢復使用自己的配置,不影響其他角色。",
        default = 0,
        getvalue = function() return U1DB and U1DB.shareAddonEnable end,
        callback = function(cfg, v, loading)
            if loading then return end
            U1DB = U1DB or {}
            if v then
                -- 开启:
                -- 1. 先备份本角色当前 U1DB.addons(只备份一次,后续启动不覆盖原备份)
                -- 2. 设置开关标志
                -- 3. 确保 sharedProfile 存在(不存在就用当前角色状态生成基线;存在就跳过)
                -- 4. 立即 ApplySharedToCurrent(无 reload,让 UI 跟实际一致)
                if U1Profiles then
                    U1Profiles:BackupPreSharedAddons()
                    U1DB.shareAddonEnable = true
                    local prof = U1Profiles:EnsureSharedProfile()
                    if prof and prof.u1dbaddons then
                        local n = 0
                        for _ in pairs(prof.u1dbaddons) do n = n + 1 end
                        U1Message(format(LOCALE_zhCN
                            and "[共享启停]本角色将使用账号级[%s]共享方案。基线包含 %d 个插件,已存放在方案列表第一位(无法删除,删除无效)。原始启停已备份,关闭时自动恢复。"
                            or  "[共用啟停]本角色將使用帳號級[%s]共用方案。基線包含 %d 個插件,已存放在方案列表第一位(無法刪除,刪除無效)。原始啟停已備份,關閉時自動恢復。",
                            prof.name, n))
                    end
                    U1Profiles:ApplySharedToCurrent()
                end
            else
                -- 关闭:
                -- 1. 清除开关标志
                -- 2. 从 backup 恢复 U1DB.addons(让角色回到"开启前"的状态)
                -- 3. 清掉 backup
                U1DB.shareAddonEnable = nil
                if U1Profiles then
                    U1Profiles:RestorePreSharedAddons()
                end
                U1Message(LOCALE_zhCN and "[共享启停]本角色已退出共享,已恢复本角色原始启停配置(不影响其他角色)。" or "[共用啟停]本角色已退出共用,已恢復本角色原始啟停配置(不影響其他角色)。")
            end
        end,
    },
    {
        text = LOCALE_zhCN and "单次复制共享配置到当前角色" or "單次複製共用配置到當前角色",
        tip = LOCALE_zhCN
            and "说明`把[全局通用配置]单次复制到当前角色(会弹框确认)。`\n"
                .. "本角色|cffff8800不会|r因此加入共享,后续独立修改不关联。`\n"
                .. "适用场景: 想用一次共享配置但又不想开启共享开关时使用。`\n"
                .. "前提: 必须有其他角色开启过共享并生成了[全局通用配置]基线。`\n"
                .. "|cffff8800本按钮是给未开启共享配置开关的角色使用的。|r"
            or  "說明`把[全帳號通用配置]單次複製到當前角色(會彈框確認)。`\n"
                .. "本角色|cffff8800不會|r因此加入共用,後續獨立修改不關聯。`\n"
                .. "適用場景: 想用一次共用配置但又不想開啟共用開關時使用。`\n"
                .. "前提: 必須有其他角色開啟過共用並生成了[全帳號通用配置]基線。`\n"
                .. "|cffff8800本按鈕是給未開啟共用配置開關的角色使用的。|r",
        callback = function(cfg, v, loading)
            if loading then return end
            if not U1Profiles then return end
            -- 条件 1: 本角色已开启共享 → 不可用(已开启就用 ApplySharedToCurrent,不需要这个按钮)
            if U1DB and U1DB.shareAddonEnable then
                U1Message(LOCALE_zhCN and "[单次复制]本角色已开启共享,请直接使用共享配置(无需单次复制)。" or "[單次複製]本角色已開啟共用,請直接使用共用配置(無需單次複製)。")
                return
            end
            -- 条件 2: 共享配置不存在/为空 → 不可用(得先有角色开开关生成基线)
            -- 注意: 用 GetSharedProfile(只读)而不是 EnsureSharedProfile(会创建)
            --       否则没人开过开关时,会创建一份"以本角色状态为基线"的 profile,
            --       导致"单次复制把自己复制给自己"的奇怪行为
            local prof = U1Profiles:GetSharedProfile()
            if not prof or not prof.u1dbaddons or next(prof.u1dbaddons) == nil then
                U1Message(LOCALE_zhCN and "[单次复制]共享配置不存在,请先在某个角色开启共享以生成基线。" or "[單次複製]共用配置不存在,請先在某個角色開啟共用以生成基線。")
                return
            end
            StaticPopup_Show("U1_COPY_SHARED_CONFIRM")
        end,
    },

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
