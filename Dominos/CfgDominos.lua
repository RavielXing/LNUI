U1RegisterAddon("Dominos", {
    title = LOCALE_zhCN and "多米诺动作条" or "多米诺动作条",
    optdeps = {"Masque"},
    defaultEnable = 0,
    load = "NORMAL",
    minimap = "LibDBIcon10_Dominos",
    tags = { TAG_INTERFACE },
    icon = 'Interface/AddOns/Dominos/Dominos',
    desc = LOCALE_zhCN and "一个简单易用的动作条移动插件，可以移动动作条、施法条、姿态条、宠物条、图腾条等等。" or "一个简单易用的动作条移动插件，可以移动动作条、施法条、姿态条、宠物条、图腾条等等。",

    runBeforeLoad = function(info, name)
		_G.Dominos = LibStub('AceAddon-3.0'):GetAddon('Dominos')
        SLASH_DOMINO_CONFIG1 = '/dmn' SlashCmdList["DOMINO_CONFIG"] = function() Dominos:ToggleLockedFrames() end
        Dominos.ShowOptions = function()
            local _ = InterfaceOptionsFrame:IsShown() and InterfaceOptionsFrame:Hide()
            UUI.OpenToAddon('dominos', true)
        end

        Dominos.OWNER_NAME = {artifact="神器",exp="经验声望",page="翻\n页",vehicle="离开\n载具",pet="宠物技能",menu="菜单",bags="背包",roll="掷骰框",alerts="提示框",extra="特殊\n动作",encounter="战斗能量",cast="施法条",cast_new="美化施法条",zone="区域\n技能",class="职业", talk="剧情对话"}
        --[[对DebuffCaster的支持
        Dominos.ActionButton.oriCreate = Dominos.ActionButton.Create;
        function Dominos.ActionButton:Create(id)
            local b = self:oriCreate(id)
            if b and b.cooldown then b.cooldown.DCFlag=nil end
            return b;
        end--]]
    end,

    toggle = function(name, info, enable, justload)
        if enable and GroupLootContainer and justload then
            GroupLootContainer:EnableMouse(false)
        end
    end,

    {
        text = LOCALE_zhCN and '重置为预设方案' or '重置为预设方案',
        type = 'button',
        secure = 1,
        confirm = LOCALE_zhCN and "注意：当前的动作条设置将重置并无法恢复，您是否确定？" or "注意：当前的动作条设置将重置并无法恢复，您是否确定？",
        tip = LOCALE_zhCN and "预设了动作条布局方案，可以重置后自行微调，注意：当前的动作条设置将重置并无法恢复" or "预设了动作条布局方案，可以重置后自行微调，注意：当前的动作条设置将重置并无法恢复",
        callback = function(cfg, v, loading)
            if(loading) then return end
            Dominos:Unload()
            Dominos.ignoreResetCalback = true
            Dominos.db:ResetProfile()
            Dominos.ignoreResetCalback = nil
            -- insert out diff
            -- Dominos:U1_InitPreset(true)
            Dominos.isNewProfile = nil
            Dominos:Load()
            --local masque = U1GetMasqueCore and U1GetMasqueCore()
            --if masque then masque:Group("Dominos"):ReSkinWithSub() end
            Dominos:GetModule("ButtonThemer"):Reskin() --LibStub("AceAddon-3.0"):GetAddon("Dominos")
            Dominos:ToggleLockedFrames()
        end
    },

    {
        type = 'button',
        text = LOCALE_zhCN and '进入布局模式' or '进入布局模式',
        tip = LOCALE_zhCN and "说明`进入布局设置模式，点击小地图旁边的多米诺按钮也可以进入。" or "说明`进入布局设置模式，点击小地图旁边的多米诺按钮也可以进入。",
        callback = function() Dominos:ToggleLockedFrames() end,
    },

    {
        type = 'button',
        text = LOCALE_zhCN and "配置选项" or "配置选项",
        --tip = "说明`选择不同的配置方案，可以常换常新，建议查看下操作按钮的说明。",
        callback = function()
            if(not IsAddOnLoaded'Dominos_Config') then
                LoadAddOn'Dominos_Config'
                C_Timer.After(GetTickTime()*2, function()
                    LibStub("AceConfigDialog-3.0"):Open("Dominos")
                end)
            else
                LibStub("AceConfigDialog-3.0"):Open("Dominos")
            end
        end,
    },

    {
        var = 'overrideui',
        default = true,
        text = LOCALE_zhCN and '保留默认载具界面' or '保留默认载具界面',
        tip = LOCALE_zhCN and '说明`开启此选项后会使用暴雪默认的载具界面，如果不开启，则会使用动作条1来显示载具操作按钮。' or '说明`开启此选项后会使用暴雪默认的载具界面，如果不开启，则会使用动作条1来显示载具操作按钮。',
        getvalue = function() return Dominos:UsingOverrideUI() end,
        callback = function(_, v)
            return Dominos:SetUseOverrideUI(v)
        end,
    },

	{	--	显示空按钮
		var = 'showgrid',
		text = '显示空按钮',
		default = false,
		getvalue = function(cfg, info) return Dominos:ShowingEmptyButtons() end,
		callback = function(cfg, v, loading, info)
			return Dominos:SetShowEmptyButtons(v);
		end,
	},

    {
        var = 'showbind',
        text = LOCALE_zhCN and '显示绑定热键' or '显示绑定热键',
        default = true,
        getvalue = function() return Dominos:ShowBindingText() end,
        callback = function(_, v) return Dominos:SetShowBindingText(v) end,
    },

    {
        var = 'tipcombat',
        text = LOCALE_zhCN and '战斗中显示鼠标提示' or '战斗中显示鼠标提示',
        default = true,
        getvalue = function() return Dominos.db.profile.showTooltipsCombat end,
        callback = function(_,v) return Dominos:SetShowCombatTooltips(v) end,
    },

    {
        type = 'button',
        text = LOCALE_zhCN and '按键绑定模式' or '按键绑定模式',
        tip = LOCALE_zhCN and "说明`进入按键绑定模式，可以快速的给动作条设置绑定热键。" or "说明`进入按键绑定模式，可以快速的给动作条设置绑定热键。",
        callback = function() Dominos:ToggleBindingMode() end,
    },

});

