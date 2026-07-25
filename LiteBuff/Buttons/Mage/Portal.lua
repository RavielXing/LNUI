if select(2, UnitClass("player")) ~= "MAGE" then return end

local _, addon = ...
local L = addon.L

-- 部落：传送ID / 传送门ID
local hordeSpells = {
    {tele = 3567,   portal = 11417},    -- 奥格瑞玛
    {tele = 3563,   portal = 11418},    -- 幽暗城
    {tele = 3566,   portal = 11420},    -- 雷霆崖
    {tele = 32272,  portal = 32267},    -- 银月城（燃烧的远征）
    {tele = 49358,  portal = 49361},    -- 斯通纳德
    {tele = 35715,  portal = 35717},    -- 沙塔斯
    {tele = 53140,  portal = 53142},    -- 达拉然 - 诺森德
    {tele = 88344,  portal = 88346},    -- 托尔巴拉德
    {tele = 132627, portal = 132626},   -- 锦绣谷
    {tele = 176242, portal = 176244},   -- 战争之矛
    {tele = 193759, portal = nil},      -- 守护者圣殿（无传送门，左右键共用）
    {tele = 224869, portal = 224871},   -- 达拉然 - 破碎群岛
    {tele = 281404, portal = 281402},   -- 达萨罗
    {tele = 344587, portal = 344597},   -- 奥利波斯
    {tele = 395277, portal = 395289},   -- 瓦德拉肯
    {tele = 446540, portal = 446534},   -- 多恩诺嘉尔
    {tele = 1259190, portal = 1259194}, -- 银月城
}

-- 联盟：传送ID / 传送门ID
local allianceSpells = {
    {tele = 3561,   portal = 10059},    -- 暴风城
    {tele = 3562,   portal = 11416},    -- 铁炉堡
    {tele = 3565,   portal = 11419},    -- 达纳苏斯
    {tele = 32271,  portal = 32266},    -- 埃索达
    {tele = 49359,  portal = 49360},    -- 塞拉摩
    {tele = 33690,  portal = 33691},    -- 沙塔斯
    {tele = 53140,  portal = 53142},    -- 达拉然 - 诺森德
    {tele = 88342,  portal = 88345},    -- 托尔巴拉德
    {tele = 132621, portal = 132620},   -- 锦绣谷
    {tele = 176248, portal = 176246},   -- 暴风之盾
    {tele = 193759, portal = nil},      -- 守护者圣殿（无传送门，左右键共用）
    {tele = 224869, portal = 224871},   -- 达拉然 - 破碎群岛
    {tele = 281403, portal = 281400},   -- 伯拉勒斯
    {tele = 344587, portal = 344597},   -- 奥利波斯
    {tele = 395277, portal = 395289},   -- 瓦德拉肯
    {tele = 446540, portal = 446534},   -- 多恩诺嘉尔
    {tele = 1259190, portal = 1259194}, -- 银月城
}

local button = addon:CreateActionButton('MagePortal', '传送门', nil, nil, 'DUAL')

local _scrollSnippet = [[
    local spell2 = self:GetAttribute('spell2List'..index)
    self:SetAttribute('spell2', spell2)
    self:CallMethod('SetSpell2', spell2)
]]

button:SetFlyProtect()
local spellList = {}
local spellList2 = {}

local update = function()
    wipe(spellList)
    wipe(spellList2)

    local faction = UnitFactionGroup("player")
    local spellPairs = (faction == "Alliance") and allianceSpells or hordeSpells
    local knownPairs = {}

    -- 收集已学会的传送/传送门配对
    for _, pair in ipairs(spellPairs) do
        local teleId = pair.tele
        local portalId = pair.portal

        if IsSpellKnown(teleId) then
            local knownPortalId = portalId
            -- 如果传送门技能未学会，则右鍵也使用传送技能
            if knownPortalId and not IsSpellKnown(knownPortalId) then
                knownPortalId = nil
            end
            table.insert(knownPairs, {
                tele = teleId,
                portal = knownPortalId or teleId
            })
        end
    end

    -- 按传送ID降序排列，最新的传送（ID较大）排在前面
    table.sort(knownPairs, function(a, b) return a.tele > b.tele end)

    -- 构建左右键技能列表
    for _, pair in ipairs(knownPairs) do
        addon:BuildSpellList(spellList, pair.tele)
        addon:BuildSpellList(spellList2, pair.portal)
    end

    if(#spellList > 0) then
        for count, tbl in next, spellList2 do
            button:SetAttribute('spell2List'..count, tbl.spell)
        end

        if(not button:IsShown()) then button:Show() end
        button:SetScrollable(spellList, 'spell1', _scrollSnippet)
        button.spellList2 = spellList2
        button:__163_UpdateButton()
        button:__UpdateScrollAttr_163()
        button:InvokeMethod'OnTalentSwitch'
    else
        if(button:IsShown()) then button:Hide() end
    end
end

addon:__163_OnSpellChanged(update)