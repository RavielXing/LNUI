local addonName = ...
--[[------------------------------------------------------------
默认银行界面打开全部银行背包
---------------------------------------------------------------]]
U1PLUG["OpenBags"] = function()
    CoreOnEvent("BANKFRAME_OPENED", function()
        if BankFrame:IsVisible() then
            for i = NUM_TOTAL_EQUIPPED_BAG_SLOTS+1, (NUM_TOTAL_EQUIPPED_BAG_SLOTS + NUM_BANKBAGSLOTS) do
                OpenBag(i)
            end
        end
    end)
end


--[[------------------------------------------------------------
双击空格跳过动画
---------------------------------------------------------------]]
U1PLUG["shuangjikongge"] = function()
    local _f = CreateFrame("Frame")
    _f:SetFrameStrata("LOW")
    _f:Show()
    _f:EnableKeyboard(true)
    _f:SetPropagateKeyboardInput(true);
    _f:SetScript("OnKeyDown", function(self, event, ...)
        if event == "SPACE" then
            if self._lastSpace and GetTime() - self._lastSpace < 0.25 then
                self._lastSpace = nil
            else
                self._lastSpace = GetTime()
                return
            end
            -- 处理双击空格情况
            if TalkingHeadFrame and TalkingHeadFrame.MainFrame and TalkingHeadFrame.MainFrame.CloseButton then
                if TalkingHeadFrame.MainFrame.CloseButton:IsVisible() then
                    TalkingHeadFrame.MainFrame.CloseButton:Click()
                end
            end
            if GossipFrame:IsShown() then
                -- Stop if NPC has quests or quest turn-ins
                if C_GossipInfo.GetNumAvailableQuests() > 0 or C_GossipInfo.GetNumActiveQuests() > 0 then return end
                local options = C_GossipInfo.GetOptions()
                if #options == 1 then
                    self._count = (self._count or 0) + 1
                    if self._count <= 2 then U1Message(LOCALE_zhCN and "你通过双击空格选择了唯一对话选项。" or "你通過雙擊空格選擇了唯一對話選項。") end
                    C_GossipInfo.SelectOption(options[1].gossipOptionID)
                end
            end
            -- RareScanner
            if scanner_button and scanner_button:IsShown() and not InCombatLockdown() then
                scanner_button:Hide()
            end
        end
    end)
end

    _G["U1Toggle_SkipTalkingHead"] = function(enable)
        if enable then
            UIParent:UnregisterEvent("TALKINGHEAD_REQUESTED");
            if TalkingHeadFrame then TalkingHeadFrame:UnregisterEvent("TALKINGHEAD_REQUESTED"); end
        else
            if TalkingHeadFrame then TalkingHeadFrame:RegisterEvent("TALKINGHEAD_REQUESTED"); else UIParent:RegisterEvent("TALKINGHEAD_REQUESTED"); end
        end
    end

--[[------------------------------------------------------------
ctrl点击游戏菜单按钮回收内存，无选项
---------------------------------------------------------------]]
U1PLUG["GameMenuGC"] = function()
    local gc = function()
        UpdateAddOnMemoryUsage();
        local beforeMem = 0;
        for i = 1, GetNumAddOns(), 1 do
            local mem = GetAddOnMemoryUsage(i);
            beforeMem = beforeMem + mem;
        end
        local beforeLua = collectgarbage("count")
        collectgarbage("collect")
        UpdateAddOnMemoryUsage();
        local afterMem = 0;
        for i = 1, GetNumAddOns(), 1 do
            local mem = GetAddOnMemoryUsage(i);
            afterMem = afterMem + mem;
        end
        local afterLua = collectgarbage("count")
        U1Message(format(LOCALE_zhCN and "内存已回收，插件占用：%.1fM -> %.1fM, LUA占用：%.1fM -> %.1fM" or "內存已回收，插件占用：%.1fM -> %.1fM, LUA占用：%.1fM -> %.1fM", beforeMem / 1024, afterMem / 1024, beforeLua / 1024, afterLua / 1024))
    end
    MainMenuMicroButton:HookScript("OnClick", function()
        if IsControlKeyDown() then
            if GameMenuFrame:IsVisible() then HideUIPanel(GameMenuFrame) end
            CoreScheduleBucket("gc", 0.2, gc)
        end
    end)
end
U1PLUG["GameMenuGC"]() U1PLUG["GameMenuGC"] = nil

