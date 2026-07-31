-- GroupFinder manually maintained navigation placement overrides.
--
-- This table is intentionally small and hand-edited. Runtime C_LFGList
-- enumeration still decides whether an activity exists; records here only
-- override expansion placement, visible label, and sort order for runtime
-- entries that Blizzard/DB2 data places incorrectly after a game update.
--
-- Maintenance fields:
--   expansionIndex: target expansion bucket from GetExpansionName(index)
--   groupID: LFG activity group ID for normal dungeon/raid instances
--   activityID: LFG activity ID for solo activities such as world bosses
--   label: optional visible override for solo activity rows
--   orderIndex: optional sort key inside the expansion; high values place
--               LFG-only solo activities after Encounter Journal instances

local _, GF = ...

GF.NAV_MANUAL_CATALOG = {
	raid = {
		expansions = {},
	},
	dungeon = {
		expansions = {},
	},
}

return GF.NAV_MANUAL_CATALOG
