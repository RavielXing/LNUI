local O = tdDropDown_Option

O.Menu = false		-- 列表边框设置				(true:圆角  nil:默认)
O.MAX = 25

--[[------------------------------------------------------------
邮箱收件人
---------------------------------------------------------------]]
do
    local mail = {}
    function tdHookSendMail(recipient, subject, body) tdInsertValueIfNotExist("SendMailNameEditBox", recipient); end
    mail.hook = function()
        SendMailNameEditBoxButton:ClearAllPoints()
        SendMailNameEditBoxButton:SetPoint("RIGHT", SendMailNameEditBox, "RIGHT", -76, 0)--lnui
        hooksecurefunc("SendMail", function(...) tdHookSendMail(...) end)
    end
    mail.profile = "SendMailNameEditBox"
    mail.over = true
    tdCreateDropDown(mail)
end

--[[------------------------------------------------------------
拍卖行搜索
---------------------------------------------------------------]]
do
    function tdHookAuctionSearch(...) if AuctionHouseFrame.SearchBar.SearchBox:IsVisible() then tdInsertValueIfNotExist("BrowseName", AuctionHouseFrame.SearchBar.SearchBox:GetText()); end end
    local ah = {
        profile = "BrowseName",
        event = "ADDON_LOADED",
        short = true,
        func = function(arg1) return arg1 == "Blizzard_AuctionHouseUI" end,
        click = function() AuctionHouseFrame.SearchBar:StartSearch() end,
        hook = function()
            hooksecurefunc(AuctionHouseFrame.SearchBar, "StartSearch", function(...) tdHookAuctionSearch(...) end)
        end
    }
    tdCreateDropDown(ah)
end

--[[------------------------------------------------------------
冒险指南搜索装备
---------------------------------------------------------------]]
do
    local ej = {}
    ej.profile = "EncounterJournalSearchBox"
    ej.event = "ADDON_LOADED"
    ej.func = function(arg1) return arg1 == "Blizzard_EncounterJournal" end
    ej.short = true
    ej.hook = function()
        local point, relativeTo, relativePoint, xOffset, yOffset = EncounterJournalSearchBox:GetPoint()
        EncounterJournalSearchBox:SetPoint(point, relativeTo, relativePoint, xOffset-19, yOffset)
        EncounterJournalSearchBox:SetWidth(EncounterJournalSearchBox:GetWidth()-19)
    end
    ej.click = function()
        RunOnNextFrame(function()
            if EncounterJournalSearchBoxSearchButton1 and EncounterJournalSearchBoxSearchButton1:IsVisible() then
                EncounterJournalSearchBoxSearchButton1:Click()
            end
        end)
    end
    tdCreateDropDown(ej)
end

--[[------------------------------------------------------------
成就搜索
---------------------------------------------------------------]]
do
    local achieve = {
        profile = "AchievementFrame.SearchBox",
        event = "ADDON_LOADED",
        short = true,
        func = function(arg1) return arg1 == "Blizzard_AchievementUI" end,
    }
    tdCreateDropDown(achieve)
end

--[[------------------------------------------------------------
背包搜索
---------------------------------------------------------------]]
do
    tdCreateDropDown({
        profile = "BagItemSearchBox",
        short_hook = true,
    })
end

--[[------------------------------------------------------------
战网状态
---------------------------------------------------------------]]
do
    local friends = {}
    friends.profile = "FriendsFrameBattlenetFrame.BroadcastFrame.EditBox"
    friends.over = true
    friends.click = function()
        FriendsFrameBattlenetFrame.BroadcastFrame:SetBroadcast()
    end
    tdCreateDropDown(friends)
end

--[[------------------------------------------------------------
收藏界面
---------------------------------------------------------------]]
do
    local collectionLoaded = function(arg1) return arg1 == "Blizzard_Collections" or IsAddOnLoaded("Blizzard_Collections") end
    tdCreateDropDown({
        profile = "MountJournalSearchBox",
        event = "ADDON_LOADED",
        func = collectionLoaded,
        short = true,
    })

    tdCreateDropDown({
        profile = "PetJournalSearchBox",
        event = "ADDON_LOADED",
        func = collectionLoaded,
        short = true,
    })

    tdCreateDropDown({
        profile = "WardrobeCollectionFrameSearchBox",
        event = "ADDON_LOADED",
        func = collectionLoaded,
        hook = function()
            local point, rel, relPoint, x, y = WardrobeCollectionFrame.FilterButton:GetPoint(1)
            if point and point:find("LEFT") then
                WardrobeCollectionFrame.FilterButton:SetPoint(point, rel, relPoint, x + 19, y)
            end
            local hook_setting
            hooksecurefunc(WardrobeCollectionFrameSearchBox, "SetPoint", function(self)
                if hook_setting then return end
                local point, rel, relPoint, x, y = self:GetPoint(1)
                if point and point:find("RIGHT") then
                    hook_setting = 1
                    self:SetPoint(point, rel, relPoint, x - 19, y)
                    hook_setting = nil
                end
            end)
        end,
        short_hook = true,
    })

    tdCreateDropDown({
        profile = "ToyBox.searchBox",
        event = "ADDON_LOADED",
        func = collectionLoaded,
        move = true,
    })

    tdCreateDropDown({
        profile = "HeirloomsJournalSearchBox",
        event = "ADDON_LOADED",
        func = collectionLoaded,
        move = true,
    })
end

do
    tdCreateDropDown({
        profile = "Rematch.PetPanel.Top.SearchBox",
        event = "ADDON_LOADED",
        func = function(arg1) return IsAddOnLoaded("Rematch") and Rematch.PetPanel end,
        move = true,
    })

    tdCreateDropDown({
        profile = "RematchTeamPanel.Top.SearchBox",
        event = "ADDON_LOADED",
        func = function(arg1) return IsAddOnLoaded("Rematch") and RematchTeamPanel end,
        move = true,
    })
end