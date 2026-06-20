U1RegisterAddon("WhisperPop", {
    title = LOCALE_zhCN and "密语管理" or "密語管理",
    defaultEnable = 1,
    optionsAfterVar = 1,
    load = "LOGIN", 
    frames = {"WhisperPopFrame", "WhisperPopNotifyButton"}, 
    tags = { TAG_CHAT,},
    icon = "Interface\\Icons\\INV_Letter_04",
    desc = LOCALE_zhCN and "可以记录玩家收到和发送的所有密语信息。" or "可以記錄玩家收到和發送的所有密語信息。",

    toggle = function(name, info, enable, justload)
        if justload and WhisperPopNotifyButton then
            local button = WhisperPopNotifyButton
            button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            local leftClick = button:GetScript("OnClick")
            button:SetScript("OnClick", function(self, button)
                if button == "RightButton" then
                    UUI.OpenToAddon(name, true)
                    self:SetChecked(false)
                else
                    leftClick(self, button)
                end
            end)
        end
    end,

    {
        text = LOCALE_zhCN and "打开密语窗口" or "打開密語窗口",
        callback = function(cfg, v, loading) WhisperPop:ToggleFrame() end,
    },

    {
        text = LOCALE_zhCN and "重置提示按钮位置" or "重置提示按鈕位置",
        callback = function(cfg, v, loading)
            local button = WhisperPopNotifyButton
            button:ClearAllPoints()
            button:SetPoint('BOTTOM', QuickJoinToastButton, 'TOP', 0, 2)
        end
    },

    {
        text = LOCALE_zhCN and "配置选项" or "配置選項",
        callback = function(cfg, v, loading)
			Settings.OpenToCategory(U1GetSettingCategoryIDByName("WhisperPop"))
        end
    },

});