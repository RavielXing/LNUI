local L = select(2,...).L
U1_NEW_ICON = '|TInterface\\OptionsFrame\\UI-OptionsFrame-NewFeatureIcon:0:0:0:-1|t'
U1_LOAD_CONFIRM_TAINT = LOCALE_zhCN and "可能导致卡动作条，建议先别用" or "可能導致卡動作條，建議先別用"

-- default 仅在插件first run的时候运行，如果是nil则不会设置默认值
function U1CfgMakeCVarOption(title, cvar, default, options)
    local info = u1copy(options) or {}

    info.text = title
    info.var = "cvar_"..cvar
    info.dontCompareDefaultWhenSave = true -- 保存时不根据默认值清空，放弃控制玩家默认值的能力，在玩家用其他插件或被其他人上号，回来的时候可以恢复
    local origin_callback = info.callback

    if pcall(GetCVarDefault, cvar) then
        info.getvalue = info.getvalue or function()
            if info.type == "checkbox" or info.type == nil then
                return GetCVarBool(cvar)
            else
                local v = tostring(GetCVar(cvar))
                if v == "nil" then return tostring(GetCVarDefault(cvar)) else return v end
            end
        end
        info.callback = function(cfg, v, loading)
            if loading then
                if U1DB.configs[cfg._path] == nil then
                    -- 没用过爱不易不会设置, 跳过default
                    return
                end
                -- 此时v就是U1DB.configs[cfg._path], getvalue加载时不调用
            end
            --if cfg._path == "163ui_moreoptions/cvar_floatingCombatTextCombatDamage" then print(v, U1DB.configs[cfg._path], cfg.getvalue()) pdebug() end
            --加载的时候不根据保存的值设置，目的是这些变量在玩家初次游戏时不变化，只有在玩家去修改的时候才会影响到玩家
            if( false and InCombatLockdown()) then
                U1Message(LOCALE_zhCN and "战斗中无法设置此选项,请结束战斗后重试." or "戰鬥中無法設置此選項,請結束戰鬥後重試.")
            else
                if origin_callback then
                    origin_callback(cfg, v, loading)
                else
                    SetCVar(cvar, v)
                end
            end
        end
        if info.default ~= nil then U1Message(LOCALE_zhCN and "CVAR选项的default没效果，在参数上设置" or "CVAR選項的default沒效果，在參數上設置", info.cvar) end
        if default ~= nil then info.defaultFirstRun = default end
        --if info.default == nil then info.default = GetCVarDefault(cvar) end --这里不能用getvalue，否则会乱
    else
        info.disabled = 1
        info.tip = format(LOCALE_zhCN and "已失效``当前版本没有'%s'这个设置变量'" or "已失效``當前版本沒有'%s'這個設置變量'", cvar)
        info.getvalue = nil
        info.callback = nil
    end

    return info
end

U1RegisterAddon("!!!Libs", { load = "NORMAL", protected = 1, hide = 1 }) U1EnableAddOn("!!!Libs") --163UI必须第一个加载，不能依赖其他的，只能这样

