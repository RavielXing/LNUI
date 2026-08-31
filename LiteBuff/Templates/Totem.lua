------------------------------------------------------------
-- Totem.lua  (Optimized for WoW 12.1)
--
-- Changes:
-- 1. Fixed fatal typo: OnUpdateTimer was assigned string "Y" instead of function
-- 2. 实测12.1的C_Spell.GetTotemInfo不存在，仍用全局GetTotemInfo并加secret防护
-- 3. Return proper status strings "G"/"R" for status coloring
------------------------------------------------------------

local C_Spell = C_Spell

local _, addon = ...
local templates = addon.templates

local RIGHTSPELL = C_Spell.GetSpellInfo(36936)

-- 实测12.1：C_Spell.GetTotemInfo不存在，仍用全局GetTotemInfo
local function Button_OnUpdateTimer(self, spell)
	for i = 1, 4 do
		local haveTotem, name, startTime, duration = GetTotemInfo(i)
		if haveTotem then
			local st, du = startTime or 0, duration or 0
			if issecretvalue and issecretvalue(st) then st = 0 end
			if issecretvalue and issecretvalue(du) then du = 0 end
			if (not (issecretvalue and issecretvalue(name)) and name == spell) and st > 0 and du > 0 then
				return "G", st + du
			end
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