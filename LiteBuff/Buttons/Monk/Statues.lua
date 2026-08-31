------------------------------------------------------------
-- Statues.lua
--
-- Abin
-- 2013/7/22
------------------------------------------------------------

if select(2, UnitClass("player")) ~= "MONK" then return end

local _, addon = ...

local button = addon:CreateActionButton("MonkOxStatue", 115315, nil, 900, "DUAL")
button:SetSpell(115315)
button:SetAttribute("spell", button.spell)
button:RequireSpell(115315)
button:SetFlyProtect()
button:SetAttribute("type2", "destroytotem")
button:SetAttribute("totem-slot2", 1)

function button:OnUpdateTimer()
    local haveTotem, name, startTime, duration = GetTotemInfo(1)
    local st, du = 0, 0
    if haveTotem then
        st = startTime or 0
        du = duration or 0
        if issecretvalue and issecretvalue(st) then st = 0 end
        if issecretvalue and issecretvalue(du) then du = 0 end
    end
    
    if st > 0 and du > 0 then
        return "NONE", st + du
    end
    return "R"
end