------------------------------------------------------------
-- Pets.lua
-- 术士召唤恶魔常驻按钮
------------------------------------------------------------

if select(2, UnitClass("player")) ~= "WARLOCK" then return end

local _, addon = ...
local L = addon.L

local wipe = wipe

local spellList = {}
local button

local function RebuildSpellList()
    wipe(spellList)

    local specID
    local index = GetSpecialization()
    if index then
        specID = GetSpecializationInfo(index)
    end

    local order
    if specID == 266 then
        -- 恶魔术：恶魔卫士优先，其他按常见顺序
        order = { 30146, 691, 688, 697, 366222 }
    else
        -- 非恶魔术：地狱猎犬优先
        order = { 691, 688, 697, 366222 }
    end

    for _, id in ipairs(order) do
        if IsSpellKnown(id) then
            addon:BuildSpellList(spellList, id)
        end
    end

    if #spellList == 0 then
        -- 专精信息未就绪时兜底加入基础恶魔
        for _, id in ipairs({ 688, 697, 691, 366222, 30146 }) do
            if IsSpellKnown(id) then
                addon:BuildSpellList(spellList, id)
            end
        end
    end

    button:SetScrollable(spellList, "spell1")
end

button = addon:CreateActionButton("WarlockPets", "召唤恶魔", nil, nil, "DUAL")
button:SetFlyProtect()
button:RequireSpell(688)
button:SetScrollable(spellList, "spell1")

RebuildSpellList()

function button:OnSpellUpdate()
    RebuildSpellList()
end
