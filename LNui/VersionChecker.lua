U1PLUG["VersionChecker"] = function()
    local addonName = "VersionChecker"
    local VC = CreateFrame("Frame")
    local prefix = "LNui_Version"
    local version = 540
    local minVersion = 1.0

    local function InitDB()
        if not LNuiVersionCheckerDB then
            LNuiVersionCheckerDB = {}
        end

        LNuiVersionCheckerDB.lastNotify = LNuiVersionCheckerDB.lastNotify or 0
        LNuiVersionCheckerDB.lastShownVersion = LNuiVersionCheckerDB.lastShownVersion or 0
        LNuiVersionCheckerDB.firstRun = LNuiVersionCheckerDB.firstRun or true

        if LNuiVersionCheckerDB.enableSound == nil then
            LNuiVersionCheckerDB.enableSound = true
        end

        return LNuiVersionCheckerDB
    end

    local VC_DB = InitDB()

    local isInitialized = false

    local function OnEvent(self, event, ...)
        if event == "ADDON_LOADED" then
            local loadedAddon = ...
            if loadedAddon == addonName then
                VC_DB = InitDB()
            end
        elseif event == "PLAYER_LOGIN" then
            if not isInitialized then
                self:Initialize()
                isInitialized = true
            end
        end
    end

    VC:RegisterEvent("ADDON_LOADED")
    VC:RegisterEvent("PLAYER_LOGIN")
    VC:SetScript("OnEvent", OnEvent)

    function VC:Initialize()
        if not C_ChatInfo then
            -- print("|cff19CCF9[老农整合包]:|r 版本检测功能需要C_ChatInfo API支持")
            return
        end

        local success, err = pcall(function()
            C_ChatInfo.RegisterAddonMessagePrefix(prefix)
        end)

        if not success then
            -- print("|cff19CCF9[老农整合包]:|r 版本检测前缀注册失败: " .. tostring(err))
            return
        end

        if version > (VC_DB.lastShownVersion or 0) then
            self:ShowUpdateNotes()
            VC_DB.lastShownVersion = version
            VC_DB.firstRun = false
        end

        local delay = 300
        C_Timer.After(delay, function()
            self:BroadcastToGuild()
        end)

        self:RegisterEvent("CHAT_MSG_ADDON")
        self:RegisterEvent("GROUP_ROSTER_UPDATE")
        self:RegisterEvent("PLAYER_ENTERING_WORLD")

        self:SetScript("OnEvent", function(_, event, ...)
            if event == "CHAT_MSG_ADDON" then
                self:OnChatMessage(...)
            elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
                self:OnGroupUpdate()
            end
        end)
    end

    function VC:ShowUpdateNotes()

        local frame = CreateFrame("Frame", "VersionCheckerUpdateFrame", UIParent, "ButtonFrameTemplate")
        frame:SetSize(520, 420)
        frame:SetPoint("CENTER")
        frame:SetMovable(true)
        frame:SetClampedToScreen(true)
        frame:EnableMouse(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", frame.StartMoving)
        frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
        frame:SetFrameStrata("DIALOG")
        frame:SetScript("OnHide", function(self)
            if self.timer then
                self.timer:Cancel()
                self.timer = nil
            end

            if self.logoFrame then
                self.logoFrame:Hide()
            end
        end)

        if frame.SetTitle then
            frame:SetTitle("老农整合包 - 更新说明")
        elseif frame.TitleText then
            frame.TitleText:SetText("老农整合包 - 更新说明")
        elseif _G[frame:GetName() .. "TitleText"] then
            _G[frame:GetName() .. "TitleText"]:SetText("老农整合包 - 更新说明")
        end

        local function ScrubElement(r)
            if not r then return end
            if r.SetAlpha then r:SetAlpha(0) end
            if r.SetTexture then pcall(r.SetTexture, r, nil) end
            if r.Hide then r:Hide() end
        end

        if ButtonFrameTemplate_HidePortrait then
            ButtonFrameTemplate_HidePortrait(frame)
        end
        if frame.PortraitContainer then
            frame.PortraitContainer:Hide()
            local function ScrubPortraitSubtree(f)
                if not f then return end
                for i = 1, f:GetNumRegions() do
                    ScrubElement(select(i, f:GetRegions()))
                end
                for i = 1, f:GetNumChildren() do
                    ScrubPortraitSubtree(select(i, f:GetChildren()))
                end
            end
            ScrubPortraitSubtree(frame.PortraitContainer)
        end

        for _, name in ipairs({
            "PortraitFrame", "portraitFrame", "PortraitFrameBg", "Portrait", "portrait",
        }) do
            ScrubElement(frame[name])
        end
        for i = 1, frame:GetNumRegions() do
            local region = select(i, frame:GetRegions())
            local rname = region.GetName and region:GetName()
            if rname and rname:lower():find("portrait") then
                ScrubElement(region)
            end
        end

        local titleText = frame.TitleText
            or (frame.TitleContainer and frame.TitleContainer.TitleText)
            or _G[(frame:GetName() or "") .. "TitleText"]
        if titleText then
            titleText:ClearAllPoints()
            titleText:SetPoint("TOP", frame, "TOP", 0, -6)
            local fontFile, size, flags = titleText:GetFont()
            if fontFile and size then
                titleText:SetFont(fontFile, math.max(8, math.floor(size + 0.5) - 1), flags or "")
            end
        end

        local FRAME_INSET_MARGIN = 12
        local CONTENT_MARGIN = 18
        local SCROLLBAR_WIDTH = 28

        if frame.Inset then
            frame.Inset:ClearAllPoints()
            frame.Inset:SetPoint("TOPLEFT", frame, "TOPLEFT", FRAME_INSET_MARGIN, -18)
            frame.Inset:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -FRAME_INSET_MARGIN, FRAME_INSET_MARGIN)

            if not frame.Inset.Bg then
                frame.Inset.Bg = frame.Inset:CreateTexture(nil, "BACKGROUND")
                frame.Inset.Bg:SetAllPoints(frame.Inset)
            end
            frame.Inset.Bg:SetTexture("Interface\\AuctionFrame\\AuctionHouseFrameBg")
            frame.Inset.Bg:SetTexCoord(0, 1, 0, 1)
        end

        local insetParent = frame.Inset or frame

        local logoFrame = CreateFrame("Frame", nil, UIParent)
        logoFrame:SetFrameStrata("TOOLTIP")
        logoFrame:SetFrameLevel(999)
        logoFrame:SetSize(110, 110)
        logoFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", -50, 65)
        logoFrame:EnableMouse(false)

        local logo = logoFrame:CreateTexture(nil, "OVERLAY")
        logo:SetTexture("Interface\\AddOns\\!!!163UI!!!\\Textures\\UI2-logo.blp")
        logo:SetAllPoints(logoFrame)
        logo:SetDrawLayer("OVERLAY", 7)

        frame:HookScript("OnShow", function() logoFrame:Show() end)
        frame:HookScript("OnHide", function() logoFrame:Hide() end)
        logoFrame:Show()
        frame.logoFrame = logoFrame

        local confirmBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        confirmBtn:SetSize(120, 25)
        confirmBtn:SetPoint("BOTTOM", frame, "BOTTOM", 0, 18)
        confirmBtn:SetText("知道了")
        confirmBtn:SetScript("OnClick", function() frame:Hide() end)

        local scrollFrame = CreateFrame("ScrollFrame", nil, insetParent, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", insetParent, "TOPLEFT", CONTENT_MARGIN, -22)
        scrollFrame:SetPoint("BOTTOM", confirmBtn, "TOP", 0, 4)
        scrollFrame:SetPoint("LEFT", insetParent, "LEFT", CONTENT_MARGIN, 0)
        scrollFrame:SetPoint("RIGHT", insetParent, "RIGHT", -SCROLLBAR_WIDTH, 0)

        if scrollFrame.ScrollBar then
            scrollFrame.ScrollBar:ClearAllPoints()
            scrollFrame.ScrollBar:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", 0, 0)
            scrollFrame.ScrollBar:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", 0, 0)
        end

        local content = CreateFrame("EditBox", nil, scrollFrame)
        content:SetSize(scrollFrame:GetWidth(), scrollFrame:GetHeight())
        content:SetMultiLine(true)
        content:SetAutoFocus(false)
        content:SetFontObject("GameFontHighlight")
        content:SetTextInsets(10, 10, 10, 10)
        content:SetEnabled(false)
        content:SetMouseClickEnabled(false)
        content:SetMouseMotionEnabled(false)

        content:SetText([[|cff19CCF9[2026年8月14日更新内容][540版]：|r
1.背包增强插件(Baganator)升级到2.4.8-1
2.PVP战场框体(BattleGroundEnemiesFixed)升级到12.1.0
3.任务导航线(WaypointUI)升级到1.5.5
4.集合石(MeetingStone)升级岛20260813
5.SUF头像增强(ShadowedUnitFrames)升级到4.6.1
6.[神秘地瓜]副本语音助手(DiGuaTimelineAudioHelper)升级到1.6.5
7.技能冷却计时(MinimalistCooldownEdge)升级到4.3.1
8.姓名板助手(Platynator)升级到458
9.老农工具箱(LNui)升级到20260813

|cffFF7D00温馨提示：更多历史更新，可通过[|r |cff19CCF9老|cffffb300农|cffD56AFF插|cffFF6BED件|cffFF2AA5中|cff96ff00心|r |CFFFFFFFF-|r |cffFFD100更新记录|r |cffFF7D00]查看。|r]])

        scrollFrame:SetScrollChild(content)

        if frame.CloseButton then
            frame.CloseButton:Disable()
            frame.CloseButton:SetAlpha(0.5)
        end

        local countdown = 6
        confirmBtn:SetEnabled(false)
        confirmBtn:SetText("知道了 (" .. countdown .. "秒)")

        frame.timer = C_Timer.NewTicker(1, function()
            countdown = countdown - 1
            if countdown > 0 then
                confirmBtn:SetText("知道了 (" .. countdown .. "秒)")
            else
                confirmBtn:SetText("知道了")
                confirmBtn:SetEnabled(true)
                if frame.CloseButton then
                    frame.CloseButton:Enable()
                    frame.CloseButton:SetAlpha(1)
                end
                if frame.timer then
                    frame.timer:Cancel()
                    frame.timer = nil
                end
            end
        end)

        frame:Show()
    end

    function VC:BroadcastToGuild()
        if IsInGuild() then
            local success, err = pcall(function()
                C_ChatInfo.SendAddonMessage(prefix, tostring(version), "GUILD")
            end)
            if not success and VC_DB.firstRun then
            end
        end
    end

    function VC:BroadcastToGroup()
        local inGroup = IsInGroup() or IsInRaid()
        if not inGroup then return end

        local _, instanceType = IsInInstance()
        local channel

        if instanceType == "pvp" or instanceType == "arena" then
            channel = "BATTLEGROUND"
        elseif instanceType == "party" or instanceType == "raid" or instanceType == "scenario" then
            channel = "INSTANCE_CHAT"
        else
            channel = IsInRaid() and "RAID" or "PARTY"
        end

        local success, err = pcall(function()
            C_ChatInfo.SendAddonMessage(prefix, tostring(version), channel)
        end)

        if not success and VC_DB.firstRun then
        end
    end

    function VC:OnGroupUpdate()
        local currentlyInGroup = IsInGroup() or IsInRaid()

        if not self.wasInGroup and currentlyInGroup then
            C_Timer.After(1, function()
                self:BroadcastToGroup()
            end)
        end

        self.wasInGroup = currentlyInGroup
    end

    function VC:OnChatMessage(addonPrefix, message, channelType, sender)
        if addonPrefix ~= prefix then return end

        local playerName = UnitName("player")
        local senderName = sender and (sender:match("^([^-]+)") or sender)
        if senderName == playerName then return end

        local remoteVersion = tonumber(message)
        if not remoteVersion then return end
        if remoteVersion < minVersion then return end

        local currentTime = time()
        local lastNotify = VC_DB.lastNotify or 0

        if remoteVersion > version and (currentTime - lastNotify >= 43200) then
            VC_DB.lastNotify = currentTime
            print("|TInterface/AddOns/LNui/Media/laonong:20|t|cff19CCF9[老农整合包]:|r "..format("|cFFFFFF00检测到您使用的老农整合包已过期，请及时更新！|r", remoteVersion))

            if VC_DB.enableSound then
                pcall(function()
                    PlaySound(8959, "Master")
                end)
            end
        end
    end

    function VC:ToggleSound()
        VC_DB.enableSound = not VC_DB.enableSound
    end

    -- SLASH_VERSIONCHECK1 = "/vc"
    -- SLASH_VERSIONCHECK2 = "/versioncheck"
    -- SlashCmdList["VERSIONCHECK"] = function(msg)
        -- msg = msg and msg:lower() or ""
        -- if msg == "sound" then
            -- VC:ToggleSound()
        -- end
    -- end
end