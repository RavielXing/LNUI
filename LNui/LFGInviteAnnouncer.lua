U1PLUG["LFGInviteAnnouncer"] = function()
-- LFGInviteAnnouncer.lua

local defaults = { x = 0, y = 315 }
local function GetDB()
    if not LFGInviteAnnouncerDB then
        LFGInviteAnnouncerDB = {}
    end
    for k, v in pairs(defaults) do
        if LFGInviteAnnouncerDB[k] == nil then
            LFGInviteAnnouncerDB[k] = v
        end
    end
    return LFGInviteAnnouncerDB
end
local db = GetDB()

local f = CreateFrame("Frame")
f:RegisterEvent("LFG_LIST_APPLICATION_STATUS_UPDATED")

-- 创建主框架
local announceFrame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
announceFrame:SetSize(300, 80)
announceFrame:SetPoint("CENTER", UIParent, "CENTER", db.x, db.y)
announceFrame:Hide()
announceFrame:SetMovable(true)
announceFrame:EnableMouse(false)

-- 添加至暗之夜风格背景
local bg = announceFrame:CreateTexture(nil, "BACKGROUND")
bg:SetAtlas("midnight-scenario-titlebg")
bg:SetPoint("TOPLEFT", -15, 15)
bg:SetPoint("BOTTOMRIGHT", 15, -15)

-- 添加金色边框
local border = announceFrame:CreateTexture(nil, "BORDER")
border:SetAtlas("midnight-scenario-titlebarborder")
border:SetPoint("TOPLEFT", -20, 20)
border:SetPoint("BOTTOMRIGHT", 20, -20)

-- 添加熔岩效果层
local lava = announceFrame:CreateTexture(nil, "ARTWORK")
lava:SetAtlas("midnight-scenario-titlebar-lava")
lava:SetPoint("BOTTOMLEFT", -10, -15)
lava:SetPoint("BOTTOMRIGHT", 10, -15)
lava:SetHeight(15)
lava:SetBlendMode("ADD")

-- 添加符文装饰
local rune = announceFrame:CreateTexture(nil, "OVERLAY")
rune:SetAtlas("midnight-scenario-titlebar-rune")
rune:SetPoint("TOPLEFT", 10, -10)
rune:SetSize(32, 32)
rune:SetBlendMode("ADD")

-- 文字设置
announceFrame.text = announceFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
announceFrame.text:SetFont(ChatFontNormal:GetFont(), 26, "OUTLINE")
announceFrame.text:SetPoint("CENTER")
announceFrame.text:SetTextColor(1, 0.8, 0.4, 1)  -- 金色文字
announceFrame.text:SetShadowColor(0, 0, 0, 1)
announceFrame.text:SetShadowOffset(2, -2)

local function UpdatePosition()
    announceFrame:ClearAllPoints()
    announceFrame:SetPoint("CENTER", UIParent, "CENTER", db.x, db.y)
end

local function ShowAnnounce(msg)
    announceFrame.text:SetText(msg)
    -- 添加淡入淡出效果
    announceFrame:SetAlpha(0)
    announceFrame:Show()
    UIFrameFadeIn(announceFrame, 1, 0, 1)
    C_Timer.After(5, function()
        UIFrameFadeOut(announceFrame, 2, 1, 0)
        C_Timer.After(2, function() announceFrame:Hide() announceFrame:SetAlpha(1) end)
    end)
end

f:SetScript("OnEvent", function(self, event, resultid, status, prevstatus, title)
    if not resultid or status ~= "inviteaccepted" then return end
    local info = C_LFGList.GetSearchResultInfo(resultid)
    if not info or not info.activityIDs or #info.activityIDs == 0 then return end
    local activityID = info.activityIDs[1]
    local name = C_LFGList.GetActivityFullName(activityID) or "未知活动"
    local msg = name .. " - " .. (title or "")  -- 移除了"已加入："提示
    -- print("|cffb044a2[LFG]|r " .. msg)
    ShowAnnounce(msg)
end)

-- 拖动相关
local movingMode = false
local function StartMoving()
    announceFrame:StartMoving()
end
local function StopMoving()
    announceFrame:StopMovingOrSizing()
    local centerX, centerY = announceFrame:GetCenter()
    local parentX, parentY = UIParent:GetCenter()
    db.x = math.floor(centerX - parentX + 0.5)
    db.y = math.floor(centerY - parentY + 0.5)
    print("|cff19CCF9[老农整合包]|r: 位置已保存 (x="..db.x.." y="..db.y..")")
end

SLASH_LFGIA1 = "/lfgia"
SlashCmdList["LFGIA"] = function(msg)
    if msg == "move" then
        if not movingMode then
            -- 进入拖动模式
            movingMode = true
            announceFrame:Show()
            announceFrame:EnableMouse(true)
            announceFrame.text:SetText("拖动我到你想要的位置")
            announceFrame:SetMovable(true)
            announceFrame:RegisterForDrag("LeftButton")
            announceFrame:SetScript("OnDragStart", StartMoving)
            announceFrame:SetScript("OnDragStop", StopMoving)
            print("|cff19CCF9[老农整合包]|r: 现在可以拖动文本位置。再次输入 /lfgia move 退出拖动。")
        else
            -- 退出拖动模式
            movingMode = false
            announceFrame:EnableMouse(false)
            announceFrame:SetScript("OnDragStart", nil)
            announceFrame:SetScript("OnDragStop", nil)
            announceFrame:Hide()
            UpdatePosition()
            print("|cff19CCF9[老农整合包]|r: 拖动模式已关闭。")
        end
    else
        print("用法: /lfgia move  开启/关闭拖动模式。")
    end
end

UpdatePosition()

end