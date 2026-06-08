U1PLUG["minimapdifficulty"] = function()

------小地图显示副本难度-代码来自：EKE------

local G = {}
local _, playerClass = UnitClass("player")
G.Diff = "Interface\\Addons\\LNui\\Media\\difficulty.tga"
G.font = STANDARD_TEXT_FONT
G.fontSize = 10  -- 字体大小
G.fontFlag = "OUTLINE"

local F = {}
F.CreateFS = function(parent, text, fontsize, justify, anchor, x, y)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(G.font, fontsize, G.fontFlag)
    fs:SetText(text)
    fs:SetTextColor(1, 1, 1)  -- 固定为白色
    fs:SetShadowOffset(0, 0)
    fs:SetWordWrap(false)
    fs:SetJustifyH(justify)
    if anchor and x and y then
        fs:SetPoint(anchor, x, y)
    else
        fs:SetPoint("CENTER", 0, 2)
    end
    return fs
end

local instDifficulty = _G.MinimapCluster.InstanceDifficulty
instDifficulty:UnregisterAllEvents()
instDifficulty:Hide()
instDifficulty.Show = function() end

local Diff = CreateFrame("Frame", "EKMinimapDungeonIcon", Minimap)
Diff:SetSize(48, 48)
Diff:SetFrameLevel(Minimap:GetFrameLevel() + 2)
Diff:SetPoint("TOPRIGHT", Minimap, 10, 30)  -- 图标位置
Diff.Texture = Diff:CreateTexture(nil, "OVERLAY")
Diff.Texture:SetAllPoints(Diff)
Diff.Texture:SetTexture("Interface\\Addons\\LNui\\Media\\difficulty.tga")
Diff.Texture:SetVertexColor(0, 0, 0, 0.4)  -- 图标透明度（黑色）
Diff.Text = F.CreateFS(Diff, "", G.fontSize + 4, "CENTER")

local function styleDifficulty(self)
    local DiffText = self.Text
    local inInstance, instanceType = IsInInstance()
    local difficulty = select(3, GetInstanceInfo())
    local num = select(9, GetInstanceInfo())
    local mplus = select(1, C_ChallengeMode.GetActiveKeystoneInfo()) or ""
    
    local DifficultyTAG = {
        [1] = "5人普通",
        [2] = "5人英雄",
        [3] = "10人普通",
        [4] = "25人普通",
        [5] = "10人英雄",
        [6] = "25人英雄",
        [7] = "随机",
        [8] = "大米" .. mplus,
        [9] = "40人团",
        [11] = "英雄场景",
        [12] = "普通场景",
        [14] = num .. "普通",
        [15] = num .. "英雄",
        [16] = "史诗团",
        [17] = num .. "随机",
        [18] = "团队事件",
        [19] = "地城事件",
        [20] = "场景事件",
        [23] = "5人史诗",
        [24] = "漫游地城",
        [25] = "PVP",
        [29] = "PEP",
        [30] = "事件",
        [32] = "PVP",
        [33] = "漫游团队",
        [34] = "PVP",
        [38] = "普通海岛",
        [39] = "英雄海岛",
        [40] = "史诗海岛",
        [45] = "PVP",
        [147] = "普通前线",
        [149] = "英雄前线",
        [151] = "随机团队",
        [152] = "幻象",
        [153] = "海岛",
        [167] = "托加斯特",
        [205] = "追随者",
        [208] = "地下堡"
    }

    if instanceType == "party" or instanceType == "raid" or instanceType == "scenario" then
        DiffText:SetText(DifficultyTAG[difficulty] or "挑战")
    elseif instanceType == "pvp" or instanceType == "arena" then
        DiffText:SetText("PVP")
    else
        DiffText:SetText("场景")
    end

    Diff:SetAlpha(inInstance and 1 or 0)  -- 仅在副本内显示
end

-- 注册事件
Diff:RegisterEvent("PLAYER_ENTERING_WORLD")
Diff:RegisterEvent("PLAYER_DIFFICULTY_CHANGED")
Diff:RegisterEvent("INSTANCE_GROUP_SIZE_CHANGED")
Diff:RegisterEvent("ZONE_CHANGED_NEW_AREA")
Diff:RegisterEvent("CHALLENGE_MODE_START")
Diff:RegisterEvent("CHALLENGE_MODE_COMPLETED")
Diff:RegisterEvent("CHALLENGE_MODE_RESET")
Diff:SetScript("OnEvent", styleDifficulty)

end