--[[------------------------------------------------------------
/align 显示网格
---------------------------------------------------------------]]
do
    SLASH_EALIGN_UPDATED1 = "/align"
    SLASH_EALIGN_UPDATED2 = "/wangge"
    local DEFAULT_SQUARE = 30
    local f, square
    SlashCmdList["EALIGN_UPDATED"] = function(msg)
        square = tonumber(msg) or DEFAULT_SQUARE
        if f and f:IsVisible() then
            f:Hide()
            f = nil
        else
            f = CreateFrame('Frame', "ALIGN163FRAME", UIParent)
            f:SetAllPoints(UIParent)
            f.verticals = {}
            f.horizons = {}
            f:Show()

            local screenW = GetScreenWidth()
            local screenH = GetScreenHeight()
            
            -- 竖线：从左到右排列，覆盖整个屏幕宽度
            local numVertical = math.floor(screenW / square)
            for i = 0, numVertical do
                local t = f:CreateTexture(nil, 'BACKGROUND', nil, -8)
                f.verticals[i+1] = t
                t:SetColorTexture(i == numVertical/2 and 1 or 0, 0, 0, 0.5)
                
                local x = i * square
                -- 从TOPLEFT到BOTTOMLEFT，x变化形成竖线
                t:SetPoint('TOPLEFT', f, 'TOPLEFT', x - 1, 0)
                t:SetPoint('BOTTOMRIGHT', f, 'BOTTOMLEFT', x + 1, 0)
            end

            -- 横线：从上到下排列，覆盖整个屏幕高度
            local numHorizontal = math.floor(screenH / square)
            for i = 0, numHorizontal do
                local t = f:CreateTexture(nil, 'BACKGROUND', nil, -8)
                f.horizons[i+1] = t
                t:SetColorTexture(i == numHorizontal/2 and 1 or 0, 0, 0, 0.5)
                
                local y = -i * square  -- 负值表示向下
                -- 从TOPLEFT到TOPRIGHT，y变化形成横线
                t:SetPoint('TOPLEFT', f, 'TOPLEFT', 0, y + 1)
                t:SetPoint('BOTTOMRIGHT', f, 'TOPRIGHT', 0, y - 1)
            end
        end
    end
end

--[[------------------------------------------------------------
公会新闻手工加载
---------------------------------------------------------------]]
U1PLUG["FixBlizGuild"] = function()
    U1QueryGuildNews = QueryGuildNews
    QueryGuildNews = function() end
    local createLoadButton = function(parent)
        local btn = WW:Button("$parentGetNewsButton", parent, "UIMenuButtonStretchTemplate"):SetTextFont(ChatFontNormal, 13, ""):SetAlpha(0.8):SetText(LOCALE_zhCN and "加载新闻" or "加載新聞"):Size(100, 30):CENTER(0, 0):AddFrameLevel(3, parent):SetScript("OnClick", function(self)
            U1QueryGuildNews()
            QueryGuildNews = U1QueryGuildNews
            --self:Hide()
            self:ClearAllPoints() self:SetPoint("TOPRIGHT", -1, 33) self:SetSize(80, 30) self:SetText(LOCALE_zhCN and "加载新闻" or "加載新聞")
        end):un()
        CoreUIEnableTooltip(btn, LOCALE_zhCN and "老农整合包" or "老農整合包", LOCALE_zhCN and "手工加载公会新闻，减少卡顿，可以在'设置-小功能集合'里关闭此功能" or "手工加載公會新聞，減少卡頓，可以在'設置-小功能集合'裏關閉此功能")
    end
    CoreDependCall("Blizzard_GuildUI", function() createLoadButton(GuildNewsFrame) end)
    CoreDependCall("Blizzard_Communities", function() createLoadButton(CommunitiesFrameGuildDetailsFrameNews) end)
end

--[[------------------------------------------------------------
点击打开成就面板
---------------------------------------------------------------]]
local newSetItemRef = function(link, text, button, ...)
    local _, _, id = link:find("achievement:([0-9]+):")
    if id and button == "RightButton" then
        if ( not AchievementFrame ) then
            AchievementFrame_LoadUI();
        end
        if ( not AchievementFrame:IsShown() ) then
            AchievementFrame_ToggleAchievementFrame();
        end
        AchievementFrame_SelectAchievement(tonumber(id));
    end
end
hooksecurefunc("SetItemRef", newSetItemRef);