local function dominoModuleToggle(name, info, enable, justload)
    if info.dominoModule and justload then
        if IsLoggedIn() then
            local module = Dominos:GetModule(info.dominoModule, true) --EncounterBar 在开启BlizzMove的时候不加载
            if module then
                pcall(module.Unload, module) --没有统一的是否加载机制，所以只能强制Unload一下试试了
                -- module:Load()
                Dominos.Frame:ForEach('Reanchor')
            end
        end
    end
    return true
end

U1RegisterAddon("Dominos_Config", { title = "配置界面模块", protected = 1, hide = 1, });

U1RegisterAddon("Dominos_CastClassic", { title = "经典施法条模块", defaultEnable = 1, load="NORMAL", dominoModule = 'CastingBar', toggle = dominoModuleToggle, desc = "令系统默认施法条可以移动和配置的多米诺模块,有爱叶子修改。", });
U1RegisterAddon("Dominos_Cast", { title = "美化施法条模块", defaultEnable = 0, load="NORMAL", ignoreLoadAll = 1, desc = "令系统默认施法条可以移动和配置的多米诺模块,有爱叶子修改。",
    toggle = function(name, info, enable, justload)
        if justload then
            if IsLoggedIn() then
                Dominos:GetModule("CastBar"):Load()
                Dominos.Frame:ForEach('Reanchor')
            end
        else
            if enable then
                Dominos:GetModule("CastBar"):Load()
                Dominos.Frame:ForEach('Reanchor')
                PlayerCastingBarFrame:UnregisterAllEvents()
                PlayerCastingBarFrame.ignoreFramePositionManager = true
                PlayerCastingBarFrame:SetParent(Dominos.ShadowUIParent)
            else
                Dominos:GetModule("CastBar"):Unload()
                Dominos.Frame:ForEach('Reanchor')
                if IsAddOnLoaded("Quartz") then return end
                PlayerCastingBarFrame.unit = nil
                PlayerCastingBarFrame:SetUnit("player", true, false)
                PlayerCastingBarFrame.ignoreFramePositionManager = nil
                PlayerCastingBarFrame:SetParent(DominosFramecast)
            end
        end
    end,
});
U1RegisterAddon("Dominos_Roll", { title = "拾取提示模块", defaultEnable = 1, load="NORMAL", dominoModule = 'RollBars', toggle = dominoModuleToggle, desc = "让装备掷骰界面和提示获取装备的框体可以移动的多米诺模块", });
U1RegisterAddon("Dominos_Encounter", { title = "特殊能量条模块", defaultEnable = 1, load="NORMAL", dominoModule = 'EncounterBar', toggle = dominoModuleToggle, desc = "移动某些BOSS战斗时玩家特殊能量槽的多米诺模块", });
U1RegisterAddon("Dominos_Progress", { title = "经验和神器进度模块", defaultEnable = 1, load="NORMAL", dominoModule = 'ProgressBars', toggle = dominoModuleToggle, desc = "一个可移动的进度条，右键点击可以切换经验/声望/荣誉。7.0新增指示神器能量的进度条。", });
U1RegisterAddon("Dominos_ActionSets", {title = "动作条保存模块", defaultEnable = 1, load="NORMAL", desc = "可以在配置方案中保存动作条上的技能", });
U1RegisterAddon("Masque_Dominos", {title = "按钮美化皮肤-多米诺", defaultEnable = 1, load="NORMAL", desc = "按钮美化支持多米诺动作条", protected = 1, });

function debug_RollFrame()
    local times = {}
    hooksecurefunc("GroupLootFrame_OpenNewFrame", function(id, time)
        times[id] = GetTime() + time
    end)
    GetLootRollItemInfo = function(rollID)
        local name, link, quality, _, _, _, _, _, _, texture = GetItemInfo(rollID)
        return texture, name, 1, quality, true, true, true, "", "", "", ""
    end
    GetLootRollItemLink = function(rollID) return select(2, GetItemInfo(rollID)) end
    GetLootRollTimeLeft = function(rollID) return times[rollID] or (GetTime() + 10) - GetTime() end
    debug_RollFrame = nil
end