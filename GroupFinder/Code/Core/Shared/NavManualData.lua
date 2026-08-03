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
--
-- NAV_CATALOG_SUPPLEMENT is a separate, post-Encounter-Journal fallback.
-- It carries additive placement metadata for a newer client without giving
-- those records the higher priority of an explicit manual override. Ordinary
-- archive groups still require a current EntryCreation-style activity query;
-- version-gated seed data contributes group candidates, never authorization.

local _, GF = ...

GF.NAV_MANUAL_CATALOG = {
	raid = {
		expansions = {},
	},
	dungeon = {
		expansions = {},
	},
}

local supportsMidnight121 = GF.Compat
	and GF.Compat.IsInterfaceAtLeast
	and GF.Compat.IsInterfaceAtLeast(GF.INTERFACE_MIDNIGHT_12_1_0 or 120100)

-- The generated table is enabled only for 12.1+ ordinary archives and supplies
-- candidate group keys. NavCatalog still requires current EntryCreation-style
-- GetAvailableActivities() authorization and strict category/group validation;
-- exact season catalogs do not read these candidates or archive exclusions.
GF.NAV_CATALOG_ACTIVITY_SEEDS = supportsMidnight121
	and GF.NAV_CATALOG_ACTIVITY_SEEDS_121 or {
	dungeon = {},
	raid = {},
}

GF.NAV_CATALOG_ARCHIVE_EXCLUDED_GROUPS = supportsMidnight121
	and GF.NAV_CATALOG_ARCHIVE_EXCLUDED_GROUPS_121 or {
	dungeon = {},
	raid = {},
}

GF.NAV_CATALOG_SUPPLEMENT = {
	raid = {
		expansions = supportsMidnight121 and {
			{
				expansionIndex = 11,
				instances = {
					{ groupID = 429, orderIndex = 5 },
					{ groupID = 424, orderIndex = 6 },
				},
			},
		} or {},
	},
	dungeon = {
		expansions = supportsMidnight121 and {
			{
				expansionIndex = 11,
				instances = {
					{ groupID = 420, orderIndex = 9 },
				},
			},
		} or {},
	},
}

return GF.NAV_MANUAL_CATALOG
