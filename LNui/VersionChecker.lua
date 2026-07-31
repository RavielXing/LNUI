U1PLUG["VersionChecker"] = function()
    local addonName = "VersionChecker"
    local VC = CreateFrame("Frame")
    local prefix = "LNui_Version"
    local version = 533
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

        content:SetText([[|cff19CCF9[2026年7月31日更新内容][533版]：|r
1.全职业天赋汇总(MurlokExport)升级到20260728.003204
2.距离提示(RangeDisplay)升级到6.3.4
3.冷却管理器(Coolinator)升级到113
4.队伍查找器(GroupFinder)2.0.0回归，无特殊情况不再替换
  |cff7F7F7F--新增：'预组队伍''大秘境''团队副本'三个独立工作区。
  --新增：大秘境专属寻找队伍界面，支持赛季地城多选、职责与专精匹配、职责需求、已有职责、最低空位及最低评分过滤。
  --新增：大秘境'组队管理'，支持创建、更新、顶榜与解散招募；无操作权限时自动切换为只读视图。
  --新增：传送与通报、战术通报及跟随传送功能。
  --新增：'宏伟宝库'与'KeystoneLoot'底栏入口；相关插件未安装或未加载时，自动显示对应的降级状态。
  --新增：寻找队伍右键菜单支持复制队长完整名称，并统一创建招募与寻找队伍的跨服角色名称复制窗口。
  --新增：LibKeystone 数据支持，并可选读取 LibOpenRaid 与 LibOpenKeystone；外部数据仅用于补全未知钥石状态。
  --新增：共享消息传输服务，统一处理通信前缀、消息节流、失败重试及换队清理，同时保留 GFMP2 与 GFTP1 独立协议。
  --新增：大秘境周报 Tooltip，并恢复赛季最佳纪录独立窗口。
  --新增：离线队员在当前组队会话中，将保留最后一次在线时的钥石、评分、专精及最佳纪录。
  --新增：大秘境'角色卡片'增加专精天赋切换功能。
  --修复：战斗中点击传送按钮会导致整个主窗口进入受保护状态的问题；现在仅禁用传送操作。
  --修复：集合石与大秘境顶榜流程中的同步下架事件、受保护文本恢复、成功确认、操作超时、主动解散、跨阵营选项及等级限制问题。
  --修复：未选择赛季地城时，相关过滤与搜索控件仍可操作的问题。
  --修复：大秘境搜索跨多个活动范围时结果过滤异常，以及返回页面后未重新执行过滤的问题。
  --修复：搜索建议框的所有权、锚点及关闭清理异常，避免建议框残留在屏幕左上角。
  --修复：战术通报切换草稿时缺少确认、编辑状态显示异常及滚动边界错误的问题。
  --修复：老农插件加载状态判断异常、SavedVariables 损坏时无法正确初始化，以及调试页滚动视口裁切问题。
  --修复：受保护招募说明字段、HidingBar 小地图按钮层级、任务导航合并、Tooltip 宽度及队伍与车队滚动条内缩问题。
  --优化：为主界面增加配套背景图样，统一整体视觉风格。
  --优化：当前角色底栏改为原生风格的天赋配置下拉框，并调整角色卡、PlayerModel、底栏裁切及大秘境周报布局。
  --优化：最低装等改为按角色独立保存；'默认设置'改为仅恢复当前设置分类。
  --优化：赛季地城卡片按照当前角色的赛季评分降序排列；评分相同时，保持 Blizzard 赛季地图顺序。
  --优化：统一 PvP 评分的灰、白、绿、紫、橙品质区间配色。
  --优化：统一角色、队伍、车队、寻找队伍、创建招募及黑名单页面的空状态字号。
  --优化：统一按钮四态、刷新图标、传送图标、钥石链接、列表行背景、专精缓存、评分颜色及最佳纪录表格。
  --优化：完善英文与繁体中文术语，并补充繁体中文更新日志前缀适配。
  --适配：完善 KeystoneLoot、LibKeystone、LibOpenRaid、LibOpenKeystone、集合石、老农插件包及 HidingBar 的兼容与降级处理。
  --重构：预组队伍与大秘境工作区，引入 LFGWorkspacePolicy 与 LFGWorkspaceView，实现双视图、单一 LFG 核心及单一搜索会话。
  --重构：设置页面，将功能归纳为'界面与外观''列表样式''提醒与通报''战术通报''高级设置'五个分类。
  --重构：战术通报页面，采用左侧赛季地城列表与右侧编辑器布局，并增加未保存、已设置状态图示及草稿切换确认。
  --重构：角色、队伍、车队、地城、寻找队伍、创建招募及黑名单的数据结构，将赛季、钥石、评分、周常、角色、名单、车队与传送拆分为独立缓存服务。
  --重构：由多语言、当前装等及当前赛季驱动的测试夹具，并统一预组队伍与大秘境的调试数据。|r
  |cffFF2D2D--集合石(MeetingStone)下架，请Interface\AddOns里，删除MeetingStone、MeetingStoneEX文件夹 |r

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