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
    
    -- 修复：通过 tostring 中转后再 tonumber，清除 taint 污染
    -- 直接对 secret number 用 tonumber 无效，必须先转字符串
    if type(startTime) == "number" then
        local ok, val = pcall(function() return tonumber(tostring(startTime)) end)
        startTime = ok and val or 0
    else
        startTime = 0
    end
    
    if type(duration) == "number" then
        local ok, val = pcall(function() return tonumber(tostring(duration)) end)
        duration = ok and val or 0
    else
        duration = 0
    end
    
    if startTime > 0 and duration > 0 then
        return "NONE", startTime + duration
    end
    return "R"
end