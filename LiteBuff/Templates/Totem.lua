------------------------------------------------------------
-- Totem.lua  (Optimized for WoW 12.1)
--
-- Changes:
-- 1. Fixed fatal typo: OnUpdateTimer was assigned string "Y" instead of function
-- 2. Adapted to C_Spell.GetTotemInfo table return in 12.1
-- 3. Return proper status strings "G"/"R" for status coloring
------------------------------------------------------------

local C_Spell = C_Spell

local _, addon = ...
local templates = addon.templates

local RIGHTSPELL = C_Spell.GetSpellInfo(36936)

-- WoW 12.1: GetTotemInfo returns a table, not multiple returns
local function Button_OnUpdateTimer(self, spell)
	for i = 1, 4 do
		local info = C_Spell.GetTotemInfo(i)
		if info and info.haveTotem and info.totemName == spell
		   and (info.startTime or 0) > 0 and (info.duration or 0) > 0 then
			return "G", info.startTime + info.duration
		end
	end
	return "R"
end

templates.RegisterTemplate("TOTEM", function(button)
	button.spell2 = RIGHTSPELL
	button:SetAttribute("spell2", RIGHTSPELL)
	button:SetFlyProtect()
	-- FIXED: Was incorrectly assigned as string "Y" due to typo
	button.OnUpdateTimer = Button_OnUpdateTimer
end, "DUAL")