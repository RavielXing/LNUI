AutoTurnIn.QuestLevelFormat = " [%d] %s"
AutoTurnIn.WatchFrameLevelFormat = "[%d%s%s] %s"
AutoTurnIn.QuestTypesIndex = {
	[0] = "",           --default
	[1] = "g",			--Group
	[41] = "+",			--PvP
	[62] = "r",			--Raid
	[81] = "d",			--Dungeon
	[83] = "L", 		--Legendary
	[85] = "h",			--Heroic
	[98] = "s", 		--Scenario QUEST_TYPE_SCENARIO
	[102] = "a", 		-- Account
}

function AutoTurnIn:ShowQuestLevelInLog()
	-- =====  DISABLED IN 12.0+ TO PREVENT UI WIDGET TAINT =====
	-- Modifying QuestMapFrame causes taint that propagates to Blizzard_UIWidgetManager,
	-- triggering arithmetic errors on secret number values in UIWidgetTemplateTextWithState.
	-- See: https://github.com/.../AutoTurnIn/issues/...
	return
end

--[[
	FIXME: This thing taints the global frames. 
	To check: ESC ->"Edit mode" and close the layout window. 
--]]
function AutoTurnIn:ShowQuestLevelInWatchFrame()
	-- =====  DISABLED IN 12.0+ TO PREVENT UI WIDGET TAINT =====
	-- Modifying ObjectiveTrackerFrame causes taint that propagates to Blizzard_UIWidgetManager,
	-- triggering arithmetic errors on secret number values in UIWidgetTemplateTextWithState.
	-- See: https://github.com/.../AutoTurnIn/issues/...
	return
end