U1RegisterAddon("!!!163UI!!!", {
    title = L["爱不易"],
    tags = {TAG_MANAGEMENT},
    desc = L["爱不易是新一代整合插件。其设计理念是兼顾整合插件的易用性和单体插件的灵活性，同时适合普通和高级用户群体。|n|n    功能上，爱不易实现了任意插件的随需加载，并可先进入游戏再逐一加载插件，此为全球首创。此外还有标签分类、拼音检索、界面缩排等特色功能。"],
    protected = 1,
    icon = "Interface\\AddOns\\!!!163UI!!!\\Textures\\UI2-logo",

    nopic = 1,

    author = L["爱不易"],

    {
        var = "showTrackerButton",
        default = true,
        text = U1_NEW_ICON .. "显示任务通报和自动交接",
        tip = LOCALE_zhCN and "说明`任务追踪标题栏这两个按钮因为有加载对应插件的功能，所以是比较特殊的存在，无法通过关闭插件来隐藏。只能在设置里加一个选项。" or "說明`任務追蹤標題欄這兩個按鈕因為有加載對應插件的功能，所以是比較特殊的存在，無法通過關閉插件來隱藏。只能在設置裏加一個選項。",
        callback = function(cfg, v, loading)
            RunOnNextFrame(function()
                if QuestAnnounceTrackerQuickSwitch then CoreUIShowOrHide(QuestAnnounceTrackerQuickSwitch, v) end
                if AutoTurnInTrackerQuickSwitch then CoreUIShowOrHide(AutoTurnInTrackerQuickSwitch, v) end
            end)
        end
    },

    {
        var = "soundRedirect",
        text = LOCALE_zhCN and "插件声音通过主声道播放" or "插件聲音通過主聲道播放",
        tip = LOCALE_zhCN and "说明`开启此选项后，第三方的插件音效会从主声道播放，而不是默认的'声音效果'声道。这样就可以把所有的音效都关掉，但不会错过插件提示的声音。`注意，'系统-声音'设置里最上面的'开启声效'不能管, 要关的是'声音效果'和'环境音效'" or "說明`開啟此選項後，第三方的插件音效會從主聲道播放，而不是默認的'聲音效果'聲道。這樣就可以把所有的音效都關掉，但不會錯過插件提示的聲音。`註意，'系統-聲音'設置裏最上面的'開啟聲效'不能管, 要關的是'聲音效果'和'環境音效'",
        default = 1,
        callback = function(cfg, v, loading)
            if loading then
                local config = cfg._path
                local playS, playSF = PlaySound, PlaySoundFile
                local wipe, playing, looping, updater = table.wipe, {}, {}, CreateFrame("Frame", "U1_SOUND_REDIRECT")
                looping[SOUNDKIT.UI_BONUS_LOOT_ROLL_LOOP or ""] = true --LootFrame
                looping[SOUNDKIT.IG_CREATURE_AGGRO_SELECT or 0] = true --TargetFrame_OnEvent
                looping[SOUNDKIT.IG_CHARACTER_NPC_SELECT or 0] = true --TargetFrame_OnEvent
                looping[SOUNDKIT.IG_CREATURE_NEUTRAL_SELECT or 0] = true --TargetFrame_OnEvent
                looping[SOUNDKIT.INTERFACE_SOUND_LOST_TARGET_UNIT or 0] = true --TargetFrame_OnHide
                updater:SetScript("OnUpdate", function(self) wipe(playing) end)
                if CreateLoopingSoundEffectEmitter then
                    hooksecurefunc("CreateLoopingSoundEffectEmitter", function(startingSound, loopingSound)
                        -- 12.0: 过滤掉不能作为表键的对象
                        if type(loopingSound) == "number" or type(loopingSound) == "string" then
                            looping[loopingSound] = true
                        end
                    end)
                end
                local function shouldRedirect(channel, sound)
                    -- 12.0: sound 可能是受保护的 table/userdata，不能直接索引表
                    if type(sound) ~= "number" and type(sound) ~= "string" then
                        return false
                    end
                    if looping[sound] then return end
                    if(not U1GetCfgValue(config)) then return end
                    channel = channel and type(channel) == "string" and channel:upper() or "SFX"
                    if(channel == "MASTER") then return end
                    if playing[sound] then return end
                    if(GetCVarBool("Sound_EnableSFX") and channel~="MUSIC" and channel~="MASTER" and channel~="AMBIENCE") then return end
                    playing[sound] = true
                    return true
                end
                hooksecurefunc("PlaySound", function(sound, channel) if shouldRedirect(channel, sound) then playS(sound, "Master") end end)
                -- 12.0: PlaySoundFile 可能已不存在，加判断避免报错
                if playSF then
                    hooksecurefunc("PlaySoundFile", function(sound, channel) if shouldRedirect(channel, sound) then playSF(sound, "Master") end end)
                end
            else
                if v then
                    if GetCVarBool("Sound_EnableSFX") then
                        U1Message(LOCALE_zhCN and "已关闭游戏音效，现在只会听到插件的声音" or "已關閉遊戲音效，現在只會聽到插件的聲音")
                    end
                    SetCVar("Sound_EnableSFX", "0")
                    SetCVar("Sound_EnableAmbience", "0")
                    Sound_GameSystem_RestartSoundSystem()
                end
            end
            CoreUIShowOrHide(U1_SOUND_REDIRECT, v)
        end
    },
    {
        var = "ahkeep",
        text = LOCALE_zhCN and "保持拍卖行等界面开启" or "保持拍賣行等界面開啟",
        tip = LOCALE_zhCN and "说明`打开交易技能等界面时保持拍卖行界面开启，适用于屏幕分辨率不高的玩家。如果遇到拍卖行无法打开的情况，请尝试关闭此选项。" or "說明`打開交易技能等界面時保持拍賣行界面開啟，適用於屏幕分辨率不高的玩家。如果遇到拍賣行無法打開的情況，請嘗試關閉此選項。",
        default = false,
        callback = function(cfg, v, loading)
            if loading and not v then return end
            --- 拍卖行不会自动关闭, RegisterUIPanel(ProfessionsCustomerOrdersFrame, attributes);
            local function handleFrame(frameName, v)
                local frame = _G[frameName]
                if not frame then return end
                if v then
                    frame:SetAttribute("UIPanelLayout-defined", false);
                    frame:SetAttribute("UIPanelLayout-area", false);
                    tinsertdata(UISpecialFrames, frameName)
                else
                    frame:SetAttribute("UIPanelLayout-defined", true);
                    frame:SetAttribute("UIPanelLayout-area", UIPanelWindows[frameName].area or "doublewide");
                    tremovedata(UISpecialFrames, frameName)
                end
                if not frame._hooked163 then
                    frame._hooked163 = true
                    hooksecurefunc(frame, "SetAttributeNoHandler", function(self, arg1, value)
                        if (arg1 == "UIPanelLayout-area" and value and U1GetCfgValueFast2(cfg)) then
                            self:SetAttribute(arg1, false); --为了代码简单我们用SetAttribute防止循环
                            self:SetAttribute("UIPanelLayout-defined", false);
                        end
                    end)
                end
            end
            CoreDependCall("Blizzard_AuctionHouseUI", function() handleFrame("AuctionHouseFrame", v) end)
            CoreDependCall("Blizzard_Soulbinds", function() handleFrame("SoulbindViewer", v) end)
            --CoreDependCall("Blizzard_Professions", function() handleFrame("ProfessionsFrame", v) end) --和BlizzMove结合可能导致打不开
            --CoreDependCall("Blizzard_ClassTalentUI", function() handleFrame("ClassTalentFrame", v) end)
            --CoreDependCall("Blizzard_ProfessionsCustomerOrders", function() handleFrame("ProfessionsCustomerOrdersFrame", v) end)
        end,
    },
    {
        var = "fixhot",
        text = LOCALE_zhCN and "临时修复动作条热键乱码" or "臨時修復動作條熱鍵亂碼",
        tip = LOCALE_zhCN and "说明`暴雪给动作条热键设置的默认字体不支持中文，所以遇到'鼠标滚轮'之类的就会显示????，这个选项是用来临时修复的，如果自己修改了字体，请关闭。" or "说明`暴雪给动作条热键设置的默认字体不支持中文，所以遇到'鼠标滚轮'之类的就会显示????，这个选项是用来临时修复的，如果自己修改了字体，请关闭。",
        default = 1,
        callback = function(cfg, v, loading)
            U1NumberFontNormalSmallGray = U1NumberFontNormalSmallGray or WW:Font("U1NumberFontNormalSmallGray", ChatFontNormal, 12, .6, .6, .6, 1):SetFontFlags("OUTLINE"):un()
            if loading then
                CoreDependCall("ExtraActionBar", function()
                    hooksecurefunc("U1BAR_CreateBar", function(name)
                        local font, height, flags
                        if U1GetCfgValue(cfg._path) then
                            font, height, flags = U1NumberFontNormalSmallGray:GetFont()
                        else
                            font, height, flags = NumberFontNormalSmallGray:GetFont()
                        end
                        for i=1, 12 do _G[name.."AB"..i.."HotKey"]:SetFont(font, height, flags) end
                    end)
                end)
            end
            if loading and not v then return end

            local font, height, flags
            if v then
                font, height, flags = U1NumberFontNormalSmallGray:GetFont()
            else
                font, height, flags = NumberFontNormalSmallGray:GetFont()
            end
            for _, btn in next, ActionBarButtonEventsFrame.frames do
                if btn:GetName() then
                    local hotkey = _G[btn:GetName().."HotKey"]
                    if hotkey then
                        hotkey:SetSize(37, 10)
                        --载具的会看不到
                        --hotkey:ClearAllPoints();
                        --hotkey:SetPoint("TOPRIGHT", 1, -2);
                        hotkey:SetFont(font, height, flags)
                    end
                end
            end
            for i=1, 10 do
                if _G["U1BAR"..i] then
                    for j =1, 12 do _G["U1BAR"..i.."AB"..j.."HotKey"]:SetFont(font, height, flags) end
                end
            end
        end,
    },
    {
        text = LOCALE_zhCN and "重置界面框体顺序" or "重置界面框體順序",
        confirm = LOCALE_zhCN and "此操作需要重载界面，您是否确定？" or "此操作需要重載界面，您是否確定？",
        tip = LOCALE_zhCN and "说明:暴雪目前的界面存在一个BUG，当打开过多界面时，框体层次顺序可能会出错，使得某些按钮被遮挡无法看到，或者无法点击。` `当出现类似问题的时候，尝试点击此按钮，会重置所有框体的层次并重载界面，问题一般就会修复。" or "说明:暴雪目前的界面存在一个BUG，当打开过多界面时，框体层次顺序可能会出错，使得某些按钮被遮挡无法看到，或者无法点击。` `当出现类似问题的时候，尝试点击此按钮，会重置所有框体的层次并重载界面，问题一般就会修复。",
        callback = function(cfg, v, loading)
            local f = EnumerateFrames()
            while f do
                if f:IsUserPlaced() then
                    f:SetFrameLevel(1)
                end
                f = EnumerateFrames(f)
            end
            ReloadUI()
        end
    },
    {
        text = L["小地图相关"], type = "text",
        {
            lower = true,
            text = L["收集全部小地图图标"],
            callback = function(cfg, v, loading)
                CoreCall("U1_MMBCollectAll");
                CoreCall("U1_MMBUpdateUI");
            end
        },
        {
            text = L["还原全部小地图图标"],
            callback = function(cfg, v, loading)
                CoreCall("U1_MMBRestoreAll");
                CoreCall("U1_MMBUpdateUI");
            end
        },
        {
            var = "coord",
            default = 1,
            text = LOCALE_zhCN and "显示坐标小窗" or "顯示坐標小窗",
            callback = function(cfg, v, loading) if not MinimapCoordsButton then return end if v then MinimapCoordsButton:Show() else MinimapCoordsButton:Hide() end end,
        },
        {
            var = "mmp_elite",
            default = nil,
            text = LOCALE_zhCN and "图标用精英边框" or "圖標用精英邊框",
            callback = function(cfg, v, loading)
                local function change(on)
                    LibDBIcon10_U1MMB.overlay:SetTexture(on and "Interface\\AddOns\\!!!163UI!!!\\Textures\\UI2-minimap-btn" or 136430)
                end
                if loading and U1_CreateMinimapButton then
                    hooksecurefunc("U1_CreateMinimapButton", function() change(v) end)
                else
                    change(v)
                end
            end,
        },

    },
    {
        text = L["控制台设置"], type = "text",
        {
            var = "scale",
            text = LOCALE_zhCN and "缩放比例" or "縮放比例",
            default = 1,
            type = "spin",
            range = { 0.5, 1.5, 0.1 },
            callback = function(cfg, v, loading)
                UUI():SetScale(v)
            end,
        },
        {
            var = "alpha",
            text = LOCALE_zhCN and "透明度" or "透明度",
            default = 1,
            type = "spin",
            range = { 0.3, 1, 0.1 },
            callback = function(cfg, v, loading)
                UUI():SetAlpha(v)
            end,
        },
        {
            var = "english",
            text = L["显示插件英文名"],
            default = false,
            tip = L["说明`选中显示插件目录的名字，适合中高级用户快速选择所需插件。"],
            getvalue = function() return U1GetShowOrigin() end,
            callback = function(cfg, v, loading)
                U1SetShowOrigin(v);
                if not loading then
                    U1SortAddons();
                    UUI.Right.ADDON_SELECTED();
                end
            end,
        },
        {
            var = "sortmem",
            text = L["按插件所用内存排序"],
            default = false,
            tip = L["说明`选中则按插件(包括子模块)所占内存大小进行排序，否则按插件名称排序。"],
            getvalue = function() return not U1DB.sortByName end,
            callback = function(cfg, v, loading)
                U1DB.sortByName = not v;
                if not loading then
                    UpdateAddOnMemoryUsage();
                    U1SortAddons()
                end
            end,
        },
        {
            text = LOCALE_zhCN and "清理自动保存方案" or "清理自動保存方案",
            tip = LOCALE_zhCN and "说明`一些小号长久运行生成的方案比较占内存，一键清理" or "說明`一些小號長久運行生成的方案比較占內存，一鍵清理",
            confirm = LOCALE_zhCN and "即将清理方案管理里所有自动保存的方案，以及橙装闪换的数据，会自动重载，请确定" or "即將清理方案管理裏所有自動保存的方案，以及橙裝閃換的數據，會自動重載，請確定",
            callback = function(cfg, v, loading)
                U1DBG.profiles.auto = nil
                U1DB.LS = nil
                ReloadUI()
            end,
        },
    },
});